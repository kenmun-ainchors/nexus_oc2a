#!/usr/bin/env python3
"""
Rebuilds journal-2026-05-10.md with Yoda's response (verbatim) field added to each entry.
"""

import re

JOURNAL_PATH = '/Users/ainchorsoc2a/.openclaw/workspace/memory/journal-2026-05-10.md'

with open(JOURNAL_PATH, 'r', encoding='utf-8') as f:
    content = f.read()

# ── Response definitions ───────────────────────────────────────────────────────

R_GOVERNANCE = (
    '> "Model Governance — fixed ✅\n'
    '>\n'
    '> **Fix 1 — Governance triad (Haiku)**\n'
    '> - Root cause: `model-policy.json` had `requiredModel: sonnet` for Shield/Lex/Sage — never updated when CHG-0193 switched them to Haiku\n'
    '> - Actual config (openclaw.json) was already correct — Warden was comparing against stale policy baseline\n'
    '> - Fixed: security/legal/qa `requiredModel` → `haiku` in model-policy.json. Violations will clear next Warden run.\n'
    '>\n'
    '> **Fix 2 — Gemma4:31b allowlist**\n'
    '> - Root cause: `ollama/gemma4:31b-cloud` was in model-policy.json but missing from openclaw.json runtime allowlist — that\'s what the cron executor checks\n'
    '> - Fixed: added `gemma4:31b-cloud` (alias: `gemma4cloud`) to `agents.defaults.models`\n'
    '> - Cron `7ff14b97` (RTB trial, 8:15 AM) will now run without rejection\n'
    '>\n'
    '> Gateway restarted. Both live.\n'
    '>\n'
    '> Also — LinkedIn RustDesk post scheduled to fire at **9:00 AM today** (15 min away). You\'ll get a Telegram confirmation when it posts."'
)

R_LINKEDIN_TEXT = (
    '> "Here\'s the full text to paste in:\n'
    '>\n'
    '> ---\n'
    '>\n'
    '> (the rendezvous broker) and hbbr (the relay server). Straightforward on paper. On macOS with Docker Desktop, a different story.\n'
    '>\n'
    '> The walls hit fast. macOS Application Firewall silently drops Docker UDP traffic — no error, no log, just nothing. Docker Desktop on macOS has known UDP port forwarding issues after any network change. The config file (RustDesk2.toml) gets overwritten on every app launch — you have to edit through the UI, not the file, and nobody tells you this. Then the 1.4.x client tries port 21114 (API server) before falling back to 21116 — but the open-source server doesn\'t include the API server. Firewall silently drops 21114. Client never falls back. Zero registrations. No error.\n'
    '>\n'
    '> I spun up Tailscale. NAT traversal, no open ports, free tier. Ten minutes later, remote access was working.\n'
    '>\n'
    '> Two things I\'ll carry forward. Know your options before you start. Tailscale, Cloudflare Tunnel, WireGuard, a cloud-hosted RustDesk on Linux — these were all valid paths. Knowing your fallbacks upfront changes how you evaluate the primary option. Know when to pivot. Chasing a fix only makes sense when you understand the effort-to-return ratio."'
)

R_OTEL = '> "TKT-0133 — **EA: OTel vs Dynatrace** — raised, synced to Notion, routed to Atlas. Backlog item for next sprint planning."'

R_HANDOVER = (
    '> "Here\'s your Day 16 handoff — **Sun 10 May, 4:02 PM AEST.**\n'
    '>\n'
    '> **✅ Done today (Sprint 2 close + Sprint 3 prep)**\n'
    '>\n'
    '> - **LinkedIn RustDesk post** — live. API truncation bug hit, you manually pasted the remaining text. TKT-0123 open to fix script permanently.\n'
    '> - **HF FLUX.1-schnell** — live (TKT-0121 ✅). Decision: ChatGPT = primary image source, HF = fallback.\n'
    '> - **Model governance fixed** — Warden false positives resolved. Governance triad (Shield/Lex/Sage) now correctly haiku in model-policy.json. gemma4cloud added to openclaw.json allowlist. Gateway restarted.\n'
    '> - **TKT-0133** — EA: OTel vs Dynatrace brief raised, routed to Atlas.\n'
    '> - **telegram-alert.sh** — API-independent fallback alert built (TKT-0113 ✅).\n'
    '> - **Model3-Policy v1.0** — all 7 T3 agents with routing decision tree.\n'
    '> - **Strategy-to-Backlog Pipeline** — TKT-0125 ✅, ceremony formalised.\n'
    '> - **Notion AKB** — 342 records intact, filter issue cleared.\n'
    '> - **Google Drive** — all 6 folders clean: journals, blogs, memory, platform docs, EA assessments, drafts. Nightly sync cron live.\n'
    '>\n'
    '> **🔴 Open / pending your input**\n'
    '>\n'
    '> - **obs-collector dedup TKT** — want me to raise it?\n'
    '> - **`main` daily budget cap** — $80 is too tight on sprint days. Suggest $120–150. Call?\n'
    '> - **Angie** — 9+ day contact gap. Onboarding Stage 1 stalled. JotForm API key still missing (Apr 28).\n'
    '> - **Sprint 3** — carrying TKT-0124 (MinIO hybrid) + TKT-0128 (Aria mandate). Sprint planning when you\'re ready.\n'
    '>\n'
    '> What are we working on?"'
)

