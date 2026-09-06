# Harness Self-Evolution Plugin

> DeepSeek Harness 全盘自进化升级插件 - 让插件生态系统持续自我优化

## 概述

Harness Self-Evolution Plugin 是一个为 DeepSeek Harness 框架设计的自进化插件，它能够：

- **插件扫描**：发现并分析 harness 插件（经 `scan_plugins` 工具触发）
- **实时监控**：跟踪插件性能，检测异常模式
- **智能分析**：基于 Matt Pocock 工程原则生成进化提案
- **协同执行**：通过 Sub-Agent 协调完成升级

## 核心理念

**一切皆可进化** - 插件本身也是可进化的实体，通过数据驱动的迭代实现持续优化。

## 架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Harness Evolution Plugin                  │
├──────────────┬──────────────┬──────────────┬───────────────┤
│   Scanner    │   Monitor    │    Engine    │    Executor   │
│  (插件扫描)   │  (实时监控)  │  (进化分析)  │   (升级执行)  │
└──────────────┴──────────────┴──────────────┴───────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   MCP Server    │
                    │  (10 Tools,     │
                    │   stdio JSON-RPC)│
                    └─────────────────┘
```

> ⚠️ **没有「启动时自动扫描」**。本插件是 stdio MCP 服务器，只在被调用时工作：
> 扫描靠 `scan_plugins` 工具（客户端启动时调一次即可建立档案）；
> 监控事件由宿主在工具调用链上经 `record_tool_call` / `record_user_feedback`
> 注入。进程自身启动只装配依赖、不碰磁盘扫描。

### 四大核心组件

#### 1. Scanner - 插件扫描器

扫描 harness 插件，建立初始档案（`scan_plugins` 工具触发）：

- 解析 `plugin.json` 和 `SKILL.md`
- 计算复杂度、接口清晰度、文档质量评分
- 建立插件档案到 Registry

#### 2. Monitor - 性能监控器

实时监控插件表现，检测进化信号：

- 跟踪调用延迟、成功率、Token 消耗
- 检测循环行为、性能下降、用户纠正
- 分类信号强度（强/中/弱）

#### 3. Engine - 进化引擎

基于 Matt Pocock 原则生成进化提案：

- 映射信号到进化类型
- 选择适用的工程原则
- 生成具体变更方案

#### 4. Executor - 升级执行器

协调 Sub-Agent 完成实际升级：

- 分解任务到 code-generator、test-writer、doc-writer
- 执行三级验证（T0/T1/T2）
- 支持回滚机制

## 安装

### 前置要求

- **MoonBit 工具链**（`moon`）
- **Windows**：Visual Studio 的 C++ 生成工具（`cl.exe`）+ Windows SDK。
  native 后端要把 MoonBit 编译成 C 再用 MSVC 链接，`build.ps1` 会自动探测
  并注入 `INCLUDE` / `LIB` / `PATH`，**不需要**手工跑 `vcvars64.bat`。
- DeepSeek Harness 或 ZCode CLI

运行时**不需要 Node.js** —— 产物是一个独立的 native 可执行文件。

### 安装步骤

```powershell
# 克隆仓库
# GitHub
git clone https://github.com/Across2005/harness-self-evolution-plugin.git

# 或 GitLink 国内镜像
git clone https://www.gitlink.org.cn/Across2005/harness-self-evolution-plugin.git

cd harness-self-evolution-plugin

# 构建：check + test + build，产物复制到 bin\harness-evolution.exe
# 依赖由 moon 根据 moon.mod 里写死的精确版本自动拉取，无需单独的 install 步骤
.\build.ps1 all

# 链接到 ZCode（可选）
zcode plugin link .
```

> **为什么锁死 async 0.20.1**：0.21.x 开始使用 `noraise + nocancel` 效果注解语法，
> 而当前工具链（moon 0.1.20260819）解析它会报 `[3002] Parse error, unexpected token '+'`。
> 升级到能解析该语法的 moon 版本后方可放开约束。
>
> **关于 `moon.lock`**：本机工具链**不产生**模块根的 `moon.lock`
> （`moon mod tidy` 是独立插件 `moon-mod`，未安装时直接报错；
> `.mooncakes/.moon-lock` 实测为空）。可复现构建靠的是 `moon.mod` 里
> **写死的精确版本**而不是范围，并由架构守卫 G6 机器化钉住。
> 用 `moon tree` 可随时核对实际解析结果（应为 `moonbitlang/async@0.20.1`）。

### build.ps1 的子命令

| 命令 | 作用 |
|------|------|
| `.\build.ps1 check` | `moon check --deny-warn --target native`（零错零警才算过） |
| `.\build.ps1 test` | `moon test --target native` |
| `.\build.ps1 build` | release 构建 + 复制到 `bin\harness-evolution.exe` |
| `.\build.ps1 fmt` | `moon fmt` |
| `.\build.ps1 all` | 依次执行 check → test → build |

## 配置

### 配置来源（plugin.json，不是 AGENTS.md）

> 配置只来自 `.zcode-plugin/plugin.json` 的 `evolution_config` 段
> （查找顺序：`$HARNESS_EVOLUTION_CONFIG` → `<cwd>/.zcode-plugin/plugin.json`
> → 内置默认值）。**AGENTS.md 不参与任何配置解析** —— 下面的示例块只是为了
> 直观展示各项含义，实际必须写进 plugin.json。

```markdown
## Self-Evolution

