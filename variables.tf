###########
# Datadog
###########

variable "datadog_extension_layer_version" {
  description = "Version for the Datadog Extension Layer"
  type        = number
  default     = 81
}

variable "datadog_dotnet_layer_version" {
  description = "Version for the Datadog .NET Layer"
  type        = number
  default     = 20
}

variable "datadog_java_layer_version" {
  description = "Version for the Datadog Java Layer"
  type        = number
  default     = 21
}

variable "datadog_node_layer_version" {
  description = "Version for the Datadog Node Layer"
  type        = number
  default     = 125
}

variable "datadog_python_layer_version" {
  description = "Version for the Datadog Python Layer"
  type        = number
  default     = 110
}


###################
# Lambda Function
###################

variable "architectures" {
  description = "Instruction set architecture for your Lambda function. Valid values are [\"x86_64\"] and [\"arm64\"]."
  type        = list(string)
  default     = ["x86_64"]
}

variable "code_signing_config_arn" {
  description = "To enable code signing for this function, specify the ARN of a code-signing configuration. A code-signing configuration includes a set of signing profiles, which define the trusted publishers for this function."
  type        = string
  default     = null
}

variable "dead_letter_config_target_arn" {
  description = "ARN of an SNS topic or SQS queue to notify when an invocation fails."
  type        = string
  default     = null
}

variable "description" {
  description = "Description of what your Lambda Function does."
  type        = string
  default     = null
}

variable "environment_variables" {
  description = "Map of environment variables that are accessible from the function code during execution."
  type        = map(string)
  default     = {}
}

variable "ephemeral_storage_size" {
  description = "The amount of Ephemeral storage(/tmp) to allocate for the Lambda Function in MB."
  type        = number
  default     = null
}

variable "file_system_config_arn" {
  description = "Amazon Resource Name (ARN) of the Amazon EFS Access Point that provides access to the file system."
  type        = string
  default     = null
}

variable "file_system_config_local_mount_path" {
  description = "Path where the function can access the file system, starting with /mnt/."
  type        = string
  default     = null
}

variable "filename" {
  description = "Path to the function's deployment package within the local filesystem."
  type        = string
  default     = null
}

variable "function_name" {
  description = "Unique name for your Lambda Function."
  type        = string
  default     = null
}

variable "handler" {
  description = "Function entrypoint in your code."
  type        = string
  default     = null
}

variable "kms_key_arn" {
  description = "Amazon Resource Name (ARN) of the AWS Key Management Service (KMS) key that is used to encrypt environment variables."
  type        = string
  default     = null
}

variable "layers" {
  description = "List of Lambda Layer Version ARNs (maximum of 5) to attach to your Lambda Function."
  type        = list(string)
  default     = []
}

variable "logging_config_application_log_level" {
  description = "For JSON structured logs, choose the detail level of the logs your application sends to CloudWatch when using supported logging libraries."
  type        = string
  default     = null
}

variable "logging_config_log_format" {
  description = "Select between Text and structured JSON format for your function's logs."
  type        = string
  default     = null
}

variable "logging_config_log_group" {
  description = "The CloudWatch log group your function sends logs to."
  type        = string
  default     = null
}

variable "logging_config_system_log_level" {
  description = "For JSON structured logs, choose the detail level of the Lambda platform event logs sent to CloudWatch, such as ERROR, DEBUG, or INFO."
  type        = string
  default     = null
}

variable "memory_size" {
  description = "Amount of memory in MB your Lambda Function can use at runtime."
  type        = number
  default     = null
}

variable "package_type" {
  description = "Lambda deployment package type."
  type        = string
  default     = null
}

variable "publish" {
  description = "Whether to publish creation/change as new Lambda Function Version."
  type        = bool
  default     = null
}

variable "reserved_concurrent_executions" {
  description = "Amount of reserved concurrent executions for this lambda function."
  type        = number
  default     = null
}

variable "role" {
  description = "Amazon Resource Name (ARN) of the function's execution role. The role provides the function's identity and access to AWS services and resources."
  type        = string
  default     = null
}

variable "runtime" {
  description = "Identifier of the function's runtime."
  type        = string
  default     = null
}

variable "s3_bucket" {
  description = "S3 bucket location containing the function's deployment package."
  type        = string
  default     = null
}

variable "s3_key" {
  description = "S3 key of an object containing the function's deployment package."
  type        = string
  default     = null
}

variable "s3_object_version" {
  description = "Object version containing the function's deployment package."
  type        = string
  default     = null
}

variable "skip_destroy" {
  description = "Set to true if you do not wish the function to be deleted at destroy time, and instead just remove the function from the Terraform state."
  type        = bool
  default     = null
}

variable "snap_start_apply_on" {
  description = "Conditions where snap start is enabled."
  type        = string
  default     = null
}

variable "source_code_hash" {
  description = "Used to trigger updates. Must be set to a base64-encoded SHA256 hash of the package file specified with either filename or s3_key."
  type        = string
  default     = null
}

variable "tags" {
  description = "Map of tags to assign to the object."
  type        = map(string)
  default     = null
}

variable "timeout" {
  description = "Amount of time your Lambda Function has to run in seconds."
  type        = number
  default     = null
}

variable "tracing_config_mode" {
  description = "Whether to sample and trace a subset of incoming requests with AWS X-Ray."
  type        = string
  default     = null
}

variable "vpc_config_ipv6_allowed_for_dual_stack" {
  description = "Allows outbound IPv6 traffic on VPC functions that are connected to dual-stack subnets."
  type        = bool
  default     = null
}

variable "vpc_config_security_group_ids" {
  description = "List of security group IDs associated with the Lambda function."
  type        = set(string)
  default     = null
}

variable "vpc_config_subnet_ids" {
  description = "List of subnet IDs associated with the Lambda function."
  type        = set(string)
  default     = null
}
