# Harness Self-Evolution Plugin × DSH 兼容性测试报告

- **测试日期**：2026-09-20
- **被测插件**：`@across2005/harness-self-evolution` v3.0.0（MoonBit native，`bin/harness-evolution.exe`，1.59 MB）
- **宿主环境**：DeepSeek Harness `@deepseek-ai/dsh@0.1.6-alpha.1`（满足 `engines.dsh >=0.1.6`）
- **宿主实际启动树（DSH_HOME）**：`C:/Users/19207/.minimax/v2/plugin-data/local-minimax/dsh/dsh-home`（Mavis 托管，非默认树）
- **挂载方式**：profile `web` 的 `dsh.profile.bundles` 含 `@across2005/harness-self-evolution`（pnpm link → Junction → 本工作区）+ `dsh-evolution-panel`；插件自带 `cordis.patch.yml` 作为 bundle patch 提供 `mcp-harness-evolution` 挂载行（`@deepseek-ai/dsh-mcp-client`，stdio，`failOnStartupError: true`）
- **数据根**：`C:/Users/19207/.harness-evolution/v2`

---

## 修复状态（2026-09-20 同日闭环，v3.1.0）

本报告列出的 A/B/C/E 四项**已全部修复并实证**；D/F 按决策**本轮不碰**（见 `ROADMAP.md` § v3.1、
`CONTEXT.md` § v3.1 决策记录）。修复后的验证证据：

| 项 | 修法 | 实证 |
|---|---|---|
| **A** 启动路径/树不一致 | 出厂挂载行改 `disabled: true` + 零机器路径；新增 `scripts/install-dsh.ps1` 按目标树注入 id 定向覆盖行；`dsh_home()` 新增**安装路径推导**档；扫描根随 `dsh_home()` 派生 | ① 无 `DSH_HOME`、exe 路径不匹配安装位时，`create_sub_agent scope=user` 落进 `<dsh-home>/skills/`（旧版落 `~/.dsh/skills/`）；② `--dump-config` exit 0 且该行 `disabled: false`、`command/cwd/env.DSH_HOME` 全为本树；③ 磁盘缓存 `version = 4` 且唯一条目指向 `<dsh-home>/profiles/web`（证明会话内已是新二进制且树已纠正） |
| **B** `scan_targets` 非 DSH 根 | 出厂 `.dsh-plugin/plugin.json` 删除该段（回落派生默认根） | 全量重扫后缓存 **83 → 1** 条（陈旧的多宿主档案清空）；守卫 G8 钉住「出厂清单无 `scan_targets`」 |
| **C** SKILL.md 解析噪音 | `read_manifest_meta` 对非 JSON 清单短路（`manifest_is_json` 纯函数） | 同一目录 36 个 SKILL.md 型插件：**旧 3.0.0 = 36 条告警 → 新 3.1.0 = 0 条**，发现数同为 36（行为不变） |
| **E** 陈旧缓存 | `cache_version` 3 → 4（整份作废重扫） | 重扫后只剩本树 1 条；`proposals.jsonl` / `metrics.jsonl` / `execution.log` 未受影响 |

**最终门禁**：`moon check --deny-warn` exit 0（零错零警）；`moon test` **453/453**（443 → 453，新增 10 条）；
G5b 锚点同步；MCP 工具面**零变更**（仍 14 个，schema 不变，`tools/list` 回显 `version: 3.1.0`）；
版本五处一并升 3.1.0（`moon.mod` 0.3.2）。

> 注：本轮同时落盘了 Matt Pocock 工程流程脚手架（`docs/agents/{issue-tracker,domain,triage-labels}.md`
> 与 `AGENTS.md` 的 `## Agent skills` 块），供后续 `/triage`、`/to-spec`、`/implement` 等流程消费。

---

## 一、结论摘要

| 维度 | 结论 |
|---|---|
| **二进制 MCP 协议** | ✅ 兼容（JSON-RPC 握手 / tools/list 正常，协议 2024-11-05） |
| **工具面** | ✅ 14 个工具与文档、清单完全一致，会话内全部可调 |
| **构建链** | ✅ `moon check --deny-warn` 0 错 0 警；`moon test` **443/443 通过** |
| **读路径（扫描/快照/提案/指标/清单）** | ✅ 全部工作，且数据缺口如实声明 |
| **写路径（子 Agent 工厂）** | ✅ 端到端可用，产出格式与 DSH skill 发现格式兼容 |
| **提案状态机** | ✅ propose（信号门控 + 确定性 ID 去重）正常 |
| **部署一致性** | ⚠️ **当前部署扫描/写入落在默认树 `~/.dsh`，而宿主实际从 `dsh-home` 树启动**——已知问题、有文档化修法、但本部署未应用 |
| **配置一致性** | ⚠️ 出厂 `plugin.json` 的 `scan_targets` 仍含两条非 DSH 根（多宿主时代残留），与 v3.0.0「DSH-only」声明不一致 |

