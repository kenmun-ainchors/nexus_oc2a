#!/bin/bash
# db-write.sh falls back to file when PG is down
# WARNING: Requires PG to be stopped. Set EXIT 2 (skip) by default.
echo "REQUIRES PG RESTART — run during maintenance window"
exit 2
