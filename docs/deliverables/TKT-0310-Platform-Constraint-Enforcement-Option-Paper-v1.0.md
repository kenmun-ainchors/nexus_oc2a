# TKT-0310: Platform Constraint Enforcement — Option Paper

**Author:** Thrawn 🎯, Platform Architecture Specialist  
**Date:** 2026-06-02  
**Status:** v1.0 — For Review  
**Classification:** Internal — Platform Architecture  

---

## 1. Executive Summary

The OpenClaw platform operates a multi-agent architecture where agents, crons, and automated workflows share finite compute, memory, and I/O resources. As the agent fleet has scaled — both in number and in capability — four distinct classes of resource-constraint violations have emerged in production: model context window overflows, token attention window drift (tilde-path desync), MD file size breaches, and cron timeout failures.

Each violation class degrades platform reliability differently. Context overflows produce silent truncation and non-deterministic agent behavior. Tilde-path bugs cause agents to operate on stale or empty state in isolated cron sessions. File size breaches risk gateway startup failures when SOUL.md or AGENTS.md exceed hard limits. Cron timeouts produce zombie processes and missed scheduled work with no automated recovery.

This paper evaluates five solution approaches against each violation class, ranks them by effort-to-impact ratio, and recommends a phased implementation that delivers 80% of risk reduction within two sprint cycles. The recommended approach prioritizes *defense-in-depth at the gateway layer* — enforcing constraints at injection time rather than relying on per-agent discipline — combined with lightweight runtime guards for crons.

---

## 2. Problem Statement

### 2.1 Model Context Window Overflow

**Observed Incidents:**
- DeepSeek V4 agents with large workspace context (MEMORY.md + SOUL.md + AGENTS.md + conversation history) exceeding the 128K token window.
- Agent behavior degrades silently: middle-context attention loss causes agents to "forget" injected system prompts, reverting to base model behavior.
- No pre-flight token budget check exists at the gateway. Agents receive all files unconditionally, and the model provider's truncation strategy is opaque and non-deterministic.

**Impact:**
- Unreliable agent outputs in long-running sessions.
- "Amnesia" bugs where agents lose core instructions mid-task.
- Difficult to diagnose — failure mode is degradation, not hard error.

**Root Cause:** No context budget accounting at injection time. Gateway does not measure total injected token count against model window limits.

---

### 2.2 Token Attention Window Drift — Tilde-Path Bug

**Observed Incidents:**
- Cron sessions executing under `launchd` context receive `$HOME` as the system user's home (`/var/root` or `/Users/daemon`) rather than the agent workspace owner's home.
- File paths using `~/` (tilde) resolve to `$HOME` at shell expansion time. In isolated cron environments, this points to the wrong directory.
- Agents read empty or stale AGENTS.md / SOUL.md / MEMORY.md files from the wrong home directory, then operate with zero context.
- First observed: cron-scheduled heartbeats on macOS nodes generating nonsensical outputs because the agent "thought" it had no instructions.

**Impact:**
- Silent context corruption: agent believes it loaded files correctly but operated on wrong/empty data.
- Cron tasks produce garbage outputs posted to production channels.
- Recurring — every cron invocation in the affected environment reproduces the bug.

**Root Cause:** Path resolution at shell layer differs between interactive sessions (where `$HOME` is the workspace owner) and cron/launchd sessions (where `$HOME` is the system service user). Agents receive tilde-paths without normalization at the platform layer.

---

### 2.3 MD File Size Limits — Hard Ceilings Breached

**Observed Incidents:**
- MEMORY.md exceeded 15K limit after 90 days of daily memory accumulation without curation.
- AGENTS.md approached 12K limit when teams added extensive procedural checklists.
- SOUL.md exceeded 10K limit after personality + voice + biography sections grew organically.
- Gateway startup validation flagged size breaches, requiring manual intervention to truncate files before agents could start.

**Current Hard Limits:**

| File | Limit |
|------|-------|
| SOUL.md | 10 KB |
| AGENTS.md | 12 KB |
| MEMORY.md | 15 KB |
| HEARTBEAT.md | 15 KB |

**Impact:**
- Gateway startup blocked until files are manually trimmed — platform unavailable.
- No incremental enforcement: files grow silently until startup validation fails.
- Truncation is manual and lossy — important context may be cut.

