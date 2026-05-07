# TKT-0086 — Strategy Coherence Review & Governance Gap Analysis
**Steps 1 + 2 | Produced by Yoda | 2026-05-07**

---

## STEP 1 — COHERENCE REVIEW

Documents reviewed:
- `docs/ainchors-strategy-okr-2026-05.md` (OKR)
- `docs/ainchors-guardrails-rules-2026-05.md` (Guardrails)
- `docs/governance-guardrails-2026-05.md` (G1-G2, W1-W2)
- VMS provided inline (training-led 80/20, SME AU/SEA, Auralith/Nexus, Angie network)

---

### 1. Internal Consistency

#### ✅ Aligned — What hangs together well

1. **Training-led 80/20 priority is consistent across all three docs.** VMS frames it as the strategic split. OKR makes it the core constraint of C1 ("staying training-led"), T1-T3, and R3. Guardrails enforce it via R3 ("Aria must treat training as primary top-of-funnel for the next 6-12 months"). All three layers are coherent.

2. **Nexus-first for implementation is coherent.** VMS says Nexus is the default platform. OKR measures it via C1-KR3, S1-KR3, X1-KR2. Guardrails enforce it via Y1, C1 (Ahsoka must propose Nexus as default; non-Nexus requires human approval + CHG). Consistent at strategy, measurement, and rule levels.

3. **SME target segment (AU/MY, 10-200 FTE) is consistently framed.** VMS defines the ICP. OKR KR1 specifies "10-200 FTE" founders. Guardrails R2 requires Aria to define entry points appropriate for this audience. C2 protects them from premature L3 upsell.

4. **Governance-by-design (Sanctum) is consistently demanded.** VMS mentions governance built in from day one. OKR G1 makes it a standalone objective with KRs. Guardrails G1-G2 define the specific operational rules. All three docs agree on Shield→Lex→Sage for client-facing outputs.

5. **Auralith/AInchors delineation is consistent within the strategy docs.** OKR clearly separates AInchors (commercial entity, training/consulting) from Auralith (technology/IP, Nexus). Guardrails reference both by name in Atlas A1 (P2/P3 roadmap includes "multi-client Nexus as managed platform for AInchors clients"). Internal coherence is good.

6. **Evidence-first principle (C3) aligns with VMS trust narrative and OKR outcome measurement.** C3 requiring grounded ROI claims maps to C1-KR4 (case studies describing concrete outcomes) and T1-KR2 (NPS measurement). No conflict.

---

### 2. Completeness — Gaps

#### ⚠️ Gap 1: SEA markets beyond MY not guardrailed
- **OKR context:** VMS mentions AU/SEA broadly; OKR C1-KR1 specifies AU/MY for the 6-12 month window.
- **Missing:** No guardrail for what happens when Ahsoka or Aria encounters prospects from Singapore, Indonesia, Philippines, or other SEA markets. Lex should check regulatory implications per market, but there's no rule triggering this.
- **Docs:** `ainchors-guardrails-rules-2026-05.md` Section 6 (C1-C4) — no SEA-beyond-MY rule.
- 💡 **Fix:** Add C5 to Ahsoka guardrails: "For SME clients outside AU/MY, Lex must confirm regulatory equivalency and human (Ken/Angie) must approve market entry before any proposal is issued."

#### ⚠️ Gap 2: NPS and quality tracking not guardrailed
- **OKR context:** T1-KR2 requires NPS ≥ 40 and "would recommend" ≥ 80%.
- **Missing:** No guardrail requires agents to capture, log, or report NPS data from workshops. There's no rule about how NPS data is collected or where it lives.
- **Docs:** OKR `ainchors-strategy-okr-2026-05.md` T1-KR2 vs guardrails Sections 5 (Aria) and 6 (Ahsoka) — no NPS capture rule.
- 💡 **Fix:** Add R4 or an Aria/Ahsoka rule: post-workshop NPS must be logged to Notion/Holocron within 48h of workshop completion. Aria owns collection; Yoda owns aggregation for reporting.

#### ⚠️ Gap 3: Architecture review cadence not guardrailed
- **OKR context:** X2-KR3 requires "at least 2 internal architecture reviews per quarter."
- **Missing:** Atlas A1-A3 define roadmapping and classification rules, but no guardrail mandates the quarterly review cadence or what constitutes a valid architecture review.
- **Docs:** OKR Section 6 (X2-KR3) vs guardrails Section 4 (A1-A3).
- 💡 **Fix:** Add A4: "Atlas must trigger a quarterly architecture review within the first 2 weeks of each quarter. Yoda schedules it; Ken approves the review finding before the quarter ends."

