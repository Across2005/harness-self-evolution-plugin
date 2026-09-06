# Harness Self-Evolution Plugin - 设计文档

## 1. 项目概述

### 1.1 核心目标
创建一个针对 DeepSeek Harness 的全盘自进化升级插件，实现：
- **启动时扫描**：自动发现并分析所有 harness 插件
- **实时监控**：跟踪当前对话中各插件的实际表现
- **智能进化**：基于 Matt Pocock 工程原则自动生成升级提案
- **自主迭代**：通过子 Agent 协同完成插件的持续优化

### 1.2 设计理念融合

#### DeepSeek Harness "一切皆插件"
- 插件本身也作为可进化的实体
- 利用六大扩展机制实现自我增强
- 五层架构确保清晰的进化边界

#### Matt Pocock 工程原则
- **先对齐，再动手**：进化前先建立性能基线
- **垂直切片 > 水平切片**：每个插件独立进化路径
- **紧反馈环 > 盲目试错**：实时监控 + 快速验证
- **Deep Module > 浅模块**：进化后接口更简洁
- **定期架构扫描**：周期性全局优化
- **词汇即文档**：进化记录即文档

#### Hermes-Evolution 审慎机制
- **信号驱动**：强信号（失败/纠正）+ 中信号（模式/偏好）
- **提案审批**：所有进化需用户确认
- **重复检测**：避免无效进化
- **分级强度**：100% 积极 / 50% 审慎 / 0% 关闭

## 2. 系统架构

### 2.1 整体架构图

```
┌─────────────────────────────────────────────────────────────┐
│                    Harness Self-Evolution                    │
│                      (ZCode Plugin)                          │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   Scanner    │    │   Monitor    │    │   Engine     │
│  (启动扫描)   │    │  (实时监控)   │    │  (进化引擎)   │
└──────────────┘    └──────────────┘    └──────────────┘
        │                     │                     │
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────────────────────────────────────────────────────┐
│                      Plugin Registry                          │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│  │ Plugin A   │  │ Plugin B   │  │ Plugin C   │  ...       │
│  │ (性能数据) │  │ (性能数据) │  │ (性能数据) │            │
│  └────────────┘  └────────────┘  └────────────┘            │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌──────────────┐
                    │   Executor   │
                    │  (升级执行)   │
                    └──────────────┘
                              │
                              ▼
                    ┌──────────────┐
                    │  Sub-Agents  │
                    │  (协同执行)   │
                    └──────────────┘
```

### 2.2 五层架构映射

遵循 DeepSeek Harness 五层架构：

| 层级 | 职责 | 本插件实现 |
|------|------|-----------|
| **应用层** | 用户交互入口 | SKILL.md (主 skill) |
| **API 层** | 服务调用桥梁 | MCP Server (JSONRPC) |
| **核心层** | 业务逻辑核心 | Engine + Executor |
| **能力层** | 外部能力访问 | Scanner + Monitor |
| **基础层** | 数据持久化 | Plugin Registry (JSONL) |

### 2.3 数据流向

```
启动阶段：
用户启动 → Scanner 扫描 → Plugin Registry 初始化 → 就绪

运行阶段：
用户对话 → Monitor 监控 → 收集性能数据 → 更新 Registry

进化阶段：
性能数据 → Engine 分析 → 生成提案 → 用户审批 → Executor 执行 → Sub-Agent 升级
```

## 3. 核心组件设计

### 3.1 Plugin Scanner（插件扫描器）

**职责**：启动时扫描所有 harness 插件，建立初始档案

**扫描范围**：
```bash
# DeepSeek Harness 插件目录
~/.deepseek/harness/plugins/
~/.deepseek/harness/extensions/

# ZCode 插件目录
~/.zcode/cli/plugins/
~/.zcode/skills/

# 用户自定义插件
<workspace>/.harness/plugins/
```

**扫描内容**：
- 插件元数据（plugin.json）
- 技能定义（SKILL.md）
- 工具接口（tools/）
- 事件监听器（events/）
- Capability 定义（capabilities/）

