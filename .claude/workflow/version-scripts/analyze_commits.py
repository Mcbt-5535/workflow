#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
分析Git提交历史以确定版本号更新类型

作者: Assistant
日期: 2026-02-12
"""

import subprocess
import sys
import re


def get_git_commits_since_last_tag():
    """获取自上次标签以来的所有提交"""
    try:
        # 获取最新的标签
        result = subprocess.run(
            ["git", "describe", "--tags", "--abbrev=0"], capture_output=True, text=True
        )
        # 使用 %B 获取完整 commit message（含 body/footer），以 ---COMMIT--- 作为分隔符切分
        separator = "---COMMIT---"
        if result.returncode == 0:
            latest_tag = result.stdout.strip()
            # 获取自该标签以来的所有提交信息（完整 message）
            result = subprocess.run(
                ["git", "log", f"{latest_tag}..HEAD", f"--pretty=format:%B%n{separator}"],
                capture_output=True,
                text=True,
            )
        else:
            # 如果没有标签，获取最近的10个提交（完整 message）
            result = subprocess.run(
                ["git", "log", f"--pretty=format:%B%n{separator}", "-10"],
                capture_output=True,
                text=True,
            )

        # 按分隔符切分为单条 commit 的完整 message，过滤空块
        commit_messages = [
            block.strip() for block in result.stdout.split(separator) if block.strip()
        ]
        return commit_messages
    except Exception as e:
        print(f"Error getting commits: {e}", file=sys.stderr)
        return []


def analyze_commits_for_version_bump(commit_messages):
    """
    分析提交信息以确定版本号更新类型
    返回: 'major', 'minor', 或 'patch'
    """
    # 使用优先级系统，多种提交类型中取最高优先级
    bump_priority = {"major": 3, "minor": 2, "patch": 1}  # 最高优先级  # 最低优先级

    max_priority = 0
    final_bump_type = "patch"

    # 破坏性变更检测：footer 中的 BREAKING CHANGE，或标题中的 type!: 标记（如 feat!: / fix!:）
    breaking_re = re.compile(
        r"^BREAKING[ -]CHANGE\b|^(feat|fix|refactor)!:",
        re.IGNORECASE | re.MULTILINE,
    )

    for message in commit_messages:
        # subject 为完整 message 的第一行，用于 type 前缀判断
        subject_lower = message.splitlines()[0].lower() if message.splitlines() else ""

        # 检查是否包含破坏性变更 (major)：扫描整个 message（含 body/footer）
        if breaking_re.search(message):
            priority = bump_priority["major"]
            if priority > max_priority:
                max_priority = priority
                final_bump_type = "major"

        # 检查是否是新功能提交 (minor)
        elif subject_lower.startswith("feat:"):
            priority = bump_priority["minor"]
            if priority > max_priority:
                max_priority = priority
                final_bump_type = "minor"

        # 检查是否是修复提交 (patch)
        elif subject_lower.startswith("fix:"):
            priority = bump_priority["patch"]
            if priority > max_priority:
                max_priority = priority
                final_bump_type = "patch"

        # 检查其他类型提交 (如refactor, perf等，也视为patch)
        elif (
            subject_lower.startswith("refactor:")
            or subject_lower.startswith("perf:")
            or subject_lower.startswith("docs:")
            or subject_lower.startswith("style:")
            or subject_lower.startswith("test:")
            or subject_lower.startswith("chore:")
        ):
            priority = bump_priority["patch"]
            if priority > max_priority:
                max_priority = priority
                final_bump_type = "patch"

    return final_bump_type


def main():
    if len(sys.argv) != 2 or sys.argv[1] != "analyze":
        print("Usage: python analyze_commits.py analyze")
        sys.exit(1)

    commits = get_git_commits_since_last_tag()
    if not commits:
        # 如果没有新提交，返回 'patch' 作为默认值
        print("patch")
        return

    version_bump_type = analyze_commits_for_version_bump(commits)
    print(version_bump_type)


if __name__ == "__main__":
    main()
