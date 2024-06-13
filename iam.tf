locals {
  role_split                         = split("/", aws_lambda_function.this.role)
  role_name                          = local.role_split[length(local.role_split) - 1]
  create_secrets_manager_read_policy = var.datadog_grant_read_secret_permissions && lookup(var.environment_variables, "DD_API_KEY_SECRET_ARN", null) != null ? 1 : 0
}

data "aws_iam_policy_document" "secrets_manager_read_policy_document" {
  count = local.create_secrets_manager_read_policy
  statement {
    sid       = "ReadSecret"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.environment_variables["DD_API_KEY_SECRET_ARN"]]
  }
}

resource "random_uuid" "aws_iam_policy_uuid" {}

resource "aws_iam_policy" "secrets_manager_read_policy" {
  count       = local.create_secrets_manager_read_policy
  name        = "lambda-datadog-terraform-secrets-manager-read-policy-${random_uuid.aws_iam_policy_uuid.result}"
  description = "Allow read permissions to Datadog API Key in Secrets Manager"
  policy      = data.aws_iam_policy_document.secrets_manager_read_policy_document[0].json
}

resource "aws_iam_role_policy_attachment" "attach_secrets_manager_read_policy" {
  count      = local.create_secrets_manager_read_policy
  role       = local.role_name
  policy_arn = aws_iam_policy.secrets_manager_read_policy[0].arn
}
