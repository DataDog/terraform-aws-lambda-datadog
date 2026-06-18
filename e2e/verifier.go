// Repo-local config + Lambda config-verification for the e2e suite. The generic,
// cross-cloud helpers (exec/retry, telemetry, naming, verification primitives) come from
// the shared e2eshared package; what lives here is everything specific to this module:
// the AWS retry patterns and the Lambda "config present / clean" assertions.
package e2e

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	e2eshared "github.com/DataDog/terraform-aws-lambda-datadog/e2e/shared"
)

// sharedCfg parameterizes the shared helpers for this module: the AWS CLI, the AWS
// transient-error patterns safe to retry, and the tool/platform naming.
var sharedCfg = e2eshared.Config{
	Tool:     "tflambda",
	Platform: "lambda",
	Command:  "aws",
	RetryPatterns: []string{
		"Throttling",
		"ThrottlingException",
		"TooManyRequestsException",
		"RequestTimeout",
		"ServiceUnavailable",
		"InternalFailure",
		"InternalServerError",
		"Rate exceeded",
		"Could not connect",
		"timed out",
		"connection reset",
		"ResourceConflictException",
	},
}

// functionConfig is the subset of get-function-configuration we assert on.
type functionConfig struct {
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

func getConfig(ctx context.Context, region, functionName string) (functionConfig, error) {
	res, err := e2eshared.RunWithRetries(ctx, sharedCfg, 3, 5*time.Second,
		"lambda", "get-function-configuration",
		"--function-name", functionName, "--region", region, "--output", "json")
	if err != nil {
		return functionConfig{}, err
	}
	var cfg functionConfig
	if err := json.Unmarshal([]byte(res.Stdout), &cfg); err != nil {
		return functionConfig{}, fmt.Errorf("parsing function configuration: %w", err)
	}

	return cfg, nil
}

func getTags(ctx context.Context, region, functionArn string) (map[string]string, error) {
	res, err := e2eshared.RunWithRetries(ctx, sharedCfg, 3, 5*time.Second,
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

func (c functionConfig) hasLayer(substr string) bool {
	for _, l := range c.Layers {
		if strings.Contains(l.Arn, substr) {
			return true
		}
	}

	return false
}

func layerArns(cfg functionConfig) []string {
	arns := make([]string, 0, len(cfg.Layers))
	for _, l := range cfg.Layers {
		arns = append(arns, l.Arn)
	}

	return arns
}

// verifyInstrumented asserts config present: pinned DD layers + extension, required DD_*
// env wiring, the redirected handler, and identifying tags.
func verifyInstrumented(cfg functionConfig, tags map[string]string, exp Expectations) error {
	var v e2eshared.Violations

	// Pinned layers: Datadog runtime layer + extension layer at the exact versions.
	nodeLayer := fmt.Sprintf(":layer:%s:%d", exp.NodeLayerName, exp.NodeLayerVersion)
	if !cfg.hasLayer(nodeLayer) {
		v.Addf("expected pinned Datadog node layer %q among %v", nodeLayer, layerArns(cfg))
	}
	extLayer := fmt.Sprintf(":layer:Datadog-Extension:%d", exp.ExtensionLayerVersion)
	extLayerFips := fmt.Sprintf(":layer:Datadog-Extension-FIPS:%d", exp.ExtensionLayerVersion)
	if !cfg.hasLayer(extLayer) && !cfg.hasLayer(extLayerFips) {
		v.Addf("expected pinned Datadog extension layer %q among %v", extLayer, layerArns(cfg))
	}

	// Handler must be redirected to the Datadog Node wrapper.
	const wrapper = "/opt/nodejs/node_modules/datadog-lambda-js/handler.handler"
	if cfg.Handler != wrapper {
		v.Addf("expected handler redirected to %q, got %q", wrapper, cfg.Handler)
	}

	// Required DD_* env wiring, with identity on service/env/version.
	env := cfg.Environment.Variables
	e2eshared.RequireValues(&v, "env var", env, map[string]string{
		"DD_API_KEY_SECRET_ARN":      exp.SecretArn,
		"DD_SITE":                    exp.Site,
		"DD_SERVICE":                 exp.Service,
		"DD_ENV":                     exp.Env,
		"DD_VERSION":                 exp.Version,
		"DD_TRACE_ENABLED":           "true",
		"DD_SERVERLESS_LOGS_ENABLED": "true",
		"DD_LAMBDA_HANDLER":          "index.handler",
	})
	if got := env["DD_TAGS"]; !strings.Contains(got, "one_e2e_run_id:"+exp.RunID) {
		v.Addf("DD_TAGS %q missing run-id marker one_e2e_run_id:%s", got, exp.RunID)
	}

	// Identifying tags on the resource: the module marker + hygiene tags.
	if tags["dd_sls_terraform_module"] == "" {
		v.Addf("missing dd_sls_terraform_module tag")
	}
	e2eshared.RequireHygieneTags(&v, sharedCfg, tags, exp.RunID)

	return v.Err("instrumented contract violated")
}

// verifyUninstrumented asserts absence explicitly: no Datadog layers, no DD_* env vars,
// no Datadog module tag.
func verifyUninstrumented(cfg functionConfig, tags map[string]string) error {
	var v e2eshared.Violations

	for _, l := range cfg.Layers {
		if strings.Contains(l.Arn, ":layer:Datadog-") {
			v.Addf("residual Datadog layer %q", l.Arn)
		}
	}
	e2eshared.ForbidKeyPrefix(&v, "env var", cfg.Environment.Variables, "DD_")
	if tags["dd_sls_terraform_module"] != "" {
		v.Addf("residual dd_sls_terraform_module tag %q", tags["dd_sls_terraform_module"])
	}

	return v.Err("uninstrumented (post-remove) contract violated")
}
