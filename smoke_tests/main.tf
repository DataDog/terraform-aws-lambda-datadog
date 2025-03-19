resource "aws_iam_role" "lambda_role" {
  name = "terraform-smoketest-${var.datadog_service_name}-role"
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "",
          "Effect" : "Allow",
          "Action" : "sts:AssumeRole",
          "Principal" : {
            "Service" : "lambda.amazonaws.com"
          }
        }
      ]
  })
}

resource "aws_iam_policy" "secrets_manager_read_policy" {
  name        = "terraform-smoketest-${var.datadog_service_name}-secrets-manager-policy"
  description = "Policy to allow read access to Secrets Manager"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadSecret"
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = var.datadog_secret_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "attach_secrets_manager_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.secrets_manager_read_policy.arn
}

data "archive_file" "zip_python_code" {
  type        = "zip"
  source_dir  = "${path.module}/src_python/"
  output_path = "${path.module}/build/hello-python.zip"
}

data "archive_file" "zip_node_code" {
  type        = "zip"
  source_dir  = "${path.module}/src_node/"
  output_path = "${path.module}/build/hello-node.zip"
}

module "lambda-python-3-13" {
  source = "../"

  filename      = "${path.module}/build/hello-python.zip"
  function_name = "terraform-smoketest-python-3-13-${var.datadog_service_name}-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "app.lambda_handler"
  runtime       = "python3.13"
  architectures = ["arm64"]
  memory_size   = 256

  environment_variables = {
    "DD_API_KEY_SECRET_ARN" : var.datadog_secret_arn
    "DD_ENV" : "dev"
    "DD_SERVICE" : var.datadog_service_name
    "DD_SITE" : var.datadog_site
    "DD_VERSION" : "1.0.0"
  }
}

module "lambda-python-3-12" {
  source = "../"

  filename      = "${path.module}/build/hello-python.zip"
  function_name = "terraform-smoketest-python-3-12-${var.datadog_service_name}-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "app.lambda_handler"
  runtime       = "python3.12"
  architectures = ["arm64"]
  memory_size   = 256

  environment_variables = {
    "DD_API_KEY_SECRET_ARN" : var.datadog_secret_arn
    "DD_ENV" : "dev"
    "DD_SERVICE" : var.datadog_service_name
    "DD_SITE" : var.datadog_site
    "DD_VERSION" : "1.0.0"
  }
}

module "lambda-python-3-11" {
  source = "../"

  filename      = "${path.module}/build/hello-python.zip"
  function_name = "terraform-smoketest-python-3-11-${var.datadog_service_name}-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "app.lambda_handler"
  runtime       = "python3.11"
  architectures = ["arm64"]
  memory_size   = 256

  environment_variables = {
    "DD_API_KEY_SECRET_ARN" : var.datadog_secret_arn
    "DD_ENV" : "dev"
    "DD_SERVICE" : var.datadog_service_name
    "DD_SITE" : var.datadog_site
    "DD_VERSION" : "1.0.0"
  }
}

module "lambda-python-3-10" {
  source = "../"

  filename      = "${path.module}/build/hello-python.zip"
  function_name = "terraform-smoketest-python-3-10-${var.datadog_service_name}-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "app.lambda_handler"
  runtime       = "python3.10"
  architectures = ["arm64"]
  memory_size   = 256

  environment_variables = {
    "DD_API_KEY_SECRET_ARN" : var.datadog_secret_arn
    "DD_ENV" : "dev"
    "DD_SERVICE" : var.datadog_service_name
    "DD_SITE" : var.datadog_site
    "DD_VERSION" : "1.0.0"
  }
}

module "lambda-python-3-9" {
  source = "../"

  filename      = "${path.module}/build/hello-python.zip"
  function_name = "terraform-smoketest-python-3-9-${var.datadog_service_name}-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "app.lambda_handler"
  runtime       = "python3.9"
  architectures = ["arm64"]
  memory_size   = 256

  environment_variables = {
    "DD_API_KEY_SECRET_ARN" : var.datadog_secret_arn
    "DD_ENV" : "dev"
    "DD_SERVICE" : var.datadog_service_name
    "DD_SITE" : var.datadog_site
    "DD_VERSION" : "1.0.0"
  }
}

module "lambda-python-3-8" {
  source = "../"

  filename      = "${path.module}/build/hello-python.zip"
  function_name = "terraform-smoketest-python-3-8-${var.datadog_service_name}-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "app.lambda_handler"
  runtime       = "python3.8"
  architectures = ["arm64"]
  memory_size   = 256

  environment_variables = {
    "DD_API_KEY_SECRET_ARN" : var.datadog_secret_arn
    "DD_ENV" : "dev"
    "DD_SERVICE" : var.datadog_service_name
    "DD_SITE" : var.datadog_site
    "DD_VERSION" : "1.0.0"
  }
}

module "lambda-node-22" {
  source = "../"

  filename      = "${path.module}/build/hello-node.zip"
  function_name = "terraform-smoketest-node-22-${var.datadog_service_name}-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.lambda_handler"
  runtime       = "nodejs22.x"
  memory_size   = 256

  environment_variables = {
    "DD_API_KEY_SECRET_ARN" : var.datadog_secret_arn
    "DD_ENV" : "dev"
    "DD_SERVICE" : var.datadog_service_name
    "DD_SITE" : var.datadog_site
    "DD_VERSION" : "1.0.0"
  }
}

module "lambda-node-20" {
  source = "../"

  filename      = "${path.module}/build/hello-node.zip"
  function_name = "terraform-smoketest-node-20-${var.datadog_service_name}-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.lambda_handler"
  runtime       = "nodejs20.x"
  memory_size   = 256

  environment_variables = {
    "DD_API_KEY_SECRET_ARN" : var.datadog_secret_arn
    "DD_ENV" : "dev"
    "DD_SERVICE" : var.datadog_service_name
    "DD_SITE" : var.datadog_site
    "DD_VERSION" : "1.0.0"
  }
}

module "lambda-node-18" {
  source = "../"

  filename      = "${path.module}/build/hello-node.zip"
  function_name = "terraform-smoketest-node-18-${var.datadog_service_name}-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.lambda_handler"
  runtime       = "nodejs18.x"
  memory_size   = 256

  environment_variables = {
    "DD_API_KEY_SECRET_ARN" : var.datadog_secret_arn
    "DD_ENV" : "dev"
    "DD_SERVICE" : var.datadog_service_name
    "DD_SITE" : var.datadog_site
    "DD_VERSION" : "1.0.0"
  }
}
