# 品牌替换记录（WeKnora → AI知识库）

> 用途：记录本产品相对上游 WeKnora（腾讯开源）所做的前端品牌替换，便于后续跟官方升级时处理冲突。
> 范围：**仅前端展示层（`frontend/`）**。后端代码（`internal/`、`cmd/`、`client/` 等）未做任何品牌改动。
> 最后更新：2026-09-30

## 一、品牌定义

| 项 | 值 |
|---|---|
| 中文品牌名 | AI知识库 |
| 英文品牌名 | AI Knowledge Base |
| 副标题 | 企业智能知识库 / 私有知识库 |

## 二、核心原则

只改"给人看的"（浏览器中客户可见的文案、图片、标题）；不改"给程序用的"（协议字段、存储 key、标识符、文件名）。

i18n 文件只改 value，不改 key。

## 三、已完成的改动

### A. 资源与页面外壳

| 文件 | 改动 |
|---|---|
| `frontend/index.html` | `<title>` → AI知识库；meta keywords/description 去除微信平台字样并改名 |
| `frontend/embed.html` | `<title>` → AI知识库 Embed |
| `frontend/public/favicon.ico` | 替换为蓝色"AI"图标（二进制替换，文件名不变） |
| `frontend/src/assets/img/weknora.png` | 替换为"AI知识库"logo（二进制替换，**文件名保留**，引用处不改） |
| `frontend/src/assets/img/screenshot-1.svg` | 登录页轮播图内烤入文字 `WeKnora · Knowledge Search` → `AI Knowledge Base · Knowledge Search` |
| `frontend/src/views/auth/Login.vue` | 删除顶部官网/GitHub 链接；logo 外层无 href 的 `<a>` 改为 `<div>`；图片 alt → AI知识库 |
| `frontend/src/components/UserMenu.vue` | 删除用户菜单中的 GitHub 菜单项、`openGithub()` 函数及失效的 `.menu-github-star-icon` 样式；后又删除"帮助与文档"菜单项、`openDocs()` 函数、`docsUrl` import 及失效的 `.menu-external-icon` 样式（i18n key `general.helpAndDocs` 保留未删） |

### B. 中文文案 `frontend/src/i18n/locales/zh-CN.ts`

仅改 value，约 25 处：

- 登录/注册引导、新会话标题、新手引导欢迎语（此前已改）
- 集成页：`WeKnora CLI` → AI知识库 CLI；`WeKnora Skill` → AI知识库 Skill；Skill/浏览器插件副标题与安装提示中的自称
- API 签名（HMAC）说明中的自称（`aud=weknora` 作为协议值保留未动）
- 嵌入渠道：来源白名单提示、webhook 描述；webhook 示例路径 `/weknora/embed-events` → `/ai-kb/embed-events`（`X-WeKnora-Signature` 头名保留）
- 沙箱密钥说明 2 处
- 沙箱设置：dockerHostRisk、标准/桌面模板全套文案（标题、镜像名、概述、创建/重建确认、DNS 帮助、TLS 目录帮助、空闲回收帮助等，约 16 处；i18n key 如 `weknoraTemplateTitle` 保留未动）
- 对象存储路径前缀示例 `如 weknora` → `如 ai-kb`

### C. 英文文案 `frontend/src/i18n/locales/en-US.ts`

与中文一一对应，约 28 处，品牌名统一为 **AI Knowledge Base**（此前文件中混用的 `AIRAG` / `AI RAG` 已在本次新增文案中统一；登录引导等历史改动保持用户原值 `AI RAG` 未回改）。

### D. 日文 / 韩文 / 俄文文案 `ja-JP.ts` / `ko-KR.ts` / `ru-RU.ts`

与 zh/en 完全相同的 key 集合，每文件约 33 处 value，品牌名分别本地化为 **AIナレッジベース**（日）、**AI 지식베이스**（韩）、**AI-база знаний**（俄，按语法变格）；"本系统/平台"自称分别用 システム/プラットフォーム、시스템/플랫폼、система/платформа。ko/ru 中原本就未本地化、保留英文的条目（沙箱模板标题、docker 帮助、webhook 描述等）按 en-US 新值同步。每文件改完均 grep 复核：剩余命中仅为 i18n key 名、WeKnora Cloud 组、协议头、`WEKNORA_*` 环境变量、镜像/profile/包名、`aud=weknora`。

