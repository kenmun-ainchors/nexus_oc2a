# DRAFT Gap Analysis — Yoda Orchestrator MD Files
**STATUS: DRAFT FOR REVIEW — Awaiting Ken approval**
**Produced by:** Yoda 🟢 | **Issued by:** Ken Mun (CTO) | **Date:** 2026-05-10
**Files analysed:** 5 existing + 3 proposed (6 files read in full)
**Instruction ref:** YODA_MD email (19e116043602a5e1)

---

## SECTION 1 — File-by-File Diff Summary

### 1A — SOUL.md: Existing vs Proposed Yoda_SOUL.md

| Area | Existing | Proposed | Status |
|------|----------|----------|--------|
| Identity section | Name, role, basic traits | Name, role, streams, reporting, deployment | **ENHANCED** |
| Core traits | Direct, resourceful, proactive | Same traits implied but not listed separately | **SAME** |
| Communication style | Separate section (short sentences, no corp language) | Folded into "How I Summarise to Ken" | **ENHANCED** (more actionable) |
| Non-negotiables | 3 standards (Security, Veracity, Quality) + verbose rule list | 8 numbered rules, tighter scope | **ENHANCED** |
| Skill Gate rule | ❌ Not present | ✅ Rule #7 — audit-skill.sh + Ken approval required | **NEW** |
| Consulting stream | ❌ Not present | ✅ Consulting stream added (Ahsoka leads) | **NEW** |
| Routing table | ❌ Not present | ✅ Concise routing map (Atlas/Thrawn/Lando/Forge etc.) | **NEW** |
| Aevlith note | ❌ Not present | ✅ TKT-0114 placeholder | **NEW** |
| Key references section | ❌ Not present | ✅ Links to MEMORY.md, RULES.md, Holocron, Model3-Policy | **NEW** |
| Cadences table | ✅ Full table (12 entries incl. weekly/monthly/quarterly) | ❌ Not present — deferred to RULES.md | **MISSING-IN-NEW** |
| Slash commands | ✅ /resume, /research, /diagnostics, /commit (with descriptions) | ❌ Not present | **MISSING-IN-NEW** |
| Credit alert rule | ✅ Check cost-alert-state.json every response, alert both Ken+Angie | ❌ Not present | **MISSING-IN-NEW** |
| Obsidian reference | ❌ Still in /commit rule: "Obsidian + git" — Obsidian retired Day 9 | N/A — correctly absent | **CONFLICT** (existing is wrong) |
| Boundaries section | ✅ Private things, ask before acting, group chat rules | ❌ Not present | **MISSING-IN-NEW** |
| Continuity instruction | ✅ Wake fresh, read MEMORY.md + daily logs | Same intent in Key References section | **SAME** |
| SOUL size | 4,304 chars ✅ under 5,000 | 3,243 chars ✅ under 5,000 | **SAME** — both compliant |

---

### 1B — RULES.md: Existing (RULES.md + YODA_RULES.md) vs Proposed Yoda_RULES.md

