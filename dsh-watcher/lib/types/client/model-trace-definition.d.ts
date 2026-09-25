import type { Context as ClientContext } from '@deepseek-ai/cordis';
import { type ModelStepTrace } from '../observation/model-trace.ts';
declare module '@deepseek-ai/dsh-client-ui-conversation/client' {
    interface ConversationStepDataMap {
        /** Provider-exposed model activity retained for one Step. */
        'dsh-watcher-model-stage': ModelStepTrace;
    }
}
/** Register the Step-scoped, read-only model-stage projection. */
export declare function registerModelTraceDefinition(ctx: ClientContext): void;
//# sourceMappingURL=model-trace-definition.d.ts.map