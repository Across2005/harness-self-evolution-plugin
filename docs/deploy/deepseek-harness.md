# Deploy on DeepSeek Harness (DSH)

Verified against DSH 0.1.5-rc.2 web profile on 2026-09-25, with 0.1.6-alpha.1 retained as a regression target. The patch dialect, the `dsh-mcp-client` schema, the `~/.dsh` user directory, and the four host-related facts below are from the packaged DSH runtime (`@deepseek-ai/dsh-app-boot`, `dsh-mcp-client`, `dsh-home-paths`, `dsh-skill`) — not from documentation, which can drift.

> **v3.2 note**: the tool surface is now **sixteen** (added `record_tool_call` / `record_user_feedback`); the 2026-09-18 end-to-end run above observed fourteen at that time.

## What this host uses

| Thing | DSH value |
|---|---|
| User home | `~/.dsh/` (the DSH home dir; env `DSH_HOME` overrides) |
| Plugin mount points | `~/.dsh/profiles/<name>/node_modules/<pkg>` (created by `dsh plugin add` via pnpm link) |
| User-level skill discovery | `~/.dsh/skills/` (rank 400), plus `~/.agents/skills/` (rank 500) |
| Loader patch language | `cordis.patch.yml` = array of `{insert, replace}` rows; `- insert:` value is `[{id, name, config?}]` |
| MCP bridge package | `@deepseek-ai/dsh-mcp-client` — spawns the exe over stdio and registers the tools |
| Web profile extras | web profile does **not** include `dsh-mcp-client` by default; you need an `--patch` overlay or a proper `cordis.patch.yml` mount row |

The plugin's user-scope sub-agent definitions write to `<DSH_HOME>/skills/<name>.md` (`~/.dsh/skills/<name>.md` when the home resolves to the default). DSH picks them up as skills in subsequent sessions (and in the current session if `dsh-skill-filesystem` is loaded).

## Which tree? (`DSH_HOME`) — install is per-tree

`dsh plugin add` writes into `$DSH_HOME/profiles/<name>` — **the tree the invoking CLI resolves**, not
"the DSH on this machine". The default is `~/.dsh`, but a managed launcher may point `DSH_HOME` somewhere
else (e.g. a plugin-data `dsh-home`), and the two trees share nothing: `bundles`, `node_modules`,
`sessions`, `skills`, and `storages` are all per-tree. An install verified in one tree is invisible to a
host booting another (live case: 2026-09-18).

```powershell
$env:DSH_HOME                                                            # which tree would dsh touch?
dsh --profile web --dump-config | Select-String 'mcp-harness-evolution'  # already mounted here?
```

Install into the tree the host actually uses:

```powershell
$env:DSH_HOME = '<the host tree>'      # e.g. <pluginData>\dsh-home
pwsh -File scripts/install-dsh.ps1 -Profile web   # installs the bundle AND injects the mount row
dsh --profile web --dump-config | Select-String 'mcp-harness-evolution'  # exit 0, row enabled
# rollback
pwsh -File scripts/install-dsh.ps1 -Profile web -Uninstall
dsh plugin --profile web remove "@across2005/harness-self-evolution"
```

**A restart is required.** `dsh.profile.bundles` is read at boot; `patchReload: "live"` reloads config
inside the tree but will not mount a newly added bundle. Until the host restarts, the session shows no
`mcp__harness-evolution__*` tools even though `--dump-config` is green.

### How the plugin learns the tree (`DSH_HOME`) — v3.1

Installing into the right tree is only half the job — the MCP child **cannot inherit** `DSH_HOME`:
DSH spawns it through `scrubbedParentEnv()`, which drops every `DSH_*` name
(`@deepseek-ai/dsh-subprocess`), and `@deepseek-ai/dsh-mcp-client` merges the mount row's `env`
**after** that scrub. The Loader expands neither `${ENV_VAR}` nor relative paths for
`config.command` / `config.cwd` (see § Path substitution), so a shipped literal can only ever be
right for one machine — and a wrong one means the plugin **silently never mounts** (one `warning`
line, harness keeps booting; see the box below).

