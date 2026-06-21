# Context for Aria — What Yoda Has Built
_Updated daily by Yoda 🟢 | Aria reads this for platform context and training material development_
_Last updated: 2026-05-03 (Day 9 — AKB catch-up run — covering Day 8 + Day 9)_

## Memory Update — 2026-06-22
- **LinkedIn personal auth — FIXED ✅**: Ken has resolved the LinkedIn client secret mismatch. Angie's personal profile OAuth flow should now work. Aria can retry LinkedIn personal-account posting when Angie is ready.

---

This file gives Aria a curated, accurate view of what the AInchors technical team is building — the platform, the agents, the rules, and the why. Use it both for training content development and as a live reference for what's operational.

---

## Current Platform State (Day 9 — 2026-05-03)

### What's LIVE Right Now

| System | Status | Notes |
|--------|--------|-------|
| Yoda 🟢 (Lead Ops Agent) | ✅ LIVE | Ken's AI. Sonnet 4.6. OC1 Mac mini. |
| Aria 🔵 (Business Lead Agent) | ✅ LIVE | Angie's AI. Sonnet 4.6. OC1 Mac mini (migrates to OC2 later). |
| Shield 🛡️ (Security Governance) | ✅ LIVE | Haiku 4.5. Daily cron 22:00 AEST. |
| Lex ⚖️ (Legal Governance) | ✅ LIVE | Haiku 4.5. Daily cron 22:05 AEST. |
| Sage 🧪 (QA Governance) | ✅ LIVE | Haiku 4.5. Daily cron enabled. |
| Warden 🔍 (Model Compliance) | ✅ LIVE | Haiku 4.5. Every 15 min. Checks all 6 agents for model drift. |
| Spark ✨ (Social & Digital Marketing Agent) | ✅ LIVE | kimi-k2.6:cloud. **ALL social platforms** (LinkedIn, Instagram, Facebook, X). Ken approves personal content; Angie approves AInchors brand content. 3×/week (Tue/Wed/Thu). LinkedIn API connected (Member ID: FhpPCanUWM). First run: 2026-05-06. (CHG-0130/0137) |
| Content Governance Triad Gate | ✅ LIVE | scripts/content-governance-review.sh. Shield→Lex→Sage mandatory on ALL public content from ALL agents. TKT-0033, CHG-0129. |
| Warden Model Drift Monitoring | ✅ LIVE | 15-min cron. Replaced CI Framework (CHG-0428, deprecated 2026-05-24). Enforces model-policy.json compliance across all agents. |
| Health monitoring | ✅ LIVE | Checks every 15 min. `scripts/health-check.sh`. Fixed 2026-04-28. |
| Auto-heal | ✅ LIVE | Nightly 23:30 AEST. 12 checks. Auto-fixes stale state. |
| Daily journal cron | ✅ LIVE | 23:55 AEST — journal only (split from blog). |
| Daily blog cron | ✅ LIVE | 00:05 AEST — blog only (split from journal 2026-04-28). |
| AKB daily update cron | ✅ LIVE | 03:00 AEST — updates this Obsidian vault. Now runs on qwen3.5:cloud (Ollama Cloud free tier) with think=False (CHG-0110/0111). |
| Latency tracker | ✅ LIVE | obs-collector CHECK P (every 5 min). Baselines: Sonnet 8.2s avg, Haiku 3.1s avg, gemma4:e2b 2.8s avg, qwen3.5:cloud 58s avg. (CHG-0109) |
| Release monitor cron | ✅ LIVE | Daily 06:00 AEST. Auto-detects OpenClaw security patches (TRIGGER-04) and v4.0 (TRIGGER-06). Cron 6bd53c89. |
| Telegram: Ken → @AInchorsOC1Bot | ✅ LIVE | Routes to Yoda. Ken only. Hard allowlist. |
| Telegram: Angie → @AInchorsAriaBot | ✅ LIVE | Routes to Aria. Angie only. Hard allowlist. |
| Cost tracking | ✅ LIVE | Midday cost tracker cron. 3-tier credit alerts. |
| Resiliency stack | ✅ LIVE | See `Operations/ResiliencyFramework.md`. 5-level stack. |
| ITSM ticketing (TKT-NNNN) | ✅ LIVE | Ticket-first rule. Every piece of work gets a ticket. |
| Change log (CHG-NNNN) | ✅ LIVE | Append-only. Every config/script/rule change logged. |

