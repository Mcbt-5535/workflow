# Claude Code Workflow — Plan / Dev / Review

一个可复制、可移动的 Claude Code workflow 系统，用 **三角色分工 + 本地 markdown 计划 + hooks 续航** 来省 token 并保持质量。

```
🧠 Opus 规划   →   ⚙️  Haiku 实现   →   🔍 Opus 审查
   /wf-plan              /wf-dev × N            /wf-review
```

## 设计原则

| 痛点 | 这里的做法 |
|---|---|
| 大模型实现代码贵 | 规划/审查用 Opus（一次性），实现用 Haiku（重复调用） |
| 长对话 context 膨胀 | 计划落盘成 `.md`，每次会话重新加载 |
| 多日工作衔接难 | `/wf-evening` 写总结，`/wf-morning` 读计划，hooks 自动注入 |
| 计划想随时改 | 直接编辑 `.claude/workflow/plans/*.md` 或用 `/wf-interrupt`，dev agent 下一轮自动跟进 |
| review 拉全文很贵 | reviewer 只读 `git diff`，最多看 5 个问题 |

## 快速上手

```bash
# 1. 把整个 workflow/ 目录复制到任何项目下，或在当前目录直接用
cp -r workflow/ ~/your-project/
# 或者用 install.sh 安装到别的项目
bash install.sh ~/your-project

# 2. 给 hooks 加执行权限（首次复制后）
chmod +x .claude/hooks/*.sh

# 3. 启动 Claude Code
cd ~/your-project
claude

# 4. 试一下完整循环
/wf-plan 给 CLI 加一个 --sort-by-date 选项
/wf-dev          # 执行第 1 步
/wf-dev          # 执行第 2 步
/wf-review       # 提交前审查
/wf-evening      # 写当日总结，规划明天
```

## 命令速查

| 命令 | 作用 | 谁来跑 |
|---|---|---|
| `/wf-plan <任务>` | 拆解任务、写计划 | planner (Opus) |
| `/wf-dev` | 执行计划下一步 | developer (Haiku) |
| `/wf-review` | 基于 `git diff` 审查 | reviewer (Opus) |
| `/wf-morning` | 早上加载昨日上下文 | 主对话 |
| `/wf-handoff` | 下午做人工交接简报 | 主对话 |
| `/wf-evening` | 晚上总结 + 规划明天 | 主对话 |
| `/wf-status` | 查看所有计划进度 | 主对话 |
| `/wf-interrupt <改动>` | 不丢进度地修改活跃计划 | 主对话 |

## 目录结构

```
workflow/
├── .claude/
│   ├── settings.json              # 权限 + hooks 配置
│   ├── agents/
│   │   ├── planner.md             # Opus 规划者
│   │   ├── developer.md           # Haiku 实现者
│   │   └── reviewer.md            # Opus 审查者
│   ├── commands/
│   │   ├── plan.md                # /wf-plan
│   │   ├── dev.md                 # /wf-dev
│   │   ├── review.md              # /wf-review
│   │   ├── morning.md             # /wf-morning
│   │   ├── evening.md             # /wf-evening
│   │   ├── handoff.md             # /wf-handoff
│   │   ├── status.md              # /wf-status
│   │   └── interrupt.md           # /wf-interrupt
│   ├── hooks/
│   │   ├── session-start.sh       # 启动时注入活跃计划
│   │   └── stop.sh                # 晚间提醒写总结
│   └── skills/
│       └── workflow-intro/
│           └── SKILL.md           # 询问 workflow 时自动加载
├── .claude/workflow/plans/                         # 活跃 + 近期完成的计划
│   └── README.md
├── .claude/workflow/summaries/                     # 每日总结
│   └── README.md
├── .claude/workflow/archive/                       # 已完成归档
│   └── README.md
├── CLAUDE.md                      # 给 Claude 的项目级指令
├── README.md                      # 本文件
└── install.sh                     # 一键复制到其它项目
```

## 一天的典型流程

