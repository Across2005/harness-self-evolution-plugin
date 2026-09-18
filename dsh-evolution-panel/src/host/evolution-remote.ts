import type { Context } from '@deepseek-ai/cordis'
import { TypertRemoteService } from '@deepseek-ai/dsh-typert-protocol'
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

// The `@Remote` / `@Remote({ mode: 'stream' })` decorators from
// dsh-typert-protocol are TC39 stage-3 method decorators. DSH's own Typert
// build chain compiles them into prototype markers, but this repo's build
// (`tsc + tsdown`) leaves the syntax raw — which Node cannot parse and DSH
// rejects at boot ("Invalid or unexpected token"). We therefore register the
// identical markers imperatively, replicating typert-protocol's `mark()`
// byte-for-byte (descriptor key, `version: 1`, `methods` array, frozen marker
// with `method` / optional `mode` / `invocation`).
const REMOTE_METHOD_DESCRIPTOR = '@deepseek-ai/dsh-typert-protocol/remote-methods'

interface RemoteMethodDescriptor {
  version: number
  methods: unknown[]
}

function markRemote(prototype: object, method: string, mode?: 'stream'): void {
  const desc = Object.getOwnPropertyDescriptor(prototype, REMOTE_METHOD_DESCRIPTOR)
  const existing = (desc?.value ?? undefined) as RemoteMethodDescriptor | undefined
  const marker = Object.freeze({
    method,
    ...(mode === undefined ? {} : { mode }),
    invocation: Object.freeze({ kind: 'direct' }),
  })
  Object.defineProperty(prototype, REMOTE_METHOD_DESCRIPTOR, {
    configurable: true,
    value: Object.freeze({
      version: 1,
      methods: Object.freeze([...(existing?.methods ?? []), marker]),
    }),
  })
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
    super(ctx, 'evolutionRuntime', { namespace: 'evolution' })
    this.poller = createRuntimePoller(defaultDataRoot(), (view) => {
      for (const sink of this.sinks) sink.push(view)
    })
    this.poller.start()
  }

  private readonly poller: RuntimePoller
  private readonly sinks = new Set<{ push: (view: EvolutionView) => void }>()

  async snapshot(): Promise<EvolutionView | undefined> {
    return this.poller.latest()
  }

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

// Register the Remote method markers the decorators would have emitted at
// class definition time (`@Remote` on `snapshot`, `@Remote({ mode: 'stream' })`
// on `watch`).
markRemote(EvolutionRuntimeService.prototype, 'snapshot')
markRemote(EvolutionRuntimeService.prototype, 'watch', 'stream')
