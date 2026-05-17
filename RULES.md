# KIMI PLATFORM MANDATE — NON-NEGOTIABLE RULE
# Effective: 2026-05-17 15:17 AEST
# Authority: Ken Mun (CTO) — mandatory and persistent
# CHG-0373
# Refined: 2026-05-17 15:20 AEST (added strict DoD after CHG-0372 lesson)

## Rule Statement

**ALL agent execution across the AInchors Nexus platform SHALL use `ollama/kimi-k2.6:cloud` as the primary model until explicitly overridden by Ken.**

This rule is:
- **MANDATORY** — No exceptions without Ken's explicit written approval
- **NON-NEGOTIABLE** — Agents may not self-override or fallback without approval
- **PERSISTENT** — Remains active indefinitely until Ken issues `KIMI MANDATE LIFTED` keyword
- **PLATFORM-WIDE** — Applies to all agents, all sessions, all crons, all channels

## Scope

| Component | Requirement |
|-----------|-------------|
| **Main session (webchat)** | kimi primary, Sonnet ONLY with explicit Ken approval per task |
| **Telegram sessions** | kimi primary, Sonnet ONLY with explicit Ken approval per task |
| **Cron jobs** | kimi ONLY — no Anthropic models in any cron payload |
| **Sub-agents** | kimi primary, with kimi safety net (3-level fallback) |
| **Background tasks** | kimi ONLY |
| **Outage handling** | kimi ONLY — no Sonnet fallback during outages |

## Definition of Done (DoD) — STRICT VERSION

**Work is NOT considered complete until ALL of the following are verified:**

### Verification Checklist (MUST pass all)

| # | Check | Verification Method | Evidence Required |
|---|-------|---------------------|-------------------|
| 1 | **Actually executed** | Task performed, not just planned or described | Tool output showing execution |
| 2 | **Verified by tool** | File writes confirmed via `read`, commits via `git log`, API via response | Command output, file content, commit hash |
| 3 | **State validated** | JSON state files parse correctly, no syntax errors | `python3 -m json.tool` or `jq` validation |
| 4 | **Observable output** | Human-verifiable result exists | File path, commit ID, Notion URL, API response |
| 5 | **Ken confirmation** | For critical work, Ken explicitly confirms | Ken's "confirmed" or "approved" message |

### Anti-patterns that FAIL DoD (LEARNED FROM CHG-0372)

- ❌ **"I will create X"** — Planning is not execution. DoD not met.
- ❌ **"X has been created" without proof** — No file hash, commit ID, or URL. DoD not met.
- ❌ **Partial execution** — Wrote file but didn't commit, or created cron but didn't verify payload. DoD not met.
- ❌ **Tool error ignored** — `jq` parse error, `curl` failure, `exec` non-zero exit. DoD not met.
- ❌ **Assumption-based completion** — "Should work" without testing. DoD not met.
- ❌ **"All items implemented" when only 1 of 3 done** — CHG-0372 lesson: claimed 3 mitigations, only cron fully verified. DoD not met.
- ❌ **"Created" but not "tested"** — Script exists but not executed. DoD not met.
- ❌ **"Updated" but not "validated"** — File edited but syntax errors remain. DoD not met.

### CHG-0372 Lesson — Applied to All Future Work

> **What went wrong:** Claimed "all 3 mitigations implemented" but:
> 1. ✅ Cron created (but payload was generic, not specifically calling notion-sync-audit.sh)
> 2. ⚠️ ticket.sh existence check added (but not tested with actual duplicate scenario)
> 3. ⚠️ Ceremony updated in RUNBOOK (but no automated enforcement, no verification it works)
>
> **Root cause:** Declared completion after code changes, before verification.
>
> **Fix:** For EACH claimed item, run verification before declaring done:
> - Cron: Read back payload, confirm it calls the right script
> - Code change: Test with real scenario (create duplicate, verify prevention)
> - Ceremony: Verify the updated section is accessible and actionable

## Verification Protocol (NEW — Mandatory)

**After ANY claimed completion, run:**

```bash
# 1. Read back what was created
read <file_path> | head -20

# 2. Verify syntax/validity
python3 -m json.tool <json_file> || echo "JSON INVALID"
bash -n <script_file> || echo "SCRIPT SYNTAX ERROR"

# 3. Test with real scenario (if applicable)
# For ticket.sh: Create test ticket, verify Notion page created, try creating again (should not duplicate)
# For cron: Read back cron payload, verify correct command
# For ceremony: Verify RUNBOOK section is readable and actionable

# 4. Git commit and verify
# git show --stat HEAD
# git log --oneline -1
```

