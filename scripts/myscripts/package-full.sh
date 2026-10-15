#!/bin/bash
set -eo pipefail
VERSION="${1:-v0.1.0}"
SRC="/mnt/e/zhangjianchun/WeKnora"
OUT="$HOME/release"
REGISTRY="ghcr.io/zhangjianchun"
EDITIONS=("lite" "pro" "enterprise")


SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/pack-common.lib.sh"

echo "=== AiRAG Full Offline Packager ==="
[ -f "$SRC/docker-compose.yml" ] || { echo "ERROR: 未找到 docker-compose.yml"; exit 1; }
[ -f "$SRC/.env.example" ] || [ -f "$SRC/.env.lite.example" ] || { echo "ERROR: 未找到 .env.example"; exit 1; }
mkdir -p "$OUT"

for EDITION in "${EDITIONS[@]}"; do

    case "${EDITION}" in
        lite)       EDITION_CN="基础版" ;;
        pro)        EDITION_CN="专业版" ;;
        enterprise) EDITION_CN="旗舰版" ;;
        *)          EDITION_CN="${EDITION}" ;;
    esac


    PKG="AiRAG-full-${EDITION}_${VERSION}"
    PKG_DIR="$OUT/$PKG"
    echo ""
    echo "════════════════════════════════════════════"
    echo "  打包 ${EDITION} 离线版"
    echo "════════════════════════════════════════════"
    rm -rf "$PKG_DIR"
    mkdir -p "$PKG_DIR"
    cd "$PKG_DIR"

    cp "$SRC/docker-compose.yml" .
    sed -i "s|:-wechatopenai}|:-ghcr.io/zhangjianchun}|g" docker-compose.yml
    sed -i "s|/weknora-ui:|/airag-ui-${EDITION}:|g" docker-compose.yml
    sed -i 's|/weknora-app:|/airag-app:|g' docker-compose.yml
    sed -i 's|/weknora-docreader:|/airag-docreader:|g' docker-compose.yml
    sed -i 's|/weknora-sandbox:|/airag-sandbox:|g' docker-compose.yml
    sed -i "s|\${AIRAG_VERSION:-latest}|\${AIRAG_VERSION:-${VERSION}}|g" docker-compose.yml

    if [ -f "$SRC/.env.example" ]; then
        cp "$SRC/.env.example" .env.example
    elif [ -f "$SRC/.env.lite.example" ]; then
        cp "$SRC/.env.lite.example" .env.example
    fi
    if [ -f .env.example ]; then
        grep -qE '^\s*NEO4J_ENABLE\s*=' .env.example \
            && sed -i 's/^\s*NEO4J_ENABLE\s*=.*/NEO4J_ENABLE=false/' .env.example \
            || echo "NEO4J_ENABLE=false" >> .env.example
        grep -qE '^\s*LANGFUSE_ENABLED\s*=' .env.example \
            && sed -i 's/^\s*LANGFUSE_ENABLED\s*=.*/LANGFUSE_ENABLED=false/' .env.example \
            || echo "LANGFUSE_ENABLED=false" >> .env.example
    fi

    [ -d "$SRC/config" ] && { mkdir -p config; cp -r "$SRC/config/"* config/ 2>/dev/null || true; }
    [ -d "$SRC/docker/searxng" ] && { mkdir -p docker/searxng; cp -r "$SRC/docker/searxng/"* docker/searxng/ 2>/dev/null || true; }
    [ -d "$SRC/misc" ] && { mkdir -p misc; cp -r "$SRC/misc/"* misc/ 2>/dev/null || true; }
    [ -f "$SRC/LICENSE" ] && cp "$SRC/LICENSE" .
    date -u '+%Y-%m-%dT%H:%M:%SZ' > BUILD_TIME

    # =========离线包独有：导出docker镜像tar包 =========
    mkdir -p images
    echo ">> 导出docker镜像，时间较长，请耐心等待..."
    docker save \
        "${REGISTRY}/airag-ui-${EDITION}:${VERSION}" \
        "${REGISTRY}/airag-app:${VERSION}" \
        "${REGISTRY}/airag-docreader:${VERSION}" \
        "paradedb/paradedb:v0.22.6-pg17" \
        "redis:7.0-alpine" \
        -o images/airag-full-images.tar

    # 输出sh脚本：load_images使用离线版本，其余全部复用公共lib
    TEMPLATE_load_images_sh_offline > load-images.sh
    TEMPLATE_start_sh > start.sh
    TEMPLATE_stop_sh > stop.sh
    TEMPLATE_status_sh > status.sh
    TEMPLATE_logs_sh > logs.sh
    TEMPLATE_enable_neo4j_sh > enable-neo4j.sh
    TEMPLATE_disable_neo4j_sh > disable-neo4j.sh
    TEMPLATE_backup_sh > backup.sh
    TEMPLATE_restore_sh > restore.sh
    TEMPLATE_reset_password_sh > reset-password.sh
    TEMPLATE_test_sh_offline > test.sh

    chmod +x *.sh

    # PS1脚本：load‑images使用离线版，其余全部复用公共lib已修复函数
    PS1_load_images_offline "load-images.ps1"
    PS1_start "start.ps1"
    PS1_stop "stop.ps1"
    PS1_status "status.ps1"
    PS1_logs "logs.ps1"
    PS1_enable_neo4j "enable-neo4j.ps1"
    PS1_disable_neo4j "disable-neo4j.ps1"
    PS1_backup "backup.ps1"
    PS1_restore "restore.ps1"
    PS1_reset_password "reset-password.ps1"
    PS1_test_offline "test.ps1"

    # 离线包README
