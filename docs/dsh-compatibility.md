# DSH 插件兼容性：成功实践、兼容原理与多平台方法论

> 本文档沉淀 2026-09-17 对 `harness-self-evolution-plugin`（MoonBit 编译的原生 stdio MCP
> server，v2.6.0）与 DeepSeek Harness 0.1.6-alpha.1 的兼容性修复全过程。
>
> 五部分：① 成功实践记录（2026-09-17 的三处接缝修复）；② 为什么兼容（DSH 底层契约）；
> ③ 怎么做兼容（方法论与判据）；④ 如何做多平台兼容（多宿主抽象设计）；
> ⑤ 实践记录二：把插件接进正在运行的 DSH（2026-09-18，多 home 现实与生效时机）。
>
> 所有结论都有源码或实测依据，不靠文档假设。
>
> **机制说明书**：DSH 插件接入机制的完整解剖（host 半 / client 半双契约、产物硬契约、
> 故障诊断顺序）见 [dsh-plugin-integration.md](dsh-plugin-integration.md)。
> 本文的 §2.1–2.3 是当时（2026-09-17）的三处接缝，说明书里有更完整、更晚（2026-09-18）的版本。
>
> **实践记录二（2026-09-18）**：把插件接进**正在运行**的 DSH——多 home 现实、作用域与生效时机、
> `.dsh-module-fallback` 陷阱，见 §五。

---

## 一、成功实践记录

### 1.1 起点：8 个问题

| # | 严重度 | 问题 | 根因（一句话） |
|---|--------|------|----------------|
| ISSUE-01 | P0 | `dsh plugin add` 后整个 profile 崩溃 | 根 `cordis.patch.yml` 把「元数据映射」塞进 `insert`，`patch.insert?.forEach` 抛 TypeError |
| ISSUE-02 | P1 | patch 与 plugin.json 元数据漂移 | patch 写 v2.4.0/10 工具，实际 v2.6.0/14 工具 |
| ISSUE-03 | P1 | 宿主目录模型错位 | 假设 `~/.deepseek/harness/**`，真实是 `~/.dsh/**` |
| ISSUE-04 | P1 | 能力模型与 README 承诺不符 | 文档虚构「subagent 三件套」等不存在的 DSH 能力 |
| ISSUE-05 | P2 | watcher/panel 两个 TS 子插件未测 | 从未参与实测 |
| ISSUE-06 | P2 | 观测侧事件名未验证 | Monitor 声称监听 Cordis 事件，实为 out-of-process 无法订阅 |
| ISSUE-07 | P3 | 端到端模型回合未验证 | 无 API 凭据 |
| ISSUE-08 | P3 | 环境与方法经验项 | 版本字段陈旧、产物时效、无图像输入等纪律 |

### 1.2 修复动作（对号入座）

1. **`cordis.patch.yml` 重写**（ISSUE-01/02）：从元数据映射改为 loader 挂载行方言——
   一条 `insert: [{id, name, config}]`，`name: '@deepseek-ai/dsh-mcp-client'`，config 含
   `transport/stdio、serverName/harness-evolution、command/cwd、failOnStartupError: true`。
2. **宿主目录模型修正**（ISSUE-03）：`src/store/paths.mbt` 的 `host_agents_dir` 把
   `deepseek-harness` 分支从 `~/.deepseek/harness/agents/` 改为 `~/.dsh/skills/`；新增
   `HARNESS_EVOLUTION_USER_DIR` 显式覆盖；扫描根 `~/.deepseek/harness/*` → `~/.dsh/profiles/`。
3. **元数据对齐**（ISSUE-02/04）：`package.json` 的 `engines.deepseek-harness` → `engines.dsh`
   （`>=0.1.6`），`files` 补上 exe 与配置；`plugin.json` 的 `scan_targets` 对齐。
