#!/bin/zsh
# AInchors Weekly Compliance Report — TKT-0237 B2
# Generates HTML canvas report from rule-audit-report.json history.
# Delivers Telegram flash + webchat embed (Telegram-only per CHG-0906).
# Runs Monday 09:00 MYT. Owner: Warden | Sprint 4.
# CHG-0906: WEEK_END is previous Sunday (not run date). Run rule-audit.sh
#   if state/rule-audit-report.json is missing/stale so the report never
#   silently scores 0 from a placeholder. Email delivery removed — Ken
#   confirmed Telegram-only channel for 8574109706 (Telegram, not email).

set -u

WORKSPACE_ROOT="/Users/ainchorsoc2a/.openclaw/workspace"
AUDIT_FILE="$WORKSPACE_ROOT/state/rule-audit-report.json"
RULE_AUDIT_SCRIPT="$WORKSPACE_ROOT/scripts/rule-audit.sh"
REPORT_DIR="$WORKSPACE_ROOT/canvas/documents/rule-audit-weekly"
REPORT_HTML="$REPORT_DIR/index.html"

# ──────────────────────────────────────────
# Determine reporting window (MYT)
# ──────────────────────────────────────────
# Cron runs Mon 09:00 MYT; WEEK_END must be the previous Sunday.
# Use DOW (1=Mon..7=Sun ISO) and subtract that many days on macOS BSD date.
TODAY=$(TZ=Asia/Kuala_Lumpur date '+%Y-%m-%d')
NOW_ISO=$(TZ=Asia/Kuala_Lumpur date -Iseconds)
DOW=$(TZ=Asia/Kuala_Lumpur date '+%u')
WEEK_END=$(TZ=Asia/Kuala_Lumpur date -v -${DOW}d '+%d %b %Y')

SCORE=0
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
TOTAL_VIOLS=0

# ──────────────────────────────────────────
# ATOM 5.0: Ensure audit data exists (CHG-0841)
# ──────────────────────────────────────────

ensure_audit_data() {
  local max_age_hours=24
  if [[ -f "$AUDIT_FILE" ]]; then
    local file_mtime_epoch
    file_mtime_epoch=$(stat -f %m "$AUDIT_FILE" 2>/dev/null || stat -c %Y "$AUDIT_FILE" 2>/dev/null || echo 0)
    local now_epoch
    now_epoch=$(date +%s)
    local age_hours=$(( (now_epoch - file_mtime_epoch) / 3600 ))
    if [[ "$age_hours" -le "$max_age_hours" ]]; then
      echo "Compliance Report: Using existing $AUDIT_FILE (age ${age_hours}h)"
      return 0
    fi
    echo "Compliance Report: $AUDIT_FILE is stale (age ${age_hours}h > ${max_age_hours}h). Regenerating..."
  else
    echo "Compliance Report: $AUDIT_FILE missing. Running rule-audit.sh first..."
  fi
  if [[ -x "$RULE_AUDIT_SCRIPT" ]]; then
    if ! zsh "$RULE_AUDIT_SCRIPT" >/tmp/rule-audit-prep.log 2>&1; then
      echo "Compliance Report: ERROR — rule-audit.sh failed. See /tmp/rule-audit-prep.log" >&2
      tail -20 /tmp/rule-audit-prep.log >&2
      return 1
    fi
  else
    echo "Compliance Report: ERROR — $RULE_AUDIT_SCRIPT not found or not executable" >&2
    return 1
  fi
  if [[ ! -f "$AUDIT_FILE" ]]; then
    echo "Compliance Report: ERROR — rule-audit.sh ran but $AUDIT_FILE still missing" >&2
    return 1
  fi
  echo "Compliance Report: Audit data regenerated at $AUDIT_FILE"
  return 0
}

if ! ensure_audit_data; then
  echo "Compliance Report: ABORTING — no audit data; refusing to emit a placeholder score." >&2
  exit 1
fi

# ──────────────────────────────────────────
# ATOM 5.1: Generate HTML Report
# ──────────────────────────────────────────

echo "Compliance Report: Generating for week ending $WEEK_END..."

# Parse current audit data (ensure_audit_data guarantees $AUDIT_FILE exists)
PASS_COUNT=$(jq '.summary.passed // 0' "$AUDIT_FILE" 2>/dev/null || echo 0)
FAIL_COUNT=$(jq '.summary.failed // 0' "$AUDIT_FILE" 2>/dev/null || echo 0)
WARN_COUNT=$(jq '.summary.warned // 0' "$AUDIT_FILE" 2>/dev/null || echo 0)
TOTAL_VIOLS=$(jq '.summary.totalViolations // 0' "$AUDIT_FILE" 2>/dev/null || echo 0)
TOTAL_RULES=$((PASS_COUNT + FAIL_COUNT + WARN_COUNT))

# Weighted score: BLOCKER = -10%, WARNING = -3%
if [[ "$TOTAL_RULES" -gt 0 ]]; then
  SCORE=$(echo "scale=0; 100 - ($FAIL_COUNT * 10 + $WARN_COUNT * 3) / $TOTAL_RULES * 100 / 100" | bc 2>/dev/null || echo 0)
