# GatewayRecovery.md — AInchors Outage & Recovery Runbook

**Owner:** Ken Mun (CTO) / Yoda (AI Ops Lead)
**Last updated:** 2026-04-29
**Linked:** US23 · CHG-0075 · INC-20260426

---

## Section 1 — What Standby Mode Means

Standby mode activates automatically when `outage-detect.sh` cannot reach the Anthropic API. It is a protective mode — not a full failure.

### What happens when standby activates

| Component | Behaviour |
|-----------|-----------|
| Interactive sessions (Yoda) | **Paused** — Anthropic API required |
| Background crons (health-check, cost tracker, PVT) | **Gemma4 local only** — limited capability |
| System banner | Displayed to Ken with reason + triage links |
| `state/standby-mode.json` | Written with `active: true`, reason, and timestamp |
| `state/system-banner.json` | Set to `active: true` with critical-type banner |
| `/tmp/outage-alert-pending.txt` | Written once on new outage (Telegram alert source) |

### State files

**`state/standby-mode.json`** — present and `active: true` while in standby:
```json
{
  "active": true,
  "since": "2026-04-29T01:00:00Z",
  "reason": "Anthropic API auth/key failure (HTTP 401)",
  "fallback": "ollama/gemma4:26b",
  "fallbackScope": "background-crons-only",
  "policy": "CHG-0075: Gemma4 standby for bg crons only."
}
```

**`state/system-banner.json`** — drives the in-app warning banner:
```json
{
  "active": true,
  "type": "critical",
  "title": "⚠️ STANDBY MODE — Anthropic API Unavailable",
  "message": "...",
  "dismissable": false
}
```

### What standby does NOT mean
- Data is not lost
- Local Gemma4 continues background health monitoring
- All state files are preserved — full recovery is automatic once Anthropic is reachable

---

## Section 2 — Triage Steps

Run these in order. Stop when you find the cause.

### Step 1 — Check Anthropic status page
```
https://status.anthropic.com
```
If there is an active incident, wait it out. Nothing to fix on our end.

### Step 2 — Check billing console
```
https://console.anthropic.com/settings/billing
```
Look for:
- Expired or declined payment method
- Credit balance at zero (prepaid accounts)
- Account suspension notice

**Fix:** Update payment method or top up credit. API access restores within minutes.

### Step 3 — Verify API key in keychain
```zsh
security find-generic-password -s "anthropic-api-key" -w | head -c 20
```
Expected: starts with `sk-ant-api03-` (20+ chars).

If missing or wrong:
```zsh
# Re-add key
security add-generic-password -s "anthropic-api-key" -a "$USER" -w "sk-ant-api03-YOUR-KEY"
```

### Step 4 — Test the API directly
```zsh
KEY=$(security find-generic-password -s "anthropic-api-key" -w)
curl -s -o /dev/null -w "%{http_code}" \
  -H "x-api-key: $KEY" \
  -H "anthropic-version: 2023-06-01" \
  https://api.anthropic.com/v1/models
```
- `200` = key and billing OK — run recovery steps below
- `401` / `403` = auth failure — check key
- `402` = billing suspended — check console
- `429` = rate limited — wait and retry
- `5xx` = Anthropic-side outage — check status page

---

## Section 3 — Recovery Steps

Once the root cause is resolved (billing fixed, key updated, Anthropic back online):

### Step 1 — Run outage-detect.sh (auto-clears standby)
```zsh
zsh ~/.openclaw/workspace/scripts/outage-detect.sh
# Exit 0 = recovered. State files cleared. Banner cleared. Recovery trigger written.
```

### Step 2 — Restart the gateway (if it was restarted during the outage)
```zsh
openclaw gateway restart
# Or:
launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway
```

### Step 3 — Validate the fallback chain
```zsh
zsh ~/.openclaw/workspace/scripts/validate-fallback-chain.sh
# Exit 0 = all links healthy
```

### Step 4 — Run PVT (post-verification test)
```zsh
bash ~/.openclaw/workspace/scripts/pvt.sh
# Must pass 9/9
```

### Step 5 — Confirm with Ken
Send Ken a Telegram update confirming recovery and root cause.

### Step 6 — Log an incident (if >30 min downtime)
```zsh
bash ~/.openclaw/workspace/scripts/incident-log.sh
```

---

## Section 4 — Fallback Chain Reference (CHG-0075)

```
┌─────────────────────────────────────────────────────────┐
│             AInchors Fallback Chain (CHG-0075)          │
├─────────────────────────────────────────────────────────┤
│  TIER 1 (Primary)   │  anthropic/claude-sonnet-4-6      │
│  TIER 2 (Fallback)  │  anthropic/claude-haiku-4-5       │
│  TIER 3 (Standby)   │  STANDBY MODE (see below)        │
├─────────────────────────────────────────────────────────┤
│  LOCAL CRONS ONLY   │  ollama/gemma4:26b               │
│                     │  (background tasks, never Aria)   │
└─────────────────────────────────────────────────────────┘
```

### Rules (CHG-0075)
- **Opus** is NOT in the auto-fallback chain. Deliberate escalation only.
- **Gemma4** is NOT permitted for interactive Aria sessions. Background crons only.
- When both Sonnet and Haiku are unreachable → **STANDBY MODE**. Do not silently fall back to Gemma4 for interactive work.
- Fallback chain is validated on boot and on every Anthropic failure detected by `outage-detect.sh`.

### Expected `openclaw.json` config
```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "anthropic/claude-sonnet-4-6",
        "fallbacks": ["anthropic/claude-haiku-4-5"]
      }
    }
  }
}
```

---

## Section 5 — Scripts Reference

| Script | Purpose | When to run |
|--------|---------|-------------|
| `scripts/outage-detect.sh` | Tests Anthropic API, activates/clears standby, writes banner and trigger files | Auto: called from `health-check.sh` every 5 min |
| `scripts/validate-fallback-chain.sh` | Validates all 5 links: key → API → Ollama → Gemma4 loaded → Gemma4 warm → config | Auto: called by `outage-detect.sh` on failure; manually on demand |
| `scripts/health-check.sh` | Master health check — gateway, Ollama, disk, state staleness, Anthropic, standby | Auto: every 5 min via cron |
| `scripts/pvt.sh` | Post-verification test — 9 checks must pass after any risky op | After every recovery, deployment, or config change |
| `scripts/incident-log.sh` | Log an incident to `state/incident-log.json` + Notion | Any P1/P2 outage >30 min |

### outage-detect.sh exit codes
| Exit | Meaning |
|------|---------|
| `0` | Anthropic healthy — standby cleared if it was active |
| `1` | Outage detected — standby activated, banner up, trigger file written |

### Trigger files
These files are written by `outage-detect.sh` and consumed by the main session to send Telegram alerts:

| File | Written when |
|------|-------------|
| `/tmp/outage-alert-pending.txt` | New outage detected (first time, not repeat) |
| `/tmp/outage-recovery-pending.txt` | Outage cleared after being in standby |

---

## Appendix — Quick Reference Card

```
OUTAGE DETECTED?
  1. status.anthropic.com → incident? → wait
  2. console.anthropic.com/billing → suspended? → fix payment
  3. security find-generic-password -s "anthropic-api-key" -w → key OK?
  4. Fix root cause → zsh scripts/outage-detect.sh → exit 0?
  5. openclaw gateway restart → zsh scripts/validate-fallback-chain.sh
  6. bash scripts/pvt.sh → 9/9 → done
```

---

*Generated by Yoda (US23) · 2026-04-29 · Triggered by 2026-04-26 night outage*
