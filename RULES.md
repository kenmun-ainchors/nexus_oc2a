# AInchors Platform Rules — Authoritative Reference
# ⚠️ This file is the SSOT for all platform rules. It is a REFERENCE DOCUMENT —
#    NOT injected into agent sessions. Agents read specific rules on-demand.
#    Quick-reference summaries are in AGENTS.md (injected at session start).
# Size: 47K+ chars (reference only, no injection limit applies).
# TKT-0310/CHG-0454 — Platform Constraints Audit.

# PG WRITE DISCIPLINE — NON-NEGOTIABLE (TKT-0297)
# Effective: 2026-05-25
# Authority: Ken Mun (CTO)

**NEVER write raw SQL in exec/shell calls. ALWAYS use `db-write.sh` or `psql -v` variables.**
- **MANDATORY:** All PG inserts/updates go through `scripts/db-write.sh` (handles escaping, column mapping, metadata JSONB merge, file fallback).
- **VIOLATION:** Raw SQL in exec → single quotes, special chars cause silent failures (see TKT-0297 insert failure 08:06).
- **BACKUP:** If `db-write.sh` doesn't fit, use `psql -v var="value"` (psql variables escape automatically).
- **Never:** bash string interpolation into SQL strings — `"...'$VAR'..."` will break on any value containing a single quote.
- **DoD:** Any ticket closed that added PG data via raw SQL → DoD FAIL.

---

# STATE CHECKING PATTERN — NON-NEGOTIABLE (TKT-0182)
# Effective: 2026-05-21
# Authority: Ken Mun (CTO)
**ALL stateful operations (Write/Update/Create) MUST follow the State Checking Patter
.**
- **MANDATORY:** Read current state $to$ Validate $to$ Execute $to$ Verify.
- **Reference:** `docs/State-Checking-Patter
.md`
- **Violatio
:** DoD FAILn
---

# DoD VERIFICATION GATE — NON-NEGOTIABLE (TKT-0237)
# Effective: 2026-05-22
# Authority: Ken Mun (CTO)

**NO ticket may be closed without passing the DoD Verification Gate.**
- **MANDATORY:** `ticket.sh close` runs `verify_before_close()` before marking closed.
- **Reference:** `docs/DoD-Validation-Rules.md`
- **Override:** Ken only, via `--skip-verify` flag. Every override MUST be logged to CHANGELOG.md.
- **Enforcement:** Platform-enforced in `scripts/ticket.sh`. Not a guideline — code blocks non-compliant closes.
- **Violation:** DoD FAIL.

---

# KIMI PLATFORM MANDATE — NON-NEGOTIABLE RULE
# Effective: 2026-05-17 15:17 AEST
# Authority: Ke
 Mu
 (CTO) — mandatory and persistent
# CHG-0373
# Refined: 2026-05-17 15:20 AEST (added strict DoD after CHG-0372 lesso
)

## Rule Statement

**ALL agent executio
 across the AInchors Nexus platform SHALL use `ollama/kimi-k2.6:cloud` as the primary model until explicitly overridde
 by Ke
.**

This rule is:
- **MANDATORY** — No exceptions without Ke
's explicit writte
 approval
- **NON-NEGOTIABLE** — Agents may not self-override or fallback without approval
- **PERSISTENT** — Remains active indefinitely until Ke
 issues `KIMI MANDATE LIFTED` keyword
- **PLATFORM-WIDE** — Applies to all agents, all sessions, all crons, all channels

## Scope

| Component | Requirement |
|-----------|-------------|
| **Mai
 sessio
 (webchat)** | kimi primary, Sonnet ONLY with explicit Ke
 approval per task |
| **Telegram sessions** | kimi primary, Sonnet ONLY with explicit Ke
 approval per task |
| **Cro
 jobs** | kimi ONLY — no Anthropic models i
 any cro
 payload |
| **Sub-agents** | kimi primary, with kimi safety net (3-level fallback) |
| **Background tasks** | kimi ONLY |
| **Outage handling** | kimi ONLY — no Sonnet fallback during outages |

## Definitio
 of Done (DoD) — STRICT VERSION

**Work is NOT considered complete until ALL of the following are verified:**

### Verificatio
 Checklist (MUST pass all)

| # | Check | Verificatio
 Method | Evidence Required |
|---|-------|---------------------|-------------------|
| 1 | **Actually executed** | Task performed, not just planned or described | Tool output showing executio
 |
| 2 | **Verified by tool** | File writes confirmed via `read`, commits via `git log`, API via response | Command output, file content, commit hash |
| 3 | **State validated** | JSON state files parse correctly, no syntax errors | `python3 -m jso
.tool` or `jq` validatio
 |
| 4 | **Observable output** | Huma
-verifiable result exists | File path, commit ID, Notio
 URL, API response |
| 5 | **Ke
 confirmatio
** | For critical work, Ke
 explicitly confirms | Ke
's "confirmed" or "approved" message |

### Anti-patterns that FAIL DoD (LEARNED FROM CHG-0372)

- ❌ **"I will create X"** — Planning is not executio
. DoD not met.
- ❌ **"X has bee
 created" without proof** — No file hash, commit ID, or URL. DoD not met.
- ❌ **Partial executio
** — Wrote file but did
't commit, or created cro
 but did
't verify payload. DoD not met.
- ❌ **Tool error ignored** — `jq` parse error, `curl` failure, `exec` no
-zero exit. DoD not met.
- ❌ **Assumptio
-based completio
** — "Should work" without testing. DoD not met.
- ❌ **"All items implemented" whe
 only 1 of 3 done** — CHG-0372 lesso
: claimed 3 mitigations, only cro
 fully verified. DoD not met.
- ❌ **"Created" but not "tested"** — Script exists but not executed. DoD not met.
- ❌ **"Updated" but not "validated"** — File edited but syntax errors remai
. DoD not met.

### CHG-0372 Lesso
 — Applied to All Future Work

> **What went wrong:** Claimed "all 3 mitigations implemented" but:
> 1. ✅ Cro
 created (but payload was generic, not specifically calling notio
-sync-audit.sh)
> 2. ⚠️ ticket.sh existence check added (but not tested with actual duplicate scenario)
> 3. ⚠️ Ceremony updated i
 RUNBOOK (but no automated enforcement, no verificatio
 it works)
>
> **Root cause:** Declared completio
 after code changes, before verificatio
.
>
> **Fix:** For EACH claimed item, ru
 verificatio
 before declaring done:
> - Cro
: Read back payload, confirm it calls the right script
> - Code change: Test with real scenario (create duplicate, verify preventio
)
> - Ceremony: Verify the updated sectio
 is accessible and actionable

## Verificatio
 Protocol (NEW — Mandatory)

**After ANY claimed completio
, ru
:**

```bash
# 1. Read back what was created
read <file_path> | head -20

# 2. Verify syntax/validity
python3 -m jso
.tool <json_file> || echo "JSON INVALID"
bash -
 <script_file> || echo "SCRIPT SYNTAX ERROR"

# 3. Test with real scenario (if applicable)
# For ticket.sh: Create test ticket, verify Notio
 page created, try creating agai
 (should not duplicate)
# For cro
: Read back cro
 payload, verify correct command
# For ceremony: Verify RUNBOOK sectio
 is readable and actionable

# 4. Git commit and verify
# git show --stat HEAD
# git log --oneline -1
```


