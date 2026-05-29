#!/bin/bash
# 工作流子模块分支创建、编辑准备、上游 PR 推送脚本
# 用法: contribute.sh <description> | --push

set -eu

# 无论当前工作目录如何，都解析父仓库根目录
PARENT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# 检测子模块目录（返回绝对路径）
_detect_submodule_dir() {
    local env_override="${WF_SUBMODULE_PATH:-}"
    if [ -n "$env_override" ]; then
        echo "$env_override"
        return 0
    fi

    # 首先尝试 .workflow（最常见的情况）
    if [ -d "$PARENT_ROOT/.workflow" ] && [ -d "$PARENT_ROOT/.workflow/.git" ]; then
        echo "$PARENT_ROOT/.workflow"
        return 0
    fi

    # 在 .gitmodules 中扫描我们仓库的 URL
    if [ -f "$PARENT_ROOT/.gitmodules" ]; then
        local repo_url
        repo_url=$(cd "$PARENT_ROOT/.workflow" 2>/dev/null && git remote get-url origin 2>/dev/null || echo "")
        if [ -n "$repo_url" ]; then
            grep -q "url = .*$repo_url" "$PARENT_ROOT/.gitmodules" 2>/dev/null && echo "$PARENT_ROOT/.workflow" && return 0
        fi
    fi

    echo "Error: Could not detect workflow submodule. Set WF_SUBMODULE_PATH or ensure .workflow exists." >&2
    return 1
}

# 解析 SUBMODULE_DIR（绝对路径）
SUBMODULE_DIR=$(_detect_submodule_dir)

# 要求子模块是真正的 git 子模块（不仅仅是目录）
if ! git -C "$SUBMODULE_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
    echo "Error: .workflow is not a git repository." >&2
    exit 1
fi


ACTION="${1:-}"

# 检查子模块是否干净（分支操作前必需）
if ! git -C "$SUBMODULE_DIR" diff --quiet 2>/dev/null; then
    echo "Error: Workflow submodule has uncommitted changes:" >&2
    git -C "$SUBMODULE_DIR" status --short >&2
    echo "" >&2
    echo "Commit your changes first: git -C .workflow commit -am '...'" >&2
    exit 1
fi

if ! git -C "$SUBMODULE_DIR" diff --cached --quiet 2>/dev/null; then
    echo "Error: Workflow submodule has staged changes:" >&2
    git -C "$SUBMODULE_DIR" status --short >&2
    echo "" >&2
    echo "Commit your changes first: git -C .workflow commit -am '...'" >&2
    exit 1
fi

