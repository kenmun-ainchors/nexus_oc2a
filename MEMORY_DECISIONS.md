# MEMORY_DECISIONS.md — Locked Architecture Decisions
# Append-only. Decisions here are FINAL unless Ken explicitly reopens.
# Size target: ≤ 6,000 chars. Auto-heal enforces.
# Superseded by TRIGGER-13 (TKT-0153 semantic memory store post-OC2).
# Last updated: 2026-05-11

## Product & Commercial
- **P1–P4:** P1=internal | P2=SaaS individual agents | P3=commercial tier label | P4=Enterprise/FSI. Licensed product DROPPED from P3.
- **P3 trigger:** formal ROI checklist before enabling. P4 may skip P3 (enterprise prefers physical).
- **P2:** RLS from day one. Multi-tenant (tenant_id, RLS, shared state).
- **P2 client model policy:** Gemma4 local only. BYOK = opt-in, client accepts data residency risk (CHG-0236).
- **Anthropic DPA:** Claude API blocked for client data (APRA CPG 235 / Privacy Act APP 11). Gemma4 local default.
- **BYOK + Nexus-first locked globally.** agentToAgent enabled. canvas embed: sub-agents pass full path only.

## Agile & Delivery
- Agile Framework v1.0 (CHG-0222). Sprint 1 started 2026-05-07. P2 target: end-Aug 2026. Aevlith inc. hard gate: end-May 2026.
- CI Cycle A running. Cycle 2A started.
- Sprint capacity: Pre-OC2=5 items | OC2-setup=2–3 | Post-OC2=5. 30% headroom. P2 contingency: mid-Sep 2026.

## Incidents (locked learnings)
- **INC-20260511-001 (22:03 AEST Day 17):** Thrawn wrote directly to openclaw.json → array schema break → ~2 min gateway crash. Fix: `openclaw doctor --fix`. Rule locked: Thrawn/Atlas NEVER write files. Config via gateway tool only.
- **INC-20260509-001:** 26h API degradation (balance $0). Auto-reload now live (TRIGGER-08).

## Routing Rules (locked)
- **L-026:** Build/implement/scripts → Forge ONLY. Atlas=EA assess. Thrawn=arch design. NEVER route build to Thrawn or Atlas.
- **Atlas vs Thrawn:** Atlas=enterprise-facing (TOGAF, P1–P4, client/market). Thrawn=platform-internal (Nexus, model routing, ITSM). Atlas sets constraints, Thrawn implements.

## Memory Architecture
- **Option B (current):** MEMORY.md (hot ≤8k) + MEMORY_TICKETS.md (backlog) + MEMORY_DECISIONS.md (decisions). Implemented 2026-05-11.
- **Option D (future, TRIGGER-13):** Semantic store on MinIO. TKT-0153. Gate: OC2 stable + MinIO 2-sprint prod validation.

## File Access
- **MinIO live (TKT-0124 ✅):** Agent blob store on OC1. Tailscale URL: `https://ainchorss-mac-mini.tail5e2567.ts.net`. Script: `scripts/minio-upload.sh`. Buckets: agent-memory, generated-media, workspace-assets, brand-code.
- **Google Drive (human layer):** "AInchors — Yoda Working Files" | Root: `1EyLi8JCvxwixhpBdRwP0PwdZokrg78Jl` | State: `state/gdrive-folders.json`
- **Rule:** Agent blobs → MinIO. Human docs → Drive. P1 permanent until P2 S3 migration (Option D).
