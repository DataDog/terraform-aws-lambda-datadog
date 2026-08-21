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

module "dotnet7" {
  source = "../../.."

  filename      = "function.zip"
  function_name = "dotnet7"
  handler       = "Example::Example.Function::Handler"
  role          = "arn:aws:iam::123456789012:role/lambda"
  runtime       = "dotnet7"
}
