# DSH 插件接入机制说明书

> **定位**：回答"DeepSeek Harness 接入一个插件，到底是什么逻辑"。
> **读者**：给 DSH 写插件的作者、排查 DSH 页面故障的维护者、需要读懂本仓库 DSH 分支的宿主 Agent。
> **实证基线**：DSH `0.1.6-alpha.1`（web profile），2026-09-18。所有结论取自 DSH runtime 源码、官方产物样例与浏览器/服务端对照实验；未实证的推断均已显式标注。
> **关联文档**：[dsh-compatibility.md](dsh-compatibility.md)（本仓库的兼容修复档案）、[deploy/deepseek-harness.md](deploy/deepseek-harness.md)（部署步骤）、[code-architecture.md](code-architecture.md)（本仓库分路径加载架构）。

---

## 0. 一页速查

**DSH 没有"一种插件"。一个插件包最多有四张脸，各自独立接入：**

| # | 面 | 接入方式 | 宿主侧落点 | 失败后果 |
|---|---|---|---|---|
| ① | **host 半**（Node 代码） | `package.json` 的 `dsh.bundle.patch` → 自己的 `cordis.patch.yml` | Loader entry → fiber | 该 entry 不激活（日志警告）；required id 失败则整进程退出 |
| ② | **client 半**（浏览器代码） | `package.json` 的 `dsh.client` + `exports["./client"]` | 产物拼进 `/plugins/??…` combo | **整条 combo 解析失败 → 同 combo 全部插件一起崩** |
| ③ | **MCP 桥**（外部进程） | patch 里 `insert` 一行 `@deepseek-ai/dsh-mcp-client` 配置 | stdio 子进程 + 工具表 | 该行不激活（`failOnStartupError: true` 时亦然）；**只有** `requiredStartupEntryIds` 里的 id 失败才整进程退出 |
| ④ | **纯声明**（无代码） | profile 的 `cordis.patch.yml` 或 `--patch` overlay | 直接改 entry 树 | patch 未命中会 warn；文件格式错则 boot 失败 |

**三条最容易踩的硬规则**（各对应一次真实事故）：

1. `insert:` 的值必须是**挂载行数组** `[{id, name, config?}]`——写成元数据映射会让整个 profile 崩（`patch.insert?.forEach is not a function`）。
2. client 产物必须是 **Lazy-CJS 工厂**，**禁止任何顶层 `import`/`export`**——一处违规连坐同 combo 全部插件（实测 56 个）。
3. `--patch` **只接受单文件**且可重复传；逗号分隔多文件会被当成一个路径直接 ENOENT。

**诊断第一原则**：host 半与 client 半的失败**互不通知**。服务端日志正常、MCP 已启动，页面照样可能整页崩。**先看浏览器 console，再谈服务端。**

---

## 1. host 半：四层叠加的 Loader 树

### 1.1 声明

```jsonc
// 插件包 package.json
{
  "name": "my-dsh-plugin",
  "dsh": {
    "manifestVersion": 1,                       // 可选，清单格式版本（当前为 1）
    "bundle": { "patch": "./cordis.patch.yml" } // ★ 声明"我是 profile 的一层"
  },
  "engines": { "dsh": ">=0.1.6" }               // 可选，作者声明的兼容范围
}
```

`dsh.bundle.patch` 是**唯一**让包进入 profile 层栈的钥匙。装了包但没这个字段，只会得到一条"installed as a plain dependency, not a profile layer"的 warning。

### 1.2 安装：`dsh plugin add` 是"pnpm 转发 + 事后对账"

```
dsh plugin --profile web add <spec>
  ├─ 首次使用：initProfile() 生成 profiles/web/{package.json, cordis.yml, cordis.patch.yml}
  ├─ 把相对路径 spec 按调用目录锚定（`add .` 不会自链 profile）
  ├─ spawnSync("pnpm", [...])，cwd = profile 目录
  └─ reconcilePlugins()：跑完后按"已装依赖里谁声明了 dsh.bundle"重写 dsh.profile.bundles
```

