#!/usr/bin/env bash
# Uninstall the workflow from this project. Removes all wf-* prefixed files
# and the .claude/workflow/ directory. Does NOT touch your project's CLAUDE.md
# or other agents/commands/hooks/settings. Existing settings.json hook entries
# referencing wf-*.sh are reported but not auto-deleted (you decide).

set -euo pipefail

# Locate project root: this script lives at <root>/.claude/workflow/uninstall.sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$ROOT"
echo "Uninstalling workflow from $ROOT"
echo ""

confirm() {
  local prompt="$1"
  read -r -p "$prompt [y/N] " ans
  case "$ans" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

if ! confirm "This will remove .claude/workflow/ AND all wf-* prefixed files in .claude/. Continue?"; then
  echo "Aborted."
  exit 1
fi

# Save user's data if requested
if [ -d ".claude/workflow/plans" ] || [ -d ".claude/workflow/summaries" ] || [ -d ".claude/workflow/archive" ]; then
  if confirm "Save plans/summaries/archive to ./workflow-data-backup-$(date +%Y%m%d)/ before deleting?"; then
    BACKUP="workflow-data-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP"
    for d in plans summaries archive; do
      if [ -d ".claude/workflow/$d" ]; then
        cp -r ".claude/workflow/$d" "$BACKUP/"
        echo "  ✓ backed up $d/ → $BACKUP/$d/"
      fi
    done
  fi
fi

# Delete prefixed files in canonical .claude/ subdirs
for d in agents commands hooks; do
  if [ -d ".claude/$d" ]; then
    rm -f .claude/$d/wf-*.* 2>/dev/null || true
    echo "  ✓ removed .claude/$d/wf-* files"
  fi
done

# Delete skill folder
rm -rf .claude/skills/wf-workflow-intro 2>/dev/null || true
[ -d .claude/skills/wf-workflow-intro ] || echo "  ✓ removed .claude/skills/wf-workflow-intro/"

# Delete the workflow namespace (will delete this script too on the final step)
WORKFLOW_DIR=".claude/workflow"
if [ -d "$WORKFLOW_DIR" ]; then
  # Note: deleting the dir while running from it works on most filesystems
  rm -rf "$WORKFLOW_DIR"
  echo "  ✓ removed $WORKFLOW_DIR/"
fi

# Detect leftover hook refs in settings.json
SETTINGS=".claude/settings.json"
if [ -f "$SETTINGS" ] && grep -q "wf-.*\.sh" "$SETTINGS" 2>/dev/null; then
  echo ""
  echo "⚠ $SETTINGS still references wf-* hooks. Remove these blocks manually:"
  grep -n "wf-.*\.sh" "$SETTINGS" || true
  echo ""
  echo "  Or if jq is available:"
  echo "    jq 'del(.hooks.SessionStart, .hooks.PostToolUse, .hooks.Stop, .hooks.SessionEnd)' $SETTINGS > tmp && mv tmp $SETTINGS"
  echo "  (warning: this removes ALL hooks under those event names, not just wf-*)"
fi

echo ""
echo "✅ Uninstalled."
