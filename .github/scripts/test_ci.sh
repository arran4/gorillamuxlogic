#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROUTE_SCRIPT="$SCRIPT_DIR/route.sh"
RELEASE_SCRIPT="$SCRIPT_DIR/prepare-release.sh"

PASSED_COUNT=0
FAILED_COUNT=0

log_pass() {
  echo "  PASS: $1"
  PASSED_COUNT=$((PASSED_COUNT + 1))
}

log_fail() {
  echo "  FAIL: $1 - $2"
  FAILED_COUNT=$((FAILED_COUNT + 1))
}

echo "=== 1. Testing Event Routing Logic ($ROUTE_SCRIPT) ==="

test_route() {
  local test_name="$1"
  local env_setup="$2"
  local expected_exit="$3"
  local expected_code_checks="$4"
  local expected_release="$5"
  local expected_publisher="$6"
  local expected_maintenance="$7"
  local expected_autofix="$8"
  local expected_mode="$9"

  local tmp_output
  tmp_output=$(mktemp)

  local actual_exit=0
  local script_stdout
  # Run in subshell with clean env, exported test variables, and output redirect
  script_stdout=$(
    (
      unset EVENT_NAME GITHUB_EVENT_NAME EVENT_ACTION GITHUB_EVENT_ACTION
      unset INPUT_MODE INPUTS_MODE REF_TYPE GITHUB_REF_TYPE GITHUB_REF SCHEDULE GITHUB_EVENT_SCHEDULE
      export GITHUB_OUTPUT="$tmp_output"
      set -a
      eval "$env_setup"
      set +a
      "$ROUTE_SCRIPT"
    ) 2>&1
  ) || actual_exit=$?

  if [[ "$actual_exit" != "$expected_exit" ]]; then
    log_fail "$test_name" "Expected exit code $expected_exit, got $actual_exit. Output: $script_stdout"
    rm -f "$tmp_output"
    return
  fi

  if [[ "$expected_exit" != "0" ]]; then
    log_pass "$test_name (expected error caught with exit $actual_exit)"
    rm -f "$tmp_output"
    return
  fi

  local code_checks release publisher maintenance autofix mode
  code_checks=$(grep "^run_code_checks=" "$tmp_output" | cut -d'=' -f2)
  release=$(grep "^run_release=" "$tmp_output" | cut -d'=' -f2)
  publisher=$(grep "^run_publisher=" "$tmp_output" | cut -d'=' -f2)
  maintenance=$(grep "^run_maintenance=" "$tmp_output" | cut -d'=' -f2)
  autofix=$(grep "^run_autofix=" "$tmp_output" | cut -d'=' -f2)
  mode=$(grep "^mode=" "$tmp_output" | cut -d'=' -f2)

  local errs=""
  [[ "$code_checks" != "$expected_code_checks" ]] && errs+="code_checks: expected $expected_code_checks got $code_checks; "
  [[ "$release" != "$expected_release" ]] && errs+="release: expected $expected_release got $release; "
  [[ "$publisher" != "$expected_publisher" ]] && errs+="publisher: expected $expected_publisher got $publisher; "
  [[ "$maintenance" != "$expected_maintenance" ]] && errs+="maintenance: expected $expected_maintenance got $maintenance; "
  [[ "$autofix" != "$expected_autofix" ]] && errs+="autofix: expected $expected_autofix got $autofix; "
  [[ "$mode" != "$expected_mode" ]] && errs+="mode: expected $expected_mode got $mode; "

  if [[ -n "$errs" ]]; then
    log_fail "$test_name" "$errs"
  else
    log_pass "$test_name"
  fi

  rm -f "$tmp_output"
}

# 1. Ordinary PR (opened)
test_route "Ordinary PR opened" \
  'EVENT_NAME="pull_request"; EVENT_ACTION="opened"; GITHUB_REF="refs/pull/1/merge"' \
  0 true false false false false "validate"

# 2. Ordinary PR (synchronize)
test_route "Ordinary PR synchronize" \
  'EVENT_NAME="pull_request"; EVENT_ACTION="synchronize"; GITHUB_REF="refs/pull/1/merge"' \
  0 true false false false false "validate"

# 3. Closed PR (must NOT run code checks or any other jobs)
test_route "Closed PR" \
  'EVENT_NAME="pull_request"; EVENT_ACTION="closed"; GITHUB_REF="refs/pull/1/merge"' \
  0 false false false false false "validate"

# 4. Push to main
test_route "Push to main" \
  'EVENT_NAME="push"; REF_TYPE="branch"; GITHUB_REF="refs/heads/main"' \
  0 true false false false false "validate"

