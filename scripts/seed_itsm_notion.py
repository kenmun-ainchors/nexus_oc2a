#!/usr/bin/env python3
"""Seed ITSM User Stories into Notion Backlog DB."""
import json, time, urllib.request, urllib.error

API_KEY = "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"
DB_ID   = "39d890b6ece881bf9c3aeb784cf09c05"
HEADERS = {
    "Authorization": f"Bearer {API_KEY}",
    "Notion-Version": "2022-06-28",
    "Content-Type":  "application/json",
}

def rt(text):
    """Build rich_text array, splitting into 2000-char chunks."""
    chunks = []
    while text:
        chunks.append({"type": "text", "text": {"content": text[:2000]}})
        text = text[2000:]
    return chunks

def effort_map(e):
    return {"S": "S \u2014 < 2 hours", "M": "M \u2014 Half day",
            "L": "L \u2014 Full day", "XL": "XL \u2014 Multi-day"}[e]

def impact_map(p):
    return {"CRITICAL": "High", "HIGH": "High", "MEDIUM": "Medium", "LOW": "Low"}[p]

def create_page(title, priority, effort, notes_text, yoda_text):
    body = {
        "parent": {"database_id": DB_ID},
        "properties": {
            "US Title":        {"title": rt(title)},
            "Priority":        {"select": {"name": priority.capitalize() if priority != "CRITICAL" else "Critical"}},
            "Category":        {"select": {"name": "Platform"}},
            "Effort":          {"select": {"name": effort_map(effort)}},
            "Stream":          {"select": {"name": "Technical"}},
            "Impact":          {"select": {"name": impact_map(priority)}},
            "Status":          {"select": {"name": "Backlog"}},
            "Notes":           {"rich_text": rt(notes_text)},
            "Yoda Assessment": {"rich_text": rt(yoda_text)},
        }
    }
    data = json.dumps(body).encode()
    req  = urllib.request.Request("https://api.notion.com/v1/pages",
                                  data=data, headers=HEADERS, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            resp = json.loads(r.read())
            return {"ok": True, "id": resp["id"], "url": resp.get("url", "")}
    except urllib.error.HTTPError as e:
        body_err = e.read().decode()
        return {"ok": False, "error": f"HTTP {e.code}: {body_err[:400]}"}
    except Exception as ex:
        return {"ok": False, "error": str(ex)}

# ─────────────────────────────────────────────────────────────────────────────
# USER STORIES DATA
# ─────────────────────────────────────────────────────────────────────────────
STORIES = [
  # ── PHASE 1 ──
  {
    "id": "ITSM-US-001",
    "title": "Define and implement P1–P4 incident severity tiers",
    "priority": "CRITICAL", "effort": "S",
    "notes": (
      "Phase: 1\n"
      "Story: As Ken (CTO), I want incidents classified by severity (P1–P4) with defined SLOs, "
      "so that we prioritise responses appropriately and don't treat a gateway outage the same as a slow disk.\n\n"
      "Acceptance Criteria:\n"
      "- P1–P4 severity definitions documented with examples (P1=platform down, P2=degraded, P3=minor impact, P4=cosmetic/info)\n"
      "- Severity field added to incident-log.sh log command\n"
      "- Response/resolution SLOs per tier (P1: respond 15m/resolve 1h; P2: respond 1h/resolve 4h; P3: respond 4h/resolve 24h; P4: respond 24h/resolve 72h)\n"
      "- Existing INC records back-populated with severity tier\n"
      "- Severity field visible in Notion Incident Log DB view\n\n"
      "Dependencies: None\n"
      "Existing artefacts: scripts/incident-log.sh, state/incident-log.json, Notion Incident Log DB"
    ),
    "yoda": (
      "Foundational story — no other ITSM practice makes sense without a severity model. "
      "S effort because severity definitions are documentation work, not engineering. "
      "The SLO numbers are already decided; this is about codifying them. "
      "Start here, Day 1. Zero risk of getting this wrong — just commit to the tiers and move."
    ),
  },
  {
    "id": "ITSM-US-002",
    "title": "Formalise Yoda as Service Desk Lead with triage protocol",
    "priority": "CRITICAL", "effort": "S",
    "notes": (
      "Phase: 1\n"
      "Story: As Ken, I want a defined service desk function where Yoda triages all incoming requests/incidents, "
      "so that nothing falls through the cracks and I can operate at CTO level instead of being the first responder for everything.\n\n"
      "Acceptance Criteria:\n"
      "- Yoda's Service Desk role documented in Operations/ServiceDesk.md\n"
      "- Triage protocol defined: receive → classify → assign → acknowledge → escalate if P1/P2\n"
      "- Acknowledgement SLOs by severity (P1: 5 min, P2: 15 min, P3: 1h, P4: 4h)\n"
      "- 'Ticket First' rule documented and communicated — no work starts without TKT\n"
      "- Yoda generates daily desk report (open tickets, ageing, SLA breach risk) at morning standup\n\n"
      "Dependencies: ITSM-US-001 (severity tiers), ITSM-US-005 (TKT integration)\n"
      "Existing artefacts: Morning standup (8AM), Telegram alerts, OpenClaw chat"
    ),
    "yoda": (
      "This is the organisational clarity story. Ken needs to stop being the de-facto service desk. "
      "Documenting my role costs nothing and pays dividends immediately. "
      "S effort — write the doc, align with Ken, done. "
      "The triage protocol is already implicit in how we operate; this makes it explicit and auditable."
    ),
  },
  {
    "id": "ITSM-US-003",
    "title": "Define and publish internal SLOs for platform and services",
    "priority": "CRITICAL", "effort": "S",
    "notes": (
      "Phase: 1\n"
      "Story: As Ken, I want clearly defined SLOs for platform availability and incident response/resolution, "
      "so that we have targets to measure against and can demonstrate operational capability to clients.\n\n"
      "Acceptance Criteria:\n"
      "- Platform availability SLO defined: ≥99.5% monthly (~3.6h downtime/month)\n"
      "- Per-severity response and resolution SLOs defined (see ITSM-US-001)\n"
      "- SLOs documented in Operations/SLOs.md\n"
      "- SLO targets visible in Notion as a reference DB or page\n"
      "- SLO measurement methodology documented\n\n"
      "Dependencies: ITSM-US-001\n"
      "Existing artefacts: health-check.sh, state/incident-log.json, MTTR tracking"
    ),
    "yoda": (
      "Quick Win QW-1 formalised as a US. 99.5% is the right target for our current monitoring maturity — "
      "not so tight that measurement error makes us look bad, not so loose it's meaningless. "
      "S effort because the numbers already exist in the gap analysis. Write the doc, publish to Notion. "
      "This is a commitment ceremony more than engineering work."
    ),
  },
  {
    "id": "ITSM-US-004",
    "title": "Implement SLO measurement and weekly reporting",
    "priority": "CRITICAL", "effort": "M",
    "notes": (
      "Phase: 1\n"
      "Story: As Ken, I want actual SLO performance measured and reported weekly, "
      "so that we know if we're meeting our commitments and can catch SLA breaches before clients do.\n\n"
      "Acceptance Criteria:\n"
      "- health-check.sh appends timestamped result to state/uptime-log.json\n"
      "- slo-report.sh computes availability % for last 24h, 7d, 30d\n"
      "- Incident response time vs SLO target computed from INC records\n"
      "- Weekly SLO report auto-generated by Yoda (Friday nightly close)\n"
      "- SLO breach triggers Telegram alert\n\n"
      "Dependencies: ITSM-US-003, ITSM-US-001\n"
      "Existing artefacts: health-check.sh, scripts/incident-log.sh, state/incident-log.json"
    ),
    "yoda": (
      "The difference between defining SLOs and measuring them is the difference between a promise and evidence. "
      "M effort — the uptime-log.json append is 5 lines in health-check.sh; "
      "slo-report.sh is a 50-line jq script. "
      "This builds immediately on QW-4 (quick win). "
      "High value: without measurement, SLOs are fiction."
    ),
  },
  {
    "id": "ITSM-US-005",
    "title": "Connect TKT-NNNN system to Notion as single ITSM record",
    "priority": "CRITICAL", "effort": "M",
    "notes": (
      "Phase: 1\n"
      "Story: As Yoda (Service Desk Lead), I want all TKT tickets mirrored/linked in Notion, "
      "so that Notion remains the single source of truth and Ken can view all operational activity in one place.\n\n"
      "Acceptance Criteria:\n"
      "- TKT INC tickets sync to Notion Incident Log DB\n"
      "- TKT CHG tickets sync to Notion Change Log DB\n"
      "- TKT SRQ tickets visible in Notion Tasks or new Service Requests DB\n"
      "- TKT ID (TKT-NNNN) is primary identifier across all linked records\n"
      "- Existing INC records migrated to TKT format\n\n"
      "Dependencies: TKT system build (parallel track)\n"
      "Existing artefacts: Notion Backlog DB, Notion Tasks DB, Notion Incident Log DB"
    ),
    "yoda": (
      "Blocked on TKT system delivery (parallel track). Interim: use Notion Incident Log + Backlog as ticket stores. "
      "M effort once TKT lands. The integration is a sync script — TKT event → Notion API call. "
      "Architecture is straightforward: webhook or polling from TKT, Notion page create/update. "
      "Don't block Phase 1 other stories on this — proceed with Notion-native records until TKT is ready."
    ),
  },
  {
    "id": "ITSM-US-006",
    "title": "Define and automate PIR trigger for P1/P2 incidents",
    "priority": "HIGH", "effort": "S",
    "notes": (
      "Phase: 1\n"
      "Story: As Ken, I want every P1 and P2 incident to automatically trigger a Post-Incident Review (PIR), "
      "so that we learn from serious incidents and don't repeat them.\n\n"
      "Acceptance Criteria:\n"
      "- PIR template defined: timeline, impact, root cause, contributing factors, action items, owner\n"
      "- P1/P2 INC closure automatically creates PIR TKT linked to original INC\n"
      "- PIR must be completed within 24h of P1 resolution, 72h of P2 resolution\n"
      "- PIR action items become separate TKTs (Problem or CI type)\n"
      "- PIR summary added to incident-log.sh report output\n\n"
      "Dependencies: ITSM-US-001, ITSM-US-005\n"
      "Existing artefacts: scripts/incident-log.sh (rca field), Notion Incident Log DB"
    ),
    "yoda": (
      "PIRs are where learning happens. S effort — the template is a document, the trigger is a rule on INC closure. "
      "Anti-pattern warning: don't skip PIRs because 'we're a startup'. "
      "Each P1 is a $1,000+ learning opportunity. "
      "The rca field already exists in incident-log.sh — this formalises the process around it."
    ),
  },
  {
    "id": "ITSM-US-007",
    "title": "Patch auto-heal.sh to file INC record for every self-resolved event",
    "priority": "HIGH", "effort": "S",
    "notes": (
      "Phase: 1\n"
      "Story: As Yoda, I want every auto-heal resolution to create an INC record, "
      "so that self-healed incidents are visible in our incident history and we can spot patterns.\n\n"
      "Acceptance Criteria:\n"
      "- auto-heal.sh calls incident-log.sh after each auto-resolved check (severity P3/P4, status=auto-resolved)\n"
      "- INC record includes: check name, symptom detected, fix applied, resolution time\n"
      "- Auto-resolved INCs tagged 'auto-heal' for filtering in Notion\n"
      "- Auto-heal weekly summary shows count of auto-resolved vs filed-for-Ken incidents\n"
      "- No duplicate INC creation if same check fires/auto-resolves multiple times in same run\n\n"
      "Dependencies: ITSM-US-001\n"
      "Existing artefacts: scripts/auto-heal.sh, scripts/incident-log.sh"
    ),
    "yoda": (
      "Currently auto-heal runs silently — it fixes things but leaves no trace. "
      "This is a visibility gap. S effort: add ~10 lines to auto-heal.sh per heal action. "
      "The deduplication logic is important — use a run-ID to prevent INC storms. "
      "Immediate payoff: after 2 weeks we'll see which auto-heals fire most often → PRB candidates."
    ),
  },

  # ── PHASE 2 ──
  {
    "id": "ITSM-US-008",
    "title": "Define and publish AInchors Service Catalogue (v1)",
    "priority": "CRITICAL", "effort": "M",
    "notes": (
      "Phase: 2\n"
      "Story: As Ken, I want a defined catalogue of services that Yoda and agents can fulfil, "
      "so that requests have a defined scope, SLO, and fulfilment path — and we can show clients what we offer.\n\n"
      "Acceptance Criteria:\n"
      "- Minimum 15 catalogue items defined (internal ops + client-facing)\n"
      "- Each item has: name, description, owner, SLO (fulfilment time), inputs required, output delivered\n"
      "- Catalogue published in Notion (Service Catalogue DB)\n"
      "- Each item maps to a TKT request type (SRQ subtype)\n"
      "- Catalogue v1 reviewed and signed off by Ken\n\n"
      "Starter items (15): Run Platform Diagnostics (30m), Deploy New Agent (2h), Generate Operational Report (1h), "
      "Update Content Calendar (2h), Rotate Secrets (30m), Run PVT (15m), Backup On-Demand (15m), "
      "Asset Registry Review (1h), Incident RCA Report (4h), Generate Client Report (2h), "
      "Update KB Article (1h), Cost Report (30m), Sprint Planning Brief (1h), Pre-Risky-Op Checkpoint (15m), "
      "Onboard New Agent (4h)\n\n"
      "Dependencies: ITSM-US-003, ITSM-US-005\n"
      "Existing artefacts: Notion Backlog DB, auto-heal.sh (12 service actions), run-diagnostics.sh"
    ),
    "yoda": (
      "The service catalogue is the bridge between 'Yoda does stuff' and 'AInchors delivers services'. "
      "M effort — the 15 starter items are already identified; this is about formalising them in Notion with SLOs. "
      "Client-facing payoff: we can show prospects a real service catalogue with real SLOs. "
      "Don't over-engineer v1 — 15 items, clean descriptions, committed SLOs. Expand in v2."
    ),
  },
  {
    "id": "ITSM-US-009",
    "title": "Implement service request intake and fulfilment workflow",
    "priority": "HIGH", "effort": "M",
    "notes": (
      "Phase: 2\n"
      "Story: As Ken, I want service requests to follow a defined intake → assignment → fulfilment → closure workflow, "
      "so that requests don't get lost and SLOs are tracked end-to-end.\n\n"
      "Acceptance Criteria:\n"
      "- SRQ TKT states defined: New → Triaged → In Progress → Pending Ken → Closed\n"
      "- Yoda auto-assigns SRQs matching catalogue items within acknowledgement SLO\n"
      "- SLO breach alerts sent if SRQ not progressed within 50% of fulfilment SLO\n"
      "- SRQ closure requires: output delivered, Ken acknowledgement (for client-facing), TKT note\n"
      "- Weekly SRQ fulfilment report: volume, SLO adherence %, average fulfilment time\n\n"
      "Dependencies: ITSM-US-008, ITSM-US-005\n"
      "Existing artefacts: Notion Tasks DB, scripts/task-create.sh, scripts/task-complete.sh"
    ),
    "yoda": (
      "The workflow makes the catalogue real. Without intake/fulfilment states, a catalogue is just a menu. "
      "M effort — state machine is simple (5 states), auto-assignment is pattern matching against catalogue item names. "
      "The 50% SLO warning is a proactive breach-prevention mechanism — flag early, not at deadline. "
      "task-create.sh and task-complete.sh are reusable building blocks."
    ),
  },
  {
    "id": "ITSM-US-010",
    "title": "Implement Problem Management (PRB tickets + KEDB)",
    "priority": "HIGH", "effort": "M",
    "notes": (
      "Phase: 2\n"
      "Story: As Yoda, I want a formal Problem Management process with PRB tickets and a Known Error Database, "
      "so that recurring incidents are tracked, root causes investigated, and workarounds documented.\n\n"
      "Acceptance Criteria:\n"
      "- PRB ticket type created in TKT system, synced to Notion (new Problem DB)\n"
      "- Auto-rule: any INC with same root cause 2+ times in 30 days → Yoda raises PRB\n"
      "- PRB record includes: problem statement, linked INCs, affected CIs, workaround, status, root cause\n"
      "- KEDB created in Notion: Known Error entries with symptom, workaround, linked PRB\n"
      "- PRB closure requires: root cause confirmed, fix implemented or permanent workaround in KEDB\n\n"
      "Dependencies: ITSM-US-001, ITSM-US-005\n"
      "Existing artefacts: scripts/incident-log.sh (rca field), state/incident-log.json"
    ),
    "yoda": (
      "Problem Management stops the 'fix the same thing every week' cycle. "
      "The auto-rule (2x same root cause in 30 days) is the detection mechanism — simple frequency analysis on INC records. "
      "KEDB is a Notion DB, not a complex system. M effort. "
      "Start with PRB-001 filed manually (Quick Win QW-8) to make the practice real before automation lands."
    ),
  },
  {
    "id": "ITSM-US-011",
    "title": "Extend Notion Asset Registry to function as a CMDB with CI relationships",
    "priority": "HIGH", "effort": "L",
    "notes": (
      "Phase: 2\n"
      "Story: As Ken, I want the asset registry to capture relationships between configuration items (not just a list), "
      "so that we know the blast radius of any change before we make it.\n\n"
      "Acceptance Criteria:\n"
      "- CI Type field added to Asset Registry: Host / Service / Script / Config / Secret / Agent\n"
      "- CI Relationships field added (Notion relation to other Asset Registry records)\n"
      "- Dependent Services field added (what breaks if this CI fails)\n"
      "- Owner, Lifecycle Stage, and Last Reviewed fields verified/added\n"
      "- All 53 existing assets updated with CI Type and key relationships\n"
      "- New CMDB view in Notion shows CIs grouped by type with relationship count\n\n"
      "Dependencies: None\n"
      "Existing artefacts: Notion Asset Registry DB (53 assets), scripts/asset-review.sh, state/config-baseline.json"
    ),
    "yoda": (
      "L effort — not because CMDB is complex, but because classifying 53 assets takes methodical work. "
      "Anti-pattern: don't try to build full relationship graphs for all 53 at once. "
      "Focus on the 7 critical config CIs and the 10 most-changed assets first. "
      "The Notion relation field is the right tool — no custom DB needed. "
      "Blast radius analysis pays for this effort on the first Normal change."
    ),
  },
  {
    "id": "ITSM-US-012",
    "title": "Add CMDB blast radius check to pre-risky-op checkpoint",
    "priority": "HIGH", "effort": "M",
    "notes": (
      "Phase: 2\n"
      "Story: As Ken, I want the pre-risky-op checkpoint to query the CMDB for dependent CIs before any change is approved, "
      "so that we know what else might be impacted and can warn appropriately.\n\n"
      "Acceptance Criteria:\n"
      "- cmdb-blast-radius.sh <CI-ID> queries Notion Asset Registry for dependents of named CI\n"
      "- Script outputs: CI name, dependent services, last change date, health status\n"
      "- Pre-risky-op rule updated to include blast-radius check step before Ken confirmation\n"
      "- If dependents found: output shown to Ken, Ken explicitly confirms 'aware of [N] dependents'\n"
      "- CHG ticket references affected CIs (CI field added to CHG TKT template)\n\n"
      "Dependencies: ITSM-US-011, ITSM-US-013\n"
      "Existing artefacts: scripts/pre-restart-cleanup.sh, pre-risky-op rule in Operations/Standards.md"
    ),
    "yoda": (
      "This converts the CMDB from a passive registry to an active safety gate. "
      "M effort — cmdb-blast-radius.sh is a Notion API query filtered by relationship field. "
      "The pre-risky-op rule update is a documentation change + script hook. "
      "High value: prevents silent cascading failures from undocumented dependencies. "
      "Must complete ITSM-US-011 first — the CMDB needs relationships before this can query them."
    ),
  },
  {
    "id": "ITSM-US-013",
    "title": "Define three change types and formalise change management process",
    "priority": "MEDIUM", "effort": "S",
    "notes": (
      "Phase: 2\n"
      "Story: As Ken, I want change requests classified as Standard, Normal, or Emergency, "
      "so that routine changes don't need Ken sign-off but risky changes get appropriate review.\n\n"
      "Acceptance Criteria:\n"
      "- Change types documented: Standard (pre-approved scripts, no Ken review), Normal (Ken approval required, CHG ticket), "
      "Emergency (break-glass, execute, retrospective review ≤24h)\n"
      "- Standard Change catalogue defined (list of pre-approved change patterns)\n"
      "- CHG TKT template updated with: change type, risk score (1–5), affected CIs, rollback plan\n"
      "- Emergency change procedure documented: who can invoke, notification requirement, retrospective SLA\n"
      "- Notion Change Log DB completed with all required fields for all CHG types\n\n"
      "Dependencies: ITSM-US-005\n"
      "Existing artefacts: CHANGELOG.md, scripts/changelog-append.sh, pre-risky-op checkpoint rule, Notion Change Log DB"
    ),
    "yoda": (
      "Anti-pattern alert: no CAB meetings. For 1 CTO + AI, CAB = Ken says yes. "
      "Standard changes are the efficiency win — pre-approved patterns don't need approval each time. "
      "S effort because this is a definition exercise — the change catalogue is a short list, not a policy manual. "
      "Emergency change procedure is critical: define it before you need it, not during a P1."
    ),
  },
  {
    "id": "ITSM-US-014",
    "title": "Create Continual Improvement Register (CIR) in Notion",
    "priority": "MEDIUM", "effort": "S",
    "notes": (
      "Phase: 2\n"
      "Story: As Ken, I want a Continual Improvement Register where all improvement ideas are captured, prioritised, "
      "and tracked to completion, so that good ideas don't get lost and we can measure improvement velocity.\n\n"
      "Acceptance Criteria:\n"
      "- CIR Notion DB created: CI-ID, title, description, source, raised date, owner, status, outcome, impact measurement\n"
      "- Auto-rule: recurring INC (2x in 30 days) raises CI-ID linked to PRB\n"
      "- Weekly Friday CI Review: Yoda generates CIR report, Ken prioritises top 3 for next week\n"
      "- Monthly CI retrospective auto-generated: items closed, average time-to-close, items raised\n"
      "- All existing auto-heal 'needs-Ken' Notion US migrated to CIR format\n\n"
      "Dependencies: ITSM-US-005\n"
      "Existing artefacts: Notion Backlog DB, daily journal (improvement notes), auto-heal Notion US filing"
    ),
    "yoda": (
      "Quick Win QW-5 formalised. S effort because the DB structure is simple and we can duplicate the Backlog DB as a start. "
      "The CI velocity metric (≥4 items closed/month) is the accountability mechanism. "
      "Without a register, improvement ideas are journal entries — they disappear. "
      "With a register, they're tracked commitments. The Friday CI Review cadence makes it live."
    ),
  },

  # ── PHASE 3 ──
  {
    "id": "ITSM-US-015",
    "title": "Add timestamped metric logging to health-check for trend analysis",
    "priority": "HIGH", "effort": "M",
    "notes": (
      "Phase: 3\n"
      "Story: As Yoda, I want health-check results stored as a time series (not just pass/fail at one point), "
      "so that we can detect gradual degradation trends before they become incidents.\n\n"
      "Acceptance Criteria:\n"
      "- health-check.sh appends each run result to state/metrics.json: timestamp, check name, result, duration_ms\n"
      "- metrics.json has rolling 90-day retention (auto-prune entries older than 90 days)\n"
      "- metrics-trend.sh <check-name> <days> computes: pass rate %, average value, trend (improving/stable/degrading)\n"
      "- Nightly close includes metrics trend summary for all checks (degrading trends flagged)\n"
      "- SLO measurement reads from metrics.json for availability calculation\n\n"
      "Dependencies: ITSM-US-003\n"
      "Existing artefacts: scripts/health-check.sh"
    ),
    "yoda": (
      "The shift from point-in-time to time-series is the intelligence upgrade that makes monitoring actually useful. "
      "Currently health-check tells us 'is it OK right now?' — time-series tells us 'is it getting worse?' "
      "M effort — appending to metrics.json is trivial; the trend computation script is the main work. "
      "90-day rolling window is right-sized: enough history for trends, not so much it bloats state."
    ),
  },
  {
    "id": "ITSM-US-016",
    "title": "Add system resource capacity monitoring to nightly close",
    "priority": "HIGH", "effort": "M",
    "notes": (
      "Phase: 3\n"
      "Story: As Ken, I want CPU, RAM, disk, and API usage tracked and alerted at threshold, "
      "so that we don't hit capacity walls during client work or agent scale-out.\n\n"
      "Acceptance Criteria:\n"
      "- capacity-snapshot.sh collects: CPU% (5-min avg), RAM used/total, disk used/total, API calls today vs daily limit, Ollama queue depth\n"
      "- Capacity snapshot runs at nightly close and appends to state/capacity-log.json\n"
      "- Alert thresholds: disk >80% = WARNING, >90% = CRITICAL; RAM >85% = WARNING; API usage >70% of limit = WARNING\n"
      "- Capacity trend (7-day) included in Friday CI review\n"
      "- capacity-forecast.sh projects days-to-threshold based on 7-day trend\n\n"
      "Dependencies: ITSM-US-015\n"
      "Existing artefacts: scripts/health-check.sh (disk check), state/cost-state.json, scripts/cost-tracker.sh"
    ),
    "yoda": (
      "Disk >80% is already tracked in health-check.sh. This extends that to a full capacity posture. "
      "M effort — capacity-snapshot.sh is ~40 lines collecting from standard OS/API sources. "
      "The forecast script is the high-value deliverable: 'disk full in 23 days' is actionable; 'disk at 75%' is not. "
      "Cost tracker already has API call data — reuse that, don't duplicate."
    ),
  },
  {
    "id": "ITSM-US-017",
    "title": "Implement per-agent performance tracking (token usage, task rate, errors)",
    "priority": "MEDIUM", "effort": "L",
    "notes": (
      "Phase: 3\n"
      "Story: As Ken, I want to see how each AI agent is performing — token spend, task completion rate, error rate — "
      "so that I can identify underperforming agents and optimise model assignment.\n\n"
      "Acceptance Criteria:\n"
      "- Per-agent metrics tracked: task count (daily/weekly), token usage (daily/weekly), error count, average task duration\n"
      "- Agent metrics stored in state/agent-metrics.json (per agent, rolling 30 days)\n"
      "- Notion Agent Status DB updated with current metrics (automated daily)\n"
      "- Weekly agent performance report: top performer, most errors, cost-per-task per agent\n"
      "- Alert if any agent has >20% error rate over 24h\n\n"
      "Dependencies: ITSM-US-016, ITSM-US-015\n"
      "Existing artefacts: state/cost-state.json, Notion Agent Status DB"
    ),
    "yoda": (
      "L effort because per-agent instrumentation requires hooking into each agent's task execution path. "
      "The data collection is scattered across different agent logs. "
      "High future value: model assignment decisions become data-driven rather than intuitive. "
      "The >20% error rate alert is the guard rail — catch a broken agent before it burns tokens and fails client work. "
      "Phase 3 placement is correct — Phase 1-2 infrastructure must be solid first."
    ),
  },
  {
    "id": "ITSM-US-018",
    "title": "Automate monthly availability report generation",
    "priority": "MEDIUM", "effort": "S",
    "notes": (
      "Phase: 3\n"
      "Story: As Ken, I want a monthly availability report generated automatically, "
      "so that we have objective evidence of platform reliability to share with clients and track improvement over time.\n\n"
      "Acceptance Criteria:\n"
      "- availability-report.sh generates: availability % for month, downtime events (count, duration, cause), SLO target vs actual, planned vs unplanned downtime split\n"
      "- Report runs first day of each month for prior month\n"
      "- Report saved to reports/availability-YYYY-MM.md\n"
      "- Report linked in Notion (monthly review page)\n"
      "- Report format is client-presentable (clean markdown, no internal jargon)\n\n"
      "Dependencies: ITSM-US-004, ITSM-US-015\n"
      "Existing artefacts: state/uptime-log.json (from ITSM-US-004), scripts/incident-log.sh"
    ),
    "yoda": (
      "S effort once ITSM-US-004 (uptime-log.json) is running — the report is a jq/awk script over existing data. "
      "The client-presentable format requirement is important: no internal IDs, no raw JSON, clean prose + numbers. "
      "This is a sales asset as much as an operational document. "
      "First report month will be Month 1 of operations — good baseline to improve from."
    ),
  },
  {
    "id": "ITSM-US-019",
    "title": "Create Knowledge Base index with article lifecycle management",
    "priority": "MEDIUM", "effort": "M",
    "notes": (
      "Phase: 3\n"
      "Story: As Yoda, I want all operational knowledge organised in a searchable index with a defined lifecycle, "
      "so that agents can find accurate, current information without digging through scattered docs.\n\n"
      "Acceptance Criteria:\n"
      "- KB Index created in Notion: KB-ID, title, ITIL practice area, status (Draft/Active/Retired), last reviewed, author, linked TKT/INC/PRB records\n"
      "- All 13 Operations/ docs registered in KB Index with KB-IDs\n"
      "- Article lifecycle enforced: Active articles reviewed quarterly (auto-reminder to Yoda)\n"
      "- INC and PRB records have KB link field: 'resolved using KB-NNN'\n"
      "- 'Onboarding KB' package created: essential articles for any new agent type\n\n"
      "Dependencies: ITSM-US-010\n"
      "Existing artefacts: Notion Holocron (migrated TKT-0042), workspace Operations/ docs"
    ),
    "yoda": (
      "The 13 Operations docs exist but are undiscoverable without knowing their filenames. "
      "M effort — the KB Index DB setup is quick; the value is in the lifecycle discipline. "
      "Quarterly review reminders prevent docs from becoming wrong silently. "
      "'Resolved using KB-NNN' links make knowledge reuse visible and measurable. "
      "Onboarding KB package is the force multiplier for new agent types."
    ),
  },
  {
    "id": "ITSM-US-020",
    "title": "Define planned maintenance window policy and schedule",
    "priority": "LOW", "effort": "S",
    "notes": (
      "Phase: 3\n"
      "Story: As Ken, I want defined maintenance windows where planned work can occur with reduced incident risk, "
      "so that clients know when to expect planned downtime and we have protected time for infrastructure work.\n\n"
      "Acceptance Criteria:\n"
      "- Standard maintenance window defined: Sundays 02:00–04:00 AEST (pre-existing backup/heal window)\n"
      "- Emergency maintenance window procedure: 1h notice minimum, Telegram notification\n"
      "- Maintenance window schedule maintained in Notion (calendar view)\n"
      "- Normal CHG tickets scheduled within maintenance windows by default\n"
      "- Availability SLO excludes planned maintenance downtime from calculation\n\n"
      "Dependencies: ITSM-US-013\n"
      "Existing artefacts: scripts/backup.sh (02:00 scheduled), scripts/auto-heal.sh (23:30 scheduled)"
    ),
    "yoda": (
      "Low priority because the Sunday 02:00 window already exists — backup.sh and auto-heal.sh both run then. "
      "S effort: formalise what already happens, add to Notion calendar, update SLO exclusion formula. "
      "Low risk of getting wrong — the window is already de-facto agreed. "
      "This story is about making implicit policy explicit for client transparency."
    ),
  },

  # ── PHASE 4 ──
  {
    "id": "ITSM-US-021",
    "title": "Implement INFO/WARNING/EXCEPTION event taxonomy in health-check",
    "priority": "MEDIUM", "effort": "M",
    "notes": (
      "Phase: 4\n"
      "Story: As Yoda, I want health-check events classified as INFO, WARNING, or EXCEPTION, "
      "so that we don't treat all events the same and can implement appropriate automated responses per event class.\n\n"
      "Acceptance Criteria:\n"
      "- Event classes defined: INFO (log only), WARNING (log + Yoda reviews at next standup), EXCEPTION (log + raise INC + alert Ken immediately)\n"
      "- health-check.sh output includes event class tag per check result\n"
      "- Event class drives automated response: INFO → metrics.json, WARNING → Notion note, EXCEPTION → INC creation + Telegram alert\n"
      "- Alert suppression rule: same EXCEPTION in <10 min → suppress repeat alerts, escalate once with count\n"
      "- Event class visible in Notion Incident Log for EXCEPTION events\n\n"
      "Dependencies: ITSM-US-015\n"
      "Existing artefacts: scripts/health-check.sh, scripts/auto-heal.sh"
    ),
    "yoda": (
      "Currently health-check produces binary pass/fail with no severity classification. "
      "This upgrade makes the event stream intelligent. M effort — refactor health-check.sh check loop to classify output. "
      "Alert suppression is critical: without it, a flapping check generates 50 Telegram messages in 10 minutes. "
      "The suppress-once-with-count pattern (seen in enterprise monitoring) is the right model. "
      "Phase 4 placement: needs metrics.json (Phase 3) as foundation."
    ),
  },
  {
    "id": "ITSM-US-022",
    "title": "Define release types (Hotfix/Standard/Major) and release notes template",
    "priority": "MEDIUM", "effort": "S",
    "notes": (
      "Phase: 4\n"
      "Story: As Ken, I want a defined release process with typed releases and standard release notes, "
      "so that anyone knows what changed, what the risk was, and how to roll back.\n\n"
      "Acceptance Criteria:\n"
      "- Release types documented: Hotfix (immediate, retrospective CHG ≤1h), Standard (planned, CHG ticket, maintenance window preferred), Major (Ken sign-off, maintenance window required)\n"
      "- Release notes template defined: version/date, change summary, affected components, test evidence (PVT result), rollback procedure\n"
      "- Release notes generated automatically from CHG ticket + PVT result for Standard/Major releases\n"
      "- Release calendar maintained in Notion\n"
      "- PVT failure on Standard/Major release = auto-rollback trigger\n\n"
      "Dependencies: ITSM-US-013\n"
      "Existing artefacts: scripts/pvt.sh, scripts/changelog-append.sh, CHANGELOG.md, pre-risky-op rule"
    ),
    "yoda": (
      "S effort — the three release types are already implicitly in use; this formalises and documents them. "
      "The release notes template is a markdown file with placeholders. "
      "Auto-generation from CHG ticket + PVT result is the efficiency win — no manual note-writing for Standard releases. "
      "Auto-rollback on PVT failure is already partially in pvt.sh — extend it. "
      "Release Management is the last ITSM practice to formalise, so Phase 4 placement is correct."
    ),
  },
  {
    "id": "ITSM-US-023",
    "title": "Maintain release calendar and release communication workflow",
    "priority": "LOW", "effort": "S",
    "notes": (
      "Phase: 4\n"
      "Story: As Ken, I want a release calendar and communication workflow so that planned releases are visible in advance, "
      "clients are notified for major releases, and we can plan work around release dates.\n\n"
      "Acceptance Criteria:\n"
      "- Release Calendar Notion DB (or view): release date, version, type, affected services, CHG reference, status\n"
      "- Major release communication template: what's changing, when, expected downtime, contact if issues\n"
      "- Upcoming releases included in weekly morning standup brief\n"
      "- Releases aligned with maintenance windows by default (Standard/Major)\n"
      "- Past releases viewable as release history with release notes linked\n\n"
      "Dependencies: ITSM-US-022, ITSM-US-020\n"
      "Existing artefacts: Notion Projects DB, Notion Content Calendar"
    ),
    "yoda": (
      "Low priority — only becomes critical when we have clients to communicate to. "
      "S effort: a Notion DB view on CHG records filtered by release type, plus a communication template. "
      "The morning standup brief inclusion is a 3-line addition to the standup template. "
      "Don't over-invest here pre-client. Build the calendar, write the template, move on. "
      "Phase 4 placement is right — this is polish on top of ITSM-US-022."
    ),
  },
  {
    "id": "ITSM-US-024",
    "title": "Establish weekly Continual Improvement review cadence",
    "priority": "MEDIUM", "effort": "S",
    "notes": (
      "Phase: 4\n"
      "Story: As Ken, I want a regular (weekly, Friday) CI review where Yoda presents open CIR items and we prioritise the top 3 for next week, "
      "so that improvements don't stall and the improvement loop actually closes.\n\n"
      "Acceptance Criteria:\n"
      "- Friday nightly close includes CI Review section: all open CIR items, items closed this week, top 3 recommended for next week\n"
      "- Monthly CI retrospective: items raised, closed, abandoned; average time-to-close; improvement impact\n"
      "- CIR items >30 days In Progress flagged as stalled → Yoda escalates to Ken\n"
      "- CI velocity metric tracked: CI items closed per month (target: ≥4/month)\n"
      "- Closed CI items include: what changed, measurable outcome\n\n"
      "Dependencies: ITSM-US-014\n"
      "Existing artefacts: scripts/roi-update.sh, daily journal (Friday format), morning standup template"
    ),
    "yoda": (
      "The cadence is what turns the CIR from a database into a living practice. "
      "S effort — the Friday nightly close template already exists; add a CI Review section. "
      "Target ≥4 CI items closed/month is achievable but requires discipline. "
      "The 30-day stall flag prevents the CIR from becoming a graveyard of good intentions. "
      "Phase 4 placement: CIR must be live (ITSM-US-014, Phase 2) before the cadence is meaningful."
    ),
  },
  {
    "id": "ITSM-US-025",
    "title": "Build ITSM Framework health dashboard in Notion",
    "priority": "MEDIUM", "effort": "M",
    "notes": (
      "Phase: 4\n"
      "Story: As Ken, I want a single Notion page showing the health of all ITSM practices at a glance, "
      "so that I can assess operational posture in 60 seconds without reading 15 separate reports.\n\n"
      "Acceptance Criteria:\n"
      "- ITSM Dashboard Notion page exists with sections per practice area\n"
      "- Each practice shows: current RAG status (Red/Amber/Green), last updated, key metric, open actions\n"
      "- Dashboard auto-updated by Yoda weekly (Friday nightly close)\n"
      "- Platform availability % displayed prominently (current month vs SLO)\n"
      "- Open tickets by type (INC/PRB/CHG/SRQ) and age displayed\n"
      "- CI velocity and CIR backlog count visible\n\n"
      "Dependencies: ITSM-US-004, ITSM-US-015, ITSM-US-016, ITSM-US-018\n"
      "Existing artefacts: Notion workspace, all reporting scripts"
    ),
    "yoda": (
      "The dashboard is EPIC-001's payoff moment — Ken gets 60-second operational visibility. "
      "M effort — the data is all available by Phase 4; the work is the Notion page layout and weekly auto-update script. "
      "RAG status per practice is a judgement call (I'll define the RAG criteria in the dashboard). "
      "The auto-update script is a Friday nightly close task: query all data sources, update Notion page. "
      "This is also a client-showable artefact — 'here's our operational dashboard' closes trust gaps."
    ),
  },
  {
    "id": "ITSM-US-026",
    "title": "Conduct ITSM Framework v1.0 retrospective at end of Phase 4",
    "priority": "MEDIUM", "effort": "S",
    "notes": (
      "Phase: 4\n"
      "Story: As Ken, I want a formal retrospective at the end of the 8-week epic, "
      "so that we assess what we built, what worked, what didn't, and plan EPIC-002 improvements from an evidence base.\n\n"
      "Acceptance Criteria:\n"
      "- Retrospective report produced: US completion rate, SLO performance, incident metrics, CMDB coverage %, KB article count\n"
      "- Maturity re-assessment: score all 15 ITIL practices against gap analysis baseline (target: all ≥3)\n"
      "- Top 5 items for EPIC-002 identified (from CIR and retrospective)\n"
      "- Retrospective published as Obsidian note + Notion page\n"
      "- EPIC-001 marked complete in Notion Projects DB\n\n"
      "Dependencies: All Phase 1–4 US\n"
      "Existing artefacts: daily journal, CI register, SLO reports, availability reports"
    ),
    "yoda": (
      "The retrospective is how EPIC-001 closes the loop. S effort because all the data exists in reports — "
      "this is synthesis and maturity scoring, not data collection. "
      "The maturity re-assessment against the gap analysis baseline will show quantified improvement. "
      "Top 5 EPIC-002 items should emerge from the CIR naturally — the retrospective surfaces and prioritises them. "
      "Don't skip this. The 8-week discipline only pays off if we measure the outcome."
    ),
  },

  # ── Migration US (US-027 to US-032) with ITSM-US prefix ──
  {
    "id": "ITSM-US-027",
    "title": "Back-populate severity tier on all existing INC records",
    "priority": "HIGH", "effort": "S",
    "notes": (
      "Phase: 1 (Migration)\n"
      "Story: As Yoda, I want all historical INC records (from state/incident-log.json and Notion) to have a severity tier, "
      "so that our historical MTTR data is comparable against SLO targets.\n\n"
      "Acceptance Criteria:\n"
      "- All existing INC records reviewed and severity assigned (P1–P4 per new definitions)\n"
      "- incident-log.json updated with severity field for all records\n"
      "- Notion Incident Log DB severity field populated for all existing records\n"
      "- MTTR calculated per severity tier from historical data\n"
      "- Baseline established: 'pre-EPIC-001 MTTR by severity' documented\n\n"
      "Dependencies: ITSM-US-001\n"
      "Existing artefacts: state/incident-log.json, Notion Incident Log DB"
    ),
    "yoda": (
      "Migration story — no new capability, but without this the historical INC data is incomparable to our new SLOs. "
      "S effort because the historical INC count should be manageable (Day 3 of operations). "
      "The pre-EPIC-001 MTTR baseline is important: it gives us a 'before' measurement for the retrospective. "
      "Do this in Phase 1 Week 1, immediately after ITSM-US-001 defines the severity tiers."
    ),
  },
  {
    "id": "ITSM-US-028",
    "title": "Complete Notion Change Log DB with all historical CHG records",
    "priority": "MEDIUM", "effort": "M",
    "notes": (
      "Phase: 1 (Migration)\n"
      "Story: As Ken, I want the Notion Change Log to be complete and current (all CHG-NNNN entries from CHANGELOG.md present), "
      "so that our change history is queryable and we have an audit trail from Day 1.\n\n"
      "Acceptance Criteria:\n"
      "- All CHG entries from CHANGELOG.md present in Notion Change Log DB\n"
      "- Each Notion CHG record has: CHG-ID, date, type, description, author, affected components, PVT result, status\n"
      "- Change type field back-populated (Standard/Normal/Emergency as best-fit for historical changes)\n"
      "- Notion Change Log DB has correct views: by type, by date, by status\n"
      "- Going forward: changelog-append.sh also creates/updates Notion CHG record\n\n"
      "Dependencies: ITSM-US-013\n"
      "Existing artefacts: CHANGELOG.md (all CHG-NNNN entries), Notion Change Log DB (partial)"
    ),
    "yoda": (
      "The CHANGELOG.md is the authoritative record; Notion is partially populated. M effort to close the gap. "
      "Once complete, the Notion Change Log becomes queryable by type, date, and component. "
      "The going-forward automation (changelog-append.sh → Notion) is the lasting change. "
      "Historical back-population is a one-time migration cost. "
      "Phase 1 placement: get audit trail complete early so all future changes have a clean baseline."
    ),
  },
  {
    "id": "ITSM-US-029",
    "title": "Classify all 53 existing assets with CI type and key relationships",
    "priority": "HIGH", "effort": "L",
    "notes": (
      "Phase: 2 (Migration)\n"
      "Story: As Yoda, I want all existing assets in the registry classified by CI type and with at least their primary relationships documented, "
      "so that the CMDB is immediately useful for blast-radius analysis.\n\n"
      "Acceptance Criteria:\n"
      "- All 53 assets classified with CI Type (Host/Service/Script/Config/Secret/Agent)\n"
      "- Primary relationships documented for all CIs (at minimum: 'depends on' and 'used by' for each)\n"
      "- Lifecycle stage assigned to all CIs\n"
      "- At least the 7 Critical Config CIs have full relationship graphs\n"
      "- asset-review.sh updated to include CMDB completeness check in weekly review\n\n"
      "Dependencies: ITSM-US-011\n"
      "Existing artefacts: Notion Asset Registry DB (53 assets), scripts/asset-review.sh"
    ),
    "yoda": (
      "L effort because this is methodical classification work, not engineering. "
      "53 assets × average 10 mins each = ~9 hours of focused review. "
      "Strategy: batch by CI Type (all Hosts first, then Services, etc.) for efficiency. "
      "Priority: 7 Critical Config CIs first — these have the highest blast radius risk. "
      "The asset-review.sh CMDB completeness check prevents regression after migration."
    ),
  },
  {
    "id": "ITSM-US-030",
    "title": "Register all existing Operations/ docs in the Knowledge Base Index",
    "priority": "MEDIUM", "effort": "S",
    "notes": (
      "Phase: 3 (Migration)\n"
      "Story: As Yoda, I want all 13 existing Operations docs registered in the KB Index with KB-IDs and practice area tags, "
      "so that agents can find them by category without knowing the filename.\n\n"
      "Acceptance Criteria:\n"
      "- All 13 Operations docs registered in KB Index Notion DB with KB-ID (KB-001 to KB-013)\n"
      "- Each doc tagged with ITIL practice area (may have multiple)\n"
      "- Each doc has last-reviewed date (set to Day 3 as baseline)\n"
      "- Article status set to Active for all 13 (they're current)\n"
      "- Quarterly review reminder set for all 13 (trigger: 90 days from registration)\n\n"
      "Dependencies: ITSM-US-019\n"
      "Existing artefacts: Notion Holocron Platform Operations + workspace Operations/ ("
      "RunDiagnostics.md, IncidentLog.md, OfflinePlaybook.md, AsyncExecution.md, SecretsManagement.md, Standards.md, "
      "Compliance.md, JournalFormat.md, BlogFormat.md, ROIModel.md)"
    ),
    "yoda": (
      "S effort because we're registering existing docs, not creating content. "
      "The 13 files are known; the KB-IDs are sequential; the ITIL practice tags are deterministic. "
      "Quick Win QW-7 (add ITIL practice header to each doc) can be done in parallel. "
      "Once registered, these docs become findable by practice area — this is the discoverability upgrade. "
      "Quarterly review reminders are auto-set in Notion; zero maintenance after setup."
    ),
  },
  {
    "id": "ITSM-US-031",
    "title": "Migrate existing auto-heal Notion US to Continual Improvement Register",
    "priority": "MEDIUM", "effort": "S",
    "notes": (
      "Phase: 2 (Migration)\n"
      "Story: As Ken, I want all existing auto-heal 'needs Ken' US migrated to the CIR format, "
      "so that they're tracked with proper CI-IDs, priority, and don't get lost in the general backlog.\n\n"
      "Acceptance Criteria:\n"
      "- All existing auto-heal Notion US items reviewed and migrated to CIR DB\n"
      "- Each item assigned CI-ID, source=auto-heal, priority assessed by Yoda\n"
      "- Items with existing TKT/US references cross-linked\n"
      "- auto-heal.sh updated to file new items directly to CIR DB (not general Backlog)\n"
      "- Old auto-heal US entries in Backlog archived (not deleted — audit trail)\n\n"
      "Dependencies: ITSM-US-014\n"
      "Existing artefacts: Notion Backlog DB (auto-heal US entries), scripts/auto-heal.sh"
    ),
    "yoda": (
      "S effort — the auto-heal US items are already in Notion; this is a re-classification exercise. "
      "The key change is updating auto-heal.sh to point at CIR DB instead of Backlog DB (one config change). "
      "Archive (not delete) the old Backlog entries — audit trail matters. "
      "After this migration, the Backlog DB is clean: only sprint-ready US, no auto-heal noise."
    ),
  },
  {
    "id": "ITSM-US-032",
    "title": "Create client-facing SLA template based on internal SLOs",
    "priority": "HIGH", "effort": "M",
    "notes": (
      "Phase: 2 (Migration)\n"
      "Story: As Ken, I want a client-ready SLA template derived from our internal SLOs, "
      "so that when the first client comes aboard we have a professional SLA to present rather than scrambling.\n\n"
      "Acceptance Criteria:\n"
      "- SLA template document created (reports/client-sla-template.md)\n"
      "- Template includes: service scope, availability targets, incident response times, exclusions, measurement methodology, reporting cadence, escalation contacts\n"
      "- SLA targets are ≤ internal SLOs (never promise clients more than we promise ourselves)\n"
      "- Template reviewed by Ken and marked 'approved'\n"
      "- Template stored in Obsidian (Legal/SLA-Template.md) and Notion (Compliance page)\n\n"
      "Dependencies: ITSM-US-003, ITSM-US-004\n"
      "Existing artefacts: Operations/Compliance.md, Operations/Standards.md"
    ),
    "yoda": (
      "High priority because client SLA readiness is a Day-1 business requirement. "
      "M effort — the internal SLOs (ITSM-US-003) are the source of truth; derive client SLAs from them with appropriate margin. "
      "Critical rule: SLA targets ≤ internal SLOs. Never commit to clients what you haven't committed to yourself. "
      "The 'approved by Ken' gate is essential — no client SLA goes out without CTO sign-off. "
      "This is a migration story because it formalises existing compliance intent from Operations/Compliance.md."
    ),
  },
]

# ─────────────────────────────────────────────────────────────────────────────
# MIGRATION USER STORIES (ITSM-MIG-001 to ITSM-MIG-006)
# These mirror US-027 to US-032 with ITSM-MIG prefix
# ─────────────────────────────────────────────────────────────────────────────
MIG_STORIES = [
  {
    "id": "ITSM-MIG-001",
    "title": "Back-populate severity tier on all existing INC records",
    "priority": "HIGH", "effort": "S",
    "notes": (
      "Phase: 1 (Migration)\n"
      "Story: As Yoda, I want all historical INC records (from state/incident-log.json and Notion) to have a severity tier, "
      "so that our historical MTTR data is comparable against SLO targets.\n\n"
      "Acceptance Criteria:\n"
      "- All existing INC records reviewed and severity assigned (P1–P4 per new definitions)\n"
      "- incident-log.json updated with severity field for all records\n"
      "- Notion Incident Log DB severity field populated for all existing records\n"
      "- MTTR calculated per severity tier from historical data\n"
      "- Baseline established: 'pre-EPIC-001 MTTR by severity' documented\n\n"
      "Dependencies: ITSM-US-001\n"
      "Existing artefacts: state/incident-log.json, Notion Incident Log DB\n\n"
      "[Migration story — mirrors ITSM-US-027]"
    ),
    "yoda": (
      "Migration task: back-populate all historical INC records with severity tier. "
      "Do this immediately after ITSM-US-001 defines the tiers. "
      "The pre-EPIC-001 MTTR baseline is the 'before' measurement for the Phase 4 retrospective. "
      "S effort at startup scale — incident history is days old, not years."
    ),
  },
  {
    "id": "ITSM-MIG-002",
    "title": "Complete Notion Change Log DB with all historical CHG records",
    "priority": "MEDIUM", "effort": "M",
    "notes": (
      "Phase: 1 (Migration)\n"
      "Story: As Ken, I want the Notion Change Log to be complete and current (all CHG-NNNN entries from CHANGELOG.md present), "
      "so that our change history is queryable and we have an audit trail from Day 1.\n\n"
      "Acceptance Criteria:\n"
      "- All CHG entries from CHANGELOG.md present in Notion Change Log DB\n"
      "- Each Notion CHG record has: CHG-ID, date, type, description, author, affected components, PVT result, status\n"
      "- Change type field back-populated (Standard/Normal/Emergency as best-fit for historical changes)\n"
      "- Notion Change Log DB has correct views: by type, by date, by status\n"
      "- Going forward: changelog-append.sh also creates/updates Notion CHG record\n\n"
      "Dependencies: ITSM-US-013\n"
      "Existing artefacts: CHANGELOG.md, Notion Change Log DB (partial)\n\n"
      "[Migration story — mirrors ITSM-US-028]"
    ),
    "yoda": (
      "Migration task: close the gap between CHANGELOG.md and Notion Change Log DB. "
      "M effort — parse CHANGELOG.md entries, create corresponding Notion records. "
      "The automation (changelog-append.sh → Notion) is the lasting change that prevents future gaps. "
      "Phase 1 priority: complete audit trail from Day 1."
    ),
  },
  {
    "id": "ITSM-MIG-003",
    "title": "Classify all 53 existing assets with CI type and key relationships",
    "priority": "HIGH", "effort": "L",
    "notes": (
      "Phase: 2 (Migration)\n"
      "Story: As Yoda, I want all existing assets in the registry classified by CI type and with at least their primary relationships documented, "
      "so that the CMDB is immediately useful for blast-radius analysis.\n\n"
      "Acceptance Criteria:\n"
      "- All 53 assets classified with CI Type (Host/Service/Script/Config/Secret/Agent)\n"
      "- Primary relationships documented for all CIs\n"
      "- Lifecycle stage assigned to all CIs\n"
      "- At least the 7 Critical Config CIs have full relationship graphs\n"
      "- asset-review.sh updated to include CMDB completeness check\n\n"
      "Dependencies: ITSM-US-011\n"
      "Existing artefacts: Notion Asset Registry DB (53 assets), scripts/asset-review.sh\n\n"
      "[Migration story — mirrors ITSM-US-029]"
    ),
    "yoda": (
      "Migration task: classify and relate all 53 existing assets. "
      "L effort — methodical classification work. Batch by CI Type for efficiency. "
      "7 Critical Config CIs first — highest blast radius risk. "
      "Strategy: Host × N, then Service × N, then Script × N, then Config, Secret, Agent. "
      "After this, CMDB is immediately useful for ITSM-US-012 blast radius checks."
    ),
  },
  {
    "id": "ITSM-MIG-004",
    "title": "Register all existing Operations/ docs in the Knowledge Base Index",
    "priority": "MEDIUM", "effort": "S",
    "notes": (
      "Phase: 3 (Migration)\n"
      "Story: As Yoda, I want all 13 existing Operations docs registered in the KB Index with KB-IDs and practice area tags, "
      "so that agents can find them by category without knowing the filename.\n\n"
      "Acceptance Criteria:\n"
      "- All 13 Operations docs registered in KB Index Notion DB with KB-ID (KB-001 to KB-013)\n"
      "- Each doc tagged with ITIL practice area\n"
      "- Each doc has last-reviewed date (set to Day 3 as baseline)\n"
      "- Article status set to Active for all 13\n"
      "- Quarterly review reminder set for all 13\n\n"
      "Dependencies: ITSM-US-019\n"
      "Existing artefacts: Notion Holocron Platform Operations\n\n"
      "[Migration story — mirrors ITSM-US-030]"
    ),
    "yoda": (
      "Migration task: register 13 existing docs in the new KB Index. "
      "S effort — sequential Notion API calls, one per doc. "
      "KB-001 to KB-013 assigned in alphabetical order or by ITIL practice grouping. "
      "The quarterly review reminder is set once and auto-fires — zero maintenance."
    ),
  },
  {
    "id": "ITSM-MIG-005",
    "title": "Migrate existing auto-heal Notion US to Continual Improvement Register",
    "priority": "MEDIUM", "effort": "S",
    "notes": (
      "Phase: 2 (Migration)\n"
      "Story: As Ken, I want all existing auto-heal 'needs Ken' US migrated to the CIR format, "
      "so that they're tracked with proper CI-IDs, priority, and don't get lost in the general backlog.\n\n"
      "Acceptance Criteria:\n"
      "- All existing auto-heal Notion US items reviewed and migrated to CIR DB\n"
      "- Each item assigned CI-ID, source=auto-heal, priority assessed by Yoda\n"
      "- Items with existing TKT/US references cross-linked\n"
      "- auto-heal.sh updated to file new items directly to CIR DB\n"
      "- Old auto-heal US entries in Backlog archived (not deleted)\n\n"
      "Dependencies: ITSM-US-014\n"
      "Existing artefacts: Notion Backlog DB (auto-heal US entries), scripts/auto-heal.sh\n\n"
      "[Migration story — mirrors ITSM-US-031]"
    ),
    "yoda": (
      "Migration task: move auto-heal backlog noise out of the general Backlog into the CIR. "
      "S effort — re-classification, not re-engineering. "
      "Archive old entries (audit trail). Update auto-heal.sh target DB (one config line). "
      "Result: Backlog DB becomes clean sprint-ready US only. CIR DB gets auto-heal items with proper tracking."
    ),
  },
  {
    "id": "ITSM-MIG-006",
    "title": "Create client-facing SLA template based on internal SLOs",
    "priority": "HIGH", "effort": "M",
    "notes": (
      "Phase: 2 (Migration)\n"
      "Story: As Ken, I want a client-ready SLA template derived from our internal SLOs, "
      "so that when the first client comes aboard we have a professional SLA to present rather than scrambling.\n\n"
      "Acceptance Criteria:\n"
      "- SLA template document created (reports/client-sla-template.md)\n"
      "- Template includes: service scope, availability targets, incident response times, exclusions, measurement methodology, reporting cadence, escalation contacts\n"
      "- SLA targets are ≤ internal SLOs\n"
      "- Template reviewed by Ken and marked 'approved'\n"
      "- Template stored in Obsidian (Legal/SLA-Template.md) and Notion (Compliance page)\n\n"
      "Dependencies: ITSM-US-003, ITSM-US-004\n"
      "Existing artefacts: Operations/Compliance.md, Operations/Standards.md\n\n"
      "[Migration story — mirrors ITSM-US-032]"
    ),
    "yoda": (
      "Migration task: formalise client SLA from internal SLOs. "
      "M effort — derive, document, get Ken sign-off. "
      "Critical constraint: client SLA targets must be ≤ internal SLO targets. "
      "Never over-promise. This is a legal/business document — CTO must approve before it goes anywhere near a client."
    ),
  },
]

# ─────────────────────────────────────────────────────────────────────────────
# MAIN: Create all pages
# ─────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    results = []
    all_items = [(s, False) for s in STORIES] + [(s, True) for s in MIG_STORIES]

    for idx, (story, is_mig) in enumerate(all_items, 1):
        sid   = story["id"]
        label = f"ITSM-MIG-00{idx - 32}" if is_mig else sid
        full_title = f"{label} \u2014 {story['title']}"

        print(f"[{idx:02d}/38] Creating: {full_title[:80]}...", flush=True)
        result = create_page(
            title      = full_title,
            priority   = story["priority"],
            effort     = story["effort"],
            notes_text = story["notes"],
            yoda_text  = story["yoda"],
        )
        result["label"] = label
        result["title"] = full_title
        results.append(result)

        if result["ok"]:
            print(f"  ✅ OK — {result['id']}", flush=True)
        else:
            print(f"  ❌ FAIL — {result['error']}", flush=True)

        # Respectful rate-limiting: ~3 req/sec
        if idx < len(all_items):
            time.sleep(0.4)

    # Summary
    ok_count   = sum(1 for r in results if r["ok"])
    fail_count = len(results) - ok_count
    print(f"\n{'='*60}")
    print(f"SUMMARY: {ok_count} created, {fail_count} failed out of {len(results)} total")
    print(f"{'='*60}")
    for r in results:
        status = "✅" if r["ok"] else "❌"
        url    = r.get("url", "N/A")
        print(f"{status} {r['label']}: {r.get('id','ERROR')} | {url}")

    # Save results JSON
    with open("/Users/ainchorsoc2a/.openclaw/workspace/reports/itsm-notion-seed-results.json", "w") as f:
        json.dump(results, f, indent=2)
    print("\nResults saved to reports/itsm-notion-seed-results.json")
