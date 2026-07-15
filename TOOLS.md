# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's unique to your setup.

## What Goes Here

Things like:

- Camera names and locations
- SSH hosts and aliases
- Preferred voices for TTS
- Speaker/room names
- Device nicknames
- Anything environment-specific

## Examples

```markdown
### Cameras

- living-room → Main area, 180° wide angle
- front-door → Entrance, motion-triggered

### SSH

- home-server → 192.168.1.100, user: admin

### TTS

- Preferred voice: "Nova" (warm, slightly British)
- Default speaker: Kitchen HomePod
```

## Why Separate?

Skills are shared. Your setup is yours. Keeping them apart means you can update skills without losing your notes, and share skills without leaking your infrastructure.

---

Add whatever helps you do your job. This is your cheat sheet.

## Google (gog)

- Account: `kenmun@ainchors.com`
- Set env: `export GOG_ACCOUNT=kenmun@ainchors.com`
- Services: gmail, calendar, drive, contacts, sheets, docs
- Credentials: `~/Library/Application Support/gogcli/credentials.json`
- OAuth client: `966422666914` (project: AInchors OC1)
- Token stored: macOS Keychain (default client)
- Connected: 2026-07-14
- Binary: `/Users/ainchorsoc2a/homebrew/bin/gog` — **always use full path** in exec/cron (minimal PATH won't find it)

- `docker` → `/opt/homebrew/bin/docker` — brew standalone CLI (Docker Desktop removed 2026-05-11)
- `colima` → `/opt/homebrew/bin/colima` — container runtime, replaces Docker Desktop
- Colima auto-starts at login: `brew services start colima` (active)
- Colima socket: `unix:///Users/ainchorsoc2a/.colima/default/docker.sock`
- Docker context: `colima` (active, set as default)
- RustDesk containers managed via: `/Users/ainchorsoc2a/.openclaw/workspace/infra/rustdesk/`

### Homebrew on OC2A
- Homebrew prefix: `/Users/ainchorsoc2a/homebrew` (not `/opt/homebrew`).
- `brew` → `/Users/ainchorsoc2a/homebrew/bin/brew`
- `psql` → `/Users/ainchorsoc2a/homebrew/bin/psql`
- `minio`, `mc` → `/Users/ainchorsoc2a/homebrew/bin/minio`, `/Users/ainchorsoc2a/homebrew/bin/mc`
- `gog` → configured for both Ken (kenmun@ainchors.com) and Angie (angie.foong@ainchors.com). Services: gmail, calendar, drive, contacts, sheets, docs. OAuth client 966422666914 (project: AInchors OC1). Updated: 2026-07-14.

## Remote Access

- **RustDesk (primary):** public relay, connect by OC2A ID (visible in app UI) — no custom server. (OC1 was repurposed to dev/test 2026-07-14.)
- **Google Remote Desktop:** works when OC2A is logged in — use RustDesk first to get past login/lock screen, then CRD for full session
- **Workaround for lock screen:** RustDesk → unlock OC2A → CRD takes over. Accepted pattern, no further VNC work planned.
- **Tailscale (OC2A):**
  - IP: `100.123.95.47` — replaces OC1 Tailscale IP `100.91.60.36`
  - Hostname: `ainchorsoc2as-mac-mini-1.tailfc3ed1.ts.net`
  - Version: `1.98.8` (Homebrew)
  - Daemon: `/opt/homebrew/opt/tailscale/bin/tailscaled` (running, root-owned)
  - CLI: `/opt/homebrew/bin/tailscale` — **always use this path**; the `/Applications/Tailscale.app/Contents/MacOS/Tailscale` GUI CLI is **not installed**
  - Status: `BackendState: Running`; mesh IP responds to ping
- **Tailscale (OC1):**
  - IP: `100.75.171.40`
  - Hostname: `ainchorss-mac-mini.tailfc3ed1.ts.net`
  - Role: Dev/test passive standby (repurposed 2026-07-14)
  - Gateway: `https://ainchorss-mac-mini.tailfc3ed1.ts.net` (Tailscale serve → http://127.0.0.1:18789)
  - OpenClaw version: `2026.7.1` (confirmed 2026-07-15)
  - SSH access: `ssh -i ~/.ssh/id_oc2a_oc1 ainchorsangiefpl@ainchorss-mac-mini.tailfc3ed1.ts.net` (enabled 2026-07-15; key id_oc2a_oc1 authorized)
- **VNC:** attempted 2026-05-11 on OC1, abandoned — macOS RFB 003.889 + Tailscale utun4 TCP_NODELAY incompatibility. Not worth the complexity.

## Port Convention (LOCKED 2026-06-08 — Ken Mun)
| Port | Environment | Purpose |
|------|------------|---------|
| 18789 | Production | Main gateway (Nexus platform) |
| 18791 | Production | Browser control sidecar |
| 28789 | Sandbox | Isolated Forge/build/infra gateway |
| 38789 | Shadow | Read-only production mirror for CI/staging validation |

**Rule:** Production = 1xxxx series. Sandbox = 2xxxx series. Shadow = 3xxxx series. Never cross.

## Notion DB IDs (CHG-0401 3-DB architecture)
Canonical API patterns and usage: `agent-skills/notion/SKILL.md`.

- DB A (Backlog): 39d890b6-ece8-81bf-9c3a-eb784cf09c05
- DB B (Auto-Heal): 39d890b6-ece8-8101-8516-f515f0905ca9
- DB C (Archive): 39d890b6-ece8-81fd-8826-d250c3c2df13
