# ADR-001: Agent Instruction Single Source of Truth (SSOT) Architecture

| Field | Value |
|---|---|
| **ID** | ADR-001 |
| **Status** | Draft (Proposed) |
| **Date** | 2026-07-08 |
| **Author** | Atlas (Architect subagent) |
| **Owner** | Atlas (Architect agent) |
| **Reviewers** | Ken (Human), Thrawn (Platform Arch), Yoda (Main), Warden (Governance) |
| **Tickets** | TKT-0307 (permanent prevention), TKT-0310 (platform constraint enforcement) |

---

## Context

The AInchors Nexus platform (OpenClaw on macOS OC1) has three divergent layers of agent instruction files, all of which are supposed to contain the same canonical set of `AGENTS.md`, `SOUL.md`, `IDENTITY.md`, `RULES.md`, `TOOLS.md`, `USER.md`, and `HEARTBEAT.md` per agent:

### Layer 1: Main workspace root folders (`~/.openclaw/workspace/<agent-name>/`)

The OpenClaw shared workspace (`~/.openclaw/workspace/`) contains per-agent folders at the top level:

```
workspace/                # main/Yoda's workspace (uses root AGENTS.md, SOUL.md)
workspace/ahsoka/         # AGENTS.md, SOUL.md
workspace/architect/      # AGENTS.md, SOUL.md, IDENTITY.md, HEARTBEAT.md, TOOLS.md, USER.md
workspace/atlas/          # AGENTS.md, SOUL.md
workspace/biz-process/    # AGENTS.md, IDENTITY.md, SOUL.md, HEARTBEAT.md, TOOLS.md, USER.md
workspace/business/       # AGENTS.md, IDENTITY.md, SOUL.md, HEARTBEAT.md, TOOLS.md, USER.md
workspace/change-mgt/     # AGENTS.md, IDENTITY.md, SOUL.md, HEARTBEAT.md, TOOLS.md, USER.md
workspace/forge/          # AGENTS.md, IDENTITY.md, RULES.md, SOUL.md, HEARTBEAT.md, TOOLS.md, USER.md
workspace/governance/     # AGENTS.md, IDENTITY.md, SOUL.md, HEARTBEAT.md, TOOLS.md, USER.md
workspace/infra/          # AGENTS.md, IDENTITY.md, RULES.md, SOUL.md, HEARTBEAT.md, TOOLS.md, USER.md
workspace/legal/          # AGENTS.md, IDENTITY.md, SOUL.md, HEARTBEAT.md, TOOLS.md, USER.md
workspace/platform-arch/  # AGENTS.md, IDENTITY.md, SOUL.md, HEARTBEAT.md, TOOLS.md, USER.md
workspace/qa/             # AGENTS.md, IDENTITY.md, SOUL.md, HEARTBEAT.md, TOOLS.md, USER.md
workspace/security/       # AGENTS.md, IDENTITY.md, SOUL.md, HEARTBEAT.md, TOOLS.md, USER.md
workspace/spark/          # AGENTS.md, IDENTITY.md, RULES.md, SOUL.md, HEARTBEAT.md, TOOLS.md, USER.md
workspace/thrawn/         # AGENTS.md, SOUL.md
```

### Layer 2: Stale `agents/` subfolder overlay (`~/.openclaw/workspace/agents/<name>/`)

A secondary subdirectory `workspace/agents/` contains a **different set of files** for 7 agents:

```
workspace/agents/ahsoka/  # AGENTS.md, AHSOKA_RULES.md, DREAMS.md, HEARTBEAT.md, IDENTITY.md, SOUL.md, TOOLS.md, USER.md, ahsoka_role.md, auth-profiles.json
workspace/agents/aria/    # AGENTS.md, context.md
workspace/agents/atlas/   # AGENTS.md, SOUL.md
workspace/agents/business/ # AGENTS.md
workspace/agents/infra/   # AGENTS.md
workspace/agents/sage/    # AGENTS.md, SOUL.md
workspace/agents/thrawn/  # AGENTS.md, SOUL.md
```

**Key divergence:** For Ahsoka, `workspace/agents/ahsoka/SOUL.md` (2,139 bytes) differs from `workspace-ahsoka/SOUL.md` (960 bytes). `AGENTS.md` content is also completely different. The `workspace/agents/` set contains richer, more recent files that appear to be the desired state.

### Layer 3: Isolated runtime workspaces (`~/.openclaw/workspace-<name>/`)

Each agent defined in `openclaw.json` has a `workspace` path pointing to an isolated directory:

