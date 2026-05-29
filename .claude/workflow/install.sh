#!/usr/bin/env bash
# 统一安装/卸载/自动激活脚本
# 子命令:
#   install.sh symlink       [--target <dir>] [--force] [--quiet]
#   install.sh copy          --target <dir> [--force]
#   install.sh uninstall     [--target <dir>] [--clean-settings] [--force]
#   install.sh auto-activate
#   install.sh -h | --help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUBMODULE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/_lib.sh"

# --- 全局变量 ---
TARGET=""
FORCE=0
QUIET=0
NO_SYMLINK=0
CLEAN_SETTINGS=0
ALL=0

# 默认白名单：不使用 --all 标志时要安装的命令和代理
DEFAULT_COMMANDS=("wf-plan" "wf-dev" "wf-interrupt" "wf-review" "wf-commit")
DEFAULT_AGENTS=("wf-planner" "wf-developer" "wf-reviewer" "wf-commit")

# 检查名称是否在白名单中（通过名称传递数组）
_in_list() {
  local needle="$1" array_name="$2"
  local -n arr="$array_name"
  for item in "${arr[@]}"; do
    [ "$item" = "$needle" ] && return 0
  done
  return 1
}

# 按白名单拷贝某类组件（agents/commands），消除 copy 路径下的重复循环
# $1: 组件类型目录名（agents 或 commands）
# $2: 对应白名单数组名（如 DEFAULT_AGENTS / DEFAULT_COMMANDS）
_copy_filtered() {
  local kind="$1" whitelist_var="$2"
  local f basename_f component_name
  for f in "$SUBMODULE_DIR/.claude/${kind}/"wf-*.md; do
    if [ -f "$f" ]; then
      basename_f="$(basename "$f")"
      component_name="${basename_f%.md}"
      if [ "$ALL" = "1" ] || _in_list "$component_name" "$whitelist_var"; then
        _copy_file "$f" "$TARGET/.claude/${kind}/$basename_f"
      fi
    fi
  done
}

_show_help() {
  cat <<'EOF'
Workflow install/uninstall.

Usage:
  install.sh symlink       [--target <dir>] [--force] [--quiet]
  install.sh copy          --target <dir> [--force] [--all]
  install.sh uninstall     [--target <dir>] [--clean-settings] [--force]
  install.sh auto-activate
  install.sh -h | --help

Subcommands:
  symlink       Install workflow as symlinks (submodule mode).
                Default target = submodule parent project directory.
  copy          Copy workflow files into <dir> (no submodule).
                --all Install all commands; default installs only wf-plan, wf-dev,
                      wf-interrupt, wf-review, wf-commit and dependencies.
  uninstall     Remove workflow files / symlinks from target.
                --clean-settings strips wf-* hook entries from settings.json.
                --force also removes regular files (not just symlinks).
  auto-activate Safe-checked activation; invoked by SessionStart hook.
EOF
}

# 解析目标（父项目根目录）
_resolve_target_for_install() {
  if [ -n "$TARGET" ]; then
    TARGET="$(cd "$TARGET" 2>/dev/null && pwd || echo "$TARGET")"
  else
    TARGET="$SUBMODULE_DIR/.."
    TARGET="$(cd "$TARGET" 2>/dev/null && pwd || echo "$TARGET")"
  fi
}

# 将一个源文件符号链接到目标路径；如果链接成功返回 0，跳过返回 2
_symlink_file() {
  local source_file="$1"
  local target_path="$2"
  local rel_path
  rel_path="$(wf_relpath "$(dirname "$target_path")" "$source_file")"
  mkdir -p "$(dirname "$target_path")"
  if [ -e "$target_path" ] || [ -L "$target_path" ]; then
    if [ -L "$target_path" ]; then
      ln -sfn "$rel_path" "$target_path"
    elif [ "$FORCE" = "1" ]; then
      rm -f "$target_path"
      ln -sfn "$rel_path" "$target_path"
    else
      return 2
    fi
  else
    ln -sfn "$rel_path" "$target_path"
  fi
  return 0
}

# 确保真实状态目录存在，如果有 README 则用其初始化
_ensure_real_dir() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir"
    local seed="$SUBMODULE_DIR/.claude/workflow/$(basename "$dir")/README.md"
    [ -f "$seed" ] && cp "$seed" "$dir/README.md"
  fi
}

# 复制一个文件（由 `copy` 子命令使用）
_copy_file() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ "$FORCE" != "1" ]; then
    echo "  ⚠ skip (exists): $dst    [use --force to overwrite]"
    return
  fi
  cp "$src" "$dst"
  echo "  ✓ $dst"
}