v3.1 therefore removes the literal from the shipped artifact and resolves the tree twice over:

| Tier | Source | Set by |
|---|---|---|
| 1 | `env.DSH_HOME` in the mount row (absolute literal) | `scripts/install-dsh.ps1`, computed for **this** tree |
| 2 | **derived from the plugin's own install path** — `<X>/profiles/<name>/node_modules/…` → `X`, read from the child's cwd / `argv[0]` | nothing; the plugin does it itself (`src/store/paths.mbt::dsh_home`) |
| 3 | `~/.dsh` | fallback, unchanged from `resolveDshHome` |

Tier 2 is the belt to tier 1's braces: the installer writes the mount row's `cwd` as the install
location inside the profile, so even if `env.DSH_HOME` were dropped, `create_sub_agent scope=user`
still lands in the tree that actually mounted the plugin. A blank or relative `$DSH_HOME` counts as
unset, and a relative value is never adopted (the plugin's cwd is not the host's).

The shipped bundle patch keeps the row `disabled: true` with placeholder values; the installer's
id-targeted override replaces the whole `config` and enables it:

```powershell
pwsh -File scripts/install-dsh.ps1 -Profile web    # resolves the tree, writes the row, prints checks
```

After a host restart, confirm with step 4 of § What you should verify after install.

## Install: the standard path (installer)

The shipped `cordis.patch.yml` mounts the row **disabled and without machine paths** (see
§ How the plugin learns the tree). `scripts/install-dsh.ps1` installs the bundle into the target tree
and injects the enabled row into that profile's patch layer:

```powershell
pwsh -File scripts/install-dsh.ps1 -Profile web                 # $DSH_HOME, else ~/.dsh
pwsh -File scripts/install-dsh.ps1 -Profile web -DryRun         # print what would be written
pwsh -File scripts/install-dsh.ps1 -Profile web -SkipPluginAdd  # bundle already installed
pwsh -File scripts/install-dsh.ps1 -Profile web -Uninstall      # remove the injected row
# dsh not on PATH:
pwsh -File scripts/install-dsh.ps1 -Profile web `
  -DshCommand 'node C:/Users/me/.minimax/v2/plugin-data/local-minimax/dsh/runtime/node_modules/@deepseek-ai/dsh/lib/bin.js'
```

Then verify statically and boot:

```powershell
dsh --profile web --dump-config | Select-String 'mcp-harness-evolution'  # exit 0, row enabled
dsh --profile web web --port 39401                                       # or whichever port
```

Confirm boot by reading the startup log — expect lines like `[HarnessEvolution] Loaded config from <path>` and `Server started (data root: ..., intensity: 50%, scan roots: N, monitoring: true)`. The scan-root count includes profile and overlay paths, so don't hard-compare to a number.

## Install: the `--patch` overlay path (experiments only)

For a throwaway tree / isolated experiment, or when you want to layer the plugin without touching any
profile file. Note the entry is an **id-targeted override**, not an `insert`: the bundle already
carries the `mcp-harness-evolution` row (disabled), and inserting a second row with the same id is an
error (`duplicate loader entry id`).

```powershell
# Write overlay file once (template below)
dsh --profile web --dump-config --patch .\cordis.overlay.yml          # exit 0
node "<DSH runtime>/node_modules/@deepseek-ai/dsh/lib/bin.js" `
  --profile web --patch .\cordis.overlay.yml --no-open --port 39401
```

Overlay template (`cordis.overlay.yml`) — absolute literals for the machine you are on:

```yaml
- id: mcp-harness-evolution            # override the shipped (disabled) row
  disabled: false
  config:
    transport: stdio
    serverName: harness-evolution
    command: '<checkout>/bin/harness-evolution.exe'
    args: []
    cwd: '<checkout>'
    env:
      # absolute literal for the tree this host boots; '' means unset -> the plugin
      # falls back to install-path derivation, then ~/.dsh
      DSH_HOME: ''
    failOnStartupError: true
```

