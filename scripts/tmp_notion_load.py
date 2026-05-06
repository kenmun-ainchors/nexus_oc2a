#!/usr/bin/env python3
"""
Notion loader: Strategy OKR + Guardrails 2026-05
"""
import json, time, urllib.request, urllib.error, sys

import subprocess, os
NOTION_KEY = subprocess.check_output(["cat", os.path.expanduser("~/.config/notion/api_key")]).decode().strip()

HOLOCRON_ID = "355c1829-53ff-81db-9fbc-c46e878dc3b5"
HEADERS = {
    "Authorization": f"Bearer {NOTION_KEY}",
    "Notion-Version": "2025-09-03",
    "Content-Type": "application/json",
}
RATE_SLEEP = 0.4

def api(method, path, body=None):
    url = f"https://api.notion.com/v1/{path}"
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(url, data=data, headers=HEADERS, method=method)
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        err = e.read().decode()
        print(f"HTTP {e.code} on {method} {path}: {err[:300]}", file=sys.stderr)
        raise

def create_page(parent_page_id, title):
    time.sleep(RATE_SLEEP)
    body = {
        "parent": {"page_id": parent_page_id},
        "properties": {"title": {"title": [{"text": {"content": title}}]}}
    }
    r = api("POST", "pages", body)
    print(f"  Created page: '{title}' -> {r['id']}")
    return r["id"]

def append_blocks(page_id, blocks):
    """Append blocks in chunks of 50 to stay under limits."""
    chunk_size = 50
    for i in range(0, len(blocks), chunk_size):
        chunk = blocks[i:i+chunk_size]
        time.sleep(RATE_SLEEP)
        api("PATCH", f"blocks/{page_id}/children", {"children": chunk})
        print(f"  Appended blocks {i}..{i+len(chunk)-1}")

def h1(text):
    return {"object": "block", "type": "heading_1", "heading_1": {"rich_text": [{"text": {"content": text}}]}}

def h2(text):
    return {"object": "block", "type": "heading_2", "heading_2": {"rich_text": [{"text": {"content": text}}]}}

def h3(text):
    return {"object": "block", "type": "heading_3", "heading_3": {"rich_text": [{"text": {"content": text}}]}}

def para(text):
    # Notion rich text has a 2000 char limit per block
    chunks = [text[i:i+1900] for i in range(0, len(text), 1900)]
    return [{"object": "block", "type": "paragraph", "paragraph": {"rich_text": [{"text": {"content": c}}]}} for c in chunks]

def bullet(text):
    chunks = [text[i:i+1900] for i in range(0, len(text), 1900)]
    blocks = []
    for i, c in enumerate(chunks):
        blocks.append({"object": "block", "type": "bulleted_list_item", "bulleted_list_item": {"rich_text": [{"text": {"content": c}}]}})
    return blocks

def divider():
    return {"object": "block", "type": "divider", "divider": {}}

