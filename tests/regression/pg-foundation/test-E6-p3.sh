#!/bin/bash
# Warden cron is active and reads model policy
set -e
/opt/homebrew/bin/openclaw cron get 83accf7b 2>/dev/null | /opt/homebrew/bin/jq -e '.enabled == true' >/dev/null 2>&1 && exit 0 || exit 2