对账是**按已安装状态**而非依赖差异——所以 `update` 能让一个在新版本里才获得 `dsh.bundle` 的包自动入栈；反过来，依赖被移除或不再声明 bundle 的包会**自动出栈**。

> **本插件的挂载行不由 bundle patch 直接启用**（v3.1）：`cordis.patch.yml` 里的
> `mcp-harness-evolution` 行出厂 `disabled: true` 且不含机器路径 —— 静态字面量只对一台机器
> 成立，在别的机器上该插件会**静默不挂载**（一行 warning，宿主照常启动；见下「启动成败」）。
> `scripts/install-dsh.ps1` 负责在该树上写一条 **id 定向覆盖行**（`applyEntryPatches` 对
> id 命中者逐字段 `target[key] = value`，故覆盖行重述整个 `config`）到
> `<profile>/cordis.patch.yml`，即下面第 (2) 层。`dsh plugin add` 单独运行**不会**挂载工具。

### 1.3 合成：四层叠加

```
$DSH_HOME/profiles/<name>/package.json  →  dsh.profile.bundles: [bundleA, bundleB, …]
        │
        ├─(1) 逐 bundle：resolveBundleDir → readFile(pkg.dsh.bundle.patch) → 解析 patch list
        │        解析锚点顺序：安装锚点（dsh 包自身位置）→ profile 目录
        ├─(2) profile 自己的 cordis.patch.yml          （用户 tweak 层）
        ├─(3) $DSH_HOME/cordis.patch.yml               （home 级；优先级高于 profile 级）
        └─(4) CLI --patch <file>（可重复；overlay 层，最后应用）
        │
        ▼ applyEntryPatches：逐层合并
        ▼ mountRootInclude(cordis:include) → Loader 建 entry → 每 entry 一个 fiber
        ▼ auditStartupEntries：清点激活结果
```

**补丁语义**（`applyEntryPatches`，全树只此一处算法）：

| 写法 | 语义 |
|---|---|
| `- id: <target>` + 其它字段 | **整段替换**目标行的该字段（`config` 是整体替换，不是深度合并——要保留的字段必须重述） |
| `- id: <group>` + `insert: [...]` | 向该 group 追加子行 |
| `- insert: [...]`（无 id） | 向顶层追加行 |
| `name` 与目标不符 | 跳过并 warn（防误伤） |
| `id` 未命中 | warn，继续（不是错误） |

**注意**：`insert` 行的 `name` 若以 `./`、`../` 或绝对路径书写，会在解析时**转成 file URL 并按 patch 文件所在目录锚定**；包名保持字面量。

### 1.4 装配与失败语义

Loader 并发挂载所有 entry。启动审计（`auditStartupEntries`）在树稳定后清点：

| 失败模式 | 可选 entry | **required entry** | 说明 |
|---|---|---|---|
| 模块 import 失败 / 模块求值抛错 | warn，继续 | 停止启动 | `plugin tree failed to load` |
| 配置 schema 校验失败 | warn，继续 | 停止启动 | 新 entry 保持不激活 |
| `apply()` 同步/异步抛错 | warn，继续 | 停止启动 | 异步版在 settle 后报 |
| 注入的 service 不可用 | warn，等待依赖 | 停止启动 | 补上 provider 可激活 |
| `apply()` 之外产生 unhandled rejection | **致命**，无论 entry id | **致命** | 停进程并退出非零 |

**required 名单**（全局，与具体 profile 无关）：`agent-loop`、`webserver`、`modules`、`connection`、`headless-runner`、`acp`、`sdk-jsonrpc-server`。
**缺失或显式 disabled 的 required id 不影响启动**——只有"enabled 但激活失败"才算。

**`failOnStartupError: true` 到底管什么**（★ 2026-09-22 复验更正，此前文档过度声明为"中止整个 profile 启动"）：

