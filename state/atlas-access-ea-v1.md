# EA: AInchors Nexus Access Architecture
## Comprehensive Review — Personas, Channels, Phases, and Recommendations

**Classification:** Internal — Technical Architecture
**Author:** Atlas 🏛️ — Enterprise Architect, AInchors
**Requested by:** Ken Mun, CTO (via Yoda orchestration, 2026-05-12)
**Trigger:** TKT-0136 — MinIO mobile access → expanded to full access architecture EA
**Status:** DRAFT FOR REVIEW — pending Ken Mun approval
**Version:** v1.0
**Date:** 2026-05-12

---

> **Document Purpose**
>
> This EA addresses the immediate MinIO mobile access blocker and — at Ken's
> direction — expands to a comprehensive access architecture review across all
> personas, channels, services, and platform phases (MVP through P4).
>
> It delivers: (1) current-state assessment, (2) a per-persona/per-channel
> access direction matrix, (3) technology options evaluation, (4) a phase-by-phase
> access architecture roadmap, (5) security posture mapping, and (6) a clear
> recommendation with an immediate action for MVP.
>
> All architecture decisions herein are DRAFT FOR REVIEW. Ken has final authority.

---

## 1. Executive Summary

**Immediate recommendation (MVP): Deploy Cloudflare Tunnel for MinIO and OpenClaw gateway.**

AInchors currently has a single-node (OC1) platform with all services bound to
loopback, accessible only via Tailscale. This is the correct security default —
but it creates a hard blocker for mobile access without a VPN client installed.

The architectural answer across all phases is a **layered access model**:

| Layer | What it does | Applies from |
|-------|-------------|-------------|
| **L1 — Direct LAN** | Office/desk access, no overhead | MVP forever |
| **L2 — Tailscale mesh** | Admin, dev, HIVE node-to-node traffic | MVP forever |
| **L3 — Cloudflare Tunnel** | Authenticated public URL access, no port forwarding | MVP → P2 |
| **L4 — Nexus Public API** | Client-facing, tenant-scoped REST API | P2 onward |
| **L5 — The Citadel** | Client portal, SSO-enabled, fully branded | P2 onward |

This model requires minimal work to stand up at MVP (Cloudflare Tunnel ≈ 30 min),
scales naturally to P2 multi-tenant (swap Cloudflare for Nexus API + Citadel for
client surfaces), and is fully extensible to P4 enterprise/on-prem deployments.

**No architectural debt** is introduced by starting with Cloudflare Tunnel at MVP.
It is explicitly designed as a bridge layer, not a permanent P2 architecture.

---

## 2. Current State Assessment

### 2.1 Infrastructure Topology

```
OC1 (Mac Mini M4 24GB) — Melbourne — Production
  │
  ├── OpenClaw Gateway (:18789) — loopback only (S2 control)
  ├── MinIO Console (:9001) — loopback only
  ├── MinIO API (:9000) — loopback only
  ├── Postgres (:5432) — loopback only
  ├── obs.db / tasks.db — local filesystem
  └── All cron jobs, agents, Telegram bots

Access paths today:
  ├── [LAN / local] → Ken desktop: direct, full access
  ├── [Tailscale] → Remote desktop/laptop with Tailscale client
  └── [Telegram] → Ken & Angie: chat interface, no file/console access
```

### 2.2 Current Access Gaps

| Service | Ken (desktop) | Ken (mobile) | Angie (desktop) | Angie (mobile) | P2 client |
|---------|:---:|:---:|:---:|:---:|:---:|
| OpenClaw webchat | ✅ LAN | ❌ No Tailscale | ✅ If Tailscale | ❌ | ❌ |
| OpenClaw Telegram | ✅ | ✅ | ✅ | ✅ | — |
| MinIO console | ✅ LAN | ❌ **BLOCKED** | ❌ | ❌ | N/A |
| MinIO API | ✅ LAN | ❌ **BLOCKED** | ❌ | ❌ | N/A |
| Agent logs / obs.db | ✅ LAN/SSH | ❌ | ❌ | ❌ | — |
| Future: The Citadel | N/A | N/A | N/A | N/A | ❌ Not built |
| Future: Datapad | N/A | N/A | N/A | N/A | ❌ Not built |

**Root cause:** All services are loopback-bound (correct per S1–S7). Remote access
requires Tailscale. Ken has no Tailscale on mobile. There is no lightweight
public-URL access layer in place.

---

## 3. Persona Analysis

### 3.1 Ken Mun — CTO, Co-founder