### E. 版本弹窗与登录页后续微调（五种语言）

- `systemInfo.versionDescription`：去掉镜像名 → 中"当前应用服务端的版本号"（en `Version of the application backend` / 日 アプリケーションサーバーのバージョン / 韩 애플리케이션 서버의 버전 번호 / 俄 Версия серверной части приложения）
- `systemInfo.frontendVersionDescription`：→ 中"当前 UI 界面的构建版本号"（en `Build version of the UI` / 日 UIのビルドバージョン / 韩 UI 빌드 버전 번호 / 俄 Версия сборки UI）
- 登录/注册页 `platform.*` 标签与 `auth.subtitle` / `auth.registerSubtitle` 按产品新定位更新（混合检索/智能体问答/知识图谱/多模态解析等），五种语言同 key 对齐，key 名均未动。

### F. 示例数据 / 示例文本

| 文件 | 改动 |
|---|---|
| `frontend/src/views/knowledge/components/FAQEntryManager.vue` | 下载的 FAQ 导入示例中 5 处 `WeKnora` → AI知识库 |
| `frontend/src/views/knowledge/settings/chunkingSamples.ts` | 分块调试示例 Markdown/FAQ：标题与正文中的自称 → AI知识库；`git clone https://github.com/Tencent/WeKnora` → `<你的仓库地址>` 占位；官方 daocloud 镜像地址 → 泛化私有仓库示例 |

## 四、明确未改（白名单，改了会断）

| 类别 | 示例 | 位置 |
|---|---|---|
| HTTP 头 | `X-WeKnora-Desktop-Token`、`X-WeKnora-Signature` | `api/auth/index.ts`、i18n webhook 提示 |
| JWT 协议值 | `aud=weknora` | i18n HMAC 说明（前端照抄后端约定） |
| 本地存储 key | `WeKnora_settings`、`WeKnora_theme`、`WeKnora_${userId}_*`、`weknora_lite_mode` | `stores/settings*.ts`、`stores/auth.ts`、`composables/preferenceStorage.ts`、`composables/useResourcePins.ts`、`index.html` |
| Provider / 功能标识 | `weknoracloud` | `Settings.vue` 菜单 key、模型相关代码 |
| 函数/类型/组件/文件名 | `saveWeKnoraCloudCredentials`、`WeKnoraCloudSettings.vue`、`weknoraCloudModels.ts` 等 | 全前端 |
| 环境变量名 | `WEKNORA_*`（如 `WEKNORA_BASE_URL`） | i18n 说明文案中照写 |
| CLI 二进制 / 配置名 | 命令 `weknora ...`、profile 名 `weknora` | CLI 集成页及 i18n |
| ClawHub 包名 | `@lyingbug/weknora` | i18n Skill 生态说明 |
| 实际镜像名 | `weknora-app`、`weknora-ui` | SystemInfo 版本说明 |
| 嵌入 Widget SDK | 全局对象 `WeKnora.init()`、postMessage source、文件名 `weknora-widget.js` | `public/weknora-widget.js`（客户集成代码依赖） |
| 代码注释 / console 日志 | `[WeKnora] ...` 等 | `main.ts`、`preferenceStorage.ts`、各 .vue/.ts 注释 |
| package.json name | `name` 字段 | `frontend/package.json` |
| 其他语言中的程序标识 | ja/ko/ru 里的 i18n key 名、WeKnora Cloud、协议头/环境变量/包名等 | 随 zh/en 同一白名单保留（品牌自称已全部本地化，见三-D） |

## 五、WeKnora Cloud（保留原名，待功能开关阶段处理）

"WeKnora Cloud" 是腾讯托管的云模型 / 云解析服务（需腾讯 APPID/APPSECRET），属于真实第三方服务名而非单纯品牌自称，故本轮全部保留，涉及：

- 设置菜单一项：`Settings.vue`（key `weknoracloud`，label `WeKnora Cloud`）
- 页面：`views/settings/WeKnoraCloudSettings.vue`、`ParserEngineSettings.vue` 中的云解析引擎选项
- 组件：`ModelEditorDialog.vue` 的 WeKnoraCloud 凭证提示
- i18n：zh-CN / en-US / ja / ko /ru 中 `weknoraCloud` 整组及解析引擎条目（约 15 条/语言，五种语言均保留原名）

