: | /bin/zsh -c '
# Check current CREST skill path
echo "=== CREST skill location ==="
find infra/sandbox/seed/skills/crest -type f 2>/dev/null || true
find agent-skills/crest -type f 2>/dev/null || true
'