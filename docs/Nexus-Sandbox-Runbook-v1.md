# Nexus Sandbox Environment — Comprehensive Runbook
**TKT-0135 | Version 1.0 | 2026-05-13**
**Status: APPROVED — Ken Mun 2026-05-13**
**Author:** Yoda 🟢 (revised comprehensive version)

---

## Executive Summary

The **Nexus Sandbox** is a containerized demo environment that showcases the core capabilities of the Nexus AI platform on your local machine. It runs Mini Yoda (orchestrator agent) and Aria (business operations agent) in a completely isolated, secure container stack with zero access to production systems or real data.

Use the Sandbox to:
- **Demonstrate platform architecture** to stakeholders (investors, clients, partners)
- **Showcase agent orchestration** — how Yoda routes requests and delegates work
- **Show business operations capabilities** — how Aria handles analysis, drafting, and compliance
- **Illustrate governance in action** — HITL approval gates, compliance review, decision tracing
- **Validate workflow patterns** before deploying to production

**Time to demo:** ~5–10 minutes per scenario. Full setup: ~60 seconds.

---

## What Is Nexus?

The **Nexus Platform** is AInchors' AI-powered business operations system built on:

- **Multi-agent orchestration** — Yoda (lead orchestrator) routes requests to specialist agents
- **Tiered model strategy** — Requests routed to models by tier (T0 system, T1 local, T2 cloud, T3 cloud-fallback)
- **Governance as a first-class feature** — The Sanctum (Shield + Lex + Sage) reviews all external-facing outputs
- **Operating model design** — Agents handle specific domains: business analysis, process design, change management, content, infrastructure
- **Phase-based delivery** — MVP (now), P1 (OC2 + HA), P2 (SaaS + SME clients), P3 (SME product), P4 (enterprise)

The Sandbox showcases the **MVP core** — two agents working in concert to handle business requests.

---

## The Sandbox Environment — What You're Seeing

### Architecture at a Glance

```
Your Mac (OC1)
├─ Colima (Docker runtime)
└─ Sandbox Compose Stack (isolated network)
   ├─ OpenClaw Container (Mini Yoda + Aria inside)
   │  └─ Port 3131 (loopback) → Your browser
   ├─ MinIO Container (demo data storage)
   │  └─ Port 9131 (console), 9000 (API)
   └─ MinIO Init (bucket setup, exits after init)
```

**Isolation guarantees (Atlas-verified):**
- No host filesystem access (no /Users, no keychain)
- No privileged containers
- Dedicated MinIO volume (not prod bucket)
- Sandbox-only credentials (never prod API keys)
- Loopback network binding only (127.0.0.1 — cannot be accessed from outside)

### Agents in the Sandbox

#### Mini Yoda 🟢 — Orchestration Showcase
**What:** Lightweight version of Yoda (lead orchestrator) that routes requests and governs approvals.

**Capabilities showcased:**
- Receives unstructured business requests
- Identifies request type and complexity
- Selects appropriate model tier (T1 local → T2 cloud)
- Routes to Aria with rich context
- Enforces S2 (Human-in-the-Loop) approval gates for high-stakes work
- Summarizes and delivers outcomes

**In the Sandbox:** Mini Yoda is configured to:
- Use Gemma4:26b local or fallback to Ollama Cloud (kimi) for demos
- Run approval gates interactively (you approve on screen)
- Log decisions and flow reasoning for transparency

#### Aria 🔵 — Business Operations Agent
**What:** Lightweight version of Aria (business agent) that handles customer analysis, drafting, compliance review.

**Capabilities showcased:**
- Market and competitive analysis
- Proposal and email drafting
- Meeting transcript summarization
- Compliance review (via Lex governance layer)
- Structured output formatting

**In the Sandbox:** Aria is configured to:
- Use T1 models (local inference when possible)
- Show governance integration — Lex overlay runs on compliance-sensitive tasks
- Produce demo-quality outputs in ~30–90 seconds per scenario

---

## How to Request and Run a Demo

### Step 1: Request a Demo

Message **Yoda** on Telegram (`@AInchorsOC1Bot`) or via WebChat:

```
Yoda, I want to run a Nexus sandbox demo. 
[Optional: brief context about who's watching and what you want to emphasize]
```

**Examples:**
- "Demo for investor call in 30 min — focus on orchestration and governance"
- "Client discovery — show business analysis and compliance review capabilities"
- "Internal team walkthrough — all scenarios, ~20 min total"