后续计划：做版本/功能开关时，将整个菜单与引擎选项在 UI 隐藏，并在后端 API 入口校验（前端隐藏不等于接口禁用）。

## 六、仍指向官方的入口（待决策）

| 入口 | 位置 | 现状 |
|---|---|---|
| 官方文档链接（统一常量） | `utils/docsUrl.ts` 的 `DOCS_BASE_URL = https://weknora.weixin.qq.com/docs/` | 保留；自建文档就绪后改此常量一处即可全局切换 |
| ~~用户菜单 GitHub 项~~ | `components/UserMenu.vue` | **已删除**（菜单项 + `openGithub()` + 死样式）。i18n 键 `common.github` / `common.githubStarTip` 已无引用但保留在 5 个语言文件中，升级时无需处理 |
| ~~用户菜单"帮助与文档"~~ | `components/UserMenu.vue` | **已删除**（菜单项 + `openDocs()` + `docsUrl` import + `.menu-external-icon` 死样式）；i18n 键 `general.helpAndDocs` 保留 |
| ~~设置页 7 处官方文档入口~~ | 成员管理"了解 RBAC"（`TenantMembers.vue`）、模型配置"查看内置模型管理指南"（`ModelSettings.vue`）、IM 集成"查看接入文档"（`IntegrationSettingsSection.vue`）、API 集成"API 文档"整行（`ApiIntegrationSettings.vue`）、CLI 页"查看 CLI 文档/安装说明"CTA（`CliIntegrationLanding.vue`）、沙箱配置"集群搭建指南"（`SandboxSettings.vue`）、知识图谱配置"如何启用知识图谱？"（`GraphSettings.vue`，同时移除 `VITE_KG_GUIDE_URL`/docsUrl 跳转逻辑，警告文案保留） | **已全部删除**（模板链接节点 + handler + 仅此处使用的 import/死样式）；描述正文保留；i18n 键（含 `graphSettings.howToEnable`）均保留未删；CLI 安装命令本身保留 |
| 数据库迁移失败"报告 Issue" | `views/settings/SystemInfo.vue` `reportIssueURL` | 保留：仍指向腾讯 GitHub issue 模板，仅数据库迁移失败的故障场景出现；如需去除删按钮即可 |
| CLI 安装命令 | `views/integrations/CliIntegrationLanding.vue` | 命令/仓库地址保留（改了不可用）；功能开关阶段可整页隐藏 |
| 浏览器扩展商店 | i18n 中"Chrome 应用商店"相关 | 上架自有扩展前保留 |

## 七、跟官方升级时的冲突处理

1. 本文件第三、五、六节列出的路径在 `git merge` 上游代码时是冲突高发区，合并时以"展示值用 AI知识库 / AI Knowledge Base，标识符与 key 保持上游原样"为准则。
2. 上游若新增含 WeKnora 的**可见文案**，升级后需重新扫描：
   ```bash
   grep -RIn --exclude-dir=node_modules --exclude-dir=dist "WeKnora" frontend/src frontend/public frontend/index.html frontend/embed.html
   ```
   并按"客户是否可见"逐行判定。
3. 上游若修改 localStorage key、HTTP 头、provider 标识等，**必须跟随上游**，不可保留旧名。
4. 资源文件 `weknora.png` 建议长期保留文件名（引用点少且升级无冲突）；如需改名，需同步更新 `menu.vue`、`Login.vue` 两处引用。
5. 注意：`frontend/package-lock.json` 的改动与品牌替换无关，合并时按依赖变更正常处理。

## 八、交付提醒

- 品牌改动需重新构建前端镜像后客户才能看到：
  ```bash
  docker compose up -d --build frontend
  ```
  （或 `--build` 整个应用）
- 浏览器端有旧资源缓存时，提示客户 Ctrl+Shift+R 强刷。

## 九、v0.9.0 同步（2026-11-13）

### 同步方式

- `main` 快进到官方 tag `v0.9.0`（`f17ee8a8`，2026-10-29），`branding` 以 merge 合入；升级前备份标签 `backup/branding-pre-0.9.0`。
- 合并前先做「预清理」提交，把冲突从 10 个压到 5 个（i18n 归一化 + 还原无实际定制的上游文件）。

### 定制结构变化

