function isRecord(value) {
    return typeof value === 'object' && value !== null && !Array.isArray(value);
}
function finiteNumber(value) {
    return typeof value === 'number' && Number.isFinite(value) ? value : null;
}
function nonNegativeNumber(value) {
    const number = finiteNumber(value);
    return number !== null && number >= 0 ? number : null;
}
function locationOf(value) {
    const data = value.data;
    if (!isRecord(data))
        return null;
    const turn = finiteNumber(data.turn);
    const step = finiteNumber(data.step);
    const seq = finiteNumber(value.seq);
    const time = finiteNumber(value.time);
    return turn === null || step === null || seq === null || time === null
        ? null
        : { turn, step, seq, time };
}
function reasoningTokensOf(value) {
    return isRecord(value) ? nonNegativeNumber(value.reasoningTokens) : null;
}
function reasoningTextOf(value) {
    if (!isRecord(value) || !Array.isArray(value.content))
        return null;
    const parts = value.content.flatMap((block) => (isRecord(block) && block.type === 'reasoning' && typeof block.text === 'string'
        ? [block.text]
        : []));
    return parts.length === 0 ? null : parts.join('\n\n');
}
/** Parse only the seven event shapes needed by the read-only model-stage fold. */
export function modelTraceEventOf(value) {
    if (!isRecord(value) || typeof value.type !== 'string')
        return null;
    const location = locationOf(value);
    if (location === null || !isRecord(value.data))
        return null;
    const data = value.data;
    if (value.type === 'step/start')
        return { ...location, kind: 'step-start' };
    if (value.type === 'step/end')
        return { ...location, kind: 'step-end' };
    if (value.type === 'llm/retry') {
        const retry = nonNegativeNumber(data.retry);
        const delayMs = nonNegativeNumber(data.delayMs);
        return retry === null || delayMs === null
            ? null
            : { ...location, kind: 'retry', retry, delayMs };
    }
    if (value.type === 'assistant/message') {
        return {
            ...location,
            kind: 'message',
            reasoningText: reasoningTextOf(data.message),
            reasoningTokens: reasoningTokensOf(data.usage),
        };
    }
    // RC1 historical chunkrow envelopes preserve fragment times and sequence identities.
    if (['chunkrow/reasoning-chunks', 'chunkrow/text-chunks', 'chunkrow/tool-call-chunks'].includes(value.type)) {
        const tool = value.type === 'chunkrow/tool-call-chunks';
        const parts = tool ? data.args : data.texts;
        const gaps = data.dt;
        if (!Array.isArray(parts) || !parts.length || !parts.every(p => typeof p === 'string')
            || !Array.isArray(gaps) || gaps.length !== parts.length - 1 || !gaps.every(Number.isSafeInteger))
            return null;
        let time = location.time;
        const fragments = [];
        for (let i = 0; i < parts.length; i++) {
            if (i > 0)
                time += gaps[i - 1];
            if (!Number.isSafeInteger(time))
                return null;
            const text = parts[i];
            if (text !== '' || (tool && typeof data.name === 'string'))
                fragments.push({ seq: location.seq + i, time, text });
        }
        const first = fragments[0];
        if (!first)
            return null;
        const base = { ...location, time: first.time, lastSeq: location.seq + parts.length - 1 };
        return value.type === 'chunkrow/reasoning-chunks'
            ? { ...base, kind: 'reasoning-delta', text: fragments.map(f => f.text).join(''), fragments }
            : { ...base, kind: 'output-delta' };
    }
    if (value.type !== 'assistant/chunk' || !isRecord(data.chunk) || typeof data.chunk.type !== 'string') {
        return null;
    }
    const chunk = data.chunk;
    if (chunk.type === 'reasoning-delta') {
        return typeof chunk.text === 'string' && chunk.text !== ''
            ? { ...location, kind: 'reasoning-delta', text: chunk.text }
            : null;
    }
    if (chunk.type === 'text-delta') {
        return typeof chunk.text === 'string' && chunk.text !== ''
            ? { ...location, kind: 'output-delta' }
            : null;
    }
    if (chunk.type === 'tool-call-delta') {
        const hasArguments = typeof chunk.argumentsDelta === 'string' && chunk.argumentsDelta !== '';
        return hasArguments || typeof chunk.name === 'string'
            ? { ...location, kind: 'output-delta' }
            : null;
    }
    if (chunk.type === 'usage') {
        return { ...location, kind: 'usage', reasoningTokens: reasoningTokensOf(chunk.usage) };
    }
    return null;
}
function runningAttempt(attempt, startedAt) {
    return {
        kind: 'running',
        attempt,
        startedAt,
        firstTokenTime: null,
        firstReasoningTime: null,
        lastReasoningTime: null,
        firstOutputTime: null,
        reasoningText: '',
        fragments: [],
    };
}
export function startModelStepTrace(event) {
    return {
        turn: event.turn,
        step: event.step,
        startSeq: event.seq,
        lastSeq: event.seq,
        startTime: event.time,
        attempts: [runningAttempt(1, event.time)],
        reasoningTokens: null,
    };
}
function partialModelStepTrace(event) {
    return {
        turn: event.turn,
        step: event.step,
        startSeq: event.seq,
        lastSeq: event.seq,
        startTime: null,
        attempts: [runningAttempt(1, null)],
        reasoningTokens: null,
    };
}
function replaceLast(attempts, attempt) {
    if (attempts.length === 1)
        return [attempt];
    return [attempts[0], ...attempts.slice(1, -1), attempt];
}
function appendAttempt(attempts, attempt) {
    return [...attempts, attempt];
}
function sameStep(trace, event) {
    return trace.turn === event.turn && trace.step === event.step;
}
/** Fold one normalized event without discarding reasoning from a retried attempt. */
export function updateModelStepTrace(trace, event) {
    if (!sameStep(trace, event) || event.kind === 'step-start')
        return trace;
    const current = { ...trace, lastSeq: Math.max(trace.lastSeq, event.lastSeq ?? event.seq) };
    const attempt = trace.attempts.at(-1);
    if (attempt === undefined)
        return trace;
    if (event.kind === 'usage') {
        return event.reasoningTokens === null ? current : { ...current, reasoningTokens: event.reasoningTokens };
    }
    if (event.kind === 'reasoning-delta') {
        if (attempt.kind !== 'running')
            return current;
        const fragments = event.fragments ?? [{ seq: event.seq, time: event.time, text: event.text }];
        return {
            ...current,
            attempts: replaceLast(trace.attempts, {
                ...attempt,
                firstTokenTime: attempt.firstTokenTime ?? event.time,
                firstReasoningTime: attempt.firstReasoningTime ?? event.time,
                lastReasoningTime: fragments.at(-1)?.time ?? event.time,
                reasoningText: attempt.reasoningText + event.text,
                fragments: [...attempt.fragments, ...fragments],
            }),
        };
    }
    if (event.kind === 'output-delta') {
        if (attempt.kind !== 'running')
            return current;
        return {
            ...current,
            attempts: replaceLast(trace.attempts, {
                ...attempt,
                firstTokenTime: attempt.firstTokenTime ?? event.time,
                firstOutputTime: attempt.firstOutputTime ?? event.time,
            }),
        };
    }
    if (event.kind === 'retry') {
        if (attempt.kind !== 'running')
            return current;
        const retried = {
            ...attempt,
            kind: 'retried',
            endedAt: event.time,
            retry: event.retry,
            retryDelayMs: event.delayMs,
        };
        return {
            ...current,
            attempts: appendAttempt(replaceLast(trace.attempts, retried), runningAttempt(attempt.attempt + 1, null)),
        };
    }
    if (event.kind === 'message') {
        const reasoningTokens = event.reasoningTokens ?? trace.reasoningTokens;
        if (attempt.kind !== 'running')
            return { ...current, reasoningTokens };
        return {
            ...current,
            reasoningTokens,
            attempts: replaceLast(trace.attempts, {
                ...attempt,
                kind: 'complete',
                endedAt: event.time,
                reasoningText: event.reasoningText ?? attempt.reasoningText,
            }),
        };
    }
    if (attempt.kind !== 'running')
        return current;
    return {
        ...current,
        attempts: replaceLast(trace.attempts, {
            ...attempt,
            kind: 'interrupted',
            endedAt: event.time,
        }),
    };
}
/** Fold raw Session-like values for golden replay and boundary tests. */
export function foldModelTraceEvents(values) {
    const traces = new Map();
    for (const value of values) {
        const event = modelTraceEventOf(value);
        if (event === null)
            continue;
        const key = `${event.turn}:${event.step}`;
        const current = traces.get(key);
        if (event.kind === 'step-start') {
            traces.set(key, startModelStepTrace(event));
            continue;
        }
        const trace = current ?? partialModelStepTrace(event);
        traces.set(key, updateModelStepTrace(trace, event));
    }
    return traces;
}
function attemptEnd(attempt, now) {
    return attempt.kind === 'running' ? now : attempt.endedAt;
}
function firstTokenTime(trace) {
    for (const attempt of trace.attempts) {
        if (attempt.firstTokenTime !== null)
            return attempt.firstTokenTime;
    }
    return null;
}
function visibleReasoningDuration(trace, _now) {
    let sampled = false;
    let total = 0;
    for (const attempt of trace.attempts) {
        if (attempt.firstReasoningTime === null || attempt.lastReasoningTime === null)
            continue;
        if (attempt.firstOutputTime !== null && attempt.lastReasoningTime > attempt.firstOutputTime)
            continue; // interleaved timing remains unattributed
        sampled = true;
        // An open request does not prove continuously emitted reasoning.
        const end = attempt.lastReasoningTime;
        total += Math.max(0, end - attempt.firstReasoningTime);
    }
    return sampled ? total : null;
}
/** Derive additive display segments without calling unobserved latency Thinking. */
export function modelStageMetrics(trace, now) {
    const last = trace.attempts.at(-1);
    const live = last?.kind === 'running';
    const end = last === undefined ? null : attemptEnd(last, now);
    const totalMs = trace.startTime === null || end === null ? null : Math.max(0, end - trace.startTime);
    const firstToken = firstTokenTime(trace);
    const firstResponseMs = trace.startTime === null || firstToken === null
        ? null
        : Math.max(0, firstToken - trace.startTime);
    const visibleReasoningMs = visibleReasoningDuration(trace, now);
    const finalReasoning = last?.lastReasoningTime ?? null;
    const outputStart = last?.firstOutputTime ?? null;
    const outputMs = outputStart === null || end === null || (live && finalReasoning !== null && last?.firstOutputTime === null)
        ? null
        : Math.max(0, end - outputStart);
    const attributed = (firstResponseMs ?? 0) + (visibleReasoningMs ?? 0) + (outputMs ?? 0);
    const unattributedMs = totalMs === null ? null : Math.max(0, totalMs - attributed);
    return {
        kind: trace.startTime === null ? 'partial' : 'measured',
        live,
        totalMs,
        firstResponseMs,
        visibleReasoningMs,
        outputMs,
        unattributedMs,
    };
}
export function hasReasoningEvidence(trace) {
    return trace.attempts.some(attempt => attempt.reasoningText.trim() !== '' || attempt.fragments.length > 0);
}
//# sourceMappingURL=model-trace.js.map