module "network" {
  source = "./modules/network"

  vpc_cidr             = var.vpc_cidr
  primary_priv_cidr    = var.primary_priv_cidr
  secondary_priv_cidr  = var.secondary_priv_cidr
  tertiary_priv_cidr   = var.tertiary_priv_cidr
  primary_pub_cidr     = var.primary_pub_cidr
  secondary_pub_cidr   = var.secondary_pub_cidr
  tertiary_pub_cidr    = var.tertiary_pub_cidr
  k8s_cluster_name     = var.k8s_cluster_name
}

module "ecr" {
  source = "./modules/ecr"
}

module "eks" {
  source = "./modules/eks"

  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  k8s_cluster_name   = var.k8s_cluster_name
}

module "karpenter" {
  source = "./modules/karpenter"

  providers = {
    helm = helm
  }

  cluster_name     = module.eks.cluster_name
  k8s_cluster_name = var.k8s_cluster_name
}