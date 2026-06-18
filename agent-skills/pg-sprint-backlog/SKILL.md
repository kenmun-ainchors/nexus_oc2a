---
name: pg-sprint-backlog
description: PG Sprint-Backlog Interface — canonical ticket and sprint operations via db-ticket.sh and db-sprint.sh. Covers the full lifecycle: brief, notes, context, folding, dependency, Notion.
---

# PG Sprint-Backlog Skill

## When to Load

Load this skill **before any ticket or sprint operation**. Mandatory for all agents. This is the canonical interface — never rediscover the PG ticket/sprint interface per-session.

## Quick Reference

| Operation | Subcommand | Example |
|-----------|-----------|---------|
| Read a ticket | `db-ticket.sh read <ID>` | `bash scripts/db-ticket.sh read TKT-0369` |
| Create a ticket (interactive) | `db-ticket.sh create` | `bash scripts/db-ticket.sh create` (interactive only — needs TTY) |
| **Create a ticket (non-interactive — preferred for agents/CI)** | **`db-ticket.sh create-from-json <ID> '<json>'`** | **`bash scripts/db-ticket.sh create-from-json TKT-0500 '{...}'`** |
| Update a ticket | `db-ticket.sh update <ID> '<json>'` | `bash scripts/db-ticket.sh update TKT-0400 '{"status":"in-progress"}'` |
| Groom a ticket | `db-ticket.sh groom <ID>` | `bash scripts/db-ticket.sh groom TKT-0400` (interactive) |
| Fold a ticket | `db-ticket.sh fold <ID> --into <PARENT>` | `bash scripts/db-ticket.sh fold TKT-0381 --into TKT-0369` |
| List tickets | `db-ticket.sh list [filters]` | `bash scripts/db-ticket.sh list --open --sprint "Sprint 7"` |
| List blocked | `db-ticket.sh list --blocked` | `bash scripts/db-ticket.sh list --blocked` |
| Find blocked-by | `db-ticket.sh list --blocked-by <ID>` | `bash scripts/db-ticket.sh list --blocked-by TKT-0323` |
| Sync to Notion | `db-ticket.sh sync <ID>` | `bash scripts/db-ticket.sh sync TKT-0369` |
| Validate tickets | `db-ticket.sh validate` | `bash scripts/db-ticket.sh validate` |
| Current sprint | `db-sprint.sh current` | `bash scripts/db-sprint.sh current` |
| Commit to sprint | `db-sprint.sh commit <ID> <seq> <effort> <agent>` | `bash scripts/db-sprint.sh commit TKT-0400 3 M forge` |
| Sprint status | `db-sprint.sh status` | `bash scripts/db-sprint.sh status --sprint "Sprint 7"` |
| Sprint plan | `db-sprint.sh plan` | `bash scripts/db-sprint.sh plan --sprint "Sprint 7"` |
| Create sprint | `db-sprint.sh create "<name>" "<dates>"` | `bash scripts/db-sprint.sh create "Sprint 8" "2026-06-15 to 2026-06-21"` |
| Defer ticket | `db-sprint.sh defer <ID> --to <Sprint> --reason "..."` | `bash scripts/db-sprint.sh defer TKT-0400 --to "Sprint 8" --reason "capacity"` |
| Migrate sprint | `db-sprint.sh migrate [--dry-run]` | `bash scripts/db-sprint.sh migrate --sprint "Sprint 7"` |

**Absolute path:** `scripts/db-ticket.sh` and `scripts/db-sprint.sh` at `/Users/ainchorsangiefpl/.openclaw/workspace/scripts/`.

---

## ⚠️ SHELL COMPATIBILITY — L-090 FIX (2026-06-13)

`db-ticket.sh` uses **bash-only** constructs: `read -p`, `[[ ... ]]`, `local`, `$'...'` quoting, `declare -A`. When invoked under **zsh**, the script's interactive prompts fail with:

```
cmd_create:read:13: -p: no coprocess
```

zsh's `read -p` requires a coprocess (zpty) that is not set up by default. This bug tripped Yoda twice in one day (L-090), causing a S1-grade silence-failure pattern: the agent emitted architectural commentary and bypassed ticket creation, requiring a manual nudge.

**Two structural fixes are in place (CHG-0524):**

1. **Auto-reexec to bash** — the script detects `$ZSH_VERSION` at startup and re-execs to `/bin/bash` with the same arguments. This makes the script work under any caller shell. Override with `DB_TICKET_FORCE_BASH=0` (escape hatch for testing).

2. **`create-from-json` subcommand** — the proper fix. Accepts a complete JSON payload on the command line. Idempotent, scriptable, works under bash and zsh. **Agents and CI MUST prefer `create-from-json` over interactive `create`.**

**When to use which:**

