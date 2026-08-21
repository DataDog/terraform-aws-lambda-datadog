terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
  }
}

provider "aws" {
  access_key                  = "mock_access_key"
  secret_key                  = "mock_secret"
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true
}

module "python_arm" {
  source = "../.."

  architectures                   = ["arm64"]
  datadog_extension_layer_version = 201
  datadog_python_layer_version    = 202
  filename                        = "function.zip"
  function_name                   = "python-arm"
  handler                         = "app.handler"
  role                            = "arn:aws:iam::123456789012:role/lambda"
  runtime                         = "python3.14"
}

check "python_arm_layer_synthesis" {
  assert {
    condition = toset(module.python_arm.layers) == toset([
      "arn:aws:lambda:us-east-1:464622532012:layer:Datadog-Python314-ARM:202",
      "arn:aws:lambda:us-east-1:464622532012:layer:Datadog-Extension-ARM:201",
    ]) && module.python_arm.handler == "datadog_lambda.handler.handler" && module.python_arm.environment[0].variables.DD_LAMBDA_HANDLER == "app.handler"
    error_message = "Python ARM layer synthesis or version overrides changed"
  }
}