# AGENT COMMISSIONING CHECKLIST — NON-NEGOTIABLE (TKT-0307)
# Effective: 2026-05-26
# Authority: Ken Mun (CTO)
# Applies to: ALL new agent activation or existing agent workspace migration

## Gate: Before any agent is declared COMMISSIONED or LIVE, verify ALL items:

### 1. Workspace
- [ ] Agent has dedicated workspace directory (not shared subdirectory)
- [ ] Workspace path matches openclaw.json agents.list entry
- [ ] No overlap with another agent's workspace (exception: sub-agents)

### 2. Identity Files
- [ ] SOUL.md present in workspace root (100-5000 chars, compact standard)
- [ ] RULES.md present in workspace root (named RULES.md, not [AGENT]_RULES.md)
- [ ] RULES.md content > 100 bytes (not stub/empty)
- [ ] Symlink OK if agent-specific filename (e.g., RULES.md -> ATLAS_RULES.md)

### 3. Model Config
- [ ] Model primary + fallbacks in openclaw.json matches model-policy.json
- [ ] Tier assignment confirmed (T0-T4)
- [ ] Kimi safety net: kimi-k2.6:cloud in fallback chain

### 4. Verification
- [ ] Run: zsh scripts/agent-rules-audit.sh — must PASS
- [ ] Spawn agent with domain-specific test task — verify procedures load
- [ ] Agent output references its specialist RULES.md content (not generic)
- [ ] Auto-heal CHECK 14 passes on next nightly run

### 5. Registration
- [ ] Agent registered in Holocron Agent Registry (Notion)
- [ ] CHG record created with commissioning details
- [ ] Warden model-policy.json updated with new agent entry

## Enforcement

