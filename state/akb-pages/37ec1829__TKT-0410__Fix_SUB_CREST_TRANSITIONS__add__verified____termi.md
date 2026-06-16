# [TKT-0410] Fix SUB_CREST_TRANSITIONS: add 'verified' → terminal edge so typed completion paths work for verified tasks

- **Notion ID:** `37ec182953ff81868340eb273e247c5f`
- **Status:** Open
- **Type:** Bug
- **Priority:** High
- **Category:** Technical
- **Sprint:** Sprint 8
- **Created:** 2026-06-12T09:57:00.000+10:00
- **Last Edited:** 2026-06-15T00:58:00.000Z

## Notes

scripts/lib/pg_task_queue.py:611 SUB_CREST_TRANSITIONS map does not include 'verified' as a source state. This blocks all typed completion mutators (sc_sub_crest_complete, sc_complete_atom, pg_set_task_status) from transitioning a task from 'verified' to 'complete'/'done'/'sub_crest_done'. Symptom: tasks with all atoms verified but parent done are stuck in 'verified' indefinitely (e.g. task-2026-06-10-f9504783, stuck 10h). Fix: add minimum edge 'verified': {'complete', 'sub_crest_done', 'done'}. Optional followup: rename 'verified' at task level to avoid collision with atom-level 'verified'.