# --- symlink 子命令 ---
cmd_symlink() {
  _resolve_target_for_install

  if wf_is_windows; then
    if [ "$FORCE" != "1" ] && [ "${WF_ALLOW_WIN_SYMLINK:-0}" != "1" ]; then
      cat >&2 <<EOF
⚠ Windows detected. Symlinks require Developer Mode or Administrator.
  Either:
    1. Enable Developer Mode (Settings > Developer > Developer mode)
    2. Run install.sh symlink --force as Administrator
    3. Use install.sh copy --target <dir> instead
    4. Set WF_ALLOW_WIN_SYMLINK=1 and re-run
EOF
      exit 1
    fi
  fi

  local links_created=0
  local links_skipped=0

  # 代理 / 命令 / 钩子
  for kind in agents commands hooks; do
    for f in "$SUBMODULE_DIR/.claude/$kind/"wf-*.*; do
      [ -f "$f" ] || continue
      local name target_link component_name
      name="$(basename "$f")"
      component_name="${name%.*}"

      # 对代理和命令应用白名单过滤，但跳过钩子
      if [ "$kind" != "hooks" ]; then
        local whitelist_var="DEFAULT_${kind^^}"
        if [ "$ALL" != "1" ] && ! _in_list "$component_name" "$whitelist_var"; then
          continue
        fi
      fi

      target_link="$TARGET/.claude/$kind/$name"
      if _symlink_file "$f" "$target_link"; then
        links_created=$((links_created + 1))
      else
        links_skipped=$((links_skipped + 1))
      fi
    done
  done

  # 技能目录（作为整体目录符号链接）
  if [ -d "$SUBMODULE_DIR/.claude/skills/wf-workflow-intro" ]; then
    local skill_target skill_dir rel
    skill_target="$TARGET/.claude/skills/wf-workflow-intro"
    skill_dir="$(dirname "$skill_target")"
    mkdir -p "$skill_dir"
    rel="$(wf_relpath "$skill_dir" "$SUBMODULE_DIR/.claude/skills/wf-workflow-intro")"
    if [ -e "$skill_target" ] || [ -L "$skill_target" ]; then
      if [ -L "$skill_target" ]; then
        rm -f "$skill_target"
        ln -sfn "$rel" "$skill_target"
        links_created=$((links_created + 1))
      elif [ "$FORCE" = "1" ]; then
        rm -rf "$skill_target"
        ln -sfn "$rel" "$skill_target"
        links_created=$((links_created + 1))
      else
        links_skipped=$((links_skipped + 1))
      fi
    else
      ln -sfn "$rel" "$skill_target"
      links_created=$((links_created + 1))
    fi
  fi

  # 真实状态目录
  _ensure_real_dir "$TARGET/.claude/workflow/plans"
  _ensure_real_dir "$TARGET/.claude/workflow/summaries"
  _ensure_real_dir "$TARGET/.claude/workflow/archive"

  # 符号链接工作流支持文件
  for f in WORKFLOW.md checkpoint.sh clean.sh contribute.sh settings.snippet.json auto-activate.snippet.json _lib.sh; do
    local src="$SUBMODULE_DIR/.claude/workflow/$f"
    local dst="$TARGET/.claude/workflow/$f"
    [ -f "$src" ] || continue
    if _symlink_file "$src" "$dst"; then
      links_created=$((links_created + 1))
    else
      links_skipped=$((links_skipped + 1))
    fi
  done

  # 设置合并
  local target_settings="$TARGET/.claude/settings.json"
  local snippet="$SUBMODULE_DIR/.claude/workflow/settings.snippet.json"
  local merge_status="merged"
  if [ -f "$target_settings" ]; then
    if wf_merge_settings "$target_settings" "$snippet" --dry-run 2>/dev/null | grep -q "noop"; then
      merge_status="already merged"
    else
      wf_merge_settings "$target_settings" "$snippet" >/dev/null 2>&1 || merge_status="merge failed"
    fi
  else
    cp "$snippet" "$target_settings"
  fi

  # 激活哨兵
  local sha timestamp
  sha="$(git -C "$SUBMODULE_DIR" rev-parse HEAD 2>/dev/null || echo "unknown")"
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  mkdir -p "$TARGET/.claude/workflow"
  {
    echo "SHA: $sha"
    echo "TIMESTAMP: $timestamp"
  } > "$TARGET/.claude/workflow/.activated"

  if [ "$QUIET" = "0" ]; then
    echo ""
    echo "✓ Workflow installed as symlinks in $TARGET"
    echo "  Links created: $links_created"
    [ "$links_skipped" -gt 0 ] && echo "  Links skipped: $links_skipped (use --force to overwrite)"
    echo "  Settings: $merge_status"
    echo ""
    echo "Next steps:"
    echo "  • Commit .claude/ to version control"
    echo "  • Update workflow: git submodule update --remote && make -C .workflow install"
    echo "  • Uninstall: make -C .workflow uninstall"
    echo "  • Contribute: /wf-contribute"
    echo ""
  fi
}

