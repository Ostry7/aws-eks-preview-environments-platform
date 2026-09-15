# Create main VPC
resource "aws_vpc" "main-vpc" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"

  tags = {
    Name = "MainVPC"
    Usage = "main"
  }
}

# Create IGW
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main-vpc.id
}

# Create availability_zones with 3Private Subnets AZs and 3Public Subnets AZs
#Priv AZs
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }

}

resource "aws_subnet" "primary-priv" {
  vpc_id            = aws_vpc.main-vpc.id
  cidr_block        = var.primary-priv_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    "kubernetes.io/role/internal-elb" = 1 #from https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks
    Name = "primary-priv_subnet"
  }
}

resource "aws_subnet" "secondary-priv" {
  vpc_id            = aws_vpc.main-vpc.id
  cidr_block        = var.secondary-priv_cidr
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    "kubernetes.io/role/internal-elb" = 1 #from https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks
    Name = "secondary-priv_subnet"
  }
}

resource "aws_subnet" "tertiary-priv" {
  vpc_id            = aws_vpc.main-vpc.id
  cidr_block        = var.tertiary-priv_cidr
  availability_zone = data.aws_availability_zones.available.names[2]

  tags = {
    "kubernetes.io/role/internal-elb" = 1 #from https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks
    Name = "tertiary-priv_subnet"
  }
}

# Public AZs
resource "aws_subnet" "primary-pub" {
  vpc_id            = aws_vpc.main-vpc.id
  cidr_block        = var.primary-pub_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch  = true

  tags = {
    "kubernetes.io/role/elb" = 1 #from https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks
    Name = "primary-pub_subnet"
  }
}

resource "aws_subnet" "secondary-pub" {
  vpc_id            = aws_vpc.main-vpc.id
  cidr_block        = var.secondary-pub_cidr
  availability_zone = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch  = true

  tags = {
    "kubernetes.io/role/elb" = 1 #from https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks
    Name = "secondary-pub_subnet"
  }
}

resource "aws_subnet" "tertiary-pub" {
  vpc_id            = aws_vpc.main-vpc.id
  cidr_block        = var.tertiary-pub_cidr
  availability_zone = data.aws_availability_zones.available.names[2]
  map_public_ip_on_launch  = true

  tags = {
    "kubernetes.io/role/elb" = 1 #from https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks
    Name = "tertiary-pub_subnet"
  }
}

# Create route table
resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.main-vpc.id

  route {
    cidr_block = "0.0.0.0/0" # Send any traffic that does not match any more specific route in this route table through the Internet Gateway (local route WINS)
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "aws_route_table"
  }
}
resource "aws_route_table_association" "public" {
    for_each = {
        primary = aws_subnet.primary-pub
        secondary = aws_subnet.secondary-pub
        tertiary = aws_subnet.tertiary-pub
    }

    subnet_id      = each.value.id
    route_table_id = aws_route_table.route_table.id
}

# Create ECR
resource "aws_ecr_repository" "ecr_repo" {
  name                 = "main_ecr_repo"
  image_tag_mutability = "IMMUTABLE"
}

# Create EKS (based on:https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks)
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.5"

  cluster_name    = var.k8s_cluster_name
  cluster_version = "1.36"

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    aws-ebs-csi-driver = {
      service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
    }
  }

  vpc_id = aws_vpc.main-vpc.id
  subnet_ids = [
    aws_subnet.primary-priv.id,
    aws_subnet.secondary-priv.id,
    aws_subnet.tertiary-priv.id
  ]
  #vpc_id     = module.vpc.vpc_id
  #subnet_ids = module.vpc.private_subnets

  eks_managed_node_group_defaults = {
    ami_type = "AL2023_x86_64_STANDARD"

  }

  eks_managed_node_groups = {
    one = {
      name = "node-group-1"

      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 3
      desired_size = 2
    }

    two = {
      name = "node-group-2"

      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 2
      desired_size = 1
    }
  }
}


# https://aws.amazon.com/blogs/containers/amazon-ebs-csi-driver-is-now-generally-available-in-amazon-eks-add-ons/ 
data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.39.0"

  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}
