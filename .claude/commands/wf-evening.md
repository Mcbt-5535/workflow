---
description: Evening routine — write today's summary, plan tomorrow's first step, archive completed plans.
---

Evening wrap-up:

1. Capture today's date: `date +%Y-%m-%d`.
2. Gather signals:
   - Active plans: `ls .claude/workflow/plans/*.md` and read frontmatter + checkbox stats.
   - Today's commits (if git repo): `git log --since=midnight --oneline`.
   - Uncommitted changes: `git status --short`.
3. Write `.claude/workflow/summaries/YYYY-MM-DD.md` in this exact format:

```markdown
---
date: YYYY-MM-DD
---

# Daily summary — YYYY-MM-DD

## Shipped
- <bullet per completed step or commit>

## In progress
- Plan: <path> (N/M done) — next step: <title>

## Blocked / needs human
- <each `[?]` step or HUMAN: note from active plans>

## Tomorrow's first move
- **Start with:** `/wf-dev` on `<plan path>` → step "<title>"
- Or: `/wf-plan <new task>` if priorities shifted

## Notes
- <anything worth remembering — surprises, decisions, links>
```

4. For each plan whose checklist is 100% done:
   - Update its frontmatter `status: in_progress` → `status: done`.
   - Move it from `.claude/workflow/plans/` to `.claude/workflow/archive/`.

5. Report back in 3 lines:
   - summary path,
   - count of plans active / archived today,
   - tomorrow's first move.

Do not write code or modify other files. Just summarize + archive.
