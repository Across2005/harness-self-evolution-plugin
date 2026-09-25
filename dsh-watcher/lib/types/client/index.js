import { loadCompleteHistory } from "../hub/history.js";
import { Watcher } from "./Watcher.js";
import { registerModelTraceDefinition } from "./model-trace-definition.js";
import { InsightsSettings } from "./Insights.js";
export const name = 'dsh-watcher-client';
export const inject = ['slots', 'sessions', 'uiConversation'];
/**
 * Native session-header utility. Order 50 sits after Session log (0)
 * and before the files-panel toggle (110). No overlay glyph.
 */
export function apply(ctx) {
    registerModelTraceDefinition(ctx);
    ctx.inject(['remote', 'remote.session'], c => {
        c.slots.inject('settings.section', () => c.slots.register({
            name: 'settings.section', id: 'watcher-insights', order: 85,
            label: 'Watcher', inject: () => ({ remote: c.remote }),
        }, InsightsSettings));
    });
    ctx.slots.inject('conversation.session.header.utilities', () => ctx.slots.register({
        name: 'conversation.session.header.utilities',
        id: 'dsh-watcher',
        order: 50,
        label: 'Watcher',
        inject: (sessionId) => {
            // Workspace Host provides ISessions.binding(); keep runtime behavior.
            const session = ctx.sessions.binding?.(sessionId)?.session;
            if (session === undefined)
                throw new Error(`dsh-watcher: session "${sessionId}" is unavailable`);
            return {
                loadAllHistory: signal => loadCompleteHistory({
                    signal,
                    loadOlder: () => session.loadOlder(),
                    read: () => {
                        const sessionSnapshot = session.getSnapshot();
                        const conversation = ctx.uiConversation.binding(sessionId).snapshot.getSnapshot();
                        const chat = conversation.views.get('chat');
                        if (chat === undefined)
                            throw new Error('dsh-watcher: Chat conversation target is unavailable');
                        const firstNode = chat.legacy.nodes[0];
                        const firstTurn = chat.timeline.turnOrder[0];
                        return {
                            hasMore: sessionSnapshot.hasMore,
                            loadingOlder: sessionSnapshot.loadingOlder,
                            headKey: `${firstTurn ?? 'none'}:${firstNode?.seq ?? 'none'}:${chat.legacy.nodes.length}`,
                        };
                    },
                }),
            };
        },
    }, Watcher));
}
//# sourceMappingURL=index.js.map