**输出格式**：
```json
{
  "plugin_id": "browser-use-0.4.1",
  "name": "browser-use",
  "version": "0.4.1",
  "type": "official|community|custom",
  "capabilities": ["browser_control", "web_automation"],
  "tools": ["navigate", "click", "type", "screenshot"],
  "events": ["on_navigation", "on_error"],
  "dependencies": ["@modelcontextprotocol/server"],
  "scan_timestamp": "2026-09-04T10:30:00Z",
  "initial_metrics": {
    "complexity_score": 7.5,
    "interface_clarity": 8.0,
    "documentation_quality": 9.0
  }
}
```

### 3.2 Performance Monitor（性能监控器）

**职责**：实时监控当前对话中各插件的实际表现

**监控维度**（基于 Langchain Harness 工程实践）：

#### 3.2.1 效率指标
- **调用延迟**：工具调用的响应时间
- **成功率**：成功调用 / 总调用次数
- **重试次数**：失败后重试的次数
- **Token 消耗**：每次调用的 token 成本

#### 3.2.2 质量指标
- **用户满意度**：用户反馈（显式 + 隐式）
- **任务完成率**：完整完成任务的比例
- **错误类型分布**：超时、参数错误、权限错误等
- **循环检测**：重复相同操作的次数

#### 3.2.3 行为模式
- **使用频率**：高频 / 低频 / 闲置
- **组合模式**：与其他插件的协同模式
- **上下文适配**：在不同场景下的表现差异

**数据结构**：
```json
{
  "session_id": "sess_743efd36",
  "plugin_id": "browser-use-0.4.1",
  "timestamp": "2026-09-04T10:35:22Z",
  "event_type": "tool_call",
  "event_data": {
    "tool": "navigate",
    "params": {"url": "https://example.com"},
    "latency_ms": 1250,
    "success": true,
    "token_usage": {"input": 150, "output": 80},
    "retry_count": 0
  },
  "context": {
    "task_type": "web_scraping",
    "user_feedback": null,
    "conversation_turn": 5
  }
}
```

### 3.3 Evolution Engine（进化引擎）

**职责**：分析性能数据，生成符合 Matt Pocock 原则的进化提案

#### 3.3.1 信号检测（借鉴 hermes-evolution）

**强信号**（立即触发进化）：
- 用户明确纠正插件行为
- 用户明确表达"以后都这样/不要这样"
- 连续失败 >= 3 次
- 性能指标持续下降（> 20%）

**中信号**（累积触发）：
- 同类任务出现清晰模式
- 某个参数组合反复出错
- 用户偏好重复出现（>= 2 次）
- 循环行为被检测到

**弱信号**（仅记录）：
- 轻微性能波动
- 一次性上下文需求
- 用户明确说"这次只是临时的"

#### 3.3.2 进化策略（Matt Pocock 原则映射）

| 原则 | 进化策略 | 实现方式 |
|------|---------|---------|
| **先对齐，再动手** | 建立性能基线 | Scanner 初始扫描 + Monitor 持续跟踪 |
| **垂直切片** | 单插件独立进化 | 每个插件独立的进化路径 |
| **紧反馈环** | 快速验证循环 | 小步迭代 + 实时测试 |
| **Deep Module** | 简化接口 | 合并工具、优化参数、隐藏细节 |
| **架构扫描** | 全局优化 | 周期性跨插件分析 |
| **词汇即文档** | 进化记录即文档 | 自动更新 SKILL.md |

#### 3.3.3 进化提案格式

