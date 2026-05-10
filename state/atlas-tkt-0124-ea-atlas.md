# EA Assessment — TKT-0124: Interim Business Data + Agent Memory Platform
**Author:** Atlas 🏛️ — Enterprise Architect, AInchors
**Ticket:** TKT-0124
**Date:** 2026-05-10
**Status:** FINAL — For Ken Mun (CTO) review
**Scope:** OC1 interim implementation + transition roadmap to P2 and beyond
**Requested by:** Ken Mun (CTO)

---

## Executive Summary

TKT-0124 establishes the interim blob/object storage and agent memory layer for AInchors P1 operations. The four required capabilities — remote file access (KL team), business file repository (Angie + KL staff), agent business memory (Aria + business-stream agents), and Brand Code knowledge base — are well-scoped for a single S3-compatible object store solution.

**Recommendation: MinIO on Docker (OC1) is the correct P1 interim choice.** It directly maps to the P2 target architecture (S3-compatible), runs on existing Docker infrastructure, satisfies Australian data sovereignty requirements, and provides a clean migration path to AWS S3 Sydney or a self-hosted NAS cluster post-TRIGGER-02 without changing any agent or application code.

**Critical design principle (from DataMemory_P1P4_Roadmap.md):** Use `MINIO_ENDPOINT` abstraction at all integration points from day one. Every agent, script, and workflow must reference the endpoint via environment variable — not hard-coded. This is the single most important implementation constraint for a zero-friction transition to P2.

---

## Section 1: Architecture Assessment

### 1.1 Is MinIO on OC1 the Right Interim Choice?

**Short answer: Yes, with appropriate scope discipline.**

MinIO is the S3-compatible object store that directly mirrors the P2 target in the DataMemory_P1P4_Roadmap.md (Section 3, P2 Data Types: *"S3-compatible object store (AWS S3 Sydney or MinIO self-hosted) for document storage. Presigned URLs for secure access."*). Choosing MinIO now means:

- Agent code, scripts, and presigned URL patterns written today will work **unchanged** against AWS S3 Sydney in P2
- The same AWS SDK / boto3 / MinIO SDK calls are compatible
- Bucket naming conventions established now transfer directly
- No re-architecture; only an endpoint swap at migration

**Alternatives considered:**

| Option | Verdict | Rationale |
|--------|---------|-----------|
| **MinIO on Docker (OC1)** | ✅ RECOMMENDED | S3-compatible, Docker-native, runs on existing OC1 infrastructure, direct migration path to AWS S3, open source, Australian soil, zero external dependency |
| AWS S3 Sydney (now) | ❌ Premature | Adds cloud cost, external dependency, and internet-only access for internal tools. Skips P1 → P2 hardware investment cycle. OC2 arrival in Jul changes the calculus. |
| Cloudflare R2 | ❌ Excluded | Data residency: Cloudflare R2 does not guarantee Australian soil. Violates S2 data sovereignty requirement. |
| Backblaze B2 | ❌ Excluded | Same residency problem. US-domiciled storage. |
| Nextcloud on Docker | ❌ Misfit | Nextcloud is a collaboration platform, not an object store. No presigned URL native support. Does not map to S3 API — agents would need separate integration. Over-engineered for the file-sharing use case. |
| Synology NAS (OC1) | ❌ Not yet available | NAS arrives with OC2 hardware. Not available for P1 interim. Will be incorporated in P2 transition. |
| Local filesystem + Tailscale | ❌ Weak | No object store semantics, no presigned URLs, no agent-native SDK support, no versioning. Acceptable only for emergency fallback. |

**Verdict:** MinIO is the only option that satisfies all four requirements (remote access, file repo, agent memory, Brand Code) with a clean P2 migration path and zero S3 API lock-in risk.

---

### 1.2 OC1 Constraints and Fit

| Constraint | Detail | Mitigation |
|------------|--------|-----------|
| **Storage capacity** | Mac Mini M4 24GB internal NVMe. MinIO data directory competes with Ollama models, Postgres, OS. | Designate a dedicated MinIO data path. Monitor with `df -h` threshold alert at 80% via health-check.sh. External USB SSD acceptable for overflow pending NAS arrival. |
| **Memory** | 24GB shared across all services. MinIO at idle: ~200MB. Under load: ~500MB. Acceptable. | Set Docker memory limit: `--memory=2g`. MinIO does not need more in P1 load profile. |
| **Concurrency** | OC1 is also primary OpenClaw production host. MinIO I/O under heavy agent load may compete. | Separate Docker network. Rate-limit agent upload operations. Async uploads preferred over synchronous blocking. |
| **Single-node HA** | No HA at P1. MinIO runs single-node. If OC1 is down, object store is unavailable. | Acceptable for P1 internal ops. Not acceptable at P2. Daily backup via `mc mirror` to external location. |
| **Internet bandwidth** | Residential internet (assumed). KL team access via Tailscale Funnel. | Funnel routes via Tailscale relay nodes — adequate for document-sized files. Large media generation batches should be queued off-peak. |

**OC1 fit rating:** ✅ Appropriate for P1 interim scope. Not intended to run beyond TRIGGER-02 (OC2 commissioning ~27 Jul 2026).

---

### 1.3 Data Sovereignty and S2 Compliance