| Path | Use this |
|------|----------|
| Human at TTY, wants prompts | `bash scripts/db-ticket.sh create` (interactive) |
| Agent writing a ticket, CI, no TTY | **`bash scripts/db-ticket.sh create-from-json TKT-NNNN '<json>'`** (NON-NEGOTIABLE) |
| Cron / auto-heal | **`bash scripts/db-ticket.sh create-from-json ...`** (NEVER interactive) |

**Do NOT invoke with `zsh scripts/db-ticket.sh`** — even though the auto-reexec handles it, the `changelog` skill says "use zsh" for that script (because of `${(P)var}`). The two skills have different shell requirements — do not generalize.

---

## db-ticket.sh — Canonical Ticket Interface

**Script:** `/Users/ainchorsangiefpl/.openclaw/workspace/scripts/db-ticket.sh`
**PG Table:** `state_tickets`
**Fallback File:** `state/tickets.json` (read-only cache, maintained for backward compat)

### Subcommand Catalog

#### `read <TKT-ID>`
Returns full ticket as JSON with metadata expanded. Includes: id, title, status, priority, type, created_at, updated_at, metadata (brief, grooming_history, depends_on, blocks, folded_from, folded_scope, notion_sync, sprint_target, etc.).

```bash
bash scripts/db-ticket.sh read TKT-0369
```

**No flags accepted.** Just the TKT-ID.

#### `create`
**Interactive only — NO flags.** Launches guided creation flow prompting for:
- TKT-ID (validated: `TKT-NNNN[X][-X]` format, must not exist)
- Title (required)
- Brief (1-2 sentence scope summary — what this ticket delivers)
- Priority (critical/high/medium/low, default: medium)
- Type (task/bug/build/epic/story/chg, default: task)
- Effort (XS/S/M/L/XL, default: M)
- Assigned agent
- Number of acceptance criteria
- Dependencies (comma-separated TKT-IDs)
- Sprint target

Review screen shown before confirming. After confirmation:
1. Writes to PG `state_tickets` with SAFE_MODE (collision detection)
2. Updates `state/tickets.json` fallback
3. Triggers Notion sync in background

```bash
bash scripts/db-ticket.sh create
```

**If you pass flags, it will reject them with an error.** This is intentional — ticket.sh flag-silence was Failure #5.

#### `create-from-json <TKT-ID> '<json-payload>'` — L-090 NON-INTERACTIVE (PREFERRED FOR AGENTS)
**The right way to create tickets programmatically.** Accepts a complete JSON payload on the command line. Idempotent, scriptable, works under bash AND zsh (auto-reexec handles it). No TTY required. **Agents, CI, and crons MUST use this — not `create`.**

**Required JSON fields:**
- `title` (string)
- `status` (open|backlog|pending|monitoring|fold|done|...)
- `priority` (critical|high|medium|low) — normalizes p0/p1/p2/p3
- `type` (task|bug|build|epic|story|chg|feature|infra)
- `metadata` (object) — see Update schema below

**Optional JSON fields:**
- `id` (TKT-NNNN) — must match CLI arg if present, auto-injected if absent
- `created_at` (ISO 8601) — auto-set if absent
- `notionpageid`, `url` — read-only, ignored

**Example (full payload):**

```bash
bash scripts/db-ticket.sh create-from-json TKT-0503 '{
  "title": "Sandbox install OpenClaw v2026.6.6 on port 28789",
  "status": "open",
  "priority": "high",
  "type": "task",
  "metadata": {
    "brief": "Per CHG-0521: DEFER + SANDBOX on TRIGGER-04 v2026.6.6. Clone v2026.6.6, install on port 28789, smoke-test core flows incl. Telegram delivery, 2h observation, bake validated build into OC2 fresh install.",
    "effort": "M",
    "agent": "Yoda",
    "ac_count": 4,
    "sprint": "Sprint8",
    "depends_on": [],
    "blocks": ["TKT-0501"],
    "grooming_history": [{
      "date": "2026-06-13T08:00:00+10:00",
      "decisions": "Ken approved DEFER + SANDBOX 2026-06-13 07:53 AEST",
      "ac_count": 4,
      "ken_approved": true
    }],
    "folded_from": [],
    "folded_scope": [],
    "notion_sync": { "last_synced": null, "status": "pending" }
  }
}'
```

**Returns:** the created ticket JSON on success (same shape as `read`). Exit 0 on success, 1 on validation failure, 3 on collision.

**When `create-from-json` is the wrong choice:** never. If you have all the data up-front (which any agent should), use it. The interactive `create` is kept for humans at a TTY.

**Verification:** first run on 2026-06-13 08:20 AEST — TKT-9999 created via zsh invocation, auto-reexec to bash succeeded, read-back confirmed. TKT-9998 created via bash interactive (regression — still works). Test tickets cleaned up. CHG-0524.

