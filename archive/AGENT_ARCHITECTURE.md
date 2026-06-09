# AInchors AI Agent Architecture — TOM (Target Operating Model)
_Version 2.1 — 2026-04-26 | "TOM" is the canonical term for this agent team roster_
_Canonical doc: ~/Documents/AInchors/Agents/Architecture.md_

---

## Overview

Two operational streams. One lead agent. Shared memory backbone.

```
                        ┌─────────────────┐
                        │   Ken (CTO)     │
                        │   Angie (CEO)   │
                        └────────┬────────┘
                                 │
                        ┌────────▼────────┐
                        │   YODA 🟢       │
                        │   Lead Agent    │
                        │   Orchestrator  │
                        └──────┬──────────┘
                               │
              ┌────────────────┴────────────────┐
              │                                 │
   ┌──────────▼──────────┐           ┌──────────▼──────────┐
   │  TECHNICAL STREAM   │           │   BUSINESS STREAM   │
   │  (Ken / CTO)        │           │   (Angie / CEO)     │
   └──────────┬──────────┘           └──────────┬──────────┘
              │                                 │
   ┌──────────▼──────────┐           ┌──────────▼──────────┐
   │ 🔧 Dev Agent        │           │ 📣 Social Agent      │
   │ 🔬 Research Agent   │           │ ✍️  Content Agent    │
   │ 🏗️  Infra Agent     │           │ 🎯 Marketing Agent   │
   │                     │           │ 🎧 Support Agent     │
   │                     │           │ 📊 Report Agent      │
   │                     │           │ 🔎 Research Agent    │
   └─────────────────────┘           └─────────────────────┘
```

---

## Agent Roster

### Lead Agent
| Agent | Role | Owner |
|-------|------|-------|
| Yoda 🟢 | Lead orchestrator. Manages all agents, routes tasks, holds global context, reports to Ken and Angie. | Ken |

### Technical Stream
| Agent | Role | Key Tools |
|-------|------|-----------|
| Dev Agent 🔧 | Code generation, debugging, architecture, builds, code review | Coding, exec, file ops |
| Research Agent 🔬 | AI research, competitive intel, technical analysis, documentation | Web search, fetch, summarise |
| Infra Agent 🏗️ | Platform ops, deployments, monitoring, config management | Exec, SSH, config |

### Business Stream
| Agent | Role | Key Tools |
|-------|------|-----------|
| Social Agent 📣 | Instagram, Facebook, LinkedIn — post, monitor, engage, report | Social APIs, image gen |
| Content Agent ✍️ | Course content, blog posts, training materials, scripts | Docs, slides, video briefs |
| Marketing Agent 🎯 | Campaigns, email marketing, lead gen, funnels | Email, CRM, analytics |
| Support Agent 🎧 | Customer queries, triage, escalation, ticketing | Email, comms, knowledge base |
| Report Agent 📊 | Weekly/monthly reports, dashboards, proposals, decks | Data, slides, docs |
| Research Agent 🔎 | Market research, competitor analysis, industry trends, client intel, pricing, opportunity identification | Web search, fetch, summarise, reports |

---

## Shared Memory Architecture

All agents share one workspace. Memory is file-based — structured, readable, writable by any agent.

```
workspace/
├── MEMORY.md                    # Yoda's long-term curated memory (main session)
├── SHARED_CONTEXT.md            # Business context shared by ALL agents
├── AGENT_ARCHITECTURE.md        # This file
│
├── memory/
│   ├── YYYY-MM-DD.md            # Daily logs (Yoda)
│   ├── shared/
│   │   ├── company.md           # Company facts, brand, tone, contacts
│   │   ├── projects.md          # Active projects + status
│   │   ├── decisions.md         # Key decisions log
│   │   └── integrations.md      # Tool/API connection status
│   └── agents/
│       ├── social.md            # Social agent state + last run
│       ├── content.md           # Content agent state + queue
│       ├── marketing.md         # Marketing agent state
│       ├── support.md           # Support agent state + tickets
│       └── report.md            # Report agent state + schedules
│
├── handoff/
│   ├── queue.md                 # Active task handoff queue
│   └── YYYY-MM-DD-HH-task.md   # Individual task handoff files
│
└── state/
    ├── heartbeat-state.json     # Heartbeat check tracking
    └── agent-status.json        # All agent last-run + health
```

---

## Handoff Protocol

When Yoda assigns a task to a sub-agent:

1. **Create handoff file** in `handoff/` with:
   - Task ID
   - Assigned agent
   - Context (what they need to know)
   - Input (what to work on)
   - Expected output
   - Deadline/priority

2. **Sub-agent reads handoff**, executes, writes output back to file.

3. **Yoda reviews output**, updates `memory/shared/projects.md` and `state/agent-status.json`.

4. **Archive** completed handoff.

### Handoff File Template
```markdown
# TASK-{ID}
- **Agent:** {agent-name}
- **Status:** pending | in-progress | done | failed
- **Priority:** low | normal | high | urgent
- **Created:** {timestamp}
- **Due:** {deadline or ASAP}

## Context
{what the agent needs to know}

## Task
{what to do}

## Expected Output
{what done looks like}

## Output
{filled by agent on completion}
```

---

## Communication Flow

- **Ken → Yoda:** Web chat (primary), Telegram (urgent)
- **Yoda → Ken:** Web chat (replies), Telegram (urgent/offline alerts)
- **Yoda → Sub-agents:** Task spawning via sessions_spawn, handoff files
- **Sub-agents → Yoda:** Output via handoff files, announce delivery
- **Yoda → Angie's team:** Via report outputs, email drafts (with Ken approval)

---

## Escalation Rules

| Trigger | Action |
|---------|--------|
| Sub-agent fails 2x | Yoda takes over, alerts Ken |
| Urgent external message | Yoda notifies Ken on Telegram |
| Decision required | Yoda flags to Ken, does not proceed |
| External send (email, social post) | Always ask Ken first |

---

## Build Order (Phases)

### Phase 1 — Foundation (Now)
- [x] Yoda identity + memory
- [x] Telegram channel
- [ ] Shared memory structure created
- [ ] SHARED_CONTEXT.md populated
- [ ] Heartbeat optimised
- [ ] Gmail integration
- [ ] Calendar integration

### Phase 2 — Technical Stream
- [ ] Dev Agent deployed
- [ ] Research Agent deployed
- [ ] Infra Agent deployed
- [ ] Project management tool selected + integrated

### Phase 3 — Business Stream
- [ ] Social Agent deployed (Instagram → Facebook → LinkedIn)
- [ ] Content Agent deployed
- [ ] Support Agent deployed
- [ ] Marketing Agent deployed
- [ ] Report Agent deployed
- [ ] Research Agent 🔎 deployed (Business Stream)

### Phase 4 — Full Operations
- [ ] Remote dashboard (Tailscale)
- [ ] All integrations live
- [ ] Agents running autonomously
- [ ] Weekly reporting to Ken + Angie
