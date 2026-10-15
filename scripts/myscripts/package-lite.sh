#!/bin/bash
set -eo pipefail
VERSION="${1:-v0.1.0}"
SRC="$HOME/WeKnora"
PKG="AiRAG-lite_${VERSION}_linux_amd64"
OUT="$HOME/release"
GOJIEBA_DICT="${HOME}/go/pkg/mod/github.com/yanyiwu/gojieba@v1.4.7/deps/cppjieba/dict"

write_ps1() {
    local outfile="$1"
    local content="$2"
    printf '\xef\xbb\xbf' > "$outfile"
    printf "%s" "$content" >> "$outfile"
}

echo "=== AiRAG Lite Packager ==="
echo "  Version : ${VERSION}"
echo "  Output  : ${OUT}/${PKG}.tar.gz"
echo ""

# ── 前置检查 ──
[ -f "$SRC/WeKnora-lite" ] || { echo "ERROR: 未找到 $SRC/WeKnora-lite"; exit 1; }
[ -f "$SRC/frontend/dist/index.html" ] || { echo "ERROR: 未找到前端 dist"; exit 1; }
[ -f "$SRC/docreader/dist/docreader-server" ] || { echo "ERROR: 未找到 docreader-server"; exit 1; }
[ -f "$SRC/LICENSE" ] || { echo "ERROR: 未找到 LICENSE"; exit 1; }
echo ">> 检查通过"
echo ""

rm -rf "$OUT/$PKG" 2>/dev/null || sudo rm -rf "$OUT/$PKG"
mkdir -p "$OUT/$PKG"
cd "$OUT/$PKG"

cp "$SRC/WeKnora-lite" .
cp -r "$SRC/config" .
cp -r "$SRC/migrations" .
mkdir -p web
cp -r "$SRC/frontend/dist/"* web/
cp "$SRC/.env.lite.example" .env

if [ -d "$GOJIEBA_DICT" ]; then
    mkdir -p gojieba-dict
    cp -r "$GOJIEBA_DICT/"* gojieba-dict/
else
    echo "WARNING: gojieba 词典源目录不存在: $GOJIEBA_DICT"
fi

cp "$SRC/docreader/dist/docreader-server" .
chmod +x docreader-server
cp "$SRC/LICENSE" .
[ -f "$SRC/docs/LITE.md" ] && cp "$SRC/docs/LITE.md" ./README.md
[ -f "$SRC/BRANDING-PUBLIC.md" ] && cp "$SRC/BRANDING-PUBLIC.md" ./BRANDING.md
date -u '+%Y-%m-%dT%H:%M:%SZ' > BUILD_TIME

