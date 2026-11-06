data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "eks_describe" {
  statement {
    effect    = "Allow"
    actions   = ["eks:DescribeCluster"]
    resources = [var.cluster_arn]
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.function_name}-eks-access"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "eks_describe" {
  name   = "${var.function_name}-eks-describe"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.eks_describe.json
}