# 品牌覆盖物（branding-overrides）

本目录存放 **AI 知识库 / AiRAG** 相对上游 WeKnora 的「非前端」定制，供打包与部署时重放。

## 为什么存在

`branding` 分支只保留两类改动：**前端品牌展示层** 与 **镜像名 / 容器名 / 网络名**。
其余定制（中文提示词、构建加速、docreader 单文件打包、env 模板文案等）如果直接改上游文件，每次官方升级都会产生冲突。现在这些文件在分支上保持与官方一致，定制内容集中在这里，由脚本在交付阶段覆盖。

> 关键原则：上游文件是「基底」，本目录是「覆盖层」。升级官方版本后，只需重新核对本目录文件与上游新版的差异，不需要解合并冲突。

## 如何应用

```bash
# 1) 查看会覆盖哪些文件
bash branding-overrides/apply.sh <目标目录> --check

# 2) 应用到打包目录（推荐）或仓库根目录
bash branding-overrides/apply.sh <目标目录>
```

`scripts/myscripts/package-*.sh` / `package-docker.sh` 已在生成包目录时自动调用本脚本，正常交付无需手动执行。
若直接在本仓库用 `docker compose up -d` 部署，需要先执行 `bash branding-overrides/apply.sh .`，并注意这会修改工作树（脚本会打印还原命令）。

## 覆盖清单

| 覆盖物 | 作用 |
|---|---|
| `config/prompt_templates/*.yaml` | 4 个提示词模板中文化（拒答规则、意图、系统提示词、Agent 系统提示词） |
| `config/config.yaml` | `conversation.max_completion_tokens: 4096` |
| `docker/Dockerfile.app` | `GOPROXY` 与 uv 安装脚本走国内镜像 |
| `frontend/Dockerfile` | 注入 `VITE_EDITION` / `VITE_AppVersion` 构建参数 |
| `docreader/*` | PyInstaller 单文件打包（spec、hook、入口脚本、pyproject dev 组、uv.lock） |
| `scripts/build_browserskill.sh` | git clone / pnpm 走国内代理与镜像 |
| `env/.env.example`、`env/.env.lite.example` | 品牌文案；**密钥一律留空**；`AIRAG_ENABLE_PRODUCT_DOCS=0` |

> `.gitignore` 第 2 行 `.*` 会忽略所有点开头文件，因此第 9 行有 `!branding-overrides/env/.env.lite.example` 例外。
> 这一行不能删：`package-lite.sh` 在干净 clone 里要靠它拿到品牌化模板，否则会退回官方模板。

## 构建期定制（不在覆盖层内，但在本分支源码上）

有一类改动**必须在源码层**，不能放进本覆盖层：

| 文件 | 改动 | 为什么不能靠覆盖层 |
|---|---|---|
| `internal/application/service/agent_service.go` | `registerProductDocTools()` 增加 `AIRAG_ENABLE_PRODUCT_DOCS` 开关，默认不注册 `search_weknora_docs` / `read_weknora_doc` | 交付包只含预编译二进制（`WeKnora-lite`、`frontend/dist`），**没有 Go 源码**；打包阶段再覆盖已影响不到二进制 |

**为什么不能直接删空 `website-docs/`**：`website-docs/embed.go` 用 `//go:embed 0*/*.md` 把 74 篇文档编进服务端，删空会让 `go build` 报 `no matching files found`；`frontend/src/utils/docsUrl.test.ts` 也会失败。保留目录原样、在工具注册入口关掉，是最小侵入且唯一可靠的做法。

**升级重放**：每次同步官方新版后，确认 `registerProductDocTools()` 里这段开关仍在（`"os"` import + 紧跟 `config == nil` 判断后的 `os.Getenv` 提前 return）。若上游重写了该函数，把开关重新加回去即可。**漏掉会导致助手把上游品牌答给客户**；这是本分支唯一一处后端源码改动，冲突面只有几行。

**恢复文档检索**：先把 `website-docs/0*/*.md` 换成自己的品牌化文档（v0.9.0 的 74 篇里有 281 处 `WeKnora`，另含大量官方站点与仓库链接，不是简单文本替换能覆盖的），再在 `.env` 设 `AIRAG_ENABLE_PRODUCT_DOCS=1`。当前默认 `0`。

## 已放弃、跟随上游的定制

以下历史改动不再保留，请勿从备份分支恢复：

- `.dockerignore`：定制版删除了上游的多条排除规则（含 `frontend/` 排除与 protoc 例外），会让构建上下文变大且行为不一致。
- `config/prompt_templates.bak/`：改中文前的备份，无运行价值。
- `packages/protoc.zip`：1.7 MB 构建产物误提交。
- `scripts/build_browserskill.sh.bak`：脚本备份。
- `frontend/package-lock.json`、`go.mod`：前者是本地 npm 版本造成的重排，后者只是 `// indirect` 标记变化，均无实际定制；跟随上游可消除两个高频冲突文件。
- `.gitignore` 保留 4 行交付相关忽略项（`docreader/build/`、`airag-full-images.tar` 等），它与上游无冲突。

## 密钥安全

`env/` 两个模板中的 `JWT_SECRET` / `SYSTEM_AES_KEY` / `SYSTEM_SIGNING_KEY` 已清空。
交付时由部署方生成并写入 `.env`，**禁止把真实密钥写回仓库**（历史上 `.env.example` 曾硬编码真实值）。

## 每次官方升级后的维护动作

1. 先同步 `main` 到新 tag，再合并进 `branding`。
2. 逐个对比本目录文件与上游同名文件的新版内容（`git diff <旧tag>..<新tag> -- <路径>`），把定制点重新打到新版基底上。
3. 重点复核 `config/config.yaml`、`docker/Dockerfile.app`、`docreader/pyproject.toml` 与 `docreader/uv.lock`——这几个文件上游变化较频繁。
4. **确认「构建期定制」那一处后端开关没有被合并冲掉**，再编译二进制。
5. 运行 `bash branding-overrides/apply.sh <临时目录> --check` 确认清单，再跑一次构建验证。
