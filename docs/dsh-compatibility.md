# DSH 插件兼容性：成功实践、兼容原理与路径收拢方法论

> 本文档沉淀 2026-09-17 对 `harness-self-evolution-plugin`（MoonBit 编译的原生 stdio MCP
> server，v2.6.0）与 DeepSeek Harness 0.1.6-alpha.1 的兼容性修复全过程，
> 并在 **2026-09-22 独立复验**后补入三处新接缝（§2.5–2.7）与一条阻塞缺陷的修复记录（§5.5）。
>
> 七部分：① 成功实践记录（2026-09-17 的三处接缝修复）；② 为什么兼容（DSH 底层契约，
> 含 2026-09-22 新增的启动成败分级 / 安装器产物合法性 / 包元数据声明性）；
> ③ 怎么做兼容（方法论与判据）；④ 路径收拢（DSH 单宿主）；
> ⑤ 实践记录二：把插件接进正在运行的 DSH（2026-09-18，多 home 现实与生效时机）；
> ⑥ 复验记录三（2026-09-22，安装器阻塞缺陷与两处文档失真）。
>
> 所有结论都有源码或实测依据，不靠文档假设。
>
> **机制说明书**：DSH 插件接入机制的完整解剖（host 半 / client 半双契约、产物硬契约、
> 故障诊断顺序）见 [dsh-plugin-integration.md](dsh-plugin-integration.md)。
> 本文的 §2.1–2.3 是当时（2026-09-17）的三处接缝，说明书里有更完整、更晚的版本。
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
2. **宿主目录模型修正**（ISSUE-03）：`src/store/paths.mbt` 把 DSH user 作用域目录从
   `~/.deepseek/harness/agents/` 改为 `<DSH home>/skills/`（现由 `dsh_agents_dir()`/`dsh_home()` 解析）；
   新增 `HARNESS_EVOLUTION_USER_DIR` 显式覆盖；扫描根 `~/.deepseek/harness/*` → `~/.dsh/profiles/`。
3. **元数据对齐**（ISSUE-02/04）：`engines` 键统一为 DSH 自己的 `engines.dsh`（`>=0.1.6`，
   `package.json` 与 `.dsh-plugin/plugin.json` 一致；见 §2.7），`files` 补上 exe 与配置；
   `plugin.json` 的 `scan_targets` 对齐。
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
| 端到端闭环 | 宿主内依次调 16 个工具（v3.1 时为 14；v3.2 起含注入面） | ✅ 见下 |

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
| `env` | dict | 覆盖子进程环境（这里显式转发 `DSH_HOME`） |
| `failOnStartupError` | bool | 握手/工具发现失败时**拒绝该插件激活**（一行 warning）；**不**中止 harness —— 见 §2.5 |

为什么 overlay 挂载能通、而标准路径崩：

- overlay（`scripts/_archive/_dsh_overlay_mcp.yml`，一次性探针，已归档）写的就是**正确的数组方言** +
  `failOnStartupError: true`，
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

### 2.5 接缝四：启动成败的**分级** —— 什么才是致命的（★ 2026-09-22 复验新增）

这是 2026-09-22 复验最值得沉淀的一条：**「插件不工作」与「宿主起不来」是两个量级，
它们的触发条件完全不同，而此前的文档把它们混为一谈。**

宿主的启动审计（`dsh-app-boot/lib/index.js::auditStartupEntries` :2509-2516）：

```js
const requiredStartupEntryIds = new Set([
  "agent-loop","webserver","modules","connection",
  "headless-runner","acp","sdk-jsonrpc-server" ]);        // :2408-2416

for (const failure of failures)
  (failure.entry === bootstrapIncludes.get(ctx)
   || requiredStartupEntryIds.has(failure.entry.options.id)
     ? required : optional).push(failure);                // :2513
if (optional.length > 0) warn(...);                       // :2514  ← 一行 warning
if (required.length > 0) throw ...;                       // :2515  ← 只有这里才致命
```

由此得到一张**必须记牢的分级表**：

