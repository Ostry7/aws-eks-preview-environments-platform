output "cluster_name" {
  value = module.eks.cluster_name
}

output "ecr_repo_name" {
  value = module.ecr.ecr_repo_name
}

output "region" {
  value = var.aws_region
}

output "preview_base_domain" {
  value = "${module.network.ingress_eip_public_ip}.sslip.io"
}