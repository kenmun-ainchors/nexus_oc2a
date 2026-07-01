#!/bin/bash
# serve.sh - Local dev server for ainchors.com replica
# Usage: ./serve.sh [port]
# Default port: 8080

PORT="${1:-8080}"
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== AINCHORS Local Dev Replica ==="
echo "Serving from: $DIR"
echo ""

# Check if port is available
if lsof -i :$PORT >/dev/null 2>&1; then
    echo "⚠️  Port $PORT is in use. Trying next available port..."
    for try_port in $(seq $((PORT + 1)) $((PORT + 20))); do
        if ! lsof -i :$try_port >/dev/null 2>&1; then
            PORT=$try_port
            break
        fi
    done
    echo "   Using port $PORT instead."
fi

echo "Starting server on http://localhost:$PORT"
echo "Press Ctrl+C to stop."
echo ""

# Use Python3's built-in HTTP server
cd "$DIR"
python3 -m http.server $PORT --bind 127.0.0.1
