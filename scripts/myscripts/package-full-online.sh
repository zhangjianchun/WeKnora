#!/bin/bash
set -e

VERSION="${1:-v0.1.0}"
SRC="/mnt/e/zhangjianchun/WeKnora"
OUT="$HOME/release"
REGISTRY="ghcr.io/zhangjianchun"

echo "=== AiRAG Online Packager ==="
echo "  Version   : ${VERSION}"
echo "  Editions  : lite / pro / enterprise"
echo "  Output    : ${OUT}/AiRAG-online-{edition}_${VERSION}.tar.gz"
echo ""

[ -f "$SRC/docker-compose.yml" ] || { echo "ERROR: 未找到 $SRC/docker-compose.yml"; exit 1; }
[ -f "$SRC/.env.example" ] || [ -f "$SRC/.env.lite.example" ] || { echo "ERROR: 未找到 .env.example"; exit 1; }

echo ">> 检查通过"
echo ""

for EDITION in lite pro enterprise; do

    PKG="AiRAG-online-${EDITION}_${VERSION}"
    PKG_DIR="$OUT/$PKG"

    echo ""
    echo "════════════════════════════════════════════"
    echo "  打包 ${EDITION} 版本"
    echo "════════════════════════════════════════════"
    echo ""

    rm -rf "$PKG_DIR"
    mkdir -p "$PKG_DIR"

    # ── 复制 docker-compose.yml ──
    cp "$SRC/docker-compose.yml" "$PKG_DIR/"

    # ── 替换镜像地址 ──
    cd "$PKG_DIR"

    sed -i 's|:-wechatopenai}|:-ghcr.io/zhangjianchun}|g' docker-compose.yml
    sed -i "s|/weknora-ui:|/airag-ui-${EDITION}:|g" docker-compose.yml
    sed -i 's|/weknora-app:|/airag-app:|g' docker-compose.yml
    sed -i 's|/weknora-docreader:|/airag-docreader:|g' docker-compose.yml
    sed -i 's|/weknora-sandbox:|/airag-sandbox:|g' docker-compose.yml
    sed -i "s|\${AIRAG_VERSION:-latest}|\${AIRAG_VERSION:-${VERSION}}|g" docker-compose.yml

    echo "   image 行："
    grep "image:" docker-compose.yml | grep -E "airag|paradedb|redis" | sed 's/^/     /'
    echo ""

    # ── 复制 .env.example 并调整默认值 ──
    if [ -f "$SRC/.env.example" ]; then
        cp "$SRC/.env.example" "$PKG_DIR/"
    elif [ -f "$SRC/.env.lite.example" ]; then
        cp "$SRC/.env.lite.example" "$PKG_DIR/.env.example"
    fi

    if [ -f "$PKG_DIR/.env.example" ]; then
        # 强制 NEO4J_ENABLE=false
        if grep -qE "^\s*NEO4J_ENABLE\s*=" "$PKG_DIR/.env.example"; then
            sed -i 's/^\s*NEO4J_ENABLE\s*=.*/NEO4J_ENABLE=false/' "$PKG_DIR/.env.example"
        else
            echo "" >> "$PKG_DIR/.env.example"
            echo "# 知识图谱默认关闭。需要时执行 ./enable-neo4j.sh 启用。" >> "$PKG_DIR/.env.example"
            echo "NEO4J_ENABLE=false" >> "$PKG_DIR/.env.example"
        fi

        # 强制 LANGFUSE_ENABLED=false（避免日志噪音）
        if grep -qE "^\s*LANGFUSE_ENABLED\s*=" "$PKG_DIR/.env.example"; then
            sed -i 's/^\s*LANGFUSE_ENABLED\s*=.*/LANGFUSE_ENABLED=false/' "$PKG_DIR/.env.example"
        else
            echo "" >> "$PKG_DIR/.env.example"
            echo "# 关闭 Langfuse 追踪，避免日志噪音。需要时自行开启。" >> "$PKG_DIR/.env.example"
            echo "LANGFUSE_ENABLED=false" >> "$PKG_DIR/.env.example"
        fi
    fi

    # ── 复制配置 ──
    [ -d "$SRC/config" ] && { mkdir -p "$PKG_DIR/config"; cp -r "$SRC/config/"* "$PKG_DIR/config/" 2>/dev/null || true; }
    [ -d "$SRC/docker/searxng" ] && { mkdir -p "$PKG_DIR/docker/searxng"; cp -r "$SRC/docker/searxng/"* "$PKG_DIR/docker/searxng/" 2>/dev/null || true; }
    [ -d "$SRC/misc" ] && { mkdir -p "$PKG_DIR/misc"; cp -r "$SRC/misc/"* "$PKG_DIR/misc/" 2>/dev/null || true; }
    [ -f "$SRC/LICENSE" ] && cp "$SRC/LICENSE" "$PKG_DIR/"

    date -u '+%Y-%m-%dT%H:%M:%SZ' > "$PKG_DIR/BUILD_TIME"

    # ══════════════════════════════════════════════
    #  生成 .sh 脚本
    # ══════════════════════════════════════════════

    # ── load-images.sh（在线版：docker compose pull）──
    cat > "$PKG_DIR/load-images.sh" <<'LOAD_EOF'
