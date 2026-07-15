# iMessage Bridge — Architecture & Approval Gate

**Date:** 2026-07-14
**Status:** Proposed (pending Ken approval)
**Companion:** `FEASIBILITY.md` and `CHG-0877.md`

## 1. Components

| Component | Path | Purpose |
|---|---|---|
| **Bridge script** | `scripts/imessage-bridge.sh` | One-shot CLI. Validates → audits → sends via `osascript`. |
| **Approval gate** | Telegram inline buttons (preferred) or console prompt | Ken must press "Send" before the script ever touches `osascript`. |
| **Audit table** | PG `state.imessage_sends` (preferred) or `state/imessage-audit.jsonl` (fallback) | Every send logged with hash, not plaintext. |
| **Allowlist** | `state/imessage-bridge.allowlist` (plain text, one address per line) | Hard gate. Empty allowlist = no sends possible. |
| **Kill switch** | `state/imessage-bridge.disabled` (file presence = off) | Ken can disable instantly. |
| **Config** | `state/imessage-bridge.config` (env-style: `DAILY_CAP=20`, `BODY_MAX=1000`) | Tunables. |

All paths under `state/` (not `scripts/`) so the configuration is data, not code, and the kill switch is one-touch.

## 2. Approval gate design (two paths)

### Path A — Telegram inline buttons (default, recommended)
1. Forge (or Yoda) renders a draft message:
   > *To:* Damo `+61xxx` *(allowlisted ✅)*
   > *Body:* "Running 10 min late, see you at 7"
   > *Length:* 38 chars · *Daily count after send:* 4/20
   > [✅ Send]  [✏️ Edit]  [❌ Cancel]
2. Ken taps ✅. Telegram callback hits the bridge script with `--approved <send_id>`.
3. The script validates the approval token, then sends. Returns success/fail inline.
4. Audit row written with `approver=telegram:<user_id>`, `approval_ts=…`.

### Path B — Console / exec prompt
- Useful when Telegram isn't available.
- Bridge script supports `--require-confirm` flag; if set, it prints the draft and waits for `y\n` on stdin. The OpenClaw exec channel doesn't support interactive stdin, so in practice this means Forge pre-runs the script and Ken runs it manually from a Terminal.

**For the MVP prototype, both paths ship. The Telegram path is the production one.**

## 3. Send flow (sequence)

```
Yoda/Forge    Bridge Script       osascript     Messages.app    Apple Cloud    Recipient
   │              │                  │               │              │              │
   │ --drafts-->  │                  │               │              │              │
   │ (waits for Ken approval)        │               │              │              │
   │ --send-->    │                  │               │              │              │
   │              │ check disabled   │               │              │              │
   │              │ check allowlist  │               │              │              │
   │              │ check daily cap  │               │              │              │
   │              │ check body length│               │              │              │
   │              │ write audit row  │               │              │              │
   │              │ ─── osascript ──▶│               │              │              │
   │              │                  │ ── send ────▶ │              │              │
   │              │                  │               │ ── iMessage ▶│              │
   │              │                  │               │              │ ── iPhone ──▶│
   │              │ ◀── result ──────│ ◀── ok ───────│              │              │
   │              │ update audit row │               │              │              │
   │ <-- ok ------│                  │               │              │              │
```

## 4. Failure handling

| Failure | Detection | Action |
|---|---|---|
| TCC denied | `osascript` returns `Not authorised` | Surface to Ken, recommend opening System Settings → Privacy & Security → Automation and granting Terminal. Script exits 77 (EX_NOPERM). |
| No Messages session | `osascript` returns `Application isn't running` | Try `open -ga Messages` once and retry. If still fails, exit 69 (EX_UNAVAILABLE). |
| AppleScript error | Any non-zero return | Audit row marked `error`, full error captured (no body). Ken notified via Telegram. |
| Daily cap hit | Counted in audit before send | Exit 78 (EX_CONFIG), message: "Daily cap reached. Increase `DAILY_CAP` in `state/imessage-bridge.config` or wait until tomorrow AEST." |
| Recipient not in allowlist | Pre-check | Exit 78. Ken can edit allowlist; do not auto-add. |
| Body too long | Pre-check | Exit 78. Suggest a shorter draft. |
| Kill switch on | `state/imessage-bridge.disabled` exists | Exit 78. Tell Ken how to re-enable (`rm state/imessage-bridge.disabled`). |

## 5. Audit schema (PG preferred)

```sql
CREATE TABLE IF NOT EXISTS state.imessage_sends (
  id            BIGSERIAL PRIMARY KEY,
  ts            TIMESTAMPTZ NOT NULL DEFAULT now(),
  to_address    TEXT        NOT NULL,
  body_sha256   CHAR(64)    NOT NULL,
  body_length   INT         NOT NULL,
  approver      TEXT,             -- 'telegram:8574109706' or 'console:ken'
  approval_ts   TIMESTAMPTZ,
  send_ts       TIMESTAMPTZ,
  exit_code     INT,
  error_text    TEXT,
  apple_script  TEXT         -- exact AppleScript run, for forensics
);
-- body is never stored. sha256 only. receipt-of-proof.
```

Fallback if PG is unavailable: append-only JSONL in `state/imessage-audit.jsonl`, one line per send, same fields. The script auto-detects.

## 6. What the prototype delivers (this CHG)

- `scripts/imessage-bridge.sh` — the bridge (one-shot, idempotent per `--send-id`).
- `scripts/imessage-bridge-test.sh` — pre-flight checks (osascript version, Messages.app reachable, allowlist writable, kill switch status).
- `state/imessage-bridge.allowlist` — initially contains only Ken's own number (for self-test) and Damo's number (once Q2 is answered).
- `state/imessage-bridge.config` — defaults: `DAILY_CAP=20`, `BODY_MAX=1000`, `REQUIRE_CONFIRM=1`.
- README in `projects/imessage-bridge/README.md` with usage.
- One test send to Ken's own number, performed only after Ken replies "go" to the approval prompt.

## 7. What is explicitly **not** in this CHG

- Inbox / message-history reads.
- Attachments, images, voice, Tapbacks, reactions.
- Group chats.
- Multi-recipient / CC.
- iMessage → Telegram or other bridges (no chat sync in either direction).
- Reading `chat.db`.
- Any background daemon or listener. Sends are strictly synchronous, one per invocation.
