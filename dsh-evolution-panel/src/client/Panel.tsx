import { useEffect, useState } from 'react'
import { createPortal } from 'react-dom'
import type { EvolutionView, ExecRecordView } from '../host/view.ts'

/**
 * Evolution runtime panel — read-only, three working views.
 * Honesty contract (DESIGN.md): missing data says «not wired», never renders
 * as a green zero; malformed lines are shown verbatim; no color-only states.
 */

export interface PanelInjected {
  snapshot: () => unknown
  watch: () => unknown
}

type Conn = 'connecting' | 'live' | 'silent'

/** Unwrap the typert envelope when present; accept bare values too. */
function unwrap(raw: unknown): EvolutionView | undefined {
  if (raw === null || typeof raw !== 'object') return undefined
  const r = raw as Record<string, unknown>
  const inner = 'ok' in r && 'value' in r ? r.value : raw
  if (inner === null || typeof inner !== 'object') return undefined
  const v = inner as Record<string, unknown>
  return typeof v.generatedAt === 'number' && typeof v.root === 'string'
    ? (v as unknown as EvolutionView)
    : undefined
}

const STATUS_ORDER = ['pending', 'approved', 'executing', 'completed', 'rejected'] as const

const EVENT_LABEL: Record<string, { text: string; tone: 'neutral' | 'bad' | 'good' }> = {
  start: { text: '开始', tone: 'neutral' },
  progress: { text: '进度', tone: 'neutral' },
  error: { text: '失败', tone: 'bad' },
  rollback: { text: '已回滚', tone: 'bad' },
  complete: { text: '完成', tone: 'good' },
}

function clockOf(ts: string): string {
  const m = /T(\d{2}:\d{2}:\d{2})/.exec(ts)
  return m ? m[1] : ts
}

function StatusChip(props: { status: string; count: number }) {
  return (
    <span
      style={{
        fontSize: 12,
        padding: '2px 8px',
        borderRadius: 999,
        border: '1px solid var(--dsw-border-subtle, #e2e4e9)',
        background: 'var(--dsw-surface-subtle, #f5f6f8)',
        color: 'var(--dsw-text-primary, #17181c)',
        fontVariantNumeric: 'tabular-nums',
      }}
    >
      {props.status} · {props.count}
    </span>
  )
}

function RecordRow(props: { record: ExecRecordView }) {
  const r = props.record
  if (r.malformed) {
    return (
      <div style={{ fontSize: 12, padding: '3px 0' }}>
        <span style={{ marginRight: 6 }}>异常行</span>
        <code style={{ fontSize: 13, wordBreak: 'break-all' }}>{r.message}</code>
      </div>
    )
  }
  const meta = EVENT_LABEL[r.event] ?? { text: r.event, tone: 'neutral' as const }
  const toneColor =
    meta.tone === 'bad'
      ? 'var(--dsw-error, #d83b3b)'
      : meta.tone === 'good'
        ? 'var(--dsw-success, #1e9e62)'
        : 'var(--dsw-text-secondary, #5f636d)'
  return (
    <div style={{ display: 'flex', gap: 8, fontSize: 13, padding: '3px 0', alignItems: 'baseline' }}>
      <span style={{ fontVariantNumeric: 'tabular-nums', color: 'var(--dsw-text-tertiary, #858a94)' }}>
        {clockOf(r.ts)}
      </span>
      {/* text carries the state; color is redundant emphasis only */}
      <span style={{ color: toneColor, minWidth: 42 }}>{meta.text}</span>
      <span style={{ color: 'var(--dsw-text-secondary, #5f636d)' }}>{r.proposalId}</span>
      <span style={{ overflowWrap: 'anywhere' }}>{r.message}</span>
    </div>
  )
}

