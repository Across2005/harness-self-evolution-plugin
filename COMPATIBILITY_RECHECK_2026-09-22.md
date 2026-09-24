# Harness Self-Evolution Plugin × DSH 兼容性复验报告

- **复验日期**：2026-09-22
- **被测仓库**：`D:\Agent设计\harness-self-evolution-plugin`（工作区脏：10 个文件未提交，见 §4）
- **产品版本**：v3.1.0（`package.json` / `.dsh-plugin/plugin.json` / MCP `serverInfo.version` 三方一致）
- **宿主**：DeepSeek Harness `@deepseek-ai/dsh@0.1.6-alpha.1`（runtime 位于 `C:\Users\19207\.minimax\v2\plugin-data\local-minimax\dsh\runtime`）
- **本会话宿主树（`DSH_HOME`）**：`C:\Users\19207\.dsh`（**与首版报告实测的 minimax `dsh-home` 树不是同一棵**）
- **工具链**：`moon 0.1.20260920`（feature flags `rr_moon_mod,rr_moon_pkg`）
- **本会话挂载状态**：本树**未安装**本插件（bundles 仅 `dsh-base`+`dsh-web-app`，patch 层为出厂空模板 `[]`，`profiles/node_modules/@across2005` 不存在，`skills/` 为空）——故本会话工具面中没有任何 `mcp__harness-evolution__*`

> 与首版 `COMPATIBILITY_TEST_REPORT.md` 的关系：首版结论建立在更早的宿主树与更早的提交上。
> 本报告是**独立复验**，不复用其结论，并在其声称「已修复」的 A 项修复路径里**发现一个新的阻塞级缺陷**。

---

## 一、结论摘要

| 维度 | 结论 | 证据 |
|---|---|---|
| MCP 协议 / 工具面 | ✅ PASS | §2.1 |
| **宿主真实传输挂载** | ✅ PASS | §2.2 |
| 出厂补丁被 DSH 正确合成 | ✅ PASS | §2.3 |
| 子进程环境清洗契约（`scrubbedParentEnv`） | ✅ PASS | §2.2 / §2.4 |
| v3.1「安装路径推导」第三档 | ✅ PASS | §2.5 |
| user-scope 写路径 ↔ DSH skill 发现格式 | ✅ PASS | §2.6 |
| T0 `moon check --deny-warn` | ✅ PASS | §3.1 |
| T1 `moon test` | ✅ PASS（453/453） | §3.2 |
| **安装器启用链路（目标树注入）** | ❌ **BLOCKER** | §4.1 |
| 文档对 `failOnStartupError` 的致命性断言 | ❌ 与宿主不符（过度声明） | §4.2 |
| 出厂二进制 ↔ 源码一致性 | ⚠️ 落后一个修订 | §4.3 |
| `engines` 声明 | ⚠️ 宿主不读取（纯元数据） | §4.4 |
| 仓库卫生（`scripts/`） | ⚠️ 10 个探针脚本入库 | §4.5 |

**总评：协议层、传输层、工具面、构建层与 DSH 0.1.6-alpha.1 完全兼容，且 v3.1 的路径可移植化设计在真实条件下端到端成立。
但「让插件真正挂上去」的那条安装链路存在一个可复现的阻塞缺陷：在出厂空 patch 层上运行安装器会写出非法 YAML，导致 DSH 拒绝启动该 profile。
该缺陷恰好命中当前用户树的默认状态。**

---

## 二、动态验证证据

### 2.1 二进制直连 MCP 握手（stdin JSON-RPC）

```
$init | .\bin\harness-evolution.exe
→ {"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05",
   "capabilities":{"tools":{}},"serverInfo":{"name":"harness-self-evolution","version":"3.1.0"}}}
```

