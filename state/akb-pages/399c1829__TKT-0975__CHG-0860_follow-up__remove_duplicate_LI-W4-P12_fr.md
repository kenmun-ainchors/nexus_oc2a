# [TKT-0975] CHG-0860 follow-up: remove duplicate LI-W4-P12 from Ken campaign queue

- **Notion ID:** `399c182953ff81f2bd47db643b563269`
- **Status:** Open
- **Type:** Forge
- **Priority:** High
- **Category:** Technical
- **Sprint:** Sprint 11
- **Created:** 2026-07-10T02:40:00.000+10:00
- **Last Edited:** 2026-07-10T02:40:00.000Z

## Notes

Forge's migration for CHG-0860 left LI-W4-P12 in both queued and published arrays in state/linkedin-campaign-ken.json. The queued entry is scheduled for Tue 15 Jul 07:30 AEST, but the post is already live (postedAt 2026-07-08 13:08 AEST, postUrn urn:li:share:7480457588195618816). Remove the queued duplicate to prevent an unintended repost.