### Step 2: Yoda Validates & Spins Up

Yoda will:
1. Confirm scope with you (which scenarios, ~how long)
2. Run `make sandbox-up` to start the environment
3. Wait for health checks (~10–15 seconds)
4. Send you the access URL: `http://127.0.0.1:3131`
5. Confirm Mini Yoda and Aria are ready for demo

### Step 3: You Run the Demo

Open the URL in your browser. You'll see:
- **Mini Yoda chat interface** on the left
- **Chat history & reasoning** on the right
- **Current agent state** (which agent is active, what model tier)

Choose one or more scenarios below. Paste the demo prompt into the chat. Watch as:
- Mini Yoda receives your request
- Reasons about routing and model selection
- Routes to Aria (or asks for approval first)
- Aria produces the output
- Full flow and decisions are logged

### Step 4: Demo Complete → Tell Yoda

When you're done, message Yoda:

```
Sandbox demo complete. Tear it down.
```

Yoda will:
1. Run `make sandbox-down` (stops containers, removes all volumes)
2. Run `sandbox-verify.sh` (confirms zero residual state)
3. Confirm cleanup complete

**Nothing persists.** All demo data, conversations, and state are destroyed. Next demo starts from a clean seed image.

---

## Available Demo Scenarios

All scenarios use **synthetic data only** — fictitious companies, contacts, and context. Nothing is real or confidential.

### S001: Route-a-Request (45–60 seconds)

**What:** Shows how Mini Yoda receives a business request, analyzes complexity, selects a model tier, and routes to Aria.

**Demo prompt:**
```
I need a market analysis for our new AI consulting offering targeting 
mid-market financial services companies. Focus on competitive landscape, 
buyer pain points, and market sizing.
```

**What the audience sees:**
1. Mini Yoda receives the request in chat
2. Logs internal reasoning: "Business analysis request — requires research depth → Route to Aria + T2 model"
3. Transitions to Aria context
4. Aria produces a structured market analysis with competitive positioning
5. Mini Yoda presents results back to you

**Why it's compelling:** Demonstrates the routing intelligence and context handoff between agents.

---

### S002: Approval Flow Demo (60–90 seconds)

**What:** Shows S2 (Human-in-the-Loop) governance gate. High-value decisions require explicit human approval before execution.

**Demo prompt:**
```
Prepare a draft proposal for AcmeCorp (financial services). 
This is a potential $250k engagement. Include executive summary, 
scope, timeline, and pricing.
```

**What the audience sees:**
1. Mini Yoda receives the request
2. Logs reasoning: "High-value proposal ($250k) → S2 gate required"
3. **Pauses and asks for your approval:** "OK to proceed with proposal drafting?"
4. You click **Approve** on screen
5. Mini Yoda routes to Aria with full context
6. Aria produces proposal draft
7. Demo operator (you) can review and refine, or accept and move on

**Why it's compelling:** Shows that high-stakes decisions never run on autopilot — humans stay in the loop.

---

### S003: Business Brief (30–45 seconds)

**What:** Aria generates a structured competitive analysis from minimal input. Fast, insightful, demo-ready output.

**Demo prompt:**
```
Summarise the competitive landscape for AI-powered workflow automation 
in the Australian SME market.
```

**What the audience sees:**
1. Aria receives the request
2. Produces a structured brief with:
   - Market size estimate
   - Key competitors & positioning
   - Buyer personas (CFO, COO, Operations Director)
   - Adoption blockers & opportunities
   - AInchors differentiation (synthetic but credible)
3. Output appears in ~40 seconds, formatted for presentation

**Why it's compelling:** Shows how agents can generate business insights on demand, with professional structure and depth.

---

### S004: Email Draft (20–30 seconds)

**What:** Aria drafts a professional follow-up email based on a meeting context. Shows writing quality and tone.

**Demo prompt:**
```
Draft a follow-up email to Sarah Chen at BlueSky Financial after our 
discovery call today. Key points: explored their onboarding automation 
challenge, proposed a 4-week pilot, next step is a technical brief from 
their CTO. Keep it warm but professional.
```

**What the audience sees:**
1. Aria receives the context
2. Produces a draft email with:
   - Personalized greeting
   - Discovery call summary
   - Clear next steps
   - Professional tone (not templated or robotic)
3. Email appears in ~25 seconds, ready to copy-paste (in real usage)

**Why it's compelling:** Demonstrates writing quality and business acumen in a practical, relatable context.

