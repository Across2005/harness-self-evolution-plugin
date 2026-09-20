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
 *
 * ★ 2026-09-19 加固：原先这里把 Node 真实的 `createRequire` 交给工厂，
 * 于是产品里任何 `require("zod")` 在 Node 下都能解析 —— 那次
 * 「zod 被外部化 → 产物顶层 require("zod") → 整页 Failed to load plugins」
 * 的事故发生时本用例仍然全绿。现在换成**宿主同构的 require 存根**：
 * 只解析平台 seed 表 + 已物化记录，其余抛与宿主逐字同款的
 * `missed the module table`，让产物漂移在本用例里就能变红。
 */

const panelDir = join(dirname(fileURLToPath(import.meta.url)), '..')
const nodeRequire = createRequire(join(panelDir, 'package.json'))

/** 宿主 `makeRequire` 的第一条分支：平台 seed 表（静态注入的 React 等单例）。 */
const PLATFORM_SEED_MODULES = new Set(['react', 'react-dom', 'react/jsx-runtime'])

/**
 * 宿主 `makeRequire` 的同构替身（契约来源：`@deepseek-ai/dsh-client-modules/lib/client.js`
 * 的 `makeRequire`，三条分支 —— seed → 已物化记录 → 已注册工厂）。
 * 这里没有「已注册工厂」这一支：单测里没有别的插件产物，任何非 seed 的名字都该走
 * 与宿主相同的失败路径。
 */
function hostRequire() {
  const materialized = new Map()
  return (spec) => {
    if (materialized.has(spec)) return materialized.get(spec)
    if (PLATFORM_SEED_MODULES.has(spec)) {
      // seed 词在宿主体内就是真实单例；在 Node 里用真实包顶上，语义等价。
      const mod = nodeRequire(spec)
      materialized.set(spec, mod)
      return mod
    }
    throw new Error(
      `client-modules: require("${spec}") missed the module table — not a platform seed word, ` +
        'not a materialized module, and no registered package factory',
    )
  }
}

function loadClientBundle() {
  let factory
  globalThis.window = { __ModuleLoader__: { load: (m) => { factory = m.factory } } }
  new Function('window', readFileSync(join(panelDir, 'lib/client.js'), 'utf8'))(globalThis.window)
  assert.equal(typeof factory, 'function', 'client bundle must register a Lazy-CJS factory')
  return factory
}

test('client apply mounts the remote contribution before registering the header button', async () => {
  const mod = loadClientBundle()(hostRequire())
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
