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
- Connected: 2026-04-29
- Binary: `/opt/homebrew/bin/gog` — **always use full path** in exec/cron (minimal PATH won't find it)

## Docker / Colima

- `docker` → `/opt/homebrew/bin/docker` — brew standalone CLI (Docker Desktop removed 2026-05-11)
- `colima` → `/opt/homebrew/bin/colima` — container runtime, replaces Docker Desktop
- Colima auto-starts at login: `brew services start colima` (active)
- Colima socket: `unix:///Users/ainchorsangiefpl/.colima/default/docker.sock`
- Docker context: `colima` (active, set as default)
- RustDesk containers managed via: `/Users/ainchorsangiefpl/.openclaw/workspace/infra/rustdesk/`

## Remote Access

- **RustDesk (primary):** public relay, connect by OC1 ID (visible in app UI) — no custom server
- **Google Remote Desktop:** works when OC1 is logged in — use RustDesk first to get past login/lock screen, then CRD for full session
- **Workaround for lock screen:** RustDesk → unlock OC1 → CRD takes over. Accepted pattern, no further VNC work planned.
- **Tailscale IP (OC1):** `100.91.60.36`
- **VNC:** attempted 2026-05-11, abandoned — macOS RFB 003.889 + Tailscale utun4 TCP_NODELAY incompatibility. Not worth the complexity.

## Port Convention (LOCKED 2026-06-08 — Ken Mun)
| Port | Environment | Purpose |
|------|------------|---------|
| 18789 | Production | Main gateway (Nexus platform) |
| 18791 | Production | Browser control sidecar |
| 28789 | Sandbox | Isolated Forge/build/infra gateway |
| 38789 | Shadow | Read-only production mirror for CI/staging validation |

**Rule:** Production = 1xxxx series. Sandbox = 2xxxx series. Shadow = 3xxxx series. Never cross.

## Notion DB IDs (CHG-0401 3-DB architecture)
- DB A (Backlog): 34dc1829-53ff-814b-8257-d3a3bf351d44
- DB B (Auto-Heal): 364c1829-53ff-81c0-9dbd-ff2c907d1a6b
- DB C (Archive): 364c1829-53ff-818e-a783-ebafcb6a9880
