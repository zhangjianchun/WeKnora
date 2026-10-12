#!/bin/bash
set -e

VERSION="${1:-v0.1.0}"
PREV_VERSION="${2:-v0.1.0}"
REGISTRY="ghcr.io/zhangjianchun"
SRC_WIN="/mnt/e/zhangjianchun/WeKnora"
SRC_WSL="$HOME/WeKnora"
OUT="${HOME}/release"

step() {
    echo ""
    echo "════════════════════════════════════════════"
    echo "  $1"
    echo "════════════════════════════════════════════"
    echo ""
}

die() {
    echo "ERROR: $1" >&2
    exit 1
}

step "AiRAG UI-Only Rebuild"
echo "  UI 版本       : $VERSION"
echo "  App 版本      : $PREV_VERSION（沿用）"
echo "  Docreader 版本: $PREV_VERSION（沿用）"
echo ""

command -v docker >/dev/null || die "docker 未安装"
command -v npm >/dev/null || die "npm 未安装"
command -v rsync >/dev/null || die "rsync 未安装"

[ -d "$SRC_WIN" ] || die "Windows 源目录不存在: $SRC_WIN"
mkdir -p "$OUT" "$SRC_WSL"

# ── Step 1: 同步源码 ──
step "Step 1/7 同步源码 Windows → WSL"

rsync -a \
    --exclude='.git' \
    --exclude='node_modules' \
    --exclude='.vite' \
    --exclude='.venv' \
    --exclude='.venv_proto' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='dist' \
    --exclude='build' \
    --exclude='WeKnora-lite' \
    --exclude='WeKnora-lite-*' \
    --exclude='*.tar' \
    --exclude='*.tar.gz' \
    --exclude='*.tar.zst' \
    --exclude='data/files' \
    --exclude='logs' \
    --exclude='backups' \
    "$SRC_WIN/" "$SRC_WSL/"

echo "  ✅ 同步完成"

cd "$SRC_WSL"

# ── Step 2: 构建前端 dist（lite 版）──
step "Step 2/7 构建前端 dist (lite)"

cd "$SRC_WSL/frontend"

if [ ! -f node_modules/vite/bin/vite.js ]; then
    echo ">> node_modules 缺失或无效，重新安装..."
    rm -rf node_modules
    npm install --registry=https://registry.npmmirror.com
fi

echo ">> 构建前端 (lite)..."
NODE_OPTIONS=--max-old-space-size=6144 VITE_EDITION=lite npm run build

[ -f dist/index.html ] || die "前端构建失败"

echo ""
echo "  ✅ dist 已生成: $(du -sh dist | cut -f1)"
echo "  ✅ index.html: $(ls -lh dist/index.html | awk '{print $5, $6, $7, $8}')"

# ── Step 3: 构建 3 个前端镜像 ──
step "Step 3/7 构建 3 个前端镜像"

cd "$SRC_WSL"

for EDITION in lite pro enterprise; do
    echo ">> 构建 airag-ui-${EDITION}:${VERSION}..."
    docker build \
        --build-arg VITE_EDITION=${EDITION} \
        -t "${REGISTRY}/airag-ui-${EDITION}:${VERSION}" \
        -f frontend/Dockerfile frontend/
    echo "  ✅ airag-ui-${EDITION}:${VERSION}"
    echo ""
done

# ── Step 4: 复用 app/docreader 旧镜像，打新版本 tag ──
step "Step 4/7 复用 app/docreader 旧镜像"

echo ">> 从 ${PREV_VERSION} 打新 tag：${VERSION}"
echo ""

if ! docker image inspect "${REGISTRY}/airag-app:${PREV_VERSION}" >/dev/null 2>&1; then
    die "找不到 ${REGISTRY}/airag-app:${PREV_VERSION}，请先构建"
fi

if ! docker image inspect "${REGISTRY}/airag-docreader:${PREV_VERSION}" >/dev/null 2>&1; then
    die "找不到 ${REGISTRY}/airag-docreader:${PREV_VERSION}，请先构建"
fi

docker tag "${REGISTRY}/airag-app:${PREV_VERSION}"      "${REGISTRY}/airag-app:${VERSION}"
docker tag "${REGISTRY}/airag-docreader:${PREV_VERSION}" "${REGISTRY}/airag-docreader:${VERSION}"

echo "  ✅ airag-app:${VERSION} 已从 ${PREV_VERSION} 打 tag"
echo "  ✅ airag-docreader:${VERSION} 已从 ${PREV_VERSION} 打 tag"

echo ""
echo ">> 当前本地镜像："
docker images | grep -E "${REGISTRY}/airag-" | sed 's/^/     /'

# ── Step 5: 推送五个镜像 ──
step "Step 5/7 推送镜像到 GHCR"

if ! grep -q "ghcr.io" ~/.docker/config.json 2>/dev/null; then
    echo "WARNING: 未检测到 GHCR 登录状态"
    read -r -p "继续推送? [y/N] " ans
    [[ "$ans" != "y" && "$ans" != "Y" ]] && die "用户取消"
fi

docker push "${REGISTRY}/airag-ui-lite:${VERSION}"
docker push "${REGISTRY}/airag-ui-pro:${VERSION}"
docker push "${REGISTRY}/airag-ui-enterprise:${VERSION}"
docker push "${REGISTRY}/airag-app:${VERSION}"
docker push "${REGISTRY}/airag-docreader:${VERSION}"

echo ""
echo "  ✅ 五个镜像已推送"

# ── Step 6: 打三个包 ──
step "Step 6/7 打三个分发包"

if [ -x ~/package-lite.sh ]; then
    ~/package-lite.sh "$VERSION"
fi

if [ -x ~/package-full.sh ]; then
    ~/package-full.sh "$VERSION"
fi

if [ -x ~/package-full-online.sh ]; then
    ~/package-full-online.sh "$VERSION"
fi

# ── 汇总 ──
step "完成汇总"

echo ">> 分发包："
ls -lh "$OUT"/AiRAG-*.tar.gz 2>/dev/null | sed 's/^/     /'

echo ""
echo ">> GHCR 镜像："
for img in airag-ui-lite airag-ui-pro airag-ui-enterprise airag-app airag-docreader; do
    echo "     ${REGISTRY}/${img}:${VERSION}"
done

echo ""
echo "🎉 前端重建全部完成！"