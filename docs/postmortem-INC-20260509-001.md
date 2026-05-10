# Post-Mortem: INC-20260509-001
**Incident:** Extended API Degradation — Anthropic balance zero  
**Severity:** P2 | **Duration:** 25h 54m | **Author:** Yoda 🟢  
**Date written:** 2026-05-10 | **Review:** Ken Mun

---

## 1. Summary

Anthropic API balance hit $0 on 2026-05-08 at ~10:05 AEST. All agent operations requiring Claude API calls degraded or failed. The system ran blind for ~26 hours — the alert mechanism designed to notify Ken could not fire because it depended on the same API that was down. Ken manually detected the issue and topped up the balance on 2026-05-08 at ~21:32 AEST. Full recovery confirmed 2026-05-09 at 12:00 AEST.

---

## 2. Timeline

| Time (AEST) | Event |
|-------------|-------|
| May 8 ~10:05 | API balance hits $0. First health_failure events logged in obs.db. |
| May 8 ~10:05 | Telegram alert system attempts to fire — silently fails (requires Anthropic API). |
| May 8 ~10:05–21:32 | System runs degraded. 274 health_failure + 99 delegation_fail events accumulate. Worst hour: 8PM AEST (420 errors/hour). No alert reaches Ken. |
| May 8 ~21:32 | Ken manually detects, tops up API balance to $479.35. |
| May 8 ~21:36 | Last health_failure recorded. API recovering. |
| May 9 ~12:00 | Yoda detects via obs-trend review. Confirms full recovery. TRIGGER-08 re-armed. |
| May 9 ~12:14 | INC-20260509-001 formally logged. TKT-0113 raised. |

**Total duration:** 1,554 minutes (~25h 54m)  
**Client impact:** None (P1 ops only, no external clients yet)  
**Ops impact:** All Yoda/Aria/agent operations degraded for ~26h

---

## 3. Root Cause

**Primary:** Anthropic API balance depleted to $0. No credit remained to serve requests.

**Contributing — Critical:** Alert system architectural dependency failure.  
The Telegram alert mechanism (health-check.sh → Claude API → Telegram) required the Anthropic API to construct and send the alert. When the API went down, the alert system went down with it. The failure mode that most needed alerting was the exact failure mode that disabled alerting.

**Contributing — Moderate:** Auto-reload threshold too low at time of incident.  
TRIGGER-08 was defined but had not been confirmed firing reliably. Balance depleted past the threshold without triggering a reload.

**Contributing — Minor:** No secondary human-visible indicator.  
No dashboard, no SMS, no non-API fallback that Ken could observe passively.

---

## 4. Impact Assessment

| Category | Impact |
|----------|--------|
| Agent operations | ❌ Degraded ~26h. All Claude-dependent tasks failed silently or queued. |
| Alerting | ❌ Complete failure. Zero notifications reached Ken during outage. |
| Data integrity | ✅ No data lost. obs.db recorded all failures accurately. |
| External clients | ✅ No impact. No P2 clients yet. |
| Recovery | ✅ Full. Self-recovered once balance restored. |
| Detection | ⚠️ Manual by Ken. Not by Yoda or automated system. |

---

## 5. What Went Well

- obs.db faithfully recorded all 274+ failure events — full audit trail exists
- Auto-reload (TRIGGER-08) was in place and re-armed correctly post-recovery
- No data corruption or state inconsistency from the outage
- Recovery was clean and immediate once balance was restored
- Ken identified and resolved without requiring Yoda guidance

---

## 6. What Went Wrong

| Finding | Severity |
|---------|----------|
| Alert system depends on the thing it monitors — circular failure | 🔴 Critical |
| 26h blind spot — no detection until Ken manually checked | 🔴 Critical |
| Auto-reload didn't prevent balance hitting $0 | 🟠 High |
| No non-API fallback communication path exists | 🔴 Critical |
| Post-mortem delayed 22 days (written 2026-05-10, incident 2026-05-09) | 🟡 Medium |

---

## 7. Action Items

| # | Action | Owner | TKT | Status | Due |
|---|--------|-------|-----|--------|-----|
| A1 | Build API-independent fallback alert (Telegram bot direct HTTP, no Claude) | Yoda | TKT-0113 | Open | Sprint 2 |
| A2 | Raise balance alert threshold — warn at $80, not $50 | Yoda | — | ✅ Done (TRIGGER-08 T1 threshold) | Done |
| A3 | Add billing card validation reminder — monthly cron checks card hasn't expired | Yoda | — | 🟡 Open | Sprint 2 |
| A4 | health-check.sh: if Anthropic API fails, attempt SMS/non-API path | Yoda | TKT-0113 | Blocked on TKT-0113 | Sprint 2 |
| A5 | Add Anthropic balance check as a Krennic SRE runbook item | Yoda | TKT-0074 | Open | OC2 sprint |
| A6 | Document: "what to do if Yoda goes silent" — Ken's manual recovery guide | Yoda | — | 🟡 Open | Sprint 2 |

---

## 8. Preventability

**Yes — fully preventable** with two changes:
1. **API-independent alert path** (TKT-0113) — the single highest-leverage fix. A Telegram bot calling the Telegram API directly (HTTP, no Anthropic) would have fired within minutes of the first health failure.
2. **Higher early-warning threshold** — T1 alert at $80 now active. With auto-reload at <$50, balance should never approach zero again under normal usage.

---

## 9. Systemic Learnings

**L-019 (added 2026-05-09):** Alert system must not depend on the component it monitors. Health alerts must use a communication path that is independent of the Anthropic API.

**L-020:** Auto-reload is not a substitute for an alert. Auto-reload prevents the outage; the alert is needed when auto-reload itself fails (billing card expired, Anthropic billing system down, etc.).

**New learning (this post-mortem):**  
**L-021:** Every critical failure mode must have a human-visible signal that doesn't depend on the system under failure. For AInchors P1: Telegram bot HTTP direct = minimum viable fallback. For P2+: SMS/WhatsApp via independent provider.

---

## 10. Follow-Up

- **TKT-0113** (fallback alert) is in this sprint's candidate list — needs to move to committed.  
- **Krennic** (SRE agent, TKT-0074) would own runbooks and SLO definitions that would have caught this faster. Build trigger: OC2 sprint.
- This post-mortem to be shared with Angie as context for why TKT-0113 is HIGH priority.

---

*INC-20260509-001 closed. Post-mortem complete.*
