# AInchors Governance Hierarchy — Gap Analysis & Policy Creation Proposal

**Status:** DRAFT FOR REVIEW — Pending Ken Mun approval
**Author:** Atlas 🏛️ — Enterprise Architect, AInchors / Aevlith Technologies
**Ticket:** TKT-0137 AC1
**Date:** 2026-05-12
**Version:** v1.0
**Parent documents:** AI_CHARTER_v1.0.md · AI_GOVERNANCE_FRAMEWORK_v1.0.md · Agent_Governance_Framework_v1.md · Nexus_Enterprise_Landscape_P2P4.md · DataMemory_P1P4_Roadmap.md · Nexus-Access-Policy-v1.0.md · File-Routing-Policy-v1.0.md · RULES.md · nexus-client-isolation-policy-v1.md

---

## Executive Summary

- **24 governance gaps identified** across all five governance layers, spanning missing policies, unapproved drafts, and structural misalignments between the EA roadmap and current governance artefacts.
- **Layer 3 (Policies) is the most critical gap.** Of the 10 planned policies (POL-001 to POL-010), zero are written and approved. Two exist as DRAFT FOR REVIEW (Nexus Access Policy, Nexus Client Isolation Policy). One is approved (File-Routing-Policy-v1.0.md). The rest do not exist.
- **10 gaps are P2 hard gates.** The EA roadmap (Nexus_Enterprise_Landscape_P2P4.md, DataMemory_P1P4_Roadmap.md) creates governance obligations that are not yet met. P2 client onboarding cannot proceed without resolving at least 10 of these gaps.
- **Risk if not addressed:** P2 client onboarding without these policies in place creates regulatory exposure (APP/Privacy Act), architectural drift (agents operating without enforceable constraints), audit failure, and contractual risk when KL onboarding begins.
- **12 new policies are proposed** (POL-001 to POL-012), sequenced by P2 gate → KL onboarding → audit readiness → ongoing hygiene.

---

## 1. Governance Hierarchy — Current State

Map of what exists today against the 5-layer model.

| Layer | Name | What Should Exist | What Exists Today | Status |
|-------|------|-------------------|-------------------|--------|
| **1 — Principles** | AI Charter | Foundational AI ethics and agent permission charter | AI_CHARTER_v1.0.md + Aevlith Technologies Addendum | ✅ APPROVED (2026-05-07) |
| **2 — Framework** | AI Governance Framework | Operational governance machinery: model governance, agent lifecycle, risk register, audit | AI_GOVERNANCE_FRAMEWORK_v1.0.md | ✅ APPROVED (2026-05-04) |
| **2 — Framework** | Agent Governance Framework | Governance tiers per agent, operating model per agent, operationalisation checklist | Agent_Governance_Framework_v1.md | ✅ APPROVED (2026-05-08) |
| **3 — Policies** | Data Classification Policy | Formal data classification scheme (PUBLIC/INTERNAL/CONFIDENTIAL/RESTRICTED) | **Not written** | ❌ MISSING |
| **3 — Policies** | Data Retention Policy | Formal retention schedules per data category and phase | **Not written** | ❌ MISSING |
| **3 — Policies** | Model Governance Policy | Standalone enforceable policy for model approval, routing, retirement | **Embedded in Framework only** | ⚠️ EMBEDDED |
| **3 — Policies** | Agent Lifecycle Policy | Formal policy for agent creation, change, and retirement | **Embedded in Framework only** | ⚠️ EMBEDDED |
| **3 — Policies** | Incident Response Policy | Formal policy with severity classification, SLAs, PIR obligations | **Embedded in RULES.md only** | ⚠️ EMBEDDED |
| **3 — Policies** | Privacy / APP Compliance Policy | APP gap analysis + formal PII handling policy | **Not written** | ❌ MISSING |
| **3 — Policies** | Sanctum Invocation Policy | When to invoke Shield/Lex/Sage, triad disagreement resolution | **Not written — informal only** | ❌ MISSING |
| **3 — Policies** | Content Governance Policy | Formal policy for all external-facing content gate | **Embedded in RULES.md only** | ⚠️ EMBEDDED |
| **3 — Policies** | Third-Party AI Provider Policy | DPA requirements, provider change process, Ollama Cloud decision | **Embedded in Framework only** | ⚠️ EMBEDDED |
| **3 — Policies** | Warden Escalation Thresholds Policy | Formal breach thresholds, alert criteria, suppression rules | **Not written (TKT-0061)** | ❌ MISSING |
| **3 — Policies** | Tier 3 Delegation Model | Who can approve Tier 3 actions on Ken's behalf from P2 | **Not written** | ❌ MISSING |
| **3 — Policies** | Nexus Access Policy | Data tier rules, agent access matrix, storage patterns | Nexus-Access-Policy-v1.0.md | ⚠️ DRAFT FOR REVIEW |
| **3 — Policies** | Nexus Client Isolation Policy | Per-client isolation requirements for P2 onboarding | nexus-client-isolation-policy-v1.md | ⚠️ DRAFT FOR REVIEW |
| **3 — Policies** | Client DPA Template | Standard Data Processing Agreement for P2 clients | **Not written (TKT-0060)** | ❌ MISSING |
| **3 — Policies** | File Routing Policy | SSOT routing rules for all file types across all storage layers | File-Routing-Policy-v1.0.md | ✅ APPROVED (2026-05-12) |
| **4 — Standards** | RULES.md (Yoda) | Operational rules and standards for Yoda | RULES.md | ✅ Operational |
| **4 — Standards** | Agent RULES.md files | Per-agent operational standards | ATLAS_RULES, LEX_RULES, SHIELD_RULE_1, SAGE_RULES, LANDO_RULES, DTCM_RULES | ✅ Partial (not all agents have full RULES) |
| **4 — Standards** | S4 Tool Scope (per-agent) | Formal per-agent tool permission matrix | **Not written (TKT-0062)** | ❌ MISSING |
| **4 — Standards** | Specialist Agent Routing Standard | Formal Yoda routing rules for Atlas, Thrawn, Lando, Mon Mothma | **Not written — informal only** | ❌ MISSING |
| **5 — SOPs/Runbooks** | Incident response SOP | Runbook for incident detection, containment, PIR | Scripts exist (incident-log.sh) but no formal runbook | ⚠️ PARTIAL |
| **5 — SOPs/Runbooks** | P2 client onboarding SOP | Step-by-step client onboarding procedure | **Not written** | ❌ MISSING |
| **5 — SOPs/Runbooks** | Aevlith incorporation gate SOP | Verification procedure before client data onboarded | **Not written** | ❌ MISSING |
| **5 — SOPs/Runbooks** | Warden runbook | Formal breach response procedure for Warden escalations | **Not written** | ❌ MISSING |