#### `update <TKT-ID> '<json-payload>'`
Validates and writes JSON to PG. The payload is validated against a schema:

- **Forbidden fields:** `id`, `created_at` (system-managed)
- **Metadata type validation:** brief (string), grooming_history (array), depends_on (array), blocks (array), folded_from (array), folded_scope (array), notion_sync (object), sprint (string), effort (string), agent (string)

Metadata writes use direct PG UPDATE to avoid shell escaping issues. Non-metadata fields use `db-write.sh`. Updates `tickets.json` fallback automatically.

```bash
bash scripts/db-ticket.sh update TKT-0369 '{"status":"in-progress","metadata":{"effort":"L"}}'
```

**No flags accepted after payload.** Rejects `--force`, `--dry-run`, etc.

##### TKT-0538 Fix — top-level column updates now land in PG

Before TKT-0538, `db-ticket.sh update TKT-NNNN '{"status":"..."}'` could silently degrade to file fallback because `db-write.sh` used `INSERT ... ON CONFLICT` and PG check constraints on the attempted insert row rejected the operation.

After TKT-0538, `db-write.sh` detects existing rows and emits a plain `UPDATE`, so `status`, `priority`, `sprint`, `sprint_seq`, `epic`, and other top-level column changes are written to PG reliably.

Unknown keys are still merged into `metadata` JSONB as before.

Always verify with `bash scripts/db-ticket.sh read <ID>` after an update.

#### `groom <TKT-ID>`
Appends a grooming entry to `metadata.grooming_history[]`. Interactive prompts for:
- Grooming decisions (what was decided, changed, or clarified)
- AC count (current or updated)
- Ken approved? [y/N]

Grooming entry format: `{date, decisions, ac_count, ken_approved}`.

```bash
bash scripts/db-ticket.sh groom TKT-0369
```

**No flags accepted.** Just the TKT-ID.

#### `fold <TKT-ID> --into <PARENT-ID>`
**CHG-0456 5-Gate Fold SOP.** Only `--into` flag is accepted; all other flags rejected.

| Gate | Name | Action |
|------|------|--------|
| 1 | Extract | Read child metadata (title, brief, status, effort, AC count) |
| 2 | Migrate | Append structured scope entry to parent's `metadata.folded_scope[]` |
| 3 | Update | Write `folded_into` + `folded_at` to child metadata |
| 4 | Close | Set child status to `folded` in PG |
| 5 | Sync | Trigger Notion sync for both tickets |

Scope is preserved in parent's `folded_scope[]` as: `{tkt_id, title, brief, ac_count, effort, folded_at}`.

```bash
bash scripts/db-ticket.sh fold TKT-0381 --into TKT-0369
```

**Guardrails:**
- Child cannot be the same as parent
- Child cannot already be folded
- Both tickets must exist in PG

#### `list [filters]`
Dependency-aware ticket queries. Accepted filters:

| Filter | Description |
|--------|-------------|
| `--status <s>` | Filter by status (normalized: open/in-progress/closed/pending/backlog/cancelled/monitoring/folded) |
| `--sprint <name>` | Filter by `metadata.sprint_target` |
| `--open` | All non-closed statuses (open, in-progress, pending, backlog, grooming, monitoring) |
| `--blocked` | Tickets with dependencies where NO blocker is closed/done/folded |
| `--blocked-by <TKT>` | Tickets blocked BY a specific ticket |

```bash
bash scripts/db-ticket.sh list --sprint "Sprint 7" --open
bash scripts/db-ticket.sh list --blocked
bash scripts/db-ticket.sh list --blocked-by TKT-0323
```

#### `sync <TKT-ID>`
One-shot PG → Notion sync for a single ticket. Updates `metadata.notion_sync` with syncing/synced/failed status. Uses `pg-to-notion-sync.sh`.

```bash
bash scripts/db-ticket.sh sync TKT-0369
```

#### `validate`
Audits all open tickets for required metadata fields:
- `metadata.brief` must exist and be non-empty
- `metadata.grooming_history[]` must exist and be non-empty
- `metadata.notion_sync` must exist

Reports pass/fail counts and lists failed tickets. Exit 0 if all pass, exit 1 if any fail.

```bash
bash scripts/db-ticket.sh validate
```

### Critical Rules
1. **Subcommands only.** No top-level flags. `db-ticket.sh --force create` will error.
2. **`create` is interactive ONLY.** No `--title`, `--priority`, `--type` flags — those were the source of Failure #5.
3. **`update` payload must be valid JSON.** Schema validation rejects type violations and forbidden fields.
4. **`fold` only accepts `--into`.** No other flags in fold context.
5. **Unknown subcommands print usage and exit 1.** No silent degradation.

---

