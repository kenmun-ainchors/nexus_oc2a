# LI-W1-P3 — "The four things that quietly broke when everything was loud"

## Slot
Thu 18 Jun 07:30 AEST

## Draft

---

Everyone sees the visible failures. The invisible ones are what kills you.

When the cost bent, the visible failure was the bill. The invisible failures were the four things that broke underneath:

1. Hydration drift. The system started losing context between calls. State that should have been preserved was being re-interpreted each time. The output looked the same. It wasn't.

2. Context exhaustion. The model that used to handle long workflows started failing earlier. No error message. Just a sudden drop in quality.

3. Execution decay. Tasks that used to complete in a few steps started taking more. The extra steps weren't useful. They were retries dressed up as progress.

4. Drift. The system's behaviour started to deviate from its spec. Slowly. Eventually I noticed. The drift had been happening for a while.

The cost was the symptom. These four were the disease.

When one thing breaks visibly, four things are breaking invisibly. The visible failure is the canary. The invisible ones are the coal mine.

When you see a big visible problem, audit the four things that live underneath it. The visible problem is almost never the whole story.

#AIinAustralia #BuildingInPublic #FoundationWork

---

## Image Prompt
A row of four drinking glasses on a dark wood table, three of them cracked in nearly-invisible places and leaking a single drop each, the fourth one intact, single warm light source from one side, muted earth tones, editorial still-life photography, contemplative and slightly melancholic mood. Square 1:1 format, no text, no logos, professional quality.

## Governance
CLEARED (Shield: clear, Lex: conditional, Sage: conditional)