R_BUDGET = '> "Done. `main` daily cap raised **$80 → $150** (CHG-0268). Reviewing at end of Sprint 3."'

R_TKT0141 = (
    '> "Tagged as **DEC-016** — pending your confirmation.\n'
    '>\n'
    '> **AC for your review:**\n'
    '>\n'
    '> `main` daily budget cap: **$80 → $150** (CHG-0268). Sprint 3 monitoring period only.\n'
    '>\n'
    '> **Review criteria at sprint end:**\n'
    '> - Avg daily spend <$100 → revert to $80\n'
    '> - $100–$150 → keep at $150\n'
    '> - >$150 → escalate + discuss\n'
    '>\n'
    '> Reply **CONFIRMED** to lock it, or let me know if you want different thresholds."\n'
    '> "Got it. Tagging the TKT-0141 open questions as DEC items for your review now."\n'
    '> "Tagged. **3 ACs from TKT-0141 — pending your review:**\n'
    '>\n'
    '> - **DEC-017** — CLI-Anything: adopt / reject / conditional? (read Atlas assessment when it lands)\n'
    '> - **DEC-018** — xurl BLOCK verdict: accept as false positive, or restrict from agent sessions?\n'
    '> - **DEC-019** — Cisco Skill Scanner + Snyk mcp-scan: pilot as SOP step 3b, or skip?\n'
    '>\n'
    '> All marked `pending-ken`. Flagged at next sprint review per DoD gate check."'
)

R_WARDEN = (
    '> "Clear picture. Here\'s the Warden failure pattern:\n'
    '>\n'
    '> **Last 10 runs:**\n'
    '> - 20:07 ❌ — "Agent couldn\'t generate a response"\n'
    '> - 19:07 ❌\n'
    '> - 18:07 ❌\n'
    '> - 17:07 ✅ Clean\n'
    '> - 16:07 ❌\n'
    '> - 15:07 ✅ Clean (x5 before that)\n'
    '>\n'
    '> **Root cause:** Warden runs with full `agentId: main` context — that\'s MEMORY.md + SOUL.md + AGENTS.md injected (~16,800 tokens per run). Haiku intermittently chokes on this context load and fails to generate a response. The model-drift-check.sh itself passes (exit 0), but the agent run aborts.\n'
    '>\n'
    '> Fix: add `lightContext: true` + replace multi-step agentTurn with single wrapper script."\n'
    '> "✅ **Fixed.** Latest run at top:\n'
    '>\n'
    '> ```\n'
    '> summary: "CLEAN: exit 0"\n'
    '> status: ok\n'
    '> duration: 5.6s\n'
    '> tokens: 11,330 (vs 16,900 before)\n'
    '> ```\n'
    '>\n'
    '> 3 consecutive passes now. Here\'s what changed:\n'
    '>\n'
    '> - **`warden-cron.sh`** — new wrapper script handles all 3 steps (check → log → escalate) in pure shell/Python. No LLM decision-making needed.\n'
    '> - **Minimal prompt** — Haiku just runs 1 script and outputs 1 line. Zero multi-step reasoning.\n'
    '> - **`lightContext: true`** — kept, reduces context further.\n'
    '> - Context dropped: 16,900 → 11,330 tokens per run. Duration: 12s → 5.6s.\n'
    '>\n'
    '> Next scheduled run: 21:07 AEST. Should hold."'
)