| Requirement | Status | Detail |
|-------------|--------|--------|
| **Australian soil** | ✅ Compliant | MinIO data stored on OC1 NVMe in Melbourne. No data leaves Australian soil. |
| **S2: Tailscale-only (internal)** | ✅ Compliant | All internal access (Ken Windows, Yoda agents) via Tailscale Serve. Zero public internet exposure for internal endpoints. |
| **S2: Funnel (KL team)** | ⚠️ Considered | Tailscale Funnel exposes a public HTTPS endpoint proxied through Tailscale's relay infrastructure. Data transits Tailscale's network (US-based). For INTERNAL and CONFIDENTIAL business documents, this is an acceptable P1 trade-off given the team access requirement. It is NOT acceptable for RESTRICTED or regulated data. |
| **Credential security** | ✅ Compliant | MinIO root + service account credentials stored in macOS Keychain only. Never in plaintext files, never in git. |
| **Encryption in transit** | ✅ Compliant | Tailscale Funnel and Serve both use TLS. Internal MinIO API must have TLS enabled (self-signed cert acceptable for P1 internal; Tailscale Serve handles TLS termination for served endpoints). |
| **Encryption at rest** | ⚠️ Partial | OC1 covered by macOS FileVault (disk-level AES-XTS). MinIO does not provide application-level encryption at P1. Acceptable for INTERNAL classification. For CONFIDENTIAL data (Brand Code, agent memory containing business strategy), consider enabling MinIO Server-Side Encryption (SSE-S3) in P2. |

**S2 Compliance Gap:** Tailscale Funnel proxies through Tailscale's US infrastructure. This is a known trade-off for KL team remote access. Mitigations: (1) limit Funnel exposure to `documents` and `generated-media` buckets only; (2) do not expose `agent-memory` or `brand-code` via Funnel; (3) document this as an accepted risk in the change record.

---

### 1.4 Alignment with DataMemory_P1P4_Roadmap.md P2 Blob Design

The P2 blob design in the Roadmap (Section 3 — Data Type Lens, P2) specifies:
- *"S3-compatible object store (AWS S3 Sydney or MinIO self-hosted) for document storage. Postgres for metadata."*
- *"Object metadata carries classification label."*
- *"Object classification label mandatory. PII flag on object metadata."*
- *"Presigned URLs for secure access. No direct filesystem access."*

**TKT-0124 alignment:**

| Roadmap P2 Requirement | TKT-0124 Implementation | Alignment |
|------------------------|------------------------|-----------|
| S3-compatible object store | MinIO on Docker | ✅ Direct |
| Presigned URLs for secure access | minio-upload.sh presigned URL generation | ✅ Direct |
| No direct filesystem access | All access via MinIO API or presigned URL | ✅ Direct |
| Object metadata: classification label | Object tags on upload (`--tags "classification=INTERNAL"`) | ✅ Implement |
| Object metadata: PII flag | Object tag `pii_present=false/true` on upload | ✅ Implement |
| Postgres for metadata | Deferred to P2 — acceptable at P1 scale | ⚠️ Deferred |
| Per-tenant namespace | Deferred — P2 multi-tenant foundation | ⚠️ Deferred (bucket-level separation is sufficient at P1) |

**Assessment:** TKT-0124 correctly instantiates the P2 blob layer at P1 scale. The object metadata tagging (classification + PII flag) should be implemented now, not deferred — it costs nothing to add tags on upload and avoids a retrofitting exercise at P2.

---

## Section 2: Proposed Solution Architecture — OC1

### 2.1 MinIO Docker Deployment

```yaml
# docker-compose.minio.yml
# Location: /Users/ainchorsangiefpl/.openclaw/workspace/docker/docker-compose.minio.yml

version: '3.8'

services:
  minio:
    image: minio/minio:RELEASE.2025-05-01T01-11-07Z  # Pin to a tested release; update via CHG
    container_name: ainchors-minio
    hostname: minio
    restart: unless-stopped
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER_FILE: /run/secrets/minio_root_user
      MINIO_ROOT_PASSWORD_FILE: /run/secrets/minio_root_password
      MINIO_VOLUMES: /data
    ports:
      - "127.0.0.1:9000:9000"   # S3 API — loopback only; Tailscale Serve exposes externally
      - "127.0.0.1:9001:9001"   # Console UI — loopback only
    volumes:
      - /Volumes/MinIO-Data:/data          # Dedicated path — see storage note below
      - /etc/minio/certs:/root/.minio/certs:ro  # Optional: TLS certs
    secrets:
      - minio_root_user
      - minio_root_password
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s
    networks:
      - ainchors-internal

networks:
  ainchors-internal:
    driver: bridge

secrets:
  minio_root_user:
    external: true   # Injected via Docker secrets or env at startup — sourced from Keychain
  minio_root_password:
    external: true
```

**Storage path recommendation:**
- Primary: `/Users/ainchorsangiefpl/.openclaw/minio-data` (on internal NVMe, up to ~100GB available)
- Overflow: External USB SSD mounted at `/Volumes/MinIO-Data` if capacity pressure builds before NAS
- **Do not use the workspace directory itself** — keep MinIO data separate from workspace files

**Ports:**
- `9000` — S3 API (bound to loopback; Tailscale Serve exposes to Tailscale network)
- `9001` — MinIO Console (bound to loopback; accessible only via Tailscale Serve or SSH tunnel)

**Restart policy:** `unless-stopped` — survives reboots, recovers from crashes, does not restart on manual `docker stop`

**Image pinning:** Pin to a specific MinIO release tag. Never use `latest` in production. Update via formal CHG record. Check MinIO security advisories monthly.

---

### 2.2 Bucket Structure

| Bucket | Purpose | Versioning | Access | Classification | Funnel Exposed? |
|--------|---------|------------|--------|----------------|-----------------|
| `generated-media` | AI-generated images, audio, video outputs from hf-generate-image.sh and other pipelines | Off | Ken + agents (write), Angie/KL (read) | INTERNAL | ✅ Yes (read-only presigned) |
| `documents` | Business documents: contracts, reports, proposals, SOW, shared files for KL team | Off | Ken + Angie + KL (write), agents (read) | INTERNAL / CONFIDENTIAL | ✅ Yes (authenticated) |
| `workspace-assets` | Operational workspace assets: scripts, exported reports, backups of state files | Off | Agents (write), Ken (read) | INTERNAL | ❌ No |
| `business-docs` | Formal business repository: classified business documents, financial records, sensitive ops | Off | Ken (write), selected agents (read) | CONFIDENTIAL | ❌ No |
| `agent-memory` | Persistent agent business memory: Aria's customer context, business-stream agent state, decisions | Off | Agents (read/write), Ken (read) | CONFIDENTIAL | ❌ No |
| `brand-code` | Machine-readable Brand Code KB per HBR Agentic Marketing Org framework | **On** | Agents (read), Ken (write) | CONFIDENTIAL | ❌ No |

