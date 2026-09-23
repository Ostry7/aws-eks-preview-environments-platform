variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}


variable "primary_priv_cidr" {
  description = "CIDR block for primary-priv"
  type        = string
}

variable "secondary_priv_cidr" {
  description = "CIDR block for secondary-priv"
  type        = string
}

variable "tertiary_priv_cidr" {
  description = "CIDR block for tertiary-priv"
  type        = string
}

variable "primary_pub_cidr" {
  description = "CIDR block for primary-pub"
  type        = string
}

variable "secondary_pub_cidr" {
  description = "CIDR block for secondary-pub"
  type        = string
}

variable "tertiary_pub_cidr" {
  description = "CIDR block for tertiary-pub"
  type        = string
}

variable "k8s_cluster_name" {
  description = "Kubernetes cluster name"
  type = string
}