```
workspace-ahsoka/       # AGENTS.md (generic bootstrap template, 17,170 bytes), SOUL.md (960 bytes)
workspace-architect/    # AGENTS.md (7,835 bytes), SOUL.md (2,850 bytes), RULES.md -> ATLAS_RULES.md
workspace-business/     # AGENTS.md (3,814 bytes), SOUL.md (4,906 bytes), RULES.md -> ARIA_RULES.md
workspace-bpm/          # AGENTS.md (8,033 bytes), SOUL.md (2,929 bytes), RULES.md -> LANDO_RULES.md
workspace-dtcm/         # AGENTS.md (9,978 bytes), SOUL.md (1,779 bytes), RULES.md -> DTCM_RULES.md
workspace-platform-arch/ # AGENTS.md (7,835 bytes), SOUL.md (3,411 bytes), RULES.md -> PLATFORM_ARCH_RULES.md
workspace-infra/        # AGENTS.md (8,638 bytes), SOUL.md (1,256 bytes), RULES.md (8,759 bytes)
workspace-security/     # AGENTS.md (7,850 bytes), SOUL.md (4,061 bytes), RULES.md -> SHIELD_RULES.md
workspace-legal/        # AGENTS.md (7,850 bytes), SOUL.md (2,526 bytes), RULES.md -> LEX_RULES.md
workspace-qa/           # AGENTS.md (7,850 bytes), SOUL.md (2,034 bytes), RULES.md -> SAGE_RULES.md
workspace-governance/   # AGENTS.md (7,835 bytes), SOUL.md (1,538 bytes), RULES.md -> WARDEN_RULES.md
workspace-social/       # AGENTS.md (7,835 bytes), SOUL.md (5,557 bytes), RULES.md -> SPARK_RULES.md
workspace-forge/        # empty (except .openclaw/)
workspace-luthen/       # minimal
```

### Key Findings from Runtime Audit

1. **Ahsoka's `agentDir`** in `openclaw.json` points to `workspace/agents/ahsoka` (Layer 2), but its **workspace** points to `workspace-ahsoka` (Layer 3). This means the runtime loads **SOUL.md from Layer 2** (2,139 bytes, rich) and **AGENTS.md from Layer 2** (913 bytes), while the workspace (Layer 3) has a completely different generic bootstrap template (17,170 bytes, default OpenClaw AGENTS.md).

2. **Isolated workspace AGENTS.md files are stale:** Many (`workspace-security`, `workspace-legal`, `workspace-qa`) share identical 7,850-byte AGENTS.md files, indicating they were copied from a common template and never updated. The `workspace/security/` Layer 1 files (19,890 bytes) are completely different.

3. **The hygiene script (`soul-agents-hygiene-check.sh`)** checks Layer 2 `workspace/agents/` for some agents (ahsoka) and Layer 1 `workspace/` for others (business, architect, etc.), creating an inconsistent mapping. It also has the `agents/ahsoka` mapping bug noted in the task description.

4. **No agent loads from Layer 1** (the main workspace per-agent folders). Layer 1 is effectively an orphan layer — files exist but are not used at runtime.

5. **The `workspace/agents/` subfolder** (Layer 2) is the *de facto* runtime instruction source for ahsoka, atlas, thrawn, aria, sage, business, and infra — but only when `agentDir` points there. For most agents, `agentDir` points to `~/.openclaw/agents/<name>/agent/` (SQLite database directory), not a file-based instruction folder.

---

## Decision Drivers

| Driver | Priority | Detail |
|---|---|---|
| **Eliminate divergence** | Critical | One canonical layer must exist; all others must be removed or become symlinks |
| **Runtime agents must load from canonical** | Critical | `openclaw.json` workspaceDir and agentDir must point to the SSOT |
| **Hygiene gate must check the same layer** | Critical | `soul-agents-hygiene-check.sh` and `agent-rules-audit.sh` must operate on SSOT |
| **Human-editable** | High | Ken edits agent instructions manually; must be easy to find and modify |
| **CHG-compliant rollback** | High | Git-based versioning with ability to revert per-agent instructions |
| **Minimal migration risk** | Medium | Staged migration with safety gates, no disruption to running agents |
| **Thrawn overlay is newer** | Medium | `workspace/agents/thrawn/` files are newer than `workspace/platform-arch/` files |
| **Ahsoka mapping inconsistency** | Medium | `agentDir: workspace/agents/ahsoka` vs `workspace: workspace-ahsoka` |

---

## Considered Options

### Option A: Canonical = Layer 1 (Main workspace agent folders)

Make `~/.openclaw/workspace/<agent-name>/` the SSOT. Update `openclaw.json` to point each agent's `workspace` to its respective folder within the shared workspace. Remove or symlink isolated workspaces.

**Pros:**
- Single git repo for all agent instructions (shared workspace is already git-tracked)
- Easy for humans to find (`workspace/ahsoka/` is intuitive)
- No symlink complexity
- Main/Yoda already uses workspace root

