---
description: Pause the active plan and inject a new step / blocker / pivot — without losing progress.
argument-hint: <what to inject, e.g. "add step: write integration test before step 4">
---

Interrupt the active plan with the following change:

$ARGUMENTS

Steps:
1. Find the active plan (most recent `.claude/workflow/plans/*.md` with `status: in_progress`).
2. Re-read it fully (it's small — usually <150 lines).
3. Apply the requested change. Common cases:
   - **Add a step:** insert a new `- [ ]` bullet at the right position. Update step numbering only in titles, not in checkbox state.
   - **Remove a step:** delete the bullet. If already done, leave it but mark `(reverted)`.
   - **Reorder:** move bullets, preserving their `[x] / [ ] / [?]` state.
   - **Pivot goal:** rewrite the Goal section, then list which existing steps still apply under `## Plan` and add new ones below.
4. Add a single line under `## Notes` (create section if missing):
   `- <today>: interrupted — <one-line summary>`
5. Save. Report back: which steps were added/removed/reordered.

Hard rules:
- Do not execute any plan steps. This is an edit-only command.
- Do not change `[x]` to `[ ]` unless the user explicitly says "revert step N".
- Preserve all existing `HUMAN:` notes.
