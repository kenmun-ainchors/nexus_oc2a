
## CHG-0470 — Forge Sandbox Boundary Hardening + Auto-Heal CHECK 18
- **Date:** 2026-06-08
- **Type:** incident
- **Source:** Yoda + TKT-0332
- **Trigger:** INC-20260608-001 — Gateway 30-min SIGTERM reboot loop from Forge sandbox write side-effect
- **Changed:**
  - Forge RULES.md: Added Sandbox Write Boundary section — forbidden paths listed, escalate-to-Yoda rule
  - Auto-heal.sh: Added CHECK 18 (orphaned gateway process detection — detects orphaned openclaw PIDs holding port 18789, auto-kills if active gateway exists, escalates to Ken if no active gateway)
  - LESSONS.md: Registered L-050 (Failed sandbox writes trigger side-effect gateway outages)
  - LaunchAgent plist regenerated to v2026.5.27 (resolved 5.12→5.27 version mismatch)
- **Why:** Forge attempted write to nexus-sandbox/openclaw.json → sandbox escape guard blocked write → but failed attempt triggered OpenClaw config validation → detected version mismatch → regenerated gateway token → restart loop → 35-min outage
- **Verified:** auto-heal.sh bash -n OK. Gateway running clean (PID 82305). Forge RULES.md updated.
- **Linked:** TKT-0332, INC-20260608-001, L-050, INC-20260511-001

## CHG-0466 — Nexus Controller Build Scaffolding (TKT-0333)
- **Date:** 2026-06-08
- **Type:** build
- **Source:** Infra subagent
- **Trigger:** TKT-0333 — Complete Atoms 4-11 of Nexus Controller scaffold
- **Changed:**
  - **Atom 4** ✅: Sandbox LaunchAgent plist created at ~/Library/LaunchAgents/ai.openclaw.sandbox-gateway.plist (port 28789, RunAtLoad=false)
  - **Atom 5** ✅: CI workflow verified/fixed (.github/workflows/ci.yml — PR→main trigger, self-hosted runner, lint+test)
  - **Atom 6** ✅: Env configs created (sandbox.env.example, prod.env.example), *.env in .gitignore
  - **Atom 7** ✅: Secrets stored in macOS Keychain (nexus-controller-sandbox-db, nexus-controller-prod-db)
  - **Atom 8** ⚠️: Skipped — backup.sh has no PG dump section to inject controller_* pattern
  - **Atom 9** ✅: CHECK 19 added to auto-heal.sh (sandbox gateway liveness on port 28789, bash -n OK)
  - **Atom 10** ✅: Git tag v0.1.0-scaffold created, TRIGGERS.md with TRIGGER-04 stub
  - **Atom 11** ✅: CHANGELOG entry appended, Notion page created in DB A (Backlog)
- **Why:** Foundation scaffolding required before Nexus Controller deployment (CHG-0421). Establishes sandbox gateway environment, CI wiring, secrets management, observability check, and version baseline.
- **Verified:** plutil -lint OK, YAML valid syntax, Keychain secrets confirmed, bash -n OK, git tag visible
- **Linked:** TKT-0333, CHG-0466, Atoms 4-11
- **Atoms 1-3:** Previously completed (scaffold dirs, PR template, GH Actions runner)
- **Port Convention (LOCKED):** Prod gateway: 18789, Sandbox gateway: 28789, Browser control: 18791
