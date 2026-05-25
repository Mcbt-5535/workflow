# Project: workflow system

This project uses a 3-agent Plan → Dev → Review workflow to balance quality with token cost.

## Roles

- **Planner (Opus)** — invoked via `/wf-plan <task>`. Writes a step-by-step plan to `.claude/workflow/plans/YYYY-MM-DD-<slug>.md`.
- **Developer (Haiku)** — invoked via `/wf-dev`. Reads the active plan, executes one unchecked step, marks it done.
- **Reviewer (Opus)** — invoked via `/wf-review`. Reads `git diff`, audits against the plan.

Heavy thinking happens twice (plan + review). Bulk implementation runs on the cheap model.

## What goes where

- `.claude/workflow/plans/` — active and recently-completed plans. Markdown with frontmatter (`status: in_progress | done`).
- `.claude/workflow/summaries/` — one file per day. Written by `/wf-evening`, read by `/wf-morning`.
- `.claude/workflow/archive/` — plans whose checklist is 100% done. Moved here by `/wf-evening`.
- `.claude/agents/` — the three subagent definitions.
- `.claude/commands/` — slash commands that orchestrate.
- `.claude/hooks/` — session-start + stop hooks (load context, evening nudge).

## Default behavior for routine work

When the user describes a new feature, bug, or refactor:
1. Suggest `/wf-plan <task>` first if it's non-trivial (≥3 files or ≥3 logical steps).
2. After a plan exists, use `/wf-dev` repeatedly — do NOT implement directly in the main conversation.
3. Use `/wf-review` before declaring work done.

When the user asks a question, gives a one-line fix, or explores: respond directly. The workflow is for substantial work, not chatter.

## Editing plans by hand is encouraged

The user may open `.claude/workflow/plans/*.md` and edit it directly — add steps, reorder, mark `[?]`. The developer agent will pick up changes on the next `/wf-dev`. The plan is a contract that the user always controls.

## Contributing improvements back to the workflow

When the workflow is installed as a Git submodule, all internal files are editable in place — thanks to symlinks, changes to `.workflow/.claude/agents/wf-planner.md` affect your project immediately without copy-paste or restart. You can branch the submodule, make changes (agents, commands, hooks, skills), commit them, and submit a PR back upstream — all from your project — using `/wf-contribute`. See the README section "Contributing back upstream" for the full flow.

This is the intended way to customize the workflow for your team: edit the agents/commands live in your project, test them in your active plan, commit to a branch, and PR them back. Once approved, the entire team gets the benefit via `git submodule update --remote`.

## Daily rhythm

- Start: `/wf-morning` (loads yesterday's summary + active plan)
- Work: `/wf-plan` → `/wf-dev` × N → `/wf-review`
- Mid-afternoon: `/wf-handoff` (briefing for human reviewer + debug session)
- End: `/wf-evening` (summary + tomorrow's first step)

## Hooks

- `SessionStart` injects active plan status into context so you don't have to re-explain.
- `PostToolUse` (matcher `Edit|Write|MultiEdit`) fires after any plan edit and refreshes:
  - `.claude/workflow/plans/STATUS.md` — auto-generated dashboard (active plan, progress, all-plans table, last 10 activity entries).
  - `.claude/workflow/plans/.progress.log` — append-only audit log; one line per state change.
  - This gives you a real-time view of step completion without paying tokens to ask the model.
- `Stop` reminds you to run `/wf-evening` after 5pm if no summary exists yet for today.
- `SessionEnd` writes a safety-net auto-checkpoint to `.claude/workflow/summaries/YYYY-MM-DD-checkpoint-HHMM.md` if there's active work and no summary/wf-checkpoint exists yet for today. Captures: active plan + next step + `git status --short`.

`.claude/workflow/plans/STATUS.md` is **auto-generated** — never hand-edit it; your changes will be overwritten on the next plan edit. To inspect status without re-running anything: `cat .claude/workflow/plans/STATUS.md`.

## Emergency interruption flow

When the user must shut down RIGHT NOW (meeting, power cut, change of plans):

- `/wf-checkpoint <optional reason>` — manual slash, <60-second save to `.claude/workflow/summaries/<date>-checkpoint-<HHMM>.md`. Uses the model; richest detail (includes mental notes from this conversation).
- If the user forgets to run `/wf-checkpoint` and just closes Claude Code, the `SessionEnd` hook writes the same kind of file automatically (less detail; bash only).
- **Usage-limit fallback:** `bash checkpoint.sh "<reason>"` — pure bash, **uses zero tokens**. Use this when the 5-hour limit has been hit and the slash command itself would fail. Captures active plan + git status + recent progress log; same output format.
- Next session: `claude` re-opens here, `SessionStart` hook loads the active plan, and `/wf-morning` reads whichever summary/wf-checkpoint is most recent — picks up where you left off without you re-explaining.

## Usage-limit (5-hour window) survival

If the user hits the rolling 5-hour limit:

- All hooks keep working (they're local bash, not API calls). `.claude/workflow/plans/STATUS.md` and `.claude/workflow/plans/.progress.log` continue to reflect the latest step state.
- All slash commands (including `/wf-checkpoint`, `/wf-morning`, `/wf-evening`, `/wf-dev`, `/wf-review`, `/wf-plan`) fail because they need the model.
- The user should run **`bash checkpoint.sh "<reason>"`** from a terminal — pure bash, no tokens. State is preserved.
- On resume, the user runs `claude` again; the SessionStart hook surfaces the active plan path + progress automatically.
- If the limit hit mid-`/wf-dev`, the step may be partial: code changed but checkbox still `[ ]`. The checkpoint file's "⚠️ Possible mid-step state" section explains how to decide between continuing vs. `git checkout --`.

## Hard rules for the main agent

- **Never implement without a plan** for non-trivial work. Plans are cheap; rework is expensive.
- **Never modify a plan's structure** — only checkboxes and the Notes/Risks sections.
- **Always prefer subagents** for their respective stages. Token cost matters.
- **`status: done` plans are read-only.** They live in `.claude/workflow/archive/`.