# 5. Push to master
test_route "Push to master" \
  'EVENT_NAME="push"; REF_TYPE="branch"; GITHUB_REF="refs/heads/master"' \
  0 true false false false false "validate"

# 6. Push to feature branch
test_route "Push to feature branch" \
  'EVENT_NAME="push"; REF_TYPE="branch"; GITHUB_REF="refs/heads/feature-x"' \
  0 true false false false false "validate"

# 7. External eligible v* tag push
test_route "External eligible v* tag push" \
  'EVENT_NAME="push"; REF_TYPE="tag"; GITHUB_REF="refs/tags/v1.0.0"' \
  0 true false true false false "validate"

# 8. External ineligible non-v tag push
test_route "External ineligible non-v tag push" \
  'EVENT_NAME="push"; REF_TYPE="tag"; GITHUB_REF="refs/tags/test-1"' \
  0 true false false false false "validate"

# 9. Manual validate dispatch
test_route "Manual validate dispatch" \
  'EVENT_NAME="workflow_dispatch"; INPUT_MODE="validate"; GITHUB_REF="refs/heads/main"; REF_TYPE="branch"' \
  0 true false false false false "validate"

# 10. Manual release-major dispatch
test_route "Manual release-major dispatch" \
  'EVENT_NAME="workflow_dispatch"; INPUT_MODE="release-major"; GITHUB_REF="refs/heads/main"; REF_TYPE="branch"' \
  0 true true false false false "release-major"

# 11. Manual release-minor dispatch
test_route "Manual release-minor dispatch" \
  'EVENT_NAME="workflow_dispatch"; INPUT_MODE="release-minor"; GITHUB_REF="refs/heads/main"; REF_TYPE="branch"' \
  0 true true false false false "release-minor"

# 12. Manual release-patch dispatch
test_route "Manual release-patch dispatch" \
  'EVENT_NAME="workflow_dispatch"; INPUT_MODE="release-patch"; GITHUB_REF="refs/heads/main"; REF_TYPE="branch"' \
  0 true true false false false "release-patch"

# 13. Manual release-test dispatch
test_route "Manual release-test dispatch" \
  'EVENT_NAME="workflow_dispatch"; INPUT_MODE="release-test"; GITHUB_REF="refs/heads/main"; REF_TYPE="branch"' \
  0 true true false false false "release-test"

# 14. Manual release-rc dispatch
test_route "Manual release-rc dispatch" \
  'EVENT_NAME="workflow_dispatch"; INPUT_MODE="release-rc"; GITHUB_REF="refs/heads/main"; REF_TYPE="branch"' \
  0 true true false false false "release-rc"

# 15. Manual release-alpha dispatch
test_route "Manual release-alpha dispatch" \
  'EVENT_NAME="workflow_dispatch"; INPUT_MODE="release-alpha"; GITHUB_REF="refs/heads/main"; REF_TYPE="branch"' \
  0 true true false false false "release-alpha"

# 16. Manual lint-fix dispatch
test_route "Manual lint-fix dispatch" \
  'EVENT_NAME="workflow_dispatch"; INPUT_MODE="lint-fix"; GITHUB_REF="refs/heads/main"; REF_TYPE="branch"' \
  0 true false false false true "lint-fix"

# 17. Manual monthly-maintenance dispatch
test_route "Manual monthly-maintenance dispatch" \
  'EVENT_NAME="workflow_dispatch"; INPUT_MODE="monthly-maintenance"; GITHUB_REF="refs/heads/main"; REF_TYPE="branch"' \
  0 true false false true false "monthly-maintenance"

# 18. Scheduled monthly maintenance
test_route "Scheduled monthly maintenance" \
  'EVENT_NAME="schedule"; SCHEDULE="17 3 1 * *"; GITHUB_REF="refs/heads/main"' \
  0 true false false true false "monthly-maintenance"

# 19. Valid publish-tag dispatch
test_route "Valid publish-tag dispatch" \
  'EVENT_NAME="workflow_dispatch"; INPUT_MODE="publish-tag"; REF_TYPE="tag"; GITHUB_REF="refs/tags/v1.0.0"' \
  0 false false true false false "publish-tag"

# 20. Invalid publish-tag dispatch (branch ref)
test_route "Invalid publish-tag dispatch on branch" \
  'EVENT_NAME="workflow_dispatch"; INPUT_MODE="publish-tag"; REF_TYPE="branch"; GITHUB_REF="refs/heads/main"' \
  1 "" "" "" "" "" ""