- **强度**: 50% (审慎)
  - 100% (积极): 强信号或两个中信号均可触发
  - 50% (审慎): 仅强信号触发
  - 0% (关闭): 不做任何进化检查

- **冷却期**: 24 小时
```

> ⚠️ **50% 强度下的一个已知限制**：`propose_evolution` 工具的 `signals` 参数
> 传入的手动信号按设计是 **medium** 强度，而 50% 只放行 **strong** ——
> 因此在出厂默认配置下，手动信号不会触发提案。这是从 1.0 版继承的行为，
> 2.0 刻意保持一致（见 CONTEXT.md 的「已知缺陷与有意保留的行为」）。
> 要让手动信号生效，把 `intensity` 设为 `"100%"`。

### 在 plugin.json 中配置

```json
{
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
  }
}
```

> 2.0 起 `evolution_config` **真的会被读取**（1.0 里它是一处配置孤岛：
> 写了但没有任何代码读）。查找顺序：`$HARNESS_EVOLUTION_CONFIG` →
> `<cwd>/.zcode-plugin/plugin.json` → 内置默认值。配置缺失绝不会导致启动失败。
>
> `max_log_bytes` 是观测日志（`metrics.jsonl` / `signals.jsonl`）的**保留上限**
> （字节，默认 32 MiB，下界 1 MiB）：超限后自动裁掉最旧的完整行，
> 至少保留最新一条。越界取值会回落默认值并在启动时点名告警。
>
> `max_proposals_per_session` 已删除：1.0 里它被赋值后从未参与任何判定。

## 使用

### 调用模式

本插件是 MCP 服务器，一切行为都由**工具调用**驱动：

1. **扫描**：客户端调用 `scan_plugins` 建立档案
2. **监控**：宿主在工具调用链上经 `record_tool_call` / `record_user_feedback`
   注入事件，累积信号
3. **提案**：`propose_evolution` 基于信号/手动 `signals` 生成提案

> ⚠️ 第 2 步**目前没有生产调用方**：本插件没有「其他插件被调用」的事件来源
> （`record_tool_call` / `record_user_feedback` 无生产调用方，1.0 亦如此），
> 所以 `metrics.jsonl` 不会有数据、信号不会自动触发。可用的是手动路径：
> `propose_evolution` → `approve_proposal` → `execute_evolution`
> （注意已知缺陷第 1 条 F5：默认 50% 强度下手动信号也是无效的，
> 要生效得把 `evolution_config.intensity` 设为 `"100%"`）。
> 原因与取舍见 `CONTEXT.md` 已知缺陷第 9 条。

### 手动命令

```bash
# 查看插件状态
/harness-evolution status

# 查看性能指标
/harness-evolution metrics <plugin-id>

# 手动触发分析
/harness-evolution analyze <plugin-id>

# 查看提案列表
/harness-evolution proposals

