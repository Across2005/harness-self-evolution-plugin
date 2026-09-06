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
| **Retention（保留上限）** | 观测日志（metrics / signals 两个 JSONL）按字节自动**窗口裁剪**的上限：保留最新的完整行、至少保住最新一条，崩溃残行一并清除 | `store/jsonl.mbt` 的 `Jsonl::trim_to`、`types/config.mbt` 的 `max_log_bytes` |
| **DAG Layer（DAG 层）** | Sub-Agent 任务按依赖拓扑排序后的分层，同层可并行 | `executor/dag.mbt` 的 `topo_layers` |
| **Agent Definition（子 Agent 定义）** | Markdown + YAML frontmatter 的 agent 载体文件（name / description / 可选 color / tools，正文为系统提示词），工厂只产出定义文件——**创建 ≠ 派发** | `factory/factory.mbt` 的 `AgentDefinition` |
| **Sub-Agent Factory（子 Agent 工厂）** | 校验、渲染、解析定义文件并管理两个作用域的工厂（v2.1 新增，`docs/subagent-factory.md`） | `factory/`、`store/agent_defs.mbt` |
| **AgentScope（定义作用域）** | 定义文件写在哪：`plugin`（插件数据根的 `agents/`，默认）/ `user`（宿主 `~/.zcode/agents/`，跨出数据根，宿主在后续会话加载） | `types/agent_scope.mbt`、wire 表 `agent_scope_wire` |

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
   `util → types → store → {scanner, monitor} → {engine, executor, factory} → mcp → harness_evolution`。
   分层是**构造性**无环证明：比跑 DFS 更强，任何新增反向边立刻变红。
   *守卫 G1 / G1b*
9. **默认数据目录只有一处定义** — `.harness-evolution` 字面量只允许出现在
   `store/paths.mbt`。　*守卫 G4 / G4b*

## 数据文件布局

```
~/.harness-evolution/v2/          # 可用 $HARNESS_EVOLUTION_HOME 覆盖
├── plugin-cache.json   # 扫描缓存（每条带 DirFingerprint）
├── metrics.jsonl       # 性能事件（monitor）※ 受 max_log_bytes 窗口裁剪
├── signals.jsonl       # 进化信号（monitor 写 / engine 读）※ 同上
├── proposals.jsonl     # 进化提案（ProposalStore 唯一读写口）
├── execution.log       # 执行日志（executor）
└── agents/             # 子 Agent 定义（factory 写，scope=plugin）
                        # scope=user 写宿主的 ~/.zcode/agents/（跨出数据根）
```

**窗口裁剪（Retention）**：metrics / signals 两个 JSONL 是 append-only 的
观测日志，而 `get_metrics` / `get_signals_for_plugin` 每次全量读盘解析 ——
无上限的增长会直接变成每次查询的延迟。二者受 `max_log_bytes`（默认 32 MiB，
下界 1 MiB）约束：flush 成功后若超限，`Jsonl::trim_to` 裁到只保留**最新的
完整行**（至少保住最新一条；崩溃残留的不完整行一并清除，否则下一次 append
会把新行拼在残行后面毒化两行）。裁剪挂在**唯一的写入路径**（flush）上，
失败被 `trim_quietly` 独立兜住 —— 既不能让 flush 重新 raise（H1 承诺），
也不能被判成 append 失败而回填重试（重复落盘）。**提案与执行日志不裁**：
前者是状态机与审计的事实来源，后者事件稀疏；按插件切分文件仍为后续工作。

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

`max_log_bytes`（观测日志保留上限）走与 H2 同款的取值域校验：
合法域 `[1 MiB, ~2 GiB]`（下界之下意味着裁剪几乎每轮 flush 都触发，属退化
取值；`0` 会把「无界增长」静默带回来，故同样不合法），越界即回落默认值
（32 MiB）+ 点名字段告警。

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

## 已修复的缺陷（2.0 自身引入，非 1.0 遗留）

上面 F1-F5 是 1.0 就存在、移植时必须一并修掉的缺陷。下面三条不同：它们是
**2.0 重写自己带进来的失效面**。三条都按「先写测试 → 实测变红 → 再改实现 →
转绿」的顺序处理，红绿都是当场跑出来的数字。H1 / H2 那一轮：加完测试未实现时为
`Total tests: 242, passed: 237, failed: 5.`，实现后 `242, passed: 242, failed: 0.`。
R 组（观测日志窗口裁剪）落地后为 `253, passed: 253, failed: 0.`。W 的数字见表内与下面一段。

