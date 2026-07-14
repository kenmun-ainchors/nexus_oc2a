#!/usr/bin/env bash
# lex-check.sh — Lex ⚖️ Legal Assurance Gate
# Usage: bash lex-check.sh --asset-path PATH --asset-type TYPE --brief "..." --intended-for "..." --produced-by AGENT
# Returns: 0 = PASS, 1 = FAIL, 2 = ERROR
# NOTE: L1-L4 require LLM review for nuanced legal judgement — automated checks catch obvious patterns only.
# TKT-0017 | Lex Rule 1

export PATH="$PATH:/usr/local/bin:/opt/homebrew/bin"

WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
QA_LOG="$WORKSPACE/state/lex-qa-log.json"
TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S+10:00")

ASSET_PATH=""; ASSET_TYPE=""; BRIEF=""; INTENDED_FOR=""; PRODUCED_BY="yoda"

while (( $# > 0 )); do
  case "$1" in
    --asset-path)   ASSET_PATH="$2"; shift 2 ;;
    --asset-type)   ASSET_TYPE="$2"; shift 2 ;;
    --brief)        BRIEF="$2"; shift 2 ;;
    --intended-for) INTENDED_FOR="$2"; shift 2 ;;
    --produced-by)  PRODUCED_BY="$2"; shift 2 ;;
    *) echo "Unknown: $1" >&2; exit 2 ;;
  esac
done

[ -z "$ASSET_PATH" ] && { echo "ERROR: --asset-path required" >&2; exit 2; }

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  LEX ⚖️  Legal Gate — $(date '+%Y-%m-%d %H:%M AEST')          ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "  Asset:        $(basename "$ASSET_PATH")"
echo "  Intended for: $INTENDED_FOR"
echo "  Produced by:  $PRODUCED_BY"
echo ""

PASS=0; FAIL=0; ISSUES=()
LLM_DEFERRED=()

[ ! -f "$ASSET_PATH" ] && { echo "ERROR — File not found: $ASSET_PATH" >&2; exit 2; }
CONTENT=$(cat "$ASSET_PATH" 2>/dev/null || echo "")

# ── L1: Contractual Language — automated pattern scan ──────────────────────
echo "[ L1 — Contractual Language ]"
L1_WARN=false

# Absolute guarantee language
if echo "$CONTENT" | grep -iqE "\bguaranteed?\b|\bwill definitely\b|\bwill always\b|\b100%\s+(guaranteed?|success|accurate)"; then
  L1_WARN=true
  echo "  WARN — Absolute guarantee language detected — may imply warranty"
  ISSUES+=("L1: Guarantee/absolute language found — verify not creating implied warranty")
fi
# Commitment language  
if echo "$CONTENT" | grep -iqE "\bwe will deliver\b|\bwe commit to\b|\bwe guarantee\b|\bwe promise\b"; then
  L1_WARN=true
  echo "  WARN — Commitment language detected — may imply contractual obligation"
  ISSUES+=("L1: Commitment language found — verify authorised by Ken/Angie")
fi
# Pricing without caveats
if echo "$CONTENT" | grep -iqE "A\$[0-9,]+.*per (month|year|project)" && ! echo "$CONTENT" | grep -iqE "estimate|subject to|may vary|indicative|excl\. GST"; then
  L1_WARN=true
  echo "  WARN — Pricing without caveats — add 'estimate' or 'subject to change'"
  ISSUES+=("L1: Pricing commitment without appropriate caveats")
fi

if [ "$L1_WARN" = false ]; then
  PASS=$((PASS+1)); echo "  PASS — No high-risk contractual language detected"
  LLM_DEFERRED+=("L1: Nuanced contract risk — LLM review pending")
else
  PASS=$((PASS+1))  # Provisional — flagged for LLM review
  echo "  PROVISIONAL PASS — Warnings flagged for LLM review"
  LLM_DEFERRED+=("L1: WARNINGS found — requires Lex LLM review before delivery")
fi

# ── L2: Regulatory Compliance — pattern scan ──────────────────────────────
echo ""
echo "[ L2 — Regulatory Compliance ]"
L2_FAIL=false

# Email without unsubscribe (commercial emails)
if [[ "$ASSET_TYPE" == "email" ]] || echo "$CONTENT" | grep -iqE "unsubscribe|marketing email|newsletter"; then
  if ! echo "$CONTENT" | grep -iqE "unsubscribe|opt.out|manage preferences"; then
    L2_FAIL=true; ISSUES+=("L2: Commercial email missing unsubscribe mechanism (Spam Act requirement)")
    echo "  FAIL — Commercial email without unsubscribe link (Spam Act)"
  else
    echo "  PASS — Unsubscribe mechanism present"
  fi
fi
# Financial advice disclaimer
if echo "$CONTENT" | grep -iqE "return on investment|ROI|financial (benefit|saving|gain|projection)|invest(ment|ing)"; then
  if ! echo "$CONTENT" | grep -iqE "not financial advice|general information only|estimate|projection|past performance"; then
    echo "  WARN — Financial language without disclaimer — add 'not financial advice' caveat"
    ISSUES+=("L2: Financial language without disclaimer — may trigger ASIC concerns")
  else
    echo "  OK — Financial language has appropriate caveats"
  fi
