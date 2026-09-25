import assert from 'node:assert/strict'
import { copyFileSync, existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { spawn, spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { isExactDshVersion } from './dsh-version.mjs'

/**
 * Desktop-host coexistence smoke test.
 *
 * This never opens a browser and never mutates the active DSH tree. It creates
 * a custom profile under a temporary DSH_HOME, preserves a complete
 * `mcp-headroom` row, runs the real installer, and boots the DSH desktop CLI
 * with `--no-open`. A tiny profile-local probe reads the live tool registry and
 * records both server-qualified namespaces.
 *
 * The `headroom` row uses a second copy of the native MCP executable as a
 * deterministic stand-in for an external headroom server. That keeps this test
 * about DSH's coexistence contract (two complete stdio rows and two distinct
 * serverName namespaces), rather than depending on a package that is not
 * published or installed on the test machine.
 */

const repo = resolve(fileURLToPath(new URL('..', import.meta.url)))
const cli = process.env.DSH_CLI ?? process.env.DSH_BIN ?? 'dsh'
const cliIsJavaScript = /\.[cm]?js$/i.test(cli)
const expectedVersion = process.env.DSH_EXPECTED_VERSION?.trim()
const node = process.execPath
const root = mkdtempSync(join(tmpdir(), 'harness-dsh-coexistence-'))
const profile = 'coexistence-smoke'
const profileDir = join(root, 'profiles', profile)
const installedDir = join(profileDir, 'node_modules', '@across2005', 'harness-self-evolution')
const nativeExe = join(installedDir, 'bin', 'harness-evolution.exe')
const patchPath = join(profileDir, 'cordis.patch.yml')
const toolMarker = join(root, 'tool-namespaces.jsonl')
const headroomRoot = join(root, '.harness-evolution-headroom', 'v2')
const harnessRoot = join(root, '.harness-evolution', 'v2')
const env = {
  ...process.env,
  DSH_HOME: root,
  DSH_TELEMETRY_MODE: 'OFF',
  // DSH's bundled package bootstrap passes vendor-specific npm keys that npm
  // reports as unknown; keep the coexistence smoke focused on its own result.
  NPM_CONFIG_LOGLEVEL: process.env.NPM_CONFIG_LOGLEVEL ?? 'silent',
}
for (const key of ['npm_config_side_effects_cache', 'pnpm_config_side_effects_cache']) {
  delete env[key]
}

const q = (value) => `'${String(value).replaceAll('\\', '/').replaceAll("'", "''")}'`
const native = (value) => String(value).replaceAll('\\', '/')
const run = (command, args, options = {}) => {
  const result = spawnSync(command, args, { encoding: 'utf8', env, ...options })
  if (result.error) throw result.error
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(' ')} exited ${result.status}\n${result.stdout}\n${result.stderr}`)
  }
  return result
}
const nativeShell = process.platform === 'win32' && !/\.(?:exe|com)$/i.test(cli)
const dsh = (...args) => cliIsJavaScript
  ? run(node, [cli, ...args])
  : run(cli, args, nativeShell ? { shell: true } : {})
const desktopCommand = () => cliIsJavaScript
  ? { command: node, args: (args) => [cli, ...args] }
  : { command: cli, args: (args) => args }

function row({ id, serverName, command, cwd, dataRoot, disabled = false }) {
  return [
    `- id: ${id}`,
    "  name: '@deepseek-ai/dsh-mcp-client'",
    `  disabled: ${disabled}`,
    '  config:',
    '    transport: stdio',
    `    serverName: ${serverName}`,
    `    command: ${q(command)}`,
    '    args: []',
    `    cwd: ${q(cwd)}`,
    '    env:',
    `      DSH_HOME: ${q(root)}`,
    `      HARNESS_EVOLUTION_HOME: ${q(dataRoot)}`,
    '    failOnStartupError: true',
  ].join('\n')
}

function install(args) {
  const installer = join(repo, 'scripts', 'install-dsh.ps1')
  const command = process.env.PWSH ?? 'pwsh'
  return run(command, [
    '-NoProfile',
    '-File', installer,
    '-Profile', profile,
    '-DshHome', root,
    '-RepoRoot', repo,
    '-SkipPluginAdd',
    ...args,
  ])
}

function waitForToolMarker(timeoutMs = 45_000) {
  const deadline = Date.now() + timeoutMs
  while (Date.now() < deadline) {
    if (existsSync(toolMarker)) {
      const lines = readFileSync(toolMarker, 'utf8').trim().split(/\r?\n/).filter(Boolean)
      for (let index = lines.length - 1; index >= 0; index--) {
        try {
          const value = JSON.parse(lines[index])
          if (Array.isArray(value) && value.some((name) => name.startsWith('mcp__headroom__')) && value.some((name) => name.startsWith('mcp__harness-evolution__'))) return value
        } catch {
          // A partially written line is not a readiness signal.
        }
      }
    }
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 50)
  }
  return undefined
}

let desktop
try {
  if (cliIsJavaScript) assert.ok(existsSync(cli), `DSH CLI script not found: ${cli}; set DSH_CLI or put dsh on PATH`)
  // A bare `dsh` command is resolved by spawnSync below; fail with a useful
  // platform error rather than asserting that a command name is a file path.
  assert.ok(existsSync(join(repo, 'bin', 'harness-evolution.exe')), 'build the native binary first: build.ps1 -Task build')
  if (expectedVersion) {
    const version = dsh('--version').stdout.trim()
    assert.ok(isExactDshVersion(version, expectedVersion), `DSH CLI reported ${version}; expected exact version ${expectedVersion}`)
  }

  // Initialize a custom profile from the shipped web bundle without touching
  // the GUI's active profile.
  dsh('--profile', profile, '--from-default-profile', 'web', '--dump-config')
  mkdirSync(join(installedDir, 'bin'), { recursive: true })
  copyFileSync(join(repo, 'bin', 'harness-evolution.exe'), nativeExe)

  const headroom = row({
    id: 'mcp-headroom',
    serverName: 'headroom',
    command: nativeExe,
    cwd: installedDir,
    dataRoot: headroomRoot,
  })
  const baseHarness = row({
    id: 'mcp-harness-evolution',
    serverName: 'harness-evolution',
    command: nativeExe,
    cwd: installedDir,
    dataRoot: harnessRoot,
    disabled: true,
  })
  const insert = (entry) => `- insert:\n${entry.split('\n').map((line) => `  ${line}`).join('\n')}`
  const headroomPatch = insert(headroom)
  const original = readFileSync(patchPath, 'utf8').replace(/^[ \t]*\[\][ \t]*\r?\n?/m, '')
  writeFileSync(patchPath, `${original.trimEnd()}\n${headroomPatch}\n${insert(baseHarness)}\n`)

  // The installer must preserve the complete external row byte-for-byte and
  // add only its marker block.
  install([])
  const afterInstall = readFileSync(patchPath, 'utf8')
  assert.ok(afterInstall.includes(headroomPatch), 'installer changed the complete mcp-headroom row')
  assert.match(afterInstall, /# >>> mcp-harness-evolution \(install-dsh\.ps1\) >>>/)
  assert.match(afterInstall, /serverName: harness-evolution/)

  // The effective profile must compose both rows, with the installer override
  // enabling the harness row.
  const dump = dsh('--profile', profile, '--dump-config').stdout
  assert.match(dump, /- id: mcp-headroom[\s\S]*serverName: headroom/)
  assert.match(dump, /- id: mcp-harness-evolution[\s\S]*serverName: harness-evolution/)
  assert.match(dump, /disabled: false/)

  // A profile-local probe observes the actual ToolRuntime, not merely the YAML.
  const probeDir = join(profileDir, 'node_modules', 'mcp-namespace-probe')
  mkdirSync(probeDir, { recursive: true })
  writeFileSync(join(probeDir, 'package.json'), JSON.stringify({ name: 'mcp-namespace-probe', version: '1.0.0', type: 'module', main: 'index.js' }))
  writeFileSync(join(probeDir, 'index.js'), [
    "import { appendFileSync } from 'node:fs'",
    `const marker = ${JSON.stringify(toolMarker)}`,
    'export function apply(ctx) {',
    "  ctx.inject(['tools'], scope => {",
    '    let attempts = 0',
    '    const poll = () => {',
    '      try {',
    '        const names = scope.tools.schemas().map(schema => schema.name)',
    "        if (names.some(name => name.startsWith('mcp__headroom__')) && names.some(name => name.startsWith('mcp__harness-evolution__'))) { appendFileSync(marker, JSON.stringify(names) + '\\n'); return }",
    '        if (attempts++ > 20000) { appendFileSync(marker, JSON.stringify(names) + "\\n"); return }',
    '      } catch {',
    '        if (attempts++ > 20000) return',
    '        setImmediate(poll)',
    '        return',
    '      }',
    '      setImmediate(poll)',
    '    }',
    '    poll()',
    '  })',
    '}',
  ].join('\n') + '\n')
  const profileManifestPath = join(profileDir, 'package.json')
  const profileManifest = JSON.parse(readFileSync(profileManifestPath, 'utf8'))
  profileManifest.dependencies = { ...(profileManifest.dependencies ?? {}), 'mcp-namespace-probe': '1.0.0' }
  writeFileSync(profileManifestPath, JSON.stringify(profileManifest, null, 2) + '\n')
  const bootPatch = readFileSync(patchPath, 'utf8')
  writeFileSync(patchPath, `${bootPatch.trimEnd()}\n- insert:\n    - id: mcp-namespace-probe\n      name: mcp-namespace-probe\n`)

  let output = ''
  const launcher = desktopCommand()
  desktop = spawn(launcher.command, launcher.args(['--profile', profile, '--no-open', '--port', '0']), {
    env,
    stdio: ['ignore', 'pipe', 'pipe'],
    shell: !cliIsJavaScript && nativeShell,
  })
  desktop.stdout.on('data', chunk => { output += chunk })
  desktop.stderr.on('data', chunk => { output += chunk })

  const names = waitForToolMarker()
  assert.ok(names, `desktop boot did not expose both MCP namespaces\n${output}`)
  assert.ok(names.includes('mcp__headroom__scan_plugins'))
  assert.ok(names.includes('mcp__harness-evolution__scan_plugins'))
  // The live registry is the activation criterion; native server diagnostics
  // are intentionally not used as a second readiness signal.

  // Uninstall is also part of the coexistence contract: the external row is
  // not collateral damage.
  install(['-Uninstall'])
  const afterUninstall = readFileSync(patchPath, 'utf8')
  assert.ok(afterUninstall.includes(headroomPatch), 'uninstall removed or changed mcp-headroom')
  assert.doesNotMatch(afterUninstall, /# >>> mcp-harness-evolution \(install-dsh\.ps1\) >>>/)

  console.log(`PASS: desktop DSH ${native(cli)} booted mcp-headroom + mcp-harness-evolution with distinct namespaces (${names.length} tools)`)
} finally {
  if (desktop && desktop.exitCode === null) {
    await new Promise((resolveExit) => {
      if (desktop.exitCode !== null) {
        resolveExit()
        return
      }
      desktop.once('exit', resolveExit)
      desktop.kill()
    })
  }
  if (process.platform === 'win32' && desktop?.pid) {
    spawnSync('taskkill', ['/PID', String(desktop.pid), '/T', '/F'], { stdio: 'ignore' })
  }
  if (process.env.KEEP_DSH_COEXISTENCE !== '1') rmSync(root, { recursive: true, force: true })
  else console.log(`kept ${root}`)
}
