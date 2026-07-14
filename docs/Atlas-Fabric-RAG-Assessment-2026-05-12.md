# Fabric (Daniel Miessler) — EA Assessment for AInchors RAG Architecture
**Status:** LIVE — Approved by Ken Mun 2026-05-12
**Decisions:** D1=DEFER-CLI (defer Fabric CLI to P2, start /patterns/ directory now) | D2=CONFIRM-ATLAS-A3 (Atlas owns pattern governance under A3 mandate, quarterly review at P2) — Pending Ken Mun approval
**Author:** Atlas 🏛️ | Requested by: Ken Mun (CTO) | Date: 2026-05-12
**TKT:** Assessment | Ref: TKT-0104, Nexus_Enterprise_Landscape_P2P4.md

---

## Recommendation: CONCEPT-ONLY at P1 → ADOPT at P2

**Lead:** Adopt the pattern library concept now. Defer the Fabric CLI toolchain to P2.

AInchors should build an internal **AInchors Pattern Store** — a governed library of reusable prompt templates inspired by Fabric's architecture — starting in P1. The Fabric CLI itself should be installed and integrated into the RAG ingestion pipeline at P2, when client content flows in at scale and the investment is justified.

This is not a TOM gap that requires a new agent. Pattern library governance is an Atlas A3 responsibility within the existing architecture function.

---

## 1. Architecture Fit

### What Fabric Is (and Isn't)

Fabric is a **prompt execution framework**, not a RAG pipeline. It does not:
- Store or retrieve embeddings
- Perform vector search
- Manage tenants or data residency

It does:
- Execute reusable markdown prompt templates ("patterns") against any LLM
- Pipe arbitrary text through a named pattern via CLI: `fabric --pattern extract_wisdom < document.txt`
- Run against Ollama (local), Claude, GPT — model-agnostic

**Verdict:** Fabric does NOT duplicate our RAG pipeline (pgvector + nomic-embed-text + PII scanner). It operates at the prompting/synthesis layer, upstream and downstream of retrieval. These are complementary.

---

### Where Fabric Patterns Add Value in the RAG Flow

#### a) Content Pre-Processing (Before Chunking → pgvector)

**High value. Recommended for P1/P2.**

Raw documents (PDFs, email threads, client submissions, regulatory guidance) are poor RAG inputs — verbose, unstructured, redundant. Fabric patterns can pre-process them into clean, dense, structured Markdown **before** the RecursiveCharacterTextSplitter runs.

Relevant patterns:
- `extract_wisdom` — distils key ideas, insights, facts from long content
- `summarize` — condenses verbose documents
- `create_markdown` — converts unstructured text to structured Markdown
- `label_and_rate` — scores and labels content quality (maps to our `quality_score` threshold ≥0.7 in TKT-0104)

**Impact:** Better-structured input → cleaner chunks → better retrieval precision. Directly improves the RAG retrieval quality without changing any downstream infrastructure.

**P1 action (minimal):** Build AInchors equivalents of `extract_wisdom` and `create_markdown` as governed pattern templates. Apply them manually during knowledge base seeding (Month 2, TKT-0104 Action 4).

---

#### b) Query Augmentation (Before Retrieval)

**Moderate value. Defer to P2.**

Fabric has patterns for prompt refinement and expansion. Applied to user queries before vector search, they could improve recall (especially for SME clients with imprecise queries).

At P1, query volume is minimal (Ken only). The benefit is real but the ROI does not justify implementation complexity now. Design a query augmentation hook in the retrieval API at P2 build time.

---

#### c) Post-Retrieval Synthesis (After Context Pulled)

**High value. Partially in place today.**

This is where our agents already operate — they receive retrieved context chunks and synthesise a response. The problem is that these synthesis prompts live as ad-hoc text in SOUL.md files (hard-limited to 5,000 chars) and RULES.md files (ungoverned).

Fabric's pattern model provides a better architecture: synthesis instructions as standalone, versioned, reusable Markdown templates — callable by any agent, not embedded in identity files.

