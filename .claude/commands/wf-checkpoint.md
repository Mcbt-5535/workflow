---
description: Emergency checkpoint — save current state in under 1 minute so you can shut down and resume later.
argument-hint: <optional note, e.g. "going into a meeting" or "shutting down for the day">
---

Emergency checkpoint. Speed matters more than completeness. Target: <60 seconds wall-clock.

## Steps (do all of them, in order, fast)

1. Capture timestamp: run `date '+%Y-%m-%d %H:%M'` and `date '+%H%M'`. Store as `$NOW` and `$HHMM` mentally.
2. Active plan:
   - Find `.claude/workflow/plans/*.md` matching `YYYY-MM-DD-*.md` with `status: in_progress` (latest if multiple).
   - Read just its frontmatter + Plan section. Count `[x]`, `[ ]`, `[?]`.
   - Grab the title of the first `[ ]` step → that's the "next step".
   - If the most recent assistant action in *this* conversation was implementing step N (but [ ] wasn't flipped to [x]), note step N as "in flight, not marked done".
3. Uncommitted changes:
   - `git status --short` (one command, capture output).
   - `git diff --stat | tail -5` (if any output).
   - If not a git repo, skip silently.
4. Write `.claude/workflow/summaries/<YYYY-MM-DD>-checkpoint-<HHMM>.md` with this template:

```markdown
---
type: checkpoint
datetime: <NOW>
source: manual (/checkpoint)
---

# Checkpoint — <NOW>

> Reason: $ARGUMENTS

## Active plan
- **File:** `<plan path>`
- **Progress:** <DONE>/<TOTAL> done<, X blocked if any>
- **Next step:** <first [ ] title>
- **In flight (not yet marked):** <step title if relevant, else "none">

## Uncommitted work
```
<git status --short output, max 20 lines, or "no changes / no git repo">
```

## Mental notes
- <any blockers / surprises / decisions from this conversation worth remembering, max 5 bullets>

## Resume next session
```
claude          # in this directory
# SessionStart hook will auto-load the active plan
/wf-morning        # optional — reads this checkpoint as the most-recent summary
/wf-dev            # continue execution
```
```

5. Output to the user **only**: `✅ Checkpoint saved: <path>. Safe to exit.` Nothing else.

## Hard rules — read these every time

- **Do NOT run tests, lints, builds, or anything slow.** This is a snapshot, not a review.
- **Do NOT commit, stage, stash, or push.** The user might want to handle git themselves before shutting down. If you think they should, mention it in "Mental notes" — don't act.
- **Do NOT modify the plan.** Don't flip [ ] → [x], don't add steps.
- **Do NOT do code analysis.** No reasoning about correctness here.
- **If anything is ambiguous, write it as-is.** Don't pause to ask the user — they're on a clock.
- **If git is uninitialized, skip git steps silently** — don't suggest `git init`.

The whole command should produce one new file in `.claude/workflow/summaries/` and one line of output. That's it.
