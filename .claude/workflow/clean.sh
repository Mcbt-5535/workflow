#!/usr/bin/env bash
# clean.sh — Audit and clean outdated workflow runtime artifacts.
#
# Usage:
#   bash .claude/workflow/clean.sh [--dry-run] [--keep N] [--yes]
#
# Flags:
#   --dry-run   Report what would be removed (default when --yes is absent).
#   --yes       Execute cleanup without prompting.
#   --keep N    Checkpoint files to keep per past day (default: 1).

set -euo pipefail

# ---- Resolve project root ----
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# When installed via symlink the script lives in .claude/workflow/; parent of that is .claude/; parent is project root.
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WF_DIR="$PROJECT_ROOT/.claude/workflow"
PLANS_DIR="$WF_DIR/plans"
SUMMARIES_DIR="$WF_DIR/summaries"
ARCHIVE_DIR="$WF_DIR/archive"

# ---- Parse flags ----
DRY_RUN=1
KEEP=1
for arg in "$@"; do
  case "$arg" in
    --yes)     DRY_RUN=0 ;;
    --dry-run) DRY_RUN=1 ;;
    --keep)    ;;  # handled below
    --keep=*)  KEEP="${arg#--keep=}" ;;
    [0-9]*)    KEEP="$arg" ;;  # positional number after --keep
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