**Access profile:**
- Technical user — can operate CLI, SSH, browser, mobile
- Primary channel: Webchat (OC1 direct or Tailscale)
- Secondary: Telegram (@AInchorsOC1Bot → Yoda)
- Tertiary: Mobile browser — no Tailscale client installed

**Access requirements:**
- MinIO: view stored objects, check storage usage, upload files from mobile
- OpenClaw gateway: chat with Yoda from any device
- Logs and observability: diagnose issues remotely
- Future: approve decisions, review The Bridge dashboard

**Blocking gaps:**
- Mobile access to MinIO console — **critical, immediate**
- Mobile access to OpenClaw webchat — desired but managed via Telegram today

---

### 3.2 Angie — Co-founder, Business Lead

**Access profile:**
- Non-technical — operates via Telegram exclusively today
- No VPN/SSH tooling installed
- Telegram is her primary (and currently only) operational interface

**Access requirements:**
- Chat with Aria (business stream agent) via Telegram — **working today**
- Future: review The Citadel for status/reports as a "client zero" user
- Future: basic dashboard for agent status (Beacon, P1+)

**Blocking gaps:**
- Cannot access any web interface today (by design at MVP, but must be fixed by P2)
- Future: needs a low-friction web/mobile portal — The Citadel MVP

---

### 3.3 AI Agents (Yoda, Aria, governance triad, etc.)

**Access profile:**
- Internal service accounts — no external access needed
- Communicate via OpenClaw gateway (loopback or Tailscale)
- Execute tools, scripts, APIs via cron and on-demand

**Access requirements:**
- All intra-HIVE (OC1 to OC2 via Tailscale, post-P1) — covered
- External API calls (Telegram, Google, Anthropic, etc.) — outbound only, no inbound exposure
- No agent should ever be accessible from outside the HIVE

**Access gaps:** None at MVP. HIVE mesh covered by Tailscale at P1.

---

### 3.4 P2 Clients (SME business owners, non-technical)

**Access profile:**
- Non-technical operators
- Web browser + mobile browser
- No VPN capability
- Expect a consumer-grade web experience

**Access requirements:**
- The Citadel client portal — agent status, tasks, reports, document delivery
- Telegram bot (per-client @Bot) — async notifications, approvals
- Datapad — weekly ROI and activity reports (PDF or Notion)
- API access (via Nexus Public REST API if client is technical or has an IT team)

**Access gaps:** Everything — The Citadel does not exist yet. This is a P2 build.

---

### 3.5 P4 Enterprise / FSI Clients

**Access profile:**
- IT teams with VPN / Tailscale capability
- May operate on-prem deployment (physical HIVE in client data centre)
- Require SSO/SAML, MFA, full RBAC
- Compliance officers need audit trail access

**Access requirements:**
- On-prem: full local access within their network
- AInchors remote management: Tailscale site-to-site
- Compliance: immutable audit log export, APRA CPG 234/235 controls

---

## 4. Services Access Direction Matrix

> **Legend:** ✅ = Implemented/planned | 🔧 = Build required | ❌ = Not applicable/blocked | 🅿️ = Parked

### 4.1 MVP (Now — until OC2 arrives, OC1-only, Ken + Angie only)

| Service | Ken LAN | Ken Remote | Ken Mobile | Angie | Agents |
|---------|:---:|:---:|:---:|:---:|:---:|
| **OpenClaw Webchat** | ✅ Direct | ✅ Tailscale | 🔧 CF Tunnel | ❌ | — |
| **OpenClaw Telegram** | ✅ | ✅ | ✅ | ✅ | ✅ (outbound) |
| **MinIO Console** | ✅ LAN | ✅ Tailscale | 🔧 **CF Tunnel** | ❌ | — |
| **MinIO API** | ✅ LAN | ✅ Tailscale | 🔧 CF Tunnel | ❌ | — |
| **SSH / Terminal** | ✅ | ✅ Tailscale | — | ❌ | — |
| **Postgres** | ✅ LAN | ✅ Tailscale | ❌ | ❌ | ✅ Loopback |
| **Agent logs** | ✅ | ✅ Tailscale | 🔧 CF Tunnel (readonly) | ❌ | ✅ |

**MVP action:** Deploy Cloudflare Tunnel for MinIO and OpenClaw webchat.
Time to implement: ~30–45 minutes. Zero ongoing cost (Cloudflare free tier).

---

### 4.2 P1 (OC2 era — HA cluster, NAS, KL team onboarding, expanded agents)