## db-sprint.sh — Sprint Operations (PG-First)

**Script:** `/Users/ainchorsangiefpl/.openclaw/workspace/scripts/db-sprint.sh`
**PG Table:** `state_sprints` (authoritative) + `state_tickets.metadata.sprint_target` (ticket assignment)
**Sprint JSON files:** `state/sprint-N.json` — read-only cache, NOT authoritative

### Subcommand Catalog

#### `current`
Returns current sprint as JSON from PG. Detection priority:
1. Active/committed sprint in `state_sprints`
2. Most recent sprint by `sprint_number`
3. Most common `sprint_target` in open tickets
4. Default: "Sprint 7"

Merges ticket counts (total/done) into the response.

```bash
bash scripts/db-sprint.sh current
```

#### `commit <TKT-ID> <seq> <effort> <agent>`
Commits a ticket to the current sprint. Sets on `state_tickets`:
- `metadata.sprint_target` — sprint name
- `metadata.sprint_seq` — sequence number
- `metadata.sprint_effort` — effort estimate
- `metadata.sprint_agent` — assigned agent
- `metadata.sprint_committed_at` — timestamp

Also updates `state_sprints.items` if a PG sprint row exists.

```bash
bash scripts/db-sprint.sh commit TKT-0369 1 M-L forge
```

#### `status [--sprint <name>]`
Sprint progress view with **live dependency graph resolution**. For each ticket in the sprint:
- Shows: SEQ, ID, TITLE, STATUS, FLAG (READY/BLOCKED), EFFORT, AGENT
- **READY:** no unfulfilled dependencies (or no deps at all)
- **BLOCKED:** at least one dependency not closed/done/folded — verified by PG query

Summary: Total | Open | In Progress | Done | Pending | Blocked | Ready | Completion %

```bash
bash scripts/db-sprint.sh status --sprint "Sprint 7"
```

#### `plan [--sprint <name>]`
Sprint planning view: all committed items with sprint metadata. Shows:
- Sprint dates, status, capacity (from PG `state_sprints`)
- Committed items table: SEQ, ID, TITLE, EFFORT, AGENT, STATUS, DEPS
- Deferred items (with reason)
- Folded items

```bash
bash scripts/db-sprint.sh plan --sprint "Sprint 7"
```

#### `create "<Sprint X>" "<dates>"`
Creates a new sprint row in PG `state_sprints`. Dates format: `"2026-06-15 to 2026-06-21"`. Sprint number extracted from name. Rejects if sprint number already exists.

```bash
bash scripts/db-sprint.sh create "Sprint 8" "2026-06-15 to 2026-06-21"
```

#### `defer <TKT-ID> --to <Sprint X> --reason "..."` 
Defers a ticket from current sprint to target sprint. Updates:
- `metadata.sprint_target` → new sprint
- `metadata.deferred` → true
- `metadata.deferred_from` → old sprint
- `metadata.deferred_reason` → reason text
- `metadata.deferred_at` → timestamp
- Removes `sprint_seq` and `sprint_effort` (reset for new sprint)

```bash
bash scripts/db-sprint.sh defer TKT-0400 --to "Sprint 8" --reason "capacity full, deferring low-priority"
```

#### `migrate [--sprint <name>] [--dry-run]`
Migrates sprint JSON data to PG metadata. Processes:
1. `state/sprint-N.json` → `sequence[]` items
2. `state/sprint-N-assessed.json` → `priority_queue[]` items

For each ticket: checks if already in PG with correct sprint, detects conflicts (different sprint in PG vs JSON), applies migration. Reports: migrated, already-set, conflicts, not-in-PG.

`--dry-run` shows what would change without writing.

```bash
bash scripts/db-sprint.sh migrate --sprint "Sprint 7"
bash scripts/db-sprint.sh migrate --sprint "Sprint 7" --dry-run
```

---

## Ticket Metadata Schema

All fields live in `state_tickets.metadata` (JSONB column).

```json
{
  "brief": "1-2 sentence scope summary — what this ticket delivers",
  "effort": "XS|S|M|L|XL",
  "agent": "Forge|Yoda|Aria|Sage|Thrawn|...",
  "ac_count": 3,
  "sprint": "Sprint 7",
  "sprint_target": "Sprint 7",
  "sprint_seq": 1,
  "sprint_effort": "M-L",
  "sprint_agent": "forge",
  "sprint_committed_at": "2026-06-10T11:00:00+10:00",
  "depends_on": ["TKT-0323"],
  "blocks": [],
  "grooming_history": [
    {
      "date": "2026-06-10T11:00:00+10:00",
      "decisions": "Refined scope — split into Part A/B/C. Ken confirmed L effort.",
      "ac_count": 9,
      "ken_approved": true
    }
  ],
  "folded_from": ["TKT-0381", "TKT-0382"],
  "folded_scope": [
    {
      "tkt_id": "TKT-0381",
      "title": "Original child title",
      "brief": "Original child scope summary",
      "ac_count": 2,
      "effort": "S",
      "folded_at": "2026-06-10T11:00:00+10:00"
    }
  ],
  "folded_into": "TKT-0369",
  "folded_at": "2026-06-10T11:00:00+10:00",
  "notion_sync": {
    "last_synced": "2026-06-10T11:00:00+10:00",
    "status": "synced"
  },
  "deferred": true,
  "deferred_from": "Sprint 7",
  "deferred_reason": "capacity full",
  "deferred_at": "2026-06-10T11:00:00+10:00"
}
```

