#!/usr/bin/env bash
# 应用 AI 知识库（AiRAG）品牌覆盖物到目标目录。
#
# 用法：
#   bash branding-overrides/apply.sh <目标目录>            # 复制覆盖
#   bash branding-overrides/apply.sh <目标目录> --check    # 仅列出将覆盖的文件
#
# 典型目标：打包脚本的临时包目录（推荐）、或本地部署的仓库根目录。
# 覆盖采用「同名替换、其余保留」策略，不会删除目标目录中上游自带的文件。

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-.}"
MODE="${2:-apply}"

if [[ ! -d "$TARGET" ]]; then
    echo "ERROR: 目标目录不存在: $TARGET" >&2
    exit 1
fi
TARGET="$(cd "$TARGET" && pwd)"

if [[ "$MODE" == "--check" ]]; then
    echo "将覆盖到 $TARGET 的文件："
    (cd "$HERE" && find . -type f ! -name apply.sh ! -name README.md | sed 's|^\./||' | sort)
    exit 0
fi
if [[ "$MODE" != "apply" ]]; then
    echo "ERROR: 未知参数: $MODE" >&2
    exit 1
fi

copy_dir() {
    local src="$1" dst="$2"
    [[ -d "$src" ]] || return 0
    mkdir -p "$dst"
    cp -r "$src"/. "$dst"/
    echo "  ✓ ${src#"$HERE"/} -> ${dst#"$TARGET"/}"
}

copy_file() {
    local src="$1" dst="$2"
    [[ -f "$src" ]] || return 0
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo "  ✓ ${src#"$HERE"/} -> ${dst#"$TARGET"/}"
}

echo "=== 应用品牌覆盖物到 $TARGET ==="
copy_dir  "$HERE/config"    "$TARGET/config"
copy_dir  "$HERE/docker"    "$TARGET/docker"
copy_dir  "$HERE/frontend"  "$TARGET/frontend"
copy_dir  "$HERE/docreader" "$TARGET/docreader"
copy_file "$HERE/scripts/build_browserskill.sh" "$TARGET/scripts/build_browserskill.sh"
copy_file "$HERE/env/.env.example"      "$TARGET/.env.example"
copy_file "$HERE/env/.env.lite.example" "$TARGET/.env.lite.example"
echo "=== 完成 ==="

if [[ -d "$TARGET/.git" ]]; then
    echo "提示：目标是一个 Git 工作树，上述文件已被修改。"
    echo "      如需还原，执行：git -C \"$TARGET\" checkout -- config docker frontend docreader scripts/build_browserskill.sh .env.example .env.lite.example"
fi