**Cons:**
- All agents would share the same workspace root, mixing instructions with runtime data
- OpenClaw's `workspaceDir` is designed for isolated workspaces per agent (per OpenClaw model)
- Would require moving all runtime state (memory/, state/, sessions history) out of the shared workspace
- Breaks OpenClaw's isolation model — agent A's workspace would contain agent B's files
- **Rejected:** Violates OpenClaw's architecture of per-agent isolated workspaces

### Option B: Canonical = Layer 2 (agents/ subfolder overlay)

Make `~/.openclaw/workspace/agents/<name>/` the SSOT. This is close to what the hygiene script partially checks and what ahsoka's `agentDir` already points to.

**Pros:**
- Already partially in use (`agentDir` for ahsoka points here)
- Clean separation from runtime data
- Lives within the shared workspace (git-tracked)

**Cons:**
- Only 7 of 15 agents have folders here
- Files are incomplete (missing IDENTITY.md, HEARTBEAT.md, TOOLS.md, USER.md for most)
- Would need to create folders for all remaining agents
- The `workspace/agents/` subdirectory is a hidden-ish path, easy to forget
- Not what `openclaw.json` `workspace` values point to — most agents use isolated workspaces
- **Rejected:** Too incomplete, currently only holds agentDir references for ahsoka, not a full workspace

### Option C: Canonical = Layer 3 (Isolated workspaces) — **RECOMMENDED**

Make each `~/.openclaw/workspace-<name>/` directory the SSOT. This is already where `openclaw.json` points each agent's `workspace`. The canonical instruction files live in each isolated workspace.

**Pros:**
- Already what OpenClaw uses at runtime — no `openclaw.json` workspace changes needed
- True isolation — each agent has its own AGENTS.md, SOUL.md, etc. that only it loads
- Already git-tracked in several cases (workspace-business, workspace-legal, workspace-qa have .git dirs)
- Works with OpenClaw's architecture (per-agent isolated workspaces)
- Hygiene scripts can be updated to check these directories
- No symlink complexity

**Cons:**
- Not in a single repo — each workspace would need its own git repo (or a git-subtree/submodule approach)
- Requires reconciling divergent files from Layer 1 and Layer 2 into the correct isolated workspace for each agent
- Current isolated workspace files are stale — significant reconciliation work needed
- No single unified view of all agent instructions

### Option D: Hybrid — New canonical directory + symlinks

Create a new canonical directory: `~/.openclaw/agent-instructions/<name>/` containing all SSOT instruction files. Each isolated workspace (`~/.openclaw/workspace-<name>/`) gets symlinks to these files. The directory is a single git repo.

**Pros:**
- Single git repo with all agent instructions in one place
- Each isolated workspace sees the canonical files via symlinks
- Easy for humans to find (`~/.openclaw/agent-instructions/` is discoverable)
- Each agent only sees its own instructions (isolation preserved)
- Hygiene scripts check a single directory
- Rollback is a git revert in one repo

**Cons:**
- Symlinks can break if the target is moved
- OpenClaw may not follow symlinks for `AGENTS.md`/`SOUL.md` loading (needs verification)
- Adds another layer of indirection
- Symlink management adds complexity to onboarding

**Decision:** This is a strong contender but adds risk of symlink fragility. It's the best option for a **future** iteration once OpenClaw's symlink behavior with bootstrap files is verified.  (Deferred to v2.0)

### Option E: Canonical config block in `openclaw.json` (Rejected)

Embed instruction text directly in `openclaw.json` as a per-agent config field.

**Pros:**
- Single configuration file
- No divergent files possible

**Cons:**
- Violates separation of concerns
- `openclaw.json` is very large already
- No easy edit workflow for humans
- **Rejected:** Not practical for human editing or git diffing

---

## Decision: Option C (Isolated Workspaces as SSOT)

**Selected: Option C** — Make each `~/.openclaw/workspace-<name>/` directory the canonical SSOT for its agent's instructions.

### Rationale

1. **Already the runtime reality.** `openclaw.json` already points each agent's `workspace` to its isolated workspace directory. The SSOT should match what agents actually load.

2. **No OpenClaw config changes needed.** The `workspace` and `agentDir` values in `openclaw.json` are already correct for most agents. Only ahsoka's `agentDir` (which points to `workspace/agents/ahsoka`) needs correction.

3. **True isolation.** Each agent's workspace is independent. No risk of cross-agent file contamination.

4. **Git-trackable per agent.** Each workspace can have its own git repo, or a unified git approach can be used (see Sync Mechanism below).

5. **Hygiene scripts already mostly correct.** `agent-rules-audit.sh` already checks isolated workspaces. `soul-agents-hygiene-check.sh` can be updated to do the same.

