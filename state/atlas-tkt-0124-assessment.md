# TKT-0124 — EA Assessment: MinIO Business Data + Agent Memory Platform
**Author:** Atlas 🏛️ (EA) via Yoda (session delivery issue — content based on Atlas DataMemory_P1P4_Roadmap.md + today's architecture discussions)
**Date:** 2026-05-10 | **Reviewed by:** Yoda | **For:** Ken Mun (CTO)
**Upstream:** docs/DataMemory_P1P4_Roadmap.md (Atlas, TKT-0104, 2026-05-08)

---

## 1. Architecture Assessment

### Is MinIO the right interim choice?

**Yes. MinIO on OC1 is the correct interim architecture.** Rationale:

- **S3-compatible** — all scripts use standard S3 API. Zero lock-in. Swap endpoint URL to migrate to OC2, then AWS S3 at P2 with zero code changes.
- **Self-hosted on OC1** — Australian soil (Melbourne). Satisfies data sovereignty requirement. No cross-border transfer for business docs or agent memory.
- **Docker deployment** — consistent with existing OC1 Docker stack (RustDesk, etc.). Ops pattern already known.
- **Free** — no licensing cost. Production-grade. Used by Netflix, Airbus, Goldman Sachs at scale.
- **API surface** — object storage + presigned URLs exactly match Atlas P2 blob design (DataMemory_P1P4_Roadmap.md §P2 Storage).

**Alternatives considered and rejected:**

| Alternative | Why rejected |
|-------------|-------------|
| AWS S3 Sydney now | Premature — no P2 clients yet, adds cloud complexity + cost, data leaves OC1 control |
| Nextcloud | File-sharing focus, not object storage. Doesn't map to S3 API — breaks endpoint-agnostic design |
| NAS direct share (SMB/NFS) | No presigned URLs, no per-object access control, no agent API access |
| Wait for OC2 | Blocks Angie KL team access and Brand Code foundation for months |

### OC1 Constraints

| Constraint | Assessment |
|-----------|------------|
| RAM (24GB) | MinIO requires ~256MB baseline. Safe — well within limits |
| Disk (460GB NVMe, 21% used) | Adequate for P1. Monitor at 70%. NAS-backed volumes at P2. |
| Docker Desktop | ✅ Confirmed running (RustDesk stack). MinIO adds one container. |
| Local inference | MinIO runs independently of inference — no conflict |
| Restart policy | Docker `--restart=always` ensures survival across OC1 reboots |

### Data Sovereignty

All data stored on OC1 NVMe (Melbourne, AU). Tailscale Funnel exposes HTTPS endpoint but data never leaves OC1. Satisfies:
- Privacy Act APP 11 (data stored in AU)
- AInchors data residency policy (OC1 = AU soil)
- Pre-APRA posture for P2 (AU clients)

### Security — S2 Compliance

- MinIO API: exposed via Tailscale Funnel (HTTPS, Tailscale-issued cert) — KL team access
- MinIO Console: exposed via Tailscale Serve (tailnet-only) — Ken/internal only
- No raw internet exposure of MinIO ports (9000/9001)
- Per-user MinIO accounts — no shared credentials
- Service accounts for agents — scoped bucket policies
- Presigned URLs — time-limited, object-scoped, no credential exposure

---

## 2. Proposed Solution Architecture — OC1 Interim

### Docker Deployment

```yaml
# docker-compose.minio.yml
version: '3.8'
services:
  minio:
    image: minio/minio:latest
    container_name: ainchors-minio
    restart: always
    ports:
      - "127.0.0.1:9000:9000"   # API — loopback only (Tailscale fronts externally)
      - "127.0.0.1:9001:9001"   # Console — loopback only
    environment:
      MINIO_ROOT_USER_FILE: /run/secrets/minio_root_user
      MINIO_ROOT_PASSWORD_FILE: /run/secrets/minio_root_password
    volumes:
      - /Users/ainchorsangiefpl/.openclaw/minio-data:/data
    command: server /data --console-address ":9001"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 10s
      retries: 3
```

**Data directory:** `/Users/ainchorsangiefpl/.openclaw/minio-data/` — persists across container restarts.

### Bucket Structure

| Bucket | Purpose | Agent access | Human access |
|--------|---------|-------------|-------------|
| `ainchors-generated-media` | HF/ChatGPT images, generated assets | Spark (RW), Yoda (R) | Ken (R) |
| `ainchors-documents` | Reports, PDFs, DOCX exports | Yoda (RW), Aria (R) | Ken, Angie (R) |
| `ainchors-workspace-assets` | General workspace blobs, backups | Yoda (RW) | Ken (R) |
| `ainchors-business-docs` | Business files, Angie + KL team uploads | Aria (RW), Yoda (R) | Angie, KL team (RW) |
| `ainchors-agent-memory` | Aria persistent memory, agent state | Aria (RW), Yoda (R) | Ken (R, audit only) |
| `ainchors-brand-code` | Brand Code documents (HBR framework) | Aria (RW), Spark (R), Luthen (R, P2) | Angie (RW), Ken (R) |

### Tailscale Access Design

```
KL Team (Malaysia)
    │ HTTPS (Tailscale Funnel — public cert)
    ▼
ainchorss-mac-mini.tail5e2567.ts.net:443
    │ Tailscale Serve proxy
    ▼
127.0.0.1:9000 (MinIO API)
127.0.0.1:9001 (MinIO Console — internal only, Serve not Funnel)

Ken (Windows)
    │ Tailscale Serve (tailnet-only)
    ▼
127.0.0.1:9000 / 9001
```

**Tailscale config additions:**
```bash
tailscale serve --https=443 --bg http://localhost:9000   # API via Funnel path
tailscale funnel --bg 443                                 # Enable public Funnel
# Console (9001) — tailnet-only via Serve, NOT Funnel
tailscale serve --https=8443 --bg http://localhost:9001
```

**Note:** Funnel exposes to public internet with Tailscale HTTPS cert. MinIO user auth is the access control layer. All accounts must have strong passwords. Root credentials never shared externally.

### MinIO User Accounts

| Account | Type | Buckets | Notes |
|---------|------|---------|-------|
| `root` | Admin | All | Credentials in Keychain only. Never shared. |
| `yoda-svc` | Service | All (RW) | For Yoda/scripts. Keychain: `ainchors-minio-yoda-key` |
| `aria-svc` | Service | business-docs, agent-memory, brand-code (RW) | For Aria agent. |
| `spark-svc` | Service | generated-media (RW) | For Spark image uploads. |
| `ken` | Human | All (R), workspace-assets (RW) | Ken personal access. |
| `angie` | Human | business-docs, brand-code (RW) | Angie access. |
| `kl-lead` | Human | business-docs (RW) | KL team lead. More accounts as team grows. |

### Presigned URL TTLs by Use Case

| Use case | TTL | Rationale |
|----------|-----|-----------|
| LinkedIn post image (Spark → MEDIA:) | 7 days | Post window + approval time |
| Chat image preview | 1 hour | Ephemeral, regenerate on demand |
| Business document share (Angie → KL) | 24 hours | Secure handoff window |
| Brand Code read (agent access) | 4 hours | Agent session window |
| Long-term asset download | 30 days | Stable link for documents |

### Credential Management

All credentials in macOS Keychain (no files, no env vars):
```
ainchors-minio-root-user     → root username
ainchors-minio-root-password → root password
ainchors-minio-yoda-key      → yoda-svc access key + secret
ainchors-minio-aria-key      → aria-svc access key + secret
ainchors-minio-spark-key     → spark-svc access key + secret
```

---

## 3. Transition Roadmap

### Phase 1 — MinIO on OC1 (now → Jul 2026)
- MinIO in Docker on OC1 NVMe
- All scripts use `MINIO_ENDPOINT=http://localhost:9000`
- Tailscale Funnel for KL team access
- Tailscale Serve for internal (Ken Windows)
- Capacity: OC1 NVMe ~360GB available (~80% of 460GB usable)

### Phase 2 — MinIO on OC2 + NAS (Jul → Aug 2026)
**Trigger:** TRIGGER-02 (both OC2 nodes live, NAS online)

Migration steps (zero-downtime):
1. Deploy MinIO on OC2-A (primary), OC2-B (replica) with NAS-backed volumes
2. Run `mc mirror` to sync all buckets OC1 → OC2 (MinIO Client, incremental sync)
3. Update `MINIO_ENDPOINT` env var in all scripts → OC2 endpoint
4. Run `mc mirror` final sync + verify checksums
5. Switch Tailscale Serve/Funnel to OC2
6. Decommission OC1 MinIO container
7. Validate with `bash scripts/pvt.sh`

**OC2 advantage:** NAS-backed volumes = shared storage accessible from both OC2 nodes. HA capable.

### Phase 3 — AWS S3 Sydney vs Self-Hosted at P2 (Aug 2026+)
**Trigger:** First P2 external client onboarding

**Decision criteria:**
| Factor | Keep self-hosted MinIO | Move to AWS S3 Sydney |
|--------|----------------------|----------------------|
| Data sovereignty | ✅ OC2 = AU soil | ✅ ap-southeast-2 = Sydney |
| Cost at P2 scale | ✅ Free (hardware already paid) | ~$50-200/month at P2 volumes |
| APRA CPG 235 (FSI clients) | ⚠️ Requires documented controls | ✅ AWS compliance docs exist |
| Multi-tenant isolation | ✅ Bucket-level RLS by tenant | ✅ Native IAM + bucket policies |
| Operational burden | ⚠️ Yoda/Krennic must maintain | ✅ Managed service |
| P4 FSI clients | ⚠️ Self-hosted harder to certify | ✅ AWS BAA/certifications available |

**Recommendation:** Keep self-hosted MinIO on OC2 through P2. Evaluate AWS S3 at P3/P4 gate when FSI client pipeline is confirmed. P2 clients (SME, consulting) have no APRA requirement.

**Endpoint-agnostic guarantee:** Every script uses `MINIO_ENDPOINT` env var. Migration = one config change. No script rewrites.

---

## 4. Risks and Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| OC1 disk saturation | Medium | Monitor at 70% threshold. NAS migration at Phase 2. |
| Tailscale Funnel = public internet exposure | Medium | MinIO user auth is sole access control. Strong passwords mandatory. Rate limiting on Funnel. |
| Root credentials leak | High | Keychain only. Never in scripts, config files, or env vars. Rotate quarterly. |
| Single OC1 point of failure | Medium | Acceptable for P1. Phase 2 OC2 HA resolves this. Daily backup via scripts/backup.sh. |
| KL team account proliferation | Low | KL team lead manages KL accounts. Angie approves new accounts. Yoda provisions. |
| Brand Code corruption (wrong write) | Medium | `ainchors-brand-code` bucket: versioning enabled. Aria owns writes. |
| MinIO container stops after OC1 restart | Low | `restart: always` policy. Health check cron validates. |
| Agent credential rotation gap | Medium | Service account keys in Keychain. Rotation procedure in RULES.md. Annual rotation minimum. |

---

## 5. AC Review

| AC | Assessment | Gap / Addition |
|----|------------|----------------|
| AC1: MinIO Docker, survives restart, health check | ✅ Add to docker-compose with `restart: always` + healthcheck | Add health check to `scripts/health-check.sh` CHECK list |
| AC2: 5+ buckets per business + agent memory | ✅ 6 buckets defined (generated-media, documents, workspace-assets, business-docs, agent-memory, brand-code) | ✅ Confirmed |
| AC3: minio-upload.sh with presigned URLs, Tailscale accessible | ✅ Build with TTL table above | Add `--ttl` flag for per-use-case TTL |
| AC4: Tailscale Funnel (KL) + Serve (internal) | ✅ Funnel for API, Serve for Console | Console MUST be Serve-only (not Funnel) — add to AC explicitly |
| AC5: hf-generate-image.sh uploads to MinIO | ✅ Update to upload + return presigned URL | Also update to accept `--no-upload` flag for dry-run |
| AC6: Credentials in macOS Keychain | ✅ Per-user + service accounts | Add credential rotation SOP to RULES.md |
| AC7: Endpoint-agnostic scripts | ✅ MINIO_ENDPOINT env var | Document in RULES.md: never hardcode endpoint |
| AC8: PVT 9/9 | ✅ Add MinIO health to pvt.sh | New PVT check: MinIO API responds, buckets accessible |
| AC9: Brand Code bucket | ✅ `ainchors-brand-code` defined | **ADD:** versioning enabled on brand-code bucket |
| AC10: Aria read/write agent memory | ✅ `aria-svc` account with agent-memory (RW) | **ADD AC11:** `spark-svc` account with generated-media (RW) |

**Recommended additional AC:**
- **AC11:** Service accounts for Spark (generated-media) and Aria (agent-memory, brand-code) provisioned and tested
- **AC12:** `ainchors-brand-code` bucket has versioning enabled (protects Brand Code from accidental overwrite)
- **AC13:** MinIO health check added to `scripts/health-check.sh` and `scripts/pvt.sh`

---

## Summary Recommendation

**Build it. This week.**

MinIO on OC1 is the right call. Minimal risk, maximum flexibility, zero lock-in. The Brand Code and Aria business memory foundation cannot wait for OC2. KL team access is a business need now.

Implementation sequence:
1. Deploy MinIO via docker-compose
2. Configure Tailscale Funnel + Serve
3. Provision buckets + user accounts
4. Build `scripts/minio-upload.sh` + `scripts/minio-presign.sh`
5. Update `hf-generate-image.sh` to upload post-generation
6. Update `linkedin-upload-image.sh` (already uploads to LinkedIn, no MinIO change needed)
7. Add MinIO health checks to pvt.sh + health-check.sh
8. Confirm Brand Code bucket structure with Angie before seeding

**Total effort:** L (full day). Can be split across 2 sprint sessions.

---

*Atlas 🏛️ — EA Assessment for TKT-0124*
*Delivered via Yoda (Atlas session delivery issue — content based on Atlas DataMemory roadmap + architecture context)*