| 失败 | 分级 | 实际后果 | 可观测证据 |
|---|---|---|---|
| MCP 握手 / 工具发现失败（`failOnStartupError: true`） | optional | 该插件不激活，**harness 照常启动** | stderr 一行 `warning: 1 entry did not activate` |
| `config.command` 指向不存在的文件（装错树） | optional | 同上：**插件静默不工作** | 同上 |
| 本插件被 `disabled: true`（出厂默认，未跑安装器） | 不算失败 | 不激活、无告警 | `--dump-config` 里该行 `disabled: true` |
| patch 层的 id 在树里不存在 | 未命中 | Loader 记一条 per-entry warning，不影响启动 | `--dump-config` 里没有该行 |
| **patch 层 YAML 解析失败** | **throw** | **profile 完全无法 boot** | `dsh: failed to parse patches <file>: YAMLException …` |
| `insert:` 的值写成映射 | **throw** | 同上（ISSUE-01） | `TypeError: patch.insert?.forEach is not a function` |

**为什么这条值得单独成节**：`failOnStartupError` 这个名字强烈暗示「启动失败开关」，但它的
作用域被宿主限制在**该 entry 的激活**上。据此推理出的「路径写错会打挂 profile」是错的，
而真正会打挂 profile 的那条路径（patch 层解析）反而被忽略了 —— 2026-09-22 复验发现的
阻塞缺陷（§4.1）恰好落在这个被忽略的盲区里。

> **可推广的纪律**：兼容性断言必须以**宿主对该字段的分类代码**为依据，而不是字段名的语义。
> 每写一条「X 会导致 Y」的断言，都要能指出宿主里做这个判断的那一行。

### 2.6 接缝五：安装器写的是「宿主必须能解析的文件」（★ 同上）

`scripts/install-dsh.ps1` 不是普通的便利脚本 —— 它写的是 **DSH 的 profile patch 层**，
而这个文件的解析失败是 `throw`（§2.5 最后两行）。所以它有一条**高于一切的不变量**：

> **产出的 YAML 必须是宿主 `parsePatchList` 能解析的。**

历史破口（已修，见 §4.1）正出在这里：DSH 为每个新 profile 生成的出厂模板逐字是
「三行注释 + 一行 `[]`」（`PROFILE_PATCH_TEMPLATE`，:480-484）。`[]` 是 **flow 序列**，
YAML 不允许同一层级上 flow 序列后接**块序列项**；旧代码把 `[]` 当「空文件」在其后追加
`- id: …`，于是**在默认状态下**写出了宿主无法 boot 的文件。

修法与判据：

| 面 | 内容 |
|---|---|
| 修法 | 写前先**整行删掉** `[]`（`Remove-EmptyFlowSequence`），再按「有无真实条目」决定追加还是直接接块 |
| 顺序纪律 | 分支**顺序即正确性**：`[]` 在 `Test-HasRealContent` 眼里是**真实内容**，所以必须先归一化再判定 |
| 写前守卫 | `Assert-PatchLayerShape` 拒写「仍有裸 `[]`」或「标记块不完整」的内容（宁可安装失败，也不打挂宿主） |
| 回归判据 | `scripts/test-install-dsh.ps1`（7 场景，临时树跑真实脚本）+ `scripts/test-patch-layer.mjs`（用宿主自己的 `js-yaml` 解析） |
| 卸载可逆 | `-Uninstall` 删块后若只剩注释，补回 `[]`，使文件与出厂态**逐字一致** |

> **维护提示（一次真实的踩坑）**：判「裸 `[]`」必须**逐行 `Trim()` 比较**，不能用
> PowerShell 的 `-match '(?m)^[ \t]*\[\][ \t]*$'`。`-match` 里 `$` 会匹配**输入末尾**，
> 而该文件恒以换行结尾 —— 于是该模式在末尾的空位置上恒成立，守卫会对**每一个合法产物**
> 误报（`Assert` 变 `Reject`，比没有守卫更糟）。同理，验证器里判「`[]` 非法」也必须
> 限定为「`[]` **之后还有内容**」：只有注释 + `[]` 是**完全合法**的 YAML。

