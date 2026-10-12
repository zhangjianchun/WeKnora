#!/bin/bash
set -e

VERSION="${1:-v0.1.0}"
REGISTRY="ghcr.io/zhangjianchun"
SRC_WIN="/mnt/e/zhangjianchun/WeKnora"
SRC_WSL="$HOME/WeKnora"
OUT="${HOME}/release"

SKIP_SYNC="${SKIP_SYNC:-0}"
SKIP_FRONTEND="${SKIP_FRONTEND:-0}"
SKIP_LITE_BUILD="${SKIP_LITE_BUILD:-0}"
SKIP_DOCKER="${SKIP_DOCKER:-0}"
SKIP_PUSH="${SKIP_PUSH:-0}"
SKIP_LITE_PKG="${SKIP_LITE_PKG:-0}"
SKIP_FULL_PKG="${SKIP_FULL_PKG:-0}"
SKIP_ONLINE_PKG="${SKIP_ONLINE_PKG:-0}"

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

step "前置检查"

[ -d "$SRC_WIN" ] || die "Windows 源目录不存在: $SRC_WIN"
command -v docker >/dev/null || die "docker 未安装"
command -v go >/dev/null || die "go 未安装"
command -v npm >/dev/null || die "npm 未安装"
command -v rsync >/dev/null || die "rsync 未安装"

echo "  ✅ Windows 源: $SRC_WIN"
echo "  ✅ WSL 构建目录: $SRC_WSL"
echo "  ✅ 版本: $VERSION"
echo "  ✅ 输出: $OUT"

mkdir -p "$OUT" "$SRC_WSL"

# ── Step 0: 同步 Windows → WSL ──
if [ "$SKIP_SYNC" != "1" ]; then
    step "Step 0/8 同步源码 Windows → WSL"

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
else
    echo ">> 跳过 Step 0（同步）"
fi

cd "$SRC_WSL"

# ── Step 1: 构建前端 dist（lite 版，给 Lite 二进制用）──
if [ "$SKIP_FRONTEND" != "1" ]; then
    step "Step 1/8 构建前端 dist (VITE_EDITION=lite)"

    cd "$SRC_WSL/frontend"

    if [ ! -f node_modules/vite/bin/vite.js ]; then
        echo ">> node_modules 缺失或无效，重新安装..."
        rm -rf node_modules
        npm install --registry=https://registry.npmmirror.com
    fi

    echo ">> 构建前端 (lite)..."
    NODE_OPTIONS=--max-old-space-size=6144 \
    VITE_EDITION=lite \
        npm run build

    [ -f dist/index.html ] || die "前端构建失败"

    echo ""
    echo "  ✅ dist 已生成: $(du -sh dist | cut -f1)"
    echo "  ✅ index.html: $(ls -lh dist/index.html | awk '{print $5, $6, $7, $8}')"
else
    echo ">> 跳过 Step 1（前端构建）"
fi

# ── Step 2: 构建 Lite 二进制 ──
if [ "$SKIP_LITE_BUILD" != "1" ]; then
    step "Step 2/8 构建 Lite 二进制"

    cd "$SRC_WSL"

    # 确保 gojieba 模块存在
    GOJIEBA_PATH="$HOME/go/pkg/mod/github.com/yanyiwu/gojieba@v1.4.7"
    if [ ! -f "$GOJIEBA_PATH/jieba.go" ]; then
        echo ">> gojieba 模块缺失，重新下载..."
        go env -w GOPROXY=https://goproxy.io,direct
        sudo rm -rf "$GOJIEBA_PATH" 2>/dev/null || true
        sudo rm -rf "$HOME/go/pkg/mod/cache/download/github.com/yanyiwu/gojieba" 2>/dev/null || true
        go mod download github.com/yanyiwu/gojieba
    fi

    [ -f "$GOJIEBA_PATH/jieba.go" ] || die "gojieba 模块下载失败"

    export EDITION=lite
    eval "$(./scripts/get_version.sh env)"
    LDFLAGS="-w -s $(./scripts/get_version.sh ldflags)"
    export CGO_CFLAGS="-Wno-deprecated-declarations"

    echo ">> 编译 WeKnora-lite..."
    CGO_ENABLED=1 go build -tags "sqlite_fts5" -ldflags="${LDFLAGS}" \
        -o WeKnora-lite ./cmd/server

    [ -f WeKnora-lite ] || die "Lite 二进制构建失败"

    echo "  ✅ WeKnora-lite: $(du -h WeKnora-lite | cut -f1)"