`tools/list` 返回 **14 个工具**，与 `DSH_INTEGRATION.md`、`.dsh-plugin/plugin.json` 三方逐字一致：
`scan_plugins, get_plugin_metrics, propose_evolution, execute_evolution, list_proposals, approve_proposal,
reject_proposal, create_sub_agent, list_sub_agents, delete_sub_agent, analyze_plugins, evolve_plugin,
manage_sub_agent, get_runtime_snapshot`

当前源码重建产物（`_build\native\release\build\harness_evolution\harness_evolution.exe`）工具面同样为 **14 个**，名称集合一致。

启动日志（stderr，非 stdout —— 符合「stdout 只承载协议字节」不变量）：

```
[HarnessEvolution] Loaded config from <repo>/.dsh-plugin/plugin.json
[HarnessEvolution] Server started (data root: C:/Users/19207/.harness-evolution/v2, intensity: 50%, scan roots: 2, monitoring: true)
```

### 2.2 宿主真实传输挂载（最强证据）

不使用自建客户端，而用**宿主自己的**代码路径拉起插件：`@modelcontextprotocol/client@2.0.0` 的
`StdioClientTransport`（`dsh-mcp-client/lib/index.js` 第 40-45 行实际使用的传输类）+
`@deepseek-ai/dsh-subprocess` 的 `scrubbedParentEnv()`，环境按 `buildChildEnv()` 语义「清洗后再并入挂载行 env」：

```
child env DSH_* keys: ["DSH_HOME"]        ← 清洗丢弃全部 DSH_*，仅挂载行显式给的那一项存活
SPAWN+LIST OK
tools: 14
names: scan_plugins, get_plugin_metrics, propose_evolution, execute_evolution, ...
```

即：**DSH 的 spawn 路径能成功拉起本二进制并完成工具发现**。这是首版报告只靠「会话内调用」间接给出的结论，
本轮改为直接以宿主传输层代码复现。

> 该测试在 `workspace-write` 沙箱下会被 `spawn EPERM` 拦截（管道 stdio 子进程属已记录沙箱边界），
> 已按规程原地升级权限完成，未修改任何用户树文件。

### 2.3 出厂补丁被 DSH 正确合成（静态，不改用户树）

用 `--patch` 叠加层把仓库出厂 `cordis.patch.yml` 交给 DSH 自己的解析器（临时 `DSH_HOME`，零用户树写入）：

```
$ dsh --profile web --dump-config --patch <repo>/cordis.patch.yml
[exit=0]
  # == <repo>\cordis.patch.yml
  - id: mcp-harness-evolution
    name: '@deepseek-ai/dsh-mcp-client'
    disabled: true
    config:
      transport: stdio
      serverName: harness-evolution
      command: harness-evolution.exe
      args: []
      cwd: ''
      env: { DSH_HOME: '' }
      failOnStartupError: true
```

证实：`insert:` 数组 → 挂载行的展开语义正确（`patch.insert?.forEach`，`dsh-app-boot/lib/index.js:2142`），
且 v3.1「出厂 `disabled: true` + 零机器路径」的产物形态成立。

### 2.4 文档断言的逐条源码核对

| 插件文档的断言 | 宿主源码 | 判定 |
|---|---|---|
| `scrubbedParentEnv()` 丢弃全部 `DSH_*` | `dsh-subprocess/lib/index.js:50`，导出见 `:103` | ✅ |
| 挂载行 `env` 在清洗**之后**合并 | `dsh-mcp-client/lib/index.js:26-31` `buildChildEnv` = `{...scrubbedParentEnv(), ...extra}` | ✅ |
| `insert` 里塞映射会 `patch.insert?.forEach is not a function` | `dsh-app-boot/lib/index.js:2142` | ✅ |
| 工具公开名 `mcp__<serverName>__<rawName>` | `dsh-mcp-client/lib/index.js:56-60` | ✅ |
| `failOnStartupError: true` 会**直接中止整个 profile 启动** | 见 §4.2 | ❌ **过度声明** |
| DSH 无独立 agents 目录，user 定义以 skill 落盘 | `dsh-skill-filesystem/lib/index.js:172` = `join(dshHome,"skills")` | ✅ |
| DSH skill 解析器忽略未知 frontmatter 键（`color`/`tools`） | `parseSkillFile` 只取 `name`/`description`/`whenToUse`/`metadata`/两个 invocation 键，仅按名拒绝 legacy 键（`:660-705`、`:849-862`），无 unknown-key 校验 | ✅ |
| 扫描根随 `dsh_home()` 派生 | `default_scan_roots` 源自 `dsh_profiles_dir()` | ✅ |

