#!/usr/bin/env bash
set -euo pipefail

EVENT_NAME="${EVENT_NAME:-${GITHUB_EVENT_NAME:-}}"
EVENT_ACTION="${EVENT_ACTION:-${GITHUB_EVENT_ACTION:-}}"
INPUT_MODE="${INPUT_MODE:-${INPUTS_MODE:-}}"
REF_TYPE="${REF_TYPE:-${GITHUB_REF_TYPE:-}}"
GITHUB_REF="${GITHUB_REF:-}"
SCHEDULE="${SCHEDULE:-${GITHUB_EVENT_SCHEDULE:-}}"

run_code_checks=true
run_release=false
run_publisher=false
run_maintenance=false
run_autofix=false
mode="validate"

if [[ "$EVENT_NAME" == "pull_request" ]]; then
  if [[ "$EVENT_ACTION" == "closed" ]]; then
    run_code_checks=false
  fi
elif [[ "$EVENT_NAME" == "schedule" ]]; then
  run_maintenance=true
  run_code_checks=true
  mode="monthly-maintenance"
elif [[ "$EVENT_NAME" == "workflow_dispatch" ]]; then
  mode="${INPUT_MODE:-validate}"
  if [[ "$mode" == "lint-fix" ]]; then
    run_autofix=true
  elif [[ "$mode" == "publish-tag" ]]; then
    if [[ "$REF_TYPE" == "tag" && "$GITHUB_REF" == refs/tags/v* ]]; then
      run_code_checks=false
      run_publisher=true
    else
      echo "Error: publish-tag mode requires a v* tag context. Found: $GITHUB_REF" >&2
      exit 1
    fi
  elif [[ "$mode" == release-* ]]; then
    run_release=true
  elif [[ "$mode" == "monthly-maintenance" ]]; then
    run_maintenance=true
    run_code_checks=true
  elif [[ "$mode" == "validate" ]]; then
    run_code_checks=true
  else
    echo "Error: Unsupported mode: $mode" >&2
    exit 1
  fi
elif [[ "$EVENT_NAME" == "push" && "$REF_TYPE" == "tag" && "$GITHUB_REF" == refs/tags/v* ]]; then
  run_publisher=true
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "run_code_checks=$run_code_checks"
    echo "run_release=$run_release"
    echo "run_publisher=$run_publisher"
    echo "run_maintenance=$run_maintenance"
    echo "run_autofix=$run_autofix"
    echo "mode=$mode"
  } >> "$GITHUB_OUTPUT"
fi

echo "run_code_checks=$run_code_checks"
echo "run_release=$run_release"
echo "run_publisher=$run_publisher"
echo "run_maintenance=$run_maintenance"
echo "run_autofix=$run_autofix"
echo "mode=$mode"
