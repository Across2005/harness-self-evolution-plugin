# Harness Self-Evolution Plugin

A MoonBit-native plugin that scans, monitors, proposes, and rolls back evolutions for plugin ecosystems on two AI harness hosts: DeepSeek Harness and Minimax Code. Version 2.6.0. MIT.

This plugin is the same compiled binary for every host. What changes per host is how the host launches the binary, where data is read and written, and which host-specific files (patches, manifests, panels) sit alongside the binary.

## Which host are you on?

Pick the one that runs your sessions. If you don't know, run:

```powershell
# Windows PowerShell
Test-Path '~/.dsh'
Test-Path '~/.minimax'
```

Open the matching guide:

| Host | Status (2026-09-17) | Guide |
|---|---|---|
| **DeepSeek Harness** (DSH) ≥ 0.1.6 | **Verified end-to-end** | [docs/deploy/deepseek-harness.md](docs/deploy/deepseek-harness.md) |
| **Minimax Code** (Mavis) | **Verified end-to-end** | [docs/deploy/mavis.md](docs/deploy/mavis.md) |
| anything else | **Unsupported** | — |

What "verified" means: a fresh install completes the full propose → approve → execute loop on this machine, and the runtime stays healthy afterwards. "Unsupported" means the runtime will fall back to the DSH path and emit a `Unknown HARNESS_EVOLUTION_HOST ...` warning on every boot — do not rely on it.

The status of the active host is **printed by the binary itself at startup** (see `host_verification_notice` in `src/store/paths.mbt`). Operators do not have to read this README to know whether they are on a verified host; the boot log says so directly. The same matrix is also pinned by a regression test (`host verification notice reflects the current verification matrix`) so an unnoticed change to one without the other fails the build.

If your host isn't in the table, see [docs/code-architecture.md § Adding a new host](docs/code-architecture.md#adding-a-new-host) — four edits in the runtime plus a deploy guide, plus the verification test.

If you are **writing or debugging a DSH plugin** rather than deploying this one, read [docs/dsh-plugin-integration.md](docs/dsh-plugin-integration.md): the host-half / client-half contract, the Lazy-CJS client bundle rule (one stray top-level `export` breaks every plugin in the combo), `DSH_HOME` routing, and the diagnosis order for "Failed to load plugins".

## What it does

- **Scan** installed plugins across the configured scan roots for the active host
- **Monitor** call latency, success rate, token usage, retry count, and user feedback
- **Identify** strong signals (user override, three consecutive failures, > 20% latency regression) and medium signals (repeated parameter misuses, loop detection, repeated preferences)
- **Propose** benchmark-driven evolutions bound to Matt Pocock engineering principles
- **Approve** is always a human step. `auto_approve` is `false` by default and stays `false` — the only gate against "code changes itself into a wall"
- **Execute** with state machine `pending → approved → executing → completed`, with deterministic rollback from a verified snapshot on validator failure
- **Sub-agent factory** persists Markdown + YAML frontmatter definitions; scope `plugin` lives under the plugin's data root, scope `user` lives in the host's user-level directory (path differs per host, see deploy guides)

## Architecture in one paragraph

The compiled binary (`bin/harness-evolution.exe`) is a stdio MCP server. The MCP protocol surface and the fourteen tools are host-agnostic. Two things change per host: (a) the path layout, declared in `src/store/paths.mbt::host_agents_dir` and `src/scanner/scanner.mbt::default_scan_roots`; (b) the launcher and supplementary files. The runtime picks the host from `HARNESS_EVOLUTION_HOST` (`deepseek-harness` default, or `minimax-code`; `HARNESS_EVOLUTION_USER_DIR` overrides the user directory explicitly). Any other value warns at startup and falls back to the DSH directory. Each deploy guide in `docs/deploy/` spells out exactly which launcher mechanism and which supplementary files that host uses.

See [docs/code-architecture.md](docs/code-architecture.md) for the split-path loading principle in detail.

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