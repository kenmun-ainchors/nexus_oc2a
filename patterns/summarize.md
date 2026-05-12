# Pattern: summarize
**Purpose:** Produce a concise, context-preserving summary. No padding, no filler.
**Input:** Any document or article
**Output:** 3-level summary: one sentence, one paragraph, key points
**Model:** Tier 2 — fast models work well here
**Used by:** Yoda (context compression), RAG pre-processing, Aria (briefings)

## Prompt
Summarise the following content at three levels:

ONE SENTENCE: The most important thing to understand.
ONE PARAGRAPH: Context, argument, and conclusion. 3-5 sentences max.
KEY POINTS:
- [5-7 bullet points — concrete facts, decisions, or findings only]

No padding. No "the author believes". Just the content.