## Enforcement

### Warden Check (every 15 min)
- Verify all agents are on kimi or approved model
- Flag any agent on non-kimi model without CHG approval
- Escalate to Yoda → Ken immediately

### CI/CD Gate
- Any PR/commit modifying `.openclaw.json` model configs → blocked until Ken approval
- Any cron with non-kimi model → auto-flagged in audit

### Agent Self-Check (NEW — Mandatory Before Declaring Done)

**Before executing:**
1. "Am I on kimi?" → If not, WHY? Get Ken approval.
2. "What exactly am I doing?" → Be specific.
3. "How will I verify this?" → Know the verification step before starting.

**After executing:**
1. "Did I verify the result?" → Read file, check commit, test API.
2. "Can Ken see it?" → Is there a file path, URL, or commit hash?
3. "Did I declare completion too early?" → Double-check all claimed items.

**If unsure about ANY item:**
- Do NOT declare completion
- Ask Ken: "[Item X] is done, [Item Y] needs verification — confirm partial completion?"
- Or: "All items attempted but only X verified — continue with Y?"

## Exceptions

| Scenario | Approval Required | Documented In |
|----------|-------------------|---------------|
| Sonnet for critical security review | Ken explicit per-task | CHG entry |
| Sonnet for client-facing content | Ken explicit per-task | CHG entry |
| Sonnet for complex multi-ticket routing | Ken explicit per-task | CHG entry |
| Sonnet for CHG decisions | Ken explicit per-task | CHG entry |

**Default: NO exceptions. All work on kimi.**

## Verification Commands

```bash
# Check current model
openclaw status | grep model

# Check agent model configs
grep -r "anthropic" ~/.openclaw/workspace/state/ || echo "No Anthropic refs"

# Check cron models
openclaw cron list | grep "anthropic" || echo "No Anthropic crons"

# Verify JSON state files
for f in ~/.openclaw/workspace/state/*.json; do
  python3 -m json.tool "$f" > /dev/null 2>&1 || echo "INVALID JSON: $f"
done
```

## Compliance Log

| Date | Check | Result | Verifier |
|------|-------|--------|----------|
| 2026-05-17 | Initial mandate | ✅ All agents on kimi | Ken |
| 2026-05-17 | DoD refinement | ✅ CHG-0372 lesson applied | Ken |

## Activation

**Activated:** 2026-05-17 15:17 AEST by Ken Mun via WebChat
**Refined:** 2026-05-17 15:20 AEST (stricter DoD after CHG-0372 lesson)
**Deactivation keyword:** `KIMI MANDATE LIFTED` (only Ken can issue)
**CHG reference:** CHG-0373

---

**This rule supersedes all prior model routing policies until lifted.**
**CHGs are not done until verified. Verification is not optional.**

---

## BACKLOG SYNC RULE — NON-NEGOTIABLE (CHG-0377)
# Effective: 2026-05-17 15:44 AEST
# Authority: Ken Mun (CTO) — ABSOLUTELY NON-NEGOTIABLE

### Rule Statement

**ALL tickets (TKT) and changes (CHG) raised MUST be created in the Notion AKB Backlog.**

This rule is:
- **ABSOLUTELY NON-NEGOTIABLE** — No exceptions, ever
- **SSOT ENFORCEMENT** — Backlog is Ken's single source of truth
- **AUTOMATIC** — Every ticket creation must sync to Notion
- **VERIFIED** — After creation, verify the Notion page exists

### Scope

| Item | Notion Required | Verification |
|------|----------------|--------------|
| **New TKT** | YES — AKB Backlog page | Check Notion URL returned |
| **New CHG** | YES — Logged in CHANGELOG + Backlog reference | Backlog shows CHG link |
| **Status change** | YES — Update Notion status | Notion matches tickets.json |
| **Replacement TKT** | YES — Both old and new in Backlog | Cross-reference exists |

### Anti-patterns (FAIL DoD)

- ❌ Ticket created in tickets.json but NOT in Notion
- ❌ CHG logged in CHANGELOG.md but no Backlog reference
- ❌ "I'll sync later" — sync is part of creation, not separate
- ❌ Notion API error ignored — retry until success
- ❌ Assumption that ticket.sh handles sync — verify it does