| Service | Ken | Angie | KL Team | Agents (HIVE) |
|---------|:---:|:---:|:---:|:---:|
| **OpenClaw Webchat** | ✅ CF Tunnel | ✅ CF Tunnel | ✅ CF Tunnel (auth-gated) | — |
| **OpenClaw Telegram** | ✅ | ✅ | ✅ (if provisioned) | ✅ |
| **MinIO Console** | ✅ CF Tunnel | 🔧 CF Tunnel (limited) | 🔧 CF Tunnel (scoped) | — |
| **MinIO API** | ✅ CF Tunnel | ❌ | 🔧 CF Tunnel (scoped) | ✅ Tailscale |
| **OC2 Ollama API** | ✅ Tailscale | ❌ | ❌ | ✅ Tailscale only |
| **Postgres** | ✅ Tailscale | ❌ | ❌ | ✅ Tailscale |
| **NAS** | ✅ Tailscale | ❌ | ❌ | ✅ Tailscale |
| **Beacon Dashboard** | 🔧 CF Tunnel | 🔧 CF Tunnel | 🔧 CF Tunnel | — |
| **The Bridge (Ops)** | 🔧 CF Tunnel | 🔧 CF Tunnel (limited) | 🔧 CF Tunnel (limited) | — |

**P1 additions:**
- KL team onboarding requires provisioned Cloudflare Access identities (email-based, zero additional cost)
- OC2 Ollama API must remain Tailscale-only (loopback on OC2, no external exposure ever)
- NAS management stays Tailscale-only — never exposed via tunnel
- Beacon dashboard (if built) delivered via Cloudflare Tunnel with Cloudflare Access auth

---

### 4.3 P2 (SaaS — first paying clients, The Citadel live)

| Service | Ken | Angie | P2 SME Clients | Agents |
|---------|:---:|:---:|:---:|:---:|
| **OpenClaw Webchat** | ✅ CF Tunnel | ✅ CF Tunnel | ❌ (via Citadel) | — |
| **OpenClaw Telegram** | ✅ | ✅ | ✅ Per-client bot | ✅ |
| **MinIO Console** | ✅ CF Tunnel | ✅ CF Tunnel (limited) | ❌ Internal only | — |
| **Nexus Public REST API** | ✅ | 🔧 | ✅ Per-tenant API key | ✅ |
| **The Citadel (Client Portal)** | — | 🔧 (admin view) | ✅ OAuth2 / API key | — |
| **Datapad (Reports)** | ✅ | ✅ | ✅ (via Citadel or PDF) | — |
| **Holonet (Webhooks)** | — | — | ✅ HMAC-gated | ✅ |
| **OC2 Ollama API** | ✅ Tailscale | ❌ | ❌ Internal only | ✅ Tailscale |
| **Postgres** | ✅ Tailscale | ❌ | ❌ Internal only | ✅ Internal |
| **Beacon Dashboard** | ✅ CF Tunnel | ✅ CF Tunnel | ❌ Internal only | — |

**P2 transition:** Cloudflare Tunnel continues for AInchors-internal surfaces
(MinIO, webchat, Beacon). Client-facing traffic shifts to Nexus Public REST API
and The Citadel — purpose-built, tenant-isolated, not exposed via tunnel.

---

### 4.4 P3 — SME Onsite Installation ⚠️ PARKED

> P3 (SME onsite installation) is parked for future consideration.
> Design notes are included below but no investment is planned now.
> Revisit when P2 has ≥10 stable clients and a documented demand for
> on-premise SME deployments.

**P3 design notes (for future reference):**
- Client receives a packaged HIVE (Mac Mini M4 Pro × 1 or × 2) installed on-site
- Access architecture mirrors P4 but without FSI compliance overlay
- AInchors remote management via Tailscale site-to-site
- Cloudflare Tunnel optionally deployed by client for their internal web access
- The Citadel deployed locally — no AInchors SaaS dependency
- **Build gate:** Requires a self-serve installation package (Docker Compose + seed scripts + setup wizard). Estimated 3–4 months to productise. Only justified at P2 client #10+.

---

### 4.5 P4 (Enterprise — full multi-tenant, SSO, BYOK, Holonet full)

| Service | Ken (mgmt) | AInchors Support | P4 Enterprise Client | Client IT Team |
|---------|:---:|:---:|:---:|:---:|
| **OpenClaw (client instance)** | ✅ Tailscale mgmt | ✅ Tailscale mgmt | ✅ LAN / corporate VPN | ✅ LAN / SSH |
| **Nexus Public REST API** | ✅ Tailscale | — | ✅ Client network | ✅ |
| **The Citadel** | — | — | ✅ SSO/SAML + MFA | ✅ |
| **Datapad** | — | — | ✅ | ✅ |
| **Holonet (full)** | — | — | ✅ Internal bus | ✅ |
| **OC2/local Ollama** | ✅ Tailscale | ✅ Tailscale | ✅ LAN only | ✅ |
| **Postgres (client)** | ✅ Tailscale (mgmt) | ✅ Tailscale (mgmt) | ✅ LAN (DBA only) | ✅ |
| **NAS** | ✅ Tailscale | — | ✅ LAN | ✅ |
| **BYOK KMS** | — | — | ✅ Client-managed | ✅ |
| **Audit Log Export** | — | — | ✅ Compliance officer | ✅ |

