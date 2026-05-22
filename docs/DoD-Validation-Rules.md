# DoD Validation Rules
**TKT-0237 A2 | Version 1.0 | Enforced by ticket.sh verify_before_close()**

The single source of truth for what "done" means per ticket type. This document defines the verification rules that `ticket.sh close` enforces before any ticket can be marked closed.

---

## 1. Ticket Type Matrix

| Type | File Exists | Git Committed | CHANGELOG Entry | Config Baseline | Ticket Linked |
|------|-------------|---------------|-----------------|-----------------|---------------|
| `task` | ✅ Required* | ✅ Required | — | — | — |
| `bug` | ✅ Required* | ✅ Required | ✅ Required | — | ✅ (to CHG) |
| `change` (CHG) | — | ✅ Required | ✅ Required | — | — |
| `config` | ✅ Required | ✅ Required | — | ✅ Required | — |
| `incident` | ✅ Required* | ✅ Required | ✅ Required | — | ✅ (to INC) |

*Skip file check if `--deliverable-path` not declared (e.g., research tickets, DB-only changes)

---

## 2. Deliverable Path Convention

| Deliverable Type | Location | Example |
|-----------------|----------|---------|
| Document (markdown) | `docs/` | `docs/DoD-Validation-Rules.md` |
| Script (shell/python) | `scripts/` | `scripts/task-queue-processor.sh` |
| State file (JSON) | `state/` | `state/task-queue.json` |
| HTML output | `canvas/documents/` | `canvas/documents/rule-audit-weekly/index.html` |
| Config change | source path | `openclaw.json`, `scripts/ticket.sh` |
| Notion page | Notion API (not filesystem) | Check via Notion search API |
| Database migration | Postgres (not filesystem) | Check `ainchors_nexus` schema |

---

## 3. Edge Cases

### 3.1 Research / Analysis Tickets
No file deliverable. Close with `--skip-verify` and log CHANGELOG entry documenting the research outcome. Rationale: research produces knowledge, not files.

### 3.2 Ken Hand-Close
Ken can close any ticket with `--skip-verify`. Every override MUST be logged to CHANGELOG with: who overrode, which ticket, why. Audit trail is non-negotiable.

### 3.3 Database Migrations
If deliverable is a Postgres change (migration, new table, schema update), check the database directly: `psql -c "SELECT tablename FROM pg_tables WHERE schemaname='public'"`. File check is skipped.

### 3.4 Notion-Only Deliverables
If deliverable lives only in Notion (no local file), use Notion search API to verify the page exists and has correct properties. File check is skipped.

### 3.5 Tickets Without notionPageId
Tickets created before Notion integration or manually without syncing have `notionPageId: null`. Close works locally without Notion archive attempt. No error.

### 3.6 Re-close (Already Closed)
If ticket status is already `closed` or `cancelled`, close is a no-op. Warning printed, exit 0.

### 3.7 Multi-File Deliverables
Declare the primary deliverable as `--deliverable-path`. Additional files should be in the same git commit. The git check (`git diff HEAD~1 --name-only`) captures all changed files.

---

## 4. Override Protocol

| Rule | Detail |
|------|--------|
| **Who can override** | Ken Mun only |
| **How** | `ticket.sh close TKT-NNNN --skip-verify --resolution "..."` |
| **Audit trail** | Every `--skip-verify` MUST be logged to `memory/CHANGELOG.md` with: ticket ID, reason for override, date, who authorized |
| **Non-compliance** | Skip-verify without CHANGELOG entry is a DoD violation — flagged by R05 (State Checking) in rule-audit.sh |
| **Emergency exception** | If platform is down and Ken needs to close tickets manually: direct JSON edit to `state/tickets.json` with CHANGELOG entry within 24h |

---

## 5. SoT Mapping (TKT-0197)

| Check | SSOT | Location |
|-------|------|----------|
| Ticket exists | tickets.json | `state/tickets.json` |
| File exists | Local filesystem | Per path convention (§2) |
| Git committed | Git repository | `git log` on workspace |
| CHANGELOG entry | CHANGELOG.md | `memory/CHANGELOG.md` |
| Config baseline | critical-config-baseline.json | `state/critical-config-baseline.json` |
| Notion page exists | Notion API | `34dc1829-53ff-814b-8257-d3a3bf351d44` (DB A) |
| Postgres migration | Postgres | `ainchors_nexus` database |
| Content governance | content-queue.json | `state/content-queue.json` |

---

## Enforcement

This document is referenced in RULES.md as a non-negotiable gate. The `verify_before_close()` function in `scripts/ticket.sh` enforces these rules programmatically. Violations block ticket close. Override available only via `--skip-verify` with mandatory CHANGELOG audit trail.
