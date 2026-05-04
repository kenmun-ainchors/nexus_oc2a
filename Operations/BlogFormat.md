# Blog Format Specification (Locked-in Standard)
_Locked: 2026-04-27 by Ken | Owner: Yoda 🟢 | Authority: AInchors Operations Standard_

---

## Style Reference — Locked 2026-05-02 (Ken approved)

_Ken reviewed both blog versions for Day 7 (2026-05-01) and approved the sub-agent narrative style. This section locks that style as the definitive standard, superseding any conflicting guidance below._

### Act Title Format
`"[Short Label]: [What Happened or What It Means]"` — energetic and specific.
- ✅ **Good:** "Morning Sprint: Two RTBs, Done Fast" / "The $85 Accounting Ghost" / "The PoC That Revealed Its Own Limits"
- ❌ **Bad:** "Act 3: Security Audit" — too dry, no story signal

### Opening Hook
First 1–2 paragraphs must be a **meta-observation about the day's shape**, not a summary. What kind of day was it? What pattern emerged? The reader should understand the arc before you list a single event.
- Voice markers: "I came in expecting...", "None of those were on the plan", "That's not nothing"

### Callout Boxes
Use `📊 [Label]` / `⚠️ [Label]` / `🚨 [Label]` callouts sparingly — **2–3 per post maximum**. Each must punctuate a genuinely significant moment, not just decorate prose. Callout = signal that this line changes something.

### Voice Markers (Ken's first-person)
- Confident, self-aware, slightly wry
- "I came in expecting...", "That's not nothing", "None of those were on the plan", "The lesson here is one I keep relearning"
- Short punchy sentences to land decisions. Longer sentences for context.
- Never hedge: "perhaps" → just say what happened.

### Technical Depth Without Jargon
Every technical decision gets one plain-language sentence explaining **why it matters**, not just what it does.
- ✅ "The fix was a cross-run state dictionary — once a session is flagged, it's suppressed for ten minutes. Result: 183 false-positive events per day dropped to zero."
- ❌ "We implemented deduplication logic in the obs-collector."

### Honest Framing
Partial results, deferred decisions, and open questions go **in the body of the relevant act** — not buried in footnotes or softened in summary. If the PoC partially failed, say "PARTIAL PASS" in the act title region.

### Length Target
2,500–3,000 words. **Five to seven acts.** Cut filler before cutting substance.

### Reference File
`/tmp/blog-subagent-version.html` — Day 7 example, Ken-approved 2026-05-02. When in doubt, match that post's voice, structure, and density.

---

## Status

🔒 **LOCKED FORMAT** — Companion to `JournalFormat.md`. Together they define the two distinct end-of-day artefacts.

Reference exemplars:
- `~/.openclaw/canvas/documents/ainchors-day1/index.html` — Day 1
- `~/.openclaw/canvas/documents/ainchors-2026-04-26/index.html` — Day 2
- `~/.openclaw/canvas/documents/ainchors-2026-04-27/index.html` — Day 3
- `~/.openclaw/canvas/documents/model-strategy-blog/index.html` — **GOLD STANDARD** (Ken approved 2026-04-28 — use this as the primary style reference for all future blogs)

---

## Blog Types

| | **EOD Blog** (`/eod`) | **Standalone Blog** (`/blog <topic>`) |
|---|---|---|
| **Trigger** | `/eod` or 23:55 cron | `/blog <topic>` (any time) |
| **Scope** | Today's full day narrative | One focused topic, timeless |
| **Source** | Today's journal | PoC reports, state files, decisions |
| **Frequency** | One per day | Many per day if needed |
| **Path** | `canvas/documents/ainchors-YYYY-MM-DD/index.html` | `canvas/documents/ainchors-blog-<slug>/index.html` |
| **Sections** | All mandatory sections (hero → footer) | Problem → Research → Decision → Outcome → Lessons (no cost/WYWA unless relevant) |
| **Tone** | Day narrative, raw and honest | Deep-dive, shareable, evergreen |

---

## The Distinction (Journal vs Blog)