### 2.5 v3.1「安装路径推导」（第三档）端到端实证

构造临时「已安装树」`<X>/profiles/web/node_modules/@across2005/harness-self-evolution`，
**剥离全部 `DSH_*`**、`cwd` 设为该安装位，再调 `create_sub_agent scope=user`：

```json
{"success": true,
 "path": "<X>/skills/compat-probe-tree.md",
 "scope": "user", "overwritten": false}
```

- 定义**落进被装上它的那棵树**，而不是 `~/.dsh/skills` —— 即 v3.1 新增的推导档在真实条件下成立；
- 真实 `~/.dsh/skills` 条目数保持 **0**（未被误写）。

产出文件与 DSH `dsh-skill-filesystem` 发现契约一致（扁平 `<name>.md`、`name`+`description` 齐备）：

```markdown
---
name: compat-probe-tree
description: DSH compatibility probe verifying install-path DSH home derivation
---

Probe definition created by the DSH compatibility test. Safe to delete.
```

> 宿主 README 明确：「A skill is either a directory bundle `<name>/SKILL.md` or a **flat file `<name>.md`
> at the top level of a scanned root**」→ 本插件的扁平落盘布局**可被发现**，`name` 的 kebab-case 约束也与
> 插件侧校验一致。

### 2.6 顺带观察到的加固

`create_sub_agent` 拒绝含 `": "` 的 `description`：

```
invalid sub-agent description: must not contain ": " (would be parsed as a second YAML mapping key)
```

这是针对 frontmatter 注入的正确防护（若放任，会污染 YAML 结构），实测有效。

---

## 三、构建与测试门禁

### 3.1 T0 — `moon check --deny-warn`

```
$ moon check --deny-warn --target native
moon: no work to do
[exit=0]
```

exit 0，零错零警。缓存为内容键，对应工作区**当前**源码（含未提交改动）；
`moon test` 随后实际编译并运行了全部用例，进一步佐证当前源码可编译。

### 3.2 T1 — `moon test`

```
$ moon test --target native
Total tests: 453, passed: 453, failed: 0.
[exit=0]
```

**453/453 全绿**，与首版报告的门禁数一致。

---

## 四、发现的问题

### 4.1 ❌ BLOCKER：`install-dsh.ps1` 在出厂空 patch 层上写出非法 YAML，DSH 拒绝启动该 profile

**位置**：`scripts/install-dsh.ps1` 第 208-209 行（`Test-HasRealContent` 为假的 else 分支）

```powershell
} else {
  $newContent = $existing.TrimEnd() + "`n" + $block + "`n"
}
```

`Test-HasRealContent()`（第 82-90 行）把 `[]` 与注释行一并视为「无实质内容」，于是该分支把
**块序列项直接追加在一个 flow 序列 `[]` 之后**：

```yaml
[]
# >>> mcp-harness-evolution (install-dsh.ps1) >>>
- id: mcp-harness-evolution
  ...
```

YAML 不允许同一层级上 flow 序列后接块序列项。**实测复现**（临时树，`-SkipPluginAdd`）：

