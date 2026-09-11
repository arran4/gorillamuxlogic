#!/usr/bin/env bash
set -euo pipefail

TARGET_REF="${TARGET_REF:-${GITHUB_REF:-}}"
TARGET_REF_NAME="${TARGET_REF_NAME:-${GITHUB_REF_NAME:-}}"
GITHUB_SHA="${GITHUB_SHA:-$(git rev-parse HEAD)}"
RELEASE_MODE="${RELEASE_MODE:-}"
RELEASE_VERSION_OVERRIDE="${RELEASE_VERSION_OVERRIDE:-}"
DRY_RUN="${DRY_RUN:-false}"
REMOTE="${REMOTE:-${GIT_REMOTE:-origin}}"

# 1. Verify target branch / ref
DEFAULT_BRANCH=""
if [[ "$TARGET_REF" == "refs/heads/main" || "$TARGET_REF_NAME" == "main" ]]; then
  if [[ "$TARGET_REF" == "refs/heads/main" || -z "$TARGET_REF" || "$TARGET_REF" == "main" ]]; then
    DEFAULT_BRANCH="main"
  fi
elif [[ "$TARGET_REF" == "refs/heads/master" || "$TARGET_REF_NAME" == "master" ]]; then
  if [[ "$TARGET_REF" == "refs/heads/master" || -z "$TARGET_REF" || "$TARGET_REF" == "master" ]]; then
    DEFAULT_BRANCH="master"
  fi
fi

if [[ -z "$DEFAULT_BRANCH" ]]; then
  REF_DISPLAY="${TARGET_REF:-${TARGET_REF_NAME:-unknown}}"
  echo "Error: Manual release preparation must run on refs/heads/main or refs/heads/master, got $REF_DISPLAY" >&2
  exit 1
fi

# 2. Verify current commit SHA against remote default branch
git fetch "$REMOTE" "$DEFAULT_BRANCH"
MAIN_SHA=$(git rev-parse "$REMOTE/$DEFAULT_BRANCH")
if [[ "$MAIN_SHA" != "$GITHUB_SHA" ]]; then
  echo "Error: Requested release against $GITHUB_SHA but $REMOTE/$DEFAULT_BRANCH is at $MAIN_SHA" >&2
  exit 1
fi

# 3. Calculate or explicitly set version
export PATH="$(go env GOPATH 2>/dev/null || true)/bin:$HOME/bin:$PATH"

if [[ -n "${RELEASE_VERSION_OVERRIDE:-}" ]]; then
  TAG="${RELEASE_VERSION_OVERRIDE#v}"
  TAG="v${TAG}"
  echo "Using manual version override: $TAG"
  if ! [[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
    echo "Error: Override $TAG is not a valid release tag shape." >&2
    exit 1
  fi
else
  echo "Using arran4/git-tag-inc..."
  case "${RELEASE_MODE:-}" in
    release-major) level="major"; suffix="" ;;
    release-minor) level="minor"; suffix="" ;;
    release-patch) level="patch"; suffix="" ;;
    release-test)  level="patch"; suffix="test" ;;
    release-rc)    level="patch"; suffix="rc" ;;
    release-alpha) level="patch"; suffix="alpha" ;;
    *)
      echo "Error: Unsupported release mode: ${RELEASE_MODE:-}" >&2
      exit 1
      ;;
  esac
  args=(--print-version-only "$level")
  [[ -n "$suffix" ]] && args+=("$suffix")
  TAG="$(git-tag-inc "${args[@]}")"
fi

echo "Calculated TAG=$TAG"

if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "TAG=$TAG" >> "$GITHUB_ENV"
fi

# 4. Check remote state for idempotency / retry
REMOTE_SHA=$(git ls-remote --tags "$REMOTE" "refs/tags/$TAG" | grep -v '{}$' | awk '{print $1}' || true)
PEELED_SHA=$(git ls-remote --tags "$REMOTE" "refs/tags/$TAG^{}" | awk '{print $1}' || true)
if [[ -n "$PEELED_SHA" ]]; then
  REMOTE_SHA="$PEELED_SHA"
fi

if [[ -n "$REMOTE_SHA" ]]; then
  if [[ "$REMOTE_SHA" == "$GITHUB_SHA" ]]; then
    echo "Tag $TAG already exists on $REMOTE and points to correct SHA ($GITHUB_SHA). Safely retrying publish."
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "Dry run: verification passed (idempotent retry). No tag created or pushed."
      exit 0
    fi
    gh workflow run ci.yml --ref "$TAG" -f mode=publish-tag
    exit 0
  else
    echo "Error: Tag $TAG already exists on $REMOTE but points to $REMOTE_SHA, not expected $GITHUB_SHA." >&2
    exit 1
  fi
fi

# 5. Pre-tag race guard: verify remote default branch is STILL exactly GITHUB_SHA
git fetch "$REMOTE" "$DEFAULT_BRANCH"
CURRENT_MAIN_SHA=$(git rev-parse "$REMOTE/$DEFAULT_BRANCH")
if [[ "$CURRENT_MAIN_SHA" != "$GITHUB_SHA" ]]; then
  echo "Error: Race condition: $REMOTE/$DEFAULT_BRANCH advanced to $CURRENT_MAIN_SHA before tagging" >&2
  exit 1
fi

# 6. Dry run check: ensure dry-run mode never creates tags, pushes, or dispatches
if [[ "$DRY_RUN" == "true" ]]; then
  echo "Dry run: verification passed. Tag $TAG would be created and pushed for $GITHUB_SHA on $DEFAULT_BRANCH."
  exit 0
fi

# 7. Create tag, push, and dispatch publisher
git tag -d "$TAG" 2>/dev/null || true
git tag "$TAG"
git push "$REMOTE" "$TAG" || {
  REMOTE_SHA=$(git ls-remote --tags "$REMOTE" "$TAG" | awk '{print $1}')
  if [[ "$REMOTE_SHA" != "$GITHUB_SHA" ]]; then
    echo "Error: Race condition: tag pushed remotely with different SHA ($REMOTE_SHA)" >&2
    exit 1
  fi
}

echo "Dispatching publisher for tag $TAG..."
gh workflow run ci.yml --ref "$TAG" -f mode=publish-tag
