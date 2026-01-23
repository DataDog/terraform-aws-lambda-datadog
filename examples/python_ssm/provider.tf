provider "aws" {
  region = "us-east-1" # Change to match your SSM parameter region

  # If using aws-vault or other credential providers, Terraform will automatically pick up
  # AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_SESSION_TOKEN from environment
}
