# Node.js Lambda Example with SSM Parameter Store

This example demonstrates deploying a Node.js Lambda function with Datadog monitoring using AWS Systems Manager (SSM) Parameter Store to store the Datadog API key.

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.5.0
3. Datadog API Key stored in SSM Parameter Store

## Setup

### 1. Create SSM Parameter

Store your Datadog API key in SSM Parameter Store:

```bash
aws ssm put-parameter \
  --name "/dev/DD_API_KEY" \
  --value "YOUR_DATADOG_API_KEY" \
  --type "SecureString" \
  --region us-east-2
```

### 2. Configure Variables

The `terraform.tfvars` file is already configured:

```hcl
datadog_parameter_arn  = "arn:aws:ssm:us-east-2:425362996713:parameter/dev/DD_API_KEY"
datadog_service_name   = "test-lambda-ssm"
datadog_site           = "datadoghq.com"
```

### 3. Deploy with aws-vault

```bash
# Using the deploy script
aws-vault exec sso-serverless-sandbox-account-admin -- ./deploy.sh

# Or manually
aws-vault exec sso-serverless-sandbox-account-admin -- terraform init
aws-vault exec sso-serverless-sandbox-account-admin -- terraform plan
aws-vault exec sso-serverless-sandbox-account-admin -- terraform apply
```

## Testing

Invoke the Lambda function:

```bash
aws-vault exec sso-serverless-sandbox-account-admin -- aws lambda invoke \
  --function-name $(terraform output -raw function_name) \
  --region us-east-2 \
  output.json

cat output.json
```

## Cleanup

```bash
aws-vault exec sso-serverless-sandbox-account-admin -- terraform destroy
```

## Key Differences from Secrets Manager Example

- Uses `DD_API_KEY_SSM_ARN` instead of `DD_API_KEY_SECRET_ARN`
- IAM policy grants `ssm:GetParameter` permission instead of `secretsmanager:GetSecretValue`
- Parameter ARN format: `arn:aws:ssm:REGION:ACCOUNT:parameter/path/to/parameter`

## Documentation

- [Datadog Node.js Lambda Instrumentation](https://docs.datadoghq.com/serverless/aws_lambda/instrumentation/nodejs/)
- [AWS Systems Manager Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)

