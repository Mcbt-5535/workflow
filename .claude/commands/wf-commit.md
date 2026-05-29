---
description: 调用 wf-commit agent 分析当前暂存区变更，生成 commit 草稿并预填到 .git/COMMIT_EDITMSG
---

使用 `wf-commit` agent 分析当前 git 暂存区的变更，自动生成规范的 commit 草稿（格式：`[type] 标题 + 改动列表`），并写入 `.git/COMMIT_EDITMSG` 供 `git commit` 预填，同时保存备份到 `.claude/workflow/commit-drafts/` 目录。

本命令**完全手动触发，无自动运行逻辑**。Agent 不会执行任何 `git add` / `git commit` / `git tag` 命令。

生成后，运行 `git commit`（不带 `-m`）即可在编辑器中查看预填消息，你可以继续编辑或直接确认。