**Notes:**
- `brand-code` versioning is ON — Brand Code evolves iteratively; version history enables rollback and diff tracking. This satisfies AC9.
- `documents` and `generated-media` are the only buckets reachable via Tailscale Funnel (KL team access). All others are Tailscale Serve (Tailnet-only).
- Bucket lifecycle policies: add 90-day expiry to `generated-media` (configurable) to prevent unbounded growth. Other buckets: indefinite at P1.
- **Prefix conventions:**
  - `generated-media/YYYY-MM-DD/agent-name/filename.ext`
  - `documents/angie/filename.ext` | `documents/kl-team/filename.ext`
  - `agent-memory/aria/context-key.json` | `agent-memory/yoda/memory-key.json`
  - `brand-code/v1/section-name.md` | `brand-code/v1/brand-code-full.json`

---

### 2.3 Tailscale Funnel (KL Team) + Tailscale Serve (Internal)

**Tailscale Serve — Internal Tailnet Access (Ken Windows, local agents):**

```bash
# Expose MinIO S3 API to Tailscale network (Tailnet-only, no public internet)
tailscale serve --bg https://9000 http://localhost:9000
# Result: https://opc1.<tailnet>.ts.net:443 → localhost:9000

# Expose MinIO Console (optional, Ken management only)
tailscale serve --bg https://9001 http://localhost:9001
```

**Tailscale Funnel — KL Team Remote Access (public HTTPS via Tailscale relay):**

```bash
# Expose MinIO on a path-limited Funnel endpoint
# IMPORTANT: Funnel entire port 9000 is too broad — presigned URLs are self-limiting
tailscale funnel --bg 9000
# Result: https://opc1.<tailnet>.ts.net (public, TLS) → localhost:9000

# MinIO presigned URLs carry expiry + HMAC signature — safe to expose via Funnel
# KL team receives presigned URLs with limited TTL; no direct console access
```

**Access architecture diagram (logical):**

```
Ken Windows (Tailscale peer)
  └─ tailscale serve → MinIO:9000 (full API access)
  └─ tailscale serve → MinIO:9001 (console, admin)

Yoda / Aria / Agents (OC1 localhost)
  └─ localhost:9000 (direct, no proxy)

Angie KL Staff (internet, no Tailscale)
  └─ tailscale funnel → MinIO:9000
     └─ Presigned URL only (time-limited, HMAC-signed, per-file)
     └─ No direct bucket browse
     └─ Exposed buckets: generated-media, documents only

business-docs, agent-memory, brand-code
  └─ Accessible only from Tailnet (Tailscale Serve)
  └─ NEVER via Funnel
```

**Implementation note:** Funnel exposes the raw MinIO port. This means a Funnel URL is technically accessible to anyone who discovers the endpoint. Mitigations:
1. MinIO requires authentication for all bucket operations (root user / service account credentials)
2. Presigned URLs are time-limited and HMAC-signed — cannot be guessed
3. KL staff receive pre-generated presigned URLs with appropriate TTL — they do not receive MinIO credentials

---

### 2.4 MinIO User Accounts

**Design principle:** One credential per human, one service account per agent. Never share credentials between principals.

| Principal | Account Type | Buckets (Read) | Buckets (Write) | TTL / Policy |
|-----------|-------------|----------------|-----------------|--------------|
| `root` (admin) | Root account | All | All | Stored in Keychain. Never used by agents or staff. Ken admin only. |
| `ken-mun` | Human user | All | All | Ken Windows client. Stored in Keychain. |
| `angie-user` | Human user | `documents`, `generated-media` | `documents` | Angie KL — receives presigned URLs, does not hold long-lived credentials |
| `kl-team-user` | Human user (shared*) | `documents`, `generated-media` | `documents` | KL staff — shared account for P1; per-person at P2. Presigned URL access only. |
| `svc-yoda` | Service account | All | `generated-media`, `workspace-assets`, `agent-memory` | Yoda agent. Credentials injected at runtime from Keychain. |
| `svc-aria` | Service account | `agent-memory`, `brand-code`, `documents` | `agent-memory` | Aria agent. Credentials injected at runtime from Keychain. |
| `svc-agents` | Service account (shared) | `agent-memory`, `brand-code` | `agent-memory` | Business-stream agents (Atlas, other sub-agents). |
| `svc-upload` | Service account | None (write-only) | `generated-media`, `documents` | Upload-only account for hf-generate-image.sh. Cannot read or delete. |

*\*Note: Shared `kl-team-user` is acceptable for P1. At P2, issue individual per-person accounts for audit traceability.*

**MinIO Policy files:** Create explicit JSON policies per account. Example for `svc-upload`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject"],
      "Resource": [
        "arn:aws:s3:::generated-media/*",
        "arn:aws:s3:::documents/*"
      ]
    }
  ]
}
```

---

### 2.5 Presigned URL Design

Presigned URLs are time-limited, HMAC-signed URLs that grant temporary access to a specific MinIO object without requiring the caller to hold MinIO credentials. They are the primary mechanism for KL team access and for Aria returning generated assets.

**TTL Recommendations by Use Case:**

| Use Case | TTL | Rationale |
|----------|-----|-----------|
| Generated image — agent returns to Ken (interactive) | 1 hour | Ken is active; short TTL reduces exposure if URL leaks |
| Generated image — shared to KL team for review | 24 hours | Time for cross-timezone review cycle (Melbourne → KL) |
| Business document — KL team download | 7 days | Allows for async workflow; recipient may not act immediately |
| Brand Code document — agent reads for reasoning | 15 minutes | Short-lived; agents request fresh URLs per task |
| Workspace asset — internal agent consumption | 30 minutes | Agent task execution window |
| Large media archive — async processing | 4 hours | Sufficient for upload pipelines |
| Audit / compliance export | 24 hours | Reviewer needs time to download and verify |

**Presigned URL generation pattern (minio-upload.sh):**

```bash
#!/bin/bash
# minio-upload.sh — Upload file to MinIO, return presigned URL
# Usage: minio-upload.sh <bucket> <object-key> <local-file-path> [ttl-seconds]
# Dependencies: mc (MinIO Client), jq, security (macOS Keychain)

