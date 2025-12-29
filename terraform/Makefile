.PHONY: help init plan apply destroy clean outputs push-image update-lambda

# Default target
help:
	@echo "Terraform Makefile for LangChain SQL Lambda"
	@echo ""
	@echo "Available targets:"
	@echo "  init          - Initialize Terraform"
	@echo "  plan          - Show execution plan"
	@echo "  apply         - Apply Terraform configuration"
	@echo "  destroy       - Destroy all resources"
	@echo "  outputs       - Show Terraform outputs"
	@echo "  push-image    - Build and push Docker image to ECR"
	@echo "  update-lambda - Update Lambda function with latest image"
	@echo "  deploy-all    - Full deployment (apply + push-image + update-lambda)"
	@echo "  clean         - Remove Terraform files"
	@echo ""

# Initialize Terraform
init:
	@echo "Initializing Terraform..."
	terraform init

# Show execution plan
plan:
	@echo "Planning Terraform changes..."
	terraform plan

# Apply configuration
apply:
	@echo "Applying Terraform configuration..."
	terraform apply

# Auto-approve apply (use with caution!)
apply-auto:
	@echo "Applying Terraform configuration (auto-approve)..."
	terraform apply -auto-approve

# Destroy resources
destroy:
	@echo "Destroying Terraform resources..."
	terraform destroy

# Show outputs
outputs:
	@echo "Terraform Outputs:"
	@echo ""
	@terraform output

# Get specific output values
ecr-url:
	@terraform output -raw ecr_repository_url

api-endpoint:
	@terraform output -raw api_gateway_endpoint 2>/dev/null || echo "API Gateway not enabled"

github-role:
	@terraform output -raw github_actions_role_arn 2>/dev/null || echo "GitHub OIDC not enabled"

# Build and push Docker image
push-image:
	@echo "Building and pushing Docker image..."
	@ECR_REPO=$$(terraform output -raw ecr_repository_url); \
	AWS_REGION=$$(terraform output -raw aws_region); \
	echo "ECR Repository: $$ECR_REPO"; \
	echo "AWS Region: $$AWS_REGION"; \
	cd .. && \
	aws ecr get-login-password --region $$AWS_REGION | \
		docker login --username AWS --password-stdin $$ECR_REPO && \
	docker build -f Dockerfile.lambda -t $$ECR_REPO:latest . && \
	docker push $$ECR_REPO:latest

# Update Lambda function with latest image
update-lambda:
	@echo "Updating Lambda function..."
	@ECR_REPO=$$(terraform output -raw ecr_repository_url); \
	LAMBDA_FUNCTION=$$(terraform output -raw lambda_function_name); \
	AWS_REGION=$$(terraform output -raw aws_region); \
	echo "Updating $$LAMBDA_FUNCTION with $$ECR_REPO:latest"; \
	aws lambda update-function-code \
		--function-name $$LAMBDA_FUNCTION \
		--image-uri $$ECR_REPO:latest \
		--region $$AWS_REGION

# Full deployment
deploy-all: apply push-image update-lambda
	@echo ""
	@echo "✅ Deployment complete!"
	@echo ""
	@$(MAKE) outputs

# Test Lambda function
test-lambda:
	@echo "Testing Lambda function..."
	@LAMBDA_FUNCTION=$$(terraform output -raw lambda_function_name); \
	AWS_REGION=$$(terraform output -raw aws_region); \
	aws lambda invoke \
		--function-name $$LAMBDA_FUNCTION \
		--payload '{"query": "How many customers are there?"}' \
		--region $$AWS_REGION \
		response.json && \
	cat response.json && \
	rm response.json

# Test API Gateway
test-api:
	@echo "Testing API Gateway..."
	@API_ENDPOINT=$$(terraform output -raw api_gateway_endpoint 2>/dev/null); \
	if [ -z "$$API_ENDPOINT" ]; then \
		echo "API Gateway not enabled"; \
	else \
		curl -X POST $$API_ENDPOINT \
			-H "Content-Type: application/json" \
			-d '{"query": "How many customers are there?"}'; \
		echo ""; \
	fi

# Format Terraform files
fmt:
	@echo "Formatting Terraform files..."
	terraform fmt -recursive

# Validate configuration
validate:
	@echo "Validating Terraform configuration..."
	terraform validate

# Clean Terraform files
clean:
	@echo "Cleaning Terraform files..."
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate*

# Show state
show:
	@terraform show

# Refresh state
refresh:
	@terraform refresh

# Get deployment summary
summary:
	@echo "==================== Deployment Summary ===================="
	@terraform output deployment_summary
	@echo "==========================================================="
