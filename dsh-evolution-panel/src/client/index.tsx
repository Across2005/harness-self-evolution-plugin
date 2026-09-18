import type { Context as ClientContext } from '@deepseek-ai/cordis'
import type {} from '@deepseek-ai/dsh-client-ui-conversation/client'
import type {} from '@deepseek-ai/dsh-client-ui-renderer/client'
import type {} from '@deepseek-ai/dsh-typert-protocol'
import type {} from '@deepseek-ai/dsh-api-remotes/client'
import { TYPERT_REMOTE } from './remote-contribution.ts'
import { Panel } from './Panel.tsx'

export const name = 'dsh-evolution-panel-client'
export const inject = ['slots', 'remote']

/**
 * 第二枚会话头工具按钮：order 60 紧跟 Watcher 的眼睛（50）、在文件面板开关（110）之前，
 * label 进化面板。面板是全局视图（进化运行时不属于某个会话），会话头只是它的挂载锚点。
 *
 * ★ 必须先 `$mount` 贡献、再注册按钮：客户端命名空间面由**贡献挂载**建出，
 * 不挂载就没有 `ctx.remote.evolution`——实测症状是点开面板报
 * `Cannot read properties of undefined (reading 'watch')`。
 */
export async function apply(ctx: ClientContext) {
  const remote = ctx.remote as unknown as {
    $mount: (contribution: unknown) => Promise<() => Promise<void>>
  }
  const disposeRemote = await remote.$mount(TYPERT_REMOTE)
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
  return async () => {
    await disposeRemote()
  }
}
