output "service_name" {
  description = "Stable workload identity (DD_SERVICE) across phases."
  value       = var.service_name
}

output "function_name" {
  description = "Physical name of the active Lambda variant (instrumented or bare)."
  value       = var.instrumented ? local.instrumented_function_name : local.uninstrumented_function_name
}

output "function_arn" {
  description = "ARN of the active Lambda variant."
  value       = var.instrumented ? module.instrumented[0].arn : aws_lambda_function.uninstrumented[0].arn
}
