---
description: Contribute changes back to the workflow submodule upstream repository
---

Contribute changes to the workflow codebase and open a pull request upstream.

The workflow is installed as a Git submodule in `.workflow/`. This command lets you:
1. Create a contribution branch inside the submodule
2. Edit workflow internals (agents, commands, hooks, skills) in place
3. Commit your changes
4. Push the branch and open a PR back to the upstream repository

**Usage:**
- `/wf-contribute "short description"` — create a new branch and prepare for editing
- `/wf-contribute --push` — push your branch and open a PR (or print the GitHub URL if `gh` is not installed)

**Example:**
- `/wf-contribute "improve planner prompt"`
- [Make edits inside `.workflow/.claude/...`]
- Commit your changes inside `.workflow/`
- `/wf-contribute --push`

The script handles:
- Branch naming from your description
- Ensuring the submodule is clean before branching
- Pushing to upstream with proper tracking
- Opening a PR via GitHub CLI (if available) or printing a compare URL
- Guiding you through the full flow

For details, see `.claude/workflow/WORKFLOW.md` and the README section "Contributing back upstream".

Run: `bash .claude/workflow/contribute.sh "$ARGUMENTS"` and report its output to the user.