cat > README.md <<README_EOF
# AiRAG 离线版部署手册（${EDITION_CN}）
> **版本**：${VERSION}
> **分发方式**：离线版（镜像内置在images目录，不需要网络）
## 快速开始
### Linux / macOS
\`\`\`bash
./load-images.sh        # 导入本地镜像包
nano .env               # 填 DB_PASSWORD、REDIS_PASSWORD、SYSTEM_SIGNING_KEY、SYSTEM_AES_KEY
./start.sh              # 启动
\`\`\`
### Windows PowerShell
\`\`\`powershell
.\load-images.ps1       # 导入本地镜像包
notepad .env            # 填 DB_PASSWORD、REDIS_PASSWORD、SYSTEM_SIGNING_KEY、SYSTEM_AES_KEY
.\start.ps1             # 启动
\`\`\`
访问 http://localhost
## 常用命令
| Linux 命令 | Windows 命令 | 作用 |
|:---|:---|:---|
| ./start.sh | .\start.ps1 | 启动 |
| ./stop.sh | .\stop.ps1 | 停止 |
| ./status.sh | .\status.ps1 | 状态 |
| ./logs.sh app | .\logs.ps1 app | 日志 |
| ./backup.sh | .\backup.ps1 | 备份 |
| ./restore.sh | .\restore.ps1 | 恢复 |
| ./reset-password.sh | .\reset-password.ps1 | 重置密码 |
| ./enable-neo4j.sh | .\enable-neo4j.ps1 | 启用知识图谱 |
| ./disable-neo4j.sh | .\disable-neo4j.ps1 | 关闭知识图谱 |
| ./test.sh | .\test.ps1 | 自检 |
## 网络说明
本版本**完全离线，不需要访问外网/GHCR**。
## 知识图谱（可选）
默认关闭。
> 切换知识图谱：执行 enable‑neo4j.sh / enable‑neo4j.ps1，脚本会停止全部服务，再手动运行start脚本生效。
## 常见问题
- **端口 80 被占用**：改 .env 里 FRONTEND_PORT=8088
- **忘记密码**：运行 reset‑password 脚本
- **容器一直 Restarting**：看 logs 脚本输出
README_EOF

    # 清理CRLF，剥离sh脚本BOM
    find . -name "*.sh" -exec sed -i 's/\r$//' {} \;
    find . \( -name "*.yml" -o -name "*.yaml" -o -name "*.md" -o -name ".env.example" \) -exec sed -i 's/\r$//' {} \; 2>/dev/null || true
    find . -name "*.sh" -exec sed -i '1s/^\xef\xbb\xbf//' {} \;

    cd "$OUT"
    rm -f "${PKG}.tar.gz" "${PKG}.tar.gz.sha256"
    tar czf "${PKG}.tar.gz" "$PKG"
    sha256sum "${PKG}.tar.gz" > "${PKG}.tar.gz.sha256"
    echo "  ✅ ${PKG}.tar.gz"
    rm -rf "$PKG_DIR"
done
echo "🎉 离线版打包完成"
