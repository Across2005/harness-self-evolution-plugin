# CONTEXT — 领域词汇表

本文件是团队与 AI 的共享语言。所有代码、文档、提案、对话统一使用下述术语。
发现新概念时先在这里登记，再写代码（词汇即文档）。

> **2.0 说明**：实现语言已从 TypeScript + Node 换成 **MoonBit native**
> （产物是独立可执行文件 `bin/harness-evolution.exe`，运行时不需要 Node）。
> 1.0 的完整工程保留在 `legacy-ts/`，仍可运行，作为移植正确性的对拍参照。
> 下表「代码位置」一律指 `src/` 下的 MoonBit 模块。

## 核心概念

| 术语 | 含义 | 代码位置 |
|------|------|----------|
| **Plugin（插件）** | Harness 生态中可被扫描、监控、进化的功能单元，以 `plugin_id`（`name-version`）唯一标识 | `scanner/` |
| **Plugin Profile（插件档案）** | 扫描得到的插件元数据：工具列表、能力、依赖、初始指标 | `types/plugin.mbt` 的 `PluginMetadata` |
| **Manifest（清单）** | 认定「这个目录是一个插件」的证据文件，共 6 种形态，按优先级取元数据 | `scanner/discover.mbt` 的 `manifest_priority` |
| **Performance Event（性能事件）** | 一次工具调用/事件触发/能力使用的原始记录，写入 `metrics.jsonl` | `monitor/`、`types/event.mbt` 的 `EventPayload` |
| **Evolution Signal（进化信号）** | 从事件中提炼的进化触发证据，分 `strong / medium / weak` 三级，写入 `signals.jsonl` | `monitor/`、`types/signal.mbt` |
| **Evidence（证据）** | 信号的来源，是闭合类型：`Session` / `Metrics` / `UserManual` / `FilePath` | `types/signal.mbt` 的 `Evidence` |
| **Evolution Proposal（进化提案）** | 一次待审批的改进方案，写入 `proposals.jsonl`，状态机见下 | `engine/`、`types/proposal.mbt` |
| **Change（变更）** | 提案里的一项具体改动，7 个变体（合并工具/简化参数/加中间件/优化流程/更新文档/扩展能力/改进错误处理） | `types/change.mbt` 的 `Change` |
| **Intensity（强度）** | 进化激进度：`100%` 响应全部信号 / `50%` **仅强信号** / `0%` 禁用 | `types/config.mbt` 的 `Intensity` |
| **Cooldown（冷却期）** | 同一插件两次提案之间的最短间隔（默认 24h） | `EngineConfig.cooldown_hours` |
| **Signature（签名）** | `plugin-名-进化类型` 的归一化串，用于提案去重 | `engine/risk.mbt` 的 `generate_signature` |
| **Wire Table（wire 表）** | ★ 字符串枚举的**唯一**编解码表。一张表同时驱动三件事：JSONL 序列化、MCP `inputSchema.enum`、错误消息里的合法值列表 | `util/wire.mbt` + `types/wire_tables.mbt` |
| **DirFingerprint（目录指纹）** | `mtime` + 直接子项数 + 子项 `mtime`，用于判定扫描缓存条目是否仍然有效 | `store/cache.mbt` |
| **ProposalOutcome（提案结果）** | `generate_proposal` 的 6 个结果：`Created` / `AlreadyPending` / `Duplicate` / `Disabled` / `NoSignals` / `InCooldown` | `engine/engine.mbt` |
| **Trailing State（尾计数状态）** | 每插件的 O(1) 增量计数器（连续失败数、同一工具连击数） | `monitor/trailing.mbt` |
| **DAG Layer（DAG 层）** | Sub-Agent 任务按依赖拓扑排序后的分层，同层可并行 | `executor/dag.mbt` 的 `topo_layers` |

## 提案状态机

```
pending ──approve──▶ approved ──execute──▶ executing ──▶ completed
   ▲                    │                     │
   └────── reject ──▶ rejected                └── 失败自动回滚 ──▶ pending
```

状态流转只允许通过 `ProposalStore.set_status` 进行（单一事实来源）。
终态是 `completed` 与 `rejected`，从它们出发没有任何合法迁移。

可执行形式：`types/proposal.mbt` 的 `ProposalStatus::can_transition_to`
是一个穷尽 `match`，5×5 = 25 种组合全部由编译器检查。

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

代码里的单一事实来源是 `types/proposal.mbt` 的 `EvolutionType::principle`。
注意 `behavior_optimization` 与 `error_handling_improvement` **都**映射到
「紧反馈环 > 盲目试错」。原则名本身也是 wire 表里的中文字面量
（`types/wire_tables.mbt`），JSONL 与 MCP 响应里出现的正是上表右列的原文。

