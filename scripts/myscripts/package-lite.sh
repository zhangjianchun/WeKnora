#!/bin/bash
set -e

VERSION="${1:-v0.1.0}"
SRC="$HOME/WeKnora"
PKG="AiRAG-lite_${VERSION}_linux_amd64"
OUT="$HOME/release"

# 用 $HOME 避免写死用户名
GOJIEBA_DICT="${HOME}/go/pkg/mod/github.com/yanyiwu/gojieba@v1.4.7/deps/cppjieba/dict"

echo "=== WeKnora Lite Packager ==="
echo "  Version : ${VERSION}"
echo "  Output  : ${OUT}/${PKG}.tar.gz"
echo ""

# ── 前置检查 ──
if [ ! -f "$SRC/WeKnora-lite" ]; then
  echo "ERROR: 未找到 $SRC/WeKnora-lite，请先构建 Go 二进制"
  exit 1
fi

if [ ! -f "$SRC/frontend/dist/index.html" ]; then
  echo "ERROR: $SRC/frontend/dist/index.html 不存在"
  echo "       请先在 Windows 侧执行: cd frontend && npm run build"
  exit 1
fi

if [ ! -f "$SRC/docreader/dist/docreader-server" ]; then
  echo "ERROR: 未找到 $SRC/docreader/dist/docreader-server"
  echo "       请先在 docreader 目录执行 PyInstaller 打包"
  exit 1
fi

if [ ! -f "$SRC/LICENSE" ]; then
  echo "ERROR: $SRC/LICENSE 不存在，MIT 合规要求保留原始许可证"
  exit 1
fi

echo ">> 检查通过"
echo ""

# ── 清理旧目录 ──
echo ">> 清理旧目录..."
if [ -d "$OUT/$PKG" ]; then
  rm -rf "$OUT/$PKG" 2>/dev/null || sudo rm -rf "$OUT/$PKG"
fi

# ── 准备打包目录 ──
echo ">> 准备打包目录..."
mkdir -p "$OUT/$PKG"
cd "$OUT/$PKG"

cp "$SRC/WeKnora-lite" .
cp -r "$SRC/config" .
cp -r "$SRC/migrations" .
mkdir -p web
cp -r "$SRC/frontend/dist/"* web/
cp "$SRC/.env.lite.example" .env

# ── 复制 gojieba 词典 ──
if [ -d "$GOJIEBA_DICT" ]; then
  echo ">> 复制 gojieba 词典..."
  mkdir -p gojieba-dict
  cp -r "$GOJIEBA_DICT/"* gojieba-dict/
else
  echo "WARNING: gojieba 词典不存在: $GOJIEBA_DICT"
  echo "         请确认路径，或手动修改脚本中的 GOJIEBA_DICT 变量"
fi

# ── 复制 docreader-server 二进制 ──
echo ">> 复制 docreader-server..."
cp "$SRC/docreader/dist/docreader-server" .
chmod +x docreader-server

# ── 许可证（MIT 合规必需）──
echo ">> 复制 LICENSE..."
cp "$SRC/LICENSE" ./LICENSE

# ── 品牌说明（只复制公开版，不含内部隐藏功能记录）──
if [ -f "$SRC/BRANDING-PUBLIC.md" ]; then
  echo ">> 复制 BRANDING.md..."
  cp "$SRC/BRANDING-PUBLIC.md" ./BRANDING.md
fi

# ── README ──
if [ -f "$SRC/docs/LITE.md" ]; then
  cp "$SRC/docs/LITE.md" ./README.md
elif [ -f "$SRC/README.md" ]; then
  cp "$SRC/README.md" ./
fi

# ── 构建时间戳 ──
BUILD_TIME=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
echo "$BUILD_TIME" > BUILD_TIME

# ══════════════════════════════════════════════
#  生成 install.sh
# ══════════════════════════════════════════════
cat > install.sh <<'INSTALL_EOF'
#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

GOJIEBA_PATH="${HOME}/go/pkg/mod/github.com/yanyiwu/gojieba@v1.4.7/deps/cppjieba/dict"

if [ -d "${GOJIEBA_PATH}" ]; then
    echo "词典已存在，跳过"
    exit 0
fi

if [ ! -d "./gojieba-dict" ]; then
    echo "ERROR: gojieba-dict 目录不存在"
    exit 1
