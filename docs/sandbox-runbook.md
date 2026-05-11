# Nexus Sandbox Environment — Runbook
**TKT-0135 | Version 1.0 | 2026-05-10**
**Status: DRAFT FOR REVIEW**

---

## What Is the Sandbox?

The Nexus Sandbox is an isolated demo environment running on OC1 (your Mac mini) via Colima. It lets you demonstrate the Nexus multi-agent platform — specifically Mini Yoda (orchestrator) and Aria (business agent) — to clients, stakeholders, or the team, using **synthetic data only** and **no connection to prod systems**.

Think of it as a "showroom" version of Nexus: same look and feel, completely safe to run in front of anyone.

---

## How to Request a Demo

**You don't spin it up yourself.** Message Yoda:

> *"Yoda, I want to run a Nexus sandbox demo. [Brief description of who's watching and what you want to show]"*

Yoda will:
1. Confirm the demo scope with you
2. Trigger `sandbox-up` via the infra agent
3. Give you the access URL when it's ready (~30–60 seconds)
4. Tell you what demo scenarios are available

---

## What to Expect During a Demo

| Step | What Happens |
|------|-------------|
| You request a demo | Yoda validates scope and triggers spin-up |
| ~30–60 seconds | Container starts from cached image, MinIO seeds demo data |
| Yoda confirms ready | Access URL delivered (e.g., http://localhost:3131) |
| You run the demo | Choose from preset scenarios below |
| Demo complete | Tell Yoda "wrap up demo" |
| Teardown | Yoda tears down all containers and verifies clean state |

---

## Available Demo Scenarios

| ID | Name | Agent | What It Shows | ~Duration |
|----|------|-------|---------------|-----------|
| S001 | Route-a-Request | Mini Yoda | Multi-agent routing, model tier selection | 45–60s |
| S002 | Approval Flow | Mini Yoda | S2 HITL governance gate in action | 60–90s |
| S003 | Business Brief | Aria | AI-powered business analysis | 30–45s |
| S004 | Email Draft | Aria | Professional email drafting | 20–30s |
| S005 | Meeting Summary | Aria | Auto-summarisation of a meeting | 25–35s |
| S006 | Governance Demo | Aria | Lex compliance review overlay | 40–50s |
| S007 | Multi-Agent Handoff | Both | Full end-to-end orchestration + delivery | 60–90s |

All scenarios use **synthetic data only** — fictitious companies, contacts, and content.

---

## Access Details (When Running)

| Service | URL | Notes |
|---------|-----|-------|
| OpenClaw (Mini Yoda + Aria) | http://localhost:3131 | Colima port-forward, loopback only |
| MinIO Console | http://localhost:9131 | Demo bucket only |

> **Note:** Access is loopback only (127.0.0.1). No Tailscale or external access inside the sandbox container.

---

## Lifecycle: What Happens to Data After a Demo

**4C Hybrid lifecycle** (Ken-approved):

- All containers are **fully destroyed** after each demo session
- The MinIO demo bucket and all sandbox data are wiped
- **Nothing persists** — each demo starts from a clean seed image
- Spin-up uses cached Docker layers (~30–60 seconds)
- No snapshot drift; every demo starts identical

**You don't need to do anything.** Yoda handles teardown automatically after you signal demo completion.

---

## What the Sandbox Is NOT

| ❌ Not in Sandbox | ✅ In Sandbox |
|-------------------|--------------|
| Prod OpenClaw workspace | Demo agents (Mini Yoda + Aria) |
| Real emails / calendar / Slack | Synthetic demo scenarios |
| Prod MinIO bucket | Dedicated demo MinIO bucket |
| Real client data | Fictitious demo data only |
| Host keychain / prod secrets | Sandbox-only credentials |
| Tailscale network | Colima port-forward (loopback) |

---

## If Something Goes Wrong

**Demo won't start:**
> Tell Yoda — "Sandbox failed to start." Yoda will check logs and retry or escalate.

**Demo behaves unexpectedly:**
> Stop the demo, tell Yoda. Yoda can tear down and rebuild from the seed image.

**You need to force-cleanup manually:**
```bash
cd infra/sandbox
make sandbox-down
make sandbox-verify
```
If verify still shows residual resources:
```bash
docker compose -p openclaw-sandbox down --volumes --remove-orphans
docker network rm openclaw-sandbox-net 2>/dev/null || true
```

---

## Resource Limits

The sandbox runs within hard limits approved by Ken (TKT-0135):

| Resource | Limit |
|----------|-------|
| Total vCPU | 4 vCPU |
| Total RAM | 6 GB |
| Container runtime | Colima (existing on OC1) |
| Storage | Separate MinIO container (demo bucket only) |

These limits ensure the sandbox doesn't impact other OC1 workloads.

---

## Security Notes

- Sandbox uses **sandbox-only credentials** — never prod API keys or keychain secrets
- No `--privileged` containers
- No bind mounts to your OpenClaw workspace or any system paths
- All network traffic is loopback-bound via Colima port-forward
- Post-demo teardown is verified by `sandbox-verify.sh` — zero residual state guaranteed

---

*Questions? Message Yoda. Architecture questions? Route to Thrawn via Yoda.*
