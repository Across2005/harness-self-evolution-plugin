import { defineConfig } from 'tsdown'

/**
 * DSH has two different loader contracts.  The host bundle is ordinary ESM,
 * while the browser bundle is a classic Lazy-CJS factory.  Keeping one entry
 * and one ESM format for both silently breaks the client at runtime.
 */
const CLIENT_ID = 'dsh-watcher'
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
    entry: { 'dsh-watcher': './src/dsh-watcher.ts' },
    format: 'esm',
    target: 'node22',
    dts: false,
    sourcemap: true,
    outDir: './lib',
    // tsc owns the type tree under lib/types; a clean here would remove it.
    clean: false,
    outExtensions: () => ({ js: '.js' }),
  },
  {
    entry: { client: './src/client/index.tsx' },
    format: 'cjs',
    target: 'es2022',
    // Types come from tsc, not from the wrapper-shaped declaration pass.
    dts: false,
    sourcemap: true,
    outDir: './lib',
    clean: false,
    outExtensions: () => ({ js: '.js', css: '.css' }),
    banner: CLIENT_BANNER,
    footer: CLIENT_FOOTER,
    deps: {
      // React and DSH client modules are seeded by the host module table.
      neverBundle: [/^react$/, /^react-dom$/, /^react\/jsx-runtime$/, /^@deepseek-ai\//],
    },
  },
])