fi

echo "需要管理员权限部署词典，请输入密码："
sudo mkdir -p "${GOJIEBA_PATH}"
sudo cp -r ./gojieba-dict/* "${GOJIEBA_PATH}/"
sudo chmod -R 755 "${GOJIEBA_PATH}"
echo "部署完成"
INSTALL_EOF
chmod +x install.sh

# ══════════════════════════════════════════════
#  生成运维脚本
# ══════════════════════════════════════════════
echo ">> 生成运维脚本..."

# ── start.sh ──
cat > start.sh <<'START_EOF'
#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

GOJIEBA_PATH="${HOME}/go/pkg/mod/github.com/yanyiwu/gojieba@v1.4.7/deps/cppjieba/dict"
if [ ! -d "${GOJIEBA_PATH}" ]; then
    echo "ERROR: gojieba 词典未部署，请先执行 ./install.sh"
    exit 1
fi

# 加载环境变量
if [ -f .env ]; then
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
fi

mkdir -p logs data
chmod +x ./WeKnora-lite ./docreader-server 2>/dev/null || true

# 检查是否已在运行
if [ -f .airag.pid ] && kill -0 "$(cat .airag.pid)" 2>/dev/null; then
    echo "AI 知识库已在运行 (PID: $(cat .airag.pid))"
    echo "如需重启，请执行 ./restart.sh"
    exit 1
fi

# ── 启动 docreader ──
DOCREADER_PID=""
if [ -f "./docreader-server" ]; then
    echo ">> 启动 docreader..."
    nohup ./docreader-server > logs/docreader.log 2>&1 &
    DOCREADER_PID=$!
    echo "$DOCREADER_PID" > .docreader.pid

    READY=0
    for i in $(seq 1 30); do
        if (echo > /dev/tcp/127.0.0.1/50051) >/dev/null 2>&1; then
            echo "   docreader 已就绪 (${i}s, PID: ${DOCREADER_PID})"
            READY=1
            break
        fi
        sleep 1
    done
    if [ "$READY" -ne 1 ]; then
        echo "   WARNING: docreader 未在 30 秒内就绪，PDF/Word 解析可能不可用"
    fi
else
    echo "WARNING: docreader-server 不存在，PDF/Word 解析不可用"
fi

# ── 启动主程序 ──
echo ">> 启动 AI 知识库..."
nohup ./WeKnora-lite > logs/airag.log 2>&1 &
MAIN_PID=$!
echo "$MAIN_PID" > .airag.pid

PORT="${SERVER_PORT:-8080}"
READY=0
for i in $(seq 1 30); do
    if (echo > /dev/tcp/127.0.0.1/"$PORT") >/dev/null 2>&1; then
        echo "   AI 知识库已就绪 (${i}s, PID: ${MAIN_PID})"
        READY=1
        break
    fi
    sleep 1
done

if [ "$READY" -ne 1 ]; then
    echo "   ERROR: AI 知识库未在 30 秒内就绪，请查看 logs/airag.log"
    exit 1
fi

echo ""
echo "=========================================="
echo "  AI 知识库启动成功"
echo "  访问地址: http://localhost:${PORT}"
echo "  查看日志: ./logs.sh"
echo "  停止服务: ./stop.sh"
echo "=========================================="
START_EOF

# ── stop.sh ──
cat > stop.sh <<'STOP_EOF'
#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

stop_process() {
    local name="$1"
    local pidfile="$2"
    if [ ! -f "$pidfile" ]; then
        echo "   $name 未在运行（无 PID 文件）"
        return
    fi
    local pid
    pid=$(cat "$pidfile")
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "   $name 进程不存在，清理 PID 文件"
        rm -f "$pidfile"
        return
    fi

    echo "   停止 $name (PID: $pid)..."
    kill "$pid" 2>/dev/null || true

    for i in $(seq 1 10); do
        if ! kill -0 "$pid" 2>/dev/null; then
            echo "   $name 已停止"
            rm -f "$pidfile"
            return
        fi
        sleep 1
    done

    echo "   $name 未响应，强制终止..."
    kill -9 "$pid" 2>/dev/null || true
    rm -f "$pidfile"
    echo "   $name 已强制终止"
}

echo ">> 停止服务..."
# 先停主程序，再停 docreader（顺序不能反）
stop_process "AI 知识库" ".airag.pid"
stop_process "docreader" ".docreader.pid"
echo ">> 完成"
STOP_EOF

# ── restart.sh ──
cat > restart.sh <<'RESTART_EOF'
#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
./stop.sh
sleep 2
./start.sh
RESTART_EOF

# ── status.sh ──
cat > status.sh <<'STATUS_EOF'
#!/usr/bin/env bash
cd "$(dirname "$0")"

check_proc() {
    local name="$1" pidfile="$2"
    if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
        local pid uptime
        pid=$(cat "$pidfile")
        uptime=$(ps -o etime= -p "$pid" 2>/dev/null | tr -d ' ')
        echo "  ✅ $name 运行中 (PID: $pid, 运行: $uptime)"
    else
        echo "  ❌ $name 未运行"
    fi
}

check_port() {
    local port="$1"
    if timeout 1 bash -c "echo > /dev/tcp/127.0.0.1/$port" 2>/dev/null; then
        echo "  ✅ $port 监听中"
    else
        echo "  ❌ $port 未监听"
    fi
}

echo "=== AI 知识库状态 ==="
check_proc "AI 知识库" ".airag.pid"
check_proc "docreader" ".docreader.pid"

echo ""
echo "=== 端口 ==="
check_port 8080
check_port 50051

echo ""
echo "=== 磁盘占用 ==="
du -sh data 2>/dev/null || echo "  data/ 不存在"
du -sh logs 2>/dev/null || echo "  logs/ 不存在"
du -sh backups 2>/dev/null || echo "  backups/ 不存在"
STATUS_EOF

# ── backup.sh ──
cat > backup.sh <<'BACKUP_EOF'
#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

KEEP=7
BACKUP_DIR="backups"
TS=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/airag-backup-${TS}.tar.gz"

mkdir -p "$BACKUP_DIR"

echo ">> 备份 AI 知识库..."
echo "   目标: $BACKUP_FILE"

if [ -f .airag.pid ] && kill -0 "$(cat .airag.pid)" 2>/dev/null; then
    echo "   ⚠️  服务正在运行，建议先 ./stop.sh 再备份，确保数据一致"
    read -r -p "   继续备份? [y/N] " ans
    [[ "$ans" != "y" && "$ans" != "Y" ]] && exit 1
fi

TMP_STAGE=$(mktemp -d)
cleanup() {
    rm -rf "$TMP_STAGE" 2>/dev/null || sudo rm -rf "$TMP_STAGE" 2>/dev/null || true
}
trap cleanup EXIT

mkdir -p "$TMP_STAGE"

# 数据目录（SQLite + 上传文件）
[ -d data ] && cp -r data "$TMP_STAGE/"

# 配置
[ -f .env ] && cp .env "$TMP_STAGE/"
[ -d config ] && cp -r config "$TMP_STAGE/"

# 元信息
{
    echo "backup_time=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "hostname=$(hostname)"
    echo "version=$(cat BUILD_TIME 2>/dev/null || echo unknown)"
    echo "note=gojieba-dict 未包含，恢复后需重新执行 ./install.sh"
} > "$TMP_STAGE/BACKUP_INFO.txt"

tar czf "$BACKUP_FILE" -C "$TMP_STAGE" .

SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "   完成: $BACKUP_FILE ($SIZE)"

echo ">> 清理旧备份（保留最近 $KEEP 个）..."
ls -t "${BACKUP_DIR}"/airag-backup-*.tar.gz 2>/dev/null | tail -n +$((KEEP + 1)) | while read -r f; do
    echo "   删除: $f"
    rm -f "$f"
done

echo ">> 备份完成"
BACKUP_EOF

# ── restore.sh ──
cat > restore.sh <<'RESTORE_EOF'
#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

BACKUP_DIR="backups"

echo ">> 可用备份:"
if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
    echo "   没有找到备份"
    exit 1
fi

ls -lh "${BACKUP_DIR}"/airag-backup-*.tar.gz 2>/dev/null | awk '{print "   " $NF " (" $5 ")"}'

echo ""
read -r -p "输入要恢复的备份文件名（或完整路径）: " BACKUP_FILE

if [ ! -f "$BACKUP_FILE" ] && [ -f "${BACKUP_DIR}/${BACKUP_FILE}" ]; then
    BACKUP_FILE="${BACKUP_DIR}/${BACKUP_FILE}"
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "ERROR: 备份文件不存在: $BACKUP_FILE"
    exit 1
fi

echo ""
echo "⚠️  恢复将覆盖当前 data/、.env、config/ 目录"
read -r -p "确认恢复? [y/N] " ans
[[ "$ans" != "y" && "$ans" != "Y" ]] && exit 1

if [ -f .airag.pid ] && kill -0 "$(cat .airag.pid)" 2>/dev/null; then
    echo ">> 停止服务..."
    ./stop.sh
fi

SAFETY="backups/airag-pre-restore-$(date +%Y%m%d-%H%M%S).tar.gz"
echo ">> 保存当前状态到: $SAFETY"
tar czf "$SAFETY" data .env config 2>/dev/null || true

echo ">> 恢复备份..."
TMP_STAGE=$(mktemp -d)
cleanup() {
    rm -rf "$TMP_STAGE" 2>/dev/null || sudo rm -rf "$TMP_STAGE" 2>/dev/null || true
}
trap cleanup EXIT
tar xzf "$BACKUP_FILE" -C "$TMP_STAGE"

[ -d "$TMP_STAGE/data" ] && rm -rf data && cp -r "$TMP_STAGE/data" .
[ -f "$TMP_STAGE/.env" ] && cp "$TMP_STAGE/.env" .
[ -d "$TMP_STAGE/config" ] && rm -rf config && cp -r "$TMP_STAGE/config" .

echo ">> 恢复完成"
echo "   注意: 如果词典未部署，请先执行 ./install.sh"
echo "   启动: ./start.sh"
RESTORE_EOF

# ── logs.sh ──
cat > logs.sh <<'LOGS_EOF'
#!/usr/bin/env bash
cd "$(dirname "$0")"

case "${1:-}" in
    airag|main)
        tail -f logs/airag.log
        ;;
    docreader)
        tail -f logs/docreader.log
        ;;
    *)
        echo "用法: $0 [airag|docreader]"
        echo ""
        echo "最近 20 行 logs/airag.log:"
        echo "---"
        tail -20 logs/airag.log 2>/dev/null || echo "(无日志)"
        echo ""
        echo "最近 20 行 logs/docreader.log:"
        echo "---"
        tail -20 logs/docreader.log 2>/dev/null || echo "(无日志)"
        ;;
esac
LOGS_EOF

cat > reset-password.sh <<'RESET_EOF'
#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

DB="data/weknora.db"

# ── 前置检查 ──
if [ ! -f "$DB" ]; then
    echo "ERROR: 数据库不存在: $DB"
    echo "       请先启动一次服务，让系统初始化数据库"
    exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "ERROR: 未安装 sqlite3"
    echo "       Ubuntu/Debian: sudo apt install sqlite3 -y"
    echo "       CentOS/RHEL:   sudo yum install sqlite -y"
    exit 1
fi

# ── 生成 BCrypt 哈希 ──
gen_hash() {
    local password="$1"

    if command -v htpasswd >/dev/null 2>&1; then
        htpasswd -bnBC 10 "" "$password" | tr -d ':\n' | sed 's/\$2y/\$2a/'
        return
    fi

    if command -v python3 >/dev/null 2>&1; then
        if python3 -c "import bcrypt" 2>/dev/null; then
            python3 -c "import bcrypt; print(bcrypt.hashpw(b'$password', bcrypt.gensalt(rounds=10)).decode())"
            return
        fi
    fi

    echo "ERROR: 无法生成 BCrypt 哈希" >&2
    echo "       请安装 apache2-utils (htpasswd) 或 pip install bcrypt" >&2
    exit 1
}

# ── 列出当前用户 ──
echo "=== 当前用户 ==="
sqlite3 -header -column "$DB" \
    "SELECT username, email, is_active, is_system_admin FROM users WHERE deleted_at IS NULL;" 2>/dev/null || {
    echo "ERROR: 无法读取 users 表，数据库可能未初始化"
    exit 1
}
echo ""

# ── 输入信息 ──
read -r -p "请输入要重置的用户邮箱: " EMAIL
if [ -z "$EMAIL" ]; then
    echo "ERROR: 邮箱不能为空"
    exit 1
fi

USER_EXISTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE email='$EMAIL' AND deleted_at IS NULL;")
if [ "$USER_EXISTS" -eq 0 ]; then
    echo "ERROR: 用户不存在或已被删除: $EMAIL"
    exit 1
fi

read -r -s -p "请输入新密码（至少 8 位，含字母和数字）: " PASSWORD
echo ""
read -r -s -p "请再次输入新密码确认: " PASSWORD2
echo ""

if [ "$PASSWORD" != "$PASSWORD2" ]; then
    echo "ERROR: 两次输入的密码不一致"
    exit 1
fi

if [ ${#PASSWORD} -lt 8 ]; then
    echo "ERROR: 密码长度至少 8 位"
    exit 1
fi

# ── 管理员设置（三选一）──
echo ""
echo "系统管理员设置:"
echo "  1) 设为系统管理员"
echo "  2) 取消系统管理员"
echo "  3) 保持不变（默认）"
read -r -p "请选择 [1/2/3]: " ADMIN_CHOICE

# ── 停止服务 ──
if [ -f .airag.pid ] && kill -0 "$(cat .airag.pid)" 2>/dev/null; then
    echo ""
    echo ">> 停止服务..."
    ./stop.sh
fi

# ── 生成哈希 ──
echo ">> 生成密码哈希..."
HASH=$(gen_hash "$PASSWORD")

# ── 更新密码 ──
echo ">> 更新数据库..."
sqlite3 "$DB" "UPDATE users SET password_hash='$HASH', is_active=1, deleted_at=NULL, updated_at=CURRENT_TIMESTAMP WHERE email='$EMAIL';"

# ── 处理管理员设置 ──
HAS_FIELD=$(sqlite3 "$DB" "PRAGMA table_info(users);" | grep -c "is_system_admin" || true)
if [ "$HAS_FIELD" -gt 0 ]; then
    case "$ADMIN_CHOICE" in
        1)
            sqlite3 "$DB" "UPDATE users SET is_system_admin=1 WHERE email='$EMAIL';"
            echo "   已将 $EMAIL 设为系统管理员"
            ;;
        2)
            sqlite3 "$DB" "UPDATE users SET is_system_admin=0 WHERE email='$EMAIL';"
            echo "   已取消 $EMAIL 的系统管理员身份"
            ;;
        3|"")
            echo "   管理员身份保持不变"
            ;;
        *)
            echo "   WARNING: 无效选择 '$ADMIN_CHOICE'，管理员身份保持不变"
            ;;
    esac
else
    echo "   WARNING: users 表没有 is_system_admin 字段，跳过"
fi

# ── 验证 ──
UPDATED=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE email='$EMAIL' AND password_hash IS NOT NULL;")
if [ "$UPDATED" -eq 1 ]; then
    echo ""
    echo "=== 操作成功 ==="
    echo "  用户: $EMAIL"
    echo "  当前状态:"
    sqlite3 -header -column "$DB" \
        "SELECT username, email, is_active, is_system_admin FROM users WHERE email='$EMAIL';"
    echo ""
    echo "  下一步: 执行 ./start.sh 启动服务"
else
    echo "ERROR: 更新失败，请手动检查数据库"
    exit 1
fi
RESET_EOF


# ── 统一赋执行权限 ──
chmod +x start.sh stop.sh restart.sh status.sh backup.sh restore.sh logs.sh install.sh reset-password.sh

# ── 转 LF（去掉 Windows CRLF）──
sed -i 's/\r$//' .env start.sh stop.sh restart.sh status.sh backup.sh restore.sh logs.sh install.sh reset-password.sh

# ── 打包 ──
echo ">> 创建 tar.gz..."
cd "$OUT"
rm -f "${PKG}.tar.gz" "${PKG}.tar.gz.sha256"
tar czf "${PKG}.tar.gz" "$PKG"
sha256sum "${PKG}.tar.gz" > "${PKG}.tar.gz.sha256"

echo ""
echo "=== 打包完成 ==="
echo "  ${OUT}/${PKG}.tar.gz"
echo "  ${OUT}/${PKG}.tar.gz.sha256"
ls -lh "$OUT/${PKG}.tar.gz"