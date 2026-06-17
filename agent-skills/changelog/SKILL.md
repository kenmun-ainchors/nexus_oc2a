---
name: changelog
description: Create and manage CHG (Change) records for every structural platform change
---

# Changelog (CHG Records)

## What Is a CHG Record?

Every structural change (config, script, cron, rule, agent, infra, data, or doc) gets `[CHG-NNNN]` — an auto-incremented, permanent ID linked to the Notion Archive DB. This is the **provenance chain**: what changed, why, and how to rollback.

## Creation

```sh
# ⚠️ This script is zsh-only (uses ${(P)var} parameter expansion).
# Invoke with zsh explicitly, not bash:
zsh scripts/changelog-append.sh \
  --type <TYPE> \
  --source <SOURCE> \
  --title "<TITLE>" \
  --trigger "<WHAT TRIGGERED THIS>" \
  --changed "<WHAT CHANGED>" \
  --why "<WHY>" \
  --verified "<HOW VERIFIED>" \
  [--rollback "<ROLLBACK>"] \
  [--linked "<LINKS>"]
```

**Allowed --type:** `config | script | cron | rule | agent | infra | data | doc`
**Allowed --source:** `ken-prompt | auto-heal | incident-recovery | scheduled | manual`

**Common pitfalls:** using `bash` instead of `zsh` → `${(P)var}: bad substitution`. Using wrong `--type` (e.g., `build`) → enum validation error. Using TKT-ID as `--source` → must be one of the 5 enumerated values, NOT a ticket ID. Use `--source ken-prompt` when triggered by Ken approval.

## Format

Records use `[CHG-NNNN]` format, auto-incremented by the script. The file lives at `memory/CHANGELOG.md` (appended, not replaced).

## Notion Sync

CHG records go to **Notion Archive DB (DB C)**, NOT the Sprint Backlog. The script handles Notion sync automatically.
- DB C (Archive): `364c1829-53ff-818e-a783-ebafcb6a9880`

## Validation

`grep "CHG-NNNN" memory/CHANGELOG.md` && check Notion Archive DB for matching page. Both must exist for DoD.

## Audit

`grep "CHG-NNNN" memory/CHANGELOG.md`

## Reference

Notion DBs: see `TOOLS.md` (CHG-0401 3-DB architecture). Archive DB C: `364c1829-53ff-818e-a783-ebafcb6a9880`