**Root Cause:** No pre-injection size validation. Limits enforced only at gateway startup, not at file-write time or pre-injection.

---

### 2.4 Cron Timeout Thresholds — No Auto-Scaling

**Observed Incidents:**
- Long-running cron tasks (multi-step agent workflows) hitting default 300s timeout.
- No adaptive timeout: all crons use the same hard ceiling regardless of task complexity.
- Failed crons leave no recovery action — they simply die, and the next scheduled invocation may be hours away.
- Zombie processes observed when cron subprocesses are killed but child processes persist.

**Impact:**
- Missed scheduled work (morning digests, periodic memory maintenance, heartbeat checks).
- Resource leaks from unterminated child processes.
- Manual intervention required to restart failed cron chains.

**Root Cause:** Static timeout for all cron types. No auto-scaling based on task profile or historical execution time. No retry logic.

---

## 3. Options Analysis

### 3.1 Context Budget Guards

**Description:** Token-counting circuit-breaker at gateway injection time. Before injecting prompt files into an agent's context, the gateway tallies total token count (using tiktoken or equivalent) and compares against the target model's context window. If total exceeds a configurable threshold (e.g., 80% of window), the gateway either truncates non-critical files or refuses injection with a clear error.

| Aspect | Detail |
|--------|--------|
| **Pros** | Deterministic prevention of overflow; clear error messages; no model-provider dependency; works across all model backends |
| **Cons** | Tokenizer must match model family (GPT vs Claude vs DeepSeek tokenization differs); adds latency to every injection; requires per-model window configuration |
| **Effort** | Medium (3-5 days) — implement tokenizer adapter, config schema changes, injection gate logic |
| **Risk** | Low — purely additive; can be feature-flagged; fallback is current behavior |

**Coverage:** Addresses Problem 2.1 (context window overflow). Partial mitigation for 2.3 (by truncating large files before injection).

---

### 3.2 Inline-Path Reinforcement — Tilde Normalization

**Description:** A `safe-path.sh` utility that normalizes all file paths before they reach agent prompt construction. Tilde (`~`) is expanded to an absolute, canonical path using the workspace owner's home directory (resolved from config, not `$HOME` env). Applied at the gateway's prompt assembly layer before any file is read or injected.

**Implementation Sketch:**
```bash
# safe-path.sh
# Resolves tilde to workspace owner's home, not process $HOME
WORKSPACE_HOME=$(openclaw config get workspace.home)
echo "${1/\~/$WORKSPACE_HOME}"
```

Called at gateway prompt construction:
```javascript
const safePath = execSync(`safe-path.sh "${rawPath}"`).toString().trim();
```

| Aspect | Detail |
|--------|--------|
| **Pros** | Direct fix for root cause; simple implementation; zero runtime overhead; works for all path types |
| **Cons** | Shell dependency (safe-path.sh must be installed); doesn't fix paths already hardcoded in agent instructions |
| **Effort** | Low (1-2 days) — shell script + gateway integration point |
| **Risk** | Very low — path normalization is a well-understood operation; edge cases (symlinks, NFS mounts) easily handled |

**Coverage:** Addresses Problem 2.2 (tilde-path bug). Indirect help for 2.1 (correct files = correct context).

---

### 3.3 Prompt Truncation at Gateway

**Description:** Intelligent truncation of injected prompt files when total context approaches model limits. Unlike token-counting (Option 3.1), this actively reduces content. Strategy: prioritize core files (SOUL.md, AGENTS.md) over auxiliary files (MEMORY.md, HEARTBEAT.md). Within files, use summarization or head/tail extraction rather than arbitrary cutoff.

| Aspect | Detail |
|--------|--------|
| **Pros** | Allows agents to operate even with large context; graceful degradation rather than hard failure; preserves core instructions |
| **Cons** | Complex truncation logic (which parts of MEMORY.md to keep?); risk of removing critical context; requires model-specific tokenization |
| **Effort** | High (5-8 days) — summarization pipeline, priority configuration, truncation policies per file type |
| **Risk** | Medium — wrong truncation can produce worse outcomes than overflow; needs extensive testing with real agent workloads |

**Coverage:** Addresses Problems 2.1 and 2.3 together. Complementary to Option 3.1 (budget guards decide *when* to truncate; truncation logic decides *what* to remove).

---

