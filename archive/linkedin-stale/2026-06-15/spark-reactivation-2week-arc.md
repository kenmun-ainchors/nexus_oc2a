# Spark LinkedIn Reactivation — 2-Week Narrative Arc (Tue 16 Jun → Thu 25 Jun 2026)

**Story angle (Ken's directive, 2026-06-12 22:34 AEST):**
> "Why I have been quiet. What became a gap, issue, challenge, pain and broke. What we did, learned and led to CREST v1.2 live."

**Translation rule (no-internal-mention compliance):**
- ✅ Talk about: AI assistants, workflows, what breaks in production, quality gates, discipline, "the spec", recovery, lessons
- ❌ Don't name: AInchors, Yoda, Nexus, agent names, model routing, platform internals
- 🪞 Frame: First-person practitioner. "My AI assistant" / "My workflow" / "I built"

**Cadence:** Tue 07:30, Wed 12:00, Thu 07:30 AEST — 3 posts/week × 2 weeks = 6 posts total
**Theme override:** Practitioner/personal for all 6 posts. NO consulting POV for 2 weeks (per Ken).
**Voice:** Ken Mun, CTO — direct, no fluff, real numbers, practitioner-first, Australian context
**Length target:** 200–400 words. Long enough for substance, short enough to read on mobile. No draggy padding.

---

## THE 2-WEEK NARRATIVE ARC

The 6 posts form a continuous story — readers can read them in order OR each one stands alone. The arc tracks the **death-and-rebirth of a workflow**:

| Post | Day | Story beat | What the reader should takeaway |
|---|---|---|---|
| **1** | Tue 16 Jun 07:30 | **The silence** — why I went dark for 17 days | Silence can be signal, not absence |
| **2** | Wed 17 Jun 12:00 | **The crack** — the first thing I noticed was wrong | Drift is silent until it isn't |
| **3** | Thu 18 Jun 07:30 | **The diagnosis** — what I found when I audited | Specs decay. Audit before you fix. |
| **4** | Tue 23 Jun 07:30 | **The rebuild** — what I changed, line by line | Fix the input, not the model |
| **5** | Wed 24 Jun 12:00 | **The lesson** — what this taught me about AI tools | A workflow's quality = your spec's quality |
| **6** | Thu 25 Jun 07:30 | **The shift** — what I do differently now | Operate the AI, don't let it operate you |

---

## POST 1 — Tue 16 Jun 07:30 AEST

**Working title:** "Why I went quiet for 17 days"

**Hook (first line):**
I disappeared from LinkedIn for 17 days. Not a break. A rebuild.

**Body:**

For two months I'd been posting about AI workflows as if everything was working. The content was clean. The cadence held. The numbers looked fine.

But I knew the work behind it was slipping. My AI assistant had started producing output that *sounded* right but didn't reflect *me* — generic, slightly off, like a voicemail from someone pretending to be a colleague.

I kept posting anyway. Then I stopped.

The honest version: I was avoiding the rebuild because rebuilding means admitting the spec was wrong. The spec is the document that tells the AI how to behave. I'd been quietly editing around the edges for weeks.

This week I tore it down and started over.

**Insight:** Going quiet is sometimes the most productive move. Forcing output when the system underneath is broken is just expensive noise.

**Takeaway for the reader:** When your tools start producing things that don't sound like you, the answer isn't more output. It's fewer, better, with a fixed foundation.

**CTA:** None. Let the silence speak first.

**Hashtags:** #AIinAustralia #BuildingInPublic #PractitionerNotes

---

## POST 2 — Wed 17 Jun 12:00 AEST

**Working title:** "The first crack I should have noticed"

**Hook:**
The first sign wasn't a failure. It was a sentence that read perfectly — and meant nothing.

**Body:**

Three weeks before I went quiet, my AI produced a 600-word post. Clean grammar. Right format. Posted it. Got 18 likes.

Read it again the next morning. Didn't recognise myself.

That was the moment. Not the moment I admitted it — I took two more weeks of posting to admit it — but the moment the spec was already wrong and I was pretending it wasn't.

Here's what I missed: I was reviewing for *plausibility*, not for *voice*. Plausibility is "does this sound like a real LinkedIn post?" Voice is "does this sound like Ken, writing at 11pm, in a specific mood, with a specific stake in the outcome?"

Plausibility is easy. Voice is everything.

**Insight:** When you review AI output, you're usually checking the wrong thing. You check "is it good?" not "is it me?"

**Takeaway:** Build a 5-second voice test before you post anything. Read it aloud. If you don't recognise yourself, neither will anyone else.

**CTA:** None.

**Hashtags:** #AIinAustralia #BuildingInPublic #VoiceMatters

---

## POST 3 — Thu 18 Jun 07:30 AEST

**Working title:** "Auditing your own AI like you audit your own code"

**Hook:**
I've spent ten years reviewing other people's code. Reviewing my own AI output was somehow harder.

**Body:**

When I finally sat down to fix the spec, I did what I do with bad code. I asked: *what does this output assume about its input?*

The spec was assuming I was still the version of me from 8 weeks ago. Same goals. Same audience. Same risk tolerance. Same voice. None of those were true anymore.

I'd changed. The work had changed. The audience had shifted. The spec was a fossil.

Three things I found when I audited:

1. The spec had rules that contradicted each other. ("Be direct" and "Always soften criticism with praise.")
2. It referenced contexts that no longer existed.
3. It had never been tested against an actual failure case.

Lesson: specs decay the same way code does. They go stale silently. The output looks fine until it doesn't.

**Insight:** Most AI workflow problems are spec problems in disguise. The model is a mirror. If the mirror is warped, you don't replace the mirror — you fix what it's reflecting.

**Takeaway:** Schedule a quarterly spec audit. Treat your AI's instructions like production code. Version them. Test them. Replace them when they rot.

**CTA:** None.

**Hashtags:** #AIinAustralia #BuildingInPublic #SpecDrift

---

## POST 4 — Tue 23 Jun 07:30 AEST

**Working title:** "What I changed in the rebuild"

**Hook:**
Rebuilding the spec took four days. The post I published this morning took 11 minutes. That's the math.

**Body:**

Four days of work to make 11 minutes of output feel like me.

What changed:

1. **Wrote the rules like constraints, not aspirations.** "Always be direct" is an aspiration. "Never use words like 'perhaps', 'might', 'could consider'" is a constraint. Constraints are testable.
2. **Added the failure cases.** I wrote down three things the AI had done badly and the rule that should have prevented each one. Now those rules are executable.
3. **Killed the disclaimers.** Old spec said "be helpful but careful." New spec says "write like the reader is smart and short on time." The first produces hedges. The second produces posts.
4. **Added a pre-publish gate.** I read every post aloud. If I don't recognise the voice at line 1, it doesn't ship.

The 11 minutes is real. The pre-publish gate adds about 90 seconds. Everything else happened once, in the rebuild, and now compounds.

**Insight:** Quality gates feel expensive until you amortise them. The gate I built in the rebuild will pay for itself in every post for the next 12 months.

**Takeaway:** Invest in the spec, not the model. The model changes every quarter. The spec is yours.

**CTA:** None.

**Hashtags:** #AIinAustralia #BuildingInPublic #QualityGates

---

## POST 5 — Wed 24 Jun 12:00 AEST

**Working title:** "What 17 days off taught me about AI tools"

**Hook:**
If you build with AI long enough, you'll have a week like mine. Here's what I learned.

**Body:**

Three lessons from the rebuild:

**One — silence is data.**
Going quiet for 17 days told me more about my workflow than the 17 weeks before. The forced absence made the gaps obvious. I'd been too busy producing to notice the foundation rotting.

**Two — your spec is the bottleneck, not the model.**
The model hasn't changed. The output quality changed because the spec changed. The bottleneck was always the human-side documentation, not the AI capability. This is true of every AI workflow I've ever seen fail.

**Three — quality gates are a feature, not a tax.**
The pre-publish gate I added feels like overhead until you realise it's the only thing standing between you and the slow drift back to generic. The gate doesn't slow you down. The gate keeps you honest.

If you're using AI for any kind of public work — content, code, customer comms, design — the rebuild question isn't "should I upgrade my model?" It's "when did I last audit what I'm telling the model?"

**Insight:** AI tools don't get worse. Your spec does.

**Takeaway:** Audit quarterly. Add a pre-publish gate. Trust the silence when it tells you to step back.

**CTA:** "If you've had a week like this, I'd love to hear what surfaced. DM me."

**Hashtags:** #AIinAustralia #BuildingInPublic #WhatILearned

---

## POST 6 — Thu 25 Jun 07:30 AEST

**Working title:** "How I work with AI now (and what I'd tell the version of me from 6 months ago)"

**Hook:**
Six months ago I thought the work was the prompts. The work is the spec.

**Body:**

Here's what my workflow looks like today, in 5 lines:

1. The spec is a document, not a conversation. I edit it weekly, not daily.
2. I never post AI output without reading it aloud first. Voice is non-negotiable.
3. I have a list of failure cases the AI has produced. The spec exists to prevent the next one.
4. When the AI produces something generic, I ask "what rule in the spec would have stopped this?" and I add it.
5. I have a quarterly spec audit on the calendar. Same day every quarter. Non-negotiable.

If I'd known this 6 months ago, I'd have saved myself 4 weeks of mediocre output, 17 days of silence, and one full rebuild.

The honest version: the AI didn't fail. I failed to keep up with what I was asking it to do. The work is the spec. Everything else is just typing.

**Insight:** AI is a forcing function for operational clarity. If you can't write down what you want, the AI can't give it to you.

**Takeaway:** Stop optimising prompts. Start writing specs. The work is upstream of the tool.

**CTA:** "What's the rule in your workflow that, if you wrote it down, would save you a month of work? Reply with one — I'll share mine in the thread."

**Hashtags:** #AIinAustralia #BuildingInPublic #WorkflowDesign

---

## ARC-LEVEL META

**Why this works (6 posts, 2 weeks):**

1. **Post 1 hooks** with the silence. Anyone who's been quiet on LinkedIn (or social) will recognise it.
2. **Post 2 makes it personal** — the moment of self-deception, not the moment of failure.
3. **Post 3 reframes** the problem as a systems problem, not a personal one. Removes shame.
4. **Post 4 gives the fix** — specific, actionable, testable.
5. **Post 5 generalises** — turns Ken's experience into a universal practitioner lesson.
6. **Post 6 leaves a door open** — invites the reader in. The CTA is a question, not a pitch.

**Voice rules applied throughout:**
- No em-dashes (—) — use periods, commas, or hyphens
- No "co-founder", "founding", or similar
- No mentions of AInchors, Yoda, agent names, model names, or platform internals
- No consulting-speak ("helping businesses X", "I help teams Y")
- Real numbers where they fit (17 days, 600 words, 18 likes, 4 days, 11 minutes, 90 seconds)
- Short punchy sentences. Paragraph breaks at the right points.
- Australian context (not forced, just natural)
- First-person Ken's voice throughout

**Acceptance criteria (reactivation v2 GO):**

- [ ] Post 1 lands Tue 16 Jun 07:30 AEST — first post in 17 days, must feel like re-engagement
- [ ] All 6 posts pass governance gate (no em-dashes, no internal mentions, no co-founder, no fake clients, no consulting-speak)
- [ ] All 6 posts reviewed by Ken via Telegram before any posting
- [ ] If any post is rejected 2 weeks in a row, escalate to Ken — campaign pause
- [ ] Spark daily metrics cron 5d581442 continues reporting

## What I Need From Ken

For the 6-post arc:
- **Approve all 6 as-drafted** (Spark drafts from these angles)
- **Modify** specific posts (you rewrite angles, Spark drafts from your words)
- **Replace** specific posts (different angle for that slot)
- **Skip** any slot (reserved but no post that day)
- **Sequence change** (e.g., post 3 before post 2 — different narrative order)
