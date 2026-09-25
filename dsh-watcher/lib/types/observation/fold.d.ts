import type { ConversationNode, ConversationViewSnapshotStore, RunningToolCall } from '@deepseek-ai/dsh-client-ui-conversation/client';
import type { ChatSnapshot } from '@deepseek-ai/dsh-client-ui-chat/client';
import type { SessionPendingInteractionBase } from '@deepseek-ai/dsh-client-ui-session/client';
import { type ModelStepTrace } from './model-trace.ts';
/** Watcher-owned projection assembled from the public RC1 Session and Conversation stores. */
export interface WatcherSnapshot {
    readonly views: ConversationViewSnapshotStore;
    readonly chat: ChatSnapshot;
    readonly nodes: readonly ConversationNode[];
    readonly turnTimings: ReadonlyMap<number, {
        readonly startTime: number;
        readonly endTime?: number;
    }>;
    readonly runningCalls: readonly RunningToolCall[];
    readonly pending: readonly SessionPendingInteractionBase[];
    readonly blank: boolean;
    readonly running: boolean;
    readonly hasMore: boolean;
}
/** One truthful lifecycle state. Result presence alone never means success. */
export type WorkStatus = 'running' | 'waiting' | 'success' | 'failure' | 'returned' | 'interrupted' | 'unknown';
/** User-facing phases used by the compact work rail. */
export type WorkPhase = 'request' | 'steering' | 'plan' | 'investigate' | 'build' | 'verify' | 'activate' | 'desktop' | 'answer' | 'model' | 'wait' | 'failure' | 'other';
export type WorkSource = 'tool' | 'user' | 'steering' | 'assistant' | 'artifact' | 'interaction' | 'turn' | 'model';
export type WorkPresentation = {
    kind: 'terminal';
    command: string;
    cwd: string | null;
    output: string;
    exitCode: number | null;
    signal: string | null;
    running: boolean;
} | {
    kind: 'read';
    label: string;
    lang: string | null;
    lines: readonly {
        number: number;
        text: string;
    }[];
    totalLines: number;
} | {
    kind: 'diff';
    diffs: {
        path: string;
        oldText: string | null;
        newText: string;
    }[];
} | {
    kind: 'json';
    data: object | unknown[];
} | {
    kind: 'text';
    text: string;
} | {
    kind: 'image';
    attachment: unknown;
} | {
    kind: 'empty';
};
/** Immutable evidence for one recorded occurrence. */
export interface WorkItem {
    id: string;
    seq: number;
    resultSeq: number | null;
    time: number;
    resultTime: number | null;
    turn: number;
    step: number;
    source: WorkSource;
    phase: WorkPhase;
    status: WorkStatus;
    title: string;
    subtitle: string;
    toolName: string | null;
    callId: string | null;
    args: Record<string, unknown>;
    argsRaw: string | null;
    rawText: string;
    rawValue: unknown;
    presentation: WorkPresentation;
    durationMs: number | null;
    exitCode: number | null;
    signal: string | null;
    signature: string | null;
    intentKey: string | null;
    target: string | null;
    retryOf: string | null;
    retryIndex: number;
    iterationIndex: number;
    recoveredBy: string | null;
}
export interface WorkStep {
    id: string;
    turn: number;
    step: number;
    phase: WorkPhase;
    status: WorkStatus;
    title: string;
    subtitle: string;
    items: readonly WorkItem[];
    parallel: boolean;
    executionCount: number;
    retryCount: number;
    iterationCount: number;
    unconfirmedFailureCount: number;
    firstSeq: number;
    lastSeq: number;
    startTime: number | null;
    endTime: number | null;
    model: ModelStepTrace | null;
}
/** One consecutive phase inside one Turn. Every child Step remains addressable. */
export interface WorkGroup {
    id: string;
    turn: number;
    phase: WorkPhase;
    status: WorkStatus;
    title: string;
    subtitle: string;
    steps: readonly WorkStep[];
    items: readonly WorkItem[];
    executionCount: number;
    parallelStepCount: number;
    retryCount: number;
    iterationCount: number;
    unconfirmedFailureCount: number;
    firstSeq: number;
    lastSeq: number;
    startTime: number | null;
    endTime: number | null;
}
export interface WorkTurn {
    turn: number;
    status: WorkStatus;
    groups: readonly WorkGroup[];
    startTime: number | null;
    endTime: number | null;
}
export interface WorkPicture {
    nodes: readonly WorkGroup[];
    turns: readonly WorkTurn[];
    now: {
        phase: WorkPhase;
        label: string;
        status: WorkStatus;
    };
    actionCount: number;
    stepCount: number;
    turnCount: number;
    parallelStepCount: number;
    retryCount: number;
    iterationCount: number;
    pendingCount: number;
    unconfirmedFailureCount: number;
    running: boolean;
    partialHistory: boolean;
}
interface ToolPair {
    callId: string;
    seq: number;
    resultSeq: number | null;
    time: number;
    resultTime: number | null;
    turn: number;
    step: number;
    name: string;
    args: Record<string, unknown>;
    argsRaw: string;
    result: unknown;
    meta: unknown;
    callView: unknown;
    resultView: unknown;
    orphan: boolean;
}
interface EventLike {
    type: string;
    seq?: number;
    time?: number;
    data?: unknown;
}
export declare const EMPTY_PICTURE: WorkPicture;
/** Stable exact signature used only for evidence-backed retry detection. */
export declare function normalizedSignature(toolName: string, args: Record<string, unknown>): string;
/** Public RC1 Session/Conversation projection to occurrence-preserving tool pairs. */
export declare function pairsFromSnapshot(snapshot: WatcherSnapshot): ToolPair[];
/** Pair every log call/result and preserve an orphan result instead of dropping it. */
export declare function pairTools(events: readonly EventLike[]): ToolPair[];
export declare function phaseTitle(phase: WorkPhase): string;
/** Fold the official RC8 snapshot without flattening Turn/Step identity. */
export declare function foldSnapshot(snapshot: WatcherSnapshot, options?: {
    running?: boolean;
}): WorkPicture;
/**
 * Retain every occurrence already observed in this mounted page while the
 * official RC8 window advances. Latest evidence wins by stable occurrence id,
 * so running → result updates one row instead of duplicating or removing it.
 */
export declare function mergeObservedPictures(previous: WorkPicture, current: WorkPicture): WorkPicture;
/** Fold a full session JSONL replay, including approvals, steering, images, and orphan results. */
export declare function foldEvents(events: readonly EventLike[], options?: {
    running?: boolean;
}): WorkPicture;
/** Parse valid JSONL lines and skip only a torn final line. */
export declare function parseJsonl(text: string): EventLike[];
export {};
//# sourceMappingURL=fold.d.ts.map