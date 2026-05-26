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

- Account: `angie.foong@ainchors.com`
- Set env: `export GOG_ACCOUNT=angie.foong@ainchors.com`
- Services: gmail, calendar, drive, contacts, sheets, docs
- Authenticated: 2026-04-30 (OAuth, OC1)
- Binary: `/opt/homebrew/bin/gog` — **always use full path** (exec runs with minimal PATH, `gog` alone will fail)

### gog CLI Cheat Sheet (Aria use — always use full path /opt/homebrew/bin/gog)

**Calendar — list events:**
```bash
GOG_ACCOUNT=angie.foong@ainchors.com /opt/homebrew/bin/gog calendar list --max 10
```

**Calendar — create event:**
```bash
GOG_ACCOUNT=angie.foong@ainchors.com /opt/homebrew/bin/gog calendar create primary \
  --summary "Meeting title" \
  --from "2026-05-08T15:00:00+10:00" \
  --to "2026-05-08T16:00:00+10:00" \
  --attendees "person@email.com" \
  --with-meet \
  --send-updates all \
  --no-input
```
⚠️ Use `--summary` (NOT `--title`), `--from`/`--to` (NOT `--start`/`--end`), always `--no-input`

**Gmail — send email:**
```bash
GOG_ACCOUNT=angie.foong@ainchors.com /opt/homebrew/bin/gog gmail send \
  --to "recipient@email.com" \
  --subject "Subject line" \
  --body "Email body text" \
  --no-input
```

**Gmail — list unread:**
```bash
GOG_ACCOUNT=angie.foong@ainchors.com /opt/homebrew/bin/gog gmail list --unread --max 10
```

**Gmail — send HTML email:**
```bash
GOG_ACCOUNT=angie.foong@ainchors.com /opt/homebrew/bin/gog gmail send \
  --to "recipient@email.com" \
  --subject "Subject" \
  --body-html "<html>...</html>" \
  --no-input
```

**Always dry-run first for creates/sends:**
```bash
... --dry-run
```

## Related

- [Agent workspace](/concepts/agent-workspace)
