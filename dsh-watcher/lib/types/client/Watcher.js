import { jsx as _jsx, jsxs as _jsxs, Fragment as _Fragment } from "react/jsx-runtime";
import { useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { DiffBlock, IconCheckOutline16, IconChevronRightOutline14, IconCopyOutline16, IconRefreshOutline14, JsonTree, MarkdownText, Pill, ReadBlock, StateDot, TerminalBlock, useAnchoredPosition, writeClipboard, } from '@deepseek-ai/dsh-client-ui-primitives';
import { createFollow } from "../hub/follow.js";
import { clusterOutcomeSummary, clusterWorkItems, } from "../hub/aggregation.js";
import { foldSnapshot, mergeObservedPictures, } from "../observation/fold.js";
import css from './Watcher.module.css';
import { SessionInsights } from "./Insights.js";
import { OVERVIEW_STATE_LABEL, overviewStateOf, turnNeedsDefaultDisclosure, turnOverviewSummary, } from "../hub/overview.js";
import { deriveTurnPerformance, formatTokensPerSecond, groupElapsedMs, itemElapsedMs, stepElapsedMs, turnElapsedReading, } from "../observation/performance.js";
import { hasReasoningEvidence, modelStageMetrics, } from "../observation/model-trace.js";
import { stepTimelineEntries } from "./step-timeline.js";
import { chooseDisclosureDepth, createDisclosureState, layerDisclosureOpen, resetDisclosureOverrides, setLayerDisclosure, toggleLayerDisclosure, toggleTurnDisclosure, turnDisclosureOpen, } from "./disclosure-depth.js";
const PANEL_GAP = 8;
const PANEL_MARGIN = 12;
const UNPLACED_PANEL_STYLE = { visibility: 'hidden', left: 0, top: 0 };
const MARKDOWN_LABELS = Object.freeze({
    code: Object.freeze({ copyLabel: '复制', copiedLabel: '已复制' }),
    footnotes: '脚注',
});
const TERMINAL_LABELS = Object.freeze({
    signal: (signal) => `信号 ${signal}`,
    exitCode: (exitCode) => `退出码 ${exitCode}`,
    running: '运行中',
    failed: '失败',
    done: '完成',
    copy: '复制',
    copied: '已复制',
    noOutput: '没有输出',
    collapseAria: '收起终端输出',
    collapse: '收起',
    expandAria: (hidden) => `展开其余 ${hidden} 行终端输出`,
    expand: (hidden) => `展开 ${hidden} 行`,
});
const READ_LABELS = Object.freeze({
    window: (shown, total) => `显示 ${shown}/${total} 行`,
    copy: '复制',
    copied: '已复制',
    collapseAria: '收起文件内容',
    expandAria: (hidden) => `展开其余 ${hidden} 行文件内容`,
    collapse: '收起',
    expand: (hidden) => `展开 ${hidden} 行`,
});
const DIFF_LABELS = Object.freeze({
    copy: '复制',
    copied: '已复制',
    collapseAria: '收起变更内容',
    expandAria: (hidden) => `展开其余 ${hidden} 行变更`,
    collapse: '收起',
    expand: (hidden) => `展开 ${hidden} 行`,
    files: (count) => `${count} 个文件`,
});
const JSON_LABELS = Object.freeze({
    copyValue: '复制值',
    copyJson: '复制 JSON',
    copyPath: '复制路径',
    copyPrettyJson: '复制格式化 JSON',
    copyCompactJson: '复制紧凑 JSON',
    copied: '已复制',
    copyFailed: '复制失败',
    collapseNode: '收起节点',
    expandNode: '展开节点',
    copyButtonTitle: (action) => action,
});
const STATUS_LABEL = {
    running: '进行中',
    waiting: '等待你',
    success: '成功',
    failure: '失败',
    returned: '已返回',
    interrupted: '已中断',
    unknown: '未知',
};
function dotState(status) {
    if (status === 'running')
        return 'ongoing';
    if (status === 'waiting')
        return 'warning';
    if (status === 'failure' || status === 'interrupted')
        return 'error';
    if (status === 'success')
        return 'done';
    return null;
}
function StatusMark({ status, className }) {
    const state = dotState(status);
    return state === null
        ? _jsx("span", { className: `${css.neutralDot}${className === undefined ? '' : ` ${className}`}`, "data-status": status, "aria-hidden": "true" })
        : _jsx(StateDot, { state: state, size: 10, className: className });
}
function formatDuration(durationMs) {
    if (durationMs === null)
        return null;
    if (durationMs < 1000)
        return `${Math.round(durationMs)} ms`;
    const secondsWithDecimal = Math.round(durationMs / 100) / 10;
    if (secondsWithDecimal < 60) {
        return `${secondsWithDecimal < 10 ? secondsWithDecimal.toFixed(1) : Math.round(secondsWithDecimal)} s`;
    }
    const totalSeconds = Math.round(durationMs / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    if (minutes >= 60) {
        const hours = Math.floor(minutes / 60);
        return `${hours}h ${minutes % 60}m`;
    }
    return `${minutes}m ${seconds}s`;
}
function turnDuration(turn, live, now) {
    const reading = turnElapsedReading(turn, live, now);
    if (reading.kind === 'unavailable')
        return null;
    const duration = formatDuration(reading.durationMs);
    if (duration === null)
        return null;
    return {
        kind: reading.kind === 'exact' ? 'exact' : 'partial',
        value: duration,
    };
}
function useLiveClock(enabled) {
    const [now, setNow] = useState(() => Date.now());
    useEffect(() => {
        if (!enabled)
            return;
        setNow(Date.now());
        const timer = setInterval(() => setNow(Date.now()), 1000);
        return () => clearInterval(timer);
    }, [enabled]);
    return now;
}
function TurnMetricStrip({ performance }) {
    const metrics = [
        ['模型', formatDuration(performance.modelMs)],
        ['工具', formatDuration(performance.toolMs)],
        ['首 token', formatDuration(performance.ttftMs)],
    ].filter((metric) => metric[1] !== null);
    if (metrics.length === 0)
        return null;
    return (_jsx("dl", { className: css.turnMetrics, "aria-label": "\u5BF9\u8BDD\u8F6E\u6B21\u6027\u80FD\u5206\u89E3", children: metrics.map(([label, value]) => (_jsxs("div", { className: css.turnMetric, children: [_jsx("dt", { children: label }), _jsx("dd", { children: value })] }, label))) }));
}
function rawOf(item) {
    if (item.rawText.trim() !== '')
        return item.rawText;
    try {
        return JSON.stringify(item.rawValue, null, 2) ?? String(item.rawValue);
    }
    catch {
        return String(item.rawValue);
    }
}
function isJsonValue(value) {
    return typeof value === 'object' && value !== null;
}
function CopyRawButton({ text }) {
    const [copied, setCopied] = useState(false);
    const timerRef = useRef(null);
    useEffect(() => () => {
        if (timerRef.current !== null)
            clearTimeout(timerRef.current);
    }, []);
    const copy = () => {
        void writeClipboard(text).then((ok) => {
            if (!ok)
                return;
            setCopied(true);
            if (timerRef.current !== null)
                clearTimeout(timerRef.current);
            timerRef.current = setTimeout(() => setCopied(false), 1500);
        });
    };
    return (_jsxs("button", { type: "button", className: css.copyRaw, onClick: copy, "aria-label": copied ? '原始数据已复制' : '复制原始数据', children: [copied ? _jsx(IconCheckOutline16, { size: 14 }) : _jsx(IconCopyOutline16, { size: 14 }), copied ? '已复制' : '复制'] }));
}
function ResultPresentation({ presentation }) {
    switch (presentation.kind) {
        case 'terminal':
            return (_jsx(TerminalBlock, { command: presentation.command, cwd: presentation.cwd ?? undefined, output: presentation.output, exitCode: presentation.exitCode ?? undefined, signal: presentation.signal ?? undefined, running: presentation.running, maxLines: 18, labels: TERMINAL_LABELS }));
        case 'read':
            return (_jsx(ReadBlock, { label: presentation.label, lang: presentation.lang ?? undefined, lines: presentation.lines, totalLines: presentation.totalLines, maxLines: 18, labels: READ_LABELS }));
        case 'diff':
            return _jsx(DiffBlock, { diffs: presentation.diffs, maxLines: 18, labels: DIFF_LABELS });
        case 'json':
            return _jsx("div", { className: css.jsonSurface, children: _jsx(JsonTree, { data: presentation.data, label: "\u7ED3\u6784\u5316\u7ED3\u679C", labels: JSON_LABELS }) });
        case 'text':
            return (_jsx("article", { className: css.documentResult, "data-watcher-document": "", children: _jsx(MarkdownText, { text: presentation.text, labels: MARKDOWN_LABELS }) }));
        case 'image':
            return (_jsxs("div", { className: css.artifactResult, children: [_jsx("div", { className: css.artifactGlyph, "aria-hidden": "true", children: "\u25A7" }), _jsx("strong", { children: "\u56FE\u7247\u9644\u4EF6" }), _jsx("span", { children: "\u9644\u4EF6\u5DF2\u4FDD\u7559\u5728\u672C\u6B21\u4F1A\u8BDD\u8BB0\u5F55\u4E2D" }), isJsonValue(presentation.attachment)
                        ? _jsx("div", { className: css.jsonSurface, children: _jsx(JsonTree, { data: presentation.attachment, label: "\u56FE\u7247\u9644\u4EF6\u4FE1\u606F", labels: JSON_LABELS }) })
                        : null] }));
        case 'empty':
            return _jsx("div", { className: css.detailEmpty, children: "\u8FD9\u6B21\u6267\u884C\u8FD8\u6CA1\u6709\u53EF\u663E\u793A\u7684\u7ED3\u679C" });
    }
}
function preferredItem(group) {
    return group.items.find(item => item.status === 'failure' && item.recoveredBy === null)
        ?? group.items.find(item => item.status === 'waiting' || item.status === 'running')
        ?? group.items.at(-1)
        ?? null;
}
function groupStatusLabel(group) {
    return group.status === 'failure' ? '含失败记录' : STATUS_LABEL[group.status];
}
function itemPattern(item) {
    if (item.retryIndex > 0)
        return `重试 ${item.retryIndex} 次`;
    if (item.iterationIndex > 0)
        return `迭代第 ${item.iterationIndex + 1} 版`;
    if (item.recoveredBy !== null)
        return '后续已恢复';
    return null;
}
function ExecutionInspector({ group, selectedItemId, live, now, onSelectItem, onBack, }) {
    const [tab, setTab] = useState('result');
    const fallback = preferredItem(group);
    const selected = group.items.find(item => item.id === selectedItemId) ?? fallback;
    useEffect(() => setTab('result'), [group.id, selected?.id]);
    if (selected === null)
        return null;
    const duration = formatDuration(itemElapsedMs(selected, live && selected.status === 'running', now));
    const groupDuration = formatDuration(groupElapsedMs(group, live, now));
    const raw = rawOf(selected);
    const hasInput = Object.keys(selected.args).length > 0;
    const pattern = itemPattern(selected);
    return (_jsxs("aside", { className: css.inspector, "aria-label": `${group.title} 的执行详情`, "data-ud-check": "watcher-inspector", "data-ud-role": "panel", children: [_jsxs("header", { className: css.inspectorHeader, children: [_jsxs("button", { type: "button", className: css.inspectorBack, onClick: onBack, "aria-label": "\u8FD4\u56DE\u5DE5\u4F5C\u8DEF\u5F84", children: [_jsx(IconChevronRightOutline14, { size: 13, "aria-hidden": "true" }), "\u5DE5\u4F5C\u8DEF\u5F84"] }), _jsxs("div", { className: css.statusLine, "data-status": group.status, children: [_jsx(StatusMark, { status: group.status }), _jsx("span", { children: groupStatusLabel(group) }), _jsxs("span", { className: css.location, children: ["\u5BF9\u8BDD\u8F6E\u6B21 ", group.turn || '—', " \u00B7 ", group.steps.length, " \u4E2A\u6B65\u9AA4", groupDuration === null ? '' : ` · ${groupDuration}`] })] }), _jsx("h2", { className: css.inspectorTitle, children: group.title }), _jsx("p", { className: css.inspectorSummary, children: group.subtitle }), _jsxs("div", { className: css.groupSignals, "aria-label": "\u5DE5\u4F5C\u6A21\u5F0F", children: [group.parallelStepCount > 0 ? _jsxs("span", { children: ["\u5E76\u884C ", group.parallelStepCount, " \u6B21"] }) : null, group.retryCount > 0 ? _jsxs("span", { "data-retry": "", children: ["\u91CD\u8BD5 ", group.retryCount, " \u6B21"] }) : null, group.iterationCount > 0 ? _jsxs("span", { children: ["\u6709 ", group.iterationCount, " \u6B21\u8FED\u4EE3"] }) : null, group.unconfirmedFailureCount > 0 ? _jsxs("span", { "data-error": "", children: [group.unconfirmedFailureCount, " \u6761\u5931\u8D25\u540E\u672A\u89C1\u6210\u529F\u8BC1\u636E"] }) : null] })] }), _jsxs("div", { className: css.inspectorBody, children: [_jsxs("section", { className: css.executionSection, "aria-labelledby": `execution-title-${group.id}`, children: [_jsxs("div", { className: css.sectionHeading, children: [_jsx("h3", { id: `execution-title-${group.id}`, children: "\u6267\u884C\u8DEF\u5F84" }), _jsxs("span", { children: [group.items.length, " \u6761\u8BB0\u5F55"] })] }), _jsx("div", { className: css.executionList, children: group.steps.map((step, stepIndex) => {
                                    const stepLive = live && stepIndex === group.steps.length - 1;
                                    const stepDuration = formatDuration(stepElapsedMs(step, stepLive, now));
                                    return _jsxs("div", { className: css.stepBlock, "data-parallel": step.parallel ? '' : undefined, children: [_jsxs("div", { className: css.stepHeading, children: [_jsxs("span", { children: ["\u6B65\u9AA4 ", step.step || '—'] }), _jsxs("span", { className: css.stepSignals, children: [stepDuration === null ? null : _jsx("span", { className: css.stepDuration, children: stepDuration }), step.parallel ? _jsxs("span", { className: css.parallelLabel, children: [step.executionCount, " \u9879\u5E76\u884C"] }) : null] })] }), _jsx("div", { className: css.occurrences, children: step.items.map((item, itemIndex) => {
                                                    const itemDuration = formatDuration(itemElapsedMs(item, stepLive && item.status === 'running', now));
                                                    return _jsxs("button", { type: "button", className: css.occurrence, "data-selected": item.id === selected.id ? '' : undefined, "data-status": item.status, "aria-pressed": item.id === selected.id, onClick: () => onSelectItem(item.id), children: [_jsx(StatusMark, { status: item.status, className: css.occurrenceDot }), _jsxs("span", { className: css.occurrenceCopy, children: [_jsx("span", { className: css.occurrenceTitle, children: item.title }), _jsxs("span", { className: css.occurrenceMeta, children: [item.toolName ?? item.source, step.items.length > 1 ? ` · 分支 ${itemIndex + 1}` : '', itemPattern(item) === null ? '' : ` · ${itemPattern(item)}`] })] }), itemDuration === null ? null : _jsx("span", { className: css.occurrenceDuration, children: itemDuration }), _jsx(IconChevronRightOutline14, { size: 12, className: css.occurrenceChevron })] }, item.id);
                                                }) })] }, step.id);
                                }) })] }), _jsxs("section", { className: css.detailSection, "aria-labelledby": `detail-title-${selected.id}`, children: [_jsxs("div", { className: css.detailHeader, children: [_jsxs("div", { className: css.detailIdentity, children: [_jsxs("div", { className: css.detailStatus, "data-status": selected.status, children: [_jsx(StatusMark, { status: selected.status }), _jsx("span", { children: STATUS_LABEL[selected.status] }), pattern === null ? null : _jsx("span", { className: css.patternLabel, children: pattern })] }), _jsx("h3", { id: `detail-title-${selected.id}`, children: selected.title }), _jsx("p", { title: selected.subtitle, children: selected.subtitle || '没有补充说明' })] }), _jsxs("dl", { className: css.metrics, children: [duration === null ? null : _jsxs(_Fragment, { children: [_jsx("dt", { children: "\u8017\u65F6" }), _jsx("dd", { children: duration })] }), selected.exitCode === null ? null : _jsxs(_Fragment, { children: [_jsx("dt", { children: "\u9000\u51FA\u7801" }), _jsx("dd", { "data-error": selected.exitCode === 0 ? undefined : '', children: selected.exitCode })] }), selected.signal === null ? null : _jsxs(_Fragment, { children: [_jsx("dt", { children: "\u4FE1\u53F7" }), _jsx("dd", { "data-error": "", children: selected.signal })] })] })] }), _jsx("div", { className: css.tabs, role: "tablist", "aria-label": "\u6267\u884C\u6570\u636E", children: [
                                    ['result', '结果'],
                                    ['input', '输入'],
                                    ['raw', '原始'],
                                ].map(([id, label]) => (_jsx("button", { type: "button", role: "tab", "aria-selected": tab === id, className: css.tab, "data-active": tab === id ? '' : undefined, onClick: () => setTab(id), children: label }, id))) }), _jsxs("div", { className: css.tabPanel, role: "tabpanel", children: [tab === 'result' ? _jsx(ResultPresentation, { presentation: selected.presentation }) : null, tab === 'input'
                                        ? hasInput
                                            ? _jsx("div", { className: css.jsonSurface, children: _jsx(JsonTree, { data: selected.args, label: "\u6267\u884C\u8F93\u5165", labels: JSON_LABELS }) })
                                            : _jsx("div", { className: css.detailEmpty, children: "\u8FD9\u6761\u8BB0\u5F55\u6CA1\u6709\u5DE5\u5177\u8F93\u5165" })
                                        : null, tab === 'raw'
                                        ? (_jsxs("div", { className: css.rawPanel, children: [_jsxs("div", { className: css.rawToolbar, children: [_jsx("span", { children: "\u5B8C\u6574\u539F\u59CB\u6570\u636E \u00B7 \u4E0D\u622A\u65AD" }), _jsx(CopyRawButton, { text: raw })] }), _jsx("pre", { children: raw || '没有原始数据' })] }))
                                        : null] })] })] }), _jsx("footer", { className: css.inspectorFooter, children: "\u53EA\u8BFB\u89C2\u5BDF \u00B7 \u4E0D\u4F1A\u6539\u53D8 Agent" })] }));
}
/** The pupil scans only while live; the complete eye remains a useful static glyph. */
function IconLivingEye({ size = 17 }) {
    return (_jsx("svg", { className: css.eye, "data-ud-motion": "watcher-eye-scan", width: size, height: size, viewBox: "0 0 18 18", fill: "none", "aria-hidden": "true", children: _jsxs("g", { className: css.eyeBlink, children: [_jsx("path", { className: css.eyeOutline, fill: "currentColor", fillRule: "evenodd", d: "M9 3.25c-3.93 0-7.03 2.88-7.9 5.75.87 2.87 3.97 5.75 7.9 5.75s7.03-2.88 7.9-5.75C16.03 6.13 12.93 3.25 9 3.25Zm0 9.95A4.2 4.2 0 1 1 9 4.8a4.2 4.2 0 0 1 0 8.4Z" }), _jsxs("g", { className: css.eyePupil, children: [_jsx("circle", { cx: "9", cy: "9", r: "2.05", fill: "currentColor" }), _jsx("circle", { cx: "9.65", cy: "8.35", r: "0.45", fill: "var(--dsw-specific-menu)", opacity: "0.9" })] })] }) }));
}
function groupBadges(group) {
    return (_jsxs("span", { className: css.groupBadges, "aria-hidden": "true", children: [group.parallelStepCount > 0
                ? _jsx("span", { "data-kind": "parallel", children: group.parallelStepCount === 1 ? '并行' : `并行 ${group.parallelStepCount} 组` })
                : null, group.retryCount > 0 ? _jsxs("span", { "data-kind": "retry", children: ["\u91CD\u8BD5 ", group.retryCount] }) : null, group.iterationCount > 0 ? _jsxs("span", { "data-kind": "iteration", children: ["\u8FED\u4EE3 ", group.iterationCount] }) : null] }));
}
function showOverviewTag(state) {
    return state === 'waiting' || state === 'failure' || state === 'interrupted' || state === 'partial';
}
function itemMeta(item, { branch, step }) {
    return [
        step === null ? null : `步骤 ${step || '—'}`,
        item.toolName ?? item.source,
        branch === null ? null : `分支 ${branch}`,
        itemPattern(item),
    ].filter((part) => part !== null && part !== '').join(' · ');
}
function branchNumberOf(step, item) {
    if (!step.parallel)
        return null;
    const index = step.items.findIndex(candidate => candidate.id === item.id);
    return index < 0 ? null : index + 1;
}
function clusterBasisLabel(cluster) {
    if (cluster.executionCount < 2)
        return null;
    if (cluster.basis === 'mutable-target' || cluster.basis === 'shared-target')
        return '同一目标';
    if (cluster.basis === 'exact-call')
        return '同一指令';
    return null;
}
function reasoningAttemptDuration(attempt, now) {
    if (attempt.firstReasoningTime === null || attempt.lastReasoningTime === null)
        return null;
    const end = attempt.kind === 'running' && attempt.firstOutputTime === null
        ? now
        : attempt.lastReasoningTime;
    return Math.max(0, end - attempt.firstReasoningTime);
}
function reasoningAttemptState(attempt) {
    if (attempt.kind === 'running')
        return '生成中';
    if (attempt.kind === 'retried')
        return '已重试';
    if (attempt.kind === 'interrupted')
        return '已中断';
    return '已完成';
}
function ModelStage({ trace, stepId, now, open, disclosure, onToggle, onToggleReasoning, }) {
    const metrics = modelStageMetrics(trace, now);
    const hasReasoning = hasReasoningEvidence(trace);
    const total = formatDuration(metrics.totalMs);
    const visibleReasoning = formatDuration(metrics.visibleReasoningMs);
    const reasoningAttempts = trace.attempts.filter(attempt => attempt.reasoningText.trim() !== '');
    const summary = [
        total === null ? '时间不完整' : `模型 ${total}`,
        hasReasoning
            ? visibleReasoning === null ? '可见推理已记录' : `可见推理 ${visibleReasoning}`
            : null,
        trace.reasoningTokens === null ? null : `${trace.reasoningTokens.toLocaleString('zh-CN')} 推理 token`,
        metrics.live ? '进行中' : null,
    ].filter((value) => value !== null).join(' · ');
    const segments = [
        {
            key: 'wait',
            label: '首响应等待',
            durationMs: metrics.firstResponseMs,
            unavailableLabel: '时间戳不可用',
        },
        {
            key: 'reasoning',
            label: '可见推理',
            durationMs: metrics.visibleReasoningMs,
            unavailableLabel: hasReasoning ? '分段耗时不可用' : '未记录',
        },
        {
            key: 'output',
            label: '输出 / 工具意图',
            durationMs: metrics.outputMs,
            unavailableLabel: '时间戳不可用',
        },
        ...metrics.unattributedMs !== null && metrics.unattributedMs > 0
            ? [{
                    key: 'unattributed',
                    label: '重试 / 未归因',
                    durationMs: metrics.unattributedMs,
                    unavailableLabel: '不可用',
                }]
            : [],
    ];
    const measuredSegments = segments.filter((segment) => (segment.durationMs !== null && segment.durationMs > 0));
    const bodyId = `watcher-model-stage-${stepId}`;
    return (_jsxs("section", { className: css.modelStage, "data-live": metrics.live ? '' : undefined, children: [_jsxs("button", { type: "button", className: css.modelStageToggle, "aria-expanded": open, "aria-controls": bodyId, title: "\u6A21\u578B\u9636\u6BB5\u53EA\u4F7F\u7528 DSH \u4F1A\u8BDD\u4E2D\u4F9B\u5E94\u5546\u516C\u5F00\u5199\u5165\u7684\u4E8B\u4EF6", onClick: onToggle, children: [_jsx(IconChevronRightOutline14, { size: 11, className: css.modelStageChevron }), _jsx("span", { className: css.modelStageGlyph, "aria-hidden": "true" }), _jsxs("span", { className: css.modelStageCopy, children: [_jsx("span", { className: css.modelStageTitle, children: "\u6A21\u578B\u9636\u6BB5" }), _jsx("span", { className: css.modelStageSummary, children: summary })] })] }), _jsxs("div", { id: bodyId, className: css.modelStageBody, hidden: !open, children: [measuredSegments.length === 0
                        ? null
                        : (_jsx("div", { className: css.modelStageBar, "aria-label": "\u6A21\u578B\u9636\u6BB5\u8017\u65F6\u6BD4\u4F8B", children: measuredSegments.map(segment => (_jsx("span", { "data-segment": segment.key, style: { flexGrow: Math.max(segment.durationMs, 1) }, title: `${segment.label} ${formatDuration(segment.durationMs) ?? ''}` }, segment.key))) })), _jsx("dl", { className: css.modelStageLedger, children: segments.map(segment => (_jsxs("div", { className: css.modelStageMetric, children: [_jsxs("dt", { children: [_jsx("span", { className: css.modelStageSwatch, "data-segment": segment.key, "aria-hidden": "true" }), segment.label] }), _jsx("dd", { children: formatDuration(segment.durationMs) ?? segment.unavailableLabel })] }, segment.key))) }), reasoningAttempts.length === 0
                        ? _jsx("p", { className: css.modelStageNote, children: "\u672C Step \u6CA1\u6709\u4F9B\u5E94\u5546\u53EF\u89C1\u63A8\u7406\u8BB0\u5F55" })
                        : (_jsxs("div", { className: css.reasoningAttempts, children: [_jsx("p", { className: css.modelStageNote, children: "\u4EC5\u5C55\u793A\u4F9B\u5E94\u5546\u5199\u5165 DSH \u4F1A\u8BDD\u7684\u53EF\u89C1 reasoning\uFF1B\u4E0D\u8865\u5199\u672A\u8BB0\u5F55\u5185\u5BB9\u3002" }), reasoningAttempts.map(attempt => {
                                    const key = `${stepId}:attempt:${attempt.attempt}`;
                                    const reasoningOpen = layerDisclosureOpen(disclosure, 'reasoning', key);
                                    const duration = formatDuration(reasoningAttemptDuration(attempt, now));
                                    const meta = [
                                        reasoningAttemptState(attempt),
                                        duration ?? '分段耗时不可用',
                                        `${attempt.fragments.length} 个流片段`,
                                        attempt.kind === 'retried' ? `等待重试 ${formatDuration(attempt.retryDelayMs) ?? '—'}` : null,
                                    ].filter((value) => value !== null).join(' · ');
                                    return (_jsxs("section", { className: css.reasoningDisclosure, "data-open": reasoningOpen ? '' : undefined, children: [_jsxs("button", { type: "button", className: css.reasoningToggle, "aria-expanded": reasoningOpen, "aria-controls": `watcher-reasoning-${key}`, onClick: () => onToggleReasoning(key), children: [_jsx(IconChevronRightOutline14, { size: 11, className: css.reasoningChevron }), _jsx("span", { className: css.reasoningLabel, children: reasoningAttempts.length === 1 ? '推理记录' : `尝试 ${attempt.attempt}` }), _jsx("span", { className: css.reasoningMeta, children: meta })] }), _jsx("article", { id: `watcher-reasoning-${key}`, className: css.reasoningBody, hidden: !reasoningOpen, children: _jsx(MarkdownText, { text: attempt.reasoningText, labels: MARKDOWN_LABELS }) })] }, key));
                                })] }))] })] }));
}
function OverviewOccurrenceButton({ item, occurrenceNumber, branch, step, live, selected, now, onSelect, }) {
    const duration = formatDuration(itemElapsedMs(item, live, now));
    const meta = itemMeta(item, { branch, step });
    return (_jsxs("button", { type: "button", className: css.overviewOccurrence, "data-selected": selected ? '' : undefined, "data-current": live ? '' : undefined, "data-status": item.status, "data-ud-motion": "watcher-live-append", "aria-current": live ? 'step' : undefined, "aria-pressed": selected, "aria-label": `记录 ${occurrenceNumber}，${item.title}，${meta}${duration === null ? '' : `，耗时 ${duration}`}，${STATUS_LABEL[item.status]}`, onClick: onSelect, children: [_jsx("span", { className: css.overviewOccurrenceIndex, children: String(occurrenceNumber).padStart(2, '0') }), _jsx("span", { className: css.overviewOccurrenceDotSlot, "aria-hidden": "true", children: _jsx(StatusMark, { status: item.status, className: css.overviewOccurrenceDot }) }), _jsxs("span", { className: css.overviewOccurrenceCopy, children: [_jsx("span", { className: css.overviewOccurrenceTitle, children: item.title }), _jsx("span", { className: css.overviewOccurrenceMeta, children: meta })] }), duration === null ? null : _jsx("span", { className: css.overviewOccurrenceDuration, children: duration }), _jsx(IconChevronRightOutline14, { size: 12, className: css.overviewOccurrenceChevron })] }));
}
function PhaseOverview({ group, isNow, running, now, selectedGroup, selectedItemId, observationMode, open, disclosure, onToggle, onToggleLayer, onToggleReasoning, onSelectItem, }) {
    const phaseState = overviewStateOf(group.status, isNow);
    const phaseDuration = formatDuration(groupElapsedMs(group, isNow && running, now));
    const phaseSummary = [
        `${group.steps.length} 个步骤`,
        `${group.executionCount} 次执行`,
        phaseDuration,
    ].filter((part) => part !== null).join(' · ');
    const latestItemId = group.items.at(-1)?.id ?? null;
    const clusters = clusterWorkItems(group.items.filter(item => item.source !== 'model'));
    const modelSteps = group.steps.filter((step) => step.model !== null);
    const groupedModelsKey = `${group.id}:model-list`;
    const groupedModelsOpen = layerDisclosureOpen(disclosure, 'model', groupedModelsKey);
    return (_jsxs("section", { className: css.phase, "data-selected": selectedGroup ? '' : undefined, "data-now": isNow ? '' : undefined, "data-overview-state": phaseState, "aria-label": `${group.title}，${phaseSummary}，${OVERVIEW_STATE_LABEL[phaseState]}`, children: [_jsx("header", { className: css.phaseHeader, children: _jsxs("button", { type: "button", className: css.phaseToggle, "aria-expanded": open, "aria-controls": `watcher-phase-body-${group.id}`, "aria-label": `${group.title}，${phaseSummary}，${open ? '收起阶段' : '展开阶段'}`, onClick: onToggle, children: [_jsx("span", { className: css.phaseMarker, "data-state": phaseState, "aria-hidden": "true" }), _jsx(IconChevronRightOutline14, { size: 12, className: css.phaseChevron }), _jsxs("span", { className: css.phaseCopy, children: [_jsxs("span", { className: css.phaseTitleLine, children: [_jsx("span", { className: css.phaseTitle, "data-watcher-group-title": "", children: group.title }), groupBadges(group), showOverviewTag(phaseState)
                                            ? _jsx("span", { className: css.overviewTag, "data-state": phaseState, children: OVERVIEW_STATE_LABEL[phaseState] })
                                            : null] }), _jsx("span", { className: css.phaseMeta, children: phaseSummary })] })] }) }), _jsx("div", { id: `watcher-phase-body-${group.id}`, hidden: !open, children: observationMode === 'itemized'
                    ? (_jsx("div", { className: css.stepTimeline, "data-observation-mode": "itemized", children: group.steps.map(step => {
                            const stepLive = isNow && running && step.items.some(item => item.id === latestItemId && item.status === 'running');
                            const stepDuration = formatDuration(stepElapsedMs(step, stepLive, now));
                            const stepOpen = layerDisclosureOpen(disclosure, 'step', step.id);
                            const modelMetrics = step.model === null ? null : modelStageMetrics(step.model, now);
                            const modelDuration = formatDuration(modelMetrics?.totalMs ?? null);
                            const showStepTotal = stepDuration !== null && stepDuration !== modelDuration;
                            const modelOpen = layerDisclosureOpen(disclosure, 'model', step.id);
                            const timelineEntries = stepTimelineEntries(step);
                            return (_jsxs("section", { className: css.overviewStep, "data-current": stepLive ? '' : undefined, "data-parallel": step.parallel ? '' : undefined, children: [_jsx("header", { className: css.overviewStepHeader, children: _jsxs("button", { type: "button", className: css.stepToggle, "aria-expanded": stepOpen, "aria-controls": `watcher-step-body-${step.id}`, "aria-label": `步骤 ${step.step || '—'}，${step.executionCount} 次执行${stepDuration === null ? '' : `，耗时 ${stepDuration}`}，${stepOpen ? '收起步骤' : '展开步骤'}`, onClick: () => onToggleLayer('step', step.id), children: [_jsx(IconChevronRightOutline14, { size: 11, className: css.stepChevron }), _jsxs("span", { className: css.overviewStepLabel, children: ["\u6B65\u9AA4 ", step.step || '—'] }), _jsxs("span", { className: css.overviewStepSignals, children: [step.executionCount > 0 ? _jsxs("span", { children: [step.executionCount, " \u6B21"] }) : null, step.parallel ? _jsxs("span", { className: css.parallelLabel, children: [step.executionCount, " \u9879\u5E76\u884C"] }) : null, modelDuration === null ? null : _jsxs("span", { children: ["\u6A21\u578B ", modelDuration] }), showStepTotal ? _jsxs("span", { children: ["\u603B ", stepDuration] }) : null] })] }) }), _jsx("div", { id: `watcher-step-body-${step.id}`, className: css.overviewOccurrences, hidden: !stepOpen, children: timelineEntries.map(entry => {
                                            if (entry.kind === 'model') {
                                                return (_jsx(ModelStage, { trace: entry.trace, stepId: step.id, now: now, open: modelOpen, disclosure: disclosure, onToggle: () => onToggleLayer('model', step.id), onToggleReasoning: key => onToggleReasoning(key, step.id) }, `model:${step.id}`));
                                            }
                                            const item = entry.item;
                                            return (_jsx(OverviewOccurrenceButton, { item: item, occurrenceNumber: group.items.findIndex(candidate => candidate.id === item.id) + 1, branch: step.parallel ? entry.occurrenceIndex + 1 : null, step: null, live: stepLive && item.id === latestItemId && item.status === 'running', selected: selectedGroup && selectedItemId === item.id, now: now, onSelect: () => onSelectItem(item) }, item.id));
                                        }) })] }, step.id));
                        }) }))
                    : (_jsxs("div", { className: css.analysisClusters, "data-observation-mode": "grouped", children: [modelSteps.length === 0
                                ? null
                                : (_jsxs("section", { className: css.groupedModelStages, "data-open": groupedModelsOpen ? '' : undefined, children: [_jsxs("button", { type: "button", className: css.groupedModelToggle, "aria-expanded": groupedModelsOpen, "aria-controls": `watcher-grouped-models-${group.id}`, onClick: () => onToggleLayer('model', groupedModelsKey), children: [_jsx(IconChevronRightOutline14, { size: 11, className: css.groupedModelChevron }), _jsxs("span", { children: [_jsx("strong", { children: "\u6A21\u578B\u9636\u6BB5\u6C47\u603B" }), _jsxs("small", { children: [modelSteps.length, " \u4E2A Step \u00B7 \u6309 Step \u4FDD\u7559\uFF0C\u4E0D\u5408\u5E76\u63A8\u7406"] })] })] }), _jsx("div", { id: `watcher-grouped-models-${group.id}`, className: css.groupedModelList, hidden: !groupedModelsOpen, children: modelSteps.map(step => {
                                                const modelOpen = layerDisclosureOpen(disclosure, 'model', step.id);
                                                return (_jsxs("div", { className: css.groupedModelStep, children: [_jsxs("span", { className: css.groupedModelStepLabel, children: ["\u6B65\u9AA4 ", step.step || '—'] }), _jsx(ModelStage, { trace: step.model, stepId: `${step.id}:grouped`, now: now, open: modelOpen, disclosure: disclosure, onToggle: () => onToggleLayer('model', step.id), onToggleReasoning: key => onToggleReasoning(key, step.id) })] }, step.id));
                                            }) })] })), clusters.map(cluster => {
                                if (cluster.executionCount === 1) {
                                    const item = cluster.items[0];
                                    const sourceStep = group.steps.find(step => step.items.some(candidate => candidate.id === item.id));
                                    const branch = sourceStep === undefined ? null : branchNumberOf(sourceStep, item);
                                    return (_jsx("div", { className: css.analysisSingleton, children: _jsx(OverviewOccurrenceButton, { item: item, occurrenceNumber: group.items.findIndex(candidate => candidate.id === item.id) + 1, branch: branch, step: item.step, live: isNow && running && item.id === latestItemId && item.status === 'running', selected: selectedGroup && selectedItemId === item.id, now: now, onSelect: () => onSelectItem(item) }) }, cluster.id));
                                }
                                const clusterOpen = layerDisclosureOpen(disclosure, 'cluster', cluster.id);
                                const basisLabel = clusterBasisLabel(cluster);
                                const outcome = clusterOutcomeSummary(cluster);
                                const clusterMeta = [
                                    basisLabel,
                                    `${cluster.executionCount} 次执行`,
                                    `${cluster.stepCount} 个步骤`,
                                    outcome,
                                ].filter((part) => part !== null && part !== '').join(' · ');
                                return (_jsxs("section", { className: css.analysisCluster, "data-open": clusterOpen ? '' : undefined, children: [_jsxs("button", { type: "button", className: css.analysisClusterToggle, "aria-expanded": clusterOpen, "aria-controls": `watcher-cluster-body-${cluster.id}`, "aria-label": `${cluster.title}，${clusterMeta}，${clusterOpen ? '收起同类执行' : '展开同类执行'}`, onClick: () => onToggleLayer('cluster', cluster.id), children: [_jsx(IconChevronRightOutline14, { size: 11, className: css.analysisClusterChevron }), _jsx("span", { className: css.analysisClusterDotSlot, "aria-hidden": "true", children: _jsx(StatusMark, { status: cluster.latestStatus, className: css.analysisClusterDot }) }), _jsxs("span", { className: css.analysisClusterCopy, children: [_jsx("span", { className: css.analysisClusterTitle, children: cluster.title }), _jsx("span", { className: css.analysisClusterMeta, children: clusterMeta })] }), cluster.executionCount > 1
                                                    ? _jsxs("span", { className: css.analysisClusterCount, children: ["\u00D7", cluster.executionCount] })
                                                    : null] }), _jsx("div", { id: `watcher-cluster-body-${cluster.id}`, className: css.analysisClusterItems, hidden: !clusterOpen, children: cluster.items.map(item => {
                                                const sourceStep = group.steps.find(step => step.items.some(candidate => candidate.id === item.id));
                                                const branch = sourceStep === undefined ? null : branchNumberOf(sourceStep, item);
                                                return (_jsx(OverviewOccurrenceButton, { item: item, occurrenceNumber: group.items.findIndex(candidate => candidate.id === item.id) + 1, branch: branch, step: item.step, live: isNow && running && item.id === latestItemId && item.status === 'running', selected: selectedGroup && selectedItemId === item.id, now: now, onSelect: () => onSelectItem(item) }, item.id));
                                            }) })] }, cluster.id));
                            })] })) })] }));
}
/** Native session-header utility: exact work picture, typed evidence, no steering. */
export function Watcher(props) {
    const conversation = props.useConversation((state) => state);
    const chat = conversation?.views?.get('chat');
    if (chat === undefined)
        return _jsx("span", { role: "status", children: "Watcher \u6B63\u5728\u7B49\u5F85\u4F1A\u8BDD\u8BB0\u5F55\u2026" });
    return _jsx(ReadyWatcher, { ...props, chat: chat, views: conversation.views });
}
function ReadyWatcher({ useSession, useSessionPendingInteraction, useProjection, sessionId, loadAllHistory, chat, views, }) {
    const sessionSnapshot = useSession((state) => state);
    const pending = useSessionPendingInteraction((state) => state.get(sessionId));
    const snapshot = useMemo(() => ({
        views,
        chat,
        nodes: chat.legacy.nodes,
        turnTimings: chat.legacy.turnTimings,
        runningCalls: chat.legacy.runningCalls,
        pending: pending === undefined ? [] : [pending],
        blank: sessionSnapshot.blank,
        running: sessionSnapshot.running,
        hasMore: sessionSnapshot.hasMore,
    }), [chat, views, pending, sessionSnapshot.blank, sessionSnapshot.hasMore, sessionSnapshot.running]);
    const running = snapshot.running;
    const wholeSessionStats = useProjection('sessionStats');
    const wholeSessionInsights = useProjection('watcherInsights');
    const snapshotPicture = useMemo(() => foldSnapshot(snapshot, { running }), [snapshot, running]);
    const observedRef = useRef(null);
    const picture = useMemo(() => {
        const previous = observedRef.current?.sessionId === sessionId
            ? observedRef.current.picture
            : null;
        const next = previous === null ? snapshotPicture : mergeObservedPictures(previous, snapshotPicture);
        observedRef.current = { sessionId, picture: next };
        return next;
    }, [sessionId, snapshotPicture]);
    const performanceByTurn = useMemo(() => deriveTurnPerformance(snapshot.nodes, picture.turns), [snapshot.nodes, picture.turns]);
    const lastGroup = picture.nodes.at(-1);
    const lastGroupId = lastGroup?.id ?? null;
    const lastItem = lastGroup?.items.at(-1);
    const latestActivityKey = lastItem === undefined
        ? lastGroupId
        : `${lastGroupId}:${lastItem.id}:${lastItem.seq}:${lastItem.status}:${lastItem.resultSeq ?? 'open'}:${lastItem.resultTime ?? 'open'}`;
    const [open, setOpen] = useState(false);
    const [ui, setUi] = useState(() => ({ follow: true, unread: 0, selectedId: null }));
    const [selectedItemId, setSelectedItemId] = useState(null);
    const [observationMode, setObservationMode] = useState('itemized');
    const [disclosure, setDisclosure] = useState(createDisclosureState);
    const [historyLoad, setHistoryLoad] = useState({ kind: 'idle' });
    const now = useLiveClock(open && picture.running);
    const followRef = useRef(createFollow());
    const rootRef = useRef(null);
    const triggerRef = useRef(null);
    const panelRef = useRef(null);
    const railRef = useRef(null);
    const programmaticScrollRef = useRef(false);
    const historyAbortRef = useRef(null);
    const panelPosition = useAnchoredPosition({
        open,
        anchorRef: triggerRef,
        panelRef,
        gap: PANEL_GAP,
        margin: PANEL_MARGIN,
    });
    // The panel is portaled out of the conversation header so it can sit above
    // the sticky composer and every shell column. Outside dismissal therefore
    // has to test the in-place trigger and the portaled surface independently.
    useEffect(() => {
        if (!open)
            return;
        const closeOutside = (event) => {
            if (!(event.target instanceof Node))
                return;
            if (rootRef.current?.contains(event.target) === true)
                return;
            if (panelRef.current?.contains(event.target) === true)
                return;
            setOpen(false);
        };
        const closeOnEscape = (event) => {
            if (event.key !== 'Escape')
                return;
            event.preventDefault();
            setOpen(false);
            triggerRef.current?.focus();
        };
        document.addEventListener('pointerdown', closeOutside);
        document.addEventListener('keydown', closeOnEscape);
        return () => {
            document.removeEventListener('pointerdown', closeOutside);
            document.removeEventListener('keydown', closeOnEscape);
        };
    }, [open]);
    useLayoutEffect(() => {
        historyAbortRef.current?.abort();
        historyAbortRef.current = null;
        setHistoryLoad({ kind: 'idle' });
        followRef.current.reset();
        setUi(followRef.current.snapshot());
        setSelectedItemId(null);
        setDisclosure(resetDisclosureOverrides);
    }, [sessionId]);
    useEffect(() => () => {
        historyAbortRef.current?.abort();
    }, []);
    useLayoutEffect(() => {
        setUi(followRef.current.onPicture(picture));
    }, [latestActivityKey]);
    useLayoutEffect(() => {
        const rail = railRef.current;
        if (!rail || !open || !ui.follow)
            return;
        programmaticScrollRef.current = true;
        rail.scrollTop = rail.scrollHeight;
        const frame = requestAnimationFrame(() => {
            programmaticScrollRef.current = false;
        });
        return () => {
            cancelAnimationFrame(frame);
            programmaticScrollRef.current = false;
        };
    }, [ui.follow, latestActivityKey, observationMode, open]);
    const selected = ui.selectedId === null ? undefined : picture.nodes.find(group => group.id === ui.selectedId);
    const latestTurnNumber = picture.turns.at(-1)?.turn ?? null;
    const totalTurnCount = Math.max(picture.turnCount, wholeSessionStats?.turns ?? 0);
    const totalStepCount = Math.max(picture.stepCount, wholeSessionStats?.steps ?? 0);
    const historyProgress = totalStepCount > picture.stepCount
        ? `${picture.stepCount}/${totalStepCount} 个步骤`
        : totalTurnCount > picture.turnCount
            ? `${picture.turnCount}/${totalTurnCount} 个对话轮次`
            : `${picture.stepCount} 个步骤已载入`;
    const hasEdgeAlert = picture.pendingCount > 0
        || picture.now.status === 'failure'
        || picture.now.status === 'interrupted';
    const summaryState = picture.pendingCount > 0
        ? '等待确认'
        : picture.running
            ? '正在执行'
            : picture.now.status === 'failure'
                ? '执行失败'
                : picture.now.status === 'interrupted'
                    ? '已中断'
                    : picture.nodes.length > 0 ? '就绪' : '待命';
    const nowLabel = picture.now.label || (picture.nodes.length > 0 ? '执行路径已就绪' : '等待指令');
    const selectItem = (group, item) => {
        setUi(followRef.current.onSelect(group.id));
        setSelectedItemId(item.id);
    };
    const onRailScroll = () => {
        if (programmaticScrollRef.current)
            return;
        const rail = railRef.current;
        if (rail === null)
            return;
        const atBottom = rail.scrollHeight - rail.scrollTop - rail.clientHeight < 24;
        setUi(followRef.current.onScroll({ atBottom }));
    };
    const backToLatest = () => {
        programmaticScrollRef.current = true;
        setUi(followRef.current.backToLatest());
    };
    const pinForDisclosure = () => {
        if (ui.follow)
            setUi(followRef.current.setFollow(false));
    };
    const chooseObservationMode = (mode) => {
        if (mode === observationMode)
            return;
        if (ui.follow)
            programmaticScrollRef.current = true;
        setObservationMode(mode);
    };
    const chooseDepth = (depth) => {
        if (depth === disclosure.depth)
            return;
        pinForDisclosure();
        setDisclosure(chooseDisclosureDepth(depth));
    };
    const startHistoryLoad = () => {
        if (historyLoad.kind === 'loading' || historyLoad.kind === 'complete')
            return;
        historyAbortRef.current?.abort();
        const controller = new AbortController();
        historyAbortRef.current = controller;
        setHistoryLoad({ kind: 'loading' });
        void loadAllHistory(controller.signal).then((result) => {
            if (historyAbortRef.current !== controller)
                return;
            if (result.kind === 'blocked') {
                const message = result.reason === 'busy'
                    ? '主会话正在载入历史，请稍后重试'
                    : result.reason === 'page-limit'
                        ? '历史页数超出安全上限，请分次重试'
                        : '历史分页没有继续前进，请重试';
                setHistoryLoad({ kind: 'error', message });
            }
            else if (result.kind === 'complete') {
                // Keep a short terminal state until React observes the final Session
                // page. This prevents a stale `hasMore` render from starting the loop
                // a second time after the official loader has already reached page 1.
                setHistoryLoad({ kind: 'complete' });
            }
            else {
                setHistoryLoad({ kind: 'idle' });
            }
        }).catch((error) => {
            if (historyAbortRef.current !== controller || controller.signal.aborted)
                return;
            setHistoryLoad({
                kind: 'error',
                message: error instanceof Error ? error.message : String(error),
            });
        }).finally(() => {
            if (historyAbortRef.current === controller)
                historyAbortRef.current = null;
        });
    };
    useEffect(() => {
        // Full history is an explicit choice. Summary comes from the Host projection.
        if (!open || !snapshot.hasMore || historyLoad.kind !== 'idle')
            return;
    }, [open, snapshot.hasMore, historyLoad.kind, sessionId]);
    useEffect(() => {
        if (historyLoad.kind !== 'complete' || snapshot.hasMore)
            return;
        setHistoryLoad({ kind: 'idle' });
    }, [historyLoad.kind, snapshot.hasMore]);
    return (_jsxs("div", { ref: rootRef, className: css.root, "data-dsh-watcher": "header", children: [_jsx("button", { ref: triggerRef, type: "button", className: css.trigger, "data-open": open ? '' : undefined, "data-live": picture.running && picture.nodes.length > 0 ? '' : undefined, "data-alert": hasEdgeAlert ? '' : undefined, "aria-expanded": open, "aria-label": `Watcher，${summaryState}`, title: "Watcher", onClick: () => setOpen(value => !value), children: _jsx(IconLivingEye, {}) }), open
                ? createPortal(_jsxs("div", { ref: panelRef, className: css.menu, style: panelPosition ?? UNPLACED_PANEL_STYLE, role: "dialog", "aria-modal": "false", "aria-label": "Watcher \u5DE5\u4F5C\u56FE", "data-dsh-watcher-panel": "", "data-ud-motion": "watcher-panel-enter", children: [selected === undefined
                            ? null
                            : (_jsx(ExecutionInspector, { group: selected, selectedItemId: selectedItemId, live: picture.running && selected.id === lastGroupId, now: now, onSelectItem: setSelectedItemId, onBack: () => {
                                    backToLatest();
                                    setSelectedItemId(null);
                                } })), _jsxs("section", { className: css.workPicture, "aria-label": "Agent \u5DE5\u4F5C\u8DEF\u5F84", "data-ud-check": "watcher-work-picture", "data-ud-role": "panel", children: [_jsxs("header", { className: css.pictureHeader, children: [_jsxs("div", { className: css.nowBlock, "aria-live": "polite", children: [picture.running || hasEdgeAlert || summaryState !== '就绪' ? (_jsx("div", { className: css.eyebrow, "data-alert": hasEdgeAlert ? '' : undefined, children: _jsx("span", { children: summaryState }) })) : null, _jsx("div", { className: css.now, title: picture.running ? nowLabel : 'DSH-Watcher', children: picture.running ? nowLabel : 'DSH-Watcher' }), _jsxs("div", { className: css.summary, children: [_jsx("span", { children: snapshot.hasMore && totalTurnCount > picture.turnCount
                                                                ? `已载入 ${picture.turnCount}/${totalTurnCount} 轮`
                                                                : `${picture.turnCount} 轮` }), _jsx("span", { children: snapshot.hasMore && totalStepCount > picture.stepCount
                                                                ? `${picture.stepCount}/${totalStepCount} 步`
                                                                : `${picture.stepCount} 步` }), _jsxs("span", { children: [picture.actionCount, " \u6B21\u6267\u884C"] }), snapshot.hasMore || historyLoad.kind === 'loading' || historyLoad.kind === 'error' ? (_jsx("button", { type: "button", className: css.loadAllInlineBtn, onClick: startHistoryLoad, disabled: historyLoad.kind === 'loading', children: historyLoad.kind === 'loading' ? '正在补齐历史…' : historyLoad.kind === 'error' ? '重试载入' : '载入全部历史 →' })) : null, historyLoad.kind === 'loading' || historyLoad.kind === 'error' ? (_jsx("span", { role: "status", children: historyLoad.kind === 'error' ? historyLoad.message : `已载入 ${historyProgress}` })) : null] })] }), _jsxs(Pill, { className: css.follow, active: ui.follow, "aria-pressed": ui.follow, "aria-label": ui.follow ? '停止跟随最新工作' : '跟随最新工作', onClick: () => {
                                                if (!ui.follow)
                                                    programmaticScrollRef.current = true;
                                                setUi(followRef.current.setFollow(!ui.follow));
                                            }, children: [_jsx(IconRefreshOutline14, { size: 12 }), ui.follow ? '自动跟随' : '浏览历史'] })] }), _jsx(SessionInsights, { value: wholeSessionInsights, now: now, running: picture.running, waiting: picture.pendingCount > 0, onEvidence: e => {
                                        pinForDisclosure();
                                        setDisclosure(chooseDisclosureDepth('detail'));
                                        requestAnimationFrame(() => document.getElementById('watcher-turn-' + e.turn)?.scrollIntoView({ block: 'nearest' }));
                                    } }), _jsxs("div", { className: css.viewToolbar, "aria-label": "\u8DEF\u5F84\u89C6\u56FE\u8BBE\u7F6E", children: [_jsxs("div", { className: css.viewControl, children: [_jsx("span", { className: css.viewToolbarLabel, children: "\u7EC4\u7EC7" }), _jsxs("div", { className: css.viewMode, role: "group", "aria-label": "\u8DEF\u5F84\u7EC4\u7EC7\u65B9\u5F0F", children: [_jsx("button", { type: "button", "data-active": observationMode === 'itemized' ? '' : undefined, "aria-pressed": observationMode === 'itemized', title: "\u6309\u65F6\u95F4\u987A\u5E8F\u5C55\u793A\u6BCF\u4E2A\u6B65\u9AA4\u548C\u6BCF\u6B21\u6267\u884C", onClick: () => chooseObservationMode('itemized'), children: "\u9010\u9879" }), _jsx("button", { type: "button", "data-active": observationMode === 'grouped' ? '' : undefined, "aria-pressed": observationMode === 'grouped', title: "\u6309\u540C\u4E00\u76EE\u6807\u6216\u5B8C\u5168\u76F8\u540C\u7684\u6307\u4EE4\u5F52\u7C7B\uFF0C\u5C55\u5F00\u4ECD\u53EF\u67E5\u770B\u539F\u59CB\u6267\u884C", onClick: () => chooseObservationMode('grouped'), children: "\u5F52\u7C7B" })] })] }), _jsxs("div", { className: css.viewControl, children: [_jsx("span", { className: css.viewToolbarLabel, children: "\u5C42\u7EA7" }), _jsxs("div", { className: css.viewMode, role: "group", "aria-label": "\u8DEF\u5F84\u5C55\u5F00\u6DF1\u5EA6", children: [_jsx("button", { type: "button", "data-active": disclosure.depth === 'overview' ? '' : undefined, "aria-pressed": disclosure.depth === 'overview', title: "\u5C55\u5F00\u5F53\u524D\u8F6E\u6B21\uFF0C\u5C55\u793A\u9636\u6BB5\u6982\u89C8\uFF1B\u9636\u6BB5\u5185\u90E8\u4FDD\u6301\u6536\u8D77", onClick: () => chooseDepth('overview'), children: "\u6982\u89C8" }), _jsx("button", { type: "button", "data-active": disclosure.depth === 'detail' ? '' : undefined, "aria-pressed": disclosure.depth === 'detail', title: "\u5C55\u5F00\u6240\u6709\u8F6E\u6B21\u3001\u9636\u6BB5\u3001\u6B65\u9AA4\u3001\u6A21\u578B\u4E0E\u63A8\u7406\u8BB0\u5F55", onClick: () => chooseDepth('detail'), children: "\u8BE6\u60C5" })] })] })] }), !ui.follow && ui.unread > 0
                                    ? (_jsxs("button", { type: "button", className: css.unread, onClick: backToLatest, children: [_jsx(IconRefreshOutline14, { size: 12 }), ui.unread, " \u6761\u65B0\u8FDB\u5C55 \u00B7 \u67E5\u770B\u6700\u65B0"] }))
                                    : null, picture.nodes.length === 0
                                    ? (_jsxs("div", { className: css.empty, children: [_jsx("span", { className: css.emptyEye, "aria-hidden": "true", children: _jsx(IconLivingEye, { size: 22 }) }), _jsx("strong", { children: "\u8FD8\u6CA1\u6709\u5DE5\u4F5C\u8BB0\u5F55" }), _jsx("span", { children: "\u7B2C\u4E00\u8F6E\u5BF9\u8BDD\u5F00\u59CB\u540E\uFF0C\u8DEF\u5F84\u4F1A\u4ECE\u8FD9\u91CC\u751F\u957F" })] }))
                                    : (_jsx("div", { ref: railRef, className: css.railViewport, onScroll: onRailScroll, children: _jsx("div", { className: css.turns, children: picture.turns.map(turn => {
                                                const isLatestTurn = turn.turn === latestTurnNumber;
                                                const turnState = overviewStateOf(turn.status, isLatestTurn);
                                                const automaticDefaultOpen = turnNeedsDefaultDisclosure(turnState, isLatestTurn);
                                                const turnOpen = turnDisclosureOpen(disclosure, turn.turn, automaticDefaultOpen);
                                                const turnTitle = turn.turn === 0 ? '会话准备' : `对话轮次 ${turn.turn}`;
                                                const turnSummary = turnOverviewSummary(turn);
                                                const performance = performanceByTurn.get(turn.turn);
                                                const isLiveTurn = isLatestTurn && picture.running;
                                                const duration = turnDuration(turn, isLiveTurn, now);
                                                const tokenSpeed = performance?.throughput.kind === 'measured'
                                                    ? `${formatTokensPerSecond(performance.throughput.tokensPerSecond)} tok/s`
                                                    : null;
                                                const durationAria = duration === null
                                                    ? ''
                                                    : duration.kind === 'exact'
                                                        ? `，总耗时 ${duration.value}`
                                                        : `，已记录 ${duration.value}，开头未载入`;
                                                const secondaryPerformance = [
                                                    duration?.kind === 'partial' ? '开头未载入' : null,
                                                    tokenSpeed,
                                                ].filter((value) => value !== null).join(' · ');
                                                return (_jsxs("section", { className: css.turn, "aria-labelledby": `watcher-turn-${turn.turn}`, children: [_jsx("header", { className: css.turnHeader, children: _jsx("h2", { id: `watcher-turn-${turn.turn}`, children: _jsxs("button", { type: "button", className: css.turnToggle, "aria-expanded": turnOpen, "aria-controls": `watcher-turn-body-${turn.turn}`, "aria-label": `${turnTitle}，${OVERVIEW_STATE_LABEL[turnState]}，${turnSummary}${durationAria}${tokenSpeed === null ? '' : `，生成速度 ${tokenSpeed}`}，${turnOpen ? '收起轮次' : '展开轮次'}`, title: turnOpen ? '收起此轮次；新进展仍会继续更新' : '展开此轮次', onClick: () => {
                                                                        pinForDisclosure();
                                                                        setDisclosure(current => toggleTurnDisclosure(current, turn.turn, automaticDefaultOpen));
                                                                    }, children: [_jsx(IconChevronRightOutline14, { size: 13, className: css.turnChevron }), _jsxs("span", { className: css.turnCopy, children: [_jsxs("span", { className: css.turnTitleLine, children: [_jsx("span", { className: css.turnTitle, children: turnTitle }), showOverviewTag(turnState)
                                                                                            ? _jsx("span", { className: css.overviewTag, "data-state": turnState, children: OVERVIEW_STATE_LABEL[turnState] })
                                                                                            : null] }), _jsx("span", { className: css.turnSummary, children: turnSummary })] }), _jsxs("span", { className: css.turnPerformance, children: [_jsx("span", { className: css.turnDuration, children: duration === null
                                                                                        ? OVERVIEW_STATE_LABEL[turnState]
                                                                                        : duration.kind === 'exact'
                                                                                            ? `总 ${duration.value}`
                                                                                            : `已记录 ${duration.value}` }), secondaryPerformance === '' ? null : _jsx("span", { className: css.turnSpeed, children: secondaryPerformance })] })] }) }) }), _jsxs("div", { id: `watcher-turn-body-${turn.turn}`, className: css.turnBody, hidden: !turnOpen, children: [performance === undefined ? null : _jsx(TurnMetricStrip, { performance: performance }), _jsxs("div", { className: css.groupRail, children: [_jsx("span", { className: css.railLine, "aria-hidden": "true" }), turn.groups.map(group => {
                                                                            const isNow = group.id === lastGroupId;
                                                                            const selectedGroup = ui.selectedId === group.id;
                                                                            const phaseOpen = layerDisclosureOpen(disclosure, 'phase', group.id);
                                                                            return (_jsx(PhaseOverview, { group: group, isNow: isNow, running: picture.running, now: now, selectedGroup: selectedGroup, selectedItemId: selectedItemId, observationMode: observationMode, open: phaseOpen, disclosure: disclosure, onToggle: () => {
                                                                                    pinForDisclosure();
                                                                                    setDisclosure(current => toggleLayerDisclosure(current, 'phase', group.id));
                                                                                }, onToggleLayer: (layer, key) => {
                                                                                    pinForDisclosure();
                                                                                    setDisclosure(current => toggleLayerDisclosure(current, layer, key));
                                                                                }, onToggleReasoning: (key, modelKey) => {
                                                                                    pinForDisclosure();
                                                                                    setDisclosure(current => {
                                                                                        const reasoningOpen = layerDisclosureOpen(current, 'reasoning', key);
                                                                                        const withOpenParent = reasoningOpen
                                                                                            ? current
                                                                                            : setLayerDisclosure(current, 'model', modelKey, true);
                                                                                        // Opening a nested reasoning record is explicit reading intent.
                                                                                        // Keep its parent open when the live model settles and its
                                                                                        // default changes after a depth switch or live update.
                                                                                        return toggleLayerDisclosure(withOpenParent, 'reasoning', key);
                                                                                    });
                                                                                }, onSelectItem: item => selectItem(group, item) }, group.id));
                                                                        })] })] })] }, turn.turn));
                                            }) }) }))] })] }), document.body)
                : null] }));
}
//# sourceMappingURL=Watcher.js.map