#### ⚠️ Gap 4: Case study publication not specifically guardrailed
- **OKR context:** C1-KR4 requires publishing 2 case studies (1 training-led, 1 consulting/Nexus-led).
- **Missing:** C3 (evidence-first) applies to proposals but isn't explicitly extended to case studies, which carry even greater public accountability. No rule about client sign-off before publication.
- **Docs:** OKR Section 3 (C1-KR4) vs guardrails Section 6 (C3) — proposal focus, not case study.
- 💡 **Fix:** Extend C3 to cover case studies explicitly: "Case studies require written client sign-off AND Shield/Lex/Sage triad clearance before publication. No case study may claim concrete outcomes without documented evidence."

#### ⚠️ Gap 5: Sanctum SLA measurement not mandated
- **OKR context:** G1-KR2 requires tracking < 24h / < 72h turnaround averages.
- **Missing:** G2 sets the SLA targets. But no guardrail requires logging review timestamps or producing a monthly SLA report. Without logging, KR2 can't be measured.
- **Docs:** G1-KR2 in OKR vs G2 in governance guardrails doc — target defined, measurement mechanism absent.
- 💡 **Fix:** Add to G2: "All Sanctum review start and completion timestamps must be logged to `state/sanctum-sla-log.json`. Yoda produces a monthly SLA report and flags missed SLAs to Ken."

#### ⚠️ Gap 6: Use-case pattern capture from workshops not guardrailed
- **OKR context:** T1-KR4 requires capturing 10+ SME use-case patterns into Holocron from workshops.
- **Missing:** Y3 requires Holocron entries for major capabilities. But Y3 is Yoda's rule, not an Aria/Ahsoka rule. Workshop-derived SME use-case patterns come from Aria/Ahsoka interactions, not Yoda platform decisions.
- **Docs:** OKR T1-KR4 vs guardrails Section 3 (Y3) — wrong agent scoped.
- 💡 **Fix:** Add an Aria rule (R4 or new section): after each workshop, Aria must capture at least 1 SME use-case pattern into Holocron. Ahsoka captures use-case patterns during consulting engagements. Aggregate tracked in Notion.

---

### 3. Conflicts

#### 🔴 Conflict 1: Atlas A1 horizon timing vs VMS managed tenant framing
- **Conflict:** Atlas A1 defines the 3-year horizon as "P2→P3, multi-client Nexus as managed platform for AInchors clients." VMS states managed tenants come in "years 3-5." The P2→P3 transition in Atlas A1 implies managed tenants are a 2-3 year deliverable, not 3-5 years.
- **Docs:** `ainchors-guardrails-rules-2026-05.md` Section 4 (A1) vs VMS inline context.
- **Risk:** Atlas and Thrawn could plan for multi-client managed tenancy earlier than VMS intended, pulling platform resources away from training-led delivery.
- 💡 **Fix:** Clarify A1: the 3-year horizon covers "P2→P3 readiness and 3-5 SME pilot managed clients on Nexus." Mass MSP (managed service provider) scale is a 5-year horizon only.

#### 🔴 Conflict 2: Aria R1 "productised offers only" vs Ahsoka C4 escalation for large enterprise
- **Conflict:** R1 prohibits Aria from selling anything outside defined productised offers (AI Operations Jumpstart, etc.) unless a CHG is raised. C4 requires Ahsoka to escalate proposals > A$50,000 to Aria/Angie and Yoda. If a large client wants a custom (non-productised) engagement, Aria is technically blocked from accepting it under R1, while C4 requires escalation to Aria for the decision.
- **Docs:** `ainchors-guardrails-rules-2026-05.md` Section 5 (R1) vs Section 6 (C4).
- **Risk:** A A$60K custom enterprise engagement gets escalated to Aria (per C4), but Aria can't approve it without a CHG (per R1). This creates a decision deadlock or forces a CHG for every non-standard enterprise deal, which may be too slow.
- 💡 **Fix:** Add an exception clause to R1: "Offers > A$50,000 escalated per C4 may be approved by Ken without a CHG entry, provided Ken gives explicit written approval in session."

---

### 4. Missing Pillars

