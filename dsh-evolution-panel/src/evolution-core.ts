import { fileURLToPath } from 'node:url'
import { readEvolutionView, rootSignature, type ReadOptions } from './host/runtime-read.ts'
import type { EvolutionView } from './host/view.ts'

const POLL_INTERVAL_MS = 5000

export interface RuntimePoller {
  start(): void
  stop(): void
  latest(): EvolutionView | undefined
}

/**
 * mtime/size-driven poller: recompute the view only when the data root
 * changed, then notify. Channel-agnostic by design (tested in
 * tests/runtime-read.test.mjs through the reader; the loop itself is trivial).
 */
export function createRuntimePoller(
  root: string,
  onSnapshot: (view: EvolutionView) => void,
  opts: ReadOptions = {},
): RuntimePoller {
  let timer: NodeJS.Timeout | undefined
  let lastSig = ''
  let last: EvolutionView | undefined
  const tick = () => {
    const sig = rootSignature(root)
    if (sig === lastSig) return
    lastSig = sig
    try {
      last = readEvolutionView(root, opts)
    } catch {
      // unreadable root: keep the previous view rather than flashing empty
      return
    }
    onSnapshot(last)
  }
  return {
    start() {
      if (timer !== undefined) return
      tick()
      timer = setInterval(tick, POLL_INTERVAL_MS)
      timer.unref?.()
    },
    stop() {
      if (timer !== undefined) clearInterval(timer)
      timer = undefined
    },
    latest: () => last,
  }
}

/** Default data root, mirroring unit A store/paths.mbt (single source of truth). */
export function defaultDataRoot(env: NodeJS.ProcessEnv = process.env): string {
  const home = homeDirectory(env)
  const override = expandHome(env.HARNESS_EVOLUTION_HOME?.trim() ?? '', home)
  if (override !== '') return normalizePath(override)

  // MCP children and the panel host must resolve the same tree. The installer
  // writes HARNESS_EVOLUTION_HOME explicitly; the remaining fallback mirrors
  // paths.mbt: DSH_HOME, profile-install path arithmetic, then ~/.dsh.
  const configured = expandHome(env.DSH_HOME?.trim() ?? '', home)
  const dshHome = isAbsolutePath(configured)
    ? normalizePath(configured)
    : installedDshHome() ?? `${normalizePath(home)}/.dsh`
  // Read-only host adapter; the MoonBit writer remains the single write-side
  // definition in store/paths.mbt. Keep this suffix mirrored and covered by
  // runtime-read parity tests so both sides resolve the same DSH tree.
  return `${dshHome}/.harness-evolution/v2`
}

function homeDirectory(env: NodeJS.ProcessEnv): string {
  return env.HOME || env.USERPROFILE || process.cwd()
}

function expandHome(path: string, home: string): string {
  if (path === '~') return home
  if (path.startsWith('~/') || path.startsWith('~\\')) {
    return `${home}/${path.slice(2)}`
  }
  return path
}

export function installedDshHome(
  candidates: string[] = [process.cwd(), fileURLToPath(import.meta.url)],
): string | undefined {
  for (const candidate of candidates) {
    const match = normalizePath(candidate).match(/^(.*?)\/profiles\/[^/]+\/node_modules\/.+(?:\/|$)/)
    if (!match) continue
    const prefix = match[1] || '/'
    if (isAbsolutePath(prefix)) return prefix
    if (/^[A-Za-z]:$/.test(prefix)) return `${prefix}/`
  }
  return undefined
}

function isAbsolutePath(path: string): boolean {
  return path.startsWith('/') || /^[A-Za-z]:[\\/]/.test(path)
}

function normalizePath(path: string): string {
  const slashed = path.replace(/\\/g, '/')
  const prefix = slashed.startsWith('//') ? '//' : slashed.startsWith('/') ? '/' : ''
  const segments = slashed.split('/').filter((segment) => segment.length > 0)
  return prefix + segments.join('/')
}