```json
{
  "proposal_id": "evo-2026-09-04-browser-use-simplify-interface",
  "plugin_id": "browser-use-0.4.1",
  "trigger_signals": [
    {
      "type": "medium",
      "description": "用户连续 3 次使用 navigate + click + type 组合",
      "evidence": "session_logs/sess_743efd36.jsonl"
    }
  ],
  "evolution_type": "interface_simplification",
  "matt_pocock_principle": "Deep Module > 浅模块",
  "proposed_changes": {
    "merge_tools": [
      {
        "new_tool": "smart_fill",
        "merged_from": ["navigate", "click", "type"],
        "new_interface": {
          "params": ["url", "selector", "text"],
          "description": "一站式表单填充：导航 + 定位 + 输入"
        }
      }
    ],
    "simplify_params": [
      {
        "tool": "screenshot",
        "remove_params": ["format", "quality"],
        "defaults": {"format": "png", "quality": 90}
      }
    ]
  },
  "expected_benefits": {
    "latency_improvement": "30%",
    "token_reduction": "25%",
    "user_satisfaction": "+15%"
  },
  "validation_plan": {
    "test_scenarios": ["form_filling", "web_scraping"],
    "success_criteria": "成功率 >= 95%，延迟 < 1s",
    "rollback_strategy": "保留原工具 30 天"
  },
  "risk_assessment": {
    "breaking_changes": false,
    "backward_compatible": true,
    "migration_effort": "low"
  }
}
```

### 3.4 Upgrade Executor（升级执行器）

**职责**：执行进化提案，协调 Sub-Agent 完成实际升级

#### 3.4.1 执行流程

```
提案审批 → Executor 启动 → Sub-Agent 协同 → 验证测试 → 部署上线
    │              │              │              │           │
    │              │              │              │           └─ 更新 Registry
    │              │              │              └─ 回归测试
    │              │              └─ 代码生成 + 文档更新
    │              └─ 分解任务 + 分配 Agent
    └─ 用户确认
```

#### 3.4.2 Sub-Agent 协同模式

**Agent 类型**：
- **Code Generator Agent**：生成新工具代码
- **Test Agent**：编写和执行测试用例
- **Doc Writer Agent**：更新 SKILL.md 和文档
- **Integration Agent**：处理依赖和集成

**协同示例**：
```javascript
// Executor 分解任务
const tasks = [
  {
    agent: "code-generator",
    task: "实现 smart_fill 工具，合并 navigate + click + type",
    input: proposal.proposed_changes.merge_tools[0]
  },
  {
    agent: "test-writer",
    task: "为 smart_fill 编写测试用例",
    input: proposal.validation_plan.test_scenarios
  },
  {
    agent: "doc-writer",
    task: "更新 SKILL.md，添加 smart_fill 使用说明",
    input: proposal.proposed_changes.merge_tools[0].new_interface
  }
];

// 并行执行
await Promise.all(tasks.map(t => spawnAgent(t)));
```

#### 3.4.3 验证机制

**三级验证**（借鉴 defending-code-reference-harness）：
1. **T0 - 语法验证**：代码可编译/解析
2. **T1 - 功能验证**：新工具功能正常
3. **T2 - 回归验证**：不影响现有功能

**验证结果处理**：
- 全部通过 → 部署上线
- T0/T1 失败 → 回退 + 重新生成
- T2 失败 → 评估影响 + 决策（继续/回退）

## 4. 技术实现细节

### 4.1 插件元数据结构

> ⚠️ **2.0 更正**：本节与 §4.2、§4.3 是 **1.0 阶段的设计草图**，其中有几处
> **连 1.0 的实现都从未符合过**，保留原文是为了留下设计意图的痕迹，
> 但不得当作现状来读：
>
> | 草图里的内容 | 实际情况 |
> |---|---|
> | `server.addTool` / `server.addEventHandler` | 1.0 用的是 `@modelcontextprotocol/sdk` 的 `McpServer.registerTool`；2.0 是**自研 stdio JSON-RPC**（`src/mcp/`） |
> | `on_plugin_call` / `on_user_feedback` 两个事件 | **从未注册过**（实测：`legacy-ts/src/mcp/server.ts` 只有 `registerTool`，无任何 `registerEvent`） |
> | `~/.harness-evolution/registry.jsonl` | **从未存在**。注册表是进程内存（`ServerState.registry`），落盘的是 `plugin-cache.json` |
> | `scan_timestamp` / `status` 字段 | 真实字段名是 `scanned_at`（Unix 毫秒），且没有 `status` |
> | `main: "./dist/mcp/server.js"` | 2.0 是 `"./bin/harness-evolution.exe"` |
>
> **权威来源**：接口契约看 `README.md` 的「API」节与 `.zcode-plugin/plugin.json`；
> 词汇与不变量看 `CONTEXT.md`；数据结构看 `src/types/*.mbt`。

