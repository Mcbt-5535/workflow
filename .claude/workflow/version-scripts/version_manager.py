#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
版本号管理脚本
用于自动管理项目的版本号，支持语义化版本控制
格式: MAJOR.MINOR.PATCH (主版本号.次版本号.修订号)

作者: Assistant
日期: 2026-02-12
"""

import os
import re
import sys
import json
import subprocess
from pathlib import Path
from datetime import datetime


class VersionManager:
    def __init__(self, version_file=".version"):
        self.version_file = Path(version_file)
        self.version = self._load_version()

    def _load_version(self):
        """从版本文件加载当前版本号"""
        if self.version_file.exists():
            with open(self.version_file, "r") as f:
                content = f.read().strip()
                # 尝试解析JSON格式，如果失败则解析纯文本格式
                try:
                    version_data = json.loads(content)
                    return version_data.get("version", "0.0.1")
                except json.JSONDecodeError:
                    # 如果不是JSON格式，则认为是纯版本号
                    return content.strip()
        else:
            # 如果版本文件不存在，返回初始版本号
            return "0.0.1"

    def _save_version(self, version):
        """保存版本号到文件"""
        version_data = {
            "version": version,
            "updated_at": datetime.now().isoformat(),
        }
        with open(self.version_file, "w") as f:
            json.dump(version_data, f, indent=2)
            f.write("\n")

    def get_current_version(self):
        """获取当前版本号"""
        return self.version

    def _parse_version(self, version_str):
        """解析版本号字符串为数字元组"""
        match = re.match(r"^(\d+)\.(\d+)\.(\d+)$", version_str)
        if match:
            return tuple(map(int, match.groups()))
        else:
            raise ValueError(f"Invalid version format: {version_str}")

    def _get_commit_count_since_last_tag(self):
        """获取自上次标签以来的提交数量"""
        try:
            # 获取最新的标签
            result = subprocess.run(
                ["git", "describe", "--tags", "--abbrev=0"], capture_output=True, text=True
            )
            if result.returncode == 0:
                # raw_tag 用于 git ref 拼接，保留原始前缀（如 v）
                raw_tag = result.stdout.strip()
                # 获取自该标签以来的提交数量
                result = subprocess.run(
                    ["git", "rev-list", f"{raw_tag}..HEAD", "--count"],
                    capture_output=True,
                    text=True,
                )
                # 检查 rev-list 是否成功，失败则返回 fallback 0
                if result.returncode != 0:
                    print(
                        f"Error: git rev-list failed: {result.stderr.strip()}",
                        file=sys.stderr,
                    )
                    return 0
                commit_count = int(result.stdout.strip())
                return commit_count
            else:
                # 如果没有标签，返回0
                return 0
        except Exception as e:
            print(f"Error getting commit count: {e}", file=sys.stderr)
            return 0

    def _format_version(self, major, minor, patch):
        """格式化版本号为字符串"""
        return f"{major}.{minor}.{patch}"

    def bump_major(self):
        """增加主版本号"""
        major, minor, patch = self._parse_version(self.version)
        new_version = self._format_version(major + 1, 0, 0)
        self._save_version(new_version)
        self.version = new_version
        return new_version

    def bump_minor(self):
        """增加次版本号"""
        major, minor, patch = self._parse_version(self.version)
        new_version = self._format_version(major, minor + 1, 0)
        self._save_version(new_version)
        self.version = new_version
        return new_version

    def bump_patch(self):
        """增加修订号，基于当前提交数计算新版本号"""
        commit_count = self._get_commit_count_since_last_tag()
        # 如果没有新提交，至少增加1
        if commit_count == 0:
            commit_count = 1

        # 获取最新的标签版本作为基础
        try:
            result = subprocess.run(
                ["git", "describe", "--tags", "--abbrev=0"], capture_output=True, text=True
            )
            if result.returncode == 0:
                # raw_tag 保留原始前缀用于 ref 拼接；version_str 去除 v 前缀仅用于版本号解析
                raw_tag = result.stdout.strip()
                version_str = raw_tag.lstrip("v")
                base_major, base_minor, base_patch = self._parse_version(version_str)
                # 基于最新标签的版本号，将提交数作为patch版本
                new_version = self._format_version(
                    base_major, base_minor, base_patch + commit_count
                )
            else:
                # 如果没有标签，基于当前版本号增加提交数
                major, minor, patch = self._parse_version(self.version)
                new_version = self._format_version(major, minor, patch + commit_count)
        except Exception as e:
            # 如果无法获取标签，基于当前版本号增加提交数
            major, minor, patch = self._parse_version(self.version)
            new_version = self._format_version(major, minor, patch + commit_count)

        self._save_version(new_version)
        self.version = new_version
        return new_version

    def set_version(self, version):
        """设置指定版本号"""
        # 验证版本号格式
        if not re.match(r"^\d+\.\d+\.\d+$", version):
            raise ValueError(
                f"Invalid version format: {version}. Expected format: MAJOR.MINOR.PATCH"
            )

        self._save_version(version)
        self.version = version
        return version

    def get_dynamic_version(self):
        """动态计算当前版本（基于最新标签和提交数）"""
        try:
            # 获取最新的标签
            result = subprocess.run(
                ["git", "describe", "--tags", "--abbrev=0"], capture_output=True, text=True
            )
            if result.returncode == 0:
                # raw_tag 保留原始前缀用于 ref 拼接；version_str 去除 v 前缀仅用于版本号解析
                raw_tag = result.stdout.strip()
                version_str = raw_tag.lstrip("v")
                base_major, base_minor, base_patch = self._parse_version(version_str)

                # 获取自该标签以来的提交数量
                result = subprocess.run(
                    ["git", "rev-list", f"{raw_tag}..HEAD", "--count"],
                    capture_output=True,
                    text=True,
                )
                # 检查 rev-list 是否成功，失败则回退到当前版本
                if result.returncode != 0:
                    print(
                        f"Error: git rev-list failed: {result.stderr.strip()}",
                        file=sys.stderr,
                    )
                    return self.version
                commit_count = int(result.stdout.strip())

                # 计算新版本号，将基础标签版本与提交数相加
                return self._format_version(base_major, base_minor, base_patch + commit_count)
            else:
                # 如果没有标签，返回当前版本
                return self.version
        except Exception as e:
            print(f"Error computing dynamic version: {e}", file=sys.stderr)
            return self.version


def main():
    if len(sys.argv) < 2:
        print("Usage: python version_manager.py <command> [version]")
        print("Commands:")
        print("  get              - Get current version")
        print("  major            - Bump major version")
        print("  minor            - Bump minor version")
        print("  patch            - Bump patch version")
        print("  set <version>    - Set specific version (format: x.y.z)")
        print("  dynamic          - Get dynamic version based on latest tag and commit count")
        sys.exit(1)

    command = sys.argv[1]
    vm = VersionManager()

    try:
        if command == "get":
            print(vm.get_current_version())
        elif command == "major":
            new_version = vm.bump_major()
            print(new_version)
        elif command == "minor":
            new_version = vm.bump_minor()
            print(new_version)
        elif command == "patch":
            new_version = vm.bump_patch()
            print(new_version)
        elif command == "set":
            if len(sys.argv) < 3:
                print("Error: Version number required for 'set' command")
                sys.exit(1)
            version = sys.argv[2]
            new_version = vm.set_version(version)
            print(new_version)
        elif command == "dynamic":
            print(vm.get_dynamic_version())
        else:
            print(f"Unknown command: {command}")
            sys.exit(1)
    except ValueError as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
