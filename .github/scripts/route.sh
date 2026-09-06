#!/bin/bash
set -euo pipefail

run_code_checks=false
run_pr_meta_checks=false
run_cleanup=false
run_release=false
is_monthly=false
is_nightly=false

case "${GITHUB_EVENT_NAME:-}" in
  push)
    run_code_checks=true
    if [[ "${GITHUB_REF:-}" == refs/tags/v* ]]; then
      run_release=true
    fi
    ;;
  pull_request)
    if [[ "${GITHUB_EVENT_ACTION:-}" == "closed" ]]; then
      run_cleanup=true
    else
      run_pr_meta_checks=true
      run_code_checks=true
    fi
    ;;
  release)
    ;;
  workflow_dispatch)
    run_code_checks=true
    case "${INPUTS_MODE:-}" in
      monthly-maintenance)
        is_monthly=true
        ;;
      lint-fix)
        is_nightly=true
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
  schedule)
    run_code_checks=true
    if [[ "${GITHUB_EVENT_SCHEDULE:-}" == "17 3 1 * *" ]]; then
      is_monthly=true
    fi
    if [[ "${GITHUB_EVENT_SCHEDULE:-}" == "41 2 * * *" ]]; then
      is_nightly=true
    fi
    ;;
esac

echo "run_code_checks=$run_code_checks" >> "${GITHUB_OUTPUT:-/dev/null}"
echo "run_pr_meta_checks=$run_pr_meta_checks" >> "${GITHUB_OUTPUT:-/dev/null}"
echo "run_cleanup=$run_cleanup" >> "${GITHUB_OUTPUT:-/dev/null}"
echo "run_release=$run_release" >> "${GITHUB_OUTPUT:-/dev/null}"
echo "is_monthly=$is_monthly" >> "${GITHUB_OUTPUT:-/dev/null}"
echo "is_nightly=$is_nightly" >> "${GITHUB_OUTPUT:-/dev/null}"
