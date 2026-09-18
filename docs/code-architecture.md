# Code architecture: shared core + per-host split-path loading

This doc is for readers who want to understand how the plugin supports two AI harness hosts from a single binary, and for new contributors adding host support.

## The one-line principle

The binary is the same for every host. What changes per host is the launcher, the supplementary files alongside the binary, and the paths inside the runtime that are read from `HARNESS_EVOLUTION_HOST`.

## What the runtime tells the operator about host verification

At boot, after the unknown-host warning, `main.mbt::main` calls `host_verification_notice()` (in `src/store/paths.mbt`) and writes the result to the boot log. The wording is not decorative:

- **DSH**: `Host: DeepSeek Harness ≥ 0.1.6 — verified end-to-end 2026-09-17 (web profile, propose→approve→execute loop + user-scope skill hot discovery).`
- **Minimax Code**: `Host: Minimax Code — verified end-to-end 2026-09-17 (MCP server + Plugin V1 + Mini App floating panel with 14-tool live grid).`
- **Unknown host**: no notice (handled by `unknown_host_warning`; do not double-warn).

The matrix is pinned by a regression test (`host verification notice reflects the current verification matrix`, in `src/store/store_wbtest.mbt`). Both recognized hosts are already verified end-to-end, so when you add a host or re-verify one, two files change in lockstep:

1. `src/store/paths.mbt::host_verification_notice` — write the `verified ...` wording, quoting the date and the specific behaviors you exercised
2. `src/store/store_wbtest.mbt` — the test asserts the exact wording, so it will fail at your change and force you to update the assertion alongside

Do not change one without the other. The test exists to make that mistake expensive.

Everything in `src/` except the small handful of files listed in the next section:

- `src/mcp/` — JSON-RPC server, schema definitions, fourteen tool handlers, architecture guards. Host-agnostic.
- `src/scanner/` — plugin discovery, manifest parsing, metrics extraction. The *logic* is host-agnostic; only the *default scan roots* change per host.
- `src/monitor/` — performance event collection, signal detection, statistics, flush.
- `src/engine/` — proposal generation, risk analysis, planning, academic-writing evolution.
- `src/executor/` — DAG execution, sandbox validation, with state-machine guards.
- `src/factory/` — sub-agent definition factory and validation.
- `src/store/` — JSONL storage for proposals, metrics, signals, cache, execution log. The data file layout is host-agnostic; the *data root* (`$HARNESS_EVOLUTION_HOME`, default `~/.harness-evolution/v2`) is per-deployment, not per-host.
- `src/types/` — wire types, config types, agent scope, change types.
- `src/util/` — path utilities, time, wire encoding.

If you are reading any file in those directories and you see `HARNESS_EVOLUTION_HOST` mentioned, stop — that file is in the next group.

## What changes per host

Three things, all small:

1. **User-level sub-agent directory** (`src/store/paths.mbt::host_agents_dir`)
2. **Default plugin scan roots** (`src/scanner/scanner.mbt::default_scan_roots`)
3. **Launcher and supplementary files** — these live *outside* `src/`, in the deployment directory

The runtime picks the host at startup. Two env vars control the split:

- `HARNESS_EVOLUTION_HOST` — `deepseek-harness` (default) or `minimax-code`. Unknown values log a warning and fall back to the DSH path.
- `HARNESS_EVOLUTION_USER_DIR` — explicit override for the user-scope sub-agent directory. When set, it wins over `HARNESS_EVOLUTION_HOST`. Use this when a host's user directory is in a non-standard location (CI, containerized installs, multi-profile setups).

The resolution priority is `HARNESS_EVOLUTION_USER_DIR` > `HARNESS_EVOLUTION_HOST` > default DSH. The implementation is in `src/store/paths.mbt::user_agents_dir` and is unit-tested with a temporary directory injection (the test never touches the real home).

## Where to look first when investigating host behavior

| Symptom | File |
|---|---|
| Sub-agent definition lands in the wrong directory | `src/store/paths.mbt::host_agents_dir` and `user_agents_dir` |
| Scan picks up the wrong set of plugins | `src/scanner/scanner.mbt::default_scan_roots` and the `scan_targets` block in `.dsh-plugin/plugin.json` |
| Plugin fails to load on a host | The deploy guide for that host — usually a launcher mechanism or a manifest dialect problem |
| Unknown host value silently falls back | `src/store/paths.mbt::unknown_host_warning`, surfaced via `src/harness_evolution/main.mbt::main` |

## Adding a new host

Four files to edit, in this order:

1. **`src/store/paths.mbt::host_agents_dir`** — add a `match` arm returning the host's user-level sub-agent directory. The MoonBit compiler will fail the match-exhaustiveness check at every call site that uses the return type, so you cannot forget this step.
2. **`src/scanner/scanner.mbt::default_scan_roots`** — add the host's plugin scan roots. Order matters: put the most-likely-to-exist roots first.
3. **`.dsh-plugin/plugin.json::scan_targets`** — add the same roots to the manifest so `ScanConfig::from_plugin_json` reads them at boot. Without this, the runtime will warn and fall back to the hardcoded defaults.
4. **`src/store/paths.mbt::unknown_host_warning`** — update the supported-values list in the warning message.

Then write a deploy guide under `docs/deploy/<host>.md` modeled on `docs/deploy/mavis.md`. The guide should state the verification status, list the paths the host actually uses (from the host's source bundles, not from documentation), and end with verification steps.

## What "verified end-to-end" means

A host is verified when, on a fresh install, the following loop completes without intervention beyond the initial human approval:

1. `scan_plugins` returns at least one plugin in the result
2. `propose_evolution` produces a proposal with a non-empty change set
3. `approve_proposal` transitions the proposal to `approved`
4. `execute_evolution` runs the proposal to `completed`
5. `create_sub_agent(scope=user)` writes a file that the host actually loads in a subsequent session

DSH 0.1.6-alpha.1 and Minimax Code both have this. No host is shipped on code paths alone.

## Anti-patterns to avoid

These come from real mistakes in this repo's history. Don't repeat them:

- Hardcoding a host directory literal in more than one file. `~/.dsh/skills/` is the single canonical spot. If you need to mention it elsewhere, reference the helper.
- Treating documentation as the source of truth for host paths. Documentation drifts. Source bundles don't.
- Adding a host to the README before the code path exists. Add the match arm first, then the README claim.
- Adding a host to the README without a deploy guide. Users will not know how to install.
- Hiding a host's verification status. Every host in the README has actually completed the loop above; a host that has not is not listed, and the README says so.