set -euo pipefail

BUCKET="${1:?Bucket required}"
OBJECT_KEY="${2:?Object key required}"
LOCAL_PATH="${3:?Local file path required}"
TTL="${4:-3600}"  # Default: 1 hour

# Endpoint from environment (endpoint-agnostic design)
MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://localhost:9000}"

# Inject credentials from Keychain at runtime
ACCESS_KEY=$(security find-generic-password -a "minio" -s "svc-upload-access-key" -w)
SECRET_KEY=$(security find-generic-password -a "minio" -s "svc-upload-secret-key" -w)

# Configure mc alias (ephemeral, session-scoped)
mc alias set ainchors-minio "${MINIO_ENDPOINT}" "${ACCESS_KEY}" "${SECRET_KEY}" --quiet

# Upload with classification metadata
mc put "${LOCAL_PATH}" \
  "ainchors-minio/${BUCKET}/${OBJECT_KEY}" \
  --attr "classification=INTERNAL;uploaded-by=svc-upload;pii_present=false"

# Generate presigned URL
PRESIGNED_URL=$(mc share download \
  "ainchors-minio/${BUCKET}/${OBJECT_KEY}" \
  --expire "${TTL}s" \
  --json | jq -r '.share')

echo "${PRESIGNED_URL}"
```

**hf-generate-image.sh integration:**
After image generation, hf-generate-image.sh pipes the output file to minio-upload.sh:

```bash
# In hf-generate-image.sh (after generation):
OBJECT_KEY="$(date +%Y-%m-%d)/${AGENT_NAME:-unknown}/$(basename "${OUTPUT_FILE}")"
PRESIGNED_URL=$(bash "${WORKSPACE}/scripts/minio-upload.sh" \
  "generated-media" "${OBJECT_KEY}" "${OUTPUT_FILE}" 3600)
echo "PRESIGNED_URL=${PRESIGNED_URL}" >> "${TASK_OUTPUT}"
```

---

### 2.6 Credential Management

**Rule (non-negotiable, per RULES.md):** All MinIO credentials stored in macOS Keychain. Zero plaintext in files, environment, scripts, git, or Docker environment variables.

| Secret | Keychain Entry | Service Name | Account |
|--------|---------------|--------------|---------|
| MinIO root username | `security add-generic-password` | `minio-root` | `root-user` |
| MinIO root password | `security add-generic-password` | `minio-root` | `root-password` |
| `ken-mun` access key | `security add-generic-password` | `minio-ken` | `access-key` |
| `ken-mun` secret key | `security add-generic-password` | `minio-ken` | `secret-key` |
| `svc-yoda` access key | `security add-generic-password` | `minio-svc-yoda` | `access-key` |
| `svc-yoda` secret key | `security add-generic-password` | `minio-svc-yoda` | `secret-key` |
| `svc-aria` access key | `security add-generic-password` | `minio-svc-aria` | `access-key` |
| `svc-aria` secret key | `security add-generic-password` | `minio-svc-aria` | `secret-key` |
| `svc-upload` access key | `security add-generic-password` | `minio-svc-upload` | `access-key` |
| `svc-upload` secret key | `security add-generic-password` | `minio-svc-upload` | `secret-key` |

**Docker secret injection pattern:**
```bash
# At container start, inject from Keychain via init script
# scripts/minio-start.sh

ROOT_USER=$(security find-generic-password -a "root-user" -s "minio-root" -w)
ROOT_PASS=$(security find-generic-password -a "root-password" -s "minio-root" -w)

docker run -d \
  --name ainchors-minio \
  --restart unless-stopped \
  -e MINIO_ROOT_USER="${ROOT_USER}" \
  -e MINIO_ROOT_PASSWORD="${ROOT_PASS}" \
  -p 127.0.0.1:9000:9000 \
  -p 127.0.0.1:9001:9001 \
  -v "${MINIO_DATA_PATH:-${HOME}/.openclaw/minio-data}:/data" \
  minio/minio:RELEASE.2025-05-01T01-11-07Z \
  server /data --console-address ":9001"
```

**Note:** The `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD` Docker env vars are set only at container creation — they are not persisted in docker-compose.yml or git. The start script pulls from Keychain at launch time.

---

## Section 3: Transition Roadmap

### Phase 1: OC1 Now (TKT-0124 Scope, May–Jul 2026)

| Item | Detail |
|------|--------|
| **Platform** | MinIO single-node on Docker, OC1 Mac Mini M4 24GB |
| **Endpoint** | `http://localhost:9000` (agent-local) / `https://opc1.<tailnet>.ts.net` (Tailscale Serve, Ken) / Tailscale Funnel (KL team) |
| **Storage** | OC1 internal NVMe or external USB SSD (~100–500GB available) |
| **HA** | None — single node. Backup: `mc mirror` daily to external drive or offsite location |
| **Access** | Tailscale Serve (internal) + Tailscale Funnel (KL external presigned only) |
| **Agents** | Yoda + Aria (initial wiring), `svc-upload` for generation pipelines |
| **Trigger to Phase 2** | TRIGGER-02: OC2 hardware arrives and is commissioned (~27 Jul 2026) |