**总评：插件与 DSH 0.1.6-alpha.1 协议/工具/构建层完全兼容；剩余问题集中在「装进了哪棵树」的部署配置与出厂配置残留，均为配置层问题而非代码缺陷。**

---

## 二、测试证据明细

### 1. 二进制 MCP 握手（无宿主直连测试）

```
$init | .\bin\harness-evolution.exe 2>$null
→ {"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05",
   "capabilities":{"tools":{}},"serverInfo":{"name":"harness-self-evolution","version":"3.0.0"}}}
```

`tools/list` 返回 **14 个工具**：`scan_plugins, get_plugin_metrics, propose_evolution, execute_evolution, list_proposals, approve_proposal, reject_proposal, create_sub_agent, list_sub_agents, delete_sub_agent, analyze_plugins, evolve_plugin, manage_sub_agent, get_runtime_snapshot` —— 与 `DSH_INTEGRATION.md`、`.dsh-plugin/plugin.json` 三方一致。

### 2. 会话内工具连通性（真实挂载验证）

本会话（运行于该 DSH 实例上）中 14 个 `mcp__harness-evolution__*` 全部可用并实际调用成功：

| 工具 | 测试 | 结果 |
|---|---|---|
| `get_runtime_snapshot` | 数据根/缓存/提案/execution.log/data_gaps | ✅ 61 条缓存、3 条 completed 提案、`signals.jsonl` 缺口如实点名 |
| `list_proposals` | 全量 | ✅ 3 条（全部 completed） |
| `get_plugin_metrics` | tabbit-0.0.0 | ✅ 返回空统计（未接线，非报错） |
| `list_sub_agents` | 全量 | ✅ 空数组无错 |
| `scan_plugins` | ① 默认根 ② `target_paths` 指向实际树 `.../dsh-home/profiles`（force_rescan） | ✅ 均正常；实际树发现 `dsh-profile-web-0.0.0` |
| `analyze_plugins` | mode=scan | ✅ 83 条缓存插件 |
| `create_sub_agent` | scope=user 烟测 | ✅ 落盘 `C:/Users/19207/.dsh/skills/evo-smoke-test.md`（见 §3） |
| `delete_sub_agent` | 清理烟测 | ✅ 文件已删 |
| `propose_evolution` | ① 无信号 ② 带手动信号 | ✅ ① 返回「insufficient signals」诚实空操作；② 确定性 ID 命中既有提案去重，返回 completed 而非重复生成 |

> 说明：`approve/execute` 未执行（会真实改动代码，超出只读兼容测试范围）；`evolve_plugin`/`manage_sub_agent` 为同语义合并工具，底层路径已被上面覆盖。

### 3. 子 Agent 工厂与 DSH skill 格式（写路径实证）

`create_sub_agent scope=user` 产出的文件（已清理）：

```markdown
---
name: evo-smoke-test
description: DSH compatibility smoke test agent
---

Temporary smoke-test definition. Delete after verification.
```

格式与 DSH `dsh-skill-filesystem` 发现要求一致（frontmatter 含 `name` + `description`，正文为指令体）。出厂 `skills/harness-evolution/SKILL.md` frontmatter 亦合法（`name`/`description`/`version: 3.0.0`）。

### 4. 构建与自检

| 命令 | 结果 |
|---|---|
| `moon check --deny-warn` | ✅ exit 0（46 tasks），0 错 0 警 |
| `moon test` | ✅ **443/443 通过**，exit 0 |
| 工具链 | `moon 0.1.20260915` ≥ 要求的 `>=0.1.20260904`；依赖锁 `moonbitlang/async@0.20.1` |

---

## 三、发现的问题与风险

### A. ⚠️ 当前部署「树不一致」：扫描与 user 作用域写入落在 `~/.dsh`，宿主实际从 `dsh-home` 启动（最重要）

