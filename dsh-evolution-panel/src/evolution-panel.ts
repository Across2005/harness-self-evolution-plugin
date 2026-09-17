import type { Context } from '@deepseek-ai/cordis'
import { EvolutionRuntimeService } from './host/evolution-remote.ts'

export { createRuntimePoller, defaultDataRoot, type RuntimePoller } from './evolution-core.ts'

export const name = 'dsh-evolution-panel'
export const inject = [] as string[]

/**
 * Host-owned read-only observation of unit A's data root, exposed to the
 * browser client through the Typert Gateway (`ctx.remote.evolution.*`).
 * No new transport, no writes, no model-facing surface.
 */
export function apply(ctx: Context): void {
  console.log('[dsh-evolution-panel] loaded')
  // Service self-registers in its constructor and unregisters with the
  // owning fiber; start/stop of the poller is explicit via the effect below
  // so tests and HMR reloads never leak the interval.
  const service = new EvolutionRuntimeService(ctx)
  ctx.effect(() => () => service.dispose(), 'dsh-evolution-panel/runtime')
}
