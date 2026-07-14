# CHG-DRAFT — Restore MinIO Service on New Host

**Status:** DRAFT — pending Ken approval  
**Proposed CHG-ID:** CHG-0ZZZ (to be assigned by changelog-append.sh after execution)  
**Date:** 2026-07-14 00:29 AEST  
**Type:** Normal  
**Source:** CREST post-migration shakedown — platform operational readiness  
**Triggered by:** Migration to `ainchorsoc2a` host left MinIO binary, data dir, secrets, and launchd service absent.

## Current state
- `minio` binary not installed (`command -v minio` fails).
- `mc` (MinIO client) not installed.
- `infra/minio/` directory does not exist in workspace.
- Health check reports `MinIO: down (http://127.0.0.1:9000/minio/health/live failed)`.
- Legacy scripts `scripts/minio-upload.sh` and `scripts/minio-presign.py` still point to old host paths and old Tailscale hostname `ainchorss-mac-mini.tail5e2567.ts.net`.

## What changed (proposed)
1. Install `minio` and `mc` via the local Homebrew (`/Users/ainchorsoc2a/homebrew/bin/brew install minio/stable/minio minio/stable/mc`).
2. Create workspace directories:
   - `infra/minio/data`
   - `infra/minio/secrets`
3. Create credentials:
   - `infra/minio/secrets/minio_user.txt`
   - `infra/minio/secrets/minio_password.txt`
   - Add the password to macOS Keychain with service `ainchors-minio`.
   **Decision:** use fresh auto-generated credentials on this host. Old host credentials will not be migrated.
4. Create a LaunchAgent plist at `~/Library/LaunchAgents/com.ainchors.minio.plist` that starts MinIO on `127.0.0.1:9000` with `infra/minio/data` as data dir.
5. Load/start the service and verify `http://127.0.0.1:9000/minio/health/live` returns 200.
6. Update `scripts/minio-upload.sh`:
   - Resolve `mc` path via `command -v` / brew prefix fallback.
   - Resolve workspace/secrets paths via script location.
   **Tailscale hostname (this host, OC2A):** `ainchorsoc2as-mac-mini-1.tailfc3ed1.ts.net`. Replaces old OC1 endpoint `ainchorss-mac-mini.tail5e2567.ts.net`.
7. Update `scripts/minio-presign.py`:
   - Resolve workspace/secrets paths.
   - Update `ENDPOINT` to `ainchorsoc2as-mac-mini-1.tailfc3ed1.ts.net`.
8. Smoke test: upload a small test file to a `test` bucket and generate a presigned URL.

## Why
MinIO is required for platform file storage and presigned asset delivery. It is currently a red item in heartbeat health-state and blocks any feature depending on object storage.

## Verification plan
1. `curl -sS http://127.0.0.1:9000/minio/health/live` returns 200.
2. `brew services list | grep minio` shows `started`.
3. `scripts/minio-upload.sh --file /tmp/minio-test.txt --bucket test` exits 0 and prints a presigned URL.
4. Health-state re-check no longer reports MinIO down.

## Rollback
- Unload LaunchAgent: `launchctl unload ~/Library/LaunchAgents/com.ainchors.minio.plist`.
- Stop service: `brew services stop minio`.
- Revert script edits via git.
- Remove installed packages if needed.

## Linked
- Archived TKT-0155 AKB page: `state/akb-pages/37bc1829__TKT-0155___ARCHIVED___TKT-0155__Migrate_MinIO_from_Colima_D.md`