4. **文档对齐**（ISSUE-04/06）：README / DSH_INTEGRATION / BUILD / CONTEXT / DESIGN / SKILL /
   docs 全部改为「14 工具 + 真实挂载方式 + 监控边界如实声明」，删除虚构的
   `get_execution_plan` / `report_task_result` / `finalize_execution` 三件套。
5. **回归测试同步**（ISSUE-03）：`store_wbtest.mbt` S6 网改断言并新增
   `HARNESS_EVOLUTION_USER_DIR` 覆盖用例；`architecture_test.mbt` G5b 守卫 432→434（S14 用例 + 验证矩阵用例）。

### 1.3 验证结果（全部机器可复现）

| 验证 | 命令/方法 | 结果 |
|------|-----------|------|
| T0 语法 | `moon check --deny-warn --target native` | ✅ 零警告 |
| T1/T2 | `moon test --target native` | ✅ 434/434（0 失败） |
| patch 静态合成 | `dsh --profile web --dump-config --patch cordis.patch.yml` | ✅ exit 0，合成 mcp-client 行 |
| 标准安装 | `dsh plugin add <repo>` → `--dump-config` → `remove` | ✅ 全程 exit 0，profile 还原 |
| 端到端闭环 | 宿主内依次调 14 个工具 | ✅ 见下 |

端到端闭环（在真实 DSH 宿主内直调 `mcp__harness-evolution__*`）：

```
scan_plugins          → 59 插件（含 ~/.dsh/profiles/ 命中的 dsh-profile-web）
propose_evolution     → 生成提案（带手动 strong 信号）
list_proposals        → pending
approve_proposal      → approved
execute_evolution     → 3 个 validator 任务 success
list_proposals        → completed（pending→approved→executing→completed 全流转）
create_sub_agent(user)→ 落到 ~/.dsh/skills/evo-compat-test.md
                       + DSH 宿主【当会话即热发现】为技能 evo-compat-test  ← ISSUE-03 唯一硬判据通过
delete_sub_agent(user)→ 清理成功
```

---

## 二、为什么兼容（DSH 0.1.6 底层契约）

兼容不是「碰巧能跑」，而是三处接缝与宿主的真实契约对齐。理解这三层，就能判断任何
DSH 插件的兼容性。

### 2.1 接缝一：patch 层 —— `cordis.patch.yml` 是「挂载操作行」，不是「元数据清单」

DSH 的配置树是 **Cordis loader + patch 分层** 模型：

- 每个 profile 是一个「空 entry list」：`cordis.yml` 内容就是 `[]`（`~/.dsh/profiles/web/cordis.yml`）。
- bundle（`dsh-base` / `dsh-web-app` 等）各自带一份 `cordis.patch.yml`，往空树上**插入行**。
- 用户层（profile 的 `cordis.patch.yml`）→ home 层（`$DSH_HOME/cordis.patch.yml`）→ `--patch` overlay 依次覆盖。

patch 文件的**真实方言**（`dsh-app-boot/lib/index.js`）：

```yaml
# 顶层必须是 YAML 数组；每个元素是 loader patch entry
- insert:                 # insert 的值必须是【挂载行数组】，不是映射
    - id: mcp-harness-evolution
      name: '@deepseek-ai/dsh-mcp-client'   # name = npm 包名，Loader 用它解析模块
      config: { ... }
```

三个硬事实：

1. **`name` 是 npm 包名**，由 Cordis Loader 解析（相对名会经 `anchorInsertedPluginNames`
   转 file URL；裸包名经 `bareModuleBaseUrl` 从 runtime 的 node_modules 解析）。
2. **`id` 是后续层的定位目标**——profile patch / `--patch` overlay 按 id 覆盖某行的 config 或 disable。
3. **崩溃点**：`dsh-app-boot/lib/index.js:2136-2144` 的 `anchorInsertedPluginNames` 对
   `patch.insert?.forEach(visit)` 迭代。若把 `{name, version, keywords, ...}` 这类**元数据映射**
   整块塞进 `insert`，`patch.insert` 是 object、没有 `forEach`，直接抛
   `TypeError: patch.insert?.forEach is not a function`。

