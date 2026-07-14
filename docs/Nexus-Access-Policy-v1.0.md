# Nexus Access Policy v1.0
**Status:** LIVE — Approved by Ken Mun 2026-05-12 — Nexus Operations Mandate
**OD decisions:** OD-01 Forge-Sprint | OD-02 Angie MinIO rec approved | OD-03 KL dev rec approved | OD-04 Postgres=Tailscale-only confirmed | OD-05 Notion violations DB approved
**Author:** Atlas 🏛️ | Requested by: Ken Mun (CTO) | TKT-0161
**Date:** 2026-05-12
**Supersedes:** Informal routing assumptions. Complements: File-Routing-Policy-v1.0.md, EA-Addendum-Storage-Access-Architecture-v0.1.md, DataMemory_P1P4_Roadmap.md, RULES.md

---

**ITIL Practice:** Information Security Management

> **⚠️ DRAFT FOR REVIEW**
> This document is not yet in force. Upon Ken Mun approval it becomes the
> **Nexus Operations Mandate** — strictly enforced across all agents, all storage
> layers, and all humans operating the AInchors Nexus platform.

---

## 1. Purpose & Mandate Statement

The Nexus platform operates across multiple storage layers, multiple agents, and
multiple human personas. Without a formal access policy, every agent is a
potential source of data misrouting, tier confusion, and compliance exposure.

**This policy defines:**
- What data lives where
- Who (agents and humans) can read, write, and delete what
- The approved patterns that govern all data movement
- How both **outbound** (Nexus/agents → users/clients) and **inbound** (users/clients → Nexus) data flows are governed
- What constitutes a violation and how violations are escalated

**What this prevents:**
- Tier 0 (restricted) data written to cloud storage
- Agents reading from other agents' workspaces directly
- Deliverables delivered via local filesystem path to Angie or external parties
- State files modified without ticket.sh
- MinIO URLs shared as `s3://` or raw IP — not Tailscale FQDN
- Human-readable deliverables lost in MinIO without Drive sync
- Credentials stored in files rather than macOS Keychain

Once approved by Ken Mun, this policy is **strictly enforced**. Violations are
logged, escalated, and tracked to resolution. No agent or human may override
this policy without a formal CHG approved by Ken.

---

## 2. Scope

### In Scope
- All AInchors Nexus agents (Yoda, Aria, Spark, Atlas, Thrawn, Forge, Lando,
  Mon Mothma, Ahsoka, Shield, Lex, Sage, Warden)
- All human personas (Ken Mun, Angie, KL Team, P2 Clients)
- All storage layers: OC1 local filesystem, Google Drive, MinIO (4 buckets),
  Notion Holocron, Agent session memory (MEMORY.md, daily notes, context files),
  Postgres database
- All file types: Markdown, HTML, JSON, PDF, DOCX, images, scripts, config,
  state files, logs, vector embeddings

**Bidirectional coverage:** This policy governs both directions of data flow:
- **Outbound:** Nexus/agents → users, clients, and external systems (Sections 1–7)
- **Inbound:** Users/clients → Nexus — file submissions, documents, and business data (Section 8)

Both directions are subject to the same classification, storage, and access controls defined herein.

### Out of Scope
- Network-level ACLs and firewall rules (governed by S1–S7 controls and
  EA-Addendum-Storage-Access-Architecture-v0.1.md)
- Cloudflare Access identity policies (separate operational runbook)
- macOS Keychain key management (governed by SecretsManagement.md)
- Git repository access control (governed by GitHub org settings)

---

## 3. Data Classification

Four tiers, strictly enforced. Every file, record, and object must be
classified at creation. Classification determines which storage layers are
permitted and who may access.

### Tier 0 — Restricted
**Definition:** Client PII, regulated data, biometric data, credentials, API
keys, tokens, pairing codes, APRA-regulated content, financial records of
external parties.

**Storage:** OC1 local filesystem ONLY. Never cloud. Never MinIO. Never Drive.
Never agent-to-agent without explicit Ken approval and a CHG entry.
Credentials specifically: macOS Keychain ONLY — never any file.

**Examples:** API keys, Keychain secrets, client personal data (P2+), APRA
regulated FSI workloads, OAuth tokens, pairing codes, client financial data.

**Access:** Ken only (or owning agent for scoped credential access via
secrets-init.sh). No agent may store Tier 0 data outside OC1 local.

---

### Tier 1 — Internal
**Definition:** AInchors operational data, agent state, platform decisions,
MEMORY.md, daily notes, CHANGELOG.md, tickets, governance state, health state,
observability data, cost state, session context.

**Storage:** OC1 local filesystem (primary). Notion Holocron (decisions, tickets,
sprint data). Agent session memory. Postgres (audit log, shared state).
Drive only for human-facing summaries (e.g. sprint reports, EA docs) — the
source of truth for those summaries is Drive once synced.

**No MinIO** for Tier 1 state files — state/ backups to MinIO workspace-assets
are automated backup only, not primary access.

**Examples:** state/*.json, MEMORY.md, memory/YYYY-MM-DD.md, CHANGELOG.md,
tickets.json, RULES.md, SOUL.md, health-state.json, cost-state.json,
agent_events (Postgres), agent_decisions (Postgres).

**Access:** Agents (read/write own domain). Ken (full). Angie (Drive-synced
summaries only — not raw state files).

---

### Tier 2 — Working
**Definition:** Deliverables in progress — drafts, analyses, runbooks, social
drafts, proposals in review, blog posts before publication, canvas HTML before
governance clearance, sub-agent outputs pending review.

**Storage:** OC1 local filesystem (primary working copy). Drive (for
Ken/Angie review once ready). MinIO (agent-side staging — draft prefixes).

**Examples:** docs/*.md drafts, /tmp/draft-*.html (governance review),
canvas/documents/ (pre-publication), workspace-social/ (social drafts),
MinIO ainchors-brand-code/social/*/drafts/, MinIO
ainchors-workspace-assets/consulting/proposals/.

**Access:** Producing agent (R/W). Governance agents Shield/Lex/Sage (R for
review). Ken (R/W via Drive or local session). Angie (R via Drive only).

---

### Tier 3 — Published
**Definition:** Approved, released documents. Governance-cleared content.
Posted social media. Published blog posts. Approved architecture documents.
Final proposals delivered to clients. Immutable once approved — no silent edits.

**Storage:** Google Drive (SSOT for human-readable). MinIO approved/posted
prefixes (agent consumption and presigned URL delivery). Notion Holocron
(decisions, approved frameworks). Any post-publication change requires a new
version + CHG entry.

**Examples:** Drive EA Assessments (status=LIVE), MinIO
ainchors-brand-code/social/linkedin/posted/, MinIO
ainchors-workspace-assets/consulting/client-deliverables/, Notion approved
frameworks, published canvas HTML after governance clearance.

