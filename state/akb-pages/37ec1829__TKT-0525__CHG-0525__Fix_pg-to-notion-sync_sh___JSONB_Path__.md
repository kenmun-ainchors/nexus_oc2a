# [TKT-0525] CHG-0525: Fix pg-to-notion-sync.sh — JSONB Path + zsh Reserved Variable Bugs

- **Notion ID:** `37ec182953ff81758a56d292457d689f`
- **Status:** Open
- **Type:** CHG
- **Priority:** High
- **Category:** Operations
- **Sprint:** Sprint 7
- **Created:** 2026-06-13T03:26:00.000+10:00
- **Last Edited:** 2026-06-13T03:54:00.000Z

## Notes

Two silent-failure bugs in pg-to-notion-sync.sh: (1) JSONB dot-notation metadata->>'notion_sync.status' returns NULL — batch query never matched pending tickets. (2) zsh reserved variable 'status' causes read-only error. Both fixed. 30 tickets synced on re-run. L-096.
