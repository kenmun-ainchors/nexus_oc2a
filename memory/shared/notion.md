# Notion Workspace — AInchors HQ
_Connected: 2026-04-25 | Integration: AInchors Yoda | Last Holocron audit: 2026-07-09 (CHG-0850)_

## Root
| Page | ID |
|------|-----|
| AInchors HQ | 34dc182953ff8039a2ead3b675f8d2de |
| ⚙️ Technical Stream | 34dc182953ff81d6910cd5caded4213d |
| 💼 Business Stream | 34dc182953ff8159a687df9337ef2c2f |
| 🤖 Agent Operations | 34dc182953ff81c0bab9de3c3395de60 |
| 📝 Meeting Notes | 34dc182953ff81cf9512d2ceebb0e227 |
| 📊 Reports | 34dc182953ff81e4a1b1e947f7e2bf31 |

## Databases
| Database | ID | Use |
|----------|-----|-----|
| Projects | 9fe918e317c74b2ba250310578d8ab47 | All projects, both streams |
| Tasks | 26de9c3ba4604b6eb3e2408fc8993c10 | All tasks, both streams |
| Clients | c46b7b78d7c049a3a4d0f8f6d553531a | CRM — client profiles |
| Agent Status | b84600c443b34ad8a0e3736bc373222c | All 14 agents status |
| Content Calendar | ~~07b6afaf-da51-4f0e-bb0c-6d37f3b78149~~ | Removed/stale — DB not found in Notion (404). Spark content pipeline tracked in Backlog A and state_content_queue PG table. |
| Cost Tracker | 34dc182953ff81b1a587ec39b239e465 | Daily token costs by model |
| Meeting Notes | e8073a50c2fa4e3aa3a42119ea4c7eb0 | All meeting records |
| Backlog — User Stories | 34dc182953ff814b8257d3a3bf351d44 | All US — backlog, sprint, done |
| Asset Registry | 34ec182953ff810f8af9c8f9d5468400 | 53 assets — evergreen review, weekly cron |
| Incident Log | 34ec182953ff812a85e4f00f207ec8e5 | Service incidents, RCA, MTTR tracking |

## API Notes
- Use Notion-Version: 2022-06-28 for all operations (2025-09-03 has schema issues)
- Config: ~/.config/notion/api_key
| Service Tickets | 34ec182953ff81f3b936f1422f750315 | Ad-hoc tickets (TKT-NNNN) — requests, tasks, questions without INC/US/CHG |
