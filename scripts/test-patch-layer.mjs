// scripts/test-patch-layer.mjs
// ─────────────────────────────────────────────────────────────────────────────
// 回归验证器：证明 install-dsh.ps1 产出的 profile patch 层是**宿主真能解析**的 YAML。
//
// 为什么必须用宿主自己的解析器（而不是「看起来对」）：
//   宿主解析 patch 层走的是 `js-yaml` ——
//     `import * as yaml from "js-yaml"`（dsh-app-boot/lib/index.js:6）
//     `parsed = yaml.load(content, { schema: userPatchesSchema })`  (:2161, `parsePatchList`)
//   解析失败是 **throw**，一路上抛到 prepareProfile → profile **完全无法 boot**
//   （不只是插件不挂载）。2026-09-22 复验发现的阻塞缺陷正是如此：出厂空模板的 `[]`
//   （flow 序列）后面被追加了块序列项 `- id: …`，宿主直接
//       YAMLException: end of the stream or a document separator is expected (6:1)
//   本脚本用**同一个 `js-yaml` 包、同一个 `load` API** 做同一件事，把这条判据机器化。
//
// 为什么钉住 `js-yaml` 而不是 `yaml`（★ 一次真实的踩坑，留作维护提示）：
//   本机 runtime 的 `node_modules` 下**同时**存在 `yaml@2.9.1` 与 `js-yaml@4.3.2`。
//   `yaml`（eemeli/yaml）v2 的 ESM 命名空间**没有** `load`，只有 `parse`；
//   而宿主用的是 `js-yaml` 的 `load`。若验证器误取 `yaml`，会得到
//   `TypeError: yaml.load is not a function` —— 一个「验证器坏了」而不是「产物坏了」的
//   假阴性。故这里显式要求 `js-yaml`，并把它写进输出，便于日后核对。
//
// 用法（由 scripts/test-install-dsh.ps1 调用；也可单独对一个文件跑）：
//   node scripts/test-patch-layer.mjs <patch.yml> [--expect-empty] [--quiet]
//
// 退出码：0 = 全部断言通过；1 = 有断言失败（打印每条失败原因）；2 = 用法/环境错误。
//
// 断言清单（每条都对应一个真实会打挂宿主或静默失效的形态）：
//   A. 解析成功，且顶层是**数组**（`parsePatchList` 的第二个 throw 点 :2165）
//   B. 每个元素是**映射**（第三个 throw 点 :2167）
//   C. 不存在「裸 `[]` 独占一行」—— 历史缺陷的确切形状
//   D. `mcp-harness-evolution` 行**恰好一条**（重复 id 会让 Loader 报 duplicate entry id）
//   E. 该行的 id 定向覆盖形态正确：`disabled: false`、`config` 是**映射**、
//      command/cwd 是绝对路径且指向该 profile 的安装位、`env.DSH_HOME` 已给出
//   F. `config.command` / `config.cwd` / `config.env.DSH_HOME` 与安装器算出的值逐字一致
//      （由 --expect-* 参数传入；不传则只做形状检查）
//
// 词汇说明：这里的「id 定向覆盖行」= DSH patch 语义下 `id` 命中既有 entry 后逐字段
// `target[key] = value` 的那条 patch entry（不是 `insert`）。
// ─────────────────────────────────────────────────────────────────────────────

import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import { isAbsolute, join } from 'node:path'

// ---- 0. 解析参数 ------------------------------------------------------------

const argv = process.argv.slice(2)
const flags = new Set(argv.filter((a) => a.startsWith('--')))
const positional = argv.filter((a) => !a.startsWith('--'))

function opt(name) {
  const hit = argv.find((a) => a.startsWith(`--${name}=`))
  return hit === undefined ? undefined : hit.slice(name.length + 3)
}

