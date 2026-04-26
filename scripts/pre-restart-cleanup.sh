#!/usr/bin/env bash
# =============================================================================
# pre-restart-cleanup.sh — AInchors Pre-Restart Cleanup
# =============================================================================
# Run this BEFORE any gateway restart, openclaw update, or risky operation.
# Automates the pre-op checkpoint from SOUL.md.
#
# Usage: bash scripts/pre-restart-cleanup.sh
#
# Actions:
#   1. Flush check   — verify git workspace is clean (or commit pending changes)
#   2. Plugin cleanup — remove openclaw-unknown-* stale dirs
#   3. Verify        — confirm only one versioned plugin dir remains
#   4. Confirm       — print safe-to-restart banner
#
# Exit codes: 0 = clean and safe | 1 = issues found (review before proceeding)
# =============================================================================

set -uo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
PLUGIN_DIR="$HOME/.openclaw/plugin-runtime-deps"
LOG_DIR="$HOME/Backups/ainchors/logs"
LOG_FILE="$LOG_DIR/pre-restart.log"

mkdir -p "$LOG_DIR"

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PRE-RESTART] $1" | tee -a "$LOG_FILE"; }

echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}${BOLD}║      AInchors Pre-Restart Cleanup        ║${RESET}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════╝${RESET}"
echo ""

RUN_TIME="$(date '+%Y-%m-%d %H:%M:%S %Z')"
log "=== Pre-Restart Cleanup Begin === $RUN_TIME"

ISSUES=0

# ── STEP 1: Git flush check ───────────────────────────────────────────────────
echo -e "${BOLD}[1/3] Git workspace flush check${RESET}"

cd "$WORKSPACE" 2>/dev/null || { echo -e "  ${RED}❌ Cannot cd to workspace: $WORKSPACE${RESET}"; log "ERROR: cannot cd to workspace"; exit 1; }

GIT_STATUS=$(git status --porcelain 2>/dev/null || echo "NOT_GIT")

if [[ "$GIT_STATUS" == "NOT_GIT" ]]; then
  echo -e "  ${YELLOW}⚠️  Workspace is not a git repo — skipping git check${RESET}"
  log "Git: WARN (not a git repo)"
elif [[ -z "$GIT_STATUS" ]]; then
  echo -e "  ${GREEN}✅ Git workspace is clean — nothing to commit${RESET}"
  log "Git: CLEAN"
else
  echo -e "  ${YELLOW}⚠️  Uncommitted changes detected:${RESET}"
  echo "$GIT_STATUS" | head -20 | sed 's/^/     /'
  echo ""
  echo -e "  ${YELLOW}Auto-committing pending changes before restart...${RESET}"
  git add -A 2>/dev/null
  COMMIT_MSG="[pre-restart] auto-commit pending changes before gateway restart — $(date '+%Y-%m-%d %H:%M:%S')"
  if git commit -m "$COMMIT_MSG" 2>/dev/null; then
    echo -e "  ${GREEN}✅ Changes committed: $COMMIT_MSG${RESET}"
    log "Git: AUTO-COMMITTED ($COMMIT_MSG)"
    # Push if origin is configured
    if git remote get-url origin > /dev/null 2>&1; then
      if git push 2>/dev/null; then
        echo -e "  ${GREEN}✅ Pushed to remote${RESET}"
        log "Git: PUSHED"
      else
        echo -e "  ${YELLOW}⚠️  Push failed (no remote access?) — changes committed locally${RESET}"
        log "Git: PUSH FAILED (local commit only)"
      fi
    fi
  else
    echo -e "  ${RED}❌ Git commit failed — please commit manually before restarting${RESET}"
    log "Git: COMMIT FAILED"
    ISSUES=$((ISSUES + 1))
  fi
fi

# ── STEP 2: Plugin cleanup ────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}[2/3] Plugin-runtime-deps cleanup${RESET}"

if [[ ! -d "$PLUGIN_DIR" ]]; then
  echo -e "  ${YELLOW}⚠️  Plugin dir not found: $PLUGIN_DIR — may be normal on fresh install${RESET}"
  log "Plugin cleanup: SKIP (dir not found)"
