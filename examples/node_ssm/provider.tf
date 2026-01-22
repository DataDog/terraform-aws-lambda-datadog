provider "aws" {
  region = "us-east-2" # Match the region of your SSM parameter

  # If using aws-vault or other credential providers, Terraform will automatically pick up
  # AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_SESSION_TOKEN from environment
}

