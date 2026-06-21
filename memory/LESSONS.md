## L-163 — Malformed silent replies (`ANNOUNCE_SKIP` concatenation) can crash-loop an agent session
**Date:** 2026-06-21
**Source:** Aria session `3c4d1fb8-5456-4ab2-83ed-0567b1fc58cd` stuck in perpetual `SKIPANNOUNCE`; required gateway restart to clear.
**Lesson:** OpenClaw treats any non-empty assistant response as content to deliver. When an agent wants to stay silent, the only valid reply is a clean, single `NO_REPLY` occupying the entire message. Emitting `ANNOUNCE_SKIP` — or concatenating it hundreds of times — is not a valid silent-response token. The runtime aborts the malformed turn and retries delivery, which re-invokes the same bad model output, creating an infinite retry loop that drives gateway CPU until the session is killed.
**Fix:** Gateway restart cleared the stuck Aria session. Aria's weekly ROI cron (`d1c03b59`) remains registered and enabled. No data loss.
**Evidence:** Aria transcript seq 187 showed `ANNOUNCE_SKIP` repeated continuously; seq 201 last turn aborted with `This operation was aborted`; gateway PID 86218 was at 37% CPU for 34 minutes before restart.
**Prevention:** (1) **All agents must use `NO_REPLY` and nothing else for silent responses.** (2) Do not send inter-session acknowledgments into an already looping session — each message feeds another retry. (3) If an agent's turn aborts on a malformed reply, reset/kill that session immediately rather than waiting. (4) Consider a runtime prompt guard or post-process filter that rejects any assistant message containing `ANNOUNCE_SKIP` and replaces it with `NO_REPLY`. (5) Add this rule to every agent's behavioral rules file.

---

