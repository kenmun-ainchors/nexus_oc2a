#!/bin/bash
# check-oc1-reachable.sh — TRIGGER-19 detection script
# CHG-0944: Probes OC1 reachability from OC2A via Tailscale. (Originally added under TRIGGER-18; corrected 2026-07-20 to TRIGGER-19 when TRIGGER-18 was restored to its original Spark: LinkedIn Stability Arc Post content.)
#
# Targets:
#   - 100.75.171.40 (Tailscale IP)
#   - ainchorss-mac-mini.tailfc3ed1.ts.net (MagicDNS hostname)
# Auth:
#   - SSH key: ~/.ssh/id_oc2a_oc1 (required, do NOT prompt for password)
#
# Behaviour:
#   1. Tailscale ping to 100.75.171.40 (1 packet, 2s timeout) must succeed.
#   2. SSH login to ainchorsangiefpl@100.75.171.40 with BatchMode=yes and
#      a 5s connect timeout must succeed and echo OC1_SSH_OK.
#   3. State file: state/oc1-reachability.json is written on every run.
#      Exit 0 on success, exit 1 on failure.
#   4. Silent on stdout unless --verbose. Always logs to
#      ~/.openclaw/logs/check-oc1-reachable.log.
#   5. Idempotent: re-running does not corrupt state. The state file is
#      written via a temp + atomic mv.
#
# Usage:
#   bash scripts/check-oc1-reachable.sh
#   bash scripts/check-oc1-reachable.sh --verbose
#
# Exit codes:
#   0 = OC1 reachable (ping AND ssh both pass)
#   1 = OC1 unreachable (ping failed OR ssh failed OR key missing)

set -uo pipefail

# ── Configuration ───────────────────────────────────────────────────────────
WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
STATE_DIR="$WORKSPACE/state"
STATE_FILE="$STATE_DIR/oc1-reachability.json"
LOG_DIR="$HOME/.openclaw/logs"
LOG_FILE="$LOG_DIR/check-oc1-reachable.log"
SSH_KEY="$HOME/.ssh/id_oc2a_oc1"
OC1_IP="100.75.171.40"
OC1_HOST="ainchorss-mac-mini.tailfc3ed1.ts.net"
OC1_USER="ainchorsangiefpl"

VERBOSE=0
for arg in "$@"; do
  case "$arg" in
    --verbose|-v) VERBOSE=1 ;;
    --help|-h)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) ;;
  esac
done

mkdir -p "$STATE_DIR" "$LOG_DIR"

# ── Logging helpers ─────────────────────────────────────────────────────────
ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log_line() { echo "[$(ts)] $*" >> "$LOG_FILE"; }
vlog() { [[ "$VERBOSE" -eq 1 ]] && echo "$@"; log_line "$@"; }

# ── State writer (atomic) ───────────────────────────────────────────────────
write_state() {
  local json_content="$1"
  local tmp="${STATE_FILE}.tmp.$$"
  printf '%s\n' "$json_content" > "$tmp"
  mv -f "$tmp" "$STATE_FILE"
}

now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# ── Pre-flight: SSH key must exist ─────────────────────────────────────────
if [[ ! -f "$SSH_KEY" ]]; then
  log_line "FAIL: SSH key missing at $SSH_KEY"
  write_state "{\"reachable\": false, \"checkedAt\": \"$(now_iso)\", \"error\": \"ssh_key_missing\"}"
  exit 1
fi

# ── Probe 1: Tailscale ping ─────────────────────────────────────────────────
vlog "ping: ${OC1_IP} (1 packet, 2s timeout)"
if ! ping -c 1 -W 2 "$OC1_IP" >/dev/null 2>&1; then
  log_line "FAIL: ping to ${OC1_IP} failed (no reply within 2s)"
  write_state "{\"reachable\": false, \"checkedAt\": \"$(now_iso)\", \"via\": \"${OC1_IP}\", \"error\": \"ping_failed\"}"
  exit 1
fi
vlog "ping OK"

# ── Probe 2: SSH login (BatchMode = fail if password prompt) ────────────────
vlog "ssh: ${OC1_USER}@${OC1_IP} (key=$SSH_KEY, connect_timeout=5, BatchMode=yes)"
SSH_OUTPUT=$(
  ssh -o ConnectTimeout=5 \
      -o BatchMode=yes \
      -o StrictHostKeyChecking=accept-new \
      -o IdentitiesOnly=yes \
      -i "$SSH_KEY" \
      "${OC1_USER}@${OC1_IP}" \
      "echo OC1_SSH_OK" 2>/dev/null
) || SSH_EXIT=$?
SSH_EXIT=${SSH_EXIT:-0}

if [[ "$SSH_OUTPUT" != "OC1_SSH_OK" ]] || [[ "$SSH_EXIT" -ne 0 ]]; then
  log_line "FAIL: ssh to ${OC1_USER}@${OC1_IP} did not return OC1_SSH_OK (exit=${SSH_EXIT:-?})"
  write_state "{\"reachable\": false, \"checkedAt\": \"$(now_iso)\", \"via\": \"${OC1_IP}\", \"error\": \"ssh_failed\"}"
  exit 1
fi
vlog "ssh OK"

# ── Both probes passed — OC1 is reachable ───────────────────────────────────
log_line "PASS: OC1 reachable (ping+ssh via ${OC1_IP})"
write_state "{\"reachable\": true, \"checkedAt\": \"$(now_iso)\", \"via\": \"${OC1_IP}\", \"ssh\": true, \"host\": \"${OC1_HOST}\"}"
exit 0