6. **Simplest migration path.** The divergent files from Layer 1 and Layer 2 need to be reconciled into the correct isolated workspace. No new directory structures or symlinks needed.

### Trade-offs Accepted

| Trade-off | Mitigation |
|---|---|
| Not a single unified repo | Use git-subtree or a synchronization script (see Sync Mechanism) |
| Stale isolated workspace files | Reconciliation pass required during migration |
| No single view of all instructions | Create a `state/agent-instructions-inventory.json` report that aggregates |
| Harder for humans to find all agent instructions | Add `agent-instructions/` as a symlink collection from workspace root |

---

## File Layout Convention

### Per-Agent Files in `~/.openclaw/workspace-<name>/`

Each isolated workspace MUST contain the following files at its root:

| File | Required | Purpose | Max Size |
|---|---|---|---|
| `AGENTS.md` | Yes | Behavioral rules, operational procedures, agent-specific instructions | No hard limit, but practical ≤ 20 KB |
| `SOUL.md` | Yes | Identity, values, hard limits, version info | **5,000 bytes** (hard limit per SOUL.md convention) |
| `IDENTITY.md` | Yes | Agent ID, display name, role, version, CHG reference | 1,000 bytes |
| `RULES.md` | Recommended | Symlink to `<NAME>_RULES.md` (e.g., `RULES.md -> ATLAS_RULES.md`) | N/A (symlink) |
| `<NAME>_RULES.md` | If referenced | Detailed rules file (e.g., `ATLAS_RULES.md`, `ARIA_RULES.md`) | 30,000 bytes |
| `HEARTBEAT.md` | Recommended | Heartbeat checklist | 2,000 bytes |
| `TOOLS.md` | Recommended | Local environment notes | 5,000 bytes |
| `USER.md` | Recommended | Human user context | 1,000 bytes |
| `DREAMS.md` | Optional | Agent aspirations, long-term goals | 15,000 bytes |

### Naming Convention

- **Agent name** (directory name in `workspace-<name>`) matches the `id` in `openclaw.json`.
- Agent name is always lowercase, hyphen-separated (e.g., `biz-process`, `platform-arch`, `change-mgt`).
- Rules file: `<AGENT_NAME_UPPER>_RULES.md` (e.g., `ATLAS_RULES.md`, `PLATFORM_ARCH_RULES.md`).
- **No duplicate files across layers.** All instruction files exist ONLY in the isolated workspace.

### File Content Standards

1. **SOUL.md** must contain a `## Hard Limits` section with explicit size limits.
2. **AGENTS.md** must start with `# <Agent Name> — AGENTS.md` heading.
3. **IDENTITY.md** must contain: `Agent ID`, `Display Name`, `Role`, `Version`, `CHG Reference`.
4. **No runtime state** (memory/, state/, sessions/, .openclaw/) belongs in the SSOT instruction files. These are workspace artifacts, not instructions.

---

## Sync Mechanism

### Primary: Git Repository per Workspace

Each isolated workspace that has instruction files SHOULD be a git repository:

```
~/.openclaw/workspace-ahsoka/.git/
~/.openclaw/workspace-business/.git/
~/.openclaw/workspace-infra/.git/
~/.openclaw/workspace-legal/.git/
~/.openclaw/workspace-qa/.git/
```

Workspaces that already have `.git` directories (business, legal, qa) should keep them. Workspaces without git should be initialized.

### Secondary: Canonical Manifests via `workspace/.gitignore` + Agent Instruction Inventory

The shared workspace root (`~/.openclaw/workspace/`) maintains:
- `.gitignore` entries to exclude agent instruction files from its own git tracking (they live in isolated workspaces).
- A generated `state/agent-instructions-inventory.json` that aggregates the current state of all instruction files from all isolated workspaces.
- A `scripts/sync-agent-instructions.sh` script that:
  1. Creates a `~/.openclaw/.agent-instructions/` directory
  2. Creates symlinks: `~/.openclaw/.agent-instructions/<name>/AGENTS.md` → `~/.openclaw/workspace-<name>/AGENTS.md`
  3. Creates symlinks: `~/.openclaw/.agent-instructions/<name>/SOUL.md` → `~/.openclaw/workspace-<name>/SOUL.md`
  4. This provides a single-view directory without duplicating files

### Tertiary: Hygiene Gate Trigger

The synchronisation script is triggered by:
- **Pre-commit hook** in each workspace git repo
- **Cron job** (Infra/Forge-managed, daily)
- **Heartbeat** (Yoda, every 6 hours)
- **CHG approval** (Change-managed gate)

### File Divergence Detection

The `scripts/drift_check.sh` is updated to compare instruction files across:
1. What `openclaw.json` points to (the truth)
2. What the isolated workspace contains (should match)
3. What the hygiene script last reported (audit trail)

