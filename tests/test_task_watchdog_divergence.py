#!/usr/bin/env python3
"""
TKT-0409 AC3 test: task-watchdog.sh cross-check + exit 1 on divergence.

Strategy: stub a divergence by injecting a fake entry into state/task-queue.json
that is NOT in PG, then run the watchdog. Expected exit = 1.

The test preserves the original state/task-queue.json via backup-and-restore,
so it can be run repeatedly without polluting the real file.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile

WS = "/Users/ainchorsangiefpl/.openclaw/workspace"
JSON_PATH = os.path.join(WS, "state", "task-queue.json")
SCRIPT = os.path.join(WS, "scripts", "task-watchdog.sh")


def run_watchdog():
    """Run the watchdog and return (exit_code, stdout, stderr)."""
    proc = subprocess.run(
        ["bash", SCRIPT],
        capture_output=True, text=True, timeout=30, cwd=WS
    )
    return proc.returncode, proc.stdout, proc.stderr


def main():
    if not os.path.exists(JSON_PATH):
        print(f"FAIL: {JSON_PATH} does not exist — cannot test")
        sys.exit(1)
    if not os.path.exists(SCRIPT):
        print(f"FAIL: {SCRIPT} does not exist — cannot test")
        sys.exit(1)

    # Backup
    backup_path = JSON_PATH + ".test-backup"
    shutil.copy(JSON_PATH, backup_path)

    try:
        # ── Step 1: Run baseline to confirm script runs ──
        ec, out, err = run_watchdog()
        # We don't assert baseline exit code — it may be 0, 1, or 2 depending on real state.
        # We just confirm it runs without crashing.
        print(f"Baseline run: exit={ec}")

        # ── Step 2: Stub a divergence ──
        # Inject a fake task id that does NOT exist in PG, so cross-check
        # reports 'missing_in_pg' and exits 1.
        with open(JSON_PATH) as f:
            data = json.load(f)

        fake_id = "FAKE-TEST-DIVERGENCE-2026-06-12"
        # Make sure it's not already there
        data["queue"] = [e for e in data.get("queue", [])
                         if (e.get("atom_id") or e.get("id")) != fake_id]
        data["queue"].append({
            "atom_id": fake_id,
            "tkt": "TKT-FAKE",
            "seq": 99,
            "ac": "AC-FAKE",
            "title": "TKT-0409 AC3 divergence test stub",
            "type": "test",
            "status": "queued",
            "agent": "forge",
            "queued_at": "2026-06-12T12:00:00+10:00"
        })
        data["lastUpdated"] = "2026-06-12T12:00:00+10:00"

        with open(JSON_PATH, "w") as f:
            json.dump(data, f, indent=2)

        # ── Step 3: Run watchdog, expect exit 1 (divergence) ──
        ec, out, err = run_watchdog()
        print(f"Divergence run: exit={ec}")
        print("--- stdout ---")
        print(out)
        if err.strip():
            print("--- stderr ---")
            print(err)

        # ── Assertions ──
        assert ec == 1, f"FAIL: expected exit 1 on divergence, got {ec}"
        assert "DIVERGENCE" in out, f"FAIL: expected DIVERGENCE in output, got: {out[:200]}"
        assert fake_id in out, f"FAIL: expected fake id {fake_id} in divergence report, got: {out[:300]}"
        assert "EXIT 1" in out, f"FAIL: expected 'EXIT 1' message"

        # Divergence alert file should be written
        alert_file = os.path.join(WS, "state", "task-queue-divergence-alert.json")
        assert os.path.exists(alert_file), f"FAIL: divergence alert file {alert_file} not written"
        with open(alert_file) as f:
            alert = json.load(f)
        assert alert.get("alertType") == "json_pg_divergence", \
            f"FAIL: alert file has wrong alertType: {alert.get('alertType')}"

        print("\n✓ TKT-0409 AC3 PASS: stub divergence detected, exit 1 confirmed")
        print(f"  - Watchdog exited with code 1")
        print(f"  - Divergence alert file written: {alert_file}")
        print(f"  - Fake id {fake_id} correctly flagged as missing_in_pg")

    finally:
        # Always restore the original
        shutil.move(backup_path, JSON_PATH)
        print("Restored original state/task-queue.json")


if __name__ == "__main__":
    main()
