# LinkedIn Draft — LI-W5-P15
## The metric that lies
**Slot:** Thu 16 Jul 07:30 AEST
**Week:** 5 | **Post:** 3 | **Theme:** What AI Agents in Production Actually Look Like
**Movement:** Post-arc, Theme A rotation

---

The first metric I tracked was output volume. How many tasks did the agent complete? How fast? How many calls per hour?

It looked healthy. The numbers went up. I felt good.

Then I started reading the outputs.

A large share of the "completed" tasks were wrong. Not dramatically wrong. Subtly wrong. The kind of wrong that passes a surface check but fails a quality check. The agent had finished the task, logged it as complete, and moved on. The metric said success. The reality said failure.

I had built a system that optimised for throughput over accuracy. And because throughput is easier to measure, I had fooled myself into thinking the system was working.

The worst metrics in AI operations are the ones that feel good. Completion rate without quality review. Token efficiency without output review. Speed without correctness. Cost per call without error rate. They all tell a story. It's just not the real story.

What I track now:

1. **Quality pass rate** — of everything the agent produces, what percentage would I ship without editing?
2. **Silent failure rate** — how often does the agent complete a task and produce something plausible but wrong?
3. **Context drift** — how often does the agent lose track of what it's doing mid-workflow?
4. **Recovery time** — when the agent fails, how long before a human notices and fixes it?

None of these numbers feel as good as throughput. But they're the only numbers that matter.

The metric that lies is the one you want to be true.

#AIinAustralia #BuildingInPublic #MetricsThatMatter

---

## Image Prompt
A close-up of a vintage analog gauge on industrial machinery, the needle pointing firmly into a green "OPTIMAL" zone, but a second smaller dial below it showing a red warning zone, soft workshop lighting, muted metallic greys with the red warning accent catching the light, editorial product photography, the tension between surface optimism and hidden trouble. Square 1:1 format, no text, no logos, professional quality.