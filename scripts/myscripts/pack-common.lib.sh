#!/bin/bash
# pack‑common.lib.sh 公共打包库：在线/离线包共用
# 不要直接运行，由打包脚本 source ./pack‑common.lib.sh

set -eo pipefail

# write_ps1：接收here‑doc管道输入，输出 UTF‑8‑BOM ps1文件
write_ps1() {
    local outfile="$1"
    local tmpraw
    tmpraw=$(mktemp)
    cat > "$tmpraw"
    printf '\xef\xbb\xbf' > "$outfile"
    cat "$tmpraw" >> "$outfile"
    rm -f "$tmpraw"
}

########################## shell脚本
TEMPLATE_load_images_sh_online() {
cat <<'LOAD_EOF'
#!/bin/bash
set -eo pipefail
cd "$(dirname "$0")"
echo ">> 从镜像仓库拉取 Docker 镜像（需要网络）..."
docker compose pull
[ ! -f .env ] && cp .env.example .env && sed -i 's/\r$//' .env
echo "镜像拉取完成，下一步: 编辑 .env 后执行 ./start.sh"
LOAD_EOF
}

TEMPLATE_start_sh() {
cat <<'START_EOF'
#!/bin/bash
set -eo pipefail
cd "$(dirname "$0")"
sed -i 's/\r$//' .env 2>/dev/null || true
if [ ! -f .env ]; then
    echo "ERROR: 未找到 .env"
    echo "HINT: 请先运行 ./load-images.sh 生成 .env 文件"
    exit 1
fi

MISSING=""
while IFS= read -r line; do
    [[ $line =~ ^# ]] && continue
    [[ -z $line ]] && continue
    eval "$line"
done < .env

[ -z "${DB_PASSWORD:-}" ] && MISSING="${MISSING} DB_PASSWORD"
[ -z "${REDIS_PASSWORD:-}" ] && MISSING="${MISSING} REDIS_PASSWORD"
[ -z "${SYSTEM_SIGNING_KEY:-}" ] && MISSING="${MISSING} SYSTEM_SIGNING_KEY"
[ -z "${SYSTEM_AES_KEY:-}" ] && MISSING="${MISSING} SYSTEM_AES_KEY"

[ -n "$MISSING" ] && { echo "ERROR: .env 中以下变量未填写：${MISSING}"; exit 1; }
NEO4J_ENABLED=0
grep -qE '^\s*NEO4J_ENABLE\s*=\s*true' .env && NEO4J_ENABLED=1
echo ">> 启动 AiRAG..."
if [ "$NEO4J_ENABLED" -eq 1 ]; then
    docker compose --profile neo4j up -d --wait 2>/dev/null || docker compose --profile neo4j up -d
else
    docker compose up -d --wait 2>/dev/null || docker compose up -d
fi
docker compose ps
FRONTEND_PORT=$(grep "^FRONTEND_PORT=" .env | cut -d= -f2 || echo 80)
echo "=========================================="
echo "  AiRAG 启动完成"
echo "  访问地址: http://localhost:${FRONTEND_PORT}"
echo "=========================================="
START_EOF
}

TEMPLATE_stop_sh() {
cat <<'STOP_EOF'
#!/bin/bash
set -eo pipefail
cd "$(dirname "$0")"
docker compose --profile full down
STOP_EOF
}

TEMPLATE_status_sh() {
cat <<'STATUS_EOF'
#!/bin/bash
set -eo pipefail
cd "$(dirname "$0")"
docker compose ps
STATUS_EOF
}

TEMPLATE_logs_sh() {
cat <<'LOGS_EOF'
#!/bin/bash
set -eo pipefail
cd "$(dirname "$0")"
case "${1:-}" in
    app|backend) docker compose logs -f app ;;
    frontend)    docker compose logs -f frontend ;;
    docreader)   docker compose logs -f docreader ;;
    postgres|db) docker compose logs -f postgres ;;
    redis)       docker compose logs -f redis ;;
    neo4j)       docker compose logs -f neo4j ;;
    *) echo "用法: $0 [app|frontend|docreader|postgres|redis|neo4j]"; docker compose logs --tail 50 ;;
esac
LOGS_EOF
}

