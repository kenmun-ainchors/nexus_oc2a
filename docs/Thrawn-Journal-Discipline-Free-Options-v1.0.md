# Option Paper: Discipline-Free Journal Solution for AInchors Nexus
**Version:** 1.0
**Author:** Thrawn, Platform Architect
**Date:** 2026-05-30
**Status:** Approved — Ken Mun 2026-05-30

## 1. Executive Summary
The current journal system relies on agent discipline (manual calls to `journal-append.sh`), which has proven unreliable, particularly in high-context webchat sessions. This has resulted in significant data loss (e.g., the May 29 evening gap). This paper proposes four architectural shifts to move from a "Push" (Agent-driven) to a "Pull" (System-driven) or "Event-driven" journaling model, ensuring 100% coverage of interactive sessions without increasing token burn or agent cognitive load.

---

## 2. Proposed Options

### Option A: The "Transcript-to-Journal" Post-Processor (Pull Model)
Instead of agents writing entries during the session, a system process parses the `.jsonl` transcript files at the end of the day or at specific checkpoints.

- **Architecture:** A new script `journal-generate.sh` is added to the EOD cron (23:55 AEST). It scans all active session transcripts (`agent:main:dashboard:*` and `agent:main:telegram:*`) for the current date. It uses a lightweight LLM call or regex-based heuristic to summarize "meaningful exchanges" into journal entries.
- **Implementation Effort:** Low/Medium.
- **Token Overhead:** Zero during interaction; minimal at EOD.
- **Coverage Guarantee:** High (covers all recorded transcripts).
- **Integration:** Replaces or supplements `journal-append.sh` within the 23:55 cron.
- **Risk:** Summarization quality may vary if the LLM isn't given a strong prompt to identify "substantive work" vs. banter.

### Option B: Middleware Event Hook (Interceptor Model)
Implement a hook at the OpenClaw gateway/runtime level that triggers a background "Journaling Agent" whenever a response is sent to the user.

- **Architecture:** Every time a `message` is dispatched to the user in a `main` session, a background event is emitted. A lightweight "Shadow Agent" consumes this event, evaluates if the exchange was "meaningful" (using a small model or keyword triggers), and calls `journal-append.sh` asynchronously.
- **Implementation Effort:** High (requires gateway/runtime modification).
- **Token Overhead:** Low (runs in background, not in the main prompt chain).
- **Coverage Guarantee:** Absolute (every interaction is seen).
- **Integration:** Seamlessly feeds into existing `journal-append.sh` and EOD pipeline.
- **Risk:** Potential for "noise" if the filter for "meaningful" work is too broad.

### Option C: The "Session-End" Finalizer (Checkpoint Model)
Shift the responsibility from "per-exchange" to "per-session closure."

- **Architecture:** Modify the session lifecycle. When a session is terminated or reaches a specific inactivity timeout, a `session-summarize` trigger is fired. This trigger reads the session's `.jsonl` transcript and appends a comprehensive summary to the daily journal.
- **Implementation Effort:** Medium.
- **Token Overhead:** Zero during interaction; one-time cost at session end.
- **Coverage Guarantee:** Very High (provided sessions are closed/timed out).
- **Integration:** Fits perfectly before the 23:55 EOD finalizer.
- **Risk:** If a session stays open for days, the "end" trigger is delayed.

### Option D: Database-Driven Journaling (SSOT Model)
Leverage the existing PG (Postgres) state tables to track "milestones" rather than text entries.

- **Architecture:** Agents don't write to a file; they update a `session_milestones` table in PG when a task is completed. The EOD cron then queries this table to generate the `.md` journal file.
- **Implementation Effort:** Medium.
- **Token Overhead:** Negligible (SQL update vs. script call).
- **Coverage Guarantee:** Medium (still relies on some agent action, but SQL updates are faster/easier to automate via tool-hooks).
- **Integration:** Uses PG as the bridge to the existing EOD file generator.
- **Risk:** Still fundamentally "discipline-based" unless the DB updates are triggered by the platform.

---

## 3. Comparison Matrix

| Feature | Option A (Post-Proc) | Option B (Middleware) | Option C (Session-End) | Option D (DB-Driven) |
| :--- | :--- | :--- | :--- | :--- |
| **Effort** | L/M | H | M | M |
| **Token Burn** | EOD only | Background | Session-End | Negligible |
| **Coverage** | High | Absolute | Very High | Medium |
| **Discipline** | None (System) | None (System) | None (System) | Low (Agent) |
| **Complexity** | Low | High | Medium | Medium |

---

## 4. Recommendation

**Recommended: Option A (The "Transcript-to-Journal" Post-Processor)**

### Rationale:
Option A provides the best balance of **reliability, low risk, and implementation speed**. 

1. **Zero Friction:** It requires no changes to agent behavior and no modifications to the core OpenClaw gateway (unlike Option B).
2. **Full Coverage:** Since `.jsonl` transcripts are the ground truth of all interactions (Webchat and Telegram), nothing is missed.
3. **Token Efficiency:** By moving the "thinking" about what belongs in the journal to the EOD window, we eliminate token burn during the critical active-work phase.
4. **Safe Integration:** It leverages the existing 23:55 AEST cron, turning the journal from a "diary written in real-time" into a "curated record generated from evidence."

### Implementation Path:
1. Create `journal-generate.sh` to iterate over `.jsonl` files for the current date.
2. Feed transcripts to a lightweight model to extract key technical decisions (e.g., "TRIGGER restructure v2.0", "CHG-0446").
3. Append results to `memory/journal-YYYY-MM-DD.md` before the EOD finalizer runs the commit.