# 21. Invalid publish-tag dispatch (non-v tag)
test_route "Invalid publish-tag dispatch on non-v tag" \
  'EVENT_NAME="workflow_dispatch"; INPUT_MODE="publish-tag"; REF_TYPE="tag"; GITHUB_REF="refs/tags/test-1"' \
  1 "" "" "" "" "" ""

# 22. Invalid workflow_dispatch mode
test_route "Invalid workflow_dispatch mode" \
  'EVENT_NAME="workflow_dispatch"; INPUT_MODE="nonexistent-mode"; GITHUB_REF="refs/heads/main"' \
  1 "" "" "" "" "" ""


echo ""
echo "=== 2. Testing Release Precondition & Decision Logic ($RELEASE_SCRIPT) ==="

# Set up isolated local git repos to simulate remote origin and local checkout
TEMP_BASE=$(mktemp -d)
trap 'rm -rf "$TEMP_BASE"' EXIT

BARE_REMOTE="$TEMP_BASE/remote.git"
WORK_REPO="$TEMP_BASE/work"

git init --bare "$BARE_REMOTE" >/dev/null
git clone "$BARE_REMOTE" "$WORK_REPO" >/dev/null 2>&1

cd "$WORK_REPO"
git config user.name "CI Tester"
git config user.email "ci-test@example.com"
git config commit.gpgsign false
git config tag.gpgsign false
git checkout -b main >/dev/null 2>&1
echo "package main" > main.go
git add main.go
git commit -m "initial commit" >/dev/null
git push origin main >/dev/null 2>&1
INIT_SHA=$(git rev-parse HEAD)

# Tag initial commit with v1.0.0 on remote
git tag v1.0.0
git push origin v1.0.0 >/dev/null 2>&1

test_release_prep() {
  local test_name="$1"
  local env_vars="$2"
  local expected_exit="$3"
  local expected_output_substr="$4"

  local actual_exit=0
  local output
  output=$(
    (
      cd "$WORK_REPO"
      export DRY_RUN="true"
      export REMOTE="origin"
      set -a
      eval "$env_vars"
      set +a
      "$RELEASE_SCRIPT"
    ) 2>&1
  ) || actual_exit=$?

  if [[ "$actual_exit" != "$expected_exit" ]]; then
    log_fail "$test_name" "Expected exit code $expected_exit, got $actual_exit. Output: $output"
    return
  fi

  if [[ -n "$expected_output_substr" ]] && [[ "$output" != *"$expected_output_substr"* ]]; then
    log_fail "$test_name" "Output did not contain '$expected_output_substr'. Output: $output"
    return
  fi

  log_pass "$test_name"
}

# 1. Valid manual release on main with exact SHA matching origin/main
test_release_prep "Valid manual release on main (release-minor, exact SHA)" \
  'TARGET_REF="refs/heads/main"; TARGET_REF_NAME="main"; GITHUB_SHA="'"$INIT_SHA"'"; RELEASE_MODE="release-minor"' \
  0 "Dry run: verification passed"

# 2. Valid manual release using built-in GitHub runner variable values
test_release_prep "Valid manual release using runner GITHUB_REF and GITHUB_REF_NAME" \
  'GITHUB_REF="refs/heads/main"; GITHUB_REF_NAME="main"; GITHUB_SHA="'"$INIT_SHA"'"; RELEASE_MODE="release-patch"' \
  0 "Dry run: verification passed"

# 3. Valid manual release on master branch
git checkout -b master >/dev/null 2>&1
git push origin master >/dev/null 2>&1
MASTER_SHA=$(git rev-parse HEAD)
git checkout main >/dev/null 2>&1

test_release_prep "Valid manual release on master" \
  'TARGET_REF="refs/heads/master"; TARGET_REF_NAME="master"; GITHUB_SHA="'"$MASTER_SHA"'"; RELEASE_MODE="release-patch"' \
  0 "Dry run: verification passed"

# 4. Invalid release branch (feature branch) - MUST BE REJECTED
test_release_prep "Invalid release branch rejected (feature branch)" \
  'TARGET_REF="refs/heads/feature-abc"; TARGET_REF_NAME="feature-abc"; GITHUB_SHA="'"$INIT_SHA"'"; RELEASE_MODE="release-minor"' \
  1 "Manual release preparation must run on refs/heads/main or refs/heads/master"