> 教训：DSH 的 `cordis.patch.yml` **不是** package.json/plugin.json 的「翻译件」。元数据只属于
> `package.json` 与 `.dsh-plugin/plugin.json`；patch 只做「挂载哪个包、怎么配」这一件事。

### 2.2 接缝二：mcp-client 层 —— 原生 exe 靠「桥梁插件」进 DSH

本插件是 MoonBit 编译的**原生可执行文件**，不是 JS 模块，无法直接进 Cordis loader。
它进 DSH 的唯一正道是 `@deepseek-ai/dsh-mcp-client`——一个 Cordis 插件，负责 spawn
外部进程、经 stdio JSON-RPC 通信、把远端工具注册到 DSH 的 `ctx.tools`。

mcp-client 的 config 受 zod schema 约束（`dsh-mcp-client/lib/index.js:780-800`）：

| 字段 | 约束 | 说明 |
|------|------|------|
| `transport` | `"stdio"` \| `"streamable-http"` | stdio 才适合本地 exe |
| `serverName` | `/^[A-Za-z0-9_-]{1,32}$/` | **决定工具公开名** `mcp__<serverName>__<tool>` |
| `command` | 必填 string | 直接传给 MCP SDK spawn，**绝对路径最稳**（相对路径按 spawn 的 cwd 解析，不可控） |
| `cwd` | string | 子进程工作目录 |
| `env` | dict | 覆盖子进程环境（这里传 `HARNESS_EVOLUTION_HOST`） |
| `failOnStartupError` | bool | **强判据**：MCP 握手/工具发现失败 → DSH 启动直接失败 |

为什么 overlay 挂载能通、而标准路径崩：

- overlay（`_dsh_overlay_mcp.yml`）写的就是**正确的数组方言** + `failOnStartupError: true`，
  所以 `--dump-config --patch overlay` 合成成功、真实 boot 成功。
- 根 patch 是手写的历史遗留错误（元数据映射），所以 `dsh plugin add`（消费 bundle patch）崩。

这解释了报告里「同一个 exe，overlay 能起、add 就崩」的看似矛盾——**崩的不是 exe，是 patch 方言**。

### 2.3 接缝三：宿主数据层 —— 真实目录是 `~/.dsh`，且「没有用户级 agents 目录」

这是最隐蔽的一层错位。事实来源是宿主源码，不是插件自己的假设：

| 概念 | 真实路径/机制 | 源码依据 |
|------|---------------|----------|
| DSH home | `~/.dsh`（`DSH_HOME` 可覆盖） | `dsh-home-paths/lib/index.js:11` `DSH_HOME_DIR_NAME=".dsh"` |
| 插件挂载点 | `~/.dsh/profiles/<name>/node_modules/<pkg>`（pnpm link 成符号链接） | 实测 + `dsh plugin add` 写 `dsh.profile.bundles` + `dependencies` |
| 用户级技能根 | `~/.dsh/skills/`（rank 400）、`~/.agents/skills/`（rank 500） | `dsh-skill-filesystem/lib/index.js:150-188` |
| skill 格式 | `SKILL.md` 或扁平 `<name>.md`，frontmatter 需 `name`+`description`，正文即指令体；名 grammar `/^[a-z0-9]+(?:-[a-z0-9]+)*$/` | `dsh-skill/lib/index.js:17` |
| 「用户级 agents 目录」 | **不存在**。subagent 由 `subagent`/`subagent_fork` 工具进程内派发 | 全仓 grep 无此机制 |

关键结论：本插件的 user-scope「子 Agent 定义文件」（Markdown + YAML frontmatter + 指令体）
与 DSH 的 **skill** 是**同构**的（`name` + `description` frontmatter，正文即系统提示词），
且插件 `validate_name` 的 kebab-case 是 DSH skill 名 grammar 的**严格子集**。所以正确落点是
`~/.dsh/skills/<name>.md`，DSH 会在后续会话（甚至当会话，经 skill-filesystem 热监听）发现并加载。

