# Atlas Gap Analysis — File Routing Policy vs TKT-0124 vs Live State
**Author:** Atlas 🏛️  
**Date:** 2026-05-12  
**Status:** LIVE — Approved by Ken Mun 2026-05-12
**Note:** All 7 gaps actioned same-day via CHG-0285, CHG-0287, TKT-0158, TKT-0160.  
**Scope:** File Routing Policy v1.0 (approved 2026-05-12) vs TKT-0124 Hybrid Storage Amendment vs actual OC1 state

---

## Critical Gaps — Top 3

- **MinIO has zero running containers.** Colima is up but no MinIO container exists. The entire agent layer (4 buckets) is non-functional. Any agent-layer storage calls will silently fail.
- **drive-sync.sh covers only 3 of 8 required file categories.** Canvas deliverables (non-blog), marketing collaterals, social drafts, sprint reports, and proposals are not synced. Drive is NOT the SSOT it claims to be right now.
- **Two new docs created today are not in the sync list.** `File-Routing-Policy-v1.0.md` and `EA-Addendum-Storage-Access-Architecture-v0.1.md` will not reach Drive until manually added or the script is patched.

---

## 1. TKT-0124 vs Policy — Alignment Check

**Assessment: ALIGNED — no conflicts. Policy extends TKT-0124, does not contradict it.**

- TKT-0124 defined the two-layer architecture (human → Drive, agent → MinIO). Policy v1.0 formalises and operationalises this with routing rules, folder structure, and sync obligations. Consistent.
- TKT-0124 noted MinIO as "to build." Policy v1.0 carries that forward — MinIO rules are defined but implementation is acknowledged as pending. No conflict.
- TKT-0124 P2 note (migrate to AWS S3 Sydney) is not addressed in Policy v1.0 — this is correct and expected. P2 planning is out of scope for MVP policy.
- **One gap to flag:** TKT-0124 defines "workspace-assets" as a MinIO bucket. Policy v1.0 includes it in the bucket list but does not define what agent writes go there vs. `state/`. Needs clarification before MinIO is built — low urgency now, needed before P1 gate.

---

## 2. Implementation Gaps — Prioritised

### P0 — Blocking now

**GAP-01: MinIO has no running container**
- Colima is running. `docker ps` returns zero containers. MinIO was never deployed or was removed when Docker Desktop was dropped.
- Impact: Agent-layer storage is completely unavailable. Any MinIO writes (generated-media, agent-memory, brand-code) will fail silently or error.
- Evidence: `docker ps` output is empty as of 2026-05-12 10:36.

**GAP-02: drive-sync-failures.json does not exist**
- Policy requires all Drive upload failures to be logged here. The file is missing from `state/`.
- Impact: If any Drive upload fails, there is no audit trail. Agents can't log failures. Heartbeat alerts on sync failures can't trigger.
- This is a P0 because it's a safety net that must exist before Drive sync is considered reliable.

### P1 — Fix this sprint

**GAP-03: drive-sync.sh is missing Drive folder IDs for 5 of 8 file categories**
- Script has IDs for: Journal (`1WUcG6...`), Memory (`1qn7pZ...`), Docs (`1WsvbM...`)
- Script has NO IDs for: Canvas/, Marketing/, Proposals/, Social/Drafts/, Sprint Docs/
- Impact: Even if we add sync logic, it cannot run without the target folder IDs. Forge needs to look these up or create these folders in Drive.

**GAP-04: New docs not in hardcoded sync list**
- `drive-sync.sh` uses a hardcoded file list for the docs section. Files created after the last script update are invisible to it.
- Missing today: `File-Routing-Policy-v1.0.md`, `EA-Addendum-Storage-Access-Architecture-v0.1.md`
- Also missing (pre-existing): `DRAFT_Gap_Analysis_Yoda_Orchestrator_MD_20260510.md`, `Nexus_Enterprise_Landscape_P2P4.md`, `Phase4_DataMemory_Architecture.md`, `Phase4_DataMemory_Architecture_ContextHandoff.md`, `aevlith-it-strategy-2026-05.md`, `aevlith-charter-addendum-draft.md`, `Backup_Strategy_3-2-1-1.md`, `Skill-Installation-Policy-v1.0.md`, `EA-Addendum-Storage-Access-Architecture-v0.1.md`, `Context-Handoff-Delta-20260507-20260510.md`
- Fix: Switch docs section from hardcoded list to glob `"$WORKSPACE/docs/"*.md`, or add a canvas/ section.

