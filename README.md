# Harness Self-Evolution Plugin

A MoonBit-native plugin that scans, monitors, proposes, and rolls back evolutions for the DeepSeek Harness (DSH) plugin ecosystem. Version 3.0.0. MIT.

This plugin targets DeepSeek Harness. Deployment hinges on how DSH launches the binary, where data is read and written, and which files (patches, manifests, panels) sit alongside the binary.

## Where your data lives

DSH resolves its home via `$DSH_HOME` (`~/.dsh` by default; a managed launcher may point it
elsewhere). The plugin mirrors that: user-scope sub-agent definitions land under
`<DSH home>/skills/`. Full install, verification, and rollback:
[docs/deploy/deepseek-harness.md](docs/deploy/deepseek-harness.md).

Since v3.0.0 the plugin is **DSH-only**: the earlier claim of MiniMax Code compatibility was a
over-declaration (DSH's own source has no such host concept) and has been removed.

If you are **writing or debugging a DSH plugin** rather than deploying this one, read [docs/dsh-plugin-integration.md](docs/dsh-plugin-integration.md): the host-half / client-half contract, the Lazy-CJS client bundle rule (one stray top-level `export` breaks every plugin in the combo), `DSH_HOME` routing, and the diagnosis order for "Failed to load plugins".

## What it does

- **Scan** installed plugins across the configured scan roots for the active host
- **Monitor** call latency, success rate, token usage, retry count, and user feedback
- **Identify** strong signals (user override, three consecutive failures, > 20% latency regression) and medium signals (repeated parameter misuses, loop detection, repeated preferences)
- **Propose** benchmark-driven evolutions bound to Matt Pocock engineering principles
- **Approve** is always a human step. `auto_approve` is `false` by default and stays `false` — the only gate against "code changes itself into a wall"
- **Execute** with state machine `pending → approved → executing → completed`, with deterministic rollback from a verified snapshot on validator failure
- **Sub-agent factory** persists Markdown + YAML frontmatter definitions; scope `plugin` lives under the plugin's data root, scope `user` lives under `<DSH home>/skills/` (see the deploy guide)

## Architecture in one paragraph

The compiled binary (`bin/harness-evolution.exe`) is a stdio MCP server exposing fourteen tools. The user-scope path resolves through `src/store/paths.mbt::dsh_agents_dir` (`<DSH home>/skills`, `$DSH_HOME`-aware), and the scan roots through `src/scanner/scanner.mbt::default_scan_roots`; `HARNESS_EVOLUTION_USER_DIR` overrides the user directory explicitly. Since v3.0.0 the multi-host abstraction is gone — DSH is the only target.

See [docs/code-architecture.md](docs/code-architecture.md) for the path-resolution detail.

## Build

```powershell
.\build.ps1 -Task all    # check + test + build; one command rebuilds the binary
```

Build prerequisites: MoonBit `>=0.1.20260904`, MSVC or Clang on Linux/macOS. The current binary in `bin/harness-evolution.exe` is Windows-native; rebuilding on the target platform produces a native binary for that platform.

## Data and configuration

The plugin stores proposals, metrics, signals, cache, and execution log under `$HARNESS_EVOLUTION_HOME` (default `~/.harness-evolution/v2/`). Override with the env var to keep dev/test data separate.

Configuration is read in this order, first file that exists wins:

1. `$HARNESS_EVOLUTION_CONFIG` (explicit override)
2. `<cwd>/.dsh-plugin/plugin.json` (self-manifest)
3. `.dsh-plugin/plugin.json` (relative to plugin root)

If none exist the plugin starts with built-in defaults — missing config is not a startup failure.

> **Breaking change (unreleased v2.7.0)**: the legacy `<cwd>/.zcode-plugin/plugin.json` fallback is no longer read. A deployed instance that still carries that file must rename it to `.dsh-plugin/plugin.json` — the contents need no change.

## Installing into the right tree (`DSH_HOME`)

Installing is **per DSH tree**: `dsh plugin add` writes into `$DSH_HOME/profiles/<name>`, and `$DSH_HOME`
decides which tree boots (`~/.dsh` by default — a managed launcher may point it somewhere else). Trees
share nothing: `bundles`, `node_modules`, sessions, and skills are all per-tree, so an install verified in
one tree stays invisible to a host booting another. `dsh.profile.bundles` is read at boot, so the host must
be **restarted** before the fourteen `mcp__harness-evolution__*` tools appear in a session.

```powershell
$env:DSH_HOME                                                            # which tree is dsh touching?
dsh --profile web --dump-config | Select-String 'mcp-harness-evolution'  # already mounted in this tree?
```

Full install, verification, and rollback: [docs/deploy/deepseek-harness.md](docs/deploy/deepseek-harness.md);
the live-install practice (multi-home reality, `.dsh-module-fallback` pitfalls):
[docs/dsh-compatibility.md](docs/dsh-compatibility.md).

## License

MIT. See [LICENSE](LICENSE).