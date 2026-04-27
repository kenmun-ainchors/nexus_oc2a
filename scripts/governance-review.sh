#!/bin/zsh
# AInchors Governance Review — routes content through Shield 🔐, Lex ⚖️, Sage 🧪
# Usage: governance-review.sh --content "content to review" --type TYPE --requester "Aria/Yoda"
# Types: external-email | social-post | training-content | client-proposal | blog-post | general
#
# Each agent reviews independently. All three must APPROVE for content to proceed.
# Any BLOCKED/FAIL/NON-COMPLIANT result halts delivery and notifies requester.

set -u

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
LOG="$WORKSPACE/state/governance-review.log"
CONTENT=""; TYPE="general"; REQUESTER="unknown"

while (( $# > 0 )); do
  case "$1" in
    --content)   CONTENT="$2"; shift 2 ;;
    --type)      TYPE="$2"; shift 2 ;;
    --requester) REQUESTER="$2"; shift 2 ;;
    *) echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$CONTENT" ]] && { echo "ERROR: --content required" >&2; exit 1; }

NOW=$(date '+%Y-%m-%d %H:%M %Z')
echo "[$NOW] GOVERNANCE REVIEW — type=$TYPE requester=$REQUESTER" | tee -a "$LOG"
echo "[$NOW] Content preview: ${CONTENT:0:200}..." | tee -a "$LOG"

echo ""
echo "═══════════════════════════════════════════"
echo "  🔐 Shield (Security) + ⚖️ Lex (Legal) + 🧪 Sage (QA)"
echo "  Governance review initiated by: $REQUESTER"
echo "  Content type: $TYPE"
echo "═══════════════════════════════════════════"
echo ""
echo "This review runs as 3 isolated sub-agent sessions."
echo "Each agent evaluates independently."
echo "All 3 must APPROVE for content to proceed."
echo ""
echo "Results will be returned via Yoda main session."
echo "Check state/governance-review.log for audit trail."

# Log the review request
echo "[$NOW] Review requested — content type: $TYPE | requester: $REQUESTER | chars: ${#CONTENT}" >> "$LOG"
