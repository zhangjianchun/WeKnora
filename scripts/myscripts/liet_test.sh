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
step "Step 4.5 编译 Lite Go 二进制"

cd "$SRC_WSL"
export CGO_ENABLED=1
export CGO_CFLAGS="-Wno-deprecated-declarations"
eval "$(./scripts/get_version.sh env)"
LDFLAGS="$(./scripts/get_version.sh ldflags) -X 'google.golang.org/protobuf/reflect/protoregistry.conflictPolicy=warn'"
go build -tags "sqlite_fts5" -ldflags="-w -s $LDFLAGS" -o WeKnora-lite ./cmd/server

ls -lh WeKnora-lite
echo "  ✅ WeKnora-lite 已重新编译"