# Model Emergency Runbook — v1.0
## Status: APPROVED by Ken Mun 2026-05-15 18:28 AEST | Trigger: CHG-0349 | Date: 2026-05-15

---

## 1. Purpose

Document the trigger conditions, decision flow, execution steps, and rollback procedure for switching all agents to Ollama Cloud (kimi) when Claude API credits are depleted.

**Owner:** Yoda (all agents)
**Approver:** Ken Mun (CTO)
**Review cadence:** Monthly, or after each emergency activation

---

## 2. Trigger Conditions

| Trigger | Condition | Detection |
|---|---|---|
| **Credit depletion** | Anthropic API balance < $15 AND auto-reload failed | cost-alert-state.json Tier 3, or Ken reports |
| **API outage** | Claude API unreachable for > 5 minutes | health-check.sh anthropicReachable=false |
| **Billing failure** | Auto-reload triggered but payment declined | cost-tracker.sh alert |
| **Ken directive** | Ken explicitly says "switch to kimi" or equivalent | Direct directive |

**Auto-detect:** Warden cron (15-min) checks `state/cost-alert-state.json`. If `tier3.triggered=true`, Warden surfaces alert to Ken. Ken confirms → trigger.

---

## 3. Keywords

| Keyword | Who can trigger | What happens |
|---|---|---|
| **`CLAUDE DEPLETED`** | Ken | Initiates emergency switch (same as auto-detect + confirmation) |
| **`CLAUDE RESTORE`** | Ken ONLY | Reverts all agents to original Sonnet/Haiku config |

**Keyword rules:**
- Must be uppercase, exact spelling
- Must be the only text in the message (or clearly standalone)
- Cannot be triggered by any agent — human authority only
- Telegram = valid trigger channel (accepted per CHG-0349)

---

## 4. Decision Flow

```
Detection (cost < $15 OR API unreachable)
    → Warden alerts Ken
        → Ken confirms: "CLAUDE DEPLETED" or "switch to kimi"
            → Yoda executes Section 5
                → All agents on kimi
                    → Ken: "CLAUDE RESTORE" when credits back
                        → Yoda executes Section 6
```

---

## 5. Execution Steps (Activation)

### Step 1: Confirm trigger
- [ ] Verify `state/cost-alert-state.json` tier3 or Ken explicit directive
- [ ] Log CHG entry (type: Emergency)

### Step 2: Save current config
```bash
# Before any changes — snapshot
python3 -c "
import json, shutil, datetime
shutil.copy('/Users/ainchorsangiefpl/.openclaw/openclaw.json',
            '/Users/ainchorsangiefpl/.openclaw/workspace/state/openclaw-pre-emergency.json')
print('Snapshot saved')
"
```

### Step 3: Update all agents to interim models
```python
KIMI = "ollama/kimi-k2.6:cloud"
GEMMA4 = "ollama/gemma4:26b"
DEEPSEEK_PRO = "ollama/deepseek-v4-pro:cloud"

# All agents: primary=kimi, fallbacks=[gemma4, deepseek-pro]
# See: CHG-0349 for exact script
```

### Step 4: Update Warden model-policy
- Whitelist interim models (kimi, gemma4, deepseek-pro, deepseek-flash)
- Set `requiredPrimary = ollama/kimi-k2.6:cloud`
- Log interim period metadata

### Step 5: Apply conservative mode
- Append interim rule to SOUL.md (NO risky state manipulation without Ken approval)
- Update AGENTS.md
- Cascade diligence guidance to all agents

### Step 6: Restart gateway
```bash
openclaw gateway restart
```

### Step 7: Verify
```bash
openclaw gateway status
python3 -c "import json; cfg=json.load(open('/Users/ainchorsangiefpl/.openclaw/openclaw.json')); print([a['id'] + '=' + a['model']['primary'] for a in cfg['agents']['list']])"
```

### Step 8: Confirm to Ken
- Telegram + webchat: "All agents on kimi. Conservative mode active. Revert: CLAUDE RESTORE."

---

## 6. Rollback Steps (Deactivation)

### Step 1: Ken triggers keyword
- Ken says: **`CLAUDE RESTORE`**