**Access:** Read broadly (agents, humans with appropriate Drive/MinIO access).
Write: restricted — new version requires CHG. No overwrite of approved content.

---

## 4. Storage Layer Rules

### 4.1 OC1 Local Filesystem (`workspace/`, `workspace-social/`, `workspace-architect/`, etc.)

| Dimension | Rule |
|-----------|------|
| **What goes here** | Agent working files, state files, scripts, config, canvas HTML (render path), docs/ (agent-reference copy of Drive), memory/, reports/, workspace-social/ (social staging) |
| **Who reads** | Agents only (own workspace domain). Ken during active LAN/Tailscale session. |
| **Who writes** | Agents (own workspace). Ken explicitly. No cross-workspace writes between agents. |
| **What never goes here** | Client PII (Tier 0). Anything that should only live in Drive. Final deliverables without a corresponding Drive sync. |
| **State files** | `state/` is platform-internal. Never synced to Drive or MinIO (except automated backup of state/ to workspace-assets). Never shared with external parties. |
| **Scripts** | `scripts/` is platform-internal. SSOT is GitHub. Never synced to Drive. |
| **Canvas** | `canvas/documents/` is render path. Ken opens by local path during active session. Drive sync mandatory after creation (Tier 3 when published). |
| **Cross-agent** | Agents must not read/write other agents' workspace directories directly. Shared data passes through `workspace/state/` (shared keys) or MinIO `ainchors-agent-memory/shared/`. |
| **Inbound content** | Tier 0 inbound client/user files stored here ONLY after intake classification — never routed to cloud. Tier 1–3 inbound content staged here pending classification, then promoted to additional storage per Section 8.3. |

---

### 4.2 Google Drive (`AInchors — Yoda Working Files/` hierarchy)

| Dimension | Rule |
|-----------|------|
| **What goes here** | All human-readable, human-accessible files. Drive is SSOT for all deliverables once synced. |
| **Who reads** | Ken, Angie, KL Team (P1+, role-scoped folders). Mobile, Windows, any browser — Drive is the universal access layer for humans. |
| **Who writes** | Agents via `gog drive upload` (mandatory after every deliverable). Ken and Angie directly (Drive UI). |
| **Sync obligation** | Every write to docs/, canvas/, workspace-social/ that produces a deliverable triggers a Drive upload. Sync failures logged to `state/drive-sync-failures.json`. |
| **What never goes here** | Tier 0 data. Credentials. state/ files. Platform-internal scripts. Agent memory raw files (MEMORY.md — use summaries only). |
| **SSOT rule** | If Drive and local conflict, Drive wins. Local is agent-reference only. |
| **Search before create** | Always search for existing folder before `gog drive mkdir`. Never create duplicates. |

**Target folder structure (locked):**
```
AInchors — Yoda Working Files/
├── EA Assessments/          ← Atlas/Thrawn architecture docs (LIVE when approved)
├── Canvas/                  ← Published HTML deliverables (standup, slides, pitch)
├── Proposals/               ← Ahsoka client proposals
├── Marketing/               ← Marketing collaterals, brand assets
├── Social/
│   ├── Drafts/              ← Spark outputs pending Ken/Angie review
│   └── Published/           ← Archived after posting
├── Sprint Docs/             ← Sprint reviews, burndowns, reports
└── Journal/                 ← Daily journals (EOD cron syncs nightly)
```

---

### 4.3 MinIO (4 Buckets)

MinIO is the **agent layer** — machine-readable, not human-facing. All MinIO
URLs shared with Ken or in any document must use the Tailscale FQDN:
`https://ainchorsoc2as-mac-mini-1.tailfc3ed1.ts.net:9000/{bucket}/{path}`

Never: `s3://`, `http://100.91.60.36:9000/`, `local/`, `localhost`.

| Bucket | Purpose | Who Writes | Who Reads | What Never Goes Here |
|--------|---------|------------|-----------|---------------------|
| `ainchors-brand-code` | Social drafts, blog, marketing materials, brand content | Spark, Aria, Mon Mothma, Ahsoka | Agents (consumption), Ken (presigned URL if needed) | Tier 0 data, state files, credentials |
| `ainchors-workspace-assets` | Working docs, architecture, consulting, governance, ops, state backups | Atlas, Thrawn, Forge, Ahsoka, Shield, Lex, Sage, Warden, Lando, Mon Mothma | Agents (own path), Ken (presigned URL) | Tier 0 data, client PII, credentials |
| `ainchors-generated-media` | AI-generated images, videos, visual assets, presentations | Spark, Forge, Atlas | Agents (presigned URL generation), Ken (presigned URL) | Documents, state files, Tier 0 data |
| `ainchors-agent-memory` | Agent memory artifacts, handoffs, shared context | Yoda, Aria, agent producing handoff | Receiving agent (own path), Yoda | Tier 0 data, client PII, credentials |

**Inbound content:** After intake classification (Section 8.3), Tier 1–3 inbound
user/client content is staged to the appropriate bucket per the intake pipeline.
Tier 0 inbound content is **never** stored in MinIO — OC1 local only (see Section 8.3).

**Per-agent MinIO paths** are defined in `state/minio-routing-policy.json`.
Agents must follow that policy — no ad-hoc bucket/path creation.

---

### 4.4 Notion Holocron (Knowledge Base)

| Dimension | Rule |
|-----------|------|
| **What goes here** | Decisions (Decisions DB), tickets/US/CHG (AKB Backlog DB), sprint docs, approved frameworks, architecture notes, lessons learned, agent design rationale |
| **Who reads** | Ken (full), Angie (role-scoped), KL Team (P1+, role-scoped), Agents (via gog or Notion API for reads) |
| **Who writes** | Agents via ticket.sh (tickets, CHG), via manual Notion API for framework/decision pages. Yoda for sprint and platform docs. |
| **What never goes here** | Tier 0 data. Raw state files. Credentials. Internal-only memory (MEMORY.md → Notion summaries only). |
| **SSOT** | Notion is SSOT for all US, TKT, CHG, INC records. Local tickets.json is a cache only. |

---

### 4.5 Agent Session Memory (MEMORY.md, Daily Notes, Context Files)

| Dimension | Rule |
|-----------|------|
| **What goes here** | Agent's curated long-term memory (MEMORY.md), raw daily session logs (memory/YYYY-MM-DD.md), shared context files (memory/shared/) |
| **Who reads** | Owning agent only (main session). MEMORY.md must NOT be loaded in sub-agents, isolated crons, or shared contexts — security risk (personal context leakage). |
| **Who writes** | Owning agent (main session). Yoda writes MEMORY.md in main session only. |
| **What never goes here** | Client PII (Tier 0). Credentials. Verbatim secret values. |
| **Cross-agent sharing** | Agents share via `memory/shared/` (aria-daily-brief.md, decisions.md). Not by reading each other's MEMORY.md. |
| **Isolation rule** | Sub-agents and crons operate with `lightContext: true` — no MEMORY.md access except where explicitly required (standup, RTB summary). |