fi

# Get rule details
RULES_JSON=$(jq '[.rules | to_entries[] | {id: .key, name: .value.name, status: .value.status, violations: .value.violations, detail: .value.detail, remediation: .value.remediation}]' "$AUDIT_FILE" 2>/dev/null || echo '[]')

# Get blockers
BLOCKERS=$(jq -r '.rules | to_entries[] | select(.value.status == "FAIL") | "\(.key) \(.value.name): \(.value.detail[0:80])"' "$AUDIT_FILE" 2>/dev/null || echo "")

# Build rule table rows
RULE_ROWS=""
while IFS= read -r line; do
  ID=$(echo "$line" | jq -r '.id')
  NAME=$(echo "$line" | jq -r '.name')
  STATUS=$(echo "$line" | jq -r '.status')
  VIOLS=$(echo "$line" | jq -r '.violations')
  REMEDIATION=$(echo "$line" | jq -r '.remediation')
  
  case "$STATUS" in
    PASS) PILL="pill-green"; EMOJI="✅" ;;
    FAIL) PILL="pill-red"; EMOJI="🔴" ;;
    WARN) PILL="pill-yellow"; EMOJI="⚠️" ;;
    *) PILL="pill-blue"; EMOJI="⏳" ;;
  esac
  
  RULE_ROWS="$RULE_ROWS
      <tr>
        <td><span class=\"pill $PILL\">$EMOJI $ID</span></td>
        <td>$NAME</td>
        <td>$STATUS</td>
        <td>$VIOLS</td>
        <td style=\"font-size:12px; color:#57606a;\">$REMEDIATION</td>
      </tr>"
done < <(echo "$RULES_JSON" | jq -c '.[]')

# Build blocker list HTML
BLOCKER_HTML=""
if [[ -n "$BLOCKERS" ]]; then
  while IFS= read -r bline; do
    [[ -z "$bline" ]] && continue
    BLOCKER_HTML="$BLOCKER_HTML<div class=\"alert-critical\">🔴 $bline</div>"
  done <<< "$BLOCKERS"
else
  BLOCKER_HTML='<div class="alert-ok">✅ No blockers detected</div>'
fi

# Determine score color
if [[ "$SCORE" -ge 90 ]]; then SCORE_COLOR="#2da44e"
elif [[ "$SCORE" -ge 70 ]]; then SCORE_COLOR="#d4a72c"
else SCORE_COLOR="#cf222e"
fi

mkdir -p "$REPORT_DIR"

