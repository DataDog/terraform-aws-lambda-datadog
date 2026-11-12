// Package e2e exercises the full lifecycle of the lambda-datadog Terraform module
// against real AWS and Datadog: APPLY the module and verify config, trigger it and verify
// telemetry flows, re-APPLY for idempotency, REMOVE and verify the function is gone, then
// always tear down and verify nothing is left.
//
// See README.md for the auth and environment prerequisites.
package e2e

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/files"
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
	runID                 string
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
		region:                envOr("AWS_REGION", envOr("AWS_DEFAULT_REGION", "ap-northeast-3")),
		secretArn:             mustEnv(t, "DD_API_KEY_SECRET_ARN"),
		site:                  envOr("DD_SITE", "datadoghq.com"),
		ddAPIKey:              mustEnv(t, "DD_API_KEY"),
		ddAppKey:              mustEnv(t, "DD_APP_KEY"),
		nodeLayerVersion:      intEnvOr(t, "DD_NODE_LAYER_VERSION", defaultNodeLayerVersion),
		extensionLayerVersion: intEnvOr(t, "DD_EXTENSION_LAYER_VERSION", defaultExtensionLayerVersion),
		runID:                 envOr("E2E_RUN_ID", e2eshared.NewRunID()),
	}
}

func TestLambdaInstrumentationLifecycle(t *testing.T) {
	cfg := loadConfig(t)
	ctx := context.Background()

	runID := cfg.runID
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

	// Run from a copy of the repository so local state never leaks between runs.
	repoCopy, err := files.CopyTerraformFolderToTemp("..", "e2e-")
	require.NoError(t, err)
	t.Cleanup(func() { os.RemoveAll(repoCopy) })

	opts := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: filepath.Join(repoCopy, "e2e", "fixture"),
		Vars:         commonVars(false),
		NoColor:      true,
	})
	// Retry the cloud, not the assertions: bounded retries on transient AWS errors.
	for pattern, message := range map[string]string{
		"Throttling":                  "AWS API throttling",
		"TooManyRequestsException":    "AWS API throttling",
		"ResourceConflictException":   "concurrent Lambda mutation",
		"ServiceUnavailableException": "AWS service unavailable",
	} {
		opts.RetryableTerraformErrors[pattern] = message
	}
	opts.TimeBetweenRetries = 10 * time.Second

	// Teardown always, even on failure. Vars track the last applied state.
	defer runPhase(t, "teardown", func() {
		if _, err := terraform.DestroyE(t, opts); err != nil {
			t.Errorf("terraform destroy failed: %v", err)
			if err := deleteWorkload(ctx, cfg.region, serviceName); err != nil {
				t.Errorf("fallback delete of %q failed: %v", serviceName, err)
			}
			return
		}
		require.NoError(t, verifyRemoved(ctx, cfg.region, serviceName), "destroy must remove the function and role")
	})

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

	// APPLY: create the workload through the module (from nothing) and verify config present.
	runPhase(t, "instrumentation deploy", func() {
		opts.Vars = commonVars(true)
		terraform.InitAndApply(t, opts)
	})

	runPhase(t, "config verification", func() {
		fnCfg, err := getConfig(ctx, cfg.region, terraform.Output(t, opts, "function_name"))
		require.NoError(t, err)
		tags, err := getTags(ctx, cfg.region, terraform.Output(t, opts, "function_arn"))
		require.NoError(t, err)
		require.NoError(t, verifyInstrumented(fnCfg, tags, exp))
	})

	runPhase(t, "invoke", func() { invokeLambda(t, ctx, cfg.region, serviceName) })

	runPhase(t, "telemetry wait", func() { checkTelemetryFlowing(t, ctx, cfg, id) })

	runPhase(t, "idempotency check", func() {
		exitCode := terraform.PlanExitCode(t, opts)
		if exitCode != 0 {
			t.Log(terraform.Plan(t, opts))
		}
		require.Equal(t, 0, exitCode, "re-apply must be a no-op")
	})

	// REMOVE: toggle the module off and verify the function is gone (clean end-state).
	runPhase(t, "remove", func() {
		opts.Vars = commonVars(false)
		terraform.InitAndApply(t, opts)

		_, err := getConfig(ctx, cfg.region, serviceName)
		require.ErrorContains(t, err, "ResourceNotFoundException", "function should no longer exist after the module is removed")
	})
}

// checkTelemetryFlowing waits in parallel for spans and logs that carry the run's service,
// env, version, and run ID.
func checkTelemetryFlowing(t *testing.T, ctx context.Context, cfg config, id e2eshared.Identity) {
	t.Helper()
	client := e2eshared.NewTelemetryClient(cfg.site, cfg.ddAPIKey, cfg.ddAppKey)

	type search struct {
		label string
		run   func(context.Context, string) ([]e2eshared.Event, error)
		query string
	}
	searches := []search{
		{"spans", client.SearchSpans, e2eshared.SpanQuery(id)},
		{"logs", client.SearchLogs, e2eshared.LogQuery(id)},
	}
	errs := make(chan error, len(searches))
	for _, s := range searches {
		go func() {
			_, err := client.WaitForMatching(ctx, s.label, s.run, s.query, id)
			if err != nil {
				err = fmt.Errorf("%w; sample: %s", err, sampleEvent(ctx, s.run, s.query))
			}
			errs <- err
		}()
	}

	var failures []string
	for range searches {
		if err := <-errs; err != nil {
			failures = append(failures, err.Error())
		}
	}
	require.Empty(t, failures, "telemetry did not flow: %s", strings.Join(failures, "; "))
}

// sampleEvent describes one event matching query, so identity mismatches show what
// Datadog actually received.
func sampleEvent(ctx context.Context, search func(context.Context, string) ([]e2eshared.Event, error), query string) string {
	events, err := search(ctx, query)
	switch {
	case err != nil:
		return err.Error()
	case len(events) == 0:
		return "none"
	default:
		return fmt.Sprintf("attrs=%v tags=%v", events[0].Attrs, events[0].Tags)
	}
}

// runPhase logs a phase's start, a heartbeat every 30 seconds, and its end, so long
// waits stay visible in CI.
func runPhase(t *testing.T, name string, run func()) {
	t.Helper()
	started := time.Now()
	t.Logf("START: %s", name)

	stop := make(chan struct{})
	done := make(chan struct{})
	go func() {
		defer close(done)
		ticker := time.NewTicker(30 * time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				t.Logf("RUNNING: %s (%s elapsed)", name, time.Since(started).Round(time.Second))
			case <-stop:
				return
			}
		}
	}()
	defer func() {
		close(stop)
		<-done
		t.Logf("DONE: %s (%s)", name, time.Since(started).Round(time.Second))
	}()

	run()
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
