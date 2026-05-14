# Yoda Daily Brief — 2026-05-14 (Day 20)
_Written by Yoda 🟢 for Aria 🔵 + Angie | ~11:00 PM AEST_

---

## What Happened Today

Day 20 was one of the biggest architecture days so far. Ken and Yoda locked in the platform's long-term direction, produced two major reference documents, and fixed a cascade of smaller issues that had been building up.

### The Big Decision: Which Way Does the Platform Go?

The morning started with a question that's been brewing for a while: how should Nexus be redesigned to support paying clients without becoming a mess?

Yoda commissioned Atlas (the enterprise architect agent) to write a formal option paper overnight. By morning it was ready — three options laid out with pros, cons, and scores:

- **Option A** — Patch what we have, keep improving incrementally. Simple but limited.
- **Option B** — Redesign the data and integration layers properly, but keep OpenClaw as the platform. Best of both worlds.
- **Option C** — Full rebuild from scratch. Maximum flexibility, maximum risk.

Ken chose **Option B, phased delivery**. This was the recommendation too — score 4.70 out of 5. The logic: OpenClaw works well, the problem is that data is scattered in flat JSON files and agents hand work to each other informally. Fix those two things (proper database, defined integration contracts) and the platform is ready for clients. Don't rebuild everything.

Ken also introduced something we're now calling the **Work Currency Model** — a way of thinking about which AI model to use based on how much "thinking work" a task actually needs. High-currency work (real decisions, drafting, complex analysis) → use Sonnet or Haiku. Medium-currency → use Kimi (Ollama Cloud). Low-currency or no-LLM-needed → use scripts or system events. This immediately applied: four high-frequency monitoring crons that were consuming main Sonnet session turns were moved to isolated Haiku/Kimi sessions, saving roughly $19 per 11-hour window.

### Two Golden Blueprint Documents Approved

With the architecture direction decided, the next step was documenting it properly so every agent (and future team member) can read one place and know the full picture.

Two documents were produced and approved today:

**1. Technology Strategy & Roadmap v1.0 (Internal)** — Vision, principles, P1-P4 roadmap, model and cost strategy, OKRs. This is the "why and where we're going" document.

**2. Nexus System Architecture v1.0** — The full stack: every agent, all infrastructure, data architecture, integration design, security controls, what the platform looks like today, and what it should look like by P2. This is the "what and how it works" document.

Five older fragmented docs were officially retired. These two replace all of them. Both are now the definitive reference — any agent doing architectural work must read these before making design decisions.

Ken also set up automatic review triggers so the documents stay current at each major platform milestone (P1, P2, P4 and annually).

### LinkedIn Gets Its Analytics Layer

LinkedIn approved AInchors' Advertising API access (the MDP program), which unlocks the ability to pull post performance data — likes, comments, reach — via API.

There was a fair bit of troubleshooting to get the new token working (the client secret was stale, PKCE had to be removed, and the redirect URI needed confirming). End result: token issued, valid until 12 July 2026, with 10 API scopes including analytics and organization management.

To actually use the analytics data, the posting script was also updated to capture the "activity URN" — a unique ID LinkedIn assigns to every post — and store it in the queue file. Without that ID, there's nothing to query when we want to pull stats later.

Also today: Spark accidentally posted two LinkedIn posts (one from a cancelled series, one from the live series). Root cause was a verbal-only cancellation that was never written to the queue or cron. New rule: any post cancellation must be confirmed by Yoda as "cron deleted + queue updated." No verbal-only acknowledgements.

### Gateway Had a Rough Afternoon

The intensive Day 20 work — 12+ Atlas sub-agents running, the grooming session, lots of document generation — pushed the gateway's event loop to 98.3% utilisation (max delay of 28 seconds). Seven tasks were lost in the queue.

A restart was needed. Post-restart, three hygiene crons were added: Mission Control refresh slowed from 5 minutes to 15 minutes, a weekly automatic gateway restart (Saturday midnight), and a daily stale task cleanup (3am). These prevent the same situation building up again.

### Operational Tidying

- **Config baseline false positives fixed** — Auto-heal was generating 38+ false "config drift" alerts per run because the baseline file was from before the model format changed in May. Updated. Auto-heal should now run clean.
- **Cost tracker classification fixed** — 6 agents (Lando, Mon Mothma, Ahsoka and others) were falling into the wrong stream category or being missed entirely. All 12 agents now correctly classified across technical, business, and consulting streams.
- **Daily budget cap** — Temporarily raised to $450 (from $150) for the build phase through Sunday. Actual spend has been ~$400/day during this intensive architecture period.
- **Grooming session** — 54 open tickets organised into buckets, Sprint 4-8 plan locked.

---

## Key Decisions Made