```
$ dsh --profile web --dump-config
Error: dsh: failed to parse overlay <tree>\profiles\web\cordis.patch.yml:
  YAMLException: end of the stream or a document separator is expected (6:1)
   4 | []
   5 | # >>> mcp-harness-evolution (ins ...
   6 | - id: mcp-harness-evolution
-------^
    at parsePatchList (dsh-app-boot/lib/index.js:2163)
    at loadOverlayPatches (:2133) → loadProfileDirectory (:1029) → loadProfile (:1061)
[exit=1]
```

**为什么这是阻塞级**：`parsePatchList` 是 **throw**，异常一路上抛至 `prepareProfile` 并终止启动——
profile **完全无法 boot**，不只是「插件不挂载」。

**触发条件是默认状态**：`[]` + 注释正是 DSH 为每个新 profile 生成的出厂 patch 层模板。
**当前用户树 `C:\Users\19207\.dsh\profiles\web\cordis.patch.yml` 的内容逐字就是这个模板**，
且该目录里已存在 `cordis.patch.yml.bak-evo` / `package.json.bak-evo`（历史安装尝试的残留，对 DSH 无副作用）。
即：**在这台机器上直接执行文档给出的 `pwsh -File scripts/install-dsh.ps1 -Profile web`，会打挂 web profile 启动。**

**缺陷边界（已实测收窄）**：

| 分支（patch 层现状） | 产出 | DSH 解析 |
|---|---|---|
| 文件不存在 | 注释 + 块 | ✅ exit 0 |
| 已含本脚本标记块 | 替换块（幂等） | ✅ |
| 已含其它插件条目（如 `mcp-headroom`） | 追加块 | ✅ exit 0（实测） |
| **出厂空模板（注释 + `[]`）** | `[]` + 块 | ❌ **YAML 解析失败** |

**已验证的修法**：把 `[]` 行替换掉（而非在其后追加），其余不变——

```powershell
} else {
  # `[]` 是 flow 序列，后面不能再接块序列项 —— 必须整行替换，而不是追加
  $stripped = [regex]::Replace($existing, '(?m)^[ \t]*\[\][ \t]*\r?\n?', '')
  $newContent = $stripped.TrimEnd() + "`n" + $block + "`n"
}
```

实测：去掉 `[]` 行后 DSH `--dump-config` **exit 0**；再补上 bundle
（`dsh.profile.bundles` 含本插件）后，合成结果正是期望的启用行：

```
# == @across2005/harness-self-evolution, patched by <profile>\cordis.patch.yml
- id: mcp-harness-evolution
  name: '@deepseek-ai/dsh-mcp-client'
  disabled: false
  config:
    transport: stdio
    serverName: harness-evolution
    command: <profile>/node_modules/@across2005/harness-self-evolution/bin/harness-evolution.exe
    cwd:     <profile>/node_modules/@across2005/harness-self-evolution
    env: { DSH_HOME: <tree> }
    failOnStartupError: true
```

→ 出厂补丁 + 安装器覆盖行的**设计本身是对的**，坏的只是那一个分支。

**附带观察（次要，建议一并核对）**：安装器在第 141 行**先读取** patch 层内容，第 166 行才执行
`dsh plugin add`。若 `dsh plugin add` 会改写 patch 层，则第 4 步是基于陈旧内容写入。本轮的复现用了
`-SkipPluginAdd`，未验证该交错是否有害，但「先读后写」的顺序值得复核。

### 4.2 ❌ 文档过度声明：`failOnStartupError: true` 并不会中止 profile 启动

插件在三处（`cordis.patch.yml:17-18`、`README.md:68-72`、`DSH_INTEGRATION.md:33`）声明
「MCP 握手/工具发现失败时 DSH 启动**直接失败**／**直接中止整个 profile 启动**」，并把它作为
v3.1「出厂行必须 `disabled: true`」的**决策理由**。

宿主真实语义（`dsh-app-boot/lib/index.js`）：