**Summary:** 3 approved policies, 2 draft policies, 8 embedded-only, 11 entirely missing across Layers 3–5.

---

## 2. EA Roadmap — Governance Requirements

Each approved EA document creates governance obligations. Mapped below.

### 2.1 Nexus_Enterprise_Landscape_P2P4.md (LIVE — 2026-05-12)

| EA Requirement | Governance Obligation Created | Gap |
|----------------|------------------------------|-----|
| Multi-tenant RLS from day one (Decision A confirmed) | Data classification and access control policy must define how tenant_id is managed, who can access cross-tenant audit data, and what constitutes a cross-tenant violation | GAP-001, GAP-011 |
| Block Claude for all P2 client workloads (Decision H confirmed) | Model routing policy must formally document this constraint so agents cannot override it | GAP-007 (model governance policy) |
| BYOK clients bring their own DPA | Third-party provider policy must define BYOK DPA obligations, what AInchors retains vs transfers | GAP-009 |
| Warden: AInchors-managed at P2, per-tenant at P4 (Decision F) | Warden escalation threshold policy required to define what constitutes a breach per tenant, how cross-tenant incidents are handled | GAP-005 |
| P3 ROI checklist required before P3 tier enabled (Decision G) | Policy or standard required for P3 tier unlock criteria, Ken approval authority | GAP (new — no existing TKT) |
| Sanctum gate mandatory for external sends and client deliverables | Formal Sanctum Invocation Policy required — when all three vs single, disagreement resolution | GAP-015 |
| P2 evidence pack must be complete before external auditability | APP gap analysis (item 8), DPA (item 7), Warden reports (item 4), SLA history (item 5) all outstanding | GAP-006, GAP-007 (DPA), GAP-005 |
| APRA CPG 234/235 at P4: immutable audit log, WORM, formal change control | Data retention policy, incident response policy, change management policy must be formalised before P4 | GAP-003, GAP-004 |
| Per-client Telegram bot, separate allowFrom | Client isolation policy must be approved and enforced | GAP-010 |
| Gemma4 local for all client-facing P2 workloads | Data residency register must formally document Anthropic DPA status and Claude routing exclusion | GAP-014 |

### 2.2 DataMemory_P1P4_Roadmap.md (LIVE — 2026-05-12)

| EA Requirement | Governance Obligation Created | Gap |
|----------------|------------------------------|-----|
| Data classification tagging mandatory on all records from P2 (CPG 234) | Standalone data classification policy required — definitions, enforcement mechanism, tagging obligation | GAP-001 |
| PII scanner on all document ingestion before chunking/embedding (Action 5) | PII handling must be enshrined in a policy, not just embedded in RULES.md | GAP-006 (Privacy/APP) |
| Retention schedules: live 12 months, offline 7 years for audit log; per-category per phase | Formal retention policy required | GAP-004 |
| Data residency register required — for each model/API, document where data flows | Formal register document required | GAP-014 |
| tenant_id on all Postgres tables from P1 — designed for P2 | Access policy must define who can query across tenant_id values and when | GAP-001, GAP-011 |
| Session state must not persist beyond session end without explicit promotion | Session lifecycle policy required — not documented anywhere | GAP-001 (data classification covers this partially) |
| Optimistic locking in P1, event sourcing at P4 — schema designed for migration | Change management policy must cover schema changes (CPG 235 Clause 27) | GAP-003 |
| APRA CPG 234: data classification on all stored data | Formal classification policy with enforcement | GAP-001 |
| APRA CPG 235: data quality gate, source verification, retention | Data retention policy and data quality standard required | GAP-004 |
| APP 11 — Security safeguards for personal information | Privacy/APP Policy required | GAP-006 |
| Deletion mechanism at P4: cryptographic erasure + deletion certificate | Formal data retention and deletion policy with audit trail requirement | GAP-004 |

### 2.3 Nexus-Access-Policy-v1.0.md (DRAFT FOR REVIEW — Pending Ken)

| EA Requirement | Governance Obligation Created | Gap |
|----------------|------------------------------|-----|
| 15 named access patterns (PATTERN-01 through PATTERN-15) | These patterns require formal approval before agents are bound by them | GAP-011 |
| Violation definitions (V0–V3) and escalation SLAs | state/access-violations.json must exist; obs-collector CHECK required | GAP-011, GAP-022 |
| Quarterly compliance review by Atlas | This review obligation must be backed by a Policy, not just embedded in an unapproved document | GAP-011 |
| Agent access matrix (Table in Section 5) | Formalises cross-agent access constraints — requires Ken approval to be enforceable | GAP-011 |
| Human access matrix (Table in Section 6) | Angie and KL team access rules require approval before onboarding | GAP-011 |
| OD-01: access-violations.json does not exist | Forge must create it; obs-collector CHECK required | GAP-022 |
| OD-05: Violations should also log to Notion DB | Governance completeness requires Notion audit trail for V0/V1 violations | GAP-022 |

