# AWS Lambda Deployment Setup Guide

This guide walks you through setting up GitHub Actions to deploy your containerized application to AWS Lambda.

## Prerequisites

1. **AWS Account** with permissions to:
   - Create/manage Lambda functions
   - Create/manage ECR repositories
   - Create/manage IAM roles

2. **GitHub Repository** with this code

## Setup Steps

### 1. Create ECR Repository

```bash
aws ecr create-repository \
    --repository-name langchain-sql-lambda \
    --region us-east-1
```

### 2. Create Lambda Execution Role

Create an IAM role with the following trust policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

Attach these policies:
- `AWSLambdaBasicExecutionRole` (for CloudWatch logs)

```bash
# Create the role
aws iam create-role \
    --role-name langchain-sql-lambda-role \
    --assume-role-policy-document file://trust-policy.json

# Attach basic execution policy
aws iam attach-role-policy \
    --role-name langchain-sql-lambda-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

### 3. Create Lambda Function

```bash
# Get your AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create Lambda function with container image
aws lambda create-function \
    --function-name langchain-sql-query \
    --package-type Image \
    --code ImageUri=$ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/langchain-sql-lambda:latest \
    --role arn:aws:iam::$ACCOUNT_ID:iam:role/langchain-sql-lambda-role \
    --timeout 60 \
    --memory-size 512 \
    --region us-east-1
```

### 4. Create GitHub OIDC Provider (Recommended)

This allows GitHub Actions to assume an AWS role without storing credentials.

```bash
# Create OIDC provider
aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### 5. Create GitHub Actions IAM Role

Create a role that GitHub Actions can assume:

**Trust Policy** (`github-trust-policy.json`):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/YOUR_REPO_NAME:*"
        }
      }
    }
  ]
}
```

**Permissions Policy** (`github-permissions-policy.json`):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "lambda:UpdateFunctionCode",
        "lambda:UpdateFunctionConfiguration",
        "lambda:GetFunction"
      ],
      "Resource": "arn:aws:lambda:us-east-1:YOUR_ACCOUNT_ID:function:langchain-sql-query"
    }
  ]
}
```

Create the role:
```bash
aws iam create-role \
    --role-name github-actions-lambda-deploy \
    --assume-role-policy-document file://github-trust-policy.json

aws iam put-role-policy \
    --role-name github-actions-lambda-deploy \
    --policy-name LambdaDeploymentPolicy \
    --policy-document file://github-permissions-policy.json
```

### 6. Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these secrets:
- `AWS_ROLE_ARN`: ARN of the github-actions-lambda-deploy role
  - Format: `arn:aws:iam::YOUR_ACCOUNT_ID:role/github-actions-lambda-deploy`
- `OPENAI_API_KEY`: Your OpenAI API key

### 7. (Optional) Create API Gateway

To expose your Lambda function via HTTP:

```bash
# Create REST API
aws apigateway create-rest-api \
    --name langchain-sql-api \
    --region us-east-1

# Get the API ID and root resource ID
API_ID="your-api-id"
RESOURCE_ID="your-root-resource-id"

# Create resource
aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $RESOURCE_ID \
    --path-part query-sql

# Create POST method
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $NEW_RESOURCE_ID \
    --http-method POST \
    --authorization-type NONE

# Integrate with Lambda
aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $NEW_RESOURCE_ID \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:$ACCOUNT_ID:function:langchain-sql-query/invocations

# Deploy API
aws apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name prod
```

Your API endpoint will be:
```
https://$API_ID.execute-api.us-east-1.amazonaws.com/prod/query-sql
```

## Testing the Deployment

### Test Lambda directly:
```bash
aws lambda invoke \
    --function-name langchain-sql-query \
    --payload '{"query": "How many customers are there?"}' \
    --region us-east-1 \
    response.json

cat response.json
```

### Test via API Gateway:
```bash
curl -X POST https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/prod/query-sql \
    -H "Content-Type: application/json" \
    -d '{"query": "How many customers are there?"}'
```

## Workflow Triggers

The workflow runs on:
- Push to `main` branch
- Manual trigger via GitHub Actions UI

## Customization

Edit `.github/workflows/deploy-lambda.yml` to customize:
- `AWS_REGION`: Change deployment region
- `ECR_REPOSITORY`: Change ECR repository name
- `LAMBDA_FUNCTION_NAME`: Change Lambda function name
- Branch triggers
- Memory/timeout settings

## Troubleshooting

### Permission Errors
- Verify IAM role trust policies
- Check GitHub OIDC provider configuration
- Ensure role has necessary permissions

### Lambda Timeouts
- Increase timeout in workflow (default: 60 seconds)
- Increase memory allocation

### Image Size Issues
- Lambda container images have a 10 GB limit
- Optimize Dockerfile to reduce image size

## Cost Considerations

- **Lambda**: Pay per request and compute time
- **ECR**: Pay for storage (~$0.10/GB/month)
- **API Gateway**: Pay per million requests (~$3.50)

Free tier:
- Lambda: 1M requests + 400,000 GB-seconds/month
- ECR: 500 MB storage/month for 12 months