export function Panel({ snapshot, watch }: PanelInjected) {
  const [open, setOpen] = useState(false)
  const [conn, setConn] = useState<Conn>('connecting')
  const [view, setView] = useState<EvolutionView | undefined>(undefined)

  useEffect(() => {
    if (!open || view !== undefined) return
    let cancelled = false
    void (async () => {
      try {
        const v = unwrap(await (snapshot() as Promise<unknown>))
        if (!cancelled && v) {
          setView(v)
          setConn('live')
        }
      } catch {
        if (!cancelled) setConn('silent')
      }
    })()
    return () => {
      cancelled = true
    }
  }, [open, snapshot, view])

  useEffect(() => {
    if (!open) return
    let cancelled = false
    void (async () => {
      try {
        const stream = watch() as AsyncIterable<unknown>
        for await (const item of stream) {
          if (cancelled) break
          const v = unwrap(item)
          if (v) {
            setView(v)
            setConn('live')
          }
        }
      } catch {
        if (!cancelled) setConn('silent')
      }
    })()
    return () => {
      cancelled = true
    }
  }, [open, watch])

  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false)
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open])

  return (
    <span data-ud-check="evolution-panel">
      <button
        type="button"
        aria-expanded={open}
        aria-haspopup="dialog"
        onClick={() => setOpen((v) => !v)}
        style={{ fontSize: 13, padding: '4px 10px' }}
      >
        进化面板
      </button>
      {open &&
        createPortal(
          <div
            role="dialog"
            aria-label="进化运行时"
            style={{
              position: 'fixed',
              top: 56,
              right: 24,
              width: 'min(420px, calc(100vw - 32px))',
              maxHeight: 'calc(100vh - 88px)',
              overflowY: 'auto',
              background: 'var(--dsw-surface-menu, #ffffff)',
              border: '1px solid var(--dsw-border-subtle, #e2e4e9)',
              borderRadius: 12,
              boxShadow: '0 8px 28px rgba(23, 24, 28, 0.14)',
              padding: 12,
              color: 'var(--dsw-text-primary, #17181c)',
              zIndex: 1000,
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
              <h2 style={{ fontSize: 16, fontWeight: 600, margin: 0 }}>进化运行时</h2>
              <span style={{ fontSize: 12, color: 'var(--dsw-text-tertiary, #858a94)' }}>
                {conn === 'live' && view ? `更新于 ${new Date(view.generatedAt).toLocaleTimeString()}` : conn === 'live' ? '等待数据' : conn === 'connecting' ? '连接中' : '未获取到数据'}
              </span>
            </div>
            {view === undefined ? (
              <p style={{ fontSize: 13, color: 'var(--dsw-text-secondary, #5f636d)' }}>
                {conn === 'silent'
                  ? 'Host 未提供运行时视图（数据根不可读或通道未放行）——不伪造内容。'
                  : '首次折叠内容将在此生长。'}
              </p>
            ) : (
              <>
                <section aria-label="管道总览" style={{ marginTop: 8 }}>
                  <h3 style={{ fontSize: 12, fontWeight: 500, margin: '8px 0 4px' }}>管道总览</h3>
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                    {STATUS_ORDER.filter((s) => (view.proposals.countByStatus[s] ?? 0) > 0).map((s) => (
                      <StatusChip key={s} status={s} count={view.proposals.countByStatus[s]} />
                    ))}
                    {view.proposals.total === 0 && (
                      <span style={{ fontSize: 12 }}>暂无提案记录</span>
                    )}
                  </div>
                  <div style={{ fontSize: 12, color: 'var(--dsw-text-secondary, #5f636d)', marginTop: 4 }}>
                    扫描档案 {view.pluginCache.count} · 提案 {view.proposals.total}
                    {view.proposals.malformedLines > 0 ? ` · 损坏行 ${view.proposals.malformedLines}` : ''}
                  </div>
                </section>
                <section aria-label="执行时间线" style={{ marginTop: 8 }}>
                  <h3 style={{ fontSize: 12, fontWeight: 500, margin: '8px 0 4px' }}>
                    执行时间线
                    <span style={{ fontWeight: 400, color: 'var(--dsw-text-tertiary, #858a94)' }}>
                      {' '}（{view.execution.source === 'jsonl' ? '结构化镜像' : view.execution.source === 'log' ? '旧文本日志' : '暂无执行记录'}
                      {view.execution.residualDropped ? ' · 尾部半行待下轮' : ''}）
                    </span>
                  </h3>
                  {view.execution.records.length === 0 ? (
                    <div style={{ fontSize: 13 }}>尚无执行事件</div>
                  ) : (
                    view.execution.records.map((r, i) => <RecordRow key={i} record={r} />)
                  )}
                </section>
                <section aria-label="指标与缺口" style={{ marginTop: 8 }}>
                  <h3 style={{ fontSize: 12, fontWeight: 500, margin: '8px 0 4px' }}>指标与缺口</h3>
                  <div style={{ fontSize: 13 }}>
                    指标事件：{view.metrics.wired ? `${view.metrics.lines} 条` : '未接线'} · 信号：
                    {view.signals.wired ? `${view.signals.lines} 条` : '未接线'}
                  </div>
                  {view.dataGaps.map((g, i) => (
                    <div key={i} style={{ fontSize: 12, color: 'var(--dsw-text-secondary, #5f636d)', marginTop: 3 }}>
                      {g}
                    </div>
                  ))}
                </section>
                <div style={{ fontSize: 12, color: 'var(--dsw-text-tertiary, #858a94)', marginTop: 8, overflowWrap: 'anywhere' }}>
                  数据根 {view.root}
                </div>
              </>
            )}
          </div>,
          document.body,
        )}
    </span>
  )
}
