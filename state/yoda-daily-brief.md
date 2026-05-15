# Yoda Daily Brief — 2026-05-15 (Day 21)
_Written by Yoda 🟢 for Aria 🔵 + Angie | ~11:00 PM AEST_

---

## What Happened Today

Day 21 was a day of crises, recoveries, and hard decisions. The platform survived two significant challenges — and came out stronger on the other side with new rules, a formal emergency runbook, and a cost forecast for the months ahead.

### Morning: Platform Tuning and Sprint Close-Out

The day started with Ken verifying TKT-0160 (context unification between Telegram and webchat). After testing, we confirmed Option C as the final state: **kimi on Telegram, Sonnet on webchat**, with a context brief refreshed twice daily (2pm + 8pm) to bridge the gap. Ken also approved two new tickets for Sprint 5: TKT-0175 (fixing cost tracker blind spots) and TKT-0176 (tech stream ROI framework).

Ken then completed Sprint 3 review and staged Sprint 4 backlog — 15 candidate items ready for Sunday planning. Three hard commitments already locked: Three Work Types Rule, Sources of Truth Register, and Cloudflare Tunnel.

### Afternoon: Cost Tracking Fixed and Forecast Built

Ken asked for a cost report for Angie. The tracker had been undercounting by about 20% due to isolated cron/subagent sessions that don't write to the main log. Ken suggested a simple calculated approach (turns × model rate × token estimate) — much more practical than reverse-engineering OpenClaw internals. Approved and locked for Sprint 5.

Ken then asked for a **full cost forecast to P4 completion** (end of year). Three scenarios generated:
- **Scenario A (Best):** $61,270 — no contingency, everything goes to plan
- **Scenario B (Realistic):** $70,460 — 15% contingency, our recommendation
- **Scenario C (Worst):** $79,651 — 30% contingency, all risks materialise

Plus a focused P1-only breakdown with three scope variants (full / core / bare minimum) to help Ken size the immediate work. Reports emailed as DOCX.

### Evening: API Emergency — All Agents Switched to kimi

At 5:18 PM, Ken declared an emergency: **Claude API credits depleted, auto-reload not firing.**

All 12 agents were immediately switched from Sonnet/Haiku to **kimi (Ollama Cloud)** as primary model. Key actions:
- **Keyword locked:** `CLAUDE RESTORE` — Ken says this, we revert instantly
- **Config saved:** Original Sonnet/Haiku settings backed up for clean rollback
- **Conservative mode activated:** No risky state manipulation (file edits, restarts, deletions) without explicit Ken "PROCEED" approval
- **Model Emergency Runbook v1.0** created — formal procedure for future incidents

Later in the evening, Warden detected Anthropic API returning HTTP 502 (unreachable). Because all agents were already on kimi, there was **zero platform impact.** The interim switch proved its value.

### Key Learning from the Emergency

The emergency exposed a gap: kimi doesn't handle complex orchestration as reliably as Sonnet. A control UI session (system-level, not Ken's chat) was creating independent sessions — something Sonnet never did. We implemented an explicit routing workaround and documented it. The lesson: **interim models need interim rules.**

---

## Key Decisions Made

| Decision | What Was Decided | Who Approved |
|---|---|---|
| TKT-0160 final state | Option C confirmed: kimi Telegram + Sonnet webchat + 2x daily context brief | Ken (14:27) |
| Context brief cadence | 30-min → 2x daily (2pm + 8pm), silent (no notifications) | Ken (17:27) |
| TKT-0175 strategy | Calculated cost approach (turns × rate × tokens) vs file parsing | Ken (09:51) |
| TKT-0176 raised | Tech stream ROI framework — groom and populate | Ken (10:32) |
| Sprint 4 planning | Sunday 18 May 09:00 AEST | Ken (17:32) |
| Telegram model revert | Back to Sonnet (main) — kimi risk unacceptable for mobile work | Ken (14:36) |
| API emergency switch | All 12 agents → kimi primary, deepseek fallback | Ken emergency (17:18) |
| Conservative mode | No risky state manipulation without explicit "PROCEED" | Ken (18:30) |
| Emergency runbook | `CLAUDE DEPLETED` = trigger, `CLAUDE RESTORE` = rollback | Ken approved (18:35) |
| Cost forecast | Three scenarios to P4: A=$61K, B=$70K, C=$80K | Ken (20:29) |