- 新增 `branding-overrides/`：中文提示词、`config.yaml`、Dockerfile 国内加速、docreader 单文件打包、env 模板等非前端定制，改为**交付期覆盖**，分支上的上游文件保持干净。详见 `branding-overrides/README.md`；`scripts/myscripts/package-*.sh` 已自动调用 `apply.sh`。
- `en-US.ts` / `ja-JP.ts` 的 4 空格整文件重排已归一化为上游风格，相对官方的 diff 从约 8000 行降到数十行。
- 语言包扩展到 **6 种**：zh-CN / **zh-TW（补做）** / en-US / ja-JP / ko-KR / ru-RU。0.9.0 每种新增约 1180 行（助手、自动化、审批、空间默认模型），其中 WeKnora 自称已按品牌规则替换。
- 白名单新增：i18n key 名 `searchWeKnoraDocs` / `readWeKnoraDoc` **不得替换**（首次批量替换曾误伤，已修）。其余保留项见第四节。

### 版本门控（edition.ts）

- 新增 key：`nav.assistant`（**助手总开关**）、`nav.automations`、`settings.assistant`、`settings.defaults`、`assistant.collaboration`、`assistant.automations`、`assistant.approvals`。
- **单一总开关**：`edition.ts` 导出 `isAssistantEnabled()`（读 `FEATURE_MATRIX['nav.assistant']`），`ASSISTANT_DEPENDENT_KEYS` 登记了 `settings.assistant` / `nav.automations` / `assistant.*` 等派生功能。`isFeatureEnabled()` 对这些 key 额外要求总开关为 `true`，所以把 `nav.assistant` 一行改成 `false` 时，Logo 旁入口、设置页「助手」、自动化导航、多智能体协作、执行审批、助手引导弹框会一起消失；改成 `true` 则按各自矩阵分档整体恢复。**不用再逐行改 6 个开关。**
- 已接线：Logo 旁 / 折叠态助手按钮、设置 section 过滤与深链守卫、自动化导航与路由守卫、执行权限选择器（`ASSISTANT_CAPABILITIES.approvals()`）、自动化新建按钮（`...automations()`）、聊天「问助手」、Wiki / 文档助手动作按钮；组件统一调用 `isAssistantEnabled()`。
- `settings.defaults`（空间默认模型）与助手无关，不受总开关影响。
- **刻意不接线**：聊天流里的审批卡片 / 协作进度卡片——隐藏会让运行中的任务卡在待审批，`assistant.collaboration` / `assistant.approvals` 只作能力预留，以后要关某个能力请在「入口」处调用。
- 0.8.3 时因 400 报错被注释的助手入口与设置项已恢复，改由门控控制。

### 升级注意

- 官方升级须知：先备份 DB / 文件存储 / 部署配置；PostgreSQL `000119–000134`、SQLite `000037–000051` 迁移；新变量 `WEKNORA_LOG_FORMAT`、`WEKNORA_SANDBOX_USER_ALLOCATION`（需 Redis、全副本升级后才可开）、`WEKNORA_TENANT_DEFAULT_STORAGE_QUOTA_MB`；显式 `docker compose pull`（只 `up -d` 会复用旧镜像）。
- 定制版镜像版本由 `AIRAG_VERSION` 控制，官方 `WEKNORA_VERSION` 不被定制 compose 读取；两者关系写在 `branding-overrides/env/.env.example`。

### 品牌泄漏收口（同日）

- **助手入口整体隐藏才是有效防线**：定制版后端直接用旧版官方镜像（只改镜像名、不编译 Go），后端源码开关不会进入交付二进制。上一轮加在 `registerProductDocTools()` 的 `AIRAG_ENABLE_PRODUCT_DOCS` 已回滚，`agent_service.go` 回到官方 v0.9.0 原文，env 覆盖物里的同名变量也一并移除；详见 `branding-overrides/README.md`「前端功能门控」。
- **不要删空 `website-docs/`**：`website-docs/embed.go` 用 `//go:embed 0*/*.md` 把 74 篇文档编进服务端，删空会让 `go build` 报 `no matching files found`，`docsUrl.test.ts` 也会失败。内置文档含上游品牌与官方站点链接，靠 `edition.ts` 关闭助手面板 / 浮动入口 / 引导弹框兜住。
- 清掉 3 处官方文档外链：`ModelEditorDialog.vue`（compat 文档）、`SandboxConfigEditorDrawer.vue`（集群搭建指南，两处）、`SystemInfo.vue`（迁移排障文档 + 上游 GitHub issue 上报）。微信开发者文档、E2B 控制台等第三方服务商链接保留；迁移失败仍显示完整错误详情。
- 修复：`.env.lite.example` 覆盖物此前被 `.gitignore` 的 `.*` 规则忽略、从未入库，导致 lite 包会拿到官方模板；已加例外规则。
- **CLI 集成**：`settings.integrationCli` 属 edition.ts「彻底隐藏」组，全版本 `false`，导航过滤与深链守卫都已封住，客户进不去该页。`CliIntegrationLanding.vue` 的安装命令已把官方仓库地址换成自有仓库 `https://github.com/zhangjianchun/WeKnora.git`，避免打包产物里残留官方地址；`cd WeKnora/cli` 目录名与 `weknora` 二进制名保持不变（与 fork 仓库一致）。若以后要放开入口，需先确认自有仓库对客户可访问并补齐配套 CLI 说明。