### Field Types & Constraints

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `brief` | string | Yes | Non-empty string. Filled on create, can be updated via groom. |
| `effort` | string | Yes | XS/S/M/L/XL. Set on create. |
| `agent` | string | Yes | Agent name. Set on create. |
| `ac_count` | number | Yes | Integer ≥ 0. Set on create, updated via groom. |
| `sprint` | string | No | Sprint assignment (legacy, prefer `sprint_target`). |
| `sprint_target` | string | No | Active sprint assignment. Set by `db-sprint.sh commit`. |
| `sprint_seq` | number | No | Sequence within sprint. Set by commit. |
| `sprint_effort` | string | No | Effort for sprint context. Set by commit. |
| `sprint_agent` | string | No | Agent for sprint context. Set by commit. |
| `sprint_committed_at` | string | No | ISO 8601 timestamp. Set on commit. |
| `depends_on` | array | No | Array of TKT-ID strings. Blocks execution until deps closed. |
| `blocks` | array | No | Array of TKT-ID strings this ticket blocks. |
| `grooming_history` | array | Yes | Must have ≥ 1 entry for validation. Each entry: {date, decisions, ac_count, ken_approved}. |
| `folded_into` | string | No | Parent TKT-ID. Set on child when folded. |
| `folded_from` | array | No | Child TKT-IDs. Set on parent when children folded in. |
| `folded_scope` | array | No | Structured scope from folded children. Preserved permanently. |
| `notion_sync` | object | Yes | {last_synced, status}. Status: pending/syncing/synced/failed. |
| `deferred` | boolean | No | True if deferred from a sprint. |
| `deferred_from` | string | No | Source sprint name. |
| `deferred_reason` | string | No | Reason for deferral. |
| `deferred_at` | string | No | ISO 8601 timestamp. |

---

## PG Table Reference

### `state_tickets`

| Column | Type | Description |
|--------|------|-------------|
| `id` | text | Primary key. TKT-NNNN format. |
| `title` | text | Ticket title. |
| `status` | text | open/in-progress/closed/pending/backlog/cancelled/monitoring/folded |
| `priority` | text | critical/high/medium/low |
| `type` | text | task/bug/build/epic/story/chg/feature/infra |
| `created_at` | timestamptz | System-managed. |
| `updated_at` | timestamptz | Auto-updated on write. |
| `metadata` | jsonb | All structured metadata (see schema above). |
| `sequence` | int | Legacy sequence number. |
| `tags` | text[] | Array tags. |
| `notionpageid` | text | Notion page ID for sync. |
| `url` | text | URL field. |

### `state_sprints`

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key (auto). |
| `sprint_number` | int | Numeric sprint identifier. |
| `sprint_name` | text | "Sprint N" format. |
| `start_date` | date | Sprint start date. |
| `end_date` | date | Sprint end date. |
| `status` | text | planning/active/committed/completed |
| `capacity` | int | Sprint capacity in points. |
| `committed_at` | timestamptz | When items were committed. |
| `committed_by` | text | Who committed. |
| `items` | jsonb | Array of committed items: [{tkt, seq, effort, agent, committed_at}]. |
| `notes` | text | Free-text notes. |
| `created_at` | timestamptz | Auto. |
| `updated_at` | timestamptz | Auto. |
| `tenant_id` | text | Tenant identifier. |

---

## Common Query Patterns

### Get all open tickets for current sprint
```bash
bash scripts/db-ticket.sh list --sprint "Sprint 7" --open
```

### Find blocked tickets
```bash
bash scripts/db-ticket.sh list --blocked
```

### Find what's blocked by a specific ticket
```bash
bash scripts/db-ticket.sh list --blocked-by TKT-0323
```

### Show sprint progress with dependency resolution
```bash
bash scripts/db-sprint.sh status --sprint "Sprint 7"
```

### View sprint plan (committed items)
```bash
bash scripts/db-sprint.sh plan --sprint "Sprint 7"
```

### Validate all open tickets have required metadata
```bash
bash scripts/db-ticket.sh validate
```

