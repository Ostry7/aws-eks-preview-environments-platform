output "vpc_id" {
  value = aws_vpc.main-vpc.id
}

output "private_subnet_ids" {
  value = [
    aws_subnet.primary-priv.id,
    aws_subnet.secondary-priv.id,
    aws_subnet.tertiary-priv.id,
  ]
}

output "public_subnet_ids" {
  value = [
    aws_subnet.primary-pub.id,
    aws_subnet.secondary-pub.id,
    aws_subnet.tertiary-pub.id,
  ]
}

output "ingress_eip_allocation_id" {
  value = aws_eip.ingress.allocation_id
}

output "ingress_eip_public_ip" {
  value =  aws_eip.ingress.public_ip
}