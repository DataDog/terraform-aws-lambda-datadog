variable "architectures" {
  description = "Architecture for the Lambda function"
  type        = list(string)
  default     = ["x86_64"]
}

variable "datadog_extension_layer_version" {
  description = "Version for the Datadog Extension Layer"
  type        = number
  default     = 56
}

variable "datadog_node_layer_version" {
  description = "Version for the Datadog Node Layer"
  type        = number
  default     = 108
}

variable "datadog_python_layer_version" {
  description = "Version for the Datadog Python Layer"
  type        = number
  default     = 92
}

variable "environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
}

variable "filename" {
  description = "Name of the Lambda function"
  type        = string
}

variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "handler" {
  description = "Entry point for the Lambda function"
  type        = string
}

variable "layers" {
  description = "Layers for the Lambda function"
  type        = list(string)
  default     = []
}

variable "role" {
  description = "ARN of an existing IAM role to attach to the Lambda function"
  type        = string
}

variable "runtime" {
  description = "Runtime environment for the Lambda function"
  type        = string
}

variable "tags" {
  description = "Tags for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "timeout" {
  description = "Timeout for the Lambda function"
  type        = number
  default     = null
}
