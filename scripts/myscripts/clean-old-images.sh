#!/bin/bash
# 清理旧版本 Docker 镜像，保留 v0.1.12

KEEP="v0.1.12"
REGISTRY="ghcr.io/zhangjianchun"

echo ">> 停止所有 AiRAG 容器..."
docker ps -q --filter "name=AiRAG-" | xargs -r docker stop 2>/dev/null || true
docker ps -aq --filter "name=AiRAG-" | xargs -r docker rm 2>/dev/null || true

echo ">> 删除旧版本镜像（保留 ${KEEP}）..."

# 前端
for v in v0.1.9 v0.1.10 v0.1.11; do
    docker rmi "${REGISTRY}/airag-ui-lite:${v}" 2>/dev/null && echo "  删 airag-ui-lite:${v}"
    docker rmi "${REGISTRY}/airag-ui-pro:${v}" 2>/dev/null && echo "  删 airag-ui-pro:${v}"
    docker rmi "${REGISTRY}/airag-ui-enterprise:${v}" 2>/dev/null && echo "  删 airag-ui-enterprise:${v}"
done

# 后端
for v in v0.1.9 v0.1.10 v0.1.11; do
    docker rmi "${REGISTRY}/airag-app:${v}" 2>/dev/null && echo "  删 airag-app:${v}"
    docker rmi "${REGISTRY}/airag-docreader:${v}" 2>/dev/null && echo "  删 airag-docreader:${v}"
done

echo ""
echo ">> 清理 dangling image..."
docker image prune -f

echo ""
echo ">> 当前镜像："
docker images | grep -E "airag|REPOSITORY"

echo ""
echo ">> Docker 占用："
docker system df