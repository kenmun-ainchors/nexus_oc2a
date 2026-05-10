# TKT-0124 Architecture Amendment: Hybrid Storage Model
**Decision date:** 2026-05-10 13:37 AEST | **Approved by:** Ken Mun (CTO)
**Amends:** state/atlas-tkt-0124-ea-atlas.md (Atlas EA Assessment)
**Scope:** AInchors P1 ONLY

---

## Decision

AInchors will use a **hybrid storage model for P1 internal use only:**

| Layer | Solution | Status |
|-------|----------|--------|
| **Human layer** | Google Workspace (Drive) | ✅ Live |
| **Agent/technical layer** | MinIO on OC1 | 🔨 To build |

**Rationale:** AInchors is on Google Workspace. Drive already provides everything the human layer needs (file access from Windows, KL team access from Malaysia, Angie collaboration, Brand Code authoring in Google Docs). Zero new infrastructure for the human layer. MinIO scoped to agent-specific requirements only.

---

## P2 Strategy — UNCHANGED

At P2, all storage (human + agent + client) moves to AWS S3 Sydney (S3-compatible). Google Drive is retired for non-AInchors entities. **This model cannot be extended to P2 clients** — multi-tenant architecture cannot support different storage models per client. S3-compatible object store is the standard from P2 onward. No exceptions.

---

## Revised Architecture

### Human Layer — Google Drive (AInchors only)

| Use case | Drive folder | Who |
|----------|-------------|-----|
| Business documents | AInchors — Yoda Working Files/EA Assessments | Ken, Angie |
| Sprint docs, reports | AInchors — Yoda Working Files/Sprint Docs | Ken |
| Brand Code authoring | Brand Code (Google Docs) | Angie (primary author), KL team (review) |
| KL team file sharing | Shared Drive folder (to create) | Angie + KL team |
| Generated images | AInchors — Yoda Working Files/Generated Images | Ken |
| Any file Ken needs remotely | Upload via `gog drive upload` | Yoda |

**Delivery rule:** Any file Ken needs to access from Windows → Yoda uploads to Drive. No exceptions until MinIO is live.

### Agent Layer — MinIO on OC1

**Reduced from 6 buckets to 4:**

| Bucket | Purpose | Change from original EA |
|--------|---------|------------------------|
| `ainchors-agent-memory` | Aria + business agent persistent memory | ✅ Unchanged |
| `ainchors-generated-media` | hf-generate-image.sh output, presigned URL delivery | ✅ Unchanged |
| `ainchors-workspace-assets` | Internal ops, script outputs, state backups | ✅ Unchanged |
| `ainchors-brand-code` | Structured Brand Code (JSON/MD) for agent consumption | ✅ Unchanged |
| ~~`ainchors-documents`~~ | ~~Business documents~~ | ❌ Removed → Google Drive |
| ~~`ainchors-business-docs`~~ | ~~Business file repository~~ | ❌ Removed → Google Drive |

**Tailscale Funnel scope reduced:** Funnel now only needed for presigned URL delivery (generated-media). Human file browsing handled by Drive. No MinIO Console via Funnel needed.

---

## Revised AC List

| AC | Description | Change |
|----|-------------|--------|
| AC1 | MinIO Docker, survives restart, health check | Unchanged |
| AC2 | 4 buckets: agent-memory, generated-media, workspace-assets, brand-code | **Reduced from 6** |
| AC3 | minio-upload.sh with presigned URLs, Tailscale accessible | Unchanged |
| AC4 | Tailscale Serve (internal) + Funnel (presigned URL delivery only) | **Reduced scope** |
| AC5 | hf-generate-image.sh uploads to MinIO, returns presigned URL | Unchanged |
| AC6 | Credentials in Keychain | Unchanged |
| AC7 | Endpoint-agnostic (MINIO_ENDPOINT env var) | Unchanged |
| AC8 | PVT 9/9 | Unchanged |
| AC9 | brand-code bucket with versioning enabled | Unchanged |
| AC10 | Aria read/write to agent-memory bucket | Unchanged |
| AC11 | Versioning on agent-memory bucket (Atlas) | Unchanged |
| AC12 | Classification + PII tags on all uploads (Atlas) | Unchanged |
| AC13 | Daily mc mirror backup cron (Atlas) | Unchanged |
| AC14 | MinIO health in health-check.sh + Telegram alert (Atlas) | Unchanged |
| AC15 | Brand Code bucket with object lock at creation (Atlas) | Unchanged |
| **AC16** | **Google Drive folder structure live, gog upload working** | **NEW — already done** |
| **AC17** | **Brand Code in Google Docs (human-readable) synced/aligned with MinIO brand-code bucket** | **NEW** |

---

## What This Means for the Build

MinIO build is now **smaller and more focused:**
- 4 buckets instead of 6
- No KL team MinIO onboarding needed (Drive handles it)
- No MinIO Console Funnel needed
- Funnel only needed for presigned URL endpoints (generated-media)

**Estimated effort reduction:** M → S (half day vs full day)

---

## P2 Transition Note

When P2 begins:
1. All MinIO agent-layer content migrates to AWS S3 Sydney (`mc mirror`)
2. Drive is retained for AInchors-internal use only (it's free, it works)
3. Client-facing content flows exclusively through S3
4. Multi-tenant isolation: S3 bucket-per-tenant or prefix-per-tenant (per DataMemory P2 design)

Drive never becomes a client data store. S3 is the multi-tenant standard.