R_TOKEN_OPT = (
    '> "This is a platform design principle. Let me capture it properly and turn it into a persistent CI activity.\n'
    '>\n'
    '> **The core problem we just saw:**\n'
    '>\n'
    '> Warden was spending ~16,900 tokens every 15 minutes to run 2 bash scripts. That\'s ~65,000 tokens/hour, ~1.56M tokens/day — just for compliance checks. And it was the same pattern across many crons.\n'
    '>\n'
    '> **Root causes:**\n'
    '> 1. LLM used where shell/Python suffices — no reasoning needed, just automation\n'
    '> 2. Full main-agent bootstrap context loaded on every isolated cron by default (~16k tokens of SOUL.md/MEMORY.md/AGENTS.md injected even when irrelevant)\n'
    '> 3. Verbose script stdout piped back into LLM context — model reads 430 lines just to capture one exit code\n'
    '> 4. No token baseline tracking per cron — overspend goes unnoticed until something breaks"\n'
    '> "**Learning L-022 locked. TKT-0144 raised. RULES.md updated.**\n'
    '>\n'
    '> **The 6 platform principles (now non-negotiable):**\n'
    '>\n'
    '> - **P1 — Shell-first:** No reasoning needed = no LLM. `systemEvent` or wrapper script.\n'
    '> - **P2 — `lightContext: true`** on all isolated background crons. Default injects 16k tokens of context that most crons never need.\n'
    '> - **P3 — Scripts → state files.** Large stdout never returns to model context.\n'
    '> - **P4 — Model right-sizing:** Tier 0 (no LLM) → Tier 3 (Haiku) → Tier 4 (Sonnet) → Tier 5 (Opus). Use the floor, not the ceiling.\n'
    '> - **P5 — Token budgets per category:** Monitoring <500 | Compliance <2k | Reporting <5k | Content <10k\n'
    '> - **P6 — Monthly CI audit:** Flag any cron >2x its category target. Investigate and fix. Never-ending loop.\n'
    '>\n'
    '> **TKT-0144** covers the audit script + backfill + obs.db integration. Goes in Sprint 3.\n'
    '>\n'
    '> The Warden fix was one instance. The bigger win is this becomes part of how we build and review every cron going forward — same discipline as the canvas embed rule or the exec binary path rule."'
)

R_PARALLEL = '> _(response delivered in parallel session — not recovered from b1247fcd)_'
R_SILENT = '> _(silent — no chat reply)_'
R_NOT_RECOVERED = '_[not recovered from transcript]_'

# ── Section → response mapping ─────────────────────────────────────────────────
# Key: unique substring of the section header line
# Value: response string (None = not recovered, False = silent, str = verbatim)

