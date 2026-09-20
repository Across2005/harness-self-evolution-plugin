# BUILD.md — 构建与接手总指南

> **面向对象**：接手本仓库的 Harness / Agent / 工程师。
> **阅读契约**：本文只描述「可复现的构建与验收事实」。任何地方与代码冲突时，**以代码为准**，并把偏差登记到 [§5 已知偏差](#5-已知偏差与陷阱接手者必读)。
> **写就时点**：产品 v2.6.0 / mooncakes 0.2.6；写就时实测工具链 moon `0.1.20260904`、Node `v26.4.0`、pnpm `12.3.4`。

---

## 0. 一分钟总览

本仓库包含**两个互相独立构建、独立安装**的单元：

| | 单元 A：MoonBit MCP 插件 | 单元 B：dsh-watcher 浮窗插件 |
|---|---|---|
| 位置 | `src/`（MoonBit） | `dsh-watcher/`（TypeScript + React） |
| 形态 | stdio JSON-RPC **MCP server**（native 可执行文件） | DSH Web **client 插件**（会话标题栏浮窗，含"模型阶段/可见推理"展示） |
| 构建 | `.\build.ps1 all`（PowerShell） | `npm run build`（需 DSH checkout 符号链接依赖） |
| 产物 | `bin\harness-evolution.exe` | `lib/dsh-watcher.js`（Host 侧）+ `lib/client.js`（浏览器侧） |
| 宿主注册 | `package.json`（`dsh.bundle` → `cordis.patch.yml`）+ `.dsh-plugin/plugin.json`（自述清单/配置载体） | `dsh-watcher/cordis.yml`（`kind: client`，`profile: web`） |
| 运行依赖 | MoonBit 工具链仅构建期需要；**运行期零 Node** | 运行期由 DSH Web Host 加载；Node 仅构建期需要 |

两者关系：**A 是被观察者，B 是观察者**。A 执行进化提案（`execute_evolution` 返回任务 DAG）；B 在 DSH Web 会话标题栏提供只读浮窗，实时展示执行步骤、模型思考过程（供应商公开的 reasoning）、工具调用与耗时。B 不依赖 A 的任何代码，可单独安装卸载。

---

## 1. 环境要求

| 工具 | 版本 | 用途 | 备注 |
|---|---|---|---|
| MoonBit 工具链 `moon` | `0.1.20260904`（实测通过） | 单元 A 编译/测试 | `build.ps1` 按 `$env:MOON_EXE` → `~\.moon\bin\moon.exe` → PATH 顺序锚定，**不要**依赖 PATH 上可能存在的旧版 moon（见 §5.4） |
| MSVC `cl.exe` + Windows SDK | VS 2019/2022/18 任一 + SDK 10.x | 单元 A native 链接 | 仅 Windows；`build.ps1` 自动探测并注入 `INCLUDE`/`LIB`/`PATH`（等价 `vcvars64.bat`，无需 cmd.exe） |
| Node.js | `^22.19.0 \|\| >=24` | 单元 B 构建/测试 | 本机实测 v26.4.0 可用 |
| npm（或 pnpm） | 随 Node | 单元 B 脚本 | `dsh-watcher/package.json` 的 scripts 用 npm 语法；DESIGN.md 里写的 `pnpm typecheck` 与 `npm run typecheck` 等价 |
| DSH CLI `dsh` | 生态 `0.1.2-rc.1` | 两个单元的插件安装 | `dsh plugin --profile web add/list/remove` |
| DSH 源码 checkout | `0.1.2-rc.1`（已构建） | 仅单元 B **从源码构建**时需要 | 判定标准：checkout 内存在 `tools/dshx/src/client-build.js` |

**本机（Windows）实测事实**：

- 仓库工作目录：`D:\Agent设计\harness-self-evolution-plugin`。
- 本机 DSH 运行时目录 `C:\Users\19207\.minimax\v2\plugin-data\local-minimax\dsh\runtime` 只有 `node_modules`（包名 `dsh-runtime` 0.0.0），**不是源码 checkout** —— 不能直接喂给 `link-harness-dependencies.mjs`。要从源码构建单元 B（含 `typecheck`/`test`），需另备一份 `0.1.2-rc.1` 源码 checkout。
- `dsh-watcher/lib/` 已包含**可安装的**预构建产物：`dsh-watcher.js`、`client.js`、`client.js.map`（注意：`lib/types/` 下的 d.ts 与 `dsh-watcher.js.map` 不在仓库里，需重新构建生成；这只影响 TS 类型消费，不影响安装运行）。`dsh-watcher/node_modules` **不存在**——没有 checkout 就无法跑 `typecheck`/`test`（devDeps 全部由 link 脚本从 checkout 符号链接而来）。

---

## 2. 单元 A：MoonBit MCP 插件

### 2.1 依赖与锁定

`moon.mod` 唯一外部依赖：`moonbitlang/async@0.20.1`（已 vendored 到 `.mooncakes/moonbitlang/async/`）。

> **为什么锁死 0.20.1**：async 0.21.x 起使用 `noraise + nocancel` 效果注解语法，moon `0.1.20260819` 解析报 `[3002] Parse error, unexpected token '+'`。当前工具链 `0.1.20260904` 已实测支持 `errdefer`（仓库错误路径清理已采用），但对 async 0.21.x 未复测，**维持锁定**；升级工具链并复测通过后方可放宽。

依赖已 vendored，常规构建**不需要联网拉取**。若 `.mooncakes/` 缺失，先执行 `moon update` 恢复。

### 2.2 构建命令（三级验证）

一切经由根目录 `build.ps1`：

| 命令 | 等价裸命令 | 验收标准 | 对应验证级 |
|---|---|---|---|
| `.\build.ps1 check` | `moon check --deny-warn --target native` | **零错零警**（任何新警告都算失败） | T0 语法 |
| `.\build.ps1 test` | `moon test --target native` | 全部用例通过（当前基线 443，以实际输出为准），内含架构守卫 G1–G7 | T1 功能 |
| `.\build.ps1 build` | `moon build --target native --release` + 产物复制 | 生成 `bin\harness-evolution.exe` | — |
| `.\build.ps1 all` | check → test → build 依次执行、逐步核对退出码 | 三步全绿 | T2 回归 |
| `.\build.ps1 fmt` | `moon fmt` | — | — |

> **写就时点实测**：本文档交付前在本机实跑了 `check` 与 `test`：T0 零错零警（`moon check --deny-warn --target native`，46 tasks）；T1 `Total tests: 434, passed: 434, failed: 0`。测试输出里的 `Parse error` / `OSError(...Incorrect function.)` 等行是**负向路径用例的预期日志**（store/monitor/mcp 的容错测试），不是失败。

产物落点：`_build\native\release\build\**\harness_evolution.exe` → 由脚本复制为 `bin\harness-evolution.exe`（**不要**手工去 `target\` 找，native 后端产物在 `_build\`）。

### 2.3 宿主注册与数据目录

- **宿主清单**：DSH 侧权威 manifest 是 `package.json` 的 `dsh.bundle`（→ `cordis.patch.yml`）；`.dsh-plugin/plugin.json` 是自述清单与运行时配置载体（`mcp.transport: stdio`、protocolVersion `2024-11-05`、`evolution_config`、`monitoring`）。**v3.1 起不再写 `scan_targets`**（该段只支持 `~/` 展开，表达不了 `<DSH home>`；出厂语义改为回落「随 `dsh_home()` 派生」的默认根）。
- **DSH bundle patch**：`cordis.patch.yml`（顶层 YAML 数组、`- insert:` 形式），是 **loader 挂载行**（`insert: [{id, name, config}]`，`name` = npm 包名），**不是** plugin.json 的元数据翻译——元数据只存在于 `package.json` 与 `.dsh-plugin/plugin.json`。**v3.1 起该行默认 `disabled: true` 且不含机器绝对路径**：由 `scripts/install-dsh.ps1` 在目标树上以 id 定向覆盖行启用并注入本树路径。
- **安装**（公开渠道）：
  ```sh
  dsh plugin --profile web add "github:Across2005/harness-self-evolution-plugin#v3.1.0"
  pwsh -File scripts/install-dsh.ps1 -Profile web     # 注入挂载行（按树解析路径）
  ```
  Linux/macOS 沙箱首次安装可能需要在宿主侧显式放行构建（`allowBuilds`）。
- **配置链**：`$HARNESS_EVOLUTION_CONFIG` → `<cwd>/.dsh-plugin/plugin.json` → `.dsh-plugin/plugin.json`（相对插件根兜底）→ 内置默认。`AGENTS.md` 不参与配置解析。**破坏性变更（v2.7.0，开发中）**：旧布局 `<cwd>/.zcode-plugin/plugin.json` 的回退已移除，该文件不再被读取；已部署实例需把它改名为 `.dsh-plugin/plugin.json`（内容无需改），否则其中的 `evolution_config` / `scan_targets` 静默失效、回落内置默认。
- **数据目录**：唯一 `~/.harness-evolution/v2/`（`$HARNESS_EVOLUTION_HOME` 可覆盖），内含 `plugin-cache.json` / `metrics.jsonl` / `signals.jsonl` / `proposals.jsonl` / `execution.log` / `execution.jsonl`（v2.7 结构化执行事件镜像，与 execution.log 同源双写）/ `sandbox/` / `agents/`。
- **宿主**：自 v3.0.0 起仅支持 DeepSeek Harness（DSH）单一宿主；多宿主开关 `HARNESS_EVOLUTION_HOST` 已移除，用户级目录可用 `HARNESS_EVOLUTION_USER_DIR` 显式覆盖。

### 2.4 修改禁区（架构不变量）

改代码前必读 `AGENTS.md` 与 `CONTEXT.md`。机器化守卫在 `src/mcp/architecture_test.mbt`（`moon test` 阶段变红即拒）：

| 守卫 | 约束 |
|---|---|
| G1/G1b | 包依赖图与声明完全一致，每条边严格向下（`util → types → store → scanner/monitor/planner → engine/executor/factory → mcp → harness_evolution`） |
| G2/G2b | `@stdio.stdout` 只在 `mcp/server.mbt`（**stdout 只承载协议字节**，日志只能走 `util/log.mbt` 的 stderr）；`@stdio.stderr` 只在 `util/log.mbt` |
| G3/G3b | `@fs` 写操作只在 `store/`（JSONL I/O 只存在于 `store/`） |
| G4/G4b | 数据目录字面量只在 `store/paths.mbt` |
| G5/G5b | 测试覆盖（含守卫自身的负向探针） |
| G6 | `moon.mod` 只有一个外部依赖，native 是首选目标 |
| G7 | 配置监听器在首轮轮询**之前**预置 mtime 基线（源码守卫；store 侧原语测不出「调用方真的预置了」，见 `src/store/config_watch.mbt` 注释） |

另注意：提案状态只能 `pending → approved → executing → completed`（或 `reject_proposal` → `rejected`）；审批必须人工（`auto_approve: true` 会被告警并回落 `false`，这是故意设计，不是缺陷）。

---

## 3. 单元 B：dsh-watcher（浮窗 / 思考过程插件）

### 3.1 它是什么

DSH Web 的**只读 client 插件**：会话标题栏"眼睛"按钮 → Portal 浮窗，把会话折成 `对话轮次 → 阶段 → 步骤 → 模型阶段/每次执行` 的工作图；其中"模型阶段"展示思考过程——`首响应等待 / 可见推理 / 输出·工具意图 / 重试·未归因` 四段时间分解 + 供应商公开 reasoning 正文（按尝试折叠，流式增长）。**只展示供应商写入会话的可见 reasoning，绝不补写、绝不把排队/网络延迟叫"思考"**（完整契约见 `dsh-watcher/DESIGN.md`）。

> **来源**：本目录是外部插件 [`aa2246740/dsh-watcher`](https://github.com/aa2246740/dsh-watcher) 的源码副本（MIT），为与单元 A 协同而纳入本仓库；只读，不修改任何会话数据。
>
> **与单元 A 协同使用**：`execute_evolution` 启动进化执行后打开浮窗，可 ① 实时观察任务 DAG 的执行路径与并行分布；② 用模型/工具/首 token 耗时定位瓶颈；③ 执行失败时经 Inspector 下钻到具体失败步骤的命令、退出码与原始证据。

双入口结构（由 `dsh-watcher/package.json` 的 `exports` 声明）：

- Host 侧 `lib/dsh-watcher.js`（入口 `src/dsh-watcher.ts`）：注册 `watcherInsights` 会话投影（`src/insights/projection.ts` + `engine.mjs`，只留耗时/token 统计，不留推理正文）。
- 浏览器侧 `lib/client.js`（入口 `src/client/index.tsx`）：slot 注入 + React 浮窗。

### 3.2 从源码构建

前置：一份**已构建完成的** DSH `0.1.2-rc.1` 源码 checkout（判定：存在 `tools/dshx/src/client-build.js`）。

```sh
cd dsh-watcher

# 1) 把 @deepseek-ai/* 官方包、react、tsdown 等以符号链接方式
#    指向 Harness checkout —— 不下载任何包、不改动 checkout
node scripts/link-harness-dependencies.mjs /path/to/harness

# 2) 构建（tsc 类型检查 + tsdown 打包，双入口 → lib/）
DSHX_HARNESS=/path/to/harness npm run build

# 3) 测试（tsc + node --test tests/*.test.mjs，含 golden-replay 回放）
npm test
```

可用脚本（`dsh-watcher/package.json`）：

| 脚本 | 作用 |
|---|---|
| `npm run build` | `tsc -p tsconfig.json && tsdown` → `lib/` |
| `npm run typecheck` | 仅类型检查（不产出） |
| `npm test` | `tsc` + `node --test tests/*.test.mjs` |

> **依赖来源的唯一路径是 link 脚本**：`dsh-watcher` 的 devDeps（`typescript`、`tsdown`、`react`、`@types/*`）和全部 `@deepseek-ai/*` peer 包都由 `link-harness-dependencies.mjs` 从 checkout **符号链接**进 `node_modules`——不执行它，`typecheck`/`test`/`build` 一条都跑不了（写就时点 `dsh-watcher/node_modules` 不存在），也没有 registry 安装的后备路径。

冷启动校验可用 `dshx start` / `dshx verify-boot`（走 `cordis.patch.yml`，**不要**用裸 pnpm/npm 直接拉起）。DESIGN.md 的质量门：`typecheck`、聚焦测试、`build`、`dshx check` 全过才可声明可用。

### 3.3 安装 / 更新 / 卸载 / 验证

```sh
# 安装（本地目录；或 github:aa2246740/dsh-watcher）
dsh plugin --profile web add ./dsh-watcher

# 卸载
dsh plugin --profile web remove dsh-watcher
```

- 安装后**重启 DSH Host，并刷新页面一次**（首次是 `new-client` 变更，boot 图需包含 Watcher）。
- **client-only 更新**（改了 `client/` 代码重新构建后）：走 existing-client HMR 分支，**无需重启 Host**，刷新页面即可；`cordis.yml` 的 `hotReload.artifacts` 列出参与热载的 Host 侧文件。
- 验证三步：
  1. `dsh plugin --profile web list` 中出现 `dsh-watcher`；
  2. Host 日志出现 marker：`[my-plugins/dsh-watcher] loaded`；
  3. Web 会话标题栏出现眼睛按钮（在 Session 日志之后、文件面板开关之前，order 50）。
- 交互约定、验收 quality gates 全文在 `dsh-watcher/DESIGN.md`（约 390 行，是本单元的**设计契约**，改动 UI 前必读）。

### 3.4 架构地图（浮窗如何展示思考过程）

数据流一行图：

```
Session 事件流（assistant/chunk·reasoning-delta 等）
  → ConversationNodeDefinition 折叠为每 Step 的 ModelStepTrace
  → foldSnapshot 折成工作图（轮次/阶段/步骤/执行）
  → Watcher.tsx Portal 浮窗渲染
  → ModelStage 组件：时间分解条 + 推理记录（MarkdownText）
```

| 层 | 文件 | 职责 |
|---|---|---|
| 插件声明 | `dsh-watcher/cordis.yml`、`dshx.yml`、`package.json` | id/entry/kind:client/profile:web/hotReload；`dsh.client.inject` 声明依赖的官方 UI 包 |
| Host 入口 | `src/dsh-watcher.ts` | 注入 `sessionProjections`/`sessions`，装统计投影 |
| 统计投影 | `src/insights/projection.ts` + `engine.mjs` | `watcherInsights`（zod 校验、可重放折叠；设置页 Insights 数据源） |
| Client 入口 | `src/client/index.tsx` | 向 `conversation.session.header.utilities` slot（order 50）注入眼睛按钮；注册模型轨迹定义；设置页分区（order 85） |
| 思考数据折叠 | `src/client/model-trace-definition.ts` + `src/observation/model-trace.ts` | 把 `step/start`、`reasoning-delta`、`text-delta`、`tool-call-delta`、`usage`、`assistant/message`、`llm/retry`、`chunkrow/*` 归一化并按 Step 折成 `ModelStepTrace`（含逐片段推理时间戳、重试尝试链） |
| 工作图投影 | `src/observation/fold.ts` + `performance.ts` | 会话→轮次→阶段→步骤→执行的折叠与嵌套耗时（不把并行子项相加成总数） |
| 浮窗 UI | `src/client/Watcher.tsx`（约 1600 行） | `createPortal` 浮层 + `useAnchoredPosition` 锚定眼睛按钮 + Follow/折叠/逐项·归类/概览·详情 |
| 展开策略 | `src/client/disclosure-depth.ts` | 最新流式模型阶段默认展开；打开推理记录会钉住父级模型阶段 |
| 历史补全 | `src/hub/history.ts` | 打开面板时自动走 `session.loadOlder()` 分页拉全历史 |

改动的最小核对清单：改了 `model-trace.ts` 的折叠语义 → 必须同步 `tests/model-trace.test.mjs` 与 `tests/golden-replay.test.mjs`；改了 UI 结构 → 对照 DESIGN.md 的 Quality Gates 逐条自查（13/13/12px 字号下限、无 `循环` 误标、不跨轮次分组等）。

---

## 4. 接手清单（按序执行）

1. **验收现状**（先证明你拿到的基线是绿的，再动手）：
   - 单元 A：`.\build.ps1 all` → 三步全绿，`bin\harness-evolution.exe` 生成（写就时点 T0/T1 已实测全绿，见 §2.2）。
   - 单元 B：**有 checkout** → 按 §3.2 link 依赖后 `npm run typecheck && npm test`；**无 checkout** → 直接用预构建 `lib/` 走 §3.3 安装并验证 marker 与眼睛按钮（跳过 typecheck/test，并在交接记录里注明验证级别）。
2. **读契约**：根 `AGENTS.md`（角色边界）→ `CONTEXT.md`（词汇表/守卫/配置来源）→ 改 A 看 `DESIGN.md`；改 B 看 `dsh-watcher/DESIGN.md`。
3. **改代码**：遵守 §2.4 架构不变量；A 侧任何变更跑三级验证，B 侧跑 §3.2 三条命令。
4. **文档同步**：工具数量、用例数、默认值等数字改后逐字核对；发现新偏差登记进 §5。
5. **发布核对**：产品版本（`package.json`、`.dsh-plugin/plugin.json`）与 mooncakes 版本（`moon.mod`，`0.x` 线，0.2.6 ↔ v2.6.0）按既有先例解耦推进；`cordis.patch.yml` 已无 `version` 字段（挂载行方言），不再有版本漂移。

---

## 5. 已知偏差与陷阱（接手者必读）

写就时点逐项核实过的偏差与陷阱。**修掉一项就删一项，新增一项就补一项。**

1. **~~`cordis.patch.yml` 版本滞后~~（已修复）**：旧 patch 写 `version: "2.4.0"` 且整块是元数据映射（会触发 DSH `patch.insert?.forEach` 崩溃，ISSUE-01）。现改为挂载行方言（`insert: [{id, name, config}]`），不再携带版本/元数据，漂移随之消除。
2. **~~`DSH_INTEGRATION.md` 描述的 3 个 MCP 工具未注册~~（已修复）**：`get_execution_plan` / `report_task_result` / `finalize_execution` 从未注册，`DSH_INTEGRATION.md` 已重写为真实挂载方式与 14 工具清单。`execute_evolution` 是**自包含**工具（内部跑完 DAG，返回 `{success, proposal_id, results}`，**不**返回 `task_dag` 供宿主编排），不要假设上述 3 个工具存在，也不要假设「宿主 subagent() 编排 task DAG」。
3. **`record_tool_call` / `record_user_feedback` 是 monitor 内部 API**（`src/monitor/monitor.mbt`），**不是** MCP 工具；根 README「已知限制」一节所说的"无生产调用方"指的是这两个内部 API 的调用路径，不是注册工具。
4. **moon 多版本共存陷阱**：PATH 上可能并存旧版 moon（如 `0.1.20260713`，按旧布局找 `~/.moon/lib/runtime.c` 会直接报 `input ... runtime.c missing`）。`build.ps1` 已锚定 `~\.moon\bin\moon.exe` 并打印实际版本；绕过脚本裸跑 `moon` 时自行注意，必要时设 `MOON_EXE`。
5. **PowerShell「假红」陷阱**（`build.ps1` 内注释有完整分析）：moon 把进度信息写 stderr，PS 在 `$ErrorActionPreference='Stop'` 下会把成功运行也包成终止错误；`| Select-Object -First 1` 会提前终止管道、掐断原生进程造成非零退出码。复刻脚本行为时以 `$LASTEXITCODE` 为唯一成败依据。
6. **async 0.21.x 解析错误**：升级 `moonbitlang/async` 前见 §2.1；工具链升级后先复测 `moon check --deny-warn`。
7. **本机无 DSH 源码 checkout**：`dsh-watcher` 从源码构建需自备 `0.1.2-rc.1` checkout；否则用预构建 `lib/`。`link-harness-dependencies.mjs` 对 checkout 是**只读**的（符号链接），但要求路径里存在 `tools/dshx/src/client-build.js`。
8. **`moon check` 必须带 `--deny-warn --target native`**：任何新警告都算 T0 失败（Validator 约定），不要为了绿灯去掉 `--deny-warn`。

9. **HEAD 不是 fmt-clean**：当前工具链（moon 0.1.20260904）的 `moon fmt` 会重排全仓约 50 个未改动文件（换行样式、结构体字面量尾逗号等）——v2.6 提交时的「fmt 零 churn」结论对新工具链已失效。混跑 `moon fmt` 前先把功能 diff 提交干净，或事后回退无关 churn（v2.7 可视化首批即按此处理）；全仓统一格式化应单独走一个 `chore: fmt` 提交。
10. **~~`.dsh-plugin` 清单迁移进行中~~（迁移已完成；并列的待决项仍在）**：自述清单已从旧布局 `.zcode-plugin/plugin.json` 迁到 `.dsh-plugin/plugin.json`，且本版配置链**已删除旧路径回退**（破坏性，迁移动作见 §2.3：把旧文件改名为 `.dsh-plugin/plugin.json`），故「两个门牌并存」的中间态不复存在。另一件并列的事**仍未决**：移除 ZCode 相关形态后，插件清单形态由 6 种收敛为 **4 种**（`package.json` / `.claude-plugin/plugin.json` / `.mcp.json` / `SKILL.md`），而 scanner 依旧不识别本插件自己的门牌 `.dsh-plugin/plugin.json` —— **是否把它列为第 5 种形态仍需决策**；在决定前不要把「DSH 插件互见」当作既有能力。

> 文档整理记录：`dsh-watcher/QUICKSTART.md` 与 `dsh-watcher/INTEGRATION.md` 曾与 `dsh-watcher/README.md` 重复且携带未经验证的 `npm install` 构建路径，已在整理中删除；其唯一增量（来源说明与协同使用场景）并入本文 §3.1。

---

## 6. 文档索引

| 文档 | 用途 |
|---|---|
| [`README.md`](README.md) | 产品概述、安装、MCP 工具表（中英双语） |
| [`AGENTS.md`](AGENTS.md) | 五个协同 Agent 的职责边界与工作流（接手前必读） |
| [`CONTEXT.md`](CONTEXT.md) | 领域词汇表、设计上下文、缺陷清单、配置来源、架构守卫 |
| [`DESIGN.md`](DESIGN.md) | 单元 A 详细设计、模块边界、调用链 |
| [`DSH_INTEGRATION.md`](DSH_INTEGRATION.md) | DSH subagent 编排指南（注意 §5 偏差 2） |
| [`docs/subagent-factory.md`](docs/subagent-factory.md) | 子 Agent 工厂设计 |
| [`dsh-watcher/README.md`](dsh-watcher/README.md) | 单元 B 概述与安装（英文版 [`README.en.md`](dsh-watcher/README.en.md) 同步） |
| [`dsh-watcher/DESIGN.md`](dsh-watcher/DESIGN.md) | 单元 B 设计契约（浮窗交互、计时语义、quality gates） |

---

*本文由接手交接流程生成于 v2.6.0 基线；文中所有命令、路径、版本均按写就时点仓库实况逐项核实，其中单元 A 的 T0（`moon check --deny-warn`，零错零警）与 T1（434/434）已在本机实跑验证。*
