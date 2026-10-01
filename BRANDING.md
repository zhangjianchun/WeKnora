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
