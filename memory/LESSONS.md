# Lessons Log — AInchors Nexus Platform

## L-175 — Instrumentation DoD must test the production call path
**Date:** 2026-07-11 · **CHG:** CHG-0861 · **Context:** CRESTv2-P1-EXEC-INSTRUMENT-001

**Rule:** When building diagnostic instrumentation, the Definition of Done must include a positive interception test via the actual production call path (e.g. the native OpenClaw `exec` tool), not only a test harness that calls the wrapper directly. A wrapper that passes all its internal tests but is never invoked by the production path is a hollow green.

**Trigger:** The exec-empty instrumentation wrapper (CHG-0861) passed 21/21 tests and showed no latency increase, but the tests only invoked `bash scripts/exec-wrapper.sh <cmd>`. Normal agent calls via the OpenClaw `exec` tool bypassed the wrapper entirely, so the instrumentation could not capture the target failure.

**Precedent:** L-084, L-109 — never claim completion from a summary or internal test; always validate the actual production path.

**Action:** Corrected DoD for Option B exec interception requires a native `exec` tool call (e.g. `true` and `exit 7`) to produce an artifact in `state/exec-debug.log` and `state_exec_debug` before any latency/behaviour test is evaluated.
