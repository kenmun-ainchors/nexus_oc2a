# 2026-05-19 — Daily Brief for Aria & Angie

## 🟢 What Yoda Built Today

Today was all about fixing invisible bugs, getting LinkedIn back on track, and tightening the platform's engineering discipline. A good "maintenance and momentum" day.

- **LinkedIn Campaign Full Reset:** Ken wasn't happy with the direction of the posts, so we killed the old AIOps series that had been limping along and started fresh. Redrafted 3 new posts from scratch with a totally different voice — first-person, reflective, "here's what I learned" instead of "here's what you're doing wrong." Ken approved all 3. The first one was posted, images generated and uploaded for all of them, and the rest are scheduled for later this week.

- **Single Source of Truth for LinkedIn:** Discovered LinkedIn campaign state was spread across 3 different files that kept getting out of sync with each other. Consolidated everything into one file (`linkedin-campaign.json`) — published posts, skipped posts, drafts, approval status, rejection log, image assets, everything in one place. This prevents the drift that killed the old campaign.

- **Drive Upload Discipline Fix:** Found that agents were uploading files to the wrong Google Drive folder (root "/" instead of the right subfolder). Added mandatory rules across all agent playbooks: every Drive upload must specify which folder it goes to. Moved the misplaced files to their correct homes.

- **Blog May 18 Finally Published:** Yesterday's blog had been blocked by a dead-end in our content review pipeline. The three review agents (Shield, Lex, Sage) were trying to use a model that no longer exists after the weekend's model switchover. Fixed the routing, ran the reviews, and published.

- **Shell Script Anthropic Audit:** Found 5 scripts across the platform that still had hardcoded references to the old Claude/Sonnet models (which don't work anymore). Fixed all of them. Discovered this was a systemic gap — our "what to do when the API dies" runbook covered agents and background jobs, but not shell scripts.

- **Journal Date Boundary Fix:** Found a bug where journal entries written late at night (after midnight) were getting filed under the wrong date. Fixed so entries always go to the date they actually happened, even if the writer runs at 1am.

- **Nightly Gateway Restart Redesigned:** Replaced a single unreliable restart job with a two-step design using a marker file. The old approach always reported as "failed" because the restart killed its own process. Now it reports reliably: "restarted successfully" or "restart failed."

- **Backup Health Check Fixed:** A backup monitoring script had been looking for a file with the wrong name since it was created — every check was a false alarm sent to Ken. Fixed the filename, and the backup system confirms: healthy, 293MB, 56,566 files protected.

- **Session Transcript Safety:** Before anything restarts the platform at night, all session transcripts now get copied to a safe backup directory. This prevents the kind of data loss that happened yesterday where afternoon work was unrecoverable.

- **Notion Sync Audit:** Ran a full audit comparing our ticket system with Notion: found 9 duplicates, 5 missing pages, and 8 extras. Cleaned everything up — 87 Notion pages now perfectly match 227 tickets in the system.

## ⚖️ Key Decisions

- **LinkedIn Voice Locked In:** Posts are now first-person, reflective, practical — no belittling tone, no "everyone's doing X wrong." Ken's voice as a practitioner who learned things the hard way. This is the permanent style going forward.

- **Standalone Posts > Series:** No more numbered post series (Part 1, Part 2...). Every post is self-contained. Series break when slots shift, and it confuses readers. Each post now stands alone.

- **One Campaign File, Always:** Campaign state split across multiple files is banned. One domain = one SSOT file. This rule applies to all future campaigns too.

- **UTC is 10 Hours Behind AEST (Not Ahead):** A painful but important one. Cron schedules use UTC. 07:30 AEST = 21:30 UTC the PREVIOUS day. We had P1 scheduled for tomorrow instead of today because we added instead of subtracted.

## 🎓 Training Content Angles (For AI Courses)

- **The Demo-to-Production Gap is 100x Bigger Than People Think:** Most AI demos take 5 minutes. Real production takes infrastructure, error handling, state management, and discipline. (From today's LinkedIn post theme.)

- **The Model is Never the Bottleneck:** It's the plumbing — data flow, failure handling, audit trails, and cost management. Model choice matters far less than the engineering around it.

- **Why Campaign State Drift Happens (And How One SSOT File Fixes It):** Real example of 3 files diverging over a few days, and how consolidating to one file eliminated the problem instantly.

- **The Hidden Model References That Survive a Migration:** When you switch AI providers, checking agents and crons isn't enough. Shell scripts, routing files, and helper utilities may still reference the dead provider — and they'll fail silently.

- **UTC Time Zone Traps in Automation:** AEST = UTC+10 means 07:30 Tuesday in Melbourne is 21:30 Monday in UTC. Subtract 10, don't add. One character wrong = post goes out a day late.

## ⏳ What's Open / Next

- **LinkedIn P2 and P3:** Approved and scheduled for Wed 21 May 12:00 and Thu 22 May 07:30 (images ready, crons set with correct UTC times).
- **Sprint 4:** In progress this week. Ken is directing the rebuild.
- **OC2 Hardware:** ETA early July 2026. The two Mac Mini M4 Pros unlock local models and the real platform scaling.
- **Aevlith Incorporation:** Still pending ASIC registration — this is a hard prerequisite for taking on clients.
- **Anthropic API:** Standby mode continues. DeepSeek-Pro is performing well as the day-to-day model.
