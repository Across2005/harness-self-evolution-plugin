import { existsSync, readFileSync, statSync } from 'node:fs'
import { join } from 'node:path'
import {
  evolutionViewSchema,
  type EvolutionView,
  type ExecRecordView,
  type ProposalSummary,
} from './view.ts'

/**
 * Pure-filesystem reader for the harness-evolution data root
 * (`~/.harness-evolution/v2` by default; `$HARNESS_EVOLUTION_HOME` respected).
 *
 * No cordis imports here on purpose: this module is the unit-tested core,
 * exercised by `node --test` against fixture dirs before any injection
 * channel is decided. It never writes and never throws on bad data —
 * corrupt lines become `malformed` records, missing files become honest gaps.
 */

export interface ReadOptions {
  tailLines?: number
  recentProposals?: number
  now?: () => number
}

const DEFAULT_TAIL = 200
const DEFAULT_RECENT = 10

/**
 * execution.jsonl tail: one JSON ExecRecord per line
 * ({ ts, proposal_id, event, message, malformed } written by unit A).
 * A trailing line without a final newline is a half-written flush artifact:
 * it is withheld (residual) and re-read on the next poll.
 */
export function parseExecutionJsonl(
  text: string,
  tailLines: number,
): { records: ExecRecordView[]; residualDropped: boolean } {
  const records: ExecRecordView[] = []
  let residualDropped = false
  const lines = text.split('\n')
  let end = lines.length
  if (end > 0 && lines[end - 1] === '') {
    end -= 1 // clean trailing newline: last empty segment is not a line
  } else if (end > 0) {
    end -= 1 // no final newline: half line, withhold it
    residualDropped = true
  }
  for (let i = Math.max(0, end - tailLines); i < end; i++) {
    const raw = lines[i].trim()
    if (raw === '') continue
    try {
      const j = JSON.parse(raw) as Record<string, unknown>
      records.push({
        ts: typeof j.ts === 'string' ? j.ts : '',
        proposalId: typeof j.proposal_id === 'string' ? j.proposal_id : '',
        event: typeof j.event === 'string' ? j.event : '',
        message: typeof j.message === 'string' ? j.message : '',
        malformed: j.malformed === true,
      })
    } catch {
      records.push({ ts: '', proposalId: '', event: '', message: raw, malformed: true })
    }
  }
  return { records, residualDropped }
}

/** execution.log fallback: `[ISO] [proposal_id] [event] message` text lines. */
export function parseExecutionLog(text: string, tailLines: number): ExecRecordView[] {
  const out: ExecRecordView[] = []
  const lines = text.split('\n').filter((l) => l.trim() !== '')
  for (const raw of lines.slice(-tailLines)) {
    const m = /^\[([^\]]*)\] \[([^\]]*)\] \[([^\]]*)\] (.*)$/.exec(raw)
    if (m) {
      out.push({ ts: m[1], proposalId: m[2], event: m[3], message: m[4], malformed: false })
    } else {
      out.push({ ts: '', proposalId: '', event: '', message: raw, malformed: true })
    }
  }
  return out
}

/**
 * Normalize one JSONL `created_at` to epoch milliseconds.
 *
 * The writer's wire form is a **string**: epoch-millis digits on today's rows,
 * ISO-8601 on some older ones. A bare `typeof === 'number'` test therefore
 * zeroed every row and quietly collapsed `recent` ordering to file order
 * (measured 2026-09-18: 12/12 rows were strings ⇒ every `createdAt: 0`).
 * Numbers, digit strings, and ISO strings are all accepted; anything else
 * becomes 0 — which keeps the row visible instead of dropping it.
 */
function createdAtMillis(raw: unknown): number {
  if (typeof raw === 'number') return Number.isFinite(raw) ? raw : 0
  if (typeof raw !== 'string') return 0
  const text = raw.trim()
  if (text === '') return 0
  if (/^\d+$/.test(text)) {
    const n = Number(text)
    return Number.isFinite(n) ? n : 0
  }
  const parsed = Date.parse(text)
  return Number.isNaN(parsed) ? 0 : parsed
}

/**
 * proposals.jsonl fold: append-only ledger, rows sharing proposal_id
 * collapse with the **later** row winning (mirrors unit A ProposalStore).
 */