### Raw PG query (read-only, for investigation)
```bash
bash scripts/db.sh -c "SELECT id, status, metadata->>'brief' FROM state_tickets WHERE status='open' ORDER BY id;"
```

### Check if a ticket exists
```bash
bash scripts/db.sh -c "SELECT id FROM state_tickets WHERE id='TKT-0369';"
```

### Export all sprint tickets as JSON array
```bash
bash scripts/db.sh -c "SELECT jsonb_agg(row_to_json(t)) FROM state_tickets t WHERE metadata->>'sprint_target' = 'Sprint 7';"
```

---

## Error Handling

### Ticket not found
```
ERROR: Ticket TKT-XXXX not found in PG or fallback file
```
→ Verify the TKT-ID exists. Use `bash scripts/db-ticket.sh list` to see all tickets.

### Duplicate ticket on create
```
ERROR: TKT-XXXX already exists. Use 'db-ticket.sh update' to modify.
```
→ Use `update` subcommand instead, or pick a different ID.

### Create collision (race)
```
ERROR: COLLISION: TKT-XXXX was created between check and write. Use db-ticket.sh update instead.
```
→ Rare. The ticket was created between existence check and write. Use `update`.

### Schema validation failure on update
```
ERROR: Schema validation failed: METADATA_TYPE_ERROR: metadata.grooming_history must be array
```
→ Fix the JSON payload. Refer to the metadata schema above.

### PG write degraded
```
WARNING: PG write degraded (...). Ticket may only exist in file fallback.
```
→ PG is unreachable. Write went to `tickets.json` fallback only. Sync when PG is back online.

### Flags silently ignored (DO NOT DO THIS)
```
bash scripts/ticket.sh create --id TKT-0400 --title "Foo" --priority high
```
→ **This is wrong.** ticket.sh has no flag validation and will silently ignore flags.
→ Use: `bash scripts/db-ticket.sh create` (interactive) or `bash scripts/ticket.sh create "TKT-0400" "Foo" "high" "task"` (positional for legacy ticket.sh).

### Wrong tool: using db.sh directly for ticket writes
```bash
bash scripts/db.sh -c "INSERT INTO state_tickets VALUES (...);"
```
→ **NEVER do this.** Direct DB writes bypass metadata validation, grooming history, and Notion sync. Violations are detectable by missing `grooming_history[]` entries.

### ⚠️ CRITICAL — L-095: TQP queue writes go to PG, NOT to `state/task-queue.json` (2026-06-13)

**`state/task-queue.json` is a write-only audit trail.** TQP (`scripts/task-queue-processor.sh`, cron `a89d00ef`) reads **exclusively from PG `state_task_queue` table**, never from the JSON file. The JSON file is only consumed by `scripts/task-watchdog.sh` for **divergence detection** (it generates the alert when JSON says `queued` but PG says `done`, or vice versa).

**WRONG — TQP will NEVER see this:**
```bash
python3 -c "import json; d=json.load(open('state/task-queue.json')); d['queue'].append(atom); ..."
```
→ Atom is filed in JSON. TQP cron runs every 5 min, finds nothing, logs "TQP: No queued or dispatched tasks. Exiting." — silent failure (L-095).

**CORRECT — INSERT directly into PG `state_task_queue`:**
```bash
bash scripts/db-raw.sh -c "INSERT INTO state_task_queue (id, title, status, priority, source, atoms_jsonb, atoms, created_at, updated_at, created_at_ts, updated_at_ts, atom_index, tenant_id, iteration_count, persistence_type)
VALUES ('TKT-NNNN-A1', 'Atom title', 'queued', 8, 'agent:tqp',
        '{\"ac\":\"AC1\",\"tkt\":\"TKT-NNNN\",\"task\":\"...\",\"agent\":\"forge\",\"effort\":\"S\",\"atom_seq\":1,\"depends_on\":[],\"pass_condition\":\"...\",\"model\":\"flash\"}'::jsonb,
        'auto-queued description', '2026-06-13T10:00:00+10:00', '2026-06-13T10:00:00+10:00', '2026-06-13 10:00:00+10:00', '2026-06-13 10:00:00+10:00',
        1, 'ainchors', 0, 'INLINE_ATOM')
ON CONFLICT (id) DO UPDATE SET status='queued', atoms_jsonb=EXCLUDED.atoms_jsonb, updated_at=EXCLUDED.updated_at;"
```

