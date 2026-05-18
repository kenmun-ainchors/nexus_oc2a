#!/usr/bin/env bash
# version-check.sh — Check OpenClaw upstream version for TRIGGER-04
# Created 2026-05-18 (CHG-0400) — script was missing, cron 6bd53c89 was failing silently

set -euo pipefail

CURRENT_VERSION=$(openclaw --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")

# Check latest version via npm registry
LATEST_VERSION=$(npm view openclaw version 2>/dev/null || echo "unknown")

echo "OpenClaw version: current=${CURRENT_VERSION}, latest=${LATEST_VERSION}"

if [[ "$CURRENT_VERSION" != "$LATEST_VERSION" ]] && [[ "$LATEST_VERSION" != "unknown" ]]; then
    echo "DRIFT: version mismatch (current=${CURRENT_VERSION}, available=${LATEST_VERSION})"
    exit 1
else
    echo "OK: up to date (${CURRENT_VERSION})"
    exit 0
fi
