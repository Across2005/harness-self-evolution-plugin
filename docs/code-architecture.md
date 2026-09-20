# Code architecture: path resolution (DSH-only)

This doc is for readers who want to understand how the plugin resolves the paths it reads and
writes, and for new contributors. Since v3.0.0 the plugin targets **DeepSeek Harness (DSH) only**;
the earlier multi-host abstraction (a `minimax-code` host selected by `HARNESS_EVOLUTION_HOST`)
was an over-declaration — DSH's own source has no such host concept — and has been removed.

## The one-line principle

User-scope paths resolve through a single helper. The data root (`$HARNESS_EVOLUTION_HOME`,
default `~/.harness-evolution/v2`) is per-deployment; the user-scope sub-agent directory is
`<DSH home>/skills/`, and the DSH home mirrors the host's `resolveDshHome` via `dsh_home()`.

## Host-agnostic core

Everything in `src/`:

- `src/mcp/` — JSON-RPC server, schema definitions, fourteen tool handlers, architecture guards.
- `src/scanner/` — plugin discovery, manifest parsing, metrics extraction; default scan roots live here.
- `src/monitor/` — performance event collection, signal detection, statistics, flush.
- `src/engine/` — proposal generation, risk analysis, planning, academic-writing evolution.
- `src/executor/` — DAG execution, sandbox validation, with state-machine guards.
- `src/factory/` — sub-agent definition factory and validation.
- `src/store/` — JSONL storage for proposals, metrics, signals, cache, execution log; path resolution lives in `paths.mbt`.
- `src/types/` — wire types, config types, agent scope, change types.
- `src/util/` — path utilities, time, wire encoding.

## How paths resolve

Two things the runtime reads from configuration:

1. **User-level sub-agent directory** (`src/store/paths.mbt::user_agents_dir`) — `HARNESS_EVOLUTION_USER_DIR` if set, otherwise `dsh_agents_dir()` = `<DSH home>/skills`. The DSH home (`dsh_home()`) resolves in three tiers: `$DSH_HOME` (blank counts as unset, non-absolute rejected) → **derived from the plugin's own install path** (`<X>/profiles/<name>/node_modules/…` → `X`, read from the child's cwd / `argv[0]`) → `~/.dsh`. The first tier mirrors the host's `resolveDshHome`; the second is what makes a hand-written mount row survivable (`scrubbedParentEnv` drops every `DSH_*`).
2. **Default plugin scan roots** (`src/scanner/scanner.mbt::default_scan_roots`) — `@store.dsh_profiles_dir()` (= `<DSH home>/profiles`, the *same* resolved home as the user directory) plus a speculative `~/.agents/plugins`. Overridable by `.dsh-plugin/plugin.json::scan_targets`, which the **shipped** manifest no longer sets (it cannot express `<DSH home>`).

The resolution priority for the user directory is `HARNESS_EVOLUTION_USER_DIR` > `dsh_agents_dir()`. The implementation is in `src/store/paths.mbt::user_agents_dir` and is unit-tested with a temporary-directory injection (the test never touches the real home).

## Where to look first when investigating path behavior

| Symptom | File |
|---|---|
| Sub-agent definition lands in the wrong directory | `src/store/paths.mbt::user_agents_dir` / `dsh_home` / `dsh_agents_dir` |
| Scan picks up the wrong set of plugins | `src/scanner/scanner.mbt::default_scan_roots` (derives from `@store.dsh_profiles_dir()`) — and, if the tree itself is wrong, `src/store/paths.mbt::dsh_home` |
| Plugin fails to load under DSH | `docs/deploy/deepseek-harness.md` — usually a launcher mechanism or a manifest dialect problem |
| Mounted tools missing after a fresh install | the row is `disabled: true` until `scripts/install-dsh.ps1` enables it for that tree |

## Changing paths

To move where user-scope definitions land, edit `dsh_home()` (or set `HARNESS_EVOLUTION_USER_DIR`);
`default_scan_roots()` follows automatically because it derives from the same resolved home. The
name/validation contract that keeps definitions discoverable by DSH is pinned in
`factory/factory_wbtest.mbt` (see "name validation enforces kebab-case").

## What "verified end-to-end" means

A host is verified when, on a fresh install, the following loop completes without intervention beyond the initial human approval:

1. `scan_plugins` returns at least one plugin in the result
2. `propose_evolution` produces a proposal with a non-empty change set
3. `approve_proposal` transitions the proposal to `approved`
4. `execute_evolution` runs the proposal to `completed`
5. `create_sub_agent(scope=user)` writes a file that the host actually loads in a subsequent session

DSH 0.1.6-alpha.1 has this. Nothing is shipped on code paths alone.

## Anti-patterns to avoid

These come from real mistakes in this repo's history. Don't repeat them:

- Hardcoding a host directory literal in more than one file. The DSH user-scope directory is `<DSH home>/skills/`, and its only two literals live side by side in `paths.mbt` (`~/.dsh` in `dsh_home`, `skills` in `dsh_agents_dir`). If you need to mention it elsewhere, reference the helper.
- Treating documentation as the source of truth for host paths. Documentation drifts. Source bundles don't.