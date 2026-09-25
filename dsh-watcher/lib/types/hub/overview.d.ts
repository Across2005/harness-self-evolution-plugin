import type { WorkGroup, WorkStatus, WorkTurn } from '../observation/fold.ts';
/** Overview progress is deliberately separate from execution evidence status. */
export type OverviewState = 'active' | 'current' | 'waiting' | 'failure' | 'interrupted' | 'settled' | 'partial';
export declare const OVERVIEW_STATE_LABEL: Readonly<Record<OverviewState, string>>;
/** Project evidence status into the one question overview markers answer: where should the user look? */
export declare function overviewStateOf(status: WorkStatus, isLatest: boolean): OverviewState;
export declare function groupOverviewSummary(group: WorkGroup): string;
export declare function turnOverviewSummary(turn: WorkTurn): string;
export declare function turnNeedsDefaultDisclosure(state: OverviewState, isLatest: boolean): boolean;
//# sourceMappingURL=overview.d.ts.map