`failOnStartupError: true` rejects **this plugin's activation** when the MCP handshake or tool
discovery fails — it does **not** abort the harness. `mcp-harness-evolution` is not in the host's
`requiredStartupEntryIds`, so app-boot classifies its failure as *optional* and only prints one
`warning` line (`dsh-app-boot/lib/index.js:2408-2416`, `2513-2515`). Boot success therefore still
implies the binary speaks MCP and the sixteen tools are present — but boot failure does **not**
imply the plugin failed.

> **The genuinely fatal failure is a patch layer DSH cannot parse.** `parsePatchList` *throws*
> (`dsh-app-boot/lib/index.js:2158-2163`) and the profile never boots at all. That file is written by
> `scripts/install-dsh.ps1`, so its output is pinned by a regression suite that parses it with the
> host's own `js-yaml`:
>
> ```powershell
> pwsh -File scripts/test-install-dsh.ps1     # 7 scenarios, temp tree only, no real DSH tree touched
> ```
>
> The historical trigger was the factory-fresh patch template (three comment lines plus a bare `[]`):
> a block sequence item appended after a flow sequence is invalid YAML, and that template is exactly
> what DSH writes for every new profile.

## Path literals and path substitution (★ H7)

DSH's cordis Loader does not resolve relative paths or `${ENV_VAR}` interpolation for
`config.command` / `config.cwd` (verified against `@deepseek-ai/dsh-app-boot/lib/index.js`: its
`anchorInsertedPluginNames` only rewrites `entry.name`). Any absolute `command`/`cwd` therefore has
to be **computed for the machine it runs on** — which is why v3.1 moved it out of the shipped patch
and into `scripts/install-dsh.ps1` (see § How the plugin learns the tree).

`scripts/replace-paths.ps1` is the remaining tool for **fork/CI** work: it rewrites checkout-path
literals inside the repo's own files (the installer needs no such thing — it resolves the target
tree at run time).

```powershell
pwsh -File scripts/replace-paths.ps1 `
  -OldPath 'D:/Agent设计/harness-self-evolution-plugin' `
  -NewPath '<your checkout path>'
```

The shipped `cordis.patch.yml` no longer contains a checkout path at all (guard G9 pins that), so
today the script's main use is rewriting example literals in this document.

## DSH compatibility notes

The whole history is at `docs/dsh-compatibility.md`. The single thing that will break your install if you get it wrong is the patch dialect — `- insert:` must be an **array of mount rows** (`[{id, name, config}]`), not a metadata mapping. The team has hit this before; the symptom is `TypeError: patch.insert?.forEach is not a function` at `dsh-app-boot/lib/index.js:2142` (`anchorInsertedPluginNames`) and the entire profile goes down with it.

Things you should not assume from documentation, only from runtime source:

- The real user home is `~/.dsh/`, not `~/.deepseek/harness/`, and `$DSH_HOME` overrides it. The plugin's `paths.mbt::dsh_home` mirrors that precedence, so user-scope definitions follow the tree — see § Forwarding `DSH_HOME` to the plugin.
- DSH does not have a separate "user-level agents directory" concept — the plugin writes skill-format files (`SKILL.md` / `<name>.md` with `name` + `description` frontmatter) and the host discovers them via `dsh-skill-filesystem`.
- The web profile disables `skill-filesystem`, `tool-subagent`, `tool-subagent-fork`, and `tool-workflow` by default. Plugin-side claims of "host-side subagent orchestration" do not hold on web profile out of the box.

## What you should verify after install

