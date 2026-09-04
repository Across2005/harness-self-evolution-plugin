# CONTEXT — 领域词汇表

本文件是团队与 AI 的共享语言。所有代码、文档、提案、对话统一使用下述术语。
发现新概念时先在这里登记，再写代码（词汇即文档）。

## 核心概念

| 术语 | 含义 | 代码位置 |
|------|------|----------|
| **Plugin（插件）** | Harness 生态中可被扫描、监控、进化的功能单元，以 `plugin_id`（`name-version`）唯一标识 | `scanner/` |
| **Plugin Profile（插件档案）** | 扫描得到的插件元数据：工具列表、能力、依赖、初始指标 | `types.PluginMetadata` |
| **Performance Event（性能事件）** | 一次工具调用/事件触发/能力使用的原始记录，写入 `metrics.jsonl` | `monitor/` |
| **Evolution Signal（进化信号）** | 从事件中提炼的进化触发证据，分 `strong / medium / weak` 三级，写入 `signals.jsonl` | `monitor/`, `types.EvolutionSignal` |
| **Evolution Proposal（进化提案）** | 一次待审批的改进方案，写入 `proposals.jsonl`，状态机见下 | `engine/` |
| **Intensity（强度）** | 进化激进度：`100%` 响应全部信号 / `50%` 仅强信号 / `0%` 禁用 | `engine.config` |
| **Cooldown（冷却期）** | 同一插件两次提案之间的最短间隔（默认 24h） | `engine.config.cooldownHours` |
| **Signature（签名）** | `plugin-名-进化类型` 的归一化串，用于提案去重 | `engine.generateSignature` |

## 提案状态机

```
pending ──approve──▶ approved ──execute──▶ executing ──▶ completed
   ▲                    │                     │
   └────── reject ──▶ rejected                └── 失败自动回滚 ──▶ pending
```

状态流转只允许通过 `ProposalStore.setStatus` 进行（单一事实来源）。

## 信号类别与进化类型映射

| 信号类别 (category) | 触发条件示例 | 进化类型 (evolution_type) |
|---------------------|--------------|---------------------------|
| `loop` | 同一工具连续调用 ≥5 次 | `behavior_optimization` |
| `struggle` | 连续失败 ≥3 次 / 延迟回归 +20% | `interface_simplification`（高复杂度时） |
| `correction` | 用户纠正 / 负面反馈 | `error_handling_improvement` |
| `preference` | 用户重复偏好 | `documentation_enhancement` / `interface_simplification` |
| `workflow` | 可复用工作流模式 | `capability_extension` |
| 性能统计 | 平均延迟 >2s / 成功率 <90% | `performance_tuning` |

## Matt Pocock 原则 ↔ 进化类型

| 进化类型 | 应用原则 |
|----------|----------|
| `interface_simplification` | Deep Module > 浅模块 |
| `behavior_optimization` | 紧反馈环 > 盲目试错 |
| `performance_tuning` | 垂直切片 > 水平切片 |
| `documentation_enhancement` | 词汇即文档 |
| `capability_extension` | 先对齐，再动手 |
| `error_handling_improvement` | 紧反馈环 > 盲目试错 |

## Sub-Agent 角色

| Agent | 职责 |
|-------|------|
| `code-generator` | 按提案实现工具合并/中间件/能力扩展代码 |
| `test-writer` | 按 validation_plan.test_scenarios 编写测试 |
| `doc-writer` | 按 proposed_changes.update_documentation 更新文档 |
| `integration` | 处理依赖关系与兼容性 |
| `validator` | 执行 T0/T1/T2 三级验证 |

## 架构不变量（架构扫描时逐条核对）

1. **JSONL I/O 只存在于 `store/`** — 任何模块不得直接读写
   `proposals.jsonl / metrics.jsonl / signals.jsonl`。
2. **提案状态只经 `ProposalStore` 流转** — engine、executor、server 共享同一实例。
3. **信号检测热路径不读磁盘** — 失败/循环检测基于内存会话事件；
   磁盘深度检查受 `DEEP_CHECK_INTERVAL_MS` 节流。
4. **MCP 工具处理器不写 try/catch** — 错误统一由 `defineTool` 包装器转标准错误响应。
5. **无清单目录不是插件** — scanner 跳过没有 `package.json` 或 `SKILL.md` 的目录。

## 数据文件布局

```
~/.harness-evolution/
├── plugin-cache.json   # 扫描缓存（scanner）
├── metrics.jsonl       # 性能事件（monitor）
├── signals.jsonl       # 进化信号（monitor 写 / engine 读）
├── proposals.jsonl     # 进化提案（ProposalStore 唯一读写口）
└── execution.log       # 执行日志（executor）
```
