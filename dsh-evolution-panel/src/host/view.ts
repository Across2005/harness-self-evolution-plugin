import { z } from 'zod'

/**
 * Evolution runtime view — the single shape shared by the Host reader,
 * whatever injection channel wins the spike, and the client panel.
 *
 * Honesty rules (contract, see DESIGN.md):
 * - `metrics`/`signals` distinguish `notWired` from `zeroActivity`.
 * - Corrupt input lines are surfaced as `malformed` records, never dropped
 *   into a green-looking empty state.
 */

export const execRecordSchema = z.object({
  ts: z.string(),
  proposalId: z.string(),
  event: z.string(),
  message: z.string(),
  malformed: z.boolean(),
})
export type ExecRecordView = z.infer<typeof execRecordSchema>

export const proposalSummarySchema = z.object({
  proposalId: z.string(),
  pluginId: z.string(),
  status: z.string(),
  createdAt: z.number(),
})
export type ProposalSummary = z.infer<typeof proposalSummarySchema>

export const evolutionViewSchema = z.object({
  version: z.literal(1),
  generatedAt: z.number(),
  root: z.string(),
  pluginCache: z.object({
    exists: z.boolean(),
    count: z.number().int().nonnegative(),
  }),
  proposals: z.object({
    total: z.number().int().nonnegative(),
    countByStatus: z.record(z.string(), z.number().int().nonnegative()),
    recent: z.array(proposalSummarySchema),
    malformedLines: z.number().int().nonnegative(),
  }),
  execution: z.object({
    /** tail of execution.jsonl (preferred) or execution.log fallback. */
    source: z.enum(['jsonl', 'log', 'none']),
    /** true when jsonl exists but predates part of the text log (dual-write rollout gap). */
    legacyTextFallback: z.boolean(),
    records: z.array(execRecordSchema),
    /** trailing partial line withheld for next poll (not an error). */
    residualDropped: z.boolean(),
  }),
  metrics: z.object({ wired: z.boolean(), lines: z.number().int().nonnegative() }),
  signals: z.object({ wired: z.boolean(), lines: z.number().int().nonnegative() }),
  /** human-readable gap notices, e.g. defect 9 «not wired» wording. */
  dataGaps: z.array(z.string()),
})
export type EvolutionView = z.infer<typeof evolutionViewSchema>