---

### 4.6 Database (Postgres — P1 build, loopback + Tailscale only)

| Dimension | Rule |
|-----------|------|
| **What goes here** | Episodic audit log (agent_events, agent_decisions, decision_lineage, memory_access_log), shared agent state (agent_shared_state, agent_state_history), session state (P1: Postgres tables; P2: Redis), vector embeddings (pgvector — knowledge_chunks, knowledge_documents) |
| **Who reads** | Agents (loopback API). Ken (Tailscale + psql or admin tool). Warden (compliance monitoring). |
| **Who writes** | Agents via loopback. Ken directly (Tailscale). All state mutations logged. |
| **What never goes here** | Client PII in unencrypted columns (P1). Credentials in any column. |
| **Access path** | Loopback (`localhost:5432`) only. Tailscale for remote admin. NEVER via Cloudflare Tunnel. NEVER via public port. |
| **Multi-tenant (P2)** | `tenant_id` column on every table from P1 (default: `'ainchors'`). RLS enforced from P2. |
| **Inbound content** | Intake event log (`intake_events` table at P2). RAG embeddings for classified inbound content (`knowledge_chunks`, `knowledge_documents` via pgvector). Tier 0 inbound content: encrypted blob store at P2 only — never in unencrypted columns. |

---

## 5. Agent Access Matrix

Permission key:
- **R** = Read only
- **W** = Write (create/update)
- **R/W** = Read + Write
- **R/W/D** = Full manage (read, write, delete)
- **None** = No access
- **Cond** = Conditional (read for review/audit only, specified)
- **Backup** = Automated backup writes only (not primary access)

| Agent | OC1 Local (own workspace) | OC1 Local (other workspaces) | OC1 Local `state/` (shared) | Google Drive | MinIO (own paths) | MinIO (other paths) | Notion | Session Memory (own) | Session Memory (others) | Postgres |
|-------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **Yoda 🟢** | R/W/D | R (workspace/ shared only) | R/W | R/W via gog | R/W (workspace-assets, agent-memory) | R (read-only, orchestration) | R/W | R/W | None | R/W |
| **Aria 🔵** | R/W/D | None | R (shared keys only) | R/W via gog (Social/Marketing) | R/W (brand-code, agent-memory/aria) | None | R/W (business stream) | R/W | None | None |
| **Spark ✨** | R/W (workspace-social) | None | R (shared keys only) | R (read source), W (Social/Marketing via gog) | R/W (brand-code) | R (generated-media read for reference) | R (relevant) | R/W | None | None |
| **Atlas 🏛️** | R/W (workspace-architect) | R (workspace/docs for context) | R | R/W via gog (EA Assessments) | R/W (workspace-assets/technology, workspace-assets/consulting/frameworks, generated-media/presentations) | None | R/W (architecture, decisions) | R/W | None | None |
| **Thrawn 🔷** | R/W (own workspace) | R (workspace/docs for context) | R/W | R/W via gog (EA Assessments, Sprint Docs) | R/W (workspace-assets/technology) | None | R/W (platform, governance) | R/W | None | None |
| **Forge 🔧** | R/W (own workspace) | R (workspace/state for infra monitoring) | R/W | R/W via gog (Sprint Docs) | R/W (workspace-assets/technology) | Backup (workspace-assets for state backups) | R/W (infra, incidents) | R/W | None | R (health monitoring) |
| **Lando 🎰** | R/W (own workspace) | None | R | None | R/W (workspace-assets/business) | None | R/W (business stream) | R/W | None | None |
| **Mon Mothma 👑** | R/W (own workspace) | None | R | None | R/W (workspace-assets/business, ainchors-brand-code/marketing-materials/training) | None | R/W (business stream) | R/W | None | None |
| **Ahsoka 🌙** | R/W (own workspace) | None | R | R/W via gog (Proposals) | R/W (workspace-assets/consulting, ainchors-brand-code/marketing-materials/consulting) | None | R/W (consulting stream) | R/W | None | None |
| **Shield 🛡️** | Cond (read for review, own workspace R/W) | Cond (read for security review only) | R | None | Cond (R for review) + W (governance/reviews, governance/audits) | None | R/W (governance) | R/W | None | None |
| **Lex ⚖️** | Cond (read for review, own workspace R/W) | Cond (read for legal review only) | R | None | Cond (R for review) + W (governance/reviews, governance/compliance) | None | R/W (governance) | R/W | None | None |
| **Sage 🧪** | Cond (read for review, own workspace R/W) | Cond (read for QA review only) | R | None | Cond (R for review) + W (governance/reviews, governance/audits) | None | R/W (governance) | R/W | None | None |
| **Warden 🔍** | R (all — monitoring only) | R (all — monitoring only) | R (all) | None | R (all — audit) + W (governance/compliance, governance/incidents) | — | R/W (compliance) | R (all — drift monitoring) | R (all — drift monitoring) | R (audit log) |

**Notes:**
1. "Own workspace" = agent's designated workspace directory (e.g. `workspace-architect/` for Atlas, `workspace-business/` for Aria)
2. All cross-agent reads (Shield/Lex/Sage/Warden) are strictly **read-only for the stated purpose** — they must not write to files they are reviewing
3. Forge backup writes to MinIO workspace-assets are automated and scoped to `state/` backup paths only
4. Warden monitoring access is read-only across all layers — it writes only to its designated governance/ paths and triggers Yoda escalation

---

## 6. Human Access Matrix

| Persona | OC1 Local | Google Drive | MinIO Console | MinIO API | Notion | Postgres | Cloudflare Tunnel |
|---------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **Ken Mun (CTO)** | Admin (LAN direct / Tailscale remote) | Admin | Admin (LAN / Tailscale / CF Tunnel) | Admin (LAN / Tailscale / CF Tunnel) | Admin | Admin (Tailscale only) | ✅ (Email OTP → MVP) |
| **Angie (CEO)** | None | R/W (business files, Social, Marketing) | None currently (P1: R scoped prefix) | None (P1: R scoped prefix via CF Tunnel) | R/W (business stream) | None | Planned P1 (Telegram primary MVP) |
| **KL Marketing (P1+)** | None | R/W (Marketing, Social folders) | None (file access via Bridge UI P1+) | None (presigned URLs only) | R (relevant) | None | ✅ P1 (Google Workspace SSO) |
| **KL Developer (P1+)** | None | R | None (S3 API key only, scoped IAM) | R/W (dev-scoped prefix, API key) | R (relevant) | None | ✅ P1 (Google Workspace SSO) |
| **KL Support (P1+)** | None | R (support docs) | None | None | R (support tickets) | None | ✅ P1 (Google Workspace SSO) |
| **KL Admin (P1+)** | None | R/W (Admin folder) | None | None | R/W (admin scope) | None | ✅ P1 (Google Workspace SSO) |
| **P2 SME Clients (P2+)** | None | None | None | R (presigned URLs only, time-limited, tenant-scoped) | None | None | ❌ (via Citadel only) |

