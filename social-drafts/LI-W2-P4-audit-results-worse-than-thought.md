# LI-W2-P4 — "I ran an audit. The results were worse than I thought."

## Slot
Tue 23 Jun 07:30 AEST

## Draft

---

Some time back I decided to look at my own AI system the way a new engineer joining the company would look at it.

That mindset changed everything.

I wrote a set of questions. Nothing fancy. Just the basics: does this thing do what it says it does? Where does state live? What happens when the primary path fails?

Then I opened the spec documents and compared them to the actual running workflows.

They did not match.

The audit found a long list of problems I'd been working around without even realising it. Rules that contradicted each other. One said "be conservative." Another said "ship fast." Both were active in the same workflow.

Context budgets existed in theory but had never been measured. So nobody knew which workflows were blowing past their allocation until they visibly slowed down.

Quality gates existed on paper but not in the code path. The checkbox was always ticked. The gate was never actually wired.

And the fallback chain. It "worked" in the sense that the system didn't crash. But it had never been tested under real failure conditions. When the real failure came, the fallback folded.

The number that surprised me: most of what I thought was functioning was actually being held together by small workarounds I'd added in real time as the system grew.

I had been polishing the surface while the structure underneath kept quietly shifting.

**What I learned:** You cannot rebuild a foundation you haven't measured. The audit isn't bureaucracy. It's the first honest look at what you actually built versus what you think you built.

**What I do now:** Small, regular audits. Automated. With alerts. The structure underneath gets looked at before it becomes a surprise.

#AIinAustralia #BuildingInPublic #AuditBeforeFix

---

## Image Prompt
Close-up of a worn leather-bound notebook open on a desk, the page covered in a hand-drawn audit checklist with several items circled in red ink, soft warm desk-lamp light, muted browns and creams, documentary photography style, intimate and honest mood. Square 1:1 format, no text, no logos, professional quality.

## Governance
CLEARED (Shield: clear, Lex: conditional, Sage: conditional)