else
    echo ">> 跳过 Step 2（Lite 构建）"
fi

# ── Step 3: 构建 Docker 镜像（3 个前端 + app + docreader）──
if [ "$SKIP_DOCKER" != "1" ]; then
    step "Step 3/8 构建 Docker 镜像"

    cd "$SRC_WSL"

    echo ">> 构建 3 个前端镜像 (lite / pro / enterprise)..."
    for EDITION in lite pro enterprise; do
        echo ""
        echo "   → airag-ui-${EDITION}:${VERSION}"
        docker build \
            --build-arg VITE_EDITION=${EDITION} \
            -t "${REGISTRY}/airag-ui-${EDITION}:${VERSION}" \
            -f frontend/Dockerfile frontend/
    done

    echo ""
    echo ">> 构建 airag-app（可能 5-15 分钟）..."
    docker build \
        --build-arg GOPROXY_ARG=https://goproxy.io,direct \
        -t "${REGISTRY}/airag-app:${VERSION}" \
        -f docker/Dockerfile.app .

    echo ""
    echo ">> 构建 airag-docreader（可能 5-15 分钟）..."
    docker build \
        -t "${REGISTRY}/airag-docreader:${VERSION}" \
        -f docker/Dockerfile.docreader .

    echo ""
    echo ">> 本地镜像："
    docker images | grep -E "${REGISTRY}/airag-" | sed 's/^/     /'
else
    echo ">> 跳过 Step 3（Docker 构建）"
fi

# ── Step 4: 推送到 GHCR ──
if [ "$SKIP_PUSH" != "1" ]; then
    step "Step 4/8 推送镜像到 GHCR"

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
else
    echo ">> 跳过 Step 4（推送 GHCR）"
fi

# ── Step 5: 打 Lite 二进制包 ──
if [ "$SKIP_LITE_PKG" != "1" ]; then
    step "Step 5/8 打 Lite 二进制包"

    if [ ! -x ~/package-lite.sh ]; then
        echo "  ⚠️  ~/package-lite.sh 不存在或不可执行，跳过"
    else
        ~/package-lite.sh "$VERSION"
    fi
else
    echo ">> 跳过 Step 5（Lite 打包）"
fi

# ── Step 6: 打离线包 ──
if [ "$SKIP_FULL_PKG" != "1" ]; then
    step "Step 6/8 打离线包（含镜像 tar）"

    if [ ! -x ~/package-full.sh ]; then
        echo "  ⚠️  ~/package-full.sh 不存在或不可执行，跳过"
    else
        ~/package-full.sh "$VERSION"
    fi
else
    echo ">> 跳过 Step 6（离线打包）"
fi

# ── Step 7: 打在线包（3 版本）──
if [ "$SKIP_ONLINE_PKG" != "1" ]; then
    step "Step 7/8 打在线包（3 版本）"

    if [ ! -x ~/package-full-online.sh ]; then
        echo "  ⚠️  ~/package-full-online.sh 不存在或不可执行，跳过"
    else
        ~/package-full-online.sh "$VERSION"
    fi
else
    echo ">> 跳过 Step 7（在线打包）"
fi

# ── 汇总 ──
step "完成汇总"

echo ">> 分发包："
ls -lh "$OUT"/AiRAG-*.tar.gz 2>/dev/null | sed 's/^/     /' || echo "     （无）"

echo ""
echo ">> GHCR 镜像："
for img in airag-ui-lite airag-ui-pro airag-ui-enterprise airag-app airag-docreader; do
    echo "     ${REGISTRY}/${img}:${VERSION}"
done

echo ""
echo "🎉 全部完成！"