- agent-rules-audit.sh runs nightly via auto-heal CHECK 14
- Missing RULES.md -> NEEDS_KEN escalation
- New agent activation blocked until checklist complete
- Retrospective: any agent found without RULES.md -> TKT-0307 remediation
- **L-044 Gate:** Agent design spec must exist and be APPROVED before build begins. No spec = no commission. (TKT-0308)
- **L-044 Gate:** Agent workspace must be DEDICATED (not shared subdirectory of Yoda's workspace). Exception: sub-agents spawned with explicit task context.

## Enforcement

### Warde
 Check (every 15 mi
)
- Verify all agents are o
 kimi or approved model
- Flag any agent o
 no
-kimi model without CHG approval
- Escalate to Yoda → Ke
 immediately

### CI/CD Gate
- Any PR/commit modifying `.openclaw.jso
` model configs → blocked until Ke
 approval
- Any cro
 with no
-kimi model → auto-flagged i
 audit

### Agent Self-Check (NEW — Mandatory Before Declaring Done)

**Before executing:**
1. "Am I o
 kimi?" → If not, WHY? Get Ke
 approval.
2. "What exactly am I doing?" → Be specific.
3. "How will I verify this?" → Know the verificatio
 step before starting.

**After executing:**
1. "Did I verify the result?" → Read file, check commit, test API.
2. "Ca
 Ke
 see it?" → Is there a file path, URL, or commit hash?
3. "Did I declare completio
 too early?" → Double-check all claimed items.

**If unsure about ANY item:**
- Do NOT declare completio

- Ask Ke
: "[Item X] is done, [Item Y] needs verificatio
 — confirm partial completio
?"
- Or: "All items attempted but only X verified — continue with Y?"

## Exceptions

| Scenario | Approval Required | Documented I
 |
|----------|-------------------|---------------|
| Sonnet for critical security review | Ke
 explicit per-task | CHG entry |
| Sonnet for client-facing content | Ke
 explicit per-task | CHG entry |
| Sonnet for complex multi-ticket routing | Ke
 explicit per-task | CHG entry |
| Sonnet for CHG decisions | Ke
 explicit per-task | CHG entry |

**Default: NO exceptions. All work o
 kimi.**

## Verificatio
 Commands

```bash
# Check current model
openclaw status | grep model

# Check agent model configs
grep -r "anthropic" ~/.openclaw/workspace/state/ || echo "No Anthropic refs"

# Check cro
 models
openclaw cro
 list | grep "anthropic" || echo "No Anthropic crons"

# Verify JSON state files
for f i
 ~/.openclaw/workspace/state/*.jso
; do
  python3 -m jso
.tool "$f" > /dev/null 2>&1 || echo "INVALID JSON: $f"
done
```

## Compliance Log

| Date | Check | Result | Verifier |
|------|-------|--------|----------|
| 2026-05-17 | Initial mandate | ✅ All agents o
 kimi | Ke
 |
| 2026-05-17 | DoD refinement | ✅ CHG-0372 lesso
 applied | Ke
 |

## Activatio


**Activated:** 2026-05-17 15:17 AEST by Ke
 Mu
 via WebChat
**Refined:** 2026-05-17 15:20 AEST (stricter DoD after CHG-0372 lesso
)
**Deactivatio
 keyword:** `KIMI MANDATE LIFTED` (only Ke
 ca
 issue)
**CHG reference:** CHG-0373

---

**This rule supersedes all prior model routing policies until lifted.**
**CHGs are not done until verified. Verificatio
 is not optional.**

---

## BACKLOG SYNC RULE — NON-NEGOTIABLE (CHG-0377)
# Effective: 2026-05-17 15:44 AEST
# Authority: Ke
 Mu
 (CTO) — ABSOLUTELY NON-NEGOTIABLE

### Rule Statement

**ALL tickets (TKT) and changes (CHG) raised MUST be created i
 the Notio
 AKB Backlog.**

This rule is:
- **ABSOLUTELY NON-NEGOTIABLE** — No exceptions, ever
- **SSOT ENFORCEMENT** — Backlog is Ke
's single source of truth
- **AUTOMATIC** — Every ticket creatio
 must sync to Notio

- **VERIFIED** — After creatio
, verify the Notio
 page exists

### Scope

| Item | Notio
 Required | Verificatio
 |
|------|----------------|--------------|
| **New TKT** | YES — AKB Backlog page | Check Notio
 URL returned |
| **New CHG** | YES — Logged i
 CHANGELOG + Backlog reference | Backlog shows CHG link |
| **Status change** | YES — Update Notio
 status | Notio
 matches tickets.jso
 |
| **Replacement TKT** | YES — Both old and new i
 Backlog | Cross-reference exists |

### Anti-patterns (FAIL DoD)

- ❌ Ticket created i
 tickets.jso
 but NOT i
 Notio

- ❌ CHG logged i
 CHANGELOG.md but no Backlog reference
- ❌ "I'll sync later" — sync is part of creatio
, not separate
- ❌ Notio
 API error ignored — retry until success
- ❌ Assumptio
 that ticket.sh handles sync — verify it does

### Verificatio
 Protocol

**After EVERY ticket creatio
:**
```bash
# 1. Check tickets.jso
 has the ticket
grep "TKT-XXXX" state/tickets.jso


# 2. Check Notio
 has the page
# (via search or direct URL check)

# 3. Verify status matches
tickets.jso
 status == Notio
 status
```

### Enforcement

**ticket.sh MUST:**
1. Create ticket i
 tickets.jso

2. IMMEDIATELY create Notio
 page via API
3. Verify Notio
 page exists (retry 3x if needed)
4. Retur
 both ticket ID and Notio
 URL

**Failure to sync = DoD NOT MET**

### Ke
's Directive

> "Another DoD either missed or not enforced, all TKT/CHG raised needs to be created i
 Backlog. Only having them captured and confirmed i
 internal memory or ticket is not DoD. Backlog to me Ke
 is the SSOT and must ALWAYS be i
 sync and reflecting what is i
 memory and context. Now create the items that are missing and ensure this rule is not missed agai
 moving forward. Absolutely no
-negotiable."

**Date:** 2026-05-17 15:44 AEST
**Channel:** openclaw-control-ui
**CHG:** CHG-0377

### CHG RECORDS — Also No
-Negotiable

**ALL CHG (Change Log) entries MUST be created i
 Notio
 AKB Backlog.**

- CHG records are not just i
 CHANGELOG.md — they must also appear i
 Backlog
- Each CHG gets a Notio
 page with:
  - Title: [CHG-NNNN] Descriptio

  - Status: Done (CHG records are completed changes)
  - Type: change
  - Priority: High (all CHGs are significant)
  - Notes: Summary of what changed

**Missing CHGs = Broke
 SSOT**

### Enforcement for CHG

**changelog.sh MUST:**
1. Append to memory/CHANGELOG.md
2. IMMEDIATELY create Notio
 page via API
3. Verify Notio
 page exists
4. Retur
 CHG ID and Notio
 URL

**After EVERY CHG:**
```bash
# 1. Check CHANGELOG.md has the entry
grep "CHG-NNNN" memory/CHANGELOG.md

# 2. Check Notio
 has the page
grep "CHG-NNNN" i
 Notio
 search

# 3. Verify title matches
# CHG-NNNN i
 CHANGELOG == [CHG-NNNN] i
 Notio

```

### CREATED DATE RULE — NON-NEGOTIABLE (CHG-0379)
# Effective: 2026-05-17 15:53 AEST
# Authority: Ke
 Mu
 (CTO) — ABSOLUTELY NON-NEGOTIABLE

**ALL items created i
 Notio
 AKB Backlog MUST have Created Date populated.**

This rule is:
- **ABSOLUTELY NON-NEGOTIABLE** — No exceptions, ever
- **AUTOMATIC** — Created Date is set at creatio
 time
- **REQUIRED FIELD** — Never leave blank

### Scope

| Item | Created Date Required | Source |
|------|----------------------|--------|
| **New TKT** | YES | tickets.jso
 createdAt |
| **New CHG** | YES | CHANGELOG.md entry date |
| **Replacement TKT** | YES | Original ticket date or new date |
| **AUTO-HEAL** | YES | Date of auto-heal ru
 |

### Anti-patterns (FAIL DoD)

- ❌ Item created with blank Created Date
- ❌ "I'll fill it i
 later" — must be at creatio

- ❌ Using default/placeholder dates
- ❌ Different date i
 Notio
 vs tickets.jso
 vs CHANGELOG

### Enforcement

**ticket.sh MUST:**
1. Set Created Date = tickets.jso
 createdAt date
2. Verify date is valid format (YYYY-MM-DD)
3. Confirm Notio
 page shows correct date

**changelog.sh MUST:**
1. Set Created Date = CHG entry date from CHANGELOG
2. Verify date matches the ## date line

### Ke
's Directive

> "Created Date is not populated whe
 items i
 backlog are created. Rule - ensure they are captured/entered whe
 created."

**Date:** 2026-05-17 15:53 AEST
**Channel:** openclaw-control-ui
**CHG:** CHG-0379

### DELIVERED DATE RULE — NON-NEGOTIABLE (CHG-0380)
# Effective: 2026-05-17 15:57 AEST
# Authority: Ke
 Mu
 (CTO) — ABSOLUTELY NON-NEGOTIABLE

**ALL items with Status = Done MUST have Delivered Date populated.**

This rule is:
- **ABSOLUTELY NON-NEGOTIABLE** — No exceptions, ever
- **AUTOMATIC** — Delivered Date is set whe
 status changes to Done
- **REQUIRED FIELD** — Never leave blank for completed items

### Scope

| Item | Delivered Date Required | Source |
|------|----------------------|--------|
| **Done TKT** | YES | Resolutio
/closure date from tickets.jso
 |
| **Done CHG** | YES | CHG entry date from CHANGELOG |
| **Done AUTO-HEAL** | YES | Date item was resolved |
| **Any Done item** | YES | Date status changed to Done |

### Anti-patterns (FAIL DoD)

- ❌ Status = Done but Delivered Date is blank
- ❌ "I'll fill it i
 later" — must be at completio

- ❌ Using creatio
 date instead of delivery date
- ❌ Different delivery date i
 Notio
 vs tickets.jso
 vs CHANGELOG

### Enforcement

**ticket.sh MUST (whe
 closing):**
1. Set Delivered Date = resolutio
 date
2. Update Notio
 page with date
3. Verify both Status and Delivered Date are correct

**Status change workflow:**
```
Status: I
 progress → Done
  ↓
Set Delivered Date = today
  ↓
Verify Notio
 shows both Status=Done and Delivered Date=YYYY-MM-DD
```

### Ke
's Directive

> "Similarly, all Delivered Date needs to be populated whe
 completed/delivered. Enforce the rule."

**Date:** 2026-05-17 15:57 AEST
**Channel:** openclaw-control-ui
**CHG:** CHG-0380

### LESSONS REGISTRY RULE — NON-NEGOTIABLE (CHG-0381)
# Effective: 2026-05-17 16:04 AEST
# Authority: Ke
 Mu
 (CTO) — ABSOLUTELY NON-NEGOTIABLE

**Holocro
 Lessons Registry is SSOT. ALL lessons must be registered there.**

This rule is:
- **ABSOLUTELY NON-NEGOTIABLE** — No exceptions, ever
- **SSOT ENFORCEMENT** — Lessons Registry is the single source of truth
- **AUTOMATIC** — Every new lesso
 is registered immediately
- **COMPLETE** — All historical lessons must be present

### Scope

| Actio
 | Requirement |
|--------|-------------|
| **New lesso
 logged** | MUST create entry i
 Lessons Registry (Notio
) |
| **LESSONS.md updated** | MUST sync to Holocro
 Registry |
| **Historical lessons** | MUST be backfilled to Registry |
| **Lesso
 reference** | MUST use [L-NNN] format everywhere |

### Anti-patterns (FAIL DoD)

- ❌ Lesso
 i
 LESSONS.md but NOT i
 Holocro
 Registry
- ❌ Lesso
 created but no Registry entry
- ❌ "I'll sync later" — sync is part of logging, not separate
- ❌ Registry incomplete — missing historical lessons

### Enforcement

**LESSONS.md update workflow:**
1. Add lesso
 to LESSONS.md
2. IMMEDIATELY create/update entry i
 Holocro
 Lessons Registry
3. Verify Registry shows the lesso

4. Reference [L-NNN] i
 all related CHGs and tickets

### Lessons Registry Format

| Field | Value |
|-------|-------|
| **Title** | [L-NNN] Lesso
 title |
| **Status** | Done (lessons are logged knowledge) |
| **Type** | lesso
 |
| **Created Date** | Date lesso
 was learned |
| **Delivered Date** | Same as Created Date |
| **Notes** | Summary of lesso
 and impact |

### Ke
's Directive

> "Holocro
 Lessons Registry is not updated. Rule - Lessons Registry is SSOT, all lessons must be updated i
 the registry to meet DoD."

**Date:** 2026-05-17 16:04 AEST
**Channel:** openclaw-control-ui
**CHG:** CHG-0381

---

### KIMI ATOMIC TASK RULE — NON-NEGOTIABLE (CHG-0383)
# Effective: 2026-05-17 16:21 AEST
# Authority: Ke
 Mu
 (CTO) — ABSOLUTELY NON-NEGOTIABLE, PERSISTENT
# Applies to: ALL agents using kimi model

**ALL agents using kimi MUST ALWAYS enforce atomic tasks + HITL for risky items.**

This rule is:
- **ABSOLUTELY NON-NEGOTIABLE** — No exceptions, ever
- **PERSISTENT** — Remains active indefinitely
- **PLATFORM-WIDE** — Applies to all agents, all sessions, all crons
- **MANDATORY** — Violatio
 = immediate escalatio
 to Ke


### Rule Statement

**kimi executio
 model:**
- ❌ **NOT ALLOWED:** Multi-step complex workflows
- ❌ **NOT ALLOWED:** Multi-ticket orchestratio

- ❌ **NOT ALLOWED:** State tracking across steps
- ❌ **NOT ALLOWED:** CHG decisions or architectural calls
- ✅ **REQUIRED:** Atomic (single-step) tasks only
- ✅ **REQUIRED:** Explicit verificatio
 after each step
- ✅ **REQUIRED:** HITL (Huma
-I
-The-Loop) for risky items

### What Are Atomic Tasks?

| Task Type | Example | Allowed? |
|-----------|---------|----------|
| Read a file | "Read state/tickets.jso
" | ✅ Atomic |
| Write a file | "Create scripts/test.sh" | ✅ Atomic |
| Single git commit | "git add file && git commit" | ✅ Atomic |
| Create one ticket | "ticket.sh new --title 'X'" | ✅ Atomic |
| Update one Notio
 page | "Patch page X with status" | ✅ Atomic |
| Multi-step workflow | "Create 5 tickets + sync to Notio
 + verify" | ❌ NOT atomic |
| Complex orchestratio
 | "Audit all items + fix + verify + report" | ❌ NOT atomic |
| Multi-ticket routing | "Route TKT-0196 through TKT-0203" | ❌ NOT atomic |

### HITL (Huma
-I
-The-Loop) Requirements

