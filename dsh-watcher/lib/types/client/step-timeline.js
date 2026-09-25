/** Compose the visible rows owned by one authoritative DSH Step. */
export function stepTimelineEntries(step) {
    const occurrences = step.items
        .filter(item => item.source !== 'model')
        .map((item, occurrenceIndex) => ({ kind: 'occurrence', item, occurrenceIndex }));
    if (step.model === null)
        return occurrences;
    // RC8 opens step/start before it appends the entered user/message records.
    // That lifecycle boundary starts timing, but it is not a causal claim that
    // the model ran before the prompt. Keep only the entered prompt rows ahead
    // of the model; steering queued during a live Step remains after it.
    const firstAgentOccurrence = occurrences.findIndex(entry => entry.item.source !== 'user');
    const modelIndex = firstAgentOccurrence < 0 ? occurrences.length : firstAgentOccurrence;
    return [
        ...occurrences.slice(0, modelIndex),
        { kind: 'model', trace: step.model },
        ...occurrences.slice(modelIndex),
    ];
}
//# sourceMappingURL=step-timeline.js.map