# HBR: Redesigning Your Marketing Organisation for the Agentic Age
**Source:** HBR, May 8 2026 | **Saved:** 2026-05-10 | **TKT:** TKT-0127
**Original:** docs/HBR_Agentic_Marketing_Org_May2026.docx

---

## Core Thesis
AI doesn't fix marketing by speeding up existing workflows. It requires a new operating model built for human-agent collaboration. The bottleneck is the operating model, not the tools.

---

## The Agentic Marketing Platform — 4 Layers

| Layer | What it does | AInchors mapping |
|-------|-------------|-----------------|
| **Foundation — Brand Code** | Machine-readable KB: brand strategy, product experience, customer insights, business rules. Encoded as taxonomies, prompt templates, decision trees, tagged datasets. Evolves with use. Prevents knowledge loss when people leave. | Aria's knowledge base — to be built as structured brand + product intelligence layer |
| **Execution Layer** | Specialized agents per workstream (content gen, localization, testing, distribution, reporting). Each handles one type of task. | Spark (content/social). New agents needed for other workstreams. |
| **Orchestration Layer** | Coordinates execution agents — manages dependencies, priorities, routing, triggers. Replaces project plans + status meetings. Routes decisions to humans when judgement needed. | Aria coordinates. Future: dedicated orchestration agent. |
| **Interface Layer** | Single surface in familiar tools (Slack, WhatsApp, Teams). Marketers set intent, review outputs, make decisions. No retraining needed. | Telegram (Angie + KL team). MinIO for file/asset sharing (TKT-0124). |

---

## Five Agentic Workstreams

| Workstream | What agents do | Human role |
|------------|---------------|------------|
| **Intelligence & Ideation** | Synthesize market signals, competitive intel, audience behaviour, performance data → structured briefs | Evaluate opportunities, set priorities, define strategic intent |
| **Content Creation** | Generate content across formats/channels/segments from brand code. On-brief from first draft. | Set standards, shape creative intent, elevate where agents can't |
| **Research & Testing** | Design + execute experiments (real or synthetic audiences), synthesize results. Embedded, not episodic. | Define learning agenda — what to test, why, how results inform strategy |
| **Distribution** | Adapt, schedule, deploy content across channels/markets/segments | Channel strategy + partnership decisions |
| **Performance & Reporting** | Monitor continuously, flag anomalies, feed learnings back into system in near real time | Interpret results, understand tradeoffs, guide system evolution |

---

## The New Marketer Role
- Director of work, not producer of work
- Sets intent, evaluates outputs, makes decisions in context
- Value = judgement, not execution
- Must think in workflows, not functions
- Must let go of the instinct to step in and do the work

---

## Benchmarks (BCG research cited)
- Marketing materials adapted up to **98x faster**
- Unit costs reduced by **80%**
- Click-through rates up to **17x**
- Up to **3x ROI, campaign speed, and content volume**

---

## AInchors Application Notes
- **Brand Code folds into TKT-0124 business memory layer** (Ken confirmed 2026-05-10). Not a separate build — it IS the structured content of the MinIO-backed business memory layer.
- TKT-0124 = infrastructure + memory layer (MinIO + Brand Code documents + business data)
- TKT-0127 = agents + workstreams built on top of TKT-0124
- Angie + KL team = the human directors in this model
- Spark already covers content creation + distribution for Ken's personal profile
- Need to extend Spark (or new agents) to cover AInchors brand channels
- Phase 1 (P1 MVP, pre-OC2): TKT-0124 live → Brand Code seeded → Content Creation + Distribution workstreams active for Angie+KL team
- Phase 2 (P2, post-OC2): All 5 workstreams + orchestration layer + external client delivery
