output "architectures" {
  description = "Instruction set architecture for your Lambda function."
  value       = aws_lambda_function.this.architectures
}

output "arn" {
  description = "Amazon Resource Name (ARN) identifying your Lambda Function."
  value       = aws_lambda_function.this.arn
}

output "code_signing_config_arn" {
  description = "To enable code signing for this function, specify the ARN of a code-signing configuration."
  value       = aws_lambda_function.this.code_signing_config_arn
}

output "dead_letter_config" {
  description = "ARN of an SNS topic or SQS queue to notify when an invocation fails."
  value       = aws_lambda_function.this.dead_letter_config
}

output "description" {
  description = "Description of what your Lambda Function does."
  value       = aws_lambda_function.this.description
}

output "environment" {
  description = "Map of environment variables that are accessible from the function code during execution."
  value       = aws_lambda_function.this.environment
}

output "ephemeral_storage" {
  description = "The amount of Ephemeral storage(/tmp) to allocate for the Lambda Function in MB."
  value       = aws_lambda_function.this.ephemeral_storage
}

output "file_system_config" {
  description = "Connection settings for an EFS file system."
  value       = aws_lambda_function.this.file_system_config
}

output "filename" {
  description = "Path to the function's deployment package within the local filesystem."
  value       = aws_lambda_function.this.filename
}

output "function_name" {
  description = "Unique name for your Lambda Function"
  value       = aws_lambda_function.this.function_name
}

output "handler" {
  description = "Function entrypoint in your code."
  value       = aws_lambda_function.this.handler
}

output "image_config" {
  description = "Container image configuration values that override the values in the container image Dockerfile."
  value       = aws_lambda_function.this.image_config
}

output "image_uri" {
  description = "ECR image URI containing the function's deployment package."
  value       = aws_lambda_function.this.image_uri
}

output "invoke_arn" {
  description = "ARN to be used for invoking Lambda Function from API Gateway."
  value       = aws_lambda_function.this.invoke_arn
}

output "kms_key_arn" {
  description = "Amazon Resource Name (ARN) of the AWS Key Management Service (KMS) key that is used to encrypt environment variables."
  value       = aws_lambda_function.this.kms_key_arn
}

output "last_modified" {
  description = "Date this resource was last modified."
  value       = aws_lambda_function.this.last_modified
}

output "layers" {
  description = "List of Lambda Layer Version ARNs (maximum of 5) to attach to your Lambda Function."
  value       = aws_lambda_function.this.layers
}

output "logging_config" {
  description = "Advanced logging settings."
  value       = aws_lambda_function.this.logging_config
}

output "memory_size" {
  description = "Amount of memory in MB your Lambda Function can use at runtime."
  value       = aws_lambda_function.this.memory_size
}

output "package_type" {
  description = "Lambda deployment package type."
  value       = aws_lambda_function.this.package_type
}

output "publish" {
  description = "Whether to publish creation/change as new Lambda Function Version."
  value       = aws_lambda_function.this.publish
}

output "qualified_arn" {
  description = "ARN identifying your Lambda Function Version."
  value       = aws_lambda_function.this.qualified_arn
}

output "qualified_invoke_arn" {
  description = "Qualified ARN (ARN with lambda version number) to be used for invoking Lambda Function from API Gateway."
  value       = aws_lambda_function.this.qualified_invoke_arn
}

output "reserved_concurrent_executions" {
  description = "Amount of reserved concurrent executions for this lambda function."
  value       = aws_lambda_function.this.reserved_concurrent_executions
}

output "runtime" {
  description = "Identifier of the function's runtime."
  value       = aws_lambda_function.this.runtime
}

output "s3_bucket" {
  description = "S3 bucket location containing the function's deployment package."
  value       = aws_lambda_function.this.s3_bucket
}

output "s3_key" {
  description = "S3 key of an object containing the function's deployment package."
  value       = aws_lambda_function.this.s3_key
}

output "s3_object_version" {
  description = "Object version containing the function's deployment package."
  value       = aws_lambda_function.this.s3_object_version
}

output "signing_job_arn" {
  description = "ARN of the signing job."
  value       = aws_lambda_function.this.signing_job_arn
}

output "signing_profile_version_arn" {
  description = "ARN of the signing profile version."
  value       = aws_lambda_function.this.signing_profile_version_arn
}

output "skip_destroy" {
  description = "Set to true if you do not wish the function to be deleted at destroy time, and instead just remove the function from the Terraform state."
  value       = aws_lambda_function.this.skip_destroy
}

output "snap_start" {
  description = "Snap start settings for low-latency startups."
  value       = aws_lambda_function.this.snap_start
}

output "source_code_hash" {
  description = "Used to trigger updates. Must be set to a base64-encoded SHA256 hash of the package file specified with either filename or s3_key."
  value       = aws_lambda_function.this.source_code_hash
}

output "source_code_size" {
  description = "Size in bytes of the function .zip file."
  value       = aws_lambda_function.this.source_code_size
}

output "tags" {
  description = "Map of tags to assign to the object."
  value       = aws_lambda_function.this.tags
}

output "tags_all" {
  description = "A map of tags assigned to the resource, including those inherited from the provider."
  value       = aws_lambda_function.this.tags_all
}

output "timeout" {
  description = "Amount of time your Lambda Function has to run in seconds."
  value       = aws_lambda_function.this.timeout
}

output "tracing_config" {
  description = "Tracing settings."
  value       = aws_lambda_function.this.tracing_config
}

output "version" {
  description = "Latest published version of your Lambda Function."
  value       = aws_lambda_function.this.version
}

output "vpc_config" {
  description = "VPC settings."
  value       = aws_lambda_function.this.vpc_config
}