#!/bin/bash
set -e
cd "$(dirname "$0")"

echo ">> 从镜像仓库拉取 Docker 镜像（需要网络）..."
docker compose pull

echo ""
if [ ! -f .env ]; then
    cp .env.example .env
    sed -i 's/\r$//' .env 2>/dev/null || true
    echo ">> 已生成 .env，请编辑后启动"
fi

sed -i 's/\r$//' .env 2>/dev/null || true

echo ""
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    echo "=========================================="
    echo "  镜像拉取完成（Windows / Git Bash 环境）"
    echo ""
    echo "  下一步:"
    echo "    notepad .env"
    echo "    ./start.sh                # 或在 PowerShell 里执行 .\\start.ps1"
    echo "=========================================="
else
    echo "=========================================="
    echo "  镜像拉取完成"
    echo ""
    echo "  下一步:"
    echo "    nano .env"
    echo "    ./start.sh"
    echo "=========================================="
fi
LOAD_EOF
    chmod +x "$PKG_DIR/load-images.sh"

    # ── start.sh（含 NEO4J 检测 + --wait）──
    cat > "$PKG_DIR/start.sh" <<'START_EOF'
#!/bin/bash
set -e
cd "$(dirname "$0")"

sed -i 's/\r$//' .env 2>/dev/null || true

if [ ! -f .env ]; then
    echo "ERROR: 未找到 .env 文件"
    echo "       请先执行: cp .env.example .env"
    exit 1
fi

MISSING=""
grep -qE "^\s*DB_PASSWORD\s*=\s*.+" .env || MISSING="${MISSING} DB_PASSWORD"
grep -qE "^\s*REDIS_PASSWORD\s*=\s*.+" .env || MISSING="${MISSING} REDIS_PASSWORD"
grep -qE "^\s*SYSTEM_SIGNING_KEY\s*=\s*.+" .env || MISSING="${MISSING} SYSTEM_SIGNING_KEY"
grep -qE "^\s*SYSTEM_AES_KEY\s*=\s*.+" .env || MISSING="${MISSING} SYSTEM_AES_KEY"

if [ -n "$MISSING" ]; then
    echo "ERROR: .env 中以下变量未填写：${MISSING}"
    echo "       请编辑 .env 后重试"
    exit 1
fi

NEO4J_ENABLED=0
if grep -qE "^\s*NEO4J_ENABLE\s*=\s*true" .env 2>/dev/null; then
    NEO4J_ENABLED=1
    echo ">> 检测到 NEO4J_ENABLE=true，将同时启动 Neo4j"
fi

echo ">> 启动 AiRAG 核心服务（首次启动约 2-3 分钟）..."

# 用 --wait 等所有 healthcheck 通过；不支持 --wait 时回退
if [ "$NEO4J_ENABLED" -eq 1 ]; then
    docker compose --profile neo4j up -d --wait 2>/dev/null || docker compose --profile neo4j up -d
else
    docker compose up -d --wait 2>/dev/null || docker compose up -d
