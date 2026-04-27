# MEMORY.md - Yoda's Long-Term Memory

## Identity
- Name: Yoda 🟢
- Role: AI business operations lead agent
- Lead agent for Ken Mun (CTO)

## The People
- **Ken Mun** — Co-founder, CTO. Technical lead. My direct operator.
  - Email: kenmun@ainchors.com | Mobile: +61403650578
- **Angie Foong** — Co-founder, CEO. Business lead. Has trainers, marketing/sales, support staff.
  - Email: angie.foong@ainchors.com | Mobile: +61430928371
  - **Authority: CEO = highest authority. Full access to all AInchors information via Aria.**
  - Aria 🔵 acts on Angie's behalf with full read access to all data (Yoda workspace, Obsidian, Notion, state files)
  - Telegram: paired to @AInchorsOC1Bot → routes to Aria (ID: 8141152780)

## The Company
- **Name:** AI Anchor Solutions Pty Ltd
- **Short name:** AInchors
- **Domain:** ainchors.com
- **Stage:** Brand new. Day 1 of technical department = 2026-04-25.
- **Focus:** 
  1. AI courses & training for businesses
  2. AI consulting services
  3. Building AI solutions (products/custom builds)
- **Technical team size:** 1 (Ken) + me as lead agent. Growing.

## Email Accounts
- ken@ainchors.com → kenmun@ainchors.com (being set up)
- info@ainchors.com
- accounts@ainchors.com
- Provider: Gmail (Google Workspace)

## Two Streams of Work
### Technical Stream (Ken / CTO)
- Build AI agentic foundation
- Build and manage AI agent team
- Platform development
- I (Yoda) am the lead agent for this stream

### Business Stream (Angie / CEO)
- Training delivery
- Marketing & sales
- Support operations
- AI agents to handle and expand these functions

## Tools to Integrate (full scope)
- Email
- Calendar
- Project management
- Comms (team messaging)
- Coding / dev tools
- Video creation & editing
- Slides & presentations
- Documents & Excel
- Image creation & editing
- Web content management (CMS)
- Social media — posting, listening, responding, management
  - Priority order: Instagram → Facebook → LinkedIn
- Proposal creation
- Reporting

## Infrastructure
- **OC1 (this Mac mini):** Permanent base. Yoda runs here. Technical stream lead + oversight of all.
- **OC2 (future Mac mini):** Angie's machine. Business stream agents. Managed by Angie, overseen by Yoda.
- Current Mac mini → becomes OC2 when Yoda migrates to new, more powerful Mac mini.
- Tailscale: critical for OC1↔OC2 cross-instance communication (Phase 3, not Phase 4)
- Telegram: Ken's secondary channel (urgent/offline)

## Dual-Instance Architecture
- Yoda (OC1) = Lead agent. Oversees OC2. Manages holistic knowledge, decisions, context.
- OC2 = Business stream. Angie's instance. Sub-agents managed locally there.
- Cross-instance: Yoda assigns work to OC2, reviews outputs, maintains alignment.
- Shared knowledge: synced via Obsidian vault (iCloud or Git) + structured handoffs.
- Yoda must be PORTABLE — full migration guide required before new Mac mini arrives.

## Agent Architecture Plan
- Two streams: Technical + Business
- Yoda = lead agent (technical stream primary, oversees all)
- Sub-agents to be built for: content, social, support, marketing, reporting, coding
- Angie's team to eventually have their own AI agent layer

## Open Items
- Company name not yet captured — ask Ken
- Email: kenmun@ainchors.com being set up — integrate once live
- Project management tool: not yet decided
- Social media accounts not yet connected (Instagram, Facebook, LinkedIn — in priority order)
- Remote access (Tailscale) deferred
- Agent team to be designed and built

## Active Backlog (User Stories — Notion source of truth)
- US18: Monthly SLA Report (reliability)
- US19: HA Design (reliability)
- US20: Research Framework formalised
- US22: Fix cost tracker script (parser broken — High)
- **US23: Resilient outage handling (High, Platform, M)** — NEW Day 3. Triggered by 2026-04-26 night outage. Auto-detect billing/auth failures, validate fallback chain on boot + first failure, Gemma4 standby mode with user-facing banner, full recovery doc.
- PiKVM remote access (deferred, hardware dependency)
