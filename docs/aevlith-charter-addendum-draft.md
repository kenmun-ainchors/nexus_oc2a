# Aevlith Technologies Technology Governance Addendum
## to the AInchors AI Charter v1.0

> **DRAFT — For Ken Mun Review and Approval**
> Prepared by: Lex ⚖️ (Legal & Compliance Agent)
> Reference: TKT-0087 AC-1
> Date: 2026-05-07
> Status: DRAFT — awaiting Ken Mun sign-off before any external use

---

## Overview

The AInchors AI Charter v1.0 governs all agents deployed across AInchors and Aevlith Technologies. This addendum clarifies how governance obligations are allocated *between* the two entities. It does not replace or override the Charter — it sits under it, resolving ambiguities that become material when the first SME clients come on board at P2.

The two entities in plain terms:
- **AInchors** (Ainchor Solutions Pty Ltd) — the commercial entity. Contracts with clients, delivers training and consulting, owns the client relationship.
- **Aevlith Technologies** — the technology/IP entity. Designs, builds, and operates Nexus. Provides the platform that powers both internal AInchors operations and client implementations.

Ken Mun is CTO of both entities. In P1, all governance authority rests with Ken directly. This addendum describes how that authority is structured as the platform moves toward P2.

---

## 1. Scope Clarification

AInchors and Aevlith Technologies are separate entities that share a governance spine: the AI Charter applies to both, in full, without exception. The Charter's "who it applies to" section already names all agents regardless of which entity they nominally sit under — this addendum reinforces that there is no governance gap between the two.

The practical split is: **Aevlith Technologies owns the platform; AInchors owns the client relationship.** Aevlith Technologies builds and operates Nexus. AInchors packages Nexus capability into training, consulting, and managed service offerings and is the contracting party with clients. Neither entity operates independently of the Charter's principles, tier requirements, or human-in-the-loop rules. Any agent operating within Nexus — whether running an AInchors-internal task or a client workflow — is bound by the same rules.

---

## 2. Data Responsibility