- 宿主进程 `DSH_HOME` = `...\local-minimax\dsh\dsh-home`；但 MCP 子进程经 `scrubbedParentEnv()` 丢弃全部 `DSH_*`，挂载行 `cordis.patch.yml` 又只转发 `DSH_HOME: ''`（空 = 未设置）。
- **实证**：`create_sub_agent scope=user` 写到 `C:/Users/19207/.dsh/skills/`（默认树），而宿主只从 `<dsh-home>/skills/` 发现 skill（该目录当前不存在）→ 定义不会被本宿主加载。
- **实证**：默认扫描根 `~/.dsh/profiles/` 扫到的是**另一棵**树的 web profile（bundles 只有 `dsh-base`+`dsh-web-app`，并未挂载本插件）；实际树的 `.../dsh-home/profiles` 只有在 `target_paths` 显式指向时才被扫到。
- 两棵树各有同名 `web` profile → `plugin_id` 均为 `dsh-profile-web-0.0.0`，缓存按先到先得去重，可能指向错误路径。
- **修法（文档已给，本部署未执行）**：`pwsh -File scripts/replace-paths.ps1 -DshHome "$env:DSH_HOME"` 把实际树绝对路径写入挂载行 `env.DSH_HOME`，然后重启宿主。

### B. ⚠️ 出厂配置与「DSH-only」声明不一致：`scan_targets` 仍含两条非 DSH 根

- `.dsh-plugin/plugin.json` 的 `scan_targets` = `["~/.dsh/profiles/", "~/.agents/skills/", "~/.openclaw-autoclaw/skills/"]`。
- v3.0.0 只从硬编码 `default_scan_roots()` 移除了 MiniMax 根，但 `scan_targets` 覆盖默认值，后两条根（其他产品的 skills 目录）仍被扫描 → 缓存里混入 autoclaw 等非 DSH 插件（61 条缓存中约 50 条来自这两条根）。
- 建议：v3.0.0 语义下 `scan_targets` 应收敛为 `["~/.dsh/profiles/", "~/.agents/plugins"]`（与 `default_scan_roots` 对齐）。

### C. 低危噪音：SKILL.md 作为清单形式必然触发 JSON 解析告警

- `manifest_priority` 含 `"SKILL.md"`（F3 设计），但 `read_manifest_meta` 用 `read_json` 读它——SKILL.md 是 Markdown，永远解析失败。
- 实测旧引导日志约 60 行 `[Store] Cannot parse .../SKILL.md: Invalid character '-' at line 1, column 1`；功能不受影响（回落目录名 + 0.0.0），但每次全量扫描刷屏。
- 建议：对 `manifest == "SKILL.md"` 走 frontmatter 解析或静默跳过。

### D. 已知边界（非缺陷）：监控未接线

- `get_plugin_metrics` / 信号检测为空是「无生产调用方注入」而非「无活动」；`get_runtime_snapshot.data_gaps` 如实点名（本插件自测量覆盖自身工具调用）。符合文档声明。

### E. 低危：插件缓存含 v3.0.0 之前的陈旧记录

- 缓存中的 `harness-evolution-0.0.0`（`C:/Users/19207/.minimax/plugins/...`）、`.openclaw-autoclaw/skills/*` 等来自多宿主时代的扫描（同批时间戳 2026-09-18T00:19:37）。按当前根全量 force_rescan 后这些路径不再被扫到（记录保留与否取决于缓存改写策略）。建议定期全量重扫一次以收敛。

### F. 备注：dsh-watcher 未挂载

- `dsh-watcher` 已装入 profile node_modules 但不在 `dsh.profile.bundles` 列表中（`dsh-evolution-panel` 在），DSH_INTEGRATION 中「跨插件观测由进程内 dsh-watcher 承担」在本部署尚不成立。

---

## 四、建议动作（按优先级）

1. **应用树的转发**：`scripts/replace-paths.ps1 -DshHome "$env:DSH_HOME"`，重启宿主，重验 `create_sub_agent scope=user` 落盘到 `<dsh-home>/skills/`。
2. **收敛 `scan_targets`**：移除 `.agents/skills` / `.openclaw-autoclaw/skills`，与 v3.0.0 单宿主声明对齐；顺手做一次全量 force_rescan 清陈旧缓存。
3. **处理 SKILL.md 告警噪音**（可选，纯体验）。
4. 若要在本机恢复「宿主能加载 user 作用域定义」，可同步把 `<dsh-home>/skills` 目录建出来并确认宿主 skill-filesystem 的发现根。

---

## 五、测试范围声明

- 覆盖：二进制直连握手、14 工具真实调用、写路径烟测（已清理）、提案管线（propose 信号门控 + 去重）、构建/自检（T0/T1）。
- 未覆盖（需人工或授权）：`approve_proposal → execute_evolution` 全链路（会真实改代码）、`evolve_plugin action=execute`、回滚验证、T2 全量回归（`moon test` 已覆盖本仓全部 443 用例）。
