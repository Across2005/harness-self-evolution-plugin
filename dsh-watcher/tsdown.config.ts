import { defineConfig } from 'tsdown'

export default defineConfig({
  entry: {
    'dsh-watcher': './src/dsh-watcher.ts',
    client: './src/client/index.tsx',
  },
  format: 'esm',
  target: 'node22',
  dts: true,
  sourcemap: true,
  clean: true,
  outDir: './lib',
})