# Re-parse to handle `--keep N` (two separate tokens)
args=("$@")
for i in "${!args[@]}"; do
  if [ "${args[$i]}" = "--keep" ] && [ $((i+1)) -lt ${#args[@]} ]; then
    KEEP="${args[$((i+1))]}"
  fi
done

TODAY="$(date +%Y-%m-%d)"

# ---- Helper: check if all checkboxes are done ----
_all_done() {
  local file="$1"
  local unchecked
  unchecked=$(grep -c '^\- \[ \]' "$file" 2>/dev/null || true)
  [ "$unchecked" -eq 0 ]
}

# ---- Helper: read frontmatter status ----
_plan_status() {
  local file="$1"
  grep -m1 '^status:' "$file" 2>/dev/null | sed 's/status:[[:space:]]*//' | tr -d '[:space:]'
}

# ---- Collect plans to archive ----
plans_to_archive=()
shopt -s nullglob
for f in "$PLANS_DIR"/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md; do
  base="$(basename "$f")"
  [ "$base" = "README.md" ] && continue
  [ "$base" = "STATUS.md" ] && continue
  status="$(_plan_status "$f")"
  if [ "$status" = "done" ] || { [ "$status" != "in_progress" ] && [ "$status" != "blocked" ] && _all_done "$f"; }; then
    plans_to_archive+=("$f")
  elif [ "$status" = "in_progress" ] && _all_done "$f"; then
    plans_to_archive+=("$f")
  fi
done
shopt -u nullglob

# ---- Collect summaries to remove ----
summaries_to_remove=()
shopt -s nullglob
declare -A day_checkpoints  # day → sorted list of checkpoint files
for f in "$SUMMARIES_DIR"/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-checkpoint-[0-9]*.md; do
  base="$(basename "$f")"
  day="${base%%-checkpoint-*}"
  if [ -z "${day_checkpoints[$day]+_}" ]; then
    day_checkpoints[$day]="$f"
  else
    day_checkpoints[$day]="${day_checkpoints[$day]} $f"
  fi
done
shopt -u nullglob

for day in "${!day_checkpoints[@]}"; do
  IFS=' ' read -ra files <<< "${day_checkpoints[$day]}"
  # Sort by filename (HHMM is lexicographic)
  IFS=$'\n' sorted=($(printf '%s\n' "${files[@]}" | sort)); unset IFS
  total=${#sorted[@]}
  if [ "$day" = "$TODAY" ]; then
    keep_n=3
  else
    keep_n=$KEEP
  fi
  # Mark all but the last keep_n for removal
  if [ $total -gt $keep_n ]; then
    remove_count=$((total - keep_n))
    for ((i=0; i<remove_count; i++)); do
      summaries_to_remove+=("${sorted[$i]}")
    done
  fi
done

# ---- Progress log ----
PROGRESS_LOG="$PLANS_DIR/.progress.log"
log_lines=0
log_trim=0
if [ -f "$PROGRESS_LOG" ]; then
  log_lines=$(wc -l < "$PROGRESS_LOG")
  if [ "$log_lines" -gt 200 ]; then
    log_trim=1
  fi
fi

# ---- STATUS.md ----
STATUS_FILE="$PLANS_DIR/STATUS.md"
status_delete=0
[ ${#plans_to_archive[@]} -gt 0 ] && [ -f "$STATUS_FILE" ] && status_delete=1

# ---- Report ----
echo "## Workflow cleanup report"
echo ""

echo "### Plans to archive (${#plans_to_archive[@]})"
if [ ${#plans_to_archive[@]} -gt 0 ]; then
  echo "| File | Status | Checkboxes |"
  echo "|---|---|---|"
  for f in "${plans_to_archive[@]}"; do
    base="$(basename "$f")"
    st="$(_plan_status "$f")"
    done_count=$(grep -c '^\- \[x\]' "$f" 2>/dev/null || true)
    total_count=$(grep -c '^\- \[' "$f" 2>/dev/null || true)
    echo "| $base | ${st:-unknown} | $done_count/$total_count |"
  done
else
  echo "_None — all plans are active or already archived._"
fi

echo ""
echo "### Checkpoint summaries to remove (${#summaries_to_remove[@]})"
if [ ${#summaries_to_remove[@]} -gt 0 ]; then
  echo "| File | Reason |"
  echo "|---|---|"
  for f in "${summaries_to_remove[@]}"; do
    base="$(basename "$f")"
    day="${base%%-checkpoint-*}"
    if [ "$day" = "$TODAY" ]; then
      echo "| $base | today — not among last 3 |"
    else
      echo "| $base | past day — not the latest $KEEP |"
    fi
  done
else
  echo "_None — summaries are already lean._"
fi

echo ""
echo "### Progress log"
if [ -f "$PROGRESS_LOG" ]; then
  if [ $log_trim -eq 1 ]; then
    echo "- Current: $log_lines lines → trim to last 100 entries"
  else
    echo "- Current: $log_lines lines — within limit, no trim needed"
  fi
else
  echo "- Not found — nothing to do"
fi

echo ""
total_plans=${#plans_to_archive[@]}
total_summaries=${#summaries_to_remove[@]}
echo "**Totals:** $total_plans plan(s) to archive, $total_summaries summary file(s) to remove, log trim: $([ $log_trim -eq 1 ] && echo yes || echo no)"
echo ""

# ---- Dry run: stop here ----
if [ $DRY_RUN -eq 1 ]; then
  echo "_Dry run — no files changed._"
  exit 0
fi

# ---- Execute ----
echo "## Executing…"
echo ""

mkdir -p "$ARCHIVE_DIR"

archived=0
for f in "${plans_to_archive[@]}"; do
  base="$(basename "$f")"
  dest="$ARCHIVE_DIR/$base"
  # Update status in frontmatter if needed
  if ! grep -q '^status: done' "$f"; then
    # Replace in_progress/unknown with done
    sed -i 's/^status: .*/status: done/' "$f"
  fi
  mv "$f" "$dest"
  echo "  ✓ archived: $base"
  ((archived++)) || true
done

removed=0
for f in "${summaries_to_remove[@]}"; do
  base="$(basename "$f")"
  rm "$f"
  echo "  ✓ removed: $base"
  ((removed++)) || true
done

if [ $log_trim -eq 1 ] && [ -f "$PROGRESS_LOG" ]; then
  tail -n 100 "$PROGRESS_LOG" > "$PROGRESS_LOG.tmp" && mv "$PROGRESS_LOG.tmp" "$PROGRESS_LOG"
  echo "  ✓ progress log trimmed to 100 lines"
fi

if [ $status_delete -eq 1 ] && [ -f "$STATUS_FILE" ]; then
  rm "$STATUS_FILE"
  echo "  ✓ STATUS.md removed (regenerates on next plan edit)"
fi

echo ""
echo "Done: $archived plan(s) archived, $removed summary file(s) removed."
