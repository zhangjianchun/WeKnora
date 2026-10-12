#!/bin/bash
set -e

VERSION="${1:-v0.1.0}"
SRC="/mnt/e/zhangjianchun/WeKnora"
OUT="$HOME/release"
DOCKER_PKG="AiRAG-docker_${VERSION}"
PLATFORMS="linux/amd64,linux/arm64"

echo "=== AiRAG Docker Packager ==="
echo "  Version  : ${VERSION}"
echo "  Platforms: ${PLATFORMS}"
echo "  Output   : ${OUT}/${DOCKER_PKG}.tar.gz"
echo ""

# ── 前置检查 ──
if [ ! -f "$SRC/WeKnora-lite" ]; then
  echo "ERROR: 未找到 $SRC/WeKnora-lite"
  exit 1
fi

if [ ! -f "$SRC/docreader/dist/docreader-server" ]; then
  echo "ERROR: 未找到 docreader-server"
  exit 1
fi

if [ ! -f "$SRC/frontend/dist/index.html" ]; then
  echo "ERROR: 前端未构建"
  exit 1
fi

if ! docker buildx version >/dev/null 2>&1; then
  echo "ERROR: docker buildx 不可用"
  exit 1
fi

echo ">> 检查通过"
echo ""

# ── 准备构建上下文 ──
echo ">> 准备 Docker 构建上下文..."
BUILD_CTX=$(mktemp -d)
cleanup() {
  rm -rf "$BUILD_CTX" 2>/dev/null || sudo rm -rf "$BUILD_CTX" 2>/dev/null || true
}
trap cleanup EXIT

mkdir -p "$BUILD_CTX"

cp "$SRC/WeKnora-lite" "$BUILD_CTX/"
cp "$SRC/docreader/dist/docreader-server" "$BUILD_CTX/"
cp -r "$SRC/frontend/dist" "$BUILD_CTX/web"
cp -r "$SRC/config" "$BUILD_CTX/"
cp -r "$SRC/migrations" "$BUILD_CTX/"

GOJIEBA_DICT="${HOME}/go/pkg/mod/github.com/yanyiwu/gojieba@v1.4.7/deps/cppjieba/dict"
if [ -d "$GOJIEBA_DICT" ]; then
  mkdir -p "$BUILD_CTX/gojieba-dict"
  cp -r "$GOJIEBA_DICT/"* "$BUILD_CTX/gojieba-dict/"
else
  echo "WARNING: gojieba 词典不存在: $GOJIEBA_DICT"
fi

cat > "$BUILD_CTX/Dockerfile" <<'DOCKERFILE_EOF'
FROM ubuntu:25.10

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libgomp1 \
    libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

ENV HOME=/home/zhangjianchun
RUN mkdir -p /home/zhangjianchun/go/pkg/mod/github.com/yanyiwu/gojieba@v1.4.7/deps/cppjieba/dict

WORKDIR /app

COPY WeKnora-lite ./
COPY docreader-server ./
COPY web/ ./web/
COPY config/ ./config/
COPY migrations/ ./migrations/
COPY docker-entrypoint.sh ./
COPY gojieba-dict/ /home/zhangjianchun/go/pkg/mod/github.com/yanyiwu/gojieba@v1.4.7/deps/cppjieba/dict/

RUN chmod +x WeKnora-lite docreader-server docker-entrypoint.sh

EXPOSE 8080 50051

ENTRYPOINT ["./docker-entrypoint.sh"]
DOCKERFILE_EOF

cat > "$BUILD_CTX/docker-entrypoint.sh" <<'ENTRY_EOF'
#!/bin/bash
set -e

mkdir -p data logs

if [ -f "./docreader-server" ]; then
    echo ">> 启动 docreader..."
    ./docreader-server > logs/docreader.log 2>&1 &

    for i in $(seq 1 30); do
        if (echo > /dev/tcp/127.0.0.1/50051) >/dev/null 2>&1; then
            echo "   docreader 已就绪 (${i}s)"
            break
        fi
        sleep 1
    done
fi

echo ">> 启动 AI 知识库..."
exec ./WeKnora-lite
ENTRY_EOF

chmod +x "$BUILD_CTX/docker-entrypoint.sh"

# ── 构建多平台镜像 ──
echo ">> 构建多平台镜像 (${PLATFORMS})..."
cd "$BUILD_CTX"

