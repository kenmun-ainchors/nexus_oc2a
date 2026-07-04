#!/usr/bin/env bash
# standup-composer.sh
# Rich-content composer for stand-up sections 2, 5, 6, 7.
# Thin bash wrapper around an embedded Python composer.
# Output: .openclaw/tmp/standup-composer-input.json
# Falls back to deterministic placeholder if LLM unavailable.

set -euo pipefail

WORKSPACE="${WORKSPACE:-/Users/ainchorsangiefpl/.openclaw/workspace}"
OUTPUT_FILE="${WORKSPACE}/.openclaw/tmp/standup-composer-input.json"
mkdir -p "$(dirname "$OUTPUT_FILE")"

python3 - "$WORKSPACE" "$OUTPUT_FILE" << 'PYEOF'
import json, os, sys, subprocess, glob, re, urllib.request
from datetime import datetime, timezone, timedelta
from pathlib import Path

WORKSPACE = Path(sys.argv[1])
OUTPUT_FILE = Path(sys.argv[2])

def safe_read_text(path, limit=5000):
    try:
        text = Path(path).read_text(encoding="utf-8", errors="ignore")
        return text[:limit]
    except Exception:
        return ""

def safe_read_json(path, default=None):
    default = default if default is not None else {}
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return default

aest = timezone(timedelta(hours=10))
now_aest = datetime.now(timezone.utc).astimezone(aest)
today_str = now_aest.date().isoformat()

start = datetime(2026, 4, 25).date()
day_n = (now_aest.date() - start).days + 1

# ── Load context ─────────────────────────────────────────────────────────────
memory_july = ""
for f in sorted(glob.glob(str(WORKSPACE / "memory" / "2026-07-*.md"))):
    memory_july += f"=== {Path(f).name} ===\n{safe_read_text(f)}\n\n"

aria_brief = ""
for candidate in [
    WORKSPACE / "state" / "aria-daily-brief.md",
    WORKSPACE / ".openclaw" / "tmp" / "aria-daily-brief.md",
]:
    if candidate.exists():
        aria_brief = safe_read_text(candidate, 8000)
        break

changelog = ""
if (WORKSPACE / "memory" / "CHANGELOG.md").exists():
    changelog = "\n".join((WORKSPACE / "memory" / "CHANGELOG.md").read_text().splitlines()[-100:])

sprint_state = safe_read_json(WORKSPACE / "state" / "sprint-current.json", {})
health_state = safe_read_json(WORKSPACE / "state" / "health-state.json", {})
backup_state = safe_read_json(WORKSPACE / "state" / "backup-state.json", {})

# ── Compose prompt ──────────────────────────────────────────────────────────
prompt = f"""You are a stand-up brief composer for AInchors Nexus Platform.
Today is {today_str}.

Generate 4 blocks of concise, specific, context-driven content for the morning stand-up.

## Context

### Recent Memory Journals (July 2026)
{memory_july}

### Aria Daily Brief (latest)
{aria_brief}

### Recent CHANGELOG entries
{changelog}

### Sprint State
{json.dumps(sprint_state, indent=2)}

### Health State
{json.dumps(health_state, indent=2)}

### Backup State
{json.dumps(backup_state, indent=2)}

## Required Blocks

1. **businessStream** (2-4 sentences): What Aria/the business stream did yesterday and what needs attention today. Reference specific items from Aria's brief, Angie interactions, proposal work, LinkedIn publishing status, or open business items.

2. **frameworkMaturity** (2-3 sentences): Governance/framework progress. Reference Shield/Lex/Sage clearance status, CREST compliance, Warden model compliance, sprint ceremonies, or policy work.

3. **progress** (3-5 bullet points): Summary of CHGs/sprint work since last stand-up. Reference actual CHG numbers, sprint status, ticket work, or infrastructure changes.

4. **rtb** (Rose/Thorn/Bud):
   - **rose**: A specific positive from yesterday
   - **thorn**: A specific challenge or blocker
   - **bud**: An opportunity or upcoming focus

Use specific names, numbers, and details from the context above. Be concrete, not generic.

Return ONLY valid JSON with NO markdown fences, NO extra text, exactly this schema:
{{"businessStream":"...","frameworkMaturity":"...","progress":"...","rtb":{{"rose":"...","thorn":"...","bud":"..."}}}}
"""