**Phase 1 delivery sequence:**
1. Deploy MinIO container (docker run or docker-compose)
2. Create buckets (6 buckets per Section 2.2)
3. Enable versioning on `brand-code`
4. Create user accounts + policy files (per Section 2.4)
5. Store credentials in Keychain
6. Configure Tailscale Serve (internal) + Tailscale Funnel (KL)
7. Write minio-upload.sh with presigned URL generation
8. Wire hf-generate-image.sh → minio-upload.sh
9. Wire Aria agent → `agent-memory` bucket (read/write)
10. Run PVT 9/9

---

### Phase 2: OC2 + NAS Post-TRIGGER-02 (~Jul–Aug 2026)

**Architecture change:** Move MinIO to OC2-A (48GB M4 Pro) — better memory headroom, dedicated to storage/data services. OC1 shifts to primary API / inference host.

| Item | Detail |
|------|--------|
| **Platform** | MinIO on OC2-A (primary) + NAS (data persistence layer) |
| **Storage** | NAS (arriving with OC2 hardware) — MinIO data directory mounted from NAS via local network NFS/SMB |
| **HA** | Semi-HA: MinIO on OC2-A, data on NAS. OC2-B can act as MinIO standby with shared NAS mount |
| **MinIO mode** | Consider MinIO Erasure Coding mode (4-node or 2+2) across OC2-A / OC2-B if NAS supports it |
| **Endpoint** | Update `MINIO_ENDPOINT` env var → new OC2-A Tailscale address. Zero code changes required. |
| **New capabilities** | Enable MinIO SSE-S3 (server-side encryption at rest), per-object TTL lifecycle rules, object lock for brand-code |
| **Migration approach** | `mc mirror ainchors-minio-opc1 ainchors-minio-opc2a` — zero-downtime sync then atomic endpoint swap |

**Zero-downtime migration procedure:**
```bash
# Step 1: Configure new alias for OC2-A MinIO
mc alias set ainchors-minio-new https://opc2a.<tailnet>.ts.net:9000 <access> <secret>

# Step 2: Mirror all buckets (can run while OC1 is live)
mc mirror ainchors-minio ainchors-minio-new --watch &

# Step 3: Wait for initial sync to complete
mc diff ainchors-minio ainchors-minio-new

# Step 4: Pause new uploads (maintenance window: 5 min)
# Step 5: Final sync
mc mirror ainchors-minio ainchors-minio-new

# Step 6: Update MINIO_ENDPOINT in environment + agent configs
# Step 7: Restart agents / scripts (pick up new endpoint)
# Step 8: Verify PVT 9/9 against new endpoint
# Step 9: Decommission OC1 MinIO container
```

---

### Phase 3: P2 Infrastructure (~End-Aug 2026 target)

**Decision point: AWS S3 Sydney vs. self-hosted at P2**

#### Option A: AWS S3 Sydney (ap-southeast-2)

| Dimension | Detail |
|-----------|--------|
| **Pro** | Zero operational overhead. 11 nines durability. Scales to petabytes. Native lifecycle, versioning, replication. Direct integration with future AWS stack (RDS, Lambda, CloudFront). |
| **Pro** | Data residency: AWS ap-southeast-2 (Sydney) — Australian soil. Satisfies P2 SaaS sovereignty requirements for AU-based clients. |
| **Con** | Monthly cost at SME scale (~100GB: ~$2.30/month + egress). Not free but negligible at P2 launch scale. |
| **Con** | External cloud dependency. Requires internet for agent access (vs. local NAS). Acceptable for P2 cloud-hosted platform. |
| **Con** | No local copy for offline resilience (mitigated by P2 being cloud-primary). |

#### Option B: Self-Hosted MinIO on OC2 + NAS (at P2)

| Dimension | Detail |
|-----------|--------|
| **Pro** | Zero ongoing cloud cost. Full data sovereignty. No third-party dependency. |
| **Pro** | Lowest latency for local agent operations. |
| **Con** | Operational burden: RAID configuration, MinIO upgrades, capacity management, backup strategy, DR. |
| **Con** | Not cost-effective at P2 scale once team/client data grows — NAS drives aren't free, and time has a cost. |
| **Con** | OC2 is primarily targeted for inference workloads (48GB M4 Pro = Ollama, Gemma4, multi-agent concurrency). Using it as a persistent storage host creates resource contention. |

**Atlas Recommendation: AWS S3 Sydney at P2.**

Rationale:
1. P2 is SaaS, cloud-hosted. The platform will live in AWS ap-southeast-2. Having object storage co-located in the same AWS region eliminates cross-network egress and latency.
2. The per-agent `MINIO_ENDPOINT` abstraction means migration from MinIO to S3 is a one-line config change — no code changes, no re-architecture.
3. S3 is used by MinIO's own architecture as the backing store in distributed mode — using S3 directly at P2 removes the MinIO middleware layer and its operational overhead.
4. Self-hosted NAS + MinIO at P2 scale is an operational tax that distracts from product development. The NAS should be used for local backup and high-throughput inference data, not as a production object store for a SaaS platform.
5. Multi-tenant P2 (per DataMemory_P1P4_Roadmap.md) requires per-tenant bucket namespacing — S3 handles this natively via key prefix patterns or per-tenant bucket policies.

**Exception:** If P2 client contracts require on-premises data storage (highly regulated clients), self-hosted MinIO on OC2 remains viable as a second-tier option. Keep MinIO as the interface layer — clients see S3-compatible API regardless.

**Endpoint abstraction ensures zero-friction migration:**

```bash
# P1 (OC1)
export MINIO_ENDPOINT="http://localhost:9000"
export MINIO_ACCESS_KEY=$(security find-generic-password -a "access-key" -s "minio-svc-yoda" -w)
export MINIO_SECRET_KEY=$(security find-generic-password -a "secret-key" -s "minio-svc-yoda" -w)

# P2 Phase 2 (OC2)
export MINIO_ENDPOINT="https://opc2a.<tailnet>.ts.net:9000"

# P2 Target (AWS S3 Sydney)
export MINIO_ENDPOINT="https://s3.ap-southeast-2.amazonaws.com"
export MINIO_ACCESS_KEY=$(security find-generic-password -a "access-key" -s "aws-s3-svc-yoda" -w)
export MINIO_SECRET_KEY=$(security find-generic-password -a "secret-key" -s "aws-s3-svc-yoda" -w)
# Bucket names: same. Object keys: same. Code: unchanged.
```