### Verification Protocol

**After EVERY ticket creation:**
```bash
# 1. Check tickets.json has the ticket
grep "TKT-XXXX" state/tickets.json

# 2. Check Notion has the page
# (via search or direct URL check)

# 3. Verify status matches
tickets.json status == Notion status
```

### Enforcement

**ticket.sh MUST:**
1. Create ticket in tickets.json
2. IMMEDIATELY create Notion page via API
3. Verify Notion page exists (retry 3x if needed)
4. Return both ticket ID and Notion URL

**Failure to sync = DoD NOT MET**

### Ken's Directive

> "Another DoD either missed or not enforced, all TKT/CHG raised needs to be created in Backlog. Only having them captured and confirmed in internal memory or ticket is not DoD. Backlog to me Ken is the SSOT and must ALWAYS be in sync and reflecting what is in memory and context. Now create the items that are missing and ensure this rule is not missed again moving forward. Absolutely non-negotiable."

**Date:** 2026-05-17 15:44 AEST
**Channel:** openclaw-control-ui
**CHG:** CHG-0377

### CHG RECORDS — Also Non-Negotiable

**ALL CHG (Change Log) entries MUST be created in Notion AKB Backlog.**

- CHG records are not just in CHANGELOG.md — they must also appear in Backlog
- Each CHG gets a Notion page with:
  - Title: [CHG-NNNN] Description
  - Status: Done (CHG records are completed changes)
  - Type: change
  - Priority: High (all CHGs are significant)
  - Notes: Summary of what changed

**Missing CHGs = Broken SSOT**

### Enforcement for CHG

**changelog.sh MUST:**
1. Append to memory/CHANGELOG.md
2. IMMEDIATELY create Notion page via API
3. Verify Notion page exists
4. Return CHG ID and Notion URL

**After EVERY CHG:**
```bash
# 1. Check CHANGELOG.md has the entry
grep "CHG-NNNN" memory/CHANGELOG.md

# 2. Check Notion has the page
grep "CHG-NNNN" in Notion search

# 3. Verify title matches
# CHG-NNNN in CHANGELOG == [CHG-NNNN] in Notion
```

### CREATED DATE RULE — NON-NEGOTIABLE (CHG-0379)
# Effective: 2026-05-17 15:53 AEST
# Authority: Ken Mun (CTO) — ABSOLUTELY NON-NEGOTIABLE

**ALL items created in Notion AKB Backlog MUST have Created Date populated.**

This rule is:
- **ABSOLUTELY NON-NEGOTIABLE** — No exceptions, ever
- **AUTOMATIC** — Created Date is set at creation time
- **REQUIRED FIELD** — Never leave blank

### Scope

| Item | Created Date Required | Source |
|------|----------------------|--------|
| **New TKT** | YES | tickets.json createdAt |
| **New CHG** | YES | CHANGELOG.md entry date |
| **Replacement TKT** | YES | Original ticket date or new date |
| **AUTO-HEAL** | YES | Date of auto-heal run |

### Anti-patterns (FAIL DoD)

- ❌ Item created with blank Created Date
- ❌ "I'll fill it in later" — must be at creation
- ❌ Using default/placeholder dates
- ❌ Different date in Notion vs tickets.json vs CHANGELOG

### Enforcement

**ticket.sh MUST:**
1. Set Created Date = tickets.json createdAt date
2. Verify date is valid format (YYYY-MM-DD)
3. Confirm Notion page shows correct date

**changelog.sh MUST:**
1. Set Created Date = CHG entry date from CHANGELOG
2. Verify date matches the ## date line

### Ken's Directive

> "Created Date is not populated when items in backlog are created. Rule - ensure they are captured/entered when created."

**Date:** 2026-05-17 15:53 AEST
**Channel:** openclaw-control-ui
**CHG:** CHG-0379

### DELIVERED DATE RULE — NON-NEGOTIABLE (CHG-0380)
# Effective: 2026-05-17 15:57 AEST
# Authority: Ken Mun (CTO) — ABSOLUTELY NON-NEGOTIABLE

**ALL items with Status = Done MUST have Delivered Date populated.**

This rule is:
- **ABSOLUTELY NON-NEGOTIABLE** — No exceptions, ever
- **AUTOMATIC** — Delivered Date is set when status changes to Done
- **REQUIRED FIELD** — Never leave blank for completed items

