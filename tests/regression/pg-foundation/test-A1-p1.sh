#!/bin/bash
# PG is running and accepting connections
set -e
/opt/homebrew/bin/pg_isready -h /tmp -q
