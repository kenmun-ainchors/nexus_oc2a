# Training Content Pipeline
_For Aria 🔵 & the Spark content engine | Ideas from daily platform work that can become social/media content_

---

## Pipeline Status

| ID | Title | Status | Date Added | Source |
|---|---|---|---|---|
| TC-193 | The database sequence that broke silently: silent infrastructure failures in AI platforms | 💡 idea | 2026-06-07 | CHG-0463 PG sequence desync |
| TC-194 | Closing a sprint with an AI team: ceremony discipline for automated operations | 💡 idea | 2026-06-07 | Sprint 6 close + re-sequence |
| TC-195 | When the sandbox crashes production: why logical separation isn't enough | 💡 idea | 2026-06-08 | INC-20260608-001 + CHG-0471 |
| TC-196 | Your QA bot keeps failing? Check the context window first | 💡 idea | 2026-06-08 | CHG-0472 Sage model change |
| TC-197 | Measure what you think you're measuring: mirror lag vs ticket dormancy | 💡 idea | 2026-06-08 | CHG-0473 Harness v2.2 |
| TC-198 | 108 tickets, 4 categories, 1 afternoon: how to hygiene-sweep a 14-month ticket backlog | 💡 idea | 2026-06-12 | TKT-0407 sweep |
| TC-199 | Your AI lied about completing the sweep: a CRITICAL lesson in trusting summaries | 💡 idea | 2026-06-12 | L-084 fabrication incident |
| TC-200 | 28 days of training wheels: from 'Ask Ken' to structural guards (CREST v1.3) | 💡 idea | 2026-06-12 | CHG-0500 Conservative Mode lift |
| TC-201 | The build-in-public redemption arc: why 3 content angles got rejected and the 4th stuck | 💡 idea | 2026-06-12 | Spark v1→v2 reactivation |
| TC-202 | Stub-victim pattern: when duplicate ticket IDs silently break your data integrity | 💡 idea | 2026-06-12 | L-077 + L-085, TKT-0339 duplicates |
| TC-203 | QBR defense in depth: 5 layers so no single failure drops the quarter | 💡 idea | 2026-06-12 | CHG-0505 QBR lock-in |
| TC-204 | The 5-layer anti-regression stack: building defense-in-depth for AI automation | 💡 idea | 2026-06-15 | L-137 defense stack (syntax + wiring + null-safety + cooldown-gating + pipefail-trap) |
| TC-205 | 'SHOULD_FIRE=false' is not enough: why you must gate the side effect, not the flag | 💡 idea | 2026-06-15 | L-136 cooldown-gating bug |
| TC-206 | The sprint build-on rule: additive planning that prevents knowledge loss | 💡 idea | 2026-06-15 | L-140 Sprint plan discipline, Sprint 8 ceremony |
| TC-207 | When subagents lie about their own tests: the verifier_corpus pattern | 💡 idea | 2026-06-15 | L-139 anti-subagent-trap, CHG-0590 |
| TC-208 | Script wrappers don't need AI models: 14 cron conversions saved 70% cloud calls | 💡 idea | 2026-06-15 | CHG-0601/0602 batch cron downgrade |
| TC-209 | 24 lessons in one day: the silence-failure family and why automation bugs stay hidden | 💡 idea | 2026-06-15 | L-116 through L-140, 33 CHGs in one day |
| TC-210 | The day my AI bill became the loudest thing in the room | 💡 idea | 2026-06-16 | LI-W1-P1 — first post of the 4-week Foundation Arc |
| TC-211 | 572× undercount: your gateway logs are not a billing system | 💡 idea | 2026-06-17 | CHG-0618/0619 — Ollama dashboard scraper vs log counter (28 vs 15,932 requests) |
| TC-212 | When the cron cache lies: fresh data beats cached snapshots for alerting | 💡 idea | 2026-06-17 | CHG-0606 — 30-min cache false alert fix, quota canary |
| TC-213 | Wrong workspace, no error: 8 silent cron failures discovered by audit | 💡 idea | 2026-06-17 | CHG-0617 — WO-002 cross-workspace sandbox fix |
| TC-214 | I tried to jail my AI. The guard didn't exist. | 💡 idea | 2026-06-17 | CHG-0608/0609 — CREST §6 tools.deny experiment, discipline-based governance |
| TC-215 | 37 files, 3,647 lines removed: git commit as progress, not mess | 💡 idea | 2026-06-17 | CHG-0611 — tribal knowledge evicted from agent files, skill-load pointers installed |
| TC-216 | Model swap: 1 GPU tier down, same output | 💡 idea | 2026-06-17 | CHG-0621 — deepseek-v4-pro → kimi-k2.7-code trial, cost vs capability matching |
| TC-217 | Your subagent said it's done. The git log says otherwise. | 💡 idea | 2026-06-18 | L-151 — subagent verification trap, completion events ≠ evidence |
| TC-218 | The UPSERT that wasn't: Postgres check constraints silently swallow your update | 💡 idea | 2026-06-18 | L-155 — db-write.sh UPSERT fix, INSERT ON CONFLICT check constraint trap |
| TC-219 | The missing edge: why verified tasks stalled at 99% complete | 💡 idea | 2026-06-18 | L-156 — SUB_CREST_TRANSITIONS verified→terminal edge fix |
| TC-220 | Don't yield the session: why waiting for a 3-second subagent cost 30 seconds | 💡 idea | 2026-06-18 | L-148 — sessions_yield anti-pattern for short subagent timeouts |
| TC-221 | The old-code audit that found 0 hardcoded paths | 💡 idea | 2026-06-18 | TKT-0529 A7 Bundle 4 — systematic hardcoded path removal, 4 regression suites |
| TC-222 | Your AI's identity crisis: when SOUL.md is 5KB of rules and 0KB of personality | 💡 idea | 2026-06-19 | CHG-0673 — 17-agent SOUL.md refactor, rules→AGENTS.md migration |
| TC-223 | 32 tickets, 3 waves, 1 EPIC: organising a platform migration without losing your mind | 💡 idea | 2026-06-19 | CHG-0672 — PG SSOT EPIC TKT-0342, Sprint 9-11 wave planning |
| TC-224 | The test ticket that cost $50 in tokens: test data lifecycle management | 💡 idea | 2026-06-19 | CHG-0669 — TKT-9999/9998 deletion, production context pollution |
| TC-225 | 100% sprint completion is a choice: deferring vs forcing work into closing sprints | 💡 idea | 2026-06-19 | CHG-0671 — Sprint 8 15/15 close, TKT-0293/0326 deferred to Sprint 10 |
| TC-226 | Model drift is real: 3 files disagreed on what model Atlas should use | 💡 idea | 2026-06-19 | Thrawn dispatch review — SKILL.md vs model-policy vs CREST mismatch |
| TC-227 | The day we rewrote the AI governance rulebook (and it worked) | 💡 idea | 2026-06-20 | CREST v1.3 full implementation — 6 PG tables, 29 phase rules, 8 models, 4 tiers, UAT |
| TC-228 | Your AI said it's on the right model. The Warden said otherwise. Both were right. | 💡 idea | 2026-06-20 | CHG-0693 — 45 stale drift violations, 3-layer structural lock |
| TC-229 | The $200/month model that lost its job to a $40/month model | 💡 idea | 2026-06-20 | CHG-0685 — deepseek-v4-pro demoted, glm-5.2:cloud promoted |
| TC-230 | LinkedIn API setup: the 2-hour tech job that turned into a business handoff | 💡 idea | 2026-06-20 | CR-002 — technical enablement to operational handoff |
| TC-231 | The benchmark that saved $150/month: model selection by data, not gut feel | 💡 idea | 2026-06-20 | CHG-0690 — 12-atom benchmark, kimi-k2.7-code 91.5% vs deepseek 87.2% |
| TC-232 | Your sprint review said 100% complete. The items array said otherwise. | 💡 idea | 2026-06-20 | CHG-0676 — db-sprint.sh defer() stale items bug |