### 2.4 为什么「端到端能通」—— 三处接缝的闭合

```
dsh plugin add ──► 写 dsh.profile.bundles + pnpm link（patch 层接缝 ① 闭合）
   └─► boot 时读 bundle 的 dsh.bundle.patch ──► insert mcp-client 行（① 正确方言）
         └─► mcp-client spawn exe（接缝 ② 闭合：serverName/command/failOnStartupError 合法）
               └─► exe 内 create_sub_agent(scope=user) 写 ~/.dsh/skills/（接缝 ③ 闭合）
                     └─► skill-filesystem 热发现 → 宿主可调用
```

---

## 三、怎么做兼容（方法论与判据）

### 3.1 核心原则：宿主的源码与真实行为是唯一事实来源

文档会过时、会夸大、会虚构。判断兼容的唯一可靠路径是**读宿主源码 + 实机复现**，且每一步
都留下可复现的证据（退出码、崩溃栈、关键日志行）。

本次用到的六条纪律：

1. **反证法定位方言**：仓库内正确的样例（`dsh-watcher/cordis.patch.yml` 的 `insert: [{id,name}]`）
   反证根 patch 是手写错误——不是方言本身模糊，是这份文件写错了。
2. **崩溃栈 → 源码 → 逐行确认**：从 `TypeError: patch.insert?.forEach` 定位到
   `dsh-app-boot/lib/index.js:2142`，确认 `insert` 必须数组。
3. **强判据替代弱判据**：`failOnStartupError: true` 让「MCP 握手 + 工具发现」成为启动成败的
   一部分——不依赖「模型回合能否调起来」这种需要凭据的弱验证。
4. **静态合成先于真实安装**：`--dump-config --patch <file>` 在**不污染 profile** 的前提下先证
   patch 合法（合成 exit 0 + 输出含目标行），再走 `dsh plugin add`。
5. **隔离 + 闭环**：数据目录用 `HARNESS_EVOLUTION_HOME` 隔离；安装/卸载用 `add`/`remove` 闭环，
   破坏性实验的归因靠 remove/re-add 对照。
6. **单一事实来源（词汇即文档）**：每个路径/命令/工具名 grep 可证；文档不描述不存在的能力，
   拿不准的如实标「待确认」而非编造。

### 3.2 三级验证（T0/T1/T2）作为「自动改代码失控」的闸门

- **T0 语法**：`moon check --deny-warn` 零错零警（任何新警告都算失败）。
- **T1 功能**：变更相关测试全绿，失败给出第一条失败用例名 + 断言差异。
- **T2 回归**：全量构建 + 测试 + 架构守卫（G1–G6 机器化卡死），确认旧功能无一回归。

本次实测教训：架构守卫 G5b 把测试数硬编码为 432，新增一条用例就会失败——**改代码必须同步
更新守卫的锚点**，否则「全绿」是假象。

### 3.3 兼容性验证的最小可复现配方（可直接套用）

```powershell
# ① 构建（产物时效必须核对：exe 晚于 src）
.\build.ps1 -Task all

# ② 静态合成（不落 profile，先证 patch 合法）
dsh --profile web --dump-config --patch cordis.patch.yml   # 期望 exit 0 且含 mcp-client 行

# ③ 真实安装闭环
dsh plugin --profile web add "<repo>"                     # exit 0
dsh --profile web --dump-config                            # exit 0，无崩溃
# boot 新端口 → stderr 见 "[HarnessEvolution] Server started"
# 会话内 / 目录含 mcp__harness-evolution__* 14 工具

# ④ 端到端（宿主 Agent 直调）
scan_plugins → propose_evolution(带 signals) → approve_proposal → execute_evolution → list_proposals

# ⑤ 宿主目录硬判据
create_sub_agent(scope=user, name=...) → 文件落在 ~/.dsh/skills/ 且宿主热发现为技能

# ⑥ 收尾还原
dsh plugin --profile web remove "@across2005/harness-self-evolution"
```

