# Deploy on DeepSeek Harness (DSH)

Verified against DSH 0.1.6-alpha.1 web profile on 2026-09-17, and re-verified on 2026-09-18 against a **running** web profile (install into the host's own tree → restart → all fourteen tools callable in-session; see [docs/dsh-compatibility.md](../dsh-compatibility.md) §5). The patch dialect, the `dsh-mcp-client` schema, the `~/.dsh` user directory, and the four host-related facts below are from DSH 0.1.6 source bundles (`@deepseek-ai/dsh-app-boot`, `dsh-mcp-client`, `dsh-home-paths`, `dsh-skill`) — not from documentation, which can drift.

## What this host uses

| Thing | DSH value |
|---|---|
| User home | `~/.dsh/` (the DSH home dir; env `DSH_HOME` overrides) |
| Plugin mount points | `~/.dsh/profiles/<name>/node_modules/<pkg>` (created by `dsh plugin add` via pnpm link) |
| User-level skill discovery | `~/.dsh/skills/` (rank 400), plus `~/.agents/skills/` (rank 500) |
| Loader patch language | `cordis.patch.yml` = array of `{insert, replace}` rows; `- insert:` value is `[{id, name, config?}]` |
| MCP bridge package | `@deepseek-ai/dsh-mcp-client` — spawns the exe over stdio and registers the tools |
| Web profile extras | web profile does **not** include `dsh-mcp-client` by default; you need an `--patch` overlay or a proper `cordis.patch.yml` mount row |

The plugin's user-scope sub-agent definitions write to `~/.dsh/skills/<name>.md`. DSH picks them up as skills in subsequent sessions (and in the current session if `dsh-skill-filesystem` is loaded).

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
dsh plugin --profile web add "<repo>"
dsh --profile web --dump-config        # exit 0 + mount row = the layer is in THIS tree
# rollback
dsh plugin --profile web remove "@across2005/harness-self-evolution"
```

**A restart is required.** `dsh.profile.bundles` is read at boot; `patchReload: "live"` reloads config
inside the tree but will not mount a newly added bundle. Until the host restarts, the session shows no
`mcp__harness-evolution__*` tools even though `--dump-config` is green.

## Install: the standard `dsh plugin add` path

Pre-built bundle. After verifying this repo's `cordis.patch.yml` matches the team's open-rigour patch (see [DSH compatibility notes](#dsh-compatibility-notes) below):

```powershell
dsh plugin --profile web add "D:\Agent设计\harness-self-evolution-plugin"
# or, if published to GitHub:
# dsh plugin --profile web add "github:Across2005/harness-self-evolution-plugin#v2.6.0"

dsh --profile web --dump-config    # exit 0, must contain the mcp-client mount row
dsh --profile web web --port 39401 # or whichever port; test boot
```

Confirm boot by reading the startup log — expect lines like `[HarnessEvolution] Loaded config from <path>` and `Server started (data root: ..., intensity: 50%, scan roots: 8, monitoring: true)`. The exact scan-root count includes profile and overlay paths, so don't hard-compare to a number.

## Install: the `--patch` overlay path

Use this if you don't have an open-rigour `cordis.patch.yml`, or if you want to layer the plugin on a profile that already has bundles:

```powershell
# Write overlay file once (template below)
dsh --profile web --dump-config --patch .\cordis.patch.overlay.yml    # exit 0
node "<DSH runtime>/node_modules/@deepseek-ai/dsh/lib/bin.js" \
  --profile web --patch .\cordis.overlay.yml --no-open --port 39401
```

Overlay template (`cordis.overlay.yml`):

```yaml
- insert:
    - id: mcp-harness-evolution
      name: '@deepseek-ai/dsh-mcp-client'
      config:
        transport: stdio
        serverName: harness-evolution
        command: 'D:/Agent设计/harness-self-evolution-plugin/bin/harness-evolution.exe'
        args: []
        cwd: 'D:/Agent设计/harness-self-evolution-plugin'
        env:
          HARNESS_EVOLUTION_HOST: deepseek-harness
        failOnStartupError: true
```

`failOnStartupError: true` is the strong check: if the MCP handshake or tool discovery fails, DSH boot aborts. Boot success implies the binary speaks MCP and the fourteen tools are present.

## Path substitution (★ H7)

DSH's cordis Loader does not resolve relative paths or `${ENV_VAR}` interpolation (verified against `@deepseek-ai/dsh-app-boot/lib/index.js`). The `command` and `cwd` values above **must be absolute path literals**.

If your checkout lives at a different path, run:

```powershell
pwsh -File scripts/replace-paths.ps1 `
  -OldPath 'D:/Agent设计/harness-self-evolution-plugin' `
  -NewPath '<your checkout path>'
```

The script rewrites both `cordis.patch.yml` and this doc's overlay template. Verify with:

```powershell
git grep -n '<your checkout path>' cordis.patch.yml docs/deploy/deepseek-harness.md
```

You should see 2 hits (one in each file), all inside the `- insert:` block.

## DSH compatibility notes

The whole history is at `docs/dsh-compatibility.md`. The single thing that will break your install if you get it wrong is the patch dialect — `- insert:` must be an **array of mount rows** (`[{id, name, config}]`), not a metadata mapping. The team has hit this before; the symptom is `TypeError: patch.insert?.forEach is not a function` at `dsh-app-boot/lib/index.js:2142` (`anchorInsertedPluginNames`) and the entire profile goes down with it.

Things you should not assume from documentation, only from runtime source:

- The real user home is `~/.dsh/`, not `~/.deepseek/harness/`. The plugin's `paths.mbt` already targets `~/.dsh/skills/`.
- DSH does not have a separate "user-level agents directory" concept — the plugin writes skill-format files (`SKILL.md` / `<name>.md` with `name` + `description` frontmatter) and the host discovers them via `dsh-skill-filesystem`.
- The web profile disables `skill-filesystem`, `tool-subagent`, `tool-subagent-fork`, and `tool-workflow` by default. Plugin-side claims of "host-side subagent orchestration" do not hold on web profile out of the box.

## What you should verify after install

```powershell
# 1. The exe speaks MCP on stdio — no host needed
$init = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"probe","version":"0"}}}'
$note = '{"jsonrpc":"2.0","method":"notifications/initialized"}'
$list = '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
$init, $note, $list | & bin\harness-evolution.exe 2>$null
# expect: serverInfo {name: harness-self-evolution, version: 2.6.0}, then tools[] with 14 entries

