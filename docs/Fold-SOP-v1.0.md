## Fold SOP — Ticket Folding Standard Operating Procedure
### Locked: 2026-06-01 | Authority: Ken Mun | CHG-0456 | NON-NEGOTIABLE

This SOP applies whenever Ken instructs "fold [child] into [parent]" or "merge [child] into [parent]".
Folding = child ticket scope is absorbed into parent. The child closes. No knowledge is lost.

### Gate 1 — SCOPE EXTRACTION (must pass before close)
Extract the child ticket's scope from ALL available sources:
- Ticket title, description, ACs (if they exist)
- CHANGELOG.md references
- Ken's notes/briefs (verbatim if available)
- Any linked tickets or child tickets

If the child ticket has NO description and NO ACs (L-047 violation), reconstruct scope from title + CHANGELOG + memory search. Document the reconstruction in both tickets.

### Gate 2 — SCOPE MIGRATION (must pass before close)
Map every distinct requirement from the child to the parent:
- If covered by existing parent AC → note which AC
- If covered by a parent child-ticket → note which child
- If NOT covered → ADD AS NEW AC to parent
- If partially covered → ADD the missing part as sub-AC

Write the mapping into `metadata.folded_scope` on the parent ticket as structured JSON:
```json
{
  "CHILD-TKT-ID": {
    "title": "...",
    "original_scope": "...",
    "migrated_to": "AC3 / TKT-XXXX / new AC",
    "gaps": ["...if any..."]
  }
}
```

### Gate 3 — PARENT UPDATE
Update the parent ticket:
1. Write full description (if missing per L-047)
2. Update ACs to include any new requirements from gate 2
3. Add child ticket ID to `metadata.folded_tickets` array
4. Add `metadata.ken_brief` if Ken gave specific fold instruction
5. If the child had its own children, re-parent them

### Gate 4 — CHILD CLOSE
Close the child ticket via `ticket.sh close`:
- Resolution: verbatim Ken instruction + pointer to parent
- Example: "2026-06-01 Ken: folded into TKT-0317. Scope migrated: Theme 1 (Progressive Disclosure). Child tickets re-parented. See TKT-0317 metadata.folded_scope."
- Do NOT close until gates 1-3 are complete

### Gate 5 — STATE SYNC & JOURNAL
1. Update `state/sprint-current.json` (if ticket is in sprint)
2. Log CHG entry in `memory/CHANGELOG.md`
3. Journal via `journal-append.sh`
4. Trigger Notion sync (automatic via ticket.sh close)

### ANTI-PATTERN — NEVER DO THIS
- ❌ Close child with generic note: "folded into TKT-0317 — addressed by sub-tickets"
- ❌ Close child without checking parent already covers its scope
- ❌ Close child without reading its actual requirements
- ❌ Close child without migrating distinct scope into parent ACs
- ❌ Assume "the parent epic covers it" without verifying

### Verification Checklist (run before closing child)
- [ ] Child scope extracted from all sources
- [ ] Every requirement mapped to parent AC or child ticket
- [ ] Gaps identified and either: new AC added OR separate child ticket raised
- [ ] `metadata.folded_scope` written on parent
- [ ] Parent description is comprehensive (L-047 compliant)
- [ ] Ken's verbatim fold instruction captured in parent metadata
- [ ] Child's child tickets re-parented (if any)
- [ ] Sprint JSON updated (if applicable)
