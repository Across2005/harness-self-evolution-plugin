# Deploy on Minimax Code (Mavis)

Verified on Minimax Code Desktop (data root `~/.minimax/`) on 2026-09-17. Three independent install paths are documented. Pick one based on how visible you want the plugin to be.

| Path | Effort | What you get |
|---|---|---|
| **A. MCP server only** | 5 min | 14 tools available in every Mavis session as `mcp__harness_evolution__*` |
| **B. Plugin V1 package** | 30 min | The plugin is a discoverable Local Plugin in Mavis's plugin panel, with its own Skill description |
| **C. Mini App floating panel** | 60 min | A native floating panel inside Mavis, with a button per tool and live result preview |

You can layer them. Path A is the minimum; path B adds discoverability; path C adds the panel UI.

## What this host uses

| Thing | Mavis value |
|---|---|
| User home | `~/.minimax/` |
| MCP server registry | `~/.minimax/mcp.json` (each entry: `name`, `type: stdio`, `command`, `args`, `env`, optional `cwd`, `timeout`) |
| Local Plugin V1 root | `~/.minimax/plugins/<plugin-id>/` (schemaVersion 1) |
| Mini App root | `<workspace>/miniapps/<plugin-id>/` (workspace-relative, synced into the plugin dir on `miniapp init`) |
| User-level agent / skill dir | `~/.minimax/agents/` |
| Host connector NDJSON | stdout is reserved for it; never write `console.log` or `process.stderr.write` from Mini App server code |

## Path A: MCP server only

Register the existing binary. Mavis will spawn it on demand in every session and expose its tools.

```powershell
mavis mcp create --name "harness-evolution" --transport "stdio" `
  --command "D:\Agent设计\harness-self-evolution-plugin\bin\harness-evolution.exe" `
  --description "Harness Evolution: 14 stdio MCP tools (scan, monitor, propose, execute, sub-agent mgmt)" `
  --env "{\"HARNESS_EVOLUTION_HOST\":\"minimax-code\"}" --enabled true
```

Verify:

```powershell
mavis mcp get --name "harness-evolution"
# expected: enabled=true, transport=stdio, command="D:\...\bin\harness-evolution.exe"
```

Open Mavis, start a session, and ask: "list the installed harness-evolution tools". You should see fourteen tools under `mcp__harness_evolution__*`.

## Path B: Plugin V1 package

Build a discoverable local Plugin. Same binary, but Mavis shows it in the Plugins panel and the Skill description becomes a candidate for in-product help.

Plugin V1 disallows native binaries inside the package, so the binary is invoked through a small Node.js shim that reads `HARNESS_EVOLUTION_EXE` from env:

```
~/.minimax/plugins/harness-evolution/
  .minimax-plugin/plugin.json         # manifest
  icon.png / icon-dark.png            # category icon (Code)
  mcp.json                            # server config
  scripts/launch.cjs                   # Node.js shim
  skills/harness-evolution/SKILL.md   # Skill description