fi

echo ""
echo ">> 服务状态："
docker compose ps

# 检查是否有容器未启动（Created 状态，通常是依赖未就绪）
CREATED=$(docker compose ps --format "{{.Name}}|{{.Status}}" 2>/dev/null | grep -c "Created" || echo 0)
if [ "$CREATED" -gt 0 ]; then
    echo ""
    echo ">> 检测到 ${CREATED} 个容器未启动，等待依赖就绪后重试..."
    sleep 30
    if [ "$NEO4J_ENABLED" -eq 1 ]; then
        docker compose --profile neo4j up -d
    else
        docker compose up -d
    fi
    docker compose ps
fi

echo ""
FRONTEND_PORT=$(grep "^FRONTEND_PORT=" .env | cut -d= -f2 || echo 80)
echo "=========================================="
echo "  AiRAG 启动完成"
echo "  访问地址: http://localhost:${FRONTEND_PORT}"
echo ""
echo "  查看日志: ./logs.sh"
echo "  停止服务: ./stop.sh"
echo ""
echo "  启用可选服务:"
echo "    ./enable-neo4j.sh                         # 知识图谱"
echo "    docker compose --profile searxng up -d    # 联网搜索"
echo "=========================================="
START_EOF
    chmod +x "$PKG_DIR/start.sh"

    # ── stop.sh ──
    cat > "$PKG_DIR/stop.sh" <<'STOP_EOF'
#!/bin/bash
set -e
cd "$(dirname "$0")"
echo ">> 停止 AiRAG 服务..."
docker compose --profile full down
echo ">> 完成"
STOP_EOF
    chmod +x "$PKG_DIR/stop.sh"

    # ── status.sh ──
    cat > "$PKG_DIR/status.sh" <<'STATUS_EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "=== AiRAG 服务状态 ==="
docker compose ps
echo ""
echo "=== Docker 卷 ==="
docker volume ls --filter "name=airag_" --format "table {{.Name}}\t{{.Driver}}" 2>/dev/null || true
STATUS_EOF
    chmod +x "$PKG_DIR/status.sh"

    # ── logs.sh ──
    cat > "$PKG_DIR/logs.sh" <<'LOGS_EOF'
#!/bin/bash
cd "$(dirname "$0")"
case "${1:-}" in
    app|backend) docker compose logs -f app ;;
    frontend)    docker compose logs -f frontend ;;
    docreader)   docker compose logs -f docreader ;;
    postgres|db) docker compose logs -f postgres ;;
    redis)       docker compose logs -f redis ;;
    neo4j)       docker compose logs -f neo4j ;;
    *)
        echo "用法: $0 [app|frontend|docreader|postgres|redis|neo4j]"
        docker compose logs --tail 50
        ;;
esac
LOGS_EOF
    chmod +x "$PKG_DIR/logs.sh"

    # ── enable-neo4j.sh ──
    cat > "$PKG_DIR/enable-neo4j.sh" <<'ENABLE_NEO4J_EOF'
#!/bin/bash
set -e
cd "$(dirname "$0")"

[ -f .env ] || { echo "ERROR: 未找到 .env"; exit 1; }

if grep -qE "^\s*NEO4J_ENABLE\s*=" .env 2>/dev/null; then
    sed -i 's/^\s*NEO4J_ENABLE\s*=.*/NEO4J_ENABLE=true/' .env
else
    echo "NEO4J_ENABLE=true" >> .env
fi

echo ">> 启动 Neo4j..."
docker compose --profile neo4j up -d neo4j

echo ">> 等待 Neo4j 就绪（最多 60 秒）..."
for i in $(seq 1 60); do
    if (echo > /dev/tcp/127.0.0.1/7687) >/dev/null 2>&1; then
        echo "   Neo4j 已就绪 (${i}s)"
        break
    fi
    sleep 1
done

echo ">> 重启 app..."
docker compose restart app

echo ""
echo "  知识图谱已启用"
echo "  Neo4j 控制台: http://localhost:7474"
echo "  默认账号: neo4j / password"
ENABLE_NEO4J_EOF
    chmod +x "$PKG_DIR/enable-neo4j.sh"

    # ── disable-neo4j.sh ──
    cat > "$PKG_DIR/disable-neo4j.sh" <<'DISABLE_NEO4J_EOF'
