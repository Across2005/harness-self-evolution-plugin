import { z } from 'zod'

/**
 * 客户端侧的 Remote 贡献（contribution）。
 *
 * 实测 2026-09-18：没有这个文件，`ctx.remote.evolution` 根本不存在，面板报
 * `Cannot read properties of undefined (reading 'watch')`。原因：**命名空间面是由
 * 客户端挂载的贡献建出来的，不是宿主服务本身**——见 `@deepseek-ai/dsh-api-remotes/client`
 * 的 apply：它对每个包 `await ctx.remote.$mount(contribution)`，网关的
 * `mountContribution` 内部才做 `ctx.typert.remotes.register(...)` 并按 namespace 建代理。
 *
 * 官方包的这个文件由 `@deepseek-ai/dsh-typert-generator` 生成；本机 runtime 里没有该生成器
 * （只有 typert-loader / protocol / registry），所以这两个 descriptor 按生成物的同形状手写。
 * 载荷校验留在宿主侧（`host/view.ts` 的 `evolutionViewSchema` 已经校验过）；客户端 codec 用
 * 透传 schema，而面板对认不出的载荷会响亮报错（不会静默空白）。
 */
const viewResult = (typeSymbol: string) => ({
  mode: 'strict' as const,
  typeSymbol,
  schema: z.unknown(),
})

export const TYPERT_REMOTE = {
  package: 'dsh-evolution-panel',
  descriptors: [
    {
      id: 'dsh-evolution-panel#evolution/snapshot',
      service: 'evolutionRuntime',
      namespace: 'evolution',
      method: 'snapshot',
      invocation: { kind: 'direct' as const },
      parameters: [],
      result: viewResult('dsh-evolution-panel#host/view:EvolutionView'),
    },
    {
      id: 'dsh-evolution-panel#evolution/watch',
      service: 'evolutionRuntime',
      namespace: 'evolution',
      method: 'watch',
      mode: 'stream' as const,
      invocation: { kind: 'direct' as const },
      parameters: [],
      cancellation: { parameter: 'signal' },
      result: viewResult('dsh-evolution-panel#host/view:EvolutionView'),
    },
  ],
}

export default TYPERT_REMOTE
