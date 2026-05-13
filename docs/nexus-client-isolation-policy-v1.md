# Nexus Client Isolation Policy v1.0

> **Status:** APPROVED — Ken Mun, 2026-05-13 (via TKT-0157 — minor stale reference patch pending before P2 sprint)
> **Reference:** TKT-0087 AC-3 | OKR X1-KR2
> **Date:** 2026-05-07
> **Owner:** Ken Mun, CTO — Ainchor Solutions Pty Ltd
> **Enforced by:** Yoda (operational), Warden (automated monitoring)
> **Parent documents:** [AI Charter v1.0](./AI_CHARTER_v1.0.md) | [AI Governance Framework v1.0](./AI_GOVERNANCE_FRAMEWORK_v1.0.md)

---

## 1. Purpose

AInchors is approaching P2 — first SME clients on Nexus. OKR X1-KR2 requires per-client environment isolation for at least 2 SME clients, including config separation, logging separation, and Sanctum reviews.

This policy defines the **minimum technical and operational requirements** that must be in place before any SME client environment goes live on Nexus. It applies to all agents operating client workloads (Yoda, Atlas, Ahsoka) and to all Nexus infrastructure that processes client data.

**This is not a client contract.** It is an internal standard. Meeting this policy is a prerequisite for P2 client onboarding, not an optional quality target.

### What this policy governs

- Configuration isolation between client environments
- Data and logging separation
- Communication channel isolation
- Governance and audit separation
- Infrastructure isolation (P1 vs P2 requirements)
- The onboarding gate process
- Ongoing compliance obligations

### Who this applies to

All agents deployed on Nexus that handle, or could handle, client workloads: **Yoda, Atlas, Ahsoka**, and any future consulting or delivery agent. Also applies to Warden (monitoring enforcement) and Shield/Lex/Sage (Sanctum review flows per client).

---

## 2. Minimum Isolation Requirements

Every client environment on Nexus must satisfy **all** of the following requirements before any client data is processed. Requirements marked **[P2]** are mandatory for Docker-based P2 deployment; requirements marked **[P1]** are achievable on OC1 today. Requirements without a phase tag are mandatory for **both** P1 and P2.

---

### 2.1 Configuration Isolation

Each client environment must have a fully independent configuration context — no shared configuration files between clients, and no shared configuration between AInchors internal operations and any client environment.

| Requirement                  | Detail                                                                                        | Phase |
| ---------------------------- | --------------------------------------------------------------------------------------------- | ----- |
| Separate workspace directory | `workspace-client-{id}/` — never a subdirectory of the AInchors ops workspace                 | P1    |
| Separate SOUL.md             | Client-scoped identity, persona, and operating constraints                                    | P1    |
| Separate MEMORY.md           | Client-scoped persistent memory — no AInchors internal context                                | P1    |
| Separate AGENTS.md           | Client-scoped agent operating rules                                                           | P1    |
| Separate API key set         | Each client has its own API keys — never shared across clients or with AInchors internal keys | P1    |
| Separate openclaw.json       | Independent OpenClaw agent configuration per client instance                                  | P1    |
| Separate model-policy.json   | Client agents operate under their own model tier policy                                       | P1    |

**Verification:** Yoda runs a config diff check at onboarding to confirm no shared paths or API keys between client environments and the AInchors internal workspace.

---

### 2.2 Data Isolation

Client data must never cross into another client's context, into AInchors internal operations, or into Tier 2/3 cloud APIs. The data sovereignty principle from the AI Charter (§2, Principle 4) is non-negotiable and extends to all client data.

| Requirement                                        | Detail                                                                                                                                         | Phase |
| -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ----- |
| Separate logging directory                         | `logs/client-{id}/` — no shared log streams between clients                                                                                    | P1    |
| Separate obs.db instance or client_id partitioning | Either a fully separate `obs.db` per client, or all records tagged with a unique `client_id` and isolated by tag in queries                    | P1    |
| No cross-client agent context                      | Client agent sessions must not have access to another client's workspace, memory, or task history — verified by Warden                         | P1    |
| Tier 0/1 model enforcement                         | Client data never routes to Tier 2/3 cloud APIs (Claude, Ollama Cloud). Enforced via client-scoped `model-policy.json` and monitored by Warden | P1    |
| Tier 1 local inference for client workloads        | With OC2-A live, all client-facing LLM workloads route to local Gemma4:26b (Tier 1)                                                            | P2    |