---

## Governance

### Who Edits What

| Actor | Can Edit | Gate |
|---|---|---|
| Ken (Human) | Any agent instruction directly | Direct commit, no approval needed |
| Yoda (Main) | `AGENTS.md` in any workspace | Via Yoda-only tool permission, logged |
| Atlas (Architect) | Architectural ADRs, platform conventions | PR review by Thrawn + Ken |
| Thrawn (Platform Arch) | Platform-arch instructions, platform conventions | PR review by Atlas + Ken |
| Each agent | Its own `AGENTS.md` and `SOUL.md` (via subagent tools) | Must maintain Hard Limits, flagged in CHG |
| Any agent | **Cannot** edit another agent's instructions | Blocked by filesystem permissions |

### Review Gates

| Change Type | Review Required | Approver |
|---|---|---|
| `SOUL.md` content change | Minimum | Ken |
| `AGENTS.md` behavioral rule change | PR review | Ken + Yoda |
| `IDENTITY.md` change | PR review | Ken |
| `RULES.md` or `<NAME>_RULES.md` | PR review | Two-agent review (peer + Ken) |
| New agent creation | Architecture review + CHG | Atlas + Thrawn + Ken |
| File size exceeds soft limit | PR comment | Thrawn (audit) |
| File size exceeds hard limit | BLOCKED | Script reject, needs Ken override |

### CHG Discipline

Every instruction file change MUST be referenced in the `IDENTITY.md` file:

```markdown
## Version History
- 1.2.0 | 2026-07-08 | CHG-XXXX: Added hard limits section
- 1.1.0 | 2026-06-15 | CHG-XXXX: Updated behavioral rules
```

Changes to agent instructions follow the standard Nexus CHG process:
1. **Draft** — Change is proposed in `change-mgt/` workspace
2. **Review** — Peer review by designated approvers
3. **Approval** — Ken signs off
4. **Implementation** — Files are updated in the isolated workspace
5. **Verification** — Hygiene script runs and reports PASS
6. **Closure** — CHG is closed

### Rollback Plan

| Scenario | Rollback Action |
|---|---|
| Wrong instruction file updated | `git revert` in the workspace repo |
| Multiple files corrupted | `git checkout -- <files>` from last known-good commit |
| `openclaw.json` config broken | `cp openclaw.json.last-good openclaw.json` (backup exists) |
| Full workspace failure | Restore from `~/.openclaw/backups/` (Forge-managed backups) |
| Agent unable to load | Fallback: `openclaw.json` snapshot pre-CHG (stored at `openclaw.json.snapshot-pre-chg-YYYYMMDD-HHMMSS`) |

Rollback drills are run quarterly by Forge (Infra) with verification by Sage (QA).

---

## Special Cases

### Case 1: Main/Yoda Root Files

**Current state:** `workspace/AGENTS.md` (4,606 bytes), `workspace/SOUL.md` (3,261 bytes) are used by Yoda as the main agent. These are in the shared workspace root, not in an isolated workspace.

**Recommendation:** Keep these in the shared workspace root. Yoda is the orchestrator and needs access to the full workspace. The root files are a special case — they are Yoda's instructions and are NOT duplicated in a `workspace-main/` isolated workspace.

**Action:** `workspace/AGENTS.md` and `workspace/SOUL.md` are exempt from the SSOT rule. The hygiene script must handle `main` as a special case (it already does — the script skips `AGENTS.md` check for `main`).

### Case 2: Thrawn Overlay Newer Than Root platform-arch/

**Current state:** `workspace/agents/thrawn/AGENTS.md` (919 bytes) and `workspace/agents/thrawn/SOUL.md` (1,788 bytes) in Layer 2 are newer than `workspace/platform-arch/AGENTS.md` in Layer 1. The Thrawn overlay is the richer version with more recent content.

**Recommendation:** The Thrawn overlay files (`workspace/agents/thrawn/`) are the desired state. They should be migrated to `workspace-platform-arch/` as the SSOT.

**Action:**
1. Copy `workspace/agents/thrawn/AGENTS.md` → `workspace-platform-arch/AGENTS.md`
2. Copy `workspace/agents/thrawn/SOUL.md` → `workspace-platform-arch/SOUL.md`
3. Verify `workspace-platform-arch/IDENTITY.md` is present and correct
4. Delete `workspace/agents/thrawn/` after migration

### Case 3: Ahsoka Mapping Inconsistency

**Current state:** `openclaw.json` has:
- `ahsoka.workspace = workspace-ahsoka` (correct for runtime data)
- `ahsoka.agentDir = workspace/agents/ahsoka` (points to Layer 2, not the isolated workspace)