# 2. The host actually mounted it — check the process parent, not just the config
Get-CimInstance Win32_Process -Filter "Name='harness-evolution.exe'" |
  Select-Object ProcessId, ParentProcessId, CreationDate
# expect: one exe whose parent is the running DSH node process (after the restart from § Which tree?)
# The host's stderr should also show: [HarnessEvolution] Server started (data root: ..., scan roots: N, ...)

# 3. The tools are wired, in a session on that host
#   get_runtime_snapshot   -> JSON with "root" (data root) and "data_gaps"
#   scan_plugins          -> plugin records (a live host scans ~/.dsh, ~/.minimax/plugins, ~/.agents/skills, ...)
#   list_proposals        -> [] on a fresh data root
#   create_sub_agent scope=user name=evo-smoke content="..."  # -> file under <that tree's>/skills/
#   delete_sub_agent scope=user name=evo-smoke               # -> cleanup

# 4. The user directory is real (per-tree!)
Get-ChildItem "$env:DSH_HOME\skills" -ErrorAction SilentlyContinue | Select-Object Name
```

One machine can run several hosts over the same exe: this checkout's binary is also spawned by
Minimax Code through `~/.minimax/plugins/harness-evolution/` (`mcp.json` + `scripts/launch.cjs` shim,
`HARNESS_EVOLUTION_HOST=minimax-code`) while DSH spawns it directly via `dsh-mcp-client`. Both default
to the same data root (`~/.harness-evolution/v2`); set a distinct `HARNESS_EVOLUTION_HOME` per host if
you want them isolated.

If the browser surface shows the chat panel but `/` reports `dsh web authentication required`, you opened the bare URL. The startup log prints `dsh web: http://127.0.0.1:<port>/?token=<token>`; open that URL once and the token sticks.

## See also

- [docs/dsh-compatibility.md](../dsh-compatibility.md) — the historical record of the 0.1.6 fix, including the patch-dialect crash analysis and the directory-model correction
- [DSH_INTEGRATION.md](../../DSH_INTEGRATION.md) — the per-tool contract: what each of the fourteen tools does, `execute_evolution` being a self-contained tool, sub-agent scope mechanics, and the monitor boundary declaration

## 用户自验 Checklist（A9 — 用户在 DSH 上跑）

> 计划层 A9：本节是给「自己在 DSH 上验证部署」的用户跑的手册。维护方**不**进入 DSH 流程；本节列了 8 步最小验证 + 期望输出对照表 + 异常诊断。

