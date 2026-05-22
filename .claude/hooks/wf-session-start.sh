#!/usr/bin/env bash
# SessionStart hook: load active plan + yesterday's summary into Claude's context.
# Token-cheap: ~30 lines max, no full file dumps.

set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"

TODAY=$(date +%Y-%m-%d)
# Portable "yesterday": GNU first, then BSD fallback
YESTERDAY=$(date -d "yesterday" +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d 2>/dev/null || echo "")

# --- Find active plan ---
# Scan only date-prefixed files (skip README.md and other docs)
ACTIVE_PLAN=""
for f in $(ls -r .claude/workflow/plans/*.md 2>/dev/null); do
  base=$(basename "$f")
  # Only consider files matching YYYY-MM-DD-*.md
  case "$base" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md)
      if grep -q "^status: in_progress" "$f" 2>/dev/null; then
        ACTIVE_PLAN="$f"
        break
      fi
      ;;
  esac
done

count_lines() {
  # robust: returns 0 if file missing or no matches, never empty
  grep -c "$1" "$2" 2>/dev/null || true
}

OUT=""

if [ -n "$ACTIVE_PLAN" ]; then
  TOTAL=$(grep "^- \[" "$ACTIVE_PLAN" 2>/dev/null | wc -l | tr -d ' ')
  DONE=$(grep "^- \[x\]" "$ACTIVE_PLAN" 2>/dev/null | wc -l | tr -d ' ')
  BLOCKED=$(grep "^- \[?\]" "$ACTIVE_PLAN" 2>/dev/null | wc -l | tr -d ' ')
  NEXT=$(grep -m1 "^- \[ \]" "$ACTIVE_PLAN" 2>/dev/null | sed 's/^- \[ \] //' | cut -c1-120 || echo "")
  OUT="ACTIVE PLAN: ${ACTIVE_PLAN} (${DONE}/${TOTAL} done"
  [ "${BLOCKED:-0}" -gt 0 ] 2>/dev/null && OUT="${OUT}, ${BLOCKED} blocked"
  OUT="${OUT})."
  [ -n "$NEXT" ] && OUT="${OUT} Next: ${NEXT}."
  OUT="${OUT} Use /wf-dev to continue, /wf-status for progress."
elif [ -n "$YESTERDAY" ] && [ -f ".claude/workflow/summaries/${YESTERDAY}.md" ]; then
  OUT="No active plan. Yesterday's summary at .claude/workflow/summaries/${YESTERDAY}.md. Run /wf-morning to load context."
else
  OUT="No active plan. Start a new task with /wf-plan <task description>."
fi

# Output as additionalContext via SessionStart JSON contract.
# Escape backslashes and double-quotes for safe JSON; flatten newlines.
ESCAPED=$(printf '%s' "$OUT" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr '\n' ' ')

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "${ESCAPED}"
  }
}
EOF