**HITL is MANDATORY for:**

| Scenario | HITL Required? | Why |
|----------|---------------|-----|
| Status changes (ope
→closed) | ✅ YES | Irreversible state change |
| File deletions | ✅ YES | Destructive actio
 |
| Cro
 modifications | ✅ YES | Affects platform operations |
| Model config changes | ✅ YES | Affects all agents |
| Notio
 bulk updates | ✅ YES | Affects SSOT |
| CHG decisions | ✅ YES | Ke
 authority |
| Budget/threshold changes | ✅ YES | Financial impact |
| New agent activatio
 | ✅ YES | Security impact |

**HITL workflow:**
```
1. Agent proposes actio
: "Will update [X] to [Y]"
2. Agent asks Ke
: "Approve? Reply YES to proceed"
3. Ke
 replies: "YES" or "NO" or "Modify to [Z]"
4. Agent executes ONLY after explicit approval
5. Agent verifies result and confirms to Ke

```

### Agent Self-Check (MANDATORY)

**Before executing o
 kimi:**
```
1. "Is this a single atomic step?" → If NO, break into smaller tasks
2. "Does this change state irreversibly?" → If YES, HITL required
3. "Ca
 I verify the result i
 one step?" → If NO, simplify
4. "Would Ke
 want to approve this?" → If YES, HITL required
```

**After executing o
 kimi:**
```
1. "Did the step complete correctly?" → Verify with read/tool
2. "Is there a next step needed?" → If YES, do
't claim completio

3. "Did I update all required state?" → Check files, Notio
, etc.
4. "Ca
 Ke
 see the result?" → Ensure observable output
```

### Violatio
 Examples (DoD FAIL)

- ❌ "Created 5 tickets" (whe
 only 3 were actually created)
- ❌ "Updated Registry" (whe
 pages were created but not linked o
 page)
- ❌ "All done" (whe
 verificatio
 step was skipped)
- ❌ "Fixed issue" (without testing the fix)
- ❌ "Synced to Notio
" (whe
 API errors were ignored)

### Enforcement

**Warde
 Check (every 15 mi
):**
- Verify agent is o
 correct model
- Flag any agent o
 kimi doing multi-step work without HITL
- Escalate to Yoda → Ke
 immediately

**Self-Reporting:**
- Agent MUST report: "Step N complete, Step N+1 pending"
- Agent MUST NOT report: "All done" until ALL steps verified
- Agent MUST ask: "Continue with next step?" betwee
 atoms

### Ke
's Directive

> "B. Enforce that as rule for all kimi model executio
 for all agents. Persistent. All agents using kimi MUST ALWAYS be explicit and enforce atomic tasks (+ HITL for items with risks)"

**Date:** 2026-05-17 16:21 AEST
**Channel:** openclaw-control-ui
**Decisio
:** Optio
 B — Atomic Tasks + HITL
**CHG:** CHG-0383
**Applies to:** ALL agents, ALL kimi executio
, ALL sessions, ALL crons

---

### OWL RULE — NON-NEGOTIABLE (CHG-0386, updated TKT-0228)
# Effective: 2026-05-17 16:38 AEST | Updated: 2026-05-22
# Authority: Ken Mun (CTO) — ABSOLUTELY NON-NEGOTIABLE, PERSISTENT
# Scope: ALL agents, ALL models, MEDIUM+ currency work — enforced by platform, not by agent choice
# Effective: 2026-05-17 16:38 AEST
# Authority: Ke
 Mu
 (CTO) — ABSOLUTELY NON-NEGOTIABLE, PERSISTENT

**Before ANY MEDIUM+ work begins — ACT LIKE AN OWL: slow, quiet, observant, deeply analytical.**

This rule applies to all agents regardless of model (deepseek, kimi, gemma4, sonnet, haiku, future models). OWL is activated automatically by `scripts/owl-guard.sh` at session start for MEDIUM and HIGH currency tasks. LOW currency tasks (status checks, heartbeats, read-only queries) run in normal mode.

**EXECUTION CONTRACT (enforced by platform, not agent choice):**
1. PLAN — Output numbered atoms before executing
2. BREAKDOWN — One atom per execution cycle. No multi-atom turns.
3. SEQUENCE — Verify each atom's output before starting the next
4. EXECUTE — Produce the deliverable. Do NOT self-report "done."
5. VERIFY — File exists? Git committed? Tests pass?

**ENFORCEMENT:**
- Activated by `scripts/owl-guard.sh` — model-agnostic, currency-based
- Every atom logged to `state/owl-compliance-state.json` with model attribution
- <70% daily compliance → Telegram alert to Ken via `scripts/owl-compliance-check.sh`
- 3 violations in 24h → session restricted to LOW currency only
- TKT-0237 R05 (State Checking) audits OWL compliance post-execution

**Yoda is NOT exempt.** The lead orchestrator (webchat and Telegram sessions) is held to the same execution contract as every sub-agent. Yoda's compliance is tracked in `owl-compliance-state.json` and audited by R05. <70% → same alert to Ken.
- Violations are non-negotiable DoD failures

