# MEMORY.md Archive — 2026-07-03

Archived from MEMORY.md as part of CHG-0808 platform hygiene trim to ≤12K chars.
These sections are older/less-frequently-used and retained here for reference.

---

## CREST v1.3 — Executed 2026-06-20 09:28 AEST (CHG-0680)
- **Status:** Approved and fully executed. TKT-0546 closed; TKT-0547 (UAT) closed.
- **Three moves:** (1) External loop ownership — Yoda owns CREST loop; agents are phase executors. (2) Sage-as-Judge — Sage renders Verify pass/fail/needs_human verdicts; specialists assemble evidence only. (3) Capability-based multi-model routing — **role × phase** matrix replaces binary model selection; `data_class` dimension is schema-ready but intentionally unpopulated in v1.3, deferred to CREST v2.0 / TKT-0710. Verify primary: gemma4:31b-cloud (20/20 benchmark).
- **Pre-Tier-A gates (G1-G5):** all completed before execution: CHG record, baseline snapshot, down-migration DDL, judgment benchmark (gemma4:31b-cloud 20/20; glm-5.1:cloud deferred for thinking-output issue), dispatch-validate baseline.
- **Execution tiers:** Tiers A–D completed 2026-06-20. Verification sweep WS1/WS2/WS3 passed; synthetic sub-CREST UAT passed (Plan/Execute/Verify/Replan/Synthesize/Done).
- **Docs:** `docs/CREST-v1.3-Recursive-Model-C.md`, `docs/CREST-v1.3-Model-Policy-Schema.md`, `agents/sage/SOUL.md` + `AGENTS.md`.
- **Oracle-reviewed:** kimi-k2.6:cloud 2026-06-20 09:15 AEST; 8 gaps fixed in v2.

## Yoda/Aria CREST Plan/Replan — kimi-k2.7-code:cloud Primary — 2026-06-20 13:40 AEST (CHG-0690)
- **Benchmark:** 12-atom Yoda+Aria CREST Plan test vs `glm-5.2:cloud`, `kimi-k2.7-code:cloud`, `deepseek-v4-pro:cloud`.
- **Verdict:** `kimi-k2.7-code:cloud` adjusted 91.5% > deepseek 87.2% > glm 84.6%.
- **Action:** PG `crest_phase_rules` updated — `yoda_master` Plan/Replan primary → `kimi-k2.7-code:cloud` (fallback `deepseek-v4-pro:cloud`); `business` Plan/Replan primary → `kimi-k2.7-code:cloud` (fallback `kimi-k2.6:cloud`).
- **SSOT:** `state/model-policy.json`, `agent-skills/crest/SKILL.md`, PG `state_model_policy.crest_phase_rules`.

## GLM-5.2:cloud Adoption — 2026-06-20 11:58 AEST (CHG-0685)
- **Verify role:** NOT viable. No filesystem access via `ollama run` and emits visible chain-of-thought; same block as glm-5.1:cloud.
- **Plan/Analysis role:** Adopted as primary for `design_backend` agents (Atlas, Thrawn, Lando, Mon Mothma). Corrected rubric-only benchmark: glm-5.2:cloud 91.7% (77/84), deepseek-v4-pro:cloud 90.5%, kimi-k2.7-code:cloud 89.3%.
- **Replan role:** `kimi-k2.7-code:cloud` primary for `design_backend`; it led on Replan in the benchmark.
- **Yoda/Aria primary:** Unchanged at `kimi-k2.7-code:cloud`.
- **Deepseek-v4-pro:cloud:** Demoted to fallback-only for `design_backend` Plan/Replan.

## Aria Default Chat Model Alignment — 2026-06-20 16:04 AEST (CHG-0691)
- **Decision:** Aria default chat/user-interaction model = `ollama/kimi-k2.7-code:cloud`, matching Yoda.
- **Scope:** `business`, `ahsoka`, `luthen` agent static models in `openclaw.json`; `business|Synthesize` PG rule moved to `kimi-k2.7-code:cloud`; `crest_v13.phase_rules` re-exported from PG.
- **SSOT:** `state/model-policy.json`, `state/critical-config-baseline.json`, PG `crest_phase_rules`, `~/.openclaw/openclaw.json`.