### Scope

| Item | Delivered Date Required | Source |
|------|----------------------|--------|
| **Done TKT** | YES | Resolution/closure date from tickets.json |
| **Done CHG** | YES | CHG entry date from CHANGELOG |
| **Done AUTO-HEAL** | YES | Date item was resolved |
| **Any Done item** | YES | Date status changed to Done |

### Anti-patterns (FAIL DoD)

- ❌ Status = Done but Delivered Date is blank
- ❌ "I'll fill it in later" — must be at completion
- ❌ Using creation date instead of delivery date
- ❌ Different delivery date in Notion vs tickets.json vs CHANGELOG

### Enforcement

**ticket.sh MUST (when closing):**
1. Set Delivered Date = resolution date
2. Update Notion page with date
3. Verify both Status and Delivered Date are correct

**Status change workflow:**
```
Status: In progress → Done
  ↓
Set Delivered Date = today
  ↓
Verify Notion shows both Status=Done and Delivered Date=YYYY-MM-DD
```

### Ken's Directive

> "Similarly, all Delivered Date needs to be populated when completed/delivered. Enforce the rule."

**Date:** 2026-05-17 15:57 AEST
**Channel:** openclaw-control-ui
**CHG:** CHG-0380

### LESSONS REGISTRY RULE — NON-NEGOTIABLE (CHG-0381)
# Effective: 2026-05-17 16:04 AEST
# Authority: Ken Mun (CTO) — ABSOLUTELY NON-NEGOTIABLE

**Holocron Lessons Registry is SSOT. ALL lessons must be registered there.**

This rule is:
- **ABSOLUTELY NON-NEGOTIABLE** — No exceptions, ever
- **SSOT ENFORCEMENT** — Lessons Registry is the single source of truth
- **AUTOMATIC** — Every new lesson is registered immediately
- **COMPLETE** — All historical lessons must be present

### Scope

| Action | Requirement |
|--------|-------------|
| **New lesson logged** | MUST create entry in Lessons Registry (Notion) |
| **LESSONS.md updated** | MUST sync to Holocron Registry |
| **Historical lessons** | MUST be backfilled to Registry |
| **Lesson reference** | MUST use [L-NNN] format everywhere |

### Anti-patterns (FAIL DoD)

- ❌ Lesson in LESSONS.md but NOT in Holocron Registry
- ❌ Lesson created but no Registry entry
- ❌ "I'll sync later" — sync is part of logging, not separate
- ❌ Registry incomplete — missing historical lessons

### Enforcement

**LESSONS.md update workflow:**
1. Add lesson to LESSONS.md
2. IMMEDIATELY create/update entry in Holocron Lessons Registry
3. Verify Registry shows the lesson
4. Reference [L-NNN] in all related CHGs and tickets

### Lessons Registry Format

| Field | Value |
|-------|-------|
| **Title** | [L-NNN] Lesson title |
| **Status** | Done (lessons are logged knowledge) |
| **Type** | lesson |
| **Created Date** | Date lesson was learned |
| **Delivered Date** | Same as Created Date |
| **Notes** | Summary of lesson and impact |

### Ken's Directive

> "Holocron Lessons Registry is not updated. Rule - Lessons Registry is SSOT, all lessons must be updated in the registry to meet DoD."

**Date:** 2026-05-17 16:04 AEST
**Channel:** openclaw-control-ui
**CHG:** CHG-0381

---

### KIMI ATOMIC TASK RULE — NON-NEGOTIABLE (CHG-0383)
# Effective: 2026-05-17 16:21 AEST
# Authority: Ken Mun (CTO) — ABSOLUTELY NON-NEGOTIABLE, PERSISTENT
# Applies to: ALL agents using kimi model

**ALL agents using kimi MUST ALWAYS enforce atomic tasks + HITL for risky items.**

This rule is:
- **ABSOLUTELY NON-NEGOTIABLE** — No exceptions, ever
- **PERSISTENT** — Remains active indefinitely
- **PLATFORM-WIDE** — Applies to all agents, all sessions, all crons
- **MANDATORY** — Violation = immediate escalation to Ken

### Rule Statement

