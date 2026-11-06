# Create EKS (based on: https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks)
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.5"

  cluster_name    = var.k8s_cluster_name
  cluster_version = "1.35"

  cluster_endpoint_public_access = true

  access_entries = {
    roboticusr = {
      principal_arn = "arn:aws:iam::521764600585:user/roboticusr"
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
    github_actions = {
      principal_arn = "arn:aws:iam::521764600585:role/github-actions-admin-role"
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

cluster_addons = {
  aws-ebs-csi-driver     = { most_recent = true }
  eks-pod-identity-agent = { most_recent = true }
}

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  eks_managed_node_group_defaults = {
    ami_type = "AL2023_x86_64_STANDARD"
  }

  node_security_group_tags = {
    "karpenter.sh/discovery" = var.k8s_cluster_name
  }

  eks_managed_node_groups = {
    one = {
      name = "node-group-1"

      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 3
      desired_size = 2
    }
  }
}

# EBS Pod identity
module "ebs_csi_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 1.4"

  name                      = "${var.k8s_cluster_name}-ebs-csi"
  attach_aws_ebs_csi_policy = true

  associations = {
    main = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "ebs-csi-controller-sa"
    }
  }
}