**Verification:** Warden runs a `client_id` tag audit on all agent runs. Any log entry, obs.db record, or model call without a valid client tag in a client context is flagged as a violation.

---

### 2.3 Communication Isolation

Each client must have its own communication channel. Client agents must not be able to reach AInchors internal agents, relay queues, or communication infrastructure.

| Requirement                                         | Detail                                                                                                                                        | Phase |
| --------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- | ----- |
| Separate Telegram bot per client                    | Separate bot token and separate `allowFrom` list per client — no shared bot with AInchors internal channels                                   | P1    |
| Client agents cannot reach AInchors internal agents | `sessions_send` routing must not permit client agents to address internal agents (Yoda, Atlas, Aria, etc.) by session ID                      | P1    |
| Per-client relay queue                              | Each client has its own relay queue file (e.g., `relay-to-client-{id}.json`) — no shared `relay-to-ken.json` access                           | P1    |
| Separate allowFrom list                             | Client Telegram bot must not include Ken's personal Telegram ID or AInchors internal contacts in its `allowFrom` unless explicitly authorised | P1    |

**Verification:** Attempt to `sessions_send` from a client agent to an internal agent session — must be blocked. Verify relay queue files are client-scoped and not readable cross-client.

---

### 2.4 Governance Isolation

Governance reviews (Sanctum) and audit records must be per-client. AInchors internal governance context must not be visible to or contaminated by client governance flows.

| Requirement                                | Detail                                                                                                                                         | Phase |
| ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- | ----- |
| Separate Sanctum review context per client | Shield, Lex, and Sage run per-client review sessions — not a shared Sanctum instance reviewing both AInchors internal and client workloads     | P1    |
| Per-client Notion Holocron subfolder       | Governance logs, decision records, and Sanctum review outputs stored under a client-specific subfolder in the Notion Holocron                  | P1    |
| Warden monitoring with client_id tag       | Warden monitors all client agents under a `client_id` tag — enabling per-client compliance reports, separate from AInchors internal monitoring | P1    |
| Separate CHANGELOG.md per client           | Change records for client environments logged in the client workspace, not mixed into the AInchors internal CHANGELOG.md                       | P1    |

**Verification:** Warden generates a per-client compliance report monthly. Sanctum review history is queryable by client context — no cross-client review results appear.

---

### 2.5 Infrastructure Isolation *(P2 — Docker required)*

> ⚠️ **P2 requirement.** The following are mandatory for P2 (OC2 deployment, Q2 2026) and are NOT required for P1. On P1, configuration and data isolation (§2.1–§2.4) provide the minimum acceptable isolation floor.

| Requirement                                    | Detail                                                                                                                                          | Phase |
| ---------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | ----- |
| Separate Docker container per client           | Each client's OpenClaw instance runs in its own container — no shared process namespace                                                         | P2    |
| Separate network namespace                     | No direct container-to-container traffic without explicit routing rules. Client containers cannot reach AInchors internal containers by default | P2    |
| Separate filesystem mount per client container | Client workspace, logs, and config mounted into the client container only — not accessible from other containers                                | P2    |
| Separate Docker secrets/env per container      | API keys and secrets injected via Docker secrets or per-container environment variables — never baked into a shared image layer                 | P2    |

**P2 target (Q2 success criteria, per Aevlith Technologies IT Strategy §5):** 2 SME client environments deployed in isolated Docker containers on Nexus.

---

## 3. Pre-Client-Onboarding Checklist

**Gate:** This checklist must be completed and signed off by Ken before any client data is ingested. Yoda runs the checklist. Ken approves the final gate.

