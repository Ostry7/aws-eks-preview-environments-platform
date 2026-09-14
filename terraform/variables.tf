variable "aws_region" {
  type    = string
  default = "eu-north-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "primary-priv_cidr" {
  description = "CIDR block for primary-priv"
  type        = string
  default     = "10.0.1.0/24"
}

variable "secondary-priv_cidr" {
  description = "CIDR block for secondary-priv"
  type        = string
  default     = "10.0.2.0/24"
}

variable "tertiary-priv_cidr" {
  description = "CIDR block for tertiary-priv"
  type        = string
  default     = "10.0.3.0/24"
}

variable "primary-pub_cidr" {
  description = "CIDR block for primary-pub"
  type        = string
  default     = "10.0.101.0/24"
}

variable "secondary-pub_cidr" {
  description = "CIDR block for secondary-pub"
  type        = string
  default     = "10.0.102.0/24"
}

variable "tertiary-pub_cidr" {
  description = "CIDR block for tertiary-pub"
  type        = string
  default     = "10.0.103.0/24"
}