```js
const requiredStartupEntryIds = new Set([
  "agent-loop","webserver","modules","connection","headless-runner","acp","sdk-jsonrpc-server"
]);                                                                    // :2408-2416

for (const failure of failures)
  (failure.entry === bootstrapIncludes.get(ctx) || requiredStartupEntryIds.has(failure.entry.options.id)
    ? required : optional).push(failure);                              // :2513
if (optional.length > 0) warn(activationDiagnostic(binName, "warning", optional));  // :2514
if (required.length > 0) throw ...;                                    // :2515
```

`mcp-harness-evolution` **不在** required 名单里 → 该条目的激活失败被归入 **optional** → 只打印一行
warning，**其余条目照常运行**。宿主自己的 README 也明说：
「Setting `failOnStartupError: true` rejects plugin activation; app-boot's startup policy still permits
an optional MCP entry to fail without aborting the harness.」（`dsh-mcp-client/README.md:71`）

**影响**：不影响协议兼容，但
1. 文档向读者承诺了一个不存在的严重后果；
2. 更重要的是——v3.1 的**风险论证方向反了**：路径写错只带来一行 warning + 该插件不挂载，
   而**真正会打挂 profile 启动**的是 §4.1 那个安装器分支（`parsePatchList` 是 throw）。
   决策结论（出厂不写死机器路径）依然正确，但理由需要按实际语义改写。

### 4.3 ⚠️ 出厂二进制落后源码一个修订

| 产物 | 大小 | mtime | SHA256 |
|---|---|---|---|
| `bin/harness-evolution.exe`（`package.json` `files` 里发布的那份） | 1,597,440 | 2026-09-20 19:12 | `96C17F0A…` |
| `_build\native\release\build\harness_evolution\harness_evolution.exe`（当前源码构建） | 1,596,928 | 2026-09-21 21:30 | `884DE34E…` |

- 两者 MCP 版本号均为 `3.1.0`、工具面均为 14 个，故 **协议行为无差异**；
- 但工作区源码最新改动时间为 2026-09-21 21:30（`src/store/exec_log.mbt`），**晚于**出厂二进制，
  即 `bin/` 里的发布产物**不对应仓库当前源码**；
- 刷新方式已存在：`.\build.ps1 -Task build`（第 174-181 行：`moon build --target native --release`
  后 `Copy-Item` 到 `bin\harness-evolution.exe`）。

本轮 §2.1–§2.5 的**动态测试对两个二进制都做了**：直连握手/`create_sub_agent` 用出厂二进制，
宿主传输挂载用出厂二进制，工具面对照与全新构建产物比对 —— 结论相同，故此差异**不影响本轮兼容性判定**，
但发布完整性上应闭合。

### 4.4 ⚠️ `engines` 声明未被宿主读取，且两处键名不一致

- 全量检索宿主 runtime 的 `@deepseek-ai/*` 库代码，**无任何读取 `pkg.engines` 的位置**；
  `dsh-app-boot` 亦无 `engines` 匹配。即 `engines.dsh` / `engines.deepseek-harness` 纯属元数据，
  不会被校验（0.1.6-alpha.1 上）。
- 两处名称还不一致：`package.json` 用 `"dsh"`，`.dsh-plugin/plugin.json` 用 `"deepseek-harness"`。
  当前无害，但若未来宿主开始校验，双写不一致会先绊到自己。建议统一为一个键名并在文档里如实标注
  「声明性、当前不被宿主校验」。

### 4.5 ⚠️ 仓库卫生：`scripts/` 下 10 个一次性探针脚本已入库

`git ls-files scripts` 显示这些被跟踪（非忽略）：

```
scripts/_dsh_compat_probe.mjs        scripts/_dsh_overlay_mcp.yml
scripts/_dsh_web_full_overlay.yml    scripts/_e2e_mcp_full.mjs   (20 KB)
scripts/_enable_skill_fs_overlay.yml scripts/_miniapp_call.mjs
scripts/_miniapp_locator.ps1         scripts/_miniapp_probe.ps1
scripts/_miniapp_smoke.mjs           scripts/_notice_probe.ps1
scripts/_run_real.mjs
```

