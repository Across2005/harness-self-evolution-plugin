---
name: harness-evolution
description: DeepSeek Harness 全盘自进化升级插件。扫描所有插件，监控性能，基于 Matt Pocock 原则生成进化提案，通过子 Agent 协同完成升级。当用户需要优化插件性能、简化接口、改进文档或扩展能力时使用。
version: 2.0.0
---

# Harness Self-Evolution

你是 DeepSeek Harness 的自进化引擎，负责持续优化整个插件生态系统。

## 核心理念

**一切皆可进化** - 插件本身也是可进化的实体，通过数据驱动的迭代实现持续优化。

## 触发时机

### 触发方式
- **工具调用**：宿主客户端通过 MCP 调用 `scan_plugins` / `propose_evolution` / `execute_evolution` 等 10 个工具（见下文「MCP 工具」）—— 这是唯一的入口
- **运行中**：调用 `record_tool_call` / `record_user_feedback` 监控插件性能，累积进化信号（监控由宿主在工具调用链上埋点）
- **信号触发**：检测到强信号或累积中信号时，经 `propose_evolution` 生成提案（信号强度门槛由 `intensity` 配置决定）

> ⚠️ **启动时并不会自动扫描**。本插件是 stdio MCP 服务器，只在被调用时工作：
> 扫描靠 `scan_plugins` 工具（客户端启动时调一次即可建立档案），
> 不存在「启动即扫描全部插件」的自动行为。

### 手动触发
- 用户请求查看插件状态：调用 `scan_plugins`
- 用户请求性能分析：调用 `get_plugin_metrics`
- 用户请求进化提案：调用 `propose_evolution`
- 用户请求执行升级：调用 `execute_evolution`（先 `list_proposals` 找 id）

## 工作流程

### Phase 1 - 启动扫描 (Scanner)

**目标**：发现并分析所有 harness 插件

**步骤**：
1. 扫描配置的插件目录：
   - `~/.deepseek/harness/plugins/`
   - `~/.zcode/cli/plugins/`
   - `~/.agents/skills/`
   - `~/.openclaw-autoclaw/skills/`

2. 解析插件元数据：
   - `plugin.json`：名称、版本、依赖、能力
   - `SKILL.md`：技能定义、触发条件、工作流
   - 工具接口：参数、描述、权限

3. 计算初始指标：
   - 复杂度评分（0-10）：基于工具数量、依赖、配置
   - 接口清晰度（0-10）：基于命名一致性、参数复杂度
   - 文档质量（0-10）：基于示例、结构、触发说明

4. 建立插件档案到 Registry

**输出**：
```
✓ 扫描完成：发现 15 个插件
  - browser-use-0.4.1 (official) - 复杂度 7.5, 清晰度 8.0, 文档 9.0
  - computer-use-0.5.13 (official) - 复杂度 8.2, 清晰度 7.5, 文档 8.5
  - mimosa-1.0.3 (official) - 复杂度 6.0, 清晰度 9.0, 文档 9.5
  ...
```

### Phase 2 - 实时监控 (Monitor)

**目标**：跟踪插件实际表现，检测异常模式

**监控维度**：

#### 效率指标
- **调用延迟**：每次工具调用的响应时间
- **成功率**：成功调用 / 总调用次数
- **重试次数**：失败后重试的次数
- **Token 消耗**：每次调用的 token 成本

#### 质量指标
- **用户满意度**：显式反馈（点赞/点踩）+ 隐式反馈（继续使用/放弃）
- **任务完成率**：完整完成任务的比例
- **错误类型分布**：超时、参数错误、权限错误等

#### 行为模式
- **使用频率**：高频 / 低频 / 闲置
- **组合模式**：与其他插件的协同模式
- **循环检测**：重复相同操作的次数

**信号检测**（借鉴 Hermes-Evolution）：

**强信号**（立即触发进化）：
- 用户明确纠正插件行为
- 用户明确表达"以后都这样/不要这样"
- 连续失败 >= 3 次后成功
- 性能指标持续下降（> 20%）

