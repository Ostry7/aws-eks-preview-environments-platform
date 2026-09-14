# Create main VPC
resource "aws_vpc" "main-vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Usage = "main"
  }
}

# Create availability_zones with 3Public Subnets AZs and 3Private Subnets AZs
# Declare the data source
data "aws_availability_zones" "available" {
  state = "available"

}

resource "aws_subnet" "primary-priv" {
    vpc_id = aws_vpc.main-vpc.id
    availability_zone = data.aws_availability_zones.available.names[0]

  # ...
}

resource "aws_subnet" "secondary-priv" {
    vpc_id = aws_vpc.main-vpc.id
    availability_zone = data.aws_availability_zones.available.names[1]

  # ...
}

resource "aws_subnet" "tertiary-priv" {
    vpc_id = aws_vpc.main-vpc.id
    availability_zone = data.aws_availability_zones.available.names[2]

  # ...
}

