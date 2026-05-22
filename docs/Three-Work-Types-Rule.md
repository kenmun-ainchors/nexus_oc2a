# Three Work Types Rule

This document codifies the foundational architecture framework for work currency and routing within the system.

## 1. Work Currency Definitions

The system recognizes exactly three work currencies. Each currency has a clear boundary based on the nature of the task, the required cognitive load, and the associated cost/resource tier.

| Currency | Definition | Examples | Route to | Model Tier |
|---|---|---|---|---|
| **HIGH** | Reasoning, judgment, design, architecture decisions | Architecture design, security audits, client proposals, governance decisions, CHG approvals, legal review, new agent activation | Claude Sonnet (T3) | Paid premium, fallback only |
| **MEDIUM** | Content generation, template filling, classification, data analysis, code generation | Blog writing, ticket summarisation, data classification, code refactoring, test generation, content moderation | Ollama Cloud (T2) | Flat-rate ($100/mo) |
| **LOW/ZERO** | CRUD operations, system calls, state file reads/writes, health checks | Ticket status updates, state.json writes, health checks, file ops, git commits, backups, cron management | Script layer (T1/$0) | bash/python3/jq |

## 2. Work Currency Routing Table

The following patterns map common Nexus tasks to their correct currency tier.

| Task Pattern | Currency | Route |
|---|---|---|
| Agent writes to tickets.json | LOW | script (`ticket.sh`) |
| Agent generates EOD blog | MEDIUM | Ollama Cloud (`deepseek-v4-pro`) |
| Agent proposes architecture change | HIGH | Claude Sonnet |
| Warden checks model compliance | LOW | script (`model-drift-check.sh`) |
| Shield reviews external content | MEDIUM | Ollama Cloud |
| Lex reviews legal document | HIGH | Claude Sonnet |
| Auto-heal runs health checks | LOW | script |
| Cron run fails $\rightarrow$ dead-letter | LOW | script |
| Budget check calculation | LOW | script |
| Agent creates new cron job | MEDIUM | Ollama Cloud |
| Yoda classifies incoming task | MEDIUM | Ollama Cloud |
| Sage validates policy accuracy | HIGH (Complex) / MEDIUM (Routine) | Claude Sonnet / Ollama Cloud |
| Agent spawns sub-agent | LOW | OpenClaw built-in |
| Git commit and push | LOW | script |
| Generate DOCX from template | LOW | script (`generate-doc.sh`) |

## 3. Escalation Rule

When a task fails, the system follows a strictly defined tier-up-on-failure pattern to ensure reliability without wasting high-tier resources.

**Pattern:**
1. **Initial Attempt:** Task starts at its assigned currency tier.
2. **Local Failure:** If the tier fails, retry once with a self-debugging prompt.
3. **Tier Escalation:** If it still fails, escalate **UP** one tier.
4. **T2 $\rightarrow$ T3 Escalation:** When escalating to T3, provide minimal context only (task summary + errors + relevant snippets). Do not dump the full transcript.
5. **Hard Stop:** If the task still fails at T3, trigger a **HITL (Human-In-The-Loop) gate**. Stop all automation and ask Ken.
