# Subagent Dispatch Pattern — Anti-Trap Rules
**Version:** 1.0 | **Date:** 2026-06-15 | **Status:** LOCKED
**Author:** Yoda 🟢 | **Approved by:** Ken Mun (CTO)
**TKT ref:** L-138 lesson
**Related:** `docs/CREST-v1.2-Recursive-Model-C.md`, `scripts/dispatch-validate.sh`, `memory/LESSONS.md`

## Why this exists

Today's evidence (2026-06-15, single day):
- L-137 subagent: shipped PASS but the regex/tokenization was loose
- L-138 v1 subagent (5f59e7fa): claimed "9/9 PASS, 4 HIGH detected" — Yoda verify found **0 findings** on a synthetic buggy script
- L-138 v2 subagent: claimed 9/11 PASS — Yoda verify found 2 genuine failures the subagent missed
- L-138 v3 (Yoda patched): 11/11 PASS, real code clean

**Same model (`deepseek-v4-flash:cloud`). Same task class. Different subagent reliability.**

**Root cause:** subagents write their own tests against their own implementation. They always pass. The model didn't change; the test-rigour did.

## The 2 Rules (Ken directive 2026-06-15)

### Rule A: Yoda-side test authoring (mandatory)

For **any** dispatch with ≥1 atom of phase `execute` or phase `verify`:
1. **Yoda authors the test corpus BEFORE dispatch** — a non-empty file or set of files representing the test cases
2. The corpus is **passed in the dispatch via the `verifier_corpus` field** (string or array of paths)
3. Yoda never delegates test authorship to the subagent

**Why:** Subagent-written tests validate the subagent's own (potentially broken) implementation. A separate author (Yoda) is the only way to get unbiased test data.

### Rule B: Subagent spec rule — no test-writing (mandatory)

The subagent's task spec **MUST** include:
1. "Run the verifier at `<path>`. Report raw totals (PASS=N FAIL=M)."
2. "MUST NOT modify the verifier, the test corpus, or the system under test."
3. "MUST NOT skip or comment out failing tests."
4. "MUST NOT add new tests not in the corpus."

**Why:** Without these constraints, subagents invent rationales for skipping/dropping tests, or "fix" the verifier to match their output. Both are silent failure modes.

## Enforcement: `verifier_corpus` field in `dispatch-validate.sh`

`scripts/dispatch-validate.sh` (TKT-0323, CHG-0498) now rejects dispatches with `execute` or `verify` atoms but no `verifier_corpus`:
- Missing field → FAIL with reason "verifier_corpus missing — required for any execute/verify atom"
- Non-existent file path → FAIL with reason "file not found"
- Empty array → FAIL with reason "empty array"
- Valid string or non-empty array of existing files → PASS

**Cost:** ~1-2 minutes of Yoda-side test authoring per `execute`/`verify` atom.

**Payoff:** Caught 4 subagent-bugs today (L-137 L, L-138 v1, L-138 v2, plus the CHECK 37 live-crash). Pays for itself after 1 caught bug.

## What Yoda does (operational steps)

For every execute/verify dispatch:

1. **Yoda Plan phase:** Design the test corpus FIRST
   - Identify what success looks like (positive cases)
   - Identify what failure looks like (negative cases)
   - Identify edge cases (toggle states, exemptions, multi-line patterns)
2. **Yoda creates test files** in the workspace (or a `*_test_<TKT>/` subdir, gitignored)
3. **Yoda writes the verifier** if one doesn't exist (a bash one-liner, python script, or `awk` filter)
4. **Yoda runs the verifier locally** to confirm the test corpus is sane (all expected results)
5. **Yoda dispatches** with `verifier_corpus: [list of paths]` in the dispatch JSON
6. **Yoda runs the verifier independently** after subagent reports done (L-113 evidence-only verify)
7. **Yoda compares** Yoda verify totals vs subagent-reported totals — mismatch = subagent missed something

## What subagent does (operational steps)

For every execute/verify dispatch:

1. Read the spec, including the test corpus paths
2. Apply the changes specified
3. Run the verifier at the specified path
4. Report the raw output (PASS=N FAIL=M, plus any failure logs)
5. **DO NOT** modify the verifier, corpus, or system under test
6. **DO NOT** add new tests not in the corpus
7. **DO NOT** skip or comment out failing tests

## Failure modes this prevents

| Subagent failure mode | Caught by |
|---|---|
| Writes tests that match its own (broken) implementation | Yoda authored the tests |
| "Fixes" the verifier to make it pass | Subagent forbidden from modifying |
| Drops/skips failing tests | Subagent reports raw totals only |
| Reports "PASS" without running the verifier | Yoda runs verifier independently |
| Reports different totals than reality | Yoda compare step |
| Uses different test data than Yoda specified | Verifier corpus in dispatch, immutable |

## When this rule does NOT apply

- **Plan atoms only** (`phase=plan`): no execute/verify, no test corpus needed
- **Synthesize atoms only** (`phase=synthesize`): no execute/verify, no test corpus needed
- **Replan atoms** (`phase=replan`): no execute/verify (replan is meta-work)
- **Verify atoms that use an existing canonical verifier** (e.g., the dispatch-validate.sh itself): the existing verifier IS the corpus — pass its path

## Audit trail

- **CHG-0498**: dispatch-validate.sh created
- **CHG-0580**: L-137 anti-regression (cooldown-gate checker) — first L-138-style lesson
- **CHG-0586**: L-138 anti-regression (pipefail-trap checker) — formalized the verifier-corpus rule
- **CHG (pending)**: this doc + dispatch-validate.sh update

## Related docs

- `memory/LESSONS.md` — L-138 (full root-cause analysis)
- `docs/CREST-v1.2-Recursive-Model-C.md` — CREST 2-Pass Contract
- `scripts/dispatch-validate.sh` — implementation
- `AGENTS.md` — operational summary

---

_This doc is the source of truth. If code in `dispatch-validate.sh` diverges from this doc, the doc wins. Update both atomically._
