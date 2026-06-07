# [CHG-0460] CHG-0457: Fix Backup Health Check Field-Name Mismatch

- **Notion ID:** `376c182953ff81b8b078c101c5e76434`
- **Status:** Done
- **Type:** CHG
- **Priority:** 
- **Category:** 
- **Sprint:** 
- **Created:** 2026-06-06
- **Last Edited:** 2026-06-05T22:06:00.000Z

## Notes

Type: script | Source: incident-recovery | Trigger: Telegram BACKUP_HEALTH FAILURE alert | Changed: backup-health-check.sh jq queries: .lastBackup → .last_backup (with snake_case fallback). .lastSnap → .workspace_snapshot. Backup was actually healthy (6h old, 1.7GB) but script read unknown for both fields due to camelCase/snake_case mismatch | Why: State file schema changed from camelCase to snake_case but script queries were never updated | Verified: Re-ran script: now reports BACKUP: healthy (snap: workspace-2026-06-06-0205, age: 6h, size: 1.7G, files: 220773) | Rollback: N/A