---

## 四、如何做多平台兼容（多宿主抽象设计）

本插件宣称支持 DeepSeek Harness / ZCode / Minimax Code 多宿主。多平台兼容的本质是：
**把「随宿主变化的接缝」收拢成可枚举、可覆盖、可测试的单一来源，把「与宿主无关的内核」彻底隔离。**

### 4.1 随宿主变化的接缝（差异清单）

| 接缝 | DeepSeek Harness | ZCode | Minimax Code |
|------|------------------|-------|--------------|
| 用户级定义目录 | `~/.dsh/skills/`（skill 形式） | `~/.zcode/agents/` | `~/.minimax/agents/` |
| 插件扫描根 | `~/.dsh/profiles/` | `~/.zcode/cli/plugins/`、`~/.zcode/skills/` | `~/.minimax/plugins/`、`~/.minimax/extensions/` |
| 安装方式 | `dsh plugin add` + `cordis.patch.yml`（mcp-client 挂载） | 自有 loader | 自有 loader |
| 子 Agent 载体 | skill（`SKILL.md`/`.md`） | agent `.md`（ZCode agent 格式） | agent `.md` |

关键观察：**内核（扫描/监控/提案/执行/状态机）与宿主无关；只有「目录路径」和「落盘载体」随宿主变。**

### 4.2 收拢策略：一个枚举、一张 wire 表、一处 fallback

本次已在代码里落地的三个机制：

1. **`host_agents_dir(host)` 单一来源**（`src/store/paths.mbt`）：`match host { "zcode" => ..., "minimax-code" => ..., "deepseek-harness" => ..., _ => None }`。
   新增宿主时编译器会在 match 穷尽处报错，逼实现者决定该宿主的目录。
2. **`HARNESS_EVOLUTION_HOST` 切换 + `HARNESS_EVOLUTION_USER_DIR` 显式覆盖**：
   前者按宿主名选目录，后者允许用户直接指定 user 作用域目录，避免再次硬编码漂移。
   优先级：`USER_DIR` > `HOST 推导` > 默认 DSH。
3. **wire 表单一来源**（`src/types/wire_tables.mbt`）：一个字符串枚举只有一张 wire 表，
   「合法性列表」与「JSON 编解码」同源，新增宿主枚举值只改一处。

### 4.3 新宿主接入 checklist（可操作的扩展协议）

接入第 N 个宿主时，按此清单逐项核对，缺一不可：

1. **核实该宿主的真实目录模型**（读宿主源码，不读文档）：
   - 用户级 agents/skill 定义目录在哪？载体格式是什么（`.md` frontmatter？`SKILL.md`？）？
   - 插件挂载点/扫描根在哪？
2. **改 `host_agents_dir`**：加一个 match 分支；同步更新 `unknown_host_warning` 的
   `Supported values` 文案。
3. **改扫描根**：`default_scan_roots()` + `.dsh-plugin/plugin.json` 的 `scan_targets` 按宿主列举。
4. **确认载体格式是否同构**：若该宿主的 agent 载体与 DSH skill 不同构（frontmatter 键名/结构不同），
   需要在 factory 的 render/parse 层按宿主分派（而不是复用同一 render）。
5. **补回归用例**：`store_wbtest.mbt` 加「该宿主 → 目录跟随」断言；`scan_targets_wbtest.mbt`
   加「该宿主扫描根」断言；`architecture_test.mbt` G5b 守卫同步测试数。
6. **文档对齐**：README 宿主目录表、SKILL 工具描述、`docs/` 各处的路径逐字核对。
7. **实机闭环**：install → dump-config/boot → 端到端最小闭环 → 目录硬判据 → remove。

