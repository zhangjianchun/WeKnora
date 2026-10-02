/**
 * AI 知识库 · 销售版本控制
 * ============================================================
 * 所有版本配置集中在本文件。
 *
 * 交付不同版本时：
 *   1. 修改 CURRENT_EDITION 这一行的值
 *   2. 重新构建前端镜像：docker compose build frontend
 *
 * 想把某个功能移到某个版本时：
 *   只改 FEATURE_MATRIX 里对应那一行即可。
 *
 * 注意：纯前端 UI 门控，不做后端鉴权。
 * ============================================================
 */

export type Edition = 'lite' | 'pro' | 'enterprise'

/** 交付时改这一行：'lite' | 'pro' | 'enterprise' */
export const CURRENT_EDITION: Edition = 'lite'

// -------- 功能 key 定义 --------
// 新增受控功能时：① 在这里加 key；② 在 FEATURE_MATRIX 里加对应一行；③ 在对应 section 映射表登记
export type FeatureKey =
  // ==================== 左侧主导航 ====================
  | 'nav.toolbox'                    // 工具箱
  | 'nav.artifact'                   // 产物
  | 'nav.sharedSpace'                // 共享空间
  // ==================== 系统设置 ====================
  | 'settings.personalMemory'        // 我的记忆
  | 'settings.members'               // 成员管理
  | 'settings.chathistory'           // 消息管理
  | 'settings.longTermMemory'        // 长期记忆
  | 'settings.ollama'                // Ollama
  | 'settings.weknoraCloud'          // WeKnora Cloud
  | 'settings.integrationIm'         // IM 集成
  | 'settings.integrationEmbed'      // 网页嵌入
  | 'settings.integrationApi'        // API 集成
  | 'settings.integrationMcpServer'  // MCP Server
  | 'settings.integrationCli'        // CLI
  | 'settings.integrationChrome'     // Chrome 插件
  | 'settings.integrationClaw'       // Claw Skill
  | 'settings.sandbox'               // 沙箱配置
  | 'settings.websearch'             // 网络搜索
  | 'settings.adminSystem'           // 系统设置（系统管理）
  | 'settings.adminModelCatalog'     // 模型目录
  | 'settings.adminTaskQueue'        // 任务队列
  | 'settings.adminApiKey'           // 平台 API Key
  | 'settings.adminAuditLog'         // 审计日志
  // ==================== 知识库设置 ====================
  | 'kb.multimodal'                  // 知识库 · 图像处理
  | 'kb.asr'                         // 知识库 · 音频处理
  | 'kb.graph'                       // 知识库 · 知识图谱
  | 'kb.datasource'                  // 知识库 · 数据源
  | 'kb.share'                       // 知识库 · 共享管理
  | 'kb.activity'                    // 知识库 · 活动记录
  // ==================== 编辑智能体 ====================
  | 'agent.suggestions'              // 智能体 · 对话推荐
  | 'agent.conversation'             // 智能体 · 多轮对话
  | 'agent.websearch'                // 智能体 · 网络搜索
  | 'agent.tools'                    // 智能体 · 工具配置
  | 'agent.mcp'                      // 智能体 · MCP 服务
  | 'agent.multimodal'               // 智能体 · 附件上传
  | 'agent.skills'                   // 智能体 · 技能
  | 'agent.share'                    // 智能体 · 发布集成