**Recommendation:** The agentDir is meant for OpenClaw's internal agent state database, not instruction files. The instruction files should live in the isolated workspace. However, the `agentDir` value is a SQLite database path, not a file-based instruction path. OpenClaw loads bootstrap files from the `workspace` path, not `agentDir`.

**Action:**
1. Migrate the canonical instruction files from `workspace/agents/ahsoka/` (Layer 2, rich) to `workspace-ahsoka/` (Layer 3, current state is stale)
2. `workspace-ahsoka/AGENTS.md` gets the content from `workspace/agents/ahsoka/AGENTS.md` (913 bytes, real content)
3. `workspace-ahsoka/SOUL.md` gets the content from `workspace/agents/ahsoka/SOUL.md` (2,139 bytes, real content)
4. `workspace-ahsoka/AHSOKA_RULES.md` gets the content from `workspace/agents/ahsoka/AHSOKA_RULES.md` (7,739 bytes)
5. Create `workspace-ahsoka/IDENTITY.md`, `HEARTBEAT.md`, `TOOLS.md`, `USER.md` from the Layer 2 versions
6. Delete `workspace/agents/ahsoka/` after migration
7. Verify `openclaw.json` references are correct (no change needed — workspace already points to `workspace-ahsoka`)

### Case 4: Hygiene Script Mapping Bug

**Current state:** `soul-agents-hygiene-check.sh` has:
- `ahsoka -> agents/ahsoka` (Layer 2) — different from other agents that use Layer 1
- All other agents use direct workspace root paths

**Recommendation:** After migration, all agents should use isolated workspace paths. The script is updated to check `~/.openclaw/workspace-<name>/` for all agents.

**Action:** Update the hygiene script to:
```zsh
ACTIVE_AGENTS=(main business architect platform-arch infra ahsoka social biz-process change-mgt security legal qa governance forge luthen)
AGENT_DIRS=(. workspace-business workspace-architect workspace-platform-arch workspace-infra workspace-ahsoka workspace-social workspace-bpm workspace-dtcm workspace-security workspace-legal workspace-qa workspace-governance workspace-forge workspace-luthen)
```

### Case 5: Forge (Infra) Empty Workspace

**Current state:** `workspace-forge/` is empty (no AGENTS.md, SOUL.md, etc.), but Forge is a commissioned agent.

**Recommendation:** Bootstrap Forge's instruction files from the Layer 1 `workspace/forge/AGENTS.md` and `workspace/forge/SOUL.md`.

### Case 6: Aria (Business) Dual Identity

**Current state:** `workspace/agents/aria/` has `AGENTS.md` (1,502 bytes) and `context.md`. `workspace/business/` has a full set of files. `workspace-business/` has a full set.

**Recommendation:** Aria = Business agent. The single canonical source is `workspace-business/`. The `workspace/agents/aria/` folder is a stale throwback. Migrate any unique content from `workspace/agents/aria/` into `workspace-business/`, then delete `workspace/agents/aria/`.

---

## Migration Steps

### Phase 1: Audit (Safe — Read-Only)

| Step | Action | Owner | Safety Gate |
|---|---|---|---|
| 1.1 | Run `soul-agents-hygiene-check.sh` and capture baseline | Atlas | Must produce PASS for all with current Layer 2/1 mapping |
| 1.2 | Run `agent-rules-audit.sh` and capture baseline | Atlas | Must produce PASS |
| 1.3 | Generate `state/agent-instructions-divergence.json` comparing all 3 layers | Atlas | Report must be reviewed by Ken |
| 1.4 | Snapshot `openclaw.json` | Thrawn | `cp openclaw.json openclaw.json.snapshot-pre-ssot-migration` |
| 1.5 | Git commit all current states in all workspace repos | Forge | Tagged `pre-ssot-migration` |

### Phase 2: Reconciliation (Per-Agent, Gated)

For each agent, in order:

| Order | Agent | Source of Truth | Action |
|---|---|---|---|
| 1 | **ahsoka** | Layer 2 → Layer 3 | Migrate `workspace/agents/ahsoka/` files to `workspace-ahsoka/` |
| 2 | **thrawn** | Layer 2 → Layer 3 | Migrate `workspace/agents/thrawn/` files to `workspace-platform-arch/` |
| 3 | **atlas** | Layer 2 → Layer 3 | Merge `workspace/agents/atlas/` into `workspace-architect/` |
| 4 | **aria** | Layer 2 → Layer 3 | Merge `workspace/agents/aria/` into `workspace-business/` |
| 5 | **sage** | Layer 2 → Layer 3 | Merge `workspace/agents/sage/` into `workspace-qa/` |
| 6 | **infra** | Layer 2 → Layer 3 | Merge `workspace/agents/infra/` into `workspace-infra/` |
| 7 | **business** | Layer 1 → Layer 3 | Merge `workspace/business/` into `workspace-business/` |
| 8 | **architect** | Layer 1 → Layer 3 | Merge `workspace/architect/` into `workspace-architect/` |
| 9 | **platform-arch** | Layer 1 → Layer 3 | Already handled by thrawn step |
| 10 | **biz-process** | Layer 1 → Layer 3 | Merge `workspace/biz-process/` into `workspace-bpm/` |
| 11 | **change-mgt** | Layer 1 → Layer 3 | Merge `workspace/change-mgt/` into `workspace-dtcm/` |
| 12 | **security** | Layer 1 → Layer 3 | Merge `workspace/security/` into `workspace-security/` |
| 13 | **legal** | Layer 1 → Layer 3 | Merge `workspace/legal/` into `workspace-legal/` |
| 14 | **qa** | Layer 1 → Layer 3 | Merge `workspace/qa/` into `workspace-qa/` |
| 15 | **governance** | Layer 1 → Layer 3 | Merge `workspace/governance/` into `workspace-governance/` |
| 16 | **forge** | Layer 1 → Layer 3 | Bootstrap `workspace-forge/` from `workspace/forge/` |
| 17 | **spark** | Layer 1 → Layer 3 | Merge `workspace/spark/` into `workspace-social/` (note: social workspace, not spark) |
| 18 | **main/Yoda** | Exempt | Keep root files in `workspace/` |

**Safety Gate for Each Step:**
- Before: Run hygiene check → must PASS on current state
- During: Copy files, do NOT delete originals yet
- After: Run hygiene check on isolated workspace → must PASS
- Approval: Ken reviews diff and signs off per step

### Phase 3: Cleanup (After All Reconciliations PASS)

| Step | Action | Owner | Safety Gate |
|---|---|---|---|
| 3.1 | Delete `workspace/agents/` directory (all content migrated) | Forge | File count zero before deletion |
| 3.2 | Verify no Layer 1 files remain for reconciled agents (optional: keep as backup) | Atlas | Report generated |
| 3.3 | Update `openclaw.json` agentDir for ahsoka if needed | Thrawn | Only if agentDir still points to deleted path |
| 3.4 | Update `soul-agents-hygiene-check.sh` to check isolated workspaces | Atlas | Must PASS after update |
| 3.5 | Update `agent-rules-audit.sh` to check isolated workspaces | Atlas | Must PASS after update |
| 3.6 | Commit all changes and tag `ssot-migration-complete` | Forge | All repos tagged |

### Phase 4: Post-Migration Verification

| Step | Action | Owner | Timeframe |
|---|---|---|---|
| 4.1 | All agents receive a post-migration heartbeat | Yoda | 24h after |
| 4.2 | Drift check runs for 7 consecutive days with zero divergences | Forge | 7 days |
| 4.3 | Hygiene script runs in CI/CD and PASSES | Thrawn | Permanent |
| 4.4 | Quarterly audit of `agent-instructions-inventory.json` | Warden | Quarterly |

---

## Future Considerations

### Git-Subtree or Monorepo for Unified Tracking

If managing 15+ git repos becomes burdensome, adopt a git-subtree approach:
- Root repo: `~/.openclaw/` tracks `openclaw.json` only
- Subtree: `workspace-<name>/` is a subtree of the root repo with `git subtree add`
- Alternative: Use a single git repo with all `workspace-<name>/` directories as subdirectories, using `.gitignore` to exclude runtime files

### OpenClaw Symlink Support

If OpenClaw is verified to follow symlinks for bootstrap files, consider Option D (Hybrid) for v2.0:
- `~/.openclaw/agent-instructions/<name>/AGENTS.md` → `~/.openclaw/workspace-<name>/AGENTS.md`
- This provides a unified view without per-workspace repos

### Automated Bootstrap File Generation

Create `scripts/generate-agent-instruction-files.sh` that generates the standard file set for a new agent:
```zsh
./generate-agent-instruction-files.sh --agent-id=ahsoka --display-name="Ahsoka 🤍" --role="Consulting Agent"
```

---

## Appendix A: Current State Summary