### 3.4 Timeout Auto-Scaling for Crons

**Description:** Replace static 300s timeout with adaptive timeout based on task profile and historical execution data. Short crons (heartbeats, checks) get base timeout; long crons (model inference, multi-step workflows) get extended timeout. Implement exponential backoff retry with configurable max retries. Add zombie process reaping via process group tracking.

**Implementation:**
- Task profiles: `heartbeat` (60s), `standard` (300s), `extended` (900s), `batch` (3600s)
- Auto-scaling: if a cron historically completes in ~200s, set timeout to 250s; if it grows, scale up to task profile max
- Retry: 3 retries with 2x backoff (30s → 60s → 120s)
- Process group tracking: kill `-TERM` → wait 5s → kill `-KILL` on the process group, not just the parent PID

| Aspect | Detail |
|--------|--------|
| **Pros** | Eliminates one-size-fits-all timeout; retry logic prevents missed work; zombie reaping fixes resource leaks; task profiles easy to configure |
| **Cons** | Historical data requires storage (simple JSON per cron); edge case: first run of new cron has no history; adds complexity to cron runner |
| **Effort** | Medium (3-4 days) — cron runner refactor, task profile config, retry logic, process group management |
| **Risk** | Low-Medium — carefully handle infinite retry loops; ensure process group killing doesn't affect sibling processes |

**Coverage:** Addresses Problem 2.4 (cron timeouts). Provides foundation for future cron observability.

---

### 3.5 File Size Enforcement — Pre-Injection Validation

**Description:** Validate file sizes at three checkpoints: (1) file-write time (agent or skill writes a file), (2) gateway startup (existing check), (3) pre-injection (before reading file into agent context). When a limit is breached, the platform rejects the write with a clear error and suggests remediation (e.g., "MEMORY.md is 16.2 KB — limit is 15 KB. Run `/memory curate` to trim."). Optionally, implement automatic summarization of large files (delegate to a lightweight model to condense).

| Aspect | Detail |
|--------|--------|
| **Pros** | Catches breaches early (write-time) instead of at startup; clear remediation guidance; three-layer defense; optional auto-summarization reduces manual work |
| **Cons** | Write-time enforcement may block legitimate agent operations; auto-summarization quality is model-dependent; three checkpoints means three places to configure limits |
| **Effort** | Medium (3-5 days) — write hook, pre-injection validator, auto-summarization pipeline, remediation messaging |
| **Risk** | Low — validation failures are informative, not destructive; can be warn-only initially, then enforce |

**Coverage:** Addresses Problem 2.3 (file size limits) comprehensively. Combined with Option 3.3 (truncation), provides end-to-end file size management.

---

### 3.6 Summary Comparison Matrix

| Solution | Problems Addressed | Effort | Risk | Priority |
|----------|-------------------|--------|------|----------|
| Context Budget Guards (3.1) | 2.1, partial 2.3 | Medium | Low | P1 |
| Tilde Normalization (3.2) | 2.2 | Low | Very Low | P0 |
| Prompt Truncation (3.3) | 2.1, 2.3 | High | Medium | P2 |
| Timeout Auto-Scaling (3.4) | 2.4 | Medium | Low-Medium | P1 |
| File Size Enforcement (3.5) | 2.3 | Medium | Low | P1 |

---

## 4. Recommended Approach

### 4.1 Decision Rationale

The recommended approach is **defense-in-depth with phased rollout**, prioritizing solutions by:

1. **Risk severity** — tilde-path bug produces silently wrong outputs (P0).
2. **Effort-to-impact ratio** — tilde normalization is ~1 day and eliminates a recurring class of failures.
3. **Synergy** — context budget guards + file size enforcement work together: budget guards measure total load, file size enforcement prevents individual file bloat.
4. **Low-risk first** — deploy low-risk solutions (tilde fix, budget guards as warn-only) to gather operational data before enabling enforcement.

**Recommended combination:** Options 3.2 + 3.1 + 3.5 + 3.4, deployed in that order. Option 3.3 (prompt truncation) is deferred to Phase 3 as it carries higher complexity and risk; budget guards alone will prevent overflow, and truncation is only needed if overflow *would* occur.

### 4.2 Why Not Truncation-First?