| Decision | What Was Decided | Who Approved |
|---|---|---|
| Architecture Direction (TKT-0162) | Option B Phased — redesign data + integration layers, keep OpenClaw | Ken (10:28 AM AEST) |
| Work Currency Model | High-currency→Sonnet/Haiku, Medium→Kimi, Low→scripts | Ken (locked) |
| Golden Blueprint Documents | Two docs approved as definitive platform reference | Ken (12:39 PM AEST) |
| 1b external version deleted | External strategy doc deleted per Ken instruction | Ken |
| Sprint 4–8 plan locked | 8 new architecture tickets sequenced S4-S8 | Ken (10:55 AM AEST) |
| Post cancellation rule (L-027) | Verbal cancellations never valid — must confirm cron deleted + queue updated | Ken (implicit, locked) |
| Budget cap temp raise | $150 → $450 until Sunday 17 May | Ken (11:32 AM AEST) |
| Golden Blueprint review cadence | P1/P2/P4 triggers + annual cron for document freshness | Ken (12:49 PM AEST) |

---

## Training Content Angles (for AI Courses)

*New ideas from today's work — what lessons are worth teaching?*

**TC-117 — The Work Currency Model: matching your AI model tier to the task**
Not every AI task needs your smartest model. Today we formalised a framework: high-currency work (real decisions, complex analysis) → premium models; medium-currency (summaries, drafts) → mid-tier cloud models; low-currency (monitoring, triggers) → scripts or system events. Result: ~$19/11hr saved by moving four monitoring crons off the main session. The principle: treat AI time like a budget line, not an unlimited resource.
*Source: CHG-0307/0308/0323 — Work Currency Model*

**TC-118 — From five fragmented docs to two golden blueprints: how to consolidate your platform knowledge**
After 20 days of building, we had five separate architecture documents — each partially right, some contradicting others. Today we produced two definitive reference documents that supersede all of them. Lesson: scattered documentation is a governance risk. Every agent making design decisions was working from different assumptions. One truth source beats five partial truths.
*Source: CHG-0315/0318 — Golden Blueprint consolidation*

**TC-119 — When the platform eats itself: diagnosing gateway event loop saturation from intensive AI workloads**
Running 12+ concurrent sub-agents for architecture work pushed the gateway's event loop to 98.3% utilisation — 28-second delays, 7 lost tasks. The fix was a restart, but the prevention is: weekly scheduled restarts, slower polling intervals, and daily stale task cleanup. Lesson: AI platforms have resource ceilings like any other system. Know your limits before they find you.
*Source: CHG-0320/0321 — Event loop saturation incident*

**TC-120 — Closing the LinkedIn analytics loop: why you need to store the post ID at publish time**
LinkedIn's analytics API requires an "activity URN" — a unique post identifier — to pull performance data. But if you don't store it at the moment of posting, it's gone. Today we updated the posting script to capture and store this ID in the queue file. Lesson: analytics pipelines need to be designed at publish time, not after the fact.
*Source: CHG-0322 — linkedin-post.sh activity URN tracking*

**TC-121 — When your $150 budget cap costs $400 a day: how to detect and respond to cost reality drift**
Our daily budget cap was $150. Actual spend during the intensive build phase: ~$400/day. The cap was exceeded 6 out of 10 days — but nobody caught it early because the tracker was running behind. Today we raised it temporarily to match reality and commissioned a full cost investigation. Lesson: budget caps without accurate tracking are false comfort. Verify your tooling before trusting your numbers.
*Source: CHG-0312/0313 — Budget cap raise + cost investigation*

---

## What's Open / What's Next

### Tomorrow (Friday 16 May)
- 08:00 AEST: Reminder cron fires → Batch DRAFT FOR REVIEW session (governance docs to review before Sprint 4)
- Ken to discuss TKT-0114 (Aevlith/Angie) — partnership formalisation
- Standup email format issue still unresolved — Ken to describe what specifically looks wrong

### Sprint 4 (Starts Monday 19 May — Planning: Sunday 18 May)

| Ticket | What It Is | Priority |
|---|---|---|
| TKT-0141 | Security close-out (S3 carry) | P1 |
| TKT-0142 | Security close-out (S3 carry) | P1 |
| TKT-0165 | Three Work Types Rule implementation | P1 |
| TKT-0166 | SoT Register | P1 |
| Cloudflare Tunnel | CF Access config | P1 |

### Sprint 5 (May 26+)
- **TKT-0164 Postgres** — Critical path for P2. Data architecture foundation.
- TKT-0108 doc gen, TKT-0157 client isolation policy, TKT-0156 guardrails, TKT-0130 QBR

### Waiting On Ken
- DRAFT FOR REVIEW batch session (Friday 16 May reminder set — 5 docs pending)
- Standup email format feedback (what specifically looks wrong?)
- TKT-0114 discussion with Angie (Aevlith partnership)
- HF API key for Keychain (TKT-0121 — LinkedIn image gen via FLUX)
- AInchors LinkedIn company page onboarding (deferred, Trigger 05f9d2ef set)

---

*Next brief: tomorrow after close | Questions → ask Yoda in main chat*
