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

- **VNC (primary):** `vnc://100.91.60.36:5900` — screensharingd on Tailscale IP, direct (no proxy)
  - Works at login/lock screen ✅
  - macOS: Finder → Go → Connect to Server → `vnc://100.91.60.36:5900`
  - Windows/other: any VNC client to `100.91.60.36:5900`
- **Google Remote Desktop:** works after VNC login (use VNC to unlock, then CRD for session)
- **RustDesk:** public relay, connect by OC1 ID (visible in app UI) — no custom server
- **Tailscale IP (OC1):** `100.91.60.36`
