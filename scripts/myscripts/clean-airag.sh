#!/bin/bash
# 清理所有 AiRAG 容器、镜像、数据卷、网络
# 用于模拟"全新用户首次部署"

set -e

echo "════════════════════════════════════════════"
echo "  AiRAG 环境清理"
echo "════════════════════════════════════════════"
echo ""

# ── 1. 停止并删除容器 ──
echo ">> [1/5] 停止并删除 AiRAG 容器..."
CONTAINERS=$(docker ps -aq --filter "name=AiRAG-" 2>/dev/null || true)
if [ -n "$CONTAINERS" ]; then
    docker stop $CONTAINERS 2>/dev/null || true
    docker rm -f $CONTAINERS 2>/dev/null || true
    echo "   已删除: $(echo $CONTAINERS | wc -w) 个容器"
else
    echo "   无 AiRAG 容器"
fi

# ── 2. 删除 AiRAG 镜像 ──
echo ""
echo ">> [2/5] 删除 AiRAG 镜像..."
IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "airag|wechatopenai/weknora" 2>/dev/null || true)
if [ -n "$IMAGES" ]; then
    echo "$IMAGES" | while read -r img; do
        docker rmi -f "$img" 2>/dev/null && echo "   已删: $img" || true
    done
else
    echo "   无 AiRAG 镜像"
fi

# ── 3. 删除 AiRAG 数据卷 ──
echo ""
echo ">> [3/5] 删除 AiRAG 数据卷..."
VOLUMES=$(docker volume ls -q | grep -E "airag" 2>/dev/null || true)
if [ -n "$VOLUMES" ]; then
    echo "$VOLUMES" | while read -r vol; do
        docker volume rm "$vol" 2>/dev/null && echo "   已删: $vol" || true
    done
else
    echo "   无 AiRAG 卷"
fi

# ── 4. 删除 AiRAG 网络 ──
echo ""
echo ">> [4/5] 删除 AiRAG 网络..."
NETWORKS=$(docker network ls --format "{{.Name}}" | grep -E "airag" 2>/dev/null || true)
if [ -n "$NETWORKS" ]; then
    echo "$NETWORKS" | while read -r net; do
        docker network rm "$net" 2>/dev/null && echo "   已删: $net" || true
    done
else
    echo "   无 AiRAG 网络"
fi

# ── 5. 验证 ──
echo ""
echo ">> [5/5] 验证清理结果..."
echo ""
echo "   容器:"
docker ps -a --filter "name=AiRAG-" --format "     {{.Names}}" | grep -q . && echo "     ⚠️ 还有残留" || echo "     ✅ 无残留"
echo "   镜像:"
docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "airag|wechatopenai/weknora" | grep -q . && echo "     ⚠️ 还有残留" || echo "     ✅ 无残留"
echo "   卷:"
docker volume ls -q | grep -E "airag" | grep -q . && echo "     ⚠️ 还有残留" || echo "     ✅ 无残留"
echo "   网络:"
docker network ls --format "{{.Name}}" | grep -E "airag" | grep -q . && echo "     ⚠️ 还有残留" || echo "     ✅ 无残留"

echo ""
echo "════════════════════════════════════════════"
echo "  清理完成"
echo "════════════════════════════════════════════"
echo ""
echo ">> 磁盘占用："
docker system df