---

### S005: Meeting Summary (25–35 seconds)

**What:** Aria summarizes a synthetic meeting transcript. Shows comprehension, synthesis, and actionable output.

**Demo prompt:**
```
Summarize this meeting transcript. Extract key decisions, action items, 
and risks.
```

*Aria automatically loads a synthetic meeting transcript (included in sandbox seed data) and produces:*

**What the audience sees:**
1. Aria receives the transcript
2. Produces structured summary:
   - Meeting objective & attendees
   - Key decisions made
   - Action items (owner + deadline)
   - Open risks or blockers
   - Next meeting trigger point
3. Summary in ~30 seconds

**Why it's compelling:** Shows how agents can process long-form content (transcripts, documents) and extract actionable insights.

---

### S006: Governance Demo (40–50 seconds)

**What:** Shows The Sanctum in action. Aria drafts a clause, then Lex (governance layer) reviews it for compliance risks. Both the output and the review logic are visible.

**Demo prompt:**
```
Review this draft data processing clause for APP and contractual risks:

"The Service Provider may retain and use anonymised client data for 
product improvement purposes for up to 36 months following contract 
termination."

What's safe and what needs lawyer review?
```

**What the audience sees:**
1. Aria receives the clause
2. Produces an initial assessment (compliance risks, caveats)
3. **Lex governance layer runs** (simulated for sandbox, integrated in production)
4. Lex output: highlights 2 specific risks
   - Risk 1: "36 months may exceed privacy law retention limits in AU/NZ"
   - Risk 2: "Definition of 'anonymised' is ambiguous — could expose to regulatory challenge"
5. Lex recommends "escalate to legal counsel"
6. Full decision chain is logged and visible

**Why it's compelling:** Shows that governance isn't a bottleneck — it's fast, structured, and transparent. Audiences see the reasoning.

---

### S007: Multi-Agent Handoff (60–90 seconds)

**What:** Full end-to-end orchestration. Mini Yoda receives a request, decomposes it, delegates to Aria, receives response, and delivers a final summary. The entire workflow is visible.

**Demo prompt:**
```
I need a one-page brief on why our prospect TechVantage Solutions 
should consider Nexus for their AI strategy. Cover: their current 
pain points (assume operations bottleneck + data silos), how Nexus 
solves them, and ROI assumptions.
```

**What the audience sees:**
1. **Request received** — Mini Yoda logs context: "Strategic brief for prospect TechVantage"
2. **Decomposition** — Mini Yoda breaks it into sub-tasks:
   - Analyze TechVantage's industry (Financial tech)
   - Map their likely pain points
   - Articulate Nexus value prop against those pains
   - Structure ROI narrative
3. **Delegation** — Mini Yoda routes to Aria with all context
4. **Aria produces brief** — Structured 1-page narrative with:
   - Executive summary (3 lines)
   - Pain point analysis (4 bullets)
   - How Nexus solves (4 bullets + ROI)
   - Next steps
5. **Summary & delivery** — Mini Yoda receives brief, wraps it with delivery context, sends back

**Why it's compelling:** This is the full value proposition of the platform — intelligent routing, context preservation, human-agent collaboration, and professional-quality output in ~75 seconds.

---

## Demo Best Practices

### Setup (Before the Demo)

1. **Close unnecessary apps** — Sandbox runs on Colima, but a clear desktop/browser view looks cleaner
2. **Open the sandbox URL in full-screen** — Remove distractions
3. **Have a scenario script nearby** — Copy-paste demo prompts from this runbook
4. **Test audio/video if remote** — Sandbox output is text, but you'll want to narrate

### During the Demo

1. **Go slow.** Pause between scenarios. Let outputs fully load. Narrate what's happening.
   - *"Mini Yoda is now analyzing the complexity of your request..."*
   - *"Here's the reasoning it logged — notice it selected a T2 model for research depth..."*

2. **Ask rhetorical questions.** Keep audience engaged.
   - *"What model tier would you use for this? Watch how Mini Yoda decides..."*
   - *"This is governance in action. Notice how the approval gate prevented a high-stakes decision from running blind."*

3. **Customize prompts.** If your audience is financial services, change "mid-market financial" in S001 to something specific to their industry.

4. **Jump scenarios if needed.** You don't have to do all 7. Pick 2–3 that resonate:
   - **For executives:** S002 (governance), S007 (orchestration)
   - **For technical leads:** S001 (routing), S007 (handoff)
   - **For business/ops folks:** S003 (analysis), S004 (drafting), S005 (summarization)

