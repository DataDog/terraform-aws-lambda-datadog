resource "aws_iam_role" "lambda_role" {
  name = "terraform-example-python-${var.service_name}-role"
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
  name        = "terraform-example-python-${var.service_name}-secrets-manager-policy"
  description = "Policy to allow read access to Secrets Manager"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadSecret"
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = var.secret_arn
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

data "archive_file" "zip_code" {
  type        = "zip"
  source_dir  = "${path.module}/src/"
  output_path = "${path.module}/build/hello-python.zip"
}

module "example_lambda_function" {
  source = "../../"

  filename      = "${path.module}/build/hello-python.zip"
  function_name = "terraform-example-python-${var.service_name}-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "app.lambda_handler"
  runtime       = "python3.11"
  architectures = ["arm64"]
  environment_variables = {
    "DD_API_KEY_SECRET_ARN" : var.secret_arn
    "DD_ENV" : "dev"
    "DD_LOG_LEVEL" : "DEBUG"
    "DD_SERVICE" : var.service_name
    "DD_VERSION" : "1.0.0"
  }

  depends_on = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role, aws_iam_role_policy_attachment.attach_secrets_manager_policy]
}