---

## Section 4: Risks and Mitigations

| # | Risk | Likelihood | Impact | Mitigation | Owner |
|---|------|-----------|--------|------------|-------|
| R1 | **OC1 single point of failure** — MinIO unavailable if Mac Mini crashes or reboots. Agents lose access to memory and assets. | Medium | High | Daily `mc mirror` backup to external drive. Docker `restart: unless-stopped` for auto-recovery. Health-check.sh alert after 3 failures. Manual recovery procedure documented. | Ken / Yoda |
| R2 | **Storage capacity overflow** — OC1 NVMe fills up if generated-media bucket grows unchecked. | Medium | High | 90-day lifecycle expiry on `generated-media`. Alert in health-check.sh at 80% disk usage. Provision external USB SSD before NAS arrives. | Yoda |
| R3 | **Tailscale Funnel credential exposure** — Funnel exposes MinIO port 9000 publicly. If a service account credential leaks, bucket data is accessible. | Low | High | Funnel limited to presigned URL workflows only — KL staff receive URLs, not credentials. Rotate service account credentials if exposure suspected. MinIO audit log enabled. | Ken |
| R4 | **Presigned URL oversharing** — KL team member forwards a presigned URL beyond intended recipients. | Medium | Medium | TTL limits exposure window. Use shortest acceptable TTL per use case (see Section 2.5). Log all presigned URL generation events. | Yoda |
| R5 | **Agent memory corruption** — Aria or a business-stream agent writes malformed JSON to `agent-memory`, breaking subsequent reads. | Low | High | Schema validation in upload wrapper before PUT. Versioning on agent-memory bucket (add to AC10 implementation — see Section 5). Backup via `mc mirror`. | Yoda / Aria |
| R6 | **Brand Code bucket data loss** — versioning is ON, but accidental deletion of versioned objects requires manual recovery. | Low | Critical | MinIO object lock (GOVERNANCE mode) on brand-code bucket for critical files. Regular `mc mirror` backup. Ken approval required for any brand-code delete operations. | Ken |
| R7 | **Credential sprawl** — multiple service accounts over time; rotation discipline breaks down. | Medium | Medium | Document all service accounts in a Service Account Register (state/service-account-registry.json). Quarterly rotation reminder in HEARTBEAT.md. Rotation procedure in RULES.md. | Yoda |
| R8 | **OC2 commissioning delay** — if OC2 hardware is delayed beyond 27 Jul 2026, OC1 runs as the sole MinIO host longer than planned. | Medium | Medium | Phase 1 is designed to be resilient beyond the expected window. Monitor OC1 capacity. External USB SSD provides headroom. If delay >2 weeks, escalate to Ken for capacity decision. | Ken |
| R9 | **MinIO version security vulnerability** — pinned image version may have CVEs discovered post-deployment. | Low | High | Monthly security advisory check (MinIO blog + CVE feeds). Update via CHG record within 7 days of a CVSS 7+ advisory. Pinned image makes this deliberate and controlled. | Yoda |
| R10 | **P2 migration data integrity** — `mc mirror` sync may miss objects written between final sync and endpoint switch. | Low | Medium | 5-minute maintenance window for final sync. `mc diff` verification before endpoint switch. Rollback: revert `MINIO_ENDPOINT` env var (zero-code rollback). | Yoda |
| R11 | **KL team access gap** — Tailscale Funnel can be revoked by Tailscale's service or network issues outside AInchors control. | Low | Medium | Document fallback: direct email delivery of files for urgent requests. Funnel is a convenience layer, not a sole access path. Alternative: S3 presigned URL via temporary AWS credentials (P2 migration accelerant). | Ken |
| R12 | **agent-memory bucket access by wrong agent** — a misconfigured service account could allow an agent to read another agent's memory namespace. | Low | High | MinIO policies enforce prefix-level access per service account (e.g., `svc-aria` can only read/write `agent-memory/aria/*`). Prefix-scoped policies implemented at account creation. | Yoda |

---

## Section 5: AC Review

### AC1: MinIO Docker, survives restart, health check

**Status: ✅ Covered — with additions**

- Docker `restart: unless-stopped` satisfies restart survival (Section 2.1)
- Health check: `curl -f http://localhost:9000/minio/health/live` at 30s interval, 3 retries (Section 2.1)
- **Addition required:** Wire health check failure into existing `health-check.sh`. After 3 consecutive MinIO health failures, trigger `🚨 Telegram alert` per existing escalation policy (SOUL.md).
- **Addition required:** Log MinIO container restart events to `memory/YYYY-MM-DD.md` via Docker event hook or cron check.

---

### AC2: 5+ Buckets Covering Business + Agent Memory

**Status: ✅ Covered — 6 buckets designed**

6 buckets specified in Section 2.2:
1. `generated-media`
2. `documents`
3. `workspace-assets`
4. `business-docs`
5. `agent-memory`
6. `brand-code`

All required coverage areas addressed. **Observation:** The AC says "5+ buckets" — 6 buckets is compliant. The split between `documents` (KL-accessible) and `business-docs` (internal-only, no Funnel) is intentional for S2 compliance and not redundant.

---

### AC3: minio-upload.sh with Presigned URLs, Accessible from Tailscale Peers

**Status: ✅ Covered — with refinement**