**GAP-05: canvas/documents non-blog folders not synced**
- `ainchors-context-handoff/` — context handoff doc (has `index.md`, `generate_report.py`, PDF). Not synced.
- `ainchors-ollama-poc-report/` — Ollama POC report with PDF. Not synced.
- `docgen-test/` — test artifact. Low priority but should be reviewed.
- Blog canvas folders (ainchors-2026-05-06 through 2026-05-10) ARE synced. ✅
- Policy rule: ALL canvas HTML → Drive Canvas/. These are falling through the gap.

**GAP-06: reports/ not synced at all**
- 9 files in reports/ (diagnostics, SLA report, ITSM epic plan, gap analysis) — none synced.
- Policy requires sprint reports → Drive Sprint Docs/.
- Diagnostics are local-only per policy — correct. But `sla-2026-04.md`, `itil-gap-analysis.md`, `itsm-epic-plan.md` should be reviewed for Drive sync.

**GAP-07: marketing collaterals (TKT-0027) not synced**
- canvas/documents/ was checked — no `ainchors-marketing/` folder visible in current listing.
- The TKT-0027 marketing collaterals may exist elsewhere or may not have been created yet.
- Policy requires marketing collaterals → Drive Marketing/. If they exist locally, they are not on Drive.

### P2 — Can wait

**GAP-08: workspace-social/ is empty — no social routing tested**
- The folder exists but is empty. No Spark outputs have been routed through it.
- Not urgent — Spark's social content workflow hasn't been exercised under the new policy.

**GAP-09: Agent behaviour is not enforced**
- Agents create files locally by default. Nothing enforces Drive upload post-creation.
- No post-task hook, no gating mechanism, no automated check.
- This is a process/convention gap, not a technical blocker today. Addressed in Section 5.

**GAP-10: workspace-assets MinIO bucket scope undefined**
- TKT-0124 lists it; policy includes it but doesn't define what goes there vs `state/`.
- Low risk at MVP. Define before MinIO build.

---

## 3. drive-sync.sh — What Needs to Change

**Changes required (Forge to implement):**

1. **Add Drive folder IDs** — Forge must look up or create these Drive folders and add their IDs to the script:
   - `CANVAS_FOLDER` → `AInchors — Yoda Working Files/Canvas/`
   - `MARKETING_FOLDER` → `AInchors — Yoda Working Files/Marketing/`
   - `PROPOSALS_FOLDER` → `AInchors — Yoda Working Files/Proposals/`
   - `SOCIAL_DRAFTS_FOLDER` → `AInchors — Yoda Working Files/Social/Drafts/`
   - `SPRINT_DOCS_FOLDER` → `AInchors — Yoda Working Files/Sprint Docs/`

2. **Replace hardcoded docs list with glob** — Change the docs section to:
   ```zsh
   for f in "$WORKSPACE/docs/"*.md; do
     [[ -f "$f" ]] && do_sync "$f" "$DOCS_FOLDER"
   done
   ```
   This ensures every new `.md` in docs/ is picked up without manual additions.

3. **Add canvas section for non-blog folders** — Add a new section after the journal/blogs section:
   ```zsh
   # ── Canvas Deliverables (non-blog) ───────────────────────────────────────
   if [[ "$SECTION" == "canvas" || "$SECTION" == "all" ]]; then
     echo "── Canvas Deliverables ──"
     for dir in "$CANVAS"/ainchors-context-handoff "$CANVAS"/ainchors-ollama-poc-report; do
       [[ -f "$dir/index.html" ]] && do_sync "$dir/index.html" "$CANVAS_FOLDER" "$(basename $dir).html"
       [[ -f "$dir/index.md" ]] && do_sync "$dir/index.md" "$CANVAS_FOLDER"
     done
     # Future: glob all non-date canvas folders
   fi
   ```

