# Claude Code Workflow

一个 **Plan → Dev → Review** 工作流，把规划/审查路由到 Opus、把批量实现路由到 Haiku，节省 token。

```
🧠 /wf-plan (Opus)  →  ⚙️ /wf-dev (Haiku) × N  →  🔍 /wf-review (Opus)
```

## 安装

把 `.claude/` 目录复制到你的项目根目录即可：

```bash
cp -r /path/to/workflow/.claude /your/project/
```

然后启动 Claude Code：

```bash
cd /your/project
claude
```

## Slash 命令

| 命令 | 作用 | 模型 |
|---|---|---|
| `/wf-plan <任务>` | 规划任务，生成分步计划 | Opus（planner） |
| `/wf-dev` | 执行计划下一步 | Haiku（developer） |
| `/wf-review` | 审查 `git diff` | Opus（reviewer） |
| `/wf-interrupt <改动>` | 修改活跃计划 | 主对话 |
| `/wf-commit` | 生成 commit 草稿 | 主对话 |
| `/wf-morning` | 加载昨日上下文 | 主对话 |
| `/wf-evening` | 每日总结 + 规划明天 | 主对话 |
| `/wf-handoff` | 为人工审查者做简报 | 主对话 |
| `/wf-checkpoint` | 紧急存档（消耗 token） | 主对话 |
| `/wf-status` | 查看计划进度 | 主对话 |
| `/wf-clean` | 清理运行产物 | 主对话 |

## .claude/ 目录结构

```
.claude/
├── agents/wf-*.md            # 4 个子 agent 定义
├── commands/wf-*.md          # slash 命令
├── hooks/wf-*.sh             # 4 个事件 hook
├── skills/wf-workflow-intro/ # intro skill
├── settings.json             # 权限 + hook + 状态栏配置
└── workflow/
    ├── plans/                # 活跃计划
    ├── summaries/            # 每日总结 / 检查点
    ├── archive/              # 已完成计划
    ├── checkpoint.sh         # 0-token 紧急存档（命中用量上限时使用）
    ├── clean.sh              # 清理脚本
    └── WORKFLOW.md           # agent 规则
```

## 版本管理（可选）

`.claude/workflow/version-scripts/` 包含独立的版本管理工具：

| 文件 | 用途 |
|---|---|
| `version_manager.py` | 版本管理 CLI |
| `analyze_commits.py` | 提交分析脚本 |
| `version-bump.yml` | GitHub Actions 自动版本增量模板 |

手动复制到目标项目即可使用，与 wf 工作流完全独立。

## 状态栏

`settings.json` 已配置状态栏，Claude Code 底部实时显示：

```
claude-sonnet-4-6  Thinking:xhigh  In:12.3k Out:1.2k  Ctx:13.5k/200k  5h:42%(↻ 1h30m)  7d:8%
```

依赖 `.claude/statusline-command.sh` 和 `.claude/statusline-parse.py`，两个文件已包含在 `.claude/` 中，复制过去即可直接使用。
