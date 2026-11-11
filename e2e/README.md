# End-to-end tests

Full-lifecycle e2e suite for the `lambda-datadog` Terraform module, conforming to the
shared serverless instrumentation e2e contract. It provisions a real Lambda workload,
applies the module, triggers the function, and asserts that configuration and telemetry
match the contract -- then tears everything down.

## What it does

A single Go + [Terratest](https://terratest.gruntwork.io/) test
(`TestLambdaInstrumentationLifecycle`) walks the lifecycle, with the module as the
mechanism that plugs into APPLY/REMOVE:

1. **APPLY** -- define the workload through the module (from nothing) and verify **config
   present**: pinned Datadog Node + extension layers, the redirected handler, the required
   `DD_*` env wiring, and identifying tags. The function is uniquely named
   `one-e2e-tf-lambda-<runid>`.
2. **Trigger** -- `lambda invoke`, then poll the Datadog API until **spans and logs**
   carrying the workload identity (`service`, `env`, `version`, run id) appear. Identity is
   asserted on the ingested telemetry, not mere existence.
3. **Re-APPLY** -- assert idempotency via `terraform plan` (no diff).
4. **REMOVE** -- toggle the module off and assert a **clean end-state**: the function no
   longer exists.
5. **Teardown** -- `terraform destroy`, always, even on failure.

The workload runs one canonical runtime (`nodejs22.x`); per-runtime exhaustiveness lives
upstream. The handler is duplicated from `serverless-self-monitoring`
(`lambda-managed-instances/handlers/default/nodejs`); tracing is auto-injected by the
layers and logs are auto-collected by the extension.

### Resource hygiene

Every resource is named `one-e2e-tf-lambda-<runid>` and tagged
`one_e2e_created=<unix-ts>` at creation, so the shared cross-repo sweeper can identify and
reap leaked resources without touching another team's.

## Running locally

Prerequisites:

- **AWS auth** -- credentials for the serverless sandbox account in your environment.
  Prefix the command with `aws-vault`:
  ```
  aws-vault exec sso-serverless-sandbox-account-admin -- go test -v -timeout 40m .
  ```
- **Tooling** -- `terraform` (>= 1.5), `go` (see `go.mod`), the `aws` CLI, and `dd-auth` on
  `PATH`.
- A **Secrets Manager secret** in that account holding a valid Datadog API key for the org
  the suite queries, so the workload ships telemetry where the test looks for it.

Environment variables:

| Variable                     | Required | Description                                                        |
| ---------------------------- | :------: | ------------------------------------------------------------------ |
| `DD_API_KEY_SECRET_ARN`      |   yes    | ARN of the Secrets Manager secret the extension reads.             |
| `DD_API_KEY`                 |   yes    | API key for querying spans/logs (injected by `dd-auth` below).     |
| `DD_APP_KEY`                 |   yes    | App key for querying the Datadog API (injected by `dd-auth` below).|
| `AWS_REGION`                 |    no    | Defaults to `ap-northeast-3`.                                      |
| `DD_SITE`                    |    no    | Defaults to `datadoghq.com`.                                       |
| `DD_NODE_LAYER_VERSION`      |    no    | Pin the asserted Node layer version (defaults to the module's).    |
| `DD_EXTENSION_LAYER_VERSION` |    no    | Pin the asserted extension layer version (defaults to the module's).|
| `E2E_RUN_ID`                 |    no    | Run ID for resource names and telemetry. Defaults to a random ID.  |

The suite needs Datadog API + App keys to query spans and logs. Use `dd-auth` to mint
short-lived keys for the org instead of pasting long-lived ones; it injects `$DD_API_KEY`
and `$DD_APP_KEY` into the wrapped command only:

```
cd e2e
dd-auth --domain app.datadoghq.com -- \
  aws-vault exec sso-serverless-sandbox-account-admin -- \
  env DD_API_KEY_SECRET_ARN=arn:aws:secretsmanager:us-east-1:...:secret:dd-api-key \
  go test -v -timeout 40m .
```

## In CI

`.github/workflows/e2e.yml` runs the suite when a pull request or push to `main` changes
the module sources, `e2e/`, or the workflow. It authenticates to AWS via OIDC federation
(`id-token: write`, no long-lived keys), and an auth failure fails the job. Pull requests
from forks skip the job because they can't use the OIDC role.

If the test times out or the run is cancelled, a final step deletes the run's function and
IAM role by name. The serverless-ci sweeper reaps anything else.

Required repo configuration (Settings → Secrets and variables → Actions):

**Variables** (no secrets -- Datadog auth is federated via dd-sts):

| Variable                       | Example                                                       |
| ------------------------------ | ------------------------------------------------------------- |
| `AWS_ROLE_ARN_E2E`             | `arn:aws:iam::<acct>:role/gha-terraform-aws-lambda-datadog-e2e` |
| `AWS_REGION_E2E`               | `ap-northeast-3`                                              |
| `DD_API_KEY_SECRET_ARN_E2E`    | ARN of the Secrets Manager secret the workload reads          |
| `DATADOG_SITE_E2E`             | `datadoghq.com`                                               |
| `DD_NODE_LAYER_VERSION_E2E`    | pinned Node layer version                                     |
| `DD_EXTENSION_LAYER_VERSION_E2E` | pinned extension layer version                              |

**Datadog auth (dd-sts).** The workflow obtains short-lived Datadog API + App keys at
runtime via [`DataDog/dd-sts-action`](https://github.com/DataDog/dd-sts-action), governed
by the policy `terraform-aws-lambda-datadog-e2e` in
[`dd-source`](https://github.com/DataDog/dd-source/tree/main/domains/seceng/sit/apps/apis/dd-sts/config/policies/us1.ddbuild.io)
(org 2, scoped to `apm_read` + `logs_read_data`). The same issued API key is written into
the Secrets Manager secret so the workload ships to the org the suite queries. No static
Datadog keys live in this repo.

The AWS OIDC role must trust GitHub's OIDC provider for this repo and allow managing
Lambda functions + per-run IAM roles and writing the workload secret -- scoped to
`one-e2e-tf-lambda-*` resources (full policy in
`serverless-ci/e2e/terraform/aws/policies/terraform-aws-lambda-datadog-e2e-deploy.json`).