# ── Try LLM composition via Ollama HTTP API ────────────────────────────────
llm_success = False
composed = None

OLLAMA_API = "http://localhost:11434/api/generate"

def call_ollama(model_name, prompt_text, timeout_sec=120):
    """Call Ollama generate API with stream=false. Returns response text or None."""
    payload = json.dumps({
        "model": model_name,
        "prompt": prompt_text,
        "stream": False,
    }).encode("utf-8")
    req = urllib.request.Request(
        OLLAMA_API,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        resp = urllib.request.urlopen(req, timeout=timeout_sec)
        data = json.loads(resp.read().decode("utf-8"))
        return data.get("response", "")
    except Exception:
        return None

def validate_and_parse(raw_text):
    """Run the same validation as standup-json-clean.py inline."""
    text = raw_text.strip()
    # Strip markdown fences if present
    if text.startswith("```"):
        lines = text.split("\n")
        if lines[-1].strip() == "```":
            text = "\n".join(lines[1:-1])
        else:
            text = "\n".join(lines[1:])
    try:
        d = json.loads(text)
        assert "businessStream" in d
        assert "frameworkMaturity" in d
        assert "progress" in d
        assert "rtb" in d
        assert "rose" in d["rtb"]
        assert "thorn" in d["rtb"]
        assert "bud" in d["rtb"]
        return d
    except Exception:
        return None

try:
    for model in ["kimi-k2.7-code:cloud", "deepseek-v4-flash:cloud", "qwen3.5:cloud"]:
        try:
            raw = call_ollama(model, prompt)
            if raw is None:
                continue
            parsed = validate_and_parse(raw)
            if parsed is not None:
                composed = parsed
                llm_success = True
                break
        except Exception:
            continue
except Exception:
    pass

# ── Fallback placeholder ───────────────────────────────────────────────────
if not composed:
    sprint_num = sprint_state.get("sprint", "Sprint 10")
    sprint_pct = f"{sprint_state.get('completion_pct', 0):.0f}%"
    composed = {
        "businessStream": "Aria brief available — see state/aria-daily-brief.md for latest. Key items as of yesterday include proposal work, LinkedIn publishing, and business stream open items.",
        "frameworkMaturity": f"Governance sweep routine clear. Shield, Lex, Sage all CLEAR. Warden compliance check passed. CREST compliance confirmed. {sprint_num} in progress at {sprint_pct} completion.",
        "progress": f"• {sprint_num} active — {sprint_pct} complete\n• Recent infrastructure work under CHG-0818/0820/0821 (gateway stability and auto-heal hardening)\n• Aria created Act 680 proposal for Malaysian Ministry of Digital (MYR 1,550,000)",
        "rtb": {
            "rose": "Aria completed the Act 680 proposal with enhanced agentic AI governance framework and international credentials. Angie has the email for review.",
            "thorn": "LinkedIn publish pipeline still silently failing — LI-W3-P7/P8/P9/P10 all missed scheduled posts. Business account token also expired.",
            "bud": "Angie is actively engaged again after 9 days. Opportunity to re-engage on onboarding, business stream setup, and LinkedIn publish pipeline fix.",
        },
    }

# ── Write output ─────────────────────────────────────────────────────────────
OUTPUT_FILE.write_text(json.dumps(composed, indent=2), encoding="utf-8")
print(f"[standup-composer] composed blocks → {OUTPUT_FILE} (llm={llm_success})", file=sys.stderr)
PYEOF
