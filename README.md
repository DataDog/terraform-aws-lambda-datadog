# Datadog Terraform module for AWS Lambda

[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](https://github.com/DataDog/terraform-aws-lambda-datadog/blob/main/LICENSE)

Use this Terraform module to install Datadog Serverless Monitoring for AWS Lambda.

This Terraform module wraps the [aws_lambda_function](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) resource and automatically configures your Lambda function for Datadog Serverless Monitoring by:

* Adding the Datadog Lambda layers
* Redirecting the Lambda handler
* Enabling the collection of metrics, traces, and logs to Datadog

## Usage

### Python
```
module "example_lambda_function" {
  source = "Datadog/lambda-datadog/aws"

  filename      = "example.zip"
  function_name = "example-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "app.lambda_handler"
  runtime       = "python3.11"

  environment_variables = {
    "DD_API_KEY_SECRET_ARN" : "arn:aws:secretsmanager:us-east-1:000000000000:secret:example-secret"
    "DD_ENV" : "dev"
    "DD_SERVICE" : "example-service"
    "DD_VERSION" : "1.0.0"
  }

  datadog_extension_layer_version = 56
  datadog_python_layer_version = 92
}
```

### Node
```
module "example_lambda_function" {
  source = "Datadog/lambda-datadog/aws"

  filename      = "example.zip"
  function_name = "example-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.lambda_handler"
  runtime       = "nodejs20.x"

  environment_variables = {
    "DD_API_KEY_SECRET_ARN" : "arn:aws:secretsmanager:us-east-1:000000000000:secret:example-secret"
    "DD_ENV" : "dev"
    "DD_SERVICE" : "example-service"
    "DD_VERSION" : "1.0.0"
  }

  datadog_extension_layer_version = 56
  datadog_node_layer_version = 108
}
```

## Configuration

### Lambda Function

All of the arguments available in the [aws_lambda_function](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) resource are available in this Terraform module.

Arguments defined as blocks in the `aws_lambda_function` resource are redefined as variables with their nested arguments.

For example, in `aws_lambda_function`, `environment` is defined as a block with a `variables` argument. In this Terraform module, the value for the `environment_variables` is passed to the `environment.variables` argument in `aws_lambda_function`. See [variables.tf](variables.tf) for a complete list of variables in this module.

#### aws_lambda_function resource
```
resource "aws_lambda_function" "example_lambda_function" {
  function_name = "example-function"  
  ...

  environment {
    variables = {
        "DD_API_KEY_SECRET_ARN" : "arn:aws:secretsmanager:us-east-1:000000000000:secret:example-secret"
        "DD_ENV" : "dev"
        "DD_SERVICE" : "example-service"
        "DD_VERSION" : "1.0.0"
    }
  }
  ...
}
```

#### Datadog Terraform module for AWS Lambda
```
module "example_lambda_function" {
  source = "Datadog/lambda-datadog/aws"

  function_name = "example-function"  
  ...

  environment_variables = {
    "DD_API_KEY_SECRET_ARN" : "arn:aws:secretsmanager:us-east-1:000000000000:secret:example-secret"
    "DD_ENV" : "dev"
    "DD_SERVICE" : "example-service"
    "DD_VERSION" : "1.0.0"
  }
  ...
}
```

### Datadog

#### Selecting the layer versions

Use the following variables to select the versions of the Datadog Lambda layers to use. If no layer version is specified the latest version will be used.

| Variable | Description |
| -------- | ----------- |
| `datadog_extension_layer_version` | Version of the [Datadog Lambda Extension layer](https://github.com/DataDog/datadog-lambda-extension/releases) to install |
| `datadog_node_layer_version` | Version of the [Datadog Node Lambda layer](https://github.com/DataDog/datadog-lambda-js/releases) to install |
| `datadog_python_layer_version` | Version of the [Datadog Python Lambda layer](https://github.com/DataDog/datadog-lambda-python/releases) to install |

#### Configuration

Use Environment variables to configure Datadog Serverless Monitoring. Refer to the documentation below for environment variables available in the Serverless Agent (packaged in the Extension layer) and in the Tracing libraries (packaged in the runtime layers).

* [Serverless Agent Configuration](https://docs.datadoghq.com/serverless/guide/agent_configuration/)
* Tracer Configuration
  - [Node](https://github.com/DataDog/datadog-lambda-js?tab=readme-ov-file#configuration)
  - [Python](https://github.com/DataDog/datadog-lambda-python?tab=readme-ov-file#configuration)
