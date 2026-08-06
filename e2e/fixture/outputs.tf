output "function_name" {
  description = "Physical name of the instrumented Lambda (null when removed)."
  value       = one(module.instrumented[*].function_name)
}

output "function_arn" {
  description = "ARN of the instrumented Lambda (null when removed)."
  value       = one(module.instrumented[*].arn)
}
