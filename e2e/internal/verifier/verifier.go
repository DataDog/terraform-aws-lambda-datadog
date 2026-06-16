// Package verifier reads a deployed Lambda's configuration and tags through the AWS CLI
// and asserts the instrumented / uninstrumented conformance contract. It is
// runner-agnostic (returns errors, no test-framework import), mirroring the
// cloud-run-verifier reference: assert identity, not mere existence.
package verifier

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/DataDog/terraform-aws-lambda-datadog/e2e/internal/awscli"
)

// Config is the subset of get-function-configuration we assert on.
type Config struct {
	Handler string `json:"Handler"`
	Runtime string `json:"Runtime"`
	Layers  []struct {
		Arn string `json:"Arn"`
	} `json:"Layers"`
	Environment struct {
		Variables map[string]string `json:"Variables"`
	} `json:"Environment"`
}

// Expectations pins what an instrumented workload must look like, so a mismatch blames
// the module wiring rather than upstream drift.
type Expectations struct {
	Service               string
	Env                   string
	Version               string
	RunID                 string
	Site                  string
	SecretArn             string
	NodeLayerName         string // e.g. Datadog-Node22-x
	NodeLayerVersion      int
	ExtensionLayerVersion int
}

// GetConfig fetches the function configuration.
func GetConfig(ctx context.Context, region, functionName string) (Config, error) {
	res, err := awscli.RunWithRetries(ctx, 3, 5*time.Second,
		"lambda", "get-function-configuration",
		"--function-name", functionName, "--region", region, "--output", "json")
	if err != nil {
		return Config{}, err
	}
	var cfg Config
	if err := json.Unmarshal([]byte(res.Stdout), &cfg); err != nil {
		return Config{}, fmt.Errorf("parsing function configuration: %w", err)
	}

	return cfg, nil
}

// GetTags fetches the resource tags for a function ARN.
func GetTags(ctx context.Context, region, functionArn string) (map[string]string, error) {
	res, err := awscli.RunWithRetries(ctx, 3, 5*time.Second,
		"lambda", "list-tags", "--resource", functionArn, "--region", region, "--output", "json")
	if err != nil {
		return nil, err
	}
	var out struct {
		Tags map[string]string `json:"Tags"`
	}
	if err := json.Unmarshal([]byte(res.Stdout), &out); err != nil {
		return nil, fmt.Errorf("parsing tags: %w", err)
	}

	return out.Tags, nil
}

func (c Config) hasLayer(substr string) bool {
	for _, l := range c.Layers {
		if strings.Contains(l.Arn, substr) {
			return true
		}
	}

	return false
}

// VerifyInstrumented asserts config present: pinned DD layers + extension, required DD_*
// env wiring, the redirected handler, and identifying tags.
func VerifyInstrumented(cfg Config, tags map[string]string, exp Expectations) error {
	var errs []string
	add := func(format string, args ...any) { errs = append(errs, fmt.Sprintf(format, args...)) }

	// Pinned layers: Datadog runtime layer + extension layer at the exact versions.
	nodeLayer := fmt.Sprintf(":layer:%s:%d", exp.NodeLayerName, exp.NodeLayerVersion)
	if !cfg.hasLayer(nodeLayer) {
		add("expected pinned Datadog node layer %q among %v", nodeLayer, layerArns(cfg))
	}
	extLayer := fmt.Sprintf(":layer:Datadog-Extension:%d", exp.ExtensionLayerVersion)
	extLayerFips := fmt.Sprintf(":layer:Datadog-Extension-FIPS:%d", exp.ExtensionLayerVersion)
	if !cfg.hasLayer(extLayer) && !cfg.hasLayer(extLayerFips) {
		add("expected pinned Datadog extension layer %q among %v", extLayer, layerArns(cfg))
	}

	// Handler must be redirected to the Datadog Node wrapper.
	const wrapper = "/opt/nodejs/node_modules/datadog-lambda-js/handler.handler"
	if cfg.Handler != wrapper {
		add("expected handler redirected to %q, got %q", wrapper, cfg.Handler)
	}

	env := cfg.Environment.Variables
	wantEnv := map[string]string{
		"DD_API_KEY_SECRET_ARN":      exp.SecretArn,
		"DD_SITE":                    exp.Site,
		"DD_SERVICE":                 exp.Service,
		"DD_ENV":                     exp.Env,
		"DD_VERSION":                 exp.Version,
		"DD_TRACE_ENABLED":           "true",
		"DD_SERVERLESS_LOGS_ENABLED": "true",
		"DD_LAMBDA_HANDLER":          "index.handler",
	}
	for k, want := range wantEnv {
		if got, ok := env[k]; !ok {
			add("missing env var %s", k)
		} else if got != want {
			add("env var %s = %q, want %q", k, got, want)
		}
	}
	if got := env["DD_TAGS"]; !strings.Contains(got, "one_e2e_run_id:"+exp.RunID) {
		add("DD_TAGS %q missing run-id marker one_e2e_run_id:%s", got, exp.RunID)
	}

	// Identifying tags on the resource.
	if tags["dd_sls_terraform_module"] == "" {
		add("missing dd_sls_terraform_module tag")
	}
	if tags["one_e2e_run_id"] != exp.RunID {
		add("one_e2e_run_id tag = %q, want %q", tags["one_e2e_run_id"], exp.RunID)
	}
	if tags["one_e2e_created"] == "" {
		add("missing one_e2e_created freshness tag")
	}

	if len(errs) > 0 {
		return fmt.Errorf("instrumented contract violated:\n  - %s", strings.Join(errs, "\n  - "))
	}

	return nil
}

// VerifyUninstrumented asserts absence explicitly: no Datadog layers, no DD_* env vars,
// no Datadog module tag.
func VerifyUninstrumented(cfg Config, tags map[string]string) error {
	var errs []string
	add := func(format string, args ...any) { errs = append(errs, fmt.Sprintf(format, args...)) }

	for _, l := range cfg.Layers {
		if strings.Contains(l.Arn, ":layer:Datadog-") {
			add("residual Datadog layer %q", l.Arn)
		}
	}
	for k := range cfg.Environment.Variables {
		if strings.HasPrefix(k, "DD_") {
			add("residual DD_* env var %s", k)
		}
	}
	if tags["dd_sls_terraform_module"] != "" {
		add("residual dd_sls_terraform_module tag %q", tags["dd_sls_terraform_module"])
	}

	if len(errs) > 0 {
		return fmt.Errorf("uninstrumented (post-remove) contract violated:\n  - %s", strings.Join(errs, "\n  - "))
	}

	return nil
}

func layerArns(cfg Config) []string {
	arns := make([]string, 0, len(cfg.Layers))
	for _, l := range cfg.Layers {
		arns = append(arns, l.Arn)
	}

	return arns
}
