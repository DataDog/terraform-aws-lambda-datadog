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
module "lambda-datadog" {
  source  = "DataDog/lambda-datadog/aws"
  version = "3.2.0"

  filename      = "example.zip"
  function_name = "example-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "app.lambda_handler"
  runtime       = "python3.13"
  memory_size   = 256

  environment_variables = {
    "DD_API_KEY_SECRET_ARN" : "arn:aws:secretsmanager:us-east-1:000000000000:secret:example-secret"
    "DD_ENV" : "dev"
    "DD_SERVICE" : "example-service"
    "DD_SITE": "datadoghq.com"
    "DD_VERSION" : "1.0.0"
  }

  datadog_extension_layer_version = 74
  datadog_python_layer_version = 106
}
```

### Node
```
module "lambda-datadog" {
  source  = "DataDog/lambda-datadog/aws"
  version = "3.2.0"

  filename      = "example.zip"
  function_name = "example-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.lambda_handler"
  runtime       = "nodejs22.x"
  memory_size   = 256

  environment_variables = {
    "DD_API_KEY_SECRET_ARN" : "arn:aws:secretsmanager:us-east-1:000000000000:secret:example-secret"
    "DD_ENV" : "dev"
    "DD_SERVICE" : "example-service"
    "DD_SITE": "datadoghq.com"
    "DD_VERSION" : "1.0.0"
  }

  datadog_extension_layer_version = 74
  datadog_node_layer_version = 123
}
```

### .NET
```
module "lambda-datadog" {
  source  = "DataDog/lambda-datadog/aws"
  version = "3.2.0"

  filename      = "example.zip"
  function_name = "example-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "Example::Example.Function::Handler"
  runtime       = "dotnet8"
  memory_size   = 256

  environment_variables = {
    "DD_API_KEY_SECRET_ARN" : "arn:aws:secretsmanager:us-east-1:000000000000:secret:example-secret"
    "DD_ENV" : "dev"
    "DD_SERVICE" : "example-service"
    "DD_SITE": "datadoghq.com"
    "DD_VERSION" : "1.0.0"
  }

  datadog_extension_layer_version = 74
  datadog_dotnet_layer_version = 19
}
```

### Java
```
module "lambda-datadog" {
  source  = "DataDog/lambda-datadog/aws"
  version = "3.2.0"

  filename      = "example.jar"
  function_name = "example-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "com.example.Handler"
  runtime       = "java21"
  memory_size   = 1024

  environment_variables = {
    "DD_API_KEY_SECRET_ARN" : "arn:aws:secretsmanager:us-east-1:000000000000:secret:example-secret"
    "DD_ENV" : "dev"
    "DD_SERVICE" : "example-service"
    "DD_SITE": "datadoghq.com"
    "DD_VERSION" : "1.0.0"
  }

  datadog_extension_layer_version = 74
  datadog_java_layer_version = 19
}
```

### Go
```
module "lambda-datadog" {
  source  = "DataDog/lambda-datadog/aws"
  version = "3.2.0"

  filename      = "example.zip"
  function_name = "example-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"
  memory_size   = 256

  environment_variables = {
    "DD_API_KEY_SECRET_ARN" : "arn:aws:secretsmanager:us-east-1:000000000000:secret:example-secret"
    "DD_ENV" : "dev"
    "DD_SERVICE" : "example-service"
    "DD_SITE": "datadoghq.com"
    "DD_VERSION" : "1.0.0"
  }

  datadog_extension_layer_version = 74
}
```


## Configuration

### Lambda Function

- Arguments available in the [aws_lambda_function](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) resource are available in this Terraform module. Lambda functions created from container images are not supported by this module.
- To prevent Terraform from re-creating the resource, add a `moved` block as shown below:

```tf
   moved {
    from = aws_lambda_function.{your_lambda_function}
    to   = module.{your_lambda_function}.aws_lambda_function.this
   }
