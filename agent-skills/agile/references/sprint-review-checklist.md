# Sprint Review Checklist

Canonical checklist for Sprint Review ceremony output. Used by `agent-skills/agile/scripts/sprint-review.sh`.

## Purpose

Answer these questions at the end of every sprint:

1. What did we commit to?
2. What actually shipped?
3. What is the velocity signal?
4. Is the platform healthy?
5. Are we within budget?
6. Are any crons failing?
7. What decisions or drafts are still open?
8. What risks or blockers exist?
9. What should the next sprint know?

## Checklist

### 1. Sprint identity
- [ ] Sprint name and dates
- [ ] Days remaining / elapsed
- [ ] Sprint status (`in_progress`, `committed`, `planning`, etc.)

### 2. Committed scope
- [ ] Total committed items
- [ ] Items per agent
- [ ] Effort distribution

### 3. Delivery status
- [ ] Done / closed count
- [ ] Open / in-progress count
- [ ] Folded / deferred count
- [ ] Blocked count
- [ ] Completion percentage

### 4. Velocity signal
- [ ] Compare planned vs completed
- [ ] Note carry-forward items
- [ ] Flag if completion < 60% (mandatory retrospective trigger)

### 5. Platform health
- [ ] Gateway status
- [ ] Disk status
- [ ] Ollama reachability
- [ ] Any degraded checks

### 6. Cost / budget
- [ ] Ollama weekly request usage (% used, remaining, burn rate)
- [ ] Any budget threshold breaches

### 7. Cron health
- [ ] Any cron failures
- [ ] Consecutive errors > 0
- [ ] Delivery failures (e.g., bad Telegram target)

### 8. Open decisions
- [ ] Read `state/open-decisions.json`
- [ ] Surface items needing Ken input

### 9. Draft docs
- [ ] Read `state/draft-docs.json`
- [ ] Surface drafts awaiting review

### 10. Risks / next-sprint signals
- [ ] P1/P2 blockers
- [ ] Items deferred to next sprint
- [ ] Capacity implications
- [ ] Recommended focus for planning

## Output format

`sprint-review.sh` writes a structured Markdown report to:

```
.openclaw/tmp/sprint-review-report-<Sprint-N>.md
```

And prints a concise summary to stdout.

## References

- Agile skill: `agent-skills/agile/SKILL.md`
- Sprint ops: `agent-skills/pg-sprint-backlog/SKILL.md`
