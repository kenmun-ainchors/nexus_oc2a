#!/usr/bin/env bash
# standup-composer.sh
# Rich-content composer for stand-up sections 2, 5, 6, 7.
# Collects real sources from Aria brief, journals, CHANGELOG, state files,
# then invokes OpenClaw model routing for LLM composition.
# Output: .openclaw/tmp/standup-composer-input.json
# On failure: writes degraded-composer JSON and exits non-zero.
# Does NOT call Ollama HTTP API directly — uses openclaw agent --agent infra (gateway mode).

set -euo pipefail

WORKSPACE="${WORKSPACE:-/Users/ainchorsoc2a/.openclaw/workspace}"
TMP_DIR="${WORKSPACE}/.openclaw/tmp"
OUTPUT_FILE="${TMP_DIR}/standup-composer-input.json"
PROMPT_FILE="${TMP_DIR}/standup-prompt-$(date +%Y%m%d).txt"
mkdir -p "$TMP_DIR"

my_date=$(TZ=Asia/Kuala_Lumpur date '+%Y-%m-%d')
my_daynum=$(python3 -c "
from datetime import datetime, timezone, timedelta
start = datetime(2026, 4, 25).date()
d = datetime.now(timezone.utc).astimezone(timezone(timedelta(hours=8))).date()
print((d - start).days + 1)
")
yesterday_date=$(TZ=Asia/Kuala_Lumpur date -v-1d '+%Y-%m-%d')
yesterday_daynum=$(python3 -c "
from datetime import datetime, timezone, timedelta
start = datetime(2026, 4, 25).date()
d = datetime.now(timezone.utc).astimezone(timezone(timedelta(hours=8))).date() - timedelta(days=1)
print((d - start).days + 1)
")

# ── Helper: safe read with truncation ────────────────────────────────────────
safe_head() {
    local file="$1" max_bytes="${2:-30000}"
    if [[ -f "$file" ]]; then
        head -c "$max_bytes" "$file"
    fi
}

safe_json() {
    local file="$1"
    if [[ -f "$file" ]]; then
        cat "$file" 2>/dev/null || echo "{}"
    else
        echo "{}"
    fi
}

# ── Collect context sources ──────────────────────────────────────────────────
CONTEXT=""
CONTEXT+="## Context: yesterday's date\n"
CONTEXT+="Yesterday: ${yesterday_date} (Day ${yesterday_daynum})\n"
CONTEXT+="Today: ${my_date} (Day ${my_daynum})\n\n"

# 1. Aria daily brief — full file, top entry is most recent day
CONTEXT+="## Aria Daily Brief\n"
if [[ -f "${WORKSPACE}/state/aria-daily-brief.md" ]]; then
    # Get the most recent day entries (first ~40K chars)
    CONTEXT+="$(safe_head "${WORKSPACE}/state/aria-daily-brief.md" 40000)\n\n"
else
    CONTEXT+="NOT FOUND\n\n"
fi

# 2. Journal entries for last 3 calendar days
for day in "$my_date" "$yesterday_date" "$(TZ=Asia/Kuala_Lumpur date -v-2d '+%Y-%m-%d')"; do
    jfile="${WORKSPACE}/memory/journal-${day}.md"
    if [[ -f "$jfile" ]]; then
        CONTEXT+="## Journal ${day}\n$(safe_head "$jfile" 15000)\n\n"
    fi
done

# 3. Daily memory files for last 3 calendar days
for day in "$my_date" "$yesterday_date" "$(TZ=Asia/Kuala_Lumpur date -v-2d '+%Y-%m-%d')"; do
    mfile="${WORKSPACE}/memory/${day}.md"
    if [[ -f "$mfile" ]]; then
        CONTEXT+="## Daily Memory ${day}\n$(safe_head "$mfile" 15000)\n\n"
    fi
done

# 4. CHANGELOG — last 200 lines, but extract CHG descriptions
CONTEXT+="## Recent CHANGELOG entries (CHG summaries)\n"
if [[ -f "${WORKSPACE}/memory/CHANGELOG.md" ]]; then
    # Get last 200 lines
    tail_lines=$(tail -200 "${WORKSPACE}/memory/CHANGELOG.md" 2>/dev/null || true)
    # Extract CHG lines and What changed lines
    chg_summary=$(echo "$tail_lines" | grep -E '^## 20.*\[CHG-' | head -15 || true)
    what_changed=$(echo "$tail_lines" | grep -E '^\*\*What changed:\*\*' | head -15 || true)
    CONTEXT+="## CHG headers:\n${chg_summary}\n\n## What changed:\n${what_changed}\n\n"
fi

# 5. Sprint state
CONTEXT+="## Sprint State\n$(safe_json "${WORKSPACE}/state/sprint-current.json")\n\n"

# 6. Open decisions (if exists)
CONTEXT+="## Open Decisions\n"
if [[ -f "${WORKSPACE}/state/open-decisions.json" ]]; then
    CONTEXT+="$(safe_head "${WORKSPACE}/state/open-decisions.json" 8000)\n\n"
else
    CONTEXT+="(none — file not found)\n\n"
fi

# 7. Frameworks maturity (if exists)
CONTEXT+="## Frameworks Maturity\n"
if [[ -f "${WORKSPACE}/state/frameworks-maturity.json" ]]; then
    CONTEXT+="$(safe_head "${WORKSPACE}/state/frameworks-maturity.json" 8000)\n\n"
else
    CONTEXT+="(none — file not found)\n\n"
fi

# 8. Auto-heal state (yesterday's NEEDS_KEN summary)
CONTEXT+="## Auto-Heal State\n"
if [[ -f "${WORKSPACE}/state/auto-heal-state.json" ]]; then
    CONTEXT+="$(safe_head "${WORKSPACE}/state/auto-heal-state.json" 8000)\n\n"
else
    CONTEXT+="(file not found)\n\n"
fi

# 9. Daily note
CONTEXT+="## Daily Note\n$(safe_json "${WORKSPACE}/state/daily-note.json")\n\n"

# 10. Health state
CONTEXT+="## Health State\n$(safe_json "${WORKSPACE}/state/health-state.json")\n\n"

# 11. Cost state — just summary
CONTEXT+="## Cost State (summary)\n"
if [[ -f "${WORKSPACE}/state/cost-state.json" ]]; then
    cost_summary=$(python3 -c "
import json
try:
    d = json.load(open('${WORKSPACE}/state/cost-state.json'))
    h = d.get('history', {})
    dates = sorted(h.keys())[-3:] if h else []
    total = sum(h[dt].get('totalCostEstimate', 0) for dt in dates) if h else 0
    bal = d.get('confirmedBalance', d.get('apiBalance', {}).get('remainingEstimate', 0))
    print(json.dumps({'lastThreeDaysTotal': round(total,2), 'balance': bal}))
except Exception:
    print('{}')
" 2>/dev/null)
    CONTEXT+="${cost_summary}\n\n"
else
    CONTEXT+="{}\n\n"
fi

# ── Build prompt ─────────────────────────────────────────────────────────────
PROMPT="You are a stand-up brief composer for AInchors Nexus Platform.
Today is ${my_date}. Craft concise, specific, context-driven content for the morning stand-up.

${CONTEXT}

Return ONLY valid JSON — no markdown fences, no extra text, no commentary. Use this exact schema:
{\"businessStream\":\"...\",\"frameworkMaturity\":\"...\",\"progress\":\"...\",\"rtb\":{\"rose\":\"...\",\"thorn\":\"...\",\"bud\":\"...\"}}

Requirements:

1. **businessStream** (2-4 sentences): What Aria/the business stream did yesterday. Reference specific items from Angie interactions, proposal work, LinkedIn publishing status, or open business items. Be concrete — use names, amounts, dates.

2. **frameworkMaturity** (2-3 sentences): Governance/framework progress. Reference Shield/Lex/Sage/Warden status, CREST compliance, sprint ceremonies, or policy work. Use actual statuses (CLEAR/CONDITIONAL/ESCALATED).

3. **progress** (3-5 bullet points): Summary of CHGs/sprint work since last stand-up. Reference actual CHG numbers, sprint status (Sprint 10: 3/17 done, 13 open), and specific infrastructure changes. Each bullet must reference a real CHG ID or ticket.

4. **rtb** (Rose/Thorn/Bud):
   - **rose**: A specific positive from yesterday
   - **thorn**: A specific challenge or blocker (e.g. LinkedIn publish failures, exec tool issues, stale tokens)
   - **bud**: An opportunity or upcoming focus

Use specific names, numbers, and details. Be concrete, not generic. If the context has clear details, use them. If something is missing, say you don't have the data rather than inventing."

echo "$PROMPT" > "$PROMPT_FILE"

# ── Invoke OpenClaw agent model routing ─────────────────────────────────────
LLM_SUCCESS=false
COMPOSED=""

# Primary model: ollama/deepseek-v4-flash:cloud
# Fallback: ollama/kimi-k2.6:cloud
for model in "ollama/deepseek-v4-flash:cloud" "ollama/kimi-k2.6:cloud"; do
    echo "[standup-composer] Calling model: $model (via gateway agent infra)" >&2
    result=$(openclaw agent --agent infra --model "$model" --message-file "$PROMPT_FILE" --json --timeout 120 2>/dev/null || echo '{"error":"openclaw agent failed"}')

    # Extract text from JSON result (gateway response shape)
    raw_text=$(echo "$result" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    if 'error' in d:
        sys.exit(1)
    # Gateway wraps the response in result.payloads[0].text
    payloads = d.get('result', {}).get('payloads', [])
    if not payloads:
        sys.exit(1)
    text = payloads[0].get('text', '')
    if not text:
        sys.exit(1)
    print(text)
except Exception:
    sys.exit(1)
" 2>/dev/null) && true

    if [[ -z "$raw_text" ]]; then
        echo "[standup-composer] Empty response from $model, trying fallback" >&2
        continue
    fi

    # Validate and parse JSON — strip markdown fences if present
    parsed=$(python3 -c "
import json, sys
text = sys.stdin.read().strip()
# Strip markdown fences
if text.startswith('\`\`\`'):
    lines = text.split('\n')
    if lines[-1].strip() == '\`\`\`':
        text = '\n'.join(lines[1:-1])
    else:
        text = '\n'.join(lines[1:])
try:
    d = json.loads(text)
    assert isinstance(d.get('businessStream'), str) and len(d['businessStream']) > 10
    assert isinstance(d.get('frameworkMaturity'), str) and len(d['frameworkMaturity']) > 10
    assert isinstance(d.get('progress'), str) and len(d['progress']) > 20
    assert isinstance(d.get('rtb'), dict)
    assert isinstance(d['rtb'].get('rose'), str)
    assert isinstance(d['rtb'].get('thorn'), str)
    assert isinstance(d['rtb'].get('bud'), str)
    print(json.dumps(d))
except Exception as e:
    sys.stderr.write(f'JSON validation failed: {e}\n')
    sys.exit(1)
" <<< "$raw_text") && {
        COMPOSED="$parsed"
        LLM_SUCCESS=true
        echo "[standup-composer] Model $model returned valid composition" >&2
        break
    } || {
        echo "[standup-composer] Invalid JSON from $model, trying fallback" >&2
        continue
    }
done

# ── Fallback: degraded but deterministic ────────────────────────────────────
if [[ "$LLM_SUCCESS" != "true" ]]; then
    echo "[standup-composer] All models failed — writing degraded output" >&2

    # Read what sources we have for safe, non-fabricated placeholders
    aria_snippet=""
    if [[ -f "${WORKSPACE}/state/aria-daily-brief.md" ]]; then
        aria_date=$(head -1 "${WORKSPACE}/state/aria-daily-brief.md" 2>/dev/null | grep -oE '2026-[0-9][0-9]-[0-9][0-9]' || echo "unknown")
        aria_snippet="(Aria brief $aria_date)"
    fi

    sprint_num=$(python3 -c "
import json
try:
    d = json.load(open('${WORKSPACE}/state/sprint-current.json'))
    print(d.get('sprint', 'Sprint ?'))
except:
    print('Sprint ?')
" 2>/dev/null)

    # Build state-aware placeholders from actual files where possible.
    # Use only generic, non-fabricated text — no specific claims about
    # LinkedIn posts, sprint numbers, proposal amounts, or token status.
    # These should only appear when the LLM successfully composes from live context.

    # Safe sprint reference: just the name, no fabricated counts
    sprint_ref="${sprint_num}"
    if [[ "$sprint_ref" == "Sprint ?" || -z "$sprint_ref" ]]; then
        sprint_ref="current sprint"
    fi

    # Safe aria reference: date only, no fabricated content
    aria_ref=""
    if [[ -n "$aria_snippet" ]]; then
        aria_ref="Aria brief available ${aria_snippet}."
    fi

    COMPOSED=$(cat << JSONEOF
{
  "composer_status": "degraded",
  "degraded_reason": "LLM call failed after retry+fallback — context collected but composition unavailable",
  "degraded_fallback_safe": true,
  "businessStream": "[Composer degraded — no live composition available. Manual update needed.] ${aria_ref}",
  "frameworkMaturity": "[Composer degraded — no live composition available. Manual update needed.] ${sprint_ref} active.",
  "progress": "[Composer degraded — no live composition available. Manual update needed.]\\n• ${sprint_ref} active\\n• Check state/auto-heal-state.json for NEEDS_KEN items\\n• Check memory/CHANGELOG.md for recent changes",
  "rtb": {
    "rose": "[Composer degraded — no live composition available. Manual update needed.]",
    "thorn": "[Composer degraded — no live composition available. Manual update needed.]",
    "bud": "[Composer degraded — no live composition available. Manual update needed.]"
  }
}
JSONEOF
)
    echo "$COMPOSED" > "$OUTPUT_FILE"
    echo "[standup-composer] DEGRADED → $OUTPUT_FILE" >&2
    exit 5
fi

# ── Write success output ────────────────────────────────────────────────────
# Inject composer_status: ok into success output
COMPOSED=$(echo "$COMPOSED" | python3 -c "
import json, sys
d = json.load(sys.stdin)
d['composer_status'] = 'ok'
print(json.dumps(d, ensure_ascii=False))
" 2>/dev/null || echo "$COMPOSED")

echo "$COMPOSED" > "$OUTPUT_FILE"
echo "[standup-composer] composed blocks → $OUTPUT_FILE" >&2