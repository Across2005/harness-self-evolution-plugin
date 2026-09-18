# DSH 集成指南（0.1.6 兼容 · 修正版）

> 本文档说明本插件在 DeepSeek Harness（DSH）0.1.6-alpha.1 上的真实挂载方式与工具边界。
> 上一版曾描述 `report_task_result` / `finalize_execution` 等**从未注册**的 MCP 工具，
> 以及「宿主 `subagent()` 编排 task DAG」等 web profile 默认不成立的能力 —— 均已更正。

## 挂载方式

本插件是 MoonBit 编译的**原生 stdio MCP server**（`bin/harness-evolution.exe`）。它在 DSH 里经
`@deepseek-ai/dsh-mcp-client` 以 stdio 拉起，挂载行写在 `cordis.patch.yml`（loader patch list）：

```yaml
- insert:
    - id: mcp-harness-evolution
      name: '@deepseek-ai/dsh-mcp-client'
      config:
        transport: stdio
        serverName: harness-evolution
        command: '<插件路径>/bin/harness-evolution.exe'
        args: []
        cwd: '<插件路径>'
        env:
          HARNESS_EVOLUTION_HOST: deepseek-harness
        failOnStartupError: true
```

- **`serverName: harness-evolution`** 决定工具公开名：`mcp__harness-evolution__<tool>`。
- **`failOnStartupError: true`** 是强判据：MCP 握手/工具发现失败时 DSH 启动直接失败。

安装二选一：

```powershell
# A) 标准安装（把上面的挂载行经 bundle patch 写入 profile）
dsh plugin --profile web add "D:/Agent设计/harness-self-evolution-plugin"

# B) overlay 临时挂载（不常驻，不写 profile）
dsh --profile web --dump-config --patch cordis.patch.yml   # 静态合成验证
```

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
  其真实机制是从 `~/.dsh/skills/` 扫描发现 **skill**（`dsh-skill-filesystem`，
  frontmatter 需 `name` + `description`，正文即指令体）。因此 DSH 侧 user-scope 定义
  以 skill 形式落盘到 `~/.dsh/skills/<name>.md`，宿主在后续会话经 skills 发现加载。
  可用 `HARNESS_EVOLUTION_HOST` 切换宿主、`HARNESS_EVOLUTION_USER_DIR` 显式指定目录。

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
# 1. 静态合成（不落 profile，先证 patch 合法）
dsh --profile web --dump-config --patch cordis.patch.yml   # exit 0 且含 mcp-client 行

# 2. 标准安装闭环
dsh plugin --profile web add "D:/Agent设计/harness-self-evolution-plugin"
dsh --profile web --dump-config                            # exit 0（无崩溃）
# boot 新端口 → stderr 见 "[HarnessEvolution] Server started"
# 会话内 `/` 目录含 mcp__harness-evolution__* 14 工具

# 3. 收尾还原
dsh plugin --profile web remove @across2005/harness-self-evolution
```
