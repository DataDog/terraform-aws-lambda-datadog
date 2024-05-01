output "arn" {
  description = "Amazon Resource Name (ARN) identifying your Lambda Function."
  value = module.example_lambda_function.arn
}

output "invoke_arn" {
  description = "ARN to be used for invoking Lambda Function from API Gateway."
  value = module.example_lambda_function.invoke_arn
}

output "function_name" {
  description = "Unique name for your Lambda Function"
  value = module.example_lambda_function.function_name
}
