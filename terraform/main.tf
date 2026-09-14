# Create main VPC
resource "aws_vpc" "main-vpc" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"

  tags = {
    Usage = "main"
  }
}

# Create availability_zones with 3Private Subnets AZs
data "aws_availability_zones" "available" {
  state = "available"

}

resource "aws_subnet" "primary-priv" {
  vpc_id            = aws_vpc.main-vpc.id
  cidr_block        = var.primary-priv_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "primary-priv_subnet"
  }
}

resource "aws_subnet" "secondary-priv" {
  vpc_id            = aws_vpc.main-vpc.id
  cidr_block        = var.secondary-priv_cidr
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "secondary-priv_subnet"
  }
}

resource "aws_subnet" "tertiary-priv" {
  vpc_id            = aws_vpc.main-vpc.id
  cidr_block        = var.tertiary-priv_cidr
  availability_zone = data.aws_availability_zones.available.names[2]

  tags = {
    Name = "tertiary-priv_subnet"
  }
}