### 2.7 接缝六：包元数据的**声明性**边界（★ 同上）

| 字段 | 真实地位 | 依据 |
|---|---|---|
| `dsh.bundle.patch` | **唯一**让包进入 profile 层栈的钥匙，宿主**真的读** | `dsh-app-boot` 的 `loadProfileDirectory` → `resolveBundleDir` |
| `engines.dsh` | **声明性**，宿主**不校验**。名字以 DSH 自己的 `DshEnginesManifest.dsh` 为准 | `@deepseek-ai/dsh-package-manifest/lib/types/types.d.ts:37-46`；其 README §91 明说「installers and loaders do not enforce … `engines.dsh`」 |
| `engines.deepseek-harness` | **不是**宿主定义的键名（只是 index signature 兜住的任意键） | 同上 |
| `.dsh-plugin/plugin.json` 整体 | 本插件**自用**的自描述文件，宿主不读 | 本插件 `src/` 自己解析 |

**纪律**：`engines` 统一写 `dsh`（本仓库 2026-09-22 已从 `deepseek-harness` 改齐），
并在文档里如实标注「声明性、宿主当前不校验」——**不要**把声明性字段描述成运行时契约。
这是 §2.5 那条纪律的另一个面：**名字不等于行为**。

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
3. **强判据替代弱判据**：`failOnStartupError: true` 把握手/工具发现纳入启动诊断
   （不依赖「模型回合能否调起来」这种需要凭据的弱验证）。**但要注意它的作用域只有该 entry
   的激活**（§2.5）—— 把它当成「profile 启动开关」会得出反向结论。
4. **静态合成先于真实安装**：`--dump-config --patch <file>` 在**不污染 profile** 的前提下先证
   patch 合法（合成 exit 0 + 输出含目标行），再走 `dsh plugin add`。
5. **隔离 + 闭环**：数据目录用 `HARNESS_EVOLUTION_HOME` 隔离；安装/卸载用 `add`/`remove` 闭环，
   破坏性实验的归因靠 remove/re-add 对照。
6. **单一事实来源（词汇即文档）**：每个路径/命令/工具名 grep 可证；文档不描述不存在的能力，
   拿不准的如实标「待确认」而非编造。
7. **写宿主的文件，就用宿主的解析器当判据**（★ 2026-09-22 新增）：安装器写 patch 层，
   就用**宿主的 `js-yaml`**（而不是「看起来对」）验证产物，并把这条判据机器化成回归测试
   （§2.6）。「能解析」这件事只有解析器说了算。

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

# ②b 安装器的回归套件（★ 2026-09-22 新增；只写临时树，不碰任何真实 DSH 树）
pwsh -File scripts/test-install-dsh.ps1                    # 期望 "PASS: 7/7 scenarios"
#     它用宿主的 js-yaml 解析产物 —— 「能解析」只有解析器说了算（§2.6）

# ③ 真实安装闭环
dsh plugin --profile web add "<repo>"                     # exit 0
pwsh -File scripts/install-dsh.ps1 -Profile web            # 注入挂载行（先加 -DryRun 看将写入什么）
dsh --profile web --dump-config                            # exit 0，无崩溃；该行 disabled 为 false
# boot 新端口 → stderr 见 "[HarnessEvolution] Server started"
# 会话内 / 目录含 mcp__harness-evolution__* 14 工具

# ④ 端到端（宿主 Agent 直调）
scan_plugins → propose_evolution(带 signals) → approve_proposal → execute_evolution → list_proposals

# ⑤ 宿主目录硬判据
create_sub_agent(scope=user, name=...) → 文件落在 <DSH home>/skills/ 且宿主热发现为技能
#   （home 由 paths.mbt::dsh_home() 解析：$DSH_HOME → ~/.dsh；默认即 ~/.dsh/skills/。
#    宿主 spawn MCP 子进程时丢弃全部 DSH_*，故 $DSH_HOME 须由挂载行 env 显式转发）