```
auditStartupEntries(ctx, binName, warn)                      // dsh-app-boot/lib/index.js:2509
  ├─ requiredStartupEntryIds = { agent-loop, webserver, modules, connection,
  │                              headless-runner, acp, sdk-jsonrpc-server }   // :2408-2416
  ├─ 逐条失败分类：entry === bootstrapInclude || id ∈ required → required
  │                其余                                       → optional      // :2513
  ├─ optional 非空 → warn(一行 "N entries did not activate")                  // :2514
  └─ required 非空 → throw                                                    // :2515
```

`mcp-harness-evolution` 是 **optional**。因此：

| 情形 | 实际后果 |
|---|---|
| MCP 握手/工具发现失败（`failOnStartupError: true`） | 该插件**不激活** + 一行 warning；**其余条目照常运行**，harness 正常启动 |
| `config.command` 指向不存在的文件（换机器/换树的典型症状） | 同上：插件静默不工作，宿主照常起来 |
| **patch 层 YAML 解析失败** | `parsePatchList` **throw**（:2158-2163）→ 上抛 `prepareProfile` → **profile 完全无法 boot** |
| 该行 patch 的 `id` 在树里不存在 | 该 patch 未命中，Loader 记一条 per-entry warning，不影响启动（:2150-2151 的设计意图） |

> **教训（值得推广的纪律）**：把「声明性选项的名字」当成「行为的证据」是兼容性文档最常见的失真源。
> `failOnStartupError` 这个名字听起来像"启动失败开关"，但它的作用域被宿主限制在**该 entry 的激活**
> 上。写兼容性断言时，必须回到宿主的分类代码，而不是按字段名推理。

> **可操作判据**：如果你看到"**N entries did not activate**"且 N 是个大数，几乎不可能是"host 半某一处写错"——host 半的失败是**逐 entry 隔离**的。大数集体失败指向共享的公共依赖（见 §2 的 combo 连坐，或模块解析层断裂）。N 为 1 且点名 MCP 桥，就是本插件的挂载行没生效（查 `disabled`、`command` 路径、`DSH_HOME`）。

---

## 2. client 半：完全独立的第二套契约

### 2.1 声明

```jsonc
{
  "dsh": {
    "client": {
      "platform": "web",                  // 当前只有 web
      "inject": ["@deepseek-ai/dsh-client-ui-conversation", …],  // 依赖到达顺序（这些行的 factory 先注册）
      "external": ["some-non-baseline-pkg"]                       // 非基线模块请求（精确名）
    }
  },
  "exports": { "./client": { "default": "./lib/client.js" } }
}
```

### 2.2 合成与加载

```
host 半扫描 enabled Loader entries → 合成 boot graph → 注入 window.__DSH_BOOT__
      + 把各 client 产物按 combo 分组 → /plugins/??<id1>,<id2>…&rev=<hash>

浏览器：按 classic <script src> 逐条加载 combo（默认 loadBundle 实现）
      → 每条产物执行时只做一件事：注册工厂
        window.__ModuleLoader__.load({ id, factory })
      → 首次 import/materialize 时才真正执行 factory 体内的模块代码（CSS 注入也在此时）
```

combo 是**内容寻址**的（`rev` 为内容哈希）；HMR 时单行失效重取。同一 combo URL 的多个行共享一次在途 script 任务。

### 2.3 产物硬契约：Lazy-CJS 工厂

**正确形态**（与官方 59 个产物一致）：

```js
window.__ModuleLoader__.load({
	id: "my-dsh-plugin",
	factory: (require) => {
		var module = { exports: {} };
		var exports = module.exports;
		Object.defineProperty(exports, Symbol.toStringTag, { value: "Module" });
		let react = require("react");
		// …模块体…
		exports.apply = apply;
		exports.inject = inject;
		exports.name = name;
		return module.exports;
	}
});

//# sourceMappingURL=client.js.map
```

**禁止形态**（本仓库 2026-09-18 事故的原始产物）：

```js
// …rolldown 打包体…
export { apply, inject, name };   // ← 顶层 export：致命
```

