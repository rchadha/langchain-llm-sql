# AWS Lambda Container Deployment

This guide provides a quick reference for deploying the LangChain SQL application to AWS Lambda using containers and GitHub Actions.

## Files Created

- **`Dockerfile.lambda`** - Lambda-specific Dockerfile
- **`lambda_handler.py`** - Lambda handler function (replaces Flask server)
- **`.github/workflows/deploy-lambda.yml`** - GitHub Actions deployment workflow
- **`.github/workflows/deploy-lambda-setup.md`** - Detailed setup instructions

## Quick Start

### 1. One-Time AWS Setup

```bash
# Set your AWS account ID
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create ECR repository
aws ecr create-repository \
    --repository-name langchain-sql-lambda \
    --region us-east-1

# Create Lambda execution role
aws iam create-role \
    --role-name langchain-sql-lambda-role \
    --assume-role-policy-document '{
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Allow",
        "Principal": {"Service": "lambda.amazonaws.com"},
        "Action": "sts:AssumeRole"
      }]
    }'

# Attach execution policy
aws iam attach-role-policy \
    --role-name langchain-sql-lambda-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Build and push initial image
docker build -f Dockerfile.lambda -t langchain-sql-lambda .
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
docker tag langchain-sql-lambda:latest $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/langchain-sql-lambda:latest
docker push $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/langchain-sql-lambda:latest

# Create Lambda function
aws lambda create-function \
    --function-name langchain-sql-query \
    --package-type Image \
    --code ImageUri=$ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/langchain-sql-lambda:latest \
    --role arn:aws:iam::$ACCOUNT_ID:role/langchain-sql-lambda-role \
    --timeout 60 \
    --memory-size 512 \
    --environment "Variables={OPENAI_API_KEY=your-key-here}" \
    --region us-east-1
```

### 2. Configure GitHub Actions

1. **Create GitHub OIDC Provider** (secure, no access keys needed):

```bash
aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

2. **Create GitHub Actions Role**:

Replace `YOUR_GITHUB_USERNAME` and `YOUR_REPO_NAME`:

```bash
# Create trust policy file
cat > github-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::$ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
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
  }]
}
EOF

# Create role
aws iam create-role \
    --role-name github-actions-lambda-deploy \
    --assume-role-policy-document file://github-trust-policy.json

# Create permissions policy file
cat > github-permissions-policy.json <<EOF
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
      "Resource": "arn:aws:lambda:us-east-1:$ACCOUNT_ID:function:langchain-sql-query"
    }
  ]
}
EOF

# Attach permissions
aws iam put-role-policy \
    --role-name github-actions-lambda-deploy \
    --policy-name LambdaDeploymentPolicy \
    --policy-document file://github-permissions-policy.json
```

3. **Add GitHub Secrets**:

Go to: Repository → Settings → Secrets and variables → Actions

Add:
- `AWS_ROLE_ARN`: `arn:aws:iam::YOUR_ACCOUNT_ID:role/github-actions-lambda-deploy`
- `OPENAI_API_KEY`: Your OpenAI API key

### 3. Deploy

Push to `main` branch or manually trigger the workflow in GitHub Actions.

## Testing Lambda Function

### Direct invocation:
```bash
aws lambda invoke \
    --function-name langchain-sql-query \
    --payload '{"query": "How many customers are there?"}' \
    --region us-east-1 \
    response.json && cat response.json
```

### With API Gateway:
```bash
curl -X POST https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/prod/query-sql \
    -H "Content-Type: application/json" \
    -d '{"query": "How many customers are there?"}'
```

## Local Testing (Optional)

Test the Lambda container locally:

```bash
# Build Lambda image
docker build -f Dockerfile.lambda -t langchain-sql-lambda .

# Run Lambda Runtime Interface Emulator
docker run -p 9000:8080 \
    -e OPENAI_API_KEY="your-key" \
    langchain-sql-lambda

# Test in another terminal
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" \
    -d '{"query": "How many customers are there?"}'
```

## Architecture

```
GitHub Push → GitHub Actions → Build Docker Image → Push to ECR → Update Lambda
                                                                      ↓
                                                              API Gateway (optional)
                                                                      ↓
                                                                   Users
```

## Key Differences from Regular Docker

| Feature | Regular Docker | Lambda Container |
|---------|----------------|------------------|
| Base Image | `python:3.11-slim` | `public.ecr.aws/lambda/python:3.11` |
| Entry Point | Flask server | Lambda handler |
| Handler | `app.py` with Flask | `lambda_handler.handler` |
| Port | 3002 | N/A (event-driven) |
| Request Format | HTTP | API Gateway event |
| Response Format | HTTP | API Gateway response |

## Cost Estimate

For 100,000 requests/month with avg 5-second duration:

- **Lambda**: ~$0.40/month (in free tier: $0)
- **ECR**: ~$0.10/month for image storage
- **API Gateway**: ~$0.35/month (in free tier: $0)

**Total**: ~$0.85/month (or free within AWS free tier)

## Troubleshooting

### Lambda timeout
- Increase timeout in workflow: change `--timeout 60` to higher value
- Increase memory: change `--memory-size 512` to higher value

### Permission errors
```bash
# Verify role exists
aws iam get-role --role-name github-actions-lambda-deploy

# Check trust policy
aws iam get-role --role-name github-actions-lambda-deploy --query 'Role.AssumeRolePolicyDocument'
```

### Image too large
Lambda limit: 10 GB
- Check image size: `docker images langchain-sql-lambda`
- Optimize Dockerfile to reduce dependencies

## Next Steps

1. Set up API Gateway for HTTP access
2. Add CloudWatch alarms for monitoring
3. Implement API authentication (API keys, Cognito)
4. Add request throttling and rate limiting
5. Set up multiple environments (dev, staging, prod)

See `.github/workflows/deploy-lambda-setup.md` for detailed instructions.
