# 子 Agent 工厂（Sub-Agent Factory）—— 研究结论与设计

> 状态：v2.1 落地。本文回答两个问题：
> ① 子 Agent 在 harness 工程中是怎么实现的；
> ② 「子 Agent 创建」能否做成一个 DSH（DeepSeek Harness）插件能力。
> 结论先行：**能**。本插件 v2.1 新增 3 个 MCP 工具管理子 Agent 定义，
> 出厂 5 个角色模板随插件分发；真实派发（申报书 M7）的进程型扩展缝已接入，但在事务性 sandbox adapter 落地前默认 fail closed，本文给出当前边界与设计草图。

## 1. 研究结论：子 Agent 在 harness 工程中的现状

### 1.1 本插件的 Sub-Agent 是模拟的（1.0 与 2.0 都是）

- 2.0：`src/executor/runner.mbt` 的 `simulated_task` = `@async.sleep(100)` 后返回
  `{"simulated": true, "message": "Sub-agent execution simulated"}`；
  `simulated_validation` 三级验证 sleep 后**恒返回通过**；
  `rollback()` 只记录状态回滚，不声称恢复文件（真实进程路径在事务性 adapter
  落地前由安全闸门拒绝）。
  `real_validation` 的进程能力仍用于显式开关下的只读/构建验证。
- 1.0：`legacy-ts/src/executor/index.ts` 的 `simulateSubAgent()` 同款；
  注释写的 `sessions_spawn` 从未实现。
- 但**骨架是真的**：任务 DAG 拓扑分层（`dag.mbt`）、层内并行/层间串行、
  `timeout_ms` 由 `with_timeout_opt` 真正强制、失败回滚到 pending、
  「怎么跑一个任务」是构造时注入的函数缝（`run_task` / `validate_level`）。
  接真实执行不需要改 `execute` 主体一行。

### 1.2 真实子 Agent 的参照实现

defending-code-reference-harness（本机 `~/.agents/skills/sec-sandbox-test/` 下，Apache-2.0）：
每个任务 `asyncio.create_subprocess_exec` 拉起 headless CLI
（`claude -p --output-format stream-json`，跑在 gVisor 容器里），
逐条接收 JSONL 事件并落盘 transcript；`asyncio.gather` 并发多角色
（recon/find/grade/judge/report/patch）。一句话对照：
**那边的"子 agent" = 每任务一个 CLI 子进程 + 沙箱 + 流式 JSONL 回传；
本插件的"子 agent" = 100ms sleep + 恒成功 JSON。**

### 1.3 DSH / Minimax Code 里 agent 的真实载体（本机实证）

- **用户级**：`<用户级定义目录>/agents/<name>.md` —— Markdown + YAML frontmatter
  （`name` / `description` / `color` / `tools`），正文是系统提示词。
  （实测样本取自某个已部署宿主的 user 作用域定义。）
- **插件级**：官方插件 document-skills 携带 `agents/judge.md`，frontmatter 同上
  （`tools: [Read, Bash]`）；其 plugin.json **没有**显式 `agents` 键 ——
  loader 缺省扫描插件根的 `agents/` 目录（与 `skills/`、`commands/` 同一模式），
  显式 `agents` 键也可用。
- **能力边界**：MCP 工具运行在插件自己的进程里，MCP 协议中**没有**
  「请求宿主即时 spawn 一个子 agent 会话」的方法。插件能做的只有两件事：
  1. **管理 agent 定义文件**（写/列/删 `.md`），由宿主在其后的会话中发现加载；
  2. **在自己进程内** spawn CLI 子进程当子 agent 用 ——
     这与宿主的 Task 工具体系是并行的两套，不是同一机制。

## 2. 可行性判定与三条路径

| 路径 | 做法 | 状态 |
|------|------|------|
| A. 出厂模板 | 插件根 `agents/` 目录带 5 个角色 `.md`，声明进 plugin.json | ✅ v2.1 落地 |
| B. 动态创建 | MCP 工具创建/列出/删除 agent 定义文件 | ✅ v2.1 落地 |
| C. 真实派发 | `run_task` 函数缝换进程实现（见 §4） | ⏸ 安全闸门：等待事务性 sandbox adapter |

## 3. v2.1 落地：工厂的设计

### 3.1 代码组织（新增代码全部进包，不暴露散文件）

```
src/factory/            新包：校验、frontmatter 渲染/解析、业务规则
  factory.mbt             AgentDefinition + AgentFactory
  factory_wbtest.mbt      白盒测试
src/store/
  agent_defs.mbt          AgentDefStore：.md 定义文件的读写删列（fs 写仍只在 store/）
src/mcp/
  schema.mbt              3 个新工具的 inputSchema + Args 结构体
  tools.mbt               3 个新 handler（注册进 tools()，错误统一走 call_tool）
types/wire_tables.mbt     新 wire 表 agent_scope（不变量⑦：一个枚举一张表）
agents/                  出厂 5 角色模板（Markdown，非 MoonBit，随 loader 约定分发）
```

分层：`store → factory → mcp`（与 engine/executor 同层），G1 声明图同步更新。

### 3.2 工具契约（MCP，stdio JSON-RPC）

**`create_sub_agent`** —— 创建一个子 Agent 定义文件。

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `name` | string | ✅ | kebab-case：小写字母/数字/连字符，1–64，不以 `-` 开头或结尾，无连续 `-` |
| `description` | string | ✅ | 1–1024 字符，单行（frontmatter 不换行） |
| `system_prompt` | string | ✅ | 1–65536 字符，作为 .md 正文 |
| `tools` | string[] | — | 每项 1-64 字符，且不含空白 / `,` / `[` / `]`（它们会破坏 frontmatter 的 `[a, b]` 形状；工具名白名单由宿主负责，这里只做形状校验） |
| `color` | string | — | ≤20 个小写字母 |
| `scope` | enum `plugin` \| `user` | — | 默认 `plugin`（见下） |
| `overwrite` | bool | — | 默认 `false`；同名已存在时报错而非覆盖 |

