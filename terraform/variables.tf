variable "aws_region" {
  type    = string
  default = "eu-north-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "primary_priv_cidr" {
  description = "CIDR block for primary-priv"
  type        = string
  default     = "10.0.1.0/24"
}

variable "secondary_priv_cidr" {
  description = "CIDR block for secondary-priv"
  type        = string
  default     = "10.0.2.0/24"
}

variable "tertiary_priv_cidr" {
  description = "CIDR block for tertiary-priv"
  type        = string
  default     = "10.0.3.0/24"
}

variable "primary_pub_cidr" {
  description = "CIDR block for primary-pub"
  type        = string
  default     = "10.0.101.0/24"
}

variable "secondary_pub_cidr" {
  description = "CIDR block for secondary-pub"
  type        = string
  default     = "10.0.102.0/24"
}

variable "tertiary_pub_cidr" {
  description = "CIDR block for tertiary-pub"
  type        = string
  default     = "10.0.103.0/24"
}

variable "k8s_cluster_name" {
  description = "Kubernetes cluster name"
  type = string
  default = "k8s_cluster"
}