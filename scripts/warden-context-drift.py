#!/usr/bin/env python3
"""
warden-context-drift.py — Warden 🔍 Model Context Drift Check
================================================================

CHG-0984 / TKT-1033 — Restores the [Model Context Drift] check in
scripts/model-drift-check.sh (originally introduced under CHG-0756, removed in
CHG-0803 when /tmp/warden-context-drift.py was deleted).

For each model listed in openclaw.json under models.providers.ollama.models,
this script:
  1. Reads the configured contextWindow / contextTokens / num_ctx values.
  2. Queries the local Ollama API at http://127.0.0.1:11434/api/tags and
     /api/show to fetch the runtime context length of the model if it exists
     locally.
  3. Emits one line per model in a pipe-delimited format expected by
     model-drift-check.sh:

         PASS|model_name|detail
         FAIL|model_name|detail
         SKIP|model_name|reason

Design rules (per TKT-1033):
  - Lightweight, non-blocking. Never raises an unhandled exception.
  - Unreachable Ollama API or missing local model => SKIP, not FAIL.
  - Drift is reported only when openclaw.json contextWindow disagrees with the
    reported local Ollama context length. Remote-only :cloud models and models
    the local Ollama cannot report on are SKIP.
  - Drift tolerance: a small grace percentage is allowed because Ollama can
    round training context to the nearest power of two. Default 5%.

Exit code: 0 (always — this is a non-fatal Warden check; model-drift-check.sh
already has SKIP as a pass-equivalent in its scoring loop).
"""
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from typing import Any, Dict, Iterable, List, Optional, Tuple

# ── Config ────────────────────────────────────────────────────────────────────

# Path to openclaw.json — overridable via OPENCLAW_CONFIG env for tests.
DEFAULT_OC_CONFIG = "/Users/ainchorsoc2a/.openclaw/openclaw.json"
OC_CONFIG = os.environ.get("OPENCLAW_CONFIG", DEFAULT_OC_CONFIG)

# Ollama local API — 127.0.0.1 (not localhost) so we don't accidentally hit
# some other resolver-virtualised service. Short timeouts: this is a non-
# blocking Warden check, not a critical path.
OLLAMA_BASE = os.environ.get("OLLAMA_BASE_URL", "http://127.0.0.1:11434")
API_TIMEOUT = float(os.environ.get("OLLAMA_TIMEOUT_SECS", "2"))

# Drift tolerance: Ollama may round context length to a power of two or to a
# model-family default. Allow up to 5% discrepancy before flagging FAIL.
DRIFT_TOLERANCE = float(os.environ.get("DRIFT_TOLERANCE_PCT", "5"))


# ── Helpers ──────────────────────────────────────────────────────────────────

def _read_json(path: str) -> Dict[str, Any]:
    try:
        with open(path, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except FileNotFoundError:
        return {}
    except (OSError, json.JSONDecodeError) as exc:
        # Corrupt or unreadable config: surface as a global SKIP for caller.
        raise SystemExit(f"SKIP|__config__|unreadable: {exc}")


def _http_json(url: str, payload: Optional[Dict[str, Any]] = None,
               timeout: float = API_TIMEOUT) -> Optional[Dict[str, Any]]:
    """Best-effort HTTP GET/POST. Returns None on any network/parse error."""
    data = None
    headers = {"Accept": "application/json"}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method="POST" if data else "GET")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError,
            OSError, json.JSONDecodeError, ValueError):
        return None


def _ollama_reachable() -> bool:
    """Quick liveness probe — /api/tags returns the installed model list."""
    body = _http_json(f"{OLLAMA_BASE}/api/tags")
    return isinstance(body, dict) and "models" in body


def _ollama_tags() -> List[Dict[str, Any]]:
    body = _http_json(f"{OLLAMA_BASE}/api/tags")
    if not isinstance(body, dict):
        return []
    return list(body.get("models", []) or [])


def _ollama_show(model_name: str) -> Optional[Dict[str, Any]]:
    return _http_json(f"{OLLAMA_BASE}/api/show", payload={"name": model_name})


def _ollama_context_length(info: Dict[str, Any]) -> Optional[int]:
    """
    Pull a context length out of /api/show response.

    Order of preference:
      1. <arch>.context_length under model_info (most reliable for gguf/MLX).
      2. details.context_length (legacy / embed models).
    """
    if not isinstance(info, dict):
        return None
    model_info = info.get("model_info") or {}
    for key, value in model_info.items():
        if key.endswith(".context_length") and isinstance(value, (int, float)):
            return int(value)
    details = info.get("details") or {}
    if isinstance(details, dict) and isinstance(details.get("context_length"), (int, float)):
        return int(details["context_length"])
    return None