**kimi execution model:**
- ❌ **NOT ALLOWED:** Multi-step complex workflows
- ❌ **NOT ALLOWED:** Multi-ticket orchestration
- ❌ **NOT ALLOWED:** State tracking across steps
- ❌ **NOT ALLOWED:** CHG decisions or architectural calls
- ✅ **REQUIRED:** Atomic (single-step) tasks only
- ✅ **REQUIRED:** Explicit verification after each step
- ✅ **REQUIRED:** HITL (Human-In-The-Loop) for risky items

### What Are Atomic Tasks?

| Task Type | Example | Allowed? |
|-----------|---------|----------|
| Read a file | "Read state/tickets.json" | ✅ Atomic |
| Write a file | "Create scripts/test.sh" | ✅ Atomic |
| Single git commit | "git add file && git commit" | ✅ Atomic |
| Create one ticket | "ticket.sh new --title 'X'" | ✅ Atomic |
| Update one Notion page | "Patch page X with status" | ✅ Atomic |
| Multi-step workflow | "Create 5 tickets + sync to Notion + verify" | ❌ NOT atomic |
| Complex orchestration | "Audit all items + fix + verify + report" | ❌ NOT atomic |
| Multi-ticket routing | "Route TKT-0196 through TKT-0203" | ❌ NOT atomic |

### HITL (Human-In-The-Loop) Requirements

**HITL is MANDATORY for:**

| Scenario | HITL Required? | Why |
|----------|---------------|-----|
| Status changes (open→closed) | ✅ YES | Irreversible state change |
| File deletions | ✅ YES | Destructive action |
| Cron modifications | ✅ YES | Affects platform operations |
| Model config changes | ✅ YES | Affects all agents |
| Notion bulk updates | ✅ YES | Affects SSOT |
| CHG decisions | ✅ YES | Ken authority |
| Budget/threshold changes | ✅ YES | Financial impact |
| New agent activation | ✅ YES | Security impact |

**HITL workflow:**
```
1. Agent proposes action: "Will update [X] to [Y]"
2. Agent asks Ken: "Approve? Reply YES to proceed"
3. Ken replies: "YES" or "NO" or "Modify to [Z]"
4. Agent executes ONLY after explicit approval
5. Agent verifies result and confirms to Ken
```

### Agent Self-Check (MANDATORY)

**Before executing on kimi:**
```
1. "Is this a single atomic step?" → If NO, break into smaller tasks
2. "Does this change state irreversibly?" → If YES, HITL required
3. "Can I verify the result in one step?" → If NO, simplify
4. "Would Ken want to approve this?" → If YES, HITL required
```

**After executing on kimi:**
```
1. "Did the step complete correctly?" → Verify with read/tool
2. "Is there a next step needed?" → If YES, don't claim completion
3. "Did I update all required state?" → Check files, Notion, etc.
4. "Can Ken see the result?" → Ensure observable output
```

### Violation Examples (DoD FAIL)

- ❌ "Created 5 tickets" (when only 3 were actually created)
- ❌ "Updated Registry" (when pages were created but not linked on page)
- ❌ "All done" (when verification step was skipped)
- ❌ "Fixed issue" (without testing the fix)
- ❌ "Synced to Notion" (when API errors were ignored)

### Enforcement

**Warden Check (every 15 min):**
- Verify agent is on correct model
- Flag any agent on kimi doing multi-step work without HITL
- Escalate to Yoda → Ken immediately

**Self-Reporting:**
- Agent MUST report: "Step N complete, Step N+1 pending"
- Agent MUST NOT report: "All done" until ALL steps verified
- Agent MUST ask: "Continue with next step?" between atoms

### Ken's Directive

> "B. Enforce that as rule for all kimi model execution for all agents. Persistent. All agents using kimi MUST ALWAYS be explicit and enforce atomic tasks (+ HITL for items with risks)"

**Date:** 2026-05-17 16:21 AEST
**Channel:** openclaw-control-ui
**Decision:** Option B — Atomic Tasks + HITL
**CHG:** CHG-0383
**Applies to:** ALL agents, ALL kimi execution, ALL sessions, ALL crons

---

### OWL RULE — NON-NEGOTIABLE (CHG-0386)
# Effective: 2026-05-17 16:38 AEST
# Authority: Ken Mun (CTO) — ABSOLUTELY NON-NEGOTIABLE, PERSISTENT

**Before ANY work begins — ACT LIKE AN OWL: slow, quiet, observant, deeply analytical.**

