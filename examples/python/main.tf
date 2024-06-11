resource "aws_iam_role" "lambda_role" {
  name = "terraform-example-python-${var.datadog_service_name}-role"
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

resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "zip_code" {
  type        = "zip"
  source_dir  = "${path.module}/src/"
  output_path = "${path.module}/build/hello-python.zip"
}

module "lambda-datadog" {
  source = "../../"

  filename      = "${path.module}/build/hello-python.zip"
  function_name = "terraform-example-python-${var.datadog_service_name}-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "app.lambda_handler"
  runtime       = "python3.11"
  architectures = ["arm64"]
  memory_size   = 256

  environment_variables = {
    "DD_API_KEY_SECRET_ARN" : var.datadog_secret_arn
    "DD_ENV" : "dev"
    "DD_SERVICE" : var.datadog_service_name
    "DD_SITE": var.datadog_site
    "DD_VERSION" : "1.0.0"
  }
}