- `scope=plugin` → 写入 `<数据根>/agents/<name>.md`（插件自管理，默认）。
- `scope=user` → 写入宿主的用户级定义目录（**跨出数据根**，宿主会加载；
  默认宿主 DeepSeek Harness 为 `<DSH home>/skills/<name>.md` —— **DSH 0.1.5-rc.2 没有独立的
  「用户级 agents 目录」**（0.1.6-alpha.1 回归目标同样如此），其真实机制是从 `<DSH home>/skills/` 扫描发现 skill
  （`dsh-skill-filesystem`，frontmatter 需 `name` + `description`，正文即指令体）；
  home 由 `paths.mbt::dsh_home()` 解析 `$DSH_HOME`，未设置时回落 `~/.dsh`，
  故 user-scope 定义以 **skill** 形式落盘，宿主在后续会话经 skills 发现加载；
  可用 `HARNESS_EVOLUTION_USER_DIR` 显式指定目录（自 v3.0.0 起 `HARNESS_EVOLUTION_HOST` 多宿主开关已移除）；
  这是刻意的显式选择，工具描述里向 LLM 说明影响面）。
- 返回：`{success, path, name, scope, overwritten}`。
- 错误：非法 name/description（`Failure`，经 `call_tool` 转 isError）、
  已存在且未 overwrite、目录创建失败。

**`list_sub_agents`** —— 列出定义。`scope?`（缺省 = 两个作用域都列，
顺序固定为先 plugin 后 user；传 `plugin` / `user` 只列对应作用域）。
返回每项 `{name, description, color?, tools?, scope, path}`。
解析只认 YAML 子集：`---` 围栏 + `key: value` 行；`tools` 形如 `[A, B]`。
解析失败的文件跳过并在 stderr 告警，不让整个列表失败。

**`delete_sub_agent`** —— 删除定义。`name` ✅、`scope?`（默认 `plugin`）。
只删除两个**可写目录**里的文件；出厂模板（仓库 `agents/`）不在这两个目录里，
天然不可被此工具删除。

### 3.3 持久化与守卫

- 写路径全部在 `store/agent_defs.mbt`（G3：fs 写只在 store）。
- 数据根新增 `agents/` 子目录，路径字面量仍只在 `store/paths.mbt`（G4）；
  各宿主的用户级 agents 目录字面量同址定义（`user_agents_dir`）。
- `agent_scope` 是新的字符串枚举 → 一张 wire 表（不变量⑦），
  schema 的 `enum` 直接取 `names()`。
- handler 不写 try/catch（不变量④），业务失败 `raise Failure`。

### 3.4 边界与风险（写进工具描述，让 LLM 与用户都有感知）

- 创建 ≠ 派发：本工具只产出定义文件，宿主何时、以何种方式加载由宿主决定，
  未必热生效。
- `scope=user` 写的是宿主配置目录：文件内容会成为后续会话里可被调用的 agent
  系统提示词。工厂对内容只做形状校验，不做语义审查 —— 与 SKILL.md 的
  「审批强制」一致，写入动作本身就是显式工具调用（用户可见）。
- 出厂模板的内容属于插件版本管理；数据目录与用户目录里的定义归用户所有。

## 4. M7 真实派发：安全闸门与事务性 adapter（当前状态）

`UpgradeExecutor` 仍通过 `run_task` 函数缝选择执行器；`execute` 主体不直接依赖
进程细节。但当前生产装配的 `process_task` **不会启动任意子进程**：设置
`HARNESS_EVOLUTION_AGENT_CMD` 会明确返回

```text
real sub-agent execution is disabled: HARNESS_EVOLUTION_AGENT_CMD requires a transactional sandbox adapter
```

这是刻意的 fail-closed，而不是能力回归声明：裸子进程可以绕过
`sandbox_atomic_write`，导致新建/删除文件与并发写入无法进入
`PreCheckResult.modified_paths`，此时声称「已回滚」会制造假安全感。未设置该变量时仍
回退 `simulated_task`，因此测试注入缝与现有提案闭环保持不变。

### 4.1 重新开放真实派发的前置条件

1. 提案/工具层提供可信 `TaskTarget`：`plugin_id`、绝对 `boundary_root` 与完整的
   `target_files` allowlist；不能从工具名或扫描根猜目标文件。
2. 真实 runner 在临时 worktree/copy 中运行，或返回完整的
   created/modified/deleted mutation manifest；边界外、符号链接与未声明文件均拒绝。
3. executor 在 `run_pipeline` 开头建立 sandbox，在任务/验证失败时恢复，在成功
   且 post-verify 通过后丢弃；恢复失败必须独立记录，不能吞掉主错误。
4. 为上述生命周期补 fake-hook 与真实字节级回归后，才可把 M7 标为已实现。

### 4.2 仍可用的真实验证

`HARNESS_EVOLUTION_REAL_VALIDATION=true` 仍显式运行 T0/T1/T2 命令（`moon check`、
`moon test`、`build.ps1 -Task all`），失败返回证据；关闭时使用
`simulated_validation`。该开关是验证命令入口，不授予任务 runner 文件回滚能力。

依赖：`executor/moon.pkg` 的 `moonbitlang/async/process` 仍供 real_validation 使用。
**刻意不做**：在工厂里直接派发 —— 创建（管理平面）与派发（数据平面）分开，
是 defending harness 与本仓分层的一致做法。
