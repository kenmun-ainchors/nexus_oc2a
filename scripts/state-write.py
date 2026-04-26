#!/usr/bin/env python3
"""
AInchors Safe State Writer
Atomic writes with file locking for all shared state files.
Usage: python3 state-write.py <file_path> <json_string>
Or import: from state_write import safe_read, safe_write, safe_update
"""

import json
import os
import sys
import fcntl
import tempfile
import time

LOCK_TIMEOUT = 10  # seconds


def safe_write(path: str, data: dict, retries: int = 3) -> bool:
    """Atomically write JSON to path with file locking."""
    lock_path = path + ".lock"
    for attempt in range(retries):
        try:
            # Acquire lock
            lock_fd = open(lock_path, "w")
            deadline = time.time() + LOCK_TIMEOUT
            while True:
                try:
                    fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    break
                except IOError:
                    if time.time() > deadline:
                        raise TimeoutError(f"Could not acquire lock on {lock_path}")
                    time.sleep(0.1)

            # Write to temp file in same directory (same filesystem = atomic rename)
            dir_path = os.path.dirname(os.path.abspath(path))
            with tempfile.NamedTemporaryFile(
                mode="w", dir=dir_path, suffix=".tmp", delete=False
            ) as tmp:
                json.dump(data, tmp, indent=2)
                tmp_path = tmp.name

            # Atomic rename
            os.rename(tmp_path, path)

            # Release lock
            fcntl.flock(lock_fd, fcntl.LOCK_UN)
            lock_fd.close()
            return True

        except TimeoutError as e:
            print(f"[state-write] Lock timeout on attempt {attempt+1}: {e}", file=sys.stderr)
            if attempt == retries - 1:
                return False
            time.sleep(0.5)
        except Exception as e:
            print(f"[state-write] Write error on attempt {attempt+1}: {e}", file=sys.stderr)
            if attempt == retries - 1:
                return False
            time.sleep(0.2)
        finally:
            try:
                lock_fd.close()
            except:
                pass

    return False


def safe_read(path: str, default: dict = None) -> dict:
    """Read JSON with file locking to prevent reading mid-write."""
    if not os.path.exists(path):
        return default or {}

    lock_path = path + ".lock"
    try:
        lock_fd = open(lock_path, "w")
        deadline = time.time() + LOCK_TIMEOUT
        while True:
            try:
                fcntl.flock(lock_fd, fcntl.LOCK_SH | fcntl.LOCK_NB)
                break
            except IOError:
                if time.time() > deadline:
                    break  # Read anyway on timeout
                time.sleep(0.05)

        with open(path) as f:
            content = f.read().strip()
            if not content:
                return default or {}
            data = json.loads(content)

        fcntl.flock(lock_fd, fcntl.LOCK_UN)
        lock_fd.close()
        return data

    except Exception as e:
        print(f"[state-write] Read error: {e}", file=sys.stderr)
        return default or {}


def safe_update(path: str, updates: dict, default: dict = None) -> dict:
    """Read-modify-write atomically. Returns updated state."""
    lock_path = path + ".lock"
    try:
        lock_fd = open(lock_path, "w")
        deadline = time.time() + LOCK_TIMEOUT
        while True:
            try:
                fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except IOError:
                if time.time() > deadline:
                    raise TimeoutError(f"Could not acquire lock for update on {path}")
                time.sleep(0.1)

        # Read current state
        state = default or {}
        if os.path.exists(path):
            with open(path) as f:
                content = f.read().strip()
                if content:
                    state = json.loads(content)

        # Apply updates (deep for top-level keys)
        for k, v in updates.items():
            if isinstance(v, dict) and isinstance(state.get(k), dict):
                state[k].update(v)
            else:
                state[k] = v

        # Atomic write
        dir_path = os.path.dirname(os.path.abspath(path))
        os.makedirs(dir_path, exist_ok=True)
        with tempfile.NamedTemporaryFile(
            mode="w", dir=dir_path, suffix=".tmp", delete=False
        ) as tmp:
            json.dump(state, tmp, indent=2)
            tmp_path = tmp.name
        os.rename(tmp_path, path)

        fcntl.flock(lock_fd, fcntl.LOCK_UN)
        lock_fd.close()
        return state

    except Exception as e:
        print(f"[state-write] Update error: {e}", file=sys.stderr)
        return state if 'state' in dir() else (default or {})


# CLI usage
if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: state-write.py <path> <json>")
        sys.exit(1)
    path = sys.argv[1]
    data = json.loads(sys.argv[2])
    success = safe_write(path, data)
    sys.exit(0 if success else 1)
