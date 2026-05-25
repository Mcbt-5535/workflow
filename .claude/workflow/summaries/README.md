# .claude/workflow/summaries/

每天一个文件，由 `/wf-evening` 写入，由 `/wf-morning` 读取。

**命名规则：** `YYYY-MM-DD.md`，例如 `2026-05-22.md`。

**用途：**

- 明天可以直接接上，无需从头重建思路。
- 为下一个会话的 `SessionStart` hook 提供上下文（比重新读计划轻量）。
- 记录 git log 里保存不下来的决策和意外情况。

**格式：** 见 `.claude/commands/evening.md` 中的标准模板，大致结构：

```
## Shipped       — 完成了什么
## In progress   — 活跃计划中还剩什么
## Blocked       — [?] 步骤和 HUMAN: 备注
## Tomorrow's first move  — 明天第一条要跑的命令
## Notes         — 意外情况、决策、链接
```

总结保持简洁。它是写给未来的你的交接文档，不是日记。
