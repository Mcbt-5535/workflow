---
name: wf-workflow-intro
description: Explains how this project's Plan→Dev→Review workflow works. Trigger when the user asks about /plan, /dev, /review, /morning, /evening, /handoff, /status, /interrupt, "the workflow", "how do I save tokens", or seems unsure where to start.
---

# The 3-agent workflow

This project routes work through three specialized agents to save tokens while keeping quality high:

| Stage | Command | Agent | Model | What it does |
|---|---|---|---|---|
| Plan  | `/wf-plan <task>`   | `planner`   | Opus  | Reads codebase, writes plan to `.claude/workflow/plans/YYYY-MM-DD-<slug>.md` |
| Dev   | `/wf-dev`            | `developer` | Haiku | Reads plan, executes ONE step, marks done |
| Review| `/wf-review`         | `reviewer`  | Opus  | Reads `git diff`, audits against plan |

The 80/20: Opus thinks during plan + review (small token spend, high value). Haiku grinds out implementation (large token spend, cheap).

## Daily rhythm

```
☀️  /wf-morning     → load yesterday's leftovers
🧠  /wf-plan <task> → write a plan (if starting something new)
⚙️   /wf-dev × N    → execute steps one at a time
🔍  /wf-review      → audit before commit
🤝  /wf-handoff     → afternoon briefing for human reviewer
🌙  /wf-evening     → daily summary + tomorrow's first step
```

## Anytime tools

- `/wf-status` — show all plans and progress
- `/wf-interrupt <change>` — modify the active plan without losing progress

## How plans work

- Plans are plain markdown files in `.claude/workflow/plans/`. You can edit them by hand at any time.
- Frontmatter `status: in_progress | done` controls which plan is active.
- The `developer` agent finds the first `- [ ]` step and runs only that.
- Mark `- [?]` if a step is blocked. `HUMAN:` notes surface in `/wf-handoff`.

## Token-saving rules

1. **Don't ask Opus to implement.** Use `/wf-dev` (Haiku) — 15× cheaper.
2. **Don't paste files into review.** `/wf-review` reads the diff itself.
3. **One step per `/wf-dev`.** Keeps each invocation small and recoverable.
4. **Plans on disk, not in context.** Resume tomorrow with a fresh window.
5. **Diff-based review.** Reviewer never reads whole files unless a finding demands it.

## When NOT to use this workflow

- Trivial fix (≤1 file, ≤20 lines): just ask directly. Overhead > benefit.
- Pure exploration / Q&A: ask directly.
- Anything where you'd skip the plan if a human asked you to plan it.

## Tips

- The plan is a contract. The dev agent will not exceed its scope. If you want more, edit the plan first via `/wf-interrupt`.
- Plans are checked into git (or not — your call). They're a great trail of design decisions.
- Hooks auto-load active plan context on session start — no need to remind Claude what you were doing.