# ⑥ 收尾还原
dsh plugin --profile web remove "@across2005/harness-self-evolution"
```

---

## 四、路径收拢（DSH 单宿主）

自 v3.0.0 起本插件只服务 DeepSeek Harness（DSH）单一宿主。历史上曾声明双宿主
（DSH + MiniMax Code），但 MiniMax Code 是本插件单方面声明、DSH 源码中不存在的
宿主概念，已砍除。剩下的原则不变：

**把「随部署变化的接缝」收拢成可枚举、可覆盖、可测试的单一来源，把与路径无关的内核彻底隔离。**

### 4.1 路径接缝（单一来源清单）

| 接缝 | DSH |
|------|-----|
| 用户级定义目录 | `<DSH home>/skills/`（skill 形式；`dsh_home()` 解析 `$DSH_HOME` → 安装路径推导 → `~/.dsh`） |
| 插件扫描根 | `@store.dsh_profiles_dir()` = `<DSH home>/profiles`（+ speculative `~/.agents/plugins`），与用户级目录**同源**；出厂清单不再设 `scan_targets`（它表达不了 `<DSH home>`） |
| 安装方式 | `scripts/install-dsh.ps1`（安装期按树注入挂载行）+ `cordis.patch.yml`（出厂行默认 `disabled: true`、零机器路径） |
| 子 Agent 载体 | skill（`SKILL.md`/`.md`，frontmatter `name`+`description`） |

关键观察：**内核（扫描/监控/提案/执行/状态机）与路径无关；只有「目录路径」和「落盘载体」需要收口。**

### 4.2 收拢策略：一处 fallback、一张 wire 表

代码里已落地的机制：

1. **`user_agents_dir()` 单一来源**（`src/store/paths.mbt`）：`HARNESS_EVOLUTION_USER_DIR` 覆盖，
   否则 `dsh_agents_dir()` —— 后者由 `dsh_home()` 解析 `<DSH home>`（镜像宿主 `resolveDshHome`
   的 `$DSH_HOME` → `~/.dsh` 两档）。于是「宿主的 home 不是 `~/.dsh`」这一现实有唯一收口点。
   自 v3.0.0 起 `host_agents_dir(host)` 与 `HARNESS_EVOLUTION_HOST` 多宿主分发已移除。
2. **`HARNESS_EVOLUTION_USER_DIR` 显式覆盖**：允许用户/测试直接指定 user 作用域目录，避免硬编码漂移。
   优先级：`USER_DIR` > `dsh_agents_dir()`。
3. **wire 表单一来源**（`src/types/wire_tables.mbt`）：一个字符串枚举只有一张 wire 表，
   「合法性列表」与「JSON 编解码」同源。

### 4.3 载体格式必须与宿主同构

本插件的 sub-agent 定义以 DSH skill 形式落盘，须满足宿主的 skill 契约，否则被静默忽略：
- frontmatter 必含 `name` + `description`；`name` 须过 DSH 的 `SKILL_NAME = /^[a-z0-9]+(?:-[a-z0-9]+)*$/`
  （本插件 `factory::validate_name` 与之等价，由 `factory_wbtest.mbt` 钉住）。
- 不写宿主拒收的 legacy invocation 键。

改路径时：编辑 `dsh_agents_dir()` / `dsh_home()`，同步 `default_scan_roots()` 与
`.dsh-plugin/plugin.json` 的 `scan_targets`；删/增用例后同步 `architecture_test.mbt` G5b 测试数锚点。

### 4.4 路径收拢的反模式（要避免的坑）

- **反模式 1：把路径差异散落到多处硬编码。** 修复前 `~/.deepseek/harness` 散落在
  `paths.mbt`、`scanner.mbt`、`agent_scope.mbt`、`tools.mbt`、`schema.mbt`、`plugin.json`、
  README 等十几处——改一处漏一处。正确做法是单一来源。
- **反模式 2：为「未来可能支持」的宿主预写路径而不验证。** 历史上对 MiniMax Code 的
  「已验证」声明正是如此——DSH 源码里没有这个宿主。每写一条宿主路径/兼容声明，都要先
  证明宿主真的读它。
- **反模式 3：把「未接线」呈现为「无活动」。** metrics/signals 链无生产调用方时，
  快照应如实点名 `data_gaps`，而不是返回空数组假装一切正常。

---

## 五、实践记录二：把插件接进正在运行的 DSH（2026-09-18）

### 5.1 现象与归因

现象：终端里 `dsh plugin add` + `--dump-config` + boot 全部通过，但用户正在使用的 GUI 里**看不到**
那 16 个工具（v3.1 时 14 个）。归因不是兼容性，而是**看的是另一棵树**——同一台机器上并存两棵 DSH home，互不可见：

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
4. 生效判据：会话内 16 个 `mcp__harness-evolution__*` 可调；`get_runtime_snapshot` 返回 `root`
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
3. **同一个 exe 可能被多个宿主实例同时拉起**：实测本机曾同时存在两个
   `harness-evolution.exe` 进程（一个由 DSH web host 拉起，一个由已移除的 MiniMax Code
   兼容路径拉起）。两者默认共用同一数据根——需要隔离时给各自设不同的
   `HARNESS_EVOLUTION_HOME`。（v3.0.0 起只剩 DSH 一条路径。）

### 5.4 判据纪律（本次新增）

「兼容性/部署结论」必须写明**在哪棵树、哪个 `DSH_HOME`** 上验证，以及**宿主是否已重启**。
否则同一台机器上「验证通过」与「用户看不见」可以同时为真——今早的坑正是判据少了一维。

---

### 5.5 复验记录三（2026-09-22）：一条被漏掉的致命路径

**复验结论**：协议层、传输层、工具面、构建层与 DSH 0.1.6-alpha.1 完全兼容，
v3.1 的路径可移植化设计在真实条件下端到端成立。但复验在**安装器**里发现一个阻塞缺陷。

| 项 | 内容 |
|---|---|
| 缺陷 | `install-dsh.ps1` 在**出厂空 patch 层**（注释 + `[]`）上把块序列项追加到 flow 序列之后 → 非法 YAML |
| 后果 | `parsePatchList` throw → **profile 完全无法 boot**（不只是插件不挂载） |
| 触发条件 | **默认状态**：`[]` + 注释正是 DSH 为每个新 profile 生成的模板 |
| 根因 | 把「`[]`」误判为「空文件」（`Test-HasRealContent` 里那句 `if ($t -eq '[]') { continue }`） |
| 修法 | 先整行删 `[]` 再判定追加/新建；加写前守卫；加 7 场景回归套件（§2.6） |

**同时更正的两处文档失真**（都是「名字 ≠ 行为」）：

1. `failOnStartupError: true` 被描述为「直接中止整个 profile 启动」——**过度声明**（§2.5）。
   真实语义是拒绝该插件激活、一行 warning。风险论证方向被写反了：
   路径写错只让插件静默不工作，而**真正打挂 profile 的是 patch 层解析失败**。
2. `engines` 两处键名不一致（`dsh` vs `deepseek-harness`），且被当作运行时契约（§2.7）。
   宿主**不校验**该字段；已统一为 `dsh` 并标注声明性。

> **给未来的维护者**：这两条更正的共同教训是 —— **兼容性文档最危险的错误不是遗漏，
> 而是把「声明性/局部性」的机制描述成「全局致命」的机制。** 它会让读者去防一个不存在的地雷，
> 同时无视真正的那一个。每写一条因果断言，都要能指出宿主里做这个判断的代码行。

---

## 六、结论

1. **兼容的本质是「与宿主的真实契约对齐」**，而契约藏在宿主的源码和真实行为里，不在文档里。
   本次三处接缝（patch 方言、mcp-client schema、宿主目录模型）逐一用源码核实 + 实机复现闭合；
   2026-09-22 复验又补上三处（启动成败分级、安装器产物合法性、包元数据声明性，见 §2.5–2.7）。
2. **原生二进制插件进 DSH 的正道是「桥梁插件 + stdio MCP」**：`dsh-mcp-client` 负责进程与
   工具注册，插件只需保证 patch 方言正确、config schema 合法、落盘目录真实。
3. **路径收拢靠「单一来源 + 穷尽枚举」**，而非把路径差异散落硬编码；
   DSH 目录解析集中在 `paths.mbt` 的 `dsh_home()` / `dsh_agents_dir()` 一处（v3.0.0 已移除多宿主抽象）。
4. **验证靠判据 + 闭环**：`--dump-config` 静态合成、`add`/`remove` 闭环、
   `create_sub_agent(scope=user)` 落盘 + 宿主热发现，三者合起来才是「真的兼容」。
   `failOnStartupError: true` 是**诊断开关**而非启动判据（§2.5）。
5. **「在哪棵树验证」是判据的一部分**：`DSH_HOME` 决定 boot 哪棵树，`dsh plugin add` 只作用于
   当前那棵；`bundles` 只在 boot 读取，装完必须重启 host。结论不写明树与环境，等于没写明环境。
6. **宿主自有机制不要越界操作**：`.dsh-module-fallback`（插件 peer 兜底解析树）不要递归、
   不要在卸载后手删；跨宿主共用一个 exe / 数据根时，用 `HARNESS_EVOLUTION_HOME` 显式隔离。
7. **写宿主的文件，就用宿主的解析器当判据**：安装器产出 patch 层，就由宿主的 `js-yaml`
   来判它合法与否，并把这条判据固化成回归测试（§2.6）。**名字、形状、直觉都不是判据。**

---

## 附：本次修复的关键文件与源码依据

| 类别 | 文件 | 关键位置 |
|------|------|----------|
| DSH patch 方言 | `dsh-app-boot/lib/index.js` | `anchorInsertedPluginNames` L2136-2144；`parsePatchList` L2158-2169（**throw 点**） |
| 出厂 patch 模板 | `dsh-app-boot/lib/index.js` | `PROFILE_PATCH_TEMPLATE` L480-484（注释 + `[]`） |
| 启动成败分级 | `dsh-app-boot/lib/index.js` | `requiredStartupEntryIds` L2408-2416；`auditStartupEntries` L2509-2516 |
| `dsh plugin add` 写入面 | `dsh/lib/plugin-*.js` | `reconcilePlugins` → `writeProfileManifest`（只改 profile `package.json`，**不碰** patch 层） |
| mcp-client schema | `dsh-mcp-client/lib/index.js` | zod Config L780-800；`SERVER_NAME_PATTERN` L767 |
| DSH home | `dsh-home-paths/lib/index.js` | `DSH_HOME_DIR_NAME=".dsh"` L11 |
| skill 发现 | `dsh-skill-filesystem/lib/index.js` | roots L150-188；`SKILL_NAME` L17（dsh-skill） |
| 包元数据契约 | `dsh-package-manifest/lib/types/types.d.ts` | `DshBundleManifest.patch` L48-51、`DshEnginesManifest.dsh` L37-46；README L91「不校验」 |
| `!!js` 求值 | `cordis-plugin-loader/lib/index.js` | `evaluate = new Function("ctx","expr",...)` L289-293 |
| 插件宿主目录 | 本项目 `src/store/paths.mbt` | `user_agents_dir` / `dsh_agents_dir` |
| 扫描根 | 本项目 `src/scanner/scanner.mbt` | `default_scan_roots` |
| 挂载行 | 本项目 `cordis.patch.yml` | `insert: [{id, name, config}]` |
| 安装器 | 本项目 `scripts/install-dsh.ps1` | 分支顺序 §4、`Remove-EmptyFlowSequence`、`Assert-PatchLayerShape` |
| 安装器回归 | 本项目 `scripts/test-install-dsh.ps1` + `scripts/test-patch-layer.mjs` | 7 场景；用宿主 `js-yaml` 判合法 |

