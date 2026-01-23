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
  --name "/datadog/api-key" \
  --value "YOUR_DATADOG_API_KEY" \
  --type "SecureString" \
  --region us-east-1
```

### 2. Configure Variables

Create a `terraform.tfvars` file:

```hcl
datadog_parameter_arn  = "arn:aws:ssm:us-east-1:000000000:parameter/datadog/api-key"
datadog_service_name   = "my-nodejs-lambda"
datadog_site           = "datadoghq.com"
```

### 3. Deploy

Using aws-vault:
```bash
aws-vault exec YOUR_PROFILE -- terraform init
aws-vault exec YOUR_PROFILE -- terraform plan
aws-vault exec YOUR_PROFILE -- terraform apply
```

Or if credentials are already configured:
```bash
terraform init
terraform plan
terraform apply
```

## Testing

Invoke the Lambda function:

```bash
aws lambda invoke \
  --function-name $(terraform output -raw function_name) \
  --region us-east-1 \
  output.json

cat output.json
```

## Cleanup

```bash
terraform destroy
```

## Key Differences from Secrets Manager Example

- Uses `DD_API_KEY_SSM_ARN` instead of `DD_API_KEY_SECRET_ARN`
- IAM policy grants `ssm:GetParameter` permission instead of `secretsmanager:GetSecretValue`
- Parameter ARN format: `arn:aws:ssm:REGION:ACCOUNT:parameter/path/to/parameter`

## Documentation

- [Datadog Node.js Lambda Instrumentation](https://docs.datadoghq.com/serverless/aws_lambda/instrumentation/nodejs/)
- [AWS Systems Manager Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