4. **Add social drafts section:**
   ```zsh
   # ── Social Drafts ──────────────────────────────────────────────────────────
   if [[ "$SECTION" == "social" || "$SECTION" == "all" ]]; then
     echo "── Social Drafts ──"
     for f in "$WORKSPACE/workspace-social/"*.md "$WORKSPACE/workspace-social/"*.txt; do
       [[ -f "$f" ]] && do_sync "$f" "$SOCIAL_DRAFTS_FOLDER"
     done
   fi
   ```

5. **Add sprint reports section:**
   ```zsh
   # ── Sprint Reports ─────────────────────────────────────────────────────────
   if [[ "$SECTION" == "sprint" || "$SECTION" == "all" ]]; then
     echo "── Sprint Reports ──"
     for f in "$WORKSPACE/reports/sla-"*.md "$WORKSPACE/reports/sprint-"*.md "$WORKSPACE/reports/itil-"*.md "$WORKSPACE/reports/itsm-epic-"*.md; do
       [[ -f "$f" ]] && do_sync "$f" "$SPRINT_DOCS_FOLDER"
     done
   fi
   ```

6. **Add sync failure logging** — Update the `sync_file()` failure path:
   ```zsh
   # In sync_file(), on failure:
   python3 -c "
   import json, datetime
   f='$WORKSPACE/state/drive-sync-failures.json'
   try: d=json.load(open(f))
   except: d={'failures':[]}
   d['failures'].append({'file':'$src','folder':'$folder','time':datetime.datetime.now().isoformat(),'error':'$result'})
   json.dump(d,open(f,'w'),indent=2)
   " 2>/dev/null
   ```

---

## 4. MinIO — Status Assessment

**State:** Colima running (macOS Virtualization.Framework, docker runtime). Zero containers active. MinIO is not deployed.

**Impact at MVP:**
- Generated images (HF/FLUX): cannot be stored. If no image generation has been triggered since TKT-0124, this is not a live breakage — just an unbuilt feature.
- Agent memory (Aria structured memory): no persistent agent memory layer. Aria is using OC1 local only.
- Brand Code structured copy: not stored in MinIO. Only the human Drive doc exists.
- workspace-assets: no backup destination for state/ files.

**Is this urgent?**
- No active workflow is currently depending on MinIO (no image generation, no structured agent-memory calls confirmed active).
- However, it is a defined P1 build per TKT-0124 and is referenced in the approved policy.
- **Recommendation:** MinIO is **not a P0 blocker** for MVP operations today but should be deployed before any agent is tasked with image generation or structured memory writes. Forge should treat this as P1 sprint work, not emergency.

**Minimum to restore:**
1. Create Docker Compose file for MinIO (single-node, Colima socket)
2. Start container, confirm API at localhost:9000
3. Create 4 buckets: `ainchors-agent-memory`, `ainchors-generated-media`, `ainchors-workspace-assets`, `ainchors-brand-code`
4. Store credentials in `state/minio-credentials.json` (local only, never Drive)
5. Update TOOLS.md with MinIO access details

---

## 5. Agent Behaviour Enforcement

**Current state:** Zero enforcement. Agents create files locally. Drive upload is manual or EOD cron only.

**Options (ordered by effort/effectiveness):**

**Option A — Skill-level instruction (lowest effort, now)**
Update relevant SKILLs and agent SOUL/RULES files to include the routing obligations. Every agent that produces a doc must include a `gog drive upload` call as the final step. Enforced by convention, not code.
- Effort: Low (text edits to skill files)
- Reliability: Moderate — depends on agents following instructions
- Recommended: YES, do this now as a baseline

**Option B — Post-task checklist in Yoda's RULES.md (low effort)**
Add a "file routing checklist" that Yoda runs at task completion: confirm Drive upload happened, log failure if not. Yoda gates task closure on upload confirmation.
- Effort: Low
- Reliability: High for Yoda-coordinated tasks; doesn't help for direct subagent outputs
- Recommended: YES, implement alongside Option A

