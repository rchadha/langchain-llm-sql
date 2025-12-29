# Simple Lambda deployment - perfect for hobby projects!
# Cost: ~$0-2/month (only pay when you use it)

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "langchain-sql"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

##################################################
# ECR Repository (reuse existing)
##################################################

resource "aws_ecr_repository" "lambda_repo" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  lifecycle {
    prevent_destroy = false
  }

  tags = {
    Name = var.ecr_repository_name
  }
}

resource "aws_ecr_lifecycle_policy" "lambda_repo_policy" {
  repository = aws_ecr_repository.lambda_repo.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = 5
      }
      action = {
        type = "expire"
      }
    }]
  })
}

##################################################
# CloudWatch Log Group
##################################################

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.lambda_function_name}-logs"
  }
}

##################################################
# IAM Role for Lambda
##################################################

resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.lambda_function_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.lambda_function_name}-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_additional_permissions" {
  name = "${var.lambda_function_name}-additional-permissions"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.lambda_function_name}:*"
      }
    ]
  })
}

##################################################
# Lambda Function
##################################################

resource "aws_lambda_function" "langchain_sql" {
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_execution_role.arn
  package_type  = "Image"
  image_uri     = var.lambda_image_uri != "" ? var.lambda_image_uri : "${aws_ecr_repository.lambda_repo.repository_url}:latest"

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  environment {
    variables = {
      OPENAI_API_KEY = var.openai_api_key
    }
  }

  image_config {
    command = ["lambda_handler.handler"]
  }

  lifecycle {
    ignore_changes = [
      image_uri,
    ]
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
    aws_iam_role_policy_attachment.lambda_basic_execution
  ]

  tags = {
    Name = var.lambda_function_name
  }
}

##################################################
# API Gateway (HTTP API - cheaper & simpler)
##################################################

resource "aws_apigatewayv2_api" "lambda_api" {
  name          = "${var.lambda_function_name}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS", "GET"]
    allow_headers = ["content-type", "x-api-key"]
    max_age       = 300
  }

  tags = {
    Name = "${var.lambda_function_name}-api"
  }
}

resource "aws_apigatewayv2_stage" "lambda_api_stage" {
  api_id      = aws_apigatewayv2_api.lambda_api.id
  name        = "$default"
  auto_deploy = true

  tags = {
    Name = "${var.lambda_function_name}-default"
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.lambda_api.id
  integration_type = "AWS_PROXY"

  integration_uri    = aws_lambda_function.langchain_sql.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "lambda_route" {
  api_id    = aws_apigatewayv2_api.lambda_api.id
  route_key = "POST /query-sql"

  target = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.langchain_sql.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda_api.execution_arn}/*/*"
}
