variable "secret_arn" {
  description = "Secret for Datadog API Key"
  type        = string
}

variable "service_name" {
  description = "Service used to filter for resources in Datadog"
  type        = string
}