```powershell
# 1. The exe speaks MCP on stdio — no host needed
$init = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"probe","version":"0"}}}'
$note = '{"jsonrpc":"2.0","method":"notifications/initialized"}'
$list = '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
$init, $note, $list | & bin\harness-evolution.exe 2>$null
# expect: serverInfo {name: harness-self-evolution, version: 3.2.1}, then tools[] with 16 entries

# 2. The host actually mounted it — check the process parent, not just the config
Get-CimInstance Win32_Process -Filter "Name='harness-evolution.exe'" |
  Select-Object ProcessId, ParentProcessId, CreationDate
# expect: one exe whose parent is the running DSH node process (after the restart from § Which tree?)
# The host's stderr should also show: [HarnessEvolution] Server started (data root: ..., scan roots: N, ...)

# 3. The tools are wired, in a session on that host
#   get_runtime_snapshot   -> JSON with "root" (data root) and "data_gaps"
#   scan_plugins          -> plugin records (a live host scans ~/.dsh/profiles, ~/.agents/plugins, ...)
#   list_proposals        -> [] on a fresh data root
#   create_sub_agent scope=user name=evo-smoke content="..."  # -> file under <that tree's>/skills/
#   delete_sub_agent scope=user name=evo-smoke               # -> cleanup

# 4. The user directory is real (per-tree!)
Get-ChildItem "$env:DSH_HOME\skills" -ErrorAction SilentlyContinue | Select-Object Name
```

Since v3.0.0 the plugin targets DSH only (the earlier MiniMax Code host claim was an
over-declaration and has been removed). The default data root is
`<DSH_HOME>/.harness-evolution/v2` so separate DSH trees do not share data; set a distinct
`HARNESS_EVOLUTION_HOME` if you run multiple instances in one tree and want their data
isolated.

If the browser surface shows the chat panel but `/` reports `dsh web authentication required`, you opened the bare URL. The startup log prints `dsh web: http://127.0.0.1:<port>/?token=<token>`; open that URL once and the token sticks.

## See also

- [docs/dsh-compatibility.md](../dsh-compatibility.md) — the historical record of the 0.1.6 fix, including the patch-dialect crash analysis and the directory-model correction
- [DSH_INTEGRATION.md](../../DSH_INTEGRATION.md) — the per-tool contract: what each of the sixteen tools does, `execute_evolution` being a self-contained tool, sub-agent scope mechanics, and the monitor boundary declaration

## 用户自验 Checklist（A9 — 用户在 DSH 上跑）

> 计划层 A9：本节是给「自己在 DSH 上验证部署」的用户跑的手册。维护方**不**进入 DSH 流程；本节列了 8 步最小验证 + 期望输出对照表 + 异常诊断。

### 前置

| 项 | 要求 |
|---|---|
| DSH | `0.1.5-rc.2`（回归：`0.1.6-alpha.1`） |
| Node | ≥ 18（DSH runtime 要求） |
| 仓库 | 已 `build.ps1 -Task all` 通过（产出 `bin/harness-evolution.exe`） |
| Profile | `web`（DSH web profile 默认无 `dsh-mcp-client`，需 `--patch` overlay） |
| 树 | 先确认宿主用的 `DSH_HOME`；插件必须装进**这一棵**，装完重启 host（见 § Which tree?） |

### 8 步最小验证

| # | 动作 | 期望输出 | 失败时排查 |
|---|---|---|---|
| 1 | `dsh --profile web --dump-config` | exit 0；输出含 `mcp-harness-evolution` mount row | 路径未替换（见 § Path substitution） |
| 2 | `node <DSH runtime>/node_modules/@deepseek-ai/dsh/lib/bin.js --version` | `0.1.5-rc.2`；回归验收使用 `0.1.6-alpha.1` | DSH 版本过低；升级或换符合要求的 profile |
| 3 | `dsh --profile web web --port 39402 --no-open` | 日志含 `[HarnessEvolution]` 与 `Server started (data root: ...)` | exe 启动失败：`Get-Content bin/harness-evolution.exe` 是否 > 1MB；`HARNESS_EVOLUTION_HOME` 是否设 |
| 4 | 从 startup 日志末尾读 `dsh web: http://127.0.0.1:39402/?token=<token>` | URL 带 token 段 | MCP `deepseek_harness_start` 只返回裸 URL，token 在日志里 |
| 5 | 浏览器打开 `http://127.0.0.1:39402/?token=<token>` | 主 UI 真实加载，无 `authentication required` | URL 缺 token；从日志拿 |
| 6 | 在 DSH 工具面板调 `scan_plugins` | 返回 ≥ 1 个插件记录 | MCP 未注入：检查 mount row 的 `disabled`/`command`，以及宿主 stderr 的 `1 entry did not activate` warning |
| 7 | 调 `get_runtime_snapshot` | 返回非空 JSON，含 `serverInfo.version` 与 `dataPaths` | MCP 握手失败：`dsh --profile web --dump-config --patch <abs>` 验证 |
| 8 | 调 `list_proposals` | `[]`（空数组，无错） | 数据根写入权限：检查 `HARNESS_EVOLUTION_HOME` 指向可写目录 |