下面是 2.0 的真实清单（与仓库里的 `.zcode-plugin/plugin.json` 一致）：

```json
// .zcode-plugin/plugin.json
{
  "name": "harness-self-evolution",
  "version": "2.1.0",
  "description": "DeepSeek Harness 全盘自进化升级插件 - 插件扫描、实时监控、智能进化、协同升级（MoonBit native）",
  "author": {
    "name": "AI Agent Designer",
    "email": "Across2005@users.noreply.github.com"
  },
  "license": "MIT",
  "keywords": [
    "harness",
    "evolution",
    "self-improvement",
    "matt-pocock",
    "hermes",
    "plugin-optimization",
    "moonbit"
  ],
  "repository": {
    "type": "git",
    "url": "git+https://github.com/Across2005/harness-self-evolution-plugin.git"
  },
  "main": "./bin/harness-evolution.exe",
  "skills": "./skills",
  "agents": "./agents",
  "capabilities": [
    "plugin_scanning",
    "performance_monitoring",
    "evolution_engine",
    "upgrade_execution",
    "sub_agent_orchestration"
  ],
  "mcp": {
    "transport": "stdio",
    "protocolVersion": "2024-11-05",
    "tools": [
      "scan_plugins",
      "get_plugin_metrics",
      "propose_evolution",
      "execute_evolution",
      "list_proposals",
      "approve_proposal",
      "reject_proposal",
      "create_sub_agent",
      "list_sub_agents",
      "delete_sub_agent"
    ]
  },
  "dependencies": {},
  "devDependencies": {},
  "engines": {
    "zcode": ">=0.5.0"
  },
  "evolution_config": {
    "intensity": "50%",
    "auto_approve": false,
    "cooldown_hours": 24,
    "max_log_bytes": 33554432,
    "signal_thresholds": {
      "consecutive_failures": 3,
      "loop_detection": 5,
      "latency_regression": 0.2
    }
  },
  "scan_targets": [
    "~/.deepseek/harness/plugins/",
    "~/.deepseek/harness/extensions/",
    "~/.zcode/cli/plugins/",
    "~/.zcode/skills/",
    "~/.agents/skills/",
    "~/.openclaw-autoclaw/skills/"
  ],
  "monitoring": {
    "enabled": true,
    "sample_rate": 1.0,
    "metrics": [
      "latency",
      "success_rate",
      "token_usage",
      "retry_count",
      "user_feedback"
    ]
  }
}
```

三处与草图不同的要点：

- **运行时零依赖**：`dependencies` 是空对象（`devDependencies` 同样为空 ——
  构建依赖是 MoonBit 工具链，不在这里声明），`engines` 里没有 `node`。
  产物是独立的 native 可执行文件，构建期才需要 MoonBit + MSVC。
- **`max_proposals_per_session` 已删除**：1.0 里它被赋值后从未参与任何判定。
- **`evolution_config` 在 2.0 真的会被读取**（1.0 是一处配置孤岛：写了但
  没有任何代码读）。`signal_thresholds` 同时接受扁平形状（2.0 规范，键名与
  `SignalThresholds` 字段逐字相同）与 1.0 的 `strong`/`medium` 嵌套形状（回退）。
- **`agents` 指向出厂子 Agent 模板目录**（5 个 `.md`，随插件分发；
  经 `create_sub_agent` 在数据根/宿主目录新建或覆盖的是**另一批**文件）。
