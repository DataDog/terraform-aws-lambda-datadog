variable "datadog_secret_arn" {
  description = "Secret for Datadog API Key"
  type        = string
}

variable "datadog_service_name" {
  description = "Service used to filter for resources in Datadog"
  type        = string
}

variable "datadog_site" {
  description = "Destination site for your metrics, traces, and logs"
  type        = string
}
