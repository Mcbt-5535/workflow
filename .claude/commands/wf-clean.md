---
description: Audit and clean outdated workflow artifacts — archive done plans, prune old summaries, trim progress log.
argument-hint: [--dry-run] [--keep N] [--yes]
---

Workflow cleanup. Audits the current project's runtime state and removes stale artifacts.

## Flags

- `--dry-run` — (default) report what *would* be removed without touching anything
- `--yes` — execute the cleanup without prompting
- `--keep N` — keep the N most-recent checkpoint files per past day (default: 1); today always keeps the last 3

## Steps

Run: `bash .claude/workflow/clean.sh $ARGUMENTS`

Report its output verbatim, then add a one-line summary at the end:
- On dry-run: `→ Run /wf-clean --yes to execute.`
- On execution: `✅ Cleanup complete.`
- On error: quote the error and suggest the user inspect `.claude/workflow/` manually.

## What gets cleaned

1. **Done plans** — Plans in `.claude/workflow/plans/` whose frontmatter `status` is `done`, or whose every checkbox is `[x]`. Moved to `.claude/workflow/archive/`.

2. **Old checkpoint summaries** — Files matching `.claude/workflow/summaries/YYYY-MM-DD-checkpoint-HHMM.md`. For each past day, keeps only the N most-recent (default 1). For today, keeps the last 3. Daily summary files (`YYYY-MM-DD.md`) are never deleted.

3. **Progress log** — `.claude/workflow/plans/.progress.log`. If it exceeds 200 lines, trimmed to the last 100 entries.

4. **Stale STATUS.md** — `.claude/workflow/plans/STATUS.md` is deleted after plans are archived; it regenerates automatically on the next plan edit.

## What is never touched

- `README.md` files in any subdirectory
- Plans with `status: in_progress` or `status: blocked`
- The latest checkpoint per day (and today's last 3)
- Daily summary files
- Any file not under `.claude/workflow/`
