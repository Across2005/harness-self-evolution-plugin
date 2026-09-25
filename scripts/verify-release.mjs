import { existsSync, statSync, readFileSync } from 'node:fs'
import { join } from 'node:path'

const root = process.cwd()
const required = [
  'package.json',
  '.dsh-plugin/plugin.json',
  'cordis.patch.yml',
  'bin/harness-evolution.exe',
]

for (const relative of required) {
  const path = join(root, relative)
  if (!existsSync(path)) {
    throw new Error(`release artifact is missing: ${relative}; run build.ps1 -Task build first`)
  }
  if (relative === 'bin/harness-evolution.exe' && statSync(path).size === 0) {
    throw new Error('release artifact is empty: bin/harness-evolution.exe')
  }
}

const packageJson = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8'))
const pluginJson = JSON.parse(readFileSync(join(root, '.dsh-plugin', 'plugin.json'), 'utf8'))
if (packageJson.version !== pluginJson.version) {
  throw new Error(`version mismatch: package.json=${packageJson.version}, plugin.json=${pluginJson.version}`)
}
const dshRange = '>=0.1.5-rc.2 <0.1.6 || >=0.1.6-alpha.1 <0.2.0'
if (packageJson.engines?.dsh !== dshRange || pluginJson.engines?.dsh !== dshRange) {
  throw new Error(`DSH baseline must be ${dshRange} in both manifests`)
}
if (!packageJson.files?.includes('bin/harness-evolution.exe')) {
  throw new Error('package.json files must include bin/harness-evolution.exe')
}

console.log(`release artifacts verified: ${packageJson.version}, DSH ${packageJson.engines.dsh}`)