# 执行提案
/harness-evolution execute <proposal-id>
```

## 进化类型

| 类型 | 触发条件 | Matt Pocock 原则 | 变更内容 |
|------|---------|------------------|---------|
| `interface_simplification` | struggle 信号 + 高复杂度 | Deep Module > 浅模块 | 合并工具、简化参数 |
| `behavior_optimization` | 循环检测 | 紧反馈环 > 盲目试错 | 添加中间件、优化流程 |
| `error_handling_improvement` | 用户纠正 | 紧反馈环 > 盲目试错 | 改进错误处理、增加提示 |
| `documentation_enhancement` | 用户偏好 + 高清晰度 | 词汇即文档 | 更新文档、添加示例 |
| `capability_extension` | 工作流模式 | 先对齐，再动手 | 扩展能力、添加工具 |
| `performance_tuning` | 性能问题 | 垂直切片 > 水平切片 | 优化性能、减少延迟 |

> 这张表与 `CONTEXT.md` 的「Matt Pocock 原则 ↔ 进化类型」是**同一份映射**，
> 代码里的单一事实来源是 `types/proposal.mbt` 的 `EvolutionType::principle`，
> 由 `src/types/types_wbtest.mbt` 的「principle 映射」用例（L260-280 附近）
> 逐条核对。1.0 版的 README 在这里有 3 处与
> CONTEXT.md 不一致（`error_handling_improvement` / `capability_extension` /
> `performance_tuning`），2.0 已按代码实际行为更正。

## 信号检测

### 强信号（立即触发）

- 用户明确纠正插件行为
- 用户明确表达"以后都这样/不要这样"
- 连续失败 >= 3 次
- 性能指标持续下降（> 20%）

### 中信号（累积触发）

- 同类任务出现清晰模式（>= 2 次）
- 某个参数组合反复出错
- 用户偏好重复出现（>= 2 次）
- 循环行为被检测到（>= 5 次）

### 弱信号（仅记录）

- 轻微性能波动
- 一次性上下文需求
- 用户明确说"这次只是临时的"

## 三级验证

| 级别 | 验证内容 | 失败处理 |
|------|---------|---------|
| T0 | 语法验证 | 回退 + 重新生成 |
| T1 | 功能验证 | 回退 + 重新生成 |
| T2 | 回归验证 | 评估影响 + 决策 |

## Sub-Agent 协同

```
提案审批 → Executor 启动 → Sub-Agent 协同 → 验证测试 → 部署上线
    │              │              │              │           │
    │              │              │              │           └─ 更新 Registry
    │              │              │              └─ 三级验证
    │              │              └─ 代码生成 + 测试 + 文档
    │              └─ 分解任务 + 分配 Agent
    └─ 用户确认
```

### Sub-Agent 类型

- **code-generator**：生成新工具代码
- **test-writer**：编写和执行测试用例
- **doc-writer**：更新 SKILL.md 和文档
- **integration**：处理依赖和集成
- **validator**：运行验证测试

> 出厂模板随插件的 `agents/` 目录分发（frontmatter + 系统提示词，ZCode 的
> agent 载体格式），宿主会自动发现加载；`create_sub_agent` /
> `list_sub_agents` / `delete_sub_agent` 三个工具可以增删管理这些定义，
> 设计与研究结论见 `docs/subagent-factory.md`。

## 数据存储

所有数据以 JSONL / JSON 格式存储在**同一个数据根目录**下：

```
~/.harness-evolution/v2/          # 可用 $HARNESS_EVOLUTION_HOME 覆盖
├── plugin-cache.json   # 扫描缓存（含目录指纹，见下）
├── metrics.jsonl       # 性能事件（monitor 写）
├── signals.jsonl       # 进化信号（monitor 写 / engine 读）
├── proposals.jsonl     # 进化提案（ProposalStore 唯一读写口）
├── execution.log       # 执行日志（executor）
└── agents/             # 子 Agent 定义（factory 写，scope=plugin）
```

> scope=user 的子 Agent 定义写到宿主的 `~/.zcode/agents/`
> （跨出数据根，宿主会在后续会话加载），路径单点定义在 `store/paths.mbt`。

**有界保留（窗口裁剪）**：`metrics.jsonl` 与 `signals.jsonl` 是 append-only
的观测日志，没有上限时会随使用无界增长，而查询路径是全量读盘解析 ——
增长直接变成每次查询的延迟。因此这两个文件受 `max_log_bytes`（默认 32 MiB）
约束：flush 成功后若文件超限，自动裁到只保留**最新的完整行**（至少保住
最新一条，崩溃残留的不完整行一并清除）。`proposals.jsonl`（提案状态机与
审计的事实来源）与 `execution.log`（事件稀疏）**不裁剪**。

数据根目录的默认值只在 `store/paths.mbt` 一处定义，并由
`mcp/architecture_test.mbt` 的 G4 守卫机器化地防止它再次扩散
（1.0 版把它散落在 4 个文件里）。

**关于 v1 目录**：2.0 使用 `v2/` 子目录，**不做自动迁移**。
若检测到 1.0 的 `~/.harness-evolution/` 存在，启动时会在 stderr 提示一行，
然后原样保留该目录不动。原因是 1.0 的 `plugin-cache.json` 命中条件过于宽松
（只要缓存非空就直接返回，从不校验目录是否还存在），实测会被一条指向
已删除临时目录的幽灵记录永久毒化 —— 丢弃重扫比迁移更安全。

**缓存指纹**：2.0 的每个缓存条目都带目录指纹（`mtime` + 直接子项数 +
子项 `mtime`）。每次启动逐条校验：目录消失 → 丢弃该条并在 stderr 告警；
指纹变化 → 只重扫该子树。

## API

### MCP Tools

| Tool | 描述 |
|------|------|
| `scan_plugins` | 扫描所有插件 |
| `get_plugin_metrics` | 获取插件性能指标 |
| `propose_evolution` | 生成进化提案 |
| `execute_evolution` | 执行进化升级 |
| `list_proposals` | 列出所有提案 |
| `approve_proposal` | 批准提案 |
| `reject_proposal` | 拒绝提案 |
| `create_sub_agent` | 创建子 Agent 定义文件（scope=user 会写入宿主 `~/.zcode/agents/`） |
| `list_sub_agents` | 列出子 Agent 定义（可按 scope 过滤） |
| `delete_sub_agent` | 删除子 Agent 定义 |

### MCP Events

本插件**不注册任何 MCP Event**，只提供上表的 10 个工具。

> 1.0 版的 README 在这里列了 `on_plugin_call` / `on_user_feedback` 两个事件，
> 但 1.0 的代码里从未调用过 `registerEvent`（实测：`legacy-ts/src/mcp/server.ts`
> 只有 `registerTool`）。2.0 删掉了这张虚构的表 —— 文档描述不存在的能力
> 比不描述更糟，它会让集成方去订阅永远不会到达的事件。
>
> 性能事件确实在采集，但走的是**本地 JSONL 落盘**（`metrics.jsonl`），
> 不是 MCP 事件通道。

## 示例

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

...

✓ 执行完成！

变更摘要：
- 新增工具: smart_fill
- 延迟: 3.0s → 1.8s (-40%)
- Token: 350 → 245 (-30%)
```

