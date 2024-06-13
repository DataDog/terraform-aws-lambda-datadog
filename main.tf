data "aws_region" "current" {}
data "aws_partition" "current" {}

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
  datadog_extension_layer_arn    = "${local.datadog_layer_name_base}:Datadog-Extension${local.datadog_extension_layer_suffix}:${var.datadog_extension_layer_version}"
  datadog_extension_layer_suffix = local.datadog_layer_suffix

  datadog_lambda_layer_arn     = "${local.datadog_layer_name_base}:${local.datadog_lambda_layer_runtime}${local.datadog_lambda_layer_suffix}:${local.datadog_lambda_layer_version}"
  datadog_lambda_layer_suffix  = local.runtime_base == "nodejs" ? "" : local.datadog_layer_suffix # nodejs doesn't have a separate layer for ARM
  datadog_lambda_layer_runtime = lookup(local.runtime_layer_map, var.runtime, "")
  datadog_lambda_layer_version = lookup(local.runtime_base_layer_version_map, local.runtime_base, "")

  datadog_account_id      = (data.aws_partition.current.partition == "aws-us-gov") ? "002406178527" : "464622532012"
  datadog_layer_name_base = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${local.datadog_account_id}:layer"
  datadog_layer_suffix    = lookup(local.architecture_layer_suffix_map, var.architectures[0])

  environment_variables = {
    common = {
      DD_CAPTURE_LAMBDA_PAYLOAD  = "false"
      DD_LOGS_INJECTION          = "false"
      DD_MERGE_XRAY_TRACES       = "false"
      DD_SERVERLESS_LOGS_ENABLED = "true"
      DD_SERVICE                 = var.function_name
      DD_SITE                    = "datadoghq.com"
      DD_TRACE_ENABLED           = "true"
    }
    runtime = lookup(local.runtime_base_environment_variable_map, local.runtime_base, {})
  }

  handler = lookup(local.runtime_base_handler_map, local.runtime_base, var.handler)

  layers = {
    extension = [local.datadog_extension_layer_arn]
    lambda    = local.datadog_lambda_layer_runtime == "" ? [] : [local.datadog_lambda_layer_arn]
  }

  tags = {
    dd_sls_terraform_module = "1.1.0"
  }
}

check "runtime_support" {
  assert {
    condition = contains(
      [
        "nodejs16.x",
        "nodejs18.x",
        "nodejs20.x",
        "python3.8",
        "python3.9",
        "python3.10",
        "python3.11",
        "python3.12",
      ],
    var.runtime)
    error_message = "${var.runtime} Lambda runtime is not supported by the lambda-datadog Terraform module"
  }
}

check "container_image_support" {
  assert {
    condition     = var.package_type != "Image"
    error_message = "Container images are not supported by the lambda-datadog Terraform module"
  }
}

resource "aws_lambda_function" "this" {
  architectures           = var.architectures
  code_signing_config_arn = var.code_signing_config_arn

  dynamic "dead_letter_config" {
    for_each = var.dead_letter_config_target_arn != null ? [true] : []
    content {
      target_arn = var.dead_letter_config_target_arn
    }
  }

  description = var.description

  # User defined environment variables take precedence over datadog defined environment variables
  # This allows users the option to override default behavior
  environment {
    variables = merge(
      local.environment_variables.common,
      local.environment_variables.runtime,
      var.environment_variables
    )
  }

  dynamic "ephemeral_storage" {
    for_each = var.ephemeral_storage_size != null ? [true] : []

    content {
      size = var.ephemeral_storage_size
    }
  }

  dynamic "file_system_config" {
    for_each = var.file_system_config_arn != null && var.file_system_config_local_mount_path != null ? [true] : []

    content {
      arn              = var.file_system_config_arn
      local_mount_path = var.file_system_config_local_mount_path
    }
  }

  filename      = var.filename
  function_name = var.function_name
  handler       = local.handler
  kms_key_arn   = var.kms_key_arn

  # Datadog layers are defined in single element lists
  # This allows for runtimes where a lambda layer is not needed by concatenating an empty list
  layers = concat(
    local.layers.extension,
    local.layers.lambda,
    var.layers
  )

  dynamic "logging_config" {
    for_each = var.logging_config_log_format != null ? [true] : []

    content {
      application_log_level = var.logging_config_log_format == "Text" ? null : var.logging_config_application_log_level
      log_group             = var.logging_config_log_group
      log_format            = var.logging_config_log_format
      system_log_level      = var.logging_config_log_format == "Text" ? null : var.logging_config_system_log_level
    }
  }

  memory_size                    = var.memory_size
  package_type                   = var.package_type
  publish                        = var.publish
  reserved_concurrent_executions = var.reserved_concurrent_executions
  role                           = var.role
  runtime                        = var.runtime
  s3_bucket                      = var.s3_bucket
  s3_key                         = var.s3_key
  s3_object_version              = var.s3_object_version
  skip_destroy                   = var.skip_destroy
  source_code_hash               = var.source_code_hash

  dynamic "snap_start" {
    for_each = var.snap_start_apply_on != null ? [true] : []

    content {
      apply_on = var.snap_start_apply_on
    }
  }

  # Datadog defined tags take precedence over user defined tags
  # This is to ensure that the dd_sls_terraform_module tag is set correctly
  tags = merge(
    var.tags,
    local.tags
  )

  timeout = var.timeout

  dynamic "tracing_config" {
    for_each = var.tracing_config_mode != null ? [true] : []

    content {
      mode = var.tracing_config_mode
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config_security_group_ids != null && var.vpc_config_subnet_ids != null ? [true] : []

    content {
      ipv6_allowed_for_dual_stack = var.vpc_config_ipv6_allowed_for_dual_stack
      security_group_ids          = var.vpc_config_security_group_ids
      subnet_ids                  = var.vpc_config_subnet_ids
    }
  }
}
