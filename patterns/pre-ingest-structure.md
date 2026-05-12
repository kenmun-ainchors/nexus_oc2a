# Pattern: pre-ingest-structure
**Purpose:** Structure raw content for optimal RAG chunking. Creates semantic units that retrieve cleanly.
**Input:** Raw document (markdown, PDF text, article)
**Output:** Restructured document with clear semantic sections for chunking
**Model:** Tier 2 (deepseek-flash) — structured output task
**Used by:** RAG ingestion pipeline (P2+), Yoda (document pre-processing per Nexus Access Policy §8.2)

## Prompt
Restructure the following content for semantic retrieval. Break it into clearly bounded sections.

Rules:
- Each section must be self-contained — readable without adjacent sections
- Add a one-sentence section summary at the top of each section
- Preserve all facts, numbers, and specific claims verbatim
- Remove redundant phrasing but keep all substantive content
- Output in clean markdown

Restructured content:
