import test from 'node:test'
import assert from 'node:assert/strict'
import { unwrap, shapeOf } from '../lib/client/Panel.js'

/**
 * Regression (measured 2026-09-18): the panel stayed on «连接中 / 首次折叠内容将在此生长»
 * forever whenever the snapshot resolved to a shape `unwrap` rejected — the dialog looked
 * empty and nothing said why. These tests pin the accepted envelopes and the shape report
 * that replaces the silent blank.
 */

const view = {
  version: 1,
  generatedAt: 42,
  root: 'C:/x',
  pluginCache: { exists: true, count: 3 },
  proposals: { total: 0, countByStatus: {}, recent: [], malformedLines: 0 },
  execution: { source: 'none', legacyTextFallback: false, records: [], residualDropped: false },
  metrics: { wired: false, lines: 0 },
  signals: { wired: false, lines: 0 },
  dataGaps: [],
}

test('unwrap accepts a bare view and the plausible envelopes', () => {
  assert.equal(unwrap(view)?.generatedAt, 42)
  assert.equal(unwrap({ ok: true, value: view })?.root, 'C:/x')
  assert.equal(unwrap({ value: view })?.root, 'C:/x')
  assert.equal(unwrap({ result: view })?.root, 'C:/x')
  assert.equal(unwrap({ data: view })?.root, 'C:/x')
  assert.equal(unwrap([view])?.root, 'C:/x')
  // 信封里嵌套一层但内容仍合法时也要认
  assert.equal(unwrap({ ok: true, value: { result: view } })?.root, 'C:/x')
})

test('unwrap rejects payloads without generatedAt/root, and shapeOf names what arrived', () => {
  assert.equal(unwrap({ ok: true }), undefined)
  assert.equal(unwrap(null), undefined)
  assert.equal(unwrap(undefined), undefined)
  assert.equal(unwrap('nope'), undefined)
  assert.equal(unwrap({ generatedAt: '42', root: 'C:/x' }), undefined) // 类型不对，不算视图
  assert.equal(shapeOf({ ok: true, meta: 1 }), 'object{ok,meta}')
  assert.equal(shapeOf(null), 'null')
  assert.equal(shapeOf(undefined), 'undefined')
  assert.equal(shapeOf([1, 2]), 'array(2)')
  assert.equal(shapeOf('x'), 'string')
  assert.equal(shapeOf({ a: 1, b: 2, c: 3, d: 4, e: 5, f: 6, g: 7, h: 8, i: 9 }), 'object{a,b,c,d,e,f,g,h,…}')
})
