# LinkedIn Campaign Stats
**Generated:** 2026-05-20 21:43 AEST | **Owned by:** Spark ✨ | **Ticket:** TKT-0232
**Data source:** LinkedIn socialActions API (live pull) | **Cron:** Daily 10:00 AEST (`5d581442`)

---

## Campaign Summary (all 9 posts — API verified)

| # | Post ID | Title | Date | Reactions | Comments | Shares |
|---|---------|-------|------|-----------|----------|--------|
| 1 | LI-SEED-1 | Opening Tease | May 3 | **48** | 0 | 0 |
| 2 | LI-SEED-2 | The Hint | May 3 | **24** | 0 | 0 |
| 3 | LI-W1-P1 | Practitioner Intro | May 5 | **31** | **2** | 0 |
| 4 | LI-W1-P2 | Problem Education | May 6 | **9** | 0 | 0 |
| 5 | LI-W1-P3 | Consultant POV | May 7 | **6** | 0 | 0 |
| 6 | LI-ADHOC-RUSTDESK | RustDesk cautionary tale | May 10 | **8** | **4** | 0 |
| 7 | LI-C1-W2-P2 | AIOps P2 — Cost of Getting It Wrong | May 12 | **20** | **6** | 0 |
| 8 | LI-C1-W2-P3 | AIOps P3 — Multi-Agent Trust | May 14 | **5** | 0 | 0 |
| 9 | LI-W3-P1 | AI demo lied to you | May 19 | **15** | 0 | 0 |

| **TOTALS** | | | **166** | **12** | **0** |

## Top Performers

- 🥇 **LI-SEED-1** (Opening Tease): 48 reactions — highest engagement
- 🥈 **LI-W1-P1** (Practitioner Intro): 31 reactions, 2 comments
- 🥉 **LI-SEED-2** (The Hint): 24 reactions
- 💬 **LI-C1-W2-P2** (AIOps Cost): 6 comments — most discussion
- 💬 **LI-ADHOC-RUSTDESK**: 4 comments, 8 reactions — strong for ad-hoc

## Insights

- **Seeders dominate:** 72 reactions combined (43% of total). The "opening tease" format works.
- **AIOps P2 surprising:** 20 reactions + 6 comments despite being posted out of order in a broken series. The cost angle resonates.
- **W3-P1 fresh:** 15 reactions in first 24h — strong start for the new "standalone" format.
- **W1-P3 weakest:** 6 reactions. Consultant POV angle may need work.
- **Shares:** Zero across all posts. This is normal for LinkedIn — shares are rare for text/image posts.
- **Impressions:** Not available via API (needs org page onboarding). Visual snapshot from May 9 showed 1,634 impressions across 4 posts.

## What Was Fixed

- ✅ `linkedin-metrics.sh`: Reactions fixed (was returning 0)
- ✅ `linkedin-post.sh`: URN capture now writes to `linkedin-campaign.json`
- ✅ All 9 URNs backfilled from Ken's LinkedIn URLs
- ✅ Daily cron `5d581442`: Spark-owned 10:00 AEST snapshots
- ✅ `linkedin-campaign.json`: metricsOwnership → Spark ✨

## Remaining

- 🔮 Organization page onboarding → unlocks impressions/reach via MDP
- 🔮 Spark spawn allowlist: fixed by Ken ✅