契约来源：`dsh-client-modules/lib/types/client/manifest.d.ts` 的 `ClientBundleRegistration`，以及 `ClientModuleCreateOptions.loadBundle` 的默认实现（same-origin classic `<script src>`）。解析分支对表外内容**显式 panic**，且注释明确写着它是"build-time bundle purity gate"的运行时镜像。

**为什么一处违规会连坐**：combo 是**一整条脚本**。任一片段含顶层 `export`/`import`，整条脚本的**解析**（parser 阶段，早于执行）就失败——同 combo 的其余插件连"注册工厂"的机会都没有，于是集体报 `import failed`。**真凶只有那个新加的、格式不对的产物**，其余都是无辜受害者。

### 2.4 模块表：平台种子 + 声明式外置

- **平台种子（PLATFORM_MODULES）**：React、Cordis 及静态 UI 库。这些是**单例**——插件产物**不得内联**它们，必须 `require()` 取用。
- `dsh.client.external` 只登记**非基线的精确请求**，且必须与包名边（inject）对齐。
- 子路径归一：`<pkg>/client` 与裸包名解析到同一行（`stripClientSuffix`）——所以插件里写 `@deepseek-ai/xxx/client` 是安全惯例。

### 2.5 一个可直接复制的 tsdown 配置模板

```ts
import { defineConfig } from 'tsdown'

const CLIENT_ID = 'my-dsh-plugin'   // 必须等于 graph row id（= 包名）

const CLIENT_BANNER = [
  'window.__ModuleLoader__.load({',
  `\tid: ${JSON.stringify(CLIENT_ID)},`,
  '\tfactory: (require) => {',
  '\t\tvar module = { exports: {} };',
  '\t\tvar exports = module.exports;',
].join('\n') + '\n'

const CLIENT_FOOTER = '\t\treturn module.exports;\n\t}\n});\n'

export default defineConfig([
  {
    // host 半：普通 ESM，Node 侧 Loader 直接 import
    entry: { 'my-plugin': './src/plugin.ts' },
    format: 'esm', target: 'es2022', dts: true, sourcemap: true,
    outDir: './lib',
    clean: false,   // ★ 若构建脚本是 `tsc && tsdown`，clean 会连 tsc 的产出一起删
    outExtensions: () => ({ js: '.js', dts: '.d.ts' }),
  },
  {
    // client 半：classic script + Lazy-CJS 工厂
    entry: { client: './src/client/index.tsx' },
    format: 'cjs', target: 'es2022', dts: true, sourcemap: true,
    outDir: './lib', clean: false,
    banner: CLIENT_BANNER,
    footer: CLIENT_FOOTER,
    deps: {
      // 平台单例保持 external，绝不内联
      neverBundle: [/^react$/, /^react-dom$/, /^react\/jsx-runtime$/, /^@deepseek-ai\//],
    },
  },
])
```

构建产物的验收判据（可 grep，两条都过才算合格）：

```powershell
# ① 头部是工厂注册
Select-String -Path lib\client.js -Pattern '^window\.__ModuleLoader__\.load\(' -Quiet   # 期望 True
# ② 全文件零顶层 import/export
(Select-String -Path lib\client.js -Pattern '^(import|export)\s').Count                    # 期望 0
```

---

## 3. 宿主环境：`DSH_HOME` 决定 boot 哪棵树

DSH 的 profile 路径是 `$DSH_HOME/profiles/<name>`，`DSH_HOME` 解析优先级为：显式配置 > `$DSH_HOME` 环境变量 > `~/.dsh`。

**实测（同一台机器、同一 runtime、同一命令）**：

| 启动方 | `DSH_HOME` | 实际 profile 目录 | 内容 |
|---|---|---|---|
| 用户 CLI 裸跑 | 未设置 → `~/.dsh` | `~/.dsh/profiles/web` | 用户在用的那棵树（可能已装第三方 bundle） |
| Mavis 的 DSH 插件 | `<pluginData>/dsh-home` | `…/dsh-home/profiles/web` | 插件隔离树（干净的 base + web-app） |

