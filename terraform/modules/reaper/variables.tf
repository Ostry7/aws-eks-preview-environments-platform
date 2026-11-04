variable "function_name" {
  type = string
}

variable "k8s_cluster_name" {
   type = string 
}

variable "aws_region" { 
  type = string 
}

variable "ttl_hours" {
   default = 1 
}

variable "dry_run" {
  default = true 
}