#!/usr/bin/env bash
# Install the workflow into an existing project. Minimally invasive:
#   - All workflow data + docs + scripts go into <target>/.claude/workflow/
#   - 17 prefixed shim files land in <target>/.claude/{agents,commands,hooks,skills}/
#   - settings.json is MERGED (not overwritten) if it already exists
#   - Existing files are NEVER overwritten without --force
#
# Usage:
#   bash install.sh <target-dir>
#   bash install.sh <target-dir> --force      # overwrite existing wf-* files
#   bash install.sh --uninstall <target-dir>  # see uninstall instructions

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
FORCE=0
TARGET=""

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --uninstall)
      echo "To uninstall, run:"
      echo "  bash <target>/.claude/workflow/uninstall.sh"
      exit 0
      ;;
    -*) echo "Unknown flag: $arg" >&2; exit 1 ;;
    *)
      [ -n "$TARGET" ] && { echo "Multiple target dirs given" >&2; exit 1; }
      TARGET="$arg"
      ;;
  esac
done

if [ -z "$TARGET" ]; then
  echo "Usage: bash install.sh <target-dir> [--force]" >&2
  exit 1
fi

# Resolve to absolute path
TARGET="$(cd "$TARGET" 2>/dev/null && pwd || echo "$TARGET")"

if [ "$SOURCE_DIR" = "$TARGET" ]; then
  echo "Source and target are the same. Nothing to do." >&2
  exit 1
fi

if [ ! -d "$TARGET" ]; then
  echo "Target directory does not exist: $TARGET" >&2
  exit 1
fi

echo "Installing workflow → $TARGET"
echo ""

# ---- Copy prefixed shim files ----
copy_file() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ "$FORCE" != "1" ]; then
    echo "  ⚠ skip (exists): $dst    [use --force to overwrite]"
    return
  fi
  cp "$src" "$dst"
  echo "  ✓ $dst"
}

copy_tree() {
  local src="$1" dst="$2"
  if [ -e "$dst" ] && [ "$FORCE" != "1" ]; then
    echo "  ⚠ skip (exists): $dst    [use --force to overwrite]"
    return
  fi
  mkdir -p "$(dirname "$dst")"
  cp -r "$src" "$dst"
  echo "  ✓ $dst/"
}

echo "▸ Copying agents…"
for f in "$SOURCE_DIR/.claude/agents/"wf-*.md; do
  [ -f "$f" ] && copy_file "$f" "$TARGET/.claude/agents/$(basename "$f")"
done

echo "▸ Copying slash commands…"
for f in "$SOURCE_DIR/.claude/commands/"wf-*.md; do
  [ -f "$f" ] && copy_file "$f" "$TARGET/.claude/commands/$(basename "$f")"
done

echo "▸ Copying hooks…"
for f in "$SOURCE_DIR/.claude/hooks/"wf-*.sh; do
  [ -f "$f" ] && copy_file "$f" "$TARGET/.claude/hooks/$(basename "$f")"
done

echo "▸ Copying skills…"
copy_tree "$SOURCE_DIR/.claude/skills/wf-workflow-intro" "$TARGET/.claude/skills/wf-workflow-intro"

echo "▸ Copying workflow data + docs…"
# .claude/workflow/ — the single namespace for everything else
mkdir -p "$TARGET/.claude/workflow"
for sub in plans summaries archive; do
  mkdir -p "$TARGET/.claude/workflow/$sub"
  if [ -f "$SOURCE_DIR/.claude/workflow/$sub/README.md" ] && [ ! -f "$TARGET/.claude/workflow/$sub/README.md" ]; then
    cp "$SOURCE_DIR/.claude/workflow/$sub/README.md" "$TARGET/.claude/workflow/$sub/README.md"
    echo "  ✓ $TARGET/.claude/workflow/$sub/README.md"
  fi
done
for f in WORKFLOW.md README.md checkpoint.sh settings.snippet.json uninstall.sh; do
  if [ -f "$SOURCE_DIR/.claude/workflow/$f" ]; then
    copy_file "$SOURCE_DIR/.claude/workflow/$f" "$TARGET/.claude/workflow/$f"
  fi
done

# Make scripts executable
chmod +x "$TARGET/.claude/hooks/"wf-*.sh 2>/dev/null || true
chmod +x "$TARGET/.claude/workflow/checkpoint.sh" 2>/dev/null || true
chmod +x "$TARGET/.claude/workflow/uninstall.sh" 2>/dev/null || true

# ---- Merge settings.json ----
echo ""
echo "▸ Merging settings.json…"
TARGET_SETTINGS="$TARGET/.claude/settings.json"
SNIPPET="$SOURCE_DIR/.claude/workflow/settings.snippet.json"

if [ ! -f "$TARGET_SETTINGS" ]; then
  cp "$SOURCE_DIR/.claude/settings.json" "$TARGET_SETTINGS"
  echo "  ✓ no existing settings.json — installed standalone version"
elif command -v jq >/dev/null 2>&1; then
  # Merge using jq: deep-merge hooks (by event name) and permissions (by allow/ask array union)
  TMP=$(mktemp)
  jq -s '
    def deep_merge(a; b):
      if (a | type) == "object" and (b | type) == "object" then
        reduce ((a | keys) + (b | keys) | unique[]) as $k ({};
          .[$k] = (
            if (a[$k] != null and b[$k] != null) then deep_merge(a[$k]; b[$k])
            elif (a[$k] != null) then a[$k]
            else b[$k] end
          )
        )
      elif (a | type) == "array" and (b | type) == "array" then
        (a + b) | unique
      else
        b   # snippet wins on scalar conflict
      end;
    deep_merge(.[0]; .[1])
    | del(._comment)
  ' "$TARGET_SETTINGS" "$SNIPPET" > "$TMP" && mv "$TMP" "$TARGET_SETTINGS"
  echo "  ✓ merged via jq (deep-merge: hooks added, permissions union)"
else
  echo "  ⚠ jq not found — cannot auto-merge."
  echo "    Manually merge into $TARGET_SETTINGS:"
  echo "      cat $TARGET/.claude/workflow/settings.snippet.json"
  echo "    Add its \"hooks\" and \"permissions.allow\" entries."
fi

# ---- Final note ----
echo ""
echo "✅ Installed."
echo ""
echo "Next steps:"
echo "  cd $TARGET"
echo "  claude"
echo "  /wf-plan <your first task>"
echo ""
echo "Optional — to expose workflow rules to Claude in this project, add to your CLAUDE.md:"
echo "  @.claude/workflow/WORKFLOW.md"
echo ""
echo "Uninstall:"
echo "  bash $TARGET/.claude/workflow/uninstall.sh"