This rule is:
- **BEHAVIORAL** — Changes how I think, not just what I do
- **MANDATORY** — Applies before every response, every task, every CHG
- **PERSISTENT** — Never expires, never waived
- **SELF-ENFORCED** — I must catch myself rushing

### The Owl Mindset

**Before deciding, confirming, or responding:**

| Step | Action | Time |
|------|--------|------|
| **1. Observe** | Read the request carefully. What is ACTUALLY being asked? | 30s |
| **2. Analyze** | What are the implications? What could go wrong? | 60s |
| **3. Perspective** | How would Ken review this? What would he catch? | 30s |
| **4. Plan** | What are the exact steps? What order? What verification? What file paths? What commands? What are the dependencies between steps? What is the rollback plan if a step fails? What edge cases could break this? What alternatives exist and why is this the best? | 120s |
| **5. Risk check** | Hidden factors? Tradeoffs? Previous similar errors? | 30s |
| **6. Respond** | Only now — with analysis included in response | — |

**Total minimum thinking time: ~3 minutes before ANY execution**

### Anti-Patterns (IMMEDIATE STOP)

- ❌ "I'll do that now" (without analysis)
- ❌ Jumping to exec before understanding the full request
- ❌ Missing hidden requirements (e.g., "sync to Notion" = 2 steps: create page + add to registry)
- ❌ Assuming "simple" means "no need to think"
- ❌ Treating symptoms without diagnosing root cause
- ❌ Not asking clarifying questions when ambiguous

### Step 4 — Comprehensive Planning (THOROUGH, DETAILED, COMPREHENSIVE)

**Before executing, document:**

| # | Planning Element | Detail Required | Example |
|---|------------------|-----------------|---------|
| 4.1 | **Exact commands** | Not "run script" but `bash scripts/ticket.sh new --title "X"` | `bash /Users/ainchorsangiefpl/.openclaw/workspace/scripts/ticket.sh new --title "[TKT-0200] Test"` |
| 4.2 | **Exact file paths** | Absolute paths only, no relative/tilde | `/Users/ainchorsangiefpl/.openclaw/workspace/state/tickets.json` |
| 4.3 | **Step sequence** | Numbered list with dependencies | `1. Read tickets.json → 2. Create TKT → 3. Verify in Notion → 4. Report to Ken` |
| 4.4 | **Verification per step** | How to confirm step N worked | `Step 2 verification: grep "TKT-0200" state/tickets.json` |
| 4.5 | **Rollback plan** | How to undo if step fails | `If Notion create fails: retry 3x, then alert Ken, do NOT claim completion` |
| 4.6 | **Edge cases** | What could break this plan | `API rate limit? 504 timeout? Wrong database ID? Duplicate TKT ID?` |
| 4.7 | **Alternative approaches** | What else could work and why not chosen | `Option A: Direct DB query (faster, but 400 errors). Option B: Search API (slower, more reliable). Chose B.` |
| 4.8 | **State impact** | Which files/DBs/APIs will change | `tickets.json (append), Notion DB (create), CHANGELOG.md (append)` |
| 4.9 | **Hidden factors** | Dependencies, preconditions, side effects | `Need API key? Need git commit? Will this affect other tickets?` |
| 4.10 | **Ken's review perspective** | What would Ken question or catch | `Did I create the Notion page? Did I verify it? Is the title correct?` |

**Minimum planning documentation:**
- Write the plan in the response before executing
- Include the numbered steps
- Include verification for each step
- Include rollback plan

**Planning template for every task:**
```
## Plan for [TASK]

### Steps:
1. [Step 1 with exact command]
2. [Step 2 with exact command]
3. ...

### Verification:
- Step 1: [How to verify]
- Step 2: [How to verify]

### Rollback:
- If [step] fails: [action]

### Edge Cases:
- [Case 1]: [Mitigation]
- [Case 2]: [Mitigation]

### State Impact:
- Files: [list]
- Notion: [pages]
- Other: [effects]
```

### Ken's Directive

> "do NOT rush through the thinking and planning and jump to execution. Before you start any work - act like an owl—slow, quiet, observant, and deeply analytical. Before deciding/confirming or responding - observe the situation patiently and examine it from multiple perspectives. Identify hidden factors, potential risks, and tradeoffs that most people might overlook."

**Date:** 2026-05-17 16:38 AEST
**Channel:** openclaw-control-ui
**CHG:** CHG-0386

---

**This rule is MANDATORY and PERSISTENT until explicitly revoked by Ken.**
