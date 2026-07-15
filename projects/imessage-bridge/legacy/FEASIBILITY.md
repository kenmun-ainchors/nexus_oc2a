# iMessage Bridge Feasibility Report — OC2A

**Date:** 2026-07-14 18:45 AEST
**Author:** Forge (infra) subagent
**Related:** Yoda dispatch 18:44 AEST, CHG-XXXX (iMessage Bridge MVP)
**Target host:** OC2A (Mac Mini M4 Pro), macOS 26.5.2, arm64, single-user session

## 1. Verdict

**Feasible, with caveats.** The minimal viable outbound iMessage bridge can be built on OC2A using `osascript` → `Messages.app` (AppleScript bridge), with a human approval gate per message. This is the lowest-risk path: no new Apple ID, no headless daemon, no third-party services. It is, however, **not zero-risk** — see §4. Recommended: ship the MVP behind a CHG, with Ken approval per message, and an immediate-kill switch.

## 2. The path that works

Apple's macOS exposes Messages.app automation through three layers (newest to oldest):

| Layer | Notes | Fit for OC2A MVP |
|---|---|---|
| **`osascript` (AppleScript)** | Built into macOS. `tell application "Messages" to send …`. Works on Tahoe. Requires **Automation → Terminal/Shell permission** for the calling process. | **Best fit.** No new deps, no daemon. |
| Shortcuts CLI (`shortcuts run`) | Requires a Shortcut. More friction. Possible later. | Skip for MVP. |
| Private CoreSimulator / `imsg` libraries | Community projects (e.g. `imsg`). Need install + entitlement gymnastics. | Skip; out of CHG scope and unsupported. |

A working outbound send looks like:

```applescript
tell application "Messages"
  set targetService to 1st service whose service type = iMessage
  set targetBuddy to buddy "+61412345678" of targetService
  send "Hello from OC2A" to targetBuddy
end tell
```

`osascript` calls this. The first invocation triggers a **TCC automation prompt** the user (Ken, in the OC2A GUI session) must accept — once accepted for the calling app, it sticks.

## 3. Why OC2A is uniquely suitable

- Already a logged-in macOS user session with Messages.app installed (`/System/Applications/Messages.app`).
- Ken is the Apple ID holder and is the only human at the keyboard. No "robot sends to humans without consent" ambiguity.
- `osascript` is present at `/usr/bin/osascript`. No new system binaries.
- Yoda already runs in this workspace; the same exec channel can reach `osascript`.

## 4. Risks (ranked)

### R1 — Apple ID / ToS / account lockout ⚠️ MEDIUM
- Apple does not formally permit scripting Messages.app for automation. The AppleScript dictionary has shipped forever, but it's an **undocumented, unsupported surface**. Apple can change or break it in any macOS update (it already has, several times since Sonoma).
- If Apple IDs are ever rate-limited, throttled, or flagged for "suspicious automation", account or device lockout is possible. This is the **biggest non-technical risk**.
- **Mitigation:** Keep volume low. Each send is human-approved. Add per-day send cap. Document the ToS gray zone in CHG.

### R2 — Automation TCC permission ⚠️ LOW (one-time)
- The first `osascript` call to Messages.app will trigger macOS's "Messages wants to control Messages" / "Terminal wants to control Messages" prompt. Ken must click Allow in the GUI.
- If denied, all sends fail silently with `execution error: Not authorised` or `Application isn't running`.
- **Mitigation:** Prompt is expected; document the one-time flow in the prototype README. Detect denial and surface a clear error.

### R3 — UI/UX side effects on the live Mac session ⚠️ MEDIUM
- AppleScript to Messages.app **may bring Messages to the foreground or open a chat window**, depending on macOS version. This is annoying if Ken is actively using the Mac.
- On Tahoe, sending via `buddy` is generally less intrusive than via `chat`, but I have not been able to verify the foreground behavior in this sandbox (TCC locked me out of the test that would force a real send).
- **Mitigation:** Prototype will use the least-invasive AppleScript form, and the run will be from a non-interactive shell. Test in a controlled window. Document the behavior we observe.

### R4 — Spoofing / number reuse ⚠️ MEDIUM
- A bad actor with shell access on OC2A can send an iMessage that **appears to come from Ken** to any iMessage address. This is the same risk as giving any local app permission to send mail "from Ken".
- **Mitigation:** Approval gate per message + audit log of every send (to, body hash, timestamp, approver). Send volume cap (e.g. 20/day). Lock the prototype script to a small allowlist of recipients.

