---
description: Plan a new task. Invokes the planner subagent (Opus) to save a step-by-step plan to .claude/workflow/plans/.
argument-hint: <task description>
---

Use the `wf-planner` subagent to plan the following task:

$ARGUMENTS

The planner will:
1. Briefly inspect the codebase
2. Write a structured plan to `.claude/workflow/plans/YYYY-MM-DD-<slug>.md`
3. Return only the path + a one-line goal

After it returns, tell me the plan path. Do not start implementing — wait for `/wf-dev`.
