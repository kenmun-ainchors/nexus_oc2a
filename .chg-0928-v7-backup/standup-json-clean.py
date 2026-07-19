#!/usr/bin/env python3
"""Validate and clean JSON output from standup composer LLM."""
import json, sys

text = sys.stdin.read().strip()

# Strip markdown fences if present
if text.startswith("```"):
    lines = text.split("\n")
    if lines[-1].strip() == "```":
        text = "\n".join(lines[1:-1])
    else:
        text = "\n".join(lines[1:])

try:
    d = json.loads(text)
    assert "businessStream" in d
    assert "frameworkMaturity" in d
    assert "progress" in d
    assert "rtb" in d
    assert "rose" in d["rtb"]
    assert "thorn" in d["rtb"]
    assert "bud" in d["rtb"]
    print(json.dumps(d))
except Exception:
    sys.exit(1)