#### ⚠️ Missing: Angie's network (MY/AU) — no guardrail for Angie-driven leads
- **VMS context:** Angie's network (MY/AU) is identified as a primary GTM channel alongside LinkedIn AIOps (Ken).
- **Missing:** No guardrail in the Guardrails doc defines how Aria handles Angie-introduced leads differently from cold LinkedIn leads. The T2 Training OKRs and R2 funnel integrity rules don't distinguish network-sourced vs. content-sourced leads.
- 💡 **Fix:** Extend R2 to note that Angie-network leads (MY/AU) may skip initial LinkedIn AIOps qualification but must still complete a structured discovery before L3/consulting upsell.

#### ⚠️ Missing: GCC market entry — no guardrail for 5-year vision
- **VMS context:** GCC is a 5-year target. No guardrail or OKR addresses it, which is appropriate for 6-12 months. However, Atlas A1 references "5 years (AU/MY/GCC coverage with enterprise entry)" without any guardrail for when/how GCC preparation should begin.
- 💡 **Fix:** This is not urgent for 6-12 months. Add a note to A1 that GCC readiness review is a Year 3 checkpoint, not a Year 1 task.

---

## STEP 2 — GOVERNANCE & POLICY GAP ANALYSIS

Documents reviewed:
- `docs/AI_CHARTER_v1.0.md`
- `docs/AI_GOVERNANCE_FRAMEWORK_v1.0.md`
- `docs/AI_LLM_GOVERNANCE.md`
- `RULES.md`
- `YODA_RULES.md`
- `state/frameworks-maturity.json`

Compared against: OKR + Guardrails + Governance Guardrails docs.

---

### 1. Policy Coverage

#### ✅ Covered: Data sovereignty rules vs C1-KR3 (client data on Tier 0/1 only)
- AI Charter v1.0 Section 5: "Client data never leaves the local environment. Never passed to cloud-hosted AI models without explicit written client consent and DPA."
- AI Governance Framework Section 3.2: `data_sensitivity` gate enforces Tier 0/1 for high/medium sensitivity; Ollama Cloud restricted to low-sensitivity tasks only. Warden enforces.
- **Verdict:** The principle is in place. But see Gap 1 below — P2 readiness required before C1-KR3 can be operationally satisfied.

#### ✅ Covered (partially): Warden monitoring vs W1
- AI Governance Framework Section 3.3: Warden runs 9 checks every 15 minutes. Drift → Yoda within one heartbeat. ✅ Matches W1.
- RULES.md ITIL-3 confirms health check cadence.
- **Gap on the 0.5% threshold:** X1-KR3 requires Warden to maintain < 0.5% missed intervals over 30 days. No existing governance document defines a measurement mechanism for interval compliance.

#### ✅ Covered: Governance gate (Shield→Lex→Sage) vs S2-KR2
- RULES.md: Full governance gate procedure documented and mandatory. Warden checks `state/content-queue.json` every cycle for bypass violations. ✅

#### ✅ Covered (partially): Y1-Y3 in YODA_RULES.md
- YODA_RULES.md has been updated with Y1-Y3 under "Scope & Strategy Alignment" section. ✅ These rules are live.

---

### 2. Gaps

#### ⚠️ Gap 1 (CRITICAL): P1/P2 governance framing doesn't match the new strategy timeline
- **Situation:** AI Charter Section 5 says "In P1 (internal only), formal compliance is not yet required." AI Governance Framework Section 6.4 lists P2 pre-conditions as hard gates before external client onboarding.
- **New strategy:** OKR C1-KR3 targets "minimum 2 SME clients with data sovereignty fully enforced" within 6-12 months. This IS P2. P2 pre-conditions are now on the critical path, not a future phase.
- **Open P2 pre-conditions (none resolved):**
  - TKT-0060: Client DPA — Lex to draft (no confirmation of completion)
  - TKT-0061: Warden escalation thresholds — deadline 2026-08-02 (within 6-12 month window)
  - TKT-0062: S4 tool scope per agent — deadline 2026-06-03 (imminent)
  - TKT-0063: Ollama Cloud DPA/exclusion for client workloads — Lex to assess
- **Docs:** AI Charter Section 5, AI Governance Framework Section 6.4 vs OKR C1-KR3.
- 💡 **Fix:** Treat TKT-0060, 0061, 0062, 0063 as CRITICAL PATH items for the 6-12 month OKR. Elevate status to P1→P2 transition work. Ken to prioritise at next standup.

