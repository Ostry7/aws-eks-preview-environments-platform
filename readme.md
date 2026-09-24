# AWS EKS Preview Environments Platform

> Ephemeral, per-pull-request preview environments on Amazon EKS — powered by a cached CI/CD pipeline and serverless automation.

## Overview
 
Every open pull request in the target application repository automatically gets its own isolated environment on EKS — a dedicated namespace, database, and public URL with TLS — built through a heavily cached CI/CD pipeline and torn down automatically once the PR closes or expires.
 
This project is a hands-on exploration of **platform engineering** patterns: self-service ephemeral environments, CI/CD performance optimization through caching, GitOps-driven provisioning, and event-driven cost control via serverless automation.

## Roadmap
 
| Phase | Scope | Status |
|---|---|---|
| 0 | Repo structure, OIDC, remote state, budget alarms | ✅ |
| 1 | VPC + EKS + ECR + Karpenter (Terraform modules) | 🔲 |
| 2 | Demo app + baseline pipeline (no cache) | 🔲 |
| 3 | Layered CI/CD caching + measurements | 🔲 |
| 4 | ArgoCD ApplicationSet + DNS/TLS preview environments | 🔲 |
| 5 | Lambda automation (reaper, cost reporter, scale-to-zero, PR commenter) | 🔲 |
| 6 | Security scanning, Kyverno policies, External Secrets, dashboards | 🔲 |
| 7 | Metrics, architecture diagram, demo, final documentation | 🔲 |

---

### Install Karpenter:

1. Prerequisites -> install *AWS CLI*, install *kubectl*, install *eksctl* (CLI for AWS EKS), install *helm*.
2. Set variables:
```bash
export KARPENTER_NAMESPACE="kube-system"
export KARPENTER_VERSION="1.14.1"
export K8S_VERSION="1.36"
export AWS_PARTITION="aws" # if you are not using standard partitions, you may need to configure to aws-cn / aws-us-gov
export ENABLE_ZONAL_SHIFT="true" # if you are not using Zonal Shift, change this to false
export CLUSTER_NAME="${USER}-karpenter-demo"
export AWS_DEFAULT_REGION="eu-north-1"
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
export TEMPOUT="$(mktemp)"
export ALIAS_VERSION="$(aws ssm get-parameter --name "/aws/service/eks/optimized-ami/${K8S_VERSION}/amazon-linux-2023/x86_64/standard/recommended/image_id" --query Parameter.Value | xargs aws ec2 describe-images --query 'Images[0].Name' --image-ids | sed -r 's/^.*(v[[:digit:]]+).*$/\1/')"

```
---

## ADR-0001: Karpenter as a node provisioner - version selection and AWS Free Tier limitations

### Context:
The platform requires dynamic provisioning of EC2 nodes for ephemeral preview environments — the number of nodes must increase and decrease in line with the number of open PRs, without manual intervention and without maintaining a fixed, overprovisioned pool of `ex_managed_node_groups`. For this purpose, Karpenter was chosen as the node autoscaler/provisioner, replacing the traditional Cluster Autoscaler, due to its faster response time, “just-in-time” provisioning tailored to specific application requirements, and native integration with the terraform-aws-modules/eks/aws module.

During the implementation, three independent blocking issues were encountered, as described below.

1. Selection of compatible versions: EKS 1.35 + Karpenter 1.6.3

Originally, the cluster was created with `cluster_version = “1.36”` (the latest available EKS version at the time the project began) and the Karpenter Helm chart 1.1.1. This combination proved to be incompatible:

```
panic: validating Kubernetes version; Karpenter version is not compatible with K8s version 1.36
```

Karpenter has strict, built-in validation for supported Kubernetes versions (not only a lower limit set by `KUBERNETES_MIN_VERSION`, but also an upper limit that is not explicitly specified in the configuration). Version 1.1.1 did not recognize K8s 1.36 as compatible and terminated the process with a panic instead of starting the controller.

An additional complication: EKS does not allow in-place cluster version downgrades (`UpdateClusterVersion` from 1.36 to 1.33 throws an `InvalidParameterException`), so downgrading to a lower K8s version required a full `terraform destroy` followed by `terraform apply` for the cluster, rather than a simple configuration update.

