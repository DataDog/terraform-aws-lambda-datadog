variable "region" {
  description = "AWS region to deploy the workload into."
  type        = string
}

# When true, the workload is defined through the lambda-datadog module (APPLY). When
# false, the module is removed and no function exists (REMOVE) -- the clean end-state.
variable "instrumented" {
  description = "Whether to define the workload through the lambda-datadog module."
  type        = bool
}

# Unique workload identity. Set atomically at creation as the resource name prefix
# (one-e2e-<tool>-<platform>-<runid>) and as the stable DD_SERVICE across phases.
variable "service_name" {
  description = "Unique workload name (one-e2e-tflambda-lambda-<runid>)."
  type        = string
}

# Unix timestamp captured by the test at creation time. AWS does not expose a usable
# native creation time cross-account, so the sweeper relies on this freshness tag.
variable "created_ts" {
  description = "Unix timestamp recorded as the one_e2e_created freshness tag."
  type        = string
}

variable "run_id" {
  description = "Run id correlator, surfaced on ingested telemetry via DD_TAGS."
  type        = string
}

variable "datadog_api_key_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the Datadog API key."
  type        = string
}

variable "datadog_site" {
  description = "Datadog site the extension ships telemetry to."
  type        = string
}

variable "dd_env" {
  description = "DD_ENV applied to the workload and asserted on telemetry."
  type        = string
  default     = "e2e"
}

variable "dd_version" {
  description = "DD_VERSION applied to the workload and asserted on telemetry."
  type        = string
  default     = "1.0.0"
}

variable "runtime" {
  description = "Canonical Node.js runtime for the workload."
  type        = string
  default     = "nodejs22.x"
}

# Pinned so a telemetry failure blames the module wiring, not a layer/extension drift.
variable "datadog_extension_layer_version" {
  description = "Pinned Datadog extension layer version."
  type        = number
}

variable "datadog_node_layer_version" {
  description = "Pinned Datadog Node layer version."
  type        = number
}
