variable "aws_region" {
  type = string
}

variable "k8s_cluster_name" {
  type = string
}

variable "cluster_arn" {
    description = "Provide ARN for K8s cluster"
    type = string
}

variable "function_name" {
    description = "Provide Lambda function name"
    type = string
}