---
feature: dsh-optimize-p0-p3
status: delivered
updated: 2026-09-24
branch: main
commits: 2838460..fce0e07
---

# DSH 插件 P0–P3 全量优化

## Report

**What was built** — v3.2.0：① 安装器回归网/复验报告入库 + DESIGN「启动时扫描」失实纠偏；② 新增 `record_tool_call`/`record_user_feedback` 注入面（工具 14→16），data_gaps/面板文案改为「注入面已暴露」；③ `process_task`/`real_validation` 经 `@process.collect_output` 真实执行（env 驱动、哨兵单 argv、spawn 失败收口），生产装配注入；④ 面板 npm test 18/18、删除 `miniapps/` 残留、版本五处一致。两轴 code-review 硬伤已修（CONTEXT 注入面词条、AGENTS 日期、G1 引用、假 cwd、写穿测试、历史 14/16 区分）。

**Verification** — `moon check --deny-warn` 零错零警；`moon test` **457/457**；`scripts/test-install-dsh.ps1` 7/7；`dsh-evolution-panel` npm test 18/18；`build.ps1 -Task all` EXIT=0 并刷新 `bin/harness-evolution.exe`（1,697,792 B）。

**Journey log** — ① PowerShell 批量字符串替换破坏 UTF-8，已用 `git show` 按字节恢复后改用 Edit 工具重做；② MoonBit 本版本 async **无 `await` 关键字**、`replace` 需 `old~/new~` 标签、`cwd?` 不接受 `String?`、`Ok(expr) catch` 必须与返回类型对齐；③ G5b 锚点 454→**457**（审查补网：写穿 +1、fake-cwd +1）。

## [S1] Problem

仓库存在四层待处理问题：

1. **P0 卫生**：安装器回归网与复验报告未入库；DESIGN 等文档仍有「启动时扫描」失实；全门禁未在当前工作树复跑。
2. **P1 缺陷 9**：监控链只有本插件自测量，宿主/Agent **没有** 向 `metrics`/`signals` 注入其他插件事件的 MCP 面；`data_gaps` 只能点名「未上报」。
3. **P2 M7**：`process_task` / `real_validation` 在开关打开时显式 `raise "not implemented"`，三级验证与子 Agent 仍是模拟。
4. **P3 面板**：`dsh-evolution-panel` 有测试但「可视化验收」未在本轮闭环；`miniapps/` 为已取消的 MiniMax 打包残留。

## [S2] Design

### P0 卫生与文档

- 提交：`scripts/test-install-dsh.ps1`、`scripts/test-patch-layer.mjs`、`scripts/_archive/README.md`、`COMPATIBILITY_RECHECK_2026-09-22.md`。
- 纠正 `DESIGN.md` 中「启动时扫描 / 启动时」等与 README/SKILL 不一致的表述（能力以「工具调用触发扫描」为准）。
- 跑 `pwsh -File scripts/test-install-dsh.ps1`（7/7）与 `.\build.ps1 -Task all`（T0/T1/T2）。

### P1 生态注入面（缺陷 9 第二步）

新增 **2 个 MCP 工具**（工具面 14 → **16**），把已就绪的 monitor API 暴露为宿主可调注入点：

| 工具 | 作用 |
|------|------|
| `record_tool_call` | 按 `plugin_id` 写入延迟/成败/可选 error_message（参数体刻意不落盘，与自测量同策略） |
| `record_user_feedback` | 写入 positive/negative + 可选 context |

- Schema：`plugin_id`、`tool`、`latency_ms`、`success`、`error_message?` / `feedback`（wire 表已有 UserFeedback）。
- Handler：只调 `state.monitor.record_*`；错误仍走 `call_tool`（不变量④）。
- `data_gaps` / 面板文案更新：从「宿主未上报」改为「**注入面已暴露**；未调用则仍无该插件数据；自测量仅本插件」。
- 同步：`.dsh-plugin/plugin.json` mcp.tools、`DSH_INTEGRATION` 工具表、SKILL、README 十四→十六、schema_wbtest 顺序锚点、G5b 测试数。

**不**在本切片挂载 `dsh-watcher` 进程内桥（另立项）；注入面是 out-of-process 下唯一可机读的生态数据入口。

### P2 M7 真实派发

依赖：`executor/moon.pkg` 增加 `"moonbitlang/async/process"`（同一 `moonbitlang/async@0.20.1`，不新增外部包）。

**`process_task`**（`HARNESS_EVOLUTION_AGENT_CMD` 已设置时）：

