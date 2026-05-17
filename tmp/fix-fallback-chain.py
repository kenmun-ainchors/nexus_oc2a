import re

with open('/Users/ainchorsangiefpl/.openclaw/workspace/scripts/validate-fallback-chain.sh', 'r') as f:
    lines = f.readlines()

# Find LINK 5 start and the "Write state" section
link5_idx = None
write_idx = None
for i, line in enumerate(lines):
    if '# ── LINK 5: openclaw.json fallback chain' in line:
        link5_idx = i
    if '# ── Write state/fallback-chain-status.json' in line:
        write_idx = i
        break

if link5_idx is not None and write_idx is not None:
    # Build interim check block
    interim_block = [
        '\n',
        '# ── INTERIM PERIOD CHECK (CHG-0362/0364) ────────────────────────────────────\n',
        '# During Conservative Mode interim period, fallback chain intentionally uses\n',
        '# interim models (kimi/gemma4/deepseek). Skip LINK 5 validation if active.\n',
        'INTERIM_ACTIVE=false\n',
        'INTERIM_REASON=""\n',
        'if [[ -f "$WORKSPACE/state/interim-model-period.json" ]]; then\n',
        '  INTERIM_ACTIVE=$(python3 -c "import json; d=json.load(open(\'$WORKSPACE/state/interim-model-period.json\')); print(\'true\' if d.get(\'active\') else \'false\')" 2>/dev/null || echo "false")\n',
        '  INTERIM_REASON=$(python3 -c "import json; d=json.load(open(\'$WORKSPACE/state/interim-model-period.json\')); print(d.get(\'reason\',\'\'))" 2>/dev/null || echo "")\n',
        'fi\n',
        '\n',
        'if [[ "$INTERIM_ACTIVE" == "true" ]]; then\n',
        '  log "INTERIM PERIOD ACTIVE ($INTERIM_REASON) — skipping fallback chain config validation"\n',
        '  log "LINK 5 (fallback chain config): SKIPPED — interim period, using temporary models"\n',
        '  RESULTS+=("fallbackChainConfig:interim-skipped")\n',
        '  # Skip to end — no chain validation during interim\n',
        'else\n',
        '\n',
    ]
    
    # Insert interim block before LINK 5
    new_lines = lines[:link5_idx] + interim_block + lines[link5_idx:write_idx] + [
        'fi\n',
        '\n',
    ] + lines[write_idx:]
    
    with open('/Users/ainchorsangiefpl/.openclaw/workspace/scripts/validate-fallback-chain.sh', 'w') as f:
        f.writelines(new_lines)
    print('Updated validate-fallback-chain.sh with interim period check')
else:
    print(f'Could not find sections: link5={link5_idx}, write={write_idx}')
