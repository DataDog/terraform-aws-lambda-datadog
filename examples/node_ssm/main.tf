resource "aws_iam_role" "lambda_role" {
  name = "terraform-example-node-ssm-${var.datadog_service_name}-role"
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

resource "aws_iam_policy" "ssm_parameter_read_policy" {
  name        = "terraform-example-node-ssm-${var.datadog_service_name}-ssm-parameter-policy"
  description = "Policy to allow read access to SSM Parameter Store"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadSSMParameter"
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = var.datadog_parameter_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "attach_ssm_parameter_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.ssm_parameter_read_policy.arn
}

data "archive_file" "zip_code" {
  type        = "zip"
  source_dir  = "${path.module}/src/"
  output_path = "${path.module}/build/hello-node.zip"
}

module "lambda-datadog" {
  source = "../../"

  filename      = "${path.module}/build/hello-node.zip"
  function_name = "terraform-example-node-ssm-${var.datadog_service_name}-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.lambda_handler"
  runtime       = "nodejs24.x"
  memory_size   = 256

  environment_variables = {
    "DD_API_KEY_SSM_ARN" : var.datadog_parameter_arn
    "DD_ENV" : "dev"
    "DD_SERVICE" : var.datadog_service_name
    "DD_SITE" : var.datadog_site
    "DD_VERSION" : "1.0.0"
  }
}

