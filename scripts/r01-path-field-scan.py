#!/usr/bin/env python3
"""
CHG-0928 v6 — Path-field-only scanner for R01 audit.

Walks session .jsonl files and counts lines (per file) that contain the
literal string "~/.openclaw" in the value of any path-like key, scanning
recursively (including inside nested objects/arrays). Other text
(message content, tool text, etc.) is ignored so legitimate mentions of
the path in conversation do not flag.

Keys scanned (recursive):
  cwd, workspaceDir, sessionFile, filePath,
  spawnedCwd, spawnedWorkspaceDir, agentDir, workspace, parentSession

Two modes:
  Single file:   script.py <path-to-file>
                 -> prints single integer (offending lines in that file)
  Batch mode:    script.py --batch <path1> <path2> ...
                 -> prints "<count>\\t<path>" per file, exits 0
                 script.py --batch <directory>
                 -> recursively scans <directory> for *.jsonl files
"""

import json
import os
import sys

PATH_KEYS = {
    "cwd",
    "workspaceDir",
    "sessionFile",
    "filePath",
    "spawnedCwd",
    "spawnedWorkspaceDir",
    "agentDir",
    "workspace",
    "parentSession",
}

NEEDLE = "~/.openclaw"


def _values_for_keys(obj, found):
    """Recursively walk obj collecting string values whose key is in PATH_KEYS."""
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k in PATH_KEYS:
                if isinstance(v, str) and NEEDLE in v:
                    found.append(v)
            else:
                _values_for_keys(v, found)
    elif isinstance(obj, list):
        for item in obj:
            _values_for_keys(item, found)
    # scalars: nothing to do


def scan_file(path):
    """Return the number of JSONL lines in `path` that have a tilde-path
    in any path-like field value."""
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            lines = fh.readlines()
    except OSError:
        return 0

    count = 0
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except ValueError:
            continue
        found = []
        _values_for_keys(obj, found)
        if found:
            count += 1
    return count


def main():
    args = sys.argv[1:]
    if not args:
        print("0")
        return 0

    if args[0] == "--batch":
        targets = args[1:]
        for tgt in targets:
            if os.path.isdir(tgt):
                for root, _dirs, files in os.walk(tgt):
                    for name in files:
                        if name.endswith(".jsonl"):
                            fpath = os.path.join(root, name)
                            try:
                                n = scan_file(fpath)
                            except Exception:
                                n = 0
                            if n > 0:
                                sys.stdout.write(f"{n}\t{fpath}\n")
            elif os.path.isfile(tgt):
                try:
                    n = scan_file(tgt)
                except Exception:
                    n = 0
                if n > 0:
                    sys.stdout.write(f"{n}\t{tgt}\n")
        return 0

    # Single-file mode (legacy)
    path = args[0]
    print(scan_file(path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
