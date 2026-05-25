# TKT-0296 — Journal Writer Fix: Design Document

**Status:** DRAFT FOR REVIEW | **Date:** 2026-05-25 | **Author:** Yoda 🟢

## Problem Statement

The journal writer has been broken since approximately May 19. Journals dropped from ~40 kB/day (per-entry format, all interactions captured) to ~2-5 kB/day (summary-only, 90% data loss). Blog generation also failed (15 days missing) as a cascade effect.

### Root Cause

The incremental writer cron (`1b853131`, every 30 min) uses `sessions_history(limit=50)` to batch-reconstruct journal entries from session history. When a session exceeds ~50 message exchanges (which happens every active day), earlier messages scroll out of the 50-message window and are permanently invisible to the writer.

This is an architectural flaw: **you cannot reconstruct a journal post-hoc from a fixed-size history window when the source data is larger than the window.**

### Why It Worked Before May 19

The incremental writer was introduced ~May 12. Before that, the EOD finalizer did a full session reconstruction — also limited to 50 messages, but the window was large enough for low-activity days. May 1-18 saw heavy build-phase activity where both mechanisms partially overlapped. After the Claude model change (May 15, CHG-0349), the gemma4-based writer started hitting timeouts and output truncation, making the window limitation fatal.

## Proposed Architecture

### Principle: Main Session Writes the Journal

The session that talks to Ken writes the journal. Not a separate cron. Not a post-hoc reconstruction. The conversation IS the journal — capture it inline.

### Flow

```
Ken sends message
    │
    ▼
Yoda processes (normal agent loop)
    │
    ▼
Yoda writes response to Ken
    │
    ▼
Yoda calls: journal-append.sh <date> <hhmm> <title> <channel> <prompt_file> <summary_file>
    │
    ▼
Entry appended atomically to memory/journal-YYYY-MM-DD.md
```

### Components

#### 1. `scripts/journal-append.sh` (NEW)
- Atomic append to journal file using directory-based locking
- Takes: date, time, title, channel, prompt file, response summary file
- Auto-creates journal file with header if missing
- < 100ms execution — no perceptible delay in conversation
- Lock timeout: 5 seconds (inline in main session, contention is impossible)

#### 2. Yoda's Journal Discipline (NEW PROCEDURE)
After every meaningful exchange with Ken, Yoda appends a journal entry:
- **Trigger:** Every Ken→Yoda→Ken round-trip where a decision/action/deliverable occurred
- **NOT triggered:** Heartbeat replies, status checks, simple acknowledgments
- **Content:** Ken's prompt (verbatim), Yoda's response summary (2-3 sentences), outcome

#### 3. `cron 4d926b2c` — EOD Finalizer (SIMPLIFIED)
The EOD finalizer's role shrinks dramatically:
- **REMOVED:** session_history reconstruction, catch-up entry writing
- **KEPT:** 
  - Replace `[in progress]` header with final Session Overview header
  - Append Business Stream section (from aria-daily-brief.md)
  - Run cost-tracker.sh, append cost summary
  - Git commit the finalized journal

#### 4. `cron 1b853131` — Incremental Writer (DISABLED)
- **REMOVED:** The 30-min incremental writer is no longer needed
- Journal entries are written inline by the main session
- There is nothing to "catch up" on

#### 5. `cron a027fd60` — Blog Generator (UNCHANGED)
- Blog generation reads the journal file — now complete with per-entry detail
- Should start producing output again once journals are fully populated

### What Changes for Yoda

Yoda's response flow gains one additional step:

```
Current:                              New:
├── Process Ken's message             ├── Process Ken's message
├── Write response to Ken             ├── Write response to Ken
└── Done                              ├── Append journal entry
                                      └── Done
```

This is a 2-3 line bash exec call after every meaningful response. The journal-append.sh script handles all formatting and file I/O atomically.

### What Stays the Same

- Journal file format (per-entry verbatim — locked since Day 2)
- Journal file location: `memory/journal-YYYY-MM-DD.md`
- EOD finalizer cron timing: 23:55 AEST
- Blog cron timing: 00:05 AEST
- Business stream capture from aria-daily-brief.md

### Rollout Plan

1. **Atom 1:** Build and test `journal-append.sh`
2. **Atom 2:** Update AGENTS.md / SOUL.md with journal discipline rule
3. **Atom 3:** Update EOD finalizer cron payload (simplified)
4. **Atom 4:** Disable incremental writer cron (`1b853131`)
5. **Atom 5:** Production test — 24-hour observation, verify journal quality
6. **Atom 6:** Verify blog generation recovers (00:05 AEST next day)

### Success Criteria

- [ ] Journal entries written inline during conversation — no cron dependency
- [ ] Journal file shows per-entry format for ALL interactions (not summary)
- [ ] Journal file size returns to ~30-50 kB/day range for active days
- [ ] EOD finalizer adds header only — no entry reconstruction
- [ ] Blog generates successfully from complete journal
- [ ] Zero journal entries lost due to session history window limitations
