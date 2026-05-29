# [CHG-0444] Budget Cap Recalibration + Ollama Cloud Model Rates

- **Notion ID:** `36ec182953ff812c9d80e952b84e91a0`
- **Status:** Done
- **Type:** CHG
- **Priority:** 
- **Category:** 
- **Sprint:** 
- **Created:** 2026-05-28
- **Last Edited:** 2026-05-28T01:42:00.000Z

## Notes

Type: config | Source: ken-prompt | Trigger: Ken approved monthly model review recommendations | Changed: cost-state.json: budget cap corrected to  USD/month ( Ollama Max +  Claude buffer). Added ollamaCloudModelRates (Set A subscription-aligned + Set B market-equivalent). cost-tracker.sh: MODEL_RATES updated with Ollama Cloud fair-value per-token rates in both main and ephemeral sections. | Why: Previous cap was A from Claude era. Ollama Cloud =  USD flat. Derived fair-value per-token rates from market comparables (OpenRouter/API pricing), scaled to match subscription. | Verified: Warden 9/9 PASS. cost-state.json valid JSON. cost-tracker.sh syntax valid. Both MODEL_RATE blocks updated. | Rollback: N/A