#### ⚠️ Gap 2: Ahsoka has no governance entry in AI Charter or Governance Framework
- **Situation:** Ahsoka is the named consulting agent in the new strategy (OKR S1-S2, Guardrails C1-C4). Ahsoka is referenced in YODA_RULES.md as a routing target for `AI_Transformation_Consultant_v2.md`.
- **Missing:** AI Charter Section 6 agent table has no Ahsoka entry. AI Governance Framework Section 4.1 agent lifecycle requirements (SOUL.md, RULES.md, CHG log, model policy entry, Notion AKB) — not confirmed for Ahsoka.
- **Risk:** Ahsoka is operating (or will operate) without formal governance registration. This is a Charter violation.
- **Docs:** AI Charter v1.0 Section 6 vs YODA_RULES.md routing section.
- 💡 **Fix:** Register Ahsoka in AI Charter agent table. Confirm/create Ahsoka's model-policy.json entry, SOUL.md, and RULES.md (C1-C4 integration). Log CHG.

#### ⚠️ Gap 3: Guardrails R1-R3 not confirmed in ARIA_RULES.md
- **Situation:** Guardrails doc Section 9.2 specifies R1-R3 should be incorporated into `ARIA_RULES.md`. RULES.md has a section "Strategy & Execution Guardrails" referencing the source doc. But `ARIA_RULES.md` was not confirmed to contain R1-R3.
- **Missing:** ARIA_RULES.md verification that R1 (productised offers only), R2 (funnel integrity), R3 (training as top-of-funnel) are formally incorporated.
- **Docs:** `ainchors-guardrails-rules-2026-05.md` Section 9.2 (integration instructions) — completion unconfirmed.
- 💡 **Fix:** Verify and update ARIA_RULES.md to include R1-R3. Log CHG. Cross-reference from RULES.md and Aria SOUL.md.

#### ⚠️ Gap 4: Ahsoka C1-C4 not confirmed in AI_Transformation_Consultant_v2.md
- **Situation:** Guardrails Section 9.2 specifies C1-C4 should be appended to `AI_Transformation_Consultant_v2.md` under Behavioural Principles and Interaction Protocol. Not confirmed as done.
- **Risk:** Ahsoka operates without the Nexus-first mandate (C1), training precondition (C2), evidence-first proposals (C3), or escalation thresholds (C4).
- **Docs:** `ainchors-guardrails-rules-2026-05.md` Section 9.2 — unconfirmed execution.
- 💡 **Fix:** Read and update `AI_Transformation_Consultant_v2.md` (or equivalent Ahsoka spec file). Log CHG.

