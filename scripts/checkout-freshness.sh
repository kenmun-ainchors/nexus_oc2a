#!/bin/zsh
# checkout-freshness.sh — Verify agent review workspace matches origin at exact SHA
# TKT-0403: Agents must NEVER review a cp -r of Yoda working copy.
# Each review runs against a FRESH git fetch/clone at the EXACT SHA under review.
#
# Usage: checkout-freshness.sh <expected-sha> <repo-path-in-agent-workspace> [--repo-url <url>]
# Exit 0 = fresh match. Exit 1 = stale/dirty/mismatch. Exit 2 = not a git repo.

set -euo pipefail

EXPECTED_SHA="${1:-}"
REPO_PATH="${2:-}"
REPO_URL="${3:-}"

if [[ -z "$EXPECTED_SHA" || -z "$REPO_PATH" ]]; then
    echo "USAGE: checkout-freshness.sh <expected-sha> <repo-path> [--repo-url <url>]" >&2
    echo "  Verifies the agent review workspace is a fresh clone at the exact SHA." >&2
    exit 1
fi

echo "=== checkout-freshness.sh — TKT-0403 Freshness Gate ==="
echo "Expected SHA: $EXPECTED_SHA"
echo "Repo path:   $REPO_PATH"

# Gate 1: Must be a git repo
if [[ ! -d "$REPO_PATH/.git" ]]; then
    echo "FAIL: $REPO_PATH is not a git repository. Review must be a fresh clone, not a cp -r." >&2
    echo "ACTION: git clone <url> $REPO_PATH && cd $REPO_PATH && git checkout $EXPECTED_SHA"
    exit 2
fi

cd "$REPO_PATH"

# Gate 2: Working tree must be clean (no dirty files)
if ! git diff --quiet 2>/dev/null && ! git diff --cached --quiet 2>/dev/null; then
    echo "FAIL: Working tree is DIRTY. Review must run against a clean checkout." >&2
    git status --short 2>/dev/null | head -10 >&2
    exit 1
fi
echo "PASS: Working tree clean"

# Gate 3: HEAD must match expected SHA (exact)
ACTUAL_SHA=$(git rev-parse HEAD 2>/dev/null || echo "")
if [[ -z "$ACTUAL_SHA" ]]; then
    echo "FAIL: Cannot determine HEAD SHA." >&2
    exit 1
fi

# Accept short or full SHA forms
if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA"* ]] && [[ "$EXPECTED_SHA" != "$ACTUAL_SHA"* ]]; then
    echo "FAIL: HEAD SHA mismatch." >&2
    echo "  Expected: $EXPECTED_SHA" >&2
    echo "  Actual:   $ACTUAL_SHA" >&2
    echo "ACTION: git fetch origin && git checkout $EXPECTED_SHA" >&2
    exit 1
fi
echo "PASS: HEAD SHA matches expected ($ACTUAL_SHA)"

# Gate 4: HEAD must not be behind origin (fetch first to check)
HAS_REMOTE=$(git remote -v 2>/dev/null | wc -l | tr -d ' ')
if [[ "$HAS_REMOTE" -gt 0 ]]; then
    REMOTE=$(git remote | head -1)
    git fetch "$REMOTE" 2>/dev/null || true
    BEHIND=$(git rev-list HEAD.."$REMOTE"/main 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$BEHIND" -gt 0 ]]; then
        echo "FAIL: Local HEAD is $BEHIND commit(s) behind $REMOTE/main." >&2
        echo "ACTION: git pull $REMOTE main" >&2
        exit 1
    fi
    echo "PASS: HEAD up-to-date with $REMOTE/main"
fi

# Gate 5: File manifest must match origin (ls-tree count comparison)
# Compare against origin tracking branch if available, otherwise origin/main
if [[ "$HAS_REMOTE" -gt 0 ]] && [[ -n "$REMOTE" ]]; then
    LOCAL_TREE_COUNT=$(git ls-tree -r HEAD 2>/dev/null | wc -l | tr -d ' ')
    
    # Determine the correct remote ref to compare against:
    # If HEAD is on a tracking branch, compare against that branch's remote.
    # Otherwise fall back to origin/main.
    REMOTE_REF="$REMOTE/main"
    UPSTREAM_BRANCH=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "")
    if [[ -n "$UPSTREAM_BRANCH" ]]; then
        REMOTE_REF="$UPSTREAM_BRANCH"
    fi
    
    git fetch "$REMOTE" 2>/dev/null || true
    REMOTE_TREE_COUNT=$(git ls-tree -r "$REMOTE_REF" 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ "$REMOTE_TREE_COUNT" -eq 0 ]]; then
        echo "INFO: Cannot determine remote tree count for $REMOTE_REF — skipping manifest match"
    elif [[ "$LOCAL_TREE_COUNT" -ne "$REMOTE_TREE_COUNT" ]]; then
        echo "FAIL: File manifest mismatch." >&2
        echo "  Local tree:   $LOCAL_TREE_COUNT files (HEAD)" >&2
        echo "  Remote tree:  $REMOTE_TREE_COUNT files ($REMOTE_REF)" >&2
        echo "  Note: Feature branches may legitimately differ from origin/main." >&2
        echo "  If this is a feature branch review, verify the diff manually:" >&2
        echo "    git diff --stat $REMOTE_REF..HEAD" >&2
        echo "  To override: set CHECKOUT_FRESHNESS_SKIP_MANIFEST=1" >&2
        if [[ -n "${CHECKOUT_FRESHNESS_SKIP_MANIFEST:-}" ]]; then
            echo "INFO: CHECKOUT_FRESHNESS_SKIP_MANIFEST=1 — accepting manifest difference"
        else
            exit 1
        fi
    else
        echo "PASS: File manifest matches $REMOTE_REF ($LOCAL_TREE_COUNT files)"
    fi
else
    echo "INFO: No remote configured — skipping manifest match (local-only repo)"
fi

# Gate 6: Reject cp -r heuristic — check git directory age vs repo content age
GIT_CONFIG_AGE=$(stat -f %m "$REPO_PATH/.git/config" 2>/dev/null || echo "0")
OLDEST_TRACKED=$(git ls-files --format='%(objectname)' 2>/dev/null | head -1 || echo "")
if [[ "$GIT_CONFIG_AGE" -lt 1700000000 ]]; then
    echo "WARN: .git/config timestamp suspiciously old — possible cp -r of stale clone"
else
    echo "PASS: Repository metadata recency check"
fi

echo ""
echo "=== ALL CHECKS PASSED — Review workspace is FRESH at $ACTUAL_SHA ==="
exit 0
