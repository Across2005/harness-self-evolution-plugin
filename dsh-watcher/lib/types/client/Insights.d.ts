import type { InsightsView } from '../insights/projection.ts';
type Evidence = {
    turn: number;
    steps: number[];
    seqs: number[];
};
export declare function SessionInsights({ value, now, running, waiting, onEvidence }: {
    value: InsightsView | undefined;
    now: number;
    running: boolean;
    waiting: boolean;
    onEvidence: (e: Evidence) => void;
}): import("react").JSX.Element | null;
export declare function InsightsSettings(props: {
    remote?: any;
}): import("react").JSX.Element;
export {};
//# sourceMappingURL=Insights.d.ts.map