// -------- 版本矩阵：每个功能一行，想移动功能只改这一行 --------
// true = 该版本显示，false = 该版本隐藏
const FEATURE_MATRIX: Record<FeatureKey, Record<Edition, boolean>> = {
  // ═══════════════ 左侧主导航 ═══════════════
  'nav.toolbox':     { lite: false, pro: false, enterprise: false },  // 工具箱（沙箱 bug 隐藏）
  'nav.artifact':    { lite: false, pro: false, enterprise: false },  // 产物（隐藏）
  'nav.sharedSpace': { lite: false, pro: true,  enterprise: true  },  // 共享空间（pro+）

  // ═══════════════ 系统设置 ═══════════════
  // --- 基础（所有版本）---
  'settings.ollama':          { lite: true,  pro: true,  enterprise: true  },  // Ollama（本地部署核心）
  'settings.members':         { lite: true, pro: true,  enterprise: true  },  // 成员管理

  // --- 进阶（pro+）---
  'settings.personalMemory':  { lite: false,  pro: true,  enterprise: true  },  // 我的记忆
  'settings.longTermMemory':  { lite: false, pro: true,  enterprise: true  },  // 长期记忆
  'settings.websearch':       { lite: false, pro: true,  enterprise: true  },  // 网络搜索（会出域，lite 不给）（添加搜索引擎设置多个搜索工具

  // --- 高级（仅 enterprise）---
  'settings.integrationIm':         { lite: false, pro: false,  enterprise: true  },  // IM 集成
  'settings.integrationApi':        { lite: false, pro: false, enterprise: true  },  // API 集成
  'settings.integrationMcpServer':  { lite: false, pro: false, enterprise: true  },  // MCP Server

  // --- 彻底隐藏 ---
  'settings.chathistory':          { lite: false, pro: false, enterprise: false },  // 消息管理
  'settings.weknoraCloud':         { lite: false, pro: false, enterprise: false },  // WeKnora Cloud
  'settings.integrationEmbed':     { lite: false, pro: false, enterprise: false },  // 网页嵌入
  'settings.integrationCli':       { lite: false, pro: false, enterprise: false },  // CLI
  'settings.integrationChrome':    { lite: false, pro: false, enterprise: false },  // Chrome 插件
  'settings.integrationClaw':      { lite: false, pro: false, enterprise: false },  // Claw Skill
  'settings.sandbox':              { lite: false, pro: false, enterprise: false },  // 沙箱配置（bug）
  
  'settings.adminSystem':          { lite: true, pro: true, enterprise: true },  // 系统设置（超管专有）
  'settings.adminModelCatalog':    { lite: false, pro: false, enterprise: false },  // 模型目录（bug + 超管专有）
  'settings.adminTaskQueue':       { lite: true, pro: true, enterprise: true },  // 任务队列（超管专有）
  'settings.adminApiKey':          { lite: false, pro: false, enterprise: true },  // 平台 API Key（超管专有）
  'settings.adminAuditLog':        { lite: true, pro: true, enterprise: true },  // 审计日志（超管专有）

  // ═══════════════ 知识库设置 ═══════════════
  // --- 基础 ---
  'kb.activity':   { lite: true,  pro: true,  enterprise: true  },  // 活动记录

  // --- 进阶（pro+）---
  'kb.multimodal': { lite: false, pro: true,  enterprise: true  },  // 图像处理
  'kb.graph':      { lite: false, pro: true,  enterprise: true  },  // 知识图谱
  'kb.share':      { lite: false, pro: true,  enterprise: true  },  // 共享管理

  // --- 高级（仅 enterprise）---
  'kb.asr':        { lite: false, pro: false, enterprise: true  },  // 音频处理
  'kb.datasource': { lite: false, pro: false, enterprise: true  },  // 数据源（拉外部数据）

  // ═══════════════ 编辑智能体 ═══════════════
  // --- 基础 ---
  'agent.conversation': { lite: true,  pro: true,  enterprise: true  },  // 多轮对话
  'agent.suggestions':  { lite: true,  pro: true,  enterprise: true  },  // 问题推荐
  'agent.multimodal':   { lite: true,  pro: true,  enterprise: true  },  // 附件上传
  'agent.tools':        { lite: true,  pro: true,  enterprise: true  },  // 工具配置
  'agent.websearch':    { lite: true, pro: true,  enterprise: true  },  // 网络搜索 （设置用那个搜索引擎）上级在 系统设置网络搜索 

  // --- 进阶（pro+）---
  'agent.share':        { lite: false, pro: true,  enterprise: true  },  // 发布集成 共享空间

  // --- 高级（仅 enterprise）---
  'agent.mcp':          { lite: false, pro: false, enterprise: true  },  // MCP 服务

  // --- 彻底隐藏 ---
  'agent.skills':       { lite: false, pro: false, enterprise: false },  // 技能（沙箱 bug）
}

// -------- 消费方 section key → feature key 映射 --------
// 只登记需要分档的项；不在映射表里的 key 一律视为"所有版本可见"。

