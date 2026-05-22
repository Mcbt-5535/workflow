#!/usr/bin/env bash
# PostToolUse hook: after any Edit/Write to .claude/workflow/plans/*.md, refresh STATUS.md and append to progress log.
# Fires every time a plan checkbox changes — captures step-by-step progress automatically.

set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"

INPUT=$(cat)

# Fast prefilter on tool name (avoid expensive parsing if irrelevant)
case "$INPUT" in
  *'"tool_name":"Edit"'*|*'"tool_name":"Write"'*|*'"tool_name":"MultiEdit"'*) ;;
  *) exit 0 ;;
esac

# Extract the file_path field (grep-only, no python dependency)
FILE_PATH=$(printf '%s' "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')

# Gate: only act when the changed file lives under .claude/workflow/plans/
case "$FILE_PATH" in
  */.claude/workflow/plans/*.md|plans/*.md) ;;
  *) exit 0 ;;
esac

NOW=$(date '+%Y-%m-%d %H:%M:%S')
LOG=".claude/workflow/plans/.progress.log"
DASH=".claude/workflow/plans/STATUS.md"

# Helper: stats for one plan file
plan_stats() {
  local f="$1"
  local total done_ blocked
  total=$(grep -c "^- \[" "$f" 2>/dev/null || echo 0)
  done_=$(grep -c "^- \[x\]" "$f" 2>/dev/null || echo 0)
  blocked=$(grep -c "^- \[?\]" "$f" 2>/dev/null || echo 0)
  # collapse possible multiline grep -c quirks
  total=${total%%$'\n'*}; done_=${done_%%$'\n'*}; blocked=${blocked%%$'\n'*}
  echo "$done_ $total $blocked"
}

# Find the active plan
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

# --- Update progress log (dedup consecutive identical states) ---
if [ -n "$ACTIVE_PLAN" ]; then
  read -r DONE TOTAL BLOCKED <<<"$(plan_stats "$ACTIVE_PLAN")"
  STATE="${ACTIVE_PLAN} | ${DONE}/${TOTAL} done | ${BLOCKED} blocked | edited:${FILE_PATH}"
  LAST=$(tail -1 "$LOG" 2>/dev/null | sed 's/^[0-9-]* [0-9:]* | //' || echo "")
  if [ "$LAST" != "$STATE" ]; then
    echo "${NOW} | ${STATE}" >> "$LOG"
  fi
fi

# --- Rebuild STATUS.md dashboard ---
{
  echo "# Plan status (auto-updated)"
  echo ""
  echo "_Last update: ${NOW}_"
  echo ""

  if [ -n "$ACTIVE_PLAN" ]; then
    read -r DONE TOTAL BLOCKED <<<"$(plan_stats "$ACTIVE_PLAN")"
    NEXT=$(grep -m1 "^- \[ \]" "$ACTIVE_PLAN" 2>/dev/null | sed 's/^- \[ \] //' | cut -c1-120 || echo "")
    echo "## Active"
    echo ""
    echo "**File:** \`${ACTIVE_PLAN}\`"
    echo "**Progress:** ${DONE}/${TOTAL} done, ${BLOCKED} blocked"
    [ -n "$NEXT" ] && echo "**Next step:** ${NEXT}"
    echo ""
  else
    echo "## Active"
    echo ""
    echo "_No plan with \`status: in_progress\`._"
    echo ""
  fi

  echo "## All plans"
  echo ""
  echo "| Plan | Status | Done | Blocked |"
  echo "|---|---|---|---|"
  for f in $(ls .claude/workflow/plans/*.md 2>/dev/null | sort -r); do
    base=$(basename "$f")
    case "$base" in
      [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md)
        STATUS_VAL=$(grep -m1 "^status:" "$f" 2>/dev/null | sed 's/^status:[[:space:]]*//')
        [ -z "$STATUS_VAL" ] && STATUS_VAL="unknown"
        read -r D T B <<<"$(plan_stats "$f")"
        echo "| ${base} | ${STATUS_VAL} | ${D}/${T} | ${B} |"
        ;;
    esac
  done

  echo ""
  echo "## Recent activity (last 10)"
  echo ""
  echo '```'
  tail -10 "$LOG" 2>/dev/null || echo "(no activity logged yet)"
  echo '```'
} > "$DASH"

exit 0
