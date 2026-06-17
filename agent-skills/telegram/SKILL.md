---
name: telegram
description: Telegram message chunking protocol, recipient config, and alert routing for all AInchors agents.
---

## MESSAGE CHUNKING PROTOCOL

**Telecom max:** 4,096 chars. **Safe chunk:** 3,800 chars.

### Pre-flight
Before ANY send, count characters. ≤ 3,800 → send as-is. > 3,800 → chunk.

### How to Chunk
1. **Split at paragraph boundaries** (period + newline). Never mid-sentence.
2. **Number every chunk** — `[1/N]`, `[2/N]` … `[N/N]`
3. **Continuity markers** — end N with `(continued →)`, start N+1 with `(← continued)`
4. **Header repetition** — include title/context in `[brackets]` at start of each chunk
5. **Send SEQUENTIALLY** — never parallel (Telegram may reorder)

### Common Violations (PROHIBITED)
- Sending > 5,000 chars as one chunk (silent truncation)
- Out-of-order chunks
- Omitting [1/N] numbers
- Assuming `sessions_send` auto-chunks (it does NOT)

---

## RECIPIENT CONFIG

| Person | Chat ID | Bot |
|--------|---------|-----|
| Ken Mun | `8574109706` | @AInchorsOC1Bot |
| Angie Foong | `8141152780` | @AInchorsAriaBot |

**Emergency keyword:** `"YODA THIS IS KEN"` — bypasses routing, immediate attention.

---

## ALERT ROUTING

All alerts target **Ken only** unless Angie is explicitly included.

| Trigger | Action |
|---------|--------|
| Budget exceeded | Telegram immediately |
| Auto-heal NEEDS_KEN (urgent) | Notion DB B + Telegram |
| Cron failures (single) | Alert Ken immediately — never wait for 3 |
| Agent health degraded | Alert Ken |
| Aria CREST violation | Alert Ken |
| DoD validation failure | Alert Ken |
| OWL compliance failure | Alert Ken |

---

## References
- RULES.md §CHG-0397 (chunking rule)
- HEARTBEAT.md §Checks (alert triggers)
- SOUL.md Non-negotiable #10