### 0.9.0 新功能按后端能力回退（同日）

- 实测组合：前端 `npm run dev` + 旧版官方后端镜像。助手提问报「流式连接失败: HTTP 400」、自动化报「404 page not found」——`/api/v1/agent-chat`、`/api/v1/automations` 在旧后端不存在，前端无法修补。
- `edition.ts` 后来收敛为「助手总开关」：`nav.assistant` 全版本 `false`，其余派生 key 通过 `ASSISTANT_DEPENDENT_KEYS` 自动跟随（详见「版本门控」）；`platform/index.vue` 用 `v-if` 整体不挂载 `AssistantPanel` / `AssistantLauncher` / `AssistantPageBridge`。菜单两处入口、设置页「助手」、命令面板（原本已注释）、聊天「问助手」、Wiki / 文档 / 知识库的助手动作按钮全部收口。
- 助手「新功能」引导弹框（含 `v0.9.0 新功能` 字样）不再弹出：`NewUserGuide.vue` 增加 `assistantGuideEnabled` prop（默认 `true`，上游单测行为不变），由 `platform/index.vue` 按开关传入；同时调 `markAssistantEntryGuideDone()`，避免该引导标记缺失把页面级情境引导一起卡住。6 种语言的 `assistantEntryGuide.stepOf` 已去掉上游版本号。
- 后端镜像升级到 0.9.0 后，只需把 `edition.ts` 的 `nav.assistant` 一行改回 `true` 即可整体恢复（见「版本门控」的单开关说明），门控接线都还在。

### 后端镜像切换到官方 v0.9.0（同日）

- 拉取 `wechatopenai/weknora-app|docreader|ui:v0.9.0`，三个镜像的 OCI `revision` 均为 `f17ee8a8d`（与 `main` 同步的 v0.9.0 tag 一致）。按交付命名打上 `ghcr.io/zhangjianchun/airag-app:v0.9.0`、`airag-docreader:v0.9.0`；本地 `wechatopenai/weknora-*:latest` 也重新指向 v0.9.0，避免 `:latest` 复用 v0.8.3 缓存。
- 本地开发栈 `E:\zhangjianchun\WeKnora\.env` 增加 `AIRAG_VERSION=v0.9.0`（定制 compose 不读 `WEKNORA_VERSION`）。
- **本地栈与交付 compose 不同代**：运行中的容器是 0.8.3 时代创建的 `WeKnora-*` 名称 / `weknora_*` 数据卷 / `weknora_WeKnora-network` 网络；仓库当前 compose 已改成 `AiRAG-*` / `airag_*` / `airag-network`（给交付包用）。直接 `docker compose up -d` 会挂到另一套数据卷、连不上现有 postgres/redis。因此把资源名对齐回本地栈的覆盖文件放在仓库外 `E:\zhangjianchun\weknora-backups\docker-compose.local-v0.9.0.yml`，只重建 `app` / `docreader`，postgres / redis / frontend 不动。
- 切换前已用 `pg_dumpall` 备份 PostgreSQL 全库到 `E:\zhangjianchun\weknora-backups\weknora-db-20261113-pre-v0.9.0.sql`；`AUTO_MIGRATE=true` 负责 0.9.0 的 `000119–000134` 迁移。
- 前端助手总开关默认仍保持关闭，后端换成 0.9.0 后可按「版本门控」一行放开。
