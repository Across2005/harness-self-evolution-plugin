import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, writeFileSync, appendFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import {
  parseExecutionJsonl,
  parseExecutionLog,
  foldProposals,
  readEvolutionView,
  rootSignature,
} from '../lib/host/runtime-read.js'

const tmp = () => mkdtempSync(join(tmpdir(), 'evo-panel-'))

const execLine = (o) => JSON.stringify(o)

test('parseExecutionJsonl keeps order, tail window, and malformed records', () => {
  const text =
    [
      execLine({ ts: 'T1', proposal_id: 'p-1', event: 'start', message: 'go', malformed: false }),
      'corrupt-not-json',
      execLine({ ts: 'T2', proposal_id: 'p-1', event: 'progress', message: 'layer', malformed: false }),
      '',
    ].join('\n')
  const { records, residualDropped } = parseExecutionJsonl(text, 10)
  assert.equal(residualDropped, false)
  assert.equal(records.length, 3)
  assert.equal(records[0].proposalId, 'p-1')
  assert.equal(records[1].malformed, true)
  assert.equal(records[1].message, 'corrupt-not-json')
  assert.equal(records[2].event, 'progress')
  // tail window keeps the NEWEST n, order old→new
  const tail2 = parseExecutionJsonl(text, 2).records
  assert.deepEqual(tail2.map((r) => r.message).slice(-2), ['corrupt-not-json', 'layer'])
})

test('parseExecutionJsonl withholds a half-written trailing line', () => {
  const full = execLine({ ts: 'T1', proposal_id: 'p', event: 'start', message: 'a', malformed: false })
  const { records, residualDropped } = parseExecutionJsonl(`${full}\n{"ts":"T2","pro`, 10)
  assert.equal(residualDropped, true)
  assert.equal(records.length, 1)
})

test('parseExecutionLog falls back to the legacy text format', () => {
  const text =
    '[2026-09-17T00:00:00.000Z] [evo-x-1.0.0] [start] Starting\nnonsense line\n'
  const out = parseExecutionLog(text, 10)
  assert.equal(out.length, 2)
  assert.equal(out[0].proposalId, 'evo-x-1.0.0')
  assert.equal(out[0].event, 'start')
  assert.equal(out[1].malformed, true)
})

test('foldProposals: later rows win per proposal_id; recent newest-first', () => {
  const rows = [
    execLine({ proposal_id: 'a', plugin_id: 'pl', status: 'pending', created_at: 100 }),
    execLine({ proposal_id: 'b', plugin_id: 'pl', status: 'pending', created_at: 200 }),
    execLine({ proposal_id: 'a', plugin_id: 'pl', status: 'completed', created_at: 100 }),
    'garbage',
  ].join('\n')
  const folded = foldProposals(rows, 10)
  assert.equal(folded.total, 2)
  assert.equal(folded.malformedLines, 1)
  assert.deepEqual(folded.countByStatus, { completed: 1, pending: 1 })
  assert.equal(folded.recent[0].proposalId, 'b')
})

test('foldProposals: created_at accepts epoch digits as string, a number, and ISO', () => {
  // Regression (measured 2026-09-18): the writer emits created_at as a STRING,
  // so a number-only test zeroed every row and degenerated `recent` ordering.
  const rows = [
    execLine({ proposal_id: 'iso', plugin_id: 'pl', status: 'completed', created_at: '2026-09-18T00:19:38.117Z' }),
    execLine({ proposal_id: 'digits', plugin_id: 'pl', status: 'completed', created_at: '1789690778118' }),
    execLine({ proposal_id: 'number', plugin_id: 'pl', status: 'completed', created_at: 1789690778119 }),
    execLine({ proposal_id: 'junk', plugin_id: 'pl', status: 'completed', created_at: 'not-a-date' }),
  ].join('\n')
  const folded = foldProposals(rows, 10)
  assert.equal(folded.total, 4)
  const byId = Object.fromEntries(folded.recent.map((p) => [p.proposalId, p.createdAt]))
  assert.equal(byId.number, 1789690778119)
  assert.equal(byId.digits, 1789690778118)
  assert.equal(byId.iso, Date.parse('2026-09-18T00:19:38.117Z'))
  assert.equal(byId.junk, 0)
  // real ordering again: number > digits > iso > unparseable
  assert.deepEqual(folded.recent.map((p) => p.proposalId), ['number', 'digits', 'iso', 'junk'])
})

test('readEvolutionView: jsonl preferred, honest gaps, zod-stable shape', () => {
  const dir = tmp()
  try {
    writeFileSync(
      join(dir, 'execution.jsonl'),
      execLine({ ts: 'T', proposal_id: 'p', event: 'complete', message: 'done', malformed: false }) + '\n',
    )
    writeFileSync(join(dir, 'proposals.jsonl'), '')
    const view = readEvolutionView(dir, { now: () => 42 })
    assert.equal(view.execution.source, 'jsonl')
    assert.equal(view.execution.records.length, 1)
    assert.equal(view.generatedAt, 42)
    // defect 9 honesty: metrics/signals missing ⇒ not-wired notices present
    assert.equal(view.metrics.wired, false)
    assert.ok(view.dataGaps.some((g) => g.includes('metrics 未接线')))
    assert.ok(view.dataGaps.some((g) => g.includes('plugin-cache.json 不存在')))
  } finally {
    rmSync(dir, { recursive: true, force: true })
  }
})

test('readEvolutionView: absent jsonl falls back to text log with a rollout note', () => {
  const dir = tmp()
  try {
    writeFileSync(
      join(dir, 'execution.log'),
      '[2026-09-17T00:00:00.000Z] [evo-old] [start] legacy\n',
    )
    const view = readEvolutionView(dir)
    assert.equal(view.execution.source, 'log')
    assert.equal(view.execution.records[0].proposalId, 'evo-old')
    assert.ok(view.dataGaps.some((g) => g.includes('execution.jsonl 缺失')))
  } finally {
    rmSync(dir, { recursive: true, force: true })
  }
})

test('rootSignature changes only when watched files change', () => {
  const dir = tmp()
  try {
    const before = rootSignature(dir)
    assert.equal(rootSignature(dir), before)
    writeFileSync(join(dir, 'proposals.jsonl'), 'x\n')
    assert.notEqual(rootSignature(dir), before)
  } finally {
    rmSync(dir, { recursive: true, force: true })
  }
})