### R5 — Privacy / content exposure ⚠️ MEDIUM
- Every message is plain text, not end-to-end encrypted against OC2A itself — the message body is in `~/Library/Messages/chat.db` in cleartext. Anyone with disk access (including future AInchors staff) can read history.
- **Mitigation:** Document that **all iMessage content is treated as Tier 1 (PII, local-only)** per AInchors data sovereignty rules. Do not sync Messages.db to any cloud. Never paste message bodies into external logs.

### R6 — Sandbox restrictions ⚠️ LOW
- Yoda/Forge agents run inside the OpenClaw gateway on OC2A. TCC currently blocks reads of `TCC.db` and `~/Library/Messages/`, which is correct. The agent will *not* be able to read prior message history — only **send new messages via osascript**. That is the right scope.
- **Mitigation:** Explicitly out-of-scope: inbox reading, attachment sending, group chats, reactions. MVP is text-only, outbound only, allowlisted.

### R7 — macOS update drift ⚠️ LOW (chronic)
- Every macOS major release has historically tweaked the AppleScript dictionary for Messages. We must re-verify after each .0 release.
- **Mitigation:** Quarterly smoke test (`scripts/imessage-bridge.sh --self-test --dry-run`) on a known recipient. Track under TKT.

## 5. Minimal viable design

```
┌─────────────────┐     approval-required      ┌──────────────┐
│ Yoda / Forge    │ ──── (Telegram/console) ──▶ │ Ken approves │
│ proposes send   │                              │ per message  │
└────────┬────────┘                              └──────┬───────┘
         │ invokes                                        │ ACK
         ▼                                                │
┌─────────────────────────────────────┐                  │
│ scripts/imessage-bridge.sh          │ ◀────────────────┘
│   - validates recipient allowlist   │
│   - validates length / sanitize     │
│   - writes audit line (PG/JSON)     │
│   - calls osascript                 │
│   - confirms return code            │
└────────┬────────────────────────────┘
         │ exec
         ▼
    AppleScript → Messages.app → Apple iMessage cloud → recipient iPhone
```

**Outbound only. One message per invocation. No inbox read. No attachments. No groups.**

## 6. Recommendation

**Proceed with MVP under CHG, with the following non-negotiables baked into the prototype:**

1. **Per-message human approval gate.** No background/queue/cron sends.
2. **Recipient allowlist** (starts: Damo, possibly Ken's own number for self-test). Deny-by-default for any other number.
3. **Daily send cap** (default 20).
4. **Audit log** (PG `state.imessage_sends` or append-only JSONL) with to / length / sha256(body) / approver / ts / exit.
5. **Kill switch**: a single file (`state/imessage-bridge.disabled` or env var) that the script checks first. Ken can drop the file to instantly stop all sends without code changes.
6. **One-shot, no daemon.** The script is invoked per send. No persistent background process.
7. **No reads** of `chat.db` or any prior messages. Body and recipient are passed as args, never auto-suggested from history.
8. **Body length cap** (default 1000 chars) and basic profanity/PII filter (warn, don't block — Ken has final say).

## 7. Open questions for Ken before prototype build

| # | Question | Why |
|---|---|---|
| Q1 | Apple ID on OC2A — is it Ken's personal iMessage number, or a dedicated account for the agent? | Personal account = personal risk; dedicated = lower blast radius. |
| Q2 | "Damo's number" — do you have it in E.164 form (`+614…`) for the allowlist? | AppleScript buddy lookup wants E.164 or iCloud email. |
| Q3 | Self-test recipient — is Ken's own iPhone OK for the first test send? | Safest first run: send to yourself. |
| Q4 | Approval channel — Telegram interactive buttons, or console prompt? | Telegram is the existing channel; Yoda already chunks to 3,800 chars. Console prompt works too. |
| Q5 | Daily cap — 20 OK, or lower (e.g. 5) for the first week? | Lower is safer while we learn the Apple ID's tolerance. |

**If you answer Q1–Q5 (or accept defaults: Ken's personal account, Damo only, self-test to Ken, Telegram buttons, 20/day), I'll proceed to build the prototype under a CHG.**