### What's PLANNED (not yet built)
- Business sub-agents: Social 📣 (Instagram/Facebook; LinkedIn covered by Spark ✨), Content ✍️ (TKT-0035), Marketing 🎯, Support 🎧, Report 📊
- Technical sub-agents: Dev 🔧, Research 🔬, Infra 🏗️
- OC2 (ETA July 2026)
- Automated social posting (TKT-0034 — when social accounts connected)
- Tailscale (OC1↔OC2 cross-instance)

---

## The 4-Tier Model Strategy (Tier 2b LIVE as of 2026-05-02)

| Tier | Model | Use | Cost |
|------|-------|-----|------|
| Tier 1 Interactive | Claude Sonnet 4.6 | All direct Ken/Angie conversations, orchestration | $3/$15 MTok |
| Tier 2a Sub-tasks | Claude Haiku 4.5 | Governance sweeps, Warden, health checks, bounded sub-tasks | $1/$5 MTok (3× cheaper) |
| **Tier 2b Ollama Cloud** ✅ NEW | **kimi-k2.6:cloud / deepseek-v4-flash:cloud / deepseek-v4-pro:cloud** | Background, creative, non-sensitive AInchors ops ONLY. **No PII, no client data.** | ~$30/mo flat |
| Tier 3 Background | Ollama gemma4:e2b | Cost tracker, asset review, batch crons | Free (local) |
| Emergency fallback | Ollama gemma4:26b | Offline only — Anthropic API down | Free (local) |

**Aria's model (as of CREST v1.3 / CHG-0680):** Resolved by `model-policy-query.sh` based on phase role, not self-selected.
- Plan / Replan: `ollama/kimi-k2.6:cloud`
- Execute / Synthesize: `ollama/deepseek-v4-flash:cloud`
- Verify (evidence assembly only, Sage renders verdict): `ollama/gemma4:31b-cloud`
- Interactive conversations with Angie/Ken follow the phase being executed.
**Aria rule:** Do not append a model signature (e.g., "_⚙️ Model: ..._") to responses. Model metadata is tracked by the runtime, not the agent. Gemma4 is never used in interactive Aria conversation paths.

---

## Governance Gate — What Aria Needs to Know

### The Gate: Shield → Lex → Sage (non-negotiable)
All three governance agents must PASS before Aria delivers anything externally:
- **Shield 🛡️** — 5 security checks (S1–S5): credentials, PII, data classification, send authorisation
- **Lex ⚖️** — 5 legal checks (L1–L5): ACL, Privacy Act, IP, disclosures, liability
- **Sage 🧪** — 5 QA checks (C1–C5): brief met, accuracy, completeness, brand voice, no fabrication

Any single FAIL = delivery halted.

### Aria's Ask-First Rule (CHG-0055)
**Aria does NOT auto-run the governance gate.** Process:
1. Generate content
2. Assess whether governance is needed
3. **Stop and ask Angie** to confirm before running the gate
4. Proceed based on Angie's response

This keeps Angie in control. Governance is opt-in at the point of delivery, not automatic on every message.

### Aria Tail Format
Every Aria response where governance ran or was offered must include:
```
🏛️ Governance: [PASS ✅ | FAIL 🚫 | Skipped | Not applicable]
```

### /governance Command
Angie (or Ken) can type `/governance` at any time to get a full gate report.  
Script: `scripts/governance-report.sh`

---

## /credit Command
Type `/credit` to get the current API credit balance and burn rate.  
Three-tier alert system (recalibrated 2026-04-28 — actual $101/day burn rate):
- Tier 1 ($80 remaining): Yellow alert (one-time, both Ken + Angie)
- Tier 2 ($40 remaining): Orange alert (every 3rd response)
- Tier 3 ($15 remaining): RED — all work pauses, ack required

**Recipients:** Ken (Telegram 8574109706) + Angie via Aria (@AInchorsAriaBot). CHG-0071.

---

