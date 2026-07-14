#!/usr/bin/env bash
# ollama-usage-scraper-run.sh — operational wrapper for TKT-0533.
# Starts the OpenClaw browser, runs the Ollama dashboard scraper, then stops the browser.
# Idempotent: if the browser is already running, `openclaw browser start` returns success.
# Never use tilde paths — only absolute paths.

set -euo pipefail

WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
SCRAPER="${WORKSPACE}/scripts/ollama-usage-scraper.py"
OPENCLAW="/Users/ainchorsoc2a/local/bin/openclaw"
LOG_PREFIX="[ollama-usage-scraper-run]"

log() {
    echo "${LOG_PREFIX} $*"
}

start_browser() {
    log "Starting OpenClaw browser..."
    "$OPENCLAW" browser start
}

wait_for_browser() {
    local i
    for i in {1..30}; do
        if "$OPENCLAW" browser status 2>/dev/null | grep -q 'running: true'; then
            log "Browser is running."
            return 0
        fi
        sleep 1
    done
    log "ERROR: Browser did not become ready within 30s"
    return 1
}

stop_browser() {
    log "Stopping OpenClaw browser..."
    "$OPENCLAW" browser stop || true
}

main() {
    cd "$WORKSPACE"

    start_browser
    if ! wait_for_browser; then
        stop_browser
        exit 2
    fi

    local scraper_rc=0
    log "Running scraper: $SCRAPER"
    python3 "$SCRAPER" || scraper_rc=$?

    stop_browser

    if [[ "$scraper_rc" -ne 0 ]]; then
        log "Scraper exited with code $scraper_rc"
        exit "$scraper_rc"
    fi

    log "Scraper completed successfully."
    exit 0
}

main "$@"