# 5. Invalid release ref (tag ref) - MUST BE REJECTED
test_release_prep "Invalid release ref rejected (tag ref)" \
  'TARGET_REF="refs/tags/v1.0.0"; TARGET_REF_NAME="v1.0.0"; GITHUB_SHA="'"$INIT_SHA"'"; RELEASE_MODE="release-minor"' \
  1 "Manual release preparation must run on refs/heads/main or refs/heads/master"

# 6. Stale-main rejection: origin/main advances after dispatch
CLONE_TWO="$TEMP_BASE/clone2"
git clone "$BARE_REMOTE" "$CLONE_TWO" >/dev/null 2>&1
(
  cd "$CLONE_TWO"
  git config user.name "Other Dev"
  git config user.email "dev@example.com"
  git config commit.gpgsign false
  git config tag.gpgsign false
  echo "update" >> main.go
  git commit -am "advance main" >/dev/null
  git push origin main >/dev/null 2>&1
)
NEW_MAIN_SHA=$(git rev-parse origin/main)

test_release_prep "Stale-main rejected (origin/main advanced past dispatch SHA)" \
  'TARGET_REF="refs/heads/main"; TARGET_REF_NAME="main"; GITHUB_SHA="'"$INIT_SHA"'"; RELEASE_MODE="release-minor"' \
  1 "Requested release against $INIT_SHA but origin/main is at"

# Update WORK_REPO to current main
cd "$WORK_REPO"
git pull origin main >/dev/null 2>&1
CURRENT_SHA=$(git rev-parse HEAD)

# 7. Valid manual version override
test_release_prep "Valid manual version override (v2.5.0)" \
  'TARGET_REF="refs/heads/main"; TARGET_REF_NAME="main"; GITHUB_SHA="'"$CURRENT_SHA"'"; RELEASE_VERSION_OVERRIDE="v2.5.0"' \
  0 "Calculated TAG=v2.5.0"

# 8. Valid manual version override without leading 'v' (auto-normalized)
test_release_prep "Valid manual version override normalized (3.1.4 -> v3.1.4)" \
  'TARGET_REF="refs/heads/main"; TARGET_REF_NAME="main"; GITHUB_SHA="'"$CURRENT_SHA"'"; RELEASE_VERSION_OVERRIDE="3.1.4"' \
  0 "Calculated TAG=v3.1.4"

# 9. Invalid manual version override format - MUST BE REJECTED
test_release_prep "Invalid manual version override format rejected" \
  'TARGET_REF="refs/heads/main"; TARGET_REF_NAME="main"; GITHUB_SHA="'"$CURRENT_SHA"'"; RELEASE_VERSION_OVERRIDE="not-a-valid-tag"' \
  1 "is not a valid release tag shape"

# 10. Tag collision with matching SHA - safe retry allowed
git tag v2.5.0 "$CURRENT_SHA"
git push origin v2.5.0 >/dev/null 2>&1

test_release_prep "Tag collision with matching SHA (safe retry)" \
  'TARGET_REF="refs/heads/main"; TARGET_REF_NAME="main"; GITHUB_SHA="'"$CURRENT_SHA"'"; RELEASE_VERSION_OVERRIDE="v2.5.0"' \
  0 "Safely retrying publish"

# 11. Tag collision with different SHA - MUST BE REJECTED
# Point remote tag v2.5.0 to INIT_SHA while main is at CURRENT_SHA
git tag -f v2.5.0 "$INIT_SHA" >/dev/null 2>&1
git push -f origin v2.5.0 >/dev/null 2>&1

test_release_prep "Tag collision with different SHA rejected" \
  'TARGET_REF="refs/heads/main"; TARGET_REF_NAME="main"; GITHUB_SHA="'"$CURRENT_SHA"'"; RELEASE_VERSION_OVERRIDE="v2.5.0"' \
  1 "already exists on origin but points to"

# 12. Safety proof: Verify that dry-run mode NEVER creates or pushes tags
REMOTE_TAGS=$(git ls-remote --tags origin | awk '{print $2}' | sort)
EXPECTED_TAGS=$(printf "refs/tags/v1.0.0\nrefs/tags/v2.5.0")
if [[ "$REMOTE_TAGS" == "$EXPECTED_TAGS" ]]; then
  log_pass "Dry-run safety proof: no unintended tags were created or pushed to origin"
else
  log_fail "Dry-run safety proof" "Remote tags were modified! Found: $REMOTE_TAGS"
fi

echo ""
echo "=== Test Summary ==="
echo "Passed: $PASSED_COUNT"
echo "Failed: $FAILED_COUNT"

if [[ "$FAILED_COUNT" -gt 0 ]]; then
  exit 1
fi
echo "All CI routing and release precondition tests passed successfully!"