# --- copy 子命令 ---
cmd_copy() {
  if [ -z "$TARGET" ]; then
    echo "Usage: install.sh copy --target <dir> [--force]" >&2
    exit 1
  fi
  TARGET="$(cd "$TARGET" 2>/dev/null && pwd || echo "$TARGET")"
  if [ ! -d "$TARGET" ]; then
    echo "Target directory does not exist: $TARGET" >&2
    exit 1
  fi
  if [ "$SUBMODULE_DIR" = "$TARGET" ]; then
    echo "Source and target are the same. Nothing to do." >&2
    exit 1
  fi

  echo "Installing workflow → $TARGET"
  echo ""

  echo "▸ Copying agents…"
  _copy_filtered agents DEFAULT_AGENTS

  echo "▸ Copying slash commands…"
  _copy_filtered commands DEFAULT_COMMANDS

  echo "▸ Copying hooks…"
  for f in "$SUBMODULE_DIR/.claude/hooks/"wf-*.sh; do
    [ -f "$f" ] && _copy_file "$f" "$TARGET/.claude/hooks/$(basename "$f")"
  done

  echo "▸ Copying skills…"
  local skill_src="$SUBMODULE_DIR/.claude/skills/wf-workflow-intro"
  local skill_dst="$TARGET/.claude/skills/wf-workflow-intro"
  if [ -e "$skill_dst" ] && [ "$FORCE" != "1" ]; then
    echo "  ⚠ skip (exists): $skill_dst    [use --force to overwrite]"
  elif [ -d "$skill_src" ]; then
    mkdir -p "$(dirname "$skill_dst")"
    rm -rf "$skill_dst"
    cp -r "$skill_src" "$skill_dst"
    echo "  ✓ $skill_dst/"
  fi

  echo "▸ Copying workflow data + docs…"
  mkdir -p "$TARGET/.claude/workflow"
  for sub in plans summaries archive; do
    mkdir -p "$TARGET/.claude/workflow/$sub"
    local seed="$SUBMODULE_DIR/.claude/workflow/$sub/README.md"
    if [ -f "$seed" ] && [ ! -f "$TARGET/.claude/workflow/$sub/README.md" ]; then
      cp "$seed" "$TARGET/.claude/workflow/$sub/README.md"
      echo "  ✓ $TARGET/.claude/workflow/$sub/README.md"
    fi
  done
  for f in WORKFLOW.md checkpoint.sh clean.sh contribute.sh settings.snippet.json auto-activate.snippet.json _lib.sh; do
    local src="$SUBMODULE_DIR/.claude/workflow/$f"
    [ -f "$src" ] && _copy_file "$src" "$TARGET/.claude/workflow/$f"
  done

  chmod +x "$TARGET/.claude/hooks/"wf-*.sh 2>/dev/null || true
  chmod +x "$TARGET/.claude/workflow/"*.sh 2>/dev/null || true

  echo ""
  echo "▸ Merging settings.json…"
  local target_settings="$TARGET/.claude/settings.json"
  local snippet="$SUBMODULE_DIR/.claude/workflow/settings.snippet.json"
  if [ ! -f "$target_settings" ]; then
    cp "$snippet" "$target_settings"
    echo "  ✓ no existing settings.json — installed standalone version"
  else
    if wf_merge_settings "$target_settings" "$snippet"; then
      echo "  ✓ merged via helper"
    else
      echo "  ⚠ merge failed — paste $snippet manually into $target_settings"
    fi
  fi

  echo ""
  echo "✅ Installed."
  echo ""
  echo "Next steps:"
  echo "  cd $TARGET"
  echo "  claude"
  echo "  /wf-plan <your first task>"
  echo ""
  echo "Optional — expose workflow rules in your CLAUDE.md:"
  echo "  @.claude/workflow/WORKFLOW.md"
  echo ""
  echo "Uninstall:"
  echo "  bash $TARGET/.claude/workflow/install.sh uninstall --target $TARGET"
}