The following was chosen: `cluster_version = “1.33”` + Karpenter Helm chart 1.6.3, as a combination confirmed in Karpenter’s official compatibility matrix to be stable and extensively tested by the community, as opposed to the relatively recently released bleeding-edge K8s 1.36.

2. Pod Identity Instead of IRSA for Karpenter

Karpenter authenticates to the AWS API using EKS Pod Identity (`aws_eks_pod_identity_association`) rather than the classic `IRSA` (IAM Roles for Service Accounts) used for the EBS CSI driver in the same cluster. This required adding an add-on:

```hcl
cluster_addons = {
  eks-pod-identity-agent = {}
}
```

and explicitly associating the role:

```hcl
resource “aws_eks_pod_identity_association” “karpenter” {
  cluster_name    = module.eks.cluster_name
  namespace       = “kube-system”
  service_account = “karpenter”
  role_arn        = module.karpenter.iam_role_arn
}
```

AWS authentication worked correctly right away (visible in the pods’ environment variables: `AWS_CONTAINER_CREDENTIALS_FULL_URI`), which confirmed that issue #1 (version incompatibility) was completely unrelated to the permissions layer.


3. AWS Free Tier Restriction on EC2 Instance Types

The AWS account used for this project has an active Free Tier restriction that rejects `CreateFleet` requests for any instance type not on a narrow, account-specific list:

```
InvalidParameterCombination: The specified instance type is not eligible
for the Free Tier.
```

Karpenter’s default NodePool (without the `node.kubernetes.io/instance-type` filter) tried dozens of general-purpose instance types in succession (`c5.xlarge`, `m5.xlarge`, `t3.medium`, etc.)—all of which were rejected. The exact, up-to-date list of allowed instance types for a given account/region was determined by:

```bash
aws ec2 describe-instance-types \
  --region eu-north-1 \
  --filters “Name=free-tier-eligible,Values=true” \
  --query “InstanceTypes[].InstanceType” \
  --output table
```

Result for eu-north-1: `t4g.small`, `t4g.micro` (ARM64/Graviton), `t3.micro`, `t3.small`, `c7i-flex.large`, `m7i-flex.large` (amd64).

Selected: Narrowing NodePool.requirements to amd64-compatible types from this list:

```yaml
requirements:
  - key: kubernetes.io/arch
    operator: In
    values: [“amd64”]
  - key: node.kubernetes.io/instance-type
    operator: In
    values: [“t3.micro”, “t3.small”, “c7i-flex.large”, “m7i-flex.large”]
```

The `t4g.*` types (Graviton/ARM64) were intentionally omitted—using them would require a parallel ARM64 path in EC2NodeClass (AMI family, image selector), which is an unnecessary complication at this stage of the project.

Side effect: zombie NodeClaims

Each failed `CreateFleet` attempt left a NodeClaim in the Unknown/LaunchFailed state, which blocked subsequent reconciliation attempts for the same pending pods (Karpenter “assigned” the pod to the dead NodeClaim instead of creating a new one). Workaround:

```bash
kubectl delete nodeclaims --all
```

This is not an architectural issue, but rather a result of iterative debugging (changing the NodePool several times without clearing previous attempts)—noted here as an operational tip for the future, not as a design decision.

## Local Terraform modules:
Local modules in Terraform is just an directory with `.tf` files. Let's look at quick analogy:
- `variable` -> is an function argument (`INPUT`)
- `output` -> is and return value (`OUTPUT`)

Root module is main directory from where we type `terraform init / plan/ apply`. This `root main.tf` file call other modules. Directory named `/modules` is just and naming convention, terraform doesn't require this name, it's looking at:
```bash
source = "./directory"
```
---

### IMPORTANT!
The modules know nothing about each other and cannot see root. Echa module is isolated; data flows in ony one direction:

```bash
ROOT_MODULE-----(variable)---->MODULE
ROOT_MODULE<----(output)------MODULE
```
So how `module A` can  pass sth into `module B`? -> ALWAYS THROUGH ROOT

```
MODULE_A---->output---->ROOT_MODULE---->variable---->MODULE_B
```