# Yoda Daily Brief — 2026-05-13 (Day 20)
_Written by Yoda 🟢 for Aria 🔵 + Angie | ~11:00 PM AEST_

---

## What Happened Today

Today was a Day 20 survival story — a rough morning followed by a productive evening sprint.

### Morning: The Great Blackout

Before anyone was awake, our Anthropic API key quietly expired. No warning email. No heads-up. Just silence.

The gateway restarted at 7:09 AM (because a blog cron had stalled overnight), and that restart exposed the dead key. Six scheduled tasks across the platform went dark — including Aria's relay poller, the journal writer, Warden's compliance checks, and the morning stand-up.

Ken ran a key rotation, then Yoda immediately pushed the new key to all 12 agents using a propagation script we wrote on the spot. All six affected tasks were manually re-triggered by around 1:00 PM and recovered cleanly.

**The bigger fix:** We identified the root cause — our fallback chain was `Sonnet → Haiku`, and *both* are Anthropic. When the key died, both models failed simultaneously with no safety net. We've now made it a platform rule that every single agent must have a third-level fallback using a completely different provider (Kimi from Ollama). No exceptions, no new agents without it. Ken locked this in as a permanent design principle.

### Stand-Up Drama

The stand-up email had a rough day too. A bug caused it to send twice to Ken (both Day 19 and Day 20 reports, back-to-back). Root cause: the cron was using `~` in file paths, which silently fails in isolated sessions. Fixed with a two-step write pattern (write to temp file → shell copy to final path). An idempotency check was also added so it can never double-send again.

### Health Check False Alarm

After the key rotation, our health monitoring script reported the Anthropic API as "degraded" — even though Yoda was clearly working fine. The culprit: health-check scripts were reading from a stale keychain entry, not from the gateway's actual active key file. All four affected scripts were updated to read from the real source of truth first. The propagation script was also updated to sync keychain entries as part of the process.

### Lessons Registry Tightened

Ken explicitly flagged that lessons weren't being logged proactively — Yoda was waiting to be asked. That stops now. The rule is: every fix gets a lesson logged in the same turn, not later. RULES.md was updated, and a pre-work gate was added so Yoda checks the lessons registry before starting any cron, agent, or script work.

### Evening: Governance Audit + Sprint Planning

Four governance documents were reviewed and decisions made:

- **Guardrails Policy** (DOC-AUDIT-007) — Approved as interim. Gap found: the integration steps were never actually executed. TKT-0156 raised to do a proper two-tier restructure.
- **Duplicate guardrails doc** (DOC-AUDIT-008) — Superseded. Archived, no further action.
- **Client Isolation Policy** (DOC-AUDIT-009) — Approved. Clear separation between what's achievable now vs. what needs OC2 hardware. Some stale references to patch before P2. TKT-0157 raised.
- **Governance Gap Analysis** (DOC-AUDIT-006) — Approved. Atlas's audit found 24 governance gaps. Ten of these are hard gates for P2 — we cannot onboard clients until they're resolved. TKT-0158 raised to write the six most critical policies.

Sprint 4 backlog was seeded with these four tickets. Planning ceremony is Sunday 18 May.

All 10 audit documents were uploaded to Google Drive with links captured in the document registry.

---

## Key Decisions Made

| Decision | What Was Decided | Who Approved |
|---|---|---|
| Kimi Safety Net (CHG-0270) | Every agent must have 3-level fallback; kimi = permanent final level | Ken (locked) |
| LinkedIn missed-post rule | Never post late — skip to next scheduled slot | Ken (locked) |
| Propagation script SOP | After any key rotation, run propagation script immediately (now covers keychain too) | Implicit (L-030) |
| auth-profiles.json = source of truth | Scripts must read from gateway config first, keychain is fallback only | Implicit (L-030) |
| Lessons discipline | Log lessons same turn as fix. No deferral. Pre-work gate enforced. | Ken (explicit) |
| DOC-AUDIT-007 Approved interim | Guardrails policy stands, integration gap flagged for TKT-0156 | Ken |
| DOC-AUDIT-009 Approved | Client isolation policy approved, stale refs to patch via TKT-0157 | Ken |
| DOC-AUDIT-006 Approved | 24 governance gaps identified, 10 are P2 hard gates (TKT-0158) | Ken |

---

## Training Content Angles (for AI Courses)

*New ideas from today's work — what lessons are worth teaching?*

**TC-113 — The single vendor trap: when your entire AI platform fails because one key expired**
Your AI platform probably has a favourite AI provider. What happens if that provider's key dies overnight? Today it took 6 automated tasks offline simultaneously. The lesson: never let a single vendor be your only path. Build multi-vendor fallback chains from day one — it's an architectural decision, not an afterthought.
*Source: Anthropic key expiry incident, CHG-0270*

**TC-114 — Reading your own governance docs: a practical audit methodology**
It's one thing to write a governance document. It's another to actually sit down and read it against what exists. Today we audited 4 documents and found: one duplicate, one with unexecuted integration steps, and one identifying 24 policy gaps (10 of which block client onboarding). How to structure a governance audit, what to look for, and how to turn findings into sprint work.
*Source: DOC-AUDIT-006/007/008/009 session*

**TC-115 — Sprint seeding ceremonies: turning document reviews directly into backlog**
A governance review isn't useful unless it creates actionable work. Today's document audit directly seeded four Sprint 4 tickets with clear priority and rationale. The pattern: review → decision → ticket in the same session. No review should end without an action registered somewhere.
*Source: Sprint 4 seeding from DOC-AUDIT session*

**TC-116 — Why scripts lie: the stale keychain problem in AI automation**
After rotating an API key, our health-check scripts still reported the old (dead) key — even though the platform was working fine. The root cause: scripts were reading from a keychain entry, not the gateway's actual config. "The script says it's broken" and "it's actually broken" are two very different things. Always verify your monitoring reads from the true source.
*Source: CHG-0284, L-030*

---

## What's Open / What's Next

### Tomorrow
- LI-C1-W2-P3 fires at 7:30 AM AEST — LinkedIn post scheduled, image attached and ready
- Monitor overnight crons for stability with new key + updated fallback chains

### This Week
- Verify all agents have correct 3-level fallback chains (kimi as final level)
- Patch: Forge to update any remaining agents missing the kimi safety net

### Sprint 4 (Planning: Sunday 18 May)
| Ticket | What It Is | Priority |
|---|---|---|
| TKT-0158 | Write 6 missing P2-gate governance policies (Data Classification, Privacy/APP, Sanctum, Warden Thresholds, Client DPA, Data Residency) | P1 |
| TKT-0156 | Restructure platform guardrails into two tiers (universal + agent-specific) | P1 |
| TKT-0157 | Patch stale references in client isolation policy before P2 | P2 |
| TKT-0155 | Cloudflare Tunnel - CF Access config (parked pending DNS propagation) | P1 |

### Waiting On Ken
- Review of Atlas governance gap analysis (24 gaps, 10 are P2 blockers) — sprint planning is the right time for this conversation

---

*Next brief: tomorrow after close | Questions → ask Yoda in main chat*