fi
# Misleading claims
if echo "$CONTENT" | grep -iqE "best in australia|#1|number one|leading|most (trusted|advanced|innovative)" && ! echo "$CONTENT" | grep -iqE "our|we believe|we aim"; then
  echo "  WARN — Superlative claim detected — verify substantiated or qualified"
  ISSUES+=("L2: Unsubstantiated superlative — may breach ACL Section 29")
fi

if [ "$L2_FAIL" = false ]; then
  PASS=$((PASS+1)); echo "  PROVISIONAL PASS — Pattern scan complete. LLM review pending for full compliance."
  LLM_DEFERRED+=("L2: Full regulatory compliance requires LLM review")
else
  FAIL=$((FAIL+1))
fi

# ── L3: Liability Exposure — pattern scan ─────────────────────────────────
echo ""
echo "[ L3 — Liability Exposure ]"

# Defamatory patterns
if echo "$CONTENT" | grep -iqE "incompetent|fraudulent|criminal|dishonest|corrupt" && echo "$CONTENT" | grep -iqE "[A-Z][a-z]+ (Pty|Ltd|Inc|Corp|LLC)"; then
  FAIL=$((FAIL+1)); ISSUES+=("L3: Potentially defamatory language about a named company")
  echo "  FAIL — Potentially defamatory language about named entity"
else
  PASS=$((PASS+1)); echo "  PROVISIONAL PASS — No obvious defamation patterns. LLM review pending."
  LLM_DEFERRED+=("L3: Liability exposure requires LLM review for nuanced claims")
fi

# ── L4: IP Rights — pattern scan ────────────────────────────────────────────
echo ""
echo "[ L4 — Intellectual Property ]"

# Unattributed quotes or content
if echo "$CONTENT" | grep -iqE '[""][^""]{50,}[""]' && ! echo "$CONTENT" | grep -iqE "source:|cited from|copyright|via |from "; then
  echo "  WARN — Long quoted text without attribution — verify IP clearance"
  ISSUES+=("L4: Quoted content without clear attribution — verify licensing")
else
  echo "  OK — No obvious unattributed IP detected"
fi
PASS=$((PASS+1))
LLM_DEFERRED+=("L4: IP rights require LLM review for full clearance")

# ── L5: Caveats & Disclosures ───────────────────────────────────────────────
echo ""
echo "[ L5 — Caveats & Disclosures ]"
L5_FAIL=false

# Financial projections need caveats
if echo "$CONTENT" | grep -iqE "project(ed|ion)|forecast|estimate(d)?"; then
  if ! echo "$CONTENT" | grep -iqE "estimate only|not a guarantee|may vary|subject to change|assumption"; then
    echo "  WARN — Projection language without 'estimate only' caveat"
    ISSUES+=("L5: Financial projection missing required caveat")
  else
    echo "  OK — Projection caveats present"
  fi
fi
# Confidentiality marking for confidential docs
if echo "$CONTENT" | grep -iqE "confidential|internal use only|proprietary"; then
  echo "  OK — Confidentiality marking present"
else
  # Check if it should have one based on content
  if echo "$CONTENT" | grep -iqE "budget|cost|salary|revenue|client (name|detail|data)"; then
    echo "  WARN — Sensitive business content without confidentiality marking"
    ISSUES+=("L5: Sensitive content may need Confidential marking")
  fi
fi
PASS=$((PASS+1))
echo "  PROVISIONAL PASS"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "╠══════════════════════════════════════════════════════╣"
TOTAL=$((PASS+FAIL))
if [ $FAIL -eq 0 ]; then
  VERDICT="PASS"
  echo "║  LEX OVERALL: PASS ($PASS/$TOTAL — provisional, LLM pending)  ║"
else
  VERDICT="FAIL"
  echo "║  LEX OVERALL: FAIL ($PASS/$TOTAL, $FAIL failed)                   ║"
fi

if [ ${#ISSUES[@]} -gt 0 ]; then
  echo "╠══════════════════════════════════════════════════════╣"
  echo "  Issues/Warnings:"
  for issue in "${ISSUES[@]}"; do echo "  • $issue"; done
fi
if [ ${#LLM_DEFERRED[@]} -gt 0 ]; then
  echo "  Deferred (LLM review):"
  for item in "${LLM_DEFERRED[@]}"; do echo "  ↳ $item"; done
fi
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "  NOTE: Lex provides risk flagging, not qualified legal advice."
echo "  For contracts >A\$10,000 or regulatory filings: seek qualified counsel."
echo ""

# Write to log
python3 -c "
import json, os
log = '$QA_LOG'
data = json.load(open(log)) if os.path.exists(log) else {'entries':[],'summary':{'total':0,'pass':0,'fail':0}}
data['entries'].append({'ts':'$TIMESTAMP','asset':'$ASSET_PATH','producedBy':'$PRODUCED_BY','intendedFor':'$INTENDED_FOR','verdict':'$VERDICT','pass':$PASS,'fail':$FAIL})
data['summary']['total']+=1
data['summary']['$VERDICT'.lower()]=data['summary'].get('$VERDICT'.lower(),0)+1
open(log,'w').write(json.dumps(data,indent=2))
" 2>/dev/null || true

[ $FAIL -eq 0 ] && exit 0 || exit 1
