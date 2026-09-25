import type { ConversationNode } from '@deepseek-ai/dsh-client-ui-conversation/client';
import type { WorkGroup, WorkItem, WorkPicture, WorkStep, WorkTurn } from './fold.ts';
/** A measured decode rate or an explicit absence of enough source evidence. */
export type DecodeThroughput = {
    kind: 'measured';
    decodeMs: number;
    outputTokens: number;
    tokensPerSecond: number;
} | {
    kind: 'unavailable';
};
/** Performance evidence correlated to one visible Turn. */
export interface TurnPerformance {
    /** Sum of step/start → assistant/message intervals carrying recorded timing. */
    modelMs: number | null;
    /** Sum of tool/call → tool/result intervals represented by this Turn. */
    toolMs: number | null;
    /** Lowest-step request dispatch → first non-empty token delta. */
    ttftMs: number | null;
    /** Output tokens divided only by first-token → message decode time. */
    throughput: DecodeThroughput;
}
/** A trustworthy wall-clock reading or a lower bound caused by a clipped start. */
export type ElapsedReading = {
    kind: 'exact';
    durationMs: number;
} | {
    kind: 'lower-bound';
    durationMs: number;
} | {
    kind: 'unavailable';
};
/** Whole-session wall-clock evidence for the complete history or current loaded window. */
export type SessionTiming = {
    kind: 'unavailable';
} | {
    kind: 'measured';
    coverage: 'complete' | 'partial';
    startTime: number;
    endTime: number;
    elapsedMs: number;
    activeTurnMs: number;
    betweenTurnMs: number;
};
/**
 * Correlate durable assistant timing/usage with Watcher's occurrence-preserving Turns.
 * Missing timing or provider usage stays unavailable; this function never estimates it.
 */
export declare function deriveTurnPerformance(nodes: readonly ConversationNode[], turns: readonly WorkTurn[]): ReadonlyMap<number, TurnPerformance>;
/** Settled Turn duration, live current duration, or a lower bound for a clipped Turn start. */
export declare function turnElapsedReading(turn: WorkTurn, live: boolean, now: number): ElapsedReading;
/** Backward-compatible numeric face for callers that do not need coverage copy. */
export declare function turnElapsedMs(turn: WorkTurn, live: boolean, now: number): number | null;
/** One phase's wall-clock span from its first Step start to its last Step end. */
export declare function groupElapsedMs(group: WorkGroup, live: boolean, now: number): number | null;
/** One Step's wall-clock span, including model, tools, and in-step waits. */
export declare function stepElapsedMs(step: WorkStep, live: boolean, now: number): number | null;
/** One execution's settled duration or live elapsed interval. */
export declare function itemElapsedMs(item: WorkItem, live: boolean, now: number): number | null;
/**
 * Decompose the loaded session span into DSH Turn intervals and time between Turns.
 * Partial history is labelled as a window; missing Turn starts use observed work only.
 */
export declare function deriveSessionTiming(picture: WorkPicture, now: number): SessionTiming;
/** Whole tokens from ten up, one decimal below, matching DSH's RC8 chat chrome. */
export declare function formatTokensPerSecond(tokensPerSecond: number): string;
//# sourceMappingURL=performance.d.ts.map