5. **Explain the timeout.** Sandbox LLM calls might take 30–60 seconds. Frame it:
   - *"In this demo environment, we're using cloud models to simulate inference. In production (P2), Aria runs on local GPU when possible, so these turn around in 5–10 seconds."*

### After the Demo

1. **Pause & ask questions:** "What questions does this raise?"
2. **Pivot to strategy:** "This is the MVP. P2 adds real multi-tenancy, custom training, and enterprise governance. Here's the roadmap..."
3. **Call to action:** Appropriate to your audience. Could be scheduling a discovery, filing an investor term sheet, or just next-steps email.

---

## Environment Setup & Configuration

### Prerequisites

- **Docker/Colima:** Installed and running on your Mac. Test with `docker info`.
- **Make:** Standard on macOS. Test with `make --version`.
- **Bash:** Standard on macOS.
- **Disk space:** ~5 GB free (for Docker image + MinIO volume)
- **Memory:** 8 GB available (Sandbox uses up to 6 GB at peak)

### Initial Setup (One-Time)

1. **Clone/update the sandbox code:**
   ```bash
   cd /Users/ainchorsangiefpl/.openclaw/workspace/infra/sandbox
   git pull origin main  # or manually sync if not a git repo
   ```

2. **Copy .env template and fill in values:**
   ```bash
   cp .env.sandbox.template .env.sandbox
   ```

3. **Edit `.env.sandbox`** — add your OpenClaw config:
   ```bash
   SANDBOX_PORT=3131
   SANDBOX_MINIO_PORT=9131
   SANDBOX_MINIO_CONSOLE_PORT=9132
   SANDBOX_MINIO_USER=sandbox-user
   SANDBOX_MINIO_PASSWORD=sandbox-password-here
   MINIO_ENDPOINT=minio-sb
   MINIO_BUCKET=demo
   ```

4. **Build the seed image (one-time, takes 2–3 min):**
   ```bash
   cd infra/sandbox
   make sandbox-build
   ```

5. **Test spin-up:**
   ```bash
   make sandbox-up
   ```

   You should see:
   ```
   ✓ Sandbox UP — OpenClaw accessible at http://127.0.0.1:3131
   Demo agents: Mini Yoda + Aria
   MinIO console: http://127.0.0.1:9131
   ```

   Open `http://127.0.0.1:3131` in your browser. You should see the OpenClaw interface.

6. **Tear down after testing:**
   ```bash
   make sandbox-down
   ```

### Building a New Image

If you make changes to seed agent configs, demo data, or dependencies:

```bash
cd infra/sandbox
make sandbox-build      # Builds fresh image
make sandbox-up         # Starts fresh container from new image
make sandbox-down       # Clean teardown
```

---

## The 4C Hybrid Lifecycle

The Sandbox uses a **4C Hybrid** data lifecycle (Ken-approved):

```
┌─────────────────────────────────────────────────┐
│ DEMO SESSION                                    │
├─────────────────────────────────────────────────┤
│ 1. You request demo                             │
│ 2. Yoda runs: make sandbox-up                   │
│ 3. Containers start, MinIO seeds demo data      │
│ 4. You run scenarios (~5–20 min)                │
│ 5. You tell Yoda: "Demo complete"               │
│ 6. Yoda runs: make sandbox-down                 │
│    - Stops all containers                       │
│    - Removes MinIO demo volume                  │
│    - Destroys network                           │
│ 7. Yoda runs: sandbox-verify.sh                 │
│    - Confirms ZERO residual state               │
│    - Verifies no containers, volumes, networks  │
│ 8. Next demo starts from clean seed image       │
│                                                 │
│ IMPORTANT: NO PERSISTENT DATA                   │
│ Every session is fully isolated & destroyed     │
└─────────────────────────────────────────────────┘
```

**Why this matters:**
- **Zero cross-demo contamination** — Each session starts identical
- **Data safety** — Demo data is destroyed, never persists
- **Predictability** — Spin-up time is consistent (~30–60 sec)
- **Resource cleanup** — Colima doesn't accumulate dead containers/volumes

---

## Troubleshooting

### Sandbox Won't Start

**Symptom:** `make sandbox-up` hangs or fails.

**Diagnosis:**
```bash
docker ps -a                    # Check for stuck containers
docker volume ls                # Check for orphan volumes
docker network ls               # Check for orphan networks
docker logs openclaw-sandbox-app  # Check container logs
```

