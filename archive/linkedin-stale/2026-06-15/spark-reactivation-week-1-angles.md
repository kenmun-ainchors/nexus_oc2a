# Spark LinkedIn Reactivation — First-Week Angles (Tue 16 Jun 2026)

**Theme:** A — "What AI Agents in Production Actually Look Like"
**Cadence:** Tue 07:30, Wed 12:00, Thu 07:30 AEST
**Voice:** Ken Mun, CTO — practitioner-first, direct, no fluff
**Hard rules:** No AInchors, no Yoda, no agent names, no em-dashes, no co-founder, no fake clients, no consulting-speak
**Model:** minimax-m3:cloud (reverts Sun 14 Jun 23:55 — first 4 posts are on the trial model)

---

## Tue 16 Jun 07:30 AEST — REACTIVATION OPENER

**Working title:** "The day my AI assistant was less reliable than my morning coffee"

**Angle (50 words):**
After 17 days off LinkedIn, here's the first thing I noticed. I cancelled my campaign because the content felt like a therapy session for AI tooling, not a practitioner's logbook. The fix wasn't more posts. It was rebuilding the spec that made the assistant sound like me in the first place.

**Hook:** "I took 17 days off LinkedIn. Not a break. A rebuild."

**Body direction:**
- Acknowledge the absence directly (no apologies, no "I've been busy")
- State the cause: content voice was drifting, not the cadence
- The fix: spec-level rebuild, not "try harder"
- One concrete lesson from the rebuild (the spec was the bottleneck, not the model)

**Insight/lesson:** Voice problems are usually spec problems. Models are mirrors. If the mirror is producing wishy-washy output, fix the input, not the mirror.

**CTA:** "If you've ever felt your AI tooling was sounding less like you, the answer isn't a better model. It's a better spec. Happy to compare notes — DM me."

**Hashtags:** #AIinAustralia #AgentAI #BuildingInPublic

---

## Wed 17 Jun 12:00 AEST — PRACTITIONER MID-WEEK

**Working title:** "Three things I learned when I stopped pretending my AI was the worker"

**Angle (50 words):**
For two years I built AI workflows that pretended the AI was the executor. Last month I rebuilt them around the opposite principle: the AI is the operator, the human is the executor. Three observations from the flip. None of them are about prompts.

**Hook:** "The shift wasn't 'use AI more.' It was 'use AI differently.'"

**Body direction:**
- Frame: "operator vs executor" is the missing distinction
- Observation 1: when AI is the operator, the bottleneck moves from prompt-quality to spec-quality
- Observation 2: governance becomes a feature, not a tax
- Observation 3: trust compounds, not decays, when the operator's interface is auditable

**Insight/lesson:** Stop selling AI as the worker. Start designing it as the operator.

**CTA:** None. Let it stand on the substance.

**Hashtags:** #AgentAI #AIinAustralia #Operations

---

## Thu 18 Jun 07:30 AEST — CONSULTING POV (rotating slot)

**Working title:** "If your AI tool feels like a magic trick, your spec is broken"

**Angle (50 words):**
Consulting POV this week. The businesses I talk to keep asking 'which AI tool should we buy?' The wrong question. The right question is: 'which parts of your operation are documented well enough that an AI can run them?' Most teams can't answer that.

**Hook:** "Stop shopping for AI tools. Start auditing your operations."

**Body direction:**
- The trap: tool-shopping before spec-shopping
- Concrete: list 3 operations in your business a new hire could run on day 1 with no training. If the list is short, you don't have a tool problem
- The fix: operational maturity, not model maturity
- Forward-looking: businesses that document will compound. Businesses that don't, won't

**Insight/lesson:** AI is a forcing function for operational clarity. If your operations are vague, AI will expose them, not hide them.

**CTA:** "What operations in your business are documented well enough for a new hire to run on day one? Be honest."

**Hashtags:** #AIinAustralia #OperationsFirst #BusinessClarity

---

## Acceptance Criteria (Week 1, 2026-06-16 → 2026-06-22)

- [ ] Tue 16 Jun 07:30 AEST: Spark cron 13b0aa89 runs, generates draft, governance gate runs, Telegram approval sent to Ken
- [ ] Wed 17 Jun 12:00 AEST: Spark cron 833ee0c7 runs, same flow
- [ ] Thu 18 Jun 07:30 AEST: Spark cron 869502c9 runs, same flow
- [ ] All 3 posts pass governance gate (no em-dashes, no AInchors/Yoda/agent names, no co-founder, no fake clients)
- [ ] All 3 posts reviewed by Ken via Telegram before any posting
- [ ] If any post is rejected, post-mortem logged to L-XXX
- [ ] Spark daily metrics cron 5d581442 continues reporting

## Risk Notes

1. **minimax-m3 quality variance** — this is the first campaign run on the trial model. If Ken rejects 2 of 3 drafts, pause and revert cron early. The reactivation should be CREST-grade, not rushed.
2. **TKT-0332 sandbox in-progress** — Spark's spec is now loaded, but the hardened sandbox boundary is still being finalized. Monitor TKT-0332 status.
3. **Reactivation of cancellation context** — Ken's prior "wishy-washy" feedback is now in `rejectionLog[]` of the campaign. Spark should read it as input, not ignore it.

## What I Need From Ken

For each of the 3 angles above, Ken can:
- **Approve as-is** (Spark drafts from the angle)
- **Modify** (Ken rewrites the angle, Spark drafts from Ken's words)
- **Replace** (Ken provides a different angle entirely)
- **Skip** (the slot is reserved but no post this week)