/**
 * 左侧主导航 path → feature key 映射
 * 说明：menu.ts 的 visibleMenuArr 与 router 守卫使用此表判断导航项是否显示。
 * 添加新的受控导航项时，在此登记。
 */
export const NAV_PATH_FEATURE: Record<string, FeatureKey> = {
  toolbox: 'nav.toolbox',
  artifacts: 'nav.artifact',
  organizations: 'nav.sharedSpace',
}

/**
 * 系统设置 section key → feature key 映射
 * 说明：Settings.vue 的 navItems 过滤、URL 深链与快捷导航守卫使用此表。
 * 新增受控设置页时，在此登记。
 */
export const SETTINGS_SECTION_FEATURE: Record<string, FeatureKey> = {
  mymemory: 'settings.personalMemory',
  members: 'settings.members',
  chathistory: 'settings.chathistory',
  memory: 'settings.longTermMemory',
  ollama: 'settings.ollama',
  weknoracloud: 'settings.weknoraCloud',
  'integration-im': 'settings.integrationIm',
  'integration-embed': 'settings.integrationEmbed',
  'integration-api': 'settings.integrationApi',
  'integration-mcpserver': 'settings.integrationMcpServer',
  'integration-cli': 'settings.integrationCli',
  'integration-chrome': 'settings.integrationChrome',
  'integration-claw': 'settings.integrationClaw',
  sandbox: 'settings.sandbox',
  websearch: 'settings.websearch',
  'system-global': 'settings.adminSystem',
  'model-catalog': 'settings.adminModelCatalog',
  'runtime-queues': 'settings.adminTaskQueue',
  'platform-api-keys': 'settings.adminApiKey',
  'system-audit-log': 'settings.adminAuditLog',
}

/**
 * 知识库设置弹框 section key → feature key 映射
 * 说明：KnowledgeBaseEditorModal.vue 的 navItems 过滤与深链守卫使用此表。
 * 新增受控知识库设置页时，在此登记。
 */
export const KB_SECTION_FEATURE: Record<string, FeatureKey> = {
  multimodal: 'kb.multimodal',
  asr: 'kb.asr',
  graph: 'kb.graph',
  datasource: 'kb.datasource',
  share: 'kb.share',
  activity: 'kb.activity',
}

/**
 * 编辑智能体弹框 section key → feature key 映射
 * 说明：AgentEditorModal.vue 的 navItems 过滤、初始 section 解析与字段高亮守卫使用此表。
 * 新增受控智能体设置页时，在此登记。
 */
export const AGENT_SECTION_FEATURE: Record<string, FeatureKey> = {
  suggestions: 'agent.suggestions',
  conversation: 'agent.conversation',
  websearch: 'agent.websearch',
  tools: 'agent.tools',
  mcp: 'agent.mcp',
  multimodal: 'agent.multimodal',
  skills: 'agent.skills',
  share: 'agent.share',
}

// -------- 解析当前版本 --------
function resolveEdition(): Edition {
  // 开发时可用 localStorage 快速切换测试
  if (import.meta.env.DEV) {
    const override = typeof window !== 'undefined' ? window.localStorage.getItem('AIKB_EDITION') : null
    if (override === 'lite' || override === 'pro' || override === 'enterprise') return override
  }
  // 构建时可用 VITE_EDITION 环境变量覆盖
  const envEdition = import.meta.env.VITE_EDITION as string | undefined
  if (envEdition === 'lite' || envEdition === 'pro' || envEdition === 'enterprise') return envEdition
  return CURRENT_EDITION
}

const EDITION: Edition = resolveEdition()

// -------- 通用判断 --------

/** 判断功能 key 在当前版本是否开放 */
export function isFeatureEnabled(key: FeatureKey): boolean {
  return FEATURE_MATRIX[key]?.[EDITION] ?? false
}

/** 判断某个 section/path key 在当前版本是否开放（不在表里的放行） */
export function isSectionEnabledByEdition(
  mapping: Record<string, FeatureKey>,
  sectionKey: string | undefined | null,
): boolean {
  if (!sectionKey) return true
  const feature = mapping[sectionKey]
  return feature ? isFeatureEnabled(feature) : true
}

/** 当前版本名（调试用） */
export const EDITION_NAME = EDITION
