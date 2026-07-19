# CHG-0927 CREST Plan — Restore Daily Operational Notifications

## Change Record
- **CHG-0927** (created 2026-07-19) — Restore daily operational notifications: standup Telegram, weekly compliance report, and EOD blog.
- Notion Archive DB C page: `3a1890b6-ece8-81e8-9d98-c5b637acd423`

## Problem Statement
Ken reported no Telegram updates or stand-up email today. Cron audit found:
1. **AInchors Stand-up Telegram Delivery** errored: "FAILED: chunk 1 send returned non-zero" + "Composer is in degraded mode".
2. **AInchors Weekly Compliance Report** errored: "Telegram recipient must be a numeric chat ID".
3. **EOD Blog** HTML missing for 2026-07-18 and 2026-07-19 at `~/.openclaw/canvas/documents/ainchors-YYYY-MM-DD/index.html`.
4. **Morning Stand-Up timing** ran at 14:33 MYT on 2026-07-18 instead of scheduled 08:00 MYT; `standup-state.json` shows Telegram/email confirmed only up to 2026-07-16.
5. **Skill loader `scripts/skill-load.sh` fails under `zsh`** while AGENTS.md mandates using `zsh` to load skills. The script is `#!/bin/bash` and uses `${BASH_SOURCE[0]}`, causing `parameter not set` under zsh. The current workaround is to run it with `bash`, which contradicts the documented rule.

## CREST Plan

### C — Classify
- **Risk:** Medium-Low. Touches live cron definitions and notification scripts, but no core runtime changes.
- **Type:** infra / cron + script fixes.
- **Affected systems:** OC2A PROD crons, Telegram alerting pipeline, EOD blog generation.

### R — Root-cause emitters
1. **Telegram standup delivery failure**  
   Cron `dc82912a-8b6d-49ff-9f4a-a26cd4710cfc` runs `scripts/standup-telegram-send.sh`, which delegates to `scripts/telegram-alert.sh`. The chunk send returned non-zero. Possible causes:
   - `telegram-alert.sh` itself failing (token, network, recipient parsing).
   - Composer degraded mode producing placeholder/empty standup content, causing empty chunk or validation failure.
   - Chunking logic edge case for the current standup size/format.

2. **Weekly compliance report chat ID failure**  
   Cron `9b190d3e-c320-43f4-a05f-59a8709af451` fails with `Telegram recipient must be a numeric chat ID`. Recipient configuration is non-numeric or missing/invalid.

3. **EOD blog missing**  
   No active cron generates `~/.openclaw/canvas/documents/ainchors-YYYY-MM-DD/index.html`. The blog generation script or cron appears missing/unscheduled. Drive sync (`c5a3911d`) runs at 00:30 MYT and syncs existing files, but does not create the blog.

4. **Stand-up timing drift**  
   Morning Stand-Up cron ran at 14:33 MYT instead of 08:00 MYT. Likely cause: system sleep/wake backlog or cron scheduling interpretation issue. Needs verification after the Telegram fix.

5. **Skill loader shell incompatibility**  
   `scripts/skill-load.sh` is a bash script invoked as `zsh scripts/skill-load.sh changelog` per AGENTS.md. It fails because `${BASH_SOURCE[0]}` is undefined in zsh. Either make the script POSIX/portable across bash and zsh, or update AGENTS.md / SKILL.md to match the working invocation (`bash scripts/skill-load.sh ...`).

### E — Execute (Forge only)
Dispatch `agentId="infra"` to:

1. **Fix `scripts/telegram-alert.sh` / standup delivery**
   - Reproduce the error by running `standup-telegram-send.sh` manually (with idempotency bypass if needed).
   - Fix root cause (token/network/recipient/chunking).
   - Ensure `standup-state.json` is updated with `telegramSentConfirmed` on success.

2. **Fix weekly compliance report recipient**
   - Locate the compliance report script/cron and ensure the Telegram recipient is a numeric chat ID (`8574109706`).

3. **Restore EOD blog generation**
   - Locate or create the EOD blog generation script (likely `eod-blog-finalizer.sh` or similar).
   - Ensure it runs as a cron before the 00:30 MYT Drive sync, so the blog HTML exists to be synced.
   - Verify output at `~/.openclaw/canvas/documents/ainchors-YYYY-MM-DD/index.html`.

4. **Validate stand-up timing**
   - Check cron schedule interpretation and host timezone/sleep settings.
   - If the issue is backlog, document; if it's a misconfiguration, fix.

5. **Fix `scripts/skill-load.sh` shell compatibility**
   - Decide with Ken: make the script work under `zsh` (the documented invocation) OR update `AGENTS.md` / skill docs to say `bash`.
   - If making zsh-compatible: replace `${BASH_SOURCE[0]}` with a portable equivalent (e.g. `$0` when sourced, or `realpath`/`readlink` fallback).
   - If updating docs: change AGENTS.md line about zsh and ensure all skill docs reflect `bash`.
   - Validate both `zsh scripts/skill-load.sh changelog` and `bash scripts/skill-load.sh changelog` succeed.

### S — Stabilize
- After patches, manually trigger:
  - Standup Telegram delivery → confirm message received and `standup-state.json` updated.
  - Weekly compliance report → confirm no chat ID error.
  - EOD blog generation → confirm HTML file created.
- Monitor the next 24h for normal cron cycles (08:00 standup, 08:20 Telegram delivery, compliance report schedule, EOD blog before midnight).
- Keep the existing auto-heal and Drive sync crons untouched.

### T — Transfer / Close
- Update `docs/RUNBOOK.md` or equivalent with the notification pipeline map and recipient configuration.
- Close CHG-0927 in Notion Archive DB C and append evidence (screenshots/logs of successful deliveries, file timestamps).
- Journal entry per Journal Discipline (TKT-0296).

## Verification Criteria
1. `scripts/standup-telegram-send.sh` runs successfully and Ken receives the standup in Telegram.
2. `state/standup-state.json` shows `telegramSentConfirmed == today` after a successful run.
3. Weekly compliance report cron runs without the chat ID error.
4. EOD blog HTML exists for the current date at `~/.openclaw/canvas/documents/ainchors-YYYY-MM-DD/index.html`.
5. Morning stand-up runs at the scheduled 08:00 MYT (within 15 min tolerance).
6. `zsh scripts/skill-load.sh changelog` succeeds (or AGENTS.md is updated to authorize `bash`).

## Rollback
- Revert script changes.
- Restore previous cron definitions if any were modified.
- Re-enable manual notification fallback if needed.

## Scope Boundary
CHG-0927 does **not** cover the R01 gateway runtime fix. That remains under **CHG-0926** and needs a separate Forge dispatch for the remaining 68 violations.

## Decision Needed
Ken: **Approve CREST Plan and Forge dispatch for CHG-0927?**  
If yes, I will spawn Forge with this plan and the three specific targets above.
