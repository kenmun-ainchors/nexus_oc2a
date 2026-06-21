# LI-W2-P4 — "I ran an audit. The results were worse than I thought."

## Slot
Tue 23 Jun 07:30 AEST

## Draft

---

The audit I ran on my own AI system found 11 structural problems.

I had been working around most of them without knowing it.

I looked at the system the way a new engineer joining the company would look at it. I opened the specs and compared them to the running workflows. They did not match.

The problems grouped into four buckets:

**Rules that fought each other.** One said "be conservative." Another said "ship fast." Both were active in the same workflow.

**Budgets that existed in theory but were never measured.** Context allocations looked fine on paper. We only noticed overflows when things slowed down.

**Gates that existed on paper but not in the code path.** The checkbox was always ticked. The actual check had never been wired.

**Fallbacks that had never been tested under real failure.** They "worked" in the sense that the system did not crash. When a real failure came, the fallback folded.

The rest were variations on the same theme: documentation pretending to be enforcement, checks pretending to be gates, and small workarounds I had added in real time as the system grew.

The number that shocked me: most of what I thought was working was actually being held together by patches I did not remember writing.

I had been polishing the surface while the structure underneath kept quietly shifting.

**What I learned:** You cannot rebuild a foundation you have not measured. The audit is not bureaucracy. It is the first honest look at what you actually built versus what you think you built.

**What I do now:** Small, regular audits. Automated. With alerts. The structure underneath gets looked at before it becomes a surprise.

#AIinAustralia #BuildingInPublic #AuditBeforeFix

---

## Image Prompt
Close-up of a worn leather-bound notebook open on a desk, the page covered in a hand-drawn audit checklist with several items circled in red ink, soft warm desk-lamp light, muted browns and creams, documentary photography style, intimate and honest mood. Square 1:1 format, no text, no logos, professional quality.

## Governance
CLEARED (Shield: clear, Lex: conditional, Sage: conditional)

