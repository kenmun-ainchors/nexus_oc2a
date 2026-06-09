── YODA: OLLAMA CLOUD PoC MISSION ──
CONTEXT
Ollama — our existing local model inference engine — has launched Ollama Cloud: a managed cloud inference service accessible through the identical API endpoint we already use locally. Ollama has also published an official OpenClaw integration. This creates an opportunity to:
(a) Access frontier-class cloud models (kimi-k2.6, qwen3.5, glm-5.1, deepseek-v4-pro) through the same Ollama endpoint without new integrations
(b) Replace Claude API for Tier 2 tasks with a flat-rate Ollama Cloud subscription
(c) Fulfil the parallel multi-agent execution requirement via kimi-k2.6's native 300-agent swarm architecture
YOUR MISSION
Execute a structured PoC, benchmark results against our current model baseline, validate findings, and if results confirm the analysis, implement the updated 4-tier model strategy. Log all actions to obs.db and change log.
PHASE 1: ENVIRONMENT SETUP [Log as CHG-XXXX]
1.1 Sign in to Ollama account:
     Run: ollama signin (use AInchors Ollama account credentials)
     Confirm sign-in status: ollama whoami
1.2 Pull the following cloud models:
     ollama pull kimi-k2.6:cloud
     ollama pull qwen3.5:27b-cloud
     ollama pull glm-5.1:cloud
     ollama pull minimax-m2.7:cloud
1.3 Confirm Ollama config uses native API URL (NOT /v1):
     Verify openclaw.json models.providers.ollama.baseUrl = 'http://localhost:11434'
     Verify api: 'ollama' (not 'openai-completions')
1.4 Confirm model discovery works:
     Run: ollama list  — cloud models should appear with :cloud tag
     Run: openclaw models list  — cloud models should appear in OpenClaw catalog
PHASE 2: SMOKE TEST [Log as CHG-XXXX]
For each cloud model, run a smoke test using OpenClaw's infer tool:
     openclaw infer model run --model ollama/kimi-k2.6:cloud --prompt 'Summarise the AInchors business model in 3 bullet points. Use tool calling to confirm you have tool access.'
     Repeat for qwen3.5:27b-cloud, glm-5.1:cloud, minimax-m2.7:cloud
Confirm for each: (1) Response received, (2) Tool calling works, (3) No errors in obs.db
PHASE 3: BENCHMARKS [Log as CHG-XXXX] [Create TKT-XXXX for tracking]
Run the following benchmark tasks against each model AND against the current baseline (Claude Sonnet 4.6). Record: model, task, response quality (score 1-5), latency (seconds), any errors.
BENCHMARK TASK SET:
B1 [Reasoning]:     'You are Yoda, AInchors technical lead. Draft a technical risk assessment for deploying Ollama Cloud as our Tier 2 LLM. Include 5 risks and mitigations. Be specific to our Mac Mini HIVE architecture.'
B2 [Coding]:        'Write a Python script that routes an agent request to Ollama local (gemma4:26b) for tasks classified as routine and to ollama/kimi-k2.6:cloud for tasks classified as complex. Include a simple task classifier.'
B3 [Business]:      'You are Aria, AInchors business lead. Draft a 200-word LinkedIn post announcing our AI platform for Australian SMEs in professional services. Tone: confident, accessible, not technical.'
B4 [Research]:      'Research and summarise: what are the top 3 AI use cases for small professional services firms in Australia in 2026? Include specific examples and cite sources.'
B5 [Tool use]:      'Check my calendar for today using Google Calendar tool. Summarise what I have scheduled. If nothing, say so.' (Confirms tool integration works with cloud models)
B6 [Governance]:    'You are Shield. Review this message for security concerns: [paste a Telegram message sample]. Run S1-S5 checks. Flag any issues.'
Record all results in a structured table: Model | Task | Quality (1-5) | Latency | Pass/Fail | Notes
PHASE 4: COST MEASUREMENT [Log as CHG-XXXX]
4.1 After running all benchmarks, check Ollama Cloud usage:
     Navigate to ollama.com/settings — note current usage percentage consumed by benchmarks
