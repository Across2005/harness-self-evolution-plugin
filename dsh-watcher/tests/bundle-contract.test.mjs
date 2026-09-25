import test from 'node:test'
import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

/**
 * The host and client halves have deliberately different module contracts:
 * the host is ordinary ESM, while the browser half is a Lazy-CJS factory whose
 * external requires are resolved from DSH's seeded module table.
 */
const watcherDir = join(dirname(fileURLToPath(import.meta.url)), '..')
const pkg = JSON.parse(readFileSync(join(watcherDir, 'package.json'), 'utf8'))
const client = readFileSync(join(watcherDir, 'lib/client.js'), 'utf8').replace(/\r\n/g, '\n')
const host = readFileSync(join(watcherDir, 'lib/dsh-watcher.js'), 'utf8').replace(/\r\n/g, '\n')
const lines = client.split('\n')

const platformSeeds = new Set(['react', 'react-dom', 'react/jsx-runtime'])
const declaredModules = new Set([
  ...(pkg.dsh?.client?.inject ?? []),
  ...(pkg.dsh?.client?.external ?? []),
])

function requiredSpecs() {
  return [...client.matchAll(/\brequire\(\s*(["'])([^"']+)\1\s*\)/g)].map((m) => m[2])
}

test('watcher host output is ESM and client output is a Lazy-CJS factory', () => {
  assert.match(host, /^import .* from /m, 'host entry must remain an ordinary ESM bundle')
  assert.equal(lines[0], 'window.__ModuleLoader__.load({')
  assert.match(client, /\n\tfactory: \(require\) => \{/)
  assert.match(client, /\n\t\tvar module = \{ exports: \{\} \};/)
  assert.match(client, /\n\t\tvar exports = module\.exports;/)
  const body = client.replace(/\n?\/\/# sourceMappingURL=[^\n]*\n?$/, '').trimEnd()
  assert.ok(body.endsWith('\t\treturn module.exports;\n\t}\n});'))
  const idLine = lines.find((line) => /^\s*id:/.test(line))
  assert.ok(idLine)
  assert.equal(JSON.parse(idLine.replace(/^\s*id:\s*/, '').replace(/,\s*$/, '')), 'dsh-watcher')
})

test('watcher CSS is embedded and idempotently installed inside the factory', () => {
  assert.match(client, /data-plugin-css/)
  assert.match(client, /dataset\.pluginCss/)
  assert.match(client, /style\.textContent/)
  assert.match(client, /dsh-watcher/)
  assert.equal(existsSync(join(watcherDir, 'lib/style.css')), false)
})

test('watcher client source map keeps the generated line count aligned', () => {
  const map = JSON.parse(readFileSync(join(watcherDir, 'lib/client.js.map'), 'utf8'))
  assert.equal(map.mappings.split(';').length, lines.length)
})
test('watcher client has no top-level ESM syntax', () => {
  const offenders = lines
    .map((text, index) => ({ text, line: index + 1 }))
    .filter(({ text }) => /^(export|import)\b/.test(text))
  assert.deepEqual(offenders, [])
})

test('watcher client requires only host-resolvable modules', () => {
  const unresolved = requiredSpecs().filter((spec) => !platformSeeds.has(spec) && !declaredModules.has(spec))
  assert.deepEqual(unresolved, [])
  const production = Object.keys(pkg.dependencies ?? {})
  assert.deepEqual(requiredSpecs().filter((spec) => production.includes(spec)), [])
})

test('watcher package exports the clean tsc declaration tree', () => {
  const rootTypes = join(watcherDir, pkg.exports['.'].types)
  const clientTypes = join(watcherDir, pkg.exports['./client'].types)
  assert.ok(existsSync(rootTypes), `missing host declaration: ${pkg.exports['.'].types}`)
  assert.ok(existsSync(clientTypes), `missing client declaration: ${pkg.exports['./client'].types}`)
  assert.doesNotMatch(readFileSync(clientTypes, 'utf8'), /window\.__ModuleLoader__/)
  assert.equal(existsSync(join(watcherDir, 'lib/client.d.ts')), false)
})