---

## 5. Technology Options Evaluation

### 5.1 The Problem Statement (MVP)

Services are loopback-bound (correct). Remote access needs a secure, authenticated
URL layer. Three valid options exist. A fourth is explicitly rejected.

---

### Option A — Cloudflare Tunnel ✅ RECOMMENDED for MVP → P1

**What it does:** `cloudflared` daemon runs on OC1. Creates an encrypted outbound
tunnel to Cloudflare's network. Cloudflare assigns a public hostname
(e.g., `minio.ainchors.com`). No port forwarding, no firewall changes.
Optional: Cloudflare Access adds identity-based authentication (email, OTP) in
front of any tunneled service.

**Architecture:**
```
Mobile browser / any device
  └──> minio.ainchors.com (Cloudflare DNS)
         └──> Cloudflare Edge (nearest PoP)
                └──> Encrypted tunnel (cloudflared daemon on OC1)
                       └──> MinIO console :9001 (loopback)
```

| Dimension | Detail |
|-----------|--------|
| **Cost** | Free tier: unlimited tunnels, unlimited bandwidth |
| **Auth** | Cloudflare Access: email + OTP (free up to 50 users) |
| **Setup time** | ~30 minutes |
| **Mobile** | Works on any browser, any device, zero client install |
| **Security** | TLS 1.3 to Cloudflare edge; encrypted tunnel to OC1; optional Zero Trust auth layer |
| **Maintainability** | Single daemon, auto-reconnects, minimal ops overhead |
| **Scalability** | Handles multiple services (MinIO, OpenClaw, Beacon) via named routes |
| **Limitation** | Cloudflare sits in the path — US-based CDN. Acceptable for MVP (AInchors-internal use only). Not for client data at P2. |

**Verdict:** Best fit for MVP. Low cost, low complexity, high security baseline. Extends naturally to P1 (KL team access via Cloudflare Access identities). Not used for P2 client-facing traffic (replaced by Nexus API + Citadel).

---

### Option B — Nginx Reverse Proxy + Public IP

**What it does:** Nginx on OC1 binds to a public interface, forwards specific
paths to loopback services. TLS via Let's Encrypt.