## 开发

### 构建与测试

```powershell
.\build.ps1 check    # moon check --deny-warn --target native
.\build.ps1 test     # moon test --target native
.\build.ps1 build    # release 构建 + 复制到 bin\
.\build.ps1 all      # check → test → build
.\build.ps1 fmt      # moon fmt
```

### 代码组织

```
src/
  util/       路径、时间、wire 编解码、日志 —— 四个零依赖 Deep Module
  types/      ADT 与 19 张 wire 表（词汇表的单一事实来源）
  store/      唯一的持久化模块（JSONL / 提案索引 / 插件缓存 / 执行日志 / 子 Agent 定义）
  scanner/    插件发现与信息提取（纯逻辑与 I/O 分离）
  monitor/    性能事件采集与信号检测
  engine/     进化提案生成（决策树 + 风险评估）
  executor/   提案执行（DAG 分层 + Sub-Agent 编排）
  factory/    子 Agent 定义管理（校验/渲染/解析）
  mcp/        自研 stdio JSON-RPC 2.0 + 10 工具 + 架构守卫测试
  harness_evolution/   可执行入口（装配与启动）
```

依赖图是**严格分层**的（`util` → `types` → `store` → `scanner`/`monitor` →
`engine`/`executor`/`factory` → `mcp` → `harness_evolution`），由
`src/mcp/architecture_test.mbt` 的 11 条守卫机器化验证：任何新增的反向边、
任何往 stdout 写日志的尝试、任何绕过 `store/` 的持久化写入，都会在
`moon test` 里立刻变红。

### 架构守卫（G1–G6）

| 守卫 | 约束 |
|------|------|
| G1 / G1b | 包依赖图与声明完全一致，且每条边严格向下（构造性无环） |
| G2 / G2b | `@stdio.stdout` 只在 `mcp/server.mbt`，`@stdio.stderr` 只在 `util/log.mbt` |
| G3 / G3b | `@fs` 的写操作只在 `store/` |
| G4 / G4b | 数据目录字面量只在 `store/paths.mbt` |
| G5 / G5b | `legacy-ts/tests/` 的 37 个 jest 用例逐条有 MoonBit 对应物 |
| G6 | `moon.mod` 只有一个外部依赖，且 native 是首选目标 |

每条守卫都做过**负向探针**验证（人为引入违规确认会变红），
否则「永远通过的测试」只是装饰。

### 与 1.0（TypeScript）版对拍

1.0 的完整工程保留在 `legacy-ts/`，仍可运行：

```powershell
cd legacy-ts
npm install
npx jest          # 37 个用例
```

它是 2.0 移植正确性的客观参照：G5 守卫会解析这 37 个用例名，
逐条核对 MoonBit 侧的对应测试是否仍然存在。

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

## 许可证

MIT

## 贡献

欢迎提交 Issue 和 Pull Request！
