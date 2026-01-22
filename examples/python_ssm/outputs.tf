output "function_name" {
  value       = module.lambda-datadog.function_name
  description = "Lambda function name"
}

output "function_arn" {
  value       = module.lambda-datadog.arn
  description = "Lambda function ARN"
}

output "invoke_arn" {
  value       = module.lambda-datadog.invoke_arn
  description = "Lambda function invoke ARN"
}

