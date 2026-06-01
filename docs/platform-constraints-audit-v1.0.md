# Platform Constraints Audit v1.0

**Date:** 2026-06-01
**Agent:** Thrawn (Subagent)
**Ticket:** TKT-0310
**Status:** DRAFT FOR REVIEW

## Executive Summary
This document identifies the critical constraints (hard and soft) within the OpenClaw platform. As the system moves into steady-state operations, the exponential growth of memory and interaction logs poses a risk of silent truncation, performance degradation, and "memory decay."

---

## 1. Core Configuration & Identity Limits

### 1.1 SOUL.md (Identity/Persona)
- **Limit Type:** Hard
- **Limit Value:** 10,000 characters (Truncation Threshold)
- **Behavior on Exceed:** Silent truncation of content beyond the threshold during injection into the model context.
- **Current State:** Low to Medium (Thrawn's SOUL.md is well under the limit).
- **Growth Rate:** Low (updates are architectural/strategic).
- **Monitoring:** None.
- **Mitigation:** Periodic audit of SOUL.md size; move detailed specs to `RULES.md` or referenced documents.
- **Priority:** Medium

### 1.2 RULES.md / AGENTS.md (Guidelines/Workspace)
- **Limit Type:** Hard
- **Limit Value:** 10,000 characters (per-file injection threshold)
- **Behavior on Exceed:** Truncation. If these files grow too large, the agent loses critical operational guardrails.
- **Current State:** Medium (AGENTS.md is comprehensive).
- **Growth Rate:** Medium (as more rules/conventions are added).
- **Monitoring:** None.
- **Mitigation:** Modularize rules into specific skill files or referenced documentation via the Holocron Registry.
- **Priority:** High

### 1.3 MEMORY.md (Long-term Memory)
- **Limit Type:** Hard
- **Limit Value:** 10,000 characters
- **Behavior on Exceed:** Truncation. This leads to "memory decay" where the agent loses the earliest curated memories as new ones are added if not managed.
- **Current State:** N/A (File missing/empty in current workspace check).
- **Growth Rate:** High (cumulative).
- **Monitoring:** None.
- **Mitigation:** Implementation of an **Archive Overflow Pattern**: when MEMORY.md hits 8k chars, move older entries to `memory/archives/YYYY-MM.md`.
- **Priority:** Critical

---

## 2. Session & Context Limits

### 2.1 Context Window Injection
- **Limit Type:** Hard (Model-specific)
- **Limit Value:** Varies by model (e.g., 128k for Claude 3.5, etc.), but OpenClaw's internal injection logic may truncate individual files at 10k.
- **Behavior on Exceed:** Model "forgets" the start of the session or fails to see the bottom of injected files.
- **Current State:** Medium.
- **Growth Rate:** Linear per session.
- **Monitoring:** Context window usage tracking (if provided by gateway).
- **Mitigation:** Aggressive use of `sessions_yield` and focused file reading instead of loading all context files.
- **Priority:** High

### 2.2 Project Context / Bootstrap
- **Limit Type:** Hard
- **Limit Value:** Total combined size of injected startup files.
- **Behavior on Exceed:** Truncation of the least critical files or the tail of the prompt.
- **Current State:** Low.
- **Growth Rate:** Low.
- **Monitoring:** None.
- **Mitigation:** Minimize `BOOTSTRAP.md` and utilize `AGENTS.md` for dynamic direction.
- **Priority:** Medium

### 2.3 Session History
- **Limit Type:** Soft/Hard
- **Limit Value:** Token limit for conversation history.
- **Behavior on Exceed:** Summarization or sliding window (loss of specific early-turn detail).
- **Current State:** Variable.
- **Growth Rate:** High (per interaction).
- **Monitoring:** Token count monitors.
- **Mitigation:** Manual summarization of long threads into `MEMORY.md` or task-specific docs.
- **Priority:** Medium

---

## 3. Data & Storage Limits

### 3.1 Journal Files (memory/YYYY-MM-DD.md)
- **Limit Type:** Soft (Performance)
- **Limit Value:** No hard char limit, but file system read/write overhead increases.
- **Behavior on Exceed:** Slower `read` operations; potential for tool truncation if files exceed 50KB/2000 lines.
- **Current State:** Low (currently empty/missing in this workspace).
- **Growth Rate:** Linear (Daily).
- **Monitoring:** None.
- **Mitigation:** Monthly rotation/compression of journal files.
- **Priority:** Medium

### 3.2 File System (Workspace)
- **Limit Type:** Hard (Disk Space)
- **Limit Value:** Host OS / Disk quota.
- **Behavior on Exceed:** `write` errors, system instability.
- **Current State:** Healthy.
- **Growth Rate:** Low (mostly text).
- **Monitoring:** Disk space alerts.
- **Mitigation:** Regular cleanup of `.openclaw/tmp/`.
- **Priority:** Low

### 3.3 Postgres Database (PG)
- **Limit Type:** Hard (Configured)
- **Limit Value:** Table sizes, WAL growth, vacuum thresholds.
- **Behavior on Exceed:** DB lockup, slow queries, disk exhaustion.
- **Current State:** Unknown (Internal Gateway).
- **Growth Rate:** Medium.
- **Monitoring:** DB metrics.
- **Mitigation:** Regular vacuuming and index optimization.
- **Priority:** High

---

## 4. Infrastructure & Runtime Limits

### 4.1 Ollama Model Sizes / RAM
- **Limit Type:** Hard (Hardware)
- **Limit Value:** OC1 24GB VRAM / System RAM constraint.
- **Behavior on Exceed:** Model offloading to CPU $\rightarrow$ extreme latency (Degradation) or Crash.
- **Current State:** Near limit for larger models.
- **Growth Rate:** N/A (Static per model).
- **Monitoring:** RAM/VRAM monitoring.
- **Mitigation:** Model quantization (4-bit) or swapping to smaller models for routine tasks.
- **Priority:** Critical

### 4.2 Cron Limits
- **Limit Type:** Hard (Gateway)
- **Limit Value:** Concurrent job limit / Queue depth.
- **Behavior on Exceed:** Delayed execution, skipped heartbeats.
- **Current State:** Low.
- **Growth Rate:** Linear with agent complexity.
- **Monitoring:** Cron logs.
- **Mitigation:** Batching tasks into Heartbeats instead of individual Crons.
- **Priority:** Medium

### 4.3 Gateway Config (openclaw.json)
- **Limit Type:** Soft/Hard
- **Limit Value:** JSON parsing limits / Schema complexity.
- **Behavior on Exceed:** Parsing errors, corrupted config $\rightarrow$ platform offline.
- **Current State:** Stable.
- **Growth Rate:** Low.
- **Monitoring:** None (except via crash).
- **Mitigation:** Use `gateway config.patch` exclusively; avoid direct manual edits.
- **Priority:** Critical

---

## Summary Table

| Component | Limit | Type | Behavior | Priority | Mitigation |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **MEMORY.md** | 10k chars | Hard | Decay/Truncation | **CRITICAL** | Archive Overflow Pattern |
| **Ollama RAM** | 24GB | Hard | Extreme Latency | **CRITICAL** | Quantization / Tiering |
| **Gateway Config** | Schema | Hard | Platform Crash | **CRITICAL** | Use `config.patch` only |
| **RULES.md** | 10k chars | Hard | Guardrail Loss | **HIGH** | Modularization |
| **PG Database** | Disk/WAL | Hard | DB Lockup | **HIGH** | Vacuum / Maintenance |
| **Context Window**| Model-dep | Hard | Forgetting | **HIGH** | Selective Reading |
| **SOUL.md** | 10k chars | Hard | Persona Loss | Medium | Externalize Specs |
| **Journals** | 50KB/2k lines| Soft | Tool Truncation | Medium | Monthly Rotation |
| **Crons** | Queue Depth | Hard | Delay/Skip | Medium | Heartbeat Batching |
| **Workspace** | Disk Space | Hard | Write Error | Low | Tmp Cleanup |
