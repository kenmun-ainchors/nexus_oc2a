# Yoda Daily Brief — 2026-05-09 (Day 15)

_Written for Aria 🔵 and Angie 🌟. Plain language. No jargon._

---

## What We Built Today

### 🏷️ The Company Has a Legal Name — Aevlith Technologies
The biggest decision of the day. Ken and the team needed a separate technology holding company (the entity that owns the Nexus platform). The original name, "Auralith," was taken — someone already registered that exact name in Australia (ABN 43 675 437 500) and there were conflicts in the UK, US, and India too.

**New name locked: Aevlith Technologies Pty Ltd.** Pronounced "AYV-lith." It comes from Latin *aevum* (timeless) and Greek *lithos* (foundation). Clean globally — no conflicts anywhere checked. Domain: aevlith.ai.

What this means: AInchors is the public face (the consulting brand Ken and Angie run). Aevlith is the invisible company behind it that owns the platform. They stay separate until Phase 4 when Nexus gets sold commercially to third parties.

Six tickets raised off the back of this — partnership agreement, ASIC registration, domain purchases, trademarks. All tracked.

---

### 📧 Standup Emails Now Display Correctly
The morning standup emails Ken receives were built with a dark theme. Gmail marks dark-themed emails as potentially promotional, and on some email clients the colours inverted and became unreadable.

Fixed: standup emails are now light theme (white background, dark text, blue headings). Looks clean in any email client, doesn't trigger Gmail's dark-mode detection.

---

### 🔍 The Observability Gap — Now Closed
The platform has a central database called `obs.db` that tracks every error, failure, and health event. Problem: only 15 types of errors were being written to it. Things like cron job failures, budget exceeded, Warden policy violations, and PVT test failures were happening — but never making it into obs.db.

Today: 10 new error categories (Q–Z) added. **Rule now locked:** anything that can go wrong must be recorded in obs.db. No exceptions. Any new error-generating script must wire into obs.db in the same change.

---

### 📚 18 Platform Learnings Formalised
We went back through 15 days of journals and changelogs and extracted every hard-won lesson. 18 learnings total (L-001 to L-018), plus 3 more from tonight's LinkedIn incident (L-019 to L-021). These cover everything from "don't store large JSON in shell variables" to "always set an explicit Telegram account ID — never rely on defaults."

Key ones worth noting:
- **L-009:** Zombie tasks can saturate the platform's event loop (we saw 28-second delays from this)
- **L-010:** Agent config files over 10,000 characters = silent truncation = wrong Telegram targets + platform crash
- **L-016:** Cost tracking must use `confirmedBalance − spentAfterDate` — any other method double-counts

All 18 live in the Notion Holocron.

---

### 🆕 New AI Model Added — Gemma4:31b Cloud
A new model became available through our Ollama Cloud provider: Gemma4 31 billion parameter, cloud-hosted. It's fast (1–4 seconds per task), handles 256,000 tokens of context, can process images as well as text, and produced quality output in benchmarking (4.2 out of 5).

Added to our model strategy for background/automated tasks (cron jobs). Running a 5-day comparison trial starting 14 May — Ken will receive outputs from both this model and kimi on Telegram and can directly compare.

---

### 🔄 CI Model Strategy Reset
The continuous improvement framework (CI Cycle A/B) was running. Cycle B was supposed to kick off with the top candidates from Cycle 1A — but when we reviewed, none of them hit the confidence gate (75% pass rate required). So Cycle B is cancelled for now.

Cycle 2A is now running with three fresh candidates: deepseek-flash, kimi, and gemma4:31b-cloud. 7-day window. If they clear the gate, Cycle B fires.

---

### 🛠️ LinkedIn Posting — Three Hard Lessons
A post (about RustDesk) went wrong tonight. Three separate bugs were discovered and fixed:

1. **Large JSON in shell variables gets silently truncated.** The post was cut off mid-sentence with no error. Fix: always write JSON to a temp file and use `curl --data-binary @file`.
2. **Content file parser silently ignores content without proper delimiters.** Post went live with only hashtags. Fix: script now fails loudly if the `---` delimiters are missing.
3. **LinkedIn API delete requires a scope we don't have.** The API returned 404 (misleadingly — not 403). Manual delete from LinkedIn UI for now. Scope fix queued.

---