**Fix:**
```bash
# Force cleanup
make sandbox-down

# If that doesn't work, manual cleanup
docker compose -p openclaw-sandbox down --volumes --remove-orphans
docker network rm openclaw-sandbox-net 2>/dev/null || true

# Rebuild and try again
make sandbox-build
make sandbox-up
```

### Slow Startup / Timeouts

**Symptom:** Sandbox takes >60 seconds to start, or health checks time out.

**Root cause:** Usually Colima is low on resources or OC1 is under load.

**Fix:**
```bash
# Check Colima resource limits
colima status

# Increase Colima memory if needed (requires restart)
colima stop
colima start --memory 12   # Increase to 12 GB if you have it
```

### OpenClaw Port Already in Use

**Symptom:** `make sandbox-up` fails with "port 3131 already in use".

**Fix:**
```bash
# Check what's on 3131
lsof -i :3131

# If it's a previous sandbox, kill it
docker kill openclaw-sandbox-app

# Or change port in .env.sandbox
SANDBOX_PORT=3132   # Use 3132 instead
```

### Agent Responses Are Slow

**Symptom:** Aria takes 30–60 seconds to respond (even slower than expected).

**Diagnosis:** Ollama is running local model inference, which is slower on M4 than on native. This is expected in the sandbox.

**Context for demo:** 
- *"In this sandbox environment, we're using cloud-hosted models to simulate inference. In production (P2), Aria runs on local GPUs, so these responses happen in 5–10 seconds."*

### Demo Data Not Appearing

**Symptom:** When you request S005 (Meeting Summary), the meeting transcript isn't loaded.

**Fix:**
```bash
# Check if MinIO was initialized properly
docker logs openclaw-sandbox-minio-init

# If init failed, manually seed the bucket
docker exec openclaw-sandbox-minio \
  /opt/minio/bin/mc mb --ignore-existing /minio_local/demo

# Copy demo data files
docker cp seed/data/demo-meeting-transcript.txt \
  openclaw-sandbox-minio:/data/demo/
```

---

## Known Limitations & Future Plans

### Current (P1 MVP)

| Limitation | Why | Future Plan |
|---|---|---|
| Mini Yoda is simplified | Showcase orchestration, not full Yoda complexity | P2: Full Yoda + all agents |
| Single agent pair (Mini Yoda + Aria) | MVP scope | P2: Add Atlas, Thrawn, Lando, Shield, Lex, Sage |
| Synthetic data only | Real data would require data masking infra | P2: Synthetic + anonymized templates |
| Local LLM inference disabled | Sandbox runs OC1-local Ollama as fallback only | P2: OC2-A local GPU for true local inference |
| No real Sanctum integration | Governance is simulated/hardcoded | P2: Full Shield/Lex/Sage review gates |
| Demo scenarios are static | You run preset scripts, not free-form | P2: Open chat (with guidelines) |
| Healthcheck port mismatch | Dockerfile uses port 3000, compose maps 3131 | TKT-0301: Fix in next build cycle |

### Roadmap (P2+)

- **Multi-agent demos** — Show all 7 T3 agents interacting
- **Real Sanctum integration** — Live compliance review layer
- **Custom data seeding** — Pass your own synthetic data into the sandbox
- **Video/streaming demos** — Record a scenario playback for async sharing
- **Containerized training** — Use sandbox to train stakeholders on platform concepts
- **P3 roadmap** — Sandbox as part of SME onboarding flow

---

## Architecture Deep Dive (For Technical Audiences)

### Network Topology

```
Sandbox Network (openclaw-sandbox-net)
├─ openclaw-sb:3000 (internal)
│  ├─ Mini Yoda orchestrator
│  ├─ Aria business agent
│  ├─ Health checker
│  └─ S2 approval gate (hardcoded for sandbox)
├─ minio-sb:9000 (API)
│ └─ Demo bucket (demo-scenarios.json, demo-meeting-transcript.txt)
└─ minio-sb:9001 (console)

Host (Colima port-forward)
├─ 127.0.0.1:3131 → openclaw-sb:3000
├─ 127.0.0.1:9131 → minio-sb:9000
└─ 127.0.0.1:9132 → minio-sb:9001
```

**Key security:**
- Sandbox network is isolated bridge (no access to host network)
- Colima port-forward binds to loopback only (127.0.0.1)
- No Tailscale, no external routing
- Credentials injected via .env.sandbox (never in image)