export function foldProposals(
  text: string,
  recentCount: number,
): {
  total: number
  countByStatus: Record<string, number>
  recent: ProposalSummary[]
  malformedLines: number
} {
  const byId = new Map<string, ProposalSummary>()
  let malformedLines = 0
  for (const raw of text.split('\n')) {
    const line = raw.trim()
    if (line === '') continue
    try {
      const j = JSON.parse(line) as Record<string, unknown>
      if (typeof j.proposal_id !== 'string') {
        malformedLines += 1
        continue
      }
      byId.set(j.proposal_id, {
        proposalId: j.proposal_id,
        pluginId: typeof j.plugin_id === 'string' ? j.plugin_id : '',
        status: typeof j.status === 'string' ? j.status : 'unknown',
        createdAt: createdAtMillis(j.created_at),
      })
    } catch {
      malformedLines += 1
    }
  }
  const countByStatus: Record<string, number> = {}
  for (const p of byId.values()) {
    countByStatus[p.status] = (countByStatus[p.status] ?? 0) + 1
  }
  const all = [...byId.values()]
  return {
    total: all.length,
    countByStatus,
    // newest first, matching unit A snapshot `recent` semantics
    recent: all.sort((a, b) => b.createdAt - a.createdAt).slice(0, recentCount),
    malformedLines,
  }
}

function countLines(path: string): number {
  const text = readFileSync(path, 'utf8')
  let n = 0
  for (const l of text.split('\n')) if (l.trim() !== '') n += 1
  return n
}

export function readEvolutionView(root: string, opts: ReadOptions = {}): EvolutionView {
  const tailLines = opts.tailLines ?? DEFAULT_TAIL
  const recentProposals = opts.recentProposals ?? DEFAULT_RECENT
  const now = opts.now ?? (() => Date.now())
  const paths = {
    pluginCache: join(root, 'plugin-cache.json'),
    proposals: join(root, 'proposals.jsonl'),
    signals: join(root, 'signals.jsonl'),
    metrics: join(root, 'metrics.jsonl'),
    executionJsonl: join(root, 'execution.jsonl'),
    executionLog: join(root, 'execution.log'),
  }
  const dataGaps: string[] = []

  // —— plugin cache ——
  let cacheExists = false
  let cacheCount = 0
  if (existsSync(paths.pluginCache)) {
    cacheExists = true
    try {
      const j = JSON.parse(readFileSync(paths.pluginCache, 'utf8')) as { plugins?: unknown[] }
      cacheCount = Array.isArray(j.plugins) ? j.plugins.length : 0
    } catch {
      dataGaps.push('plugin-cache.json 存在但无法解析（等待下一次扫描重建）。')
    }
  } else {
    dataGaps.push('plugin-cache.json 不存在：尚未做过任何一次成功扫描。')
  }

  // —— proposals ——
  const proposals = existsSync(paths.proposals)
    ? foldProposals(readFileSync(paths.proposals, 'utf8'), recentProposals)
    : { total: 0, countByStatus: {}, recent: [], malformedLines: 0 }

  // —— execution: jsonl preferred, log fallback (rollout gap) ——
  let source: 'jsonl' | 'log' | 'none' = 'none'
  let legacyTextFallback = false
  let records: ExecRecordView[] = []
  let residualDropped = false
  if (existsSync(paths.executionJsonl)) {
    source = 'jsonl'
    const parsed = parseExecutionJsonl(readFileSync(paths.executionJsonl, 'utf8'), tailLines)
    records = parsed.records
    residualDropped = parsed.residualDropped
    legacyTextFallback = existsSync(paths.executionLog)
  } else if (existsSync(paths.executionLog)) {
    source = 'log'
    records = parseExecutionLog(readFileSync(paths.executionLog, 'utf8'), tailLines)
    dataGaps.push('execution.jsonl 缺失：正在读旧版文本日志（双写上线前的历史条目不在此窗内）。')
  }

  // —— metrics / signals: honest wiring status (defect 9) ——
  const metricsExists = existsSync(paths.metrics)
  const signalsExists = existsSync(paths.signals)
  const metricsLines = metricsExists ? countLines(paths.metrics) : 0
  const signalsLines = signalsExists ? countLines(paths.signals) : 0
  if (metricsLines === 0) {
    dataGaps.push(
      'metrics 未接线（record_tool_call 无生产调用方，CONTEXT 已知缺陷 9）——「未接线」不等于「无活动」。',
    )
  }
  if (signalsLines === 0) {
    dataGaps.push('signals 未接线：等待宿主事件注入（缺陷 9）。')
  }

  return evolutionViewSchema.parse({
    version: 1,
    generatedAt: now(),
    root,
    pluginCache: { exists: cacheExists, count: cacheCount },
    proposals,
    execution: { source, legacyTextFallback, records, residualDropped },
    metrics: { wired: metricsLines > 0, lines: metricsLines },
    signals: { wired: signalsLines > 0, lines: signalsLines },
    dataGaps,
  })
}

/** mtime+size signature across watched files — cheap change detection for the poll loop. */
export function rootSignature(root: string): string {
  const parts: string[] = []
  for (const name of [
    'plugin-cache.json',
    'proposals.jsonl',
    'signals.jsonl',
    'metrics.jsonl',
    'execution.jsonl',
    'execution.log',
  ]) {
    const p = join(root, name)
    try {
      const st = statSync(p)
      parts.push(`${name}:${st.mtimeMs}:${st.size}`)
    } catch {
      parts.push(`${name}:-`)
    }
  }
  return parts.join('|')
}