```

- Arguments defined as blocks in the `aws_lambda_function` resource are redefined as variables with their nested arguments.
  * For example, in `aws_lambda_function`, `environment` is defined as a block with a `variables` argument. In this Terraform module, the value for the `environment_variables` is passed to the `environment.variables` argument in `aws_lambda_function`. See [variables.tf](variables.tf) for a complete list of variables in this module.

#### aws_lambda_function resource
```
resource "aws_lambda_function" "example_lambda_function" {
  function_name = "example-function"  
  ...

  environment {
    variables = {
        "DD_API_KEY_SECRET_ARN" : "arn:aws:secretsmanager:us-east-1:000000000000:secret:example-secret"
        "DD_ENV" : "dev"
        "DD_SITE": "datadoghq.com"
        "DD_SERVICE" : "example-service"
        "DD_VERSION" : "1.0.0"
    }
  }
  ...
}
```

#### Datadog Terraform module for AWS Lambda
```
module "lambda-datadog" {
  source  = "DataDog/lambda-datadog/aws"
  version = "3.2.0"

  function_name = "example-function"  
  ...

  environment_variables = {
    "DD_API_KEY_SECRET_ARN" : "arn:aws:secretsmanager:us-east-1:000000000000:secret:example-secret"
    "DD_ENV" : "dev"
    "DD_SITE": "datadoghq.com"
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
| `datadog_dotnet_layer_version` | Version of the [Datadog .NET Lambda layer](https://github.com/DataDog/dd-trace-dotnet-aws-lambda-layer/releases) to install |
| `datadog_java_layer_version` | Version of the [Datadog Java Lambda layer](https://github.com/DataDog/datadog-lambda-java/releases) to install |
| `datadog_node_layer_version` | Version of the [Datadog Node Lambda layer](https://github.com/DataDog/datadog-lambda-js/releases) to install |
| `datadog_python_layer_version` | Version of the [Datadog Python Lambda layer](https://github.com/DataDog/datadog-lambda-python/releases) to install |

#### Selecting the Datadog Site

The default Datadog site is `datadoghq.com`. To use a different site set the `DD_SITE` environment variable to the desired destination site. See [Getting Started with Datadog Sites](https://docs.datadoghq.com/getting_started/site/) for the available site values.

#### Configuration

Use Environment variables to configure Datadog Serverless Monitoring. Refer to the documentation below for environment variables available in the Serverless Agent (packaged in the Extension layer) and in the Tracing libraries (packaged in the runtime layers).

* [Serverless Agent Configuration](https://docs.datadoghq.com/serverless/guide/agent_configuration/)
* Tracer Configuration
  - [.NET](https://docs.datadoghq.com/tracing/trace_collection/library_config/dotnet-framework/?tab=environmentvariables)
  - [Java](https://docs.datadoghq.com/tracing/trace_collection/library_config/java/)
  - [Node](https://github.com/DataDog/datadog-lambda-js?tab=readme-ov-file#configuration)
  - [Python](https://github.com/DataDog/datadog-lambda-python?tab=readme-ov-file#configuration)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.77.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.77.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_lambda_function.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type           | Default | Required |
|------|-------------|----------------|---------|:--------:|
| <a name="input_architectures"></a> [architectures](#input\_architectures) | Instruction set architecture for your Lambda function. Valid values are ["x86\_64"] and ["arm64"]. | `list(string)` | <pre>["x86_64"]</pre> | no |
| <a name="input_code_signing_config_arn"></a> [code\_signing\_config\_arn](#input\_code\_signing\_config\_arn) | To enable code signing for this function, specify the ARN of a code-signing configuration. A code-signing configuration includes a set of signing profiles, which define the trusted publishers for this function. | `string`       | `null` | no |
| <a name="input_datadog_extension_layer_version"></a> [datadog\_extension\_layer\_version](#input\_datadog\_extension\_layer\_version) | Version for the Datadog Extension Layer | `number`       | `74` | no |
| <a name="input_datadog_dotnet_layer_version"></a> [datadog\_dotnet\_layer\_version](#input\_datadog\_dotnet\_layer\_version) | Version for the Datadog .NET Layer | `number`       | `19` | no |
| <a name="input_datadog_java_layer_version"></a> [datadog\_java\_layer\_version](#input\_datadog\_java\_layer\_version) | Version for the Datadog Java Layer | `number`       | `19` | no |
| <a name="input_datadog_node_layer_version"></a> [datadog\_node\_layer\_version](#input\_datadog\_node\_layer\_version) | Version for the Datadog Node Layer | `number`       | `123` | no |
| <a name="input_datadog_python_layer_version"></a> [datadog\_python\_layer\_version](#input\_datadog\_python\_layer\_version) | Version for the Datadog Python Layer | `number`       | `106` | no |
| <a name="input_dead_letter_config_target_arn"></a> [dead\_letter\_config\_target\_arn](#input\_dead\_letter\_config\_target\_arn) | ARN of an SNS topic or SQS queue to notify when an invocation fails. | `string`       | `null` | no |
| <a name="input_description"></a> [description](#input\_description) | Description of what your Lambda Function does. | `string`       | `null` | no |
| <a name="input_environment_variables"></a> [environment\_variables](#input\_environment\_variables) | Map of environment variables that are accessible from the function code during execution. | `map(string)`  | `{}` | no |
| <a name="input_ephemeral_storage_size"></a> [ephemeral\_storage\_size](#input\_ephemeral\_storage\_size) | The amount of Ephemeral storage(/tmp) to allocate for the Lambda Function in MB. | `number`       | `null` | no |
| <a name="input_file_system_config_arn"></a> [file\_system\_config\_arn](#input\_file\_system\_config\_arn) | Amazon Resource Name (ARN) of the Amazon EFS Access Point that provides access to the file system. | `string`       | `null` | no |
| <a name="input_file_system_config_local_mount_path"></a> [file\_system\_config\_local\_mount\_path](#input\_file\_system\_config\_local\_mount\_path) | Path where the function can access the file system, starting with /mnt/. | `string`       | `null` | no |
| <a name="input_filename"></a> [filename](#input\_filename) | Path to the function's deployment package within the local filesystem. | `string`       | `null` | no |
| <a name="input_fips"></a> [filename](#input_fips) | Enable FIPS mode. | `bool`         | `null` | no |
| <a name="input_function_name"></a> [function\_name](#input\_function\_name) | Unique name for your Lambda Function. | `string`       | `null` | no |
| <a name="input_handler"></a> [handler](#input\_handler) | Function entrypoint in your code. | `string`       | `null` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | Amazon Resource Name (ARN) of the AWS Key Management Service (KMS) key that is used to encrypt environment variables. | `string`       | `null` | no |
| <a name="input_layers"></a> [layers](#input\_layers) | List of Lambda Layer Version ARNs (maximum of 5) to attach to your Lambda Function. | `list(string)` | `[]` | no |
| <a name="input_logging_config_application_log_level"></a> [logging\_config\_application\_log\_level](#input\_logging\_config\_application\_log\_level) | For JSON structured logs, choose the detail level of the logs your application sends to CloudWatch when using supported logging libraries. | `string`       | `null` | no |
| <a name="input_logging_config_log_format"></a> [logging\_config\_log\_format](#input\_logging\_config\_log\_format) | Select between Text and structured JSON format for your function's logs. | `string`       | `null` | no |
| <a name="input_logging_config_log_group"></a> [logging\_config\_log\_group](#input\_logging\_config\_log\_group) | The CloudWatch log group your function sends logs to. | `string`       | `null` | no |
| <a name="input_logging_config_system_log_level"></a> [logging\_config\_system\_log\_level](#input\_logging\_config\_system\_log\_level) | For JSON structured logs, choose the detail level of the Lambda platform event logs sent to CloudWatch, such as ERROR, DEBUG, or INFO. | `string`       | `null` | no |
| <a name="input_memory_size"></a> [memory\_size](#input\_memory\_size) | Amount of memory in MB your Lambda Function can use at runtime. | `number`       | `null` | no |
| <a name="input_package_type"></a> [package\_type](#input\_package\_type) | Lambda deployment package type. | `string`       | `null` | no |
| <a name="input_publish"></a> [publish](#input\_publish) | Whether to publish creation/change as new Lambda Function Version. | `bool`         | `null` | no |
| <a name="input_reserved_concurrent_executions"></a> [reserved\_concurrent\_executions](#input\_reserved\_concurrent\_executions) | Amount of reserved concurrent executions for this lambda function. | `number`       | `null` | no |
| <a name="input_role"></a> [role](#input\_role) | Amazon Resource Name (ARN) of the function's execution role. The role provides the function's identity and access to AWS services and resources. | `string`       | `null` | no |
| <a name="input_runtime"></a> [runtime](#input\_runtime) | Identifier of the function's runtime. | `string`       | `null` | no |
| <a name="input_s3_bucket"></a> [s3\_bucket](#input\_s3\_bucket) | S3 bucket location containing the function's deployment package. | `string`       | `null` | no |
| <a name="input_s3_key"></a> [s3\_key](#input\_s3\_key) | S3 key of an object containing the function's deployment package. | `string`       | `null` | no |
| <a name="input_s3_object_version"></a> [s3\_object\_version](#input\_s3\_object\_version) | Object version containing the function's deployment package. | `string`       | `null` | no |
| <a name="input_skip_destroy"></a> [skip\_destroy](#input\_skip\_destroy) | Set to true if you do not wish the function to be deleted at destroy time, and instead just remove the function from the Terraform state. | `bool`         | `null` | no |
| <a name="input_snap_start_apply_on"></a> [snap\_start\_apply\_on](#input\_snap\_start\_apply\_on) | Conditions where snap start is enabled. | `string`       | `null` | no |
| <a name="input_source_code_hash"></a> [source\_code\_hash](#input\_source\_code\_hash) | Used to trigger updates. Must be set to a base64-encoded SHA256 hash of the package file specified with either filename or s3\_key. | `string`       | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Map of tags to assign to the object. | `map(string)`  | `null` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Amount of time your Lambda Function has to run in seconds. | `number`       | `null` | no |
| <a name="input_tracing_config_mode"></a> [tracing\_config\_mode](#input\_tracing\_config\_mode) | Whether to sample and trace a subset of incoming requests with AWS X-Ray. | `string`       | `null` | no |
| <a name="input_vpc_config_ipv6_allowed_for_dual_stack"></a> [vpc\_config\_ipv6\_allowed\_for\_dual\_stack](#input\_vpc\_config\_ipv6\_allowed\_for\_dual\_stack) | Allows outbound IPv6 traffic on VPC functions that are connected to dual-stack subnets. | `bool`         | `null` | no |
| <a name="input_vpc_config_security_group_ids"></a> [vpc\_config\_security\_group\_ids](#input\_vpc\_config\_security\_group\_ids) | List of security group IDs associated with the Lambda function. | `set(string)`  | `null` | no |
| <a name="input_vpc_config_subnet_ids"></a> [vpc\_config\_subnet\_ids](#input\_vpc\_config\_subnet\_ids) | List of subnet IDs associated with the Lambda function. | `set(string)`  | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_architectures"></a> [architectures](#output\_architectures) | Instruction set architecture for your Lambda function. |
| <a name="output_arn"></a> [arn](#output\_arn) | Amazon Resource Name (ARN) identifying your Lambda Function. |
| <a name="output_code_signing_config_arn"></a> [code\_signing\_config\_arn](#output\_code\_signing\_config\_arn) | To enable code signing for this function, specify the ARN of a code-signing configuration. |
| <a name="output_dead_letter_config"></a> [dead\_letter\_config](#output\_dead\_letter\_config) | ARN of an SNS topic or SQS queue to notify when an invocation fails. |
| <a name="output_description"></a> [description](#output\_description) | Description of what your Lambda Function does. |
| <a name="output_environment"></a> [environment](#output\_environment) | Map of environment variables that are accessible from the function code during execution. |
| <a name="output_ephemeral_storage"></a> [ephemeral\_storage](#output\_ephemeral\_storage) | The amount of Ephemeral storage(/tmp) to allocate for the Lambda Function in MB. |
| <a name="output_file_system_config"></a> [file\_system\_config](#output\_file\_system\_config) | Connection settings for an EFS file system. |
| <a name="output_filename"></a> [filename](#output\_filename) | Path to the function's deployment package within the local filesystem. |
| <a name="output_function_name"></a> [function\_name](#output\_function\_name) | Unique name for your Lambda Function |
| <a name="output_handler"></a> [handler](#output\_handler) | Function entrypoint in your code. |
| <a name="output_invoke_arn"></a> [invoke\_arn](#output\_invoke\_arn) | ARN to be used for invoking Lambda Function from API Gateway. |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | Amazon Resource Name (ARN) of the AWS Key Management Service (KMS) key that is used to encrypt environment variables. |
| <a name="output_last_modified"></a> [last\_modified](#output\_last\_modified) | Date this resource was last modified. |
| <a name="output_layers"></a> [layers](#output\_layers) | List of Lambda Layer Version ARNs (maximum of 5) to attach to your Lambda Function. |
| <a name="output_logging_config"></a> [logging\_config](#output\_logging\_config) | Advanced logging settings. |
| <a name="output_memory_size"></a> [memory\_size](#output\_memory\_size) | Amount of memory in MB your Lambda Function can use at runtime. |
| <a name="output_package_type"></a> [package\_type](#output\_package\_type) | Lambda deployment package type. |
| <a name="output_publish"></a> [publish](#output\_publish) | Whether to publish creation/change as new Lambda Function Version. |
| <a name="output_qualified_arn"></a> [qualified\_arn](#output\_qualified\_arn) | ARN identifying your Lambda Function Version. |
| <a name="output_qualified_invoke_arn"></a> [qualified\_invoke\_arn](#output\_qualified\_invoke\_arn) | Qualified ARN (ARN with lambda version number) to be used for invoking Lambda Function from API Gateway. |
| <a name="output_reserved_concurrent_executions"></a> [reserved\_concurrent\_executions](#output\_reserved\_concurrent\_executions) | Amount of reserved concurrent executions for this lambda function. |
| <a name="output_runtime"></a> [runtime](#output\_runtime) | Identifier of the function's runtime. |
| <a name="output_s3_bucket"></a> [s3\_bucket](#output\_s3\_bucket) | S3 bucket location containing the function's deployment package. |
| <a name="output_s3_key"></a> [s3\_key](#output\_s3\_key) | S3 key of an object containing the function's deployment package. |
| <a name="output_s3_object_version"></a> [s3\_object\_version](#output\_s3\_object\_version) | Object version containing the function's deployment package. |
| <a name="output_signing_job_arn"></a> [signing\_job\_arn](#output\_signing\_job\_arn) | ARN of the signing job. |
| <a name="output_signing_profile_version_arn"></a> [signing\_profile\_version\_arn](#output\_signing\_profile\_version\_arn) | ARN of the signing profile version. |
| <a name="output_skip_destroy"></a> [skip\_destroy](#output\_skip\_destroy) | Set to true if you do not wish the function to be deleted at destroy time, and instead just remove the function from the Terraform state. |
| <a name="output_snap_start"></a> [snap\_start](#output\_snap\_start) | Snap start settings for low-latency startups. |
| <a name="output_source_code_hash"></a> [source\_code\_hash](#output\_source\_code\_hash) | Used to trigger updates. Must be set to a base64-encoded SHA256 hash of the package file specified with either filename or s3\_key. |
| <a name="output_source_code_size"></a> [source\_code\_size](#output\_source\_code\_size) | Size in bytes of the function .zip file. |
| <a name="output_tags"></a> [tags](#output\_tags) | Map of tags to assign to the object. |
| <a name="output_tags_all"></a> [tags\_all](#output\_tags\_all) | A map of tags assigned to the resource, including those inherited from the provider. |
| <a name="output_timeout"></a> [timeout](#output\_timeout) | Amount of time your Lambda Function has to run in seconds. |
| <a name="output_tracing_config"></a> [tracing\_config](#output\_tracing\_config) | Tracing settings. |
| <a name="output_version"></a> [version](#output\_version) | Latest published version of your Lambda Function. |
| <a name="output_vpc_config"></a> [vpc\_config](#output\_vpc\_config) | VPC settings. |
<!-- END_TF_DOCS -->
