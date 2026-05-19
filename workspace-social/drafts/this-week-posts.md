# This Week's LinkedIn Posts — APPROVED
## Theme: "What AI Agents in Production Actually Look Like"
## Voice: Ken Mun, CTO — first-person, reflective, personal learning
## Status: ✅ ALL 3 APPROVED by Ken Mun (Telegram) 2026-05-19 12:10 AEST
## Slots: Tue 20 May 07:30 / Wed 21 May 12:00 / Thu 22 May 07:30 AEST

---
## POST 1 — Tuesday 20 May 07:30 AEST
### Title: What I learned taking AI from demo to production

Three weeks ago, I started putting AI agents into actual production workflows. Not demos. Not prototypes. Real systems that have to keep running when nobody's watching the dashboard.

I thought the hard part would be the AI itself. It wasn't. Getting an LLM to generate a coherent response in a controlled environment took me about twenty minutes. Getting that same system to handle edge cases, maintain state across sessions, recover from API failures without corrupting data, and stay within a reasonable cost envelope — that has been the real journey.

Here's what surprised me most: the gap between "works in the demo" and "works in production" is enormous. Orders of magnitude bigger than I expected. Every time I thought I was 80% done, I'd discover a new failure mode that sent me back to the drawing board. An agent that works perfectly for five runs suddenly fails on the sixth because a timeout shifted. A pipeline that handles 10 tasks cleanly crumbles at 11 because of a race condition in the queue.

The lesson I keep coming back to: production AI is an operations problem, not a model problem. The model is rarely the thing that breaks. It's the scaffolding around it — the queues, the retry logic, the verification steps, the logging, the human handoff points. That's where the real engineering lives.

I've stopped asking "which model should I use?" and started asking "how will I know when this fails, and what happens next?"

Curious what ratio other builders are seeing between demo time and production hardening. It's been humbling on my end.

---
📸 **Image prompt for ChatGPT (DALL-E 3):**
> A minimalist split-view illustration: left side shows a polished, glowing AI demo on a laptop screen with a small "20 min" label. Right side shows the same laptop but now surrounded by layers of scaffolding — pipes, nodes, retry loops, verification checkpoints, monitoring dashboards — with a label "3 weeks and counting." Clean modern flat design. Dark navy background with teal and warm amber accent nodes. Professional tech illustration style. Square 1:1 format. No text in image. No logos. No faces.
Format: 1024x1024 square

---
## POST 2 — Wednesday 21 May 12:00 AEST
### Title: The bottleneck is never where I think it'll be

I used to spend a lot of time comparing models. GPT-4 versus Claude versus Gemini. Reading benchmark scores. Wondering if switching providers would unlock the next level of capability.

Then I started tracking where my AI systems actually broke in production. The results surprised me.

The model was never the bottleneck. Not once.

What actually slowed things down: data moving between systems and losing context along the way. Partial failures where one component crashed but the workflow had to keep going. Knowing when the AI was confident versus when it was guessing — and routing accordingly. Making outputs traceable so someone could verify what happened. Managing costs that scaled unpredictably with usage.

None of these are model problems. These are engineering problems. Design problems. Operations problems. And they took far more of my time than I ever expected.

Here's what I'd tell myself six months ago: the difference between a "good" model and a "great" model is noise compared to the difference between thoughtful system design and no system design. The ceiling is high enough now that the model is rarely the constraint. The constraint is everything around it.

These days I pick a solid model and move on quickly. The real work is in the plumbing — and that's where I've learned the most.

What's the bottleneck that caught you off guard when you moved from experiment to production?

---
📸 **Image prompt for ChatGPT (DALL-E 3):**
> An abstract funnel or bottleneck diagram: at the wide top, small equal-sized boxes labelled with AI model names (GPT, Claude, Gemini) flow down. At the narrow bottom, much larger blocks represent the real constraints — data pipes, retry queues, verification gates, cost meters. The narrow point is not the models but the infrastructure around them. Clean modern infographic style. Dark background with teal, blue, and warm amber. Professional, elegant. Square 1:1 format. No text in image. No logos. No faces.
Format: 1024x1024 square

---
## POST 3 — Thursday 22 May 07:30 AEST
### Title: The most valuable skill I've picked up this year

If you'd asked me a year ago what skill would matter most in deploying AI, I probably would have said prompt engineering. It's everywhere. Courses, certifications, LinkedIn badges. The whole industry seems to agree.

I was wrong.

The skill that's actually made the biggest difference for me? System design thinking.

Here's what that looks like in practice: knowing when to trust the AI's output and when to route to a human. Breaking a complex workflow into atomic steps where each one can be verified independently. Designing for graceful degradation — the system should get slower or less capable under load, not completely broken. Instrumenting everything so when something goes wrong, you can trace the decision back to its source.

Prompting gets you a clever response. System design gets you a system that works at 2am when nobody's watching the dashboard. One is tactical. The other is strategic.

I learned this the hard way. I spent weeks optimizing prompts for a workflow that collapsed the moment it hit real-world variability. The prompts were polished. The pipeline around them wasn't. That was a humbling realization — and the most valuable one of the year.

Learn to think in systems. The prompting will follow naturally.

What's the one engineering principle you wish you'd understood before your first production AI deployment?

---
📸 **Image prompt for ChatGPT (DALL-E 3):**
> A clean, abstract visual contrasting two approaches: on the left, a single floating text bubble with a neat checkmark (representing prompt engineering). On the right, an interconnected system diagram with nodes, verification gates, routing paths, and dashboards all working together (representing system design). The right side glows subtly, drawing the eye. Minimalist professional illustration style. Dark navy background with teal, blue, and subtle gold accents. Square 1:1 format. No text. No logos. No faces.
Format: 1024x1024 square