| Area | Existing | Proposed | Status |
|------|----------|----------|--------|
| **Scale** | 89,310 + 5,631 = ~95KB combined | 16,541 chars (~17KB) | **⚠️ SIGNIFICANT** — 78KB gap |
| Identity & authority (R1-R3) | Spread across SOUL + RULES | Clean Part 1 (R1-R3) | **ENHANCED** |
| HIVE architecture (R4) | In MEMORY.md and various files | Clean Part 2 with ASCII diagram | **ENHANCED** |
| Storage architecture (R5) | Not consolidated in RULES | New — Drive+MinIO hybrid locked | **NEW** |
| Model/cost strategy (R6) | In MEMORY.md only | Clean Part 2 table | **NEW** in RULES |
| Nexus modules (R7) | In MEMORY.md | Part 2 table | **NEW** in RULES |
| Full agent roster (R8) | MEMORY.md + ad-hoc | Clean Part 3 table with all 14 agents incl. Forge, Ahsoka, Luthen | **ENHANCED** |
| Routing (R9) | YODA_RULES.md (partial — Atlas, Thrawn, Lando, Mon Mothma only) | Full YAML routing tree for ALL agents | **ENHANCED** |
| Cross-stream protocol (R10) | Not formalised | Clean 8-step cross-stream procedure | **NEW** |
| Sanctum protocol (R11) | Referenced but not structured | Clean Part 4 | **ENHANCED** |
| S1-S7 controls (R12) | In MEMORY.md | Table in Part 4 | **SAME** content, better location |
| SKILL gate (R13) | In RULES.md (added today) | Part 4 R13 | **SAME** |
| HITL framework (R14) | Referenced but no 5-tier definition | Clean 5-tier definition | **NEW** |
| Warden T3 details (R15) | Partial | Full coverage incl. failureAlert | **ENHANCED** |
| Daily cadences (R16) | In SOUL.md cadences table + HEARTBEAT.md | Part 5 timetable | **ENHANCED** (more complete) |
| Weekly ceremonies (R17) | In SOUL.md + ad-hoc | Part 5 | **SAME** content |
| QBR ceremony (R18) | TKT-0130 raised but not in RULES | Part 5 — Jan/Apr/Jul/Oct | **NEW** in RULES |
| Strategy-to-backlog (R19) | docs/Strategy_to_Backlog_Pipeline_v0.1.md | Reference in Part 5 | **SAME** |
| Telegram dual-bot (R20) | In RULES.md | Part 6 clean | **SAME** |
| Telegram fallback (R21) | Added today (CHG-0262) | Part 6 | **SAME** |
| Document delivery (R22) | In RULES.md | Part 6 | **ENHANCED** |
| CHG discipline (R23) | Detailed in RULES.md | Part 7 summary | **SAME** content, less detail |
| Incident protocol (R24) | Detailed in RULES.md | Part 7 summary | **SAME** content, less detail |
| DoD gate (R25) | Partial | Part 7 — 23 drafts mentioned | **ENHANCED** |
| Vision + commercial (R26-R30) | Scattered | Clean Part 8 | **ENHANCED** |
| AI Charter principles (R31) | In docs/AI_CHARTER_v1.0.md | Part 9 summary | **ENHANCED** |
| **Warden model** | claude-haiku-4-5 (CHG-0230, confirmed today) | ❌ "gemma4:e2b" listed | **CONFLICT** |
| **Forge agent** | `infra` agentId, partially defined | Listed as "🏗️ Forge" with LIVE status | **CONFLICT** (name not yet confirmed) |
| Detailed script procedures | ✅ Extensive (CLI commands, error handling, step-by-step for every task) | ❌ Not present — RULES.md is strategic, not a runbook | **MISSING-IN-NEW** |
| Slash command procedures | ✅ /resume, /research, /diagnostics, /commit, /sprint detail | ❌ Not present | **MISSING-IN-NEW** |
| Credit alert logic | ✅ Detailed 3-tier alert logic | ❌ Not present (only "Alert at A$400") | **MISSING-IN-NEW** |
| PVT procedure detail | ✅ bash scripts/pvt.sh, 9/9 must pass | ❌ Not present | **MISSING-IN-NEW** |
| Pre-risky-op checkpoint | ✅ Full flush sequence | ❌ Not present | **MISSING-IN-NEW** |
| EOD close procedure | ✅ Journal + blog, specific formats | ❌ Only mentioned as "11:55PM" | **MISSING-IN-NEW** |
| HEARTBEAT.md reference | ✅ Referenced for 30-min checks | ❌ Not referenced | **MISSING-IN-NEW** |
| Version history | None in existing RULES.md | ✅ Clean version history v1.0.0 → v2.0.0 | **NEW** |

---

### 1C — ORCHESTRATOR.md (No existing equivalent)

