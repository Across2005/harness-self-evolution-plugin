/** One timestamped provider-exposed reasoning fragment. */
export interface ReasoningFragment {
    readonly seq: number;
    readonly time: number;
    readonly text: string;
}
interface ModelAttemptEvidence {
    readonly attempt: number;
    /** Only the first attempt has an authoritative request-entry boundary. */
    readonly startedAt: number | null;
    readonly firstTokenTime: number | null;
    readonly firstReasoningTime: number | null;
    readonly lastReasoningTime: number | null;
    readonly firstOutputTime: number | null;
    readonly reasoningText: string;
    readonly fragments: readonly ReasoningFragment[];
}
export type ModelAttempt = ModelAttemptEvidence & ({
    readonly kind: 'running';
} | {
    readonly kind: 'complete';
    readonly endedAt: number;
} | {
    readonly kind: 'retried';
    readonly endedAt: number;
    readonly retry: number;
    readonly retryDelayMs: number;
} | {
    readonly kind: 'interrupted';
    readonly endedAt: number;
});
type ModelAttempts = readonly [ModelAttempt, ...ModelAttempt[]];
/** Provider/model evidence owned by one authoritative DSH Step. */
export interface ModelStepTrace {
    readonly turn: number;
    readonly step: number;
    /** Stable identity anchor: the first model event observed for this Step. */
    readonly startSeq: number;
    /** Mutable activity cursor: the newest model event folded into this trace. */
    readonly lastSeq: number;
    readonly startTime: number | null;
    readonly attempts: ModelAttempts;
    readonly reasoningTokens: number | null;
}
export type ModelStageMetrics = {
    readonly kind: 'measured' | 'partial';
    readonly live: boolean;
    readonly totalMs: number | null;
    readonly firstResponseMs: number | null;
    readonly visibleReasoningMs: number | null;
    readonly outputMs: number | null;
    readonly unattributedMs: number | null;
};
type ModelTraceEventBase = {
    readonly turn: number;
    readonly step: number;
    readonly seq: number;
    readonly time: number;
    readonly lastSeq?: number;
};
export type ModelTraceEvent = ModelTraceEventBase & ({
    readonly kind: 'step-start';
} | {
    readonly kind: 'reasoning-delta';
    readonly text: string;
    readonly fragments?: readonly ReasoningFragment[];
} | {
    readonly kind: 'output-delta';
} | {
    readonly kind: 'usage';
    readonly reasoningTokens: number | null;
} | {
    readonly kind: 'message';
    readonly reasoningText: string | null;
    readonly reasoningTokens: number | null;
} | {
    readonly kind: 'retry';
    readonly retry: number;
    readonly delayMs: number;
} | {
    readonly kind: 'step-end';
});
/** Parse only the seven event shapes needed by the read-only model-stage fold. */
export declare function modelTraceEventOf(value: unknown): ModelTraceEvent | null;
export declare function startModelStepTrace(event: ModelTraceEventBase): ModelStepTrace;
/** Fold one normalized event without discarding reasoning from a retried attempt. */
export declare function updateModelStepTrace(trace: ModelStepTrace, event: ModelTraceEvent): ModelStepTrace;
/** Fold raw Session-like values for golden replay and boundary tests. */
export declare function foldModelTraceEvents(values: readonly unknown[]): ReadonlyMap<string, ModelStepTrace>;
/** Derive additive display segments without calling unobserved latency Thinking. */
export declare function modelStageMetrics(trace: ModelStepTrace, now: number): ModelStageMetrics;
export declare function hasReasoningEvidence(trace: ModelStepTrace): boolean;
export {};
//# sourceMappingURL=model-trace.d.ts.map