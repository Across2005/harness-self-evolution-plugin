import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

/**
 * 回归（实测 2026-09-18）：面板点开报
 * `Cannot read properties of undefined (reading 'watch')` —— 客户端命名空间面
 * 由**贡献挂载**建出（`ctx.remote.$mount`），宿主服务本身不产生它。
 * 这条用例在 Node 里执行真实客户端 bundle，钉住「先挂载、再注册按钮」与贡献形状。
 */

const panelDir = join(dirname(fileURLToPath(import.meta.url)), '..')
const req = createRequire(join(panelDir, 'package.json'))

function loadClientBundle() {
  let factory
  globalThis.window = { __ModuleLoader__: { load: (m) => { factory = m.factory } } }
  new Function('window', readFileSync(join(panelDir, 'lib/client.js'), 'utf8'))(globalThis.window)
  assert.equal(typeof factory, 'function', 'client bundle must register a Lazy-CJS factory')
  return factory
}

test('client apply mounts the remote contribution before registering the header button', async () => {
  const mod = loadClientBundle()(req)
  assert.equal(typeof mod.apply, 'function')

  const calls = []
  let mounted = null
  const ctx = {
    remote: {
      $mount: async (contribution) => {
        mounted = contribution
        calls.push('mount')
        return async () => {}
      },
      evolution: { snapshot: async () => ({}), watch: () => (async function* () {})() },
    },
    slots: {
      inject: (slotName, cb) => {
        calls.push(`inject:${slotName}`)
        cb()
      },
      register: (spec) => {
        calls.push(`register:${spec.id}`)
      },
    },
  }

  const dispose = await mod.apply(ctx)
  assert.equal(typeof dispose, 'function', 'apply must return a disposer')
  assert.deepEqual(calls, [
    'mount',
    'inject:conversation.session.header.utilities',
    'register:dsh-evolution-panel',
  ])

  assert.equal(mounted.package, 'dsh-evolution-panel')
  assert.deepEqual(
    mounted.descriptors.map((d) => `${d.namespace}/${d.method}`),
    ['evolution/snapshot', 'evolution/watch'],
  )
  for (const d of mounted.descriptors) {
    assert.equal(d.service, 'evolutionRuntime')
    assert.equal(d.invocation.kind, 'direct')
    assert.deepEqual(d.parameters, [])
    assert.equal(typeof d.id, 'string')
    assert.ok(d.result && d.result.schema, 'every descriptor needs a result codec')
  }
  assert.equal(mounted.descriptors[1].mode, 'stream')
  assert.equal(mounted.descriptors[0].mode, undefined)
})