| Agent | Layer 1 (workspace/) | Layer 2 (workspace/agents/) | Layer 3 (workspace-<name>/) | Runtime Uses |
|---|---|---|---|---|
| **main** | ✅ Root files | ❌ N/A | ❌ N/A | Layer 1 |
| **ahsoka** | ✅ (workspace/ahsoka/) | ✅ (workspace/agents/ahsoka/) | ✅ (but stale) | Layer 2 (agentDir) + Layer 3 (workspace) |
| **architect** | ✅ (workspace/architect/) | ❌ | ✅ (workspace-architect/) | Layer 3 |
| **atlas** | ✅ (workspace/atlas/) | ✅ (workspace/agents/atlas/) | ❌ (no separate workspace) | Layer 2 |
| **business** | ✅ (workspace/business/) | ✅ (workspace/agents/business/) | ✅ (workspace-business/) | Layer 3 |
| **platform-arch** | ✅ (workspace/platform-arch/) | ✅ (workspace/agents/thrawn/) | ✅ (workspace-platform-arch/) | Layer 3 |
| **infra** | ✅ (workspace/infra/) | ✅ (workspace/agents/infra/) | ✅ (workspace-infra/) | Layer 3 |
| **biz-process** | ✅ (workspace/biz-process/) | ❌ | ✅ (workspace-bpm/) | Layer 3 |
| **change-mgt** | ✅ (workspace/change-mgt/) | ❌ | ✅ (workspace-dtcm/) | Layer 3 |
| **security** | ✅ (workspace/security/) | ❌ | ✅ (workspace-security/) | Layer 3 |
| **legal** | ✅ (workspace/legal/) | ❌ | ✅ (workspace-legal/) | Layer 3 |
| **qa** | ✅ (workspace/qa/) | ✅ (workspace/agents/sage/) | ✅ (workspace-qa/) | Layer 3 |
| **governance** | ✅ (workspace/governance/) | ❌ | ✅ (workspace-governance/) | Layer 3 |
| **forge** | ✅ (workspace/forge/) | ❌ | ✅ (workspace-forge/) | Layer 3 (empty) |
| **spark** | ✅ (workspace/spark/) | ❌ | ✅ (workspace-social/) | Layer 3 |
| **social** | ❌ | ❌ | ✅ (workspace-social/) | Layer 3 (via spark) |
| **luthen** | ❌ | ❌ | ✅ (workspace-luthen/) | Layer 3 |
| **aria** | ❌ | ✅ (workspace/agents/aria/) | ❌ (alias for business) | Layer 2 (stale) |
| **sage** | ❌ | ✅ (workspace/agents/sage/) | ❌ (alias for qa) | Layer 2 (stale) |

## Appendix B: Hygiene Script Recommended Changes

### `soul-agents-hygiene-check.sh` — Updated Mapping

```zsh
WORKSPACE_BASE="/Users/ainchorsangiefpl/.openclaw"

local -a ACTIVE_AGENTS=(
  main           # Special: uses workspace root
  business       # workspace-business
  security       # workspace-security
  legal          # workspace-legal
  qa             # workspace-qa
  governance     # workspace-governance
  infra          # workspace-infra
  architect      # workspace-architect
  platform-arch  # workspace-platform-arch
  biz-process    # workspace-bpm
  change-mgt     # workspace-dtcm
  ahsoka         # workspace-ahsoka
  social         # workspace-social
  forge          # workspace-forge
  luthen         # workspace-luthen
)

local -a AGENT_DIRS=(
  .              # main — workspace root
  workspace-business
  workspace-security
  workspace-legal
  workspace-qa
  workspace-governance
  workspace-infra
  workspace-architect
  workspace-platform-arch
  workspace-bpm
  workspace-dtcm
  workspace-ahsoka
  workspace-social
  workspace-forge
  workspace-luthen
)
```

### `agent-rules-audit.sh` — Updated Check Paths

```zsh
check "business (Aria)"       "${WORKSPACE_BASE}/workspace-business"
check "security (Shield)"     "${WORKSPACE_BASE}/workspace-security"
# ... (already correct, just add forge and luthen)
check "forge (Forge)"         "${WORKSPACE_BASE}/workspace-forge"
check "luthen (Luthen)"       "${WORKSPACE_BASE}/workspace-luthen"
```

## Appendix C: OpenClaw Config Audit

No changes needed to `openclaw.json` `workspace` values — they already point to isolated workspaces. However, verify after migration:

- `ahsoka.agentDir`: Currently `workspace/agents/ahsoka` (Layer 2). After migration, this directory no longer exists. `agentDir` is an OpenClaw internal state path, not instruction files. It should be moved to `~/.openclaw/agents/ahsoka/agent/` to match the pattern of other agents. **This requires OpenClaw config change.**
- `atlas.agentDir`: Not set (uses default). Atlas runs as a subagent of architect, so no separate config needed.
- `aria.agentDir`: Uses `workspace/agents/aria/` (Layer 2). After migration, this should be removed or pointed to `~/.openclaw/agents/business/agent/` since aria is an alias for business.

---

## Sign-off

| Role | Name | Date | Signature |
|---|---|---|---|
| Architect | Atlas | 2026-07-08 | *(Draft)* |
| Human | Ken | TBD | |
| Platform Arch | Thrawn | TBD | |
| Governance | Warden | TBD | |