# ============================================================
# STRATEGY OKR PAGE CONTENT
# ============================================================
def build_strategy_blocks():
    blocks = []
    blocks.append(h1("AInchors + Auralith Strategy & 6–12 Month OKRs"))
    blocks.extend(para("Version: 2026-05 | Source: ainchors-strategy-okr-2026-05.md"))
    blocks.append(divider())

    # Section 1
    blocks.append(h2("1. Context"))
    blocks.extend(para("AInchors is a two-founder AI-native business in Sydney/Melbourne focused on AI training, AI consulting, and AI solutions/products, currently in P1 (internal build and proof-of-concept) with Nexus as its internal agentic platform."))
    blocks.extend(para("Auralith is the internal technology/IP company that designs, builds, and operates Nexus for AInchors and future sister entities, with the option in years 3–5 to host a small number of direct managed tenants."))
    blocks.extend(para("The next 6–12 months are designed to be training-led (~80%) with consulting (~20%) as a selective upsell, focused on SME founders/owners (10–200 FTE) in AU/SEA and anchored on Nexus as the default implementation platform."))

    # Section 2
    blocks.append(h2("2. Company-Level North Star"))
    blocks.append(h3("Vision (5+ Years)"))
    blocks.extend(para("AInchors is the trusted AI transformation partner and operations academy for SMEs in Australia, Malaysia, and the GCC, powered by Auralith's Nexus platform and serving as a live example of how a small team with AI agents can operate a full-stack business."))
    blocks.append(h3("Mission (Next 3 Years)"))
    blocks.extend(para("Help SME founders and owners design, adopt, and operate AI-driven businesses through practical training, productised consulting, and a managed agentic operations platform, with governance and data sovereignty built in from day one."))
    blocks.append(h3("Pillar Missions"))
    blocks.extend(bullet("Training: Equip SME founders and key operators with the clarity, skills, and playbooks to design and run AI-operated businesses, starting platform-agnostic and progressing into Nexus-based implementation for those who commit."))
    blocks.extend(bullet("Consulting (Ahsoka): Deliver productised 'AI Operations Jumpstarts' that discover, prioritise, and implement a small set of high-value agentic workflows on Nexus for SMEs, with a few deeper transformation cases as reference exemplars."))
    blocks.extend(bullet("Technology (Auralith/Nexus): Provide a robust, cost-optimised, and governance-first agentic operations platform that powers AInchors and its clients, evolving from an internal platform to managed multi-client infrastructure over 3–5 years."))

    # Section 3
    blocks.append(h2("3. 6–12 Month Company-Level OKR"))
    blocks.extend(para("Objective C1 — Prove the AInchors + Nexus model with real SMEs while staying training-led."))
    blocks.extend(bullet("KR1: Deliver 6–10 paid workshops (Level 1/2) to SME founders/owners (10–200 FTE) across AU/MY, with at least 60 unique founders reached."))
    blocks.extend(bullet("KR2: Convert at least 3–5 workshop participants into paid AI Operations Jumpstart consulting engagements on Nexus."))
    blocks.extend(bullet("KR3: Run Nexus in production for AInchors + minimum 2 SME clients with data sovereignty and Sanctum governance fully enforced (Tier 0/1 for client data)."))
    blocks.extend(bullet("KR4: Publish 2 high-quality case studies (1 training-led, 1 consulting/Nexus-led) describing concrete outcomes for SMEs."))

    # Section 4
    blocks.append(h2("4. Training Pillar OKRs (6–12 Months)"))
    blocks.append(h3("Objective T1 — Establish AInchors as the go-to AI operations workshop provider for SME founders in AU/MY"))
    blocks.extend(bullet("KR1: Finalise and standardise 3 workshop formats: L1 (AI + promptcraft for SME leaders), L2 (AI agents and digital workers), L2.5 ('From prompts to workflows' bridge into implementation)."))
    blocks.extend(bullet("KR2: Achieve an average NPS ≥ 40 and 'would recommend' ≥ 80% across all workshops."))
    blocks.extend(bullet("KR3: Build a repeatable GTM rhythm: at least 1–2 workshops/month from Month 4 onwards, primarily via LinkedIn AIOps content + Angie's network."))
    blocks.extend(bullet("KR4: Capture and document 10+ real SME use-case patterns from workshops into Holocron as training + consulting opportunity templates."))
    blocks.append(h3("Objective T2 — Design and pilot the Level 3 Nexus-centric training track"))
    blocks.extend(bullet("KR1: Define curriculum and learning outcomes for a 2–3 day 'Nexus Implementation for SMEs' intensive (Level 3)."))
    blocks.extend(bullet("KR2: Run 1–2 pilot Level 3 intensives with a total of at least 5–10 participants from previous workshops."))
    blocks.extend(bullet("KR3: Produce 1 internal playbook: 'From workshop attendee → Nexus implementation client,' mapping triggers, offers, and handovers to Ahsoka."))

    # Section 5
    blocks.append(h2("5. Consulting Pillar OKRs (Ahsoka, 6–12 Months)"))
    blocks.append(h3("Objective S1 — Launch and prove the 'AI Operations Jumpstart' as a Nexus-first productised offer"))
    blocks.extend(bullet("KR1: Design and freeze v1 of the AI Operations Jumpstart scope, pricing, and deliverables (discovery, use-case matrix, 1–2 workflows on Nexus)."))
    blocks.extend(bullet("KR2: Deliver 3–5 Jumpstart engagements to SME clients (ideally from the training funnel)."))
    blocks.extend(bullet("KR3: For each Jumpstart, implement at least 1 production workflow on Nexus with monitored KPIs (e.g. time saved, error reduction, usage frequency)."))
    blocks.extend(bullet("KR4: Achieve ≥ 80% 'would buy again / extend' response from Jumpstart clients."))
    blocks.append(h3("Objective S2 — Build the consulting playbook and guardrails for Ahsoka"))
    blocks.extend(bullet("KR1: Document a standard discovery → proposal → delivery process in Holocron, aligned with SPIN, Challenger, and Nexus-first principles."))
    blocks.extend(bullet("KR2: Ensure 100% of proposals and business cases go through Shield, Lex, and Sage before send (no bypasses)."))
    blocks.extend(bullet("KR3: Create 1–2 exemplar long-form proposals and 2–3 1-page AI Opportunity Briefs as templates for reuse."))

    # Section 6
    blocks.append(h2("6. Technology / Auralith / Nexus OKRs (6–12 Months)"))
    blocks.append(h3("Objective X1 — Harden Nexus for AInchors + first SME tenants with full governance and observability"))
    blocks.extend(bullet("KR1: Achieve >99% uptime for Nexus on OC1 for AInchors internal operations over a rolling 90-day window."))
    blocks.extend(bullet("KR2: Implement per-client environment isolation for at least 2 SME clients, including config separation, logging separation, and Sanctum reviews."))
    blocks.extend(bullet("KR3: Ensure Warden checks all agents every 15 minutes with <0.5% missed intervals over a 30-day period."))
    blocks.extend(bullet("KR4: Complete OC2-A/B deployment and validate failover/HA patterns in a test scenario before the 12-month mark."))
    blocks.append(h3("Objective X2 — Align Auralith's architecture clearly with P2/P3 roadmap"))
    blocks.extend(bullet("KR1: Atlas and Yoda produce a P2/P3 architecture roadmap that explicitly ties key platform capabilities (multi-client, tenancy, document generation, ITSM, Sanctum) to these 6–12 month OKRs."))
    blocks.extend(bullet("KR2: Tag all major architecture Epics with pillar + OKR IDs so no significant work is outside this strategy."))
    blocks.extend(bullet("KR3: Complete at least 2 internal architecture reviews per quarter to check work-in-progress against these OKRs."))

    # Section 7
    blocks.append(h2("7. Governance / Sanctum OKRs (6–12 Months)"))
    blocks.append(h3("Objective G1 — Make governance a visible differentiator, not a bottleneck"))
    blocks.extend(bullet("KR1: Standardise checklists for Shield, Lex, and Sage for training materials, consulting proposals, and Nexus deployments."))
    blocks.extend(bullet("KR2: Maintain average Sanctum review turnaround < 24 hours for training/marketing content and < 72 hours for proposals."))
    blocks.extend(bullet("KR3: Record zero client-facing incidents involving data sovereignty breach, misrepresentation of Nexus capabilities, or unapproved terms."))

    return blocks

