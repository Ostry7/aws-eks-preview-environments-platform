variable "k8s_cluster_name" {
  description = "Kubernetes cluster name"
  type = string
}

variable "cluster_name" {
  description = "EKS cluster name (actual, from module.eks output)"
  type        = string
}

variable "ecr_public_username" {
  type = string
}

variable "ecr_public_password" {
  type = string
  sensitive = true
}