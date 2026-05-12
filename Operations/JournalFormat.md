# Journal Format Specification (Locked-in Standard)
_Locked: 2026-04-27 by Ken | Owner: Yoda 🟢 | Authority: AInchors Operations Standard_

---

## Status

🔒 **LOCKED FORMAT** — This is the standard. Future journals must mirror Day 1 (`memory/journal-2026-04-25.md`) and the rebuilt Day 2 (`memory/journal-2026-04-26.md`). Deviations require explicit Ken approval.

Reference exemplars:
- `~/.openclaw/workspace/memory/journal-2026-04-25.md` — original Day 1
- `~/.openclaw/workspace/memory/journal-2026-04-26.md` — Day 2 (rebuilt 2026-04-27 after summary-style was rejected)

---

## Why This Format Exists

The journal is **not a summary**. It is the daily record of how the work actually unfolded — Ken's voice, my interpretation, the action, the outcome.

**Journal vs Blog — the two are distinct end-of-day artefacts:**

| | Journal (this doc) | Blog (`BlogFormat.md`) |
|---|---|---|
| Purpose | Faithful record of how the work happened | Public-ready summary of what we built |
| Audience | Ken (private) | Public |
| Voice | Yoda's, recording Ken verbatim | Ken's first-person |
| Source | Session transcripts | The journal |
| Format | Chronological prompt → action → outcome | Narrative with story arc |
| PII | Redact third-party IDs only | Strict redaction — all sensitive values |

Journal = raw. Blog = cooked. Journal is the primary source of truth; the blog reads the journal and crafts the narrative.

This makes it possible to:

