# MEMORY Archive — 2026-05-16
# Content removed from MEMORY.md during trim (hard limit: 10,000 chars)
# Migrate to T4 semantic memory at P1 (TKT-0153, TRIGGER-13)
#
# archive_type: memory_trim
# date: 2026-05-16
# reason: hard_limit_10k
# migrate_to: t4_semantic
# original_size: 11141
# target_size: <10000
#
# ---

## Detailed Sprint Ticket Lists (removed from MEMORY.md)
→ See **MEMORY_TICKETS.md** (auto-managed) or Notion AKB Backlog for current ticket status.

### Sprint 4 (May 19-25)
- TKT-0141, TKT-0142 (S3 carries), TKT-0196 (Three Work Types Rule), TKT-0197 (SoT Register), Cloudflare Tunnel

### Sprint 5
- TKT-0195 Postgres (critical path), TKT-0108 doc gen, TKT-0157, TKT-0156, TKT-0130 QBR

### Sprint 6
- TKT-0198 JSON migration, TKT-0199 Event Bus, TKT-0170 PII Scanner, TKT-0150 DR Playbook

### Sprint 7
- TKT-0169 Typed Contracts, TKT-0171 RAG Pipeline

### Bucket C
- 8 tickets parked until QBR Sprint 5

### Bucket D
- TKT-0114 through TKT-0119 (Ken action required)

---

## Config Baseline Detail (removed from MEMORY.md)
→ See `state/critical-config-baseline.json` for live config drift detection.

Day 20 baseline (CHG-0306):
- CHG-0270 object format
- jq_queries→.model.primary
- Defaults primary=Haiku, Warden=Haiku
- BYOK+Nexus-first global
- agentToAgent enabled
- Canvas: sub-agents full path
- Auto-heal baseline updated to eliminate false-positive drift alerts
- CI Cycle A running; Cycle 2A started

---

## Golden Blueprint Drive URLs (removed from MEMORY.md)
→ Docs live in `docs/` folder; Drive copies for sharing.

- Internal Tech Strategy: https://drive.google.com/file/d/10oGRVyYlEPLshPNQG-sF_1-NZu3LbI5I/view
- System Architecture: https://drive.google.com/file/d/1FxEoTDzRlIMbbJHiD5XuR4Z5MNnpUAp-/view
- External Tech Strategy: approved CHG-0317

---

## LinkedIn Auth Detail (removed from MEMORY.md)
- MDP approved, Advertising API
- Token valid 2026-07-12
- PKCE removed
- Scopes: basicprofile, org_social, org_admin, ads
- AInchors company page onboarding deferred
- Trigger 05f9d2ef set

---

## Nexus Architecture Phase Detail (removed from MEMORY.md)
→ See `docs/Nexus-System-Architecture-v1.0.md` for full detail.

**Phase 2 (post-P2 +2wks):** Redis, multi-tenant RLS, Holonet v0, Citadel v0
**Phase 3 (TRIGGER-14):** Event sourcing, WORM audit, APRA

**KRI Dashboard:** https://www.notion.so/Nexus-Architecture-KRI-Dashboard-Option-B-Implementation-360c182953ff816a9d1dd5c104ca6cd1

**Structural fix 2.3+2.4:** Risk ↓ Sprint 4 end (25 May). Fixed Sprint 6 end (~8 Jun).

---

## Security Controls S2-S6 Detail (removed from MEMORY.md)
→ See `RULES.md` for full S1-S7 controls.

- S2: loopback only, 18789 never public
- S3: No ClawHub on prod
- S4: least-priv
- S5: no hardcoded creds
- S6: CHG logged/Warden
- S7: NAS encrypted (post-OC2)

---

*Archive created: 2026-05-16. Do NOT load into default context — read on-demand only.*
