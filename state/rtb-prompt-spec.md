# RTB Canonical Prompt Spec
_Owner: Yoda 🟢 | Locked: 2026-05-12 (CHG-0282) | All RTB trial crons use this spec — only MODEL_LABEL and MODEL_TRIAL_FILE differ._

---

## Purpose
One spec. Multiple models. Fair comparison.
Kimi, Gemma4, and Sonnet (standup) all execute this same logic against the same data.
Only the model running it changes.

## Canonical Prompt Template

```
RTB_TRIAL: Daily Rose/Thorn/Bud — AInchors Nexus Platform.

⚠️ ISOLATED SESSION — ALL file paths MUST be ABSOLUTE starting with /Users/ainchorsangiefpl/
NEVER use ~ or relative paths in any tool call.

## Step 1 — Load data
Get current date in Australia/Melbourne timezone → TODAY (YYYY-MM-DD), DAY_N (platform day number).

Read: /Users/ainchorsangiefpl/.openclaw/workspace/state/standup-data-TODAY.json
Extract these fields:
- dayN
- systemHealth (gateway status, consecutiveFailures)
- cost (confirmedBalance, dailyCost, avgDailyCost)
- warden (consecutiveClean, lastCheck, lastViolationAt)
- obsQuery (error count, warn count — last 24h window)
- taskQuery (tasks run, tasks failed)
- businessStream (Angie activity, open items)
- incidents (open count)
- backup (lastBackupAt, status)

If standup-data file missing: fall back to reading state/health-state.json + state/cost-state.json + state/model-drift-state.json directly.

## Step 2 — Framework maturity gate (mandatory)
Read: /Users/ainchorsangiefpl/.openclaw/workspace/state/frameworks-maturity.json
Extract EXACT maturity level for each framework.
Calculate:
- overall balance: average maturity across all frameworks
- lagging: any framework >1 level below average
The BUD must target the lagging framework OR a genuinely actionable emerging opportunity.

## Step 3 — Reason before writing
Do NOT report raw numbers. Apply judgement:
- obs errors high but warden consecutiveClean > 10? → historical noise, not a real thorn
- cost above average? → check if it's a one-off (CI run, batch job) or a trend
- business stream quiet? → distinguish weekend/expected cadence from genuine stall
- what is the ONE action Ken could approve today with the highest leverage?

## Step 4 — Format output
Output EXACTLY this block (no extra text before or after):

──────────────────────────────
🤖 [MODEL_LABEL] RTB — TODAY (Day DAY_N)
──────────────────────────────
📊 Framework balance: L[X] avg | [lagging framework: LY — N levels behind] OR [balanced]
🌹 ROSE [Tech]: [what is genuinely working / confirmed healthy — 1-2 sentences]
         [Biz]: [business stream win or stable note — 1-2 sentences]
🌵 THORN [Tech]: [real friction with WHY it matters — not noise — 1-2 sentences]
           [Biz]: [business stream blocker or gap — 1-2 sentences]
🌱 BUD [Tech]: [most impactful tech action Ken could approve today — 1-2 sentences]
        [Biz]: [most impactful business action Ken could approve today — 1-2 sentences]
Ken approves before work starts.
──────────────────────────────

Rules:
- NEVER report raw warden/obs error counts as thorns when consecutiveClean > 10 — they are historical noise
- Both streams MUST have a Thorn and a Bud — never "N/A" or "no activity"
- Each item: 1-3 sentences max. Actionable, not vague.
- BUD = something Ken can approve TODAY, not a multi-week direction

## Step 5 — Log to trial state
Read: /Users/ainchorsangiefpl/.openclaw/workspace/state/[MODEL_TRIAL_FILE]
If file missing, create: []
Append: {"date": "TODAY", "model": "[MODEL_ID]", "status": "delivered", "deliveredAt": "[now ISO UTC]"}
Write back to: /Users/ainchorsangiefpl/.openclaw/workspace/state/[MODEL_TRIAL_FILE]
(absolute path, write tool)

## Step 6 — Deliver
Deliver the RTB block via announce to telegram:8574109706.
Output the full RTB block as your response.
```

---

## Per-model substitutions

| Cron | MODEL_LABEL | MODEL_ID | MODEL_TRIAL_FILE | Timeout |
|---|---|---|---|---|
| Kimi (57105907) | KIMI | kimi-k2.6:cloud | kimi-rtb-trial.json | 300s |
| Gemma4 (7ff14b97) | GEMMA4 | gemma4:31b-cloud | gemma4-rtb-trial.json | 300s |
| Standup/Sonnet (3c279099) | embedded in full standup | — | — | 600s |