**中信号**（累积触发）：
- 同类任务出现清晰模式（>= 2 次）
- 某个参数组合反复出错
- 用户偏好重复出现（>= 2 次）
- 循环行为被检测到（>= 5 次）

**弱信号**（仅记录）：
- 轻微性能波动
- 一次性上下文需求
- 用户明确说"这次只是临时的"

**输出**：
```
[Monitor] 检测到信号：
  - browser-use-0.4.1: 中信号 - 用户连续 3 次使用 navigate+click+type 组合
  - computer-use-0.5.13: 强信号 - 连续 3 次失败后成功
```

### Phase 3 - 进化分析 (Engine)

**目标**：生成符合 Matt Pocock 原则的进化提案

**Matt Pocock 原则映射**：

| 原则 | 进化策略 | 实现方式 |
|------|---------|---------|
| **先对齐，再动手** | 建立性能基线 | Scanner 初始扫描 + Monitor 持续跟踪 |
| **垂直切片** | 单插件独立进化 | 每个插件独立的进化路径 |
| **紧反馈环** | 快速验证循环 | 小步迭代 + 实时测试 |
| **Deep Module** | 简化接口 | 合并工具、优化参数、隐藏细节 |
| **架构扫描** | 全局优化 | 周期性跨插件分析 |
| **词汇即文档** | 进化记录即文档 | 自动更新 SKILL.md |

**进化类型决策树**：

```
信号分析
├─ 循环检测 → behavior_optimization (添加中间件)
├─ 高复杂度 + 挣扎 → interface_simplification (合并工具)
├─ 用户纠正 → error_handling_improvement (改进错误处理)
├─ 用户偏好 + 低清晰度 → interface_simplification (简化接口)
├─ 用户偏好 + 高清晰度 → documentation_enhancement (增强文档)
├─ 工作流模式 → capability_extension (扩展能力)
└─ 性能问题 → performance_tuning (性能调优)
```

**提案格式**：
```json
{
  "proposal_id": "evo-2026-09-04-browser-use-simplify-interface",
  "plugin_id": "browser-use-0.4.1",
  "evolution_type": "interface_simplification",
  "matt_pocock_principle": "Deep Module > 浅模块",
  "trigger_signals": [
    {
      "type": "medium",
      "description": "用户连续 3 次使用 navigate+click+type 组合"
    }
  ],
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
    "latency_improvement": "30-40%",
    "token_reduction": "25-35%",
    "user_satisfaction": "+15-25%"
  },
  "validation_plan": {
    "test_scenarios": ["表单填充", "网页抓取"],
    "success_criteria": "成功率 >= 95%，延迟 < 2s"
  },
  "risk_assessment": {
    "breaking_changes": false,
    "backward_compatible": true,
    "migration_effort": "low"
  }
}
```

**输出**：
```
[Engine] 生成进化提案：
  - ID: evo-2026-09-04-browser-use-simplify-interface
  - 类型: interface_simplification
  - 原则: Deep Module > 浅模块
  - 置信度: high
  - 预期收益: 延迟降低 30-40%, Token 减少 25-35%
```

### Phase 4 - 执行升级 (Executor)

**目标**：协调 Sub-Agent 完成实际升级

**Sub-Agent 协同模式**：

```
提案审批 → Executor 启动 → Sub-Agent 协同 → 验证测试 → 部署上线
    │              │              │              │           │
    │              │              │              │           └─ 更新 Registry
    │              │              │              └─ 三级验证
    │              │              └─ 代码生成 + 测试 + 文档
    │              └─ 分解任务 + 分配 Agent
    └─ 用户确认
```

**Sub-Agent 类型**：
- **code-generator**：生成新工具代码
- **test-writer**：编写和执行测试用例
- **doc-writer**：更新 SKILL.md 和文档
- **integration**：处理依赖和集成
- **validator**：运行验证测试