- **`mcp` 段声明了 10 个工具**（前 7 个为 1.0 的 legacy 顺序，后 3 个为
  v2.1 子 Agent 工厂新增）；实现侧的真实清单见 `src/mcp/tools.mbt`。
- **`scan_targets` 是配置孤岛**（有意保留，见 `CONTEXT.md`）：扫描根在
  `scan_plugins` 调用时由 `ServerState` 提供，`plugin.json` 的该段不被
  `src/scanner/` 读取。
- **`monitoring` 段目前不参与行为**：监控事件由宿主经 MCP 工具调用链埋点
  （`record_tool_call` / `record_user_feedback` 的注入缝），
  `enabled` / `sample_rate` 尚无消费方 —— 与 `scan_targets` 一样属于
  「声明了但当前不生效」的配置项。
- **`max_log_bytes`（32 MiB）会真的被读取**：`metrics.jsonl` / `signals.jsonl`
  的裁剪上限（`flush_buffers` → `trim_to`）。

### 4.2 MCP Server 接口

```typescript
// dist/mcp/server.ts
import { Server } from '@modelcontextprotocol/server';

const server = new Server({
  name: 'harness-self-evolution',
  version: '1.0.0'
});

// 工具定义
server.addTool({
  name: 'scan_plugins',
  description: '扫描所有 harness 插件并建立档案',
  parameters: {
    type: 'object',
    properties: {
      force_rescan: { type: 'boolean', default: false }
    }
  },
  handler: async (params) => {
    return await scanner.scanAll(params.force_rescan);
  }
});

server.addTool({
  name: 'get_plugin_metrics',
  description: '获取指定插件的性能指标',
  parameters: {
    type: 'object',
    properties: {
      plugin_id: { type: 'string' },
      time_range: { 
        type: 'string', 
        enum: ['last_hour', 'last_day', 'last_week', 'all']
      }
    },
    required: ['plugin_id']
  },
  handler: async (params) => {
    return await monitor.getMetrics(params.plugin_id, params.time_range);
  }
});

server.addTool({
  name: 'propose_evolution',
  description: '为指定插件生成进化提案',
  parameters: {
    type: 'object',
    properties: {
      plugin_id: { type: 'string' },
      signals: { type: 'array', items: { type: 'string' } }
    },
    required: ['plugin_id']
  },
  handler: async (params) => {
    return await engine.generateProposal(params.plugin_id, params.signals);
  }
});

server.addTool({
  name: 'execute_evolution',
  description: '执行已审批的进化提案',
  parameters: {
    type: 'object',
    properties: {
      proposal_id: { type: 'string' }
    },
    required: ['proposal_id']
  },
  handler: async (params) => {
    return await executor.execute(params.proposal_id);
  }
});

// 事件监听
// ⚠️ 下面这段**从未实现**。1.0 没有调用过任何 registerEvent，
// 2.0 也没有 —— 本插件不注册 MCP Event（1.0/2.0 时是 7 个工具；
// v2.1 又新增 3 个子 Agent 工厂工具，现共 10 个，见 docs/subagent-factory.md）。
// 而「性能事件在采集」这句原先也是**失实的**，2026-09 复核时改掉：
// monitor 的 record_tool_call / record_user_feedback 在全仓（含 1.0）都**没有
// 生产调用方**，MCP 只暴露读取用的 get_plugin_metrics —— 采集链的第一环没有输入，
// metrics.jsonl 只被动等待一个不存在的喂数据方。详见 CONTEXT.md 已知缺陷第 9 条。
server.addEventHandler('on_plugin_call', async (event) => {
  await monitor.recordEvent(event);
});

server.addEventHandler('on_user_feedback', async (event) => {
  await monitor.recordFeedback(event);
  await engine.checkSignals(event.plugin_id);
});
```

### 4.3 Plugin Registry 数据结构

