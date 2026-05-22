---
description: Review uncommitted changes against the active plan using the reviewer subagent (Opus).
---

Use the `wf-reviewer` subagent to review the current `git diff` against the active plan.

The reviewer is read-only — it will not modify any files.

After it returns, relay the review verbatim. If there are 🛑 blocking issues, suggest which `/wf-dev` steps to re-run.