### Step 2: Restore original config
```bash
# Restore from snapshot
cp /Users/ainchorsangiefpl/.openclaw/workspace/state/openclaw-pre-emergency.json \
   /Users/ainchorsangiefpl/.openclaw/openclaw.json

# OR restore from claude-restore-config.json (has full original models)
python3 -c "
import json
restore = json.load(open('/Users/ainchorsangiefpl/.openclaw/workspace/state/claude-restore-config.json'))
original = restore['originalModels']

with open('/Users/ainchorsangiefpl/.openclaw/openclaw.json') as f:
    cfg = json.load(f)

for a in cfg['agents']['list']:
    aid = a['id']
    if aid in original:
        a['model'] = original[aid]
        print(f'Restored {aid}')

with open('/Users/ainchorsangiefpl/.openclaw/openclaw.json', 'w') as f:
    json.dump(cfg, f, indent=2)
"
```

### Step 3: Restore Warden policy
- Revert model-policy.json to pre-interim state
- Remove interim whitelist entries

### Step 4: Remove conservative mode
- Remove interim rule from SOUL.md
- Remove from AGENTS.md
- Restore normal operation rules

### Step 5: Restart gateway
```bash
openclaw gateway restart
```

### Step 6: Verify
- Check all agents back to Sonnet/Haiku
- Check gateway health
- Confirm to Ken

### Step 7: Log CHG
- type: config
- title: "Claude API restored — all agents reverted to Sonnet/Haiku"

---

## 7. Known Issues During Interim

| Issue | Mitigation |
|---|---|
| kimi loses thread on complex tasks | Explicit state checking + context brief |
| kimi may miss prior approvals | channel-state.json bridge + webchat pickup |
| kimi may execute specialist work directly | AGENTS.md routing discipline enforced |
| False positives from weaker models | Conservative mode: ask before acting |
| Cost tracking gaps | Forge cost tracker (TKT-0175) |
| **Cron explicit model override** | **See Section 7A — MUST update cron payloads, not just agent config** |

---

## 7A. Cron Model Override Behavior (CRITICAL GAP)

### The Problem

Cron jobs with explicit `model` field in their payload **override** the agent's default model and fallback chain.

```json
// Agent config: primary=kimi, fallbacks=[gemma4, deepseek-pro]
// Cron payload:
{
  "payload": {
    "model": "anthropic/claude-haiku-4-5",  // ← EXPLICIT OVERRIDE
    "message": "..."
  }
}
```

**Result:** When the cron fires, OpenClaw uses the **cron's explicit model**, not the agent's config.

**If Anthropic is blocked:**
- Cron tries to use `claude-haiku-4-5`
- Model fails (API unavailable)
- **NO automatic fallback to agent primary (kimi)**
- Cron execution fails → dead-letter or silent failure

### The Rule

> **During interim period: ALWAYS update cron payload model field. Do NOT rely on agent fallback chain for crons.**

### Procedure

**Step 1: Identify Anthropic crons**
```bash
openclaw cron list | grep "anthropic/claude"
```

**Step 2: Update each cron explicitly**
```bash
openclaw cron edit <cron-id> --model ollama/kimi-k2.6:cloud
```

**Step 3: Verify**
```bash
openclaw cron list | grep "anthropic/claude"  # Should return 0 results
```

### Verification Checklist

- [ ] All crons with explicit `anthropic/*` model updated to `ollama/kimi-k2.6:cloud`
- [ ] No Anthropic models remain in cron payloads
- [ ] `openclaw cron list` confirms 0 Anthropic entries
- [ ] CHG logged for the batch update

### Root Cause

CHG-0363 only updated **failed** Anthropic crons. Crons that hadn't failed yet (because they run at different times) retained their explicit Anthropic model. These would fail silently when their schedule next triggered.

### Related

- CHG-0391: All 12 Anthropic crons switched to kimi (2026-05-17)
- CHG-0363: Cron interim model batch update
- CHG-0373: KIMI PLATFORM MANDATE

---

## 8. Related Tickets

| Ticket | Purpose |
|---|---|
| TKT-0175 | Cost tracker calculated approach |
| TKT-0176 | Tech Stream ROI framework |
| CHG-0349 | This interim activation |
| CHG-0350 | Conservative mode rule |

---

## 9. Approval

**APPROVAL:** ✅ Ken Mun — APPROVED 2026-05-15 18:28 AEST
