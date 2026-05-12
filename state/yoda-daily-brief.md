# Yoda Daily Brief
_Shared knowledge bridge for Aria 🔵 and Angie. Updated nightly by Yoda._

---

## 2026-05-12 — Day 18

### What Yoda Built Today

It was a big governance and hygiene day — less new features, more making sure the platform is rock-solid before the next growth phase.

**Morning:**
- Fixed the standup report cron that was silently failing to write its HTML file (turned out isolated sessions don't expand `~` in file paths — classic silent failure, now a permanent rule).
- Cleaned up Warden's noise problem — it was logging 3 error entries per check run, so the platform looked like it had 141 violations when it actually had 49. Fixed so it logs one clean summary per run. The platform was genuinely healthy — the metrics just weren't telling the truth.
- Made the Kimi vs Gemma4 model comparison fair — both now run with an identical prompt spec so we're actually comparing models, not prompts.
- Finished the MinIO folder structure (53 folders across 4 buckets) and wrote the routing policy — every agent now knows exactly where to store what.

**Midday governance marathon (with Ken):**
- Created the **Decision Registry** in Notion — 19 platform decisions formalised, 17 closed. Huge milestone. This closes the gap where decisions were being made but not officially recorded.
- Added the **Strategy-Gate Rule**: if a task depends on a document that's still "Draft for Review", work stops until it's approved. (Root cause: we built MinIO before the storage architecture doc was fully signed off.)
- Added the **Ticket Discipline Rule**: all agents must use `ticket.sh` to close tickets — no more direct file writes that skip Notion sync. Patched all 11 agent rule files.
- LinkedIn post cleanup: stripped internal agent names (Atlas, Thrawn, Forge) from the AIOps Part 2 draft — replaced with a better angle about monitoring overhead costs.

**Afternoon:**
- Fixed S5 security violation — stale Anthropic API keys found hardcoded in 6 agent auth files. Removed. (TKT-0156)
- Fixed CI Cycle A timing out — batch was too heavy (4 shadow tasks at once). Reduced to 2, timeout halved. (TKT-0154)
- Approved the Governance Gap Analysis (TKT-0137) — 7 open decisions resolved, Tier 3 agents (Forge, Lando, Mon Mothma) formally enrolled in governance framework.
- Approved the **Nexus Access Policy v1.0** — the official document governing who can access the platform and how.

**Evening:**
- Ran a full backlog cleanup — ~57 items closed, 35 valid items kept, 10 items scheduled for P1/P2 gates.
- Approved the **Fabric RAG Assessment** (Ken's decision: defer Fabric CLI to P2, confirm Atlas as pattern governance owner).
- Added the **Holocron Document Registry DoD rule** — every agent-produced document must be registered in the Holocron with a Drive link. Non-negotiable from now on.
- Added the **Routing Discipline Rule** — Yoda orchestrates only. Build/implement/scripts always go to Forge. No exceptions, even when Ken says "do it now."
- Fixed the sprint assignment backlog: items sorted into Sprints 4–10 with proper P1/P2 gates.

---

### Key Decisions Made Today

| # | Decision | Who | Outcome |
|---|----------|-----|---------|
| DEC-001 to DEC-017 | Full decision grooming | Ken + Yoda | 17 of 19 closed/deferred |
| CHG-0281 | Absolute file path rule | Ken | Never use `~` in tool calls — RULES.md updated |
| CHG-0289 | Ticket discipline | Ken | `ticket.sh` is the only valid way to close tickets |
| CHG-0290/0291 | Strategy-Gate rule | Ken | No builds on unapproved strategy docs |
| CHG-0297 | Routing discipline | Ken | Yoda orchestrates only. No direct execution of infra/CLI work |
| CHG-0298 | Fabric RAG decision | Ken | D1=DEFER-CLI (P2), D2=CONFIRM-ATLAS-A3 (pattern governance) |
| CHG-0299 | Holocron registry DoD | Ken | All agent docs must be registered — mandatory Definition of Done |
| CHG-0301 | AUTO-HEAL tickets | Ken | Always created as Done — informational records, not actionable backlog |

---

### Training Content Angles (for AInchors courses)

These are the lessons from today that would resonate with business owners and non-technical founders learning AI:

1. **"Why your AI platform needs a decision registry"** — Today we formalised 19 decisions that had been living in our heads and CHANGELOG entries. Creating a searchable, dated decision log is one of the most underrated governance moves for any AI platform. Topic for Aria: how to set this up in Notion without overcomplicating it.

2. **"Don't build before you think"** — The Strategy-Gate rule came from a real mistake: we stood up MinIO before the storage architecture document was properly approved. That's a classic "move fast" trap that creates technical debt and governance gaps. Lesson: approve the design, then build.

3. **"The silent file path trap in AI automation"** — Isolated agent sessions don't expand `~` — so `~/my-file.md` silently writes nowhere. No error. No warning. Just nothing. This was behind two separate issues today alone. Great practical example for a "common AI automation bugs" module.

4. **"Metrics that lie: when 141 looks like violations but only 49 are real"** — Warden was logging 3 entries per check, so dashboards showed inflated numbers. A clean platform looked broken. Teaches the difference between raw counts and meaningful signal — critical for any AI monitoring setup.

5. **"When to stop and check the status page"** — Today we nearly diagnosed a self-inflicted Notion database problem for 10 minutes before realising it was a Notion platform incident. Rule: check the service status page FIRST before assuming your code broke something. Simple lesson, huge time-saver.

6. **"Every agent document needs a registry entry"** — We formalised the rule today that any document an agent produces (proposal, assessment, policy) must be registered centrally with a Drive link. This is the difference between "we made a document" and "we can actually find and trust our documents."

---

### What's Open / What's Next

**Active Sprint (Sprint 3):**
- TKT-0135, TKT-0141, TKT-0142, TKT-0144 — in flight
- TKT-0154 — CI batch fix done ✅
- TKT-0155 — MinIO native macOS install (pending Ken decision: now or Sprint 4?)

**Sprint 4 (planned):**
- TKT-0110 — DR Playbook
- TKT-0150 — (pending)
- TKT-0161 — Drive restructure ✅ done today
- Doc approvals and access violations cleanup

**Upcoming decisions needed from Ken:**
- TKT-0155 timing: native MinIO install now or Sprint 4?
- LinkedIn Part 2 post: APPROVE / EDIT / REJECT (delivered to Telegram)

**Overnight:**
- Warden cron running hourly
- Incremental journal cron running every 30 min
- EOD journal cron at 23:55 AEST
- EOD blog cron at 00:05 AEST
- Drive sync cron at 23:00 AEST

**CHGs today:** CHG-0278 to CHG-0302 (25 changes)
**Tickets raised:** TKT-0154 to TKT-0168 (15 new tickets)
**Decisions closed:** 17 of 19 (DEC-001 to DEC-019)

---

_Next brief: 2026-05-13 ~23:00 AEST_
