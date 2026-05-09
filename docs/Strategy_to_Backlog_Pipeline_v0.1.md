# Strategy-to-Backlog Pipeline v0.1
**Status:** Draft | **Owner:** Yoda (coordination) + Lando (documentation) | **Ken approved:** 2026-05-10
**TKT:** TKT-0125 | **Dependency:** TKT-0110 (Process Documentation Framework)

---

## Purpose

Convert strategy and roadmap artefacts produced by Atlas, Thrawn, and Lando into groomed, sprint-ready backlog tickets. Close the gap between planning and execution.

**Problem it solves:** Architecture roadmaps exist but sit in docs until manually noticed. Items only enter the backlog reactively. This pipeline makes it systematic.

---

## The Pipeline

```
Strategy Artefact (Atlas/Thrawn/Lando)
        ↓
Backlog Seeding List (required deliverable)
        ↓
Roadmap Refinement Ceremony (QBR or triage)
        ↓
Groomed Tickets in AKB Backlog (Notion)
        ↓
Sprint Planning → Sprint
```

---

## Ceremony: Roadmap Refinement

### When
- **Quarterly (QBR):** 1st Jan / Apr / Jul / Oct — full roadmap review + bulk seeding
- **Ad-hoc triage:** Any time a new strategy artefact is completed (Atlas, Thrawn, or Lando deliverable)

### Who
| Role | Responsibility |
|------|---------------|
| **Yoda** | Facilitates, raises tickets, maintains backlog |
| **Atlas** | Enterprise/P1-P4 roadmap input |
| **Thrawn** | Platform/Nexus roadmap input |
| **Lando** | Process + BPM input |
| **Ken** | Approves priorities, signs off backlog items |

### Inputs
- Completed strategy/roadmap documents (e.g. DataMemory_P1P4_Roadmap.md, Nexus Enterprise Landscape)
- Current sprint state + capacity model
- Open decisions (state/open-decisions.json)
- Any flagged "not yet ticketed" items from architecture reviews

### Outputs
- Groomed tickets in AKB Backlog (TKT-NNNN) with: title, type, priority, description, upstream artefact reference
- Backlog seeding list appended to the source artefact (see DoD below)
- Updated sprint plan if any items are immediately actionable

### Steps (Yoda runs this)
1. Read all strategy artefacts completed since last ceremony
2. Extract actionable items — anything described as a build, deploy, implement, configure, migrate, or decide
3. Check against existing tickets — no duplicates
4. Raise tickets via `scripts/ticket.sh new` for each net-new item
5. Tag each ticket with the upstream artefact reference in the description
6. Group tickets into epics where applicable (e.g. "P2 Data Infrastructure")
7. Deliver summary to Ken for priority approval
8. Ken approves priorities → items enter the prioritised backlog
9. Sprint planning picks up from there

---

## Definition of Done — Strategy Artefacts

A strategy or roadmap document is **NOT Done** until:
- [ ] Backlog Seeding List section appended to the document
- [ ] All actionable items raised as TKT-NNNN tickets in AKB Backlog
- [ ] Tickets linked back to the source artefact
- [ ] Ken has reviewed and approved priorities

**Backlog Seeding List format** (append to every strategy doc):
```markdown
## Backlog Seeding List
| Item | Priority | TKT | Notes |
|------|----------|-----|-------|
| Deploy MinIO on OC1 | High | TKT-0124 | Interim before P2 AWS S3 |
| ... | ... | ... | ... |
```

---

## Agile Framework Integration

This ceremony slots into the existing framework as follows:

| Ceremony | Cadence | Owner |
|----------|---------|-------|
| Sprint Planning | Sunday | Yoda + Ken |
| Daily Standup | 8AM AEST | Yoda → Telegram |
| Sprint Review | Friday | Yoda + Ken |
| **Roadmap Refinement** | **QBR + ad-hoc** | **Yoda + Ken** |
| Retrospective | Friday (post-review) | Yoda + Ken |

**Agile Framework v1.0 update required:** Add Roadmap Refinement as a formal ceremony. Lando to incorporate into process docs under TKT-0110.

---

## Retroactive Action (immediate)

Atlas's DataMemory_P1P4_Roadmap.md — backlog seeding list to be appended:

| Item | Priority | TKT |
|------|----------|-----|
| MinIO on OC1 — interim blob/file access | High | TKT-0124 |
| Postgres 16 + pgvector deployment on OC1 | High | TBD (P1 sprint) |
| Anthropic DPA verification + Data Residency Register | High | TBD |
| tenant_id on all Postgres tables (pre-schema lock) | High | TBD |
| Embedding model lock (nomic-embed-text 768-dim) | High | TBD |
| PII scanner (Presidio) in ingestion pipeline | Medium | TBD |

Remaining TBDs to be raised at next grooming session with Ken.

---

## Version History
| Version | Date | Change |
|---------|------|--------|
| v0.1 | 2026-05-10 | Initial draft — Ken approved concept |