- Script design in Section 2.5 covers: upload, metadata tagging, presigned URL generation
- Uses `MINIO_ENDPOINT` env var (endpoint-agnostic, satisfies AC7)
- **Addition required:** The script must also work from Ken's Windows machine (Tailscale peer). This means the endpoint in the presigned URL must resolve from outside OC1. When running minio-upload.sh from a remote Tailscale peer, `MINIO_ENDPOINT` should be set to the Tailscale Serve URL (`https://opc1.<tailnet>.ts.net`), not localhost.
- **Addition required:** The generated presigned URL must use the Tailscale-accessible endpoint, not `localhost:9000`. MinIO `--endpoint` in the mc command must match the externally accessible URL.
- **Recommendation:** minio-upload.sh should auto-detect or accept a `--public-endpoint` flag to produce presigned URLs with the correct public-facing base URL for sharing with KL team.

---

### AC4: Tailscale Funnel (KL) + Serve (Internal)

**Status: ✅ Covered**

- Tailscale Serve: internal Tailnet access for Ken Windows + agents (Section 2.3)
- Tailscale Funnel: KL team external access, limited to presigned URL workflows only (Section 2.3)
- **Gap identified (S2):** Funnel must not expose `agent-memory`, `business-docs`, or `brand-code` buckets. MinIO user policy for `angie-user` and `kl-team-user` must restrict access to `documents` and `generated-media` only. This is a policy-level control, not a network-level control — it must be explicitly configured and verified in PVT.
- **Addition to PVT:** Test that `kl-team-user` cannot access `agent-memory/*` or `brand-code/*` — should receive `Access Denied`.

---

### AC5: hf-generate-image.sh Uploads to MinIO, Returns Presigned URL

**Status: ✅ Covered**

- Integration pattern specified in Section 2.5
- Uploads to `generated-media/<date>/<agent>/<filename>`
- Returns `PRESIGNED_URL=https://...` in TASK_OUTPUT
- **Addition required:** hf-generate-image.sh should also write the presigned URL to the agent's task result for downstream consumption (e.g., Telegram delivery to Ken or Angie). Ensure the URL is logged to the daily memory file for auditability.
- **Addition:** Object tags on upload: `classification=INTERNAL`, `pii_present=false`, `generated-by=<agent-name>`, `model=<model-name>`. These tags cost nothing and provide valuable provenance for future Postgres metadata sync (P2 roadmap item).

---

### AC6: Credentials in macOS Keychain

**Status: ✅ Covered**

- Full Keychain design in Section 2.6
- Zero plaintext credentials in scripts, config files, Docker Compose, or environment
- Credentials injected at runtime via `security find-generic-password`
- **Gap:** Docker environment variable injection at container start (Section 2.6 `minio-start.sh`) means root credentials are briefly visible in the Docker process table. Mitigate by using Docker secrets (external secrets via `/run/secrets/`) instead of env vars where possible. Docker secrets are preferred but require docker-compose secrets support.
- **Rotation procedure:** Must be documented in RULES.md. Rotation steps: (1) update Keychain entry, (2) call MinIO admin API to update credentials, (3) restart container, (4) verify health check passes.

---

### AC7: Endpoint-Agnostic (MINIO_ENDPOINT Env Var)

**Status: ✅ Covered — treated as first-class design principle**

- Every script reference to MinIO uses `${MINIO_ENDPOINT:-http://localhost:9000}`
- Agent configurations use the same env var
- Migration from OC1 → OC2 → AWS S3 requires only env var update
- **Recommendation:** Document `MINIO_ENDPOINT` as a required environment variable in `RULES.md` or a new `ENV_VARS.md` reference. Agents that fail to find it should fail loudly (not silently default to localhost — this could cause prod agents to accidentally write to a dev instance).
- **Recommendation:** Add `MINIO_ENDPOINT` to the agent startup validation checklist.

---

### AC8: PVT 9/9

**Status: ✅ Covered — PVT test cases defined**

The following 9 PVT test cases are recommended for `pvt.sh` extension:

| # | Test | Pass Criterion |
|---|------|----------------|
| 1 | MinIO container is running + healthy | `docker inspect ainchors-minio | jq '.[0].State.Health.Status'` = `"healthy"` |
| 2 | All 6 buckets exist | `mc ls ainchors-minio` lists all 6 buckets |
| 3 | Versioning on `brand-code` bucket | `mc version info ainchors-minio/brand-code` = enabled |
| 4 | minio-upload.sh uploads a test file + returns valid presigned URL | Upload test.txt → get presigned URL → `curl` URL → response = file contents |
| 5 | Presigned URL accessible from Tailscale peer (Ken Windows) | From Tailscale network: `curl <presigned-url>` → 200 OK |
| 6 | Tailscale Funnel presigned URL accessible from non-Tailscale client | From internet (mobile hotspot): `curl <funnel-presigned-url>` → 200 OK |
| 7 | `kl-team-user` cannot access `agent-memory` bucket | `mc ls ainchors-minio/agent-memory --access-key kl-team-access --secret-key kl-team-secret` → AccessDenied |
| 8 | Aria read/write to `agent-memory` bucket | Aria agent writes test JSON → reads it back → contents match |
| 9 | MinIO survives container restart | `docker restart ainchors-minio` → wait 30s → health check passes → test file from step 4 still accessible |

---

### AC9: Brand Code Bucket with Versioning

**Status: ✅ Covered**

- `brand-code` bucket created with versioning enabled (Section 2.2)
- **Additions recommended:**
  1. **Object lock (GOVERNANCE mode):** Apply to critical brand-code files to prevent accidental deletion. Requires bucket-level object lock at creation time — cannot be added retroactively in MinIO. **Must be specified at bucket creation.**
  2. **Key structure:** `brand-code/v1/` prefix for current, `brand-code/archive/` for retired versions (human-managed). Versioning handles automated version history; the prefix structure handles deliberate version labelling.
  3. **Access:** Only Ken (via `ken-mun` account) should have write access. Agents (svc-yoda, svc-aria, svc-agents) have read-only access. This aligns with the Brand Code being a human-authored KB that agents consume but do not modify.
  4. **Change management:** Any modification to brand-code bucket contents should be logged as a CHG record. Agents consuming brand-code should read the version ID and log it in their reasoning (audit trail: "decision made based on brand-code v1 object version abc123").

