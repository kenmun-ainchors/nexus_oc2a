# TKT-0237 — Platform Rule Engine v1 (Groomed)
**Sprint 4 | Owner: Yoda + Warden | Effort: 7h | Status: Open**

## Scope
Platform Rule Engine v1 — automated DoD verification + 10-rule compliance audit. Two integrated workstreams.

---

## STREAM A: DoD Verification Gate

### Story A1: Pre-close validation hook in ticket.sh
**Owner:** Yoda | **Effort:** 1.5h

On `ticket.sh close`, run type-specific verification before allowing close:
- **Task-type:** verify deliverable file exists + git committed
- **Bug-type:** verify fix script exists + ticket linked to CHG
- **CHG-type:** verify CHANGELOG.md entry exists + code change in same commit
- **Config-type:** verify config file modified + baseline updated
- If verification fails: BLOCK close, output what's missing

**Deliverable:** Updated `ticket.sh` with `verify_and_close()` function
**AC:** Closing TKT-0240 (test ticket) without a deliverable file → blocked with clear error message

### Story A2: DoD validation rules registry
**Owner:** Yoda | **Effort:** 1h

Create `docs/DoD-Validation-Rules.md`:
- Per ticket type: what must exist before close
- Per deliverable class: file check, DB state check, git log check, Notion state check
- Mapped to TKT-0197 SoT Register

**Deliverable:** `docs/DoD-Validation-Rules.md`
**AC:** Document covers all 4 ticket types + TKT/CHG/INC/BUG prefixes

### Story A3: Post-deliverable validation cron
**Owner:** Warden | **Effort:** 1h

- New cron: every 2 hours, scans tickets closed in last 24h
- Re-runs DoD validation rules on each closed ticket
- If deliverable missing: creates `state/dod-validation-alert.json`
- Heartbeat picks up alert → notifies Ken via Telegram
- Auto-clears when deliverable confirmed present

**Deliverable:** `scripts/dod-validator.sh` + cron job
**AC:** Close a ticket, delete its deliverable file, wait 2h → alert fires on Telegram

---

## STREAM B: 10-Rule Audit Engine

### Story B1: Rule audit engine framework
**Owner:** Warden | **Effort:** 2h

Create `scripts/rule-audit.sh` — post-execution sweep of 10 rules:
- **R01:** Path Discipline (no tilde paths in writes)
- **R02:** SoT Compliance (reads from canonical source per SoT Register)
- **R03:** Model Routing (agent model matches Model3-Policy.md)
- **R04:** Template Adherence (output matches locked format)
- **R05:** State Checking (READ→VALIDATE→EXECUTE→VERIFY cycle observed)
- **R06:** ID Uniqueness (no duplicate TKT/CHG/INC IDs)
- **R07:** Config Drift (openclaw.json vs critical-config-baseline.json)
- **R08:** Content Governance (triad gate run on external content)
- **R09:** Cron Health (no silent cron failures >3 consecutive)
- **R10:** MEMORY Limits (MEMORY.md ≤ 16000 chars)

Output: `state/rule-audit-report.json` per run

**Deliverable:** `scripts/rule-audit.sh`
**AC:** Script runs, outputs valid JSON with all 10 rules, catches at least 1 known violation (tilde-path)

### Story B2: Weekly audit HTML report
**Owner:** Warden | **Effort:** 1.5h

- Parse `state/rule-audit-report.json` → HTML canvas report
- Per-rule compliance % (last 7 days)
- Top violations list
- Trend chart (compliance over time)
- Auto-published to `canvas/documents/rule-audit-weekly/index.html`

**Deliverable:** `scripts/rule-audit-report.sh` + Monday 09:00 AEST cron
**AC:** First report generated within 7 days, sent to Ken via Telegram + webchat embed

---

## Dependencies
```
A1 (Pre-close hook) ──→ A3 (Post-close validator)
A2 (Rules registry) ──┘
B1 (Audit engine) ────→ B2 (Weekly report)
Stream A ∥ Stream B (parallel)
```

## Execution Order
1. **A1** (Yoda) + **B1** (Warden) — parallel
2. **A2** (Yoda) + **A3** (Warden) — parallel
3. **B2** (Warden) — last

## DoD
- [ ] All 5 stories complete and verified
- [ ] `ticket.sh close` blocks when deliverable missing
- [ ] `dod-validator.sh` alerts within 2h of missed deliverable
- [ ] `rule-audit.sh` runs on Warden's 15-min cycle
- [ ] First weekly report generated within 7 days
- [ ] Zero CHG-0401/0402-class incidents for 14 consecutive days
