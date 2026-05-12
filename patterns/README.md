# AInchors Pattern Library
_Owner: Atlas 🏛️ (A3 mandate) | Created: 2026-05-12 | Status: Active_

## Purpose
Reusable AI prompt patterns for Agentic RAG ingestion, agent task quality, and content synthesis.
Inspired by Fabric (Daniel Miessler) — pattern-first approach without the CLI dependency at P1.

## Status
- P1 (current): Manual patterns — used directly in agent prompts and RAG pre-processing
- P2: Fabric CLI integration into ingestion pipeline (Ken decision D1 deferred, trigger at P2)

## Pattern format
Each pattern is a markdown file:
- **Purpose:** what this pattern does
- **Input:** what it expects
- **Output:** what it produces  
- **Model:** recommended model tier
- **Used by:** which agents

## Patterns
- `extract-wisdom.md` — Extract key insights, ideas, and recommendations from any content
- `summarize.md` — Concise structured summary with context preservation
- `analyze-claims.md` — Evaluate claims, identify assumptions, rate confidence
- `pre-ingest-structure.md` — Structure raw content for RAG chunking quality

## Governance
- Owner: Atlas (A3 mandate)
- Quarterly review: A4 cadence (Jan/Apr/Jul/Oct)
- P2 trigger: Atlas to assess Fabric CLI adoption and present recommendation to Ken
