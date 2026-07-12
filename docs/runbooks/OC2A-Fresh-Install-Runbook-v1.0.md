# OC2A Fresh Install Runbook — Option 4: Strong Separation

**Document ID:** RUNBOOK_OC2A_FreshInstall_v1.0_2026-07-12
**Based on:** [OC2A-Fresh-Install-Plan-v1.0.md](../plans/OC2A-Fresh-Install-Plan-v1.0.md) (Option 4)
**Target:** OC2A — Mac Mini M4 Pro, 48GB RAM
**Execution Context:** Run ON OC2A, by Forge on OC2A, after direct access is established
**Author:** Forge 🏗️ (infra agent on OC2A)
**Status:** DRAFT — Awaiting Ken approval and Phase 0 gate

---

## Table of Contents

1. [Pre-Flight Checks](#1-pre-flight-checks)
2. [Homebrew & Required Packages](#2-homebrew--required-packages)
3. [OpenClaw CLI Install & Onboarding](#3-openclaw-cli-install--onboarding)
4. [Gateway Configuration](#4-gateway-configuration)
5. [LaunchAgents & Service Start](#5-launchagents--service-start)
6. [Tailscale Serve Configuration](#6-tailscale-serve-configuration)
7. [Gateway & Node Health Verification](#7-gateway--node-health-verification)
8. [PostgreSQL Install & Configuration](#8-postgresql-install--configuration)
9. [Workspace Repository Setup](#9-workspace-repository-setup)
10. [Smoke-Test Command List](#10-smoke-test-command-list)
11. [Common Failure Modes & Recovery](#11-common-failure-modes--recovery)
12. [Appendix: Reference Values](#12-appendix-reference-values)

---

## 0. Execution Prerequisites

### 0.1 Who Runs This

- **Executor:** Forge 🏗️ (infra agent) running ON OC2A
- **Overseer:** Yoda 🟢 (main agent) on OC2A
- **Approver:** Ken Mun (CTO) — all gates require Ken sign-off

### 0.2 Access Requirements

Before this runbook can be executed, Ken must:

1. Enable **Remote Login** on OC2A (System Settings → General → Sharing → Remote Login)
2. Enable **Tailscale SSH** on OC2A (Tailscale admin console → Machines → OC2A → "Enable Tailscale SSH")
3. Verify direct SSH access: `ssh ken@ainchorsoc2as-mac-mini.tailfc3ed1.ts.net` succeeds
4. Confirm OC1 has **zero** OC2A admin credentials (no SSH keys, no gateway tokens, no Keychain entries)

### 0.3 OC2A Identity

| Property | Value |
|---|---|
| Hostname | `ainchorsoc2as-mac-mini.tailfc3ed1.ts.net` |
| Tailscale IP | `100.112.241.16` |
| Local IP | `192.168.1.126` (direct LAN path) |
| Hardware | Mac Mini M4 Pro, 48GB RAM |
| macOS | Sequoia 15.x (verify in pre-flight) |
| Production Port | `18789` (per port convention) |

### 0.4 Option 4 Constraints (ALWAYS ACTIVE)

- **OC1 has NO admin path to OC2A.** No SSH, no gateway token, no node pairing.
- **All configuration is rebuilt from canonical baselines**, not copied from OC1.
- **OC1 can read OC2A health endpoints only** (read-only observability).
- **Promotion path:** OC1 sandbox → manual review → reimplemented on OC2A by OC2A's Forge.

---

## 1. Pre-Flight Checks

**Goal:** Confirm OC2A is in a known-good state before any installation begins.

### 1.1 macOS Version

```bash
sw_vers
```

**Expected:** `ProductVersion: 15.x` (Sequoia). If older, update via System Settings → Software Update before proceeding.

### 1.2 Network Connectivity

```bash
# Verify internet access
ping -c 3 1.1.1.1

# Verify DNS
nslookup github.com
```

### 1.3 Tailscale Status

```bash
tailscale status
tailscale ip -4
```

**Expected:**
- OC2A shows as `ainchorsoc2as-mac-mini.tailfc3ed1.ts.net`
- IP: `100.112.241.16`
- Status: `active` / `connected`

```bash
# Verify Tailscale is running and will auto-start
tailscale status --json | python3 -c "import sys,json; d=json.load(sys.stdin); print('BackendState:', d.get('BackendState')); print('Self online:', d['Self']['Online'])"
```

### 1.4 Admin Account

```bash
whoami
id
```

**Expected:** Running as the primary admin user (likely `ken` or `ainchorsangiefpl`). Must have `sudo` access.

```bash
# Verify sudo
sudo -v
```

### 1.5 Disk Space

```bash
df -h /
```

**Expected:** At least 50GB free. OC2A has 48GB RAM; swap should not be an issue, but confirm.

### 1.6 Existing Services Check

```bash
# Confirm no conflicting services on port 18789
lsof -i :18789 2>/dev/null || echo "Port 18789 is free (good)"

# Confirm no existing PostgreSQL on 5432
lsof -i :5432 2>/dev/null || echo "Port 5432 is free (good)"

# Confirm no existing OpenClaw installation
which openclaw 2>/dev/null && echo "WARNING: openclaw already installed" || echo "openclaw not installed (good)"
```

### 1.7 Gate: Pre-Flight Complete

- [ ] macOS 15.x confirmed
- [ ] Network connectivity OK
- [ ] Tailscale connected and healthy
- [ ] Admin account with sudo
- [ ] ≥50GB free disk
- [ ] Ports 18789 and 5432 free
- [ ] No prior OpenClaw installation (or acknowledged and will be replaced)

**Sign-off:** Ken confirms pre-flight results before proceeding.

---

## 2. Homebrew & Required Packages

**Goal:** Install Homebrew and all required system packages.

### 2.1 Install Homebrew

```bash
# Install Homebrew (if not present)
which brew || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Ensure brew is in PATH for this session
eval "$(/opt/homebrew/bin/brew shellenv)"

# Verify
brew --version
```

### 2.2 Install Required Packages

```bash
# Core packages
brew install node@22 jq git curl wget

# PostgreSQL 16 (production database)
brew install postgresql@16

# Tailscale (should already be installed; verify)
which tailscale || brew install tailscale

# Optional but recommended
brew install htop watch tree
```

### 2.3 Verify Installations

```bash
node --version    # Expected: v22.x
npm --version     # Expected: 10.x+
jq --version
git --version
/opt/homebrew/opt/postgresql@16/bin/psql --version   # Expected: 16.x
tailscale version
```

### 2.4 Gate: Packages Installed

- [ ] Homebrew installed and functional
- [ ] node@22, npm, jq, git, curl, wget installed
- [ ] postgresql@16 installed (not yet initialized)
- [ ] tailscale present

---

## 3. OpenClaw CLI Install & Onboarding

**Goal:** Install OpenClaw CLI and create a fresh production profile/workspace.

### 3.1 Install OpenClaw CLI

```bash
# Install globally via npm
npm install -g openclaw@latest

# Verify
openclaw --version
```

**Target version:** `2026.6.11` or later. If a newer version is available, confirm with Ken before upgrading.

### 3.2 Create Fresh Workspace Directory

```bash
# Create the workspace directory
mkdir -p ~/.openclaw/workspace

# Create the agents directory
mkdir -p ~/.openclaw/agents
```

### 3.3 Run OpenClaw Onboarding

```bash
openclaw onboard
```

**Onboarding prompts (expected):**
- Workspace path: `~/.openclaw/workspace` (default, confirm)
- Gateway mode: `local`
- Port: `18789`
- Auth mode: `token`
- Tailscale: `enabled`

If onboarding is non-interactive, configure manually via `openclaw config` (see Section 4).

### 3.4 Verify Profile Created

```bash
ls -la ~/.openclaw/openclaw.json
cat ~/.openclaw/openclaw.json | python3 -c "import sys,json; d=json.load(sys.stdin); print('Gateway mode:', d.get('gateway',{}).get('mode')); print('Port:', d.get('gateway',{}).get('port'))"
```

### 3.5 Gate: OpenClaw Installed

- [ ] `openclaw --version` returns expected version
- [ ] `~/.openclaw/openclaw.json` exists
- [ ] `~/.openclaw/workspace/` directory created
- [ ] Gateway mode = `local`, port = `18789`

---

## 4. Gateway Configuration

**Goal:** Configure the OC2A gateway for production use with Tailscale auth.

### 4.1 Set Gateway Mode and Port

```bash
openclaw config set gateway.mode local
openclaw config set gateway.port 18789
openclaw config set gateway.bind loopback
```

### 4.2 Configure Authentication

```bash
# Enable Tailscale authentication
openclaw config set gateway.auth.allowTailscale true

# Set token auth mode
openclaw config set gateway.auth.mode token

# Generate a new production token (do NOT reuse OC1's token)
openclaw config set gateway.auth.token "$(openssl rand -hex 24)"
```

**⚠️ CRITICAL:** The OC2A gateway token must be unique. Never copy OC1's token. Store the generated token securely — it will be needed for node pairing and API access.

### 4.3 Configure Tailscale Integration

```bash
openclaw config set gateway.tailscale.mode serve
openclaw config set gateway.tailscale.resetOnExit false
```

### 4.4 Configure Control UI (Optional)

```bash
# Allow the Tailscale hostname as an origin for the control UI
openclaw config set gateway.controlUi.allowInsecureAuth false
openclaw config set gateway.controlUi.allowedOrigins '["https://ainchorsoc2as-mac-mini.tailfc3ed1.ts.net"]'
```

### 4.5 Configure Ollama Cloud (Shared Account)

```bash
# Set Ollama cloud endpoint (shared account with OC1)
openclaw config set gateway.ollama.baseUrl "https://ollama-cloud.ainchors.com"  # adjust to actual endpoint
# API key will be set via secrets-init or Keychain, not in config
```

### 4.6 Validate Configuration

```bash
openclaw config validate
```

**Expected:** No errors. If validation fails, review each setting.

### 4.7 Gate: Gateway Configured

- [ ] `gateway.mode` = `local`
- [ ] `gateway.port` = `18789`
- [ ] `gateway.bind` = `loopback`
- [ ] `gateway.auth.allowTailscale` = `true`
- [ ] `gateway.auth.mode` = `token`
- [ ] `gateway.auth.token` set (unique, not OC1's)
- [ ] `gateway.tailscale.mode` = `serve`
- [ ] `openclaw config validate` passes

---

## 5. LaunchAgents & Service Start

**Goal:** Install gateway and node as macOS LaunchAgents for auto-start on boot.

### 5.1 Install Gateway LaunchAgent

```bash
openclaw gateway service install
```

This creates `~/Library/LaunchAgents/com.openclaw.gateway.plist`.

### 5.2 Install Node LaunchAgent

```bash
openclaw node service install
```

This creates `~/Library/LaunchAgents/com.openclaw.node.plist`.

### 5.3 Verify LaunchAgent Files

```bash
ls -la ~/Library/LaunchAgents/com.openclaw.gateway.plist
ls -la ~/Library/LaunchAgents/com.openclaw.node.plist

# Inspect gateway plist
plutil -p ~/Library/LaunchAgents/com.openclaw.gateway.plist
```

**Check:** `RunAtLoad` should be `true`, `KeepAlive` should be `true`.

### 5.4 Start Services

```bash
# Load and start gateway
launchctl load ~/Library/LaunchAgents/com.openclaw.gateway.plist

# Load and start node
launchctl load ~/Library/LaunchAgents/com.openclaw.node.plist
```

### 5.5 Verify Services Running

```bash
# Check gateway
launchctl list | grep openclaw.gateway

# Check node
launchctl list | grep openclaw.node

# Alternative: use openclaw CLI
openclaw gateway status
openclaw node status
```

### 5.6 Gate: Services Running

- [ ] Gateway LaunchAgent installed and loaded
- [ ] Node LaunchAgent installed and loaded
- [ ] `openclaw gateway status` shows running
- [ ] `openclaw node status` shows running
- [ ] Both services set to auto-start on boot (`RunAtLoad: true`)

---

## 6. Tailscale Serve Configuration

**Goal:** Expose the OC2A gateway on the Tailscale tailnet via `tailscale serve`.

### 6.1 Configure Tailscale Serve

```bash
# Serve the gateway on HTTPS via Tailscale
tailscale serve --bg --https=443 http://127.0.0.1:18789
```

**What this does:**
- Proxies `https://ainchorsoc2as-mac-mini.tailfc3ed1.ts.net` → `http://127.0.0.1:18789`
- Only accessible to devices on the AInchors tailnet
- TLS terminated by Tailscale

### 6.2 Verify Serve Status

```bash
tailscale serve status
```

**Expected output:** Shows an HTTPS proxy from the Tailscale hostname to `http://127.0.0.1:18789`.

### 6.3 Test from OC2A Itself

```bash
# Test the gateway health endpoint locally
curl -s http://127.0.0.1:18789/health | jq .

# Test via Tailscale hostname (from OC2A)
curl -s https://ainchorsoc2as-mac-mini.tailfc3ed1.ts.net/health | jq .
```

### 6.4 Test from OC1 (Read-Only Observability)

**Run this on OC1 (not OC2A):**

```bash
# Verify Tailscale reachability
tailscale ping ainchorsoc2as-mac-mini

# Test read-only health endpoint (no auth required)
curl -s https://ainchorsoc2as-mac-mini.tailfc3ed1.ts.net/health | jq .
```

**Expected:** Health endpoint returns status. No auth token needed for `/health`.

### 6.5 Gate: Tailscale Serve Active

- [ ] `tailscale serve status` shows HTTPS proxy to `127.0.0.1:18789`
- [ ] Local health check passes on OC2A
- [ ] Tailscale hostname health check passes on OC2A
- [ ] OC1 can reach OC2A health endpoint (read-only)

---

## 7. Gateway & Node Health Verification

**Goal:** Comprehensive health check of the OC2A OpenClaw installation.

### 7.1 Gateway Health

```bash
# Full status
openclaw status

# Gateway-specific
openclaw gateway status --json | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('Mode:', d.get('mode'))
print('Port:', d.get('port'))
print('Running:', d.get('running'))
print('Uptime:', d.get('uptime'))
print('Tailscale auth:', d.get('auth', {}).get('allowTailscale'))
"
```

### 7.2 Node Health

```bash
openclaw node status --json | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('Connected:', d.get('connected'))
print('Node ID:', d.get('nodeId'))
print('Platform:', d.get('platform'))
"
```

### 7.3 QR / Pairing Code

```bash
# Generate pairing QR for webchat access
openclaw qr --json
```

**Expected:** Returns a `wss://` URL for the gateway. This URL can be used to connect webchat clients.

### 7.4 Webchat Connectivity Test

```bash
# Test the WebSocket endpoint
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:18789/
```

**Expected:** HTTP 200 or 101 (WebSocket upgrade). A 4xx/5xx indicates a problem.

### 7.5 Gate: Health Verified

- [ ] `openclaw status` shows healthy
- [ ] Gateway running on port 18789
- [ ] Node connected to gateway
- [ ] QR/pairing code generated successfully
- [ ] WebSocket endpoint reachable

---

## 8. PostgreSQL Install & Configuration

**Goal:** Install, initialize, and configure PostgreSQL 16 as the production database for the AInchors platform.

### 8.1 Initialize PostgreSQL

```bash
# PostgreSQL 16 was installed via brew in Section 2
# Initialize the database cluster
/opt/homebrew/opt/postgresql@16/bin/initdb --locale=C --encoding=UTF-8 /opt/homebrew/var/postgresql@16
```

### 8.2 Start PostgreSQL

```bash
# Start PostgreSQL now
/opt/homebrew/opt/postgresql@16/bin/pg_ctl -D /opt/homebrew/var/postgresql@16 -l /opt/homebrew/var/log/postgresql@16.log start

# Install as LaunchAgent for auto-start
brew services start postgresql@16
```

### 8.3 Verify PostgreSQL is Running

```bash
/opt/homebrew/opt/postgresql@16/bin/pg_isready
```

**Expected:** `/tmp/.s.PGSQL.5432` — accepting connections.

### 8.4 Create Database and Roles

```bash
# Create the AInchors platform database
/opt/homebrew/opt/postgresql@16/bin/createdb ainchors_nexus

# Create roles
/opt/homebrew/opt/postgresql@16/bin/psql -d ainchors_nexus <<'SQL'
-- Admin role (full access)
CREATE ROLE nexus_admin WITH LOGIN PASSWORD 'CHANGE_ME_ADMIN_PASSWORD' CREATEDB CREATEROLE;

-- Read-write agent role
CREATE ROLE agent_readwrite WITH LOGIN PASSWORD 'CHANGE_ME_RW_PASSWORD';

-- Read-only agent role
CREATE ROLE agent_readonly WITH LOGIN PASSWORD 'CHANGE_ME_RO_PASSWORD';

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE ainchors_nexus TO nexus_admin;
GRANT CONNECT ON DATABASE ainchors_nexus TO agent_readwrite, agent_readonly;

-- Set search path
ALTER DATABASE ainchors_nexus SET search_path TO public;
SQL
```

**⚠️ SECURITY:** Replace `CHANGE_ME_*_PASSWORD` with strong, unique passwords. Store them in macOS Keychain, not in plaintext config files.

### 8.5 Create db.sh Wrapper Script

```bash
cat > ~/.openclaw/workspace/scripts/db.sh <<'SCRIPT'
#!/bin/bash
# db.sh — Agent postgres access wrapper for OC2A
# Usage: db.sh -c "SELECT ..." | db.sh -f script.sql
export PGHOST=localhost
export PGPORT=5432
export PGUSER=agent_readwrite
export PGDATABASE=ainchors_nexus
export PGOPTIONS="--client-min-messages=warning"
/opt/homebrew/opt/postgresql@16/bin/psql -t -A "$@"
SCRIPT

chmod +x ~/.openclaw/workspace/scripts/db.sh
```

### 8.6 Verify Database Access

```bash
# Test connection
~/.openclaw/workspace/scripts/db.sh -c "SELECT current_database(), current_user, version();"

# Test write
~/.openclaw/workspace/scripts/db.sh -c "CREATE TABLE IF NOT EXISTS _install_test (id SERIAL PRIMARY KEY, ts TIMESTAMPTZ DEFAULT now()); INSERT INTO _install_test DEFAULT VALUES; SELECT * FROM _install_test; DROP TABLE _install_test;"
```

### 8.7 Gate: PostgreSQL Ready

- [ ] `pg_isready` returns accepting connections
- [ ] `ainchors_nexus` database created
- [ ] Roles created: `nexus_admin`, `agent_readwrite`, `agent_readonly`
- [ ] `db.sh` wrapper script created and executable
- [ ] Read/write test passes
- [ ] PostgreSQL auto-starts via brew services

---

## 9. Workspace Repository Setup

**Goal:** Establish the OC2A workspace with canonical configuration baselines. Under Option 4, we do NOT copy OC1's workspace — we rebuild from canonical baselines.

### 9.1 Create Workspace Directory Structure

```bash
mkdir -p ~/.openclaw/workspace/{docs,scripts,state,memory,schema,infra,security,governance,legal,qa,patterns,reports,archive,skills,agent-skills}
mkdir -p ~/.openclaw/agents/{main,business,architect,platform-arch,infra,ahsoka,social,biz-process,change-mgt,security,legal,qa,governance}/agent
```

### 9.2 Create Core Workspace Files

These files define agent identity and behavior. They must be rebuilt from canonical baselines, not copied from OC1.

#### SOUL.md (≤10,000 chars hard limit)

```bash
cat > ~/.openclaw/workspace/SOUL.md <<'EOF'
# Yoda 🟢 — SOUL.md

## Identity
- **Name:** Yoda
- **Role:** Lead Orchestrator — AInchors Nexus Platform
- **Node:** OC2A (Production)
- **Model:** ollama/kimi-k2.7-code:cloud (primary)

## Core Traits
- Wise, patient, methodical
- Evidence-driven; never fabricates
- Human authority always final (Ken & Angie)
- Security-first; governance-always

## Non-Negotiables
1. HUMAN AUTHORITY: Ken and Angie always have final say.
2. HITL GATES: Never self-approve outputs requiring human sign-off.
3. SKILL-FIRST RULE: Load skills before calling domain scripts.
4. NO FABRICATION: If unknown, say so and find out.
5. EVIDENCE-ONLY: Validated + artifact-backed.
6. CREST MANDATORY: Every execution plan runs through CREST.
7. ORCHESTRATOR ONLY: Plan, Verify, Replan, Synthesize, Close. Execute is Forge's domain.
8. SECURITY FIRST: S1–S7 controls always live.
9. CHG DISCIPLINE: Structural change = CHG record before execution.
10. ASYNC BACKGROUND: Tasks >30s via sessions_spawn.
11. SUBAGENT COMPLETION UPDATE: Always synthesize and report subagent results.
12. BOUNDARIES: Private stays private. Ask before acting externally.
13. SANCTUM PROTOCOL: External outputs → Shield → Lex → Sage.
14. DATA SOVEREIGNTY: Client data = Tier 0/1 local only.
15. TELEGRAM CHUNKING: All Telegram messages ≤3,800 chars.
16. FORGE EXECUTE GATE: Yoda never directly edits scripts/infra/build files.
17. SILENT REPLY RULE: Nothing to say → single NO_REPLY.

## Option 4 Awareness
- OC2A is the sole production authority.
- OC1 is a non-privileged sandbox with NO admin path to OC2A.
- Configuration is rebuilt from canonical baselines, never copied from OC1.
- Promotion path: OC1 sandbox → review → reimplement on OC2A.
EOF
```

#### AGENTS.md (≤12,000 chars)

```bash
cat > ~/.openclaw/workspace/AGENTS.md <<'EOF'
# Yoda 🟢 — AGENTS.md

Behavioral rules, procedures, and operational notes for Yoda on OC2A (Production).

## Agent-Specific Behavioral Rules

### My Non-Negotiables
1. HUMAN AUTHORITY: Ken and Angie always have final say. I recommend. They decide.
2. HITL GATES: I never self-approve outputs that require human sign-off.
3. SKILL-FIRST RULE: Before calling any domain script, I MUST load its skill.
4. NO FABRICATION: If I don't know, I say so and find out.
5. EVIDENCE-ONLY: Done/closed/verified = validated + backed by artifacts.
6. CREST MANDATORY: Every plan involving execution work runs through CREST.
7. ORCHESTRATOR ONLY: My CREST activities = Plan, Verify, Replan, Synthesize, Close. Execute is NEVER mine.
8. SECURITY FIRST: S1–S7 controls are always live. Warden is always watching.
9. CHG DISCIPLINE: Every structural change has a CHG record before execution.
10. ASYNC BACKGROUND: Tasks > 30s must run via sessions_spawn.
11. SUBAGENT COMPLETION UPDATE RULE: Always synthesize and report subagent results.
12. BOUNDARIES: Private things stay private. Ask before acting externally.
13. SANCTUM PROTOCOL: All external/client outputs pass Shield → Lex → Sage.
14. DATA SOVEREIGNTY: Client data = Tier 0/1 local ONLY.
15. TELEGRAM CHUNKING: All Telegram messages MUST be chunked at 3,800 chars.
16. FORGE EXECUTE GATE: Yoda NEVER directly edits scripts/, infra/, or build/config files.
17. SILENT REPLY RULE: Nothing user-facing → single NO_REPLY.

### CREST + Forge Enforcement
- NEVER directly edit scripts/, infra/, or build-related files.
- No exception for "small", "urgent", or "already in context" fixes.
- Ken or Angie can grant per-instance exception. Default = no.

### Journal Discipline — NON-NEGOTIABLE
After every meaningful exchange with Ken: append to today's journal.
File: `memory/journal-YYYY-MM-DD.md`.

### Option 4: OC2A Production Context
- OC2A is the sole production Nexus authority.
- OC1 is a non-privileged sandbox.
- No auto-propagation from OC1 to OC2A.
- Promotion: OC1 sandbox → review → reimplement on OC2A.
EOF
```

#### USER.md

```bash
cat > ~/.openclaw/workspace/USER.md <<'EOF'
# USER.md — Ken Mun

## Identity
- **Name:** Ken Mun
- **Role:** CTO, AInchors
- **Authority:** Final decision-maker for all production changes
- **Primary Contact:** Telegram (Ken), webchat on OC2A

## Angie
- **Name:** Angie
- **Role:** Co-founder, AInchors
- **Authority:** Co-equal with Ken for business decisions
- **Primary Contact:** Telegram (Angie)

## Preferences
- Prefers concise, evidence-backed recommendations
- Values security and governance above speed
- Expects CHG records for all structural changes
- Prefers async updates via Telegram for non-urgent matters
EOF
```

#### MEMORY.md

```bash
cat > ~/.openclaw/workspace/MEMORY.md <<'EOF'
# MEMORY.md — OC2A Production

## Platform
- **Node:** OC2A (Mac Mini M4 Pro, 48GB RAM)
- **Role:** Production Nexus — sole authority
- **Gateway:** local mode, port 18789
- **Database:** PostgreSQL 16 on localhost:5432
- **Ollama:** Cloud-only via shared Ollama Cloud account

## Topology (Option 4)
- OC2A: Production — self-governing
- OC1: Sandbox — non-privileged, no admin path to OC2A
- OC2B: TBD (planned after OC2A validation)

## Key Decisions
- Option 4 strong separation chosen 2026-07-12
- Fresh install, not clone of OC1
- Configuration rebuilt from canonical baselines
EOF
```

#### HEARTBEAT.md

```bash
cat > ~/.openclaw/workspace/HEARTBEAT.md <<'EOF'
# HEARTBEAT.md — OC2A Production

## Agent Fleet
| Agent | ID | Role | Status |
|-------|-----|------|--------|
| Yoda 🟢 | main | Lead Orchestrator | Active |
| Aria 🔵 | business | Business Lead | Active |
| Atlas 🏛️ | architect | Enterprise Architecture | Active |
| Thrawn | platform-arch | AI Platform Architecture | Active |
| Forge 🏗️ | infra | Build, SRE, Ops | Active |
| Ahsoka | ahsoka | Client Discovery | Active |
| Spark ✨ | social | Social/Marketing | Active |
| Lando | biz-process | Business Process Design | Active |
| Mon Mothma | change-mgt | Change Governance | Active |
| Shield 🛡️ | security | Security & Compliance | Active |
| Lex ⚖️ | legal | Legal & Regulatory | Active |
| Sage 🧪 | qa | Quality Assurance | Active |
| Warden | governance | Model/Policy Enforcement | Active |

## Channels
- Telegram: Ken, Angie
- LinkedIn: AInchors company page
- Webchat: OC2A gateway
- Crons: Daily close, health checks, backups

## Option 4
- OC1 is sandbox only — no admin path to OC2A
- Promotion: OC1 sandbox → review → reimplement on OC2A
EOF
```

### 9.3 Create TOOLS.md (OC2A-Specific)

```bash
cat > ~/.openclaw/workspace/TOOLS.md <<'EOF'
# TOOLS.md — OC2A Production

## Node Identity
- **Hostname:** ainchorsoc2as-mac-mini.tailfc3ed1.ts.net
- **Tailscale IP:** 100.112.241.16
- **Local IP:** 192.168.1.126
- **Hardware:** Mac Mini M4 Pro, 48GB RAM

## Port Convention (LOCKED)
| Port | Environment | Purpose |
|------|------------|---------|
| 18789 | Production | Main gateway (Nexus platform) |
| 18791 | Production | Browser control sidecar |

## PostgreSQL
- **Version:** 16
- **Database:** ainchors_nexus
- **Host:** localhost:5432
- **Wrapper:** ~/.openclaw/workspace/scripts/db.sh

## Ollama Cloud
- **Account:** Shared with OC1
- **Endpoint:** TBD (configure during setup)

## Remote Access
- **Tailscale SSH:** Primary remote access
- **No VNC/RDP:** Not configured
- **No OC1 admin path:** Enforced by Option 4

## Google (gog)
- **Account:** kenmun@ainchors.com
- **Binary:** /opt/homebrew/bin/gog
- **Setup:** To be configured post-install

## Docker / Colima
- **Not installed by default:** Install only if needed for sandbox/experiments
- **If needed:** brew install colima docker
EOF
```

### 9.4 Create RULES.md (Canonical Governance Baseline)

```bash
cat > ~/.openclaw/workspace/RULES.md <<'EOF'
# RULES.md — AInchors Operational Rules (OC2A Production)
_Last updated: 2026-07-12_

## SUGGEST SIMPLER ALTERNATIVES FIRST (NON-NEGOTIABLE)
Before deep-diving into a complex technical solution, surface simple alternatives:
1. State complexity/risk in ONE sentence
2. List 2-3 simpler alternatives with estimated setup time
3. Let Ken choose — then execute

## API KEY ROTATION RULE (NON-NEGOTIABLE)
Rotating any API key is a 2-step atomic operation:
1. Update openclaw.json / gateway config
2. Update macOS Keychain via secrets-init.sh
Run PVT (9/9) to verify ALL consumers before closing the CHG.

## SOUL.MD SIZE RULE (NON-NEGOTIABLE)
- Hard limit: 10,000 chars
- Warning threshold: 6,000 chars
- Pattern: SOUL.md = identity + traits + brief rules only
- All procedures in RULES.md

## ISOLATED CRON VISIBILITY RULE (NON-NEGOTIABLE)
Isolated crons have no access to other agents' session history.
Any cron reporting on another agent's activity MUST call sessions_history(sessionKey).

## ROOT CAUSE RULE (NON-NEGOTIABLE)
Never attempt a fix without confirmed root cause.

## OPTION 4: OC2A PRODUCTION RULES
1. OC1 has NO admin path to OC2A — no SSH, no tokens, no node pairing.
2. All production changes happen ON OC2A, by OC2A's Forge.
3. Configuration is rebuilt from canonical baselines, never copied from OC1.
4. Promotion path: OC1 sandbox → review → reimplement on OC2A.
5. OC1 can read OC2A health endpoints only (read-only observability).
EOF
```

### 9.5 Gate: Workspace Initialized

- [ ] Directory structure created
- [ ] SOUL.md created (≤10,000 chars)
- [ ] AGENTS.md created (≤12,000 chars)
- [ ] USER.md created
- [ ] MEMORY.md created
- [ ] HEARTBEAT.md created
- [ ] TOOLS.md created (OC2A-specific)
- [ ] RULES.md created (canonical baseline)
- [ ] All files are fresh (not copied from OC1)

---

## 10. Smoke-Test Command List

**Goal:** Run a comprehensive smoke-test suite to validate the OC2A installation end-to-end.

### 10.1 System-Level Tests

```bash
# Test 1: macOS health
sw_vers && uptime && df -h / && vm_stat | head -5

# Test 2: Network
ping -c 2 1.1.1.1 && tailscale status | head -3

# Test 3: Homebrew
brew doctor 2>&1 | head -5

# Test 4: PostgreSQL
/opt/homebrew/opt/postgresql@16/bin/pg_isready
~/.openclaw/workspace/scripts/db.sh -c "SELECT 1 AS smoke_test;"
```

### 10.2 OpenClaw Tests

```bash
# Test 5: CLI version
openclaw --version

# Test 6: Config validation
openclaw config validate

# Test 7: Gateway status
openclaw gateway status

# Test 8: Node status
openclaw node status

# Test 9: Full status
openclaw status
```

### 10.3 Network Tests

```bash
# Test 10: Local gateway health
curl -s http://127.0.0.1:18789/health | jq .

# Test 11: Tailscale serve
tailscale serve status

# Test 12: Tailscale hostname health (from OC2A)
curl -s https://ainchorsoc2as-mac-mini.tailfc3ed1.ts.net/health | jq .
```

### 10.4 Service Persistence Tests

```bash
# Test 13: LaunchAgent files present
ls -la ~/Library/LaunchAgents/com.openclaw.gateway.plist
ls -la ~/Library/LaunchAgents/com.openclaw.node.plist

# Test 14: PostgreSQL LaunchAgent
ls -la ~/Library/LaunchAgents/homebrew.mxcl.postgresql@16.plist 2>/dev/null || echo "Check brew services list"
brew services list | grep postgresql@16
```

### 10.5 Security Tests (Option 4 Verification)

**Run on OC1:**

```bash
# Test 15: OC1 cannot SSH to OC2A
ssh -o ConnectTimeout=5 ainchorsoc2as-mac-mini.tailfc3ed1.ts.net 2>&1 | head -3
# Expected: Connection refused or timeout (no SSH key on OC1 for OC2A)

# Test 16: OC1 cannot authenticate to OC2A gateway
curl -s -o /dev/null -w "%{http_code}" https://ainchorsoc2as-mac-mini.tailfc3ed1.ts.net/api/status
# Expected: 401 or 403 (no token)

# Test 17: OC1 CAN read OC2A health endpoint
curl -s https://ainchorsoc2as-mac-mini.tailfc3ed1.ts.net/health | jq .
# Expected: 200 with health JSON
```

### 10.6 Smoke-Test Pass Criteria

| Test # | Name | Expected Result |
|--------|------|----------------|
| 1 | macOS health | Sequoia 15.x, ≥50GB free |
| 2 | Network | Ping OK, Tailscale connected |
| 3 | Homebrew | No critical errors |
| 4 | PostgreSQL | Accepting connections, query works |
| 5 | CLI version | 2026.6.11+ |
| 6 | Config validate | No errors |
| 7 | Gateway status | Running |
| 8 | Node status | Connected |
| 9 | Full status | Healthy |
| 10 | Local health | 200 OK |
| 11 | Tailscale serve | Active proxy |
| 12 | TS hostname health | 200 OK |
| 13 | LaunchAgents | Files present |
| 14 | PG service | Started |
| 15 | OC1 SSH blocked | Connection refused |
| 16 | OC1 auth blocked | 401/403 |
| 17 | OC1 health read | 200 OK |

---

## 11. Common Failure Modes & Recovery

### 11.1 Gateway Won't Start

**Symptoms:** `openclaw gateway status` shows `stopped` or `error`.

**Checks:**
```bash
# Check if port is in use
lsof -i :18789

# Check LaunchAgent logs
tail -50 ~/Library/Logs/com.openclaw.gateway.log 2>/dev/null || \
  log show --predicate 'process == "openclaw"' --last 5m

# Check config validity
openclaw config validate
```

**Fixes:**
1. Kill conflicting process on port 18789: `lsof -ti :18789 | xargs kill -9`
2. Fix config errors reported by `openclaw config validate`
3. Reload LaunchAgent: `launchctl unload ~/Library/LaunchAgents/com.openclaw.gateway.plist && launchctl load ~/Library/LaunchAgents/com.openclaw.gateway.plist`
4. If all else fails, re-run onboarding: `openclaw onboard`

### 11.2 Node Won't Connect to Gateway

**Symptoms:** `openclaw node status` shows `disconnected`.

**Checks:**
```bash
# Verify gateway is running first
openclaw gateway status

# Check node logs
tail -50 ~/Library/Logs/com.openclaw.node.log 2>/dev/null

# Verify token matches
openclaw config get gateway.auth.token
```

**Fixes:**
1. Ensure gateway is running (fix gateway first if needed)
2. Restart node: `launchctl unload ~/Library/LaunchAgents/com.openclaw.node.plist && launchctl load ~/Library/LaunchAgents/com.openclaw.node.plist`
3. Re-pair node: `openclaw node pair` (if available)

### 11.3 PostgreSQL Won't Start

**Symptoms:** `pg_isready` returns `no response`.

**Checks:**
```bash
# Check PostgreSQL logs
tail -50 /opt/homebrew/var/log/postgresql@16.log

# Check if port is in use
lsof -i :5432

# Check brew services
brew services list | grep postgresql@16
```

**Fixes:**
1. Start manually: `/opt/homebrew/opt/postgresql@16/bin/pg_ctl -D /opt/homebrew/var/postgresql@16 -l /opt/homebrew/var/log/postgresql@16.log start`
2. If port conflict: `lsof -ti :5432 | xargs kill -9` then restart
3. If data directory corrupted: re-run `initdb` (⚠️ DESTRUCTIVE — only if no data exists)
4. Restart via brew: `brew services restart postgresql@16`

### 11.4 Tailscale Serve Not Working

**Symptoms:** `tailscale serve status` shows no proxy or error.

**Checks:**
```bash
# Verify Tailscale is connected
tailscale status

# Check serve configuration
tailscale serve status

# Test direct gateway access
curl -s http://127.0.0.1:18789/health
```

**Fixes:**
1. Ensure Tailscale is connected: `tailscale up`
2. Re-apply serve: `tailscale serve --bg --https=443 http://127.0.0.1:18789`
3. Reset serve: `tailscale serve reset` then re-apply
4. Verify gateway is running on 127.0.0.1:18789 first

### 11.5 Homebrew Install Failures

**Symptoms:** `brew install` hangs or fails.

**Checks:**
```bash
brew doctor
brew update
```

**Fixes:**
1. Run `brew doctor` and follow recommendations
2. Update Homebrew: `brew update`
3. Clean up: `brew cleanup`
4. For Xcode/CLT issues: `xcode-select --install`

### 11.6 npm Global Install Permission Issues

**Symptoms:** `EACCES` errors when running `npm install -g openclaw`.

**Fixes:**
```bash
# Option A: Use npx instead
npx openclaw@latest --version

# Option B: Fix npm permissions (preferred for OC2A)
npm config set prefix /opt/homebrew
# Then re-run: npm install -g openclaw@latest
```

### 11.7 Option 4 Violation: OC1 Has Access

**Symptoms:** OC1 can SSH to OC2A or authenticate to OC2A gateway.

**This is a SECURITY INCIDENT under Option 4.**

**Immediate actions:**
1. **On OC2A:** Rotate the gateway token immediately:
   ```bash
   openclaw config set gateway.auth.token "$(openssl rand -hex 24)"
   openclaw gateway restart
   ```
2. **On OC2A:** Remove any OC1 SSH authorized keys:
   ```bash
   # Check ~/.ssh/authorized_keys for OC1 keys
   cat ~/.ssh/authorized_keys
   ```
3. **On OC1:** Delete any OC2A tokens, keys, or credentials from workspace and Keychain.
4. **Document** the incident and re-verify Option 4 isolation.

### 11.8 Gateway Won't Survive Reboot

**Symptoms:** After reboot, gateway is not running.

**Checks:**
```bash
# Verify LaunchAgent is loaded
launchctl list | grep openclaw

# Check if RunAtLoad is true
plutil -p ~/Library/LaunchAgents/com.openclaw.gateway.plist | grep RunAtLoad
```

**Fixes:**
1. Reload the LaunchAgent: `launchctl load ~/Library/LaunchAgents/com.openclaw.gateway.plist`
2. If plist is missing, reinstall: `openclaw gateway service install`
3. Check system log for launchd errors: `log show --predicate 'process == "launchd"' --last 10m | grep openclaw`

---

## 12. Appendix: Reference Values

### 12.1 Port Map

| Port | Service | Bind | Auth |
|------|---------|------|------|
| 18789 | OpenClaw Gateway | 127.0.0.1 | Tailscale + Token |
| 5432 | PostgreSQL 16 | 127.0.0.1 | Password roles |
| 443 | Tailscale Serve (HTTPS) | Tailnet only | Tailscale auth |

### 12.2 File Paths

| Path | Purpose |
|------|---------|
| `~/.openclaw/openclaw.json` | Main configuration |
| `~/.openclaw/workspace/` | Agent workspace |
| `~/.openclaw/agents/` | Agent definitions |
| `~/Library/LaunchAgents/com.openclaw.gateway.plist` | Gateway auto-start |
| `~/Library/LaunchAgents/com.openclaw.node.plist` | Node auto-start |
| `/opt/homebrew/var/postgresql@16/` | PostgreSQL data directory |
| `/opt/homebrew/var/log/postgresql@16.log` | PostgreSQL logs |
| `~/.openclaw/workspace/scripts/db.sh` | Database access wrapper |

### 12.3 Key Commands Quick Reference

```bash
# Gateway
openclaw gateway status          # Check gateway health
openclaw gateway restart         # Restart gateway
openclaw config validate         # Validate configuration
openclaw config get <path>       # Read config value
openclaw config set <path> <val> # Set config value

# Node
openclaw node status             # Check node health
openclaw status                  # Full system status
openclaw qr --json               # Generate pairing QR

# Services
launchctl list | grep openclaw   # Check LaunchAgents
brew services list                # Check brew services

# PostgreSQL
pg_isready                       # Check PG status
~/.openclaw/workspace/scripts/db.sh -c "<SQL>"  # Run query

# Tailscale
tailscale status                 # Check Tailscale status
tailscale serve status           # Check serve config
tailscale ping <host>            # Test tailnet connectivity

# Logs
tail -50 ~/Library/Logs/com.openclaw.gateway.log
tail -50 /opt/homebrew/var/log/postgresql@16.log
```

### 12.4 Option 4 Isolation Verification Checklist

| Check | Command (run on OC1) | Expected |
|-------|---------------------|----------|
| SSH blocked | `ssh -o ConnectTimeout=5 oc2a.tailnet` | Connection refused |
| Gateway auth blocked | `curl -s -o /dev/null -w "%{http_code}" https://oc2a.tailnet/api/status` | 401 or 403 |
| Health read OK | `curl -s https://oc2a.tailnet/health` | 200 |
| No OC2A token in OC1 Keychain | `security find-generic-password -s 'oc2a-gateway' 2>&1` | Not found |
| No OC2A SSH key on OC1 | `ssh-keygen -lf ~/.ssh/id_* 2>/dev/null` | No OC2A-labeled keys |

---

## Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-07-12 | Forge 🏗️ (OC2A infra agent) | Initial runbook for Option 4 fresh install |

**Next Steps After This Runbook:**
1. Ken approves this runbook
2. Ken enables Remote Login / Tailscale SSH on OC2A (Phase 0)
3. Forge on OC2A executes this runbook (Phase 1)
4. Agent provisioning begins (Phase 2)
5. Data migration and operational readiness (Phase 3)
6. Validation and cutover (Phase 4)
7. OC1 demotion to sandbox (Phase 5)

---

*This runbook is for execution ON OC2A by OC2A's Forge agent. Do not execute from OC1.*
