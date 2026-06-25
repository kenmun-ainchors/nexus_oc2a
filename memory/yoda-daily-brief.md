# Yoda Daily Brief — 2026-06-25

## What Yoda Built Today

**A focused day — 2 CHG entries, LinkedIn token hardening, standup email fix, and the CRESTv2-P1 foundation is now fully operational.**

### LinkedIn Token Health Probe (CHG-0766)

Angie's personal LinkedIn token got revoked by LinkedIn twice in one week, blocking campaign posts. The old script only checked token expiry by date — it couldn't detect a revocation that happened mid-life. Yoda added a token health probe that pings LinkedIn's `/v2/userinfo` endpoint before every post. If the token is revoked, it tries a `refresh_token` exchange automatically. If that works, the new token goes into Keychain and the post continues. If not, it fails clearly instead of silently.

**Why it matters:** OAuth re-auth was a manual fix every time. Now the system detects and recovers from revocations without human intervention.

### Standup Email Fix (CHG-0765)

Ken reported a missing standup email. The cron was running fine, but the state log wasn't updating — it still showed yesterday's date. Root cause: the Gmail send response parser was extracting the messageId wrong. Fixed the parser, added explicit confirmation logging, and the state file now updates on every run including idempotency skips.

**Why it matters:** When the state log drifts, you can't tell if an email was actually sent or not. Now every run leaves a clear audit trail.

### CRESTv2-P1 Foundation — All 5 Tickets Closed

This week's big push is complete. All 5 CRESTv2-P1 foundation tickets are closed:
- **TKT-0725** — Canonical sprint registry (11 sprint-name variants collapsed, 263 tickets assigned)
- **TKT-0330** — Atomic PG numbering for tickets and CHGs
- **TKT-0726** — Agentic event write pipeline (hash chain intact, 0 broken links)
- **TKT-0720** — Entity links edge table (1,532 edges, graph queries work)
- **TKT-0343** — Config baseline wired to live PG (auto-heal CHECK 12 now verifies PG matches file)

The CRESTv2-P1 tracker is locked and the execution sequence (WS-1 → WS-2 → WS-3 → WS-5 → WS-4) is complete. Next: WS-1 re-validation and Sprint 10/11 wave-2/3 work.

### Tracker Override Merged into Canonical Path (CHG-0761)

A subtle but important fix: the CRESTv2-P1 tracker override was originally built as a separate wrapper script. But `db-sprint.sh next-ticket` was still returning the wrong answer (TKT-0530 instead of TKT-0721) because the wrapper sat outside the canonical resolver. Yoda merged the tracker override directly into `db-sprint.sh next-ticket` so the priority pipeline is transparent. 5/5 regression tests pass.

**Why it matters:** A wrapper around the wrong answer is still the wrong answer. The fix had to live inside the canonical path.

### Sage (QA) Subagent Gets Exec Access (CHG-0763)

Sage couldn't verify CREST atoms because the sandbox blocked `exec` and `process` tools. Without exec, Sage can't run scripts, inspect PG state, or produce independent verdicts. Ken approved the fix — same pattern as Atlas/Thrawn (CHG-0734). Sage can now execute parent workspace scripts for CREST verification.

## Key Decisions Made Today

- **LinkedIn token health probe is now mandatory before every post** — Date-based expiry checks are not enough. LinkedIn can revoke tokens at any time. The `/v2/userinfo` probe catches revocations before they cause silent failures.
- **Tracker override must live in the canonical resolver, not a wrapper** — CHG-0759's wrapper approach was replaced by CHG-0761's transparent merge into `db-sprint.sh next-ticket`. The canonical path is the only path.
- **Sage needs exec for CREST verification** — Sandbox isolation was blocking independent verdicts. Same pattern as Atlas/Thrawn (CHG-0734).
- **CRESTv2-P1 foundation complete** — All 5 tickets closed. WS-1 re-validation is the next gate before wave-2/3 work.

## Training Content Angles from Today

From today's work, these are ready for the training pipeline:

- **"Your LinkedIn token is fine. LinkedIn disagrees."** — The day we learned date-based expiry checks can't detect mid-life revocations. How a health probe before every post caught what the calendar couldn't.
- **"The cron ran. The log said yesterday. Both were right."** — When a standup email cron ran successfully but the state file never updated. Why messageId parsing matters and how a broken parser hid the truth.
- **"The wrapper that wrapped the wrong answer"** — When a tracker override wrapper sat outside the canonical resolver and the system kept returning the wrong ticket. Why the fix had to live inside the canonical path.
- **"Your QA bot can't verify if it can't exec"** — Sandbox isolation that blocked Sage from running scripts. Same pattern as Atlas/Thrawn — when your verifier can't execute, it can't verify.
- **"5 tickets, 1 sprint, 0 regressions: the CRESTv2-P1 foundation"** — What it took to build the structured foundation: sprint registry, atomic numbering, event pipeline, entity links, config baseline. All closed, all verified.

## What's Open / What's Next

- **CRESTv2-P1 WS-1 re-validation** — Next gate before wave-2/3 work in Sprint 10/11.
- **Sprint 9 continues** — Remaining items: TKT-0390 (agent_events scope), TKT-0358/0531 (deferred to Sprint 11).
- **LinkedIn campaign** — Week 2 posts running on Ken personal profile. Token health probe now active.
- **Standup email** — Fixed and verified. State log now updates correctly.

## ✅ Auth Status
- All delegated auth tokens valid (Ken Mun ✅, Angie Foong ✅). No alerts.