/** Minimal public facts needed to page one shared RC8 Session window. */
export interface HistoryWindowState {
    hasMore: boolean;
    loadingOlder: boolean;
    headKey: string;
}
export type CompleteHistoryResult = {
    kind: 'complete';
    pages: number;
} | {
    kind: 'cancelled';
    pages: number;
} | {
    kind: 'blocked';
    pages: number;
    reason: 'busy' | 'no-progress' | 'page-limit';
};
export interface CompleteHistoryOptions {
    read: () => HistoryWindowState;
    loadOlder: () => Promise<void>;
    signal: AbortSignal;
    maxPages?: number;
}
/**
 * Pull every older RC8 page in order. The Session remains the sole owner of
 * history continuity; this helper only repeats its public, read-only paging
 * verb and fails closed if one request does not advance the visible head.
 */
export declare function loadCompleteHistory({ read, loadOlder, signal, maxPages, }: CompleteHistoryOptions): Promise<CompleteHistoryResult>;
//# sourceMappingURL=history.d.ts.map