### 2.4 File-Routing-Policy-v1.0.md (LIVE — 2026-05-12)

| EA Requirement | Governance Obligation Created | Gap |
|----------------|------------------------------|-----|
| Drive ↔ Local sync obligation mandatory | Agents must have sync obligation in RULES.md — currently informal | Partial compliance: embedded in RULES.md |
| Open items: Drive folder audit, MinIO bucket audit, backfill of canvas/marketing files | These must be tracked as sprint items with TKTs | Execution gap, not governance gap |
| drive-sync-failures.json monitoring | obs-collector CHECK required per Observability Architecture Rule | Minor gap: CHECK may not exist |

---

## 3. Gap Analysis — Missing or Misaligned

### Gap Register

| GAP-ID | Layer | Description | Risk | Blocked Items |
|--------|-------|-------------|------|---------------|
| **GAP-001** | 3 — Policy | **Data Classification Policy missing.** No formal, standalone policy defining the four tiers (PUBLIC/INTERNAL/CONFIDENTIAL/RESTRICTED), what data falls in each, enforcement mechanism, or tagging obligation. Referenced by Charter, DataMemory roadmap (CPG 234), and Nexus-Access-Policy — but the parent policy that makes it enforceable doesn't exist. | **HIGH** | P2 client onboarding, CPG 234 compliance, tenant_id classification regime |
| **GAP-002** | 3 — Policy | **Agent Lifecycle Policy not formalised.** Agent creation, change, and retirement rules exist in Agent_Governance_Framework_v1.md (Sections 4, 5, 6) but are embedded in a Framework, not a standalone Policy. Cannot be independently referenced, audited, or versioned as required. | **MEDIUM** | Agent audit readiness, KL team agent builds |
| **GAP-003** | 3 — Policy | **Incident Response Policy not formalised.** RULES.md Section ITIL-1 describes incident management and scripts/incident-log.sh implements logging. But there is no formal policy document with severity classification (P1–P4 incident tiers), SLA obligations (acknowledge, resolve, PIR), escalation contacts, or cross-agent incident coordination. | **HIGH** | P2 client SLA commitments, APRA CPG 234 incident response obligations |
| **GAP-004** | 3 — Policy | **Data Retention Policy missing.** Charter Section 5 documents some retention rules (live 12 months, offline 7 years for audit log). DataMemory roadmap Section 4.4 has detailed retention matrices. But no standalone policy exists — these are scattered references with no single enforceable document. | **HIGH** | APRA CPG 235 retention compliance, Privacy Act APP obligations at P2, client DPA |
| **GAP-005** | 3 — Policy | **Warden Escalation Thresholds Policy missing (TKT-0061).** Charter Section 6 and Governance Framework Section 3.3 both flag this as a mandatory P2 pre-condition. Deadline confirmed 2026-08-02. Formal document defining exact escalation criteria, sensitivity levels, suppression rules, and breach definition has not been produced. Warden operates without formal thresholds. | **HIGH** | P2 go-live gate, external auditability (P2 evidence pack item), Warden's ability to escalate with legal certainty |
| **GAP-006** | 3 — Policy | **Privacy/APP Policy missing (TKT-0060 partially, Charter §5).** Charter Section 5 mandates Lex complete a formal APP gap analysis before P2. Aevlith Addendum flags controller/processor split as critical for DPA. Neither the APP gap analysis nor a formal PII handling policy has been produced. PII scanner is designed (Action 5) but not backed by an enforceable policy. | **HIGH** | P2 client onboarding (hard gate), Privacy Act compliance, Lex DPA drafting (TKT-0060) |
| **GAP-007** | 3 — Policy | **Client DPA Template missing (TKT-0060).** Charter Section 5 and Aevlith Addendum explicitly require a standard DPA drafted by Lex and approved by Ken before any client onboarding. Document must name Aevlith Technologies as data processor, define Tier 0/1 controls, include BYOK exception handling. Not written. | **HIGH** | P2 client onboarding hard gate — no client may sign without this |
| **GAP-008** | 4 — Standard | **S4 Tool Scope (per-agent permissions) not defined (TKT-0062).** Governance Framework Section 6.4 and Agent Governance Framework note all agents currently operate with `tools: null` (broad access). Shield to draft per-agent tool scope for Ken review. Deadline confirmed 2026-06-03. This is a known security gap (Risk 9 — Over-automation). | **HIGH** | Security posture at P2, prevents least-privilege enforcement per Charter Principle 6 |
| **GAP-009** | 3 — Policy | **Third-Party AI Provider Policy / Ollama Cloud DPA decision missing (TKT-0063).** Before P2: one of three options must be resolved for Ollama Cloud (formal DPA, explicit exclusion/acceptance, or BYOK). Governance Framework Section 7.1 documents this but no decision has been made and no policy document produced. Also: provider change process exists in Framework but is not a standalone enforceable policy. | **MEDIUM** | P2 go-live gate (Ollama Cloud DPA), third-party provider audit readiness |
| **GAP-010** | 3 — Policy | **Nexus Client Isolation Policy is DRAFT FOR REVIEW.** nexus-client-isolation-policy-v1.md defines minimum isolation requirements for P2 client environments (config isolation, data isolation, communication isolation, governance isolation, infrastructure isolation). Not yet approved — cannot be enforced until Ken signs off. | **HIGH** | P2 client onboarding — cannot onboard any SME client without this |
| **GAP-011** | 3 — Policy | **Nexus Access Policy is DRAFT FOR REVIEW.** Nexus-Access-Policy-v1.0.md defines data tiers, agent access matrix, human access matrix, 15 access patterns, violation definitions, and escalation SLAs. Not yet approved. Five open decisions (OD-01 to OD-05) require Ken input. Cannot be enforced, and access-violations.json does not yet exist. | **HIGH** | Compliance with Charter Principle 6 (least privilege), P2 client isolation, agent access audit readiness |
| **GAP-012** | 3 — Policy | **Tier 3 Delegation Model missing.** Charter Section 4 and Governance Framework Section 6.4 both flag this as a mandatory P2 pre-condition. Currently Ken is sole approver for all Tier 3 actions. Before P2 live, a model must be defined specifying what actions can be delegated, to whom, under what conditions, and whether Aevlith Technologies decisions can be separately delegated from AInchors commercial decisions. | **HIGH** | P2 go-live gate, scalability of approval authority, Aevlith Addendum Section 4 |
| **GAP-013** | 3 — Policy | **P2 Audit Committee roles are TBC (placeholder only).** Governance Framework Section 6.3 defines the audit committee structure but Technical Review and Legal/Compliance Review roles have no nominees — only "TBC — confirm before P2 live." This is a mandatory P2 pre-condition. An unfilled committee seat means governance reviews cannot proceed independently. | **MEDIUM** | P2 go-live gate, audit committee structure for external auditability |
| **GAP-014** | 3 — Policy | **Data Residency Register missing.** DataMemory roadmap Section 5 (Decision 5) requires a formal Data Residency Register documenting, for each model and API endpoint: where data is processed, vendor DPA status, and which data categories can flow to that endpoint. Anthropic DPA verification (TKT-0104 Action 2) feeds into this — Action 2 marked "urgent" but register not produced. | **HIGH** | Privacy Act APP compliance, CPG 235 data residency attestation for P4, Claude routing decision for P2 clients |
| **GAP-015** | 3 — Policy | **Sanctum Invocation Policy missing.** Agent Governance Framework Section 6 (CHG-P1) flags this as high priority. No formal rule in Yoda's RULES.md or as a standalone policy defines: when each triad member is invoked, what triggers all-three vs single-member review, how invocations are logged, what happens when members disagree (any BLOCK = fleet-level BLOCK), or the invocation criteria per content type. Triad operates on institutional knowledge today. | **HIGH** | Governance gate reliability at P2, triad audit trail, client-facing content review integrity |
| **GAP-016** | 3 — Policy | **Content Governance Policy embedded only — not a standalone document.** Content gate is defined in RULES.md (Governance Layer section, Content Governance Gate section) and references scripts/content-governance-review.sh. Embedded rules are operational but cannot be independently audited, versioned, or referenced from a client DPA without a standalone policy document. | **LOW** | Audit readiness, DPA reference, client-facing governance credibility |
| **GAP-017** | 3 — Policy | **Model Governance Policy embedded only — not standalone.** Model governance is defined in AI_GOVERNANCE_FRAMEWORK_v1.0.md Section 3 (model approval process, CI framework, drift detection, retirement) and state/model-policy.json. No standalone policy document exists that can be referenced by Warden, Shield, or external audit without pulling the entire Framework. | **LOW** | External auditability, Warden reference base, P4 regulated client requirements |
| **GAP-018** | 5 — SOP | **Aevlith Technologies incorporation gate has no formal verification procedure.** Charter (Ken 2026-05-07) establishes a hard gate: no SME client data on Nexus until Aevlith Technologies is legally incorporated. Target end May 2026. No formal verification procedure, sign-off checklist, or notification mechanism exists — no agent knows how to confirm incorporation is complete without asking Ken directly. | **HIGH** | P2 client onboarding hard gate, legal entity prerequisite |
| **GAP-019** | 3 — Policy | **P2 Governance Evidence Pack incomplete.** Governance Framework Section 6.5 lists 9 documents for P2 external auditability. Items 7 (DPA) and 8 (APP gap analysis) are not produced. Items 4 (Warden reports — 90 days) and 5 (SLA history — 3 months) need time to accumulate. Without all 9 items, P2 cannot claim external auditability. | **HIGH** | P2 external auditability, potential regulated client requirements |
| **GAP-020** | 4 — Standard | **Specialist agent routing rules missing from Yoda's RULES.md.** Agent Governance Framework Section 6 (CHG-P2): Atlas, Thrawn, Lando, Mon Mothma have no formal routing rules in Yoda's operational RULES.md. No invocation criteria, no output approval workflow, no handoff protocols, no SLA for Ken review of DRAFT outputs. Agents are available but engagement model is informal. | **MEDIUM** | Consistent specialist agent outputs, Mon Mothma sequence enforcement, Atlas/Thrawn boundary clarity |
| **GAP-021** | 3 — Policy | **Cross-stream governance (Yoda/Aria coordination) lacks formal rules.** How Yoda and Aria coordinate on cross-stream decisions is defined informally in SOUL.md files and MEMORY.md. No formal policy or standard governs: what outputs require both-stream sign-off, what happens when they disagree, how Ken is notified of cross-stream conflicts, or what information can flow between streams without Ken review. | **MEDIUM** | Dual-stream operational integrity, Aria Rule 3 (CR Gate) is a rule but not a policy |
| **GAP-022** | 5 — SOP | **Violation handling procedure incomplete.** Nexus-Access-Policy-v1.0.md (DRAFT) defines violations and escalation paths but is not approved. state/access-violations.json does not yet exist. No obs-collector CHECK exists for it. Violation detection is therefore not automated. RULES.md references violations in multiple places without a unified enforceable procedure. | **MEDIUM** | Policy enforcement, automated violation detection, ITIL-4 (observability) compliance |
| **GAP-023** | 5 — SOP | **Krennic SRE pre-build preparation missing.** Agent Governance Framework Section 6 (CHG-P7): build trigger defined but no runbook templates, SLO/error budget definitions, or workspace structure prepared. When build trigger fires, Yoda must build Krennic reactively with no pre-prepared framework. | **LOW** | P3/P4 operational resilience, reduces Krennic build time when trigger fires |
| **GAP-024** | 3 — Policy | **Client-facing Privacy Policy (external document) missing.** Distinct from internal APP gap analysis. A client-facing privacy statement or policy is required for P2 — referenced by the DPA, potentially required on The Citadel at P2 launch. Aevlith Addendum flags this but no document has been produced. | **MEDIUM** | P2 client onboarding, Citadel launch, Privacy Act APP obligations |

