#!/bin/zsh
# check-delegated-auth.sh — Pre-flight check for delegated gog auth tokens
# TKT-0336: Proactive detection of expired delegated tokens before Angie hits failure
# 
# Usage: check-delegated-auth.sh [--json]
#   --json    Output as JSON to state/delegated-auth-status.json
#   (no flag) Human-readable output
#
# Exit codes: 0 = all tokens valid | 1 = tokens expired (needs re-auth) | 2 = gog not available
#
# This is the second auth expiry for Angie in as many weeks. The fix is pre-flight
# detection — check tokens before they're needed, surface expired ones so Angie
# can re-auth proactively rather than hitting the failure at runtime.

set -euo pipefail

WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
STATE_DIR="$WORKSPACE/state"
# Resolve gog binary (migration 2026-07-14): prefer PATH, fall back to /opt/homebrew
GOG="$(command -v gog 2>/dev/null || true)"
if [[ -z "$GOG" && -x "/opt/homebrew/bin/gog" ]]; then
  GOG="/opt/homebrew/bin/gog"
fi
OUTPUT_JSON=false
[[ "${1:-}" == "--json" ]] && OUTPUT_JSON=true

# ---- ACCOUNTS TO CHECK ----
# Format: "email:label:services"
# Add new delegated accounts here as they're onboarded
DELEGATED_ACCOUNTS=(
  "kenmun@ainchors.com:Ken Mun (CTO):gmail,calendar,drive,contacts,sheets,docs"
  "angie.foong@ainchors.com:Angie Foong (CEO):calendar,gmail"
)

# ---- STATE ----
TODAY=$(TZ="Asia/Kuala_Lumpur" date '+%Y-%m-%d')
NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
RESULTS=()
HAS_EXPIRED=false

# ---- CHECK GOG AVAILABILITY ----
# Migration 2026-07-14: if gog is missing, report a clear status (not hard-fail exit 2)
if [[ -z "$GOG" || ! -x "$GOG" ]]; then
  if $OUTPUT_JSON; then
    echo "{\"allValid\":false,\"accounts\":[],\"missingBinary\":\"gog\",\"note\":\"gog binary not found; re-auth/install required\"}"
    exit 0
  fi
  echo "ERROR: gog binary not found (checked PATH and /opt/homebrew/bin/gog)" >&2
  # Human-readable mode: clear status, not a hard crash
  exit 1
fi

# ---- CHECK EACH ACCOUNT ----
for entry in "${DELEGATED_ACCOUNTS[@]}"; do
  IFS=':' read -r email label services <<< "$entry"
  
  # Quick test: list auth and check if this account is present + valid
  AUTH_OUTPUT=$("$GOG" auth list 2>&1) || true
  
  if echo "$AUTH_OUTPUT" | grep -q "$email"; then
    # Token exists. Test with a lightweight calendar query (non-destructive)
    # Use --max 1 to minimize API cost; we just need to confirm the token works
    CAL_TEST=$("$GOG" calendar events primary --from "$TODAY" --to "$TODAY" --max 1 --account "$email" 2>&1) || true
    
    if echo "$CAL_TEST" | grep -qi "auth\|expired\|unauthorized\|invalid.*token\|refresh.*fail"; then
      RESULTS+=("EXPIRED:$email:$label:$services — token exists but refresh failed")
      HAS_EXPIRED=true
    elif echo "$CAL_TEST" | grep -qi "error"; then
      # Non-auth error — token may be OK, service issue
      RESULTS+=("WARN:$email:$label:$services — token valid but API error: ${CAL_TEST:0:120}")
    else
      RESULTS+=("OK:$email:$label:$services — token valid")
    fi
  else
    RESULTS+=("MISSING:$email:$label:$services — no auth configured")
    HAS_EXPIRED=true
  fi
done

# ---- OUTPUT ----
if $OUTPUT_JSON; then
  # Build JSON report
  # Use $(...) command substitution to strip trailing newlines from grep -c output,
  # otherwise the heredoc inserts them as broken multi-line numbers in the JSON.
  # Fallback to 0 if no matches (grep -c returns "0" with exit 1, which `|| true` covers).
  OK_COUNT=$(printf '%s\n' "${RESULTS[@]}" | { grep -c "^OK:" || true; } | tr -d '\n')
  EXPIRED_COUNT=$(printf '%s\n' "${RESULTS[@]}" | { grep -c "^EXPIRED:" || true; } | tr -d '\n')
  MISSING_COUNT=$(printf '%s\n' "${RESULTS[@]}" | { grep -c "^MISSING:" || true; } | tr -d '\n')
  WARN_COUNT=$(printf '%s\n' "${RESULTS[@]}" | { grep -c "^WARN:" || true; } | tr -d '\n')
  
  cat > "$STATE_DIR/delegated-auth-status.json" <<EOJ
{
  "checkedAt": "$NOW",
  "checkedDate": "$TODAY",
  "okCount": $OK_COUNT,
  "expiredCount": $EXPIRED_COUNT,
  "missingCount": $MISSING_COUNT,
  "warnCount": $WARN_COUNT,
  "allValid": $([ "$HAS_EXPIRED" = false ] && echo "true" || echo "false"),
  "accounts": [
EOJ
  
  FIRST=true
  for result in "${RESULTS[@]}"; do
    IFS=':' read -r _st email label services detail <<< "$result"
    $FIRST || echo "," >> "$STATE_DIR/delegated-auth-status.json"
    FIRST=false
    cat >> "$STATE_DIR/delegated-auth-status.json" <<EOR
    {
      "email": "$email",
      "label": "$label",
      "services": "$services",
      "status": "$_st",
      "detail": "$detail"
    }
EOR
  done
  
  echo -e "\n  ]\n}" >> "$STATE_DIR/delegated-auth-status.json"
  # Pretty-print in place
  python3 -c "import json; d=json.load(open('$STATE_DIR/delegated-auth-status.json')); json.dump(d, open('$STATE_DIR/delegated-auth-status.json','w'), indent=2)" 2>/dev/null || true
else
  # Human-readable output
  echo "=== Delegated Auth Status — $TODAY ==="
  echo ""
  for result in "${RESULTS[@]}"; do
    IFS=':' read -r _st _email _label _services _detail <<< "$result"
    case "$_st" in
      OK)      echo "✅ $_label ($_email) — $_detail" ;;
      EXPIRED) echo "❌ $_label ($_email) — $_detail" ;;
      MISSING) echo "⚠️  $_label ($_email) — $_detail" ;;
      WARN)    echo "⚠️  $_label ($_email) — $_detail" ;;
    esac
  done
  echo ""
  if $HAS_EXPIRED; then
    echo "🔴 ACTION REQUIRED: Expired/missing tokens detected. Re-auth needed."
    echo ""
    for result in "${RESULTS[@]}"; do
      if echo "$result" | grep -qE "^(EXPIRED|MISSING):"; then
        IFS=':' read -r _st _email _label _services _detail <<< "$result"
        echo "   gog auth add $_email --services $_services"
      fi
    done
  else
    echo "✅ All delegated auth tokens valid."
  fi
fi

$HAS_EXPIRED && exit 1 || exit 0