> ⚠️ **2.0 更正**：`registry.jsonl` **从未存在**。
> 注册表是进程内存里的 `ServerState.registry`（`Array` 作事实来源 +
> `Map` 作 id→下标索引），由 `scan_plugins` 每次重建；
> 落盘的只有带目录指纹的 `plugin-cache.json`。
> 下面这段保留作为设计意图的记录，字段名也与真实 schema 不符
> （真实字段是 `scanned_at`，Unix 毫秒；且没有 `status`）。
> 真实的文件布局见 `CONTEXT.md` 的「数据文件布局」。

```jsonl
// ~/.harness-evolution/registry.jsonl   ← 设计草图，未实现
{"plugin_id":"browser-use-0.4.1","name":"browser-use","version":"0.4.1","type":"official","scan_timestamp":"2026-09-04T10:30:00Z","status":"active"}
{"plugin_id":"computer-use-0.5.13","name":"computer-use","version":"0.5.13","type":"official","scan_timestamp":"2026-09-04T10:30:05Z","status":"active"}
{"plugin_id":"mimosa-1.0.3","name":"mimosa","version":"1.0.3","type":"official","scan_timestamp":"2026-09-04T10:30:10Z","status":"active"}
```

```jsonl
// ~/.harness-evolution/metrics.jsonl
{"timestamp":"2026-09-04T10:35:22Z","plugin_id":"browser-use-0.4.1","event_type":"tool_call","tool":"navigate","latency_ms":1250,"success":true,"token_usage":{"input":150,"output":80}}
{"timestamp":"2026-09-04T10:35:25Z","plugin_id":"browser-use-0.4.1","event_type":"tool_call","tool":"click","latency_ms":850,"success":true,"token_usage":{"input":120,"output":60}}
{"timestamp":"2026-09-04T10:35:28Z","plugin_id":"browser-use-0.4.1","event_type":"tool_call","tool":"type","latency_ms":920,"success":true,"token_usage":{"input":130,"output":70}}
```

```jsonl
// ~/.harness-evolution/proposals.jsonl
{"proposal_id":"evo-2026-09-04-browser-use-simplify-interface","plugin_id":"browser-use-0.4.1","status":"pending","created_at":"2026-09-04T10:40:00Z","trigger_signals":["medium:用户连续3次使用navigate+click+type组合"]}
```

## 5. 主 Skill 设计

### 5.1 SKILL.md 结构

```markdown
---
name: harness-evolution
description: DeepSeek Harness 全盘自进化升级插件。启动时扫描所有插件，实时监控性能，基于 Matt Pocock 原则自动生成进化提案，通过子 Agent 协同完成升级。
version: 1.0.0
---

# Harness Self-Evolution

## 触发时机

- **启动时**：自动扫描所有 harness 插件
- **运行中**：实时监控插件性能
- **信号触发**：检测到强信号或累积中信号
- **用户请求**：用户主动请求进化分析

## 工作流程

### Phase 1 - 启动扫描
1. 扫描所有 harness 插件目录
2. 解析 plugin.json 和 SKILL.md
3. 建立初始档案到 Registry
4. 输出扫描报告

### Phase 2 - 实时监控
1. 监听所有插件调用事件
2. 记录性能指标到 metrics.jsonl
3. 检测异常模式（循环、失败、延迟）
4. 累积信号强度

### Phase 3 - 进化分析
1. 分析性能数据
2. 应用 Matt Pocock 原则
3. 生成进化提案
4. 提交用户审批

### Phase 4 - 执行升级
1. 分解升级任务
2. 协调 Sub-Agent 执行
3. 三级验证测试
4. 部署并更新文档

## 使用示例

### 查看插件状态
/harness-evolution status

### 查看性能指标
/harness-evolution metrics browser-use

### 手动触发进化分析
/harness-evolution analyze browser-use

### 查看进化提案
/harness-evolution proposals

### 执行进化提案
/harness-evolution execute evo-2026-09-04-browser-use-simplify-interface
```

## 6. 进化示例场景

### 6.1 场景：简化浏览器自动化接口

**背景**：
- 用户连续 5 次对话中使用 `navigate → click → type` 组合
- 平均延迟 3s，token 消耗 350
- 用户反馈："每次都要三步，太麻烦了"