```
CLIENT ONBOARDING ISOLATION GATE
Client ID: _______________
Client Name: _______________
Date: _______________
Completed by: Yoda
Approved by: Ken Mun

CONFIG ISOLATION
[ ] Separate workspace directory created: workspace-client-{id}/
[ ] Separate SOUL.md created and scoped to client context
[ ] Separate MEMORY.md created (blank — no AInchors internal data)
[ ] Separate AGENTS.md created
[ ] Separate API keys obtained and stored in macOS Keychain under client-scoped entry
[ ] Separate openclaw.json created for client agent instance
[ ] Separate model-policy.json created with Tier 0/1 enforcement for client workloads

DATA ISOLATION
[ ] Separate logging directory created: logs/client-{id}/
[ ] obs.db partitioned by client_id OR separate obs.db instance provisioned
[ ] Warden client_id tag configured for client agent runs
[ ] model-policy.json verified: Tier 2/3 models prohibited for client-tagged tasks

COMMUNICATION ISOLATION
[ ] Separate Telegram bot registered: bot token stored in Keychain, allowFrom set
[ ] sessions_send routing confirmed: client agent cannot address internal agent sessions
[ ] Per-client relay queue created: relay-to-client-{id}.json

GOVERNANCE ISOLATION
[ ] Sanctum review context created for client (Shield/Lex/Sage per-client config)
[ ] Notion Holocron subfolder created for client: Holocron › Clients › {client-name}
[ ] Warden monitoring active with client_id tag
[ ] Client CHANGELOG.md initialised in client workspace

INFRASTRUCTURE (P2 only — skip for P1)
[ ] Docker container provisioned for client OpenClaw instance
[ ] Network namespace confirmed: no default route to AInchors internal containers
[ ] Filesystem mount verified: client workspace mounted to client container only
[ ] Docker secrets configured for client API keys

ISOLATION TESTING
[ ] Cross-client context test passed (see §4)
[ ] Model tier test passed (see §4)
[ ] Relay isolation test passed (see §4)

FINAL GATE
[ ] Ken Mun approval received (webchat or Telegram — explicit sign-off required)
[ ] Gate completion recorded in Notion Holocron › Clients › {client-name} › Onboarding
```

---

## 4. Isolation Testing

Before any client environment goes live, Yoda runs the following three tests. All three must pass. Any failure blocks onboarding until remediated.

### Test 1 — Cross-Client Context Test

**Purpose:** Verify that Client A data cannot be read from a Client B agent session.

**Procedure:**
1. With Client A workspace populated (workspace-client-A/), spawn a Client B agent session.
2. Attempt to read `workspace-client-A/MEMORY.md` from the Client B session.
3. Attempt to query obs.db for Client A records from the Client B session context.

**Pass criteria:** Both read attempts are blocked — file is outside the Client B agent's workspace scope, and obs.db query returns no Client A records.

**Fail action:** Stop onboarding. Identify the path or query boundary violation. Remediate config. Retest.

---

### Test 2 — Model Tier Test

**Purpose:** Verify that client-tagged tasks cannot invoke Tier 2/3 models.

**Procedure:**
1. Submit a task tagged with the client's `client_id` that explicitly requests a Tier 2 or Tier 3 model (e.g., Claude Sonnet, Ollama Cloud).
2. Observe Warden response.

**Pass criteria:** Warden blocks the model call before execution. Task is rejected or escalated — not silently routed to a Tier 2/3 model.

**Fail action:** Review client `model-policy.json` and Warden enforcement config. Remediate. Retest.

---

### Test 3 — Relay Isolation Test

**Purpose:** Verify that Client A's relay queue is not accessible to Client B's agent.

**Procedure:**
1. Write a test message to `relay-to-client-A.json`.
2. From a Client B agent session, attempt to read `relay-to-client-A.json`.

**Pass criteria:** Read attempt fails — file is outside the Client B workspace scope.

**Fail action:** Review workspace directory boundaries. Remediate. Retest.

---

## 5. Ongoing Compliance

Isolation is not a one-time onboarding check. These recurring obligations apply for the lifetime of any active client on Nexus.