SECTION_RESPONSES = {
    'Pre-Session — Heartbeat': (False, R_SILENT),
    '08:17 — Morning: Warden Violations': (True, R_GOVERNANCE),
    '08:19 — Update Check': (True, R_GOVERNANCE),
    '08:30 — TKT-0121: HF FLUX': (False, R_NOT_RECOVERED),
    '08:35 — TKT-0121 Image Test': (False, R_NOT_RECOVERED),
    '08:45 — TKT-0121 Image Selection': (False, R_NOT_RECOVERED),
    '09:02 — LinkedIn RustDesk Post: Text Cutoff': (True, R_LINKEDIN_TEXT),
    '09:05 — RustDesk Post: Add Illustration': (False, R_NOT_RECOVERED),
    '09:10 — Image Generation Prompt': (False, R_NOT_RECOVERED),
    '09:20 — HF Pipeline Decision': (False, R_NOT_RECOVERED),
    '09:30 — Observability: OTel': (False, R_NOT_RECOVERED),
    '12:25 — OTel vs Dynatrace': (True, R_OTEL),
    '12:35 — LinkedIn Fix': (False, R_NOT_RECOVERED),
    '12:45 — Brand Code from HBR': (False, R_NOT_RECOVERED),
    '12:55 — Brand Code in Business': (False, R_NOT_RECOVERED),
    '13:00 — Tailscale Funnel': (False, R_NOT_RECOVERED),
    '13:10 — New Backlog Items': (False, R_NOT_RECOVERED),
    '13:20 — Business Stream File': (False, R_NOT_RECOVERED),
    '13:30 — TKT-0124 Grooming': (False, R_NOT_RECOVERED),
    '13:50 — Agent Naming': (False, R_NOT_RECOVERED),
    '14:05 — Notion Update Block': (False, R_NOT_RECOVERED),
    '14:15 — Update Check': (False, R_NOT_RECOVERED),
    '14:20 — Sprint Brief': (False, R_NOT_RECOVERED),
    '14:40 — Warden Monitoring Deep': (False, R_NOT_RECOVERED),
    '14:55 — TKT-0105 Execution': (False, R_NOT_RECOVERED),
    '15:20 — In-Flight Check': (False, R_NOT_RECOVERED),
    '15:30 — TKT-0126 Execution': (False, R_NOT_RECOVERED),
    '15:40 — TKT-0127: Agentic Marketing': (False, R_NOT_RECOVERED),
    '15:50 — Agent Name for Marketing': (False, R_NOT_RECOVERED),
    '15:55 — TKT-0127': (False, R_NOT_RECOVERED),
    '16:00 — TKT-0128: Wait for MinIO': (False, R_NOT_RECOVERED),
    '16:00 — /sprint': (False, R_NOT_RECOVERED),
    '16:02 — /resume': (False, R_NOT_RECOVERED),
    '16:05 — /handover': (True, R_HANDOVER),
    '17:02 — Budget Increase': (True, R_BUDGET),
    '17:47 — TKT-0141 AC Tagging': (True, R_TKT0141),
    '18:00 — Lando Activation': (False, R_NOT_RECOVERED),
    '18:20 — TKT-0110 Refinement': (False, R_NOT_RECOVERED),
    '18:35 — KL Team Workshop': (False, R_NOT_RECOVERED),
    '18:45 — New Backlog: Consulting': (False, R_NOT_RECOVERED),
    '18:55 — Holocron Agent Architecture': (False, R_NOT_RECOVERED),
    '19:05 — Archive Old Holocron': (False, R_NOT_RECOVERED),
    '19:10 — AI Charter and Governance': (False, R_NOT_RECOVERED),
    '19:20 — Consulting Backlog: Business Jumpstart': (False, R_NOT_RECOVERED),
    '19:30 — Consulting Product Portfolio': (False, R_NOT_RECOVERED),
    '20:23 — Warden Failed Errors': (True, R_WARDEN),
    '20:31 — Token Optimisation': (True, R_TOKEN_OPT),
    '20:10 — LinkedIn RustDesk Post: Final Fix': (True, R_PARALLEL),
    '20:10 — Yoda Orchestrator MD Gap': (True, R_PARALLEL),
    '20:42 — Option C Approved': (True, R_PARALLEL),
    '20:43 — Decision 6B': (True, R_PARALLEL),
    '20:51 — ORCHESTRATOR.md Update Triggers': (True, R_PARALLEL),
    '20:53 — Gap Analysis Report': (True, R_PARALLEL),
    '20:35 — Token Optimisation Endorsed': (True, '> "👍"'),
    '21:00 — Sprint Complete': (False, R_NOT_RECOVERED),
    '23:55 — Business Stream Daily Brief': (False, R_SILENT),
}

def get_response(header_line):
    """Return (is_verbatim, response_text) for a given header line."""
    for key, (flag, resp) in SECTION_RESPONSES.items():
        if key in header_line:
            return flag, resp
    # Default: not recovered
    return False, R_NOT_RECOVERED


def build_yoda_field(flag, resp):
    """Build the **Yoda's response (verbatim):** block."""
    if resp == R_SILENT:
        return f"**Yoda's response (verbatim):**\n{R_SILENT}"
    elif resp == R_NOT_RECOVERED:
        return f"**Yoda's response (verbatim):** {R_NOT_RECOVERED}"
    else:
        return f"**Yoda's response (verbatim):**\n{resp}"


# ── Process the file ───────────────────────────────────────────────────────────

lines = content.split('\n')
output = []
current_header = None
in_entry = False

for i, line in enumerate(lines):
    # Detect section header (## but not ###, and has '—' or is Pre-Session)
    is_section_header = bool(re.match(r'^## [^#]', line)) and ('—' in line or 'Pre-Session' in line or 'Day 16 Retro' in line)
    
    if is_section_header:
        current_header = line
        in_entry = not ('Day 16 Retro' in line)
    
    # Insert Yoda response before **Outcome:**
    if in_entry and current_header and re.match(r'^\*\*Outcome:\*\*', line):
        _, resp = get_response(current_header)
        yoda_field = build_yoda_field(None, resp)
        output.append('')
        output.append(yoda_field)
        output.append('')
    
    output.append(line)

result = '\n'.join(output)

with open(JOURNAL_PATH, 'w', encoding='utf-8') as f:
    f.write(result)

outcome_count = content.count('**Outcome:**')
response_count = result.count("**Yoda's response (verbatim):**")
print(f"Outcome blocks found in original: {outcome_count}")
print(f"Yoda response fields inserted: {response_count}")
print(f"Original lines: {len(lines)}")
print(f"Output lines: {len(output)}")
