# Pattern: extract-wisdom
**Purpose:** Extract key insights, ideas, quotes, and actionable recommendations from any content.
**Input:** Any document, article, transcript, or conversation
**Output:** Structured markdown with: KEY INSIGHTS | IDEAS | QUOTES | RECOMMENDATIONS | HABITS
**Model:** Tier 2 (kimi or deepseek) — no Claude needed
**Used by:** Yoda (pre-ingestion), Ahsoka (consulting doc analysis), Atlas (EA research)

## Prompt
You are an expert content analyst. Extract the most valuable knowledge from the content below.

Produce exactly these sections:
## KEY INSIGHTS
- [5-10 profound, non-obvious insights]

## IDEAS
- [3-5 actionable ideas this content suggests]

## QUOTES
- "[verbatim memorable quote]" — [context]

## RECOMMENDATIONS
- [Specific actions the reader should take]

## CONTENT SUMMARY
One paragraph. What this is, who wrote it, core argument.
