# Claude Code Workflow — 可安装、轻侵入

一个 **Plan → Dev → Review** 工作流，可以一键装入任何已有项目，
只新增一个文件夹和少量带前缀的 shim 文件。
通过把规划/审查路由到 Opus、把批量实现路由到 Haiku 来节省 token。

```
🧠 /wf-plan (Opus)  →  ⚙️  /wf-dev (Haiku) × N  →  🔍 /wf-review (Opus)
```

## 以 Git Submodule 方式安装（推荐）

最简单的安装方式。工作流在第一次启动 `claude` 时自动激活，无需运行任何安装脚本。

1. **把 submodule 加入项目：**
   ```bash
   git submodule add https://github.com/anthropics/workflow .workflow
   ```

2. **初始化配置（仅一次）：**
   ```bash
   mkdir -p .claude
   cp .workflow/.claude/workflow/auto-activate.snippet.json .claude/settings.json
   # 若已有 settings 文件，用 jq 合并：
   # jq -s '.[0] * .[1]' .claude/settings.json .workflow/.claude/workflow/auto-activate.snippet.json > /tmp/merged.json && mv /tmp/merged.json .claude/settings.json
   ```

3. **启动 Claude Code：**
   ```bash
   claude
   ```
   首次启动时工作流静默自动激活。submodule 路径默认为 `.workflow/`；
   如需自定义（如 `vendor/workflow/`），设置 `WF_SUBMODULE_PATH=vendor/workflow` 后重启。

## 以复制方式安装（备用）

无法使用 Git submodule 时：
```bash
make -C <path-to-workflow-repo> install-copy TARGET=~/your-project
```
说明：复制所有 `wf-*` 文件和 `.claude/workflow/` 目录；需要 `jq` 自动合并 settings。

## 卸载

```bash
make -C .workflow uninstall                    # 标准卸载
make -C .workflow uninstall ARGS=--clean-settings  # 同时清理 settings
```

Submodule 完全移除：
```bash
git submodule deinit -f .workflow
git rm -f .workflow
git commit -m "Remove workflow submodule"
```

## 顶层 Make 目标速查表

| Make 目标 | 作用 |
|---|---|
| `make install` | submodule 符号链接模式安装 |
| `make install-copy TARGET=<dir>` | 复制模式安装 |
| `make uninstall` | 卸载工作流 |
| `make auto-activate` | 安全激活守卫（SessionStart hook 用） |
| `make clean [ARGS=...]` | 清理 runtime 产物 |
| `make checkpoint REASON='...'` | 0-token 紧急存档 |
| `make contribute DESC='...'` | 创建上游贡献分支 |
| `make contribute-push` | push 并开 PR |

## Slash 命令一览

| 命令 | 作用 | 模型 |
|---|---|---|
| `/wf-plan <任务>` | 规划任务 | Opus（planner subagent） |
| `/wf-dev` | 执行下一步 | Haiku（developer subagent） |
| `/wf-review` | 审查 `git diff` | Opus（reviewer subagent） |
| `/wf-morning` | 加载昨日上下文 | 主对话 |
| `/wf-evening` | 每日总结 + 规划明天 | 主对话 |
| `/wf-handoff` | 为人工审查者做简报 | 主对话 |
| `/wf-checkpoint <原因>` | 紧急存档（消耗 token） | 主对话 |
| `/wf-status` | 查看进度 | 主对话 |
| `/wf-interrupt <改动>` | 修改活跃计划 | 主对话 |
| `/wf-contribute <描述>` | 为工作流创建贡献分支 | 主对话 |

## 侵入范围

安装后，**顶层唯一新增的是 `.workflow/` submodule**。所有其他内容都在 `.claude/` 内部：

```
.claude/
├── agents/wf-*.md                    # 3 个带前缀的 agent 定义
├── commands/wf-*.md                  # 9 个 slash 命令
├── hooks/wf-*.sh                     # 4 个事件 hook
├── skills/wf-workflow-intro/         # 1 个 skill
└── workflow/                         # 唯一新命名空间
    ├── plans/                        # 活跃计划 + 已完成计划
    ├── summaries/                    # 每日总结 + 检查点
    ├── archive/                      # 已完成归档
    ├── auto-activate.snippet.json    # settings 合并片段
    ├── install.sh                    # submodule 安装脚本
    ├── checkpoint.sh                 # 0-token 紧急存档
    ├── WORKFLOW.md                   # agent 规则（AI 端）
    ├── _lib.sh                       # 共享工具库
    └── clean.sh                      # 清理脚本
```

卸载：`make -C .workflow uninstall` 删除所有内容。

## 贡献回上游

Submodule 安装后，可在项目内直接贡献改进：

1. **创建贡献分支：**
   ```bash
   make contribute DESC="改进 planner 提示词"
   ```

2. **原地编辑并提交（符号链接自动同步）：**
   ```bash
   git -C .workflow commit -am "优化 planner 指令"
   ```

3. **推送并开 PR：**
   ```bash
   make contribute-push
   ```

详见 `make help`。