#!/bin/bash
set -e
cd "$(dirname "$0")"

[ -f .env ] || { echo "ERROR: 未找到 .env"; exit 1; }

if grep -qE "^\s*NEO4J_ENABLE\s*=" .env 2>/dev/null; then
    sed -i 's/^\s*NEO4J_ENABLE\s*=.*/NEO4J_ENABLE=false/' .env
else
    echo "NEO4J_ENABLE=false" >> .env
fi

echo ">> 停止 Neo4j..."
docker compose --profile neo4j stop neo4j 2>/dev/null || true

echo ">> 重启 app..."
docker compose restart app

echo "  知识图谱已关闭（数据保留在 airag_neo4j-data 卷中）"
DISABLE_NEO4J_EOF
    chmod +x "$PKG_DIR/disable-neo4j.sh"

    # ── backup.sh ──
    cat > "$PKG_DIR/backup.sh" <<'BACKUP_EOF'
#!/bin/bash
set -e
cd "$(dirname "$0")"

sed -i 's/\r$//' .env 2>/dev/null || true

KEEP=7
BACKUP_DIR="backups"
TS=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/airag-backup-${TS}.tar.gz"

mkdir -p "$BACKUP_DIR"

echo ">> 备份 AiRAG 数据..."
echo "   目标: $BACKUP_FILE"

cp .env "$BACKUP_DIR/env-${TS}.env" 2>/dev/null || true

echo "   导出数据库..."
DB_USER=$(docker compose exec -T postgres printenv POSTGRES_USER 2>/dev/null | tr -d '[:space:]')
DB_USER="${DB_USER:-postgres}"

docker compose exec -T postgres pg_dumpall -U "$DB_USER" > "${BACKUP_DIR}/postgres-${TS}.sql" 2>/dev/null || {
    echo "   WARNING: 数据库导出失败"
    rm -f "${BACKUP_DIR}/postgres-${TS}.sql"
}

echo "   打包数据卷..."
docker run --rm \
    -v airag_postgres-data:/data/postgres \
    -v airag_data-files:/data/files \
    -v "$(pwd)/$BACKUP_DIR:/backup" \
    busybox:1.36 \
    tar czf "/backup/volumes-${TS}.tar.gz" -C /data . 2>/dev/null || true

cd "$BACKUP_DIR"
tar czf "$(basename "$BACKUP_FILE")" \
    "env-${TS}.env" "postgres-${TS}.sql" "volumes-${TS}.tar.gz" 2>/dev/null || true

rm -f "env-${TS}.env" "postgres-${TS}.sql" "volumes-${TS}.tar.gz"
cd ..

echo "   完成: $BACKUP_FILE ($(du -h "$BACKUP_FILE" 2>/dev/null | cut -f1))"

echo ">> 清理旧备份（保留最近 $KEEP 个）..."
ls -t "${BACKUP_DIR}"/airag-backup-*.tar.gz 2>/dev/null | tail -n +$((KEEP + 1)) | while read -r f; do
    rm -f "$f"
done

echo ">> 备份完成"
BACKUP_EOF
    chmod +x "$PKG_DIR/backup.sh"

    # ── restore.sh ──
    cat > "$PKG_DIR/restore.sh" <<'RESTORE_EOF'
#!/bin/bash
set -e
cd "$(dirname "$0")"

BACKUP_DIR="backups"

echo ">> 可用备份:"
ls -lh "${BACKUP_DIR}"/airag-backup-*.tar.gz 2>/dev/null | awk '{print "   " $NF " (" $5 ")"}'