```
09:00  /wf-morning
       → 读取 .claude/workflow/summaries/2026-05-21.md
       → 加载活跃计划 .claude/workflow/plans/2026-05-21-feature-x.md (3/8 完成)
       → 报告下一步：实现 step 4

09:05  /wf-dev    # Haiku 跑 step 4
09:20  /wf-dev    # Haiku 跑 step 5
09:40  /wf-dev    # Haiku 跑 step 6
10:00  /wf-review # Opus 审查 git diff → 发现 2 个边界 case
10:10  /wf-interrupt 在 step 7 前插入：添加 null 校验
10:15  /wf-dev    # Haiku 修 null
10:25  /wf-dev    # Haiku 跑 step 7

14:00  /wf-handoff
       → 给真人 review 的 5 分钟简报
       → 列出需要拍板的 3 个问题
       → 列出建议一起 debug 的代码块

18:30  /wf-evening
       → 写 .claude/workflow/summaries/2026-05-22.md
       → 把已完成的 plan 移到 .claude/workflow/archive/
       → 写明天第一件事："/wf-dev on .claude/workflow/plans/2026-05-23-..."
```

## 自定义

- **换模型**：编辑 `.claude/agents/*.md` 顶部 frontmatter 的 `model:` 字段（`opus` / `sonnet` / `haiku` / 具体模型 ID）。
- **改计划格式**：编辑 `.claude/agents/planner.md` 里的 "Required plan structure"。
- **关闭 hook**：在 `.claude/settings.json` 里删掉那一段。
- **加新阶段**：照 planner/developer/reviewer 的模式建新 agent + 对应 slash command。

## 为什么省 token

1. Opus 只在规划和审查时短时介入（小 input + 小 output）。
2. Haiku 跑大部分实现代码（同样长度，单价约为 Opus 的 1/15）。
3. 每次 `/wf-dev` 是独立的小 context，不会把整段对话历史塞回去。
4. Review 只读 `git diff`，不读全文件。
5. 计划落盘 → 跨会话续航时只需读一个 markdown，不重复 reasoning。

## 5 小时限额生存指南

| 组件 | 限额触发时 |
|---|---|
| hooks (session-start / post-tool / stop / session-end) | ✅ 继续工作（纯 bash，不调 API） |
| `.claude/workflow/plans/STATUS.md` / `.progress.log` | ✅ 仍在自动更新 |
| 文件、git、计划 markdown | ✅ 全部保留 |
| `/wf-checkpoint` `/wf-morning` `/wf-dev` `/wf-review` 等 slash | ❌ 全部失败（需要模型） |
| `bash checkpoint.sh` | ✅ 仍可跑（**0 token**） |

操作流程：

```bash
# 限额已到，slash 用不了。在另开的终端里跑：
bash checkpoint.sh "限额到了，明天继续"
# → 保存 .claude/workflow/summaries/<date>-checkpoint-<HHMMSS>.md
# → 包含：活跃计划、下一步、git status、最近 .progress.log
# 关 Claude Code，关机

# 第二天窗口重置后：
cd /your/project
claude
# SessionStart hook 自动注入：ACTIVE PLAN: ... (N/M done). Next: ...
/wf-morning   # 完整 briefing
/wf-dev       # 接着干
```

如果你担心 `/wf-dev` 跑到一半被限额打断、代码改了但 checkbox 还是 `[ ]`：checkpoint 文件会提醒你先 `git diff` 看一眼，再决定是继续还是 `git checkout --` 回滚那一步。

## 局限性

- Hooks 不能自动切模型——切模型靠 subagent 的 `model:` frontmatter。
- 评审基于本地 uncommitted diff，已经 commit 的内容要 `git diff HEAD~N..HEAD`。
- 计划文件名用日期 + slug，同一天多个计划会按 slug 区分；非常活跃的话可以加时间戳。
- `bash checkpoint.sh` 不能在限额期间还跑 git stash / commit——它只读不写仓库，需要的话你手动来。
