import type { Context as ClientContext } from '@deepseek-ai/cordis'
import type {} from '@deepseek-ai/dsh-client-ui-conversation/client'
import type {} from '@deepseek-ai/dsh-client-ui-renderer/client'
import type {} from '@deepseek-ai/dsh-typert-protocol'
import type {} from '@deepseek-ai/dsh-api-remotes/client'
import { Panel } from './Panel.tsx'

export const name = 'dsh-evolution-panel-client'
export const inject = ['slots', 'remote']

/**
 * Second session-header utility. Order 60 sits right after the Watcher
 * eye (50) and before the files-panel toggle (110); distinct label 进化.
 * The panel is a global view (evolution runtime is not per-session) —
 * the session header is only its anchor, mirroring Watcher's pattern.
 */
export function apply(ctx: ClientContext) {
  ctx.slots.inject('conversation.session.header.utilities', () => ctx.slots.register({
    name: 'conversation.session.header.utilities',
    id: 'dsh-evolution-panel',
    order: 60,
    label: '进化面板',
    inject: () => ({
      snapshot: () => ctx.remote.evolution.snapshot(),
      watch: () => ctx.remote.evolution.watch(),
    }),
  }, Panel))
}
