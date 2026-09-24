import test from 'node:test'
import assert from 'node:assert/strict'
import { createElement } from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { EvolutionBody } from '../lib/client/Panel.js'

/**
 * 面板渲染的客观参照：用真实数据根会产出的形状渲染成 HTML，断言用户实际看到什么。
 * 这样「面板没有具体显示」这类问题不必只靠肉眼——渲染路径有机器可查的证据。
 */

const view = {
  version: 1,
  generatedAt: 1789728486583,
  root: 'C:/Users/19207/.harness-evolution/v2',
  pluginCache: { exists: true, count: 61 },
  proposals: { total: 3, countByStatus: { completed: 3 }, recent: [], malformedLines: 0 },
  execution: {
    source: 'jsonl',
    legacyTextFallback: true,
    records: [
      {
        ts: '2026-09-17T13:28:08.006Z',
        proposalId: 'evo-2026-09-17-tabbit-0.0.0-performance-tuning',
        event: 'complete',
        message: 'Execution completed successfully',
        malformed: false,
      },
    ],
    residualDropped: false,
  },
  metrics: { wired: false, lines: 0 },
  signals: { wired: false, lines: 0 },
  dataGaps: ['metrics.jsonl 尚未产生：自测量与注入面均已接线（缺陷 9）'],
}

test('EvolutionBody renders the three sections for a live view', () => {
  const html = renderToStaticMarkup(createElement(EvolutionBody, { view, conn: 'live', rawShape: '' }))
  assert.match(html, /进化运行时/)
  assert.match(html, /completed/)
  assert.match(html, /扫描档案 61/)
  assert.match(html, /提案 3/)
  assert.match(html, /结构化镜像/)
  assert.match(html, /Execution completed successfully/) // 时间线真渲染出事件行
  assert.match(html, /指标事件：未接线/) // 缺陷 9 的诚实呈现
  // 覆盖范围必须出现在 UI 上：自测量 + 注入面，不能让人误读成全生态指标
  assert.match(html, /覆盖范围：自测量=本插件/)
  assert.match(html, /record_tool_call/)
  assert.match(html, /数据根 C:\/Users\/19207\/\.harness-evolution\/v2/)
  assert.doesNotMatch(html, /连接中/)
})

test('EvolutionBody names what arrived instead of a blank dialog', () => {
  const html = renderToStaticMarkup(
    createElement(EvolutionBody, { view: undefined, conn: 'silent', rawShape: 'object{ok,meta}' }),
  )
  assert.match(html, /未获取到数据/)
  assert.match(html, /不伪造内容/)
  assert.match(html, /实际收到：object\{ok,meta\}/)
})

test('EvolutionBody says it is still connecting when no payload has arrived yet', () => {
  const html = renderToStaticMarkup(
    createElement(EvolutionBody, { view: undefined, conn: 'connecting', rawShape: '' }),
  )
  assert.match(html, /连接中/)
  assert.match(html, /首次折叠内容将在此生长/)
})
