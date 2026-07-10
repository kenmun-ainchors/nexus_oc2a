# [TKT-0973] Remove Anthropic fallback checks from validate-fallback-chain.sh and callers

- **Notion ID:** `398c182953ff81859d53daa5aabd41e7`
- **Status:** Done
- **Type:** Forge
- **Priority:** High
- **Category:** Technical
- **Sprint:** Sprint 11
- **Created:** 2026-07-09T23:43:00.000+10:00
- **Last Edited:** 2026-07-10T01:03:00.000Z

## Notes

CHG-0855 parked Anthropic but missed scripts/validate-fallback-chain.sh, which still runs LINK 1 (Anthropic key) and LINK 2 (Anthropic API reachability) on gateway start and via outage-detect.sh, outage-handler.sh, run-ci-cycle-a.sh, startup-checks.sh. This produces false 'Fallback Chain Broken' alerts. Remove Anthropic links, make Ollama Cloud + model-policy.json the validated primary chain, and update all callers.
