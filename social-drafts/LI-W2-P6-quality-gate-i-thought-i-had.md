# LI-W2-P6 — "The quality gate I thought I had (and didn't)"

## Slot
Thu 25 Jun 07:30 AEST

## Draft

---

This was the worst thing I found during the audit.

Not the most dangerous. The most embarrassing.

For a long stretch I had been telling myself there was a quality gate. There was a Markdown file describing it. There was a checkbox in the build process. The checkbox was always ticked.

The actual gate, the part that ran a check, raised a flag, stopped a bad output from going forward, had never been built.

The Markdown was the gate. I was trusting documentation to do the work of code.

And the system passed every check. Because there were no checks.

A broken gate screams. A missing gate is silent. That is the danger. You get the false confidence of a process without the protection of one.

After the audit, I rebuilt properly. Three layers now.

Pre-execution guard: checks the input, the model choice, the budget. If anything is off, the workflow does not start.

In-flight guard: every step has a typed outcome. The system can fail loud at any point. It cannot silently skip a step and report success.

Post-execution review: three independent quality checks before anything ships. Not the same check. Not the same model. Not the same criteria.

When all three fire, the output is consistent. When one fails, I know quickly. Not eventually.

**What I learned:** A gate that doesn't fire is worse than no gate. It gives you the comfort of a process without the protection of one. Build the gate. Wire it. Test it. Then test it failing.

**What I do now:** Every gate is in code. Every gate has a test that proves it fires. Every gate has a test that proves it fails when it should. Documentation describes the gate. Code runs the gate.

#AIinAustralia #BuildingInPublic #AuditBeforeFix

---

## Image Prompt
An empty security checkpoint in an industrial building, the gate arm raised, no operator present, the booth lights on, soft cool fluorescent lighting against warm concrete, documentary photography, eerie and slightly unsettling mood. Square 1:1 format, no text, no logos, professional quality.

## Governance
CLEARED (Shield: clear, Lex: conditional, Sage: conditional)