### 前置

| 项 | 要求 |
|---|---|
| DSH | ≥ 0.1.6（实测 0.1.6-alpha.1） |
| Node | ≥ 18（DSH runtime 要求） |
| 仓库 | 已 `build.ps1 -Task all` 通过（产出 `bin/harness-evolution.exe`） |
| Profile | `web`（DSH web profile 默认无 `dsh-mcp-client`，需 `--patch` overlay） |
| 树 | 先确认宿主用的 `DSH_HOME`；插件必须装进**这一棵**，装完重启 host（见 § Which tree?） |

### 8 步最小验证

| # | 动作 | 期望输出 | 失败时排查 |
|---|---|---|---|
| 1 | `dsh --profile web --dump-config` | exit 0；输出含 `mcp-harness-evolution` mount row | 路径未替换（见 § Path substitution） |
| 2 | `node <DSH runtime>/node_modules/@deepseek-ai/dsh/lib/bin.js --version` | `0.1.6-alpha.1` 或更高 | DSH 版本过低；升级或换符合要求的 profile |
| 3 | `dsh --profile web web --port 39402 --no-open` | 日志含 `[HarnessEvolution]` 与 `Server started (data root: ...)` | exe 启动失败：`Get-Content bin/harness-evolution.exe` 是否 > 1MB；`HARNESS_EVOLUTION_HOME` 是否设 |
| 4 | 从 startup 日志末尾读 `dsh web: http://127.0.0.1:39402/?token=<token>` | URL 带 token 段 | MCP `deepseek_harness_start` 只返回裸 URL，token 在日志里 |
| 5 | 浏览器打开 `http://127.0.0.1:39402/?token=<token>` | 主 UI 真实加载，无 `authentication required` | URL 缺 token；从日志拿 |
| 6 | 在 DSH 工具面板调 `scan_plugins` | 返回 ≥ 1 个插件记录 | MCP 未注入：检查 overlay 路径与 failOnStartupError |
| 7 | 调 `get_runtime_snapshot` | 返回非空 JSON，含 `serverInfo.version` 与 `dataPaths` | MCP 握手失败：`dsh --profile web --dump-config --patch <abs>` 验证 |
| 8 | 调 `list_proposals` | `[]`（空数组，无错） | 数据根写入权限：检查 `HARNESS_EVOLUTION_HOME` 指向可写目录 |

> **生效时机**：`dsh.profile.bundles` 只在 boot 时读取。刚 `dsh plugin add` 进 profile 的插件必须
> **重启 host** 才会挂载——旧进程里第 1 步 `dump-config` 是绿的，也不代表工具已可用
> （2026-09-18 实测：`dump-config` exit 0 但会话内无工具；重启后 14 个工具即刻可调）。

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
| `HarnessEvolution] Unknown HARNESS_EVOLUTION_HOST` | 环境变量拼写错或未识别 | 用 `deepseek-harness` / `minimax-code` 二选一 |
| 装了插件但会话里没有 `mcp__harness-evolution__*` 工具 | 装到了另一棵树，或 host 未重启 | 见 § Which tree?：确认宿主的 `DSH_HOME`，装进这一棵，然后重启 |
| 同一个 exe 出现多个进程 | 多个宿主各自拉起（DSH + Minimax Code） | 正常：父进程分别是各宿主；需要隔离就给各自设 `HARNESS_EVOLUTION_HOME` |
| `bin/harness-evolution.exe` 被覆盖失败 | 进程占用 | `Get-Process harness-evolution \| Stop-Process` 后再 build |

### 验证矩阵对照

执行完成后对照 `paths.mbt::host_verification_notice`：

- `HARNESS_EVOLUTION_HOST=deepseek-harness` → 应看到 `Host: DeepSeek Harness ≥ 0.1.6 — verified end-to-end 2026-09-17 ...`
- 其他宿主 → 不适用本节

如本节 8 步全过且与验证矩阵一致，则 DSH 部署已被本机制实证。可在 `paths.mbt::host_verification_notice` 的对应分支更新日期（一般不动——`verified` 日期代表项目层验证，你的部署属实例层验证）。

> **机制参考**：本文只讲"怎么部署"。DSH 插件接入的完整机制（host 半四层管线 / client 半 Lazy-CJS 产物契约 / `DSH_HOME` 路由 / 故障诊断顺序 / 写插件的 checklist）见 [docs/dsh-plugin-integration.md](../dsh-plugin-integration.md)。