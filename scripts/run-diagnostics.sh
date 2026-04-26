#!/bin/zsh
# AInchors Run Diagnostics — comprehensive, deep, slow inspection
# Trigger: explicit only (Ken /diagnostics or manual). NEVER automated.
# Output: state/diagnostics-YYYY-MM-DD-HHMM.json + reports/diagnostics-YYYY-MM-DD-HHMM.md
#
# Phases:
#   1. Pre-flight inventory
#   2. Provider chain ping (Anthropic, Opus, Gemma4)
#   3. Integration tests (Notion, Telegram, Obsidian, Memory)
#   4. Auto-heal dry-run snapshot (read what's there)
#   5. Security audit
#   6. HA readiness checklist (placeholders for OC2)
#
# Recovery drills (phase 4 in plan) deferred — too risky to simulate without isolation.

set -u

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
STATE_DIR="$WORKSPACE/state"
REPORTS_DIR="$WORKSPACE/reports"
mkdir -p "$STATE_DIR" "$REPORTS_DIR"

STAMP=$(date '+%Y-%m-%d-%H%M')
TODAY=$(date '+%Y-%m-%d')
NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
NOW_LOCAL=$(date '+%Y-%m-%d %H:%M %Z')

JSON_OUT="$STATE_DIR/diagnostics-${STAMP}.json"
MD_OUT="$REPORTS_DIR/diagnostics-${STAMP}.md"
LOG="$STATE_DIR/diagnostics-${STAMP}.log"

typeset -a PHASES_RUN
typeset -a PASS
typeset -a FAIL
typeset -a WARN

log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG"; }
phase() { log ""; log "═══ PHASE: $1 ═══"; PHASES_RUN+=("$1"); }
pass() { PASS+=("$1"); log "  ✓ PASS: $1"; }
fail() { FAIL+=("$1"); log "  ✗ FAIL: $1"; }
warn() { WARN+=("$1"); log "  ⚠ WARN: $1"; }

log "═══════════════════════════════════════════"
log "  AInchors RUN DIAGNOSTICS"
log "  Started: $NOW_LOCAL"
log "  Report:  $MD_OUT"
log "═══════════════════════════════════════════"

# ────────────────────────── PHASE 1: PRE-FLIGHT INVENTORY ──────────────────────────
phase "1. Pre-flight Inventory"

# OpenClaw + agent
OPENCLAW_VER=$(openclaw --version 2>&1 | head -1 || echo "?")
log "  OpenClaw version: $OPENCLAW_VER"
[[ "$OPENCLAW_VER" != "?" ]] && pass "openclaw cli responsive" || fail "openclaw cli unresponsive"

# Config hashes
CFG_HASH=$(shasum -a 256 "$HOME/.openclaw/openclaw.json" 2>/dev/null | awk '{print $1}')
log "  openclaw.json hash: ${CFG_HASH:0:16}…"

LAST_GOOD_HASH=$(shasum -a 256 "$HOME/.openclaw/openclaw.json.last-good" 2>/dev/null | awk '{print $1}')
if [[ "$CFG_HASH" == "$LAST_GOOD_HASH" ]]; then
  pass "openclaw.json matches last-good"
else
  warn "openclaw.json differs from last-good (may be intentional)"
fi

# Cron count
CRON_COUNT=$(jq '. | length' "$HOME/.openclaw/cron/jobs.json" 2>/dev/null || echo 0)
log "  Cron jobs: $CRON_COUNT"
(( CRON_COUNT >= 5 )) && pass "cron jobs registered ($CRON_COUNT)" || fail "low cron count ($CRON_COUNT)"

