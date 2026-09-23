variable "vpc_id" {
  description = "VPC ID from network module"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs from network module"
  type        = list(string)
}

variable "k8s_cluster_name" {
  description = "Kubernetes cluster name"
  type = string
}
