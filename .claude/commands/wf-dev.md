---
description: Execute the next unchecked step in the active plan using the developer subagent (Haiku).
---

Use the `wf-developer` subagent to execute the next step in the active plan.

Rules:
- If multiple plans have `status: in_progress`, list them and ask which one to advance.
- If no plan is active, suggest `/wf-plan <task>` and stop.
- After the subagent returns, surface its 3-line report verbatim.

Do not micromanage the subagent. It is a focused worker that does one step per call.