**Schema reference for `state_task_queue`:**
- `id` TEXT PRIMARY KEY — format: `TKT-NNNN-A{N}` or `task-YYYY-MM-DD-{uuid}`
- `title` TEXT — short title (≤80 chars preferred)
- `status` TEXT — `queued` | `dispatched` | `running` | `complete` | `done` | `closed` | `cancelled` | `pending-approval`
- `priority` INTEGER — 0-10 (10 = P0/critical, 8 = P1/high, 5 = P2/medium)
- `source` TEXT — typically `agent:tqp` (matches existing pattern)
- `atoms_jsonb` JSONB — full atom spec: `{ac, tkt, task, agent, effort, atom_seq, depends_on, pass_condition, model}`
- `atoms` TEXT — human-readable description (visible in PG psql output)
- `created_at` / `updated_at` TEXT — ISO-8601 with timezone
- `created_at_ts` / `updated_at_ts` TIMESTAMPTZ — for sort/filter
- `atom_index` INTEGER — sequence number within parent ticket (1, 2, 3…)
- `tenant_id` TEXT — always `'ainchors'`
- `iteration_count` INTEGER — default 0
- `persistence_type` TEXT — `INLINE_ATOM` for normal TQP work

**Verify your queue write will be picked up:**
```bash
bash scripts/task-queue-processor.sh    # should immediately say "Processing TKT-NNNN-A1 — Claimed"
bash scripts/db-raw.sh -c "SELECT id, status, claimedby, claimedat FROM state_task_queue WHERE id='TKT-NNNN-A1';"
```

**If you must also write to the JSON file (for audit trail — recommended):** append to the `queue` array of `state/task-queue.json` AND insert into PG. The watchdog cron will generate a divergence alert if they disagree, which is the intended safety net. Never expect TQP to read the JSON.

**Detection of orphan JSON writes:** auto-heal CHECK 28f (added L-095) scans PG for `state_task_queue` rows with `status='queued'` and compares to the `state/task-queue.json` queue array; alerts Ken via `NEEDS_KEN` if JSON has entries that PG doesn't. Existing `task-watchdog.sh` handles the opposite direction (PG→JSON).

---

## Agent Contract (NON-NEGOTIABLE)

### Write Path Rules

1. **`db-ticket.sh` is the ONLY write path for tickets.** Never use raw `db.sh -c INSERT/UPDATE` for tickets.
2. **`db-sprint.sh` is the ONLY write path for sprint data.** Never hand-edit sprint JSON files.
3. **Unknown flags are rejected.** All commands use subcommands, not `--flags`. This is enforced — passing flags to `create`, `read`, `update`, `groom`, `sync`, `validate` will error.
4. **`create` is interactive-only.** No `--title`, `--priority` flags. Just run `db-ticket.sh create` and answer prompts.
5. **Sprint JSON files (`state/sprint-N.json`) are read-only cache.** They are NOT authoritative. PG is the SSOT.

### Audit Trail

Every write through `db-ticket.sh` produces:
- `metadata.grooming_history[]` entries (created with ticket, appended on groom)
- `metadata.notion_sync` status tracking
- Timestamped updates on `updated_at`

**Violations are detectable:** raw PG writes lack `grooming_history[]` entries and have no audit trail. Run `db-ticket.sh validate` to catch violations.

### Why This Exists (Failure Registry)

This skill and the underlying scripts were created in response to **5 failures in a single session (2026-06-09):**

| # | Failure | Root Cause |
|---|---------|-----------|
| 1 | Agent guessed PG interface 3x wrong before finding correct syntax | No skill — every agent rediscovers interface per session |
| 2 | TKT-0323 scope lost — reported as M effort, actual was L 16-atom 3-part | Ticket body free-text, no structured scope capture |
| 3 | PG/JSON divergence — sprint-7.json had data that PG didn't | Dual-write discipline failed, no automated sync |
| 4 | sprint-7.json corrupted by unescaped newline in string concat | No validated write path, hand-edited JSON |
| 5 | ticket.sh --flags silently ignored — 8 tickets degraded to file-only | ticket.sh no flag validation, agent guessed wrong invocation |

**Prevention:** This skill is loaded by all agents before TKT/sprint operations. The scripts reject bad patterns structurally. The lifecycle is documented once, not rediscovered per-session.

---

## TQP Execution Path (TKT-0504)

The TQP (Task Queue Processor) is the cron-driven dispatch loop for `state_task_queue` rows. It is **not** just a queue manager — it has a 2-stage hand-off chain that downstream consumers (CREST and non-CREST) plug into.

### Architecture

```
cron a89d00ef (every 5 min)
  └─→ scripts/task-queue-processor.sh   # TQP claim loop (queue manager)
        ├─ atomic claim: status='queued' → 'dispatched', claimedby='agent:tqp'
        ├─ if parent_task_id IS NULL (non-CREST TQP atom):
        │     └─→ scripts/tqp-executor.sh --limit 1 --dry-run=false   # (A3 handoff)
        │           ├─ query: dispatched + claimedby='agent:tqp' + no parent + executor empty
        │           ├─ atomic UPDATE: state_payload.executor='tqp-executor', status='running'
        │           ├─ idempotency gate: WHERE state_payload->>'executor' IS NULL
        │           └─ INSERT in-band exec-atom: source='agent:tqp-queued',
        │              parent_task_id=original, atoms_jsonb={task,model,agent,...}
        └─ (CREST sub-atom with parent_task_id): flash-dispatcher.sh handles via state_sub_crest
   exec-atom → sessions_spawn (parent runtime) → execute → status='done'
```

