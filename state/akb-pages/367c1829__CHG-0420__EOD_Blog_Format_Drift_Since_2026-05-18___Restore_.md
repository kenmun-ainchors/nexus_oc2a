# [CHG-0420] EOD Blog Format Drift Since 2026-05-18 — Restore to Approved Template

- **Notion ID:** `367c182953ff811d9b2ced99742977f8`
- **Status:** Done
- **Type:** CHG
- **Priority:** 
- **Category:** 
- **Sprint:** 
- **Created:** 2026-05-21
- **Last Edited:** 2026-05-21T02:08:00.000Z

## Notes

Type: data | Source: ken-prompt | Trigger: ken-webchat-2026-05-21-1208 | Changed: Blogs May 18-20 drifted from locked template CHG-0368: accent colour changed (#c49b5e→#bb86fc), mandatory sections missing (What I Learned, Cost, What's Next), May 18 had zero h2 sections, file size collapsed 21-26KB→9-10KB. template-lock.json exists but is not enforced by cron script a027fd60. Root cause: CHG-0363 Ollama transition changed cron agent payload without preserving template enforcement. | Why: After 23 days of iteration, Ken locked all 3 templates on 17 May. Drift defeats template governance and degrades brand consistency. Needs immediate fix: restore approved CSS, enforce minimum section requirements, add template validation to cron. | Verified: state/template-lock.json verified active, approved baseline May-16/17 verified as reference, May-18/19/20 drift documented line-by-line, Forge assigned TKT to fix | Rollback: Revert to pre-fix state. Regenerate May 18-20 from journal source.