## Sub-Agent 角色

| Agent | wire 名 | 职责 |
|-------|---------|------|
| `CodeGenerator` | `code-generator` | 按提案实现工具合并/中间件/能力扩展代码 |
| `TestWriter` | `test-writer` | 按 `validation_plan.test_scenarios` 编写测试 |
| `DocWriter` | `doc-writer` | 按 `Change::UpdateDocumentation` 更新文档 |
| `Integration` | `integration` | 处理依赖关系与兼容性 |
| `Validator` | `validator` | 执行 T0/T1/T2 三级验证 |

任务依赖用**真正的 task id**（`SubAgentTask.deps`）表达，由 `executor/dag.mbt`
做拓扑分层，同层并行、层间串行。

> 1.0 版的 `SubAgentTask.dependencies` 字段注释写的是「Other task IDs」，
> 实际存的却是 AgentType 字符串，语义错且全仓无读取点。2.0 已修正。

## 架构不变量（架构扫描时逐条核对）

每条不变量都有对应的**机器化守卫**（`src/mcp/architecture_test.mbt`，随
`moon test` 一起跑）。守卫都做过负向探针验证 —— 人为引入违规确认会变红，
否则「永远通过的测试」只是装饰。

1. **JSONL I/O 只存在于 `store/`** — 任何模块不得直接读写
   `proposals.jsonl / metrics.jsonl / signals.jsonl`，也不得绕过 `store/`
   做任何文件系统**写**操作。　*守卫 G3 / G3b*
2. **提案状态只经 `ProposalStore` 流转** — engine、executor、MCP 工具三方
   共享**同一个实例**（`mcp/tools.mbt` 的 `ServerState::with_scan_config`
   只构造一次）。若各自构造，三个实例的内存索引会互相看不见对方的写入，
   状态机校验形同虚设。　*由 mcp/tools_wbtest 的全链路用例守住*
3. **信号检测热路径不做超过 O(1) 的工作** — 失败/循环检测基于
   `TrailingState` 增量计数器；磁盘深度检查受 `deep_check_interval_ms`
   （30s）节流。　*（1.0 的原文是「不读磁盘」，2.0 进一步收紧）*
4. **MCP 工具处理器不写 try/catch** — 错误统一由 `call_tool` 这**一处**
   包装器转标准响应。　*（1.0 里这个角色叫 `defineTool`）*
5. **无清单目录不是插件** — scanner 跳过不含任何清单文件的目录。
   清单共 **6 种**形态，按优先级取元数据：
   `.zcode-plugin/plugin.json` > `package.json` > `.claude-plugin/plugin.json`
   > `.mcp.json` > `.zcode-plugin-seed.json` > `SKILL.md`。
   *（1.0 只认 2 种，见下面 F3）*
6. **stdout 只承载协议字节** — `@stdio.stdout` 只允许出现在
   `mcp/server.mbt`；`@stdio.stderr` 只允许出现在 `util/log.mbt`
   （全仓唯一日志出口）。　*守卫 G2 / G2b，见下面 F4*
7. **一个字符串枚举只有一张 wire 表** — 取值域不得在别处重写第二遍。
   schema 的 `enum` 数组直接取自 `names()`。　*守卫见 mcp/schema_wbtest*
8. **包依赖图严格分层，每条边只向下** —
   `util → types → store → {scanner, monitor} → {engine, executor} → mcp → harness_evolution`。
   分层是**构造性**无环证明：比跑 DFS 更强，任何新增反向边立刻变红。
   *守卫 G1 / G1b*
9. **默认数据目录只有一处定义** — `.harness-evolution` 字面量只允许出现在
   `store/paths.mbt`。　*守卫 G4 / G4b*

## 数据文件布局

```
~/.harness-evolution/v2/          # 可用 $HARNESS_EVOLUTION_HOME 覆盖
├── plugin-cache.json   # 扫描缓存（每条带 DirFingerprint）
├── metrics.jsonl       # 性能事件（monitor）
├── signals.jsonl       # 进化信号（monitor 写 / engine 读）
├── proposals.jsonl     # 进化提案（ProposalStore 唯一读写口）
└── execution.log       # 执行日志（executor）
```

**v1 目录不做自动迁移**：2.0 使用 `v2/` 子目录。若检测到 1.0 的
`~/.harness-evolution/` 存在，启动时在 stderr 提示一行，然后原样保留不动。
理由见下面的 F2 —— 1.0 的缓存已被证明会被永久毒化，丢弃重扫比迁移更安全。

## 配置来源

唯一的配置入口是 `EngineConfig`（`types/config.mbt`），读取顺序：

