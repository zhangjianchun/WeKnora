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
step "AiRAG App-Only Rebuild"
echo "  App 版本      : $VERSION"
echo "  UI 版本       : $PREV_VERSION（沿用）"
echo "  Docreader 版本: $PREV_VERSION（沿用）"
echo ""
command -v docker >/dev/null || die "docker 未安装"
command -v rsync  >/dev/null || die "rsync 未安装"
[ -d "$SRC_WIN" ] || die "Windows 源目录不存在: $SRC_WIN"
mkdir -p "$OUT" "$SRC_WSL"
# ── Step 1: 同步源码 ──
step "Step 1/6 同步源码 Windows → WSL"
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
# ── Step 2: 构建 app 镜像 ──
step "Step 2/6 构建 airag-app:${VERSION}"
# 兼容两种 Dockerfile 路径
if   [ -f "$SRC_WSL/docker/Dockerfile.app" ]; then
    DOCKERFILE="docker/Dockerfile.app"
elif [ -f "$SRC_WSL/Dockerfile.app" ]; then
    DOCKERFILE="Dockerfile.app"
else
    die "找不到 Dockerfile.app（docker/Dockerfile.app 或 Dockerfile.app）"
fi
echo ">> 使用 Dockerfile: $DOCKERFILE"
echo ">> 构建中（可能 5-15 分钟）..."
echo ""
docker build \
    --build-arg GOPROXY_ARG=https://goproxy.io,direct \
    --build-arg APK_MIRROR_ARG=mirrors.tuna.tsinghua.edu.cn \
    -t "${REGISTRY}/airag-app:${VERSION}" \
    -f "$DOCKERFILE" .
docker image inspect "${REGISTRY}/airag-app:${VERSION}" >/dev/null 2>&1 \
    || die "app 镜像构建失败"
echo "  ✅ airag-app:${VERSION} 构建完成"
# ── Step 3: 复用 UI(×3) / docreader 旧镜像 ──
step "Step 3/6 复用 UI / docreader 旧镜像"
echo ">> 从 ${PREV_VERSION} 打新 tag：${VERSION}"
echo ""
# docreader
if docker image inspect "${REGISTRY}/airag-docreader:${PREV_VERSION}" >/dev/null 2>&1; then
    docker tag "${REGISTRY}/airag-docreader:${PREV_VERSION}" \
               "${REGISTRY}/airag-docreader:${VERSION}"
    echo "  ✅ airag-docreader:${VERSION} ← ${PREV_VERSION}"
else
    die "找不到 ${REGISTRY}/airag-docreader:${PREV_VERSION}，请先构建"
fi
# 三个前端
for EDITION in lite pro enterprise; do
    if docker image inspect "${REGISTRY}/airag-ui-${EDITION}:${PREV_VERSION}" >/dev/null 2>&1; then
        docker tag "${REGISTRY}/airag-ui-${EDITION}:${PREV_VERSION}" \
                   "${REGISTRY}/airag-ui-${EDITION}:${VERSION}"
        echo "  ✅ airag-ui-${EDITION}:${VERSION} ← ${PREV_VERSION}"
    else
        die "找不到 ${REGISTRY}/airag-ui-${EDITION}:${PREV_VERSION}，请先构建"
    fi
done
echo ""
echo ">> 当前本地镜像："
docker images | grep -E "${REGISTRY}/airag-" | sed 's/^/     /'
# ── Step 4: 推送五个镜像 ──
step "Step 4/6 推送镜像到 GHCR"
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

# ── Step 4.5: 编译 Lite Go 二进制 ──
step "Step 4.5 编译 Lite Go 二进制"

cd "$SRC_WSL"
export CGO_ENABLED=1
export CGO_CFLAGS="-Wno-deprecated-declarations"
eval "$(./scripts/get_version.sh env)"
LDFLAGS="$(./scripts/get_version.sh ldflags) -X 'google.golang.org/protobuf/reflect/protoregistry.conflictPolicy=warn'"
go build -tags "sqlite_fts5" -ldflags="-w -s $LDFLAGS" -o WeKnora-lite ./cmd/server

ls -lh WeKnora-lite
echo "  ✅ WeKnora-lite 已重新编译"

# ── Step 5: 打三个包 ──
step "Step 5/6 打三个分发包"
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
echo "🎉 App 重建全部完成！"
