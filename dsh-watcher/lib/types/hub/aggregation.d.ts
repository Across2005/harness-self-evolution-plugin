import type { WorkItem, WorkStatus } from '../observation/fold.ts';
export type WorkClusterBasis = 'mutable-target' | 'shared-target' | 'exact-call' | 'single';
export interface WorkStatusCounts {
    running: number;
    waiting: number;
    success: number;
    failure: number;
    returned: number;
    interrupted: number;
    unknown: number;
}
export type NonEmptyWorkItems = readonly [WorkItem, ...WorkItem[]];
/** A reversible analysis projection. `items` always retains the source records. */
export interface WorkCluster {
    id: string;
    basis: WorkClusterBasis;
    title: string;
    items: NonEmptyWorkItems;
    executionCount: number;
    stepCount: number;
    retryCount: number;
    iterationCount: number;
    latestStatus: WorkStatus;
    statusCounts: Readonly<WorkStatusCounts>;
}
/**
 * Group one phase for analysis without changing evidence identity or order.
 *
 * - Mutable calls may group by operation + target so changed inputs remain
 *   comparable as iterations.
 * - Reads may group by one exact file target so different line windows stay
 *   comparable.
 * - Search, Glob, Grep, Bash, and every other tool require exact normalized
 *   arguments. Sharing a cwd, broad path, tool name, or translated title is
 *   never enough.
 * - Messages and otherwise unsigned records remain singletons.
 */
export declare function clusterWorkItems(items: readonly WorkItem[]): readonly WorkCluster[];
export declare function clusterOutcomeSummary(cluster: WorkCluster): string;
//# sourceMappingURL=aggregation.d.ts.map