# State files
STATE_COUNT=$(ls "$STATE_DIR"/*.json 2>/dev/null | wc -l | tr -d ' ')
log "  State files: $STATE_COUNT"

# Scripts
SCRIPT_COUNT=$(ls "$WORKSPACE/scripts/" 2>/dev/null | wc -l | tr -d ' ')
log "  Scripts: $SCRIPT_COUNT"

# Memory index
MEM_FILES=$(ls "$WORKSPACE/memory/"*.md "$WORKSPACE/memory/shared/"*.md 2>/dev/null | wc -l | tr -d ' ')
log "  Memory files: $MEM_FILES"

# Secrets
KEYCHAIN_KEYS=()
for k in anthropic-api-key notion-api-key telegram-bot-token; do
  if security find-generic-password -s "$k" > /dev/null 2>&1; then
    KEYCHAIN_KEYS+=("$k")
    pass "keychain: $k present"
  else
    warn "keychain: $k missing"
  fi
done

# ────────────────────────── PHASE 2: PROVIDER CHAIN PING ──────────────────────────
phase "2. Provider Chain Ping"

# Anthropic — use a 3-token test via curl with stored key
ANTHROPIC_KEY=$(security find-generic-password -s anthropic-api-key -w 2>/dev/null || echo "")
if [[ -n "$ANTHROPIC_KEY" ]]; then
  RESP=$(curl -sS -m 30 https://api.anthropic.com/v1/messages \
    -H "x-api-key: $ANTHROPIC_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d '{"model":"claude-sonnet-4-5","max_tokens":10,"messages":[{"role":"user","content":"hi"}]}' 2>&1)
  if echo "$RESP" | jq -e '.content' > /dev/null 2>&1; then
    pass "anthropic api: sonnet ping ok"
  else
    fail "anthropic api: sonnet ping failed — $(echo "$RESP" | head -c 200)"
  fi
else
  warn "anthropic api: no keychain key, skipped"
fi

# Ollama
OLLAMA_RESP=$(curl -sS -m 5 http://127.0.0.1:11434/api/tags 2>&1)
if echo "$OLLAMA_RESP" | jq -e '.models' > /dev/null 2>&1; then
  pass "ollama: api responsive"
  if echo "$OLLAMA_RESP" | jq -e '.models[] | select(.name | contains("gemma4"))' > /dev/null 2>&1; then
    pass "ollama: gemma4 model loaded"
  else
    fail "ollama: gemma4 model NOT loaded"
  fi
else
  fail "ollama: api unresponsive"
fi

# Gateway
GW_RESP=$(curl -sS -m 5 http://127.0.0.1:18789/healthz 2>&1)
if [[ -n "$GW_RESP" ]]; then
  pass "gateway: responsive (loopback)"
else
  warn "gateway: /healthz didn't respond (may be expected — try /)"
fi

# ────────────────────────── PHASE 3: INTEGRATION TESTS ──────────────────────────
phase "3. Integration Tests"

# Notion — read database
NOTION_KEY=$(cat "$HOME/.config/notion/api_key" 2>/dev/null || security find-generic-password -s notion-api-key -w 2>/dev/null || echo "")
if [[ -n "$NOTION_KEY" ]]; then
  N_RESP=$(curl -sS -m 10 -X GET "https://api.notion.com/v1/databases/34dc182953ff814b8257d3a3bf351d44" \
    -H "Authorization: Bearer $NOTION_KEY" -H "Notion-Version: 2022-06-28" 2>&1)
  if echo "$N_RESP" | jq -e '.id' > /dev/null 2>&1; then
    pass "notion api: backlog db read ok"
  else
    fail "notion api: read failed"
  fi
else
  warn "notion api: no key found"
fi

# Telegram bot
TG_TOKEN=$(security find-generic-password -s telegram-bot-token -w 2>/dev/null || echo "")
if [[ -n "$TG_TOKEN" ]]; then
  TG_RESP=$(curl -sS -m 10 "https://api.telegram.org/bot${TG_TOKEN}/getMe" 2>&1)
  if echo "$TG_RESP" | jq -e '.result.username' > /dev/null 2>&1; then
    BOT_NAME=$(echo "$TG_RESP" | jq -r '.result.username')
    pass "telegram bot: @${BOT_NAME} responsive"
  else
    fail "telegram bot: getMe failed"
  fi
else
  warn "telegram bot: no token in keychain"
fi

# Obsidian git
if (cd "$HOME/Documents/AInchors" 2>/dev/null && git status > /dev/null 2>&1); then
  DIRTY=$(cd "$HOME/Documents/AInchors" && git status --porcelain | wc -l | tr -d ' ')
  if (( DIRTY == 0 )); then
    pass "obsidian vault: clean git state"
  else
    warn "obsidian vault: $DIRTY uncommitted changes"
  fi
else
  fail "obsidian vault: git not initialised"
fi

# Workspace git
if (cd "$WORKSPACE" 2>/dev/null && git status > /dev/null 2>&1); then
  DIRTY=$(cd "$WORKSPACE" && git status --porcelain | wc -l | tr -d ' ')
  if (( DIRTY == 0 )); then
    pass "workspace: clean git state"
  else
    warn "workspace: $DIRTY uncommitted changes"
  fi
else
  fail "workspace: git not initialised"
fi

# ────────────────────────── PHASE 4: AUTO-HEAL DRY-RUN ──────────────────────────
phase "4. Auto-Heal Snapshot (read latest report)"

LATEST_AH=$(ls -t "$STATE_DIR"/auto-heal-*.json 2>/dev/null | head -1)
if [[ -n "$LATEST_AH" ]]; then
  AH_DATE=$(basename "$LATEST_AH" .json | sed 's/auto-heal-//')
  AH_ISSUES=$(jq -r '.issues_count // 0' "$LATEST_AH")
  AH_FIXED=$(jq -r '.auto_fixed_count // 0' "$LATEST_AH")
  AH_NEEDS=$(jq -r '.needs_ken_count // 0' "$LATEST_AH")
  log "  Latest auto-heal: $AH_DATE | issues=$AH_ISSUES | fixed=$AH_FIXED | needs-ken=$AH_NEEDS"
  if (( AH_NEEDS == 0 )); then
    pass "auto-heal latest run clean"
  else
    warn "auto-heal latest run has $AH_NEEDS needs-ken items"
  fi
else
  warn "auto-heal: no run yet (first scheduled tonight 23:30)"
fi

# ────────────────────────── PHASE 5: SECURITY AUDIT ──────────────────────────
phase "5. Security Audit"

SEC_OUT=$(openclaw security audit 2>&1 | head -50)
if echo "$SEC_OUT" | grep -qi "critical"; then
  CRIT_COUNT=$(echo "$SEC_OUT" | grep -ci "critical" || echo 0)
  warn "security: $CRIT_COUNT critical findings (review report)"
fi
if echo "$SEC_OUT" | grep -qi "warn"; then
  pass "security audit: completed"
fi

# Plaintext secret scan
PLAINTEXT=$(grep -rE "sk-(ant|test|live)-[A-Za-z0-9_-]{30,}" "$HOME/.openclaw/" "$WORKSPACE" "$HOME/Documents/AInchors" 2>/dev/null | grep -v "auth-profiles.json" | grep -v ".bak" | grep -v "session" | head -5 || echo "")
if [[ -z "$PLAINTEXT" ]]; then
  pass "no plaintext API keys found in tracked dirs"
else
  fail "plaintext API key pattern found: $(echo "$PLAINTEXT" | head -1)"
fi

# Public canvas PII scan
PII_HITS=$(grep -rE "B[0-9A-Z]{7}|sk-ant-|[0-9]{10,}" "$HOME/.openclaw/canvas/documents/" 2>/dev/null | head -3 || echo "")
if [[ -z "$PII_HITS" ]]; then
  pass "canvas/blogs: no obvious PII patterns"
else
  warn "canvas: possible PII — manual review needed"
fi

# ────────────────────────── PHASE 6: HA READINESS (placeholder for OC2) ──────────────────────────
phase "6. HA Readiness (OC2 prep)"

log "  OC2 not yet online — placeholder checks:"
[[ -f "$HOME/Documents/AInchors/Operations/MigrationGuide.md" ]] && pass "migration guide exists" || warn "migration guide missing"
[[ -f "$HOME/Documents/AInchors/Agents/DualInstanceArchitecture.md" ]] && pass "dual-instance architecture documented" || warn "dual-instance arch missing"

TS_STATUS=$(tailscale status 2>&1 | head -1 || echo "not-installed")
if echo "$TS_STATUS" | grep -qi "logged out\|not-installed\|stopped"; then
  warn "tailscale: not active (deferred to Phase 3 per plan)"
else
  pass "tailscale: active"
fi

# ────────────────────────── REPORT GENERATION ──────────────────────────
log ""
log "═══ DIAGNOSTICS COMPLETE ═══"
log "  Phases: ${#PHASES_RUN[@]}"
log "  Pass:   ${#PASS[@]}"
log "  Warn:   ${#WARN[@]}"
log "  Fail:   ${#FAIL[@]}"

# JSON
phases_json=$(printf '%s\n' "${PHASES_RUN[@]}" | jq -R . | jq -s .)
pass_json=$(printf '%s\n' "${PASS[@]}" | jq -R . | jq -s 'map(select(length > 0))')
warn_json=$(printf '%s\n' "${WARN[@]}" | jq -R . | jq -s 'map(select(length > 0))')
fail_json=$(printf '%s\n' "${FAIL[@]}" | jq -R . | jq -s 'map(select(length > 0))')

cat > "$JSON_OUT" <<EOF
{
  "stamp": "$STAMP",
  "runAt": "$NOW",
  "runAtLocal": "$NOW_LOCAL",
  "phases": $phases_json,
  "pass": $pass_json,
  "warn": $warn_json,
  "fail": $fail_json,
  "summary": {
    "phases_count": ${#PHASES_RUN[@]},
    "pass_count": ${#PASS[@]},
    "warn_count": ${#WARN[@]},
    "fail_count": ${#FAIL[@]},
    "verdict": "$( (( ${#FAIL[@]} == 0 )) && echo HEALTHY || echo ATTENTION_NEEDED )"
  }
}
EOF

# Markdown report
{
  echo "# AInchors Diagnostics Report"
  echo "_Run: $NOW_LOCAL | Stamp: $STAMP_"
  echo ""
  echo "## Verdict"
  if (( ${#FAIL[@]} == 0 )); then
    echo "✅ **HEALTHY** — no failures detected."
  else
    echo "🚨 **ATTENTION NEEDED** — ${#FAIL[@]} failures."
  fi
  echo ""
  echo "**Summary:** ${#PASS[@]} pass · ${#WARN[@]} warn · ${#FAIL[@]} fail across ${#PHASES_RUN[@]} phases."
  echo ""
  if (( ${#FAIL[@]} > 0 )); then
    echo "## ❌ Failures"
    for f in "${FAIL[@]}"; do echo "- $f"; done
    echo ""
  fi
  if (( ${#WARN[@]} > 0 )); then
    echo "## ⚠️ Warnings"
    for w in "${WARN[@]}"; do echo "- $w"; done
    echo ""
  fi
  echo "## ✅ Passes"
  for p in "${PASS[@]}"; do echo "- $p"; done
  echo ""
  echo "## Phases Run"
  for ph in "${PHASES_RUN[@]}"; do echo "- $ph"; done
  echo ""
  echo "## Files"
  echo "- JSON: \`$JSON_OUT\`"
  echo "- Log:  \`$LOG\`"
} > "$MD_OUT"

log "Markdown report: $MD_OUT"
log "JSON report:     $JSON_OUT"

# Exit code reflects failures
(( ${#FAIL[@]} > 0 )) && exit 2 || exit 0
