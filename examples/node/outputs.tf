output "arn" {
  value = module.example_lambda_function.arn
}

output "invoke_arn" {
  value = module.example_lambda_function.invoke_arn
}

output "function_name" {
  value = module.example_lambda_function.function_name
}
