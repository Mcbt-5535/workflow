# .claude/workflow/plans/

Active and recently-completed plans. One markdown file per task.

**Naming:** `YYYY-MM-DD-<short-slug>.md` — e.g. `2026-05-22-add-cli-sort-flag.md`.

**Frontmatter (managed by agents, safe to edit by hand):**

```yaml
---
date: 2026-05-22
slug: add-cli-sort-flag
status: in_progress    # or done
model_for_dev: haiku
---
```

**Body shape:** see `.claude/agents/planner.md` for the canonical template.

You can edit any plan by hand at any time. The `developer` agent will pick up changes on the next `/wf-dev`. Use `/wf-interrupt <change>` if you want Claude to apply a structured change for you.

Completed plans (all `[x]`, `status: done`) are moved to `../.claude/workflow/archive/` by `/wf-evening`.
