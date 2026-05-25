#!/bin/bash
# G3: PG down → platform state files still readable (heartbeat continues)
if /opt/homebrew/bin/pg_isready -h /tmp -q 2>/dev/null; then
  echo "PG is still running — stop PG first"
  exit 2
fi
FILES_FAIL=0
for f in /Users/ainchorsangiefpl/.openclaw/workspace/state/cost-state.json /Users/ainchorsangiefpl/.openclaw/workspace/state/health-state.json /Users/ainchorsangiefpl/.openclaw/workspace/state/tickets.json; do
  [ -f "$f" ] && [ -s "$f" ] || { echo "  MISSING: $f"; FILES_FAIL=$((FILES_FAIL+1)); }
done
[ $FILES_FAIL -eq 0 ] && exit 0 || exit 1
