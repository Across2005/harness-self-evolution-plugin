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
  const override = env.HARNESS_EVOLUTION_HOME
  if (override !== undefined && override !== '') return override
  const home = env.HOME ?? env.USERPROFILE ?? '~'
  return `${home.replace(/\\/g, '/')}/.harness-evolution/v2`
}
