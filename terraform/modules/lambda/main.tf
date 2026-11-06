data "aws_caller_identity" "current" {}

locals {
  cluster_arn = "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.k8s_cluster_name}"
}

data "archive_file" "reaper" {
  type        = "zip"
  source_dir  = "${path.module}/../../../lambda/reaper/build"
  output_path = "${path.module}/reaper.zip"
}

resource "aws_lambda_function" "reaper" {
  function_name    = var.function_name
  role             = aws_iam_role.lambda.arn
  handler          = "reaper.lambda_handler"
  runtime          = "python3.14"
  architectures    = ["x86_64"]
  timeout          = 60
  memory_size      = 256
  filename         = data.archive_file.reaper.output_path
  source_code_hash = data.archive_file.reaper.output_base64sha256

  environment {
    variables = {
      CLUSTER_NAME = var.k8s_cluster_name
    }
  }

  tags = {
    Application = "preview-platform"
  }

  depends_on = [aws_iam_role_policy_attachment.basic_execution]
}

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
    resources = [local.cluster_arn]
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

# wpuszcza rolę do klastra; uprawnienia w K8s daje grupa z k8s/reaper-rbac.yaml
resource "aws_eks_access_entry" "reaper" {
  cluster_name      = var.k8s_cluster_name
  principal_arn     = aws_iam_role.lambda.arn
  kubernetes_groups = ["preview-reaper"]
}