# ══════════════════════════════════════════════
#  .sh 脚本
# ══════════════════════════════════════════════
cat > install.sh <<'INSTALL_EOF'
#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")"
# 注意：目标路径为系统go mod缓存路径，需要sudo权限
GOJIEBA_PATH="${HOME}/go/pkg/mod/github.com/yanyiwu/gojieba@v1.4.7/deps/cppjieba/dict"
if [ -d "${GOJIEBA_PATH}" ]; then echo "词典已存在，跳过"; exit 0; fi
if [ ! -d "./gojieba-dict" ]; then echo "ERROR: gojieba-dict 目录不存在"; exit 1; fi
echo "需要管理员权限部署词典，请输入密码："
sudo mkdir -p "${GOJIEBA_PATH}"
sudo cp -r ./gojieba-dict/* "${GOJIEBA_PATH}/"
sudo chmod -R 755 "${GOJIEBA_PATH}"
echo "部署完成"
INSTALL_EOF
chmod +x install.sh

cat > start.sh <<'START_EOF'
#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")"
GOJIEBA_PATH="${HOME}/go/pkg/mod/github.com/yanyiwu/gojieba@v1.4.7/deps/cppjieba/dict"
if [ ! -d "${GOJIEBA_PATH}" ]; then echo "ERROR: gojieba 词典未部署，请先执行 ./install.sh"; exit 1; fi
if [ -f .env ]; then set -a; source .env; set +a; fi
mkdir -p logs data
chmod +x ./WeKnora-lite ./docreader-server 2>/dev/null || true
if [ -f .airag.pid ] && kill -0 "$(cat .airag.pid)" 2>/dev/null; then
    echo "AI 知识库已在运行 (PID: $(cat .airag.pid))"; exit 1
fi
if [ -f "./docreader-server" ]; then
    echo ">> 启动 docreader..."
    nohup ./docreader-server > logs/docreader.log 2>&1 &
    echo $! > .docreader.pid
    for i in $(seq 1 30); do
        if (echo > /dev/tcp/127.0.0.1/50051) >/dev/null 2>&1; then echo "   docreader 已就绪 (${i}s)"; break; fi
        sleep 1
    done
fi
echo ">> 启动 AI 知识库..."
nohup ./WeKnora-lite > logs/airag.log 2>&1 &
echo $! > .airag.pid
PORT="${SERVER_PORT:-8080}"
for i in $(seq 1 30); do
    if (echo > /dev/tcp/127.0.0.1/"$PORT") >/dev/null 2>&1; then echo "   AI 知识库已就绪 (${i}s)"; break; fi
    sleep 1
done
echo ""
echo "=========================================="
echo "  AiRAG 启动成功"
echo "  访问地址: http://localhost:${PORT}"
echo "  查看日志: ./logs.sh"
echo "  停止服务: ./stop.sh"
echo "=========================================="
START_EOF
chmod +x start.sh

cat > stop.sh <<'STOP_EOF'
#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")"
stop_process() {
    local name="$1" pidfile="$2"
    if [ ! -f "$pidfile" ]; then echo "   $name 未运行"; return; fi
    local pid=$(cat "$pidfile")
    if ! kill -0 "$pid" 2>/dev/null; then rm -f "$pidfile"; return; fi
    echo "   停止 $name (PID: $pid)..."
    kill "$pid" 2>/dev/null || true
    for i in $(seq 1 10); do
        if ! kill -0 "$pid" 2>/dev/null; then rm -f "$pidfile"; echo "   $name 已停止"; return; fi
        sleep 1
    done
    kill -9 "$pid" 2>/dev/null || true
    rm -f "$pidfile"
}
echo ">> 停止服务..."
stop_process "AI 知识库" ".airag.pid"
stop_process "docreader" ".docreader.pid"
echo ">> 完成"
STOP_EOF
chmod +x stop.sh

cat > restart.sh <<'RESTART_EOF'
#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")"
./stop.sh
sleep 2
./start.sh
RESTART_EOF
chmod +x restart.sh

cat > status.sh <<'STATUS_EOF'
#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")"
check_proc() {
    local name="$1" pidfile="$2"
    if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
        echo "  ✅ $name 运行中 (PID: $(cat "$pidfile"))"
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
echo "=== AiRAG 状态 ==="
check_proc "AI 知识库" ".airag.pid"
check_proc "docreader" ".docreader.pid"
echo ""
echo "=== 端口 ==="
check_port 8080
check_port 50051
echo ""
echo "=== 磁盘 ==="
du -sh data logs backups 2>/dev/null || true
STATUS_EOF
chmod +x status.sh

cat > backup.sh <<'BACKUP_EOF'
#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")"
KEEP=7
BACKUP_DIR="backups"
TS=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/airag-backup-${TS}.tar.gz"
mkdir -p "$BACKUP_DIR"
echo ">> 备份 AiRAG 数据..."
if [ -f .airag.pid ] && kill -0 "$(cat .airag.pid)" 2>/dev/null; then
    read -r -p "服务正在运行，继续备份? [y/N] " ans
    [[ "$ans" != "y" && "$ans" != "Y" ]] && exit 1
fi
TMP_STAGE=$(mktemp -d)
trap 'rm -rf "$TMP_STAGE"' EXIT
[ -d data ] && cp -r data "$TMP_STAGE/"
[ -f .env ] && cp .env "$TMP_STAGE/"
[ -d config ] && cp -r config "$TMP_STAGE/"
tar czf "$BACKUP_FILE" -C "$TMP_STAGE" .
echo "   完成: $BACKUP_FILE"
ls -t "${BACKUP_DIR}"/airag-backup-*.tar.gz 2>/dev/null | tail -n +$((KEEP+1)) | while read -r f; do rm -f "$f"; done
echo ">> 备份完成"
BACKUP_EOF
chmod +x backup.sh

cat > restore.sh <<'RESTORE_EOF'
#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")"
BACKUP_DIR="backups"
echo ">> 可用备份:"
ls -lh "${BACKUP_DIR}"/airag-backup-*.tar.gz 2>/dev/null || { echo "没有备份"; exit 1; }
read -r -p "输入备份文件名: " BACKUP_FILE
[ -f "${BACKUP_DIR}/${BACKUP_FILE}" ] && BACKUP_FILE="${BACKUP_DIR}/${BACKUP_FILE}"
[ -f "$BACKUP_FILE" ] || { echo "文件不存在"; exit 1; }
read -r -p "确认恢复? [y/N] " ans
[[ "$ans" != "y" && "$ans" != "Y" ]] && exit 1
[ -f .airag.pid ] && ./stop.sh
TMP_STAGE=$(mktemp -d)
trap 'rm -rf "$TMP_STAGE"' EXIT
tar xzf "$BACKUP_FILE" -C "$TMP_STAGE"
[ -d "$TMP_STAGE/data" ] && rm -rf data && cp -r "$TMP_STAGE/data" .
[ -f "$TMP_STAGE/.env" ] && cp "$TMP_STAGE/.env" .
[ -d "$TMP_STAGE/config" ] && rm -rf config && cp -r "$TMP_STAGE/config" .
echo ">> 恢复完成，执行 ./start.sh 启动"
RESTORE_EOF
chmod +x restore.sh

cat > logs.sh <<'LOGS_EOF'
#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")"
case "${1:-}" in
    airag|main) tail -f logs/airag.log ;;
    docreader) tail -f logs/docreader.log ;;
    *) echo "用法: $0 [airag|docreader]"; tail -20 logs/airag.log 2>/dev/null; tail -20 logs/docreader.log 2>/dev/null ;;
esac
LOGS_EOF
chmod +x logs.sh

cat > reset-password.sh <<'RESET_EOF'
#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")"
DB="data/weknora.db"
[ -f "$DB" ] || { echo "ERROR: 数据库不存在，请先启动服务"; exit 1; }
command -v sqlite3 >/dev/null || { echo "ERROR: 未安装 sqlite3"; exit 1; }
gen_hash() {
    local password="$1"
    if command -v htpasswd >/dev/null 2>&1; then
        htpasswd -bnBC 10 "" "$password" | tr -d ':\n' | sed 's/\$2y/\$2a/'
    elif command -v python3 >/dev/null 2>&1 && python3 -c "import bcrypt" 2>/dev/null; then
        python3 -c "import bcrypt; print(bcrypt.hashpw(b'$password', bcrypt.gensalt(rounds=10)).decode())"
    else
        echo "ERROR: 无法生成 BCrypt 哈希"; exit 1
    fi
}
echo "=== 当前用户 ==="
sqlite3 -header -column "$DB" "SELECT username, email, is_active, is_system_admin FROM users WHERE deleted_at IS NULL;"
read -r -p "请输入要重置的用户邮箱: " EMAIL
USER_EXISTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE email='$EMAIL' AND deleted_at IS NULL;")
[ "$USER_EXISTS" -eq 0 ] && { echo "用户不存在"; exit 1; }
read -r -s -p "新密码: " PASSWORD; echo ""
read -r -s -p "确认新密码: " PASSWORD2; echo ""
[ "$PASSWORD" != "$PASSWORD2" ] && { echo "密码不一致"; exit 1; }
[ ${#PASSWORD} -lt 8 ] && { echo "密码长度至少 8 位"; exit 1; }
HASH=$(gen_hash "$PASSWORD")
[ -f .airag.pid ] && ./stop.sh
sqlite3 "$DB" "UPDATE users SET password_hash='$HASH', is_active=1, deleted_at=NULL, updated_at=CURRENT_TIMESTAMP WHERE email='$EMAIL';"
echo "密码已重置，执行 ./start.sh 启动"
RESET_EOF
chmod +x reset-password.sh

# ══════════════════════════════════════════════
#  .ps1 脚本（带 WSL 检测，使用 write_ps1 输出UTF‑8‑BOM，修复中文乱码）
# ══════════════════════════════════════════════
gen_lite_ps1() {
    local name="$1"
    local raw='# '${name}'.ps1
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
# 检测 WSL
if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: 未检测到 WSL（适用于 Linux 的 Windows 子系统）" -ForegroundColor Red
    Write-Host ""
    Write-Host "  AiRAG Lite 是 Linux 二进制，需要 WSL 才能运行。"
    Write-Host ""
    Write-Host "  安装步骤："
    Write-Host "    1. 以管理员身份打开 PowerShell"
    Write-Host "    2. 执行: wsl --install"
    Write-Host "    3. 重启电脑"
    Write-Host "    4. 重新运行本脚本"
    Write-Host ""
    Read-Host "按 Enter 退出"
    exit 1
}
# 检测 WSL 里是否已安装发行版
$distros = wsl -l -q 2>$null
if (-not $distros) {
    Write-Host "ERROR: WSL 已安装，但未安装任何 Linux 发行版" -ForegroundColor Red
    Write-Host "       请执行: wsl --install -d Ubuntu"
    Read-Host "按 Enter 退出"
    exit 1
}
wsl bash ./'${name}'.sh
'
    write_ps1 "${name}.ps1" "$raw"
}

for name in install start stop restart status backup restore logs reset-password; do
    gen_lite_ps1 "$name"
done

# ── shell脚本统一转为LF，移除旧的sed追加CRLF逻辑
find . -name "*.sh" -exec sed -i 's/\r$//' {} \;
find . \( -name "*.yml" -o -name "*.yaml" -o -name "*.md" -o -name ".env" \) -exec sed -i 's/\r$//' {} \; 2>/dev/null || true

# ── 打包 ──
cd "$OUT"
rm -f "${PKG}.tar.gz" "${PKG}.tar.gz.sha256"
tar czf "${PKG}.tar.gz" "$PKG"
sha256sum "${PKG}.tar.gz" > "${PKG}.tar.gz.sha256"
echo "=== 打包完成 ==="
ls -lh "$OUT/${PKG}.tar.gz"
