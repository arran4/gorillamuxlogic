#!/bin/bash
set -euo pipefail

run_code_checks=false
run_release=false

case "${GITHUB_EVENT_NAME:-}" in
  push)
    run_code_checks=true
    if [[ "${GITHUB_REF:-}" == refs/tags/v* ]]; then
      run_release=true
    fi
    ;;
  pull_request)
    run_code_checks=true
    ;;
  workflow_dispatch)
    run_code_checks=true
    case "${INPUTS_MODE:-}" in
      validate)
        ;;
      release-*)
        run_release=true
        ;;
      publish-tag)
        if [[ "${GITHUB_REF_TYPE:-}" != "tag" || ! "${GITHUB_REF:-}" =~ ^refs/tags/v.* ]]; then
          echo "publish-tag mode requires an eligible tag context (e.g. refs/tags/v*)" >&2
          exit 1
        fi
        run_release=true
        ;;
    esac
    ;;
esac

echo "run_code_checks=$run_code_checks" >> "${GITHUB_OUTPUT:-/dev/null}"
echo "run_release=$run_release" >> "${GITHUB_OUTPUT:-/dev/null}"