---

### AC10: Aria Read/Write to agent-memory Bucket

**Status: ✅ Covered — with important addition**

- `svc-aria` service account created with read/write to `agent-memory` bucket (Section 2.4)
- MinIO policy scoped to `agent-memory/aria/*` prefix
- **Critical addition: Enable versioning on `agent-memory` bucket** — the AC specifies Aria writes memory, but does not specify what happens on overwrite. Agent memory corruption (Risk R5) is mitigated by versioning, which allows rollback to any previous memory state. Recommend enabling versioning on `agent-memory` bucket in addition to `brand-code`.
- **Memory key design:** Aria should use a structured key schema: `agent-memory/aria/<context-namespace>/<key>.json`. Example: `agent-memory/aria/customers/angie-context.json`. This enables fine-grained prefix-scoped policies and structured retrieval.
- **Memory lifecycle:** Define a retention policy for agent-memory objects. Stale context (>90 days unread) should be reviewed and archived, not left to grow indefinitely. This can be a Yoda heartbeat maintenance task.
- **Concurrency note:** If multiple agent instances write to the same memory key simultaneously (parallel sub-agents), a race condition can corrupt memory. Mitigation: use object versioning + conditional writes (MinIO supports `If-Match: <etag>` conditional PUTs). Implement optimistic locking pattern in agent memory write operations — consistent with the DataMemory_P1P4_Roadmap.md T5 concurrency design (Decision 4: optimistic locking in P1).

---

## Gaps and Additions Not Covered in Original ACs

The following items are **not in the original AC list** but are recommended additions to ensure P1 completeness and P2 readiness:

| # | Gap / Addition | Priority |
|---|---------------|---------|
| G1 | **Versioning on `agent-memory` bucket** — enable versioning (not just `brand-code`) to support memory rollback. Add to AC10 or create AC11. | HIGH |
| G2 | **Object metadata tagging on all uploads** — classification label + pii_present flag + uploaded-by on every PUT. Required for P2 Postgres metadata sync (DataMemory Roadmap). Add as AC requirement. | HIGH |
| G3 | **MinIO health check wired to health-check.sh** — existing health check infrastructure should monitor MinIO. Silent failure risks extended outage. | HIGH |
| G4 | **Service Account Register** — `state/service-account-registry.json` to track all MinIO accounts, their policy scope, and rotation schedule. | MEDIUM |
| G5 | **`mc mirror` daily backup cron** — backup MinIO data directory to external drive or second location. Failure = complete data loss if OC1 fails. | HIGH |
| G6 | **Brand Code object lock at bucket creation** — must be specified when bucket is created. Cannot be added later in MinIO. Critical for Brand Code integrity. | HIGH |
| G7 | **Agent memory key schema documentation** — define the namespace + key conventions for all agent memory consumers (Aria, Yoda, business-stream agents) before first write. Retrofitting key structure is painful. | MEDIUM |
| G8 | **Presigned URL generation logging** — every presigned URL generated should be logged (bucket, key, TTL, requester, timestamp) for audit trail. Lightweight JSON append to `memory/YYYY-MM-DD.md` or a dedicated `state/presigned-url-log.jsonl`. | MEDIUM |
| G9 | **MinIO audit logging enabled** — MinIO supports audit logging via webhook or file. Enable and wire to daily log review. Required for any security incident investigation. | MEDIUM |
| G10 | **MinIO TLS for internal API** — Tailscale Serve handles TLS termination for served endpoints, but direct agent access via `localhost:9000` is plaintext. For P1 internal-only, this is acceptable. Document as a known gap to address at P2. | LOW (P1) / HIGH (P2) |

---

## Appendix A: Alignment Map — TKT-0124 vs DataMemory_P1P4_Roadmap.md

| Roadmap Item | TKT-0124 Implementation | Status |
|-------------|------------------------|--------|
| P2 blob design: S3-compatible object store | MinIO on Docker (S3-compatible) | ✅ |
| P2 blob design: Presigned URLs for secure access | minio-upload.sh + AC3 | ✅ |
| P2 blob design: No direct filesystem access | All access via MinIO API | ✅ |
| P2 blob design: Object classification label mandatory | Object tags on upload (G2) | ⚠️ Add |
| P2 blob design: PII flag on object metadata | Object tag pii_present=false/true (G2) | ⚠️ Add |
| P2 blob design: Postgres for metadata | Not in TKT-0124 scope — P2 defer | 🔵 Deferred |
| P1 Action 1: Deploy Postgres + Episodic Log | Out of TKT-0124 scope (separate ticket) | 🔵 Separate |
| P1 Action 3: tenant_id placeholder | Not applicable to MinIO (bucket-level isolation sufficient at P1) | N/A |
| Section 4.5: Data Residency — Australian soil | OC1 Melbourne, Funnel risk documented | ✅ |
| Section 4.1: Encryption at rest — FileVault | macOS FileVault covers disk | ✅ |
| Decision 7: Key Management — macOS Keychain | All credentials in Keychain | ✅ |

---

## Appendix B: Recommended AC Additions for Ken Review

If Ken approves, the following ACs should be added to TKT-0124:

| AC | Text |
|----|------|
| AC11 | Versioning enabled on `agent-memory` bucket in addition to `brand-code` |
| AC12 | All MinIO object uploads include classification and pii_present tags |
| AC13 | Daily `mc mirror` backup cron operational and logged |
| AC14 | MinIO health check integrated into existing health-check.sh; Telegram alert on 3+ failures |
| AC15 | Brand Code bucket created with object lock (GOVERNANCE mode) |

---

*Assessment complete.*
*TKT-0124 | Atlas 🏛️ — Enterprise Architect, AInchors*
*2026-05-10*
