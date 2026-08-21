#!/usr/bin/env bash
set -euo pipefail

test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/unsupported" && pwd)"
readonly test_dir

terraform -chdir="$test_dir" init -backend=false >/dev/null
if output="$(AWS_EC2_METADATA_DISABLED=true terraform -chdir="$test_dir" plan -refresh=false -input=false -lock=false -no-color 2>&1)"; then
  printf '%s\n' "dotnet7 plan unexpectedly succeeded" >&2
  exit 1
fi

printf '%s\n' "$output" | rg -F "dotnet7 Lambda runtime is not supported"
