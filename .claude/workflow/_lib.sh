#!/usr/bin/env bash
# install/uninstall/auto-activate 的共享辅助函数
# Source此文件（不要执行它）

# 将 target_settings 与 snippet 合并（使用 jq 深度合并或干运行检查）
# 成功返回 0；合并失败返回 1
# 使用 --dry-run，如果没有任何更改会返回 0 并打印 "noop"
wf_merge_settings() {
  local target_settings="$1"
  local snippet="$2"
  local dry_run=0

  if [ "${3:-}" = "--dry-run" ]; then
    dry_run=1
  fi

  # 如果目标不存在，干运行会改变它（不是 noop）
  if [ ! -f "$target_settings" ]; then
    if [ "$dry_run" = "1" ]; then
      return 0  # 不运行，所以理论上我们会复制
    fi
    # 按原样复制 snippet（不需要合并）
    cp "$snippet" "$target_settings"
    return 0
  fi

  # 目标存在 — 需要合并
  if command -v jq >/dev/null 2>&1; then
    local tmp_merged
    tmp_merged=$(mktemp)

    # 使用 jq 进行深度合并
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
          b   # snippet 在标量冲突时优先
        end;
      deep_merge(.[0]; .[1])
      | del(._comment)
    ' "$target_settings" "$snippet" > "$tmp_merged"

    if [ "$dry_run" = "1" ]; then
      # 检查合并后的文件是否与目标不同
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
    # 没有 jq 的备选方案
    if [ "$dry_run" = "1" ]; then
      # 没有 jq 无法确定干运行效果，所以假设有更改
      return 0
    fi
    # 打印警告到标准错误并返回 0（优雅降级）
    echo "⚠ jq not found — skipping settings merge. Paste .claude/workflow/auto-activate.snippet.json manually if needed." >&2
    return 0
  fi
}

# 计算从目录到文件的相对路径（不解析符号链接）
wf_relpath() {
  local from_dir="$1"
  local to_file="$2"

  # 尝试使用 GNU realpath 和 -s 选项（不解析符号链接）
  if realpath -s --relative-to "$from_dir" "$to_file" 2>/dev/null; then
    return 0
  fi

  # 对于没有 GNU realpath 的系统的备选方案：使用 Python
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import sys,os; print(os.path.relpath(sys.argv[1],sys.argv[2]))" "$to_file" "$from_dir" 2>/dev/null && return 0
  fi

  # 最后的手段：只使用绝对路径（不够理想但可以工作）
  echo "$to_file"
}

# 检测 Windows 系统
wf_is_windows() {
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) return 0 ;;
    *) return 1 ;;
  esac
}