else
  UNKNOWN_DIRS=$(ls "$PLUGIN_DIR" 2>/dev/null | grep "^openclaw-unknown-" || true)

  if [[ -n "$UNKNOWN_DIRS" ]]; then
    echo -e "  Removing stale openclaw-unknown-* dirs..."
    echo "$UNKNOWN_DIRS" | while read -r dir; do
      echo -e "    ${YELLOW}Removing: $PLUGIN_DIR/$dir${RESET}"
      rm -rf "$PLUGIN_DIR/$dir"
      log "Removed: $PLUGIN_DIR/$dir"
    done
    echo -e "  ${GREEN}✅ Stale dirs removed${RESET}"
    log "Plugin cleanup: REMOVED unknown dirs"
  else
    echo -e "  ${GREEN}✅ No openclaw-unknown-* dirs found — already clean${RESET}"
    log "Plugin cleanup: ALREADY CLEAN"
  fi
fi

# ── STEP 3: Verify plugin dir count ──────────────────────────────────────────
echo ""
echo -e "${BOLD}[3/3] Verify plugin-runtime-deps${RESET}"

if [[ ! -d "$PLUGIN_DIR" ]]; then
  echo -e "  ${YELLOW}⚠️  Plugin dir not found — skipping verification${RESET}"
  log "Plugin verify: SKIP"
else
  REMAINING=$(ls "$PLUGIN_DIR" 2>/dev/null | grep -v "^openclaw-unknown-" || true)
  REMAINING_COUNT=$(echo "$REMAINING" | grep -c "." || echo 0)
  UNKNOWN_REMAINING=$(ls "$PLUGIN_DIR" 2>/dev/null | grep "^openclaw-unknown-" || true)

  if [[ -n "$UNKNOWN_REMAINING" ]]; then
    echo -e "  ${RED}❌ openclaw-unknown-* dirs STILL present after cleanup:${RESET}"
    echo "$UNKNOWN_REMAINING" | sed 's/^/     /'
    log "Plugin verify: FAIL (unknown dirs remain)"
    ISSUES=$((ISSUES + 1))
  elif [[ "$REMAINING_COUNT" -eq 1 ]]; then
    echo -e "  ${GREEN}✅ Exactly 1 versioned dir: $(echo $REMAINING | tr -d '\n')${RESET}"
    log "Plugin verify: PASS (1 versioned dir: $REMAINING)"
  elif [[ "$REMAINING_COUNT" -gt 1 ]]; then
    echo -e "  ${YELLOW}⚠️  $REMAINING_COUNT versioned dirs found (expected 1):${RESET}"
    echo "$REMAINING" | sed 's/^/     /'
    echo -e "  ${YELLOW}  Multiple versioned dirs may be intentional — review before proceeding.${RESET}"
    log "Plugin verify: WARN ($REMAINING_COUNT versioned dirs)"
  else
    echo -e "  ${YELLOW}⚠️  No versioned dirs found — may need reinstall after restart${RESET}"
    log "Plugin verify: WARN (0 versioned dirs)"
  fi
fi

# ── Final banner ──────────────────────────────────────────────────────────────
echo ""
if [[ $ISSUES -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════╗${RESET}"
  echo -e "${GREEN}${BOLD}║  ✅ Pre-restart cleanup complete.        ║${RESET}"
  echo -e "${GREEN}${BOLD}║     Safe to restart.                     ║${RESET}"
  echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════╝${RESET}"
  log "=== Pre-Restart Cleanup COMPLETE — Safe to restart ==="
  exit 0
else
  echo -e "${RED}${BOLD}╔══════════════════════════════════════════╗${RESET}"
  echo -e "${RED}${BOLD}║  ❌ Pre-restart cleanup found issues.    ║${RESET}"
  echo -e "${RED}${BOLD}║     Review before restarting.            ║${RESET}"
  echo -e "${RED}${BOLD}╚══════════════════════════════════════════╝${RESET}"
  echo -e "  ${RED}$ISSUES issue(s) detected — see above${RESET}"
  log "=== Pre-Restart Cleanup ISSUES ($ISSUES) — review required ==="
  exit 1
fi
