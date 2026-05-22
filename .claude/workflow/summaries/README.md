# .claude/workflow/summaries/

One file per day, written by `/wf-evening` and read by `/wf-morning`.

**Naming:** `YYYY-MM-DD.md` — e.g. `2026-05-22.md`.

**Purpose:**

- Resume tomorrow without rebuilding mental state from scratch.
- Provide context to the next session's `SessionStart` hook (lighter than re-reading the plan).
- Record decisions and surprises that wouldn't survive in git log alone.

**Shape:** see `.claude/commands/evening.md` for the canonical template. Roughly:

```
## Shipped       — what got done
## In progress   — what's left in active plans
## Blocked       — [?] steps and HUMAN: notes
## Tomorrow's first move  — exact command to run
## Notes         — surprises, decisions, links
```

Keep summaries terse. They're a handoff to future-you, not a journal.