# --- uninstall 子命令 ---
cmd_uninstall() {
  _resolve_target_for_install

  shopt -s nullglob
  local removed=0
  local skipped=0

  _remove_one() {
    # 移除一个文件或符号链接
    local path="$1"
    if [ -L "$path" ]; then
      rm -f "$path"
      removed=$((removed + 1))
    elif [ -e "$path" ]; then
      if [ "$FORCE" = "1" ]; then
        rm -rf "$path"
        removed=$((removed + 1))
      else
        echo "  ⚠ regular file (use --force to delete): $path"
        skipped=$((skipped + 1))
      fi
    fi
  }

  for f in "$TARGET"/.claude/agents/wf-*.md;   do _remove_one "$f"; done
  for f in "$TARGET"/.claude/commands/wf-*.md; do _remove_one "$f"; done
  for f in "$TARGET"/.claude/hooks/wf-*.sh;    do _remove_one "$f"; done

  local skill_link="$TARGET/.claude/skills/wf-workflow-intro"
  if [ -L "$skill_link" ]; then
    rm -f "$skill_link"
    removed=$((removed + 1))
  elif [ -d "$skill_link" ]; then
    if [ "$FORCE" = "1" ]; then
      rm -rf "$skill_link"
      removed=$((removed + 1))
    else
      echo "  ⚠ regular directory (use --force to delete): $skill_link"
      skipped=$((skipped + 1))
    fi
  fi

  for f in WORKFLOW.md checkpoint.sh clean.sh contribute.sh settings.snippet.json auto-activate.snippet.json _lib.sh; do
    _remove_one "$TARGET/.claude/workflow/$f"
  done

  rm -f "$TARGET/.claude/workflow/.activated"
  rm -f "$TARGET/.claude/workflow/.activation-error.log"
  rm -f "$TARGET/.claude/workflow/.activation-error.log.reported"

  shopt -u nullglob

  if [ "$CLEAN_SETTINGS" = "1" ]; then
    # 从 settings.json 中清除 wf-* 钩子条目
    local target_settings="$TARGET/.claude/settings.json"
    if [ -f "$target_settings" ] && command -v jq >/dev/null 2>&1; then
      jq '
        .hooks |= (
          to_entries | map(
            .value |= map(
              .hooks |= map(
                select(
                  .type != "command" or
                  (.command | contains("wf-") | not)
                )
              ) | select(length > 0)
            ) | select(length > 0)
          ) | from_entries
        ) | if (.hooks // {} | length) == 0 then del(.hooks) else . end
      ' "$target_settings" > "$target_settings.tmp"
      mv "$target_settings.tmp" "$target_settings"
      echo "  ✓ stripped wf-* hook entries from settings.json"
    fi
  fi

  echo ""
  echo "✓ Workflow removed from $TARGET"
  echo "  Removed: $removed"
  [ "$skipped" -gt 0 ] && echo "  Skipped: $skipped (use --force to remove regular files)"
  echo ""
  echo "Preserved (not removed):"
  echo "  • .claude/workflow/plans/"
  echo "  • .claude/workflow/summaries/"
  echo "  • .claude/workflow/archive/"
  echo ""
  echo "To fully detach a submodule:"
  echo "  git submodule deinit -f .workflow"
  echo "  git rm -f .workflow"
  echo "  git commit -m 'Remove workflow submodule'"
  echo ""
}

# --- auto-activate 子命令 ---
_is_correct_symlink() {
  # 检查符号链接是否指向正确的子模块目录
  local link_path="$1"
  local submodule_dir="$2"
  [ -L "$link_path" ] || return 1
  local link_target
  link_target="$(readlink "$link_path")"
  [[ "$link_target" == *"$submodule_dir"* ]]
}

_collect_conflicts() {
  # 收集冲突（不是指向正确子模块的符号链接）
  local target="$1" submodule="$2"
  local -n out=$3
  local f
  for f in "$target"/.claude/agents/wf-*.md \
           "$target"/.claude/commands/wf-*.md \
           "$target"/.claude/hooks/wf-*.sh; do
    [ -e "$f" ] || continue
    _is_correct_symlink "$f" "$submodule" || out+=("$f")
  done
  if [ -e "$target/.claude/skills/wf-workflow-intro" ]; then
    _is_correct_symlink "$target/.claude/skills/wf-workflow-intro" "$submodule" \
      || out+=("$target/.claude/skills/wf-workflow-intro")
  fi
}

cmd_auto_activate() {
  # 检测子模块目录（相对路径字符串，非绝对路径）
  local submodule_rel=""
  if [ -n "${WF_SUBMODULE_PATH:-}" ]; then
    submodule_rel="$WF_SUBMODULE_PATH"
  elif [ -d ".workflow/.git" ] || [ -f ".workflow/.gitmodules" ]; then
    submodule_rel=".workflow"
  elif [ -f ".gitmodules" ] && grep -q 'path = .workflow' .gitmodules 2>/dev/null; then
    submodule_rel=".workflow"
  elif [ -d ".workflow" ]; then
    submodule_rel=".workflow"
  else
    # 没有子模块上下文 — 静默退出
    return 0
  fi

  local target
  target="$(cd "$SUBMODULE_DIR/.." 2>/dev/null && pwd || echo "$SUBMODULE_DIR/..")"

  local submodule_abs
  submodule_abs="$SUBMODULE_DIR"

  local sentinel="$target/.claude/workflow/.activated"
  local snippet="$submodule_abs/.claude/workflow/settings.snippet.json"
  local error_log="$target/.claude/workflow/.activation-error.log"

  # 检查哨兵
  if [ -f "$sentinel" ]; then
    local recorded current
    recorded="$(grep '^SHA: ' "$sentinel" | cut -d' ' -f2- || echo "")"
    current="$(git -C "$submodule_abs" rev-parse HEAD 2>/dev/null || echo "")"
    if [ -n "$recorded" ] && [ "$recorded" = "$current" ]; then
      return 0
    fi
  fi

  # 冲突检测
  local conflicts=()
  _collect_conflicts "$target" "$submodule_abs" conflicts
  if [ ${#conflicts[@]} -gt 0 ]; then
    local cf list=""
    for cf in "${conflicts[@]}"; do
      list="$list
  - $cf"
    done
    cat >&2 <<EOF

⚠ Workflow auto-activation blocked — conflicts detected:
  Existing wf-* files in .claude/ are not symlinks to $submodule_rel/:$list

  Remediation: make -C $submodule_rel install ARGS=--force
              (or ARGS=--no-symlink on Windows if symlinks are problematic)

EOF
    return 1
  fi

  # 设置合并安全性检查
  local target_settings="$target/.claude/settings.json"
  if [ -f "$target_settings" ]; then
    if ! wf_merge_settings "$target_settings" "$snippet" --dry-run >/dev/null 2>&1; then
      cat >&2 <<EOF

⚠ Workflow auto-activation blocked — settings merge would fail

  Remediation: make -C $submodule_rel install ARGS=--force

EOF
      return 1
    fi
  fi

  # 运行安装（符号链接，静默模式）
  mkdir -p "$target/.claude/workflow"
  if bash "$submodule_abs/.claude/workflow/install.sh" symlink --quiet --target "$target" 2>"$error_log"; then
    rm -f "$error_log"
    return 0
  else
    if [ ! -f "${error_log}.reported" ]; then
      echo "⚠ Workflow activation failed. See: $error_log" >&2
      touch "${error_log}.reported"
    fi
    return 1
  fi
}

# --- 参数解析 ---
if [ $# -eq 0 ]; then
  _show_help
  exit 1
fi

case "$1" in
  -h|--help) _show_help; exit 0 ;;
esac

SUBCOMMAND="$1"
shift

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --target=*) TARGET="${1#--target=}"; shift ;;
    --force) FORCE=1; shift ;;
    --quiet) QUIET=1; shift ;;
    --all) ALL=1; shift ;;
    --no-symlink) NO_SYMLINK=1; shift ;;
    --clean-settings) CLEAN_SETTINGS=1; shift ;;
    -h|--help) _show_help; exit 0 ;;
    --) shift; break ;;
    -*) echo "Unknown flag: $1" >&2; _show_help >&2; exit 1 ;;
    *)
      # 位置参数目标（后向兼容）
      if [ -z "$TARGET" ]; then
        TARGET="$1"; shift
      else
        echo "Unexpected argument: $1" >&2; exit 1
      fi
      ;;
  esac
done

case "$SUBCOMMAND" in
  symlink)
    if [ "$NO_SYMLINK" = "1" ]; then
      SUBCOMMAND="copy"
      cmd_copy
    else
      cmd_symlink
    fi
    ;;
  copy)         cmd_copy ;;
  uninstall)    cmd_uninstall ;;
  auto-activate) cmd_auto_activate ;;
  *) echo "Unknown subcommand: $SUBCOMMAND" >&2; _show_help >&2; exit 1 ;;
esac