### When to Use

The TQP execution path is for **non-CREST TQP-queued atoms** (atoms in `state_task_queue` with `source='agent:tqp'`, `parent_task_id IS NULL`). CREST sub-atoms (with `parent_task_id` set) take a different path via `flash-dispatcher.sh` (TKT-0386) and `state_sub_crest` / `state_sub_crest_atoms`.

**Idempotency contract:** the executor is safe to re-run. Rows with `state_payload.executor` non-null are skipped by the WHERE clause. `tqp-executor.sh --dry-run` is the safe inspection mode.

### Pitfalls

- **L-096 silence class.** TQP claim succeeded but no executor consumed the atom. TKT-0504 ships `tqp-executor.sh` (A1–A2) plus the A3 handoff in `task-queue-processor.sh` to close this gap. CHECK 28g in auto-heal.sh (severity WARN post-A0) detects the class. See `memory/LESSONS.md` L-096.
- **L-095 PG-vs-JSON divergence.** TQP reads/writes PG (the canonical store). The `state/task-queue.json` path is orphaned. Do not use it.
- **Role boundary (CHG-0545).** tqp-executor.sh does not call `sessions_spawn` directly. It produces an exec-atom row; the parent runtime (Yoda) consumes the exec-atom and calls `sessions_spawn`. This keeps executor execution context-free and the parent in the dispatch-control seat.
- **Cron registration.** The TQP cron `a89d00ef` is OpenClaw gateway-managed (no `crons` table in PG). Forge/Yoda isolated contexts cannot add it via DB. Yoda registers via gateway API; from Forge, only the script chain is verifiable.
- **Idempotency gate.** The atomic UPDATE is the safety net. Re-running `tqp-executor.sh` on an already-claimed atom (executor set) is a no-op. Do not remove the WHERE clause.
- **Header parsing.** `db-raw.sh` uses `psql -t -A` (tuples-only, unaligned) — NO header in output. Use `sed -n '1p'` to grab the data line, not `'2p'`. (A4 dogfood caught this bug; A2's isolated test did not.)

### Verification Command

```bash
bash scripts/tqp-executor.sh --dry-run
```

Should show 0+ queued TQP atoms ready for spawn. Pre-TKT-0504 this always returned 0 because the executor did not exist. Post-fix:
- 0 ready → healthy idle (no TQP-queued work pending)
- N ready → a downstream consumer (cron or operator) needs to run `bash scripts/tqp-executor.sh` without `--dry-run` to dispatch

End-to-end smoke test:
```bash
# 1. Insert a TQP-queued atom
bash scripts/db-raw.sh -c "INSERT INTO state_task_queue (id,title,tier,status,priority,source,atoms_jsonb,created_at,updated_at,created_at_ts,updated_at_ts) VALUES ('TKT-SMOKE','smoke','S','queued','normal','agent:tqp','{\"task\":\"echo ok\",\"agent\":\"forge\",\"model\":\"flash\"}'::jsonb,now()::text,now()::text,now(),now());"
# 2. Claim + handoff (A3 fires tqp-executor automatically)
bash scripts/task-queue-processor.sh
# 3. Verify exec-atom exists with parent_task_id=TKT-SMOKE
bash scripts/db-raw.sh -c "SELECT id,status,parent_task_id,source FROM state_task_queue WHERE parent_task_id='TKT-SMOKE';"
# 4. Cleanup
bash scripts/db-raw.sh -c "DELETE FROM state_task_queue WHERE id='TKT-SMOKE' OR parent_task_id='TKT-SMOKE';"
```

### Linked

- **L-096** — TQP claims but no executor (the silence class this section fixes)
- **TKT-0504** — TQP bridge (5 atoms: A0 demote CHECK 28g; A1 skeleton; A2 sessions_spawn integration; A3 cron handoff; A4 dogfood; A5 this doc)
- **TKT-0386** — flash-dispatcher.sh (CREST consumer, separate path; do not modify from TQP work)
- **TKT-0503** — original 5 TQP atoms stuck (the failure that motivated TKT-0504)
- **CHG-0547..0552** — one per TKT-0504 atom
- **scripts/tqp-executor.sh** — the executor (TKT-0504 A1+A2)
- **scripts/task-queue-processor.sh** — TQP claim loop with A3 handoff
- **scripts/auto-heal.sh CHECK 28g** — silence-class detector (severity WARN post-A0)
