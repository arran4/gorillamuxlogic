#!/bin/bash
set -euo pipefail

ROUTE_SCRIPT="./.github/scripts/route.sh"

run_test() {
  local test_name="$1"
  local expected_code_checks="$2"
  local expected_release="$3"

  # Ensure clean env per test run
  export GITHUB_OUTPUT=$(mktemp)

  echo "Running test: $test_name"

  if ! "$ROUTE_SCRIPT"; then
    echo "FAILED: $test_name - route.sh exited with non-zero status"
    exit 1
  fi

  local actual_code_checks=$(grep "^run_code_checks=" "$GITHUB_OUTPUT" | cut -d'=' -f2)
  local actual_release=$(grep "^run_release=" "$GITHUB_OUTPUT" | cut -d'=' -f2)

  local failed=false

  if [[ "$actual_code_checks" != "$expected_code_checks" ]]; then
    echo "FAILED: $test_name - Expected run_code_checks=$expected_code_checks, got $actual_code_checks"
    failed=true
  fi

  if [[ "$actual_release" != "$expected_release" ]]; then
    echo "FAILED: $test_name - Expected run_release=$expected_release, got $actual_release"
    failed=true
  fi

  if $failed; then
    exit 1
  else
    echo "PASSED: $test_name"
  fi

  rm -f "$GITHUB_OUTPUT"
}

# 1. Same-repository PR
export GITHUB_EVENT_NAME="pull_request"
export GITHUB_EVENT_ACTION="opened"
# GITHUB_REPOSITORY is same as fork context but we aren't using that anymore, but we can set it
run_test "Same-repository PR" "true" "false"

# 2. Fork PR
export GITHUB_EVENT_NAME="pull_request"
export GITHUB_EVENT_ACTION="opened"
run_test "Fork PR" "true" "false"

# 3. Push to main
export GITHUB_EVENT_NAME="push"
export GITHUB_REF="refs/heads/main"
export GITHUB_EVENT_ACTION=""
run_test "Push to main" "true" "false"

# 4. v* tag push
export GITHUB_EVENT_NAME="push"
export GITHUB_REF="refs/tags/v1.0.0"
run_test "v* tag push" "true" "true"

# 5. Manual release dispatch
export GITHUB_EVENT_NAME="workflow_dispatch"
export GITHUB_REF="refs/heads/main"
export INPUTS_MODE="release-minor"
run_test "Manual release dispatch" "true" "true"

# 6. Manual validate dispatch
export GITHUB_EVENT_NAME="workflow_dispatch"
export GITHUB_REF="refs/heads/main"
export INPUTS_MODE="validate"
run_test "Manual validate dispatch" "true" "false"

echo "All tests passed successfully!"
