# Smoke Tests

A simple smoke test setup that creates one of each of the various functions
that we support, making sure that our default parameters are sensible.

## Usage

* Create a [Datadog API Key](https://app.datadoghq.com/organization-settings/api-keys)
* Create a secret in [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/latest/userguide/intro.html) and add the Datadog API Key as the secret value in plaintext
* Create a `terraform.tfvars` file
  - Set the `datadog_secret_arn` to the arn of the secret you just created
  - Set the `datadog_service_name` to the name of the service you want to use to filter for the resource in Datadog
  - Set the `datadog_site` to the [Datadog destination site](https://docs.datadoghq.com/getting_started/site/) for your metrics, traces, and logs
* Run the following commands

```
terraform init
terraform plan
terraform apply
```

Confirm that the lambdas were all created as expected.

Run the following commands to clean up the environment:

```
terraform destroy
```
