import { spawnSync } from 'node:child_process'
import { existsSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

/**
 * Workspace release gate.
 *
 * The native package, panel, and watcher are independently consumable DSH
 * plugins. A root-only binary check is therefore not enough to call the
 * workspace ready: this gate runs all three build/test contracts and dry-run
 * package checks. Both required desktop runtimes are exercised: DSH_CLI is
 * the baseline and DSH_REGRESSION_CLI is the alpha runtime.
 */
const root = resolve(fileURLToPath(new URL('..', import.meta.url)))
const env = {
  ...process.env,
  // Keep package-manager bootstrap diagnostics out of the release gate unless
  // the caller explicitly asks for a different npm log level.
  NPM_CONFIG_LOGLEVEL: process.env.NPM_CONFIG_LOGLEVEL ?? 'silent',
}
// npm 24 warns about this legacy key even when it is inherited from the host.
// It is not used by this workspace; do not pass it to npm, pnpm, or DSH children.
for (const key of ['npm_config_side_effects_cache', 'pnpm_config_side_effects_cache']) {
  delete env[key]
}
const powershell = process.platform === 'win32' ? 'pwsh.exe' : 'pwsh'
const npm = process.platform === 'win32' ? 'npm.cmd' : 'npm'
const pnpm = process.platform === 'win32' ? 'pnpm.cmd' : 'pnpm'

function run(label, command, args, options = {}) {
  console.log(`\n[workspace-gate] ${label}`)
  const isWindowsShim = process.platform === 'win32' && (command === npm || command === pnpm)
  const actualCommand = isWindowsShim ? (env.ComSpec ?? 'cmd.exe') : command
  const actualArgs = isWindowsShim ? ['/d', '/c', command, ...args] : args
  const capture = options.capture === true
  const result = spawnSync(actualCommand, actualArgs, {
    cwd: options.cwd ?? root,
    env: { ...env, ...(options.env ?? {}) },
    stdio: capture ? ['ignore', 'pipe', 'pipe'] : 'inherit',
    maxBuffer: 16 * 1024 * 1024,
    shell: false,
  })
  const rawOutput = capture ? `${result.stdout ?? ''}${result.stderr ?? ''}` : ''
  if (capture) {
    const cleanOutput = rawOutput
      .split(/\r?\n/)
      .filter((line) => !/^npm warn Unknown env config "(?:npm-globalconfig|verify-deps-before-run|_jsr-registry)"/.test(line.trim()))
      .join('\n')
      .trim()
    if (cleanOutput) process.stdout.write(`${cleanOutput}\n`)
  }
  if (result.error) throw result.error
  if (result.status !== 0) {
    throw new Error(`${label} failed with exit ${result.status}${rawOutput.trim() ? `\n${rawOutput.trim()}` : ''}`)
  }
}

run('MoonBit T0/T1/T2', powershell, ['-NoProfile', '-File', 'build.ps1', '-Task', 'all'])
run('native release metadata', process.execPath, ['scripts/verify-release.mjs'])
run('DSH version matcher tests', process.execPath, ['--test', 'scripts/test-dsh-version.mjs'])
run('installer patch regression', powershell, ['-NoProfile', '-File', 'scripts/test-install-dsh.ps1'])
const panelDir = join(root, 'dsh-evolution-panel')
const watcherDir = join(root, 'dsh-watcher')
run('panel clean build and tests', npm, ['test'], { cwd: panelDir })
run('panel package dry-run', npm, ['pack', '--dry-run'], { cwd: panelDir })
run('watcher clean build and tests', pnpm, ['test'], { cwd: watcherDir })
run('watcher package dry-run', pnpm, ['pack', '--dry-run'], { cwd: watcherDir })

const baselineCli = process.env.DSH_CLI
const regressionCli = process.env.DSH_REGRESSION_CLI ?? process.env.DSH_CLI_REGRESSION
if (!baselineCli || !regressionCli) {
  throw new Error('DSH_CLI and DSH_REGRESSION_CLI are required for the workspace gate')
}
run('desktop MCP coexistence — DSH 0.1.5-rc.2 baseline', process.execPath, ['scripts/test-dsh-mcp-coexistence.mjs'], {
  env: { DSH_CLI: baselineCli, DSH_EXPECTED_VERSION: '0.1.5-rc.2' },
  capture: true,
})
run('desktop MCP coexistence — DSH 0.1.6-alpha.1 regression', process.execPath, ['scripts/test-dsh-mcp-coexistence.mjs'], {
  env: { DSH_CLI: regressionCli, DSH_EXPECTED_VERSION: '0.1.6-alpha.1' },
  capture: true,
})

if (!existsSync(join(root, 'bin', 'harness-evolution.exe'))) {
  throw new Error('workspace gate completed without the native release binary')
}
console.log('\n[workspace-gate] PASS: all available workspace contracts passed')