Truncation (Option 3.3) is seductive — "just cut content when it's too big" — but it introduces a new failure mode: *wrong content retained*. If the truncator removes the wrong section of MEMORY.md, the agent operates on partial knowledge, which is worse than a hard error that forces human attention. Budget guards (warn → refuse) are safer: they surface the problem explicitly.

Truncation is retained as a Phase 3 enhancement for environments where agents *must* operate even with oversized context (e.g., legacy workspaces with years of accumulated memory).

---

## 5. Implementation Plan

### Phase 0: Path Normalization (P0 — Immediate)

**Duration:** 1-2 days  
**Dependencies:** None  
**Rollout:** Canary → All gateways

**Tasks:**
1. Create `safe-path.sh` utility:
   - Resolve `~` using workspace config, not `$HOME`
   - Canonicalize paths (`realpath` equivalent)
   - Log warnings when tilde expansion differs from `$HOME`
2. Integrate at gateway prompt assembly:
   - Intercept all file-path references before file reads
   - Apply normalization transparently
3. Add regression test: cron session with wrong `$HOME` → agent reads correct SOUL.md
4. Deploy to canary gateway, observe 24h, deploy to all

**Success criteria:** Zero tilde-path incidents in cron sessions for 7 consecutive days.

---

### Phase 1: Core Guards (P1 — Sprint 1)

**Duration:** 5-7 days (parallel workstreams)  
**Dependencies:** Phase 0 complete

#### Workstream A: Context Budget Guards

1. Add `contextWindow` to model config schema (per-model token limits)
2. Implement token counting adapter (tiktoken for GPT-family, fallback heuristic for others)
3. Gateway injection gate:
   - Measure total injected tokens before agent spawn
   - If >80% of window: log WARN, optionally truncate non-critical files
   - If >95% of window: refuse injection, return clear error to caller
4. Config flag: `contextBudget.enforce: warn | block` (start with `warn`)
5. Dashboard metric: `gateway.context.injection_token_count`

#### Workstream B: File Size Enforcement

1. Add file-size limits to platform config schema (centralized, not hardcoded)
2. Write-time hook: intercept file writes from agents/skills, validate before commit
3. Pre-injection validator: before reading file into context, check size
4. Remediation messaging:
   - `MEMORY.md is 16.2 KB (limit: 15 KB). Suggested: /memory curate`
   - `AGENTS.md is 13.1 KB (limit: 12 KB). Consider moving procedures to a skill`
5. Config flag: `fileSize.enforce: warn | block` (start with `warn`)
6. Dashboard metric: `gateway.files.size_breach_count`

#### Workstream C: Timeout Auto-Scaling

1. Define task profiles: `heartbeat` (60s), `standard` (300s), `extended` (900s), `batch` (3600s)
2. Cron config: add `profile` field, default `standard`
3. Historical tracking: store last 10 execution times per cron in `.openclaw/cron-history.json`
4. Adaptive timeout: `max(base_timeout * 1.5, p95_historical * 1.2)` capped at profile max
5. Retry logic: 3 retries, exponential backoff (30s → 60s → 120s)
6. Process group reaping: `kill(-pgid, SIGTERM)` → 5s grace → `kill(-pgid, SIGKILL)`
7. Config: `cron.retry.maxAttempts: 3`, `cron.retry.backoffBase: 30`

---

### Phase 2: Hardening (Sprint 2)

**Duration:** 3-5 days  
**Dependencies:** Phase 1 complete

1. **Flip feature flags from `warn` to `block`:**
   - Context budget: block at >95% window
   - File size: block writes exceeding limits
   - Monitor dashboard metrics for 48h at `warn` before flipping

2. **Auto-summarization (lightweight):**
   - When MEMORY.md exceeds limit, delegate to a fast/small model (e.g., Gemma 4 31B) to produce a condensed version
   - Store original as `MEMORY.md.full` and truncated as `MEMORY.md`
   - Gate behind config flag `fileSize.autoSummarize: true`

3. **Cron observability dashboard:**
   - Per-cron: last execution time, success/fail, timeout history
   - Alert when cron exceeds 80% of adaptive timeout

---

### Phase 3: Prompt Truncation (Backlog)

**Duration:** 5-8 days  
**Trigger:** Activated when Phase 1 budget guards show ≥10% of injections hitting the 80% warn threshold