| TC-233 | The audit that only checked 100 of 472 pages: Notion's silent page_size trap | 💡 idea | 2026-06-21 | CHG-0695 — pg-to-notion-sync.sh pagination fix |
| TC-234 | 127 orphan pages and a 4-cron timeout: the real cost of deferred data integrity | 💡 idea | 2026-06-21 | CHG-0694/0696 — PG-Notion cleanup |
| TC-235 | Your sprint tool said 'Sprint 11' when the next sprint was Sprint 9: the ORDER BY trap | 💡 idea | 2026-06-21 | CHG-0697 — db-sprint.sh sprint detection fix |
| TC-236 | The silent fallback that hid every PG bug: why graceful degradation can be dangerous | 💡 idea | 2026-06-21 | CHG-0698 — db-write.sh error classification |
| TC-237 | Schema-ready, data-empty: the column that exists but doesn't work | 💡 idea | 2026-06-21 | CHG-0699/0700 — CREST v1.3 data_class deferral |
| TC-238 | 5 tickets, 1 day, 0 regressions: what it takes to close foundation work in an AI platform | 💡 idea | 2026-06-22 | TKT-0720/0725/0726/0330/0343 — 5 CRESTv2-P1 tickets closed in one session |
| TC-239 | The subagent that couldn't exec: when your architect can't inspect the architecture | 💡 idea | 2026-06-22 | TKT-0343 A1 blocked — Atlas subagent exec gap, CHG-0734 |
| TC-240 | 1,532 edges and a graph query: building a knowledge graph from scratch in 4 hours | 💡 idea | 2026-06-22 | TKT-0720 entity_links edge table, 1,437 entity + 95 file edges |
| TC-241 | The hash chain that proved nothing was lost: event sourcing for AI operations | 💡 idea | 2026-06-22 | TKT-0726 agent_events pipeline, 15 events, 0 broken links |
| TC-242 | 11 sprint names, 1 canonical table: the data cleanup nobody wants to talk about | 💡 idea | 2026-06-22 | TKT-0725 sprint registry, 11 variants collapsed, 263 tickets assigned |
| TC-243 | Your config file says one thing. The database says another. Auto-heal says fix it. | 💡 idea | 2026-06-22 | TKT-0343 state_config_baseline to PG, CHECK 12 verification |
| TC-244 | The LinkedIn regression audit that found 4 bugs in 1 hour | 💡 idea | 2026-06-23 | CHG-0743-0746 — multi-account regression audit, hardcoded accounts, wrong shell, wrong URL |
| TC-245 | Your AI's brief said the cron ran. The cron list said otherwise. | 💡 idea | 2026-06-23 | CHG-0735 — Aria evidence-based verification, pre-write fact-checking |
| TC-246 | The four-table design that was really just one table | 💡 idea | 2026-06-23 | CHG-0753 — TKT-0390 scope collapse, agent_decisions/decision_lineage redundant with entity_links |
| TC-247 | The snapshot script that called bash instead of zsh — and silently failed | 💡 idea | 2026-06-23 | CHG-0748 — macOS bash 3.2 vs zsh associative arrays, shebang compliance |
| TC-248 | When the terminated model kept getting scheduled: the cron drift that took 2 weeks to find | 💡 idea | 2026-06-23 | CHG-0742 — Spark publish cron on terminated minimax-m3, timeout scaler sweep |
| TC-249 | The audit log that's not a view: why Path A beat Path B for pg_write_events | 💡 idea | 2026-06-23 | CHG-0749/0750 — TKT-0357, real table vs view decision, audit function with 15 columns |

_Statuses: 💡 idea → ✍️ draft → ✅ scheduled → 📤 published_

---

## Notes

- All TC-NNN IDs are provisional — Aria/Spark assign final IDs when picking up for production
- Source field links back to the platform event that generated the idea
- Ideas are raw material — they need the Spark treatment before they're audience-ready