const patchPath = positional[0]
if (patchPath === undefined) {
  console.error('usage: node scripts/test-patch-layer.mjs <patch.yml> [--expect-command=<abs>] [--expect-cwd=<abs>] [--expect-dsh-home=<abs>] [--expect-empty] [--quiet]')
  process.exit(2)
}
const quiet = flags.has('--quiet')
// `--expect-empty`：用于 -Uninstall 之后的状态 —— 只要求「仍是宿主可解析的 YAML」且
// **不含**本插件的行。卸载后不该再留下挂载行，但**必须**留下合法 YAML：留下的裸 `[]`
// 或残块同样会让 profile 无法 boot（卸载路径与安装路径受同一条不变量的约束）。
const expectEmpty = flags.has('--expect-empty')
const expectCommand = opt('expect-command')
const expectCwd = opt('expect-cwd')
const expectDshHome = opt('expect-dsh-home')

// ---- 1. 拿到宿主自己的 yaml 解析器（js-yaml） -------------------------------
//
// 关键：**不新增依赖**。用宿主 runtime 里那份 `js-yaml`，与宿主 boot 时用的是同一个包
// （`dsh-app-boot` 的第 6 行 `import * as yaml from "js-yaml"`），因此「本脚本解析通过」
// 与「宿主 boot 时解析通过」是同一判据，而不是近似。
// 解析顺序：$DSH_RUNTIME/node_modules → $DSH_HOME 推导 → 本仓库 node_modules。
function loadHostYaml() {
  const candidates = []
  if (process.env.DSH_RUNTIME) candidates.push(join(process.env.DSH_RUNTIME, 'node_modules'))
  if (process.env.DSH_HOME) candidates.push(join(process.env.DSH_HOME, '..', 'runtime', 'node_modules'))
  candidates.push(join(process.cwd(), 'node_modules'))
  const tried = []
  for (const base of candidates) {
    try {
      const req = createRequire(join(base, 'noop.js'))
      const resolved = req.resolve('js-yaml')
      const mod = req('js-yaml')
      // 必须真的有 `load` —— 见文件头「为什么钉住 js-yaml 而不是 yaml」。
      if (typeof mod.load !== 'function') throw new Error('resolved js-yaml has no load()')
      return { yaml: mod, from: resolved }
    } catch (error) {
      tried.push(`${base} (${error.code ?? error.message})`)
    }
  }
  console.error('test-patch-layer: cannot locate the host `js-yaml` package. Tried:\n  ' + tried.join('\n  '))
  console.error('Set DSH_RUNTIME to the DSH runtime dir (the one containing node_modules/@deepseek-ai).')
  process.exit(2)
}

const { yaml, from: yamlFrom } = loadHostYaml()

// ---- 2. 断言工具 ------------------------------------------------------------

const failures = []
function check(ok, message) {
  if (!ok) failures.push(message)
}
function checkEq(actual, expected, label) {
  check(actual === expected, `${label}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`)
}

// ---- 3. 读文件 --------------------------------------------------------------

let raw
try {
  raw = readFileSync(patchPath, 'utf8')
} catch (error) {
  console.error(`test-patch-layer: cannot read ${patchPath}: ${error.message}`)
  process.exit(2)
}

// 断言 C：裸 `[]` 后面跟着块序列项 —— 历史缺陷的确切形状。
//
// ⚠ 判据必须是「`[]` 之后还有块序列项」，**不能**是「存在裸 `[]`」：一个只有注释 + `[]`
// 的文件（DSH 出厂模板、或 `-Uninstall` 之后的复原态）是**完全合法**的 YAML，把
// `[]` 本身当错误会让守卫对合法产物误报 —— 2026-09-22 修复过程中真的踩过这个坑
// （PowerShell 的 `-match '(?m)...$'` 在恒以换行结尾的输入上恒真），详见 install-dsh.ps1
// 的 `Test-HasBareFlowSequence` 注释。
//
// 放在解析**之前**查，因为解析失败时更需要这条诊断。
const rawLines = raw.split(/\r?\n/)
let bareFlow = -1
for (let i = 0; i < rawLines.length; i++) {
  if (!/^[ \t]*\[\][ \t]*$/.test(rawLines[i])) continue
  // 这个 `[]` 之后还有非注释、非空行的内容吗？有 = 非法（flow 序列后不能接块序列项）。
  const trailing = rawLines.slice(i + 1).find((line) => line.trim() !== '' && !line.trim().startsWith('#'))
  if (trailing !== undefined) {
    bareFlow = i
    break
  }
}
check(
  bareFlow === -1,
  `C: found a bare '[]' flow sequence on line ${bareFlow + 1} followed by further content — a block sequence item cannot follow it (this is the 2026-09-22 BLOCKER shape)`
)