---

## 4. Policy Creation Proposals

Sequenced by: P2 gate → KL onboarding → audit readiness → ongoing.

| Policy ID | Policy Name | Derived From | Scope | Owner | Priority | Producer | Est. Effort |
|-----------|-------------|--------------|-------|-------|----------|----------|-------------|
| **POL-001** | Data Classification Policy | Charter Principle 4 (Data Sovereignty), DataMemory roadmap §2, CPG 234 | Defines four classification tiers (PUBLIC/INTERNAL/CONFIDENTIAL/RESTRICTED), what data falls in each, storage constraints per tier, tagging obligation for all new files and records, enforcement mechanism. | Ken / Yoda | **P0 — Before P2 launch (critical path)** | Lex drafts (compliance framing), Atlas structures (tier definitions, enforcement), Ken approves | 3 hrs |
| **POL-002** | Data Retention Policy | Charter §5 (retention rules), DataMemory roadmap §4.4, CPG 235, Privacy Act APP 11 | Formal retention schedule per data category (episodic audit log, session state, knowledge chunks, shared agent state, backups, client data). Per-phase enforcement (P1/P2/P4). Deletion mechanisms and deletion certificate requirements. | Ken / Lex | **P0 — Before P2 launch** | Lex drafts, Atlas reviews for data architecture alignment, Ken approves | 4 hrs |
| **POL-003** | Privacy & APP Compliance Policy | Charter §5 (APP alignment), Aevlith Addendum §2, Privacy Act 1988 (Cth) | Formal APP gap analysis + PII handling policy: what constitutes PII, PII scanning obligations before ingestion, model routing for PII (Gemma4 local only), data subject rights (access, correction, deletion), APP 11 security safeguards, controller/processor split for Aevlith Technologies. | Ken / Lex | **P0 — Before P2 launch (hard gate per Charter §5)** | Lex drafts (APP compliance), Ken approves | 6 hrs |
| **POL-004** | Client Data Processing Agreement (DPA) Template | Charter §5 (TKT-0060), Aevlith Addendum §2, Privacy Act | Standard DPA for P2 SME clients: names Aevlith Technologies as data processor, defines Tier 0/1 controls, BYOK exception clause, data sovereignty obligations, retention and deletion schedule, controller/processor split, onboarding gate reference. | Ken / Lex | **P0 — Before P2 launch (hard gate per Charter §5)** | Lex drafts, Ken signs, Ken approves | 5 hrs |
| **POL-005** | Warden Escalation Thresholds Policy | Charter §6 (TKT-0061), Governance Framework §3.3, deadline 2026-08-02 | Defines exact escalation criteria for each Warden check, sensitivity levels per agent and model tier, breach definition, alert suppression rules, notification path (Warden → Yoda → Ken), response SLAs per breach type, and client tenant isolation breach handling at P2. | Ken / Warden | **P0 — Before P2 launch (hard gate per Charter §6, Governance Framework §6.4)** | Thrawn drafts (technical monitoring requirements), Lex reviews (compliance framing), Ken approves | 4 hrs |
| **POL-006** | Tier 3 Delegation Model | Charter §4 (delegation model, mandatory before P2), Governance Framework §6.4 | Defines what Tier 3 actions can be delegated, to whom (if anyone in P1), under what conditions, whether Aevlith Technologies platform decisions can be separately delegated from AInchors commercial decisions, and how delegated approvals are logged. | Ken | **P0 — Before P2 launch (hard gate per Charter §4)** | Ken defines (authority decision), Lex frames (legal structure), Atlas documents | 2 hrs |
| **POL-007** | Nexus Client Isolation Policy (Approve Existing) | AI Charter §2.4, Governance Framework §6.4, OKR X1-KR2 | Already drafted as nexus-client-isolation-policy-v1.md. Requires Ken approval to become enforceable. No new writing required — approve as-is or with minor amendments. | Ken | **P0 — Before P2 launch** | Atlas/Yoda prepared. Ken approves. | 1 hr (review + approval) |
| **POL-008** | Nexus Access Policy (Approve Existing + ODs) | Charter Principle 6 (Least Privilege), File-Routing-Policy v1.0, EA-Addendum-Storage-Access-Architecture-v0.1.md | Already drafted as Nexus-Access-Policy-v1.0.md. Five open decisions (OD-01 to OD-05) require Ken input. OD-01 (obs-collector CHECK for violations) is a Forge sprint item post-approval. Approve and trigger enforcement. | Ken | **P0 — Before P2 launch** | Atlas/Yoda prepared. Ken decides OD-01 to OD-05, then approves. | 2 hrs (OD decisions + approval) |
| **POL-009** | Sanctum Invocation Policy | Agent Governance Framework §6 (CHG-P1), Governance Framework §4 (pre-action triad), RULES.md (Governance Layer) | Defines: invocation trigger matrix (action type → which triad members), criteria for all-three vs single-member review, logging requirement per invocation, conflict resolution (any BLOCK from any member = implicit fleet-level BLOCK until Yoda resolves), invocation SLA (turnaround time per content type). | Ken / Yoda | **P1 — Before KL onboarding** | Yoda drafts (operational invocation rules), Shield/Lex/Sage review, Ken approves | 3 hrs |
| **POL-010** | Incident Response Policy | Charter §6 (incident response), RULES.md ITIL-1, Agent Governance Framework §4.x (failure surfacing) | Formalises: incident severity tiers (P1 critical → P4 informational), SLAs per tier (acknowledge, contain, resolve, PIR), escalation contacts and path, cross-agent incident coordination, client incident notification obligations at P2, APRA CPG 234 alignment for P4. Replaces embedded RULES.md ITIL-1 with an auditable policy. | Ken / Yoda | **P1 — Before KL onboarding** | Yoda drafts (operational procedures), Lex reviews (regulatory obligations), Ken approves | 3 hrs |
| **POL-011** | Third-Party AI Provider Policy | Governance Framework §7 (TKT-0063), Charter §4 (provider change process), DataMemory roadmap §4.5 (data residency) | Formalises: provider approval process (PoC, DPA, Ken approval), Ollama Cloud decision (DPA or explicit exclusion or BYOK), Data Residency Register (formal document per Decision 5), Claude data routing for P2 clients (Block-Client confirmed), provider change governance, annual provider review obligation. | Ken / Lex | **P1 — Before first audit** | Lex drafts (DPA framing, provider requirements), Atlas reviews (residency register), Ken approves | 4 hrs |
| **POL-012** | Client-Facing Privacy Statement | Privacy Act 1988 (Cth), Aevlith Addendum, POL-003 (internal APP policy) | External client-facing privacy statement for The Citadel at P2: what personal data is collected, how it is used, where it is stored, client rights under APP, AInchors and Aevlith Technologies contact details, complaint mechanism. Referenced by client DPA (POL-004). | Ken / Lex | **P1 — Before Citadel launch** | Lex drafts, Ken approves | 2 hrs |