### 4.4 多平台兼容的反模式（要避免的坑）

- **反模式 1：把宿主差异散落到多处硬编码。** 这次修复前，`~/.deepseek/harness` 散落在
  `paths.mbt`、`scanner.mbt`、`agent_scope.mbt`、`tools.mbt`、`schema.mbt`、`plugin.json`、
  README 等十几处——改一处漏一处。正确做法是单一来源 + 单一枚举。
- **反模式 2：默认为「最熟悉的宿主」。** 曾有版本把缺省从 DSH 改成 ZCode 以求对齐某处文档，
  造成行为漂移。默认宿主必须是声明的主宿主（DSH），其余经显式切换。
- **反模式 3：为「未来可能支持」的宿主预写路径而不验证。** `~/.deepseek/harness` 就是
  「想象中」的目录，实测不存在。每写一个宿主路径，都要先证明宿主真的读它。
- **反模式 4：把「未接线」呈现为「无活动」。** metrics/signals 链无生产调用方时，
  快照应如实点名 `data_gaps`，而不是返回空数组假装一切正常。

---

## 五、实践记录二：把插件接进正在运行的 DSH（2026-09-18）

### 5.1 现象与归因

现象：终端里 `dsh plugin add` + `--dump-config` + boot 全部通过，但用户正在使用的 GUI 里**看不到**
那 14 个工具。归因不是兼容性，而是**看的是另一棵树**——同一台机器上并存两棵 DSH home，互不可见：

| home | 谁在用 | 当日证据 |
|---|---|---|
| `~/.dsh`（默认） | 用户 CLI 裸跑 `dsh web` | 工作会话 `session-ff44ddd0` 的 `createdAt=06:47:11`；08:32 的 `plugin add` 落在这里；`cordis.yml` boot 标记 10:13:44 |
| `<pluginData>\dsh-home`（托管） | 当前 GUI | 该 GUI 会话 `createdAt=09:15:12`；`bundles` 只有 base + web-app，从未装过本插件 |

一条命令定性：用**宿主那棵树**的 `DSH_HOME` 跑 `dsh --profile web --dump-config`，看有没有
`mcp-harness-evolution` mount row；再看宿主进程下有没有插件子进程。
**「我装好了」与「这棵树里有」是两件事。**

### 5.2 迁移步骤（清理旧树 + 装进新树）

1. 旧树：`dsh plugin --profile web remove <pkg>`（pnpm 转发 + 按已安装状态对账 `bundles`），
   再清掉 pnpm 留下的 `node_modules` 软链。
2. 新树：分两步 `add`（插件 → `--dump-config` 校验 → 面板 → 再校验），每步必须 exit 0；
   面板若破坏合成立即 `remove` 回退（本次未触发）。
3. **重启 host** 才生效——`bundles` 只在 boot 时读取（见 5.3）。
4. 生效判据：会话内 14 个 `mcp__harness-evolution__*` 可调；`get_runtime_snapshot` 返回 `root`
   与 `data_gaps`（本机实测数据根 `~/.harness-evolution/v2`，缓存 61 个插件）。
5. 装之前先在**隔离 DSH_HOME** 里预演一遍（含 `--store-dir` 指到工作区内、真 boot 到备用端口），
   确认「插件 + 面板」这个组合能 boot，再动宿主正用的那棵树。

### 5.3 三条硬知识

1. **作用域与生效时机**：`dsh plugin add` 只改**当前 `DSH_HOME`** 那棵树；`patchReload: "live"`
   管的是树内配置变更，**不会**把新增 bundle 挂上去。实测：`dump-config` 绿但宿主未重启 → 会话内
   无工具；重启后即刻可用。
2. **`.dsh-module-fallback` 是宿主机制**：它为插件的 peer 依赖做兜底解析，profile 侧用 junction
   指向它。三条纪律：不要递归遍历（会跟进 peer 树直到挂起）；插件卸载后不要手删其内容
   （profile 侧 junction 会悬空）；清悬空链接用 `rmdir`（删链不删目标），不要 `Remove-Item -Recurse`。
