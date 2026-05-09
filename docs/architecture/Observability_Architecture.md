# Observability Architecture — AInchors / Nexus
**Version:** 1.0 | **Owner:** Yoda (Tier 0) | **Approved:** Ken Mun, 2026-05-09 | **CHG:** CHG-0247

---

## Principle

> **obs.db is the single source of truth for all operational errors and warnings.**

No error, failure, or warning may exist only in an isolated state file. Every source of error data must be wired into `obs-collector.sh`. The standup, dashboards, and alerts all read from obs.db — if it's not there, it didn't happen operationally.

This rule was formalised after the kimi RTB cron failed silently on Day 15 (2026-05-09) and was not captured in the 24h error count. Root cause: cron run failures lived in cron state only, with no feed into obs.db.

---

## Architecture

```
[Error Sources]                  [Collector]              [Store]       [Consumers]
─────────────────────────────    ─────────────────────    ──────────    ───────────────────
health-state.json ─────────────► CHECK A                 │           │ standup 24h count
warden-escalation-pending.json ► CHECK B                 │           │ obs-query.sh
auto-heal-YYYY-MM-DD.json ─────► CHECK C                 │           │ Mission Control
task-stall-alert.json ─────────► CHECK D                 │           │ Krennic (SRE, future)
stability/*.log ────────────────► CHECK E    ─────────►  │ obs.db  │ Beacon dashboard
pending-alert.json ─────────────► CHECK F                │           │   (Nexus, future)
standby-mode.json ──────────────► CHECK G                │           │
system-banner.json ─────────────► CHECK H                │           │
shield-escalation-pending.json ─► CHECK I                │           │
task-verification-alert.json ──► CHECK J                 │           │
fallback-chain-status.json ────► CHECK K                 │           │
cost-alert-state.json ─────────► CHECK L                 │           │
backup.log ─────────────────────► CHECK M                │           │
config-health.json ─────────────► CHECK N                │           │
gateway.err.log (patterns) ────► CHECK O                 │           │
latency-tracker-state.json ────► CHECK P                 │           │
cron-health-state.json ─────────► CHECK Q  (added D15)   │           │
incident-log.json ──────────────► CHECK R  (added D15)   │           │
model-drift-violations.json ───► CHECK S  (added D15)    │           │
budget-alert-state.json ────────► CHECK T  (added D15)   │           │
delegation-log.json ────────────► CHECK U  (added D15)   │           │
pvt-last-result.json ───────────► CHECK V  (added D15)   │           │
relay-to-ken.json ──────────────► CHECK W  (added D15)   │           │
overnight-task-status.json ────► CHECK X  (added D15)    │           │
shield/lex/sage-qa-log.json ───► CHECK Y  (added D15)    │           │
sanctum-sla-log.json ───────────► CHECK Z  (added D15)   │           │
```

**Collector:** `scripts/obs-collector.sh` — runs every 5 min via cron (`d3b1e203`).
**Store:** `state/obs.db` — SQLite. Purge: events older than 7 days auto-removed.
**Query:** `scripts/obs-query.sh` — used by standup, diagnostics, heartbeat.

---

## Non-Negotiable Build Rule

When ANY of the following is created, an obs-collector CHECK must be added **in the same CHG**:

| Trigger | Required action |
|---|---|
| New `state/*.json` with `status`, `error`, `failures`, `violations`, or `alerts` fields | Add CHECK to obs-collector.sh |
| New `*.log` file capturing operational events | Add CHECK (pattern match or file parse) |
| New cron job whose output is written to a state file | Add CHECK for that state file |
| New agent that produces QA verdicts, health outputs, or governance results | Add CHECK for its output state |
| New script writing `*-error.json`, `*-alert.json`, `*-violations.json` | Add CHECK for that file |

**Gate:** Yoda enforces this at CHG log time. No CHG is complete if it introduces error state without an obs CHECK.

---

## CHECK Implementation Standard

Every CHECK must follow this pattern:

