output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.lambda_repo.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.lambda_repo.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.langchain_sql.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.langchain_sql.arn
}

output "api_gateway_url" {
  description = "URL of the API Gateway endpoint"
  value       = aws_apigatewayv2_stage.lambda_api_stage.invoke_url
}

output "api_endpoint" {
  description = "Full API endpoint URL for the /query-sql route"
  value       = "${aws_apigatewayv2_stage.lambda_api_stage.invoke_url}/query-sql"
}

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution_role.arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS Region"
  value       = data.aws_region.current.name
}

# Summary output for easy reference
output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    ecr_repository    = aws_ecr_repository.lambda_repo.repository_url
    api_endpoint      = "${aws_apigatewayv2_stage.lambda_api_stage.invoke_url}/query-sql"
    lambda_function   = aws_lambda_function.langchain_sql.function_name
    log_group         = aws_cloudwatch_log_group.lambda_logs.name
  }
}