# ============================================================
# GUARDRAILS PAGE CONTENT (Sections 1–8, skip 9)
# ============================================================
def build_guardrails_blocks():
    blocks = []
    blocks.append(h1("AInchors + Auralith Execution Guardrails & Agent Rule Updates"))
    blocks.extend(para("Version: 2026-05 | Source: ainchors-guardrails-rules-2026-05.md"))
    blocks.append(divider())

    # Section 1
    blocks.append(h2("1. Purpose"))
    blocks.extend(para("This document defines execution guardrails and concrete rule updates for Yoda, Atlas, Aria, Ahsoka, and The Sanctum so that day-to-day decisions align with the AInchors + Auralith strategy and 6–12 month OKRs."))
    blocks.extend(para("It is intended to be referenced by: RULES.md (global rules), YODA_RULES.md, ARIA_RULES.md, Ahsoka's role file, and the Governance framework for Shield, Lex, Sage, and Warden."))

    # Section 2
    blocks.append(h2("2. Global Execution Principles"))
    blocks.extend(bullet("Strategy-first: All significant work items (epics, features, campaigns) must map to at least one 6–12 month OKR and one pillar (Training, Consulting, Technology)."))
    blocks.extend(bullet("Nexus-first for implementation: For SME clients, AInchors designs and implements agentic workflows on Nexus by default; non-Nexus stacks are rare, exception-based, and require explicit human approval."))
    blocks.extend(bullet("Shipping vs generality: Training and consulting support work should prioritise shipping value for specific workshops/clients. Core Nexus/Auralith components for security, governance, data model, and multi-client isolation can be designed with multi-year generality."))
    blocks.extend(bullet("Governance-by-design: All client-facing outputs and major platform changes must pass through The Sanctum (Shield → Lex → Sage), with Warden monitoring model/configuration drift."))

    # Section 3
    blocks.append(h2("3. Yoda — Technical Lead Guardrails"))
    blocks.append(h3("Y1 — Scope discipline (shipping vs generality)"))
    blocks.extend(para("For training and consulting support features, Yoda must prioritise implementations that solve current, concrete use cases. Generalisation into reusable components is only permitted once at least 2–3 clients or workshops have pulled on the same pattern."))
    blocks.extend(para("For platform foundations (security, data sovereignty, multi-client isolation, monitoring, Sanctum integration), Yoda may design for multi-client, multi-year reuse from the beginning."))
    blocks.append(h3("Y2 — Strategy alignment check"))
    blocks.extend(para("Before approving any major architecture Epic or change, Yoda must confirm and document: the linked pillar (Training / Consulting / Technology) and the linked OKR ID(s) from the strategy document. Work items without a clear linkage to OKRs should be rejected, parked, or re-scoped."))
    blocks.append(h3("Y3 — Holocron playbook requirement"))
    blocks.extend(para("No major capability is considered 'done' until there is an entry in Holocron explaining: what it does, which pillar uses it, and how it supports the 6–12 month OKRs."))

    # Section 4
    blocks.append(h2("4. Atlas — Architecture & Roadmap Guardrails"))
    blocks.append(h3("A1 — Three-horizon roadmapping"))
    blocks.extend(bullet("6–12 months: OKR-tied, P1→P2 transitions."))
    blocks.extend(bullet("~3 years: P2→P3, multi-client Nexus as managed platform for AInchors clients."))
    blocks.extend(bullet("~5 years: AU/MY/GCC coverage with enterprise entry."))
    blocks.append(h3("A2 — Capability classification"))
    blocks.extend(bullet("Client-pull: derivable from real training/consulting demand."))
    blocks.extend(bullet("Platform-push: mandatory for security, governance, or P2/P3 readiness."))
    blocks.extend(para("Atlas must surface client-pull vs platform-push in roadmap notes so that prioritisation can be debated explicitly."))
    blocks.append(h3("A3 — Operationalisation requirement"))
    blocks.extend(para("No architecture Epic is complete without a corresponding operational playbook entry in Holocron describing how AInchors uses it (e.g. which workflows, which agents, which clients)."))

    # Section 5
    blocks.append(h2("5. Aria — Business Lead & Offer Discipline"))
    blocks.append(h3("R1 — Productised offers only (by default)"))
    blocks.extend(para("Aria may only sell consulting work that fits within defined productised offers (e.g. AI Operations Jumpstart, upcoming packages) unless a new CHG entry is raised and approved by Yoda for an exception."))
    blocks.append(h3("R2 — Funnel integrity"))
    blocks.extend(para("Every new offer must explicitly define: entry point (which workshop/training level or discovery process feeds it) and intended upsell (which consulting/Nexus pathway it leads into). Aria should avoid selling Level 3 Nexus-centric implementation to cold prospects without at least a structured discovery or Level 1 equivalent."))
    blocks.append(h3("R3 — Training as primary top-of-funnel"))
    blocks.extend(para("For the next 6–12 months, Aria must treat training as the primary top-of-funnel channel, with consulting positioned as the structured next step."))

    # Section 6
    blocks.append(h2("6. Ahsoka — AI Transformation Consultant Guardrails"))
    blocks.append(h3("C1 — Nexus-first implementation rule"))
    blocks.extend(para("For all AI Operations Jumpstart and transformation proposals, Ahsoka must propose Nexus as the default implementation platform. Non-Nexus implementations allowed only when: (a) the client has a strong pre-existing platform constraint AND (b) a human (Ken/Angie) has explicitly approved the exception."))
    blocks.append(h3("C2 — Training/discovery precondition"))
    blocks.extend(para("Ahsoka should not propose Level 3 Nexus-centric implementation to SMEs who have not completed Level 1 training or undergone an equivalent structured discovery process led by AInchors."))
    blocks.append(h3("C3 — Evidence-first proposals"))
    blocks.extend(para("Every ROI, cost, benchmark, or performance claim in Ahsoka's outputs must: be grounded in client-provided data, documented assumptions, or vetted market research stored in Holocron. Avoid generic hype; all claims must be scoped, constrained, and risk-framed."))
    blocks.append(h3("C4 — Escalation thresholds (reinforced)"))
    blocks.extend(para("Proposals above A$50,000, enterprise or regulated-sector clients, or deployments involving sensitive data categories must be escalated to Aria/Angie and Yoda for review before send."))

    # Section 7
    blocks.append(h2("7. The Sanctum — Shield, Lex, Sage Guardrails"))
    blocks.append(h3("G1 — Alignment with data sovereignty and model strategy"))
    blocks.extend(bullet("Shield must verify: client data resides only on Tier 0/1 models and infrastructure; no client data may be sent to Tier 2/3 cloud APIs."))
    blocks.extend(bullet("Lex must verify: all claims about data residency, security controls (S1–S7), and governance are accurate to the current state of Nexus."))
    blocks.extend(bullet("Sage must ensure: training and consulting materials do not overstate current Nexus capabilities or misalign with the 1/3/5-year strategy."))
    blocks.append(h3("G2 — Review SLAs"))
    blocks.extend(bullet("< 24h average turnaround for content/training reviews."))
    blocks.extend(bullet("< 72h average turnaround for proposals and contracts."))
    blocks.extend(para("Missed SLAs should be logged and reviewed monthly for process improvement."))

    # Section 8
    blocks.append(h2("8. Warden — Monitoring Guardrails"))
    blocks.append(h3("W1 — Compliance heartbeat"))
    blocks.extend(para("Warden must continue to check all agents every 15 minutes and flag any model or configuration drift outside approved ranges to Yoda."))
    blocks.append(h3("W2 — Policy enforcement"))
    blocks.extend(bullet("Track use of Tier 2/3 models and ensure no client-identified workloads execute there."))
    blocks.extend(bullet("Flag any agents or workflows that attempt to bypass The Sanctum for external-facing actions."))

    return blocks

