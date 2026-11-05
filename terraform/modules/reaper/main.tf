data "archive_file" "reaper" {
  type        = "zip"
  source_file = "${path.module}/../../../lambda/reaper/reaper.py"
  output_path = "${path.module}/reaper.zip"
}

resource "aws_iam_role" "reaper" {
  name = "preview-reaper"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole",
                   Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.reaper.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "describe" {
  role = aws_iam_role.reaper.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "eks:DescribeCluster"
      Resource = "arn:aws:eks:${var.aws_region}:*:cluster/${var.k8s_cluster_name}"
    }]
  })
}

resource "aws_eks_access_entry" "reaper" {
  cluster_name      = var.k8s_cluster_name
  principal_arn     = aws_iam_role.reaper.arn
  kubernetes_groups = ["preview-reaper"]
}

resource "aws_lambda_function" "reaper" {
  function_name    = var.function_name
  role             = aws_iam_role.reaper.arn
  runtime          = "python3.12"
  handler          = "reaper.handler"
  timeout          = 60
  filename         = data.archive_file.reaper.output_path
  source_code_hash = data.archive_file.reaper.output_base64sha256
  environment {
    variables = {
      CLUSTER_NAME = var.k8s_cluster_name
      REGION       = var.aws_region
      TTL_HOURS    = tostring(var.ttl_hours)
      DRY_RUN      = tostring(var.dry_run)
    }
  }
}

resource "aws_cloudwatch_event_rule" "hourly" {
  name                = "preview-reaper-hourly"
  schedule_expression = "rate(1 hour)"
}

resource "aws_cloudwatch_event_target" "reaper" {
  rule = aws_cloudwatch_event_rule.hourly.name
  arn  = aws_lambda_function.reaper.arn
}

resource "aws_lambda_permission" "events" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.reaper.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.hourly.arn
}