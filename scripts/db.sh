#!/bin/bash
# db.sh — Agent postgres access wrapper
# Usage: db.sh -c "SELECT count(*) FROM state_tickets"
#        db.sh -f /path/to/script.sql
export PGHOST=/tmp
export PGPORT=5432
export PGUSER=ainchorsangiefpl
export PGDATABASE=ainchors_nexus
export PGOPTIONS="--client-min-messages=warning"
/opt/homebrew/bin/psql -t -A "$@"
