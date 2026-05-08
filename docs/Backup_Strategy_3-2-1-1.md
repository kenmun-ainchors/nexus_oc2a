# AInchors Backup Strategy — 3-2-1+1

**Document:** Backup_Strategy_3-2-1-1.md  
**Owner:** Ken Mun (CTO, AInchors)  
**Ticket:** TKT-0093  
**Last Updated:** 2026-05-08  
**Status:** P1 Active — iCloud offsite live, NAS deferred to OC2 (TRIGGER-02)

---

## Current State (P1, May 2026)

| Component | Status |
|-----------|--------|
| Local nightly backup | ✅ Active — `~/Backups/ainchors/` via `backup.sh` |
| Git remote (workspace) | ✅ Active — offsite code + memory copy |
| iCloud offsite backup | ✅ Active — `~/Library/Mobile Documents/com~apple~CloudDocs/AInchors-Backups/` |
| NAS encrypted storage | ❌ Deferred — awaiting OC2 hardware (July 2026) |
| backup-state.json tracking | ✅ Active — updated after every run |
| Backup health cron | ✅ Active — daily 8:05 AM AEST, alerts Ken if stale |

---

## Target State (post-OC2, July 2026)

| Component | Target |
|-----------|--------|
| Local backup | ✅ Maintained |
| iCloud offsite | ✅ Maintained |
| NAS (OC2-A + OC2-B shared) | AES-256 encrypted, Tailscale-only access |
| NAS → Cloud sync | rclone or Synology Cloud Sync (continuous) |
| Model weights versioned | Hash-verified, NAS-hosted |
| Full 3-2-1+1 compliance | ✅ Achieved on TRIGGER-02 completion |

---

## What's Backed Up (Scope)

### Included
- `~/.openclaw/workspace/` — all agent memory, state, scripts, docs, skills
- `~/.openclaw/openclaw.json` — gateway config (auth fields scrubbed)
- Git history (workspace repo, via auto-commit before tar)

### Excluded (Security)
- `auth-profiles.json` — excluded from tar (S5 fix, CHG-0152)
- `auth-state.json` — excluded from tar
- API keys, tokens — macOS Keychain only, never in files

### Not Yet Covered (OC2 scope)
- Model weights (OC2-A, OC2-B)
- Canvas session data
- Agent session databases

---

## Retention Policy

| Location | Copies Kept | Cadence |
|----------|-------------|---------|
| Local (`~/Backups/ainchors/workspace/`) | 30 | Daily |
| iCloud Drive (`AInchors-Backups/`) | 7 | Daily |
| Git remote | Unlimited (all commits) | Per-change |
| NAS (OC2) | TBD | Continuous sync |

---

## 3-2-1+1 Implementation Matrix

| Rule | Requirement | Implementation | Status |
|------|------------|----------------|--------|
| **3 copies** | 3 independent copies of data | Local tar + iCloud + Git remote | ✅ |
| **2 media types** | 2 different storage media | Local SSD + iCloud (Apple cloud) | ✅ |
| **1 offsite** | 1 copy geographically separate | iCloud (Apple data centres) + NAS (OC2) | ✅ |
| **+1 immutable** | 1 append-only / immutable copy | Git remote (commit history immutable) | ✅ |

**Current compliance:** 3-2-1+1 ✅ (all 4 rules met as of TKT-0093)

---

## NAS Encryption Plan (TRIGGER-02 Gate)

> **Gate condition:** Both OC2-A and OC2-B nodes live + NAS physically installed

### Hardware
- NAS model: TBD (arrives with OC2, July 2026)
- Shared across: OC2-A and OC2-B (model weights + agent state)

### Encryption
- **Method:** AES-256 at rest — NAS firmware-level encryption preferred; fallback: VeraCrypt volume
- **Key storage:** macOS Keychain on OC2-A (primary); USB hardware key (recovery)
- **Access:** Tailscale mesh only — no public IP, no port forwarding

### Network
- OC2-A ↔ NAS ↔ OC2-B via Tailscale (private mesh)
- No internet exposure of NAS management interface
- Firewall rule: block all inbound to NAS except Tailscale subnet

### Cloud Sync (NAS → Cloud)
- Tool: rclone (preferred) or Synology Cloud Sync
- Target: Backblaze B2 or S3-compatible bucket (encrypted client-side before upload)
- Frequency: Continuous (near-real-time for state files); daily for model weights

### Model Weights
- Version-controlled with SHA-256 hash file per version
- Stored on NAS: `/nas/models/<model-name>/<version>/`
- Hash verification on load: if mismatch → alert Ken + block model use

### S7 Completion Gate (Checklist)
- [ ] Both OC2-A and OC2-B nodes live (TRIGGER-02)
- [ ] NAS physically installed and firmware-encrypted
- [ ] Tailscale mesh routing confirmed (OC2-A ↔ NAS ↔ OC2-B)
- [ ] rclone cloud sync active and verified
- [ ] Model weights migrated to NAS with hash verification
- [ ] `backup-state.json` updated: `nasConnected: true`
- [ ] PVT 9/9 pass with NAS checks included
- [ ] Ken sign-off

---

## Recovery Procedures

### Restore from Local Backup
```bash
# List available snapshots
ls ~/Backups/ainchors/workspace/

# Restore workspace (replace with desired timestamp)
SNAP="workspace-2026-05-08-0200.tar.gz"
cd ~/.openclaw
tar -xzf ~/Backups/ainchors/workspace/$SNAP

# Restore config
cp ~/Backups/ainchors/config/openclaw-2026-05-08-0200.json ~/.openclaw/openclaw.json
```

### Restore from iCloud
```bash
ICLOUD="$HOME/Library/Mobile Documents/com~apple~CloudDocs/AInchors-Backups"
ls "$ICLOUD"  # list available

SNAP="workspace-2026-05-08-0200.tar.gz"
cd ~/.openclaw
tar -xzf "$ICLOUD/$SNAP"
```

### Restore from Git Remote
```bash
cd ~/.openclaw/workspace
git log --oneline | head -20  # find the commit to restore to
git checkout <commit-hash> -- .  # restore specific files
# OR full rollback:
git reset --hard <commit-hash>
```

### Restore from NAS (post-OC2)
```bash
# Mount NAS via Tailscale
# (Tailscale IP assigned at OC2 setup time)
mount -t nfs <NAS-TAILSCALE-IP>:/backup /mnt/nas-backup
cp /mnt/nas-backup/workspace-<date>.tar.gz ~/
tar -xzf workspace-<date>.tar.gz -C ~/.openclaw/
```

---

## S7 Compliance Status

| S7 Requirement | Status |
|----------------|--------|
| Backup strategy documented | ✅ This document |
| Local encrypted backup | ✅ (SSD at rest, macOS FileVault) |
| Offsite backup | ✅ iCloud + Git remote |
| NAS encrypted (post-OC2) | ⏳ Deferred — TRIGGER-02 gate |
| Retention policy defined | ✅ 30 local / 7 iCloud / unlimited git |
| Recovery procedures documented | ✅ This document |
| Backup health monitoring | ✅ Daily cron + Telegram alert |
| Auth files excluded from backup | ✅ CHG-0152 / S5 fix |

**Overall S7 status:** Partial — Pre-OC2 controls in place. Full compliance pending TRIGGER-02 + NAS encryption.
