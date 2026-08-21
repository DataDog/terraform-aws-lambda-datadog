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

module "dotnet8" {
  source = "../.."

  architectures                   = ["arm64"]
  datadog_dotnet_layer_version    = 202
  datadog_extension_layer_version = 201
  filename                        = "function.zip"
  function_name                   = "dotnet8"
  handler                         = "Example::Example.Function::Handler"
  role                            = "arn:aws:iam::123456789012:role/lambda"
  runtime                         = "dotnet8"
}

check "dotnet8_layer_synthesis" {
  assert {
    condition = toset(module.dotnet8.layers) == toset([
      "arn:aws:lambda:us-east-1:464622532012:layer:dd-trace-dotnet-ARM:202",
      "arn:aws:lambda:us-east-1:464622532012:layer:Datadog-Extension-ARM:201",
    ]) && module.dotnet8.handler == "Example::Example.Function::Handler" && module.dotnet8.environment[0].variables.AWS_LAMBDA_EXEC_WRAPPER == "/opt/datadog_wrapper"
    error_message = "dotnet8 layer synthesis changed"
  }
}