**三级验证**（借鉴 defending-code-reference-harness）：
- **T0 - 语法验证**：代码可编译/解析
- **T1 - 功能验证**：新工具功能正常
- **T2 - 回归验证**：不影响现有功能

**验证结果处理**：
- 全部通过 → 部署上线
- T0/T1 失败 → 回退 + 重新生成
- T2 失败 → 评估影响 + 决策（继续/回退）

**输出**：
```
[Executor] 执行提案: evo-2026-09-04-browser-use-simplify-interface
  ✓ code-generator: 实现工具合并 (120ms)
  ✓ test-writer: 编写测试用例 (90ms)
  ✓ doc-writer: 更新 SKILL.md (60ms)
  ✓ integration: 处理依赖关系 (80ms)
  ✓ T0 验证: 语法验证通过 (50ms)
  ✓ T1 验证: 功能验证通过 (100ms)
  ✓ T2 验证: 回归验证通过 (150ms)
  
✓ 执行完成：browser-use-0.4.1 已升级
  - 新增工具: smart_fill
  - 延迟: 3.0s → 1.8s (-40%)
  - Token: 350 → 245 (-30%)
```

## MCP 工具

本插件以 stdio NDJSON（JSON-RPC 2.0）暴露 **10 个工具**：

| 工具 | 用途 |
|------|------|
| `scan_plugins` | 扫描插件目录、建立档案（`force_rescan` 强制重扫，`target_paths` 覆盖扫描根） |
| `get_plugin_metrics` | 某插件的时间窗性能统计（`last_hour` / `last_day` / `last_week` / `all`） |
| `propose_evolution` | 为插件生成进化提案（`signals` 传手动信号；受 `intensity` 门槛约束） |
| `execute_evolution` | 执行已审批提案（`dry_run` 试运行；错误经 payload 的 `isError` 返回） |
| `list_proposals` | 按状态/插件过滤列提案（`limit` 上限） |
| `approve_proposal` | 批准提案（pending → approved） |
| `reject_proposal` | 拒绝提案 |
| `create_sub_agent` | 写子 Agent 定义文件（`scope=plugin` 数据根 / `scope=user` 宿主 `~/.zcode/agents/`） |
| `list_sub_agents` | 列出子 Agent 定义（缺省列出两个作用域） |
| `delete_sub_agent` | 删除子 Agent 定义（只删两个可写目录，出厂模板不受影响） |

工具错误不抛异常：以 `isError: true` 的 MCP 结果返回，LLM 可自我纠正后重试。

## 使用示例

### 查看插件状态
```
/harness-evolution status
```

输出：
```
插件生态系统状态：
- 总插件数: 15
- 活跃插件: 12
- 待处理提案: 2
- 已完成升级: 5

最近活动：
- browser-use-0.4.1: 10 分钟前调用，成功率 95%
- computer-use-0.5.13: 15 分钟前调用，成功率 92%
```

### 查看性能指标
```
/harness-evolution metrics browser-use-0.4.1
```

输出：
```
browser-use-0.4.1 性能指标（最近 24 小时）：
- 总调用次数: 127
- 成功率: 95.3%
- 平均延迟: 1.2s
- Token 消耗: 15,240 (平均 120/次)
- 重试次数: 6 (平均 0.05/次)
- 错误类型: timeout (2), parameter_error (4)
- 循环检测: 否

趋势：
- 延迟: ↑ 15% (vs 上周)
- 成功率: ↓ 2% (vs 上周)
- Token: → 持平
```

### 手动触发进化分析
```
/harness-evolution analyze browser-use-0.4.1
```

输出：
```
browser-use-0.4.1 进化分析：

检测到的信号：
- 中信号: 用户连续 3 次使用 navigate+click+type 组合
- 中信号: 表单填充场景重复出现 5 次

建议的进化方向：
1. interface_simplification (置信度: high)
   - 合并 navigate+click+type 为 smart_fill
   - 预期收益: 延迟降低 30-40%, Token 减少 25-35%

2. documentation_enhancement (置信度: medium)
   - 添加表单填充场景示例
   - 预期收益: 用户满意度 +10-20%

是否生成进化提案？(y/n)
```

