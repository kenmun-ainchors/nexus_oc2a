# CREST Boundary Reference — Authority & Non-Negotiables

**Source:** Compiled from `MEMORY.md` (Ken's governance mandate, CREST enforcement rules) and `RULES.md` (DoD gate enforcement).
**Purpose:** Single reference for the CREST boundary rules cited from the canonical authority documents. Reproduced here so the CREST skill is self-contained; do **not** modify the source MEMORY.md / RULES.md from this file.

---

## A. Ken's Governance Mandate — 2026-06-13 13:54 AEST (CHG-0545)

> Source: `MEMORY.md` §Ken's Governance Mandate.

Four rules locked into `SOUL.md` Non-Negotiables (#13–16) and confirmed by Ken:

1. **No fabrication.** Say "I don't know" and find out.
2. **Evidence-only.** Done/verified = validated + backed by artifacts. Vibe ≠ fact.
3. **CREST mandatory.** Every plan with execution work runs Plan → Execute → Verify → Replan → Synthesize → Done. No skip phases.
4. **Orchestrator only.** Yoda's CREST activities = **Plan, Verify, Replan, Synthesize, Close.** Execute is NEVER Yoda's. Per-instance Ken approval required for any exception.

**Triggered by:** TKT-0501 ("CREST synthesize and close" prompt where Yoda correctly observed ticket was already closed but could be misread as over-claiming). Ken used it to lock the boundary. CHG-0545.

### Boundary Interpretation

| Phase | Yoda's role? | Notes |
|-------|--------------|-------|
| Plan | ✅ Yes | Cognitive, pro-tier |
| Execute | ❌ NEVER | Delegate to specialists / Forge / infra executors |
| Verify | ✅ Yes | Cognitive, pro-tier, independent (L-054) |
| Replan | ✅ Yes | Cognitive, pro-tier |
| Synthesize | ✅ Yes | Flash-tier cross-specialist integration |
| Close | ✅ Yes | Terminal, audit emit |

**Exception path:** Any Yoda Execute requires per-instance Ken approval, logged to CHANGELOG.md, before dispatch.

---

## B. CREST Enforcement Rules — NON-NEGOTIABLE (LOCKED 2026-06-11)

> Source: `MEMORY.md` §CREST Enforcement Rules.

1. **No silent execution** — Plan phase explicit even for single-atom tasks.
2. **Skill-gate always** — `bash scripts/skill-load.sh <name>` before domain scripts (TKT-0396).
3. **No tribal knowledge** — reference skills, not inline memory.
4. **Model tier discipline** — Plan/Verify/Replan = strong (pro), Execute/Synthesize = cheap (flash).
5. **Triage mode is not an exemption** — each operational action starts a new CREST loop.
6. **Self-check** — if Ken asks "did you use CREST?" that's a violation → LESSONS.md.

---

## C. Replan Gate Logic (MEMORY.md §CREST Loop)

> Source: `MEMORY.md` §CREST Loop.

- **Replan Gate:** Critical decision hub. Gap found → iterate back to Execute (n++). Stop met → advance to Synthesize.
- **Routing:** Yoda plans typed DAG → queues atoms via TQP → cheap-tier executes → Yoda binary-judges 0–1 per atom → Replan → Synthesize → Done emits audit.

This is the only "stop met" condition. There is **no iteration threshold** — escalation is decided per the §D protocol below, not by a count.

---

## D. Escalation Protocol — iterate(n++) OR escalate

> Source: `docs/CREST-v1.2-Recursive-Model-C.md` §6 (LOCKED, dual PASS).

**Rule:** Specialists must never silently work around scope gaps. The decision tree:

```
Specialist Replan:
├── Gap fixable at atom level?
│   └── YES → iterate (n++) back to Execute. No escalation.
│
└── Gap NOT fixable at atom level?
    └── ESCALATE to Yoda with structured handshake (§6.2)
```

**No third option. No iteration threshold.** Escalation triggers immediately when the gap cannot be fixed at the atom level.

**Escalation handshake shape** (specialist → Yoda):

```json
{
  "sub_crest_escalation": {
    "status": "pending",
    "from_specialist": "<agent_id>",
    "reason": "scope_gap | cross_specialist | assumption_change | external_block",
    "description": "<what's blocked>",
    "impacted_sub_tickets": ["TKT-xxxx-<specialist>"],
    "proposed_resolution": "<Yoda action requested>",
    "escalated_at": "<ISO 8601>"
  }
}
```

---

## E. Governance Agents Placement

> Source: `MEMORY.md` §Governance Agents + `docs/CREST-v1.2-Recursive-Model-C.md` §5.4.

| Agent | Cadence | Placement | What It Gates |
|-------|---------|-----------|---------------|
| **Shield 🛡️** | On-demand (verdict) | **Master Synthesize Done gate** — external-facing outputs only | Security review |
| **Lex ⚖️** | On-demand (verdict) | **Master Synthesize Done gate** — external-facing outputs only | Legal/compliance/APP |
| **Sage 🧪** | On-demand (verdict) | **Master Synthesize Done gate** — external-facing outputs only | Accuracy, completeness, quality |
| **Warden 🔍** | 15-min cron (auto) | **Continuous** — monitors all agent model assignments | Model compliance, drift |

**Architectural principle:** Shield/Lex/Sage are **T4 reactive verdict-only** agents. They gate **external-facing outputs** at Master Synthesize Done. They do **NOT** gate specialist-internal Verify (no Sanctum gate on internal architecture docs, platform designs, or build outputs).

**External-facing surfaces that require governance gate:**
- Spark LinkedIn posts
- Aria external communications
- Client deliverables
- Any other output crossing AInchors boundaries

---

## F. RULES.md §DoD Verification Gate (CREST-related enforcement point)

> Source: `RULES.md` §DoD VERIFICATION GATE — NON-NEGOTIABLE (TKT-0237), Effective 2026-05-22.

**NO ticket may be closed without passing the DoD Verification Gate.**

- Ticket close: `bash scripts/db-ticket.sh update <ID> '{"status":"closed"}'`. Gate enforced by `scripts/crest-done-gate.sh` pre-close hook.
- **Reference:** `docs/DoD-Validation-Rules.md`
- **Override:** Ken only, via `--skip-verify` flag. Every override MUST be logged to CHANGELOG.md.
- **Violation:** DoD FAIL.

This is the machine-enforced CREST Done gate for ticket lifecycle. The Done phase of any CREST loop that closes a ticket must pass this gate.

---

## G. Authoritative Documents (for cross-reference)

| Topic | Canonical source |
|-------|------------------|
| Full recursive CREST spec (Model C, v1.2) | `docs/CREST-v1.2-Recursive-Model-C.md` (also copied to `references/CREST-v1.2-Recursive-Model-C.md`) |
| Mandate origin (4 rules) | `MEMORY.md` §Ken's Governance Mandate |
| Enforcement rules (6 rules) | `MEMORY.md` §CREST Enforcement Rules |
| Replan gate logic | `MEMORY.md` §CREST Loop |
| DoD close gate | `RULES.md` §DoD VERIFICATION GATE |
| Per-phase model assignment | `docs/CREST-v1.2-Recursive-Model-C.md` §4 + §5 |
| Governance agent placement | `docs/CREST-v1.2-Recursive-Model-C.md` §5.4 |

---

**Document status:** Derived reference, not authoritative. For CREST design decisions, defer to `docs/CREST-v1.2-Recursive-Model-C.md` (LOCKED, dual PASS). For boundary interpretation, defer to `MEMORY.md` and `RULES.md`.
