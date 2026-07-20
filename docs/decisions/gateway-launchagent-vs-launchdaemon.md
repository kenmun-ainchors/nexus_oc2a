# CHG-0941 — Decision Memo: LaunchAgent vs LaunchDaemon

**Date:** 2026-07-20
**Author:** Yoda (delegated to Forge) / Yoda Master Verify
**Status:** RECOMMENDATION — STAY LAUNCHAGENT + WATCHDOG
**Decision required from:** Ken Mun

---

## 1. Context

On 2026-07-19 the OpenClaw gateway (`ai.openclaw.gateway`) received a clean
SIGTERM at ~02:12 local and was not resurrected for **9h 49m** — until the
Aqua session was reactivated. Root cause: a user LaunchAgent (`gui/501/`)
only auto-respawns while the user is logged in. When the box went to sleep
with no active session, launchd sat on the dead process and nobody noticed
because stderr was routed to `/dev/null`.

This memo evaluates whether to **migrate the gateway to a system
LaunchDaemon** (always-on, even at loginwindow) as a structural fix, and
records the recommendation that this CHG is being delivered against.

---

## 2. Why LaunchAgent Was Originally Chosen

The OpenClaw gateway is more than an HTTP server. It brokers several
side-channels that depend on the **user's Aqua session**:

| Subsystem        | Why it needs Aqua                                       |
|------------------|----------------------------------------------------------|
| Browser control  | Launches Chrome on the user's display, talks to it over the per-user debug port (TKT-1009). |
| Canvas host      | Renders to per-display windows in the user's login session. |
| Phone-control    | Pairs via Continuity / Bluetooth, which is per-user.     |
| Tailscale        | Runs as a user-space daemon under the user's launchd domain. |
| Keychain / SSH   | Reads from the user's login keychain and `~/.ssh/`.      |
| Notifications    | macOS `osascript` notifications need a user session.     |

A LaunchDaemon runs in the system context (uid 0) and **cannot** reach any
of these. Moving the gateway to `/Library/LaunchDaemons/` would break the
browser, canvas, phone-control, and most keychain integrations on first
deploy — silently.

---

## 3. Trade-offs

### 3.1 Keep LaunchAgent + add watchdog (CHG-0941 path)

| Pros                                                          | Cons                                                    |
|----------------------------------------------------------------|----------------------------------------------------------|
| Preserves all Aqua-only side-channels                          | Still dies if the user is logged out for the entire run  |
| No elevation / no system files                                 | Window of failure: 2 min probe interval + 2 fails = up to 4 min dark |
| Trivial to roll back                                           | Stale state of detached sidecars (browser, canvas)        |
| 5-min SLO is achievable with a 2-min cron + 2-fail threshold   |                                                         |

### 3.2 Migrate to LaunchDaemon (rejected for this CHG)

| Pros                                                          | Cons                                                    |
|----------------------------------------------------------------|----------------------------------------------------------|
| 24/7 availability while booted                                 | **Breaks browser, canvas, phone-control, keychain integrations** |
| No user-session dependency                                      | Requires root, sudo placement, code signing review       |
| launchd enforces KeepAlive more strictly                        | Migration of NODE_OPTIONS and env wrapper is non-trivial |
|                                                                | Telemetry around who-is-logged-in is now wrong           |
|                                                                | Out of scope for CHG-0941 (would be CHG-09XX follow-up)  |

---

## 4. Recommendation

**Stay on LaunchAgent** and ship the watchdog + stderr capture +
log rotation + cron (this CHG). The signal-to-noise is strong:

- The failure mode is a **5-minute cron window**, not 9h49m. After this
  CHG the maximum dark time is bounded by the cron interval plus the
  two-failure threshold (≤ 4 min) and produces a visible `gateway.err.log`.
- The structural change (LaunchDaemon) is **destructive** to multiple
  Aqua-bound subsystems. A future CHG can split the gateway into two
  processes: a thin always-on LaunchDaemon (REST + cron + webchat) and an
  Aqua-bound LaunchAgent (browser/canvas/phone). That is **out of scope
  here** but the natural next step if Yoda is asked to chase 100% uptime.

**Concrete decision asked of Ken:**

> Approve the LaunchAgent + watchdog path for CHG-0941 **AND** flag whether
> a follow-up CHG for the split-process / LaunchDaemon migration is
> desired. Default if no answer: stay LaunchAgent indefinitely.

---

## 5. Rollback

Rollback does **not** touch the daemon side. The path is symmetric:

```sh
# Restore plist
cp ~/.openclaw/backups/ai.openclaw.gateway.plist.<ts> \
   ~/Library/LaunchAgents/ai.openclaw.gateway.plist
launchctl unload ~/Library/LaunchAgents/ai.openclaw.gateway.plist
launchctl load   ~/Library/LaunchAgents/ai.openclaw.gateway.plist

# Remove cron
crontab -l | grep -v gateway-watchdog.sh | crontab -

# Stop watchdog
rm -f ~/.openclaw/workspace/scripts/gateway-watchdog.sh
```

Total rollback time: <2 minutes, no sudo required.

---

## 6. References

- CHG-0941 — this change
- `config/newsyslog-openclaw.conf` — log rotation policy
- `scripts/gateway-watchdog.sh` — watchdog source
- `scripts/gateway-logrotate.sh` — user-space rotation
- `~/Library/LaunchAgents/ai.openclaw.gateway.plist` — updated plist
- TKT-1009 — browser sidecar lazy-spawn rationale