**推论**：排查"为什么我装的插件在这个宿主里没生效"时，**第一步永远是确认 `DSH_HOME`**——同一个 DSH 二进制可能在使用完全不同的两棵 profile 树；两棵树的 `dsh.profile.bundles` 与 `node_modules` 互不影响。

> 附注：Mavis DSH 插件的 `status` 返回的 `install.version` 是它自己 state 里的值，不随手动升级更新——**真版本问 CLI**（`node <runtime>/…/dsh/lib/bin.js --version`）。

### 3.1 作用域与生效时机（2026-09-18 实机）

`dsh plugin --profile <name> add <pkg>` 只作用于**当前 `DSH_HOME` 的那棵树**：把包 pnpm 链接进
`$DSH_HOME/profiles/<name>`，再按「已安装状态」对账该 profile 的 `dsh.profile.bundles`（依据是被装包
`package.json` 里的 `dsh.bundle` 声明）。另一棵树的 `bundles` / `node_modules` 不会有任何变化——
**「我在终端里装好了」和「我正看的这个宿主里有」是两件事**。

生效时机是硬边界：

- `dsh.profile.bundles` **只在 boot 时读取**。`patchReload: "live"` 管的是树内配置变更的实时重载，
  **不会**因为 `bundles` 新增一项就把新 bundle 挂上去。
- 装完必须**重启该 host**（或等它下一次 boot）。判据两层，缺一不可：
  1. **静态**：用同一个 `DSH_HOME` 跑 `dsh --profile <name> --dump-config` → exit 0 且含目标 mount row；
  2. **动态**：宿主进程下出现插件子进程（如 `harness-evolution.exe` 的父进程 = 该 host 的 node 进程），
     且会话内能调到该 MCP server 的工具。
- 实测：`dump-config` 通过但宿主未重启时，会话内**看不到**工具；重启后工具即刻可用
  （2026-09-18，DSH 0.1.6-alpha.1，web profile）。

> 观测（非契约）：反复执行 `--dump-config` 会让 profile 根 `cordis.yml` 的 mtime 更新（内容恒为 `[]`）。
> 做「零污染」前后指纹对照时应排除它，或只比内容哈希。

### 3.2 `.dsh-module-fallback`：插件 peer 依赖的解析兜底

profile 目录下的 `.dsh-module-fallback/` 是宿主为**插件声明的 peer 依赖**准备的兜底解析树；profile 的
`node_modules` 里会出现指向它的 junction（实测：装带 `dsh.client` 的插件后出现
`node_modules/@deepseek-ai/<pkg>` → `.dsh-module-fallback/node_modules/@deepseek-ai/<pkg>`）。
它归宿主机制所有，三条纪律：

1. **不要对它递归**：`Get-ChildItem -Recurse` 会跟进 peer 树，实测直接把命令挂到超时。
2. **卸载插件后不要手工删它的内容**：profile 侧的 junction 会立刻变成悬空链接。
3. 清理悬空 junction 用 `rmdir`（`cmd /c rmdir "<link>"`，删链不删目标），**不要** `Remove-Item -Recurse`。

误删后的核对清单（三条都过才算没伤到东西）：宿主 runtime 的 `package-lock.json` 是否引用该包 ·
被依赖插件的 `node_modules` 包数前后是否一致 · 该树能否再次正常 boot。

---

## 4. 故障诊断：症状 → 判据 → 顺序

### 4.1 症状对照表