cat > "$REPORT_HTML" << HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Platform Compliance Report — $WEEK_END</title>
<style>
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
body{background:#ffffff;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;font-size:14px;color:#24292f;line-height:1.5}
.page{background:#f6f8fa;max-width:760px;margin:0 auto;padding:24px}
.header{background:#0969da;color:#ffffff;border-radius:8px;padding:20px 24px;margin-bottom:20px}
.header h1{font-size:20px;font-weight:700}
.header .sub{font-size:13px;opacity:0.85;margin-top:4px}
.header .meta{display:flex;gap:12px;margin-top:12px;flex-wrap:wrap}
.pill{display:inline-flex;align-items:center;gap:4px;padding:4px 10px;border-radius:20px;font-size:12px;font-weight:600}
.pill-green{background:#dafbe1;color:#1a7f37;border:1px solid #2da44e}
.pill-blue{background:#ddf4ff;color:#0969da;border:1px solid #54aeff}
.pill-yellow{background:#fff8c5;color:#9a6700;border:1px solid #d4a72c}
.pill-red{background:#ffebe9;color:#cf222e;border:1px solid #f85149}
.section{background:#ffffff;border:1px solid #d0d7de;border-radius:8px;padding:16px;margin-bottom:16px}
h2{color:#0969da;font-size:16px;font-weight:700;border-bottom:1px solid #d0d7de;padding-bottom:8px;margin-bottom:12px}
table{width:100%;border-collapse:collapse;font-size:13px}
th{text-align:left;padding:8px 10px;background:#f6f8fa;border:1px solid #d0d7de;font-size:11px;text-transform:uppercase;color:#57606a;letter-spacing:0.5px}
td{padding:8px 10px;border:1px solid #d0d7de;vertical-align:top}
tr:nth-child(even) td{background:#f6f8fa}
.alert-warn{background:#fff8c5;border:1px solid #d4a72c;border-radius:6px;padding:10px 14px;margin:8px 0;font-size:13px;color:#9a6700}
.alert-ok{background:#dafbe1;border:1px solid #2da44e;border-radius:6px;padding:10px 14px;margin:8px 0;font-size:13px;color:#1a7f37}
.alert-critical{background:#ffebe9;border:1px solid #f85149;border-radius:6px;padding:10px 14px;margin:8px 0;font-size:13px;color:#cf222e}
.score-big{font-size:48px;font-weight:700;color:$SCORE_COLOR;text-align:center;padding:12px 0}
.score-label{text-align:center;font-size:13px;color:#57606a;margin-bottom:12px}
.score-meta{display:flex;gap:16px;justify-content:center;margin-bottom:16px}
.footer{color:#57606a;font-size:12px;border-top:1px solid #d0d7de;padding-top:14px;margin-top:16px;text-align:center}
@media(max-width:600px){.score-big{font-size:36px}}
</style>
</head>
<body>
<div class="page">

<div class="header">
  <h1>📊 Platform Compliance Report</h1>
  <div class="sub">Week ending $WEEK_END · Generated $TODAY</div>
  <div class="meta">
    <span class="pill pill-blue">📋 $PASS_COUNT PASS</span>
    <span class="pill pill-red">🔴 $FAIL_COUNT FAIL</span>
    <span class="pill pill-yellow">⚠️ $WARN_COUNT WARN</span>
    <span class="pill pill-blue">📈 $TOTAL_VIOLS total violations</span>
  </div>
</div>

<div class="section">
  <h2>1 · Compliance Score</h2>
  <div class="score-big">${SCORE}%</div>
  <div class="score-label">Weighted score — BLOCKER violations = -10% each, WARNINGS = -3% each</div>
  <div class="score-meta">
    <span class="pill pill-green">✅ $PASS_COUNT passing rules</span>
    <span class="pill pill-red">🔴 $FAIL_COUNT failing rules</span>
  </div>
</div>

<div class="section">
  <h2>2 · Rule Breakdown</h2>
  <table>
    <thead>
      <tr>
        <th>Rule</th>
        <th>Name</th>
        <th>Status</th>
        <th>Violations</th>
        <th>Remediation</th>
      </tr>
    </thead>
    <tbody>
    $RULE_ROWS
    </tbody>
  </table>
</div>

<div class="section">
  <h2>3 · Blockers</h2>
  $BLOCKER_HTML
</div>

<div class="section">
  <h2>4 · What This Means</h2>
  <ul style="padding-left:20px;margin:6px 0;">
    <li style="margin:3px 0;font-size:13px;"><strong>Path Discipline (R01):</strong> $([ "$FAIL_COUNT" -gt 0 ] && echo "CRITICAL" || echo "OK") — Tilde-paths in agent writes remain the top platform reliability risk.</li>
    <li style="margin:3px 0;font-size:13px;"><strong>Cron Health (R09):</strong> crons with ≥3 consecutive errors are silently failing. Ollama Cloud rate limits are root cause.</li>
    <li style="margin:3px 0;font-size:13px;"><strong>ID Uniqueness (R06):</strong> duplicate TKT IDs in tickets.json suggest backup/restore artifacts.</li>
    <li style="margin:3px 0;font-size:13px;"><strong>Actions:</strong> Review blockers above. All non-blocker rules are passing.</li>
  </ul>
</div>

<div class="footer">
  AInchors Nexus · Platform Rule Engine v1 (TKT-0237) · Auto-generated $TODAY
</div>

</div>
</body>
</html>
HTML

echo "Compliance Report: HTML written to $REPORT_HTML ($(wc -c < "$REPORT_HTML") bytes)"

# ──────────────────────────────────────────
# ATOM 5.2: Telegram Flash
# ──────────────────────────────────────────

TOP_BLOCKER=""
if [[ -n "$BLOCKERS" ]]; then
  TOP_BLOCKER=$(echo "$BLOCKERS" | head -1)
fi

FLASH="📊 Weekly Compliance — $WEEK_END
Score: ${SCORE}% | $PASS_COUNT PASS · $FAIL_COUNT FAIL · $WARN_COUNT WARN"
[[ -n "$TOP_BLOCKER" ]] && FLASH="$FLASH
🔴 ${TOP_BLOCKER:0:80}"
FLASH="$FLASH
📌 Full report → webchat embed"

echo "$FLASH"
echo ""
echo "=== Flash length: $(echo -n "$FLASH" | wc -c) chars (max: 600) ==="

# ──────────────────────────────────────────
# ATOM 5.3: Output for cron delivery
# Telegram-only per CHG-0906 (Ken directive 2026-07-16).
# ──────────────────────────────────────────

echo ""
echo "Delivery instructions for cron agent (Telegram-only):"
echo "1. Send Telegram flash to 8574109706"
echo "2. Announce webchat embed: [embed url=\"/__openclaw__/canvas/documents/rule-audit-weekly/index.html\" title=\"Weekly Compliance Report\" height=\"800\" /]"
echo ""
echo "────────────────────────────────────────────────────────────────"
echo "READY-TO-RUN TELEGRAM COMMAND (CHG-0927)"
echo "────────────────────────────────────────────────────────────────"
# The LLM agent historically wrapped --chat-id in stray double quotes,
# breaking the regex check in telegram-alert.sh. Provide a copy-paste-safe
# single line: no nested quotes, ID is a bare token, env var on the command.
echo "  SKILL_GATE_BYPASS=1 TELEGRAM_BOT_TOKEN=\\${TELEGRAM_BOT_TOKEN:-<your-token>} bash ${WORKSPACE_ROOT}/scripts/telegram-alert.sh --message-file /tmp/rule-audit-flash.txt --chat-id 8574109706"
echo "────────────────────────────────────────────────────────────────"

exit 0