它们是历次兼容测试的临时物，混在正式脚本（`install-dsh.ps1` / `replace-paths.ps1`）之间。
`package.json` 的 `files` 未包含 `scripts/`，故**不影响发布产物**，但会干扰阅读与后续维护。
同时仓库根目录还留有 `test_output.txt`、`项目申报书_v5.md` 等非代码文件（见 `git log` 的「清理根目录草稿」提交，
说明这类清理已进行过一次）。

### 4.6 未提交改动（工作区脏）

```
 M moon.mod                M src/engine/moon.pkg      M src/executor/moon.pkg
 M src/factory/moon.pkg    M src/mcp/moon.pkg         M src/monitor/moon.pkg
 M src/scanner/moon.pkg    M src/store/exec_log.mbt   M src/store/moon.pkg
 M src/types/moon.pkg
```

性质是**一次 MoonBit 工具链兼容迁移**（与 DSH 无关）：

- `moon.mod`：`version` 0.3.2 → 0.3.3，重写 `description`；
- 各 `moon.pkg` 新增 `warnings = "-implicit_impl_as_method"`，针对 moonc v0.10.14 新增的
  deprecation（`derive` 隐式方法提升）；
- `src/store/exec_log.mbt`：`record.to_json()` → `ToJson::to_json(record)`，改走 trait 形式以摆脱隐式提升。

T0/T1 在这份改动上全绿（§3），故**迁移本身是健康的**，但它尚未提交 —— 与 §4.3 的「发布二进制落后」
是同一件事的两面。

---

## 五、建议动作（按优先级）

1. **修 `install-dsh.ps1` 第 208-209 行**（§4.1，阻塞级）。修法已在 §4.1 给出并实证；
   同时为该分支补一条回归测试（「出厂空模板 → 产出可被 DSH 解析」）。
2. **在修好之前，不要在当前树跑安装器**：`C:\Users\19207\.dsh\profiles\web\cordis.patch.yml`
   正是触发态。若已误跑，把 `[]` 行加回（或删块）即可复原；`-Uninstall` 分支不受此缺陷影响。
3. **改写 `failOnStartupError` 的文档语义**（§4.2）：三处文案改为「拒绝该插件激活，只打印 warning，
   不中止 harness；真正致命的是 patch 层解析失败」。v3.1 的决策结论可保留，理由需重述。
4. **闭合发布产物**：`.\build.ps1 -Task build` 刷新 `bin/`，并提交 §4.6 的工具链迁移。
5. **统一 `engines` 键名**并标注「声明性、宿主当前不校验」（§4.4）。
6. **清理 `scripts/` 探针脚本**（§4.5），与既有的「清理根目录草稿」提交保持同一标准。

---

## 六、测试范围声明（本轮未覆盖）

- `approve_proposal → execute_evolution` 真实全链路（会实际改写代码），未执行；
  `evolve_plugin action=execute`、回滚验证同理未跑。
- 未在**本会话宿主树**做真实安装（会改动用户树）。宿主传输挂载测试用的是临时模拟树，
  且以宿主自身传输/清洗代码复现，非「会话内 14 工具可调」的直接观测。
- 未验证 `dsh plugin add` 与 patch 层写入的交错顺序（§4.1 附带观察），复现使用 `-SkipPluginAdd`。
- 未做 T2 之外的跨插件观测验证（`dsh-watcher` 在本树未挂载）。
- 沙箱说明：`spawn` 子进程测试与 `--dump-config`（会回写 profile 的 `cordis.yml`）在
  `workspace-write` 下分别被 `EPERM` 拦截；前者按规程升级权限完成，后者改用临时 `DSH_HOME` 完成，
  **未对用户真实 DSH 树做任何写入**（复验后 `~/.dsh/profiles/web/cordis.patch.yml` 与 `~/.dsh/skills` 均为原状）。