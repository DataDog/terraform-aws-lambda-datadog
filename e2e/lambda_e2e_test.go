// Package e2e exercises the full lifecycle of the lambda-datadog Terraform module
// against real AWS and Datadog: provision an uninstrumented workload, APPLY the module
// and verify config, trigger it and verify telemetry flows, re-APPLY for idempotency,
// REMOVE and verify a clean end-state, then always tear down.
//
// See README.md for the auth and environment prerequisites. The suite is skipped unless
// SKIP_LAMBDA_TESTS is unset/false.
package e2e

import (
	"context"
	"os"
	"strconv"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"

	e2eshared "github.com/DataDog/terraform-aws-lambda-datadog/e2e/shared"
)

// Canonical, pinned artifacts. One runtime per platform; exhaustiveness lives upstream.
const (
	canonicalRuntime = "nodejs22.x"
	nodeLayerName    = "Datadog-Node22-x"

	// Defaults match the module's current variables.tf and are overridable via env so a
	// failure blames the module wiring, not upstream layer drift.
	defaultNodeLayerVersion      = 135
	defaultExtensionLayerVersion = 93
)

type config struct {
	region                string
	secretArn             string
	site                  string
	ddAPIKey              string
	ddAppKey              string
	nodeLayerVersion      int
	extensionLayerVersion int
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}

	return fallback
}

func mustEnv(t *testing.T, key string) string {
	t.Helper()
	v := os.Getenv(key)
	require.NotEmptyf(t, v, "%s must be set (see e2e/README.md)", key)

	return v
}

func intEnvOr(t *testing.T, key string, fallback int) int {
	t.Helper()
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	n, err := strconv.Atoi(v)
	require.NoErrorf(t, err, "%s must be an integer", key)

	return n
}

func loadConfig(t *testing.T) config {
	t.Helper()

	return config{
		region:                envOr("AWS_REGION", envOr("AWS_DEFAULT_REGION", "us-east-1")),
		secretArn:             mustEnv(t, "DD_API_KEY_SECRET_ARN"),
		site:                  envOr("DATADOG_SITE", "datadoghq.com"),
		ddAPIKey:              mustEnv(t, "DATADOG_API_KEY"),
		ddAppKey:              mustEnv(t, "DATADOG_APP_KEY"),
		nodeLayerVersion:      intEnvOr(t, "DD_NODE_LAYER_VERSION", defaultNodeLayerVersion),
		extensionLayerVersion: intEnvOr(t, "DD_EXTENSION_LAYER_VERSION", defaultExtensionLayerVersion),
	}
}

