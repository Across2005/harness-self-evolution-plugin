import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs'
import { join, relative } from 'node:path'

const root = process.cwd()
const DSH_RANGE = '>=0.1.5-rc.2 <0.1.6 || >=0.1.6-alpha.1 <0.2.0'
const releaseBinary = 'bin/harness-evolution.exe'
const required = [
  'package.json',
  '.dsh-plugin/plugin.json',
  'cordis.patch.yml',
  'dsh-evolution-panel/package.json',
  'dsh-watcher/package.json',
  'build.ps1',
  'moon.mod',
  releaseBinary,
]

for (const relativePath of required) {
  const path = join(root, relativePath)
  if (!existsSync(path)) {
    throw new Error(`release artifact is missing: ${relativePath}; run build.ps1 -Task all first`)
  }
  if (relativePath === releaseBinary && statSync(path).size === 0) {
    throw new Error(`release artifact is empty: ${releaseBinary}`)
  }
}

function filesUnder(directory) {
  const files = []
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name)
    if (entry.isDirectory()) files.push(...filesUnder(path))
    else if (entry.isFile()) files.push(path)
  }
  return files
}

const buildInputs = [
  ...filesUnder(join(root, 'src')),
  join(root, 'build.ps1'),
  join(root, 'moon.mod'),
]
const newestInput = buildInputs
  .map((path) => ({ path, mtimeMs: statSync(path).mtimeMs }))
  .reduce((newest, current) => current.mtimeMs > newest.mtimeMs ? current : newest)
const binaryMtimeMs = statSync(join(root, releaseBinary)).mtimeMs
if (binaryMtimeMs < newestInput.mtimeMs) {
  throw new Error(
    `release artifact is stale: ${releaseBinary} is older than build input ${relative(root, newestInput.path)}; run build.ps1 -Task all`,
  )
}

function readJson(relativePath) {
  return JSON.parse(readFileSync(join(root, relativePath), 'utf8'))
}

const packageJson = readJson('package.json')
const pluginJson = readJson('.dsh-plugin/plugin.json')
if (packageJson.version !== pluginJson.version) {
  throw new Error(`version mismatch: package.json=${packageJson.version}, plugin.json=${pluginJson.version}`)
}

const dshManifests = [
  'package.json',
  '.dsh-plugin/plugin.json',
  'dsh-evolution-panel/package.json',
  'dsh-watcher/package.json',
]
for (const relativePath of dshManifests) {
  const manifest = readJson(relativePath)
  if (manifest.engines?.dsh !== DSH_RANGE) {
    throw new Error(`DSH baseline must be ${DSH_RANGE} in ${relativePath}`)
  }
}
if (!packageJson.files?.includes(releaseBinary)) {
  throw new Error(`package.json files must include ${releaseBinary}`)
}

console.log(`release artifacts verified: ${packageJson.version}, DSH ${DSH_RANGE}`)
