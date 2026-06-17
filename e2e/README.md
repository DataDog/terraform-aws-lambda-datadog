# End-to-end tests

Full-lifecycle e2e suite for the `lambda-datadog` Terraform module, conforming to the
shared serverless instrumentation e2e contract. It provisions a real Lambda workload,
applies the module, triggers the function, and asserts that configuration and telemetry
match the contract -- then tears everything down.

## What it does

A single Go + [Terratest](https://terratest.gruntwork.io/) test
(`TestLambdaInstrumentationLifecycle`) walks the lifecycle, with the module as the
mechanism that plugs into APPLY/REMOVE:

1. **Provision** an uninstrumented workload -- a bare `aws_lambda_function` running the
   hello-world handler, uniquely named `one-e2e-tflambda-lambda-<runid>`.
2. **APPLY** -- redefine the same workload through the module and verify **config
   present**: pinned Datadog Node + extension layers, the redirected handler, the required
   `DD_*` env wiring, and identifying tags.
3. **Trigger** -- `lambda invoke`, then poll the Datadog API until **spans and logs**
   carrying the workload identity (`service`, `env`, `version`, run id) appear. Identity is
   asserted on the ingested telemetry, not mere existence.
4. **Re-APPLY** -- assert idempotency via `terraform plan` (no diff).
5. **REMOVE** -- revert to the bare workload and assert a **clean end-state**: no Datadog
   layers, no `DD_*` env vars, no module tag.
6. **Teardown** -- `terraform destroy`, always, even on failure.

The workload runs one canonical runtime (`nodejs22.x`); per-runtime exhaustiveness lives
upstream. The handler is duplicated from `serverless-self-monitoring`
(`lambda-managed-instances/handlers/default/nodejs`); tracing is auto-injected by the
layers and logs are auto-collected by the extension.

### Resource hygiene

Every resource is named `one-e2e-tflambda-lambda-<runid>` and tagged
`one_e2e_created=<unix-ts>` at creation, so the shared cross-repo sweeper can identify and
reap leaked resources without touching another team's.

## Running locally

Prerequisites:

- **AWS auth** -- credentials for the serverless sandbox account in your environment.
  Prefix the command with `aws-vault`:
  ```
  aws-vault exec sso-serverless-sandbox-account-admin -- go test -v -timeout 45m .
  ```
- **Tooling** -- `terraform` (>= 1.5), `go` (see `go.mod`), and the `aws` CLI on `PATH`.
- A **Secrets Manager secret** in that account holding a valid Datadog API key, plus a
  Datadog **app key** for the same org so the suite can query the API.

Environment variables:

| Variable                     | Required | Description                                                        |
| ---------------------------- | :------: | ------------------------------------------------------------------ |
| `DD_API_KEY_SECRET_ARN`      |   yes    | ARN of the Secrets Manager secret the extension reads.             |
| `DATADOG_API_KEY`            |   yes    | API key for querying spans/logs (same org as the secret).          |
| `DATADOG_APP_KEY`            |   yes    | App key for querying the Datadog API.                              |
| `AWS_REGION`                 |    no    | Defaults to `us-east-1`.                                           |
| `DATADOG_SITE`               |    no    | Defaults to `datadoghq.com`.                                       |
| `DD_NODE_LAYER_VERSION`      |    no    | Pin the asserted Node layer version (defaults to the module's).    |
| `DD_EXTENSION_LAYER_VERSION` |    no    | Pin the asserted extension layer version (defaults to the module's).|
| `SKIP_LAMBDA_TESTS`          |    no    | Set to `true` to skip the suite.                                   |

```
cd e2e
aws-vault exec sso-serverless-sandbox-account-admin -- \
  DD_API_KEY_SECRET_ARN=arn:aws:secretsmanager:us-east-1:...:secret:dd-api-key \
  DATADOG_API_KEY=... DATADOG_APP_KEY=... \
  go test -v -timeout 45m .
```

## In CI

`.github/workflows/e2e.yml` runs the suite behind a path filter (module sources + `e2e/`)
and a `SKIP_LAMBDA_TESTS` flag, authenticating to AWS via OIDC federation
(`id-token: write`, no long-lived keys).

The live cloud run is gated only on path relevance: every PR that touches the module or
this suite runs the full lifecycle, and the AWS OIDC / dd-sts auth steps must then succeed
-- an auth or federation failure fails the job loudly rather than skipping green. When no
relevant files change, the suite no-ops via `SKIP_LAMBDA_TESTS`.

Required repo configuration (Settings → Secrets and variables → Actions):

**Variables** (no secrets -- Datadog auth is federated via dd-sts):

| Variable                       | Example                                                       |
| ------------------------------ | ------------------------------------------------------------- |
| `AWS_ROLE_ARN_E2E`             | `arn:aws:iam::<acct>:role/gha-terraform-aws-lambda-datadog-e2e` |
| `AWS_REGION_E2E`               | `us-east-1`                                                   |
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
`one-e2e-tflambda-*` resources (full policy in `serverless-ci/e2e/iam-infra.md`).