| 症状 | 最可能的层 | 判据/线索 |
|---|---|---|
| 页面："Failed to load plugins" + 一长串包名 | **client 半**（combo 解析失败） | 浏览器 console 里找 `SyntaxError` 及其 `url=/plugins/` 与行号 |
| 页面：底部持续"重新连接中." | host 半的 skill provider 缺失（web profile 默认 disable `skill-filesystem`） | 挂 `- id: skill-filesystem` + `config.includeDefaultRoots: true` 的 overlay 重试 |
| boot 抛 `patch.insert?.forEach is not a function` | patch 方言错 | `insert:` 的值必须是数组 |
| boot 抛 `duplicate loader entry id: X` | 同一 id 被两条路径挂载 | 常见于"profile 已装该 bundle"+"overlay 又注入同 id"；二者留一 |
| boot 抛 `failed to read overlay` + ENOENT | `--patch` 用法错 | 单文件。多文件写多个 `--patch`，**不要**逗号分隔 |
| `N entries did not activate`（N 很大） | 共享依赖层（client combo 连坐 / 模块解析断裂） | 先按 §4.2 顺序分诊 |
| MCP 工具不出现 | ③ MCP 桥 | patch 里有 `dsh-mcp-client` 行吗？该行 `disabled` 是不是 `true`？宿主 stderr 有无 `N entries did not activate` 的 warning？ |
| 插件"装了但没进层" | 声明缺失 | 包 `package.json` 有 `dsh.bundle` 吗？ |
| 终端里 `dump-config` 有该层，GUI/会话里却没有工具 | 看错了树 / 宿主未重启 | `$env:DSH_HOME` 与宿主是同一棵吗？宿主进程下有无插件子进程？`bundles` 只在 boot 读（§3.1） |
| 按上面排查都对，重启后仍无工具 | mount row 未真正生效 | 宿主 stderr 有无 `[HarnessEvolution] Server started`；有没有 `warning: 1 entry did not activate`（说明该行被拒绝激活） |

### 4.2 诊断顺序（不要跳步）

```
1. 确认 DSH_HOME 与实际 profile 目录（§3）      ← 先排除"看错树"
   └─ host 已在运行时：它 boot 的是同一棵树吗？装了 bundle 没重启 = 不会生效（§3.1）
2. 看浏览器 console（不是服务端日志）           ← client 半故障的唯一直接证据
   ├─ SyntaxError + /plugins/ → client 产物格式问题（§2.3）
   └─ 网络 4xx/5xx → 拉 /plugins/ 看服务端返回
3. 看服务端 boot 输出
   ├─ "[pkg] loaded" 齐全 → host 半没问题，别在服务端浪费时间
   └─ 有 entry 报错 → 按 §1.4 判定 required/可选
4. 用 --dump-config 做静态合成（不落 profile）   ← 验证 patch 合法性的最快手段
5. 零污染实验：--patch overlay + 隔离 DSH_HOME   ← 改动前先能还原
```

### 4.3 两个真实案例

**案例 A：patch 方言（P0）**——`cordis.patch.yml` 把元数据映射写进 `insert:`，`dsh plugin add` 后**整个 profile 崩溃**，堆栈落在 `dsh-app-boot/lib/index.js` 的 `patch.insert?.forEach`。修复：`insert:` 的值改成挂载行数组。控变量验证：移除该文件后 profile 立刻恢复。

**案例 B：client 产物格式（本说明书 §2.3 的来源）**——新增的第三方 client 插件把 `lib/client.js` 按 ESM 直出（末尾一行 `export { apply, inject, name };`，且把 React 内联成 1 MB）。宿主把它拼进 combo 后，浏览器在 `/plugins/` 的 **line 167452, col 1** 抛 `SyntaxError: Unexpected token 'export'` → 同 combo **56 个**插件集体 `import failed` → 整页 "Failed to load plugins"。**同期服务端 boot 完全正常**（`[pkg] loaded` + MCP `Server started`）。修复：改产物为 Lazy-CJS 工厂 + React 外置（产物 1,016,194 B → 11,110 B）；修后同页面 console **0 error / 0 warn**，面板标签正常出现。

---

## 5. 写/改一个 DSH 插件的操作规程

### 5.1 新建 checklist

