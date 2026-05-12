# Pattern: analyze-claims
**Purpose:** Evaluate claims in content. Identify assumptions, rate confidence, flag risks.
**Input:** Any document making factual or strategic claims
**Output:** Claim register with confidence ratings
**Model:** Tier 3 (Sonnet) — requires reasoning depth
**Used by:** Shield (security review), Lex (legal review), Sage (QA), Atlas (EA validation)

## Prompt
Analyse the claims in the following content. For each significant claim:

| Claim | Type | Evidence | Confidence | Risk |
|-------|------|----------|------------|------|
| [claim text] | Factual/Strategic/Opinion | Strong/Weak/None | High/Med/Low | [flag if misleading] |

Then rate the overall content: RELIABLE / PARTIALLY RELIABLE / UNRELIABLE
One sentence explaining the rating.