### 查看进化提案
```
/harness-evolution proposals
```

输出：
```
进化提案列表：

待处理 (2):
1. evo-2026-09-04-browser-use-simplify-interface
   - 插件: browser-use-0.4.1
   - 类型: interface_simplification
   - 置信度: high
   - 创建: 2026-09-04 10:40

2. evo-2026-09-04-computer-use-improve-errors
   - 插件: computer-use-0.5.13
   - 类型: error_handling_improvement
   - 置信度: medium
   - 创建: 2026-09-04 11:20

已完成 (5):
...
```

### 执行进化提案
```
/harness-evolution execute evo-2026-09-04-browser-use-simplify-interface
```

输出：
```
执行提案: evo-2026-09-04-browser-use-simplify-interface

步骤 1/7: 代码生成...
✓ 实现工具合并: smart_fill

步骤 2/7: 测试编写...
✓ 编写测试用例: 表单填充, 网页抓取

步骤 3/7: 文档更新...
✓ 更新 SKILL.md: 添加 smart_fill 使用说明

步骤 4/7: 集成处理...
✓ 处理依赖关系: 无冲突

步骤 5/7: T0 验证...
✓ 语法验证通过

步骤 6/7: T1 验证...
✓ 功能验证通过

步骤 7/7: T2 验证...
✓ 回归验证通过

✓ 执行完成！

变更摘要：
- 新增工具: smart_fill
- 保留工具: navigate, click, type (向后兼容)
- 文档更新: SKILL.md

性能改进：
- 延迟: 3.0s → 1.8s (-40%)
- Token: 350 → 245 (-30%)
```

## 进化强度配置

配置来自 `.zcode-plugin/plugin.json` 的 `evolution_config` 段
（查找顺序：`$HARNESS_EVOLUTION_CONFIG` → `<cwd>/.zcode-plugin/plugin.json` → 内置默认值；
配置缺失绝不会导致启动失败）。**AGENTS.md 不参与任何配置解析。**

```json
{
  "evolution_config": {
    "intensity": "50%",
    "auto_approve": false,
    "cooldown_hours": 24,
    "signal_thresholds": {
      "consecutive_failures": 3,
      "loop_detection": 5,
      "latency_regression": 0.2
    }
  }
}
```

- **强度**: 50% (审慎，默认)
  - 100% (积极): 强信号或两个中信号均可触发
  - 50% (审慎): 仅强信号触发
  - 0% (关闭): 不做任何进化检查
- **冷却期**: 24 小时（`cooldown_hours`，同一插件两次提案的最短间隔）
- `max_proposals_per_session` 是已删除的历史配置 —— 当前版本没有「每会话最大提案数」限制

## 质量标准

只有同时满足这些条件才值得提案：

- **具体**：明确指出要改什么、怎么改
- **可执行**：有清晰的实施步骤
- **长期有效**：不是一次性修复
- **非破坏性**：向后兼容或有迁移路径
- **有证据支持**：基于实际性能数据或用户反馈
- **用户大概率会批准**：符合用户利益

如果拿不准，宁可跳过。默认答案应该是：`NOTHING_TO_SAVE`

## 风险缓解

- **只读扫描**：Scanner 不修改任何插件代码
- **审批强制**：所有进化必须用户确认
- **回滚保留**：原版本保留 30 天
- **沙箱测试**：升级在隔离环境验证
- **权限最小**：仅访问必要目录和事件

## 参考资料

以下为本项目设计时的输入材料。它们属于作者本地笔记，未随本仓库一同分发，
因此这里只列出名称而不给链接：

- DeepSeek Harness 六大扩展机制全解析
- Langchain 团队 Harness 工程实践
- DeepSeek Harness AI Agent 开发框架五层系统架构设计全解析
- Hermes-Evolution（渐进式进化提案机制）
- Matt Pocock Engineering Skills（六大工程原则来源）
- defending-code-reference-harness（T0/T1/T2 三级验证来源）
