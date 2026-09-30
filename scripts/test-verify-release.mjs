import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { mkdirSync, mkdtempSync, rmSync, utimesSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import test from 'node:test'
import { fileURLToPath } from 'node:url'

const repo = resolve(fileURLToPath(new URL('..', import.meta.url)))
const verifier = join(repo, 'scripts', 'verify-release.mjs')
const DSH_RANGE = '>=0.1.5-rc.2 <0.1.6 || >=0.1.6-alpha.1 <0.2.0'

function writeJson(path, value) {
  mkdirSync(dirname(path), { recursive: true })
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`)
}

function makeFixture(t, dshRange = DSH_RANGE) {
  const root = mkdtempSync(join(tmpdir(), 'harness-release-gate-'))
  t.after(() => rmSync(root, { recursive: true, force: true }))

  writeJson(join(root, 'package.json'), {
    name: '@across2005/harness-self-evolution',
    version: '3.2.3',
    files: ['bin/harness-evolution.exe'],
    engines: { dsh: DSH_RANGE },
  })
  writeJson(join(root, '.dsh-plugin', 'plugin.json'), {
    version: '3.2.3',
    engines: { dsh: DSH_RANGE },
  })
  for (const packageDir of ['dsh-evolution-panel', 'dsh-watcher']) {
    writeJson(join(root, packageDir, 'package.json'), {
      name: packageDir,
      version: '0.0.0',
      engines: { dsh: dshRange },
    })
  }

  writeFileSync(join(root, 'cordis.patch.yml'), '[]\n')
  writeFileSync(join(root, 'build.ps1'), '# fixture\n')
  writeFileSync(join(root, 'moon.mod'), '{}\n')
  mkdirSync(join(root, 'src'), { recursive: true })
  writeFileSync(join(root, 'src', 'main.mbt'), 'fn main {}\n')
  mkdirSync(join(root, 'bin'), { recursive: true })
  const exe = join(root, 'bin', 'harness-evolution.exe')
  writeFileSync(exe, 'fixture-binary')

  const old = new Date('2026-01-01T00:00:00Z')
  const built = new Date('2026-01-02T00:00:00Z')
  for (const path of [join(root, 'src', 'main.mbt'), join(root, 'build.ps1'), join(root, 'moon.mod')]) {
    utimesSync(path, old, old)
  }
  utimesSync(exe, built, built)
  return { root, exe }
}

function verify(root) {
  return spawnSync(process.execPath, [verifier], { cwd: root, encoding: 'utf8' })
}

test('rejects a release binary older than its build inputs', (t) => {
  const { root, exe } = makeFixture(t)
  const changed = new Date('2026-01-03T00:00:00Z')
  utimesSync(join(root, 'src', 'main.mbt'), changed, changed)
  const result = verify(root)
  assert.notEqual(result.status, 0)
  assert.match(result.stderr, /older than build input/)
})

test('accepts a release binary newer than every build input', (t) => {
  const { root, exe } = makeFixture(t)
  const newest = new Date('2026-01-04T00:00:00Z')
  utimesSync(exe, newest, newest)
  const result = verify(root)
  assert.equal(result.status, 0, result.stderr)
})

test('rejects DSH engine-range drift in an independently packed package', (t) => {
  const { root, exe } = makeFixture(t, '>=0.1.6-alpha.1 <0.2.0')
  const newest = new Date('2026-01-04T00:00:00Z')
  utimesSync(exe, newest, newest)
  const result = verify(root)
  assert.notEqual(result.status, 0)
  assert.match(result.stderr, /DSH baseline must be/)
})
