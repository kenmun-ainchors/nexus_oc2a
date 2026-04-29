# Post-Incident Review — PIR-20260428-002

| Field | Value |
|-------|-------|
| **PIR ID** | PIR-20260428-20260428-002 |
| **Incident ID** | INC-20260428-002 |
| **Severity** | P1 |
| **Title** | Bonjour/ciao plugin crash-loop + Model drift (Apr 28) |
| **Created** | 2026-04-28T14:26:13+10:00 |
| **Completed** | 2026-04-29T11:29:00+10:00 |
| **Owner** | Ken Mun (CTO) |
| **Status** | ✅ COMPLETE |

---

## 1. Timeline

| Time (AEST) | Event |
|-------------|-------|
| ~09:00 | Day 3 work begins. Auto-heal, diagnostics, and model drift check built and deployed. |
| 14:26 | PIR auto-trigger fires for INC-20260428-002 (P1 test) — system banner raised. |
| ~18:00 | First model drift detected — Opus active after reset, should be Sonnet. Manually corrected. |
| ~19:30 | Gateway crash. Root cause: Bonjour/ciao plugin crash-looping every ~9s, destabilising process. CHG-0036 raised. |
| ~19:30–20:00 | Gateway restarted. Bonjour/ciao plugin disabled. Service restored. |
| ~20:00 | Second model drift detected — Opus again. Anti-drift baseline + Check #12 auto-heal implemented. CHG-0037 raised. |
| ~21:00 | Dual Telegram bot implemented (CHG-0038). |
| 22:10 | Diagnostics run: 16 PASS / 6 WARN / 0 FAIL. System stable. |
| Late night | Billing/auth failure — night outage occurs. US23 raised to investigate and harden. |
| 2026-04-29 11:29 | PIR completed. Banner dismissed. |

---

## 2. Root Cause — 5 Whys

### Incident A: Gateway Crash (Primary)

**Why 1 — Why did the gateway crash?**
The gateway process became unstable and terminated.

**Why 2 — Why did it become unstable?**
The Bonjour/ciao plugin was crash-looping every ~9 seconds, repeatedly throwing errors and consuming process resources.

**Why 3 — Why was the ciao plugin crash-looping?**
The plugin has known instability on this host configuration; no watchdog or circuit-breaker was in place to isolate plugin failures from the gateway process.

**Why 4 — Why was there no circuit-breaker?**
Plugin failure modes were not fully mapped during initial gateway setup; the assumption was that plugins fail gracefully.

**Why 5 — Why was that assumption unchallenged?**
No formal plugin failure test was included in the deployment checklist for new plugins.

**Root Cause:** Bonjour/ciao plugin lacked crash isolation. A single plugin's crash-loop brought down the entire gateway process.

---

### Incident B: Model Drift (Contributing)

**Why 1 — Why was Opus active instead of Sonnet?**
After a gateway reset, the model reverted to a non-default or cached configuration.

**Why 2 — Why did a reset change the model?**
Model selection was not persisted or enforced at startup; it relied on session-level state that was wiped on reset.

**Why 3 — Why was it not caught immediately?**
No automated check validated the active model after gateway restarts.

**Why 4 — Why did it happen twice?**
The first correction was manual only — no preventive control was put in place before the second drift occurred.

**Root Cause:** Model selection was ephemeral and unchecked. No post-restart validation existed.

---

## 3. Impact

| Category | Detail |
|----------|--------|
| **Service** | Gateway crash — full service outage for ~30 min (est. 19:30–20:00 AEST) |
| **Model** | Opus active twice instead of Sonnet — elevated cost risk, unexpected behaviour |
| **Night outage** | Billing/auth failure — duration unknown, detected at session start |
| **Users affected** | Ken Mun (primary), AInchors operations |
| **Data loss** | None |
| **Revenue impact** | Low — internal ops tool only |

---

## 4. Detection

| Event | How Detected | Alerting Adequate? |
|-------|--------------|--------------------|
| Gateway crash | Ken observed — no automated alert fired | ❌ No |
| Model drift x1 | Ken observed during session | ❌ No |
| Model drift x2 | Ken observed again | ❌ No (Check #12 built post-incident) |
| Night outage | Detected at next session start | ❌ No |

**Gap:** Automated detection was absent or too slow for all four failure modes on this day. Detection was entirely human-driven.

**Mitigating factor:** Diagnostics framework and auto-heal were built and deployed on the same day, significantly improving future detection posture.

---

## 5. Response

| Action | Result | Time to Resolve |
|--------|--------|-----------------|
| Gateway restart after crash | ✅ Restored | ~30 min |
| Bonjour/ciao plugin disabled | ✅ Crash-loop stopped | Immediate after diagnosis |
| Manual model correction x1 | ✅ Sonnet restored | ~5 min |
| Anti-drift baseline + Check #12 built | ✅ Auto-heal now guards this | Same session |
| Dual Telegram bot (CHG-0038) | ✅ Ops resilience improved | Same session |
| Night outage — billing/auth | 🔲 US23 raised, investigation pending | TBD |

**What worked:** Rapid diagnosis of plugin root cause. Same-day hardening response. Diagnostics built while incident was live.

**What didn't work:** No automated alerting. Manual detection added delay. Model drift occurred twice before a preventive control was coded.

---

## 6. Prevention

| Control | Status | Change Ref |
|---------|--------|------------|
| Bonjour/ciao plugin disabled | ✅ Done | CHG-0036 |
| Anti-drift baseline + Check #12 auto-heal | ✅ Done | CHG-0037 |
| Dual Telegram bot for ops comms resilience | ✅ Done | CHG-0038 |
| Plugin crash isolation / circuit-breaker | 🔲 Needed | Backlog |
| Billing/auth hardening | 🔲 In progress | US23 |
| Post-restart model validation | ✅ Done (Check #12) | CHG-0037 |
| Automated gateway crash alert | 🔲 Needed | Backlog |

---

## 7. Action Items

| # | Action | Owner | Due | Ref | Verification |
|---|--------|-------|-----|-----|--------------|
| 1 | Investigate and resolve billing/auth night outage | Ken / Yoda | 2026-05-05 | US23 | Auth confirmed stable for 72h |
| 2 | Evaluate Bonjour/ciao plugin stability; re-enable with circuit-breaker or replace | Ken | 2026-05-12 | CHG-0036 | Gateway stable 7 days post re-enable |
| 3 | Add plugin failure isolation to gateway deployment checklist | Yoda | 2026-05-05 | CHG-0036 | Checklist updated in ops docs |
| 4 | Add automated gateway crash alert (health-check → Telegram) | Yoda | 2026-05-05 | CHG-0037 | Alert fires on test crash |
| 5 | Validate anti-drift Check #12 under load / after extended resets | Yoda | 2026-05-05 | CHG-0037 | 3 consecutive clean diagnostics |
| 6 | Dual Telegram bot — confirm failover works end-to-end | Yoda | 2026-05-02 | CHG-0038 | Manual failover test passes |

---

## Sign-off

- **PIR facilitated by:** Yoda (AI ops lead)
- **Reviewed by:** Ken Mun (CTO)
- **Closed:** 2026-04-29T11:29:00+10:00
- **Next review trigger:** Any P1/P2 incident or recurrence of model drift

---

_Filed to: `state/pir/PIR-20260428-COMPLETE.md` | Source: PIR-20260428-20260428-002.json_
