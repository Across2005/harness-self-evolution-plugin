import { installProjection } from "./insights/projection.js";
export const name = 'dsh-watcher';
export const inject = ['sessionProjections', 'sessions'];
/** Host-owned replayable statistics; no new transport or model-facing writes. */
export function apply(ctx) {
    console.log('[my-plugins/dsh-watcher] loaded');
    installProjection(ctx);
}
//# sourceMappingURL=dsh-watcher.js.map