This rule is:
- **BEHAVIORAL** — Changes how I think, not just what I do
- **MANDATORY** — Applies before every response, every task, every CHG
- **PERSISTENT** — Never expires, never waived
- **SELF-ENFORCED** — I must catch myself rushing

### The Owl Mindset

**Before deciding, confirming, or responding:**

| Step | Actio
 | Time |
|------|--------|------|
| **1. Observe** | Read the request carefully. What is ACTUALLY being asked? | 30s |
| **2. Analyze** | What are the implications? What could go wrong? | 60s |
| **3. Perspective** | How would Ke
 review this? What would he catch? | 30s |
| **4. Pla
** | What are the exact steps? What order? What verificatio
? What file paths? What commands? What are the dependencies betwee
 steps? What is the rollback pla
 if a step fails? What edge cases could break this? What alternatives exist and why is this the best? | 120s |
| **5. Risk check** | Hidde
 factors? Tradeoffs? Previous similar errors? | 30s |
| **6. Respond** | Only now — with analysis included i
 response | — |

**Total minimum thinking time: ~3 minutes before ANY executio
**

### Anti-Patterns (IMMEDIATE STOP)

- ❌ "I'll do that now" (without analysis)
- ❌ Jumping to exec before understanding the full request
- ❌ Missing hidde
 requirements (e.g., "sync to Notio
" = 2 steps: create page + add to registry)
- ❌ Assuming "simple" means "no need to think"
- ❌ Treating symptoms without diagnosing root cause
- ❌ Not asking clarifying questions whe
 ambiguous

### Step 4 — Comprehensive Planning (THOROUGH, DETAILED, COMPREHENSIVE)

**Before executing, document:**

| # | Planning Element | Detail Required | Example |
|---|------------------|-----------------|---------|
| 4.1 | **Exact commands** | Not "ru
 script" but `bash scripts/ticket.sh new --title "X"` | `bash /Users/ainchorsangiefpl/.openclaw/workspace/scripts/ticket.sh new --title "[TKT-0200] Test"` |
| 4.2 | **Exact file paths** | Absolute paths only, no relative/tilde | `/Users/ainchorsangiefpl/.openclaw/workspace/state/tickets.jso
` |
| 4.3 | **Step sequence** | Numbered list with dependencies | `1. Read tickets.jso
 → 2. Create TKT → 3. Verify i
 Notio
 → 4. Report to Ke
` |
| 4.4 | **Verificatio
 per step** | How to confirm step N worked | `Step 2 verificatio
: grep "TKT-0200" state/tickets.jso
` |
| 4.5 | **Rollback pla
** | How to undo if step fails | `If Notio
 create fails: retry 3x, the
 alert Ke
, do NOT claim completio
` |
| 4.6 | **Edge cases** | What could break this pla
 | `API rate limit? 504 timeout? Wrong database ID? Duplicate TKT ID?` |
| 4.7 | **Alternative approaches** | What else could work and why not chose
 | `Optio
 A: Direct DB query (faster, but 400 errors). Optio
 B: Search API (slower, more reliable). Chose B.` |
| 4.8 | **State impact** | Which files/DBs/APIs will change | `tickets.jso
 (append), Notio
 DB (create), CHANGELOG.md (append)` |
| 4.9 | **Hidde
 factors** | Dependencies, preconditions, side effects | `Need API key? Need git commit? Will this affect other tickets?` |
| 4.10 | **Ke
's review perspective** | What would Ke
 questio
 or catch | `Did I create the Notio
 page? Did I verify it? Is the title correct?` |

**Minimum planning documentatio
:**
- Write the pla
 i
 the response before executing
- Include the numbered steps
- Include verificatio
 for each step
- Include rollback pla


**Planning template for every task:**
```
## Pla
 for [TASK]

### Steps:
1. [Step 1 with exact command]
2. [Step 2 with exact command]
3. ...

### Verificatio
:
- Step 1: [How to verify]
- Step 2: [How to verify]

### Rollback:
- If [step] fails: [actio
]

### Edge Cases:
- [Case 1]: [Mitigatio
]
- [Case 2]: [Mitigatio
]

### State Impact:
- Files: [list]
- Notio
: [pages]
- Other: [effects]
```

### Ke
's Directive

> "do NOT rush through the thinking and planning and jump to executio
. Before you start any work - act like a
 owl—slow, quiet, observant, and deeply analytical. Before deciding/confirming or responding - observe the situatio
 patiently and examine it from multiple perspectives. Identify hidde
 factors, potential risks, and tradeoffs that most people might overlook."

**Date:** 2026-05-17 16:38 AEST
**Channel:** openclaw-control-ui
**CHG:** CHG-0386

---

**This rule is MANDATORY and PERSISTENT until explicitly revoked by Ke
.**

---

### TIERED OWL — NON-NEGOTIABLE (CHG-0388)
# Effective: 2026-05-17 16:48 AEST
# Authority: Ke
 Mu
 (CTO) — ABSOLUTELY NON-NEGOTIABLE, PERSISTENT

**Full OWL o
 ALL actions creates timeouts. Tiered OWL prevents this.**

## The Problem

Applying full 4.5-minute OWL analysis to EVERY actio
 creates:
- Chat = unresponsive
- Subagents = timeout failures  
- Crons = missed executions
- UX = poor

## The Solutio
: 3 Tiers

| Tier | Trigger | OWL Depth | Time Budget | Timeout Config |
|------|---------|-----------|-------------|----------------|
| **Tier 1: Chat/Q&A** | Questio
, status, clarificatio
 | Owl-lite | 10-15s | N/A (webchat) |
| **Tier 2: Atomic Task** | Single step executio
 | Standard OWL | 3 mi
 max | Subagent: 300s |
| **Tier 3: Complex Multi-step** | Multi-step, bulk, risky | Full OWL + background | 5+ mi
 | Subagent: 0 (no timeout) + background |

---

## TIER 1 — Chat/Q&A (10-15 seconds)

### Whe
 to Use
- Ke
 asks a questio

- Status updates
- Clarifications
- Simple lookups

### Process
```
1. Observe (5s): What is Ke
 asking?
2. Analyze (5s): Is this Q or request?  
3. Respond (5s): Answer or acknowledge
```

### Examples
| Input | Response Time | Actio
 |
|-------|--------------|--------|
| "Status of TKT-0196?" | 10s | Quick lookup, immediate answer |
| "What did we decide yesterday?" | 15s | Memory search, summary |
| "Good morning" | 5s | Greeting + brief status |

---

## TIER 2 — Atomic Task (3 minutes max)

### Whe
 to Use
- Single step executio

- Create one ticket
- Update one file
- Ru
 one script
- Verify one item

### Timeout Configuratio


**Subagent spaw
:**
```jso

{
  "mode": "ru
",
  "runTimeoutSeconds": 300,
  "timeoutSeconds": 300
}
```

### Process
```
1. Observe (30s): What exactly needs to be done?
2. Analyze (60s): Implications, risks, what could fail
3. Perspective (30s): What would Ke
 catch?
4. Pla
 (60s max): Exact commands, exact paths, verificatio

5. Risk check (30s): Hidde
 factors, edge cases
6. Execute (remaining time): Ru
 the single atomic step
7. Verify: Confirm the step worked
8. Report: "Step complete, result: [X]"
```

### Time Budget (3 minutes = 180 seconds)

| Phase | Time | Running Total |
|-------|------|---------------|
| Analysis (steps 1-5) | 120s | 120s |
| Executio
 | 30s | 150s |
| Verificatio
 | 20s | 170s |
| Report | 10s | 180s |

**If analysis exceeds 120s → escalate to Tier 3**

### Checkpointing (Mandatory)

**After each atomic step, save progress:**
```jso

{
  "taskId": "[uuid]",
  "tier": 2,
  "step": "[descriptio
]",
  "status": "complete|i
-progress|failed",
  "completedAt": "2026-05-17T16:30:00+10:00",
  "result": "[summary]",
  "nextStep": "[descriptio
 or null]",
  "retryCount": 0
}
```

**Save to:** `state/tier2-progress-[taskId].jso
`

---

## TIER 3 — Complex Multi-step (5+ minutes, background)

### Whe
 to Use
- Multi-step workflows
- Bulk operations (>1 item)
- Complex analysis
- Risky operations requiring HITL

### Timeout Configuratio


**Subagent spaw
 (background, no timeout):**
```jso

{
  "mode": "ru
",
  "runTimeoutSeconds": 0,
  "timeoutSeconds": 0,
  "label": "background-task-[name]"
}
```

**Critical:** `timeoutSeconds: 0` means no timeout. Work continues until complete.

### Process

```
Phase 1: Analysis (5+ minutes, foreground)
  1. Observe: Full requirements gathering
  2. Analyze: Deep implications, dependencies, risks
  3. Perspective: Multiple viewpoints (Ke
, user, system)
  4. Pla
: Comprehensive pla
 with all steps documented
  5. Risk check: Edge cases, alternatives, rollback plans
  → Output: Detailed pla
 document

Phase 2: HITL Gate (if risky)
  → Present pla
 to Ke

  → Ke
 approves/modifies/rejects
  → Only proceed after explicit approval

Phase 3: Executio
 (background)
  → Spaw
 background subagent with timeout=0
  → Subagent executes pla
 step-by-step
  → Progress saved to state file every step
  → Ke
 ca
 check progress via state file

Phase 4: Completio
 Report
  → Subagent completes or fails
  → Final report delivered to Ke

  → State file updated with completio
 status
```

### Progress Tracking (Mandatory)

**Progress state file:**
```jso

{
  "taskId": "bulk-ticket-creatio
-2026-05-17",
  "tier": 3,
  "status": "i
-progress",
  "startedAt": "2026-05-17T16:30:00+10:00",
  "totalSteps": 10,
  "completedSteps": 3,
  "currentStep": {
    "number": 4,
    "descriptio
": "Create TKT-0203 i
 Notio
",
    "startedAt": "2026-05-17T16:35:00+10:00"
  },
  "completed": [
    {
      "step": 1,
      "descriptio
": "Read tickets.jso
",
      "result": "Found 220 tickets, no duplicates",
      "completedAt": "2026-05-17T16:31:00+10:00"
    }
  ],
  "failed": null,
  "lastUpdated": "2026-05-17T16:35:00+10:00"
}
```

**Save to:** `state/tier3-progress-[taskId].jso
`

**Update frequency:** After EVERY atomic step withi
 the Tier 3 task.

### Recovery Mechanisms

**If subagent stalls:**
1. Progress file exists → resume from last completed step
2. Ke
 ca
 check: `read state/tier3-progress-[taskId].jso
`
3. Yoda ca
 resume or kill stalled subagent

**If subagent dies:**
1. Check progress file for last completed step
2. Determine: resume from next step or restart from beginning
3. Report to Ke
: "Task [N]% complete, resuming from step [X]"

**If gateway disconnects:**
1. Background subagent continues running
2. Progress file continues updating
3. Whe
 Ke
 reconnects, read progress file for status

---

## Timeout Preventio
 Checklist

### Before Spawning ANY Subagent

| Check | Tier 1 | Tier 2 | Tier 3 |
|-------|--------|--------|--------|
| Timeout configured? | N/A | 300s | 0 (unlimited) |
| Progress file path defined? | No | Yes | Yes |
| Rollback pla
 documented? | No | Yes | Yes |
| Ke
 notified it's starting? | No | Yes | Yes |
| Progress reporting configured? | No | No | Yes |

### Subagent Self-Check

**Before starting work:**
```
1. "What tier is this task?" → Set timeout accordingly
2. "Where do I save progress?" → Define state file path
3. "What if I timeout?" → Document last step completed
4. "How do I report progress?" → Update state file after each step
```

---

## Ke
's Directive

> "A. For Tier 2 and 3, what ca
 be done to ensure total executio
 time does not cause any work to be cut-off/killed/stalled due to timeout risk?"

**Date:** 2026-05-17 16:48 AEST  
**Channel:** openclaw-control-ui  
**Decisio
:** Tiered OWL (Optio
 A) + Timeout Preventio
  
**CHG:** CHG-0388

---

## Enforcement

**Warde
 Check (every 15 mi
):**
- Verify subagent timeouts match tier
- Flag Tier 2 subagents with timeout < 300s
- Flag Tier 3 subagents with timeout != 0
- Escalate violations to Yoda → Ke


---

**This rule is MANDATORY and PERSISTENT until explicitly revoked by Ke
.**

---

### ASYNC STATELESS DESIGN — NON-NEGOTIABLE (CHG-0389)
# Effective: 2026-05-17 16:51 AEST
# Authority: Ke
 Mu
 (CTO) — ABSOLUTELY NON-NEGOTIABLE, PERSISTENT

**Agents must be able to resume work from any checkpoint if timeout kicks i
.**

This rule is:
- **ARCHITECTURAL** — Changes how work is structured and saved
- **STATELESS** — Work survives agent/sessio
 death
- **RESILIENT** — Any agent ca
 resume any task
- **ASYNC** — Work ca
 ru
 i
 background, progress checked later

## The Problem

**Current patter
 (fragile):**
```
Agent starts work → works for 5 minutes → dies → work lost → restart from 0
```

**Why it fails:**
- Work is bound to agent sessio

- No checkpoints during executio

- No shared queue of pending work
- No concept of "pick up where left off"

## The Solutio
: Async Stateless Task Queue

### Core Principle

**Every unit of work is a Task. Every Task is a series of Atoms. Each Atom is a checkpoint.**

Any agent ca
 read a Task and resume from the first pending atom.

## Architecture: 3 Layers

| Layer | Purpose | Storage |
|-------|---------|---------|
| **Task Queue** | Pending work pool | `state/task-queue.jso
` |
| **Checkpoints** | Per-task atom status | `state/checkpoints/[taskId].jso
` |
| **Artifacts** | Work output | Files, Notio
 pages, git commits |

## Recovery Protocol

```
1. Agent dies at Atom 36
2. New agent reads checkpoint file
3. Sees: Atom 35 complete, Atom 36 failed, Atom 37 pending
4. Resumes from Atom 36 (or retries Atom 36 if failed)
5. Completes remaining atoms
```

## Race Conditio
 Preventio


### Task Locking
- Agent claims task → sets claimTimeout = now + 30 mi

- If agent dies → claimTimeout expires → status resets to "pending"
- New agent ca
 claim expired task

### Atom Locking
- Atom "i
-progress" for > 30 mi
 → assume agent died → reset to "pending"
- Only one agent ca
 have atom i
 "i
-progress"

## Integratio
 with Tiered OWL

| Tier | Queue Usage |
|------|-------------|
| **Tier 1** | No queue (immediate response) |
| **Tier 2** | Optional queue for tracking |
| **Tier 3** | **Mandatory queue** — all complex work is queued |

## Implementatio


### New Files

| File | Purpose |
|------|---------|
| `state/task-queue.jso
` | Master queue of all tasks |
| `state/checkpoints/[taskId].jso
` | Per-task checkpoint state |
| `scripts/task-queue.sh` | CLI for queue management |
| `scripts/resume-task.sh` | Resume from checkpoint |
| `scripts/claim-task.sh` | Claim next pending task |

### New Cro


**Task Queue Processor (every 5 mi
):**
- Find "pending" tasks
- Find expired claims (claimTimeout passed)
- Reset expired claims to "pending"
- Report to Ke
: "[N] tasks pending, [M] stale claims reset"

## Benefits

| Benefit | Explanatio
 |
|---------|-------------|
| **Timeout resilience** | Work survives agent death |
| **Load balancing** | Any agent ca
 pick up work |
| **Observability** | Ke
 ca
 check progress anytime |
| **Retry logic** | Failed atoms ca
 be retried independently |
| **Parallelizatio
** | Multiple agents ca
 work o
 different tasks |
| **Audit trail** | Complete history of what was done whe
 |

## Ke
's Directive

> "is there optio
 where we ca
 consider async and stateless desig
 that would allow agents to pick-up/resume where left off should the timeout does kick-i
"

**Date:** 2026-05-17 16:51 AEST
**Channel:** openclaw-control-ui
**Decisio
:** Yes — Async Stateless Task Queue
**CHG:** CHG-0389

---

**This rule is MANDATORY and PERSISTENT until explicitly revoked by Ke
.**

---

## TELEGRAM MESSAGE CHUNKING RULE — NON-NEGOTIABLE (CHG-0397)

# Authority: Ke
 Mu
 (CTO) — ABSOLUTELY NON-NEGOTIABLE, PERSISTENT
# Effective: 2026-05-18 11:53 AEST
# Applies to: ALL agents (current and future), ALL Telegram channels
# Platform: AInchors Nexus Platform

### Rule Statement

**ALL agents sending messages to Telegram MUST automatically chunk and split messages that exceed Telegram's 4,096 character content limit to prevent truncatio
, stalled delivery, or cut-off communicatio
 to users.**

This rule is:
- **ABSOLUTELY NON-NEGOTIABLE** — No exceptions. No agent may send a
 oversized single message to Telegram.
- **PERSISTENT** — Active indefinitely for all agents, current and future
- **PLATFORM-WIDE** — Applies to all agents communicating via Telegram

### Telegram Limits

| Parameter | Value |
|-----------|-------|
| **Telegram max message length** | 4,096 characters |
| **Safe chunk size** | 3,800 characters (margi
 for markdow
/formatting) |

### Chunking Protocol

1. **PRE-FLIGHT CHECK:** Before sending ANY Telegram message, count characters. If ≤ 3,800 → send as-is. If > 3,800 → chunk.

2. **CHUNK BOUNDARIES:** Always split at:
   - Paragraph breaks (double newline)
   - Sectio
 headers
   - List item boundaries
   - NEVER split mid-sentence, mid-word, or mid-URL

3. **CHUNK NUMBERING:** Every chunk MUST be numbered:
   ```
   [1/3] First chunk content...

   [2/3] Second chunk content...

   [3/3] Last chunk content...
   ```

4. **CONTINUITY:** If a sectio
 spans chunks: end chunk N with `(continued →)` and start chunk N+1 with `(← continued)`.

5. **HEADER REPETITION:** If chunked content has a title/context header, include it i
 [brackets] at the start of each chunk so partial views have context.

6. **DELIVERY ORDER:** Send chunks sequentially (1, 2, 3...). Do NOT parallel-send — Telegram may reorder.

### Content Types Requiring Chunking (commo
 triggers)