## Resiliency Stack (5 levels)
See `Operations/ResiliencyFramework.md` for full detail. Summary:
1. **Auto-Heal** — nightly 23:30, self-fixes 12 checks
2. **Run Diagnostics** — on-demand `/diagnostics`, 6 phases
3. **Change Log** — every change tracked with CHG-NNNN
4. **Critical Config Baseline** — anti-drift guard on 7 configs
5. **Gateway Recovery SOP** — `Operations/GatewayRecovery.md`

---

## Business ROI Framework (F8 — Aria must implement)

Built 2026-04-28. Aria tracks business stream value.

**Aria rule (non-negotiable):** Call `scripts/log-business-value.sh` after EVERY value-generating activity.

**Value categories:** Content & IP, Campaign management, Governance compliance, Operational efficiency, Direct revenue attribution.

**Campaign tracking:** `scripts/log-campaign.sh` to track campaigns; `scripts/campaign-debrief.sh` after each campaign closes.

Current campaign: **CAMP-0001** — KL AI Prompt Engineering 101, 30 April. 21/24 seats filled. Goal met.

**Weekly ROI cron:** Sunday 18:00 AEST — ROI summary to Angie.

---

## Day 9 Updates Summary (2026-05-03)

### Key changes affecting Aria's work:
- **Spark scope expanded** — now Social & Digital Marketing Agent for ALL platforms (not just LinkedIn). Ken personal content = Ken approves. AInchors brand content = Angie approves.
- **LinkedIn Authority Campaign Week 1 approved** — 4 posts queued (Tue/Wed/Thu/Fri). Posting starts Tue 2026-05-06 07:30 AEST via API.
- **Notion AKB Backlog** — single source of truth for ALL US/TKT/CHG. ticket.sh + changelog-append.sh auto-sync every write. Aria: use Notion as the authoritative work item record.
- **Company name** — **Ainchor Solutions Pty Ltd** (not AI Anchor Solutions, not AInchors Solutions). Short name: AInchors. Domain: ainchors.com.
- **LinkedIn API live** — Ken's LinkedIn Member ID: FhpPCanUWM. Posting will happen via API from Tuesday.
- **OpenClaw updated** to v2026.5.2. Platform more secure.
- **Anthropic account moved** to AInchors account (accounts@ainchors.com). Personal account retired.
- **Balance: $495.26 USD** (topped up Day 9). Alert tiers all reset.

---

## Day 9 Business Stream Priorities (from 3 May — Sunday)

| Priority | Item | Action |
|----------|------|---------|
| 🔴 | **Angie warm check-in** | Day 3+ of no Angie contact. Aria to send warm Telegram check-in Sat 2 May. |
| 🔴 | **April 30 class debrief** | CAMP-0001 still open. No debrief received. Gentle nudge. Run campaign-debrief.sh after Angie responds. |
| 🔴 | JotForm API key | Still outstanding since 28 April. HRDF form blocked. |
| 🟡 | Meta appeal | Status unknown. |
| 🟡 | Social posts (Instagram/WhatsApp/Facebook) | Drafted 28 April, publication status unknown. |
| 🟢 | Onboarding Stage 1 | OB-02, OB-04–OB-07 unchecked. Stages 2–6 not started. Warm re-engagement today. |

---

## AKB Daily Update Cron
- **Time:** 03:00 AEST daily
- **What:** Yoda reads source files and updates all stale AKB documents in this vault
- **Scope:** HOME.md, Architecture.md, ModelStrategy.md, GovernanceFramework.md, Overview.md, context-for-aria.md, yoda-daily-brief.md
- **Git commit:** Auto-commits after each update pass

---

## Key Lessons for Training Content

### Lesson 1: Start with Identity
Before an AI agent can do anything useful, it needs identity. Name, personality, values, rules. Without this, it's a tool. With it, it's a team member.

### Lesson 2: Build the Safety Net First
Before doing any "real work," Ken and Yoda spent Day 1 on monitoring, backups, and recovery procedures. Most businesses skip this and regret it.

### Lesson 3: Every Incident is a Teacher
Multiple outages in 4 days. Each one became a new prevention rule. The platform is stronger after each failure, not weaker. This is the mindset shift AI-first companies need.