```bash
# ── CHECK [ID]: [source-file] — [what it catches] ──────────────────────────
SOURCE_FILE="$STATE/[filename]"
if [[ -f "$SOURCE_FILE" ]]; then
  python3 - <<'PYEOF'
import json, subprocess, os

state   = os.environ.get('WORKSPACE', os.path.expanduser('~/.openclaw/workspace'))
obs_log = os.path.join(state, 'scripts', 'obs-log.sh')

# 1. Read lastRunEpoch from obs-collector-state.json for deduplication
try:
    cs = json.load(open(os.path.join(state, 'state', 'obs-collector-state.json')))
    last_run = int(cs.get('lastRunEpoch', 0))
except Exception:
    last_run = 0

# 2. Parse source file
try:
    d = json.load(open(os.path.join(state, 'state', '[filename]')))
except Exception:
    sys.exit(0)

# 3. Detect condition and log
# ... condition check ...
subprocess.run([
    'bash', obs_log,
    '--source', '[source-name]',
    '--level', 'ERROR',          # ERROR | WARN | INFO
    '--type',  '[event_type]',   # snake_case, from event type registry below
    '--message', msg,            # human-readable, <200 chars
    '--detail', json.dumps({...}) # structured context
], capture_output=True)
PYEOF
fi
```

**Rules:**
1. Guard with `[[ -f "$FILE" ]]` — never fail if file is missing
2. Timestamp-dedup: only emit events newer than `lastRunEpoch` to avoid duplicates
3. Use `obs-log.sh` — never write to obs.db directly
4. Never raise an event for a condition that is already handled by an earlier CHECK (avoid double-counting)
5. `capture_output=True` — CHECK must never print to stdout (that breaks the single-line output contract)

---

## Event Type Registry

| Type | Level | Source | Meaning |
|---|---|---|---|
| `health_failure` | ERROR | health-check | System health check failed |
| `cron_run_fail` | ERROR | cron-health | Cron job execution error |
| `open_incident` | WARN | incident-log | Unresolved incident in log |
| `warden_violation_unescalated` | ERROR | warden | Model drift not escalated to Yoda |
| `budget_exceeded` | ERROR | budget | Agent budget cap breached |
| `delegation_fail` | ERROR | delegation | Task delegation returned failure |
| `pvt_fail` | ERROR | pvt | Post-validation test <9/9 |
| `relay_stuck` | WARN | relay | Ken relay message unsent >30min |
| `overnight_task_fail` | ERROR | overnight-task | Overnight task failed/stalled |
| `governance_qa_fail` | ERROR | shield/lex/sage-qa | Triad QA verdict=fail |
| `sla_breach` | WARN | sanctum | Sanctum SLA threshold exceeded |
| `incomplete_turn` | WARN | gateway | Agent produced no output |
| `anthropic_api_fail` | ERROR | gateway | Anthropic API error/overload |
| `gateway_restart` | WARN | gateway | Main session interrupted |
| `auto_heal_fix` | INFO | auto-heal | Auto-heal applied a fix |
| `auto_heal_needs_ken` | WARN | auto-heal | Auto-heal needs manual action |
| `routing_decision` | INFO | route-model | Model routing decision |
| `task_verification_fail` | ERROR | task-verify | Task done but deliverable missing |
| `fallback_chain_broken` | ERROR | fallback | Fallback chain has broken links |
| `cost_tier3` | ERROR | cost | Balance at Tier 3 (critical) |
| `backup_fail` | ERROR | backup | Backup missed or failed |
| `config_drift` | ERROR | config | Critical config baseline drift |

To add a new type: append to this table, add the CHECK, update RULES.md event type table.

---

## Residual Gaps (deferred — pre-OC2)

| Source | Reason deferred |
|---|---|
| `gemma4-shadow.json` | Not in use pre-OC2. Add when Gemma4 local active (TRIGGER-03). |
| `startup-report.json` | Low frequency, schema unstable. Add when format stabilised. |
| ClawHub plugin install logs | Not applicable (S3: no ClawHub on prod). |
| Nexus/Beacon native telemetry | Future state — Beacon replaces obs.db at P2/P3. |

---

## Future State — Nexus Beacon

obs.db + obs-collector.sh is the **pre-Nexus observability layer**. It is explicitly temporary.

At P2, Nexus **Beacon** (monitoring/health module) replaces obs.db with:
- Structured event ingestion API (not file polling)
- Real-time alerting with SLA targets
- Full agent observability dashboard (The Bridge)
- Persistent cross-session error correlation

Until Beacon is live, obs.db is the SSOT. Every new component must wire into it.

---

## Changelog

| Date | Change | CHG |
|---|---|---|
| 2026-05-09 | Architecture formalised. Checks A–O were existing. Checks Q–Z added (10 new sources). | CHG-0247 |