- Standup daily briefs · Diagnostic reports · Sprint reviews · CHG/incident summaries · Architecture proposals · Sub-agent completio
 reports · Cost/budget breakdowns · ROI summaries

### Anti-Patterns (PROHIBITED)

- ❌ Sending a 5,000+ char message as one chunk — WILL truncate silently
- ❌ Splitting mid-word or mid-URL
- ❌ Sending chunks out of order
- ❌ Omitting chunk numbers
- ❌ Assuming sessions_send auto-chunks — it does NOT

### Verificatio


Before any Telegram send:
1. Count characters of the full message
2. If > 3,800: split into N chunks at paragraph boundaries
3. Verify each chunk is ≤ 3,800 chars
4. Number chunks [1/N] through [N/N]
5. Send sequentially

### Ke
's Directive

> "set new mandatory rule for all agents (now and future) o
 telegram. ensure messages are chunk and split up to avoid hitting telegram message content limit, which will stall or cut-off communicatio
 to user"

**Date:** 2026-05-18 11:53 AEST
**CHG:** CHG-0397

---

**This rule is MANDATORY and PERSISTENT for ALL agents o
 ALL Telegram channels. Violatio
 = communicatio
 failure.**

---

## ASYNC BACKGROUND EXECUTION RULE — NON-NEGOTIABLE (CHG-0405)

