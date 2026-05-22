# [TKT-0195] Postgres Deploy + 5-Tier Schema on OC1

- **Notion ID:** `363c182953ff8145b4f2c8311e00833a`
- **Status:** Done
- **Type:** TKT
- **Priority:** High
- **Category:** 
- **Sprint:** Sprint 4
- **Created:** 2026-05-17
- **Last Edited:** 2026-05-21T10:20:00.000Z

## Notes

SCOPE LOCKED per Ken 2026-05-21. Sprint 4 deliverable: (1) brew install postgresql@16 + pgvector. (2) LaunchAgent auto-start. (3) Create ainchors_nexus DB. (4) Run 5-tier DDL from DataMemory_P1P4_Roadmap.md (T1 episodic audit, T2 vector store, T3 session, T4 shared state, T5 history). (5) Add tenant_id DEFAULT "ainchors" to all tables. Decisions: Q2=Homebrew, Q3=Redis deferred to P2, Q5=PII deferred to P2 gate, Q8=Shared schema+RLS from P2 day one. NOT IN SCOPE: JSON migration (TKT-0198), SHA-256 pipeline, vector embedding pipeline, agent wiring. Owner: Forge.