**信号检测**：
- 中信号：同类任务出现清晰模式（5 次）
- 中信号：用户偏好重复出现（2 次）
- 强信号：用户明确表达不满

**进化提案**：
```json
{
  "evolution_type": "interface_simplification",
  "matt_pocock_principle": "Deep Module > 浅模块",
  "proposed_changes": {
    "merge_tools": [{
      "new_tool": "smart_fill",
      "merged_from": ["navigate", "click", "type"],
      "new_interface": {
        "params": ["url", "selector", "text"],
        "description": "一站式表单填充"
      }
    }]
  },
  "expected_benefits": {
    "latency_improvement": "40%",
    "token_reduction": "30%",
    "user_satisfaction": "+20%"
  }
}
```

**执行过程**：
1. Code Generator Agent 生成 `smart_fill` 工具代码
2. Test Agent 编写测试用例（表单填充场景）
3. Doc Writer Agent 更新 SKILL.md
4. Integration Agent 处理依赖关系
5. 三级验证通过后部署

**结果**：
- 新工具 `smart_fill` 上线
- 延迟降至 1.8s（-40%）
- Token 降至 245（-30%）
- 用户满意度提升

### 6.2 场景：优化循环检测

**背景**：
- Monitor 检测到 `screenshot` 工具在同一页面连续调用 8 次
- 用户陷入"截图 - 调整 - 再截图"循环
- Token 消耗激增

**信号检测**：
- 强信号：循环行为被检测到（> N 次阈值）

**进化提案**：
```json
{
  "evolution_type": "behavior_optimization",
  "matt_pocock_principle": "紧反馈环 > 盲目试错",
  "proposed_changes": {
    "add_middleware": {
      "name": "loop_detection",
      "target_tool": "screenshot",
      "threshold": 5,
      "intervention": "检测到循环，建议使用 batch_screenshot 或调整参数"
    }
  }
}
```

**执行过程**：
1. Code Generator Agent 实现 loop_detection 中间件
2. Integration Agent 集成到工具调用链
3. Test Agent 验证循环检测逻辑
4. 部署并监控效果

**结果**：
- 循环次数降至平均 2 次
- Token 消耗减少 60%
- 用户获得及时提示

## 7. 风险与缓解

### 7.1 风险矩阵

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|---------|
| 进化导致功能回退 | 高 | 中 | 三级验证 + 回滚机制 |
| 过度进化（噪音） | 中 | 中 | 信号强度阈值 + 冷却期 |
| Sub-Agent 协同失败 | 中 | 低 | 任务重试 + 降级方案 |
| 性能监控开销 | 低 | 高 | 采样率调整 + 异步记录 |
| 用户审批疲劳 | 中 | 中 | 智能合并提案 + 批量审批 |

### 7.2 安全边界

- **只读扫描**：Scanner 不修改任何插件代码
- **审批强制**：所有进化必须用户确认
- **回滚保留**：原版本保留 30 天
- **沙箱测试**：升级在隔离环境验证
- **权限最小**：仅访问必要目录和事件

## 8. 未来扩展

### 8.1 短期（1-3 个月）
- 支持更多插件类型（MCP server、CLI tool）
- 优化 Sub-Agent 协同效率
- 增强可视化（性能仪表盘）

### 8.2 中期（3-6 个月）
- 跨插件协同优化（发现组合模式）
- 机器学习预测进化需求
- 社区进化提案共享

### 8.3 长期（6-12 个月）
- 完全自主进化（减少人工审批）
- 进化效果量化评估
- 插件生态系统健康度监控

## 9. 参考资料

- DeepSeek Harness 六大扩展机制全解析
- Langchain 团队 Harness 工程实践
- DeepSeek Harness 五层系统架构设计
- Matt Pocock Engineering Skills
- Hermes-Evolution
- defending-code-reference-harness

以上为本项目设计时的输入材料，属作者本地笔记，未随仓库分发。