### 🔬 Mission Control + obs-collector Bug
The Mission Control dashboard was showing 3,761 delegation failures in 24 hours — alarming. Investigation found it was a bug in the obs-collector script: it was looking for a timestamp field called `timestamp` or `at`, but the actual field in the log is `ts`. Every failed parse re-logged all 34 real failures every 5 minutes → metric inflation.

Fixed. Real count: 34 delegation failures since Day 1 (normal). 238 health failures = the API outage period (also expected). Dashboard now clean.

---

### 🚨 INC-20260509-001 — API Outage (Resolved)
The platform went down for ~26 hours when the API credit balance hit zero. Auto-reload kicked in once the balance hit $15 (TRIGGER-08), and $479.35 was reloaded. Platform fully recovered. Ken was offline at the time; Yoda handled recovery autonomously.

Lesson raised: we need a fallback alert channel that doesn't depend on the Anthropic API being up. If the API is down, we can't use Claude to send a "the API is down" alert. Ticket raised (TKT-0113) for an API-independent alert path.

---

## Key Decisions Made

| Decision | Detail |
|----------|--------|
| **Aevlith Technologies Pty Ltd** | Name locked. Zero conflicts. ASIC registration + aevlith.ai this week (blocked on partnership agreement). |
| **obs.db = SSOT for all errors** | Architecture rule. Any new failure state file → must wire to obs.db in same CHG. Non-negotiable. |
| **Cycle B cancelled** | 75% pass gate not cleared by Cycle 1A candidates. Cycle 2A running with 3 new candidates. |
| **Gemma4:31b-cloud approved** | Added to Tier 2 model strategy for background cron tasks. 5-day trial vs kimi starts 14 May. |
| **L-019 curl rule locked** | All curl API calls with multi-line payloads must use `--data-binary @tempfile`. No shell variable passing. |
| **INC-20260509-001 closed** | API degradation resolved. TRIGGER-08 auto-reload confirmed working. TKT-0113 raised for next gap. |

---

## Training Content Angles

_What from today's work would make great AI training course material?_

- **"When your tech entity needs to be invisible"** — the Aevlith story. How do you structure an IP holding company that doesn't show up publicly until you're ready? Real decision-making process, naming constraints, international trademark checks.
- **"Mining your own failures: 18 lessons from 15 days"** — retrospective methodology. How to go back through changelogs and journals and turn every incident into a reusable learning. Structured approach, categorisation, how to make them non-negotiable rules.
- **"The observability blind spot: what your error database isn't capturing"** — most platforms only wire up some of their error sources. Systematic approach to finding and closing all the gaps. The Q-Z framework.
- **"Why your API alert system can't tell you the API is down"** — the circular dependency problem. If your alerting relies on the thing that's broken, you get silence. Designing API-independent fallback channels.
- **"Shell variables that lie: the LinkedIn post that published only hashtags"** — practical coding lesson. The silent truncation bug, how to detect it, how to fix it. Great for developers new to shell scripting + API integration.
- **"Artificial inflation: when your metric dashboard is measuring its own bug"** — the obs-collector `ts` vs `timestamp` incident. 3,761 vs 34. How to spot metric inflation, root cause it, and trust your dashboards again.

---

## What's Open / What's Next

### This Week (Critical)
- **TKT-0114:** Ken + Angie to sign AInchors–Aevlith partnership agreement → BLOCKER for everything else
- **TKT-0113:** Fallback alert channel (API-independent) — HIGH priority after today's outage
- LinkedIn `--content-file` guard fix and token scope update (queued from tonight's incident)

### Upcoming
- **TKT-0115/0116/0117/0118:** ASIC registration + domain purchases (blocked on TKT-0114)
- **TKT-0119:** IP Australia trademark (Classes 35+42) — P2 milestone, Lex to review
- Gemma4:31b-cloud vs kimi RTB trial: 14–18 May, Ken reviews Telegram outputs
- Ahsoka pilots: pilot1 in_progress, pilot2 pending — gate check when both complete
- OC2 hardware: ETA 6–13 July. Commissioned ~27 July.

### Sprint Context
- Sprint 1 running. Pre-OC2 capacity: 5 items/sprint. 30% headroom buffer.
- P2 target: end-August 2026. Contingency: mid-September.

---

_Synced: 2026-05-09 23:00 AEST | Yoda 🟢_