---

## Training Content Angles (for AI Courses)

*New ideas from today's work — what lessons are worth teaching?*

**TC-122 — The calculated cost approach: when perfect tracking is impossible, build a good-enough model**
Ken suggested avoiding complex OpenClaw internals and instead using turn counts + model rates + token estimates to fill tracking gaps. Result: ~1.20x adjustment factor captures 95% of missed costs. The principle: when ground truth is expensive, a validated estimate beats a blind spot.
*Source: TKT-0175 — Calculated cost fallback for ephemeral sessions*

**TC-123 — Emergency model switching: the runbook that saves your platform when the API dies**
When Claude API credits depleted, we switched all 12 agents to kimi in under 10 minutes with zero downtime. The key was having: (1) a pre-defined trigger keyword (`CLAUDE DEPLETED`), (2) saved config for instant rollback (`CLAUDE RESTORE`), (3) conservative mode rules to prevent kimi from making bad decisions under pressure. Lesson: plan for API failure before it happens.
*Source: CHG-0348/0349/0350/0351 — Model Emergency Runbook v1.0*

**TC-124 — Interim models need interim rules: why kimi can't do everything Sonnet does**
Switching to kimi introduced new failure modes: control UI sessions creating independent contexts, weaker reasoning on complex orchestration, false positives on state checks. We had to add explicit routing rules and conservative mode. The lesson: a model swap isn't just a config change — it's an operating model change.
*Source: CHG-0350/0351 — Conservative mode + control UI mitigation*

**TC-125 — Cost forecasting for AI platforms: three scenarios every founder needs**
Ken asked for a forecast to P4 completion. We built three scenarios (best/realistic/worst) with phase buffers, contingency tiers, and explicit assumptions. The lesson: AI platform costs are predictable if you track daily burn, know your model mix, and size your phases. Don't guess — model it.
*Source: CHG-0354/0355 — Cost forecast to P4, P1 scenario DOCX reports*

**TC-126 — When the API goes down and you're already switched: the value of proactive failure modes**
Warden detected Anthropic HTTP 502 at 7:16 PM. If agents were still on Sonnet, this would have been a platform outage. Because we'd already switched to kimi at 5:18 PM, impact was zero. The lesson: sometimes the best incident response is the one you already did.
*Source: CHG-0349 — Standby mode activation with zero impact*

---

## What's Open / What's Next

### Tomorrow (Saturday 16 May)
- Standby mode continues — all agents on kimi until `CLAUDE RESTORE`
- Conservative mode active — any destructive action needs explicit Ken approval
- Context brief refreshes at 2pm and 8pm (silent)

### Sunday 18 May — Sprint 4 Planning (09:00 AEST)
- Triage 15 candidate items down to ~5 committed + carry
- Decide: kimi standup pilot — CONTINUE or REVERT?
- Three hard commitments: TKT-0196 (Three Work Types), TKT-0197 (SoT Register), TKT-0187 (Cloudflare Tunnel)

### Sprint 4 (May 19–25)
- TKT-0196, TKT-0197, TKT-0187 (committed)
- TKT-0175, TKT-0176 (carries from Sprint 3)
- 8 DRAFT FOR REVIEW docs to batch-review (TKT-0162–0168)

### Waiting On
- `CLAUDE RESTORE` from Ken when Anthropic credits reload
- Angie: Brand Code review (7 DRAFT docs)
- OC2 arrival: July 6–13 (TRIGGER-01)

---

*Next brief: tomorrow after close | Questions → ask Yoda in main chat*
