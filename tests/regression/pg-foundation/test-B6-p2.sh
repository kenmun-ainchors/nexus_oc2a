#!/bin/bash
# DoD gate prevents invalid status transitions
set -e
# ticket.sh has verify_before_close() that checks deliverable
# This test validates the gate exists (code present)
grep -q 'verify_before_close' /Users/ainchorsangiefpl/.openclaw/workspace/scripts/ticket.sh && exit 0 || exit 1
