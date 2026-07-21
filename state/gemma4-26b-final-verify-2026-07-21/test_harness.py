#!/usr/bin/env python3
"""
TKT-1023 / CHG-0962 final verification harness for gemma4:26b on OC2A.

Runs an expanded test matrix with top-level think:false in every /api/generate
request and records per-test metrics into a single JSON report.
"""
from __future__ import annotations
import json
import os
import subprocess
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime, timezone
from pathlib import Path

API = "http://127.0.0.1:11434"
MODEL = "gemma4:26b"
OUT_DIR = Path("state/gemma4-26b-final-verify-2026-07-21")
OUT_DIR.mkdir(parents=True, exist_ok=True)
RAW_LOG = OUT_DIR / "raw_runs.jsonl"
FINAL_REPORT = Path("state/gemma4-26b-final-verification-2026-07-21.json")


def utcnow() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def vmstat() -> dict:
    """Snapshot of system memory state (best-effort)."""
    info = {"ts_utc": utcnow()}
    try:
        r = subprocess.run(["vm_stat"], capture_output=True, text=True, timeout=5)
        for line in r.stdout.splitlines():
            line = line.strip()
            if ":" in line:
                k, v = line.split(":", 1)
                try:
                    info[k] = int(v.strip().rstrip(".").replace(",", ""))
                except ValueError:
                    info[k] = v.strip()
    except Exception as e:
        info["vm_stat_error"] = str(e)
    try:
        r = subprocess.run(["sysctl", "hw.memsize"], capture_output=True, text=True, timeout=5)
        info["hw_memsize_bytes"] = int(r.stdout.split(":")[1].strip())
    except Exception as e:
        info["hw_memsize_error"] = str(e)
    try:
        r = subprocess.run(["ps", "-o", "rss=", "-p", "913"], capture_output=True, text=True, timeout=5)
        info["ollama_pid_913_rss_kb"] = int(r.stdout.strip() or 0)
    except Exception:
        pass
    return info


def ollama_ps() -> list:
    try:
        r = subprocess.run(["ollama", "ps"], capture_output=True, text=True, timeout=10)
        out = []
        lines = r.stdout.strip().splitlines()
        if len(lines) <= 1:
            return out
        # header: NAME ID SIZE PROCESSOR UNTIL
        for line in lines[1:]:
            parts = line.split(maxsplit=4)
            if not parts:
                continue
            out.append({"name": parts[0], "id": parts[1] if len(parts) > 1 else "", "size": parts[2] if len(parts) > 2 else ""})
        return out
    except Exception as e:
        return [{"error": str(e)}]


def post_json(path: str, payload: dict, timeout: int = 1800) -> tuple[int, dict, float]:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        API + path,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read().decode("utf-8", errors="replace")
            try:
                return resp.status, json.loads(body), time.time() - t0
            except json.JSONDecodeError:
                return resp.status, {"_raw_body": body}, time.time() - t0
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        try:
            return e.code, json.loads(body), time.time() - t0
        except json.JSONDecodeError:
            return e.code, {"_raw_body": body, "_error": str(e)}, time.time() - t0
    except Exception as e:
        return 0, {"_exception": repr(e)}, time.time() - t0


