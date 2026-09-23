# Create ECR
resource "aws_ecr_repository" "ecr_repo" {
  name                 = "main_ecr_repo"
  image_tag_mutability = "IMMUTABLE"
}