output "cluster_name" {
  value = module.eks.cluster_name
}

output "ecr_repo_name" {
  value = module.ecr.ecr_repo_name
}