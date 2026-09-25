import { defineConfig } from 'tsdown'

/**
 * 浏览器半的注册包装 —— DSH `dsh-client-modules` 的 Lazy-CJS 契约。
 *
 * 契约来源（基线 DSH 0.1.5-rc.2；0.1.6-alpha.1 为回归目标）：
 *   - `dsh-client-modules/lib/types/client/manifest.d.ts`：`window.__ModuleLoader__.load({id, factory})`
 *     是唯一合法的注册形态；宿主把每个插件的 `lib/client.js` 拼进 `/plugins/??...` combo，
 *     浏览器按 **classic script** 解析——出现任何顶层 `export` 会让整条 combo 解析失败，
 *     同 combo 的所有插件一起报 `import failed`（页面显示 "Failed to load plugins"）。
 *   - 官方产物样例：`@deepseek-ai/dsh-client-ui-theme/lib/client.js` 头部即此包装。
 *
 * 因此 client 入口必须编译为 CJS 语义并用本包装包住：
 *   factory 内部自带 `module`/`exports` 两个局部变量，返回值即该插件的导出表；
 *   外部依赖通过 `require(...)` 从宿主模块表（PLATFORM_MODULES + 声明的 external）取。
 */
const CLIENT_ID = 'dsh-evolution-panel'

const CLIENT_BANNER = [
  'window.__ModuleLoader__.load({',
  `\tid: ${JSON.stringify(CLIENT_ID)},`,
  '\tfactory: (require) => {',
  '\t\tvar module = { exports: {} };',
  '\t\tvar exports = module.exports;',
].join('\n') + '\n'

const CLIENT_FOOTER = '\t\treturn module.exports;\n\t}\n});\n'

export default defineConfig([
  {
    // host 半：普通 ESM，由 DSH 的 Node 侧 Loader 直接 import。
    // exports/main/cordis 装载路径按 .js/.d.ts 约定（对齐 dsh-watcher 预构建 lib），
    // 覆盖 tsdown 对 ESM 的 .mjs 默认扩展名。
    entry: { 'evolution-panel': './src/evolution-panel.ts' },
    format: 'esm',
    target: 'es2022',
    dts: true,
    sourcemap: true,
    outDir: './lib',
    // clean 保持关闭：`tsc` 先行产出 lib/*.d.ts 与 lib/host、lib/client 子目录，
    // tsdown 的 clean 会连同它们一起删除（实测 "Cleaning 35 files"）。
    clean: false,
    outExtensions: () => ({ js: '.js', dts: '.d.ts' }),
    deps: { onlyBundle: false },
  },
  {
    // client 半：必须是 classic script + Lazy-CJS 工厂（见上方契约注释）。
    // react / react-dom 由宿主模块表 seed，不能内联（内联会产生第二份 React 实例，
    // 且把平台单例变成每插件私有副本）。
    entry: { client: './src/client/index.tsx' },
    format: 'cjs',
    target: 'es2022',
    // Declarations are emitted by tsc to lib/client/index.d.ts.  Running dts
    // through the CJS wrapper config produces a runtime-shaped fake .d.ts.
    dts: false,
    sourcemap: true,
    outDir: './lib',
    clean: false,
    outExtensions: () => ({ js: '.js', dts: '.d.ts' }),
    banner: CLIENT_BANNER,
    footer: CLIENT_FOOTER,
    // 依赖分流规则（两条都必须显式写，漏一侧就出事）：
    //   neverBundle = 平台单例，由宿主模块表 seed，**不能**内联（内联会产生第二份 React 实例）。
    //   alwaysBundle = 插件自有的第三方依赖，**必须**内联 —— tsdown 默认把 `dependencies`
    //     当 external，而宿主 makeRequire 只有 seed → 已物化 → 已注册工厂三条解析分支，
    //     其余一律抛错；`dsh.client.external` 也只能指向 graph row 或 seed 键，指向 zod 无人应答。
    // 实测 2026-09-19：漏掉 alwaysBundle → 产物顶层 `require("zod")`
    // → 物化时抛 "missed the module table" → 整页 "Failed to load plugins"。
    // 官方同构做法：@deepseek-ai/dsh-api-remotes/lib/client.js 内联 zod@4.4.3，require 调用数为 0。
    //
    //   onlyBundle = 白名单，三者的**方向各不相同，不要混用**：
    //     - alwaysBundle 管「本该内联的有没有被内联」（漏内联 → 产物顶层 require 平台表里没有的名字）。
    //     - onlyBundle   管「被内联的东西在不在白名单里」（误内联 → 把平台单例卷进私有副本）。
    //   ★ onlyBundle **拦不住** 2026-09-19 那次事故：tsdown 的检查集合来自
    //     `chunk.moduleIds`（**已经被内联**的模块，见 tsdown/dist/deps-*.mjs），
    //     而那次 zod 是被**外部化**了，根本不进这个集合；zod 不再内联时
    //     onlyBundle 只会打一条 INFO，不会失败。真正的守卫是
    //     `tests/client-bundle-contract.test.mjs` 的 require 白名单断言。
    //   实测 2026-09-19：内联集合恰为 `{ zod }`，故白名单取同一个值 ——
    //     除 zod 外任何东西被卷进产物都会在构建期报错。
    //   ★ 每次构建都会看到一条 `The following entries in deps.onlyBundle are not
    //     used in the bundle: - /^zod$/` —— **这是 dts 那一遍的固有噪声，别照它
    //     的建议删选项**。`deps.onlyBundle` 是 js/dts 两遍**共用**的顶层选项
    //     （tsdown 的 `deps.dts` 只接受 alwaysBundle/neverBundle，无法单独覆盖），
    //     而 dts 产物的 moduleIds 里没有 node_modules 路径 → 那一遍 `deps` 恒为空。
    //     判别实验（2026-09-19）：临时加入一个绝不可能命中的 pattern 后，dts 那遍
    //     两个都不命中、js 那遍只报我们加的那个 —— 证明 `/^zod$/` 在 js 遍确实命中。
    deps: {
      neverBundle: [/^react$/, /^react-dom$/, /^react\/jsx-runtime$/, /^@deepseek-ai\//],
      alwaysBundle: [/^zod$/],
      onlyBundle: [/^zod$/],
    },
  },
])