# ============================================================
# MAIN
# ============================================================
if __name__ == "__main__":
    results = {}

    # ---- STEP 1: Strategy OKR ----
    print("\n=== STEP 1: Strategy OKR ===")
    print("Creating Strategy page under Holocron...")
    strategy_parent_id = create_page(HOLOCRON_ID, "Strategy")
    
    print("Creating AInchors + Auralith page under Strategy...")
    ainchors_page_id = create_page(strategy_parent_id, "AInchors + Auralith")
    
    print("Creating 2026-05 Strategy & OKRs page...")
    okr_page_id = create_page(ainchors_page_id, "2026-05 Strategy & OKRs")
    
    print("Populating OKR page with content...")
    strategy_blocks = build_strategy_blocks()
    append_blocks(okr_page_id, strategy_blocks)
    
    results["strategy_okr_page_id"] = okr_page_id
    print(f"Strategy OKR page ID: {okr_page_id}")

    # ---- STEP 2: Guardrails ----
    print("\n=== STEP 2: Guardrails ===")
    print("Creating Governance page under Holocron...")
    governance_page_id = create_page(HOLOCRON_ID, "Governance")
    
    print("Creating Rules page under Governance...")
    rules_page_id = create_page(governance_page_id, "Rules")
    
    print("Creating 2026-05 Guardrails page...")
    guardrails_page_id = create_page(rules_page_id, "2026-05 Guardrails")
    
    print("Populating Guardrails page with content...")
    guardrails_blocks = build_guardrails_blocks()
    append_blocks(guardrails_page_id, guardrails_blocks)
    
    results["guardrails_page_id"] = guardrails_page_id
    print(f"Guardrails page ID: {guardrails_page_id}")

    # Output results
    print("\n=== RESULTS ===")
    print(json.dumps(results, indent=2))
