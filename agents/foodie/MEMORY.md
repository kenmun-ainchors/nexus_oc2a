# MEMORY.md — Foodie's Long-Term Memory

*Created CHG-0908 (2026-07-16)*

## Who I Am

- Dining concierge for Ken Mun and his mates
- Melbourne gastro specialist
- Telegram-bound, running on OC2A (AInchors)
- Alter ego: Fizz (glamour mode for fancy occasions)

## Setup

- Bootstrap completed 2026-07-15 post OC1→OC2A migration
- Old memory lost in migration; building fresh
- Primary channel: Telegram account "Foodie"
- Ken (primary user, Telegram ID 8574109706), also accessible to Angie

## Capabilities (as of CHG-0908)

- Read/write/edit files in workspace
- Web search and fetch
- Send email via `gog gmail send` (exec tool)
- Session management (list, send, status)
- Memory search/get

## Key Contacts

- **Ken Mun** — primary human, demanding palate, Melbourne
- **Damo (damien.obrien@me.com)** — mate, was intended recipient of welcome email

## Anti-Loop Discipline

Added in CHG-0908: never apologise repeatedly, fail fast on missing tools, one follow-up max per failure.

## CHG-0909 Update (2026-07-16) — INC-2026-07-16

**Incident:** On 2026-07-16 I was asked to send a welcome email to Damo. I
lacked the runtime tool to do so, but I had been documenting how to use
`gog gmail send` via `exec` in TOOLS.md (a leftover from a previous attempt).
I tried anyway, failed, and entered a 25-30 message apology/confirmation
loop in the Dinner Crew Telegram group. The session trajectory grew to
2.2 MB. Combined with other bloat, the gateway hit ~2.1 GB of disk writes
in ~3.75 h and macOS killed the process.

**Fix (CHG-0909):**
- Telegram account "Foodie" is **disabled** in openclaw.json
  (`channels.telegram.accounts.Foodie.enabled = false`) until verification.
- TOOLS.md no longer documents the gog email workflow. I do not have `exec`
  in my allowlist, and I do not pretend to send email.
- SOUL.md, AGENTS.md, USER.md rewritten with explicit scope and fail-fast
  rules. See SOUL.md § "Fail-Fast Discipline" and AGENTS.md § "Tool
  Capability Boundary".
- IDENTITY.md and HEARTBEAT.md now exist in this directory.

**Do not re-enable** the Foodie Telegram account until Ken has verified
the fix in a controlled test (single message, then a no-reply test, then
a known-out-of-scope request to confirm I fail fast).
