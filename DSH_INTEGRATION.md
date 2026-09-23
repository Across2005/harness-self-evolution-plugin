# DSH 集成指南（0.1.6 兼容 · 修正版）

> 本文档说明本插件在 DeepSeek Harness（DSH）0.1.6-alpha.1 上的真实挂载方式与工具边界。
> 上一版曾描述 `report_task_result` / `finalize_execution` 等**从未注册**的 MCP 工具，
> 以及「宿主 `subagent()` 编排 task DAG」等 web profile 默认不成立的能力 —— 均已更正。

## 挂载方式

本插件是 MoonBit 编译的**原生 stdio MCP server**（`bin/harness-evolution.exe`）。它在 DSH 里经
`@deepseek-ai/dsh-mcp-client` 以 stdio 拉起，挂载行由 `scripts/install-dsh.ps1` 在**目标树**上
写进该 profile 的 patch 层（`<DSH_HOME>/profiles/<name>/cordis.patch.yml`）：

```yaml
# >>> mcp-harness-evolution (install-dsh.ps1) >>>
- id: mcp-harness-evolution          # id 定向覆盖行：命中即逐字段替换（config 是整体替换）
  disabled: false
  config:
    transport: stdio
    serverName: harness-evolution
    command: '<profile>/node_modules/@across2005/harness-self-evolution/bin/harness-evolution.exe'
    args: []
    cwd: '<profile>/node_modules/@across2005/harness-self-evolution'
    env:
      # 宿主 spawn MCP 子进程时用 scrubbedParentEnv() 丢弃**全部** DSH_*（继承拿不到），
      # 只有挂载行 env 里的字面量能在清洗**之后**被合并（dsh-mcp-client 的 buildChildEnv）。
      # 值由安装器按目标树计算 —— 插件侧另有「从安装路径推导」兜底档，漏配也不会写错树。
      DSH_HOME: '<DSH_HOME>'
    failOnStartupError: true
# <<< mcp-harness-evolution (install-dsh.ps1) <<<
```

- **`serverName: harness-evolution`** 决定工具公开名：`mcp__harness-evolution__<tool>`。
- **`failOnStartupError: true`** 的**真实**语义：MCP 握手/工具发现失败时**拒绝该插件激活**
  （宿主打一行 `warning`），**不中止 harness 启动**。原因：本行 id 不在宿主的
  `requiredStartupEntryIds`（`agent-loop` / `webserver` / `modules` / `connection` /
  `headless-runner` / `acp` / `sdk-jsonrpc-server`）里，app-boot 把它的激活失败归入
  **optional**（`dsh-app-boot/lib/index.js:2408-2416` / `2513-2515`）。
  它的价值是「把握手与工具发现纳入启动诊断」，**不是**「让 boot 失败」。
- **真正会打挂 profile 启动的是 patch 层解析失败**：`parsePatchList` 是 `throw`
  （`dsh-app-boot/lib/index.js:2158-2163`），异常一路上抛到 `prepareProfile`。
  `scripts/install-dsh.ps1` 写的正是这个文件，其产物由
  `scripts/test-install-dsh.ps1`（用宿主的 `js-yaml` 解析）机器化钉住。
- **出厂 `cordis.patch.yml` 的同一行默认 `disabled: true` 且不含机器绝对路径**（v3.1）：
  静态字面量只对某一台机器成立，换机器就指向不存在的文件，**结果是该插件静默不挂载**
  （一行 warning，宿主照常启动）。安装器负责在该树上启用并注入绝对路径。

安装：

```powershell
# ① 安装 + 注入挂载行（解析 $DSH_HOME，缺省回落 ~/.dsh；-DryRun 可先看将写入什么）
pwsh -File scripts/install-dsh.ps1 -Profile web

# ② 静态自检（不 boot）
dsh --profile web --dump-config | Select-String 'mcp-harness-evolution'

# ③ 重启宿主后才挂载（bundles 与 patch 层都在 boot 时读取）
```

改安装器前后请跑它的回归套件（在临时树上跑**真实**脚本，用宿主的 `js-yaml` 验产物）：

```powershell
pwsh -File scripts/test-install-dsh.ps1     # 7 个场景，全绿才算通过
```

`-DshHome` / `-DshCommand` / `-SkipPluginAdd` / `-Uninstall` 见脚本头注释；
`dsh` 不在 PATH 时用 `-DshCommand 'node <DSH runtime>/node_modules/@deepseek-ai/dsh/lib/bin.js'`。
`scripts/replace-paths.ps1` 保留给 fork/CI 改仓库字面量的场景，不再是安装主路径。

## 权威工具清单（14 个）

以 `src/mcp/tools.mbt` 为准，宿主内公开名为 `mcp__harness-evolution__<name>`：