### Lesson 4: Governance is Not Optional
Day 4 achievement: three non-negotiable governance gates (security, legal, QA) running as live agents on every external output. Most businesses have none.

### Lesson 5: Model Cost Strategy Matters
Running everything on the most expensive model costs 3× what a tiered strategy costs. Day 4: moved governance agents to Haiku (3× cheaper) — estimated A$450–600/month saving.

### Lesson 6: Reactive → Proactive in 72 Hours
Day 1: Ken spotted problems and told Yoda to fix them.
Day 4: The system fixes itself overnight, audits all agents every 15 minutes, and reports results at morning standup.
This is the journey every AI-adopting business will take.

### Lesson 7: The Real Cost of AI Operations
Days 1–3 actual run rate: ~A$2,100/month equivalent. The A$500/month estimate was too optimistic. Transparency and measurement are essential.

### Lesson 8: Silent Truncation Is Lethal (Day 6)
Aria's SOUL.md was 17,393 characters. OpenClaw silently truncated it at ~10,000. No warning. Wrong Telegram targets → stuck session → gateway crash. Rule: AI agent config file size is a hard system constraint. Monitor it. The platform crashed twice before the root cause was found.

### Lesson 9: Your Watcher Needs a Watcher (Day 6)
The observability system (obs.db) was running but not watching the gateway logs. When the gateway crashed, obs.db missed it. 13 gateway error patterns and 10 new system checks were added. Monitoring infrastructure is not automatically monitored.

### Lesson 11: HIVE Architecture — Plan for Scale Before You Need It (Day 7)
Ken formalised the HIVE infrastructure plan on Day 7: OC1 (Mac mini M4 24GB) = permanent orchestration hub. OC2-A + OC2-B (Mac mini M4 Pro 48GB each) arriving July 2026. Key insight: OC1 has a HARD LIMIT — it cannot run local LLM inference above ~8B Q4. This is hardware, not config. Planning for that constraint ahead of time means no surprises when clients arrive.

### Lesson 12: think=False — One Parameter, 94% Latency Drop (Day 7)
The Ollama Cloud qwen3.5 model averaged 58 seconds per response. Adding a single instruction (`think=False`) dropped structured-task latency to 4 seconds. The model's default 'thinking' mode is designed for complex reasoning — wasteful on simple, structured outputs like AKB file updates. Always match inference mode to task type.

### Lesson 13: Free Alternatives Have Real Constraints (Day 7)
Ollama Cloud free tier: 3 million tokens/day, $0. Sounds perfect. Reality: only one model available (qwen3.5); frontier models (kimi-k2.6, deepseek) require paid subscription. Latency 58 seconds. Perfect for overnight batch jobs — not for anything interactive. The lesson: evaluate AI cost alternatives on latency, model availability, and task fit — not just price.

### Lesson 14: PoC → Production Same Day (Day 8)
Ken signed up for Ollama Pro at 09:14. PoC results were in by 10:13. Three Tier 2b models were live in production by lunchtime. Estimated saving: $690–1,755/mo. The lesson: when you have a clear success criterion, move from proof-of-concept to production the same day. Waiting "to be sure" is just delay.

### Lesson 15: AI Reviewing AI — The Content Governance Gate (Day 8)
We built a three-agent governance gate (Shield→Lex→Sage) that runs before every public-facing output. No human reviews every piece of AI-generated content manually. The governance layer is as automated as the creation layer. As AI generates more business content at scale, this isn't optional — it's infrastructure.

### Lesson 16: A Specialised Agent Beats a General One (Day 8)
Spark ✨ isn't "the AI that does LinkedIn". It has a specific persona (Ken's voice, practitioner-heavy), a specific model (kimi for creative speed), specific governance rules, a specific approval workflow, and a specific content strategy. Specificity is what makes an AI agent reliably useful. General-purpose agents drift.

### Lesson 18: One Key Rotation = Two Incidents (Day 9)
When we rotated the Anthropic API key (CHG-0139), we updated the gateway config but forgot the macOS Keychain entry. Result: gateway worked fine, but every script that reads from Keychain hit 401. Standby mode activated. Fix took 19 minutes. New rule: key rotation now triggers auto-heal Check #16 (keychain liveness validation). And all scripts now route through one canonical `get-secret.sh` file — one place to update, everywhere benefits.