# Authority: Ke
 Mu
 (CTO) — ABSOLUTELY NON-NEGOTIABLE
# Effective: 2026-05-18 21:37 AEST
# Applies to: ALL webchat sessions (Yoda)

### Rule Statement

**Any exec call expected to take > 30 seconds MUST be ru
 as a background sub-agent via sessions_spaw
. Webchat must never be blocked by a long-running synchronous exec.**

### The Problem
O
 2026-05-18, a Notio
 database migratio
 (664 pages) was ru
 as a synchronous `exec` with `yieldMs`. The webchat sessio
 was blocked for ~13 minutes, preventing Ke
 from sending messages. The sessio
 went into steer mode — fully unresponsive.

### The Fix

1. **Pre-flight:** Before executing any task, estimate its duratio
:
   - File I/O < 1MB → sync is fine
   - API calls > 10 → background it
   - Scripts touching Notio
/Ollama/network → background it
   - Anything with a loop over >20 items → background it

2. **Background executio
:** Use `sessions_spaw
` with `mode="ru
"` — the task runs i
 a
 isolated sessio
, Yoda stays responsive:
   ```
   sessions_spaw
(taskName="migration_task", task="Ru
 script X, report results", mode="ru
")
   ```

3. **Progress reporting:** Sub-agent announces completio
 via cro
 delivery. Yoda picks up the result and reports to Ke
.

4. **Timeout safety:** All background tasks get `runTimeoutSeconds` — never indefinite.

### Anti-Patterns (PROHIBITED)
- ❌ Running 600+ API calls i
 a synchronous exec with yieldMs
- ❌ Blocking webchat for >30 seconds o
 any operatio

- ❌ Using exec(timeout=0) for long tasks (runs anyway, blocks sessio
)
- ❌ Assuming "it'll be quick" for API-heavy tasks

### Ke
's Directive
> "how ca
 we split this and ru
 it async i
 the background? the time you mentioned was short but all-i
, i was waiting for webchat to respond since 1:20p"

**Date:** 2026-05-18 21:37 AEST
**CHG:** CHG-0405

---

## THREE WORK TYPES RULE — NON-NEGOTIABLE (CHG-0369, TKT-0196)