def ollama_unload(model: str) -> None:
    """Force unload by stopping the running model — uses the API."""
    try:
        req = urllib.request.Request(
            API + "/api/generate",
            data=json.dumps({"model": model, "keep_alive": 0}).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        urllib.request.urlopen(req, timeout=30).read()
    except Exception:
        pass


def run_test(test_id: str, prompt: str, *, num_ctx: int | None = None,
             num_predict: int = 200, temperature: float = 0.7,
             seed: int | None = None, stream: bool = False,
             note: str = "") -> dict:
    payload: dict = {
        "model": MODEL,
        "prompt": prompt,
        "stream": stream,
        "think": False,
        "num_predict": num_predict,
        "temperature": temperature,
        "options": {
            "num_predict": num_predict,
            "temperature": temperature,
        },
    }
    if num_ctx is not None:
        payload["options"]["num_ctx"] = num_ctx
    if seed is not None:
        payload["options"]["seed"] = seed

    before_vm = vmstat()
    before_ps = ollama_ps()

    t0 = time.time()
    code, body, total_time = post_json("/api/generate", payload)
    wall = time.time() - t0

    after_vm = vmstat()
    after_ps = ollama_ps()

    response_text = body.get("response", "") if isinstance(body, dict) else ""
    eval_count = body.get("eval_count") if isinstance(body, dict) else None
    prompt_eval_count = body.get("prompt_eval_count") if isinstance(body, dict) else None
    total_duration_ns = body.get("total_duration") if isinstance(body, dict) else None
    load_duration_ns = body.get("load_duration") if isinstance(body, dict) else None
    prompt_eval_duration_ns = body.get("prompt_eval_duration") if isinstance(body, dict) else None
    eval_duration_ns = body.get("eval_duration") if isinstance(body, dict) else None
    done_reason = body.get("done_reason") if isinstance(body, dict) else None

    tps_eval = None
    tps_prompt_eval = None
    if isinstance(eval_duration_ns, (int, float)) and eval_duration_ns > 0 and eval_count:
        tps_eval = round(eval_count / (eval_duration_ns / 1e9), 3)
    if isinstance(prompt_eval_duration_ns, (int, float)) and prompt_eval_duration_ns > 0 and prompt_eval_count:
        tps_prompt_eval = round(prompt_eval_count / (prompt_eval_duration_ns / 1e9), 3)

    record = {
        "test_id": test_id,
        "ts_utc": utcnow(),
        "note": note,
        "request": {
            "num_ctx": num_ctx,
            "num_predict": num_predict,
            "temperature": temperature,
            "seed": seed,
            "stream": stream,
            "think": False,
            "prompt_chars": len(prompt),
            "prompt_first_80": prompt[:80],
        },
        "http_code": code,
        "wall_seconds": round(wall, 3),
        "response_nonempty": bool(response_text and response_text.strip()),
        "response_text_preview": response_text[:200] if response_text else "",
        "response_text_length": len(response_text) if response_text else 0,
        "eval_count": eval_count,
        "prompt_eval_count": prompt_eval_count,
        "tokens_per_sec_eval": tps_eval,
        "tokens_per_sec_prompt_eval": tps_prompt_eval,
        "total_duration_ms": round(total_duration_ns / 1e6, 1) if isinstance(total_duration_ns, (int, float)) else None,
        "load_duration_ms": round(load_duration_ns / 1e6, 1) if isinstance(load_duration_ns, (int, float)) else None,
        "prompt_eval_duration_ms": round(prompt_eval_duration_ns / 1e6, 1) if isinstance(prompt_eval_duration_ns, (int, float)) else None,
        "eval_duration_ms": round(eval_duration_ns / 1e6, 1) if isinstance(eval_duration_ns, (int, float)) else None,
        "done_reason": done_reason,
        "error": body.get("_exception") or body.get("_error") if isinstance(body, dict) and (body.get("_exception") or body.get("_error")) else None,
        "ollama_ps_before": before_ps,
        "ollama_ps_after": after_ps,
        "ollama_pid_913_rss_kb_after": after_vm.get("ollama_pid_913_rss_kb"),
        "pages_free_after": after_vm.get("Pages free"),
    }
    with RAW_LOG.open("a") as f:
        f.write(json.dumps(record) + "\n")
    print(f"[{test_id}] http={code} nonempty={record['response_nonempty']} eval={eval_count} tps={tps_eval} wall={wall:.2f}s load={record['load_duration_ms']}ms done={done_reason}", flush=True)
    return record


# ── Prompt templates ──────────────────────────────────────────────────────────

PROMPT_SHORT_FACTUAL = "What is the capital of Japan? Answer in one sentence."

PROMPT_MEDIUM_REASONING = (
    "Explain in 3-4 sentences why the CAP theorem applies to distributed key-value "
    "stores like etcd or Consul, and what trade-offs a system operator accepts when "
    "tuning consistency vs availability in a leader-based consensus protocol."
)

PROMPT_LONG_CONTEXT_BASE = (
    "The following is a reference document about distributed systems consistency models. "
    "Use it to answer the question at the end.\n\n---\n\n"
)

PROMPT_QUESTION = "\n\n---\n\nQuestion: According to the document above, what are the three possible consistency guarantees in eventual consistency systems, and how does read-your-writes differ from monotonic reads? Answer in 2-3 sentences."

PROMPT_COMPLEX_MULTI_STEP = (
    "You are a senior site reliability engineer. A production gRPC service on Kubernetes "
    "is showing 30% of requests failing with deadline_exceeded after the upstream changed "
    "to a slower database. Give a structured runbook in 8-10 bullet points covering: "
    "immediate mitigations, observability checks, capacity calculation, rollback decision "
    "criteria, and a follow-up monitoring checklist. Each bullet must be one short sentence."
)

PROMPT_CODE_GEN = (
    "Write a Python function `def parse_iso_duration(s: str) -> int: ` that parses an ISO-8601 "
    "duration string like 'PT1H30M' or 'PT45S' or 'P2DT3H' into total seconds. Include input "
    "validation and 3 inline doctests covering the three example forms. No extra prose."
)


def make_long_context(target_tokens_approx: int) -> str:
    """Build a long-context prompt by repeating a paragraph to roughly hit the target token count."""
    # ~1 word per ~1.3 tokens on english; we want target_tokens_approx words ≈ 0.77x
    target_words = int(target_tokens_approx * 0.77)
    paragraph = (
        "Consistency models in distributed systems describe the contract between the system "
        "and its clients regarding the visibility and ordering of updates. Eventual "
        "consistency guarantees that, in the absence of new writes, all replicas will "
        "converge to the same value after some bounded time. Causal consistency preserves "
        "the order of potentially related operations, while read-your-writes guarantees "
        "that a client will always see its own most recent write in subsequent reads from "
        "the same session. Monotonic reads prevent the client from observing a value that "
        "is older than one it has already seen, which simplifies client-side reasoning "
        "about state. Strong consistency, by contrast, requires that every read observe "
        "the most recent committed write as if the system were a single non-replicated "
        "node, typically at the cost of latency or availability under network partitions. "
    )
    # ~93 words per paragraph
    words_per_p = 93
    n_paras = max(1, target_words // words_per_p + 1)
    body = (paragraph + " ") * n_paras
    body = body[: target_words * 6]  # generous char cap, will trim words
    words = body.split()
    words = words[:target_words]
    text = " ".join(words)
    return PROMPT_LONG_CONTEXT_BASE + text + PROMPT_QUESTION


# ── Test plan ────────────────────────────────────────────────────────────────

def main() -> int:
    print(f"== TKT-1023 / CHG-0962 final verification of {MODEL} on OC2A ==", flush=True)
    print(f"Start: {utcnow()}", flush=True)

    results: list[dict] = []
    plan: list[dict] = []

    # ---- Phase 0: Persistence & load (cold + warm) ----
    print("\n--- Phase 0: persistence + cold load ---", flush=True)
    ollama_unload(MODEL)
    time.sleep(2)

    plan.append({"phase": "0_persistence", "test_id": "p0_warmup_first_request",
                 "purpose": "cold load (no model loaded prior)"})
    r = run_test("p0_warmup_first_request", "Say 'ready' in one word.",
                 num_predict=8, temperature=0.0, note="cold load (first call)")
    results.append(r)

    # warm load test (already in memory)
    plan.append({"phase": "0_persistence", "test_id": "p0_warm_load_short",
                 "purpose": "warm load (model already resident)"})
    r = run_test("p0_warm_load_short", "Repeat: hello world",
                 num_predict=10, temperature=0.0, note="warm load")
    results.append(r)

    # ---- Phase 1: prompt type matrix at default ctx 262144, num_predict=80, temp=0.7 ----
    print("\n--- Phase 1: prompt type matrix ---", flush=True)

    plan.append({"phase": "1_prompt_types", "test_id": "p1_short_factual"})
    r = run_test("p1_short_factual", PROMPT_SHORT_FACTUAL,
                 num_predict=80, temperature=0.7, note="short factual")
    results.append(r)

    plan.append({"phase": "1_prompt_types", "test_id": "p1_medium_reasoning"})
    r = run_test("p1_medium_reasoning", PROMPT_MEDIUM_REASONING,
                 num_predict=200, temperature=0.7, note="medium reasoning/explanation")
    results.append(r)

    plan.append({"phase": "1_prompt_types", "test_id": "p1_complex_multistep"})
    r = run_test("p1_complex_multistep", PROMPT_COMPLEX_MULTI_STEP,
                 num_predict=500, temperature=0.7, note="complex multi-step instruction")
    results.append(r)

    plan.append({"phase": "1_prompt_types", "test_id": "p1_code_gen"})
    r = run_test("p1_code_gen", PROMPT_CODE_GEN,
                 num_predict=400, temperature=0.2, note="code generation (low temp)")
    results.append(r)

    # ---- Phase 2: long context at default ctx 262144 ----
    print("\n--- Phase 2: long context scaling (target ~1k/2k/4k/8k/16k prompt tokens) ---", flush=True)
    for tgt in (1000, 2000, 4000, 8000, 16000):
        long_prompt = make_long_context(tgt)
        plan.append({"phase": "2_long_context", "test_id": f"p2_longctx_{tgt}",
                     "target_input_tokens_approx": tgt, "prompt_chars": len(long_prompt)})
        r = run_test(f"p2_longctx_{tgt}", long_prompt,
                     num_predict=200, temperature=0.5, note=f"~{tgt} input tokens")
        results.append(r)

    # ---- Phase 3: explicit num_ctx values ----
    print("\n--- Phase 3: explicit num_ctx (4096 / 8192 / 16384 / 32768) ---", flush=True)
    # Use a short-to-medium prompt to keep OOM risk on context alone.
    fixed_prompt = PROMPT_MEDIUM_REASONING
    for nctx in (4096, 8192, 16384, 32768):
        plan.append({"phase": "3_num_ctx", "test_id": f"p3_numctx_{nctx}", "num_ctx": nctx})
        r = run_test(f"p3_numctx_{nctx}", fixed_prompt,
                     num_ctx=nctx, num_predict=120, temperature=0.5,
                     note=f"explicit num_ctx={nctx}")
        results.append(r)
        # If OOM/abort, no point continuing to higher ctx
        if r.get("http_code") in (0,) or (r.get("error") and "out of memory" in str(r.get("error")).lower()):
            print(f"  ! aborting remaining num_ctx tests due to {r.get('error')}", flush=True)
            break

    # ---- Phase 4: parameter variations on a fixed short prompt ----
    print("\n--- Phase 4: temperature + num_predict variations ---", flush=True)
    for temp in (0.0, 0.7):
        for npr in (20, 80, 200, 500):
            plan.append({"phase": "4_param_variations", "test_id": f"p4_t{temp}_np{npr}",
                         "temperature": temp, "num_predict": npr})
            r = run_test(f"p4_t{temp}_np{npr}", PROMPT_MEDIUM_REASONING,
                         num_predict=npr, temperature=temp,
                         note=f"temp={temp}, num_predict={npr}")
            results.append(r)

    # ---- Phase 5: concurrent 2 requests with think:false ----
    print("\n--- Phase 5: concurrent 2 overlapping requests ---", flush=True)
    import threading
    out_a: dict = {}
    out_b: dict = {}

    def worker(label, prompt, out):
        out[label] = run_test(f"p5_concurrent_{label}", prompt,
                              num_predict=120, temperature=0.7,
                              note=f"concurrent slot {label}")

    t_a = threading.Thread(target=worker, args=("A", "List 3 cloud object storage providers and their key difference.", out_a))
    t_b = threading.Thread(target=worker, args=("B", "Explain in 2 sentences what a circuit breaker pattern does in microservice architectures.", out_b))
    t0 = time.time()
    t_a.start()
    time.sleep(0.2)  # small stagger so they overlap, not race
    t_b.start()
    t_a.join(timeout=600)
    t_b.join(timeout=600)
    wall_concurrent = time.time() - t0
    print(f"  concurrent wall: {wall_concurrent:.2f}s", flush=True)
    plan.append({"phase": "5_concurrent", "test_id": "p5_concurrent_A_and_B",
                 "wall_seconds": round(wall_concurrent, 3)})
    results.append({"phase": "5_concurrent", "wall_seconds": round(wall_concurrent, 3),
                    "slot_a": out_a.get("A"), "slot_b": out_b.get("B")})

    # ---- Phase 6: regression — exact TKT-1014-style short prompt (no think:false was TKT-1014's bug) ----
    print("\n--- Phase 6: regression vs TKT-1014 (short factual at temp=0) ---", flush=True)
    plan.append({"phase": "6_regression", "test_id": "p6_reg_short_temp0"})
    r = run_test("p6_reg_short_temp0", "What is the capital of France?",
                 num_predict=20, temperature=0.0,
                 note="TKT-1014-style short factual (regression check)")
    results.append(r)

    # also retry with num_predict=80 to be sure
    plan.append({"phase": "6_regression", "test_id": "p6_reg_short_temp0_np80"})
    r = run_test("p6_reg_short_temp0_np80", "What is the capital of France?",
                 num_predict=80, temperature=0.0,
                 note="short factual num_predict=80 (regression)")
    results.append(r)

    # ---- Finalize ----
    summary = build_summary(results)
    final = {
        "ticket": "TKT-1023",
        "change": "CHG-0962",
        "test_date_local": "2026-07-21 17:18 MYT",
        "test_completed_at": utcnow(),
        "report_path": str(FINAL_REPORT.resolve()),
        "model": MODEL,
        "fix_applied": "Top-level body['think'] = false on every /api/generate request",
        "fix_root_cause_reference": "TKT-1016 / state/gemma4-31b-empty-response-investigation-2026-07-21.json — Ollama 0.32.1 enables thinking=true by default for the gemma4 parser",
        "builds_on": ["TKT-1014", "TKT-1016", "TKT-1018"],
        "environment": build_env(),
        "baseline": {
            "ts_utc": utcnow(),
            "ollama_list_post_qwen_removal": ollama_list(),
            "ollama_ps_at_start": ollama_ps(),
            "memory_snapshot": vmstat(),
        },
        "plan": plan,
        "results": results,
        "summary": summary,
        "raw_log": str(RAW_LOG.resolve()),
    }

    FINAL_REPORT.write_text(json.dumps(final, indent=2, default=str))
    print(f"\nWrote final report: {FINAL_REPORT}", flush=True)
    print(f"Raw log: {RAW_LOG}", flush=True)
    print(f"Summary:\n{json.dumps(summary, indent=2, default=str)}", flush=True)
    return 0


def ollama_list() -> list:
    try:
        r = subprocess.run(["ollama", "list"], capture_output=True, text=True, timeout=10)
        out = []
        for line in r.stdout.strip().splitlines()[1:]:
            parts = line.split()
            if parts:
                out.append({"name": parts[0], "id": parts[1] if len(parts) > 1 else "",
                            "size": parts[2] if len(parts) > 2 else "",
                            "modified": " ".join(parts[3:]) if len(parts) > 3 else ""})
        return out
    except Exception as e:
        return [{"error": str(e)}]


def build_env() -> dict:
    return {
        "host": "OC2A (Mac Mini M4 Pro 48GB unified RAM)",
        "hostname": "AINCHORSOC2A",
        "ollama_version": "0.32.1",
        "api_endpoint": API,
        "ollama_num_parallel": "default (1)",
    }


def build_summary(results: list[dict]) -> dict:
    flat = [r for r in results if "http_code" in r]
    n_total = len(flat)
    n_200 = sum(1 for r in flat if r.get("http_code") == 200)
    n_nonempty = sum(1 for r in flat if r.get("response_nonempty"))
    n_empty = sum(1 for r in flat if r.get("http_code") == 200 and not r.get("response_nonempty"))
    tps_eval = [r["tokens_per_sec_eval"] for r in flat if r.get("tokens_per_sec_eval")]
    tps_prompt = [r["tokens_per_sec_prompt_eval"] for r in flat if r.get("tokens_per_sec_prompt_eval")]
    return {
        "n_tests": n_total,
        "n_http_200": n_200,
        "n_nonempty": n_nonempty,
        "n_empty_with_200": n_empty,
        "empty_response_bug_present_with_think_false": n_empty > 0,
        "tps_eval_min": min(tps_eval) if tps_eval else None,
        "tps_eval_max": max(tps_eval) if tps_eval else None,
        "tps_eval_mean": round(sum(tps_eval) / len(tps_eval), 2) if tps_eval else None,
        "tps_prompt_eval_min": min(tps_prompt) if tps_prompt else None,
        "tps_prompt_eval_max": max(tps_prompt) if tps_prompt else None,
        "tps_prompt_eval_mean": round(sum(tps_prompt) / len(tps_prompt), 2) if tps_prompt else None,
    }


if __name__ == "__main__":
    sys.exit(main())
