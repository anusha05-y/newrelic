output "lambda_name" {
  value = aws_lambda_function.nr_alert_sync.function_name
}

output "event_rule_name" {
  value = aws_cloudwatch_event_rule.ec2_running.name
}