| Dimension | Detail |
|-----------|--------|
| **Cost** | Free (Let's Encrypt, nginx) |
| **Auth** | Must add separately (basic auth, OAuth2 proxy, fail2ban) |
| **Setup time** | 1–2 hours + TLS config + auth layer |
| **Mobile** | Yes, any browser |
| **Security** | Requires correct firewall rules. Port 443 must be open to the internet. Nginx misconfigs are a common attack surface. |
| **Scalability** | Works, but public IP exposure is a standing attack surface |
| **Limitation** | OC1 public IP must accept inbound traffic. ISP port blocks possible. Security hardening required. Ongoing TLS cert management. |

**Verdict:** More attack surface than Cloudflare Tunnel for no additional capability at MVP. Can be revisited if Cloudflare is ever unavailable or pricing changes. Not recommended as primary path.

---

### Option C — Tailscale Serve (Shared Access)

**What it does:** Tailscale Serve exposes a local service on the Tailscale hostname
(e.g., `https://ainchorss-mac-mini.tail5e2567.ts.net:443`). Accessible to any
Tailscale user who is shared into the tailnet.

| Dimension | Detail |
|-----------|--------|
| **Cost** | Free |
| **Auth** | Tailscale identity (Google/GitHub SSO) |
| **Setup time** | ~15 minutes |
| **Mobile** | ❌ Requires Tailscale client — does not resolve the original blocker |
| **Security** | Excellent — within Tailscale mesh, zero public exposure |
| **Limitation** | Does NOT solve the "no Tailscale on mobile" problem. Only suitable for adding Angie or KL team members who CAN install Tailscale. |

**Verdict:** Useful supplement for adding team members who have Tailscale installed (KL team at P1). Does NOT resolve Ken's mobile access gap. Not a substitute for Cloudflare Tunnel.

---

### Option D — Direct Public Port Exposure ❌ REJECTED

Exposing OpenClaw (:18789), MinIO (:9001/:9000) directly to the internet via
port forwarding or binding to `0.0.0.0`.

**Rejected because:**
- Violates S2 control (gateway must be loopback-bound)
- Exposes MinIO to automated brute-force and credential stuffing attacks
- CVE-2026-25253 (CVSS 8.8) history demonstrates the cost of public exposure
- 175,000 Ollama servers currently exposed by this exact mistake
- Provides no authentication layer by default

**Verdict:** Non-starter. Not considered further.

---

### Option E — Self-Hosted Reverse Proxy (Nginx Proxy Manager / Traefik + Docker)

**What it does:** A containerised reverse proxy (Traefik or Nginx Proxy Manager)
running in Docker (Colima), handling TLS termination and routing.

**Verdict:** Adds Docker operational overhead for the same outcome as Cloudflare
Tunnel at MVP scale. May be worth evaluating at P2 when more services need routing
and The Citadel web app is deployed. Not recommended for MVP.

---

### 5.2 Options Summary

| Option | Mobile? | Cost | Complexity | Security | Recommended Phase |
|--------|:---:|------|-----------|---------|------------------|
| **A — Cloudflare Tunnel** | ✅ | Free | Low | High | ✅ **MVP → P1** |
| B — Nginx + Public IP | ✅ | Free | Medium | Medium | Not recommended |
| C — Tailscale Serve | ❌ | Free | Very Low | Very High | P1 supplement only |
| D — Direct port exposure | ✅ | Free | None | ❌ None | **REJECTED** |
| E — Self-hosted proxy | ✅ | Free | Medium | High | P2 evaluation |

---

## 6. Phase-by-Phase Access Architecture Roadmap

### Phase: MVP — Now until OC2 arrives

**Platform state:** OC1 only. Two founders (Ken + Angie). Core platform live.

**Access architecture target:**
- Cloudflare Tunnel deployed for: MinIO console, MinIO API, OpenClaw webchat
- Cloudflare Access enabled: email + OTP auth on tunnel (free, blocks all unauthenticated access)
- DNS: `minio.ainchors.com`, `chat.ainchors.com` (or equivalent subdomains)
- Tailscale: remains for SSH, Postgres, direct admin, agent-to-agent (intra-HIVE)
- Telegram: Ken + Angie primary interface unchanged

**Scope of change:** OC1 only. `cloudflared` daemon install (~30 min).
Zero changes to OpenClaw config, MinIO config, or firewall rules.

**Security posture:** S2 remains fully satisfied. Loopback bind unchanged.
Cloudflare acts as the auth + TLS layer in front of the loopback services.

**Action items:**
1. `brew install cloudflared` on OC1
2. `cloudflared tunnel login` — authenticate with ainchors Cloudflare account
3. Create tunnel: `cloudflared tunnel create ainchors-oc1`
4. Configure routes: MinIO (:9001), OpenClaw webchat (:18789)
5. Enable Cloudflare Access policies: email + OTP for ken@ainchors.com + angie@ainchors.com
6. Add DNS records (Cloudflare manages automatically via tunnel config)
7. Test from Ken's mobile: `https://minio.ainchors.com` — confirm works without Tailscale
8. Raise CHG for this change. Log in Notion.

---

### Phase: P1 — OC2 era, HA cluster, NAS, KL team onboarding

**Platform state:** OC1 + OC2-A + OC2-B HIVE. NAS live. Team expanding.

**Access architecture changes:**
- Cloudflare Tunnel extended to additional services as they come live:
  `beacon.ainchors.com` (health dashboard), `bridge.ainchors.com` (ops centre)
- KL team members provisioned in Cloudflare Access: email + OTP per team member
- Tailscale: OC2 nodes join tailnet. NAS joins tailnet. All intra-HIVE via Tailscale.
- OC2 Ollama API: Tailscale-only forever. No public exposure. No tunnel.
- NAS: Tailscale-only forever. No public exposure.
- Angie web access: Cloudflare-tunneled OpenClaw chat enabled for Angie
  (if she wants web access beyond Telegram)

**Security posture changes:**
- S7 (device auth): add KL team devices to OpenClaw authorised device list
- Cloudflare Access: move from personal email auth to Google Workspace SSO
  (`@ainchors.com` domain) — eliminates per-member manual provisioning
- Warden: add Cloudflare tunnel health to daily health check

**Design decision required (P1):**
> Should Angie access OpenClaw webchat via Cloudflare Tunnel?
> Or is Telegram her permanent primary interface?
> Recommend: Telegram remains primary. Web access as fallback.
> Ken to confirm before P1 buildout.

---

### Phase: P2 — SaaS, first paying clients, The Citadel live

**Platform state:** Multi-tenant SaaS. Paying clients. The Citadel deployed.

**Access architecture changes:**
- **Client traffic no longer goes through Cloudflare Tunnel.**
  The Citadel is a purpose-built web application with its own auth (OAuth2/JWT),
  its own domain, and per-tenant session management.
- **AInchors-internal traffic still via Cloudflare Tunnel:** MinIO, Beacon, Postgres admin tools.
- Nexus Public REST API deployed and publicly accessible (HTTPS, per-tenant API keys).
- Per-client Telegram bots provisioned at onboarding.
- Holonet v0 deployed: per-tenant HMAC-gated webhook endpoints.
- The Citadel v0: Notion-based for first 2–3 clients (Decision D from TKT-0046).

**Key access separation principle at P2:**

```
AInchors-internal access (Ken, Angie, KL team):
  → Cloudflare Tunnel (authenticated, internal tools)
  → Tailscale (admin, SSH, HIVE)
  → Telegram (agents)

Client access (P2 SME clients):
  → The Citadel (OAuth2, per-tenant)
  → Per-client Telegram bot
  → Nexus Public REST API (API key, per-tenant)
  → Holonet webhooks (HMAC, per-tenant)

Never mixed:
  → Clients NEVER access AInchors-internal tools via tunnel
  → AInchors NEVER uses client-facing APIs for internal ops
```

**Security posture changes at P2:**
- Cloud KMS replaces macOS Keychain for secret storage
- Redis session cache with 24h TTL
- RLS enforced on all Postgres tables (per CHG-0234)
- Cloudflare Access: restrict tunnel to `@ainchors.com` accounts only
  (no external identities in tunnel)
- Nexus Public API: WAF rules, rate limiting, tenant isolation middleware

---

### Phase: P3 — SME Onsite Installation ⚠️ PARKED

> P3 is parked. Design for it, but do not invest in it now.
>
> When revisited, access architecture is: local LAN + optional Tailscale
> site-to-site for AInchors remote management. No Cloudflare Tunnel deployed
> by default (client preference). The Citadel deployed locally.
>
> **Trigger to revisit:** ≥10 stable P2 clients + documented SME demand for
> on-premise option + a productised installation package ready for deployment.

---

### Phase: P4 — Enterprise clients, full governance, BYOK, Holonet full

**Platform state:** Physical/in-house deployment at client site. Full FSI compliance.

**Access architecture:**
- All client workloads on client's on-prem HIVE — no AInchors cloud dependency
- AInchors remote management: Tailscale site-to-site VPN
- Client internal access: corporate LAN / corporate VPN (whatever the client uses)
- The Citadel: deployed within client network. SSO/SAML + MFA mandatory.
- Ollama API: loopback on client's OC2 nodes. Never externally exposed.
- Audit log: stored on client-managed WORM NAS. Exportable by compliance officer.
- BYOK: client manages their own KMS/HSM. AInchors provides configuration guidance.

**Access security gates (mandatory before P4 client onboarding):**
- All 7 S1–S7 controls verified on client's deployment
- RBAC + MFA enabled on The Citadel
- Network penetration test completed (or explicitly waived by Ken)
- APRA CPG 234/235 controls checklist signed off (for FSI clients)
- Tailscale management link established and tested

---

## 7. Security Posture Mapping

### 7.1 Control Mapping by Phase

| Security Control | MVP | P1 | P2 | P3 ⚠️PARKED | P4 |
|-----------------|:---:|:---:|:---:|:---:|:---:|
| **S1 — OC version currency** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **S2 — Gateway loopback bind** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **S3 — No ClawHub skills** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **S4 — Least privilege** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **S5 — Approval gates** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **S6 — API key rotation** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **S7 — Device auth** | ✅ | ✅ (KL team added) | ✅ | ✅ | ✅ |
| **Cloudflare Access auth** | 🔧 **Build** | ✅ (Workspace SSO) | ✅ | N/A | N/A |
| **Per-client Telegram bot** | N/A | N/A | 🔧 **Build** | ✅ | ✅ |
| **Nexus API tenant isolation** | N/A | N/A | 🔧 **Build** | ✅ | ✅ |
| **Cloud KMS** | N/A | N/A | 🔧 **Build** | ✅ | ✅ HSM |
| **RBAC + MFA** | N/A | N/A | 🔧 **Build** | ✅ | ✅ Mandatory |
| **WAF / rate limiting** | N/A | N/A | 🔧 **Build** | ✅ | ✅ |
| **APRA CPG 234/235** | N/A | N/A | N/A | N/A | ✅ Mandatory |

### 7.2 Cloudflare Tunnel Security Profile

Cloudflare Tunnel is a well-established production-grade ingress pattern used by
enterprises globally. The specific security properties relevant to AInchors:

| Risk | Mitigation |
|------|-----------|
| Cloudflare sees traffic metadata | Acceptable at MVP — AInchors-internal only. Not for client data. |
| Tunnel credential compromise | Tunnel token stored in macOS Keychain (S6 rotation). Cloudflare token can be revoked instantly. |
| DDoS / abuse | Cloudflare provides free DDoS mitigation at the edge. |
| Unauthenticated access | Cloudflare Access (email + OTP) blocks all unauthenticated requests before they reach OC1. |
| Misconfigured routes | Route config is version-controlled (cloudflared config.yml in workspace). |

**Data sovereignty note:**
Cloudflare Tunnel routes traffic through Cloudflare's global network (US-based edge).
- ✅ Acceptable for MVP (AInchors-internal admin access — no client data)
- ✅ Acceptable for P1 (same internal-only use)
- ❌ Not acceptable for P2 client data — use Nexus Public API (HTTPS direct) instead
- This constraint is automatically satisfied by the P2 architecture (clients use
  Nexus API + Citadel, not the Cloudflare Tunnel)

---

## 8. Open Decisions for Ken

### Decision 1 — Cloudflare Tunnel: Which services to expose at MVP?

**Context:** Minimum needed to unblock Ken mobile access is MinIO only.
Broader set (OpenClaw webchat, Beacon when built) adds more capability.

**Options:**
- **Option 1A (minimal):** MinIO console + MinIO API only
- **Option 1B (recommended):** MinIO + OpenClaw webchat (`chat.ainchors.com`)
- **Option 1C (full):** MinIO + OpenClaw webchat + future Beacon dashboard stub

**Recommendation:** Option 1B. Minimal additional work, restores webchat
access from mobile immediately.

**Ken to decide:** 1A, 1B, or 1C?

---

### Decision 2 — Cloudflare Access auth method?

**Context:** Cloudflare Access can authenticate via:
- Email + OTP (free, works for any email address, no Cloudflare account needed for users)
- Google Workspace SSO (requires `@ainchors.com` users, free via Cloudflare Access)
- GitHub, Azure AD, etc.

**Recommendation:** Start with email + OTP for MVP (fastest, no dependency on Google Workspace setup). Switch to Google Workspace SSO at P1 when KL team is onboarding.

**Ken to decide:** Confirms email + OTP for MVP start?

---

### Decision 3 — Angie web access: tunnel or Telegram-only?

**Context:** Should Angie be provisioned with Cloudflare Access credentials to use
OpenClaw webchat via browser? Or remain Telegram-only until The Citadel?

**Recommendation:** Telegram-only for now. Angie is operating well via Telegram.
Cloudflare Access for Angie introduces a new interface she'll need support to use.
Revisit at P1 when KL team access is being set up (one provisioning exercise).

**Ken to decide:** Confirms Telegram-only for Angie at MVP?

---

### Decision 4 — The Citadel domain strategy?

**Context:** At P2, client-facing surfaces need a domain strategy:
- **Option 4A:** All on `ainchors.com` subdomains (e.g., `app.ainchors.com`,
  `api.ainchors.com`, `[client].ainchors.com`)
- **Option 4B:** Separate SaaS domain (e.g., `nexus.io` or `citadel.ainchors.com`)
  for brand separation between the consulting/agency brand (ainchors.com) and
  the product brand

**Recommendation:** Defer to P2 build planning. Use `ainchors.com` subdomains
initially (simplest), with option to migrate to a product domain when brand
positioning is confirmed. Not a blocking decision for MVP or P1.

**Ken to note:** Not urgent. Raise as P2 planning item.

---

## 9. Recommendation Summary

### Immediate Action (MVP)

**Do this now — resolves Ken's mobile MinIO blocker and future-proofs the access layer:**

```bash
# On OC1 — install cloudflared
/opt/homebrew/bin/brew install cloudflared

# Authenticate with Cloudflare account
cloudflared tunnel login

# Create the tunnel
cloudflared tunnel create ainchors-oc1

# Configure routes (create ~/.cloudflared/config.yml):
# ingress:
#   - hostname: minio.ainchors.com
#     service: http://localhost:9001
#   - hostname: chat.ainchors.com
#     service: http://localhost:18789
#   - service: http_status:404

# Start tunnel
cloudflared tunnel run ainchors-oc1

# Enable Cloudflare Access on both hostnames:
# → Cloudflare dashboard → Zero Trust → Access → Applications
# → Add policy: allow ken@ainchors.com + angie@ainchors.com (email OTP)

# Install as macOS launch daemon (persists across reboots):
cloudflared service install
```

**Result:** Ken can access MinIO and OpenClaw webchat from any device, any network,
any browser, with no VPN client required. Estimated implementation: 30–45 minutes.

---

### Phase Direction Summary

| Phase | Primary Access Pattern | Client-Facing? | Key Build |
|-------|----------------------|:---:|-----------|
| **MVP** | Cloudflare Tunnel + Tailscale + Telegram | ❌ Internal only | **cloudflared setup** |
| **P1** | Cloudflare Tunnel (Workspace SSO) + Tailscale | ❌ Internal only | Extend tunnel routes, KL team access |
| **P2** | Nexus API + The Citadel + per-client Telegram | ✅ First clients | The Citadel, Nexus API, Holonet v0 |
| **P3** ⚠️PARKED | Local LAN + Tailscale site-to-site | ✅ On-prem | Installation package |
| **P4** | On-prem LAN + Tailscale mgmt + SSO/MFA | ✅ Enterprise | FSI compliance, BYOK, APRA gate |

---

### Architecture Principles (locked)

These principles apply across all phases:

1. **Loopback first.** All services bind to `127.0.0.1`. Never `0.0.0.0`. S2 is non-negotiable.
2. **No direct public port exposure.** Cloudflare Tunnel or Nexus API are the only valid public paths.
3. **Tailscale for admin, never for clients.** HIVE mesh, SSH, Postgres, Ollama, NAS = Tailscale-only.
4. **Client data never through Cloudflare.** AInchors-internal use only. Client traffic via Nexus API.
5. **Phased access expansion.** Each phase introduces new access layers but never removes security controls.
6. **Auth at every layer.** No unauthenticated public surface at any phase.

---

## Appendix A — Service Port Reference

| Service | Port | Bind | Access Path (MVP) | Access Path (P2+) |
|---------|------|------|-------------------|--------------------|
| OpenClaw Gateway | 18789 | Loopback | CF Tunnel / Tailscale | Internal + Nexus API layer |
| MinIO Console | 9001 | Loopback | CF Tunnel / Tailscale | Internal only (CF Tunnel) |
| MinIO API | 9000 | Loopback | CF Tunnel / Tailscale | Internal only |
| Postgres | 5432 | Loopback | Tailscale only | Tailscale only |
| Ollama API (OC2) | 11434 | Loopback (OC2) | Tailscale only | Tailscale only forever |
| Redis (P2) | 6379 | Loopback | Tailscale only | Tailscale only |
| The Citadel (P2) | TBD | 0.0.0.0 (via proxy) | N/A | Nexus API / Nginx/Caddy |
| Nexus Public API (P2) | 443 | Public (via proxy) | N/A | Direct HTTPS |

---

## Appendix B — Cloudflare Tunnel Config Template

```yaml
# /Users/ainchorsangiefpl/.cloudflared/config.yml
tunnel: ainchors-oc1
credentials-file: /Users/ainchorsangiefpl/.cloudflared/[tunnel-id].json

ingress:
  # MinIO Console
  - hostname: minio.ainchors.com
    service: http://localhost:9001
    originRequest:
      noTLSVerify: false

  # OpenClaw Webchat
  - hostname: chat.ainchors.com
    service: http://localhost:18789

  # Catch-all
  - service: http_status:404
```

```
Cloudflare Access Policies:
  Application: MinIO (minio.ainchors.com)
    Policy: Allow — email: ken@ainchors.com, angie@ainchors.com
    Auth method: One-time PIN (email)

  Application: OpenClaw Chat (chat.ainchors.com)
    Policy: Allow — email: ken@ainchors.com, angie@ainchors.com
    Auth method: One-time PIN (email)
```

---

## Appendix C — Phase Naming Reference

| Phase | Definition | Status |
|-------|-----------|--------|
| **MVP** | Now until OC2 arrives. OC1-only. Two founders (Ken + Angie). Core platform live. | ✅ CURRENT |
| **P1** | OC2 era. HA cluster, NAS, KL team onboarding, expanded agent team. | 🔜 July 2026 |
| **P2** | SaaS: Individuals + SME business owners. First paying customers. The Citadel live. | 🔜 Aug–Sep 2026 |
| **P3** | SaaS: SME onsite installation. | ⚠️ PARKED |
| **P4** | SaaS: Enterprise clients. Full multi-tenant, advanced governance, BYOK, Holonet. | 🔜 Year 2+ |

---

*Document: DRAFT FOR REVIEW*
*Atlas 🏛️ Enterprise Architect | AInchors / Aevlith Technologies*
*2026-05-12 | v1.0*
*Requesting approval from: Ken Mun, CTO*