TEMPLATE_enable_neo4j_sh() {
cat <<'ENABLE_NEO4J_EOF'
#!/bin/bash
set -eo pipefail
cd "$(dirname "$0")"
grep -qE '^\s*NEO4J_ENABLE\s*=' .env \
    && sed -i 's/^\s*NEO4J_ENABLE\s*=.*/NEO4J_ENABLE=true/' .env \
    || echo "NEO4J_ENABLE=true" >> .env

echo ">> 已开启知识图谱开关(NEO4J_ENABLE=true)"
echo ">> 正在停止全部服务，请执行start脚本完整重建容器生效"
docker compose --profile full down

echo ""
echo "✅操作完成！"
echo "👉 请运行： ./start.sh"
echo "执行完start脚本知识图谱功能才会正式生效"
ENABLE_NEO4J_EOF
}


TEMPLATE_disable_neo4j_sh() {
cat <<'DISABLE_NEO4J_EOF'
#!/bin/bash
set -eo pipefail
cd "$(dirname "$0")"
grep -qE '^\s*NEO4J_ENABLE\s*=' .env \
    && sed -i 's/^\s*NEO4J_ENABLE\s*=.*/NEO4J_ENABLE=false/' .env \
    || echo "NEO4J_ENABLE=false" >> .env

echo ">> 已关闭知识图谱开关(NEO4J_ENABLE=false)"
echo ">> 正在停止全部服务，请执行start脚本完整重建容器生效"
docker compose --profile full down

echo ""
echo "✅操作完成！"
echo "👉 请运行： ./start.sh"
echo "执行完start脚本知识图谱才会完全关闭，消除neo4j重连告警"
DISABLE_NEO4J_EOF
}



TEMPLATE_backup_sh() {
cat <<'BACKUP_EOF'
#!/bin/bash
set -eo pipefail
cd "$(dirname "$0")"
KEEP=7
BACKUP_DIR="backups"
TS=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/airag-backup-${TS}.tar.gz"
mkdir -p "$BACKUP_DIR"
echo ">> 备份 AiRAG 数据..."

PG_VOL=$(docker volume ls --format '{{.Name}}' | grep -E '_postgres-data$' | head -1)
FILES_VOL=$(docker volume ls --format '{{.Name}}' | grep -E '_data-files$' | head -1)
echo "   数据库卷: ${PG_VOL:-未找到}"
echo "   文件卷:   ${FILES_VOL:-未找到}"

cp .env "$BACKUP_DIR/env-${TS}.env" 2>/dev/null || true
DB_USER=$(docker compose exec -T postgres printenv POSTGRES_USER 2>/dev/null | tr -d '[:space:]')
DB_USER="${DB_USER:-postgres}"

if docker compose ps --services --filter "status=running" | grep -q "^postgres$"; then
    docker compose exec -T postgres pg_dumpall -U "$DB_USER" > "${BACKUP_DIR}/postgres-${TS}.sql" 2>/dev/null || {
        echo "   WARNING: 数据库导出失败"
        rm -f "${BACKUP_DIR}/postgres-${TS}.sql"
    }
else
    echo "   WARNING: postgres 容器未运行，跳过pg_dump导出"
    rm -f "${BACKUP_DIR}/postgres-${TS}.sql"
fi

VOL_TAR="${BACKUP_DIR}/volumes-${TS}.tar.gz"
rm -f "$VOL_TAR"
if [ -n "$PG_VOL" ] && [ -n "$FILES_VOL" ]; then
# 包进sh -c '' 单引号，规避MINGW Git‑Bash转换 /data
    docker run --rm \
        -v "${PG_VOL}:/data/postgres" \
        -v "${FILES_VOL}:/data/files" \
        busybox:1.36 sh -c 'tar czf - -C /data .' > "$VOL_TAR"
fi

cd "$BACKUP_DIR"
tar czf "$(basename "$BACKUP_FILE")" env-"${TS}".env postgres-"${TS}".sql volumes-"${TS}".tar.gz 2>/dev/null || true
rm -f "env-${TS}.env" "postgres-${TS}.sql" "volumes-${TS}.tar.gz"
cd ..

ls -t "${BACKUP_DIR}"/airag-backup-*.tar.gz 2>/dev/null | tail -n +$((KEEP+1)) | while read -r f; do rm -f "$f"; done
echo "备份完成: $BACKUP_FILE"
BACKUP_EOF
}