### Resource Allocation

```
Total Hard Limit: 4 vCPU / 6 GB RAM

openclaw-sb container:
├─ CPU: 0.80 vCPU (limit), 0.25 vCPU (reserved)
├─ RAM: 512 MB (limit), 256 MB (reserved)
└─ Node.js + OpenClaw + agents

minio-sb container:
├─ CPU: 0.20 vCPU (limit), 0.05 vCPU (reserved)
├─ RAM: 256 MB (limit), 64 MB (reserved)
└─ S3-compatible object storage

minio-init container (ephemeral):
├─ CPU: as-needed
├─ RAM: ~100 MB
└─ Exits after bucket init
```

**Why these limits?** OC1 (Mac Mini M4 24GB) needs headroom for:
- Host system (macOS Sonoma)
- OpenClaw gateway (main session)
- Other crons & agents
- Sandbox (demos)

Sandbox is never meant to consume the whole machine.

### Ollama Integration

Sandbox can access host Ollama via:
```
OLLAMA_BASE_URL=http://host.docker.internal:11434
```

**In docker-compose.sandbox.yml:**
```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

This allows sandbox containers to reach OC1's Ollama daemon (if running) for:
- Local model inference (faster, free)
- Fallback when cloud models are slow

**Current state:** Ollama integration is configured but optional. Sandbox defaults to cloud models (Ollama Cloud) for consistency.

---

## FAQ

**Q: Can I modify the demo scenarios during a demo?**  
A: No. Scenarios are baked into the seed image. But you can:
- Use S007 (Multi-Agent Handoff) with your own custom prompt
- Ask Yoda to pause the demo, customize a prompt, and re-run

**Q: Is the sandbox available for client remote demos?**  
A: Not yet. Sandbox is loopback-only (127.0.0.1). P2 roadmap includes:
- Tunneling via Cloudflare (TKT-0155)
- Or Tailscale Funnel for shareable URLs
- For now: screen-share only (Zoom, Teams, etc.)

**Q: What if I want to demo on a different machine?**  
A: You can:
- Copy the sandbox code to another Mac with Docker/Colima installed
- Rebuild the image locally (`make sandbox-build`)
- Spin it up (`make sandbox-up`)
- Requires 5 GB disk space + 8 GB available RAM

**Q: How do I use sandbox data in production?**  
A: You don't. Sandbox data is synthetic only. In production:
- Use real client data (masked/anonymized per privacy rules)
- Store in prod MinIO or AWS S3
- Sandbox is purely for demos & training

**Q: Can I run multiple sandboxes at once?**  
A: Yes. Each needs a different Compose project name and ports:
```bash
# Sandbox 1 (default)
COMPOSE_PROJECT=openclaw-sandbox SANDBOX_PORT=3131 make sandbox-up

# Sandbox 2 (custom)
COMPOSE_PROJECT=openclaw-sandbox-2 SANDBOX_PORT=3132 make sandbox-up
```

**Q: What if I find a bug in the sandbox?**  
A: Report it:
- File a GitHub issue on the Nexus repo
- Or message Yoda with: "Sandbox bug found: [description]"
- Include the output of `docker logs openclaw-sandbox-app`
- If critical, Yoda can hotfix and rebuild

---

## Getting Help

**For demo setup or issues:**  
Message Yoda on Telegram or WebChat:
```
Yoda, sandbox [your issue here]. Can you help?
```

**For architecture questions:**  
Message Yoda:
```
Yoda, route my Nexus sandbox architecture question to Thrawn.
```

**For production sandbox needs (P2+):**  
File a ticket: TKT-XXXX for your specific requirement.

---

## Summary: Demo Quick Start

1. **Request demo:** "Yoda, spin up sandbox. I want to show S001, S002, S007."
2. **Yoda starts it:** ~60 seconds later, you get `http://127.0.0.1:3131`
3. **You run scenarios:** Pick from S001–S007, paste prompts, watch outputs
4. **Tell Yoda when done:** "Sandbox demo complete. Tear it down."
5. **Yoda cleans up:** Zero residual state

**Total time:** 5–20 minutes (demo) + 2 minutes (setup/teardown).

**Outcome:** Stakeholders see a working multi-agent system making intelligent routing decisions, enforcing governance, and producing professional-quality business output.

---

*Last updated: 2026-05-13 | Approved by Ken Mun | TKT-0135 Complete*