- [ ] `package.json`：`dsh.bundle.patch` 指向真实存在的 patch 文件
- [ ] host 半产物是 ESM，`main`/`exports` 指向它，且**自包含**（不引用构建期中间文件）
- [ ] patch 文件：顶层是**数组**；`insert:` 是**挂载行数组**；`name` 用包名（不用相对路径，除非刻意做 dev overlay）
- [ ] 有 client 半的：`dsh.client.platform: "web"`；`exports["./client"]` 指向真实产物
- [ ] client 产物：① 头部是 `window.__ModuleLoader__.load({`；② 全文零顶层 `import`/`export`；③ 平台单例（react 等）未内联
- [ ] 构建脚本里 `clean` 不要吃掉 tsc 产出（`tsc && tsdown` 组合时尤其）
- [ ] 构建后跑两条 grep 判据（§2.5）
- [ ] 安装走 `dsh plugin … add`，**不要**手改 `dsh.profile.bundles`
- [ ] 装完先 `--dump-config` 静态合成，再真启
- [ ] 真启后：服务端看 `[pkg] loaded`；浏览器看 console 零错误
- [ ] 需要 MCP 工具的：走 `dsh-mcp-client` 桥；`failOnStartupError: true` 用来把握手/工具发现纳入启动诊断（**不**中止 harness）
- [ ] 收尾：确认 `DSH_HOME` 指向你要影响的那棵树

### 5.2 零污染实验纪律

实验期的改动**一律走 overlay 与隔离环境**，不动用户的持久配置：

```powershell
# 隔离数据根 + 追加 overlay，随时可弃
$env:DSH_HOME = "$env:TEMP\dsh-experiment"
node <runtime>\node_modules\@deepseek-ai\dsh\lib\bin.js `
  --profile web --patch <your-overlay.yml> --no-open --port 57179
```

还原判据：去掉 `--patch`（和/或把 `DSH_HOME` 指回原值）后行为回到基线。

---

## 6. 源码依据索引

| # | 位置（相对 `<runtime>/node_modules/@deepseek-ai/`） | 取用内容 |
|---|---|---|
| 1 | `dsh-app-boot/README.md` | profile/bundle/patch 模型、失败矩阵、required 说明 |
| 2 | `dsh-app-boot/lib/index.js` | `applyEntryPatches`（补丁语义）、`resolveBundleDir`、`boot`/`auditStartupEntries`、`anchorInsertedPluginNames` |
| 3 | `dsh/lib/plugin-*.js` | `dsh plugin` = pnpm 转发 + `reconcilePlugins` |
| 4 | `dsh/lib/profile-boot-*.js` | 层序（bundle→profile→home→overlay）、`INSTALL_ANCHOR`、`healProfilesModuleFallback` |
| 5 | `dsh-client-modules/README.md` | combo 分组、模块表种子、`lib/client.js` 构建要求 |
| 6 | `dsh-client-modules/lib/types/client/manifest.d.ts` | `__ModuleLoader__.load` 契约、purity gate、`loadBundle` 默认实现 |
| 7 | `dsh-package-manifest/README.md` | `dsh.bundle` / `dsh.client` / `engines.dsh` |
| 8 | `dsh-client-ui-*/lib/client.js`（官方产物样例） | Lazy-CJS 工厂权威形状 |
| 9 | `dsh-home-paths/lib/index.js` | `DSH_HOME` 解析优先级 |

**未实证的推断（如实标注）**：host 侧把各产物拼成 combo 的**具体拼接实现**未在 runtime 中直接读到（构建侧工具未随包分发）；combo 单脚本语义由 `manifest.d.ts` 的"one-resource combo endpoint"描述、官方产物同构性，以及案例 B 的 parse 失败行为共同支撑。

---

## 7. 一句话总结

**DSH 插件 = 一套声明（`dsh.*`）+ 两套产物（host ESM / client Lazy-CJS）**；
每条线各自独立接入、独立失败，**服务端正常不代表页面正常，页面崩不代表服务端有问题**——
排查顺序永远是：`DSH_HOME` → 浏览器 console → 服务端日志 → 静态合成 → 隔离复现。