```

Manifest schema (`.minimax-plugin/plugin.json`):

```json
{
  "schemaVersion": 1,
  "name": "harness-evolution",
  "displayName": "Harness Evolution",
  "version": "2.6.0",
  "description": "Benchmark-driven self-evolution plugin: scan plugins, monitor metrics, propose/approve/execute/rollback evolutions (14 stdio MCP tools, MoonBit-native exe wrapped via Node.js shim).",
  "author": "AI Agent Designer",
  "icon": "icon.png",
  "darkIcon": "icon-dark.png",
  "category": "Code",
  "exampleQueries": [
    "Scan installed plugins and show their version + scan-root",
    "List pending evolution proposals",
    "Get the runtime snapshot for the harness evolution service"
  ],
  "apps": [],
  "mcpServers": ["mcp.json"],
  "skills": ["skills/harness-evolution/SKILL.md"]
}
```

MCP config (`mcp.json`):

```json
{
  "schemaVersion": 1,
  "mcpServers": {
    "harness-evolution": {
      "type": "stdio",
      "command": "node",
      "args": ["./scripts/launch.cjs"],
      "env": {
        "HARNESS_EVOLUTION_HOST": "minimax-code",
        "HARNESS_EVOLUTION_EXE": "D:/Agent设计/harness-self-evolution-plugin/bin/harness-evolution.exe"
      },
      "description": "Harness Evolution: 14 stdio MCP tools (MoonBit-native exe, spawned via Node.js shim).",
      "timeout": 30000
    }
  }
}
```

Shim (`scripts/launch.cjs`):

```javascript
'use strict';
const { spawn } = require('node:child_process');
const exe = process.env.HARNESS_EVOLUTION_EXE;
if (!exe) {
  process.stderr.write('[harness-evolution] HARNESS_EVOLUTION_EXE env var is required\n');
  process.exit(2);
}
const child = spawn(exe, [], { stdio: 'inherit', env: process.env, windowsHide: true });
child.on('error', (err) => {
  process.stderr.write(`[harness-evolution] failed to spawn exe: ${err.message}\n`);
  process.exit(1);
});
child.on('exit', (code, signal) => {
  process.exit(code !== null ? code : 1);
});
```

Mavis auto-discovers Plugin V1 packages. If yours does not appear, check that all required manifest fields are present and the icon files are valid PNG.

## Path C: Mini App floating panel

Build a Mavis Mini App that lives next to the chat panel. Each MCP tool is a button; the result renders inline. The Mini App spawns the binary through the same shim and proxies JSON-RPC over the Mini App's HTTP surface.

```powershell
# in workspace root
miniapp init --pluginId "harness-evolution-panel"
# (workspace-relative) edit miniapps/harness-evolution-panel/miniapp/client/index.html
# and miniapps/harness-evolution-panel/miniapp/node/server.mjs

miniapp publish --pluginId "harness-evolution-panel"   # stages and runs
miniapp open --pluginId "harness-evolution-panel"     # opens the panel
```

The Mini App runtime injects a `MiniAppContext` with `pluginId`, `pluginRoot`, `dataDir`, `listen: { host: '127.0.0.1', port: number }`, `signal`, `logger`, and an optional `hostConnector`. The runtime contract:

- `stdout` is reserved for the Host Connector NDJSON protocol; never write to it from your Node code.
- Use `context.logger.debug / info / warn / error` for all diagnostics.
- `start(context)` must only install routes and start the HTTP listener; business calls (spawning the exe, talking JSON-RPC) live inside request handlers.
- Resolve `start(context)` only after the listener accepts connections. Resolution is the readiness signal; the plugin does not expose a readiness route.

A working `server.mjs` that satisfies this contract is in `miniapps/harness-evolution-panel/miniapp/node/server.mjs` in this repo (also at `~/.minimax/plugins/harness-evolution-panel/miniapp/node/server.mjs` after publish). It uses `context.logger` for all logs, spawns the exe lazily on first request, and proxies MCP JSON-RPC.

## What you should verify after install

For each path you enabled, do the minimum sanity that proves the binary talks to Mavis:

- **A**: in a session, ask "list the harness-evolution tools". Expect 14. Then `scan_plugins` and confirm the result mentions `harness-evolution` itself.
- **B**: in the Plugins panel, the package appears. Click it. The Skill description and example queries match the manifest.
- **C**: open the panel. The status dot goes green within ~1 second. The Tools section lists 14 tools. Click any tool, pass empty `{}` arguments if needed, and a result card appears.

If any of the above fails, the first thing to read is the exe startup log. The exe prints a one-line summary like `Server started (data root: ..., intensity: 50%, scan roots: 8, monitoring: true)`. Missing this line means the exe crashed before binding stdio.

## See also

- [`miniapps/harness-evolution-panel/`](../../miniapps/harness-evolution-panel/) — the verified working Mini App package. The `index.html` panel, `server.mjs` MCP proxy, and `miniapp.json` manifest are already correct for Mavis 0.x; copy this directory if you want to start from a working template.
- [docs/code-architecture.md](../code-architecture.md) — explains which `src/` files are shared (host-agnostic) versus per-host. Adding a new Mavis-specific feature only touches `host_agents_dir` and the `mcp.json` env block; the rest of the runtime stays unchanged.