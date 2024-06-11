resource "aws_iam_role" "lambda_role" {
  name = "terraform-example-java-${var.datadog_service_name}-role"
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
  name        = "terraform-example-java-${var.datadog_service_name}-secrets-manager-policy"
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

module "lambda-datadog" {
  source = "../../"

  filename         = "${path.module}/target/hello-world-java-0.1.0-SNAPSHOT.jar"
  source_code_hash = filebase64sha256("${path.module}/target/hello-world-java-0.1.0-SNAPSHOT.jar")
  function_name    = "terraform-example-java-${var.datadog_service_name}-function"
  role             = aws_iam_role.lambda_role.arn
  handler          = "com.serverless.Handler"
  runtime          = "java21"
  memory_size      = 1024

  environment_variables = {
    "DD_API_KEY_SECRET_ARN" : var.datadog_secret_arn
    "DD_ENV" : "dev"
    "DD_SERVICE" : var.datadog_service_name
    "DD_SITE" : var.datadog_site
    "DD_VERSION" : "1.0.0"
  }
}