| 工具 | 作用 |
|------|------|
| `scan_plugins` | 扫描插件（全量 / 定向重扫 / 路径重定向） |
| `get_plugin_metrics` | 获取插件性能指标 |
| `propose_evolution` | 生成进化提案 |
| `execute_evolution` | **自包含**执行已批准提案（见下） |
| `list_proposals` | 列出提案（按状态/插件过滤） |
| `approve_proposal` | 批准提案 |
| `reject_proposal` | 拒绝提案 |
| `create_sub_agent` | 创建子 Agent 定义文件 |
| `list_sub_agents` | 列出子 Agent 定义 |
| `delete_sub_agent` | 删除子 Agent 定义 |
| `analyze_plugins` | 合并工具：扫描并/或取指标 |
| `evolve_plugin` | 合并工具：生成或执行提案 |
| `manage_sub_agent` | 合并工具：管理子 Agent 定义 |
| `get_runtime_snapshot` | 只读运行时快照 |

## `execute_evolution` 是自包含工具

`execute_evolution` **不返回 task DAG**，也不要求宿主编排。它内部经 executor 跑完
DAG，返回执行结果摘要：

```json
{
  "success": true,
  "proposal_id": "evo-...",
  "results": [
    { "agent": "code-generator", "success": true, "duration_ms": 123 }
  ]
}
```

最小进化闭环（宿主 Agent 直接依次调用即可，无需手工拆任务）：

```
scan_plugins → propose_evolution → approve_proposal → execute_evolution
```

## 子 Agent 工厂与作用域

`create_sub_agent` / `list_sub_agents` / `delete_sub_agent` 只管理**定义文件**
（Markdown + YAML frontmatter），不派发执行：

- `scope=plugin`（默认）→ 写插件数据根下的 `agents/`（插件自管理）。
- `scope=user` → 写宿主的用户级定义目录。**DSH 没有独立的「用户级 agents 目录」**，
  其真实机制是从 `<DSH home>/skills/` 扫描发现 **skill**（`dsh-skill-filesystem`，
  frontmatter 需 `name` + `description`，正文即指令体）。因此 DSH 侧 user-scope 定义
  以 skill 形式落盘到 `<DSH home>/skills/<name>.md`，宿主在后续会话经 skills 发现加载。
  home 由 `paths.mbt::dsh_home()` 解析，优先级三档：
  **`$DSH_HOME`（去空白判空、须绝对）→ 安装路径推导 → `~/.dsh`**。
  第二档（v3.1 新增）从 `@env.current_dir()` 与 `@env.args()[0]` 里识别
  `<X>/profiles/<name>/node_modules/…` 形态并取出 `X` —— 即「本插件被哪棵树装上了」。
  宿主 spawn MCP 子进程时会用 `scrubbedParentEnv()` 丢弃**全部** `DSH_*`，继承拿不到该值，
  所以第一档须由挂载行的 `env` 显式转发（安装器已写好）；第二档保证即使那一项漏配，
  定义也不会落进宿主不读的另一棵树。
  可用 `HARNESS_EVOLUTION_USER_DIR` 显式指定目录（优先级最高）。

> 注：`create_sub_agent` 产出的 frontmatter 含 `color` / `tools` 键，DSH 的 skill 解析器
> 会忽略这些未知键，仅读 `name` / `description` —— 格式天然兼容，无需改渲染层。

## 监控边界（如实声明）

本插件作为 out-of-process stdio MCP server，**无法订阅宿主进程内的事件流**。性能事件与
进化信号需宿主侧注入（`record_tool_call` / `record_user_feedback` 已就绪但暂无生产调用方）。
在无注入时，`get_plugin_metrics` / 信号检测返回空 —— 这是「未接线」而非「无活动」，
`get_runtime_snapshot` 的 `data_gaps` 字段会如实点名。跨插件观测由进程内的
`dsh-watcher` 子插件承担。

## 验证

```powershell
# 1. 安装 + 注入挂载行（先看将写入什么：加 -DryRun）
pwsh -File scripts/install-dsh.ps1 -Profile web

# 2. 静态合成（不 boot，先证 patch 合法且该行已启用）
dsh --profile web --dump-config | Select-String 'mcp-harness-evolution'
#    exit 0；该行 disabled 为 false，command/cwd 指向本树安装位

# 3. 重启宿主后（bundles 与 patch 层都在 boot 时读取）
#    boot stderr 见 "[HarnessEvolution] Server started (data root: ..., scan roots: N, ...)"
#    会话内 14 个 mcp__harness-evolution__* 工具可调
#    create_sub_agent scope=user → 文件落 <DSH_HOME>/skills/（不是 ~/.dsh/skills/）

# 4. 收尾还原
pwsh -File scripts/install-dsh.ps1 -Profile web -Uninstall
dsh plugin --profile web remove @across2005/harness-self-evolution
```