---

## 5. Alignment Issues

Misalignments between existing documents — not gaps, but contradictions or inconsistencies that need resolution.

### A5.1 — Aria Governance Classification Mismatch
**Documents:** Yoda's RULES.md / prior Yoda governance model vs Agent_Governance_Framework_v1.md  
**Issue:** Agent Governance Framework Section 6 (CHG-P3) identifies that Yoda's prior classification of Aria as "Yoda-govern" is wrong. Aria's actual model is Dual-Principal (Model 1), with Angie as primary authority. This misclassification could lead to Yoda overriding Angie's business-stream decisions.  
**Status:** CHG-P3 raised in Agent Governance Framework. Remediation: update MEMORY.md and AI_GOVERNANCE_FRAMEWORK_v1.0.md. Confirm with Ken before acting.  
**Risk:** Medium — if Yoda routes a business-stream decision around Angie, it violates the Dual-Principal model.

### A5.2 — Warden Monitoring Scope Inconsistency
**Documents:** AI_GOVERNANCE_FRAMEWORK_v1.0.md §3.3 vs Agent_Governance_Framework_v1.md §4.7  
**Issue:** Agent Governance Framework notes MEMORY.md has inconsistent count of agents Warden monitors (6 in one place, 9 in another). Specialist agents (Atlas, Thrawn, Lando, Mon Mothma, Spark) are not enrolled in model-policy.json — Warden does not detect model drift for these agents. No explicit decision documents why they are excluded.  
**Status:** Agent Governance Framework Section 6 (CHG-P4) raised this. Explicit policy decision needed: exclude permanently (with rationale) or enrol.  
**Risk:** Medium — model drift in specialist agents is undetected. Low immediate risk (low cron frequency), higher risk when specialist agents run more regularly at P2.