**Examples of AInchors-specific synthesis patterns:**
- `analyse_client_request` — structured analysis of SME client intake
- `generate_proposal_section` — Ahsoka pattern for consulting proposal sections
- `extract_risk_finding` — for Shield/Lex regulatory document analysis
- `summarise_agent_decision` — for T3 episodic log entry synthesis

**P1 action:** Begin building the AInchors Pattern Store as a `/patterns/` directory in workspace. Each pattern is a SOUL.md-equivalent for a specific task, not an agent identity.

---

#### d) Agent Prompt Quality (Replacing Ad-Hoc RULES.md Text)

**Highest strategic value. Start in P1.**

The most impactful application of the Fabric pattern concept is **replacing ad-hoc RULES.md prompt fragments** with governed, versioned pattern templates that agents call by name.

Current state: Agent-specific reasoning instructions are scattered across RULES.md files with no lifecycle management, version control, or quality gate.

Pattern store model:
```
/patterns/
  ainchors-extract-wisdom.md        ← Pre-ingestion synthesis
  ainchors-analyse-client-request.md ← Ahsoka intake
  ainchors-compliance-check.md      ← Shield/Lex review
  ainchors-quality-gate.md          ← Sage DoD enforcement
  ainchors-decision-summary.md      ← Episodic log synthesis
```

Each pattern: single-purpose, versioned, Atlas-governed, callable by any agent. This architecture:
- Offloads complex reasoning templates from SOUL.md (respecting the 5,000-char hard limit)
- Provides a single place to update a reasoning pattern across all agents that use it
- Creates a P2-ready asset: per-client pattern customisation becomes possible
- Feeds directly into P4 APRA compliance: every agent synthesis step traceable to a versioned, auditable pattern

---

#### e) Inbound Client Content (Nexus Access Policy Section 8)

**High value. P2 priority.**

At P2, clients will submit content for ingestion into their knowledge bases. This content is unvalidated — quality and classification unknown.

Fabric's `label_and_rate` and `analyze_claims` patterns are exactly the right tool for:
1. Scoring content quality (feeds our `quality_score ≥ 0.7` threshold gate)
2. Flagging potentially problematic content before PII scan
3. Structuring raw client content into embedding-ready Markdown

At P2, Fabric CLI integrated into the ingestion pipeline means every client document submission is automatically pre-processed, quality-gated, and structured before it reaches the chunker and PII scanner. This is a compliance and quality win.

---

## 2. P1–P4 Relevance Map

| Phase | Fabric Value | Specific Application | Data Sovereignty Risk |
|-------|-------------|---------------------|----------------------|
| **P1** | Medium | AInchors Pattern Store: pre-process governance docs before embedding. Improve SOUL.md/RULES.md prompt quality. | Zero — run patterns through Ollama (local) only. |
| **P2** | High | Integrate Fabric CLI into ingestion pipeline. Client content → pattern pre-processing → PII scan → chunk → embed. Per-tenant pattern customisation. | None if run on OC2 local inference (Gemma4). Never pipe client content through cloud models. |
| **P4** | High (governance asset) | Pattern library becomes a governed, APRA-auditable asset. Every synthesis step traceable to a versioned pattern. FSI clients may customise patterns within their deployment. | Zero — P4 physical deployment runs Fabric + Ollama locally. |

---

## 3. TOM Gap Assessment

**Gap identified:** No current owner for prompt quality governance — curation, versioning, lifecycle management, and routing of agent prompt templates.

**Assessment:** This does **not** require a new Tier 3 specialist agent at P1.

**Recommended ownership model:**

| Role | Responsibility |
|------|----------------|
| **Atlas A3** | Pattern library custodian. Reviews new patterns. Approves merges. Maintains `/patterns/` directory in workspace. Quarterly pattern audit. |
| **Agent owners** (Yoda, Ahsoka, Shield, etc.) | Propose patterns for their domain. Flag patterns that are stale or underperforming. |
| **Ken (approval)** | Approves significant pattern changes that affect client-facing outputs or compliance behaviour. |

This is an extension of Atlas's existing architecture governance function, not a new TOM role. Reassess at P2 if pattern volume exceeds 50 templates or if client customisation requests require a dedicated pattern engineer.