Not scheduled for immediate implementation. Retained as a backlog item with the following design:
- Priority-based file ordering: SOUL.md > AGENTS.md > MEMORY.md > HEARTBEAT.md
- Truncation strategy per file: MEMORY.md → keep most recent 30 days; AGENTS.md → keep first 50% + last 20%; SOUL.md → never truncate (refuse injection instead)
- Model delegation: use a lightweight model to summarize truncated sections into a "context summary" injected as metadata

---

## 6. CHG Record Entry

```
CHG-2026-06-02-001 | Platform Constraint Enforcement Framework
Author: Thrawn 🎯
Tickets: TKT-0310
Type: Platform Enhancement
Components: Gateway, Cron Runner, File System Hook

Summary:
  Implements multi-layer constraint enforcement across the OpenClaw platform:
  - Path normalization (tilde → absolute using workspace config)
  - Context budget guards (token counting + injection gates)
  - File size enforcement (write-time + pre-injection validation)
  - Cron timeout auto-scaling (adaptive timeout + retry + process group reaping)

Compatibility:
  Backward compatible. New config fields use sensible defaults.
  Feature flags start in `warn` mode, requiring explicit opt-in to `block`.

Rollback:
  Set all enforcement flags to `warn` or `off`. Path normalization
  is purely additive and has no rollback risk.

Dependencies:
  - openclaw-gateway >= 2.4.0
  - tiktoken (npm) for token counting
  - workspace config schema update
```

---

## 7. Success Metrics

### Leading Indicators (within 2 weeks of deployment)

| Metric | Baseline | Target | Measurement |
|--------|----------|--------|-------------|
| Tilde-path incidents | ~3/week (estimated) | 0/week | Cron output quality reviews |
| Context overflow warnings | Unknown (not measured) | Measured, <5% of injections | `gateway.context.injection_token_count` |
| File size breaches at startup | ~1/month | 0/month | `gateway.files.size_breach_count` |
| Cron timeout failures | ~2/week | <1/week | Cron execution logs |
| Zombie processes from crons | ~1-2 active at any time | 0 | Process tree inspection |

### Lagging Indicators (within 4-8 weeks)

| Metric | Target |
|--------|--------|
| Agent "amnesia" bug reports | 80% reduction |
| Gateway startup failures (file size) | 100% reduction |
| Manual cron restarts required | 90% reduction |
| Platform uptime (gateway availability) | >99.9% |

### Dashboards to Create

1. **Constraint Health:** Token usage per injection, file size breach count, path normalization warnings
2. **Cron Execution:** Per-cron success rate, P50/P95 execution time, timeout events, retry count
3. **File System:** Largest files by category, growth rate over time, auto-summarization events (Phase 2+)

---

## Appendix A: File Size Limit Configuration Schema

```yaml
# Proposed addition to platform config
constraints:
  files:
    limits:
      SOUL.md: 10240       # 10 KB
      AGENTS.md: 12288     # 12 KB
      MEMORY.md: 15360     # 15 KB
      HEARTBEAT.md: 15360  # 15 KB
    enforce: warn           # warn | block
    autoSummarize: false    # Phase 2+
  context:
    budgetRatio: 0.80       # warn at 80% of window
    blockRatio: 0.95        # block at 95% of window
    enforce: warn           # warn | block
  cron:
    profiles:
      heartbeat: 60
      standard: 300
      extended: 900
      batch: 3600
    retry:
      maxAttempts: 3
      backoffBase: 30       # seconds
    historyWindow: 10       # executions to track
    zombieReapGrace: 5      # seconds between TERM and KILL
```

## Appendix B: Token Counting Heuristics

For model families without native tiktoken support, use a conservative heuristic:

| Model Family | Tokenizer | Chars/Token (approx) |
|-------------|-----------|----------------------|
| GPT-4 / GPT-4o | cl100k_base | ~3.5 |
| Claude 3/4 | Claude tokenizer | ~4.0 |
| DeepSeek V3/V4 | GPT-compatible (cl100k_base) | ~3.5 |
| Gemma | SentencePiece | ~4.5 |
| Llama 3/4 | BPE (tiktoken) | ~3.8 |
| Fallback (unknown) | charCount / 3.5 | ~3.5 |

Fallback uses `charCount / 3.5` which is conservatively high (overestimates tokens → earlier warning, safer).

---

*End of document. TKT-0310 Option Paper v1.0.*