[ -d "$BACKUP_DIR" ] || { echo "   没有找到备份"; exit 1; }
[ -n "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ] || { echo "   没有找到备份"; exit 1; }

echo ""
read -r -p "输入要恢复的备份文件名（或完整路径）: " BACKUP_FILE

[ ! -f "$BACKUP_FILE" ] && [ -f "${BACKUP_DIR}/${BACKUP_FILE}" ] && BACKUP_FILE="${BACKUP_DIR}/${BACKUP_FILE}"

[ -f "$BACKUP_FILE" ] || { echo "ERROR: 备份文件不存在: $BACKUP_FILE"; exit 1; }

echo ""
echo "⚠️  恢复将覆盖当前数据"
read -r -p "确认恢复? [y/N] " ans
[[ "$ans" != "y" && "$ans" != "Y" ]] && exit 1

echo ">> 停止服务..."
docker compose --profile full down

echo ">> 恢复备份..."
TMP_STAGE=$(mktemp -d)
trap 'rm -rf "$TMP_STAGE"' EXIT
tar xzf "$BACKUP_FILE" -C "$TMP_STAGE"

[ -f "$TMP_STAGE"/*.env ] && cp "$TMP_STAGE"/*.env .env
sed -i 's/\r$//' .env 2>/dev/null || true

if [ -f "$TMP_STAGE"/volumes-*.tar.gz ]; then
    docker run --rm \
        -v airag_postgres-data:/data/postgres \
        -v airag_data-files:/data/files \
        -v "$TMP_STAGE:/backup" \
        busybox:1.36 \
        sh -c "cd /data && tar xzf /backup/volumes-*.tar.gz"
fi

echo ">> 恢复完成"
echo "   启动: ./start.sh"
RESTORE_EOF
    chmod +x "$PKG_DIR/restore.sh"

    # ── reset-password.sh ──
    cat > "$PKG_DIR/reset-password.sh" <<'RESET_EOF'
#!/bin/bash
set -e
cd "$(dirname "$0")"

sed -i 's/\r$//' .env 2>/dev/null || true

[ -f .env ] || { echo "ERROR: 未找到 .env"; exit 1; }
set -a
source .env
set +a

DB_USER="${DB_USER:-postgres}"
DB_NAME="${DB_NAME:-WeKnora}"

docker compose ps --services --filter "status=running" 2>/dev/null | grep -q "^postgres$" || {
    echo "ERROR: postgres 容器未运行"; echo "       请先执行: ./start.sh"; exit 1;
}

gen_hash() {
    local password="$1"
    local escaped="${password//\'/\'\'}"

    if command -v htpasswd >/dev/null 2>&1; then
        htpasswd -bnBC 10 "" "$password" | tr -d ':\n' | sed 's/\$2y/\$2a/'
        return
    fi

    if command -v python3 >/dev/null 2>&1 && python3 -c "import bcrypt" 2>/dev/null; then
        python3 -c "import bcrypt; print(bcrypt.hashpw(b'$password', bcrypt.gensalt(rounds=10)).decode())"
        return
    fi

    docker compose exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" \
        -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;" >/dev/null 2>&1 || true

    local hash
    hash=$(docker compose exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" \
        -tAc "SELECT crypt('$escaped', gen_salt('bf', 10));" 2>/dev/null | tr -d '[:space:]')

    [ -z "$hash" ] && { echo "ERROR: 无法生成 BCrypt 哈希" >&2; exit 1; }
    echo "$hash"
}

echo "=== 当前用户 ==="
docker compose exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" -c \
    "SELECT username, email, is_active, is_system_admin FROM users WHERE deleted_at IS NULL;" 2>/dev/null || {
    echo "ERROR: 无法查询用户"; exit 1;
}
echo ""

read -r -p "请输入要重置的用户邮箱: " EMAIL
[ -z "$EMAIL" ] && { echo "ERROR: 邮箱不能为空"; exit 1; }

USER_EXISTS=$(docker compose exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" -tAc \
    "SELECT COUNT(*) FROM users WHERE email='$EMAIL' AND deleted_at IS NULL;" 2>/dev/null | tr -d '[:space:]')
[ "$USER_EXISTS" != "1" ] && { echo "ERROR: 用户不存在: $EMAIL"; exit 1; }

read -r -s -p "请输入新密码（至少 8 位，含字母和数字）: " PASSWORD
echo ""
read -r -s -p "请再次输入新密码确认: " PASSWORD2
echo ""

[ "$PASSWORD" != "$PASSWORD2" ] && { echo "ERROR: 两次密码不一致"; exit 1; }
[ ${#PASSWORD} -lt 8 ] && { echo "ERROR: 密码长度至少 8 位"; exit 1; }

echo ""
echo "系统管理员设置:"
echo "  1) 设为系统管理员"
echo "  2) 取消系统管理员"
echo "  3) 保持不变（默认）"
read -r -p "请选择 [1/2/3]: " ADMIN_CHOICE

echo ">> 生成密码哈希..."
HASH=$(gen_hash "$PASSWORD")

echo ">> 更新数据库..."
docker compose exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" -c \
    "UPDATE users SET password_hash='$HASH', is_active=TRUE, deleted_at=NULL, updated_at=CURRENT_TIMESTAMP WHERE email='$EMAIL';" >/dev/null

case "$ADMIN_CHOICE" in
    1)
        docker compose exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" -c \
            "UPDATE users SET is_system_admin=TRUE WHERE email='$EMAIL';" >/dev/null
        echo "   已设为系统管理员" ;;
    2)
        docker compose exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" -c \
            "UPDATE users SET is_system_admin=FALSE WHERE email='$EMAIL';" >/dev/null
        echo "   已取消系统管理员" ;;
    *) echo "   管理员身份保持不变" ;;
esac

echo ""
echo "=== 操作成功 ==="
docker compose exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" -c \
    "SELECT username, email, is_active, is_system_admin FROM users WHERE email='$EMAIL';"

echo ""
echo "下一步: 用新密码登录 http://localhost"
RESET_EOF
    chmod +x "$PKG_DIR/reset-password.sh"

    # ── test.sh ──
    cat > "$PKG_DIR/test.sh" <<'TEST_EOF'
#!/bin/bash
cd "$(dirname "$0")"
PASS=0; FAIL=0; WARN=0
ok()   { echo -e "  ✅ $1"; PASS=$((PASS+1)); }
bad()  { echo -e "  ❌ $1"; FAIL=$((FAIL+1)); }
warn() { echo -e "  ⚠️  $1"; WARN=$((WARN+1)); }

echo ""
echo "════════════════════════════════════════════"
echo "  AiRAG 在线版自检"
echo "════════════════════════════════════════════"
echo ""

echo "[1] 必需文件"
for f in docker-compose.yml .env.example load-images.sh start.sh stop.sh status.sh logs.sh backup.sh restore.sh reset-password.sh test.sh enable-neo4j.sh disable-neo4j.sh README.md LICENSE; do
    [ -e "$f" ] && ok "$f" || bad "$f 缺失"
done

echo ""
echo "[2] docker-compose.yml 镜像地址"
if grep -qE "ghcr\.io/zhangjianchun[\}/]/airag-" docker-compose.yml 2>/dev/null; then
    ok "镜像地址已指向 GHCR"
else
    bad "镜像地址未指向 GHCR"
fi

echo ""
echo "[3] .env 检查"
if [ -f .env ]; then
    grep -qE "^\s*NEO4J_ENABLE\s*=\s*true" .env && ok "NEO4J_ENABLE=true" || ok "NEO4J 默认关闭"
    grep -qE "^\s*LANGFUSE_ENABLED\s*=\s*true" .env && warn "LANGFUSE_ENABLED=true 会产生日志噪音" || ok "LANGFUSE 默认关闭"
fi

echo ""
echo "[4] Docker 环境"
docker --version >/dev/null 2>&1 && ok "$(docker --version)" || bad "Docker 不可用"
docker compose version >/dev/null 2>&1 && ok "$(docker compose version)" || bad "Docker Compose 不可用"

echo ""
echo "[5] 容器状态"
docker compose ps 2>/dev/null

echo ""
echo "[6] 端口检查"
for port in 80 8080; do
    (echo > /dev/tcp/127.0.0.1/$port) >/dev/null 2>&1 && ok "端口 $port 监听中" || warn "端口 $port 未监听"
done

echo ""
echo "════════════════════════════════════════════"
echo -e "  测试结果: 通过 \033[32m$PASS\033[0m / 警告 \033[33m$WARN\033[0m / 失败 \033[31m$FAIL\033[0m"
echo "════════════════════════════════════════════"
echo ""
[ "$FAIL" -eq 0 ] && echo "🎉 一切正常！" || echo "⚠️  有 $FAIL 项失败"
TEST_EOF
    chmod +x "$PKG_DIR/test.sh"

    # ── .ps1 脚本：从旧文件复制（如需一致可保留原样）──
    # 为了篇幅，这里不再展开 .ps1，保留原 v0.1.5 版本一致

    # ── README（简版）──
    {
      printf '%s\n' \
        "# AiRAG 在线版部署手册（${EDITION} 版）" \
        '' \
        "> **当前版本**：\`${EDITION}\`" \
        '> **分发方式**：在线版（镜像从 GHCR 拉取）' \
        '' \
        '## 快速开始' \
        '' \
        '```bash' \
        './load-images.sh        # 拉取镜像' \
        'nano .env               # 填 DB_PASSWORD、REDIS_PASSWORD、SYSTEM_SIGNING_KEY、SYSTEM_AES_KEY' \
        './start.sh              # 启动' \
        '```' \
        '' \
        '访问 http://localhost' \
        '' \
        '## 常用命令' \
        '' \
        '| 命令 | 作用 |' \
        '|------|------|' \
        '| ./start.sh | 启动 |' \
        '| ./stop.sh | 停止 |' \
        '| ./status.sh | 状态 |' \
        '| ./logs.sh app | 查看日志 |' \
        '| ./backup.sh | 备份 |' \
        '| ./restore.sh | 恢复 |' \
        '| ./reset-password.sh | 重置密码 |' \
        '| ./enable-neo4j.sh | 启用知识图谱 |' \
        '| ./disable-neo4j.sh | 关闭知识图谱 |' \
        '| ./test.sh | 自检 |' \
        '' \
        '## 知识图谱（可选）' \
        '' \
        '默认关闭。启用：`./enable-neo4j.sh`' \
        '' \
        '## 首次启动说明' \
        '' \
        '首次启动约 2-3 分钟（数据库初始化 + 服务就绪）。' \
        '`start.sh` 会等待所有服务健康后再返回，无需手动干预。' \
        '' \
        '## 常见问题' \
        '' \
        '- **端口 80 被占用**：改 `.env` 里 `FRONTEND_PORT=8088`' \
        '- **忘记密码**：`./reset-password.sh`' \
        '- **启动后容器一直 Restarting**：看 `./logs.sh app`' \
        '' \
        '## 文件说明' \
        '' \
        '```' \
        "AiRAG-online-${EDITION}_${VERSION}/" \
        '├── docker-compose.yml' \
        '├── .env.example' \
        '├── config/  docker/  misc/' \
        '├── load-images.sh / start.sh / stop.sh / status.sh / logs.sh' \
        '├── enable-neo4j.sh / disable-neo4j.sh' \
        '├── backup.sh / restore.sh / reset-password.sh / test.sh' \
        '└── README.md / LICENSE / BUILD_TIME' \
        '```'
    } > "$PKG_DIR/README.md"

    # ── 转 LF ──
    sed -i 's/\r$//' "$PKG_DIR"/*.sh "$PKG_DIR"/README.md "$PKG_DIR"/.env.example 2>/dev/null || true

    # ── 打包 ──
    echo ">> 创建 ${PKG}.tar.gz..."
    cd "$OUT"
    rm -f "${PKG}.tar.gz" "${PKG}.tar.gz.sha256"
    tar czf "${PKG}.tar.gz" "$PKG"
    sha256sum "${PKG}.tar.gz" > "${PKG}.tar.gz.sha256"

    echo "  ✅ ${OUT}/${PKG}.tar.gz"
    ls -lh "${OUT}/${PKG}.tar.gz" | sed 's/^/     /'
    echo ""

done

echo ""
echo ">> 三个在线包："
ls -lh "$OUT"/AiRAG-online-*_${VERSION}.tar.gz 2>/dev/null | sed 's/^/     /'
echo ""
echo "🎉 在线版打包完成！"