#!/usr/bin/env bash
# Shared helpers for install/uninstall/auto-activate.
# Source this file (don't execute it).

# Merge target_settings with snippet (jq deep-merge or dry-run check).
# Returns 0 on success; exits 1 if merging fails.
# With --dry-run, returns 0 and prints "noop" if no changes would occur.
wf_merge_settings() {
  local target_settings="$1"
  local snippet="$2"
  local dry_run=0

  if [ "${3:-}" = "--dry-run" ]; then
    dry_run=1
  fi

  # If target doesn't exist, dry-run would change it (not noop)
  if [ ! -f "$target_settings" ]; then
    if [ "$dry_run" = "1" ]; then
      return 0  # Not running, so hypothetically we'd copy
    fi
    # Copy the snippet as-is (no merging needed)
    cp "$snippet" "$target_settings"
    return 0
  fi

  # Target exists — need to merge
  if command -v jq >/dev/null 2>&1; then
    local tmp_merged
    tmp_merged=$(mktemp)

    # Deep-merge using jq
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
    ' "$target_settings" "$snippet" > "$tmp_merged"

    if [ "$dry_run" = "1" ]; then
      # Check if merged differs from target
      if cmp -s "$tmp_merged" "$target_settings"; then
        echo "noop"
        rm "$tmp_merged"
        return 0
      else
        rm "$tmp_merged"
        return 0
      fi
    else
      mv "$tmp_merged" "$target_settings"
      return 0
    fi
  else
    # No jq fallback
    if [ "$dry_run" = "1" ]; then
      # Can't determine dryness without jq, so assume changes
      return 0
    fi
    # Print advisory to stderr and return 0 (graceful degradation)
    echo "⚠ jq not found — skipping settings merge. Paste .claude/workflow/auto-activate.snippet.json manually if needed." >&2
    return 0
  fi
}

# Check if target_settings already has wf-* hook entries.
# Returns 0 if any hook command matches "wf-"
# Returns 1 otherwise (safe to merge).
wf_settings_has_wf_hooks() {
  local target_settings="$1"

  if [ ! -f "$target_settings" ]; then
    return 1  # No file, no hooks
  fi

  if command -v jq >/dev/null 2>&1; then
    # Use jq to search for wf hooks
    jq -e '
      .hooks | to_entries[] | .value[] |
      .hooks[]? |
      select(.type == "command" and (.command | contains("wf-"))) |
      .command
    ' "$target_settings" >/dev/null 2>&1
    return $?
  else
    # Fallback: grep for "wf-" in command entries
    if grep -q 'wf-' "$target_settings"; then
      return 0
    else
      return 1
    fi
  fi
}

# Compute relative path from directory to file (without resolving symlinks)
wf_relpath() {
  local from_dir="$1"
  local to_file="$2"

  # Try GNU realpath with -s (no symlink resolution)
  if realpath -s --relative-to "$from_dir" "$to_file" 2>/dev/null; then
    return 0
  fi

  # Fallback for systems without GNU realpath: use Python
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import sys,os; print(os.path.relpath(sys.argv[1],sys.argv[2]))" "$to_file" "$from_dir" 2>/dev/null && return 0
  fi

  # Last resort: just use absolute paths (less ideal but functional)
  echo "$to_file"
}

# Detect Windows
wf_is_windows() {
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) return 0 ;;
    *) return 1 ;;
  esac
}