if ! docker buildx inspect airag-builder >/dev/null 2>&1; then
  docker buildx create --name airag-builder --use
fi
docker buildx use airag-builder

docker buildx build \
    --platform "$PLATFORMS" \
    -t "airag-lite:${VERSION}" \
    -t "airag-lite:latest" \
    --output "type=oci,dest=${BUILD_CTX}/airag-lite-oci.tar" \
    .

# ── 组装分发包 ──
echo ">> 组装 Docker 分发包..."
DOCKER_OUT="$OUT/$DOCKER_PKG"
rm -rf "$DOCKER_OUT"
mkdir -p "$DOCKER_OUT"

mv "$BUILD_CTX/airag-lite-oci.tar" "$DOCKER_OUT/"

cat > "$DOCKER_OUT/docker-compose.yml" <<'COMPOSE_EOF'
services:
  airag:
    image: airag-lite:latest
    container_name: airag-lite
    ports:
      - "8080:8080"
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
      - ./.env:/app/.env
    restart: unless-stopped
COMPOSE_EOF

cp "$SRC/.env.lite.example" "$DOCKER_OUT/.env.example"

cat > "$DOCKER_OUT/load-image.sh" <<'LOAD_EOF'
#!/bin/bash
set -e
cd "$(dirname "$0")"

echo ">> 导入 Docker 镜像..."
docker load -i airag-lite-oci.tar

echo ">> 创建数据目录..."
mkdir -p data logs

if [ ! -f .env ]; then
    cp .env.example .env
    echo ">> 已创建 .env，请编辑后启动"
fi

echo ">> 启动服务..."
docker compose up -d

echo ""
echo "=========================================="
echo "  AI 知识库已启动"
echo "  访问地址: http://localhost:8080"
echo "=========================================="
LOAD_EOF
chmod +x "$DOCKER_OUT/load-image.sh"

cat > "$DOCKER_OUT/load-image.ps1" <<'LOAD_PS1'
Write-Host ">> 导入 Docker 镜像..." -ForegroundColor Cyan
docker load -i airag-lite-oci.tar

Write-Host ">> 创建数据目录..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path data, logs | Out-Null

if (-not (Test-Path .env)) {
    Copy-Item .env.example .env
    Write-Host ">> 已创建 .env，请编辑后启动" -ForegroundColor Yellow
}

Write-Host ">> 启动服务..." -ForegroundColor Cyan
docker compose up -d

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  AI 知识库已启动" -ForegroundColor Green
Write-Host "  访问地址: http://localhost:8080" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
LOAD_PS1

# ── README（用 printf，避免 heredoc 坑）──
printf '%s\n' \
  '# AiRAG Docker 版部署' \
  '' \
  '## 系统要求' \
  '- Docker 20.10+' \
  '- Docker Compose v2' \
  '- 4GB+ 内存' \
  '' \
  '## 快速开始' \
  '' \
  '### Linux / Mac' \
  '    ./load-image.sh' \
  '' \
  '### Windows (PowerShell)' \
  '    .\load-image.ps1' \
  '' \
  '## 手动操作' \
  '    docker load -i airag-lite-oci.tar' \
  '    cp .env.example .env' \
  '    docker compose up -d' \
  '' \
  '## 访问' \
  '    http://localhost:8080' \
  '' \
  '## 常用命令' \
  '    docker compose logs -f     # 查看日志' \
  '    docker compose restart     # 重启' \
  '    docker compose down        # 停止' \
  '' \
  '## 数据位置' \
  '    数据保存在当前目录 data/，备份直接复制该目录即可。' \
  > "$DOCKER_OUT/README.md"

# ── 打包 ──
echo ">> 创建 tar.gz..."
cd "$OUT"
rm -f "${DOCKER_PKG}.tar.gz" "${DOCKER_PKG}.tar.gz.sha256"
tar czf "${DOCKER_PKG}.tar.gz" "$DOCKER_PKG"
sha256sum "${DOCKER_PKG}.tar.gz" > "${DOCKER_PKG}.tar.gz.sha256"

echo ""
echo "=== Docker 打包完成 ==="
echo "  ${OUT}/${DOCKER_PKG}.tar.gz"
ls -lh "${OUT}/${DOCKER_PKG}.tar.gz"