#!/bin/bash
set -euo pipefail

# install-version.sh
# 独立脚本：为目标项目安装版本号管理系统
# 用途：将 version-bump.yml CI 脚本和 version_manager.py 工具集成到目标项目
# 检测重复安装，避免覆盖已存在的 CI 配置

# 默认参数
TARGET=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# SCRIPT_DIR 是 .claude/workflow，向上两级到仓库根目录
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 帮助文本
show_help() {
  cat <<EOF
用法: bash install-version.sh [--target <target-dir>] [--force]

选项:
  --target <dir>    指定目标项目根目录（默认：workflow submodule 的上级 git 根目录）
  --force           强制覆盖已存在的 CI 配置文件
  --help            显示帮助信息

描述:
  在目标项目中安装版本管理系统：
  - 创建/更新 .github/workflows/version-bump.yml（自动版本增量 CI）
  - 创建/更新 scripts/python_scripts/version_manager.py（版本管理工具）
  - 创建/更新 scripts/python_scripts/analyze_commits.py（提交分析工具）
  - 自动创建 .version 文件（如果不存在）

  默认目标为 workflow submodule 上级项目根目录（与 make install 行为一致）。
  如果 .github/workflows/version-bump.yml 已存在，脚本将拒绝安装并退出，
  除非指定 --force。

示例:
  bash install-version.sh                          # 安装到上级项目
  bash install-version.sh --target ~/my-project    # 安装到指定目录
  bash install-version.sh --force                  # 强制覆盖已有配置
EOF
}

FORCE=0

# 参数解析
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="$2"
      shift 2
      ;;
    --target=*)
      TARGET="${1#--target=}"
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      echo "错误: 未知选项 '$1'" >&2
      show_help
      exit 1
      ;;
  esac
done

# 默认目标：workflow submodule 上级的 git toplevel（与 install.sh 保持一致）
if [[ -z "$TARGET" ]]; then
  TARGET="$(git -C "$REPO_ROOT/.." rev-parse --show-toplevel 2>/dev/null || echo "$REPO_ROOT/..")"
fi

# 规范化目标路径（如果不存在则创建）
if [[ ! -d "$TARGET" ]]; then
  mkdir -p "$TARGET" || {
    echo "错误: 无法创建目标目录: $TARGET" >&2
    exit 1
  }
fi
TARGET="$(cd "$TARGET" && pwd)"

# 定义目标文件路径
CI_FILE="$TARGET/.github/workflows/version-bump.yml"
VERSION_SCRIPT="$TARGET/scripts/python_scripts/version_manager.py"
ANALYZE_SCRIPT="$TARGET/scripts/python_scripts/analyze_commits.py"
VERSION_FILE="$TARGET/.version"

# 源文件路径
SOURCE_CI="$SCRIPT_DIR/version-scripts/version-bump.yml"
SOURCE_SCRIPT="$SCRIPT_DIR/version-scripts/version_manager.py"
SOURCE_ANALYZE="$SCRIPT_DIR/version-scripts/analyze_commits.py"

# 检查源文件是否存在
if [[ ! -f "$SOURCE_CI" ]]; then
  echo "错误: 源文件不存在: $SOURCE_CI" >&2
  exit 1
fi

if [[ ! -f "$SOURCE_SCRIPT" ]]; then
  echo "错误: 源文件不存在: $SOURCE_SCRIPT" >&2
  exit 1
fi

if [[ ! -f "$SOURCE_ANALYZE" ]]; then
  echo "错误: 源文件不存在: $SOURCE_ANALYZE" >&2
  exit 1
fi

# 重复安装检测
if [[ -f "$CI_FILE" ]] && [[ "$FORCE" != "1" ]]; then
  echo "已安装：${CI_FILE} 已存在。如需重新安装，请使用 --force 或手动删除该文件后重试。" >&2
  exit 1
fi

# 创建必要的目录
mkdir -p "$TARGET/.github/workflows"
mkdir -p "$TARGET/scripts/python_scripts"

# 复制 CI 文件
cp "$SOURCE_CI" "$CI_FILE"

# 复制版本管理脚本和依赖分析脚本
cp "$SOURCE_SCRIPT" "$VERSION_SCRIPT"
chmod +x "$VERSION_SCRIPT"

cp "$SOURCE_ANALYZE" "$ANALYZE_SCRIPT"
chmod +x "$ANALYZE_SCRIPT"

# 自动创建 .version 文件（如果不存在）
if [[ ! -f "$VERSION_FILE" ]]; then
  echo '{"version": "0.0.1"}' > "$VERSION_FILE"
fi

# 成功提示
echo "✓ 版本管理系统已成功安装到: $TARGET"
echo "  - CI 脚本: .github/workflows/version-bump.yml"
echo "  - 版本管理工具: scripts/python_scripts/version_manager.py"
echo "  - 提交分析工具: scripts/python_scripts/analyze_commits.py"
echo "  - 版本文件: .version"
echo ""
echo "下一步:"
echo "  推送到 main 分支触发 CI 自动更新版本"

exit 0