3. **同一个 exe 可能被多个宿主同时拉起**：实测本机 `harness-evolution.exe` 同时存在两个进程，
   父进程分别是 DSH web host 与 Minimax Code 应用（后者经 `~/.minimax/plugins/harness-evolution/`
   的 `mcp.json` + `scripts/launch.cjs` shim 拉起，`HARNESS_EVOLUTION_HOST=minimax-code`）。
   两者默认共用同一数据根——需要隔离时给各自设不同的 `HARNESS_EVOLUTION_HOME`。

### 5.4 判据纪律（本次新增）

「兼容性/部署结论」必须写明**在哪棵树、哪个 `DSH_HOME`** 上验证，以及**宿主是否已重启**。
否则同一台机器上「验证通过」与「用户看不见」可以同时为真——今早的坑正是判据少了一维。

---

## 六、结论

1. **兼容的本质是「与宿主的真实契约对齐」**，而契约藏在宿主的源码和真实行为里，不在文档里。
   本次三处接缝（patch 方言、mcp-client schema、宿主目录模型）逐一用源码核实 + 实机复现闭合。
2. **原生二进制插件进 DSH 的正道是「桥梁插件 + stdio MCP」**：`dsh-mcp-client` 负责进程与
   工具注册，插件只需保证 patch 方言正确、config schema 合法、落盘目录真实。
3. **多平台兼容靠「差异收拢 + 单一来源 + 穷尽枚举」**，而非把宿主差异散落硬编码；
   新宿主接入是清单化、可测试的流程。
4. **验证靠强判据 + 闭环**：`failOnStartupError: true`、`--dump-config` 静态合成、
   `add`/`remove` 闭环、`create_sub_agent(scope=user)` 落盘 + 宿主热发现，四者合起来才是
   「真的兼容」，缺一不可。
5. **「在哪棵树验证」是判据的一部分**：`DSH_HOME` 决定 boot 哪棵树，`dsh plugin add` 只作用于
   当前那棵；`bundles` 只在 boot 读取，装完必须重启 host。结论不写明树与环境，等于没写明环境。
6. **宿主自有机制不要越界操作**：`.dsh-module-fallback`（插件 peer 兜底解析树）不要递归、
   不要在卸载后手删；跨宿主共用一个 exe / 数据根时，用 `HARNESS_EVOLUTION_HOME` 显式隔离。

---

## 附：本次修复的关键文件与源码依据

| 类别 | 文件 | 关键位置 |
|------|------|----------|
| DSH patch 方言 | `dsh-app-boot/lib/index.js` | `anchorInsertedPluginNames` L2136-2144；`parsePatchList` L2158-2169 |
| mcp-client schema | `dsh-mcp-client/lib/index.js` | zod Config L780-800；`SERVER_NAME_PATTERN` L767 |
| DSH home | `dsh-home-paths/lib/index.js` | `DSH_HOME_DIR_NAME=".dsh"` L11 |
| skill 发现 | `dsh-skill-filesystem/lib/index.js` | roots L150-188；`SKILL_NAME` L17（dsh-skill） |
| 包元数据契约 | `dsh-package-manifest/lib/types/types.d.ts` | `DshBundleManifest.patch`、`DshEnginesManifest.dsh` |
| `!!js` 求值 | `cordis-plugin-loader/lib/index.js` | `evaluate = new Function("ctx","expr",...)` L289-293 |
| 插件宿主目录 | 本项目 `src/store/paths.mbt` | `host_agents_dir` / `user_agents_dir` |
| 扫描根 | 本项目 `src/scanner/scanner.mbt` | `default_scan_roots` |
| 挂载行 | 本项目 `cordis.patch.yml` | `insert: [{id, name, config}]` |
