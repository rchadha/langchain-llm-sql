# Terraform Infrastructure for LangChain SQL Lambda

This directory contains Terraform configuration to provision all AWS infrastructure needed for the LangChain SQL Lambda application.

## Architecture

The Terraform configuration creates:

- **ECR Repository**: For storing Docker images
- **Lambda Function**: Container-based function with configurable memory/timeout
- **IAM Roles & Policies**:
  - Lambda execution role
  - GitHub Actions deployment role (OIDC-based, no access keys)
- **API Gateway (Optional)**: HTTP API for invoking Lambda
- **CloudWatch Log Groups**: For Lambda and API Gateway logs
- **GitHub OIDC Provider (Optional)**: For secure CI/CD

## Prerequisites

1. **AWS CLI** installed and configured
   ```bash
   aws configure
   ```

2. **Terraform** >= 1.0 installed
   ```bash
   # macOS
   brew install terraform

   # or download from https://www.terraform.io/downloads
   ```

3. **AWS Credentials** with permissions to create:
   - ECR repositories
   - Lambda functions
   - IAM roles and policies
   - API Gateway
   - CloudWatch log groups
   - OIDC providers

## Quick Start

### 1. Configure Variables

```bash
# Copy example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vi terraform.tfvars
```

Required variables in `terraform.tfvars`:
```hcl
openai_api_key    = "sk-proj-your-key-here"
github_repository = "your-username/your-repo"
```

### 2. Initialize Terraform

```bash
cd terraform
terraform init
```

### 3. Review Plan

```bash
terraform plan
```

This shows what resources will be created without actually creating them.

### 4. Apply Configuration

```bash
terraform apply
```

Type `yes` when prompted to confirm.

### 5. Get Outputs

```bash
terraform output
```

This displays important values like:
- ECR repository URL
- Lambda function name
- API Gateway endpoint
- GitHub Actions role ARN

## Building and Pushing Initial Image

After Terraform creates the infrastructure, you need to build and push the Docker image:

```bash
# Get ECR repository URL from Terraform output
ECR_REPO=$(terraform output -raw ecr_repository_url)
AWS_REGION=$(terraform output -raw aws_region)

# Navigate back to project root
cd ..

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_REPO

# Build and push image
docker build -f Dockerfile.lambda -t $ECR_REPO:latest .
docker push $ECR_REPO:latest

# Update Lambda function to use the new image
LAMBDA_FUNCTION=$(terraform output -raw lambda_function_name)
aws lambda update-function-code \
  --function-name $LAMBDA_FUNCTION \
  --image-uri $ECR_REPO:latest \
  --region $AWS_REGION
```

## Testing the Deployment

### Test Lambda Function Directly

```bash
LAMBDA_FUNCTION=$(cd terraform && terraform output -raw lambda_function_name)
AWS_REGION=$(cd terraform && terraform output -raw aws_region)

aws lambda invoke \
  --function-name $LAMBDA_FUNCTION \
  --payload '{"query": "How many customers are there?"}' \
  --region $AWS_REGION \
  response.json

cat response.json
```

### Test via API Gateway

```bash
API_ENDPOINT=$(cd terraform && terraform output -raw api_gateway_endpoint)

curl -X POST $API_ENDPOINT \
  -H "Content-Type: application/json" \
  -d '{"query": "How many customers are there?"}'
```

## GitHub Actions Setup

After running Terraform, configure GitHub secrets:

1. Go to your GitHub repository
2. Navigate to: Settings → Secrets and variables → Actions
3. Add these secrets:

   - **AWS_ROLE_ARN**:
     ```bash
     cd terraform && terraform output -raw github_actions_role_arn
     ```

   - **OPENAI_API_KEY**: Your OpenAI API key

Now pushes to `main` branch will automatically deploy!

## Configuration Options

### Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `aws_region` | AWS region | `us-east-1` | No |
| `environment` | Environment name | `dev` | No |
| `ecr_repository_name` | ECR repo name | `langchain-sql-lambda` | No |
| `lambda_function_name` | Lambda function name | `langchain-sql-query` | No |
| `lambda_timeout` | Timeout in seconds | `60` | No |
| `lambda_memory_size` | Memory in MB | `512` | No |
| `openai_api_key` | OpenAI API key | - | **Yes** |
| `enable_github_oidc` | Enable GitHub Actions | `true` | No |
| `github_repository` | GitHub repo (owner/name) | - | Yes if OIDC enabled |
| `enable_api_gateway` | Enable HTTP API | `true` | No |
| `log_retention_days` | Log retention | `7` | No |

### Enable/Disable Features

**Disable API Gateway** (Lambda only, no HTTP):
```hcl
enable_api_gateway = false
```

**Disable GitHub OIDC** (deploy manually):
```hcl
enable_github_oidc = false
```

## Multiple Environments

Deploy separate dev/staging/prod environments:

```bash
# Development
terraform workspace new dev
terraform apply -var="environment=dev" -var="lambda_function_name=langchain-sql-dev"

# Production
terraform workspace new prod
terraform apply -var="environment=prod" -var="lambda_function_name=langchain-sql-prod"
```

Or use separate directories:
```
terraform/
  dev/
  staging/
  prod/
```

## Remote State (Recommended for Teams)

Store Terraform state in S3 for team collaboration:

1. Create S3 bucket and DynamoDB table:
```bash
aws s3 mb s3://your-terraform-state-bucket
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

2. Update `main.tf`:
```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "langchain-sql/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

3. Re-initialize:
```bash
terraform init -migrate-state
```

## Cost Estimation

Estimated monthly costs (USD):

| Resource | Usage | Cost |
|----------|-------|------|
| Lambda | 100K requests, 5s avg | $0.40 |
| ECR | 1 GB storage | $0.10 |
| API Gateway | 100K requests | $0.35 |
| CloudWatch Logs | 1 GB | $0.50 |
| **Total** | | **~$1.35/month** |

*Most usage falls within AWS Free Tier for new accounts*

## Maintenance

### Update Lambda Configuration

```bash
# Edit terraform.tfvars
vi terraform.tfvars

# Apply changes
terraform apply
```

### View Current State

```bash
terraform show
```

### Destroy Resources

```bash
terraform destroy
```

**Warning**: This deletes all resources. Docker images in ECR will be deleted.

## Troubleshooting

### Permission Denied Errors

Ensure your AWS credentials have sufficient permissions:
```bash
aws sts get-caller-identity
```

### Lambda Function Not Updating

Terraform ignores `image_uri` changes by design (GitHub Actions handles this).

To force update via Terraform:
```bash
terraform apply -replace=aws_lambda_function.langchain_sql
```

### GitHub Actions Can't Assume Role

1. Verify OIDC provider exists:
```bash
aws iam list-open-id-connect-providers
```

2. Check GitHub repository name matches:
```bash
terraform output github_actions_role_arn
```

3. Verify trust policy:
```bash
aws iam get-role --role-name langchain-sql-query-github-actions-role
```

### API Gateway 403 Errors

Check Lambda permission:
```bash
aws lambda get-policy --function-name langchain-sql-query
```

## File Structure

```
terraform/
├── main.tf                  # Main resources
├── variables.tf             # Input variables
├── outputs.tf              # Output values
├── terraform.tfvars.example # Example configuration
├── .gitignore              # Git ignore rules
└── README.md               # This file
```

## Security Best Practices

1. **Never commit** `terraform.tfvars` (contains secrets)
2. **Use** remote state with encryption
3. **Enable** MFA delete on state bucket
4. **Rotate** OpenAI API keys regularly
5. **Review** IAM policies for least privilege
6. **Enable** CloudTrail for audit logging
7. **Use** OIDC instead of AWS access keys for CI/CD

## Next Steps

After infrastructure is deployed:

1. ✅ Configure GitHub secrets
2. ✅ Push code to trigger deployment
3. ✅ Test Lambda function
4. ✅ Test API Gateway endpoint
5. ⬜ Set up CloudWatch alarms
6. ⬜ Configure custom domain for API Gateway
7. ⬜ Add WAF for API protection
8. ⬜ Implement API authentication

## Additional Resources

- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Lambda Container Images](https://docs.aws.amazon.com/lambda/latest/dg/images-create.html)
- [GitHub OIDC with AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
