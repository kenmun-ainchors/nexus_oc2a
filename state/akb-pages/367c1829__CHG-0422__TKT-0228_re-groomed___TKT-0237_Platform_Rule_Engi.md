# [CHG-0422] TKT-0228 re-groomed + TKT-0237 Platform Rule Engine — defense-in-depth against agent drift

- **Notion ID:** `367c182953ff81e6ac14fb4dc3204247`
- **Status:** Done
- **Type:** CHG
- **Priority:** 
- **Category:** 
- **Sprint:** 
- **Created:** 2026-05-21
- **Last Edited:** 2026-05-21T06:01:00.000Z

## Notes

Type: rule | Source: ken-prompt | Trigger: ken-webchat-2026-05-21-1600 | Changed: TKT-0228 RE-GROOMED: OWL narrowed from 18h/5-story full system to 2h conditional safety mode — activated ONLY when agents run on kimi-class models for non-LOW currency work. TKT-0237 RAISED: Platform Rule Engine v1 T1 Audit Tier — Warden-owned 10-rule post-execution compliance audit (R01-R10: Path, SoT, Model, Template, State Check, ID Uniqueness, Config Drift, Content Gov, Cron Health, MEMORY). Output: rule-audit-report.json + weekly HTML report. P2 gate: T2 pre-execution intercept under Citadel. Together these form a defense-in-depth drift prevention layer with TKT-0182 State Checking and TKT-0196 Three Work Types. | Why: Ken identified the fundamental drift problem: agents treat rules as advisory, not mandatory. Markdown rules have no runtime enforcement. P2 clients require auditable compliance. T1 Audit Tier gives us visibility now; T2 Gate Tier prevents violations at P2. | Verified: TKT-0228 re-groomed, TKT-0237 raised and tagged Sprint 5 with Warden owner. Both synced to Notion. | Rollback: N/A
