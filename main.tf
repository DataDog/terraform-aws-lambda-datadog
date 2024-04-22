data "aws_region" "current" {}

locals {
  architecture_layer_suffix_map = {
    x86_64 = "",
    arm64  = "-ARM"
  }
  runtime_base = regex("[a-z]+", var.runtime)
  runtime_base_environment_variable_map = {
    nodejs = {
      DD_LAMBDA_HANDLER = var.handler
    }
    python = {
      DD_LAMBDA_HANDLER = var.handler
    }
  }
  runtime_base_handler_map = {
    nodejs = "/opt/nodejs/node_modules/datadog-lambda-js/handler.handler"
    python = "datadog_lambda.handler.handler"
  }
  runtime_base_layer_version_map = {
    nodejs = var.datadog_node_layer_version
    python = var.datadog_python_layer_version
  }
  runtime_layer_map = {
    "nodejs16.x" = "Datadog-Node16-x"
    "nodejs18.x" = "Datadog-Node18-x"
    "nodejs20.x" = "Datadog-Node20-x"
    "python3.8"  = "Datadog-Python38"
    "python3.9"  = "Datadog-Python39"
    "python3.10" = "Datadog-Python310"
    "python3.11" = "Datadog-Python311"
    "python3.12" = "Datadog-Python312"
  }
}

locals {
  datadog_lambda_layer_version = lookup(local.runtime_base_layer_version_map, local.runtime_base, null)
  environment_variables = {
    common = {
      DD_TRACE_ENABLED           = "true"
      DD_SERVERLESS_LOGS_ENABLED = "true"
      DD_SITE                    = "datadoghq.com"
    }
    runtime = lookup(local.runtime_base_environment_variable_map, local.runtime_base, {})
  }
  handler = lookup(local.runtime_base_handler_map, local.runtime_base, var.handler)
  layers = {
    extension = ["${local.layer_name_base}:Datadog-Extension${local.layer_suffix}:${var.datadog_extension_layer_version}"]
    lambda    = local.layer_runtime == null ? [] : ["${local.layer_name_base}:${local.layer_runtime}${local.runtime_base == "nodejs" ? "" : local.layer_suffix}:${local.datadog_lambda_layer_version}"]
  }
  layer_name_base = "arn:aws:lambda:${data.aws_region.current.name}:464622532012:layer"
  layer_runtime   = lookup(local.runtime_layer_map, var.runtime, null)
  layer_suffix    = lookup(local.architecture_layer_suffix_map, var.architectures[0])
  tags = {
    dd_terraform_module = "0.0.0"
  }
}

resource "aws_lambda_function" "this" {
  architectures = var.architectures

  # user defined environment variables take precedence over datadog defined environment variables
  # this is to allow users the option to override default behavior
  environment {
    variables = merge(
      local.environment_variables.common,
      local.environment_variables.runtime,
      var.environment_variables
    )
  }

  filename      = var.filename
  function_name = var.function_name
  handler       = local.handler

  # datadog layers are defined in single element lists
  # this allows for runtimes where a lambda layer is not needed by concatenating an empty list
  layers = concat(
    local.layers.extension,
    local.layers.lambda,
    var.layers
  )

  role    = var.role
  runtime = var.runtime
  timeout = var.timeout

  # datadog defined tags take precedence over user defined tags
  # this is to enforce that dd_terraform_module is set correctly
  tags = merge(
    var.tags,
    local.tags
  )
}