| Area | Status |
|------|--------|
| Full mandate definition (what Yoda owns vs doesn't) | **NEW** |
| HIVE ASCII topology diagram | **NEW** |
| Storage layers diagram | **NEW** |
| Platform module status table (with P2/P3 gates) | **NEW** |
| Full fleet topology diagram (3 streams + governance) | **NEW** |
| Agent detailed profiles table | **NEW** |
| Task routing procedures (5 steps) | **NEW** |
| Quality gate procedures | **NEW** |
| HITL gate procedures | **NEW** |
| Governance (Sanctum, security, incident) | **NEW** |
| Strategic alignment (P1-P4, revenue streams) | **NEW** |
| Key decisions log (13 entries) | **NEW** |
| Active sprint snapshot | **NEW** |
| File & reference map | **NEW** |
| Update protocol | **NEW** |
| Aevlith placeholder `{{AEVLITH_PLACEHOLDER}}` | **NEW** — clean placeholder for TKT-0114 |

---

## SECTION 2 — Critical Gaps (Must Resolve Before Adoption)

### GAP-1 — Warden Model Conflict ⚠️ CRITICAL
**What:** Proposed RULES.md R8 lists Warden model as `gemma4:e2b`. Current live model is `claude-haiku-4-5` (CHG-0230, confirmed via Warden cron and model-policy.json today).
**Files:** Proposed Yoda_RULES.md, Section R8 Agent Roster
**Risk:** If RULES.md is adopted as-is, Warden compliance documentation would be wrong. Any future session loading this file would have incorrect fleet state.
**Resolution:** Update R8 to `claude-haiku-4-5 (Haiku)` before adoption.

---

### GAP-2 — Missing Operational Runbook Content ⚠️ HIGH
**What:** The proposed RULES.md (17KB) does not contain the detailed operational procedures that are in the existing RULES.md (89KB). Missing: slash command detail (/resume, /research, /diagnostics, /commit, /sprint), credit alert 3-tier logic, PVT procedure, pre-risky-op checkpoint, EOD close format, script paths, HEARTBEAT.md reference.
**Files:** Existing workspace/RULES.md (89KB) vs Proposed Yoda_RULES.md (17KB)
**Risk:** If the proposed RULES.md *replaces* the existing, Yoda loses ~78KB of operational procedures. Slash commands would stop working correctly. EOD close would lose journal/blog format references. Credit alert logic would be missing.
**Resolution:** The proposed RULES.md is a strategic reference layer — it should not replace the existing operational RULES.md. Two options:
- **Option 1:** Rename existing RULES.md → YODA_RUNBOOK.md (operational detail). Adopt proposed as YODA_RULES.md (strategic reference). Both coexist.
- **Option 2:** Merge the missing operational detail into the proposed RULES.md (would make it ~35-40KB).
**Recommended:** Option 1 — cleaner separation of concerns.

---

### GAP-3 — Credit Alert Logic Missing ⚠️ HIGH
**What:** Existing SOUL.md has: "Credit alerts (3-tier, non-negotiable): Check balance vs state/cost-alert-state.json on every response. Alert BOTH Ken (8574109706) AND Angie via Aria (8141152780)." Proposed SOUL.md and RULES.md only say "Alert at A$400."
**Files:** Both proposed files
**Risk:** Credit alert no longer fires both Ken and Angie, or no longer fires on every response. Repeats INC-20260509-001 blind spot.
**Resolution:** Add credit alert rule explicitly to proposed SOUL.md rule list OR confirm it's covered by R21 (Telegram fallback) + existing HEARTBEAT.md logic.

---

### GAP-4 — Forge Agent Name Conflict ⚠️ MEDIUM
**What:** Proposed RULES.md and ORCHESTRATOR.md introduce "Forge 🏗️" as a named LIVE agent with `agentId: forge`. Current platform has `agentId: infra` (not named Forge). No CHG or TKT has formally confirmed "Forge" as the name for the infra agent.
**Files:** Proposed Yoda_RULES.md R8, Yoda_ORCHESTRATOR.md Section 5
**Risk:** Agent routing references `forge` which doesn't match the actual `infra` agentId. Confusion in any session that loads this RULES.md.
**Resolution:** Confirm whether `infra` agent has been formally renamed to Forge, or update proposed files to use `infra` agentId. If Forge is the intended name, raise TKT + CHG to formalise.

---

### GAP-5 — SOUL.md Missing Boundaries Section ⚠️ LOW
**What:** Existing SOUL.md has a "Boundaries" section (private things, ask before external actions, group chat rules). Not in proposed SOUL.md.
**Files:** Proposed Yoda_SOUL.md
**Risk:** Low — these are covered partially in R3 and the ORCHESTRATOR.md. But the "not Ken's voice in group chats" principle is useful in the SOUL for fast context loading.
**Resolution:** Add a 2-line Boundaries note to proposed SOUL.md, or confirm it's adequately covered by R3.

---

## SECTION 3 — Enhancements Worth Adopting

### HIGH PRIORITY — Adopt immediately

**H1 — Proposed SOUL.md v2.0.0 (after fixing GAP-3 and GAP-5)**
- Cleaner, tighter, better structured
- Adds Consulting stream (Ahsoka) — currently absent
- Adds Skill Gate rule (#7) — critical given today's TKT-0141/0142
- Adds routing table — agents now self-describe their routing in SOUL context
- Removes Obsidian reference (retired Day 9 — existing SOUL.md has a stale /commit rule)
- Adds Aevlith placeholder
- 3,243 chars — room to add missing items without breaching 5,000 limit

**H2 — ORCHESTRATOR.md as net-new reference document**
- No existing equivalent. Fills a genuine gap.
- Provides Ken with a single authoritative picture of the entire platform
- Fleet topology diagram is immediately useful for onboarding and decision-making
- Key decisions log (section 10) is valuable institutional memory
- Update protocol (section 13) ensures it stays current
- Aevlith placeholder is the right approach — no premature commitment

**H3 — Proposed RULES.md routing (R9 YAML) over existing YODA_RULES.md routing**
- Existing YODA_RULES.md routing covers Atlas, Thrawn, Lando, Mon Mothma
- Proposed R9 covers ALL agents including Spark, Ahsoka, Shield, Lex, Sage, Warden, Forge, Krennic, Luthen
- YAML format is machine-readable and easier to update
- This is a clear step-up from the existing routing rules

**H4 — HITL 5-tier framework (R14)**
- Does not exist in current RULES.md in this structured form
- Operationally valuable — clarifies what Yoda auto-executes vs what needs human approval
- Directly relevant to Sanctum protocol and new agent onboarding

---

### MEDIUM PRIORITY — Adopt in next sprint

**M1 — Cross-stream orchestration protocol (R10)**
The 8-step multi-stream procedure (Ahsoka→Atlas→Lando→Mon Mothma→Sage→Sanctum→Yoda→Ken) codifies what Yoda currently does ad-hoc. Worth formalising.

**M2 — Storage architecture consolidation (R5)**
The Drive + MinIO hybrid decision is locked but not in any RULES file. R5 puts it in the right place — referenced at the start of every session.

**M3 — Fleet roster with all 14 agents (R8)**
Current MEMORY.md has the roster. RULES.md having it too means any context load has the fleet state. Better than referencing MEMORY.md every time.

---

### LOW PRIORITY — Nice to have

**L1 — Key decisions log in ORCHESTRATOR.md (Section 10)**
Useful but duplicates CHANGELOG.md. Could cause drift if not kept in sync. Only adopt if there's an automated way to keep it current.

**L2 — Active sprint snapshot in ORCHESTRATOR.md (Section 11)**
Useful on Day 16 but stale by Day 17. Only valuable if updated regularly. Consider making this a generated section rather than static.

---

## SECTION 4 — Sections to Preserve As-Is

These exist in the current files and are fine. Carry them forward unchanged:

1. **AI Charter principles** — both existing and proposed reference the same 7 principles correctly
2. **Telegram dual-bot protocol** — both have correct bot names and routing. Consistent.
3. **S1-S7 controls table** — content is identical. Proposed has cleaner formatting.
4. **CHG discipline format** — both agree on format. Proposed is more concise but accurate.
5. **HIVE OC1/OC2 hardware spec** — both correct. Proposed ORCHESTRATOR.md has the fullest version.
6. **P1-P4 roadmap** — identical across both. ORCHESTRATOR.md has the most complete version.
7. **Sanctum protocol (Shield→Lex→Sage)** — identical. Both correct.
8. **Nexus Star Wars naming** — both consistent. No conflict.
9. **Model/cost 4-tier strategy** — both consistent. Proposed RULES.md R6 is the cleanest version.

---

## SECTION 5 — Merge Recommendation

**Recommendation: Option C — Phased Adoption**

**Phase 1 (now):**
1. Adopt proposed **SOUL.md** to replace existing — after fixing GAP-3 (credit alert) and GAP-5 (boundaries)
2. Add proposed **ORCHESTRATOR.md** as net-new — no conflict, high value immediately
3. Fix Warden model error (GAP-1) in proposed RULES.md before any further adoption

**Phase 2 (Sprint 3 or 4):**
4. Resolve GAP-2 (runbook gap): rename existing RULES.md → YODA_RUNBOOK.md (preserve all operational detail), adopt proposed Yoda_RULES.md as the strategic reference layer. Both coexist.
5. Resolve GAP-4 (Forge naming): confirm agentId and raise CHG to formalise the name

**Reasoning:**
The proposed SOUL.md is clearly superior — cleaner, more current, adds Skill Gate and Consulting stream. Adopt it now. The ORCHESTRATOR.md is net-new with no risk and high value. Adopt it immediately. The RULES.md situation is more nuanced: the proposed version is an excellent *strategic reference* but it must not replace the existing *operational runbook* (89KB) without preserving that content. The 78KB gap is the dominant risk. Phase 2 resolves this cleanly with a two-layer architecture: YODA_RUNBOOK.md (operational) + YODA_RULES.md (strategic). Option A (full replacement) is too risky given GAP-2. Option B (selective merge) is viable but complex given the scale difference.

---

## SECTION 6 — Char Count Check

| File | Chars | Limit | Status |
|------|-------|-------|--------|
| Existing SOUL.md | 4,304 | 5,000 | ✅ Compliant |
| Proposed Yoda_SOUL.md | 3,243 | 5,000 | ✅ Compliant — 1,757 chars of headroom |

No blocker. Both files are within the hard limit.
After adding GAP-3 (credit alert ~80 chars) and GAP-5 (boundaries ~120 chars), proposed SOUL.md would be ~3,443 chars — still well within 5,000.

---

## SECTION 7 — Ken's Decision Points

1. Adopt proposed **SOUL.md v2.0.0** to replace existing workspace/SOUL.md? *(Yes / No / Modify first)*

2. If Yes to #1: Add credit alert rule (GAP-3) and boundaries note (GAP-5) to proposed SOUL.md before adoption? *(Yes — add both / Yes — add credit alert only / No — omit both)*

3. Add **ORCHESTRATOR.md** as a net-new reference document at `workspace/docs/Yoda_ORCHESTRATOR.md`? *(Yes / No)*

4. Fix **Warden model** in proposed RULES.md (GAP-1): change from `gemma4:e2b` to `claude-haiku-4-5`? *(Yes / No — I'll confirm the right model)*

5. Confirm **Forge** as the formal name for the `infra` agentId (GAP-4)? *(Yes — Forge is correct / No — keep as infra / Confirm separately)*

6. For the **RULES.md** adoption: which approach? *(A: Replace existing RULES.md entirely with proposed / B: Keep existing RULES.md as YODA_RUNBOOK.md + adopt proposed as YODA_RULES.md strategic layer / C: Defer RULES.md decision to Sprint 4)*

7. Activate the **phased adoption plan** (Option C): Phase 1 now (SOUL.md + ORCHESTRATOR.md), Phase 2 in Sprint 3/4 (RULES.md)? *(Yes / No — do all at once / No — defer everything)*

---

*DRAFT FOR REVIEW — No files modified. No CHG records raised.*
*Produced by: Yoda 🟢 | 2026-05-10 | Status: Awaiting Ken's decisions 1–7*
