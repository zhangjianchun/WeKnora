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
| `env/.env.example`、`env/.env.lite.example` | 品牌文案；**密钥一律留空** |

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
4. 运行 `bash branding-overrides/apply.sh <临时目录> --check` 确认清单，再跑一次构建验证。