// 断言 A：能解析。用宿主的 API 与默认 schema。
// 注：宿主传的是 `{ schema: userPatchesSchema }`，而 `userPatchesSchema === entryListSchema`
// （dsh-app-boot :2063）—— 那是给 `!!js` 等自定义标签用的。默认 schema 已能判定
// 「这个文件的**结构**是否合法」，而结构非法正是历史缺陷的形状（也是唯一会 throw 的原因）；
// 自定义标签的语义正确性由宿主 boot 负责，不在本回归的射程内。
let parsed
try {
  parsed = yaml.load(raw)
} catch (error) {
  failures.push(`A: host YAML parser rejected the file: ${String(error).split('\n')[0]}`)
  report()
}

// 断言 A（续）：顶层必须是数组 —— `parsePatchList` 的第二个 throw 点。
check(Array.isArray(parsed), `A: top level must be a YAML array of loader patch entries, got ${Array.isArray(parsed) ? 'array' : typeof parsed}`)

// 断言 B：每个元素是映射 —— 第三个 throw 点。
if (Array.isArray(parsed)) {
  parsed.forEach((entry, index) => {
    check(
      typeof entry === 'object' && entry !== null && !Array.isArray(entry),
      `B: entry ${index + 1} must be a mapping (a loader patch entry)`
    )
  })
}

// ---- 4. 定位本插件的挂载行 --------------------------------------------------

const rows = Array.isArray(parsed) ? parsed.filter((e) => e && typeof e === 'object' && e.id === 'mcp-harness-evolution') : []

// 卸载后的状态：只要求「零条本插件行」+「仍是合法 YAML」（A/B/C 已在上面断言过）。
if (expectEmpty) {
  checkEq(rows.length, 0, 'D: number of `mcp-harness-evolution` patch entries after -Uninstall')
  if (!quiet && failures.length === 0) console.log(`  OK  ${patchPath} (uninstalled: valid YAML, no mount row)`)
  report()
}

// 断言 D：恰好一条。重复 id 会让 Loader 报 `duplicate loader entry id`。
checkEq(rows.length, 1, 'D: number of `mcp-harness-evolution` patch entries')