**Access path rules:**
- Ken local access: LAN direct during office session. Tailscale for remote. Cloudflare Tunnel for mobile (MVP action: TKT-0136 decision D1).
- Angie: Telegram primary (MVP). Cloudflare-tunneled webchat planned P1. Drive for file review. Never local filesystem path.
- KL Team: No access until P1 provisioning. All access via Cloudflare Access (Google Workspace SSO `@ainchors.com` domain).
- P2 Clients: No AInchors-internal access. Access via The Citadel + per-client Telegram bot + presigned URLs + Nexus Public REST API.
- **No persona** may access Postgres via Cloudflare Tunnel. Postgres is Tailscale-only forever.
- **No persona** may access OC2 Ollama API directly — Tailscale HIVE-only forever.

---

## 7. Approved Access Patterns

Agents and humans must follow these named patterns. Ad-hoc patterns that deviate
from the below without a CHG entry are violations.

---

**PATTERN-01: Agent Produces a Deliverable (Standard)**
> Trigger: Agent creates any human-readable output (doc, canvas, proposal, social post)
1. Write to local workspace first (`docs/`, `canvas/documents/`, `workspace-social/`)
2. Upload to MinIO under the agent's designated path (from minio-routing-policy.json)
3. Upload to Google Drive under the correct folder (File-Routing-Policy-v1.0.md Rule 1–6)
4. Confirm Drive upload success before marking deliverable done
5. On failure: log to `state/drive-sync-failures.json`, alert Ken at next heartbeat
6. Provide Ken with Drive link (never local path as durable reference)

---

**PATTERN-02: Agent Reads Shared Context**
> Trigger: Agent needs context owned by another agent or the platform
1. Read from `workspace/state/` shared keys only (e.g. active-work.json, minio-routing-policy.json)
2. Read from `memory/shared/` (aria-daily-brief.md, decisions.md)
3. Read from MinIO `ainchors-agent-memory/shared/handoffs/` for cross-agent handoffs
4. **Never** read another agent's workspace directory directly
5. **Never** read another agent's MEMORY.md or daily notes

---

**PATTERN-03: Ken Reviews a Document**
> Trigger: Agent produces a document for Ken to review
1. Upload to Google Drive (correct folder per File-Routing-Policy)
2. Share the Drive link with Ken in chat — never a raw local path unless in active LAN session
3. If Ken is in an active LAN/Tailscale session and requests the local path, provide full absolute path
4. After Ken reviews and approves: status → Tier 3 (Published). Log CHG. No further edits without new CHG.

---

**PATTERN-04: Content Approved → Publish to MinIO**
> Trigger: Ken approves a draft (social, blog, marketing)
1. Governance gate (Shield → Lex → Sage) must pass first
2. Agent moves file from draft prefix to approved/posted prefix in MinIO
   - Social: `ainchors-brand-code/social/*/drafts/` → `ainchors-brand-code/social/*/approved/` → `ainchors-brand-code/social/*/posted/`
3. Drive sync: move to `Social/Published/` folder in Drive
4. Log CHG entry (content-type, from-path, to-path, governance verdict)
5. Update `state/content-queue.json` status to `published`

---

**PATTERN-05: Credentials Management**
> Trigger: Any credential, API key, token, or secret must be stored or accessed
1. Credentials are stored ONLY in macOS Keychain via `scripts/secrets-init.sh` or `scripts/get-secret.sh`
2. No agent may write a credential to any file (workspace, state/, MinIO, Drive, Notion)
3. No agent may log a credential value to any output
4. API key rotation: update `openclaw.json` AND Keychain in the same CHG (L-008 rule)
5. If a credential is found in a file: treat as Tier 0 violation — escalate to Ken immediately, rotate the key

---

**PATTERN-06: Cross-Agent Data Handoff**
> Trigger: One agent needs to pass structured data or context to another
1. Write handoff file to `workspace/state/` (for simple shared state) OR
2. Write to MinIO `ainchors-agent-memory/shared/handoffs/{source-agent}/{target-agent}/` (for durable handoffs)
3. Record handoff in `state/active-work.json` (spawnedFrom, expectedDeliverables, awaitingResult)
4. Receiving agent reads from designated path — never reads source agent's workspace directly
5. Yoda orchestrates — always writes to `active-work.json` before spawning sub-agents

---

**PATTERN-07: Governance Review Gate**
> Trigger: Any asset destined for external delivery (blog, proposal, email, social, marketing)
1. Write draft to `/tmp/draft-{asset-name}-{date}.html` (or .md) — NEVER to final path yet
2. Spawn Shield, Lex, Sage sequentially (or via `scripts/content-governance-review.sh`)
3. If ANY returns FAIL: fix all flagged items → repeat from step 2
4. If WARN: apply fixes → recheck
5. Only when all three PASS: move from /tmp/ to final local path, then MinIO upload, then Drive upload
6. Log to `state/governance-review.log` and `state/lex-qa-log.json`
7. Append governance footer stamp to asset

---

**PATTERN-08: Client Deliverable Workflow**
> Trigger: Ahsoka or another agent produces a consulting deliverable for a client
1. Write draft to local `docs/` (agent-reference copy)
2. Run PATTERN-07 (governance gate) before any external delivery
3. Upload to Drive `Proposals/` or `EA Assessments/` (appropriate folder)
4. Upload to MinIO `ainchors-workspace-assets/consulting/client-deliverables/`
5. MinIO URL format: `https://ainchorsoc2as-mac-mini-1.tailfc3ed1.ts.net:9000/ainchors-workspace-assets/consulting/client-deliverables/{filename}`
6. Deliver to client via approved channel (email, Telegram, Citadel at P2) — never via local path

---

**PATTERN-09: Tier 0 Data Handling**
> Trigger: Any data classified Tier 0 (client PII, regulated data, credentials)
1. Store on OC1 local ONLY — no exceptions
2. Never write to MinIO, Drive, Notion, or any cloud service
3. Never pass to another agent without explicit Ken approval + CHG entry
4. For AI processing: use Gemma4 (Ollama, fully local) — never Claude API for Tier 0
5. PII scan mandatory before any document is chunked or embedded in pgvector
6. `pii_present = TRUE` flag gates embedding — Compliance Agent (Lex/Warden) must approve
7. Violation: any Tier 0 data found outside OC1 local → immediate escalation to Ken, rotate affected credentials

