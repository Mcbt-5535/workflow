# .claude/workflow/plans/

活跃计划和近期完成的计划，每个任务一个 markdown 文件。

**命名规则：** `YYYY-MM-DD-<简短描述>.md`，例如 `2026-05-22-add-cli-sort-flag.md`。

**Frontmatter（由 agent 管理，可手动编辑）：**

```yaml
---
date: 2026-05-22
slug: add-cli-sort-flag
status: in_progress    # 或 done
model_for_dev: haiku
---
```

**正文格式：** 见 `.claude/agents/planner.md` 中的标准模板。

你可以随时手动编辑任何计划文件。`developer` agent 会在下一次 `/wf-dev` 时读取最新内容。
如果想让 Claude 帮你做结构化修改，可以用 `/wf-interrupt <改动>`。

已完成的计划（所有步骤 `[x]`，`status: done`）由 `/wf-evening` 移至 `../.claude/workflow/archive/`。