### Warden — Continuous (automated)

- Warden checks `client_id` tags on all agent runs.
- Any agent run in a client context without a valid `client_id` tag is flagged.
- Any model call from a client-tagged context attempting Tier 2/3 is flagged and blocked.
- Warden generates a per-client compliance report monthly; Yoda reviews and logs to Notion.

### Monthly Isolation Audit (Yoda)

- Review `logs/client-{id}/` for any log entries that reference another client's ID, workspace path, or data.
- Review obs.db for any records where `client_id` is null or mismatched in client agent sessions.
- Review Telegram bot activity logs for any cross-client message routing.
- Log audit result to Notion Holocron › Clients › {client-name} › Compliance.

### Isolation Breach = P1 Incident

Any confirmed or suspected cross-client data exposure, context bleed, or relay queue breach is a **P1 incident**. Immediate actions:

1. Suspend affected client agent session(s).
2. Notify Ken immediately (Telegram — do not wait for heartbeat).
3. Log to `scripts/incident-log.sh` with `severity=P1`.
4. Root cause analysis within 24 hours.
5. Remediation and re-isolation test before any client agent is reinstated.
6. Post-incident review logged to Notion Holocron.

---

## 6. P1 vs P2 Implementation

| Requirement                                  | P1 (OC1 — Now)                                   | P2 (OC2 — Q2 2026)                     |
| -------------------------------------------- | ------------------------------------------------ | -------------------------------------- |
| Separate workspace directory                 | ✅ Required and achievable                        | ✅ Required                             |
| Separate SOUL.md / MEMORY.md / AGENTS.md     | ✅ Required and achievable                        | ✅ Required                             |
| Separate API key set                         | ✅ Required — macOS Keychain, client-scoped entry | ✅ Required                             |
| Separate openclaw.json                       | ✅ Required and achievable                        | ✅ Required                             |
| Separate logging directory                   | ✅ Required and achievable                        | ✅ Required                             |
| obs.db isolation (tag or separate instance)  | ✅ Required — client_id tag approach viable on P1 | ✅ Required                             |
| No cross-client agent context                | ✅ Required — verified by Warden                  | ✅ Required                             |
| Tier 0/1 model enforcement for clients       | ✅ Required — via model-policy.json               | ✅ Required                             |
| Separate Telegram bot per client             | ✅ Required and achievable                        | ✅ Required                             |
| sessions_send routing restriction            | ✅ Required — workspace boundary enforcement      | ✅ Required                             |
| Per-client relay queue                       | ✅ Required and achievable                        | ✅ Required                             |
| Per-client Sanctum review context            | ✅ Required and achievable                        | ✅ Required                             |
| Notion Holocron client subfolder             | ✅ Required and achievable                        | ✅ Required                             |
| Warden client_id monitoring                  | ✅ Required and achievable                        | ✅ Required                             |
| Docker container per client                  | ❌ Not required for P1                            | ✅ **Required for P2**                  |
| Separate network namespace                   | ❌ Not required for P1                            | ✅ **Required for P2**                  |
| Separate filesystem mount per container      | ❌ Not required for P1                            | ✅ **Required for P2**                  |
| Tier 1 local inference (Gemma4:26b on OC2-A) | ❌ Not available on P1                            | ✅ **Required for P2 client workloads** |

**P1 isolation floor summary:** On OC1, isolation is achieved through directory separation, separate config files, separate API keys, separate Telegram bots, and Warden enforcement of model tier policy and client_id tagging. There is no process-level or network-level isolation between client environments on P1 — this is an accepted P1 risk, mitigated by the config controls above.

**P2 prerequisite:** Docker-based infrastructure isolation is the architectural prerequisite for P2 multi-client production. No P2 client may go live without the Docker isolation requirements in §2.5 in place. This aligns with the Aevlith Technologies IT Strategy Q2 success criteria and OKR X1-KR2.

---

*Document version: 1.0 | TKT-0087 AC-3 | Authored by Yoda | 2026-05-07*
