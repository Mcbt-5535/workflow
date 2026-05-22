#!/usr/bin/env bash
# Stop hook: gentle reminder to run /wf-evening if it's late and no summary exists yet.
# Never blocks. Stdout shows in transcript only.

set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"

HOUR=$(date +%H | sed 's/^0//')
TODAY=$(date +%Y-%m-%d)

# Only nudge between 17:00 and 23:59 local time
if [ "${HOUR:-0}" -ge 17 ] && [ "${HOUR:-0}" -le 23 ]; then
  if [ ! -f ".claude/workflow/summaries/${TODAY}.md" ]; then
    # Check if there was real work today (any plan touched, or git activity)
    HAS_WORK=0
    if compgen -G ".claude/workflow/plans/*.md" > /dev/null 2>&1; then
      # Any plan modified today?
      if find plans -name "*.md" -newermt "$TODAY 00:00:00" 2>/dev/null | grep -q .; then
        HAS_WORK=1
      fi
    fi
    if [ -d .git ] && git log --since=midnight --oneline 2>/dev/null | grep -q .; then
      HAS_WORK=1
    fi
    if [ "$HAS_WORK" = "1" ]; then
      echo "💡 It's after 5pm and today's summary (summaries/${TODAY}.md) isn't written yet."
      echo "   Run /wf-evening to log progress and plan tomorrow's first step."
    fi
  fi
fi

exit 0