def _configured_context(model: Dict[str, Any]) -> Tuple[Optional[int], str]:
    """
    Extract the configured context window for an openclaw.json model entry.

    Returns (value, source). source is one of "contextWindow", "contextTokens",
    "num_ctx", or "missing".
    """
    for field in ("contextWindow", "contextTokens"):
        val = model.get(field)
        if isinstance(val, (int, float)) and val > 0:
            return int(val), field
    params = model.get("params") or {}
    if isinstance(params, dict):
        val = params.get("num_ctx")
        if isinstance(val, (int, float)) and val > 0:
            return int(val), "num_ctx"
    return None, "missing"


def _strip_ollama_prefix(model_id: str) -> str:
    """openclaw.json entries are like 'gemma4:31b-cloud'; Ollama uses 'gemma4:31b'."""
    if isinstance(model_id, str) and model_id.startswith("ollama/"):
        return model_id[len("ollama/"):]
    return model_id


def _model_is_local(tags: List[Dict[str, Any]], model_id: str) -> bool:
    """A model is local if /api/tags returns it (any tag match)."""
    target = _strip_ollama_prefix(model_id)
    target_base = target.split(":", 1)[0]  # 'gemma4:31b-cloud' -> 'gemma4'
    for entry in tags:
        name = entry.get("name") or entry.get("model") or ""
        if not name:
            continue
        if name == target or name == target_base:
            return True
        # Fuzzy: tag may be 'gemma4:31b' for an openclaw entry 'gemma4:31b-cloud'.
        if name.split(":", 1)[0] == target_base and "-cloud" in target:
            return True
    return False


def _classify_drift(configured: int, actual: int) -> Tuple[bool, str]:
    """Return (is_drift, detail). Tolerance applied."""
    if configured <= 0 or actual <= 0:
        return False, f"configured={configured} actual={actual}"
    diff_pct = abs(actual - configured) / configured * 100.0
    if diff_pct <= DRIFT_TOLERANCE:
        return False, f"configured={configured} actual={actual} diff={diff_pct:.2f}%"
    return True, (f"configured={configured} actual={actual} "
                  f"diff={diff_pct:.2f}% (tolerance={DRIFT_TOLERANCE:.0f}%)")


def _iter_ollama_models(cfg: Dict[str, Any]) -> Iterable[Dict[str, Any]]:
    providers = cfg.get("models", {}).get("providers", {})
    ollama = providers.get("ollama", {}) if isinstance(providers, dict) else {}
    models = ollama.get("models", []) if isinstance(ollama, dict) else []
    for m in models:
        if isinstance(m, dict) and m.get("id"):
            yield m


def _emit(line: str) -> None:
    sys.stdout.write(line + "\n")
    sys.stdout.flush()


# ── Main ─────────────────────────────────────────────────────────────────────

def main() -> int:
    cfg = _read_json(OC_CONFIG)
    if not cfg:
        _emit(f"SKIP|__config__|openclaw.json missing or empty at {OC_CONFIG}")
        return 0

    # Probe Ollama once. If unreachable, every model becomes SKIP.
    if not _ollama_reachable():
        # Still emit one line per configured model so model-drift-check.sh
        # sees the full set — but each is SKIP with a consistent reason.
        for model in _iter_ollama_models(cfg):
            _emit(f"SKIP|{model.get('id')}|ollama API unreachable at {OLLAMA_BASE}")
        return 0

    tags = _ollama_tags()

    for model in _iter_ollama_models(cfg):
        model_id = model.get("id", "")
        configured, src = _configured_context(model)
        if configured is None:
            _emit(f"SKIP|{model_id}|no contextWindow/num_ctx in openclaw.json")
            continue

        # Remote / cloud models don't live on this Ollama instance — SKIP them
        # rather than fabricating a FAIL. The user explicitly asked: "If Ollama
        # API is unreachable or a model is not found, emit SKIP for that model."
        if not _model_is_local(tags, model_id):
            _emit(f"SKIP|{model_id}|not present in local Ollama (/api/tags)")
            continue

        info = _ollama_show(_strip_ollama_prefix(model_id))
        if info is None:
            _emit(f"SKIP|{model_id}|/api/show failed for {_strip_ollama_prefix(model_id)}")
            continue

        actual = _ollama_context_length(info)
        if actual is None:
            _emit(f"SKIP|{model_id}|Ollama /api/show did not report context_length")
            continue

        is_drift, detail = _classify_drift(configured, actual)
        if is_drift:
            _emit(f"FAIL|{model_id}|{detail} src={src}")
        else:
            _emit(f"PASS|{model_id}|{detail} src={src}")

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except SystemExit as exc:
        # Allow SystemExit-based global SKIP from _read_json.
        msg = str(exc)
        if msg.startswith("SKIP|"):
            sys.stdout.write(msg + "\n")
            sys.stdout.flush()
            sys.exit(0)
        raise
    except Exception as exc:  # pragma: no cover — defensive belt-and-braces
        # Last-resort: never let this script kill model-drift-check.sh.
        sys.stdout.write(f"SKIP|__error__|{type(exc).__name__}: {exc}\n")
        sys.stdout.flush()
        sys.exit(0)
