function identityOf(item) {
    if (item.intentKey !== null)
        return { kind: 'mutable-target', key: `target\u0000${item.intentKey}` };
    if (item.toolName === 'read' && item.target !== null) {
        return { kind: 'shared-target', key: `target\u0000read\u0000${item.target}` };
    }
    if (item.signature !== null)
        return { kind: 'exact-call', key: `exact\u0000${item.signature}` };
    return { kind: 'single', key: `single\u0000${item.id}` };
}
function emptyStatusCounts() {
    return {
        running: 0,
        waiting: 0,
        success: 0,
        failure: 0,
        returned: 0,
        interrupted: 0,
        unknown: 0,
    };
}
function countStatuses(items) {
    const counts = emptyStatusCounts();
    for (const item of items)
        counts[item.status] += 1;
    return counts;
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
export function clusterWorkItems(items) {
    const accumulators = new Map();
    for (const item of items) {
        const identity = identityOf(item);
        const existing = accumulators.get(identity.key);
        if (existing === undefined) {
            accumulators.set(identity.key, { basis: identity.kind, first: item, rest: [] });
        }
        else {
            existing.rest.push(item);
        }
    }
    const clusters = [];
    for (const accumulator of accumulators.values()) {
        const clusterItems = [accumulator.first, ...accumulator.rest];
        const latest = clusterItems[clusterItems.length - 1];
        if (latest === undefined)
            continue;
        clusters.push({
            id: `cluster:${accumulator.first.id}`,
            basis: accumulator.basis,
            title: accumulator.first.title,
            items: clusterItems,
            executionCount: clusterItems.length,
            stepCount: new Set(clusterItems.map(item => item.step)).size,
            retryCount: clusterItems.filter(item => item.retryOf !== null).length,
            iterationCount: clusterItems.filter(item => item.iterationIndex > 0).length,
            latestStatus: latest.status,
            statusCounts: countStatuses(clusterItems),
        });
    }
    return clusters;
}
export function clusterOutcomeSummary(cluster) {
    const counts = cluster.statusCounts;
    return [
        counts.running > 0 ? `${counts.running} 进行中` : null,
        counts.waiting > 0 ? `${counts.waiting} 等待` : null,
        counts.success > 0 ? `${counts.success} 成功` : null,
        counts.failure > 0 ? `${counts.failure} 失败` : null,
        counts.returned > 0 ? `${counts.returned} 已返回` : null,
        counts.interrupted > 0 ? `${counts.interrupted} 已中断` : null,
        counts.unknown > 0 ? `${counts.unknown} 未知` : null,
    ].filter((part) => part !== null).join(' · ');
}
//# sourceMappingURL=aggregation.js.map