| | **Journal** | **Blog** |
|---|---|---|
| **Purpose** | Faithful record of how the work happened | Public-ready summary of what we built and why it matters |
| **Audience** | Ken (private, internal) | Public — prospects, peers, future team |
| **Voice** | Yoda's, recording Ken's words verbatim | Ken's first-person voice |
| **Source of truth** | Session transcripts (Ken's actual prompts) | Journal + decisions + outcomes |
| **Format** | Chronological, prompt → understanding → action → outcome | Narrative — story arc, lessons, takeaways |
| **PII** | Redact third-party IDs only; keep Ken's words | Strict — replace all sensitive values with `<PLACEHOLDER>` |
| **Length** | Whatever it takes (Day 1: 540 / Day 2: 1011 lines) | ~1500–3000 words typical |
| **Location** | `memory/journal-YYYY-MM-DD.md` | `canvas/documents/ainchors-YYYY-MM-DD/index.html` |
| **File type** | Markdown (private) | Self-contained HTML (publishable) |
| **When written** | Daily close, from transcripts | Daily close, after journal exists |

**Rule of thumb:** the journal is *raw*, the blog is *cooked*. Journal is the primary source. Blog is the curated narrative built from it.

The journal can be terse, technical, full of timestamps and command outputs. The blog must be readable by someone who wasn't in the room.

---

## Required Format

### File location
`~/.openclaw/canvas/documents/ainchors-YYYY-MM-DD/index.html`
(One folder per day. The folder may also hold images, diagrams, or assets referenced inline.)

### Mandatory sections (in order)

1. **Hero / Title block**
   - Day N — Date — One-line subtitle that captures the headline of the day
   - Author byline: Ken Mun (CTO) — first-person throughout

2. **Opening (1–2 paragraphs)**
   - The day's headline and why it matters
   - Set the stakes — what was at risk, what we set out to do

3. **The Story (chronological narrative)**
   - Walk through the day in 3–6 named acts (sprints, incidents, decisions)
   - Each act has a heading and a few paragraphs
   - Code blocks, command snippets, decision tables welcome
   - Architecture diagrams (inline SVG or pre-rendered) when they aid understanding
   - Pull quotes / callout boxes for the moments that mattered

4. **What Broke (only if applicable)**
   - Incidents with RCA-lite — what failed, why, fix, prevention rule added
   - Honest. No sugar-coating.

5. **What I Learned**
   - 2–4 lessons distilled from the day
   - Concrete and quotable, not generic

6. **The Cost of Day N**
   - Total USD spend (from `state/cost-state.json`)
   - Per-model breakdown
   - Cost vs value framing — what we spent vs what we got
   - Day-on-day trend if available

7. **What's Next**
   - 3–5 items planned for tomorrow / next sprint
   - Backlog highlights

8. **While You Were Away** (only on quiet/autonomous days)
   - What the platform did without me
   - Cron results, autonomous decisions, deferred items checked

9. **Footer**
   - Series link (← Previous day · Next day → when published)
   - Tagline / sign-off

### Styling

- **Self-contained HTML.** All CSS inline or in a single `<style>` block. No external CDN dependencies (resilient to network failures).
- **Medium-style readable typography** — serif body font (Charter, Georgia, or similar), generous line-height, ~720px content width.
- **Dark or light theme — pick one and be consistent across the series.**
- **Callout boxes** for warnings, decisions, key insights — distinguished by colour and icon.
- **Code blocks** monospace with syntax highlighting via inline classes (no external highlighter library).
- **Mobile-responsive** — viewport meta tag, max-width on content, no horizontal scroll.

---

## Hard Rules

1. **Built from the journal, not the transcript.** The journal is the source of truth. Don't re-extract from session jsonl — that's the journal's job. The blog reads the journal and crafts the narrative.

2. **First-person Ken voice.** "I built…" not "Yoda built…" or "We built…". (Exception: when explicitly co-authored.) Use natural, direct prose — short sentences, real numbers, no corporate filler. Match `SOUL.md` communication style.

3. **PII redaction is strict.** Every blog post is treated as if it will be published.
   - Tokens, keys, pairing codes, user IDs, IP addresses, internal session IDs → `<PLACEHOLDER>` or `[REDACTED]`
   - Run a redaction sweep before saving. The Day 1 pairing code leak (B8QTVBBU) is the cautionary tale.

4. **No fabrication.** If a number, decision, or quote isn't backed by the journal or a state file, don't invent it. If we don't know the cost, omit the cost section that day.

5. **Decisions reflect reality.** If a decision was reversed later in the day, show both — don't pretend the final answer was always the plan.

6. **Code blocks must be runnable / accurate.** No invented commands. If you reference a script, it must exist at the path stated.

7. **Length is not the metric.** A clean 1200-word post beats a padded 4000-word one. Cut filler.

8. **Self-contained.** No external JS, no remote fonts (system stack is fine), no remote images unless explicitly approved. Resilience principle: the blog should render correctly five years from now with no network.

9. **Consistent with the journal.** Timestamps, quotes, and outcomes in the blog must match the journal. If they conflict, fix the blog (journal wins).

10. **Day numbering.** Day N = N-th day of the AInchors technical department, starting Day 1 = 2026-04-25. Don't reset.

---

## Daily Close Workflow (Yoda checklist for the blog)

After the journal is written:

1. Read today's `memory/journal-YYYY-MM-DD.md` — the full text.
2. Read `state/cost-state.json` for today's spend numbers.
3. Read `state/incident-log.json` for any incidents to surface.
4. Identify the day's narrative arc — what's the headline?
5. Draft the post in the section order above.
6. Run PII sweep:
   - Search for: `B8QTVBBU`-style pairing codes, `sk-ant-`/`sk-`/API key patterns, IPs, Telegram user IDs, internal session UUIDs
   - Replace with `<PLACEHOLDER>` or `[REDACTED]`
7. Validate self-containment: no `<script src="http`, no `<link href="http` (except to other AInchors blog days, which are local).
8. Save to `canvas/documents/ainchors-YYYY-MM-DD/index.html`.
9. Git commit alongside the journal as part of the daily close.

---

## Anti-Patterns (do not do)

❌ Re-extract verbatim quotes from session transcripts — that's the journal's job  
❌ Use Yoda's voice in the blog (use Ken's first-person)  
❌ Skip the cost section because it's "not interesting" — it always belongs  
❌ Generate from a template without reading the journal first  
❌ Pad with corporate language ("synergies", "leveraging", "going forward")  
❌ Leak PII — every post is treated as public  
❌ Embed external CDN assets — must be self-contained  
❌ Mix journal and blog — they have different purposes and audiences  