1. `$HARNESS_EVOLUTION_CONFIG` 指向的文件（显式覆盖，多档案与测试场景用）
2. `<cwd>/.zcode-plugin/plugin.json` 的 `evolution_config` 段
3. 内置默认值（`Half` / 24h / `auto_approve=false` / `SignalThresholds::default()`）

配置缺失或字段非法**绝不允许让启动失败** —— 任何读不到的项各自回落默认值。

`signal_thresholds` 同时接受两种形状：**扁平**（`consecutive_failures` /
`loop_detection` / `latency_regression`，2.0 规范，键名与 `SignalThresholds`
的字段逐字相同）优先，**嵌套**（`.strong.*` / `.medium.*`，1.0 写法）作为回退。

> 1.0 里 `evolution_config` 是一处**配置孤岛**：写了但 `src/**` 里没有任何代码读它，
> 改配置等于空操作。2.0 已接通。相邻的 `scan_targets` 仍是孤岛，见下面第 6 条。

## 已修复的缺陷（1.0 → 2.0）

以下五条都在 1.0 里实测证实。**不修的话，忠实的移植只会复制一个在生产中
不可用的插件**，所以它们与移植同时完成，每条都有回归测试。

| ID | 缺陷 | 实测证据 | 修复 |
|----|------|----------|------|
| **F1** | **scanner 在生产中发现 0 个插件** | 真实布局是 `<plugin>/<version>/`（browser-use 有 4 个版本、document-skills 有 3 个），第 1 层全部零文件；而 1.0 只下探 1 层，直接在 `<root>/<entry>/` 找清单 → 被不变量⑤全部误杀 | 发现深度改为可配置（默认 3 层），命中清单后「认领子树」避免父子重复计入。**实机验证：同一台机器上 2.0 发现 15 个插件，1.0 发现 0 个** |
| **F2** | **扫描缓存永久毒化，启动即返回幽灵档案** | 本机 `~/.harness-evolution/plugin-cache.json`（526 B）唯一条目的 `path` 指向一个早已被 jest `afterEach` 删除的临时目录；而 1.0 的命中条件仅为 `cached.size > 0` → 每次启动直接返回，永不重扫 | 缓存条目增加 `DirFingerprint`，逐条校验：目录消失 → 丢弃并 stderr 告警；指纹变化 → 只重扫该子树 |
| **F3** | **清单形态覆盖不足** | `browser-use\0.4.1\` 根目录**无** `SKILL.md`；`mimosa\1.0.3\` **无** `package.json`、也无根 `SKILL.md`，只有 `.zcode-plugin/plugin.json`、`.claude-plugin/`、`.mcp.json` | 清单集合从 2 种扩到 6 种，按优先级取元数据（见不变量⑤） |
| **F4** | **14 处 `console.log` 会污染 MCP 协议通道** | 1.0 的 `src/**` 实测：`console.log` 14 处、`console.warn` 1 处、`console.error` 8 处。它没炸只是因为 `@modelcontextprotocol/sdk` 的 `StdioServerTransport` 接管并 patch 了 `console.*`；**自研 stdio server 没有这层魔法** | 新增 `util/log.mbt` 作为**唯一**日志出口，物理上只写 stderr；不变量⑥ + 守卫 G2 机器化封死 |
| **F5** | **`propose_evolution` 的 `signals` 参数在默认配置下永远无效** | 手动信号按设计是 **medium**，而默认强度 **50%** 只放行 **strong** → 两者相乘，出厂配置下手动信号永远产生不了提案，客户端只会收到一句笼统的 "insufficient signals, cooldown, or duplicate" | **行为原样保留**（见下一节），但 2.0 追加了 `reason` 字段说清真因，并用一条专门测试把它钉死 |

## 有意的语义修正

移植过程中**只有一处**故意改变了 1.0 的行为语义，记录在此以免被当成 bug 回退：

- **`is_backward_compatible` 在空变更集时返回 `true`（1.0 返回 `false`）**
  1.0 的 `checkBackwardCompatibility` 用 `changes.merge_tools?.every(...)` 与
  `changes.simplify_params?.every(...)` 两个可选链判断：
  变更集**完全为空**时两个 `?.every()` 都是 `undefined` → 结果 `false`；
  而 `{merge_tools: []}` 时 `[].every(...)` 是 `true` → 结果 `true`。
  「没有任何改动」反而被判为**不向后兼容**，而「有一个空的改动列表」被判为兼容
  —— 自相矛盾。2.0 统一为 `true`：空变更集不破坏任何既有调用方。
  专门测试：`engine/risk_wbtest.mbt` 的
  `"is_backward_compatible treats an empty change set as compatible"`。

## 已知缺陷与有意保留的行为

以下都是 1.0 的真实行为，2.0 **刻意原样保留** —— 「顺手优化」会造成静默回归，
让双跑对拍失去意义。每一条都有测试把它钉在当前状态：将来有人改动，测试会变红，
迫使他意识到自己正在改一个对外可见的语义。

1. **F5：默认 50% 强度下手动信号无效**（见上表）。
   钉死用例：`mcp/tools_wbtest.mbt` 的
   `"F5: manual signals are inert under the default 50% intensity"`，
   并附对照组证明同一份参数在 `100%` 下确实能产生提案。
   要让手动信号生效，把 `evolution_config.intensity` 设为 `"100%"`。
2. **`capabilities` / `tools` 在计算指标前不去重**。
   指标用的是原始数组，只有对外响应里的列表才去重。
   后果：重复项会**抬高** `capabilityComplexity`（同一份内容在日志里显示
   `58 tools`、在响应里显示 `46 tools`）。去重时机必须原样保留。
3. **无指标的插件一律落到 `performance_tuning`**。
   决策树里 `success_rate < 0.9` 在缺指标时（`success_rate = 0`）恒真，
   于是 `documentation_enhancement` 兜底分支**近乎死代码**，只有指标看起来
   健康时才可达。两条分支都有专门用例覆盖。
4. **`get_plugin_metrics` 不校验插件是否存在**。
   未知插件返回 `success: true` + 全零统计，而不是错误。
5. **`execute_evolution` 的失败走载荷通道而不是 `isError`**。
   提案不存在 / 状态不对时返回 `{success:false, error:...}` 的正常响应。
   这与 `propose_evolution`、`approve_proposal` 用 `isError` 的做法不一致，
   但 1.0 就是如此（`execute()` 是 `return` 而不是 `throw`）。
   三条失败通道的分界见 `mcp/tools_wbtest.mbt` 里的表格注释。
6. **`scan_targets` 是一处未接通的配置孤岛**。
   `.zcode-plugin/plugin.json` 列了 6 个扫描路径，但代码用的是
   `scanner/scanner.mbt` 里 3 个硬编码根。接通它会**改变发现哪些插件**，
   属于超出移植范围的行为变更，故保留缺口并记录在此。
   （对比：`evolution_config` 已接通，因为读它不改变行为语义。）
7. **首次 `record_tool_call` 会立即触发一次落盘**。
   链路是 `record_tool_call → maybe_deep_check → get_statistics → flush_buffers`。
   反直觉（缓冲本该等 5s 周期），但忠实移植自 1.0，并有专门用例钉住。

## 与移植计划的已知偏差

- **`scanner` 依赖 `store`**。改写计划一方面声明 `scanner → types, util, @fs`
  且「不依赖 store」，另一方面又要求把 `PluginCache` / `DirFingerprint` /
  `fingerprint_of` 放进 `store/cache.mbt`（理由是收拢 scanner 的直接 fs 读写，
  那正是 F2 修复的落脚点）。两条要求互相矛盾：scanner 要用插件缓存就必须依赖
  store。实现取了后者，因为不变量①「持久化只在 store」的优先级高于
  「scanner 少一条边」。守卫 G1 断言的是这张**实际**的图。
- **`executor` 不使用 `@process`**。计划把 `@process` 列为 executor 的依赖，
  但 1.0 的三级验证本身就是模拟的（代码里写的是 `In production, this would: ...`），
  没有真实子进程可跑。2.0 用**函数值注入缝**（`run_task` / `validate_level`）
  取代散落的 `dry_run` 分支，实现与 simulated / dry-run / failing / hanging
  四种可测行为，`timeout_ms` 由 `@async.with_timeout_opt` 真正强制执行。

## 词汇即文档：wire 表是单一事实来源

`CONTEXT.md` 里的每一个字符串枚举取值（`pending` / `interface_simplification` /
`code-generator` / `先对齐，再动手` …）都在 `types/wire_tables.mbt` 里有**唯一**
一张表。这张表同时驱动三处消费：

1. **JSONL 序列化** —— `ToJson` / `FromJson` impl 直接查表
2. **MCP `inputSchema.enum`** —— `names()` 生成合法值数组
3. **错误消息** —— 解码失败时列出全部合法值
   （实测：`unknown value "teleported"; expected one of: pending, approved, rejected, executing, completed`）

于是「schema 说合法但解码拒绝」这类矛盾在结构上不可能出现，
`mcp/schema_wbtest.mbt` 还专门遍历 schema 声明的每个取值逐个喂给 `from_json`
做往返验证。

**为什么不用 `derive(ToJson)`**：MoonBit 的 `core/json` 对 enum 生成
tagged-array（`Add(Val("x"),Val("y"))` → `["Add",["Val","x"],["Val","y"]]`）。
若对 `EvolutionType` 用 derive，`interface_simplification` 会变成
`["InterfaceSimplification"]`，直接摧毁本文件的词汇表并劣化 LLM 可读性。