#### ⚠️ Gap 5: Warden W2 extension not in any governance document
- **Situation:** W2 requires Warden to track Tier 2/3 model use for client-identified workloads and flag Sanctum bypass attempts. RULES.md has a governance bypass check (`content-queue.json`). But no governance document mandates Warden to track whether client data is on the right model tier at task execution time.
- **Missing:** Warden's current 9-check suite (AI Governance Framework Section 3.3) checks model assignment compliance but not data classification compliance per task.
- **Docs:** `governance-guardrails-2026-05.md` W2 vs AI Governance Framework Section 3.3 (Warden checks).
- 💡 **Fix:** Add W2 as a formal Warden check (check #10) in `state/model-policy.json` and AI Governance Framework. Define what "client-identified workload" means operationally (e.g., tasks tagged with a `client_id` metadata field).

#### ⚠️ Gap 6: Sanctum SLA (G2) has no implementation in any existing policy
- **Situation:** G2 defines < 24h / < 72h turnaround targets. G1-KR2 in OKR requires measuring this. But no existing governance document (Charter, Governance Framework, RULES.md) defines how Sanctum review timestamps are logged or reported.
- **Missing:** No `state/sanctum-sla-log.json`, no monthly reporting mechanism, no Warden check for SLA compliance.
- **Docs:** `governance-guardrails-2026-05.md` G2 vs AI Governance Framework Section 4.4 (performance standards) — Sanctum turnaround not listed as a performance metric.
- 💡 **Fix:** Add SLA tracking to AI Governance Framework Section 4.4. Create `state/sanctum-sla-log.json` schema. Add monthly SLA report for Sanctum to the monthly 28th cadence. Warden to flag SLA breaches.

#### ⚠️ Gap 7: Warden interval compliance (< 0.5% missed) has no measurement mechanism
- **Situation:** OKR X1-KR3 requires Warden to maintain < 0.5% missed check intervals over 30 days. Warden runs every 15 minutes (supported by AI Governance Framework), but no document defines how interval compliance is measured or reported.
- **Docs:** OKR X1-KR3 vs AI Governance Framework Section 3.3 (drift detection, no interval tracking).
- 💡 **Fix:** Add interval tracking to Warden state file. Every check logs a timestamp; a monthly script calculates the % of missed 15-min windows. Report to Ken monthly.

---

### 3. Realignment Needed

#### 🔴 Realignment 1: Auralith is absent from all existing governance documents
- **Situation:** The new strategy makes Auralith a distinct legal and operational entity (technology/IP company, Nexus operator). All existing governance documents (AI Charter, AI Governance Framework) reference only "AInchors." Auralith has no governance coverage.
- **Risk:** If Auralith operates Nexus for SME clients, the AInchors governance framework doesn't govern Auralith's operations. This creates an accountability gap, especially for data sovereignty (whose DPA applies — AInchors or Auralith?), IP ownership, and liability.
- **Docs:** AI Charter v1.0 Section 1 ("AInchors deploys autonomous AI agents") vs VMS/OKR (Auralith owns and operates Nexus).
- 💡 **Fix:** AI Charter needs a scope extension or a companion Auralith Charter that covers Nexus operations, Auralith's data responsibilities, and how Auralith/AInchors interact from a governance perspective. This is a significant gap for P2 readiness.

#### 🔴 Realignment 2: "Obsidian" references are outdated
- **Situation:** RULES.md `/commit` procedure references "Obsidian sync" as step 3. AI Charter Section 6 references `obs.db` and `CHANGELOG.md` for logging. The new strategy documents mention Notion Holocron exclusively — Obsidian is not referenced.
- **Risk:** Agents following `/commit` will attempt Obsidian sync, potentially writing to a deprecated or non-standard location.
- **Docs:** `RULES.md` (commit section, step 3) — Obsidian reference. `frameworks-maturity.json` — knowledge management framework still references Obsidian alongside Notion.
- 💡 **Fix:** Clarify Obsidian status. If retired, remove references from RULES.md `/commit`. If retained alongside Notion, update the policy to specify what goes where.

#### ⚠️ Realignment 3: Nexus-first mandate absent from all existing policy documents
- **Situation:** The new strategy's most operationally significant rule — Nexus-first for all client implementations — appears only in the new guardrails doc. AI Charter, AI Governance Framework, LLM Governance, and RULES.md contain no mention of Nexus as a platform or the Nexus-first mandate.
- **Risk:** Without a governance-level Nexus-first rule, agents not reading the new guardrails doc could propose non-Nexus implementations without recognising it as a policy violation.
- **Docs:** `ainchors-guardrails-rules-2026-05.md` (C1, Y1) vs AI Charter, AI Governance Framework — no Nexus reference.
- 💡 **Fix:** Add the Nexus-first mandate to RULES.md as a non-negotiable global principle (alongside the existing "Strategy & Execution Guardrails" section already added). Update AI Charter Section 3 to list Nexus-first as a platform principle.

#### ⚠️ Realignment 4: New agent roster not reflected in AI Charter or Governance Framework
- **Situation:** AI Charter Section 6 lists 8 agents: Yoda, Aria, Spark, Atlas, Shield, Lex, Sage, Warden. Since then, the following have been added (per YODA_RULES.md): Ahsoka, Thrawn (Platform Arch), Lando (Business Process), Mon Mothma (Change Management). Spark is listed in the Charter but not mentioned in any new strategy documents — retirement status unclear.
- **Risk:** Agents operating without Charter registration violate AI Charter Section 6 and AI Governance Framework Section 4.1.
- **Docs:** AI Charter v1.0 Section 6 vs YODA_RULES.md (agent routing sections).
- 💡 **Fix:** Update AI Charter agent table to include all active agents. Confirm Spark's status (active or retired). Log CHG entries for each new agent registration.

---

### 4. Missing Controls

#### 🔴 Missing Control 1: Training-led 80/20 split has no enforcement mechanism
- **Situation:** The VMS and OKR define training as ~80% of business activity. R3 in the Guardrails says Aria must treat training as primary top-of-funnel. But no governance control, metric, or reporting mechanism enforces or measures the 80/20 split.
- **Risk:** Without measurement, consulting could consume disproportionate resources without detection.
- **Docs:** VMS (inline) + OKR C1 ("while staying training-led") vs all governance documents — no enforcement mechanism.
- 💡 **Fix:** Add a monthly business stream metric: ratio of consulting to training pipeline activities. Track in `state/business-roi.json` or equivalent. Alert Aria/Angie if consulting pipeline exceeds 30% of total activity time.

#### 🔴 Missing Control 2: Per-client environment isolation has no policy coverage
- **Situation:** OKR X1-KR2 requires "per-client environment isolation for at least 2 SME clients, including config separation, logging separation, and Sanctum reviews." No existing governance document defines what per-client isolation means technically or what standards it must meet.
- **Risk:** Without defined isolation standards, client data from Client A could leak into Client B's context, logs, or Warden monitoring.
- **Docs:** OKR X1-KR2 vs AI Charter, AI Governance Framework — no client isolation policy.
- 💡 **Fix:** Define a "Client Isolation Policy" as a P2 pre-condition alongside TKT-0060/0061/0062/0063. Minimum requirements: separate config namespaces, separate logging paths, separate Sanctum review contexts, separate Warden monitoring per client.

#### ⚠️ Missing Control 3: Level 3 training (Nexus-centric) has no governance trigger
- **Situation:** T2-KR1 and KR3 require defining and piloting a Level 3 "Nexus Implementation for SMEs" intensive. This training will involve actual Nexus implementation for real SMEs. But no governance document defines when the governance gate applies to training deliverables vs. consulting deliverables.
- **Risk:** L3 training could involve deploying Nexus to a client environment without triggering the same governance controls as a formal consulting engagement.
- **Docs:** OKR T2-KR1/KR3 vs RULES.md Governance Gate (which covers "client content, proposals, training materials, social posts").
- 💡 **Fix:** Explicitly classify L3 Nexus training engagements as requiring the same governance gate as consulting proposals (Shield→Lex→Sage mandatory before any client Nexus deployment, even in a training context).

---

## SUMMARY SCORECARD

### Step 1 — Coherence
| Category | Count |
|---|---|
| ✅ Aligned | 6 |
| ⚠️ Gaps | 6 |
| 🔴 Conflicts | 2 |

**Top issues:**
- Conflict between Atlas A1 (managed tenants at 3yr) vs VMS (managed tenants at 3-5yr) — risks over-investing in platform vs delivery
- Conflict between R1 (productised offers only) and C4 (large deal escalation to Aria) — creates decision deadlock
- Gap: No NPS/quality tracking rule despite OKR T1-KR2 measuring it

### Step 2 — Governance Gaps
| Category | Count |
|---|---|
| ✅ Covered | 3 |
| ⚠️ Gaps | 7 |
| 🔴 Realignment needed | 4 |
| 🔴 Missing controls | 3 |

**Top issues:**
1. **CRITICAL:** P2 governance pre-conditions (TKT-0060/0061/0062/0063) are now on the critical path for the 6-12 month OKR. Need immediate elevation.
2. **HIGH:** Auralith is absent from all existing governance documents — no coverage for the technology entity that operates Nexus.
3. **HIGH:** Ahsoka has no formal governance registration (Charter, Governance Framework, model-policy.json).
4. **HIGH:** Nexus-first mandate not in RULES.md, AI Charter, or AI Governance Framework — governance gap for the strategy's core delivery rule.
5. **MEDIUM:** Obsidian references in RULES.md are outdated vs Notion Holocron strategy.

---

## RECOMMENDED NEXT ACTIONS (priority order)

1. **Elevate P2 pre-conditions to critical path** — TKT-0060 (DPA), TKT-0061 (Warden thresholds), TKT-0062 (tool scope), TKT-0063 (Ollama DPA). These must resolve before first SME client onboarding (target: 6-12 months).
2. **Register Ahsoka in AI Charter + governance lifecycle** — SOUL.md, RULES.md with C1-C4, model-policy.json entry, CHG log.
3. **Add Auralith to AI Charter scope** — extend Charter or create Auralith companion governance doc.
4. **Add Nexus-first mandate to RULES.md and AI Charter** — make it a formal policy, not just a guardrails-level rule.
5. **Verify ARIA_RULES.md integration of R1-R3** — confirm and update if incomplete.
6. **Resolve Obsidian vs Notion ambiguity** — update RULES.md `/commit` procedure.
7. **Add Sanctum SLA logging mechanism** — `state/sanctum-sla-log.json`, monthly reporting, Warden check.
8. **Define per-client environment isolation policy** — critical before first SME deployment.

---

_Produced by Yoda 🟢 | TKT-0086 Steps 1+2 | 2026-05-07 13:27 AEST_