**Controller and processor roles.** When Nexus processes client data, the legal split is:
- **Data Controller:** The client (or AInchors, where AInchors acts as a reseller or is managing data on the client's behalf under a service agreement).
- **Data Processor:** Aevlith Technologies, as the entity that operates the technical platform through which that data flows.
- **Data Sub-processor:** Any underlying model provider or infrastructure service that Aevlith Technologies routes data to — subject to the Tier 0/1 restriction in Charter Section 5 (client data stays local; no cloud AI APIs without explicit written consent and a signed DPA).

**Signing authority.** AInchors signs client DPAs, because AInchors holds the client contract. Aevlith's data processing obligations (environment isolation, log separation, retention enforcement, deletion at end of engagement) are incorporated by reference into AInchors' DPA template. Lex must ensure the standard DPA template (TKT-0060) explicitly names Aevlith Technologies as sub-processor and binds it to the same obligations.

**Data sovereignty enforcement.** Aevlith Technologies is technically responsible for enforcing Tier 0/1 controls on Nexus — per-client environment isolation, config separation, log separation, and Sanctum governance reviews (Charter Section 4 Tier 3, OKR X1-KR2). AInchors is commercially responsible for communicating those controls to clients and ensuring client contracts reflect them accurately.

**⚠️ Lex flag — APP P2 pre-condition:** The standard DPA (TKT-0060) must explicitly address the controller/processor split above before any SME client signs. Aevlith's obligations as data processor should be documented in a schedule or exhibit to the DPA, not just referenced by implication. This is a hard P2 gate.

---

## 3. IP and Liability Delineation

**Nexus IP.** Nexus — the platform, its architecture, agent framework, configuration, and all associated tooling — is Aevlith's IP. AInchors has a licence to use Nexus for its commercial operations (training delivery, consulting, managed agentic services). That licence is internal and does not transfer to clients. Clients get access to Nexus-powered services; they do not get a licence to Nexus itself.

**Platform liability.** If Nexus fails — outage, data loss, agent error at the platform level — liability for that failure sits with Aevlith Technologies. Ken, as CTO of Aevlith Technologies, is the decision-maker on remediation. The incident log (`scripts/incident-log.sh`), Notion Holocron, and the PVT process are Aevlith's operational accountability mechanisms.

**Service delivery liability.** If AInchors fails to deliver a contracted service to a client (regardless of the root cause), AInchors holds the commercial liability. A Nexus platform failure that causes an AInchors service failure does not automatically pass through liability to the client — AInchors' client contract governs what remedies apply. Aevlith's obligation is to restore the platform; AInchors' obligation is to manage the client relationship.

**⚠️ Lex flag:** Once external clients are onboarded, AInchors' client contracts should include a platform dependency clause that limits AInchors' liability for Nexus-caused failures to the extent of Aevlith's platform SLA. This needs drafting before P2 first client sign. Lex to raise a TKT at P2 kickoff.

---

## 4. Governance Applicability

The full AI Charter — all seven sections — applies to all agents operating within Nexus, whether they are AInchors-branded agents (Aria, Ahsoka, Spark) or Aevlith platform agents (Thrawn, Yoda, Shield, Lex, Sage, Warden, Krennic). There is no reduced-governance mode for Aevlith Technologies-internal operations.

Tier definitions (Charter Section 4) apply identically across both entities:
- **Tier 1 (Autonomous):** Low-risk, reversible, pre-approved. Same threshold regardless of entity.
- **Tier 2 (Audit):** Automated with logging. All Nexus platform changes that have no client-facing impact qualify here.
- **Tier 3 (Human Approval):** Any change to Nexus that affects client environments, any new agent capability, any new data type processed. Ken Mun is the sole approver in P1. Delegation model must be in place before P2 first client (Charter Section 4 — already a documented pre-condition).

The governance triad (Shield, Lex, Sage) applies to Aevlith platform decisions as well as AInchors commercial decisions. Any material platform change — new Nexus capability, infrastructure change, model routing change — should be reviewed by Shield (security) and, where it touches client data handling or compliance, by Lex before execution.

---

## 5. Operational Handoff

**Nexus changes that affect AInchors service delivery.** Any change to the Nexus platform that could affect AInchors' ability to deliver contracted services must have a CHG entry (CHANGELOG.md) and Ken approval before it goes into production. "Could affect" means: changes to agent behaviour, data flows, environment configuration, model routing, or infrastructure that AInchors-facing agents depend on. Thrawn and Yoda are jointly responsible for identifying and flagging these changes before execution.

**AInchors commercial decisions that require Nexus capability.** If AInchors (or Ahsoka on a consulting engagement) identifies a new client requirement that requires Nexus to do something it doesn't currently do, that requirement routes through Atlas and Yoda for a technical assessment before any commitment is made to the client. Ahsoka does not promise platform capability it has not confirmed with the Aevlith/Nexus team. This is a hard rule — no exceptions. The sequence is: AInchors identifies need → Atlas/Yoda assess feasibility → Ken approves commitment → Aevlith Technologies implements → AInchors delivers.

**Boundary summary (quick reference):**

| Scenario                                        | Who acts first             | Approval required                                |
| ----------------------------------------------- | -------------------------- | ------------------------------------------------ |
| Nexus platform change (no client impact)        | Aevlith Technologies (Thrawn/Yoda)     | CHG entry, Ken spot-review                       |
| Nexus platform change (client-facing impact)    | Aevlith Technologies (Thrawn/Yoda)     | CHG entry + Ken approval (Tier 3)                |
| New client requirement needing Nexus capability | AInchors (Ahsoka) triggers | Atlas/Yoda feasibility first, then Ken           |
| Client data incident (Nexus-originated)         | Aevlith Technologies (Yoda/Shield)     | Incident log, Ken immediate notification         |
| Client relationship issue (service delivery)    | AInchors (Aria/Ahsoka)     | Ken approval if it has financial or legal impact |

---

## Open Items for Lex to Revisit at P2

1. **DPA schedule for Aevlith Technologies as sub-processor** — must be included in TKT-0060 DPA template before any client onboarding.
2. **Platform liability clause in AInchors client contracts** — limits AInchors pass-through liability for Nexus-caused failures. Requires a TKT at P2 kickoff.
3. **Formal APP gap analysis** — Charter Section 5 already mandates this (Lex delivers before P2). The controller/processor split documented here should inform that analysis.
4. **Tier 3 delegation model** — Charter Section 4 already flags this as mandatory before P2. When drafted, it should specify whether any Tier 3 approvals can be delegated separately for Aevlith platform decisions vs. AInchors commercial decisions.
5. **Aevlith Technologies entity formalisation** — this addendum assumes Aevlith Technologies is a distinct legal entity. If Aevlith Technologies is currently operating as a trading name or informal structure, the IP and liability sections above will need revision to reflect the actual legal structure. Lex to confirm entity status with Ken.

---

## Addendum Governance

| Field              | Value                                                                                        |
| ------------------ | -------------------------------------------------------------------------------------------- |
| Version            | Draft 0.1                                                                                    |
| Status             | **DRAFT — For Ken Mun Review and Approval**                                                  |
| Prepared by        | Lex ⚖️                                                                                       |
| Reference ticket   | TKT-0087 AC-1                                                                                |
| Date prepared      | 2026-05-07                                                                                   |
| Sits under         | AInchors AI Charter v1.0                                                                     |
| Approval authority | Ken Mun, CTO (AInchors + Aevlith Technologies)                                                           |
| Review trigger     | On APP formalisation, P2 first client onboarding, or any material change to entity structure |

Once approved by Ken, this addendum is appended to the canonical AI Charter in Notion Holocron › Platform Operations › AI Charter and referenced in all agent RULES.md files alongside the parent Charter.