if [ "$ACTION" = "--push" ]; then
    # 推送模式：验证分支上是否存在提交
    CURRENT_BRANCH=$(git -C "$SUBMODULE_DIR" rev-parse --abbrev-ref HEAD)

    if [ "$CURRENT_BRANCH" = "HEAD" ] || [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
        echo "Error: You are on the main branch. Did you forget to run /wf-contribute <description> first?" >&2
        exit 1
    fi

    # 获取 origin/main 以确保引用存在
    git -C "$SUBMODULE_DIR" fetch origin main 2>/dev/null || true

    # 检查是否有分支领先 main 的提交
    if ! git -C "$SUBMODULE_DIR" rev-list origin/main.."$CURRENT_BRANCH" --count 2>/dev/null | grep -qv "^0$"; then
        echo "Error: No new commits on branch '$CURRENT_BRANCH'. Nothing to push." >&2
        echo "Make changes and commit them first." >&2
        exit 1
    fi

    # 以跟踪方式推送到上游
    echo "Pushing branch '$CURRENT_BRANCH' to upstream..." >&2
    if ! git -C "$SUBMODULE_DIR" push -u origin "$CURRENT_BRANCH" 2>&1; then
        echo "Error: Failed to push branch." >&2
        exit 1
    fi

    # 解析上游远程仓库以构造 PR URL 或使用 gh
    REMOTE_URL=$(git -C "$SUBMODULE_DIR" remote get-url origin)

    # 从 SSH（git@github.com:owner/repo.git）或 HTTPS（https://github.com/owner/repo.git）格式提取 owner/repo
    # 如果存在则去掉 .git 后缀
    OWNER_REPO=""
    if [[ "$REMOTE_URL" =~ git@github\.com:([^/]+)/([^/]+?)(\.git)?$ ]]; then
        OWNER_REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    elif [[ "$REMOTE_URL" =~ https://github\.com/([^/]+)/([^/]+?)(\.git)?/?$ ]]; then
        OWNER_REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    fi
    # 如果被捕获则清除 .git 后缀
    OWNER_REPO="${OWNER_REPO%.git}"

    if [ -z "$OWNER_REPO" ]; then
        # 非 GitHub 主机
        echo "" >&2
        echo "Push complete! To open a pull request on your Git host, visit:" >&2
        echo "  Remote: $REMOTE_URL" >&2
        echo "  Branch: $CURRENT_BRANCH" >&2
        exit 0
    fi

    # 首先尝试使用 gh
    if command -v gh >/dev/null 2>&1; then
        echo "" >&2
        echo "Opening GitHub PR for branch '$CURRENT_BRANCH'..." >&2
        if gh pr create \
            --repo "$OWNER_REPO" \
            --base main \
            --head "$CURRENT_BRANCH" \
            --fill --web 2>&1
        then
            echo "PR created and opened in browser." >&2
            exit 0
        else
            # 如果 gh 失败则回退到比较 URL
            echo "Could not create PR via gh. Opening compare URL instead..." >&2
            COMPARE_URL="https://github.com/$OWNER_REPO/compare/main...$CURRENT_BRANCH"
            echo "  $COMPARE_URL" >&2
            exit 0
        fi
    else
        # 没有 gh；打印比较 URL
        COMPARE_URL="https://github.com/$OWNER_REPO/compare/main...$CURRENT_BRANCH"
        echo "" >&2
        echo "gh command not found. Open your PR manually:" >&2
        echo "  $COMPARE_URL" >&2
        echo "" >&2
        echo "After your PR merges, update the submodule in your project:" >&2
        echo "  git submodule update --remote" >&2
        echo "  git add .workflow && git commit -m 'Update workflow submodule'" >&2
        exit 0
    fi
else
    # 分支模式：创建新的贡献分支
    if [ -z "$ACTION" ]; then
        echo "Usage: $0 <description> | --push" >&2
        echo "" >&2
        echo "Examples:" >&2
        echo "  $0 \"improve planner prompt\"" >&2
        echo "  $0 --push" >&2
        exit 1
    fi

    DESCRIPTION="$ACTION"

    # 从描述创建分支名
    # 格式: contrib/YYYYMMDD-<slugified-description>
    BRANCH_BASE="contrib/$(date +%Y%m%d)"
    BRANCH_SLUG=$(echo "$DESCRIPTION" | tr ' /' '--' | tr -cd 'a-zA-Z0-9-' | cut -c1-40)
    BRANCH_NAME="$BRANCH_BASE-$BRANCH_SLUG"

    # 创建或切换到分支
    if git -C "$SUBMODULE_DIR" rev-parse --verify "$BRANCH_NAME" >/dev/null 2>&1; then
        echo "Branch '$BRANCH_NAME' already exists. Switching to it..." >&2
        git -C "$SUBMODULE_DIR" checkout "$BRANCH_NAME"
    else
        echo "Creating branch '$BRANCH_NAME'..." >&2
        git -C "$SUBMODULE_DIR" checkout -b "$BRANCH_NAME"
    fi

    echo "" >&2
    echo "✓ Ready to edit the workflow!" >&2
    echo "" >&2
    echo "Next steps:" >&2
    echo "  1. Edit files under .workflow/.claude/ (agents, commands, hooks, skills)" >&2
    echo "     → Changes take effect live via symlinks in your project" >&2
    echo "  2. Commit your changes:" >&2
    echo "     git -C .workflow commit -am 'Your commit message'" >&2
    echo "  3. Push and open a PR:" >&2
    echo "     /wf-contribute --push" >&2
    exit 0
fi
