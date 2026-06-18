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

_Statuses: 💡 idea → ✍️ draft → ✅ scheduled → 📤 published_

---

## Notes

- All TC-NNN IDs are provisional — Aria/Spark assign final IDs when picking up for production
- Source field links back to the platform event that generated the idea
- Ideas are raw material — they need the Spark treatment before they're audience-ready