const row = rows[0]
if (row !== undefined) {
  // 断言 E：id 定向覆盖形态。注意这不是 `insert` —— 出厂 bundle 已经插入了该行，
  // 这里只是按 id 覆盖它的字段（故必须重述整个 `config`，DSH 是整体替换而非深度合并）。
  check(row.insert === undefined, 'E: the installer must write an id-targeted override, not an `insert` list')
  checkEq(row.disabled, false, 'E: `disabled` (the row must be enabled)')
  check(
    typeof row.config === 'object' && row.config !== null && !Array.isArray(row.config),
    `E: \`config\` must be a mapping (the whole config is replaced, not deep-merged), got ${Array.isArray(row.config) ? 'array' : typeof row.config}`
  )

  const cfg = row.config ?? {}
  checkEq(cfg.transport, 'stdio', 'E: `config.transport`')
  checkEq(cfg.serverName, 'harness-evolution', 'E: `config.serverName` (decides the public tool names mcp__harness-evolution__*)')
  // serverName 受宿主 zod 约束 /^[A-Za-z0-9_-]{1,32}$/ —— 形状检查一次，防未来改动越界。
  check(/^[A-Za-z0-9_-]{1,32}$/.test(String(cfg.serverName ?? '')), 'E: `config.serverName` must match /^[A-Za-z0-9_-]{1,32}$/')
  checkEq(cfg.failOnStartupError, true, 'E: `config.failOnStartupError`')
  check(Array.isArray(cfg.args), 'E: `config.args` must be a sequence')

  // 绝对路径：DSH 的 Loader **不**解析相对路径、**不**做 ${ENV_VAR} 插值
  // （anchorInsertedPluginNames 只 visit `entry.name`），相对值会按 spawn 的 cwd 解析，不可控。
  check(
    typeof cfg.command === 'string' && isAbsolute(cfg.command.replace(/\//g, '\\')),
    `E: \`config.command\` must be an absolute path, got ${JSON.stringify(cfg.command)}`
  )
  check(
    typeof cfg.cwd === 'string' && isAbsolute(String(cfg.cwd).replace(/\//g, '\\')),
    `E: \`config.cwd\` must be an absolute path, got ${JSON.stringify(cfg.cwd)}`
  )
  // env.DSH_HOME：宿主 spawn MCP 子进程时 scrubbedParentEnv() 丢弃**全部** DSH_*，
  // 只有挂载行 env 的字面量能在清洗**之后**被合并 —— 继承拿不到，必须显式给出。
  check(
    typeof cfg.env === 'object' && cfg.env !== null && typeof cfg.env.DSH_HOME === 'string' && cfg.env.DSH_HOME.length > 0,
    'E: `config.env.DSH_HOME` must be a non-empty absolute literal (the child cannot inherit DSH_*)'
  )
  check(
    typeof cfg.env?.DSH_HOME === 'string' && isAbsolute(cfg.env.DSH_HOME.replace(/\//g, '\\')),
    `E: \`config.env.DSH_HOME\` must be absolute, got ${JSON.stringify(cfg.env?.DSH_HOME)}`
  )
  // 安装位必须落在该 profile 的 node_modules 下 —— 这是「装进哪棵树」的落点，
  // 也是插件侧 dsh_home() 第三档「安装路径推导」识别 `<X>/profiles/<name>/node_modules/…` 的依据。
  const norm = (s) => String(s).replace(/\\/g, '/').replace(/\/+$/, '')
  if (typeof cfg.cwd === 'string') {
    check(
      /\/profiles\/[^/]+\/node_modules\/@across2005\/harness-self-evolution$/.test(norm(cfg.cwd)),
      `E: \`config.cwd\` must be the profile install location (<profile>/node_modules/@across2005/harness-self-evolution), got ${JSON.stringify(cfg.cwd)}`
    )
  }
  if (typeof cfg.command === 'string' && typeof cfg.cwd === 'string') {
    check(
      norm(cfg.command) === `${norm(cfg.cwd)}/bin/harness-evolution.exe`,
      `E: \`config.command\` must be <cwd>/bin/harness-evolution.exe, got ${JSON.stringify(cfg.command)} vs cwd ${JSON.stringify(cfg.cwd)}`
    )
  }
  if (typeof cfg.cwd === 'string') {
    // 安装位里的 <X> 必须就是 --expect-dsh-home（即挂载行进的是目标树，不是别的树）。
    const derivedHome = norm(cfg.cwd).replace(/\/profiles\/[^/]+\/node_modules\/.*$/, '')
    if (expectDshHome !== undefined) checkEq(derivedHome, norm(expectDshHome), 'F: tree derived from `config.cwd`')
    if (typeof cfg.env?.DSH_HOME === 'string') checkEq(norm(cfg.env.DSH_HOME), derivedHome, 'F: `env.DSH_HOME` vs the tree derived from `config.cwd`')
  }

  // 断言 F：与安装器算出的字面量逐字一致（调用方传入）。
  if (expectCommand !== undefined) checkEq(norm(cfg.command), norm(expectCommand), 'F: `config.command` verbatim')
  if (expectCwd !== undefined) checkEq(norm(cfg.cwd), norm(expectCwd), 'F: `config.cwd` verbatim')
}

if (!quiet && failures.length === 0 && row !== undefined) {
  console.log(`  OK  ${patchPath}`)
  console.log(`      parsed with ${yamlFrom}`)
  console.log(`      row: disabled=${row.disabled} cwd=${row.config?.cwd}`)
}

report()

// ---- 5. 报告 ----------------------------------------------------------------

// 注意：`report()` 刻意**不**引用 `row` —— 它被上面的 expectEmpty 早退路径调用，
// 那时 `row` 还在 temporal dead zone 里。行摘要由调用点在 `row` 可用后自行打印。
function report() {
  if (failures.length === 0) {
    if (!quiet) {
      console.log(`  OK  ${patchPath}`)
      console.log(`      parsed with ${yamlFrom}`)
    }
    process.exit(0)
  }
  console.error(`  FAIL  ${patchPath}`)
  for (const failure of failures) console.error(`        - ${failure}`)
  process.exit(1)
}
