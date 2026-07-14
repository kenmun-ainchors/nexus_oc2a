# CHG-DRAFT — OC2A Config & Documentation Cleanup

**Status:** DRAFT — pending Ken approval  
**Proposed CHG-ID:** CHG-0AAA  
**Date:** 2026-07-14 00:37 AEST  
**Type:** Normal  
**Source:** CREST post-migration shakedown — comprehensive OpenClaw/Nexus readiness  
**Triggered by:** Ken requested full check that platform is fully running off OC2A with no OC1-tied misconfiguration; Telegram setup flagged by `openclaw doctor`.

## Current findings
1. **Telegram (OpenClaw doctor warnings):**
   - No `channels.telegram.defaultAccount` / `accounts.default` configured — falls back to `aria`.
   - No `commands.ownerAllowFrom` configured — no Telegram user can run owner-only commands (`/diagnostics`, `/config`, `/export-trajectory`) or approve dangerous exec actions.
2. **Service environment PATH stale:** `~/.openclaw/service-env/ai.openclaw.gateway.env` and `ai.openclaw.node.env` list `/opt/homebrew/bin:/opt/homebrew/sbin` but omit the actual Homebrew prefix on this host (`/Users/ainchorsoc2a/homebrew`). Gateway/node-spawned shells cannot find `psql`, `minio`, `mc`, `brew`, etc.
3. **Agent workspace rule/config files stale:**
   - `workspace-business`, `workspace-dtcm`, `workspace-bpm`, `workspace-luthen`, `workspace-ahsoka`, `workspace-social`, `workspace-governance`, `workspace-architect`, `workspace-qa`, `workspace-legal`, `workspace-platform-arch` contain `ainchorsangiefpl` and/or old Tailscale hostname `ainchorss-mac-mini.tail5e2567.ts.net` in `.md` rule/config files.
4. **Main workspace docs stale:** Several docs still reference old Tailscale MinIO endpoint.
5. **No stale references found in:** `openclaw.json` itself, cron payloads.

## What changed (proposed)
1. **Telegram config (openclaw.json):**
   - Set `channels.telegram.defaultAccount` to `"yoda"` (Ken's primary bot `@AInchorsOC1Bot` is bound to the `yoda` account).
   - Set `commands.ownerAllowFrom` to `["telegram:8574109706"]` (Ken Mun's Telegram chat ID).
2. **Service env PATH fix:**
   - Update both `~/.openclaw/service-env/ai.openclaw.gateway.env` and `ai.openclaw.node.env` PATH to include `/Users/ainchorsoc2a/homebrew/bin:/Users/ainchorsoc2a/homebrew/sbin` and remove the non-existent `/opt/homebrew` paths.
3. **Agent workspace rule/config cleanup:**
   - In each active agent workspace listed above, replace:
     - `/Users/ainchorsangiefpl/.openclaw/workspace` → `/Users/ainchorsoc2a/.openclaw/workspace`
     - `ainchorsangiefpl` DB/user references → `ainchorsoc2a` where it denotes the local OS/DB user
     - `ainchorss-mac-mini.tail5e2567.ts.net` → `ainchorsoc2as-mac-mini-1.tailfc3ed1.ts.net`
   - Skip the pre-cutover backup workspace `workspace-pre-cutover-bak-20260713-231602`.
   - Skip historical logs, changelogs, archived reports, and migration artifacts.
4. **Main workspace docs cleanup:**
   - Update `docs/Yoda_RULES.md`, `docs/CHANGELOG.md`, and any other operational docs still referencing the old Tailscale MinIO endpoint to the current hostname.
   - Skip historical/archived changelog entries and backups.

## Verification plan
1. `openclaw doctor` returns no Telegram warnings.
2. `openclaw config get channels.telegram.defaultAccount` returns `yoda`.
3. `openclaw config get commands.ownerAllowFrom` returns `["telegram:8574109706"]`.
4. `grep "ainchorsangiefpl\|ainchorss-mac-mini.tail5e2567" ~/.openclaw/service-env/*.env` returns nothing (PATH fixed).
5. `grep -R "ainchorsangiefpl\|ainchorss-mac-mini.tail5e2567" ~/.openclaw/workspace* --include="*.md" -l` returns only skipped categories (backup workspace, historical logs, archived files).
6. `openclaw config validate` passes.

## Rollback
- Revert `openclaw.json` via git backup.
- Revert service env files via git backup.
- Revert workspace .md edits via git.

## Open decision
- **External MinIO HTTPS access:** Currently Tailscale serve proxies only `https://ainchorsoc2as-mac-mini-1.tailfc3ed1.ts.net/` → gateway 18789. Presigned MinIO URLs using the Tailscale hostname will not reach MinIO (9000) externally until a separate Tailscale serve rule is added for port/path. **Out of scope for this CHG** — can be addressed when LinkedIn/gog work is done, or sooner if Ken wants.
