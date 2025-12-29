variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "app_name" {
  description = "Application name (used for resource naming)"
  type        = string
  default     = "langchain-sql"
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "langchain-sql-app"
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "langchain-sql-lambda"
}

variable "lambda_image_uri" {
  description = "Docker image URI for Lambda function (optional, will use ECR repo URL if not provided)"
  type        = string
  default     = ""
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 60
}

variable "lambda_memory_size" {
  description = "Lambda function memory in MB"
  type        = number
  default     = 512
}

variable "openai_api_key" {
  description = "OpenAI API key for the application"
  type        = string
  sensitive   = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}
