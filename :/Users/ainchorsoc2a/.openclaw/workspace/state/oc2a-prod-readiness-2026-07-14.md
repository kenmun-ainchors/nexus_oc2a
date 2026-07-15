:
# OC2A PROD Operational Readiness — 2026-07-14 21:31 AEST

## Verdict
🟡 **OPERATIONAL WITH ACTIVE DEGRADATION** — Core platform (gateway, agents, PG, Ollama) is live. Several PROD-impacting integrations are broken or need attention before declaring "fully live."

## Green (healthy)
| Area | Status | Evidence |
|------|--------|----------|
| OpenClaw gateway | ✅ Running | `openclaw status`: pid 6424, reachable 31ms, 14 agents, 95 sessions |
| PostgreSQL | ✅ Running | `ainchors_nexus` on /tmp:5432, core tables present, `state_tickets` has 386 rows |
| Ollama Cloud | ✅ Reachable | Standby mode cleared 2026-07-09; health-state ok |
| Tailscale exposure | ✅ Active | `ainchorsoc2as-mac-mini-1.tailfc3ed1.ts.net` |
| Request budget | ✅ Healthy | 2434/59366 (4.1%), ~6 days remaining at current burn |
| Angie LinkedIn | ✅ Re-authed | `/v2/userinfo` HTTP 200, token in Keychain |
| Cron health check | ✅ Clean | `scripts/cron-health-check.sh` exit 0, no retryable failures |

## Yellow (needs attention — non-blocking but degrading)
| # | Issue | Impact | Suggested Action |
|---|-------|--------|------------------|
| 1 | **Backup stale** — latest incremental 47h old (>30h threshold) | Recovery risk | Investigate backup scheduler / NAS target |
| 2 | **Tilde path violations** in cron payloads/state files (2 files) | Cron isolation risk | Enforce absolute paths; route to Forge |
| 3 | **Cron timeout recommendations** — 27 actionable (5 increase, 22 decrease) | Efficiency/timeout risk | Manual review via scaler vA6 |
| 4 | **`linkedin-metrics.sh` missing `python-dateutil`** | LinkedIn metrics unavailable | `pip install python-dateutil` or stdlib refactor |
| 5 | **Business LinkedIn blocked** — needs Marketing Developer Platform / Business Advertising API approval | Company-page posting unavailable | Wait for LinkedIn approval, then re-auth |
| 6 | **No Telegram bot token in Keychain** | Alert channel broken | Re-add `ainchors-telegram-bot-token` and chat IDs |

## Red (actively broken — PROD impact)
| # | Issue | Impact | Evidence |
|---|-------|--------|----------|
| 1 | **PG-Notion Batch Sync cron failing** — Notion DB A schema mismatch | Tickets/CHG not syncing to Notion SSOT; 5 consecutive errors | `state/cron-health-alert.json` unacknowledged; `pg-notion-sync-errors.json` shows schema mismatch |
| 2 | **DoD validation failing** — `dod-validator.sh` exited 1: "Failed to read state_tickets from PG" | Definition-of-Done gate broken; governance alert | `state/dod-validation-alert.json` unacknowledged |

## Recommended priority order to declare "fully live"
1. **Fix Notion DB A sync** — update `pg-to-notion-sync.sh` property payload to match current Notion DB schema (Forge domain).
2. **Fix DoD validator** — investigate why it fails to read `state_tickets` despite PG being up (likely looking for `state_health` table that doesn't exist, or transient lock; route to Forge).
3. **Restore Telegram alerting** — add bot token + chat IDs to Keychain so alerts actually reach you and Angie.
4. **Resolve backup staleness** — check backup scheduler and NAS target.
5. **Patch `linkedin-metrics.sh` dependency** — `python-dateutil`.

Items 1–3 are the minimum for "fully live and trusted" operations. Items 4–5 are hygiene that can follow.
