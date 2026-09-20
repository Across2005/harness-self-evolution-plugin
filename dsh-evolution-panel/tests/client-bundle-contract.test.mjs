import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

/**
 * 客户端产物的**宿主契约测试** —— 对 `lib/client.js` 这个已构建的字节做断言。
 *
 * 为什么需要它（实测 2026-09-19）：`alwaysBundle: [/^zod$/]` 一旦被删，tsdown 会把
 * `zod` 重新外部化，产物顶层出现 `require("zod")`。宿主的 `makeRequire`
 * （`@deepseek-ai/dsh-client-modules/lib/client.js` class body :337-347）只有
 * 三条解析分支 —— seed → 已物化记录 → 已注册工厂 —— 其余一律抛
 * `client-modules: require("<spec>") missed the module table …`。
 * 又因为宿主把**所有**插件的 client 产物拼成一整条 classic script（combo URL），
 * 一个产物在物化时抛错会让同 combo 的全部插件一起 `import failed`，
 * 页面显示 "Failed to load plugins"。所以这条测试守的是**整页可用性**，不是面板自己的功能。
 *
 * 已有的 `client-mount.test.mjs` 在修复前后都是绿的 —— 它把 Node 真实的
 * `createRequire` 递给工厂，`require("zod")` 在 Node 里能解析，盲区由此而生。
 * 本文件与 A3 一起把那个盲区补掉：产物字节 + 宿主同构 require。
 *
 * 注意 `deps.onlyBundle` 是**另一个方向**的守卫（防误内联），拦不住本文件守的
 * 「该内联却被外部化」，别把两者混为一谈（见 tsdown.config.ts 的注释）。
 */

const panelDir = join(dirname(fileURLToPath(import.meta.url)), '..')
const pkg = JSON.parse(readFileSync(join(panelDir, 'package.json'), 'utf8'))
const source = readFileSync(join(panelDir, 'lib/client.js'), 'utf8').replace(/\r\n/g, '\n')
const lines = source.split('\n')

const CLIENT_ID = pkg.name

/** 宿主 `makeRequire` 的第一条分支：平台 seed 表里的名字。 */
const PLATFORM_SEED_MODULES = ['react', 'react-dom', 'react/jsx-runtime']

/** 宿主 `makeRequire` 的另两条分支（已物化记录 / 已注册工厂）对应插件声明的依赖面。 */
const DECLARED_MODULE_GRAPH_ENTRIES = [
  ...(pkg.dsh?.client?.external ?? []),
  ...(pkg.dsh?.client?.inject ?? []),
]

const RESOLVABLE_BY_HOST = new Set([...PLATFORM_SEED_MODULES, ...DECLARED_MODULE_GRAPH_ENTRIES])

/** 产物里全部 `require("<spec>")` 的 spec 字面量（按出现顺序）。 */
function requiredSpecs() {
  const specs = []
  const re = /\brequire\(\s*(["'])([^"']+)\1\s*\)/g
  for (const m of source.matchAll(re)) specs.push(m[2])
  return specs
}

test('client bundle registers the Lazy-CJS factory shape the host loader requires', () => {
  assert.equal(lines[0], 'window.__ModuleLoader__.load({', 'first line must open the loader wrapper')
  assert.match(source, /\n\tfactory: \(require\) => \{/, 'must declare a factory taking require')
  assert.match(source, /\n\t\tvar module = \{ exports: \{\} \};/, 'factory must carry its own module record')
  assert.match(source, /\n\t\tvar exports = module\.exports;/, 'factory must carry its own exports alias')
  // 产物尾部还有一行 `//# sourceMappingURL=client.js.map` 注释，比较前先剥离。
  const body = source.replace(/\n?\/\/# sourceMappingURL=[^\n]*\n?$/, '').trimEnd()
  assert.ok(
    body.endsWith('\t\treturn module.exports;\n\t}\n});'),
    'bundle must close the wrapper by returning the module exports',
  )

  // id 必须与 package.json 的 name 逐字相同：宿主按 module graph row 的 id 注册工厂，
  // 不一致会导致注册落空（页面报未激活的 entry）。
  const idLine = lines.find((l) => /^\s*id:/.test(l))
  assert.ok(idLine, 'wrapper must carry an id')
  assert.equal(JSON.parse(idLine.replace(/^\s*id:\s*/, '').replace(/,\s*$/, '')), CLIENT_ID)
})

test('client bundle contains no top-level ESM syntax', () => {
  // 宿主把每个插件的 client 产物拼成**一整条** classic script（`/plugins/??...` combo），
  // 任一产物出现顶层 export/import 会让整条 combo 解析失败（`SyntaxError: Unexpected token 'export'`），
  // 同 combo 的所有插件一起报 `import failed`。产物必须是纯 CJS 叶子。
  const offenders = lines
    .map((text, i) => ({ text, line: i + 1 }))
    .filter(({ text }) => /^(export|import)\b/.test(text))
  assert.deepEqual(
    offenders,
    [],
    `top-level ESM syntax breaks the whole plugin combo: ${JSON.stringify(offenders)}`,
  )
})

test('client bundle only requires modules the host module table can resolve', () => {
  const specs = requiredSpecs()
  const unresolvable = specs.filter((spec) => !RESOLVABLE_BY_HOST.has(spec))
  assert.deepEqual(
    unresolvable,
    [],
    `host makeRequire has only seed → materialized → registered-factory; ` +
      `these would throw "missed the module table" and take the whole combo down: ${JSON.stringify(unresolvable)}`,
  )

  // ★ 这条才是 2026-09-19 事故的直接守卫：生产依赖（`dependencies`）必须被内联，
  // 宿主模块表里**没有**它们的名字 —— 出现在 require 里就一定解析不到。
  const dependencyKeys = Object.keys(pkg.dependencies ?? {})
  const leaked = specs.filter((spec) => dependencyKeys.includes(spec))
  assert.deepEqual(
    leaked,
    [],
    `production dependencies must be inlined (deps.alwaysBundle), never required at runtime: ${JSON.stringify(leaked)}`,
  )
})

test('client bundle inlines every production dependency', () => {
  // 与上一条互为表里：上一条禁止 require 它们，这一条要求它们确实躺在产物里。
  for (const name of Object.keys(pkg.dependencies ?? {})) {
    assert.ok(
      source.includes(`node_modules/${name}/`),
      `${name} is declared in dependencies but no inlined region of it exists in the bundle`,
    )
  }
})