### A5.3 — S4 Tool Scope Gap vs Charter Principle 6
**Documents:** Charter Principle 6 (Least Privilege), Governance Framework §6.4, RULES.md  
**Issue:** Charter Principle 6 mandates least-privilege tool scope per agent. All agents currently operate with `tools: null` (broad access). This is an explicit acknowledged gap (Risk 9 in Governance Framework, TKT-0062). The gap is known but the deadline (2026-06-03) has not been actioned with a formal deliverable.  
**Status:** TKT-0062 open. Shield to draft per-agent tool scope. Not yet produced.  
**Risk:** High — until resolved, any agent could access any tool. This is a security architecture gap.

### A5.4 — Data Residency Rule for Anthropic DPA vs Deployment Reality
**Documents:** DataMemory_P1P4_Roadmap.md Decision 5 (urgent action), Nexus_Enterprise_Landscape_P2P4.md Decision H  
**Issue:** DataMemory roadmap marks Anthropic DPA verification as "urgent" (TKT-0104 Action 2). Decision H in Nexus_Enterprise_Landscape_P2P4.md notes the DPA was "already completed — missed in this doc — update required." These two documents are contradictory: one says urgent/not done, the other says done but undocumented.  
**Status:** The Data Residency Register (GAP-014) would resolve this by formally documenting the verified status. Until the register exists, agents have no authoritative reference.  
**Risk:** Medium — agents cannot confirm data routing compliance without the register.

### A5.5 — Content Governance Invocation: Yoda vs Aria Asymmetry
**Documents:** RULES.md (Governance Gate section), Agent_Governance_Framework_v1.md §4.2 (Aria), RULES.md (Governance Gate — When to Skip)  
**Issue:** RULES.md defines a different invocation model for Yoda (never ask Ken, just run it) vs Aria (always ask Angie, let her decide). This asymmetry is documented but not formalised in a policy. If a Sanctum invocation policy (GAP-015 / POL-009) is created, this asymmetry must be preserved and formally specified.  
**Risk:** Low — currently handled by agent instructions. Risk increases when KL team agents are onboarded.

### A5.6 — Aevlith Technologies Addendum Status
**Documents:** AI_CHARTER_v1.0.md (Aevlith Technologies Addendum)  
**Issue:** The Aevlith Technologies Addendum is listed as "APPROVED — Ken Mun, CTO, 2026-05-07" in the main body but the addendum's own governance table shows "Status: DRAFT — For Ken Mun Review and Approval" and "Status: APPROVED" in the approval block. Document metadata is internally inconsistent.  
**Risk:** Low — functional approval is clear. Document metadata should be corrected in next revision.

---

## 6. Recommended Roadmap