---

**PATTERN-10: Generated Media Delivery**
> Trigger: Agent generates an image or video asset (HF/FLUX/Spark)
1. Store in MinIO `ainchors-generated-media/` under appropriate path
2. Generate a presigned URL (time-limited) for delivery
3. MinIO URL: `https://ainchorsoc2as-mac-mini-1.tailfc3ed1.ts.net:9000/ainchors-generated-media/{path}`
4. No Drive copy unless Ken explicitly requests archival
5. No local persistence beyond temporary generation path
6. Presigned URL time limit: max 24h for internal; max 7 days for client delivery (P2)

---

**PATTERN-11: State File Mutation**
> Trigger: Any agent needs to update a state file (state/*.json)
1. State files are Tier 1 — OC1 local only (state/ never goes to Drive or MinIO directly)
2. For ticket-tracked state: use `scripts/ticket.sh` — NEVER write directly to tickets.json
3. For JSON array state files: read full file, parse, append in memory, write full file (never use edit tool on JSON arrays)
4. Automated backups of state/ to MinIO workspace-assets are Forge/cron-managed only
5. Any new state file with error/status/failure fields must have an obs-collector.sh CHECK added in the same CHG

---

**PATTERN-12: New Agent Workspace Isolation**
> Trigger: A new agent is provisioned or spawned
1. New agent reads only its own workspace directory and `workspace/state/` shared keys
2. Agent must not read or write to other agents' workspace directories
3. MEMORY.md is loaded only in main session — not in sub-agents or isolated crons
4. Sub-agents use `lightContext: true` unless explicitly requiring MEMORY.md context
5. Cross-agent context: pass via PATTERN-06 (shared state or handoffs) only
6. New agent SOUL.md must remain ≤ 5,000 chars (hard limit 10,000 chars)

---

**PATTERN-13: Drive Sync Failure Recovery**
> Trigger: A Drive upload fails after agent produces a deliverable
1. Agent logs failure immediately to `state/drive-sync-failures.json`
2. Agent alerts Ken at next heartbeat (or immediately if Tier 2/3 deliverable)
3. Agent retains local copy — do not delete until Drive sync confirmed
4. Retry Drive upload on next heartbeat or explicit Ken instruction
5. Forge obs-collector.sh monitors drive-sync-failures.json for unresolved entries

---

**PATTERN-14: Angie Receives Content**
> Trigger: Any content produced for Angie's review or action
1. Content delivered via Drive (Angie accesses Drive from any device)
2. Summaries/notifications delivered via Aria → @AInchorsAriaBot → Angie Telegram (8141152780)
3. Yoda NEVER sends directly to Angie's Telegram from Yoda context (cross-bot violation)
4. Crons targeting Angie MUST use `accountId: "aria"` in delivery spec
5. Never share a local filesystem path with Angie — she has no OC1 local access
6. Tier 0 data: never delivered to Angie without Ken approval

---

**PATTERN-15: Postgres Access**
> Trigger: Any agent or human needs to access the Postgres database
1. Agents access via loopback API (localhost:5432) only
2. Ken accesses via Tailscale + psql or admin tooling (Tailscale FQDN)
3. NEVER expose Postgres via Cloudflare Tunnel — not now, not ever
4. NEVER expose Postgres on a public port (direct port exposure rejected — see EA-Addendum-Storage-Access-Architecture-v0.1.md Option D)
5. All schema changes via migration scripts with CHG entry
6. tenant_id column on all tables from P1 (default: 'ainchors') — mandatory for P2 readiness

---

**PATTERN-16: User/Client Submits Content to Nexus**
> Trigger: A user or client submits a file, document, or data object via any approved inbound channel (Section 8.1)
1. Content received via approved inbound channel; Yoda or receiving agent acknowledges receipt
2. Intake agent logs receipt in `state/intake-log.json` (submitter, channel, timestamp, filename, size)
3. Shield (P2) or Yoda (MVP) classifies content — assigns data tier (0–3)
4. PII scan executed (Presidio at P2; manual Lex/Shield review at MVP) — result logged
5. Virus/integrity check: file type validation, size limits enforced, no executable content
6. Content stored in tier-appropriate location per Section 8.3
7. Yoda notified of intake completion; intake record finalised in `state/intake-log.json`
8. Yoda routes content to relevant agent for processing (PATTERN-06 for handoff)
9. Agent processes content → produces structured artifact (Stage 2 of Section 8.5)
10. Artifact promoted per context promotion pipeline (Stages 3–5 of Section 8.5) as appropriate
11. Raw file retained per lifecycle rules (Section 8.7)

---

## 8. Inbound Content Flow — User/Client → Nexus

This section governs how content submitted by users or clients **into** the Nexus
platform is received, classified, stored, accessed, and promoted through the
context and knowledge pipeline. Together with the outbound flow (Nexus/agents
→ users) covered in Sections 1–7, this completes the bidirectional data flow
governance mandate.

---

### 8.1 Inbound Channels

The following are the **approved channels** through which users and clients may
submit content to Nexus. No other inbound channels are accepted.

| Channel | Description | Availability |
|---------|-------------|-------------|
| **Telegram** | Files, images, documents sent by Ken or Angie via their Telegram bots | ✅ MVP |
| **OpenClaw Webchat** | File attachments uploaded directly in the OpenClaw chat interface | ✅ MVP |
| **Google Drive Sync** | Files placed in designated Drive folders, pulled by `drive-sync.sh` | ✅ MVP |
| **The Citadel** | Client portal file upload API — structured intake form + upload endpoint | 🔜 P2 |
| **Nexus API** | Programmatic content submission via REST endpoint | 🔜 P2+ |
| **Email** | Structured email ingestion via Gmail (gog mail integration) | 🔜 P2+ |
| **Direct agent request** | Agent asks user/client to provide a file; user delivers via any channel above | ✅ MVP |

**Rule:** Content submitted outside these approved channels must be rejected.
Agents must not accept files from ad-hoc sources (unverified URLs, unauthorised
systems) without explicit Ken instruction and a CHG entry. Rejection is logged
in `state/intake-log.json`.

---

### 8.2 Intake Processing Pipeline

Every piece of user-submitted content **must** pass through the following
mandatory, sequential pipeline before storage or agent access.

| Step | Action | Owner (MVP) | Owner (P2) | Output |
|------|--------|-------------|------------|--------|
| **1. Receipt** | Log content receipt: submitter, channel, timestamp, filename, type, size | Yoda / receiving agent | Nexus API / The Citadel | Entry in `state/intake-log.json` |
| **2. Classification** | Determine data tier (0–3) based on content type, submitter identity, and sensitivity | Yoda | Shield (automated) | Classification tag assigned |
| **3. PII Scan** | Mandatory for any client-submitted content | Lex/Shield manual review | Presidio pipeline | PII flag: present / absent / unclear |
| **4. Virus/Integrity Check** | File type validation, size limit enforcement (max 50MB), no executable content (.exe, .sh, .py, .bat, .js) | Yoda / Forge | Automated scanner | Pass / Fail |
| **5. Storage Assignment** | Route to tier-appropriate storage per Section 8.3 | Yoda | Automated routing | Storage path confirmed |
| **6. Intake Record** | Finalise intake log entry: submitter, timestamp, classification, storage path, PII result, processing status | Yoda | Automated | `state/intake-log.json` updated |

**Failure handling:** If any step fails or returns an ambiguous result, content
is quarantined to `/tmp/intake-quarantine/`. Yoda is notified and Ken is alerted
at the next heartbeat. For Tier 0 content or PII-flagged content: Ken is alerted
immediately. Quarantined content retained for 30 days (see Section 8.7).

---

### 8.3 Storage Allocation for Inbound Content

Classification from Step 2 of the intake pipeline determines storage destination.
This extends the storage rules in Section 4 specifically for inbound content.

| Tier | Classification | Primary Storage | Secondary Storage | Prohibited |
|------|---------------|-----------------|-------------------|----------|
| **Tier 0** | Client PII, regulated data, credential-adjacent | OC1 local ONLY — `workspace/intake/tier0/` (encrypted at rest) | Postgres encrypted blob store (P2) | MinIO, Drive, Notion, any cloud service |
| **Tier 1** | AInchors internal operational content | OC1 local — `workspace/intake/tier1/` | Drive (human-facing summaries only); MinIO `ainchors-workspace-assets/` private prefix | Cloud-first storage; Drive for Tier 0 |
| **Tier 2** | Working content, in-progress drafts | OC1 local (working copy); MinIO `ainchors-workspace-assets/` or `ainchors-brand-code/` | Drive (for Ken/Angie review) | Tier 0 rules apply if reclassified |
| **Tier 3** | Approved/published, client-facing deliverables | MinIO public-readable prefix; Drive (SSOT) | Notion (approved frameworks, decisions) | Silent overwrites; editing without CHG |

**Immutability rule:** Classification is immutable once assigned by the intake
pipeline. Reclassification to a lower-restriction tier requires a CHG entry and
Ken approval. Unauthorised reclassification is a **V1 violation**.

---

### 8.4 Agent Access to User-Submitted Inbound Content

This section defines which agents can access user-submitted content after intake.
Access is governed by the same tier rules as outbound content (Section 5), with
additional inbound-specific constraints.

| Agent | Tier 0 | Tier 1 | Tier 2 | Tier 3 | Conditions |
|-------|:------:|:------:|:------:|:------:|----------|
| **Yoda 🟢** | R (Ken instruction + CHG) | R | R/W | R/W | Orchestration only for Tier 0 |
| **Ahsoka 🌙** | R (engagement-scoped) | None | R | R | Tenant-scoped at P2; engagement-scoped at MVP |
| **Spark ✨** | None | None | R (brand/marketing only) | R | No access to Tier 0 or operational Tier 1 |
| **Shield 🛡️ / Lex ⚖️ / Sage 🧪** | R (review only) | R (review only) | R (review only) | R | Triggered by Yoda; read-only; intake review purpose |
| **Atlas 🏛️ / Thrawn 🔷** | None | R (platform-relevant) | R | R | Architecture/operational content only |
| **Forge 🔧** | None | R (intake pipeline mgmt) | R | R | Operational/infrastructure access only |
| **All other agents** | None | None | None | None | No access without explicit Yoda routing |

**Access rule (Tier 0):** No agent may access Tier 0 user-submitted content without:
(1) Yoda routing the content with an explicit task;
(2) Ken having approved the access (CHG entry required);
(3) Access being logged in the Postgres audit trail.

This access flow is governed by **PATTERN-16** (see Section 7).

---

### 8.5 Context Promotion Pipeline

User-submitted content does **not** automatically promote through context stages.
Each stage transition requires explicit agent action. Content must not skip
stages — doing so constitutes a **V1 violation**.

**Stage 1 — Raw Intake**
Content received, classified, and stored per Sections 8.2–8.3.
Not yet available in any agent context. Status: `intake-logged`.

**Stage 2 — Agent Processing**
Yoda routes content to the relevant agent for processing (via PATTERN-06).
The agent reads the raw file, extracts relevant information, and produces a
**structured artifact** (summary, extracted data, analysis). The raw file
remains in its intake storage location — only the artifact advances.
Status: `agent-processed`. Artifact stored: `workspace/state/intake-artifacts/{intake-id}.md`

**Stage 3 — Shared Context**
The structured artifact is written to shared context — either
`workspace/state/` (for shared-key context) or a designated shared file
(e.g. `memory/shared/context-for-aria.md`). Available to other agents via
PATTERN-02. The raw file is not shared — only the structured artifact.
Status: `context-promoted`.

**Stage 4 — Memory Promotion**
For significant, recurring content (e.g. client brief, standing business rules,
project brief), the artifact is promoted to long-term memory:
- Yoda’s MEMORY.md (main session only) for platform-wide context
- Postgres `agent_decisions` or `agent_shared_state` for durable shared state
- Notion Holocron page for approved frameworks or client context documents
Promotion requires Ken’s acknowledgement for Tier 0/1 content.
Status: `memory-promoted`.

**Stage 5 — RAG Indexing**
Reference-class content (documents, policies, client knowledge base) is ingested
into the pgvector RAG pipeline:
- Chunked and embedded via `nomic-embed-text` (Ollama, fully local — no external embedding API)
- Indexed in Postgres `knowledge_chunks` / `knowledge_documents` tables
- Accessible to agents via semantic search
- Initiated by Forge or Yoda only, with Ken approval
See Section 8.6 for full RAG ingestion rules.
Status: `rag-indexed`.

---

### 8.6 RAG Ingestion Rules

| Rule | Detail |
|------|--------|
| **Authorised initiators** | Forge or Yoda only. Ken approval required before any new content ingestion. |
| **Tier 0 in RAG** | Forbidden at MVP. At P2: permitted only in a tenant-isolated vector namespace. Never in the shared (`ainchors`) namespace. |
| **Required chunk metadata** | Source file path, submitter identity, classification tier, ingestion timestamp, PII scan result, engagement ID / tenant ID |
| **Ingestion log** | All RAG ingestion events logged to `state/rag-ingestion-log.json` with full metadata |
| **Duplicate detection** | Check for existing document by content hash before ingestion. Duplicate ingestion = V2 violation. |
| **Document size limit** | Max 10MB per document. Larger documents must be pre-processed (split or summarised) before ingestion. |
| **Purge on offboard** | At client offboarding (P2), all vector chunks for that tenant namespace are purged. Yoda initiates, Forge executes, logged to CHG entry. |
| **Embedding model** | `nomic-embed-text` via Ollama (OC2, fully local). Never an external embedding API for any content tier. |

---

### 8.7 Lifecycle and Retention for Inbound Content

| Content Type | Retention Period | Storage | Notes |
|-------------|-----------------|---------|-------|
| **Tier 0 raw intake files** | Indefinite (per DEC-009) | OC1 local only (encrypted at rest) | Never purged without explicit Ken instruction |
| **Tier 1–2 raw intake files** | 90 days rolling unless promoted to Tier 3 | OC1 local / MinIO | Forge cron auto-purges after 90 days; purge event logged |
| **Tier 3 files** | Indefinite | Drive (SSOT) + MinIO | Immutable after approval; any change requires new version + CHG |
| **Quarantined content** | 30 days then Ken decides | `/tmp/intake-quarantine/` | Yoda alerts Ken at intake; Ken decides: retain, promote, or purge |
| **Context artifacts** | Expire with session/engagement | `workspace/state/intake-artifacts/` | Configurable retention period at P2 |
| **Intake log** | Indefinite (audit requirement) | `state/intake-log.json` / Postgres | Never purged; required for compliance and violation audit trail |
| **RAG-indexed content** | Active while source relationship is active | pgvector (Postgres) | Purged at client offboarding (P2); Yoda + Forge execute purge |

---

## 9. Violation Definition & Capture

### 9.1 What Constitutes a Violation

A violation occurs when any agent or human deviates from this policy. Violations
are classified by severity.

| Severity | Code | Examples |
|----------|------|---------|
| **CRITICAL** | V0 | Tier 0 data written to cloud (MinIO, Drive, Notion). Credentials found in a file. Client PII transmitted via Claude API. Postgres exposed via public tunnel. |
| **HIGH** | V1 | Deliverable shared with Angie or external via local path. Agent writing to another agent's workspace directory. Direct write to tickets.json bypassing ticket.sh. State file with errors not wired to obs-collector CHECK. |
| **MEDIUM** | V2 | Drive sync not performed after deliverable creation. MinIO URL shared as `s3://` or IP instead of Tailscale FQDN. `~` or relative paths used in tool calls. New MinIO path created outside minio-routing-policy.json. |
| **LOW** | V3 | Missing classification tag on a new file. Drive folder duplication (created without searching first). Missing CHG entry for a content state change. |

### 9.2 Specific Violations (Non-Exhaustive)

The following are explicit violations per existing RULES.md, extended to this policy:

- **ABSOLUTE PATH VIOLATION:** Using `~`, `./`, `$HOME` in any write/read/edit tool call or cron prompt → V2
- **MINIO URL VIOLATION:** Using `s3://`, raw IP, or `local/` alias in any agent output or document → V2
- **TICKET BYPASS VIOLATION:** Writing directly to tickets.json without ticket.sh → V1
- **STRATEGY-GATE VIOLATION:** Implementing a task when a dependency doc is still DRAFT FOR REVIEW → V1
- **CROSS-WORKSPACE VIOLATION:** Agent reads/writes to another agent's workspace directory → V1
- **TIER-0 CLOUD VIOLATION:** Any Tier 0 data written outside OC1 local → V0 (CRITICAL)
- **CREDENTIAL FILE VIOLATION:** Credential stored in any file rather than Keychain → V0 (CRITICAL)
- **GOVERNANCE BYPASS VIOLATION:** External-facing asset delivered without governance gate → V1
- **DRIVE SYNC OMISSION:** Human-readable deliverable created without Drive upload → V2
- **POSTGRES EXPOSURE VIOLATION:** Postgres accessible via Cloudflare Tunnel or public port → V0 (CRITICAL)
- **TELEGRAM ROUTING VIOLATION:** Yoda context sends directly to Angie Telegram (8141152780) without Aria routing → V1
- **MEMORY CONTEXT VIOLATION:** MEMORY.md loaded in a sub-agent or isolated cron without explicit justification → V2

### 9.3 How Violations Are Captured

**Automated detection:**
- **Forge auto-heal.sh:** Nightly checks including file path format, ticket discipline, Drive sync, MINIO URL format — violations logged to `state/access-violations.json`
- **Warden (15-min cycle):** Governance gate bypass detection (state/lex-qa-log.json), content published without clearance (state/content-queue.json), model drift — logs violation event to obs.db
- **obs-collector.sh (every 5 min):** Monitors state/access-violations.json for new entries, surfaces to obs.db
- **telegram-routing-audit.sh:** Validates all cron delivery specs for correct accountId — run by pvt.sh

**Manual audit:**
- Atlas quarterly compliance review (see Section 9)
- Ken can trigger on-demand via `/diagnostics`

**Violation log format — `state/access-violations.json`:**
```json
{
  "violations": [
    {
      "id": "V-YYYYMMDD-NNN",
      "timestamp": "ISO-8601",
      "severity": "CRITICAL|HIGH|MEDIUM|LOW",
      "code": "V0|V1|V2|V3",
      "type": "tier0-cloud-write|credential-file|ticket-bypass|...",
      "agent": "yoda|aria|spark|...",
      "description": "Human-readable description of what happened",
      "filePath": "path if applicable",
      "detectedBy": "forge|warden|obs|manual",
      "status": "open|resolved",
      "chgRef": "CHG-NNNN",
      "resolvedAt": null
    }
  ]
}
```

### 9.4 Escalation Path

```
Forge detects → logs to state/access-violations.json → obs-collector picks up
→ Yoda surfaces to Ken at next heartbeat (or immediately for V0/CRITICAL)
→ Ken acknowledges → CHG entry required → resolution within 1 sprint
→ Violation marked resolved with chgRef
```

V0 (CRITICAL) violations bypass heartbeat — Yoda alerts Ken immediately via Telegram.

---

## 10. Enforcement & Review

### 10.1 Enforcement Date
This policy is enforced from the date of Ken Mun's written approval. Approval
recorded in: Notion Decisions DB, MEMORY.md, and this document (update status
from DRAFT FOR REVIEW to LIVE — Ken Mun, CTO, {DATE}).

### 10.2 Agent Propagation
Within one sprint of approval, Yoda must ensure:
- This policy is referenced in all agent RULES.md files (or SOUL.md where appropriate)
- `state/minio-routing-policy.json` is confirmed current (Atlas gap analysis may update paths)
- Forge auto-heal.sh is updated with access-violation detection checks
- Warden monitoring scope expanded to include access pattern compliance checks
- obs-collector.sh CHECK added for `state/access-violations.json`

Propagation tracked under a CHG entry raised at approval time.

### 10.3 Quarterly Review (Atlas)
- **Cadence:** Quarterly (Q1: Feb, Q2: May, Q3: Aug, Q4: Nov — aligned to sprint gates)
- **Owner:** Atlas 🏛️ with Yoda orchestration
- **Scope:** Review violation log, assess pattern coverage gaps, propose policy updates
- **Output:** Atlas EA memo → DRAFT FOR REVIEW → Ken approves → policy version incremented
- **First review:** Q3 2026 (August) or at P1 gate, whichever comes first

### 10.4 Policy Change Process
All changes to this policy require:
1. Atlas drafts updated section(s) → DRAFT FOR REVIEW
2. Ken approves (explicit written acknowledgement)
3. Version number incremented (v1.0 → v1.1 for minor, v2.0 for major)
4. CHG entry logged via changelog-append.sh
5. All agent RULES.md references updated in same CHG

### 10.5 Violation SLA
- V0 (CRITICAL): Acknowledged by Ken within 1 hour. Resolved within 24 hours. CHG required.
- V1 (HIGH): Surfaced at next heartbeat. Resolved within 1 sprint. CHG required.
- V2 (MEDIUM): Surfaced in daily standup if unresolved >24h. Resolved within 2 sprints.
- V3 (LOW): Surfaced in weekly sprint review. Resolved within 2 sprints or accepted as risk.

---

## 11. Open Decisions for Ken

The following items could not be fully resolved by Atlas without Ken's direction.
These do not block the policy's approval — they are scoped future enhancements.

### OD-01: Access Violations State File — obs-collector CHECK
**Gap:** `state/access-violations.json` does not yet exist and has no obs-collector CHECK.
**Needed:** Forge to create the file and add the CHECK to obs-collector.sh in the same CHG.
**Recommendation:** Ken to assign to Forge as a sprint item at policy approval.
**Blocks:** Full automated violation detection (manual audit possible until resolved).

### OD-02: Angie's MinIO Access at P1
**Gap:** The EA-Addendum notes Angie will get limited MinIO read access at P1 (scoped prefix via Cloudflare Tunnel). The specific prefix and IAM policy are not yet defined.
**Needed:** Ken to confirm which buckets/prefixes Angie needs read access to at P1.
**Recommendation:** `ainchors-brand-code/social/*/approved/` and `ainchors-brand-code/marketing-materials/` read-only.
**Blocks:** P1 IAM provisioning for Angie.

### OD-03: KL Developer S3 IAM Scope
**Gap:** KL Developer role is noted in the EA-Addendum as getting "dev-scoped IAM" at P1, but the specific scoped prefixes and policies are not yet defined.
**Needed:** Ken to define what prefixes the KL developer needs API access to.
**Recommendation:** `ainchors-workspace-assets/technology/` read + write on a `dev/` sub-prefix only. Ken to confirm.
**Blocks:** P1 KL team IAM provisioning.

### OD-04: Postgres Access via Cloudflare Tunnel (Explicit Prohibition Confirmation)
**Position:** This policy explicitly prohibits Postgres access via Cloudflare Tunnel (Tailscale-only). This is Atlas's recommendation. Ken should explicitly confirm this is the intent to lock it as non-negotiable.
**Needed:** Ken's written confirmation (or objection) so this can be promoted to a Rule in RULES.md.

### OD-05: Violation Log in Notion
**Gap:** Currently, access violations are captured in `state/access-violations.json`. For visibility and audit trail, should violations also be logged to a Notion DB (similar to Incidents and Tickets)?
**Recommendation:** Yes — create a `Notion: Access Violations DB` and have Forge sync V0/V1 violations there automatically.
**Blocks:** Full Notion-based audit trail for governance compliance reporting.

---

## Appendix A — Storage Layer Quick Reference

| Layer | SSOT For | Human Access | Agent Access | Tier 0 OK? |
|-------|---------|:---:|:---:|:---:|
| OC1 Local | State, config, scripts, working files | Ken (LAN/Tailscale) | ✅ Primary | ✅ Yes (local only) |
| Google Drive | Human-readable deliverables | Ken, Angie, KL Team | Via gog | ❌ Never |
| MinIO | Agent deliverables, media, memory | Ken (admin/presigned) | ✅ Primary | ❌ Never |
| Notion Holocron | Decisions, tickets, sprints, approved frameworks | Ken, Angie, KL Team | Via API | ❌ Never |
| Agent Session Memory | Agent context, MEMORY.md, daily notes | Ken (indirect) | ✅ Own only | ❌ Never |
| Postgres | Audit log, shared state, vector store | Ken (Tailscale) | ✅ Loopback | ❌ Never (unencrypted) |

---

## Appendix B — MinIO Bucket × Classification Matrix

| Bucket | Permitted Classifications | Prohibited |
|--------|--------------------------|-----------|
| `ainchors-brand-code` | Tier 2 (working drafts), Tier 3 (published) | Tier 0, Tier 1 state files |
| `ainchors-workspace-assets` | Tier 1 (backup), Tier 2 (working), Tier 3 (published) | Tier 0 |
| `ainchors-generated-media` | Tier 2 (working), Tier 3 (published) | Tier 0, Tier 1 |
| `ainchors-agent-memory` | Tier 1 (internal), Tier 2 (handoffs) | Tier 0 |

---

## Appendix C — Agent Workspace Directory Map

| Agent | Primary Workspace |
|-------|------------------|
| Yoda 🟢 | `/Users/ainchorsoc2a/.openclaw/workspace/` |
| Aria 🔵 | `/Users/ainchorsoc2a/.openclaw/workspace-business/` |
| Atlas 🏛️ | `/Users/ainchorsoc2a/.openclaw/workspace-architect/` |
| Thrawn, Forge, Shield, Lex, Sage, Warden | Designated workspace dirs (platform-internal) |
| Spark ✨ | `/Users/ainchorsoc2a/.openclaw/workspace-social/` |
| Ahsoka, Lando, Mon Mothma | Dedicated workspace dirs (business stream) |

**Shared context files** (readable by all agents): `/Users/ainchorsoc2a/.openclaw/workspace/state/` (scoped keys), `/Users/ainchorsoc2a/.openclaw/workspace/memory/shared/`

---

*Atlas 🏛️ — Enterprise Architect, AInchors*
*Requested: Ken Mun (CTO) | TKT-0161 | 2026-05-12*
**Status:** APPROVED — Ken Mun, 2026-05-12 (via TKT-0136)
*Updated: 2026-05-12 — Section 8 added (Inbound Content Flow); PATTERN-16 added; sections renumbered (old 8→9, 9→10, 10→11); bidirectional flow coverage completed (Ken Mun review feedback)*
*Next version: v1.1 at Q3 2026 review (or P1 gate, whichever first)*
