function emptyLayerOverrides() {
    return {
        phase: {},
        step: {},
        cluster: {},
        model: {},
        reasoning: {},
    };
}
export function createDisclosureState(depth = 'overview') {
    return { depth, turns: {}, layers: emptyLayerOverrides() };
}
/** Overview keeps the automatic Turn policy; detail opens every Turn by default. */
export function turnDisclosureOpen(state, turn, overviewDefaultOpen) {
    return state.turns[turn] ?? (state.depth === 'detail' || overviewDefaultOpen);
}
/** Overview stops at phase headers; detail opens every nested level by default. */
export function layerDisclosureOpen(state, layer, key) {
    return state.layers[layer][key] ?? state.depth === 'detail';
}
export function setLayerDisclosure(state, layer, key, open) {
    return {
        ...state,
        layers: {
            ...state.layers,
            [layer]: {
                ...state.layers[layer],
                [key]: open,
            },
        },
    };
}
export function toggleTurnDisclosure(state, turn, overviewDefaultOpen) {
    return {
        ...state,
        turns: {
            ...state.turns,
            [turn]: !turnDisclosureOpen(state, turn, overviewDefaultOpen),
        },
    };
}
export function toggleLayerDisclosure(state, layer, key) {
    return setLayerDisclosure(state, layer, key, !layerDisclosureOpen(state, layer, key));
}
/** Choosing a depth applies it immediately instead of inheriting stale manual folds. */
export function chooseDisclosureDepth(depth) {
    return createDisclosureState(depth);
}
/** Session-specific ids may change, while the user's chosen depth remains useful. */
export function resetDisclosureOverrides(state) {
    return createDisclosureState(state.depth);
}
//# sourceMappingURL=disclosure-depth.js.map