### Phase 1 — Before P2 Launch (Critical Path, by P2 go-live 2026-08-31)

All items in this phase are hard gates per Charter §4, §5, §6 and Governance Framework §6.4.

| # | Item | Owner | Effort |
|---|------|-------|--------|
| 1 | **Approve Nexus Client Isolation Policy (POL-007)** — Ken review and sign-off on nexus-client-isolation-policy-v1.md | Ken | 1 hr |
| 2 | **Resolve Nexus Access Policy open decisions (OD-01 to OD-05) + approve POL-008** — Ken decides Angie's MinIO prefix, KL Developer scope, Postgres tunnel prohibition, violations Notion DB | Ken | 2 hrs |
| 3 | **POL-001: Data Classification Policy** — Lex + Atlas draft, Ken approves | Lex / Atlas | 3 hrs |
| 4 | **POL-002: Data Retention Policy** — Lex drafts, Atlas reviews, Ken approves | Lex | 4 hrs |
| 5 | **POL-003: Privacy / APP Compliance Policy** — Lex drafts APP gap analysis + policy | Lex | 6 hrs |
| 6 | **POL-004: Client DPA Template (TKT-0060)** — Lex drafts, Ken approves | Lex | 5 hrs |
| 7 | **POL-005: Warden Escalation Thresholds Policy (TKT-0061)** — Thrawn drafts technical requirements, Lex frames | Thrawn / Lex | 4 hrs |
| 8 | **POL-006: Tier 3 Delegation Model** — Ken defines, Lex frames, Atlas documents | Ken / Lex | 2 hrs |
| 9 | **GAP-008: S4 Tool Scope (TKT-0062, deadline 2026-06-03)** — Shield drafts per-agent tool permissions, Ken approves | Shield | 3 hrs |
| 10 | **GAP-014: Data Residency Register** — Atlas produces, resolves Anthropic DPA contradiction | Atlas | 2 hrs |
| 11 | **GAP-013: P2 Audit Committee roles confirmed** — Ken nominates nominees for Technical Review and Legal/Compliance Review seats | Ken | 1 hr |
| 12 | **GAP-018: Aevlith incorporation gate SOP** — Yoda documents verification procedure, Ken approves | Yoda | 1 hr |
| 13 | **Accumulate P2 Evidence Pack items 4+5** — Warden reports (90 days) and SLA history (3 months) require time | Warden / Yoda | Ongoing |

**Estimated total effort:** ~34 hrs across Atlas, Lex, Thrawn, Shield, Yoda. Parallelisable across multiple sub-agents.

---

### Phase 2 — Before KL Team Onboarding (P1)

| # | Item | Owner | Effort |
|---|------|-------|--------|
| 1 | **POL-009: Sanctum Invocation Policy (CHG-P1)** — Yoda drafts, Shield/Lex/Sage review | Yoda | 3 hrs |
| 2 | **POL-010: Incident Response Policy** — Yoda drafts, Lex reviews | Yoda / Lex | 3 hrs |
| 3 | **GAP-020: Specialist agent routing rules in Yoda RULES.md (CHG-P2)** — Yoda updates RULES.md with Atlas/Thrawn/Lando/Mon Mothma routing decision tree | Yoda | 2 hrs |
| 4 | **GAP-021: Cross-stream governance rules documented** — Yoda and Aria formalise coordination protocol | Yoda / Aria | 2 hrs |
| 5 | **GAP-022: Violation handling SOP** — Once POL-008 approved, Forge creates access-violations.json + obs-collector CHECK | Forge / Yoda | 2 hrs |
| 6 | **POL-012: Client-Facing Privacy Statement** — Lex drafts for Citadel launch | Lex | 2 hrs |

---

### Phase 3 — Before First Audit (Quarterly Target — Q3 2026)

| # | Item | Owner | Effort |
|---|------|-------|--------|
| 1 | **POL-011: Third-Party AI Provider Policy (TKT-0063 + Data Residency Register complete)** — Lex drafts, Atlas reviews | Lex / Atlas | 4 hrs |
| 2 | **GAP-002: Agent Lifecycle Policy (standalone document)** — Extract from Agent Governance Framework into a standalone Policy | Atlas | 2 hrs |
| 3 | **POL-016 (future): Model Governance Policy (standalone)** — Extract from Governance Framework into a standalone enforceable policy | Atlas | 2 hrs |
| 4 | **POL-017 (future): Content Governance Policy (standalone)** — Extract from RULES.md into a standalone policy for audit reference | Yoda / Lex | 2 hrs |
| 5 | **Atlas Quarterly Governance Review (AC-18)** — Review all policies against violations log and platform changes | Atlas | 2 hrs |

---

### Phase 4 — Ongoing Governance Hygiene

| # | Item | Cadence |
|---|------|---------|
| Warden — monitor all Tier 3+ actions for policy compliance | Every 15 min (ongoing) |
| Atlas quarterly policy review — assess violations, propose updates | Quarterly (Feb/May/Aug/Nov) |
| Annual Charter and Framework review | Annual (or triggered by new phase/agent class/incident) |
| Warden scope expansion — enrol specialist agents in model-policy.json | At next quarterly review after CHG-P4 decision |
| GAP-023: Krennic pre-build preparation | Before build trigger fires (ongoing preparation) |

---

## 7. Open Decisions for Ken

