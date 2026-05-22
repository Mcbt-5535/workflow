---
description: Morning routine — load yesterday's summary + active plan, then start work.
---

Morning / resume briefing (be concise — max 12 lines total):

1. Run `date +%Y-%m-%d` and capture today's date.
2. Find the **most recent** file in `.claude/workflow/summaries/`, by mtime (`ls -t .claude/workflow/summaries/*.md | head -1`). Categorize it:
   - `YYYY-MM-DD.md` → a full daily summary
   - `YYYY-MM-DD-checkpoint-HHMM.md` → a mid-day or emergency checkpoint
   Read just that one file.
3. Look for any `.claude/workflow/plans/*.md` with `status: in_progress`. Read its frontmatter + Plan section only.
4. Output a briefing in this shape:

```
📅 <today's date>

Last session (<summary | checkpoint at HH:MM>): <one line>

Active plan: <plan path> (N/M done)
Next step: <first unchecked step title>
In flight (from checkpoint): <step title, only if the checkpoint flagged one>

Blockers / human-needed: <any HUMAN: items or [?] steps, or "none">
Uncommitted changes: <yes — N files | no | unknown>

→ Run /wf-dev to execute the next step, or /wf-plan <task> to start something new.
```

Do not auto-run `/wf-dev`. Wait for me to confirm.