### Lesson 17: Model Selection Moves to Warden (Day 8 → Day 31)
Originally we built a CI Framework that benchmarked models against real tasks weekly. With the permanent move off Claude, model evaluation shifted to Warden's 15-min drift monitoring and the monthly model strategy review. The lesson: when the landscape changes, retire systems that no longer serve their purpose — don't let them become zombie processes.

### Lesson 10: Classify Before You Build (Day 6)
Before Day 6, every new cron defaulted to an AI model. Now there's a gate: Tier 0 (script only), Tier 1 (minimal AI), Tier 2 (needs reasoning). Three crons reclassified from Tier 2 → Tier 0. Saving ~$1.50/day. Small number, important principle.

---

## Training Content Pipeline

Use the `Training/` directory to draft content. Structure:
- `Training/module-XX-title.md` — course modules
- `Training/case-study-XX-title.md` — real AInchors case studies
- `Training/quick-win-XX-title.md` — client quick-win guides

**Priority content ideas (Days 1–6):**
1. "How to give an AI agent an identity" (Yoda bootstrap story)
2. "Building health monitoring for your AI" (health-check.sh)
3. "When AI breaks: incident management for AI operations" (outages + lessons)
4. "From reactive to proactive: auto-healing AI systems" (auto-heal.sh)
5. "The real cost of AI: tracking and optimising AI spend" (cost tracker, 3-tier model strategy)
6. "ITIL for AI: bringing service management to AI operations" (ITSM framework)
7. "The governance layer: security, legal, and QA as agents" (Shield/Lex/Sage)
8. "Two bots, no confusion: clean Telegram architecture" (dual-bot setup)
9. "Model cost strategy: why you shouldn't use the most expensive model for everything" (3-tier strategy)
10. "Silent model drift: how $23 vanished before anyone noticed" (anti-drift guard)
11. "The 17KB config that crashed our platform — twice" (Aria SOUL.md truncation incident)
12. "When 2,048 tokens kills your server" (gemma4:e2b incompatibility crash)
13. "Your AI platform’s watcher needs a watcher" (obs.db + gateway monitoring gap)
14. "Tier 0, 1, or 2? Classifying AI tasks before you build them" (cron LLM classification)
15. "Rose, Thorn, Bud as an AI delivery model" (RTB operating model)
16. "HIVE Architecture: planning for scale before you need it" (OC1 permanent, OC2 July 2026)
17. "think=False: 94% latency reduction with one parameter" (qwen3.5:cloud structured task optimisation)
18. "Free isn't free: what Ollama Cloud actually costs in latency" (PoC PARTIAL PASS findings)
19. "The $85 blind spot in AI cost tracking" (cost-tracker.sh cache_write gap, CHG-0098)
20. "Security audit before your first client: the S1-S7 framework" (7 controls, 6/7 PASS)
21. "How we cut our AI bill by $1,755/month — and what failed" (Ollama Cloud PoC, three pass, two fail, same-day production)
22. "Building an AI content governance system: why AI should review AI" (Shield→Lex→Sage triad gate, all agents, all public content)
23. "From idea to LinkedIn post: how we built a social content agent in one day" (Spark ✨ architecture, model choice, approval flow)
24. "One key rotation, two incidents: the hidden fragility of distributed secrets" (CHG-0139, INC-20260503-001, canonical get-secret.sh solution)
26. "From LinkedIn agent to Social & Digital Marketing Agent: how scope expands when foundations are solid" (Spark ✨ expansion, Day 9)

---

## Technical Context (Aria can reference but doesn't need to understand deeply)
- Platform: OpenClaw on macOS Mac mini (OC1)
- AI models: Claude Sonnet 4.6 (default interactive), Claude Haiku 4.5 (governance/sub-tasks), Gemma4:e2b (background/free)
- Tools: Notion (project management), Obsidian (knowledge base), Telegram (alerts)
- Approach: ITIL 4-aligned, ITSM framework, 3-tier resiliency, 3-tier model strategy
- Scripts live in: `~/.openclaw/workspace/scripts/`
- State files live in: `~/.openclaw/workspace/state/`
