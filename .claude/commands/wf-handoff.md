---
description: Afternoon human-handoff briefing — what changed today, what needs human eyes, what to debug together.
---

Build a compact handoff briefing for a human reviewer with ~5 minutes to scan:

1. Active plan: path, status, progress (N/M).
2. Files touched since yesterday's commit: `git diff --stat <yesterday's last commit>..HEAD` plus uncommitted (`git status --short`).
3. From active plans, extract every line containing `HUMAN:` or starting with `- [?]` — these are the human-attention items.
4. From the most recent `/wf-review` output (if any in conversation), surface unresolved 🛑 / ⚠️ issues.
5. Pose up to 3 specific yes/no questions the human should answer to unblock tomorrow.

Output format:

```
🤝 Handoff — <date> <time>

Plan: <path> (N/M done)

Changed files (today):
- path/a.ts (+12 -3)
- path/b.py (new)

Needs human decision:
1. <question> — context: <one line>
2. <question> — context: <one line>

Suggested debug session:
- <area> — try `<command>` and watch for <signal>
```

Keep total under 25 lines. No code blocks except commands.
