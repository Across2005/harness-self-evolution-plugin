import type { InsightsView } from '../insights/projection.ts';
export declare function TimingPanel({ stats, scope, tokensPerSecond, }: {
    stats: InsightsView['totals'];
    scope: 'turn' | 'session';
    tokensPerSecond?: number | null;
}): import("react").JSX.Element;
//# sourceMappingURL=TimingPanel.d.ts.map