## L-162 — Yoda must not Execute script/config changes; always route to Forge
**Date:** 2026-06-21
**Source:** TKT-0698 implementation. Ken asked: *"was that following CREST policy? was the execution work dispatched to Forge?"*
**Lesson:** The orchestrator must not short-circuit CREST, even for small or contextually-familiar script fixes. Yoda produced a CREST Plan, then directly edited `scripts/db-write.sh`, `scripts/db-raw.sh`, and `scripts/test-db-write.sh` instead of spawning Forge to Execute. This violated: (a) CREST Execute-never-Yoda rule (AGENTS.md #7, CHG-0545), and (b) T0/T1 build-routing rule that build/script work is Forge-only (L-026).
**Fix:** Kept the implemented changes (Ken: *"no need. it's already done."*). Locked in new rules in AGENTS.md (#15 FORGE EXECUTE GATE) and MEMORY.md: Yoda never directly edits scripts/, infra/, or build/config files; Plan/Verify only; Execute routes to Forge via `sessions_spawn(agentId="infra")`. Added a self-check: before any `edit`/`write` on executable/config files, ask *"Is this Execute? Is this Forge's domain?"*
**Evidence:** AGENTS.md and MEMORY.md updated 2026-06-21 09:56 AEST.
**Prevention:** (1) State CREST phase explicitly in every execution-adjacent task. (2) Use `sessions_spawn` for all script/build changes, regardless of size. (3) Treat the urge to "just do it quickly" as a stop-and-dispatch signal. (4) Ken/Angie per-instance exception required; default = no exception.

---

## L-161 — Stale derived-state files can amplify resolved issues into false error floods
**Date:** 2026-06-21
**Source:** Standup report: 521 ERRORs in 24h (284 `cron_run_fail`, 123 `backup_failure`, 114 `warden_violation`).
**Lesson:** Observability collectors that read state snapshots without validating freshness will replay old failures indefinitely. `state/cron-health-state.json` still listed deleted cron `85595417`; `archive/agents/atlas/.git` had no commit, causing backup `git add` to fail every run; and `warden-escalation-pending.json` was already resolved but obs rows were not cleared. Together these three stale artifacts generated 521 ERRORs in 24h and produced a "highest error volume in system history" alarm even though production health-state was `ok` and backups were succeeding.
**Fix:** Regenerated `state/cron-health-state.json` from live cron registry, remediated nested git repo in `archive/agents/atlas/`, and deleted stale obs.db ERROR rows (CHG-0693, dispatched to Forge 2026-06-21 09:40 AEST).
**Evidence:** `state/health-state.json` status=ok; `state/backup-state.json` status=ok with last full backup 2026-06-21-0805; re-run of `scripts/obs-trend.sh` after cleanup showed 0 errors / 11 warns / 19 info.
**Prevention:** Any state file consumed by an observability collector must have a freshness/validation step: (a) skip entries whose referenced object no longer exists, (b) auto-clear matching obs rows when an escalation transitions to `resolved`, and (c) treat a >50% day-over-day error spike as a possible stale-state artifact until proven otherwise.

---

## L-160 — Nested git repos must be explicitly excluded from parent backup auto-commits
**Date:** 2026-06-19
**Source:** TKT-0539 — backup warnings for `forge/pgvector/` and `thrawn/` embedded repos.
**Lesson:** A parent git repository that runs `git add -A` during an automated backup will fail or warn whenever a nested directory contains its own `.git/`. The failure is silent if stderr is not captured in the backup log. The only robust fix is to decide the nested repo's relationship to the parent (submodule, vendor, or separate worktree) and express it explicitly — usually via `.gitignore` — before the warning first appears.
**Fix:** Appended `forge/pgvector/` and `thrawn/` to `.gitignore` (TKT-0539). No content was deleted; the embedded `.git/` histories are preserved.
**Evidence:** CHG-0648; subagent verifier totals (git-status match=0, backup warning grep=0, snapshot 1.7G).
**Prevention:** During any new repo clone or vendor import into the workspace, immediately decide and record whether it is a submodule, a plain copy, or an ignored standalone repo. Add the `.gitignore` line at the same time as the directory is created. Do not rely on `backup.sh` to tolerate embedded repos.

---

## L-159 — Allowlist historical seed artifacts instead of forcing shadow deletion
**Date:** 2026-06-19
**Source:** WO-002 divergence alert follow-up (40 extra shadow rows after `in_progress` status-map fix).
**Lesson:** A mirror writer that only upserts live rows will leave orphaned shadow rows whenever live tickets are deleted or renamed. Two valid resolutions exist: (a) teach the writer to delete unmatched shadow rows, or (b) allowlist the historical artifacts. Deletion is cleaner but risks data loss if the live deletion was accidental. Allowlisting preserves the shadow history for audit and is the safer short-term fix, provided each artifact is documented with source_tkt, loop_id, atom_id, and an expiration date.
**Fix:** Added 20 `extra_rows` allowlist entries ALLOW-HIST-001..020 to `workspace-infra/state/status-map.json`. Re-ran divergence harness: unexplained=0.
**Evidence:** CHG-0646.
**Prevention:** When designing shadow sync, decide up-front whether the writer will hard-delete, soft-delete, or allowlist orphans. If allowlisting, generate the entries automatically from the first divergence report so the noise does not recur.

---

## L-158 — Live status values can contain underscores; status maps must list every canonical variant
**Date:** 2026-06-19
**Source:** WO-002 divergence alert (TKT-0536 missing in shadow).
**Lesson:** A status map that maps `in-progress` (hyphen) but not `in_progress` (underscore) will silently skip every live ticket with the underscore form. Lower-casing is not enough — the map must enumerate the actual canonical values used in the source of truth (PG `state_tickets.status`). Live data always wins over the map; when they disagree, the mirror falls behind and divergence alerts fire.
**Fix:** Added `in_progress` alias to `plan_map` and `atom_map` in `workspace-infra/state/status-map.json`, plus `_PLAN_STATUS_MAP` and `_ATOM_STATUS_MAP` in `controller/observer/status_map.py`. Restarted `com.ainchors.mirror-writer` LaunchAgent. TKT-0536 synced on next cycle.
**Evidence:** Mirror writer log changed from `upserted=336 skipped=1` to `upserted=337 skipped=0` after restart. CHG-0645.
**Prevention:** Whenever a new status value is introduced in PG, add it to the mirror status map before any ticket uses it. Include both hyphen and underscore variants if either could exist. Treat unmapped statuses as hard failures in the writer so they surface immediately, not as silent skips.

