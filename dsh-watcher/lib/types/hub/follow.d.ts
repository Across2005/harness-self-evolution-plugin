import type { WorkPicture } from '../observation/fold.ts';
export interface FollowSnapshot {
    follow: boolean;
    unread: number;
    selectedId: string | null;
}
export interface RailScrollState {
    atBottom: boolean;
}
/**
 * Follow versus pin state for the work rail.
 *
 * The rail follows the newest recorded occurrence by default. Selecting
 * history or scrolling away pins the viewport; later occurrences and result
 * updates increment `unread` without yanking the reader away from evidence.
 */
export declare function createFollow(): {
    snapshot: () => FollowSnapshot;
    /** Counts appended occurrences or a settled live result while pinned. */
    onPicture(picture: Pick<WorkPicture, "nodes">): FollowSnapshot;
    onSelect(id: string): FollowSnapshot;
    onScroll({ atBottom }: RailScrollState): FollowSnapshot;
    setFollow(next: boolean): FollowSnapshot;
    backToLatest(): FollowSnapshot;
    reset(): FollowSnapshot;
};
//# sourceMappingURL=follow.d.ts.map