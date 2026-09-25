import type { WorkItem, WorkStep } from '../observation/fold.ts';
import type { ModelStepTrace } from '../observation/model-trace.ts';
type StepTimelineOccurrence = {
    readonly kind: 'occurrence';
    readonly item: WorkItem;
    readonly occurrenceIndex: number;
};
export type StepTimelineEntry = StepTimelineOccurrence | {
    readonly kind: 'model';
    readonly trace: ModelStepTrace;
};
/** Compose the visible rows owned by one authoritative DSH Step. */
export declare function stepTimelineEntries(step: Pick<WorkStep, 'items' | 'model'>): readonly StepTimelineEntry[];
export {};
//# sourceMappingURL=step-timeline.d.ts.map