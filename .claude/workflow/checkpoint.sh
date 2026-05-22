#!/usr/bin/env bash
# Pure-bash checkpoint — does NOT call any model.
#
# Use this when:
#   - You hit the 5-hour usage limit (slash /wf-checkpoint won't work)
#   - Claude Code is unresponsive or crashed
#   - Network is down
#   - You just want a snapshot without spending any tokens
#
# Usage:
#   bash checkpoint.sh
#   bash checkpoint.sh "ran out of tokens, picking up tomorrow"
#   ./checkpoint.sh "going to a meeting"

set -euo pipefail
# Resolve project root (this script lives at <root>/.claude/workflow/checkpoint.sh)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/../.."

REASON="${1:-terminal checkpoint}"
TODAY=$(date +%Y-%m-%d)
NOW=$(date '+%Y-%m-%d %H:%M')
HHMM=$(date '+%H%M%S')   # add seconds so two calls in same minute don't collide

mkdir -p .claude/workflow/summaries

# --- Find active plan ---
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

# --- Git state ---
GIT_STATUS=""
GIT_DIFFSTAT=""
GIT_RECENT_COMMITS=""
if [ -d .git ]; then
  GIT_STATUS=$(git status --short 2>/dev/null | head -30 || true)
  GIT_DIFFSTAT=$(git diff --stat 2>/dev/null | tail -8 || true)
  GIT_RECENT_COMMITS=$(git log --since=midnight --oneline 2>/dev/null | head -10 || true)
fi

# --- Recent progress log (from PostToolUse hook) ---
RECENT_PROGRESS=""
if [ -f .claude/workflow/plans/.progress.log ]; then
  RECENT_PROGRESS=$(tail -5 .claude/workflow/plans/.progress.log 2>/dev/null || true)
fi

CHECKPOINT_FILE=".claude/workflow/summaries/${TODAY}-checkpoint-${HHMM}.md"

{
  echo "---"
  echo "type: checkpoint"
  echo "datetime: ${NOW}"
  echo "source: manual (terminal, no model)"
  echo "---"
  echo ""
  echo "# Checkpoint — ${NOW}"
  echo ""
  echo "> Reason: ${REASON}"
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
  else
    echo "## Active plan"
    echo ""
    echo "_None_"
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

  if [ -n "$GIT_RECENT_COMMITS" ]; then
    echo "## Today's commits"
    echo ""
    echo '```'
    echo "$GIT_RECENT_COMMITS"
    echo '```'
    echo ""
  fi

  if [ -n "$RECENT_PROGRESS" ]; then
    echo "## Recent step transitions (from PostToolUse hook)"
    echo ""
    echo '```'
    echo "$RECENT_PROGRESS"
    echo '```'
    echo ""
  fi

  echo "## ⚠️  Possible mid-step state"
  echo ""
  echo "If you hit the usage limit mid-/dev, the last step may be PARTIALLY DONE in the code"
  echo "even though its checkbox is still \`- [ ]\`. Before resuming:"
  echo ""
  echo "1. Read this checkpoint."
  echo "2. \`git diff\` to see exactly what was touched."
  echo "3. Decide: continue from where it stopped, or \`git checkout --\` to revert and re-run."
  echo ""

  echo "## Resume next session"
  echo ""
  echo '```bash'
  echo "cd $(pwd)"
  echo "claude"
  echo "# SessionStart hook auto-loads active plan"
  echo "/wf-morning   # reads this checkpoint as the most-recent summary"
  echo "/wf-dev       # continue execution (or /wf-interrupt if you reverted)"
  echo '```'
} > "$CHECKPOINT_FILE"

# --- Stdout report ---
echo "✅ Checkpoint saved (no model used): ${CHECKPOINT_FILE}"
echo ""
if [ -n "$ACTIVE_PLAN" ]; then
  echo "    Active plan:  ${ACTIVE_PLAN} (${DONE}/${TOTAL} done${BLOCKED:+, ${BLOCKED} blocked})"
  [ -n "$NEXT" ] && echo "    Next step:    ${NEXT}"
fi
if [ -n "$GIT_STATUS" ]; then
  N_CHANGED=$(echo "$GIT_STATUS" | wc -l | tr -d ' ')
  echo "    Uncommitted:  ${N_CHANGED} files"
fi
echo ""
echo "Safe to close Claude Code and shut down."
echo "Tomorrow:  cd $(pwd) && claude && /wf-morning"
