import { defineConfig } from 'tsdown'

export default defineConfig({
  entry: {
    'evolution-panel': './src/evolution-panel.ts',
    client: './src/client/index.tsx',
  },
  format: 'esm',
  target: 'es2022',
  dts: true,
  sourcemap: true,
  clean: true,
  outDir: './lib',
  // exports/main/cordis 装载路径按 .js/.d.ts 约定（对齐 dsh-watcher 预构建 lib），
  // 覆盖 tsdown 对 ESM 的 .mjs 默认扩展名。
  outExtensions: () => ({ js: '.js', dts: '.d.ts' }),
  deps: {
    onlyBundle: false,
  },
})
