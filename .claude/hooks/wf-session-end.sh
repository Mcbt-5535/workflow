#!/usr/bin/env bash
# SessionEnd hook: safety-net auto-checkpoint when the user exits without /wf-evening or /checkpoint.
# Only fires if there's active work AND no recent checkpoint/summary exists for today.

set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"

TODAY=$(date +%Y-%m-%d)
NOW=$(date '+%Y-%m-%d %H:%M')
HHMM=$(date '+%H%M')

mkdir -p summaries

# Skip if today's formal summary already exists
if [ -f ".claude/workflow/summaries/${TODAY}.md" ]; then
  exit 0
fi

# Skip if a manual checkpoint was just written (< 30 min ago)
if compgen -G ".claude/workflow/summaries/${TODAY}-checkpoint-*.md" > /dev/null 2>&1; then
  RECENT=$(find summaries -name "${TODAY}-checkpoint-*.md" -mmin -30 2>/dev/null | head -1)
  [ -n "$RECENT" ] && exit 0
fi

# Find active plan (date-prefixed only, status: in_progress)
ACTIVE_PLAN=""
for f in $(ls -r .claude/workflow/plans/*.md 2>/dev/null); do
  base=$(basename "$f")
  case "$base" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md)
      if grep -q "^status: in_progress" "$f" 2>/dev/null; then
        ACTIVE_PLAN="$f"
        break
      fi
      ;;
  esac
done

# Capture git state regardless of plan presence — uncommitted work matters
GIT_STATUS=""
GIT_DIFFSTAT=""
if [ -d .git ]; then
  GIT_STATUS=$(git status --short 2>/dev/null | head -20 || true)
  GIT_DIFFSTAT=$(git diff --stat 2>/dev/null | tail -5 || true)
fi

# Decide whether there's anything worth saving
HAS_WORK=0
[ -n "$ACTIVE_PLAN" ] && HAS_WORK=1
[ -n "$GIT_STATUS" ] && HAS_WORK=1

if [ "$HAS_WORK" = "0" ]; then
  exit 0
fi

CHECKPOINT_FILE=".claude/workflow/summaries/${TODAY}-checkpoint-${HHMM}.md"

{
  echo "---"
  echo "type: checkpoint"
  echo "datetime: ${NOW}"
  echo "source: auto (SessionEnd)"
  echo "---"
  echo ""
  echo "# Auto-checkpoint — ${NOW}"
  echo ""
  echo "Session ended without /wf-evening or /checkpoint. State snapshot below."
  echo ""

  if [ -n "$ACTIVE_PLAN" ]; then
    TOTAL=$(grep "^- \[" "$ACTIVE_PLAN" 2>/dev/null | wc -l | tr -d ' ')
    DONE=$(grep "^- \[x\]" "$ACTIVE_PLAN" 2>/dev/null | wc -l | tr -d ' ')
    BLOCKED=$(grep "^- \[?\]" "$ACTIVE_PLAN" 2>/dev/null | wc -l | tr -d ' ')
    NEXT=$(grep -m1 "^- \[ \]" "$ACTIVE_PLAN" 2>/dev/null | sed 's/^- \[ \] //' | cut -c1-200 || echo "")

    echo "## Active plan"
    echo "- **File:** \`${ACTIVE_PLAN}\`"
    echo "- **Progress:** ${DONE}/${TOTAL} done, ${BLOCKED} blocked"
    [ -n "$NEXT" ] && echo "- **Next step:** ${NEXT}"
    echo ""
  fi

  echo "## Uncommitted work"
  echo ""
  echo '```'
  if [ -n "$GIT_STATUS" ]; then
    echo "$GIT_STATUS"
    [ -n "$GIT_DIFFSTAT" ] && { echo ""; echo "$GIT_DIFFSTAT"; }
  else
    echo "(no uncommitted changes or no git repo)"
  fi
  echo '```'
  echo ""

  echo "## Resume next session"
  echo '```'
  echo "claude     # in this directory"
  echo "/wf-morning   # loads this checkpoint"
  echo "/wf-dev       # continue execution"
  echo '```'
} > "$CHECKPOINT_FILE"

# Stdout shows in transcript so the user sees the path before the session ends
echo "💾 Auto-checkpoint saved: ${CHECKPOINT_FILE}"

exit 0
