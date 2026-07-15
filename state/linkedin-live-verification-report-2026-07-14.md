# LinkedIn Multi-Account — Live Verification Report
**Checked:** 2026-07-14 21:27 AEST (11:27 UTC)
**LinkedIn App:** client ID `86fb2cb4ga03jy`

## Executive Verdict
🟡 **ANGIE READY, BUSINESS BLOCKED** — Angie personal LinkedIn re-auth succeeded and token is verified. Ken personal not required. AInchors company page posting blocked until LinkedIn approves the requested Business Advertising API / Marketing Developer Platform product.

**Corrected root cause:** Share on LinkedIn only grants `w_member_social` (personal posting). Company-page posting requires `w_organization_social`, which comes from Marketing Developer Platform.

## Per-Account Status
| Account | Token in Keychain | Product Needed | Posting Status |
|---------|-------------------|----------------|----------------|
| Ken personal | Not required | Share on LinkedIn ✅ | No action |
| Angie personal | ✅ Valid (HTTP 200, member `lMSGM5TOm9`) | Share on LinkedIn ✅ | Ready for AW6-P2/P3 |
| AInchors business | ❌ Missing | Business Advertising API / Marketing Developer Platform ⏳ (requested, awaiting approval) | Blocked until approval |

## Evidence
- Angie re-auth completed 2026-07-14 21:27 AEST; `/v2/userinfo` returned HTTP 200.
- Access token present in Keychain; refresh token not issued by LinkedIn for this OAuth app.
- Business OAuth test for `w_organization_social` returned `unauthorized_scope_error` even with Share on LinkedIn Added and company page Verified.

## State Files Corrected
- `state/linkedin-auth.json` (Ken) — not required, left as missing-token state.
- `state/linkedin-auth-angie.json` — updated with live verified token.
- `state/linkedin-auth-business.json` — business blocked pending product approval.
- `state/linkedin-metrics-errors-business.json`
- `state/linkedin-token-health-business.json`
- `state/linkedin-campaign-angie.json` — AW6-P1 Tue slot marked MISSED.
- `state/linkedin-campaign-business.json` — CONTENT-BUS-001 Tue slot marked MISSED, drafts updated.
- `state/linkedin-live-verification-report-2026-07-14.md` — this file.

## Content Impact
- **Angie personal Week 6:** AW6-P1 missed Tue 14 Jul 07:30 AEST. AW6-P2 (Wed 15 Jul 12:00 AEST) and AW6-P3 (Thu 16 Jul 07:30 AEST) are approved but images not generated.
- **Business Week 5:** CONTENT-BUS-001/002/003 still contain em-dashes; CONTENT-BUS-001 also still uses fake-client phrase `"a team we work with"`. Business posting blocked regardless until product approval.

## Required Next Actions
1. **Business remains LOCKED** pending LinkedIn product approval. Aria should take no business campaign action until Yoda unblocks.
2. **Once approved, re-auth business**:
   ```zsh
   zsh /Users/ainchorsoc2a/.openclaw/workspace/scripts/linkedin-auth.sh --account business
   ```
3. **Aria/Angie own Angie personal posts now.** Decide AW6-P1 missed slot and generate images for AW6-P2/P3.
4. **Fix `linkedin-metrics.sh` dependency** — `python-dateutil` missing; route to Forge.