| ID | 缺陷 | 为什么是 2.0 新引入 | 实测证据（红） | 修复（绿） |
|----|------|--------------------|----------------|------------|
| **H1** | **一次瞬时写失败 = 丢事件 + 周期 flush 永久停摆** | 这是 2.0 重写**自己带进来的回归**。`store/jsonl.mbt` 有意让 `append` / `append_many` 的 I/O 错误直接 raise（决策本身没错），但新版 `flush_buffers` 为了「无锁、不可重入」把顺序改成 `copy → clear → 写`，raise 就落在了清空之后。对照 1.0（`legacy-ts/src/monitor/index.ts` L377-389）：它是 `await appendMany()` **成功之后**才 `this.eventBuffer = []`，所以 **1.0 不丢数据**；1.0 的代价在别处 —— `void this.flushBuffers()`（L54-56）把 rejection 丢在地上没人接，而 `legacy-ts/src/**` 实测没有任何 `unhandledRejection` 兜底，在 `engines: node >=18` 下未接住的 rejection 默认直接崩掉进程。**两边各错一半，而 2.0 错的是「丢数据」这半** | `flush_buffers keeps events when the write fails` 当场抛 `OSError("@fs.File::write(): Incorrect function.")`；`a metrics write failure does not block signals from being stored` 断言 `0 != 1` —— signals 一条都没落盘：走 `record_tool_call → maybe_deep_check → get_statistics → flush_buffers` 那条链时，raise 被 `Deep check failed` 的兜底接住、只留下一行日志，而缓冲早就清空了，于是**静默丢失**。夹具自检（先断言这条路径确实写不进去）排除了假绿 | metrics 与 signals **各自独立 `try/catch`**，互不牵连；写不进去的批次由 `bounded_requeue` 按时间序放回缓冲**头部**（未存盘的那批比缓冲里现有的更旧）等下一轮重试；新增上界 `max_buffered_items = 1000`，溢出丢**最旧**的并告警（否则磁盘长期写不进时，监控循环等于替磁盘吃内存）。`flush_buffers` 从此不 raise ⇒ `run_flush_loop` 的循环体无需兜错即可存活 |
| **H2** | **配置可以写成退化值，且被静默兜底** | 1.0 的三个阈值是 `monitor` 里的硬编码常量（3 / 5 / 0.2），用户无从写错；2.0 修掉配置孤岛、改由 `EngineConfig::from_json` 读取后，**只做了类型兜底、没做取值域校验** —— 接通配置入口的同时接通了一条新的失效通道 | `EngineConfig::from_json_checked reports out-of-domain values by name` 断言 `cfg == default` 失败（`-1 / 0 / 1 / 0` 全部原样生效）；`keeps in-domain values untouched` 断言 `0 != 2` | 新增 `EngineConfig::from_json_checked`，对 4 个数值字段做取值域校验：`cooldown_hours ∈ [0, 87600]`、`consecutive_failures ≥ 1`、`loop_detection ≥ 2`、`latency_regression ∈ (0, 100]`。越界即**回落默认值 + 点名字段告警**；`from_json` 委托它并丢掉告警（保持同步签名与既有 4 处调用点）。告警由 `main.mbt` 的 `load_config` 打到 stderr。缺失与类型不符**仍然静默回落**，为它们告警会淹没要紧的这几条 |
| **W** | **解析出来的 `evolution_config` 没接到 monitor：改阈值与日志上限在运行时是空操作** | H2 只把「配置读不读」修到 `EngineConfig` 为止。生产路径上 monitor 有且只有一个构造点（`mcp/tools.mbt` 的 `ServerState::with_scan_config` → `PerformanceMonitor::at`），而它的签名里根本没有 config，转手走 `new()` → `with_thresholds(..., SignalThresholds::default())`。于是 `types/signal.mbt` 承诺的「可由 plugin.json 覆盖」与 R 组新加的 `max_log_bytes` **只有解析方、没有消费方** —— 配置孤岛换了个位置继续存在。1.0 不存在这条路径（阈值本就是 monitor 里的硬编码常量，没人声称它可配），故算 2.0 自己引入 | `ServerState threads evolution_config.max_log_bytes into the monitor`：磁盘上 9 条事件全在，配置的 600 字节上限没触发裁剪（monitor 仍在用默认 32 MiB）；`ServerState threads evolution_config.signal_thresholds into the monitor`：先断言 `config.thresholds.consecutive_failures == 1` **通过**，随后 signals.jsonl 是 0 行 —— 红点精确落在**构造侧而非解析侧**，排除了「JSON 没解析对」这种假因。`Total tests: 255, passed: 253, failed: 2.` | `PerformanceMonitor::at` 增可选参数 `config?`（默认 `EngineConfig::default()`，`at(paths)` 的老调用点行为逐字节不变），把 `config.thresholds` 与 `config.max_log_bytes` 交给 `with_thresholds`；构造点改为 `at(paths, config~)`。修复后 `Total tests: 255, passed: 255, failed: 0.`，且日志里出现 `[Store] Trimmed .../evo-wire-cap-*/metrics.jsonl: kept 414 of 1863 bytes` —— 配置值真的驱动了裁剪，而非仅测试通过 |
| **P1** | **`trim_to` 把「整个文件只有一行且超上限」的日志裁成空文件** | R 组（窗口裁剪）的按字节算法本身是对的，但兜底分支拿 `last_start > 0` 当「存在候选行起点」的判据 —— 而**整个文件只有一行时，该行的起点恰好是 0**，永远不满足 `> 0`，于是落到「裁空」分支，直接违反 `jsonl.mbt` 自己写在文档里的「**至少保留最新的一个完整行**，哪怕它自己就超过上限」。上轮复核 R 时我按 6 个用例手工推演过，**没有一个覆盖单行超限**，所以这条边界躲过了复核 | 新增 `trim_to keeps the newest line when it is also the first line`（断言文件仍是 `bbbbbbbbbb\n`，实得空串）与 `trim_to leaves a single oversized record loadable`（断言磁盘 5 字节、`load()` 仍有 1 条，实得 0 字节 / 0 条）。既有 7 条裁剪用例全部从**第二行**开始构造，正好绕开这个分支 | 兜底判据从 `last_start > 0` 改成「有完整行即可用 `last_start`」（走到该分支时 `eff_end > 0` 必然成立，真·无完整行在上面的「放得下」就提前返回了），单行超限整条保留；同时改掉 `trim_to` 里那句「此分支不可达」的注释 —— 修复后它反而是单行场景的正常出口 |
| **P3** | **执行账本写不进去时异常逃出 `execute`；完成记账失败还会把成功的执行改判成失败** | 1.0 的 `execute` 把一切圈在一个 `try` 里；2.0 重写时，进入执行的 `set_status(Executing)` 与首条 `Start` 日志落在了「兜住一切意外」的 catch **之前**（`executor.mbt`），而 `set_status` / `ExecutionLog::append` 最终都走 `Jsonl::append`，I/O 错误按设计直接 raise（H1 的决策），`ignore()` 拦不住。后果两层：未捕获异常打到 stdout = MCP 协议通道；以及完成记账（`Completed` + `Complete` 日志）写不进时，异常被外层 catch 接住 → **已改好并验过**的执行被报成 `Unexpected error`，提案退回 `pending`，于是可以被再批一次、把同一份改动二次套用 | `an unwritable execution log does not abort a successful execution` 与 `a validation failure is still reported when the log is unwritable` 当场抛 `OSError("@fs.File::write(): Incorrect function.")`（夹具与 H1 同款：把日志路径做成目录）。夹具自检：这两条在改前必须是红的，且红的就是这个 OSError | 新增 `mark_status` / `note_event` 两个收口函数，与 monitor 的 `trim_quietly` 同构（`Ok(expr) catch { err => Err(...) }` + `log_warn`），7 处记账全部改走它们：账本没写成会留下 `Cannot record proposal status ...` / `Cannot append execution log ... 告警，但既不逸出、也**不改变执行结论** |
| **S1** | **G3 守卫的写操作清单不完备，store 外的写盘可绕过守卫** | 守卫 G3 把「store 外不得写盘」机器化，但清单只列了 `write_file` / `mkdir` / `rename` / `remove` / `rmdir` 五个符号：`@fs.create`（可创建/截断文件拿句柄写）与 `@fs.chmod` 不在清单内，`@fs.open` 的非只读模式更是完全不可见 —— 守卫在自己的盲区里恒绿。属 2.0 写守卫时的覆盖缺口（第三轮自审，2026-09-06） | 无红测：这是**守卫自身**的缺陷，现有全绿恰是它失守的证明 —— 守卫对清单外/句柄级的写路径永远不报 | 清单补入 `@fs.create` / `@fs.chmod`；行级判定提取为纯函数 `g3_line_offense`，新增规则「store 外出现 `@fs.open(` 且行内不含 `ReadOnly` 即记为 offender」（当前 store 外无任何 `@fs.open` 调用，规则是防退化哨兵），并附 4 条单测钉住判定本身：只读放行 / 非只读拦下 / `@fs.create` 拦下 / 注释行豁免 |
| **S2** | **`trim_to` 廉价预检的句柄在 `f.size()` raise 时泄漏** | `trim_to` 的预检是 `open → size() → close()` 的手动序列，而 H1 之后 Jsonl 的 I/O 错误按设计直接 raise —— `size()` 一旦 raise，`close()` 被跳过。属 2.0 自己写出的资源管理缺口（R 组引入该路径） | 无红测可构造：句柄泄漏不改变任何可断言的行为，属「测试钉不住、只能靠结构防御」的一类 | open 之后立刻 `defer f.close()`，删除手动 close（同 `scanner/discover.mbt` 的既有惯用法）；`retention_wbtest.mbt` 的 `disk_size` 助手同款改造 |
| **S3** | **阈值写成非整数被静默截断后生效** | H2 只校验了「取值域」，没校验「值形」：`signal_thresholds.consecutive_failures: 2.5` 经 `.to_int()` 截成 2 直接生效、无任何告警 —— 配置人的意图与引擎行为静默分叉，与 H2 要消灭的失效同源 | `EngineConfig::from_json_checked reports non-integer thresholds and falls back` 先写后跑：断言 `2 != 3` 失败（`2.5` 被截断采纳，未回落默认 3），types 包 `Total tests: 34, passed: 33, failed: 1.` | `threshold_int` 比照 `int_domain` / `int_floor` 改为 `(Int, String?)` 返回：`d != d.floor()` 即回落 `fallback` 并点名告警（消息带原值，如 `signal_thresholds.consecutive_failures: 2.5 is not an integer and fell back to the default 3`），告警并入 `from_json_checked` 的收集。实现后 types 包 34 全绿 |

H1 的失败面是**每一轮 flush 都可能踩到**（磁盘满、临时目录被回收、杀毒软件占用），
H2 的失败面是**配置里写错一个数就永久生效**，W 的失败面最隐蔽：**配置里写对了数，
也一样不生效**，而且解析与校验全都绿，只有最后一厘米没接上。三条修复后
`Total tests: 255, passed: 255, failed: 0.`，且 `moon check --deny-warn` 通过。

P1 / P3 是**再下一轮**（对 `c46943f…HEAD` 整个 v2 重写面做两轴评审）挖出来的：
P1 加完测试未实现时 `Total tests: 257, passed: 255, failed: 2.`，实现后 `257, passed: 257, failed: 0.`；
P3 与 P2 的用例一起把总数推到 262，未实现时 `262, passed: 260, failed: 2.`，实现后
`262, passed: 262, failed: 0.`。

S1-S3 是**第三轮自审**（2026-09-06）的产出，S3 的红绿数字见表内；落地后全量
`Total tests: 268, passed: 268, failed: 0.`，`moon check --deny-warn` 通过。
（注：268 是 factory 用例并入**前**的中途快照；`0d3b0ce` 这笔提交落盘时
按同一口径是 295。第五轮复核重新数过，此处保留原文并加此注。）
同轮还改正了两处**注释失实**（不改变行为，故不单独立行）：
`monitor/statistics.mbt` 的 `error_types_object` 自称「键序确定」，实际键序由
Map 哈希序决定（需要确定顺序的消费者应读 `error_types` 数组字段）；
`types/change.mbt` 声称「字段声明顺序决定 Json 输出顺序」，实际输出顺序与声明
顺序无关，对拍逐字节一致靠的是固定键集的确定性哈希。

## 第四轮修复（2026-09-06 会话，两轴评审 + 四子 Agent 评审）

本轮对 `moonbit-port` 分支做了**全仓两轴评审**（正确性轴 + 工程轴），再派 4 个子
Agent 分片复核（store/util、engine/executor/factory、scanner/monitor、
mcp/harness_evolution/types）。修复分三类：**4 个真 bug**（有回归测试）、
**评审发现的加固点**（测试补网 / 结构加固）、**文档失实**（不改行为）。
全量测试从 295（`0d3b0ce`）→ **314**（本笔提交），`moon check --deny-warn` 通过。
口径：这些数字是按 `test "..."` / `async test "..."` 块计数，与 `moon test`
报告的 `Total tests` 在 `f0c4e17`（262）与 `cd2c525`（314）两处实测对齐。

| ID | 类型 | 问题 | 修复 |
|----|------|------|------|
| **B1** | 真 bug | `util/time.mbt` 的 `tdiv` 用了「floor 除法」语义（`q = a/b; 符号相异且余数非零则 q+1`），而 MoonBit 的 `Int64::op_div` 本身**向零截断** —— `iso_utc(-1)` 打出 `1970-01-01T00:00:01.-1001Z` 这种垃圾 | `tdiv = a / b`（向零截断，与 `@time`/JS 的 `Date` 对拍一致）；新增 3 个负值向量用例（node 验证过基准值） |
| **BUG 1** | 真 bug | `engine/risk.mbt` 的 `generate_signature` 剥掉 plugin_id 的尾部版本段，F1（多版本并存）之后两个版本签名相同 → `proposal_id` 撞车、by_signature 索引互相遮蔽 | 保留完整 plugin_id（含版本）；签名格式 `<plugin-id>-<evolution-type>` 写进文档；新增「两版本同名插件各得独立提案」端到端回归 |
| **BUG 2** | 真 bug | `factory` 的 `validate_description` / `validate_system_prompt` 不拒首尾空白，而 `parse()` 无条件 trim —— render→parse 往返不恒等（`" a "` 渲染出来再解析就不一样了） | 描述拒首尾空白、系统提示词拒首/末空行；新增边界用例组 |
| **B1(mcp)** | 真 bug | `types/config.mbt` 的 `cooldown_hours` / `max_log_bytes` 走裸 `n.to_int()`，`0.5` / `2097152.9` 被**静默截断后生效**（S3 只修了阈值，漏了这两个字段） | 新增 `integer_field` 助手（非整数 → 回落默认 + 点名告警），`threshold_int` 委托它；新增非整数/整数两组用例 |
| **W2(store/jsonl)** | 加固 | `store/jsonl.mbt` 的 `trim_window` 会把**末尾空行**当成候选起点 —— `"aaa\nbbb\n\n"` 在上限 4 字节时保留空行而丢掉真实记录 | 候选起点必须 `raw[start] != b'\n'`；新增两条用例（单空行 / 多空行） |
| **W3(cache)/W5** | 加固 | `store/cache.mbt` 的 `DirFingerprint.child_mtime_sec` 只有秒精度 —— 同一秒内原地改写文件可骗过指纹；`cache_version` 未随指纹结构变化升级 | 改 `child_mtime_ns`（纳秒）；`cache_version` 2 → **3**（旧缓存自动整份作废重扫）；`fingerprint_of` 用 `Int64?` 累积（无哨兵值）；新增「同秒内原地重写内容 → 指纹必变」用例 |
| **W10** | 加固 | `scanner/discover.mbt` 的 `walk_into` **无深度上限** —— Windows 目录 junction 可成环（`a/junction → a`），递归无限下钻直到栈溢出 | 新增 `max_files_depth = 32` 上限，越界告警后停止（与 `discover_plugins` 的 `max_discovery_depth` 分工）；junction 无法在 MoonBit 测试里创建，用 40 层深链等价踩同一条代码路径 |
| **W4** | 加固 | `store/agent_defs.mbt` 的 `write(overwrite=true)` 用 `CreateOrTruncate` **原地截断** —— 写中途崩溃留下半截文件；且 exists 检查与写入间有竞态窗口 | 统一走 **tmp + rename 原子替换**（与 `Jsonl::write_json_atomic` 同配方），返回覆盖与否由写入前的 exists 判定 |
| **W2(monitor)/W3(monitor)** | 加固 | monitor 两条路径**零测试覆盖**：延迟回归信号（TS L255-277 的深度检查）与「signals 写失败不拖累 metrics」（H1 只测了反向） | 新增 3 条用例：周基线低延迟 + 今日高延迟 → strong/struggle 信号（证据 `Metrics`、描述 `Latency increased by X%`）；负例（涨幅为 0 不触发）；signals 路径被目录占住时 metrics 照常落盘、信号回填后补写不重复 |
| **W6** | 加固 | `scanner_wbtest.mbt` 的 F3 用例只覆盖 3/6 种清单形态 —— `.claude-plugin/plugin.json`、`.mcp.json`、`.zcode-plugin-seed.json` 从未在测试里出现过 | F3 用例扩到 6 种形态（断言含优先级与回退） |
| **WEAK 4** | 加固 | `executor` 的 `items_of` 认 7 种 Change 种类，`push_task` 只派发 6 种 —— `SimplifyParams` 被接受却不产生任务，仅含它的提案分解出 0 个代码生成任务直接滑到 Completed | 补 `cg-params` 任务（`plan_changes` 目前还发不出该类，属预埋缺口）；新增「参数简化提案分解出 cg-params + tw + integ」用例 |
| **WEAK 9** | 加固 | `dag.mbt` 的 `topo_layers` 用 `Map.set` 建索引，**重复任务 id 被静默覆盖** —— 依赖引用被遮蔽的 id 会解析到后一个同名任务 | 入口直接拒绝重复 id（消息带 id 与两个下标）；新增拒绝用例 + 「真·双父钻石」正例（`[c] → [a,b]` 两层） |
| **WEAK 3** | 加固 | 空变更集提案的「仅验证」完成路径无测试（零任务 → 直接三级验证 → Completed） | 新增端到端用例：结果恰为 3 条 Validator、状态 Completed |
| **jsonrpc** | 加固 | `parse_message` 从不校验 `jsonrpc` 版本字段（1.0 / 缺省 / 非字符串都收）—— 刻意宽容，但没被测试钉死 | 新增「宽容」用例组 + 文件头注释显式声明该行为；响应总是回 `"2.0"` |

文档失实（改文档不改代码）：根 `SKILL.md`（文件结构还是 v1 布局、MCP 工具只列 7 个缺
3 个工厂工具、`execute_evolution` 的 proposal_id 示例缺版本段、Sub-Agent 列表缺
integration）；`skills/harness-evolution/SKILL.md`（frontmatter version 1.0.0、
「启动时扫描」的失实声明、「每会话最大提案数: 3」指向已删除特性、进化强度写在
AGENTS.md 而实际配置在 plugin.json、缺 MCP 工具清单）；`DESIGN.md` §4.1 的
plugin.json 块缺 `agents`/`mcp`/`max_log_bytes`/`scan_targets`/`monitoring`/
`devDependencies`（且后两者是「声明了但当前不生效」的配置孤岛，已如实注明）；
`README.md`（「启动时扫描」×3 处、principle 映射核对位置 `behavior_wbtest` →
`types_wbtest`、AGENTS.md 配置段落、v1 目录提示、工具表）；
`executor/runner.mbt` 的「100 ms 与真实执行同量级」失实（真实是秒级，见
`docs/subagent-factory.md` §1.2）。

**本轮通则**：任何「枚举 → 消费」的映射（Change 种类 → 任务、清单形态 → 档案）
都必须双向有测试；任何「宽松兼容」行为必须有一条测试把它钉死，否则没人知道
它是刻意的。

> **给下一位改动者的通则**：新增一个 `EngineConfig` 字段时，必须同时回答
> 「谁解析它」（`types/config.mbt` 的 `from_json_checked`）与「**谁消费它**」
> （engine 消费 `intensity` / `cooldown_hours`；monitor 经
> `PerformanceMonitor::at(paths, config~)` 消费 `thresholds` / `max_log_bytes`）。
> 只补前者就会重演 W。用例名以 `ServerState threads ...` 开头的那两条就是这条通则的守卫。
>
> 上一版本这里还写着「engine 消费 `auto_approve`」，**是失实的**：全仓只有
> `types/config.mbt` 解析它，没有任何消费方（1.0 同样只声明不读，
> `legacy-ts/src/types/index.ts:295`）。已按已知缺陷第 8 条改成显式失效。
> 通则的自查方式只有一条：`grep` 字段名，看**非测试、非解析**的命中有几个 —— 0 个就是孤岛。
>
> **第二条通则（P3 换来）**：所有「账本型」写入（状态机流转、执行日志）都必须
> 经收口函数，兜错的那一层自己不能再成为抛错源。`ignore(f(...))` **只丢返回值、
> 拦不住 `f` 内部的 raise**；而 native 后端下未捕获异常打到 stdout，stdout 是
> MCP 的协议通道。新增记账调用点时先问：它抛出去会怎样？

## 第五轮复核（2026-09-06 会话，推送 `0d3b0ce` + `cd2c525` 之前）

两笔提交（factory 落地、第四轮修复）推送前做逐条实证复核。本会话的 `read`
工具通道两次给出与 git blob 不符的内容，因此下面每条事实都改由
`git show <rev>:<file>` + Python 显式 UTF-8 读回取定，不采信任何单次读取。

**基线 `cd2c525`（用户自己的两笔提交）的门禁**：`build.ps1 -Task all`
全绿 —— `Total tests: 314, passed: 314, failed: 0.`，退出码 0，产物
`bin/harness-evolution.exe` 1,284,608 B；跑完之后 `git status` 无任何改动
（moon 自己报 `no work to do`），说明这两笔提交本身就是 fmt-clean 的。

**本提交（第五轮改动后）的门禁**：同一条件独立两跑均绿 ——
`Total tests: 315, passed: 315, failed: 0.`，退出码 0，产物 1,287,168 B。
新用例不是假绿：门禁日志里抓到了它真实触发的告警 ——
`[Store] Cannot list agent definitions in .../agents/alpha.md:
OSError("@fs.readdir(): ... The directory name is invalid."); reporting no definitions`
即 Windows 下对文件路径 readdir 确实失败，`Err` 分支被走到，消息按设计
落 stderr。`moon fmt` 零额外 churn（跑完工作树仍只有本提交这 8 个文件）。

| ID | 类型 | 问题 | 修复 |
|----|------|------|------|
| **W11** | 加固 | `store/agent_defs.mbt` 的 `list()` 用 `catch { _ => [] }` 吞掉 `@fs.readdir` 失败 —— 权限故障、竞态删除、目录位置被文件占据，都会被 MCP `list_sub_agents` 读成「一个子 Agent 都没定义」。store/ 其余吞错处（jsonl 跳坏行、cache 忽略坏缓存）一律留一行日志，只有这里是静默的 | 失败改走 `Result` + `match`：仍返回空数组，但必须先 `@util.log_warn("Store", "Cannot list agent definitions in ...")`。日志只经 `src/util/log.mbt`（全仓唯一的 `@stdio.stderr` 出口，守 G2），不污染 MCP 的 stdout 协议通道。新增用例 `AgentDefStore lists nothing when the directory cannot be read` 钉住这条新分支 |
| **VER** | 一致性 | 仓库正文与代码注释早已把这一版称为 **v2.1**（`docs/subagent-factory.md:3`「状态：v2.1 落地」、`src/mcp/schema.mbt`、`src/factory/factory.mbt` 等 40+ 处），但机器可读元数据仍停在 2.0.0：`moon.mod`、`.zcode-plugin/plugin.json`、`src/mcp/jsonrpc.mbt` 的 `server_version`、`DESIGN.md` 里的 plugin.json 镜像块、`skills/harness-evolution/SKILL.md` 的 frontmatter | 五处一并升 **2.1.0**（factory 是向后兼容的功能级新增，按 semver 走 minor）。`jsonrpc.mbt` 的版本注释补一行 2.1.0 说明，保留「随 Node→native 这一 breaking change 升到 2.0.0」那句历史陈述 |

**两条评审意见经实证撤回**：

- 「`AgentDefStore::exists` 是无消费方的孤岛，可以删」—— 实测它有 3 个调用方
  （`store_wbtest.mbt:617/620/635`），且 `write()` 的文档注释依赖它描述「写入之后
  立刻可判存在」的原子性契约。删掉等于削掉已测的公开 API，不改。
- 「第四轮声称 11 处加固、表内只有 10 行」—— 那 10 行里含 **12 个不同标号**
  （`W3/W5`、`W2/W3` 各并了两条），按标号读是 12、按行读是 10，都不正好等于 11。
  差异来自标号重名而不是漏记，已在上一节按仓库既有写法 `B1(mcp)` 加限定后缀消歧。
  提交信息是用户写的，不改写。

代码注释里的裸标号（`jsonrpc.mbt:20` 的 `W1/W2`、`tools_wbtest.mbt:1222` 的 `W2`、
`retention_wbtest.mbt:139` 的 `W2`、`monitor_wbtest.mbt:886` 的 `W2`）与表内标号并非
一一对应，但各自在本地上下文里唯一 —— 追改的改动面大于收益，故只消歧文档表格。

> 第四轮的逐条红/绿证据本会话**未留档**（`_scratch` 里没有那一轮的门禁日志），
> 所以本文只写「做了什么」，不复述「去掉修复即可单独复现红」这类没有留档支撑的数字。

## 有意的语义修正

移植过程中**只有两处**故意改变了 1.0 的行为语义，记录在此以免被当成 bug 回退
（上一节 H1 / H2 / P1 / P3 是加固轮次引入的语义变化，不属于移植期间的改动）：

- **`is_backward_compatible` 在空变更集时返回 `true`（1.0 返回 `false`）**
  1.0 的 `checkBackwardCompatibility` 用 `changes.merge_tools?.every(...)` 与
  `changes.simplify_params?.every(...)` 两个可选链判断：
  变更集**完全为空**时两个 `?.every()` 都是 `undefined` → 结果 `false`；
  而 `{merge_tools: []}` 时 `[].every(...)` 是 `true` → 结果 `true`。
  「没有任何改动」反而被判为**不向后兼容**，而「有一个空的改动列表」被判为兼容
  —— 自相矛盾。2.0 统一为 `true`：空变更集不破坏任何既有调用方。
  专门测试：`engine/risk_wbtest.mbt` 的
  `"is_backward_compatible treats an empty change set as compatible"`。
- **`scan_plugins` 的 `target_paths` 从「声明了但完全无效」变成真正生效**
  1.0 的 schema 声明了这个参数，handler 却只往下传 `force_rescan`
  （`legacy-ts/src/mcp/server.ts` L29 声明 / L131 只用 force_rescan），参数是纯摆设；
  2.0 在 `mcp/tools.mbt` 里真的用它替换默认扫描根。
  连带两处覆盖，一并记在这里：那次扫描复用**同一个** `plugin_cache()` 路径，
  而 `save_cache` 是整份重写（`scanner.mbt` 只回写本次扫到的档案），
  所以一次 `target_paths` 扫描会把默认根的缓存条目全部冲掉 —— 缓存是**派生数据**，
  下一轮默认扫描会重算，代价是多扫一遍，不丢真实数据；`state.adopt(scanner.all())`
  也会把注册表替换成这批临时档案。按插件切分缓存文件仍属后续工作。

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
8. **`auto_approve` 没有消费方**（P2，1.0 继承）。
   `legacy-ts/src/types/index.ts:295` 声明后从未读过，2.0 忠实移植。缺陷不在「没接通」，
   而在**静默**：配置里写 `true` 的人会以为绕过了人工审批，而审批照旧必经。
   本轮按 H2 同款原则改成**显式失效** —— `from_json_checked` 遇 `true` 告警并回落
   `false`，用例 `auto_approve: true is reported and falls back to false` 钉住。
   **刻意不接通**：人工审批是「自动改代码失控」这条最大风险的唯一闸门，接通它属于
   对外语义变更，要单独决策，不在缺陷修复范围内。
9. **monitor 没有生产数据源**（本轮评审新发现，1.0 继承）。
   `record_tool_call` / `record_user_feedback` 在**整个仓库（含 `legacy-ts/src`）都没有
   非测试调用方**，MCP 侧只暴露读取用的 `get_plugin_metrics`。于是「指标采集 → 信号识别
   → 自动提案」这条链**第一环就没有输入**：`metrics.jsonl` 只被动等待一个不存在的喂数据方，
   `get_plugin_metrics` 恒返回全零，跑得通的只有手动 `propose_evolution`。
   `DESIGN.md` 原先那句「性能事件确实在采集」是失实的，已就地改掉。
   接通它需要平台提供「其他插件被调用」的回调（就是 `addEventHandler` 那段从未实现的草图），
   属于功能决策而非缺陷修复，故记录在此不动代码。
10. **`target_paths` 生效后带来的两处覆盖**（见「有意的语义修正」第二条）。
    一次带 `target_paths` 的扫描会冲掉默认根的插件缓存、并把注册表替换成这批临时档案。
11. **struggle 信号没有一次性抑制**（1.0 继承，忠实 TS 的不对称）。
    loop 信号有 `loop_reported` 去重、每个工具只报一次；struggle 没有对应的去重标记 ——
    判定是 `consecutive_failures >= 3` 就发（`monitor.mbt` 的 `check_for_signals`），
    于是连续失败 N 次会发出 N-2 条同信号，且之后每一轮只要仍达到阈值就会再发。
    将来若接通生产数据源（第 9 条），需评估是否给 struggle 也加去重；
    现在改它会改变 `signals.jsonl` 的产出形状，超出移植范围。

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