---

## Change Control

Same as JournalFormat.md:
1. Ken's explicit approval in webchat or Telegram
2. Update to this file (`Operations/BlogFormat.md`)
3. Reference update in `RULES.md` if the change affects the trigger or workflow
4. Note in `memory/shared/decisions.md`

---

## History

| Date | Event |
|------|-------|
| 2026-04-25 | Day 1 blog written (organic). Pairing code leaked, redacted retroactively. |
| 2026-04-26 | Day 2 blog written. "While You Were Away" section pattern established. |
| 2026-04-27 | Journal vs Blog distinction formalised. Both formats LOCKED. This document created alongside JournalFormat.md. |

---

## Writing Style — Ken Approved Standard
_Locked: 2026-04-28. Ken: "Love the blog. The way it's written is exactly how I like it. Use this level of detail, language and narrative for all future blogs."_

### Voice & Tone
- **First-person, direct.** "I built..." "I decided..." "The data showed..."
- **No hedging.** Don't say "perhaps" or "it might be worth considering". Say what happened and why.
- **Short punchy sentences for emphasis.** Long sentences for context, short sentences to land decisions.
- **Real numbers always.** "$90.07", "893ms", "8/8 PASS" — never round or approximate without noting it.
- **Technical but readable.** Don't hide the tech. Explain it once, clearly, then move on.
- **Honest about failures.** Drift incidents, bugs, wrong assumptions — write them straight. The fix matters more than the image.

### Structure & Narrative
- Every post has a **clear problem → research → decision → outcome arc**. Don't skip the problem.
- **Name your acts.** "The Problem", "The Research", "The Decision" — clear section headings that tell the story.
- **Open with stakes.** First paragraph tells the reader why this matters before explaining what it is.
- **End with lessons.** Not summaries — actual sharp insights that someone else could apply.
- **Pull quotes / callout boxes** for the moments that mattered. Used sparingly, not decoratively.

### What to Include
- Real benchmark data with exact numbers
- Decision reasoning — not just what was decided but why that option over the alternatives
- What failed or was ruled out, and why
- Cost/time/performance numbers wherever available
- What's next — always close with where this leads

### What to Avoid
- Corporate language ("leverage", "synergies", "going forward")
- Vague claims without data ("significantly faster", "much cheaper")
- Padding — if a section has nothing to say, cut it
- Apologetic tone — don't soften decisions or failures

### Reference
Primary style exemplar: `~/.openclaw/canvas/documents/model-strategy-blog/index.html`
Ken-approved 2026-04-28. When in doubt, read that post and match the voice.

