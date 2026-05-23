# Post-Incident Analysis: EOD Journal & Blog Failure (11-22 May 2026)

**Date:** 2026-05-23 22:28 AEST
**Trigger:** Ken reviewed EOD outputs — journal incomplete, blog missing for 12 days
**Severity:** HIGH — 12 days of platform output products failed silently
**Status:** DRAFT — immediate fixes applied, root cause analysis complete

---

## 1. What Failed

### Journal
- `journal-2026-05-22.md` is partial — only 3 entries (20:39-21:21), missing entire morning/afternoon Postgres deployment work
- `journal-2026-05-23.md` doesn't exist yet (will be created at 23:55 by EOD cron)
- Journal incremental writer (`1b853131`) has been timing out at 60s — not long enough to process Ken's webchat sessions which can contain 50+ long messages

### Blog
- NO blog exists for 11-22 May (12 days missing)
- Last successful blog: 10 May (ainchors-2026-05-10/index.html, 35KB)
- Blog cron (`a027fd60`) runs at 00:05, reports `ok` with 171s runtime, but produces no files
- No tmp drafts found — model ran unsuccessfully

---

## 2. How This Happened — Root Causes

### Root Cause 1: Silent Failure Detection Gap
**The critical failure:** Neither the journal nor blog crons had any delivery mode that would surface failures. Both were set to `delivery.mode: "none"`. When the blog stopped producing files after May 10, NO ONE KNEW. There was no alert, no notification, no check.

**Why it went unnoticed for 12 days:**
- HEARTBEAT.md had a strict rule: "HEARTBEAT NEVER TOUCHES EOD. FULL STOP." — so no automated check
- No heartbeat task checked "does yesterday's blog file exist?" — it should have
- No cron dead-letter alerting for blog (it reported `ok` so never triggered)
- Ken only discovered it when he reviewed manually

### Root Cause 2: Blog Cron — False Success
The blog cron reported `lastRunStatus: ok` with 171s runtime, but produced zero output files. This means:
- The model "completed" its turn (no timeout, no crash)
- It likely hallucinated success — wrote its response but never actually created the blog file
- Or the triad gate (`content-governance-review.sh`) failed silently
- The model (gemma4:31b-cloud) was in `lightContext: true` mode — possibly couldn't read the BlogFormat.md file

### Root Cause 3: Journal Incremental — Timeout
The journal incremental writer (`1b853131`, every 30 min) has been timing out:
- `lastRunStatus: error`, `lastError: "job execution timed out (last phase: model-call-started)"`
- 60s timeout was too short for sessions_history + formatting + writing
- When it times out, NO journal entries are written for that 30-min window
- Cumulative effect: by EOD, the journal is incomplete and the 23:55 finalizer has nothing to finalize

### Root Cause 4: No Cross-Validation Check
There was no independent check that says "did the blog actually produce a file? did the journal have entries today?" The system trusted the cron's `ok` status without verifying the file existed.

---

## 3. Immediate Fixes Applied

| Fix | What Changed | Status |
|-----|-------------|--------|
| Journal timeout | 60s → 180s (enough for sessions_history + write for heavy days) | ✅ Applied |
| PG sync monitor | Fixed delivery config | ✅ Applied |

---

## 4. Preventative Measures (Required)

### Short-term (tonight/tomorrow):
1. **Add blog existence check to HEARTBEAT.md** — at 06:00 AEST, check if yesterday's blog file exists at `canvas/documents/ainchors-YYYY-MM-DD/index.html`. If missing, alert Ken via Telegram. This overrides the "HEARTBEAT NEVER TOUCHES EOD" rule for this specific safety check.

2. **Add journal completeness check to HEARTBEAT.md** — at 23:00 AEST, check if `memory/journal-TODAY.md` exists and has >500 bytes. Alert if not.

3. **Add blog cron output check** — add delivery announce for blog failures ONLY. If blog produces empty output or fails, surface to Ken.

### Medium-term (Sprint 5):
4. **Replace gemma4:31b-cloud on blog cron** — use deepseek-v4-pro:cloud for reliability. Blog runs once daily at off-peak, cost is negligible.

5. **Add cron output file verification** — after blog cron runs, verify the output file exists at the expected path. If not, re-run with fallback model.

6. **Move blog/journal monitoring into health-check.sh** — make it a platform health indicator, not just a manual check.

### Long-term (P2):
7. **Postgres-based journal** — migrate journal generation to write directly to knowledge_documents with metadata. Separate the human-readable artifact from the structured data.

---

## 5. What We Learn From This

**Lesson 1:** `delivery.mode: "none"` is dangerous for output-producing crons. If a cron produces a user-facing artifact (blog, report, backup), there MUST be a verification check that the artifact exists. Silent success is worse than loud failure.

**Lesson 2:** Cron `ok` status ≠ actual output produced. The cron system reports whether the model turn completed, not whether it did what it was asked. We need file-level verification as a separate check.

**Lesson 3:** Trust but verify. The "HEARTBEAT NEVER TOUCHES EOD" rule was too rigid — it prevented a safety check that would have caught this 12 days ago.

**Lesson 4:** `lightContext: true` mode on gemma4:31b-cloud for complex tasks (like "read BlogFormat.md, read journal, write HTML") may cause silent failures. The model completes but doesn't actually execute the tool calls correctly. For EOD artifacts, use a full-context model session.

---

## 6. Recovery Plan

### Journal for 22 May
Manually reconstruct the complete journal from session transcripts. Yoda to produce a full `journal-2026-05-22.md` covering all work.

### Blog for 11-22 May
12 blog posts need backfill. This is substantial work (~2-3 hours for a quality deepseek-pro run per post). Recommendation: batch backfill over next week, one per day alongside daily blog. Or produce a "12-day roundup" single post covering the highlights.

### Blog for 23 May
Tonight's blog (00:05) will run with the existing cron — we'll see if the timeout increase fixes it. If it fails again, Yoda manually produces tomorrow.

---

*End of Analysis. For Ken Mun review.*
