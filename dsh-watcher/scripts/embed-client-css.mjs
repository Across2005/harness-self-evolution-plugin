import { readFile, rm, writeFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

/**
 * DSH composes every plugin client as one classic script and resolves its
 * `require()` calls through a small host module table.  A sidecar CSS file is
 * therefore invisible to the host: the CSS must be installed by code inside
 * the Lazy-CJS factory itself.
 */
const packageRoot = join(dirname(fileURLToPath(import.meta.url)), '..')
const clientPath = join(packageRoot, 'lib', 'client.js')
const clientMapPath = join(packageRoot, 'lib', 'client.js.map')
const cssPath = join(packageRoot, 'lib', 'style.css')
const marker = '\t\tvar exports = module.exports;\n'

const [client, css, mapText] = await Promise.all([
  readFile(clientPath, 'utf8'),
  readFile(cssPath, 'utf8'),
  readFile(clientMapPath, 'utf8'),
])
if (!client.startsWith('window.__ModuleLoader__.load({')) {
  throw new Error('embed-client-css: client.js is not a Lazy-CJS bundle')
}
if (!client.includes(marker)) {
  throw new Error('embed-client-css: client factory marker is missing')
}
if (client.includes('data-plugin-css="dsh-watcher"')) {
  throw new Error('embed-client-css: client bundle already contains the plugin style')
}

const injection = `${marker}\t\t(() => {\n\t\t\tif (typeof document === 'undefined') return;\n\t\t\tconst id = 'dsh-watcher';\n\t\t\tlet style = document.querySelector('style[data-plugin-css="' + id + '"]');\n\t\t\tif (style === null) {\n\t\t\t\tstyle = document.createElement('style');\n\t\t\t\tstyle.dataset.plugin = id;\n\t\t\t\tstyle.dataset.pluginCss = id;\n\t\t\t\t(document.head ?? document.documentElement).appendChild(style);\n\t\t\t}\n\t\t\tstyle.textContent = ${JSON.stringify(css)};\n\t\t})();\n`
const embedded = client.replace(marker, injection)
const markerLine = client.slice(0, client.indexOf(marker)).split('\n').length - 1
const addedLines = embedded.split('\n').length - client.split('\n').length
const map = JSON.parse(mapText)
const mappingLines = (map.mappings ?? '').split(';')
mappingLines.splice(markerLine + 1, 0, ...Array(addedLines).fill(''))
// tsdown intentionally omits a few wrapper/footer lines from its mapping
// string. Pad the tail so every generated line has a corresponding map slot;
// the meaningful mappings before the footer remain unchanged.
const targetLines = embedded.split('\n').length
if (mappingLines.length < targetLines) {
  mappingLines.push(...Array(targetLines - mappingLines.length).fill(''))
} else {
  mappingLines.length = targetLines
}
map.mappings = mappingLines.join(';')
await writeFile(clientPath, embedded)
await writeFile(clientMapPath, JSON.stringify(map))
await rm(cssPath, { force: true })
console.log(`embedded ${css.length} CSS bytes into ${clientPath}`)