func TestLambdaInstrumentationLifecycle(t *testing.T) {
	if os.Getenv("SKIP_LAMBDA_TESTS") == "true" {
		t.Skip("SKIP_LAMBDA_TESTS=true")
	}

	cfg := loadConfig(t)
	ctx := context.Background()

	runID := e2eshared.NewRunID()
	// one-e2e-<tool>-<platform>-<runid>: identity + sweeper blast-radius guard.
	serviceName := e2eshared.ResourceName(sharedCfg, runID)
	createdTS := strconv.FormatInt(time.Now().Unix(), 10)
	t.Logf("workload service=%s run_id=%s region=%s", serviceName, runID, cfg.region)

	commonVars := func(instrumented bool) map[string]any {
		return map[string]any{
			"region":                          cfg.region,
			"instrumented":                    instrumented,
			"service_name":                    serviceName,
			"created_ts":                      createdTS,
			"run_id":                          runID,
			"datadog_api_key_secret_arn":      cfg.secretArn,
			"datadog_site":                    cfg.site,
			"runtime":                         canonicalRuntime,
			"datadog_node_layer_version":      cfg.nodeLayerVersion,
			"datadog_extension_layer_version": cfg.extensionLayerVersion,
		}
	}

	opts := &terraform.Options{
		TerraformDir: "fixture",
		Vars:         commonVars(false),
		// Retry the cloud, not the assertions: bounded retries on transient apply errors.
		RetryableTerraformErrors: map[string]string{
			".*Throttling.*":                  "AWS API throttling",
			".*ThrottlingException.*":         "AWS API throttling",
			".*RequestError.*":                "transient AWS request error",
			".*ResourceConflictException.*":   "concurrent Lambda mutation",
			".*operation error.*timeout.*":    "transient AWS timeout",
			".*ServiceUnavailableException.*": "AWS service unavailable",
		},
		MaxRetries:         3,
		TimeBetweenRetries: 10 * time.Second,
		NoColor:            true,
	}

	// Teardown always, even on failure. Vars track the last applied state.
	defer terraform.Destroy(t, opts)

	// 1. Provision the uninstrumented workload.
	opts.Vars = commonVars(false)
	terraform.InitAndApply(t, opts)

	id := e2eshared.IdentityFor(sharedCfg, serviceName, "e2e", "1.0.0", runID)
	exp := Expectations{
		Service:               serviceName,
		Env:                   "e2e",
		Version:               "1.0.0",
		RunID:                 runID,
		Site:                  cfg.site,
		SecretArn:             cfg.secretArn,
		NodeLayerName:         nodeLayerName,
		NodeLayerVersion:      cfg.nodeLayerVersion,
		ExtensionLayerVersion: cfg.extensionLayerVersion,
	}

	// 2. APPLY (instrument) and verify config present.
	t.Run("apply_instruments_and_config_present", func(t *testing.T) {
		opts.Vars = commonVars(true)
		terraform.InitAndApply(t, opts)
		functionName := terraform.Output(t, opts, "function_name")
		functionArn := terraform.Output(t, opts, "function_arn")

		fnCfg, err := getConfig(ctx, cfg.region, functionName)
		require.NoError(t, err)
		tags, err := getTags(ctx, cfg.region, functionArn)
		require.NoError(t, err)
		require.NoError(t, verifyInstrumented(fnCfg, tags, exp))
	})

	// 3. Trigger the workload and verify telemetry flows, asserting identity.
	t.Run("trigger_and_telemetry_flows", func(t *testing.T) {
		invokeLambda(t, ctx, cfg.region, serviceName)

		client := e2eshared.NewTelemetryClient(cfg.site, cfg.ddAPIKey, cfg.ddAppKey)

		// Spans and logs are polled sequentially; give each its own full budget so a
		// slow spans poll can't starve the logs poll of time.
		spanCtx, cancelSpan := context.WithTimeout(ctx, 6*time.Minute)
		defer cancelSpan()
		span, err := client.WaitForMatching(spanCtx, "spans", client.SearchSpans, e2eshared.SpanQuery(id), id)
		require.NoError(t, err, "spans carrying the workload identity should appear")
		t.Logf("span identity verified: %+v", span.Attrs)

		logCtx, cancelLog := context.WithTimeout(ctx, 6*time.Minute)
		defer cancelLog()
		log, err := client.WaitForMatching(logCtx, "logs", client.SearchLogs, e2eshared.LogQuery(id), id)
		require.NoError(t, err, "logs carrying the workload identity should appear")
		t.Logf("log identity verified: %+v", log.Attrs)
	})

	// 4. Re-APPLY and assert idempotency (no diff).
	t.Run("reapply_is_idempotent", func(t *testing.T) {
		opts.Vars = commonVars(true)
		exitCode := terraform.PlanExitCode(t, opts)
		require.Equal(t, 0, exitCode, "re-apply should produce no diff (terraform plan detailed exit code 0)")
	})

	// 5. REMOVE and verify a clean end-state.
	t.Run("remove_leaves_clean_state", func(t *testing.T) {
		opts.Vars = commonVars(false)
		terraform.InitAndApply(t, opts)
		functionName := terraform.Output(t, opts, "function_name")
		functionArn := terraform.Output(t, opts, "function_arn")

		fnCfg, err := getConfig(ctx, cfg.region, functionName)
		require.NoError(t, err)
		tags, err := getTags(ctx, cfg.region, functionArn)
		require.NoError(t, err)
		require.NoError(t, verifyUninstrumented(fnCfg, tags))
	})
}

// invokeLambda triggers the workload a few times so a trace and log are produced, with
// bounded retries over cold-start / propagation races.
func invokeLambda(t *testing.T, ctx context.Context, region, functionName string) {
	t.Helper()
	out, err := os.CreateTemp("", "invoke-*.json")
	require.NoError(t, err)
	defer os.Remove(out.Name())
	_ = out.Close()

	for i := 0; i < 3; i++ {
		res, err := e2eshared.RunWithRetries(ctx, sharedCfg, 4, 10*time.Second,
			"lambda", "invoke",
			"--function-name", functionName,
			"--region", region,
			"--payload", "{}",
			"--cli-binary-format", "raw-in-base64-out",
			"--output", "json",
			out.Name())
		require.NoErrorf(t, err, "lambda invoke failed: %s", res.Stderr)
		t.Logf("invoke %d: %s", i+1, res.Stdout)
	}
}
