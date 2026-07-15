# iMessage Bridge — Usage

> Outbound iMessage bridge for OC2A. One-shot. Human-approved. Audited.
> Companion to `CHG-0877.md`.

## TL;DR

```bash
# 1. Pre-flight (safe, no send)
bash scripts/imessage-bridge-test.sh

# 2. Self-test (probes AppleScript reachability, no send)
bash scripts/imessage-bridge.sh --self-test

# 3. Dry-run (renders the AppleScript, no send)
bash scripts/imessage-bridge.sh --to "+61412345678" --body "Hello from OC2A" --dry-run

# 4. Real send (REQUIRES --yes-after-prompt AND a human (Ken) explicitly says "go" in chat)
bash scripts/imessage-bridge.sh \
  --to "+61412345678" \
  --body "Running 10 min late, see you at 7" \
  --send-id "2026-07-14-1845-damo" \
  --yes-after-prompt
```

The script will **refuse** to send without `--yes-after-prompt` in MVP mode. That flag is the script's own representation of "Ken said go". Never set it without a real, traceable human approval.

## First-time setup on a fresh OC2A

1. **Grant Automation permission.** Open `Messages.app` once interactively. Then run:
   ```bash
   bash scripts/imessage-bridge.sh --self-test
   ```
   macOS will prompt: *"Terminal wants to control Messages.app"*. Click **Allow**.
   The prompt sticks — you only do this once per terminal app (Terminal, iTerm, ghostty, …).

2. **Create the allowlist.**
   ```bash
   touch state/imessage-bridge.allowlist
   # Add recipients, one per line. E.164 format preferred: +61412345678
   # iCloud emails also work for iMessage.
   echo "+61412345678" >> state/imessage-bridge.allowlist   # Damo
   echo "+61400000000" >> state/imessage-bridge.allowlist   # Ken (self-test)
   ```

3. **Create the config (optional).**
   ```bash
   cat > state/imessage-bridge.config <<'EOF'
   DAILY_CAP=20
   BODY_MAX=1000
   REQUIRE_CONFIRM=1
   EOF
   ```

4. **Run pre-flight.**
   ```bash
   bash scripts/imessage-bridge-test.sh
   ```
   Fix any ❌ lines.

5. **First send is a self-test to your own number.** Confirm receipt on your iPhone.

## Daily operation

- **Drafted by Yoda/Forge → approved by Ken via Telegram buttons → invoked by Forge.**
- Each send produces one JSONL line in `state/imessage-audit.jsonl`. The body is **never** stored, only its sha256.
- To disable instantly:
  ```bash
  touch state/imessage-bridge.disabled
  ```
  To re-enable:
  ```bash
  rm state/imessage-bridge.disabled
  ```

## Audit log format

Each line in `state/imessage-audit.jsonl` is a JSON object:
```json
{
  "ts": "2026-07-14T08:45:00Z",
  "to": "+61412345678",
  "body_sha256": "a1b2c3…",
  "body_length": 38,
  "approver": "telegram:8574109706",
  "approval_ts": "2026-07-14T08:44:55Z",
  "send_id": "2026-07-14-1845-damo",
  "apple_script": "tell application \"Messages\" …",
  "send_ts": "2026-07-14T08:45:01Z",
  "exit_code": 0,
  "error_text": ""
}
```

`body` is deliberately absent. The `body_sha256` is a tamper-evident receipt — if Ken ever disputes a send, we can prove what bytes were sent without storing them.

## What the bridge will never do

- Read existing messages or chat history.
- Send to anyone not in the allowlist (the allowlist is a hard gate; script exits 4 if missing).
- Send attachments, images, voice, reactions, or to groups.
- Send more than `DAILY_CAP` messages per AEST day.
- Send without a human approval token.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `cannot address Messages.app` | TCC Automation permission missing | Open Messages.app once; re-run `--self-test`; click Allow on the prompt. |
| `Application isn't running` | Messages.app not running | `open -ga Messages` then retry. |
| `Not authorised` from osascript | Sandbox / TCC denial | Check System Settings → Privacy & Security → Automation. |
| `daily cap reached` | `DAILY_CAP` exceeded | Wait until tomorrow AEST, or raise `DAILY_CAP` in config. |
| Send appears to bring Messages to foreground | macOS UX behaviour on Tahoe | Expected on some versions; send still succeeds. |
| Recipient receives nothing | Apple ID not signed into iMessage | Open Messages.app → Preferences → iMessage → sign in. |

## See also

- `projects/imessage-bridge/FEASIBILITY.md` — full risk analysis.
- `projects/imessage-bridge/ARCHITECTURE.md` — components, sequence, failure handling.
- `CHG-0877.md` — change record and approval trail.
