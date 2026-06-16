# LI-W1-P2 — "What happens to your AI when the model underneath you disappears"

## Slot
Wed 17 Jun 12:00 AEST

## Draft

---

The model that powered my entire workflow was deprecated on a weekday afternoon. By the end of the week, half my system was running in a degraded state I didn't fully understand.

The transition wasn't sudden. It was a slow leak.

First the model's quality started drifting. Then the context window got smaller. Then the routing rules that had been working for ages started returning errors.

I kept patching. Switched the high-stakes workflows to a stronger model. Moved the bulk work to a cheaper one. Wrote more aggressive caching. Pulled context out of every call I could.

Each fix bought a window. None of them fixed the underlying problem: the model I'd designed the system around was no longer the right model, and I was rebuilding on the fly.

The honest version: I'd optimised for one model and never planned the migration.

Building an AI workflow around a single model is like building a house on one supplier's bricks. The day they change the spec, your house has a different shape.

Design for model portability. Treat the model as a replaceable component, not a foundation. The foundation is the spec, the discipline, the governance. The model is the engine.

#AIinAustralia #BuildingInPublic #ModelPortability

---

## Image Prompt
A row of identical engine blocks on a workshop bench, one engine block slightly different from the others, side-by-side comparison photo, soft industrial light, warm neutral palette with one block highlighted in cooler steel-blue, editorial product photography, calm but disquieting mood. Square 1:1 format, no text, no logos, professional quality.

## Governance
CLEARED (Shield: clear, Lex: clear, Sage: clear)