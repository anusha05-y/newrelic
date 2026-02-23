provider "aws" {
  region = var.region
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.lambda_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Inline policy
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.lambda_name}-inline"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["ec2:DescribeInstances"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["ssm:GetParameter"]
        Resource = var.nr_api_key_param_arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.lambda_name}"
  retention_in_days = 14
}

resource "aws_lambda_function" "nr_alert_sync" {
  function_name = var.lambda_name
  runtime       = "python3.11"
  handler       = "lambda_function.lambda_handler"
  role          = aws_iam_role.lambda_role.arn

  filename         = "${path.module}/../lambda/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda/lambda.zip")

  timeout     = 10
  memory_size = 128

  environment {
    variables = {
      NR_API_KEY_PARAM = var.nr_api_key_param_name
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_logs]
}

# Trigger when EC2 enters running state
resource "aws_cloudwatch_event_rule" "ec2_running" {
  name = "${var.lambda_name}-ec2-running"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
    detail = {
      state = ["running"]
    }
  })
}

# Connect EventBridge to Lambda
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule = aws_cloudwatch_event_rule.ec2_running.name
  arn  = aws_lambda_function.nr_alert_sync.arn
}

# Allow EventBridge to invoke Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.nr_alert_sync.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ec2_running.arn
}