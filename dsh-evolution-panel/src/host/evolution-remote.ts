import type { Context } from '@deepseek-ai/cordis'
import { Remote, TypertRemoteService } from '@deepseek-ai/dsh-typert-protocol'
import { createRuntimePoller, defaultDataRoot, type RuntimePoller } from '../evolution-core.ts'
import type { EvolutionView } from './view.ts'

declare module '@deepseek-ai/dsh-typert-protocol' {
  interface TypertRemoteMap {
    'evolution/snapshot': () => Promise<EvolutionView | undefined>
    'evolution/watch': () => AsyncGenerator<EvolutionView, void>
  }
  interface TypertRemoteNamespaceMap {
    evolution: import('@deepseek-ai/dsh-typert-protocol').TypertRemoteNamespace<'evolution'>
  }
}

/**
 * Host-side Remote service over the harness-evolution data root.
 * Read-only by construction: the poller forwards Host file state; there is
 * no write method on this surface — the panel must never steer the pipeline.
 *
 * `watch` is a typert logical stream, so a client keeps one live
 * subscription instead of polling over RPC.
 */
export class EvolutionRuntimeService extends TypertRemoteService<EvolutionRuntimeService> {
  constructor(ctx: Context) {
    super(ctx, 'evolutionRuntime')
    this.poller = createRuntimePoller(defaultDataRoot(), (view) => {
      for (const sink of this.sinks) sink.push(view)
    })
    this.poller.start()
  }

  private readonly poller: RuntimePoller
  private readonly sinks = new Set<{ push: (view: EvolutionView) => void }>()

  @Remote
  async snapshot(): Promise<EvolutionView | undefined> {
    return this.poller.latest()
  }

  @Remote({ mode: 'stream' })
  async *watch(): AsyncGenerator<EvolutionView, void> {
    const queue: EvolutionView[] = []
    let notify: (() => void) | undefined
    const first = this.poller.latest()
    if (first !== undefined) queue.push(first)
    const sink = {
      push: (view: EvolutionView) => {
        queue.push(view)
        notify?.()
      },
    }
    this.sinks.add(sink)
    try {
      for (;;) {
        while (queue.length > 0) yield queue.shift()!
        await new Promise<void>((resolve) => {
          notify = resolve
        })
        notify = undefined
      }
    } finally {
      this.sinks.delete(sink)
    }
  }

  /** Stop the poller and drop sinks; safe to call twice (HMR reload path). */
  dispose(): void {
    this.poller.stop()
    this.sinks.clear()
  }
}