TEMPLATE_restore_sh() {
cat <<'RESTORE_EOF'
#!/bin/bash
set -eo pipefail
cd "$(dirname "$0")"
BACKUP_DIR="backups"
ls -lh "${BACKUP_DIR}"/airag-backup-*.tar.gz 2>/dev/null || { echo "没有备份"; exit 1; }
read -r -p "输入备份文件名: " BACKUP_FILE
[ -f "${BACKUP_DIR}/${BACKUP_FILE}" ] && BACKUP_FILE="${BACKUP_DIR}/${BACKUP_FILE}"
[ -f "$BACKUP_FILE" ] || { echo "文件不存在"; exit 1; }
read -r -p "确认恢复? [y/N] " ans
[[ "$ans" != "y" && "$ans" != "Y" ]] && exit 1
docker compose --profile full down
TMP_STAGE=$(mktemp -d)
trap 'rm -rf "$TMP_STAGE"' EXIT
tar xzf "$BACKUP_FILE" -C "$TMP_STAGE"
for f in "$TMP_STAGE"/*.env; do
    [ -f "$f" ] && cp "$f" .env && break
done
PG_VOL=$(docker volume ls --format '{{.Name}}' | grep -E '_postgres-data$' | head -1)
FILES_VOL=$(docker volume ls --format '{{.Name}}' | grep -E '_data-files$' | head -1)
VOL_ARCHIVE=""
for f in "$TMP_STAGE"/volumes-*.tar.gz; do
    VOL_ARCHIVE="$f"
    break
done
if [ -f "$VOL_ARCHIVE" ] && [ -n "$PG_VOL" ] && [ -n "$FILES_VOL" ]; then
# 包进sh‑c ''单引号，规避MINGW把容器内 /data 转成Windows路径
    cat "$VOL_ARCHIVE" | docker run --rm -i \
        -v "${PG_VOL}:/data/postgres" \
        -v "${FILES_VOL}:/data/files" \
        busybox:1.36 sh -c 'tar xzf - -C /data'
fi
echo "恢复完成，执行 ./start.sh 启动"
RESTORE_EOF
}


# reset‑password.sh 增强：增加is_system_admin选择 1=true,2=false,3=不变
TEMPLATE_reset_password_sh() {
cat <<'RESET_EOF'
#!/bin/bash
set -eo pipefail
cd "$(dirname "$0")"
[ -f .env ] && { set -a; source .env; set +a; }
DB_USER="${DB_USER:-postgres}"; DB_NAME="${DB_NAME:-WeKnora}"
docker compose ps --services --filter "status=running" | grep -q "^postgres$" || { echo "postgres 未运行"; exit 1; }
gen_hash() {
    local password="$1"; local escaped="${password//\'/\'\'}"
    if command -v htpasswd >/dev/null 2>&1; then
        htpasswd -bnBC 10 "" "$password" | tr -d ':\n' | sed 's/\$2y/\$2a/'
    elif command -v python3 >/dev/null 2>&1 && python3 -c "import bcrypt" 2>/dev/null; then
        python3 -c "import bcrypt; print(bcrypt.hashpw(b'$password', bcrypt.gensalt(rounds=10)).decode())"
    else
        docker compose exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;" >/dev/null 2>&1 || true
        docker compose exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" -tAc "SELECT crypt('$escaped', gen_salt('bf', 10));" | tr -d '[:space:]'
    fi
}
echo "=== 当前用户 ==="
docker compose exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT username, email, is_active, is_system_admin FROM users WHERE deleted_at IS NULL;"
read -r -p "输入要重置的用户邮箱: " EMAIL
USER_EXISTS=$(docker compose exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" -tAc "SELECT COUNT(*) FROM users WHERE email='$EMAIL' AND deleted_at IS NULL;" | tr -d '[:space:]')
[ "$USER_EXISTS" != "1" ] && { echo "用户不存在"; exit 1; }
read -r -s -p "新密码: " PASSWORD; echo ""
read -r -s -p "确认新密码: " PASSWORD2; echo ""
[ "$PASSWORD" != "$PASSWORD2" ] && { echo "密码不一致"; exit 1; }
[ ${#PASSWORD} -lt 8 ] && { echo "密码长度至少 8 位"; exit 1; }
HASH=$(gen_hash "$PASSWORD")
echo ""
echo "设置系统管理员权限："
echo "  1 = 设置为系统管理员 true"
echo "  2 = 取消系统管理员 false"
echo "  3 = 保持原有值不变(默认)"
read -r -p "请选择 [1/2/3]:" ADMIN_OPT
SQL_UPDATE="UPDATE users SET password_hash='$HASH', is_active=TRUE, deleted_at=NULL, updated_at=CURRENT_TIMESTAMP WHERE email='$EMAIL';"
case "$ADMIN_OPT" in
1)
SQL_UPDATE="UPDATE users SET password_hash='$HASH', is_active=TRUE,is_system_admin=true, deleted_at=NULL, updated_at=CURRENT_TIMESTAMP WHERE email='$EMAIL';"
;;
2)
SQL_UPDATE="UPDATE users SET password_hash='$HASH', is_active=TRUE,is_system_admin=false, deleted_at=NULL, updated_at=CURRENT_TIMESTAMP WHERE email='$EMAIL';"
;;
3|"")
;;
*) echo "无效选项，保持原有权限"; ;;
esac
docker compose exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" -c "$SQL_UPDATE;" >/dev/null
echo "密码已重置，权限已处理完成"
RESET_EOF
}

# ========= PS1输出包装函数：直接here‑doc传给write_ps1 =========
PS1_load_images_online() {
    local out="$1"
    write_ps1 "$out" <<-'EOF'
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
Write-Host ">> 从镜像仓库拉取 Docker 镜像（需要网络）..."
docker compose pull
if (-not (Test-Path ".env")) { Copy-Item ".env.example" ".env" }
Write-Host "镜像拉取完成，下一步: notepad .env 然后 .\start.ps1"
EOF
}

PS1_start() {
    local out="$1"
    write_ps1 "$out" <<-'EOF'
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
if (-not (Test-Path ".env")) {
    Write-Host "ERROR: 未找到 .env" -ForegroundColor Red
    Write-Host "HINT: 请先运行 .\load-images.ps1 生成 .env 文件" -ForegroundColor Yellow
    exit 1
}
$envVars=@{}
$lines = Get-Content -Path ".env" -Encoding UTF8
foreach($rawLine in $lines){
    $line = $rawLine
    $trimmedLine = $line.Trim()
    if([string]::IsNullOrWhiteSpace($trimmedLine) -or $trimmedLine.StartsWith("#")){
        continue
    }
    $eqIndex = $line.IndexOf('=')
    if($eqIndex -gt 0){
        $k = $line.Substring(0,$eqIndex).Trim()
        $v = $line.Substring($eqIndex+1)
        $envVars[$k] = $v
    }
}
$missing=@()
if (-not $envVars.ContainsKey("DB_PASSWORD") -or [string]::IsNullOrWhiteSpace($envVars["DB_PASSWORD"])) { $missing += "DB_PASSWORD" }
if (-not $envVars.ContainsKey("REDIS_PASSWORD") -or [string]::IsNullOrWhiteSpace($envVars["REDIS_PASSWORD"])) { $missing += "REDIS_PASSWORD" }
if (-not $envVars.ContainsKey("SYSTEM_SIGNING_KEY") -or [string]::IsNullOrWhiteSpace($envVars["SYSTEM_SIGNING_KEY"])) { $missing += "SYSTEM_SIGNING_KEY" }
if (-not $envVars.ContainsKey("SYSTEM_AES_KEY") -or [string]::IsNullOrWhiteSpace($envVars["SYSTEM_AES_KEY"])) { $missing += "SYSTEM_AES_KEY" }

if ($missing.Count -gt 0) {
    Write-Host "ERROR: .env 中以下变量未填写：$($missing -join ', ')" -ForegroundColor Red
    exit 1
}
$neo4jEnabled = ($envVars["NEO4J_ENABLE"] -eq "true")
Write-Host ">> 启动 AiRAG..."

# 保存错误策略，临时关闭Stop，规避docker compose网络警告stderr触发异常
$oldErrAct = $ErrorActionPreference
$ErrorActionPreference = "Continue"
if ($neo4jEnabled) {
    docker compose --profile neo4j up -d --wait
    $ec=$LASTEXITCODE
    if ($ec -ne 0) { docker compose --profile neo4j up -d }
} else {
    docker compose up -d --wait
    $ec=$LASTEXITCODE
    if ($ec -ne 0) { docker compose up -d }
}
$ErrorActionPreference = $oldErrAct

docker compose ps
$port="80"
if ($envVars.ContainsKey("FRONTEND_PORT")) {
    $port = $envVars["FRONTEND_PORT"]
}
Write-Host ""
Write-Host "=========================================="
Write-Host "  AiRAG 启动完成"
Write-Host "  访问地址: http://localhost:$port"
Write-Host "  查看日志: .\logs.ps1 app"
Write-Host "  停止服务: .\stop.ps1"
Write-Host "=========================================="
EOF
}


PS1_stop() {
    local out="$1"
    write_ps1 "$out" <<-'EOF'
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
Write-Host ">> 停止 AiRAG 服务..."
docker compose --profile full down
Write-Host ">> 完成"
EOF
}

PS1_status() {
    local out="$1"
    write_ps1 "$out" <<-'EOF'
Set-Location $PSScriptRoot
docker compose ps
Write-Host ""
Write-Host "=== Docker 卷 ==="
docker volume ls --filter "name=airag_" --format "table {{.Name}}\t{{.Driver}}"
EOF
}

PS1_logs() {
    local out="$1"
    write_ps1 "$out" <<-'EOF'
param([string]$Service = "")
Set-Location $PSScriptRoot
switch ($Service) {
    "app"       { docker compose logs -f app }
    "backend"   { docker compose logs -f app }
    "frontend"  { docker compose logs -f frontend }
    "docreader" { docker compose logs -f docreader }
    "postgres"  { docker compose logs -f postgres }
    "db"        { docker compose logs -f postgres }
    "redis"     { docker compose logs -f redis }
    "neo4j"     { docker compose logs -f neo4j }
    default {
        Write-Host "用法: .\logs.ps1 [app|frontend|docreader|postgres|redis|neo4j]"
        docker compose logs --tail 50
    }
}
EOF
}

PS1_enable_neo4j() {
    local out="$1"
    write_ps1 "$out" <<-'EOF'
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
$content = Get-Content .env -Encoding UTF8
$content = $content -replace '^\s*NEO4J_ENABLE\s*=.*', 'NEO4J_ENABLE=true'
$content | Set-Content .env -Encoding UTF8

Write-Host ">> 已开启知识图谱开关(NEO4J_ENABLE=true)"
Write-Host ">> 正在停止全部服务，请执行start脚本完整重建容器生效"
$oldErrAct = $ErrorActionPreference
$ErrorActionPreference = "Continue"
docker compose --profile full down
$ErrorActionPreference = $oldErrAct

Write-Host ""
Write-Host "✅操作完成！"
Write-Host "👉 请运行： .\start.ps1"
Write-Host "执行完start脚本知识图谱功能才会正式生效"
EOF
}


PS1_disable_neo4j() {
    local out="$1"
    write_ps1 "$out" <<-'EOF'
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
$content = Get-Content .env -Encoding UTF8
$content = $content -replace '^\s*NEO4J_ENABLE\s*=.*', 'NEO4J_ENABLE=false'
$content | Set-Content .env -Encoding UTF8

Write-Host ">> 已关闭知识图谱开关(NEO4J_ENABLE=false)"
Write-Host ">> 正在停止全部服务，请执行start脚本完整重建容器生效"
$oldErrAct = $ErrorActionPreference
$ErrorActionPreference = "Continue"
docker compose --profile full down
$ErrorActionPreference = $oldErrAct

Write-Host ""
Write-Host "✅操作完成！"
Write-Host "👉 请运行： .\start.ps1"
Write-Host "执行完start脚本知识图谱才会完全关闭，消除neo4j重连告警"
EOF
}




PS1_backup() {
    local out="$1"
    write_ps1 "$out" <<-'EOF'
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
$KEEP = 7
$BACKUP_DIR = "backups"
$TS = Get-Date -Format "yyyyMMdd-HHmmss"
$BACKUP_FILE = "$BACKUP_DIR/airag-backup-$TS.tar.gz"
New-Item -ItemType Directory -Force -Path $BACKUP_DIR | Out-Null
Write-Host ">> 备份 AiRAG 数据..."
Copy-Item ".env" "$BACKUP_DIR/env-$TS.env" -ErrorAction SilentlyContinue

$pgDumpFile="$BACKUP_DIR/postgres-$TS.sql"
$runningPostgres = docker compose ps --services --filter "status=running" | Where-Object { $_ -eq "postgres" }
if ($runningPostgres) {
    $DB_USER = (docker compose exec -T postgres printenv POSTGRES_USER 2>$null)
    if (-not $DB_USER) { $DB_USER = "postgres" }
    $DB_USER = $DB_USER.Trim()
    docker compose exec -T postgres pg_dumpall -U $DB_USER > "$pgDumpFile" 2>$null
} else {
    Write-Host "   WARNING: postgres 容器未运行，跳过pg_dump导出"
    if(Test-Path $pgDumpFile){ Remove-Item $pgDumpFile -ErrorAction SilentlyContinue }
}

$pgVol = (docker volume ls --format "{{.Name}}" | Where-Object { $_ -match "_postgres-data$" } | Select-Object -First 1)
$filesVol = (docker volume ls --format "{{.Name}}" | Where-Object { $_ -match "_data-files$" } | Select-Object -First 1)
if ($pgVol -and $filesVol) {
    docker run --rm `
        -v "${pgVol}:/data/postgres" `
        -v "${filesVol}:/data/files" `
        -v "$((Get-Location).Path)/${BACKUP_DIR}:/backup" `
        busybox:1.36 `
        tar czf "/backup/volumes-$TS.tar.gz" -C /data .
}
Push-Location $BACKUP_DIR
tar czf "airag-backup-$TS.tar.gz" "env-$TS.env" "postgres-$TS.sql" "volumes-$TS.tar.gz" 2>$null
Remove-Item "env-$TS.env","postgres-$TS.sql","volumes-$TS.tar.gz" -ErrorAction SilentlyContinue
Pop-Location
Get-ChildItem "$BACKUP_DIR/airag-backup-*.tar.gz" | Sort-Object LastWriteTime -Descending |
    Select-Object -Skip $KEEP | Remove-Item -ErrorAction SilentlyContinue
Write-Host "备份完成: $BACKUP_FILE"
EOF
}

PS1_restore() {
    local out="$1"
    write_ps1 "$out" <<-'EOF'
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
$BACKUP_DIR = "backups"
$files = Get-ChildItem "$BACKUP_DIR/airag-backup-*.tar.gz" -ErrorAction SilentlyContinue
if (-not $files) { Write-Host "没有备份"; exit 1 }
$i = 1
foreach ($f in $files) { Write-Host "  [$i] $($f.Name)"; $i++ }
$idx = Read-Host "输入要恢复的备份编号"
$BACKUP_FILE = $files[$idx - 1].FullName
$ans = Read-Host "确认恢复将覆盖当前数据? [y/N]"
if ($ans -notin @("y","Y")) { exit 1 }
docker compose --profile full down
$tmp = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "airag-restore-$(Get-Random)")
tar xzf $BACKUP_FILE -C $tmp.FullName
Get-ChildItem "$($tmp.FullName)/*.env" -ErrorAction SilentlyContinue | Select-Object -First 1 | ForEach-Object {
    Copy-Item $_.FullName ".env" -Force
}
$volFile = Get-ChildItem "$($tmp.FullName)/volumes-*.tar.gz" -ErrorAction SilentlyContinue | Select-Object -First 1
$pgVol = (docker volume ls --format "{{.Name}}" | Where-Object { $_ -match "_postgres-data$" } | Select-Object -First 1)
$filesVol = (docker volume ls --format "{{.Name}}" | Where-Object { $_ -match "_data-files$" } | Select-Object -First 1)
if ($volFile -and $pgVol -and $filesVol) {
    docker run --rm `
        -v "${pgVol}:/data/postgres" `
        -v "${filesVol}:/data/files" `
        -v "$($tmp.FullName):/backup" `
        busybox:1.36 `
        sh -c "cd /data && tar xzf /backup/$($volFile.Name)"
}
Remove-Item $tmp.FullName -Recurse -Force
Write-Host "恢复完成，执行 .\start.ps1 启动"
EOF
}


PS1_reset_password() {
    local out="$1"
    write_ps1 "$out" <<-'EOF'
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
if (-not (Test-Path ".env")) { Write-Host "ERROR: 未找到 .env"; exit 1 }
$envVars=@{}
$lines = Get-Content -Path ".env" -Encoding UTF8
foreach($rawLine in $lines){
    $line = $rawLine
    $trimmedLine = $line.Trim()
    if([string]::IsNullOrWhiteSpace($trimmedLine) -or $trimmedLine.StartsWith("#")){
        continue
    }
    $eqIndex = $line.IndexOf('=')
    if($eqIndex -gt 0){
        $k = $line.Substring(0,$eqIndex).Trim()
        $v = $line.Substring($eqIndex+1)
        $envVars[$k] = $v
    }
}
$DB_USER = if ($envVars["DB_USER"]) { $envVars["DB_USER"] } else { "postgres" }
$DB_NAME = if ($envVars["DB_NAME"]) { $envVars["DB_NAME"] } else { "WeKnora" }
$running = docker compose ps --services --filter "status=running" 2>$null | Where-Object { $_ -eq "postgres" }
if (-not $running) { Write-Host "ERROR: postgres 未运行，请先 .\start.ps1"; exit 1 }
Write-Host "=== 当前用户 ==="
docker compose exec -T postgres psql -U $DB_USER -d $DB_NAME -c "SELECT username, email, is_active, is_system_admin FROM users WHERE deleted_at IS NULL;"
$email = Read-Host "输入要重置的用户邮箱"
$newpw = Read-Host "新密码（至少8位）" -AsSecureString
$pw2 = Read-Host "确认新密码" -AsSecureString
$pw1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($newpw))
$pw2s = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pw2))
if ($pw1 -ne $pw2s) { Write-Host "密码不一致"; exit 1 }
if ($pw1.Length -lt 8) { Write-Host "密码至少8位"; exit 1 }
docker compose exec -T postgres psql -U $DB_USER -d $DB_NAME -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;" | Out-Null
$hash = (docker compose exec -T postgres psql -U $DB_USER -d $DB_NAME -tAc "SELECT crypt('$pw1', gen_salt('bf', 10));").Trim()

Write-Host ""
Write-Host "设置系统管理员权限："
Write-Host "  1 = 设置为系统管理员 true"
Write-Host "  2 = 取消系统管理员 false"
Write-Host "  3 = 保持原有值不变(直接回车默认)"
$opt = Read-Host "请选择 [1/2/3]"
$sql = "UPDATE users SET password_hash='$hash', is_active=TRUE, deleted_at=NULL, updated_at=CURRENT_TIMESTAMP WHERE email='$email';"
switch($opt){
    "1" {
        $sql = "UPDATE users SET password_hash='$hash', is_active=TRUE,is_system_admin=true, deleted_at=NULL, updated_at=CURRENT_TIMESTAMP WHERE email='$email';"
    }
    "2" {
        $sql = "UPDATE users SET password_hash='$hash', is_active=TRUE,is_system_admin=false, deleted_at=NULL, updated_at=CURRENT_TIMESTAMP WHERE email='$email';"
    }
    default { Write-Host "保持原有权限" }
}
docker compose exec -T postgres psql -U $DB_USER -d $DB_NAME -c $sql | Out-Null
Write-Host "密码已重置，权限已处理完成"
EOF
}



# 在线版ps1自检：移除.sh脚本，只检查ps1、yml、md等文件
PS1_test_online() {
    local out="$1"
    write_ps1 "$out" <<-'EOF'
Set-Location $PSScriptRoot
$PASS = 0; $FAIL = 0; $WARN = 0
function ok($m)   { Write-Host "  ✅ $m"; $script:PASS++ }
function bad($m)  { Write-Host "  ❌ $m"; $script:FAIL++ }
function warn($m) { Write-Host "  ⚠️  $m"; $script:WARN++ }
Write-Host "=== 在线版自检(PowerShell) ==="
# ps1版本不检测sh脚本
$files = @("docker-compose.yml",".env.example","load-images.ps1","start.ps1","stop.ps1","status.ps1","logs.ps1","backup.ps1","restore.ps1","reset-password.ps1","test.ps1","enable-neo4j.ps1","disable-neo4j.ps1","README.md","LICENSE")
foreach ($f in $files) { if (Test-Path $f) { ok $f } else { bad "$f 缺失" } }
if (docker --version) { ok "Docker" } else { bad "Docker 不可用" }
if (docker compose version) { ok "Docker Compose" } else { bad "Docker Compose 不可用" }
Write-Host ""
Write-Host "通过 $PASS / 警告 $WARN / 失败 $FAIL"
if ($FAIL -eq 0) { Write-Host "🎉 一切正常" }
EOF
}


# ====================== 离线包 package‑full.sh 专属模板 ======================
TEMPLATE_load_images_sh_offline() {
cat <<'LOAD_EOF'
#!/bin/bash
set -eo pipefail
cd "$(dirname "$0")"
echo ">> 导入 Docker 镜像..."
docker load -i images/airag-full-images.tar
[ ! -f .env ] && cp .env.example .env && sed -i 's/\r$//' .env
echo "镜像导入完成，下一步: 编辑 .env 后执行 ./start.sh"
LOAD_EOF
}

PS1_load_images_offline() {
    local out="$1"
    write_ps1 "$out" <<-'EOF'
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
Write-Host ">> 导入 Docker 镜像（离线包，约2.6G，1‑3分钟）..."
docker load -i images/airag-full-images.tar
if (-not (Test-Path ".env")) { Copy-Item ".env.example" ".env" }
Write-Host "镜像导入完成，下一步: notepad .env 然后 .\start.ps1"
EOF
}

# 离线版 test.sh 自检：增加 images/airag‑full‑images.tar 文件检查
TEMPLATE_test_sh_offline() {
cat <<'TEST_EOF'
#!/bin/bash
set -eo pipefail
cd "$(dirname "$0")"
PASS=0; FAIL=0; WARN=0
ok()   { echo -e "  ✅ $1"; PASS=$((PASS+1)); }
bad()  { echo -e "  ❌ $1"; FAIL=$((FAIL+1)); }
warn() { echo -e "  ⚠️  $1"; WARN=$((WARN+1)); }
echo "=== 离线版自检 ==="
for f in docker-compose.yml .env.example load-images.sh start.sh stop.sh status.sh logs.sh backup.sh restore.sh reset-password.sh test.sh enable-neo4j.sh disable-neo4j.sh README.md LICENSE images/airag-full-images.tar; do
    [ -e "$f" ] && ok "$f" || bad "$f 缺失"
done
docker --version >/dev/null 2>&1 && ok "Docker" || bad "Docker 不可用"
docker compose version >/dev/null 2>&1 && ok "Docker Compose" || bad "Docker Compose 不可用"
echo -e "通过 $PASS / 警告 $WARN / 失败 $FAIL"
[ "$FAIL" -eq 0 ] && echo "🎉 一切正常"
TEST_EOF
}

# 离线版 test.ps1 自检：只检测ps1，增加images镜像tar
PS1_test_offline() {
    local out="$1"
    write_ps1 "$out" <<-'EOF'
Set-Location $PSScriptRoot
$PASS = 0; $FAIL = 0; $WARN = 0
function ok($m)   { Write-Host "  ✅ $m"; $script:PASS++ }
function bad($m)  { Write-Host "  ❌ $m"; $script:FAIL++ }
function warn($m) { Write-Host "  ⚠️  $m"; $script:WARN++ }
Write-Host "=== 离线版自检(PowerShell) ==="
$files = @("docker-compose.yml",".env.example","load-images.ps1","start.ps1","stop.ps1","status.ps1","logs.ps1","backup.ps1","restore.ps1","reset-password.ps1","test.ps1","enable-neo4j.ps1","disable-neo4j.ps1","README.md","LICENSE","images/airag-full-images.tar")
foreach ($f in $files) { if (Test-Path $f) { ok $f } else { bad "$f 缺失" } }
if (docker --version) { ok "Docker" } else { bad "Docker 不可用" }
if (docker compose version) { ok "Docker Compose" } else { bad "Docker Compose 不可用" }
Write-Host ""
Write-Host "通过 $PASS / 警告 $WARN / 失败 $FAIL"
if ($FAIL -eq 0) { Write-Host "🎉 一切正常" }
EOF
}