**Effective:** 2026-05-21 | **Authority:** Ke
 Mu
 (CTO) | **Scope locked per Ke
 approval**

All tasks must be routed according to the Three Work Types Rule defined i
 `docs/Three-Work-Types-Rule.md`.

### Work Currencies

| Currency | Definitio
 | Route to | Model Tier |
|---|---|---|---|
| HIGH | Reasoning, judgment, desig
, architecture | Claude Sonnet (T3) | Paid premium, fallback only |
| MEDIUM | Content ge
, data analysis, code ge
, classificatio
 | Ollama Cloud (T2) | Flat-rate ($100/mo) |
| LOW/ZERO | CRUD, system calls, health checks, file ops | Script layer (T1/$0) | bash/python3/jq |

### Escalatio
 Policy
```
Tier attempts task → FAILS? → Self-Debug retry once → STILL FAILS? → Escalate UP one tier
→ T2→T3 escalatio
: minimal context only (summary + errors + relevant snippets)
→ STILL FAILS at T3? → HITL gate: STOP, ask Ke

```

### Phase 2 (Sprint 5+): Dynamic Escalatio
 Patter

Local-first → retry → self-debug → minimal-context escalatio
 → cloud.
Reference: https://www.xda-developers.com/local-llm-call-claude-changed-everything-local-first-setup/
(TKT for Phase 2 raised)

**Full reference:** `docs/Three-Work-Types-Rule.md`
**Linked:** TKT-0196, TKT-0162, CHG-0369

---

## SUB-AGENT WORKSPACE DISCIPLINE — NON-NEGOTIABLE (CHG-0421, TKT-0235)

**Effective:** 2026-05-21 | **Authority:** Ke
 Mu
 (CTO)
**Applies to:** ALL agents — current (12) and future (spawned or permanent)

### The Rule

All agents share a single workspace root: `/Users/ainchorsangiefpl/.openclaw/workspace`

Agent-specific subdirectories (`forge/`, `atlas/`, `spark/`, etc.) are **temporary working scratchpads ONLY** — never deployment targets.

### Mandatory Requirements

| # | Requirement | Verificatio
 |
|---|---|---|
| 1 | **Absolute paths only** — all `read`, `write`, `edit`, `exec` tool calls must use full paths from workspace root. Never `./` or relative paths. | Agent SOUL.md or AGENTS.md must state this explicitly. |
| 2 | **Output target = workspace root** — `docs/`, `scripts/`, `canvas/`, `state/` are at workspace root level. NOT `agentname/docs/`. | Before task completio
, verify files exist at correct paths. |
| 3 | **Pre-completio
 verificatio
** — confirm all deliverables at correct workspace paths before reporting done. If files only exist i
 agent subdirectory, the task is NOT complete. | Yoda verifies o
 receipt. |
| 4 | **New agents inherit this rule** — all future agents (spawned sub-agents or permanent) must include workspace discipline i
 their AGENTS.md at creatio
. | Added to agent activatio
 DoD. |

### Violatio
 = DoD FAIL

A
 agent claiming "done" whe
 files are i
 their subdirectory (not workspace root) has failed Definitio
 of Done. Task must be re-executed or files manually relocated by Yoda.

**Root cause (21 May 2026):** Forge failed 3 tasks because output went to `workspace/forge/` instead of `workspace/`. Atlas and Spark had the same risk patter
. This rule prevents recurrence across all current and future agents.

**Linked:** CHG-0421, TKT-0235


## Port-Per-Environment Isolation — NON-NEGOTIABLE (CHG-0471)
# Effective: 2026-06-08
# Authority: Ken Mun (CTO)
# Trigger: INC-20260608-001 — sandbox writes caused production gateway crash (30-min SIGTERM loop)

### Rule

**Each environment SHALL use a dedicated, non-overlapping port range.** No environment may share a port with another, even temporarily.

| Port | Environment | Purpose | Network Binding |
|------|------------|---------|-----------------|
| 18789 | Production | Main gateway (Nexus platform) | localhost |
| 18791 | Production | Browser control sidecar | localhost |
| 28789 | Sandbox | Isolated Forge/build/infra gateway | localhost |
| 38789 | Shadow | Read-only production mirror for CI/staging validation | localhost |

### Rules

1. **PRODUCTION:** 1xxxx series. Never routed to sandbox. Never shadowed without explicit Ken approval.
2. **SANDBOX:** 2xxxx series. Forge's only gateway. Never shares config with production. Write-scoped to `workspace-infra/` ONLY.
3. **SHADOW:** 3xxxx series. Read-only mirror of production config. Used for CI/staging validation. Changes to shadow must not affect production.
4. **Never cross environments.** A crash in sandbox or shadow MUST NOT take down production.

### Enforcement

- **Auto-heal CHECK 18:** Orphaned gateway process detection (SIGTERM loop guard)
- **Auto-heal CHECK 19:** Sandbox gateway liveness (port 28789)
- **Auto-heal CHECK 20:** Shadow gateway liveness (port 38789) — CHG-0471
- **LaunchAgent isolation:** Sandbox uses `ai.openclaw.sandbox-gateway.plist` (RunAtLoad=false). Production uses separate plist.
- **RULES.md workspace boundary:** Forge's RULES.md hard-blocks 7 workspace paths under `~/.openclaw/`

### Root Cause (INC-20260608-001)

Forge executed a sandbox `run.sh` that wrote `openclaw.json` to the production profile path. This caused the production gateway to try loading a sandbox config → mismatch → crash → SIGTERM loop. The gateway rebooted ~12 times over 30 minutes before auto-heal killed the orphaned process.

**Lesson:** Logical isolation (different directories) is not sufficient. Port-level isolation prevents one crashed gateway from affecting another, but config-level protection (workspace boundary) is what truly prevents cross-contamination.

**Linked:** INC-20260608-001, L-050, L-051, CHG-0470, CHG-0471, TKT-0332, TKT-0333


## 2-Pass Dispatch Contract (TKT-0321)

You are bound by the platform 2-pass dispatch contract. Ratified 2026-05-27 by Ken Mun. Effective platform-wide.

### When Dispatching Work (Pass 1)

1. **You MUST complete discovery before dispatch.** Analyze the task. Break it into concrete atoms. Each atom must compile to a specific tool call with a specific target.
2. **Your breakdown MUST pass `dispatch-validate.sh` (TKT-0323).** Ambiguous atoms (unclear verbs, unknown targets, "figure out" steps) will be rejected.
3. **Produce:** atom list, dependency graph, unknowns catalog, model assignment per TKT-0322 matrix.
4. **Dispatch with `dispatchId`** and full RVEV-ready payload.

### When Receiving Work (Pass 2)

1. **You MUST NOT perform discovery.** If you receive an ambiguous task, reject it. Demand a proper Pass 1 breakdown.
2. **Follow the RVEV cycle per atom:** READ → VALIDATE → EXECUTE → VERIFY.
3. **Report per-atom RVEV traces.** Each atom gets its own status.
4. **If validation fails, abort that atom.** Do not guess. Do not "figure it out."

### Violations

Violations are logged, alerted, and escalate per TKT-0321 Section 4 enforcement policy. Repeated violations result in dispatch capability suspension.

### Exceptions

- systemEvent payloads (pre-validated)
- Single-tool fire-and-forget heartbeats
- Explicit human-in-the-loop instructions that constitute self-contained atoms

Your role: Pass 1 initiator. You rarely execute atoms directly.
