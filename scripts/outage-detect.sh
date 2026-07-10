#!/bin/zsh
# AInchors Outage Detector — US23 (CHG-0858)
# Tests Ollama Cloud API health, activates standby mode on failure, clears on recovery.
# Anthropic checks removed per CHG-0855/CHG-0858 — Anthropic is parked.
# Fallback chain: deepseek-v4-flash:cloud → gemma4:31b-cloud → kimi-k2.7-code:cloud
#
# DISABLED: Per CHG-0858 / TKT-0973, option B approved by Ken (2026-07-10).
# The localhost:11434 probe was causing false standby when local Ollama daemon
# is not running (OC1 runs Ollama Cloud, not local Ollama). A proper Ollama Cloud
# outage probe design is pending. Returning OK to avoid false standby.

set -uo pipefail

exit 0