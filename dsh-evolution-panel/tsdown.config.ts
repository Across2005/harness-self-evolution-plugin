import { defineConfig } from 'tsdown'

/**
 * 浏览器半的注册包装 —— DSH `dsh-client-modules` 的 Lazy-CJS 契约。
 *
 * 契约来源（实证 0.1.6-alpha.1）：
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
    dts: true,
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
    deps: {
      neverBundle: [/^react$/, /^react-dom$/, /^react\/jsx-runtime$/, /^@deepseek-ai\//],
      alwaysBundle: [/^zod$/],
    },
  },
])