> **生效时机**：`dsh.profile.bundles` 只在 boot 时读取。刚 `dsh plugin add` 进 profile 的插件必须
> **重启 host** 才会挂载——旧进程里第 1 步 `dump-config` 是绿的，也不代表工具已可用
> （2026-09-18 实测：`dump-config` exit 0 但会话内无工具；重启后当时 14 个工具即刻可调——v3.2 起为 16 个）。

### 异常诊断速查

| 现象 | 根因 | 修法 |
|---|---|---|
| `TypeError: patch.insert?.forEach is not a function` | `- insert:` 写成了元数据映射 | 改为 `[{id, name, config}]` 数组挂载行（已在本仓库 P0 修复） |
| 页面 "Failed to load plugins"（列一长串包名） | client 产物含顶层 `export`，整条 combo 解析失败（连坐） | 改产物为 Lazy-CJS 工厂：见 [dsh-plugin-integration.md §2.3](../dsh-plugin-integration.md) |
| 底部一直"重新连接中." | web profile 默认 disable `skill-filesystem` | overlay 挂 `- id: skill-filesystem` + `config: { includeDefaultRoots: true }` |
| `dsh web authentication required` | 打开了裸 URL | 从 startup 日志末尾拿带 token 的 URL |
| `Cannot find module '@deepseek-ai/dsh-mcp-client'` | web profile 没装 mcp-client | 用 `--patch` overlay 注入（见 § Install: the --patch overlay path） |
| `dsh: failed to read overlay …ENOENT` | `--patch` 用了逗号分隔多文件 | 单文件参数可重复传：`--patch a.yml --patch b.yml` |
| `duplicate loader entry id: <id>` | profile 已装该 bundle，overlay 又注入同一 id | 二者留一（bundle 内已有则删掉 overlay 的注入行） |
| 装了插件但会话里没有 `mcp__harness-evolution__*` 工具 | 装到了另一棵树 / 没跑安装器（出厂行 `disabled: true`）/ host 未重启 | 见 § Which tree?：确认宿主的 `DSH_HOME`，用 `scripts/install-dsh.ps1 -Profile <p>` 注入挂载行，然后重启 |
| `dsh: failed to parse patches/overlay <…cordis.patch.yml>`（`YAMLException`） | **profile 完全无法 boot** —— patch 层 YAML 非法。历史上由 `install-dsh.ps1` 在出厂空模板上写出 `[]` + 块序列项触发 | 把该文件里的裸 `[]` 整行删掉（块序列项已在则不要再加 `[]`）；升级到修好的安装器并跑 `scripts/test-install-dsh.ps1` |
| 同一个 exe 出现多个进程 | 多个实例各自拉起 | 正常：父进程分别是各实例；需要隔离就给各自设 `HARNESS_EVOLUTION_HOME` |
| `bin/harness-evolution.exe` 被覆盖失败 | 进程占用 | `Get-Process harness-evolution \| Stop-Process` 后再 build |

### 部署判据

v3.0.0 起启动日志不再按宿主点名验证状态（多宿主抽象已移除）。以本节步骤的实际结果为准：
`tools/list` 回显 `version: 3.2.1` + 16 个工具、`create_sub_agent scope=user` 落进
`<DSH_HOME>/skills/`、宿主重启后能看到 `mcp__harness-evolution__*` 工具 —— 三条齐即
说明 DSH 部署已实证。

> **机制参考**：本文只讲"怎么部署"。DSH 插件接入的完整机制（host 半四层管线 / client 半 Lazy-CJS 产物契约 / `DSH_HOME` 路由 / 故障诊断顺序 / 写插件的 checklist）见 [docs/dsh-plugin-integration.md](../dsh-plugin-integration.md)。