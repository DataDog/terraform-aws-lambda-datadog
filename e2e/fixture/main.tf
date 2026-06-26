locals {
  handler = "index.handler"

  # The instrumented (module) and uninstrumented (bare) variants are genuinely different
  # resources -- removing a wrapper module and replacing it with a plain aws_lambda_function
  # is how a user actually un-instruments. They use distinct physical function names so they
  # never collide during the create/destroy of a toggle, while DD_SERVICE keeps a single
  # stable workload identity for telemetry correlation across phases.
  instrumented_function_name   = var.service_name
  uninstrumented_function_name = "${var.service_name}-base"

  # Freshness + identity tags applied atomically at creation. The cross-repo sweeper
  # lists by the one-e2e- name prefix and uses one_e2e_created to skip in-flight runs.
  common_tags = {
    one_e2e_created = var.created_ts
    one_e2e_run_id  = var.run_id
  }
}

resource "aws_iam_role" "lambda" {
  name = "${var.service_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { Service = "lambda.amazonaws.com" }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "read_secret" {
  name = "read-dd-api-key-secret"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = var.datadog_api_key_secret_arn
      }
    ]
  })
}

data "archive_file" "handler" {
  type        = "zip"
  source_dir  = "${path.module}/src/"
  output_path = "${path.module}/build/handler.zip"
}

# Instrumented: the workload is defined through the module under test.
module "instrumented" {
  count  = var.instrumented ? 1 : 0
  source = "../../"

  filename         = data.archive_file.handler.output_path
  source_code_hash = data.archive_file.handler.output_base64sha256
  function_name    = local.instrumented_function_name
  role             = aws_iam_role.lambda.arn
  handler          = local.handler
  runtime          = var.runtime
  memory_size      = 256

  datadog_extension_layer_version = var.datadog_extension_layer_version
  datadog_node_layer_version      = var.datadog_node_layer_version

  environment_variables = {
    DD_API_KEY_SECRET_ARN = var.datadog_api_key_secret_arn
    DD_ENV                = var.dd_env
    DD_SERVICE            = var.service_name
    DD_SITE               = var.datadog_site
    DD_VERSION            = var.dd_version
    DD_TAGS               = "one_e2e_run_id:${var.run_id}"
    ONE_E2E_RUN_ID        = var.run_id
  }

  tags = local.common_tags
}

# Uninstrumented: the same workload defined as a bare function, with no Datadog wiring.
# This is the provisioning baseline and the post-REMOVE clean end-state.
resource "aws_lambda_function" "uninstrumented" {
  count = var.instrumented ? 0 : 1

  filename         = data.archive_file.handler.output_path
  source_code_hash = data.archive_file.handler.output_base64sha256
  function_name    = local.uninstrumented_function_name
  role             = aws_iam_role.lambda.arn
  handler          = local.handler
  runtime          = var.runtime
  memory_size      = 256

  environment {
    variables = {
      ONE_E2E_RUN_ID = var.run_id
    }
  }

  tags = local.common_tags
}