## Yoda CREST/Forge Self-Correction — 2026-06-21 09:56 AEST (Ken Mun)
- **Violation:** Yoda directly edited `scripts/db-write.sh`, `scripts/db-raw.sh`, and `scripts/test-db-write.sh` for TKT-0698 instead of dispatching Execute to Forge.
- **Rule locked in:** Yoda NEVER directly edits scripts/, infra/, or build/config files. Plan/Verify = Yoda; Execute = Forge via `sessions_spawn(agentId="infra")`.
- **No exceptions for:** small fixes, urgency, or "already in context". Per-instance exception requires explicit Ken/Angie approval.
- **Self-check:** before any `edit`/`write` on executable/config files, ask *"Is this Execute? Is this Forge's domain?"*

## Sprint 9 Planning Exception — Locked 2026-06-21 09:39 AEST (Ken Mun)
- **Sprint 9 (2026-06-22 → 2026-06-28) committed with 16 items** — explicit exception to the 6-item capacity rule.
- **Reason:** Must deliver TKT-0342 (PG SSOT Gap Remediation) and TKT-0368 (CREST v2.0 / Nexus Foundational Architecture) before OC2 arrives (ETA 6–13 Jul 2026, commission ~27 Jul).
- **Rule exception:** Velocity/capacity metrics will be skewed until both epics are complete. **Auto-rollover enabled** — unfinished Sprint 9 items roll into Sprint 10 automatically.
- **Priority stack:** TKT-0342 and TKT-0368 work takes precedence over all other Sprint 9 items.
- **Tooling note:** `db-sprint.sh current` incorrectly returned Sprint 11; actual next sprint was Sprint 9. Manually targeted Sprint 9 for all commits.

## Exec Guard Status — Revoked 2026-06-28 (CHG-0788)
- **Previous rule (CHG-0776, L-173/L-174):** Yoda would not use `exec` for arbitrary shell commands; all agents required allowlist approval.
- **Change:** Ken Mun override approval granted 2026-06-28 to revoke the exec guard due to operational outage wall.
- **Actions:** AGENTS.md Non-Negotiable #17 removed; MEMORY.md live restriction section removed; runtime gate `~/.openclaw/exec-approvals.json` set to `ask=off` for all agents; gateway restarted.
- **Remaining guard:** FORGE EXECUTE GATE (AGENTS.md #15) still routes scripts/infra/build/config edits to Forge. CREST orchestrator-only rule (CHG-0545) remains.
- **Rollback:** Re-add AGENTS.md #17, re-enable `ask=on-miss`/`security=allowlist` in exec-approvals.json.

## Open Bug — openclaw CLI wrapper PATH collision (TKT-0542)
- `bash openclaw cron get <id>` fails because `openclaw` wrapper resolves ImageMagick `import` binary instead of its intended helper. Workaround: use native `cron` tool. Not yet fixed.

## Master Platform Context (DNA) — 2026-06-21
- Context handoff documents stored in `docs/context-handoffs/` and mirrored to Google Drive.
- Drive folder: https://drive.google.com/drive/folders/1nQ5hUDeCfRTmGXFZkJmJ5DDLdgHemyp8
- Consolidation rule: Combine into a single master handoff when delta chain reaches 3+ or at next major milestone.

## Model Routing — Permanent Structure (LOCKED 2026-06-15, CHG-0596)
- Load skill: `bash scripts/skill-load.sh model-routing`. Model policy SSOT: `state/model-policy.json`.
- **NO-FABRICATION directive:** Yoda absolute NO fabrication of data.
- **Minimax trial TERMINATED** 2026-06-15 17:57 AEST (CHG-0596). Verdict: PARTIAL.

## CREST Groom vs Plan Process — Locked 2026-06-22 17:13 AEST (Ken directive)
- **Groom** = analyze ticket, refine scope, surface clarifications, assumptions, risks, open questions, and confirm decisions. Output is a **groomed brief**, not an execution plan.
- **CREST Step 1 — Plan** = takes the groomed brief and produces the execution plan: atoms, owner, schedule, rollback, evidence standards.
- Yoda must keep these separate. Groom first. Then CREST Plan. Then dispatch.

## Archived Sections (from 2026-06-20)
Previous archive reference pointing to `memory/MEMORY-archive-2026-06-20.md`. Superseded by this archive.