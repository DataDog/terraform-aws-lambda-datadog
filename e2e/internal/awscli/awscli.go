// Package awscli is a thin, runner-agnostic wrapper around the AWS CLI with bounded
// retries on transient cloud errors. It mirrors the exec/retry helper from the
// datadog-ci reference suite: retry the cloud, never retry past a real failure.
package awscli

import (
	"bytes"
	"context"
	"fmt"
	"os/exec"
	"strings"
	"time"
)

// retryablePatterns are transient cloud errors that are safe to retry. Anything else
// is treated as a real failure and surfaced immediately.
var retryablePatterns = []string{
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
}

// Result is the outcome of a single AWS CLI invocation.
type Result struct {
	Stdout   string
	Stderr   string
	ExitCode int
}

func isRetryable(r Result) bool {
	out := r.Stdout + " " + r.Stderr
	for _, p := range retryablePatterns {
		if strings.Contains(out, p) {
			return true
		}
	}

	return false
}

// Run executes a single `aws` command.
func Run(ctx context.Context, args ...string) (Result, error) {
	cmd := exec.CommandContext(ctx, "aws", args...)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()

	res := Result{Stdout: strings.TrimSpace(stdout.String()), Stderr: strings.TrimSpace(stderr.String())}
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			res.ExitCode = exitErr.ExitCode()
		} else {
			res.ExitCode = 1
		}

		return res, err
	}

	return res, nil
}

// RunWithRetries executes an `aws` command, retrying only on transient errors.
func RunWithRetries(ctx context.Context, maxAttempts int, delay time.Duration, args ...string) (Result, error) {
	var res Result
	var err error
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		res, err = Run(ctx, args...)
		if err == nil {
			return res, nil
		}
		if attempt < maxAttempts && isRetryable(res) {
			time.Sleep(delay)

			continue
		}

		return res, fmt.Errorf("aws %s failed (exit %d): %s", strings.Join(args, " "), res.ExitCode, res.Stderr)
	}

	return res, err
}