**Option C — drive-sync.sh --section flag triggered post-task (medium effort)**
After any agent creates a file, trigger `drive-sync.sh --section [relevant]` as a post-step. Can be added to agent task completion scripts or Forge's deployment hooks.
- Effort: Medium
- Reliability: High — script handles deduplication via state file
- Recommended: YES, good pattern for batch and EOD; less good for real-time delivery

**Option D — Upload wrapper function (medium effort, highest reliability)**
Create a `drive_upload_with_log()` shell function that all scripts import. Wraps `gog drive upload`, handles failures, logs to `drive-sync-failures.json`. Agents call the function, not raw gog.
- Effort: Medium (build once, include in scripts)
- Recommended: YES, build as part of drive-sync.sh refactor

**Do NOT recommend:** Filesystem watchers (inotify/FSEvents) — too fragile, platform-specific, and adds daemon complexity we don't need at MVP.

**Recommended stack for MVP:** A + B + D. Option C as needed for batch scenarios.

---

## 6. Backfill List

Files confirmed on OC1 local that are NOT on Drive (based on drive-sync.sh coverage gaps):

**docs/ — not in sync list (should go to Drive EA Assessments/Docs folder):**
- `File-Routing-Policy-v1.0.md` ← TODAY, HIGH PRIORITY
- `EA-Addendum-Storage-Access-Architecture-v0.1.md` ← TODAY
- `Atlas-Storage-Gap-Analysis-2026-05-12.md` ← THIS FILE
- `DRAFT_Gap_Analysis_Yoda_Orchestrator_MD_20260510.md`
- `Nexus_Enterprise_Landscape_P2P4.md`
- `Phase4_DataMemory_Architecture.md`
- `Phase4_DataMemory_Architecture_ContextHandoff.md`
- `aevlith-it-strategy-2026-05.md`
- `aevlith-charter-addendum-draft.md`
- `Backup_Strategy_3-2-1-1.md`
- `Skill-Installation-Policy-v1.0.md`
- `Context-Handoff-Delta-20260507-20260510.md`
- `HBR_Agentic_Marketing_Org_May2026_Summary.md`

**canvas/documents/ — not synced (should go to Drive Canvas/ or relevant subfolder):**
- `ainchors-context-handoff/index.md` + associated files
- `ainchors-ollama-poc-report/` (has PDF — confirm if Drive-worthy)

**reports/ — review and selectively sync to Drive Sprint Docs/:**
- `sla-2026-04.md` — SLA report → Sprint Docs
- `itil-gap-analysis.md` → Sprint Docs
- `itsm-epic-plan.md` → Sprint Docs
- `diagnostics-*.md` — local only per policy ✅ (no action needed)

---

## 7. Immediate Actions (Ordered)

**For Forge to execute:**

1. **Create `state/drive-sync-failures.json`** — touch `{"failures":[]}`. Unblocks GAP-02 immediately. 2 minutes.

2. **Look up Drive folder IDs** — Use `gog drive ls` on the `AInchors — Yoda Working Files/` root to get IDs for Canvas/, Marketing/, Proposals/, Social/Drafts/, Sprint Docs/. Create folders if missing. Record IDs. 10 minutes.

3. **Patch drive-sync.sh** — Apply all 6 changes from Section 3 above (glob docs, add canvas section, social, sprint, failure logging, new folder IDs). Test with `--force --section docs`. 30 minutes.

4. **Backfill priority docs** — Run `gog drive upload` for `File-Routing-Policy-v1.0.md` and this gap analysis doc to Drive EA Assessments/. These are today's approved docs and must be on Drive. 10 minutes.

5. **Backfill remaining docs/** — Run drive-sync.sh `--force --section docs` after patching to catch all missing docs in one pass.

6. **Deploy MinIO** — Create docker-compose for MinIO on Colima socket, start container, create 4 buckets. Not urgent today but assign as P1 sprint task. 1-2 hours.

7. **Update Yoda RULES.md and agent SKILLs** — Add file routing obligation to task completion checklist (Option A + B from Section 5). After Forge completes steps 1-5.

---

*Atlas 🏛️ — Gap Analysis Complete*  
*Yoda: save this file to Drive EA Assessments/ and deliver summary to Ken.*
