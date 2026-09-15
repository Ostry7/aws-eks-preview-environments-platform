# Create main VPC
resource "aws_vpc" "main-vpc" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"

  tags = {
    Name = "MainVPC"
    Usage = "main"
  }
}

# Create IGW
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main-vpc.id
}

# Create availability_zones with 3Private Subnets AZs and 3Public Subnets AZs
#Priv AZs
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }

}

resource "aws_subnet" "primary-priv" {
  vpc_id            = aws_vpc.main-vpc.id
  cidr_block        = var.primary-priv_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    "kubernetes.io/role/internal-elb" = 1 #from https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks
    Name = "primary-priv_subnet"
  }
}

resource "aws_subnet" "secondary-priv" {
  vpc_id            = aws_vpc.main-vpc.id
  cidr_block        = var.secondary-priv_cidr
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    "kubernetes.io/role/internal-elb" = 1 #from https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks
    Name = "secondary-priv_subnet"
  }
}

resource "aws_subnet" "tertiary-priv" {
  vpc_id            = aws_vpc.main-vpc.id
  cidr_block        = var.tertiary-priv_cidr
  availability_zone = data.aws_availability_zones.available.names[2]

  tags = {
    "kubernetes.io/role/internal-elb" = 1 #from https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks
    Name = "tertiary-priv_subnet"
  }
}

# Public AZs
resource "aws_subnet" "primary-pub" {
  vpc_id            = aws_vpc.main-vpc.id
  cidr_block        = var.primary-pub_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch  = true

  tags = {
    "kubernetes.io/role/elb" = 1 #from https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks
    Name = "primary-pub_subnet"
  }
}

resource "aws_subnet" "secondary-pub" {
  vpc_id            = aws_vpc.main-vpc.id
  cidr_block        = var.secondary-pub_cidr
  availability_zone = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch  = true

  tags = {
    "kubernetes.io/role/elb" = 1 #from https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks
    Name = "secondary-pub_subnet"
  }
}

resource "aws_subnet" "tertiary-pub" {
  vpc_id            = aws_vpc.main-vpc.id
  cidr_block        = var.tertiary-pub_cidr
  availability_zone = data.aws_availability_zones.available.names[2]
  map_public_ip_on_launch  = true

  tags = {
    "kubernetes.io/role/elb" = 1 #from https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks
    Name = "tertiary-pub_subnet"
  }
}

# Create route table
resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.main-vpc.id

  route {
    cidr_block = "0.0.0.0/0" # Send any traffic that does not match any more specific route in this route table through the Internet Gateway (local route WINS)
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "aws_route_table"
  }
}
resource "aws_route_table_association" "public" {
    for_each = {
        primary = aws_subnet.primary-pub
        secondary = aws_subnet.secondary-pub
        tertiary = aws_subnet.tertiary-pub
    }

    subnet_id      = each.value.id
    route_table_id = aws_route_table.route_table.id
}

# Create ECR
resource "aws_ecr_repository" "ecr_repo" {
  name                 = "main_ecr_repo"
  image_tag_mutability = "IMMUTABLE_WITH_EXCLUSION"

  image_tag_mutability_exclusion_filter { #all tags are immutable except "latest*"
    filter      = "latest*"
    filter_type = "WILDCARD"
  }

  image_tag_mutability_exclusion_filter { #all tags are immutable except "dev-*"
    filter      = "dev-*"
    filter_type = "WILDCARD"
  }
}