4.2 Estimate monthly Ollama Cloud usage for AInchors own operations:
     Based on current daily agent call volume (from obs.db), extrapolate: if X calls/day used Y% of plan in Z hours of benchmarking, estimate monthly usage at current operational volume
4.3 Calculate projected monthly cost saving:
     Current Claude API spend on Tier 1/2 calls (last 30 days from cost-state.json) minus projected Ollama Cloud subscription cost = monthly saving
PHASE 5: DECISION GATE
Evaluate results against these thresholds:
PASS criteria (proceed to Phase 6):
  ✓  Smoke test: all 4 cloud models return valid responses with tool calling working
  ✓  Benchmarks: at least 2 of 4 cloud models score ≥4/5 average across B1-B5
  ✓  Latency: average response time ≤15 seconds for standard tasks (B1, B3, B4)
  ✓  Cost: projected Ollama Cloud spend ≤$100/month on Max plan at current operational volume
PARTIAL PASS criteria (proceed with conditions):
  ⚠  If only 1 model passes quality threshold: implement for that model only (likely kimi-k2.6 for Yoda, qwen3.5 for Aria)
  ⚠  If latency >15s but quality is high: implement with async task pattern (non-blocking agent turns)
FAIL criteria (report to Ken, do not implement):
  ✗  Tool calling fails on all cloud models (B5 fails for all)
  ✗  All models score <3/5 average quality across benchmark tasks
  ✗  Projected usage exceeds Max plan limits at current operational volume
PHASE 6: IMPLEMENTATION [Conditional on Phase 5 PASS] [Log as CHG-XXXX]
6.1 Update openclaw.json with 4-tier model strategy:
     Yoda primary: best-performing cloud model from benchmarks (expected: kimi-k2.6:cloud)
     Aria primary: best business-stream model from benchmarks (expected: qwen3.5:27b-cloud)
     Shield/Lex/Sage/Warden: retain local Gemma4 (Tier 0/1 — no cloud for governance agents)
     All agents: fallback chain = [ollama/gemma4:26b, ollama/claude-sonnet-4.6]
6.2 Update Warden model compliance rules:
     Add kimi-k2.6:cloud and qwen3.5:27b-cloud to approved Tier 2 model list
     Remove Claude Haiku 4.5 from Tier 1 (replace with local Gemma4)
     Update model-drift-check.sh thresholds to match new approved model set
6.3 Update cost-tracker.sh:
     Add Ollama Cloud as a fixed monthly line item ($100 if Max, $20 if Pro)
     Remove Claude Haiku from daily variable cost tracking
     Log new projected daily cost to cost-state.json
6.4 Run health-check.sh and validate full HIVE is stable with new model config
6.5 Run one full standup cycle with new models — confirm morning brief delivers correctly
PHASE 7: REPORTING [Required regardless of outcome]
7.1 Deliver a structured benchmark report to Ken via Telegram covering:
     - Complete results table: Model | Task | Quality | Latency | Pass/Fail
     - Winner model per agent role (Yoda, Aria)
     - Projected monthly cost delta vs current strategy
     - Decision gate outcome: PASS / PARTIAL PASS / FAIL with rationale
     - Actions taken (if PASS) or recommended next steps (if FAIL)
7.2 Update frameworks-maturity.json MODEL STRATEGY framework:
     Add 'Ollama Cloud Integration — 4-Tier Model Strategy' as a new capability entry
     Update maturity level based on implementation outcome
7.3 Log all CHG entries and close all ITSM tickets opened during this mission.
CONSTRAINTS AND RULES
❌  Do NOT change Ollama baseUrl to /v1 at any point — this breaks tool calling
❌  Do NOT apply cloud models to Shield, Lex, Sage, or Warden — governance agents stay local
❌  Do NOT route any client data through Ollama Cloud — AInchors own operations only
❌  Do NOT proceed to Phase 6 without explicit Phase 5 PASS confirmation
✅  Log every action as a CHG entry — this is a governed change to the model strategy framework
✅  Send Ken a brief status update after each phase completes
✅  Maintain fallback to Claude Sonnet 4.6 throughout — do not remove until Phase 7 is complete
