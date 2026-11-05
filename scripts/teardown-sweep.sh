#!/usr/bin/env bash
# Użycie: bash scripts/teardown-sweep.sh k8s|aws
# Zmienne: CLUSTER_NAME, REGION, DRY_RUN (true/false), VPC_ID (dla fazy aws)
set -uo pipefail

CLUSTER="${CLUSTER_NAME:?brak CLUSTER_NAME}"
REGION="${REGION:?brak REGION}"
DRY_RUN="${DRY_RUN:-true}"

run() {
  if [ "$DRY_RUN" = "true" ]; then
    echo "[dry-run] $*"
  else
    echo "+ $*"
    "$@" || echo "  (nie powiodło się, idę dalej)"
  fi
}

# ── Faza 1: Kubernetes ────────────────────────────────────────────────────────
# Cel: żeby chmura sama posprzątała to, co powstało z obiektów K8s
# (LoadBalancery z Service'ów, wolumeny EBS z PVC, instancje Karpentera).
phase_k8s() {
  if ! aws eks describe-cluster --name "$CLUSTER" --region "$REGION" >/dev/null 2>&1; then
    echo "Klastra '$CLUSTER' nie ma, pomijam fazę k8s"
    return
  fi
  aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" >/dev/null

  echo "== Release'y PR-ów (app-pr-*) =="
  for r in $(helm list -n default -q 2>/dev/null | grep '^app-pr-' || true); do
    run helm uninstall "$r" -n default --wait --timeout 5m
  done

  echo "== Osierocone namespace'y pr-* =="
  for ns in $(kubectl get ns -o name | sed 's#namespace/##' | grep '^pr-' || true); do
    run kubectl delete ns "$ns" --wait --timeout=300s
  done

  echo "== Wszystkie Service'y typu LoadBalancer (usuwa LB w AWS) =="
  kubectl get svc -A -o json \
    | jq -r '.items[] | select(.spec.type=="LoadBalancer") | "\(.metadata.namespace) \(.metadata.name)"' \
    | while read -r ns name; do
        run kubectl -n "$ns" delete svc "$name" --wait --timeout=300s
      done

  echo "== Karpenter: NodePool i NodeClaim (Karpenter musi jeszcze działać) =="
  run kubectl delete nodepool --all --wait --timeout=600s
  run kubectl delete nodeclaim --all --wait --timeout=600s
}

# ── Faza 2: AWS ───────────────────────────────────────────────────────────────
# Cel: usunąć to, co blokuje Terraform przy kasowaniu subnetów/IGW/SG/EIP
# (DependencyViolation): instancje, LB, ENI, grupy bezpieczeństwa k8s-elb-*.
phase_aws() {
  local VPC="${VPC_ID:-}"
  if [ -z "$VPC" ] || [ "$VPC" = "None" ]; then
    echo "Brak VPC_ID, pomijam sweep AWS (podaj vpc_id w inputach workflow)"
    return
  fi
  echo "VPC: $VPC"

  echo "== Instancje Karpentera =="
  local ids
  ids=$(aws ec2 describe-instances --region "$REGION" \
    --filters "Name=vpc-id,Values=$VPC" "Name=tag-key,Values=karpenter.sh/nodepool" \
              "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[].Instances[].InstanceId' --output text)
  if [ -n "$ids" ]; then
    run aws ec2 terminate-instances --region "$REGION" --instance-ids $ids
    [ "$DRY_RUN" = "true" ] || aws ec2 wait instance-terminated --region "$REGION" --instance-ids $ids
  fi

  echo "== Load balancery w VPC (classic i v2) =="
  for lb in $(aws elb describe-load-balancers --region "$REGION" \
      --query "LoadBalancerDescriptions[?VPCId=='$VPC'].LoadBalancerName" --output text); do
    run aws elb delete-load-balancer --region "$REGION" --load-balancer-name "$lb"
  done
  for arn in $(aws elbv2 describe-load-balancers --region "$REGION" \
      --query "LoadBalancers[?VpcId=='$VPC'].LoadBalancerArn" --output text); do
    run aws elbv2 delete-load-balancer --region "$REGION" --load-balancer-arn "$arn"
  done

  if [ "$DRY_RUN" != "true" ]; then
    echo "== Czekam, aż zniknął ENI load balancerów =="
    for _ in $(seq 1 20); do
      n=$(aws ec2 describe-network-interfaces --region "$REGION" \
        --filters "Name=vpc-id,Values=$VPC" "Name=description,Values=ELB*" \
        --query 'length(NetworkInterfaces)' --output text)
      [ "$n" = "0" ] && break
      echo "  pozostało ENI: $n"; sleep 15
    done
  fi

  echo "== Grupy bezpieczeństwa k8s-elb-* =="
  for sg in $(aws ec2 describe-security-groups --region "$REGION" \
      --filters "Name=vpc-id,Values=$VPC" "Name=group-name,Values=k8s-elb-*" \
      --query 'SecurityGroups[].GroupId' --output text); do
    # reguły w innych SG (np. węzłów), które wskazują na ten SG
    for ref in $(aws ec2 describe-security-groups --region "$REGION" \
        --filters "Name=ip-permission.group-id,Values=$sg" \
        --query 'SecurityGroups[].GroupId' --output text); do
      perms=$(aws ec2 describe-security-groups --region "$REGION" --group-ids "$ref" --output json \
        | jq -c --arg sg "$sg" '[.SecurityGroups[0].IpPermissions[]
            | select(any(.UserIdGroupPairs[]?; .GroupId==$sg))
            | .UserIdGroupPairs |= map(select(.GroupId==$sg))
            | del(.IpRanges, .Ipv6Ranges, .PrefixListIds)]')
      run aws ec2 revoke-security-group-ingress --region "$REGION" --group-id "$ref" --ip-permissions "$perms"
    done
    run aws ec2 delete-security-group --region "$REGION" --group-id "$sg"
  done

  echo "== Odpięte ENI w VPC =="
  for eni in $(aws ec2 describe-network-interfaces --region "$REGION" \
      --filters "Name=vpc-id,Values=$VPC" "Name=status,Values=available" \
      --query 'NetworkInterfaces[].NetworkInterfaceId' --output text); do
    run aws ec2 delete-network-interface --region "$REGION" --network-interface-id "$eni"
  done

  echo "== Wolumeny EBS po PVC (status available) =="
  for v in $(aws ec2 describe-volumes --region "$REGION" \
      --filters "Name=status,Values=available" "Name=tag-key,Values=kubernetes.io/created-for/pvc/name" \
      --query 'Volumes[].VolumeId' --output text); do
    run aws ec2 delete-volume --region "$REGION" --volume-id "$v"
  done
}

case "${1:-}" in
  k8s) phase_k8s ;;
  aws) phase_aws ;;
  *)   echo "Użycie: $0 k8s|aws"; exit 2 ;;
esac