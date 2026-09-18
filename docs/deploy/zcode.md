# Deploy on ZCode

**Status: declared support, not yet verified end-to-end on a real ZCode installation.**

This page documents what the plugin claims to do on ZCode based on the code path that exists in this repo. Before relying on it, run the verification steps at the bottom and report what you find — without empirical confirmation the path can drift without warning.

## What this host uses (as declared in the code)

| Thing | ZCode value (declared) |
|---|---|
| User home | `~/.zcode/` |
| User-level sub-agent dir | `~/.zcode/agents/` (declared in `src/store/paths.mbt::host_agents_dir`) |
| Plugin scan roots | `~/.zcode/cli/plugins/cache/zcode-plugins-official`, `~/.zcode/plugins` |
| Self-manifest legacy path | `<cwd>/.zcode-plugin/plugin.json` (still read by the runtime's config discovery for backwards compatibility) |
| Env var to opt in | `HARNESS_EVOLUTION_HOST=zcode` |

The ZCode branch in `host_agents_dir` exists and is unit-tested. Nothing else in the runtime distinguishes ZCode from DSH or Minimax Code beyond the user directory and scan roots. The plugin does not bundle a ZCode loader patch or panel UI for ZCode.

## Install (proposed)

```powershell
$env:HARNESS_EVOLUTION_HOST = "zcode"
# start the binary however ZCode launches stdio MCP servers
# (specifics depend on ZCode's plugin loader; check ZCode docs for your version)
"D:\Agent设计\harness-self-evolution-plugin\bin\harness-evolution.exe"
```

If ZCode's loader accepts a path to the binary directly, the above is enough. If ZCode requires a manifest, point it at `bin/harness-evolution.exe` with the same `mcp` shape used in `.dsh-plugin/plugin.json` (transport `stdio`, protocolVersion `2024-11-05`, fourteen tool names).

## What you should verify before trusting it

These are the checks we have not been able to run end-to-end on a real ZCode installation. If you have ZCode installed, please report results:

1. Does the binary start under ZCode's plugin loader without crashing?
2. Does `HARNESS_EVOLUTION_HOST=zcode` route user-scope sub-agent writes to `~/.zcode/agents/`?
3. Do the two ZCode scan roots (`~/.zcode/cli/plugins/cache/zcode-plugins-official`, `~/.zcode/plugins`) actually exist on a fresh ZCode install, or are they speculative?
4. Does `create_sub_agent(scope=user)` produce a file ZCode actually reads?
5. Does the ZCode self-manifest convention match the plugin's `bin/harness-evolution.exe` entry?

If any of these fail, please open an issue with the error and the ZCode version. The plugin needs `host_agents_dir` and `default_scan_roots` updated in lockstep with whatever ZCode actually does.