| # | Decision | Options | Recommendation | Blocks |
|---|----------|---------|----------------|--------|
| **D1** | Nexus Access Policy OD-01: Who creates access-violations.json and the obs-collector CHECK? | (A) Forge creates as a sprint item immediately; (B) Wait until policy is approved | (A) Approve policy, assign Forge sprint item same CHG | GAP-022 resolution, automated violation detection |
| **D2** | Nexus Access Policy OD-02: Angie's MinIO access at P1 — which prefixes? | Atlas recommends: ainchors-brand-code/social/*/approved/ and ainchors-brand-code/marketing-materials/ read-only | Confirm Atlas recommendation or specify different prefix | P1 IAM provisioning for Angie |
| **D3** | Nexus Access Policy OD-04: Postgres via Cloudflare Tunnel — explicit prohibition? | (A) Confirm explicit prohibition → promote to RULES.md non-negotiable; (B) Allow limited circumstances | (A) Confirm prohibition — Tailscale-only is the correct security posture | Security standard for Postgres access |
| **D4** | Warden monitoring scope (CHG-P4): Enrol specialist agents or exclude permanently? | (A) Enrol Atlas, Thrawn, Lando, Mon Mothma, Spark in model-policy.json with their required models; (B) Formally document exclusion with rationale | (A) Enrol — consistent monitoring is better governance; exclusion should be a deliberate exception, not a default | Warden scope accuracy, GAP alignment |
| **D5** | Anthropic DPA: Is it verified or not? | DataMemory says "urgent/not done"; Nexus_Enterprise_Landscape says "already completed — update doc." | Ken to confirm status. If verified, Atlas produces Data Residency Register entry. If not, treat as TKT-0104 Action 2 urgent. | GAP-014 (Data Residency Register), Claude routing policy for P2 clients |
| **D6** | P3 ROI Checklist (Decision G from Nexus_Enterprise_Landscape) — has this been produced? | (A) Produce as a policy/standard; (B) Document as a Notion page in Holocron; (C) Embed in Nexus_Enterprise_Landscape update | (B) Notion page with formal criteria, referenced from POL documents | P3 commercial tier unlock governance |
| **D7** | Aevlith Technologies incorporation — current status? | Target was end May 2026. If incorporation is complete, Ken to confirm so the P2 client onboarding gate can be cleared. If not complete, all P2 planning blocks on this. | Ken to confirm legal entity status | P2 client onboarding hard gate (GAP-018) |

---

## Appendix A — Gap Summary Table

| GAP-ID | Layer | Risk | Phase |
|--------|-------|------|-------|
| GAP-001 Data Classification Policy | 3 | HIGH | P0 |
| GAP-002 Agent Lifecycle Policy | 3 | MEDIUM | Audit |
| GAP-003 Incident Response Policy | 3 | HIGH | KL |
| GAP-004 Data Retention Policy | 3 | HIGH | P0 |
| GAP-005 Warden Thresholds Policy | 3 | HIGH | P0 |
| GAP-006 Privacy/APP Policy | 3 | HIGH | P0 |
| GAP-007 Client DPA Template | 3 | HIGH | P0 |
| GAP-008 S4 Tool Scope | 4 | HIGH | P0 |
| GAP-009 Third-Party Provider Policy | 3 | MEDIUM | Audit |
| GAP-010 Client Isolation Policy (DRAFT) | 3 | HIGH | P0 |
| GAP-011 Nexus Access Policy (DRAFT) | 3 | HIGH | P0 |
| GAP-012 Tier 3 Delegation Model | 3 | HIGH | P0 |
| GAP-013 P2 Audit Committee TBC | 3 | MEDIUM | P0 |
| GAP-014 Data Residency Register | 3 | HIGH | P0 |
| GAP-015 Sanctum Invocation Policy | 3 | HIGH | KL |
| GAP-016 Content Governance Policy (embedded) | 3 | LOW | Audit |
| GAP-017 Model Governance Policy (embedded) | 3 | LOW | Audit |
| GAP-018 Aevlith Incorporation Gate SOP | 5 | HIGH | P0 |
| GAP-019 P2 Evidence Pack incomplete | 3 | HIGH | P0 |
| GAP-020 Specialist Agent Routing (RULES.md) | 4 | MEDIUM | KL |
| GAP-021 Cross-Stream Governance Rules | 3 | MEDIUM | KL |
| GAP-022 Violation Handling SOP | 5 | MEDIUM | KL |
| GAP-023 Krennic Pre-build Preparation | 5 | LOW | Ongoing |
| GAP-024 Client-Facing Privacy Statement | 3 | MEDIUM | KL |

**Counts:** HIGH=13 | MEDIUM=8 | LOW=3 | P0 critical path=13 | KL onboarding=7 | Audit=4 | Ongoing=1

---

## Appendix B — Policy Numbering Map

| Policy ID | Title | Status | Phase |
|-----------|-------|--------|-------|
| POL-001 | Data Classification Policy | PROPOSED | P0 |
| POL-002 | Data Retention Policy | PROPOSED | P0 |
| POL-003 | Privacy & APP Compliance Policy | PROPOSED | P0 |
| POL-004 | Client DPA Template | PROPOSED | P0 |
| POL-005 | Warden Escalation Thresholds Policy | PROPOSED | P0 |
| POL-006 | Tier 3 Delegation Model | PROPOSED | P0 |
| POL-007 | Nexus Client Isolation Policy (approve existing) | DRAFT FOR REVIEW | P0 |
| POL-008 | Nexus Access Policy (approve existing + ODs) | DRAFT FOR REVIEW | P0 |
| POL-009 | Sanctum Invocation Policy | PROPOSED | KL |
| POL-010 | Incident Response Policy | PROPOSED | KL |
| POL-011 | Third-Party AI Provider Policy | PROPOSED | Audit |
| POL-012 | Client-Facing Privacy Statement | PROPOSED | KL |

---

_Atlas 🏛️ — Enterprise Architect, AInchors / Aevlith Technologies_
_TKT-0137 AC1 | 2026-05-12 | v1.0_
_Status: LIVE — Approved by Ken Mun 2026-05-12_
_ODs resolved: D1 Forge-Sprint | D2 Angie MinIO approved | D3 Postgres=Tailscale locked | D4 Tier3 agents enrolled | D5 DPA verified | D6 P3 Checklist→Notion | D7 Aevlith NOT YET_