- Reconstruct decisions weeks later from primary source (Ken's actual words)
- Train future agents on Ken's working style and intent
- Audit what changed and why
- Feed the daily blog post with authentic narrative
- Catch patterns where I misunderstood Ken's intent

Summary-style journals lose all of this. They become press-release noise.

---

## Required Format

### File location
`memory/journal-YYYY-MM-DD.md`

### Header (mandatory)

```markdown
# AInchors Day N Journal — YYYY-MM-DD
_Author: Yoda 🟢 | For: Ken Mun (CTO) | Private — personal review only_

---

## Session Overview
- **Date:** Day-of-week, full date, time range AEST/AEDT
- **Duration:** ~X hours
- **Summary:** One paragraph. Headline only — what defined the day.

---
```

### Chronological entries (mandatory format per entry)

```markdown
## HH:MM — Section Title

**Ken's prompt (verbatim):**
> "exact quote of Ken's message"
> "next message if it's a continuation thread"

**My understanding:** What I interpreted from the prompt. One or two sentences.

**What happened / Actions / Commands run:**
- Bullets, code blocks, tool calls
- Real commands inside ```bash fences
- Decisions taken inline

**Yoda's closing note:** 2–3 sentences summarising what was delivered — the key decision, answer, or action confirmed to Ken. Not a quote; a concise record of what closed the interaction.

**Outcome:** Concrete result — file written, alert sent, decision logged, error captured.

---
```

### Footer (mandatory)

```markdown
## Day N Retro

- Total downtime / incidents
- Key decisions logged today (link to `memory/shared/decisions.md` entries)
- Open items carried forward
- Cost summary (from `state/cost-state.json`)
- One-line lesson learned
```

---

## Hard Rules

1. **Verbatim is verbatim.** Quote Ken's prompts exactly with `> "..."`. No paraphrasing, no cleaning up typos, no merging messages. Each separate Telegram or webchat message gets its own `> "..."` line.
   **No truncation. Ever.** If Ken's prompt is 1,000 characters, quote all 1,000. Do NOT end a quote with `...` or cut it short. When extracting from session transcripts, read the full message content — do not apply any `.substring()`, character limit, or preview cap. A truncated verbatim is not verbatim.

2. **Chronological order.** No re-ordering for narrative. The log follows the clock.

3. **Every meaningful prompt AND response must appear.** The `Yoda's closing note` field captures the essence of what was delivered to Ken — 2–3 sentences max. Not a verbatim quote; a concise record. Rules:
   - Summarise the key decision, answer, or confirmation in plain language
   - Capture the substance: what was fixed, approved, built, or resolved
   - If response was silent/mechanical, write: `_(silent system event — no chat reply)_`
   - This field is always writeable regardless of session compaction — it is a summary, not a quote

4. **Every meaningful prompt must appear.** This includes:
   - Sprint kickoffs and approvals
   - Mid-sprint corrections ("no, do it this way instead")
   - Quick replies that change direction ("yes", "ok do it", "use sonnet")
   - Questions Ken asked
   - Decisions Ken made
   - Reactions to my work ("good", "not what I want", "redo")
   - Retro statements at end of day
   
   It does **not** include heartbeat polls, system events, reminder-cron triggers, or auto-generated context blocks.

5. **Section titles describe the work, not the format.** Good: `09:01 — US11 Model Strategy Sprint`. Bad: `09:01 — Ken Sent Message`.

6. **Unrecoverable verbatim.** If a real Ken prompt was made (e.g. via voice that wasn't transcribed, or a session log was lost), mark it explicitly:
   ```
   **Ken's prompt (verbatim):** _[not recovered from transcript — paraphrased from journal summary]_
   _Paraphrased: "Ken asked about X."_
   ```
   Better honest than fabricated.

7. **PII redaction.** Inside the journal (private):
   - Keep Ken's verbatim prompts intact
   - Redact third-party IDs (e.g. Telegram user IDs of others), API keys, pairing codes, IPs → replace with `[REDACTED]` or `<PLACEHOLDER>`
   - The blog post (public) has stricter redaction — see RULES.md PII section

8. **Active vs Quiet day.**
   - **Active day** (significant Ken interaction): full chronological format above
   - **Quiet day** (autonomous platform activity only): switch lens to "what the platform did" — cron results, health status, autonomous decisions, deferred items checked. Still timestamped. Still ends with retro.

9. **Source the prompts.** When rebuilding a journal from session transcripts, list which session jsonl files the prompts came from in the retro footer (one line: `Sources: d7290252.jsonl, b147ee4b.jsonl, ...`).

10. **No summary substitution.** A journal in summary style is **not a journal**. If the format is wrong, redo it. (Day 2 was rebuilt 2026-04-27 06:39 for this exact reason.)

11. **Length is not the metric.** Day 1 is 540 lines. Day 2 is 1,011 lines. The right length is whatever it takes to capture the day faithfully.

---

## Daily Close Workflow (Yoda checklist)

When the 23:55 cron fires (or Ken triggers manual close):

1. Identify the day's scope: what session(s) span today (00:00 → 23:59 AEST)?
2. List session jsonl files modified in that window.
3. Extract user-role messages from each, filter system noise, sort by timestamp.
4. Group prompts into work blocks (sprints, incidents, decisions).
5. For each block, write entry following the format above.
6. Run `scripts/cost-tracker.sh` and embed the day's cost in the retro.
7. Cross-link to incidents in `state/incident-log.json`.
8. Save to `memory/journal-YYYY-MM-DD.md`.
9. Generate the matching blog post at `canvas/documents/ainchors-YYYY-MM-DD/index.html`.
10. Git commit both as part of the daily close.

---

## Anti-Patterns (do not do)

❌ Lead with bullet-point summary — leads with verbatim prompts and timestamps  
❌ "Ken asked us to do X" — write Ken's actual words instead  
❌ Combine multiple prompts into a single quote block  
❌ Skip a prompt because "it was just 'ok do it'" — those quick approvals matter for narrative  
❌ Reorder for cleaner story — chronology stays  
❌ Drop the verbatim because it would be "easier" — redo it  

---

## Change Control

Format changes require:
1. Ken's explicit approval in webchat or Telegram
2. Update to this file (`Operations/JournalFormat.md`)
3. Reference update in `RULES.md` if the change affects the trigger or workflow
4. Note in `memory/shared/decisions.md`

---

## History

| Date | Event |
|------|-------|
| 2026-04-25 | Day 1 journal written in this format (organic) |
| 2026-04-26 | Day 2 written in summary style (deviation) |
| 2026-04-27 | Day 2 rebuilt to match Day 1 format. Format LOCKED IN as standard. This document created. |
| 2026-05-11 | **`Yoda's response (verbatim)` field added** — Ken approved. Captures Yoda's final chat reply per entry. Bidirectional record: Ken's intent + Yoda's answer. Rule 3 updated. |