1. 模板支持 `{prompt}`、`{input}` 占位符；未含 `{prompt}` 时整串作 shell 命令亦可（Windows：`cmd /c` 或拆词）。
2. 实际实现：将模板中的 `{prompt}` 替换为 `task.task + "\n" + task.input` 的 JSON 字符串（`{input}` 单独时为 input 的 JSON），经 `@process.collect_output` 执行。
3. 拆词策略：简单空白分词 + 引号保留；`{prompt}`/`{input}` 先换成**无空白哨兵**再分词，回填后各占**单个 argv**。整串模板不含 `{prompt}` 时按普通 argv 直接执行（**不做**额外 shell 包装——调用方需 shell 语义时应显式写 `cmd.exe /c …`）。
4. 退出码 ≠ 0 → `raise Failure`（含 stderr 截断）；退出码 0 → 返回 `{simulated:false, exit_code, stdout_tail}`。
5. 未设置 env → 仍回退 `simulated_task`（保持既有语义）。

**`real_validation`**（`HARNESS_EVOLUTION_REAL_VALIDATION=true` 时）：

| 级 | 命令（cwd = `HARNESS_EVOLUTION_WORKDIR` 或当前目录） |
|----|-----------------------------------------------------|
| T0 | `moon check --deny-warn` |
| T1 | `moon test` |
| T2 | `pwsh -File build.ps1 -Task all`（**任意非 0** 再回落 `powershell -NoProfile -File …`，不只在「命令不存在」时） |

- 非 0 退出 → `(false, "Tn failed (exit N): …")`；0 → `(true, "Tn passed")`。
- 开关关闭 → 仍 `simulated_validation`。
- 超时：沿用 executor 的 `with_timeout_opt`（不另设）。

**装配**：`ServerState::with_scan_config` / `with_harness_config` 改为注入 `run_task=process_task, validate_level=real_validation`（二者内部按 env 自选真实/模拟），测试构造器可继续用默认模拟注入缝。

更新 X9/X10 回归：开关打开时**不再** expect “not implemented”，改为可测行为（真命令成功 / 假命令失败）。

### P3 面板验收与残留

- 跑 `dsh-evolution-panel` 的 `npm test`（typecheck + node --test）作为机器验收；记录结果。
- 面板 `dataGaps` fixture/文案与 P1 新语义对齐。
- `miniapps/harness-evolution-panel`：确认无引用后删除（已取消 MiniMax 打包）；若 panel package 仍引用则只改文档标注「已取消」。
- 更新 ROADMAP：P0–P3 状态。

### 版本

功能面 +2 工具 + 真实派发 → **3.2.0**（minor）：`moon.mod` 发布号 0.3.5、`package.json`、`.dsh-plugin/plugin.json`、`jsonrpc.server_version`、`SKILL` frontmatter、`DESIGN` 镜像。

## [S3] Out of Scope

- 不挂载 `dsh-watcher` 进程内桥、不改宿主源码。
- 不接通 `auto_approve`。
- 不改提案状态机 / patch 安装器行为（P0 只入库已有修复）。
- 不 push / 不开 PR（除非用户后续要求）。
- 不做跨平台预编译。

## Tasks

- [x] T1: P0 提交未跟踪回归网与复验报告并纠 DESIGN 文档 — acceptance: `git status` 无上述 untracked；DESIGN 无「启动时扫描」能力声明；安装器 7/7（covers: S2-P0）
- [x] T2: P1 新增 `record_tool_call`/`record_user_feedback` 工具与 schema/handler — acceptance: `tools/list` 16 个；两工具可写入 metrics/signals（covers: S2-P1; depends: T1）
- [x] T3: P1 同步清单/文档/data_gaps/面板文案/G5b — acceptance: 三方清单均 16；data_gaps 提到注入面（covers: S2-P1; depends: T2）
- [x] T4: P2 实现 `process_task` 真实执行 — acceptance: 配置 env 时执行真命令并按退出码成败；未配置回退模拟（covers: S2-P2; depends: T1）
- [x] T5: P2 实现 `real_validation` 三级真实验证 — acceptance: 开关开时 T0 跑 moon check；假 cwd 失败（covers: S2-P2; depends: T4）
- [x] T6: P2 生产装配注入 process/real + 更新 X9/X10 测试 — acceptance: ServerState 默认走 process/real 缝；测试改绿（covers: S2-P2; depends: T4 T5）
- [x] T7: P3 面板 npm test + 残留处理 + ROADMAP/CONTEXT 更新 — acceptance: panel 测试通过；残留有明确处置；ROADMAP 反映本切片（covers: S2-P3; depends: T3）
- [x] T8: 全门禁 + 版本 3.2.0 五处一致 — acceptance: build.ps1 -Task all 绿；版本号一致（covers: S2; depends: T1 T2 T3 T4 T5 T6 T7）