**Minimum viable ownership (P1):** Atlas maintains a `/patterns/README.md` index and `CHANGELOG.md` for the pattern store. All patterns reviewed before being referenced in agent RULES.md or ingestion pipelines.

---

## 4. Adoption Recommendation

### CONCEPT-ONLY (P1) → ADOPT (P2)

**P1: CONCEPT-ONLY**

Do not install the Fabric CLI toolchain on OC1 now. P1's critical path is TKT-0104 Actions 1–5 (Postgres + audit log + pgvector + PII scanner). Adding a new CLI dependency during this build phase is unnecessary risk and distraction.

Instead:
1. Create `/Users/ainchorsoc2a/.openclaw/workspace/patterns/` directory
2. Build 3–5 seed patterns (extract_wisdom equivalent, create_markdown, quality_gate, decision_summary) as governed AInchors templates
3. Apply manually during Month 2 knowledge base seeding
4. Atlas maintains the pattern store under architecture governance

**P2: ADOPT**

Integrate Fabric CLI into the ingestion pipeline at P2 build time:
- Install `fabric` with Ollama backend (no cloud model dependency)
- Wire `fabric --pattern ainchors-preprocess` as a pipeline step before the PII scanner
- Build per-tenant pattern configuration (P3 commercial tier feature flag: clients can supply custom patterns)
- Full Fabric REST API server for programmatic integration with Holonet

**Why not DEFER or SKIP?**

- The pattern library concept solves a real problem today (ungoverned, scattered prompt quality in RULES.md)
- Starting the pattern store in P1 means P2 launches with a mature, tested asset rather than building from scratch under P2 delivery pressure
- Community patterns (300+) provide a free knowledge base to draw from — even if the CLI is not yet running, the pattern library is a reference resource

---

## 5. DataMemory Roadmap Changes

One minor addition to TKT-0104:

**Add to Section 8, P1 Action 4 (Week 3–4, knowledge base ingestion pipeline):**
> Pre-ingestion pattern step: before documents are chunked, run them through the AInchors Pattern Store `ainchors-preprocess` template (extract_wisdom/create_markdown equivalent). This improves chunk quality, feeds the `quality_score` field, and is the manual P1 implementation of what becomes automated Fabric CLI processing at P2.

No structural changes to the DataMemory roadmap required. The pgvector + nomic-embed-text + PII scanner architecture is unchanged. Fabric sits upstream of the pipeline as a pre-processing layer.

---

## 6. Open Decisions for Ken

**D1 — CONCEPT-ONLY vs ADOPT at P1**
Atlas recommends CONCEPT-ONLY (pattern store, no CLI) at P1. If Ken wants immediate CLI access for ad-hoc document processing (e.g., processing the MIT Sloan materials or APRA CPG docs before embedding), ADOPT is viable — install takes ~5 minutes via Homebrew, Ollama backend, zero cloud dependency. Neither choice blocks P1 build.

**D2 — Pattern library ownership: Atlas A3 or new role?**
Atlas recommends Atlas A3 ownership at P1, reassess at P2 gate. If Ken prefers a cleaner separation of concerns and wants to plan for a dedicated "Prompt Architect" agent earlier, that is a valid P2 planning decision. Does not change the P1 recommendation.

---

## Summary

| Dimension | Assessment |
|-----------|-----------|
| Duplicates RAG pipeline? | No — operates at prompting/synthesis layer, not storage/retrieval |
| Highest value application | Pre-ingestion content structuring + agent prompt governance |
| P1 action | Create AInchors Pattern Store (`/patterns/`), 3–5 seed templates |
| P2 action | Integrate Fabric CLI into ingestion pipeline for client content |
| TOM gap | Real but addressable within Atlas A3 — no new agent needed at P1 |
| Data sovereignty risk | Zero when run on Ollama local (Gemma4/nomic-embed-text) |
| Roadmap change required | Minor — single line addition to TKT-0104 Action 4 |
| Open decisions | 2 (CLI at P1 yes/no; ownership model confirmation) |

---

**Status:** APPROVED — Ken Mun, 2026-05-12 (via Direct Ken approval)
*Atlas 🏛️ Enterprise Architect | AInchors | 2026-05-12*
