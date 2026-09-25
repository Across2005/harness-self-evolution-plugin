import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { useEffect, useState, useMemo } from 'react';
// Untyped local ESM helpers: single .mjs source kept for node tests.
// @ts-ignore TS7016: no declarations for the local .mjs module
import { alertsOf, DEFAULT_LIMITS, limitsOf, scanSessions } from '../insights/presentation.mjs';
import css from './Insights.module.css';
import { TimingPanel } from "./TimingPanel.js";
const scanSessionsTyped = scanSessions;
const STORAGE = 'dsh-watcher:insights-display:v1';
function readLimits() {
    try {
        return limitsOf(JSON.parse(localStorage.getItem(STORAGE) ?? '{}'));
    }
    catch {
        return { ...DEFAULT_LIMITS };
    }
}
function useLimits() {
    const [limits, setLimits] = useState(readLimits);
    useEffect(() => {
        const update = () => setLimits(readLimits());
        window.addEventListener('watcher-insights-settings', update);
        return () => window.removeEventListener('watcher-insights-settings', update);
    }, []);
    return limits;
}
const fmt = (n) => new Intl.NumberFormat('zh-CN', { maximumFractionDigits: 0 }).format(n);
const fmtCompact = (n) => {
    if (!Number.isFinite(n) || n <= 0)
        return '0';
    if (n >= 1e8)
        return `${(n / 1e8).toFixed(1)} 亿`;
    if (n >= 1e4)
        return `${(n / 1e4).toFixed(1)} 万`;
    return fmt(n);
};
const dayKey = (ms) => {
    const d = new Date(ms);
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
};
const dayLabel = (key) => {
    const [, m, d] = key.split('-');
    return `${Number(m)}/${Number(d)}`;
};
const PALETTE = ['#3b82f6', '#8b5cf6', '#f59e0b', '#10b981', '#ec4899', '#6366f1'];
function effortLabel(effort) {
    if (!effort)
        return '';
    const map = { high: '高', medium: '中', low: '低' };
    return map[effort.toLowerCase()] ?? effort;
}
export function SessionInsights({ value, now, running, waiting, onEvidence }) {
    const limits = useLimits();
    const [scope, setScope] = useState('turn');
    const [modelFilter, setModelFilter] = useState('all');
    if (!value)
        return null;
    const isMultiModel = (value.models?.length ?? 0) > 1;
    const selectedModel = scope === 'session' && modelFilter !== 'all' && value.models[modelFilter]
        ? value.models[modelFilter]
        : undefined;
    const stats = scope === 'turn' && value.turn
        ? value.turn.stats
        : (selectedModel ?? value.totals);
    const alerts = alertsOf(value, now, { running, waiting, limits });
    const currentRoute = value.turn?.route ?? (value.models && value.models.length > 0 ? value.models[0] : undefined);
    const totalIn = (stats.input ?? 0) + (stats.cacheRead ?? 0);
    const cachePct = totalIn > 0 ? Math.round(((stats.cacheRead ?? 0) / totalIn) * 100) : 0;
    return (_jsxs("section", { className: css.hudBox, "aria-label": "\u8017\u65F6\u5206\u5E03\u4E0E\u8FD0\u884C\u5065\u5EB7\u5EA6", children: [_jsxs("div", { className: css.hudTop, children: [_jsxs("div", { className: css.hudTopLeft, children: [_jsx("span", { className: css.hudHeading, children: scope === 'turn'
                                    ? '本轮'
                                    : selectedModel
                                        ? `模型: ${selectedModel.model}`
                                        : '全会话' }), scope === 'turn' && currentRoute?.model ? (_jsxs("span", { className: css.currentModelTag, title: currentRoute.model, children: [_jsx("strong", { className: css.modelTagText, children: currentRoute.model }), currentRoute.effort ? (_jsxs("span", { className: css.effortTag, children: ["\u601D\u8003: ", effortLabel(currentRoute.effort)] })) : null] })) : null, _jsxs("span", { className: css.contextTag, children: ["\u4E0A\u4E0B\u6587 ", _jsx("strong", { children: fmt(stats.input ?? 0) }), " Token"] })] }), _jsxs("div", { className: css.hudTopRight, children: [_jsxs("span", { className: css.tokenStat, children: [_jsx("strong", { children: fmt(stats.tokens ?? 0) }), " Token (", cachePct, "% \u547D\u4E2D)"] }), _jsxs("div", { className: css.scopeGroup, role: "group", "aria-label": "\u7EDF\u8BA1\u8303\u56F4\u5207\u6362", children: [_jsx("button", { type: "button", className: css.scopeBtn, "data-active": scope === 'turn' ? '' : undefined, onClick: () => { setScope('turn'); setModelFilter('all'); }, children: "\u672C\u8F6E" }), _jsx("button", { type: "button", className: css.scopeBtn, "data-active": scope === 'session' ? '' : undefined, onClick: () => setScope('session'), children: "\u5168\u4F1A\u8BDD" })] })] })] }), scope === 'session' && isMultiModel ? (_jsxs("div", { className: css.modelTabBar, role: "tablist", "aria-label": "\u591A\u6A21\u578B\u5207\u6362", children: [_jsxs("button", { type: "button", className: css.modelTabBtn, "data-active": modelFilter === 'all' ? '' : undefined, onClick: () => setModelFilter('all'), children: ["\u5168\u90E8\u6A21\u578B\u6C47\u603B (", value.models.length, ")"] }), value.models.map((m, idx) => (_jsxs("button", { type: "button", className: css.modelTabBtn, "data-active": modelFilter === idx ? '' : undefined, onClick: () => setModelFilter(idx), children: [m.model, " (", m.calls, "\u6B21)"] }, idx)))] })) : null, _jsxs("div", { className: css.hudBody, children: [_jsx(TimingPanel, { stats: stats, scope: scope }), alerts.length > 0 ? (_jsx("div", { className: css.alertSection, "aria-live": "polite", children: alerts.map((a) => {
                            const isRepeat = a.kind === 'repeated-failure' || a.id.startsWith('repeat');
                            const isSilence = a.id === 'silence';
                            const isReason = a.id === 'reasoning-span';
                            const tag = isRepeat ? '连续报错' : isSilence ? '网络停顿' : isReason ? '思考超时' : '异常';
                            return (_jsxs("div", { className: `${css.alertCard} ${isRepeat ? css.alertCardDanger : css.alertCardWarn}`, children: [_jsxs("div", { className: css.alertLeft, children: [_jsx("span", { className: `${css.alertTag} ${isRepeat ? css.tagDanger : css.tagWarn}`, children: tag }), _jsxs("div", { className: css.alertTexts, children: [_jsx("strong", { className: css.alertMainText, children: a.title }), _jsx("span", { className: css.alertSubText, children: a.detail })] })] }), _jsx("button", { type: "button", className: css.alertActionBtn, onClick: () => onEvidence(a), children: "\u5B9A\u4F4D\u73B0\u573A" })] }, a.id));
                        }) })) : null] })] }));
}
export function InsightsSettings(props) {
    const limits = useLimits();
    const [silence, setSilence] = useState(limits.silenceSeconds);
    const [reasoning, setReasoning] = useState(limits.reasoningSeconds);
    const [saved, setSaved] = useState(false);
    const [userPickedRange, setUserPickedRange] = useState(false);
    const [range, setRange] = useState('7');
    const [sessionSort, setSessionSort] = useState('tokens');
    const [loading, setLoading] = useState(false);
    const [sessions, setSessions] = useState(null);
    const [openSessionId, setOpenSessionId] = useState(null);
    const [hoveredIdx, setHoveredIdx] = useState(null);
    const [activeDrilldown, setActiveDrilldown] = useState(null);
    useEffect(() => {
        if (!props.remote)
            return;
        let active = true;
        setLoading(true);
        scanSessionsTyped(props.remote, { limit: 100 })
            .then(res => {
            if (active) {
                setSessions(res);
                // 智能感知：如果历史跨度确实超过 7 天，自动提档到 30 天；否则保持清爽的 7 天
                if (!userPickedRange) {
                    const times = (res?.rows ?? [])
                        .map((r) => r.updatedAt)
                        .filter((t) => typeof t === 'number' && t > 0);
                    if (times.length >= 2) {
                        const span = Math.max(...times) - Math.min(...times);
                        if (span > 7 * 86400000) {
                            setRange('30');
                        }
                    }
                }
            }
        })
            .catch(console.error)
            .finally(() => { if (active)
            setLoading(false); });
        return () => { active = false; };
    }, [props.remote, userPickedRange]);
    const refresh = () => {
        if (!props.remote || loading)
            return;
        setLoading(true);
        scanSessionsTyped(props.remote, { limit: 100 })
            .then(setSessions)
            .catch(console.error)
            .finally(() => setLoading(false));
    };
    const save = () => {
        localStorage.setItem(STORAGE, JSON.stringify({ silenceSeconds: silence, reasoningSeconds: reasoning }));
        window.dispatchEvent(new CustomEvent('watcher-insights-settings'));
        setSaved(true);
        setTimeout(() => setSaved(false), 2000);
    };
    const analytics = useMemo(() => {
        if (!sessions)
            return null;
        const days = Number(range);
        const cutoff = Date.now() - days * 86400000;
        const validRows = sessions.rows.filter((r) => r.value && (!r.updatedAt || r.updatedAt >= cutoff));
        const validViews = validRows.map((r) => r.value);
        let totalTokens = 0;
        let totalModelMs = 0;
        let totalToolMs = 0;
        let totalBashMs = 0;
        let totalTools = 0;
        let totalCacheRead = 0;
        let totalInput = 0;
        let totalErrors = 0;
        let totalRetries = 0;
        validViews.forEach((v) => {
            totalTokens += v.totals.tokens ?? 0;
            totalModelMs += v.totals.modelMs ?? 0;
            totalToolMs += v.totals.toolMs ?? 0;
            totalBashMs += v.totals.bashMs ?? 0;
            totalTools += v.totals.tools ?? 0;
            totalCacheRead += v.totals.cacheRead ?? 0;
            totalInput += v.totals.input ?? 0;
            totalErrors += v.totals.toolErrors ?? 0;
            totalRetries += v.totals.retries ?? 0;
        });
        const totalWallMs = totalModelMs + totalToolMs;
        const toolTimePct = totalWallMs > 0 ? Math.round((totalToolMs / totalWallMs) * 100) : 0;
        const totalFileMs = Math.max(0, totalToolMs - totalBashMs);
        const bashPct = totalToolMs > 0 ? Math.round((totalBashMs / totalToolMs) * 100) : 0;
        const filePct = Math.max(0, 100 - bashPct);
        const totalInAll = totalInput + totalCacheRead;
        const cacheHitPct = totalInAll > 0 ? Math.round((totalCacheRead / totalInAll) * 100) : 0;
        // 重点：按纯模型名称汇总去重，确保模型级排行榜中每个模型仅出现一次，杜绝同名混杂和 React 重复 key 乱序！
        const modelMap = new Map();
        for (const view of validViews) {
            for (const m of view.models ?? []) {
                const name = m.model || '未标注';
                let row = modelMap.get(name);
                if (!row) {
                    row = { model: name, calls: 0, tokens: 0, input: 0, output: 0, cacheRead: 0, cacheWrite: 0, reasoning: 0, modelMs: 0, firstMs: 0, firstSamples: 0 };
                    modelMap.set(name, row);
                }
                for (const k of ['calls', 'tokens', 'input', 'output', 'cacheRead', 'cacheWrite', 'reasoning', 'modelMs', 'firstMs', 'firstSamples']) {
                    if (typeof m[k] === 'number' && Number.isFinite(m[k])) {
                        row[k] += m[k];
                    }
                }
            }
        }
        const uniqueModels = [...modelMap.values()];
        // 1. 首响应延迟由短到长（升序：最快在上，TTFT 速度排行榜）
        const speedList = uniqueModels
            .filter((m) => (m.firstSamples ?? 0) > 0 && (m.firstMs ?? 0) > 0)
            .sort((a, b) => (a.firstMs / a.firstSamples) - (b.firstMs / b.firstSamples));
        // 2. 首响应排队由长到短（降序：最慢在上，延迟瓶颈排行榜）
        const latencyList = uniqueModels
            .filter((m) => (m.firstSamples ?? 0) > 0 && (m.firstMs ?? 0) > 0)
            .sort((a, b) => (b.firstMs / b.firstSamples) - (a.firstMs / a.firstSamples));
        // 3. 深度推导按思考 Token 占比降序（从高到低）
        const thinkList = uniqueModels
            .filter((m) => (m.reasoning ?? 0) > 0)
            .sort((a, b) => {
            const ratioA = a.reasoning / (((a.reasoning ?? 0) + (a.output ?? 0)) || 1);
            const ratioB = b.reasoning / (((b.reasoning ?? 0) + (b.output ?? 0)) || 1);
            return ratioB - ratioA || b.reasoning - a.reasoning;
        });
        // 4. 前缀缓存按命中率降序（从高到低）
        const cacheList = uniqueModels
            .filter((m) => (m.tokens ?? 0) > 0)
            .sort((a, b) => {
            const rateA = (a.cacheRead ?? 0) / (((a.input ?? 0) + (a.cacheRead ?? 0)) || 1);
            const rateB = (b.cacheRead ?? 0) / (((b.input ?? 0) + (b.cacheRead ?? 0)) || 1);
            return rateB - rateA || (b.cacheRead ?? 0) - (a.cacheRead ?? 0);
        });
        // 头部 6 大 KPI 卡片数据：精准绑定对应排行榜的第一名！
        const fastKing = speedList[0];
        const slowKing = latencyList[0];
        const thinkKing = thinkList[0];
        const bestCacheModel = cacheList[0];
        // 工具高耗时排查会话 TOP 3 (严格按工具总耗时降序)
        const topToolSessions = [...validRows]
            .filter((r) => (r.value?.totals?.toolMs ?? 0) > 0)
            .sort((a, b) => (b.value.totals.toolMs ?? 0) - (a.value.totals.toolMs ?? 0))
            .slice(0, 3);
        // 报错与重试排查会话 (严格按报错量降序)
        const errorSessions = [...validRows]
            .filter((r) => (r.value?.totals?.toolErrors ?? 0) > 0 || (r.value?.totals?.retries ?? 0) > 0)
            .sort((a, b) => {
            const scoreA = (a.value.totals.toolErrors ?? 0) * 100 + (a.value.totals.retries ?? 0);
            const scoreB = (b.value.totals.toolErrors ?? 0) * 100 + (b.value.totals.retries ?? 0);
            return scoreB - scoreA;
        })
            .slice(0, 6);
        // 重点对话账单：严格按用户指定的维度降序排序！
        const sortedSessions = [...validRows].sort((a, b) => {
            const va = a.value.totals;
            const vb = b.value.totals;
            if (sessionSort === 'tokens') {
                return (vb.tokens ?? 0) - (va.tokens ?? 0);
            }
            if (sessionSort === 'time') {
                const timeA = (va.modelMs ?? 0) + (va.toolMs ?? 0);
                const timeB = (vb.modelMs ?? 0) + (vb.toolMs ?? 0);
                return timeB - timeA;
            }
            if (sessionSort === 'errors') {
                const scoreA = (va.toolErrors ?? 0) * 100 + (va.retries ?? 0);
                const scoreB = (vb.toolErrors ?? 0) * 100 + (vb.retries ?? 0);
                return scoreB - scoreA || (vb.tokens ?? 0) - (va.tokens ?? 0);
            }
            return (b.updatedAt ?? 0) - (a.updatedAt ?? 0);
        });
        const maxSessionTokens = Math.max(1, ...sortedSessions.map((s) => s.value?.totals?.tokens ?? 0));
        // 环形图数据：纯模型排序，前 4 名 + 其余汇总为 "其他"，并保证严格按 Token 降序排列！
        const tokenRankedModels = [...uniqueModels].sort((a, b) => b.tokens - a.tokens);
        const topModels = tokenRankedModels.slice(0, 4);
        const restModels = tokenRankedModels.slice(4);
        const restTokens = restModels.reduce((sum, m) => sum + (m.tokens ?? 0), 0);
        const donutModels = [...topModels];
        if (restTokens > 0) {
            donutModels.push({ model: '其他模型', tokens: restTokens });
        }
        donutModels.sort((a, b) => (b.tokens ?? 0) - (a.tokens ?? 0));
        const donutTotal = donutModels.reduce((sum, m) => sum + (m.tokens ?? 0), 0);
        const colorOf = (name) => {
            const found = donutModels.findIndex((m) => m.model === name);
            return PALETTE[(found >= 0 ? found : 0) % PALETTE.length];
        };
        // 环形切片计算：无缝精准闭环，最后一段精确吸附
        const circumference = 2 * Math.PI * 38; // 238.761...
        let accumulated = 0;
        const donutSegments = donutTotal <= 0 ? [] : donutModels.map((m, idx) => {
            const pctRatio = m.tokens / donutTotal;
            const strokeLength = idx === donutModels.length - 1
                ? Math.max(0, circumference - accumulated)
                : pctRatio * circumference;
            const gapLength = Math.max(0, circumference - strokeLength);
            const offset = -accumulated;
            accumulated += strokeLength;
            return {
                model: m.model,
                tokens: m.tokens,
                pct: Math.round(pctRatio * 100),
                color: PALETTE[idx % PALETTE.length],
                dasharray: `${strokeLength} ${gapLength}`,
                dashoffset: offset,
            };
        });
        // 每日活动序列
        const keys = [];
        for (let i = days - 1; i >= 0; i--)
            keys.push(dayKey(Date.now() - i * 86400000));
        const byDay = new Map(keys.map(k => [k, new Map()]));
        validRows.forEach((row) => {
            const key = row.updatedAt ? dayKey(row.updatedAt) : keys[keys.length - 1];
            const bucket = byDay.get(key);
            if (!bucket)
                return;
            const models = row.value.models?.length
                ? row.value.models
                : [{ model: '未标注', tokens: row.value.totals.tokens ?? 0 }];
            models.forEach((m) => {
                bucket.set(m.model, (bucket.get(m.model) ?? 0) + (m.tokens ?? 0));
            });
        });
        const todayStr = dayKey(Date.now());
        const yesterdayStr = dayKey(Date.now() - 86400000);
        const daySeries = keys.map(key => {
            const bucket = byDay.get(key) ?? new Map();
            const segments = [...bucket.entries()]
                .map(([model, tokens]) => ({ model, tokens, color: colorOf(model) }))
                .sort((a, b) => b.tokens - a.tokens);
            const label = range === '7'
                ? (key === todayStr ? '今天' : key === yesterdayStr ? '昨天' : dayLabel(key))
                : (key.endsWith('01') || key.endsWith('05') || key.endsWith('10') || key.endsWith('15') || key.endsWith('20') || key.endsWith('25') ? dayLabel(key) : '');
            return { key, label, total: segments.reduce((s, x) => s + x.tokens, 0), segments };
        });
        const dayMax = Math.max(1, ...daySeries.map(d => d.total));
        return {
            validCount: validRows.length,
            listed: sessions.total,
            totalTokens,
            totalTimeHours: ((totalModelMs + totalToolMs) / 3600000).toFixed(1),
            cacheHitPct,
            totalCacheRead,
            totalToolMs,
            totalBashMs,
            totalFileMs,
            bashPct,
            filePct,
            topToolSessions,
            errorSessions,
            sortedSessions,
            maxSessionTokens,
            totalTools,
            toolTimePct,
            totalErrors,
            totalRetries,
            speedList,
            latencyList,
            thinkList,
            cacheList,
            donutModels,
            donutTotal,
            donutSegments,
            thinkKing,
            fastKing,
            slowKing,
            bestCacheModel,
            daySeries,
            dayMax,
        };
    }, [sessions, range, sessionSort]);
    const cacheNote = !analytics
        ? ''
        : analytics.cacheHitPct >= 70 ? '命中较高'
            : analytics.cacheHitPct >= 40 ? '一般'
                : '命中偏低';
    // 环形中心展示信息（不重复上面大数，展示主力占比或悬停选中的模型）
    const activeSeg = hoveredIdx !== null && analytics?.donutSegments[hoveredIdx]
        ? analytics.donutSegments[hoveredIdx]
        : null;
    const topModel = analytics?.donutSegments[0];
    return (_jsxs("div", { className: css.settingsContainer, children: [_jsxs("div", { className: css.cockpitHeader, children: [_jsxs("div", { className: css.cockpitTitleArea, children: [_jsx("h2", { className: css.cockpitMainTitle, children: "\u5BF9\u8BDD\u5F00\u9500\u4E0E\u6A21\u578B\u98CE\u4E91\u699C" }), _jsx("p", { className: css.cockpitSubTitle, children: "\u53EA\u8BFB\u6C47\u603B\u672C\u5730\u5DF2\u7F13\u5B58\u7684\u5BF9\u8BDD\u3002\u6309\u6D3B\u52A8\u65E5\u671F\u5F52\u7EC4\uFF0C\u65E0\u989D\u5916\u540E\u53F0\u5F00\u9500\u3002" })] }), _jsxs("div", { className: css.headerRightControls, children: [_jsxs("div", { className: css.rangeSwitchGroup, children: [_jsx("button", { type: "button", className: css.rangeBtn, "data-active": range === '7' ? '' : undefined, onClick: () => { setUserPickedRange(true); setRange('7'); }, children: "\u8FD1 7 \u5929" }), _jsx("button", { type: "button", className: css.rangeBtn, "data-active": range === '30' ? '' : undefined, onClick: () => { setUserPickedRange(true); setRange('30'); }, children: "\u8FD1 30 \u5929" })] }), _jsx("button", { type: "button", className: css.settingsScanBtn, onClick: refresh, disabled: loading || !props.remote, children: loading ? '正在刷新' : '刷新' })] })] }), _jsxs("div", { className: css.heroStatsRow, children: [_jsxs("div", { className: css.heroBigNum, children: [analytics ? fmtCompact(analytics.totalTokens) : '-', " ", _jsx("span", { className: css.heroUnit, children: "Token" })] }), _jsxs("div", { className: css.heroMetaCol, children: [_jsxs("span", { children: ["\u7D2F\u8BA1\u8017\u65F6 ", _jsx("strong", { children: analytics ? `${analytics.totalTimeHours} 小时` : '-' })] }), _jsxs("span", { children: ["\u7F13\u5B58\u547D\u4E2D ", _jsx("strong", { children: analytics ? `${analytics.cacheHitPct}% (${cacheNote})` : '-' })] }), _jsxs("span", { children: ["\u6709\u7EDF\u8BA1\u7684\u5BF9\u8BDD ", _jsx("strong", { children: analytics ? `${analytics.validCount} / ${analytics.listed}` : '-' })] })] })] }), _jsxs("div", { className: css.roastGrid, children: [_jsxs("div", { className: `${css.roastItem} ${activeDrilldown === 'speed' ? css.roastItemActive : ''}`, onClick: () => setActiveDrilldown(activeDrilldown === 'speed' ? null : 'speed'), children: [_jsxs("div", { className: css.roastHead, children: [_jsx("span", { className: css.roastTag, style: { color: '#10b981' }, children: "\u6781\u81F4\u6253\u5B57\u673A" }), _jsx("span", { className: css.roastCategoryBadge, children: "\u901F\u5EA6\u738B\u8005" })] }), _jsx("div", { className: css.roastTitle, title: analytics?.fastKing?.model, children: analytics?.fastKing?.model ?? '暂无数据' }), _jsx("div", { className: css.roastDesc, title: "\u9996\u5B57\u54CD\u5E94\u6700\u8FC5\u901F\uFF0C\u8F7B\u91CF\u6539\u9519\u5229\u5668", children: "\u9996\u5B57\u54CD\u5E94\u6700\u8FC5\u901F\uFF0C\u8F7B\u91CF\u6539\u9519\u5229\u5668" }), _jsx("div", { className: css.roastVal, style: { color: '#10b981' }, children: analytics?.fastKing?.firstSamples ? `首字均值 ${(analytics.fastKing.firstMs / analytics.fastKing.firstSamples / 1000).toFixed(2)} 秒` : '暂无数据' }), _jsxs("div", { className: css.roastFooter, children: [_jsx("span", { className: css.roastFooterLeft, children: "\u9996\u54CD\u5E94\u8017\u65F6" }), _jsx("span", { className: css.roastAction, children: activeDrilldown === 'speed' ? '收起透视 ▴' : '透视详情 ›' })] })] }), _jsxs("div", { className: `${css.roastItem} ${activeDrilldown === 'latency' ? css.roastItemActive : ''}`, onClick: () => setActiveDrilldown(activeDrilldown === 'latency' ? null : 'latency'), children: [_jsxs("div", { className: css.roastHead, children: [_jsx("span", { className: css.roastTag, style: { color: '#d97706' }, children: "\u6700\u6162\u6811\u61D2" }), _jsx("span", { className: css.roastCategoryBadge, children: "\u5EF6\u8FDF\u74F6\u9888" })] }), _jsx("div", { className: css.roastTitle, title: analytics?.slowKing?.model, children: analytics?.slowKing?.model ?? '暂无数据' }), _jsx("div", { className: css.roastDesc, title: "\u9996\u5B57\u6392\u961F\u6700\u4E45\uFF0C\u70B9\u6839\u70DF\u7B49\u5B83\u5F00\u5DE5", children: "\u9996\u5B57\u6392\u961F\u6700\u4E45\uFF0C\u70B9\u6839\u70DF\u7B49\u5B83\u5F00\u5DE5" }), _jsx("div", { className: css.roastVal, style: { color: '#d97706' }, children: analytics?.slowKing?.firstSamples ? `首字均值 ${(analytics.slowKing.firstMs / analytics.slowKing.firstSamples / 1000).toFixed(2)} 秒` : '暂无数据' }), _jsxs("div", { className: css.roastFooter, children: [_jsx("span", { className: css.roastFooterLeft, children: "\u6392\u961F\u74F6\u9888" }), _jsx("span", { className: css.roastAction, children: activeDrilldown === 'latency' ? '收起透视 ▴' : '透视详情 ›' })] })] }), _jsxs("div", { className: `${css.roastItem} ${activeDrilldown === 'thinking' ? css.roastItemActive : ''}`, onClick: () => setActiveDrilldown(activeDrilldown === 'thinking' ? null : 'thinking'), children: [_jsxs("div", { className: css.roastHead, children: [_jsx("span", { className: css.roastTag, style: { color: '#8b5cf6' }, children: "\u6DF1\u5EA6\u6C89\u601D\u72C2" }), _jsx("span", { className: css.roastCategoryBadge, children: "\u63A8\u7406\u786C\u6838" })] }), _jsx("div", { className: css.roastTitle, title: analytics?.thinkKing?.model, children: analytics?.thinkKing?.model ?? '暂无思考记录' }), _jsx("div", { className: css.roastDesc, title: "\u601D\u8003 Token \u5360\u81EA\u8EAB\u8F93\u51FA\u6BD4\u4F8B\u6700\u9AD8", children: "\u601D\u8003 Token \u5360\u81EA\u8EAB\u8F93\u51FA\u6BD4\u4F8B\u6700\u9AD8" }), _jsx("div", { className: css.roastVal, style: { color: '#8b5cf6' }, children: analytics?.thinkKing ? `思考占比 ${Math.round(((analytics.thinkKing.reasoning ?? 0) / (((analytics.thinkKing.reasoning ?? 0) + (analytics.thinkKing.output ?? 0)) || 1)) * 100)}%` : '无推理记录' }), _jsxs("div", { className: css.roastFooter, children: [_jsx("span", { className: css.roastFooterLeft, children: "\u63A8\u5BFC\u5360\u6BD4" }), _jsx("span", { className: css.roastAction, children: activeDrilldown === 'thinking' ? '收起透视 ▴' : '透视详情 ›' })] })] }), _jsxs("div", { className: `${css.roastItem} ${activeDrilldown === 'cache' ? css.roastItemActive : ''}`, onClick: () => setActiveDrilldown(activeDrilldown === 'cache' ? null : 'cache'), children: [_jsxs("div", { className: css.roastHead, children: [_jsx("span", { className: css.roastTag, style: { color: (analytics?.cacheHitPct ?? 0) >= 40 ? '#10b981' : '#f59e0b' }, children: (analytics?.cacheHitPct ?? 0) >= 40 ? '省流小能手' : '缓存待提升' }), _jsx("span", { className: css.roastCategoryBadge, children: "\u6210\u672C\u63A7\u5236" })] }), _jsx("div", { className: css.roastTitle, title: analytics?.bestCacheModel?.model, children: (analytics?.cacheHitPct ?? 0) >= 40 ? (analytics?.bestCacheModel?.model ?? '上下文复用') : '上下文重传较多' }), _jsx("div", { className: css.roastDesc, title: (analytics?.cacheHitPct ?? 0) >= 40 ? '前缀缓存命中率高，大幅节约 Token' : '较多长文本全量重传，可利用前缀缓存', children: (analytics?.cacheHitPct ?? 0) >= 40 ? '前缀缓存命中率高，大幅节约 Token' : '较多长文本全量重传，可利用前缀缓存' }), _jsx("div", { className: css.roastVal, style: { color: (analytics?.cacheHitPct ?? 0) >= 40 ? '#10b981' : '#f59e0b' }, children: analytics ? `命中 ${analytics.cacheHitPct}% (${fmtCompact(analytics.totalCacheRead)} Token)` : '-' }), _jsxs("div", { className: css.roastFooter, children: [_jsx("span", { className: css.roastFooterLeft, children: "\u7F13\u5B58\u6548\u7387" }), _jsx("span", { className: css.roastAction, children: activeDrilldown === 'cache' ? '收起透视 ▴' : '透视详情 ›' })] })] }), _jsxs("div", { className: `${css.roastItem} ${activeDrilldown === 'tool' ? css.roastItemActive : ''}`, onClick: () => setActiveDrilldown(activeDrilldown === 'tool' ? null : 'tool'), children: [_jsxs("div", { className: css.roastHead, children: [_jsx("span", { className: css.roastTag, style: { color: (analytics?.toolTimePct ?? 0) >= 30 ? '#f59e0b' : '#3b82f6' }, children: (analytics?.toolTimePct ?? 0) >= 30 ? '终端耗时狂' : '秒级放行' }), _jsx("span", { className: css.roastCategoryBadge, children: "\u5DE5\u7A0B\u5F52\u56E0" })] }), _jsx("div", { className: css.roastTitle, children: (analytics?.toolTimePct ?? 0) >= 30 ? `本地命令占 ${analytics?.toolTimePct}% 耗时` : `本地损耗仅 ${analytics?.toolTimePct ?? 0}%` }), _jsx("div", { className: css.roastDesc, title: (analytics?.toolTimePct ?? 0) >= 30 ? '很多时候不是模型卡，是本地脚本跑太久' : '本地工具极速执行，等待时间主要在云端', children: (analytics?.toolTimePct ?? 0) >= 30 ? '很多时候不是模型卡，是本地脚本跑太久' : '本地工具极速执行，等待时间主要在云端' }), _jsx("div", { className: css.roastVal, style: { color: (analytics?.toolTimePct ?? 0) >= 30 ? '#f59e0b' : '#3b82f6' }, children: analytics ? `工具耗时 ${Math.round(analytics.totalToolMs / 1000)} 秒 (${analytics.totalTools} 次)` : '-' }), _jsxs("div", { className: css.roastFooter, children: [_jsx("span", { className: css.roastFooterLeft, children: "\u672C\u5730\u8017\u65F6" }), _jsx("span", { className: css.roastAction, children: activeDrilldown === 'tool' ? '收起透视 ▴' : '透视详情 ›' })] })] }), _jsxs("div", { className: `${css.roastItem} ${activeDrilldown === 'reliability' ? css.roastItemActive : ''}`, onClick: () => setActiveDrilldown(activeDrilldown === 'reliability' ? null : 'reliability'), children: [_jsxs("div", { className: css.roastHead, children: [_jsx("span", { className: css.roastTag, style: { color: (analytics?.totalErrors ?? 0) > 0 ? '#ef4444' : '#10b981' }, children: (analytics?.totalErrors ?? 0) > 0 ? '翻车排查' : '运行可靠度' }), _jsx("span", { className: css.roastCategoryBadge, children: "\u7A33\u5B9A\u6027" })] }), _jsx("div", { className: css.roastTitle, title: (analytics?.totalErrors ?? 0) > 0 ? '存在工具报错' : '执行顺畅', children: (analytics?.totalErrors ?? 0) > 0 ? `${analytics?.totalErrors} 次工具报错` : '100% 顺畅' }), _jsx("div", { className: css.roastDesc, title: (analytics?.totalErrors ?? 0) > 0 ? '命令执行或参数错误，注意环境排查' : '未发生命令报错或异常，执行稳健', children: (analytics?.totalErrors ?? 0) > 0 ? '命令执行或参数错误，注意环境排查' : '未发生命令报错或异常，执行稳健' }), _jsx("div", { className: css.roastVal, style: { color: (analytics?.totalErrors ?? 0) > 0 ? '#ef4444' : '#10b981' }, children: (analytics?.totalErrors ?? 0) > 0 ? `${analytics?.totalErrors} 次报错 · ${analytics?.totalRetries} 次重试` : '0 报错 · 0 重试' }), _jsxs("div", { className: css.roastFooter, children: [_jsx("span", { className: css.roastFooterLeft, children: "\u5F02\u5E38\u68C0\u6D4B" }), _jsx("span", { className: css.roastAction, children: activeDrilldown === 'reliability' ? '收起透视 ▴' : '透视详情 ›' })] })] })] }), activeDrilldown && analytics ? (_jsxs("div", { className: css.drilldownPanel, children: [_jsxs("div", { className: css.drilldownHead, children: [_jsxs("div", { className: css.drilldownTitleGroup, children: [_jsxs("span", { className: css.drilldownTitle, children: [activeDrilldown === 'speed' && '⚡ 模型首字响应延迟对比 (TTFT)', activeDrilldown === 'latency' && '🐢 模型首字排队耗时排行榜', activeDrilldown === 'thinking' && '🧠 深度推导算力分配明细', activeDrilldown === 'cache' && '💰 前缀缓存命中率排行榜', activeDrilldown === 'tool' && '⏱️ 本地工具与终端命令耗时全景拆解', activeDrilldown === 'reliability' && '🛡️ 运行可靠度与报错排查'] }), _jsxs("span", { className: css.drilldownSub, children: [activeDrilldown === 'speed' && '按首响应延迟升序排列（最快在上，首字响应最迅速）', activeDrilldown === 'latency' && '按排队耗时降序排列（排队最久在上，定位卡顿瓶颈）', activeDrilldown === 'thinking' && '按思考 Token 占比降序排列（对比自我推导与正文算力比重）', activeDrilldown === 'cache' && '按前缀缓存命中率降序排列（直接决定上下文成本与省钱效率）', activeDrilldown === 'tool' && '本地工具耗时全景拆解（按单会话本地执行耗时由大到小降序排查）', activeDrilldown === 'reliability' && '按报错与重试次数降序排查（优先定位最高频故障会话）'] })] }), _jsx("button", { type: "button", className: css.drilldownCloseBtn, onClick: () => setActiveDrilldown(null), children: "\u6536\u8D77 \u2715" })] }), activeDrilldown === 'speed' && (_jsxs("div", { className: css.rankList, children: [analytics.speedList.map((m, idx) => {
                                const avgMs = m.firstMs / m.firstSamples;
                                const minMs = analytics.speedList[0].firstMs / analytics.speedList[0].firstSamples;
                                // 最快的模型得分为 100%，后续依次递减，条长完美单调递减
                                const score = Math.max(10, Math.min(100, Math.round((minMs / avgMs) * 100)));
                                const color = avgMs < 1000 ? '#10b981' : avgMs < 3000 ? '#3b82f6' : '#f59e0b';
                                return (_jsxs("div", { className: css.rankItem, children: [_jsxs("div", { className: css.rankItemTop, children: [_jsxs("div", { className: css.rankItemLeft, children: [_jsxs("span", { className: `${css.rankBadge} ${idx === 0 ? css.rankBadgeGold : ''}`, children: ["#", idx + 1] }), _jsx("span", { className: css.rankName, title: m.model, children: m.model })] }), _jsxs("span", { className: css.rankValMain, style: { color }, children: [(avgMs / 1000).toFixed(2), " \u79D2"] })] }), _jsx("div", { className: css.rankTrack, children: _jsx("div", { className: css.rankBar, style: { width: `${score}%`, background: color } }) }), _jsxs("div", { className: css.rankSubText, children: [_jsxs("span", { children: ["\u901F\u5EA6\u654F\u6377\u5F97\u5206 ", _jsxs("strong", { children: [score, "\u5206"] }), " (\u9996\u5B57\u5747\u503C ", (avgMs / 1000).toFixed(2), "s)"] }), _jsxs("span", { children: ["\u7D2F\u8BA1\u91C7\u6837 ", m.firstSamples, " \u6B21"] })] })] }, m.model));
                            }), analytics.speedList.length === 0 ? (_jsx("div", { className: css.drilldownEmpty, children: "\u6682\u65E0\u6A21\u578B\u9996\u5B57\u54CD\u5E94\u5EF6\u8FDF\u91C7\u6837\u6570\u636E\u3002" })) : null] })), activeDrilldown === 'latency' && (_jsxs("div", { className: css.rankList, children: [analytics.latencyList.map((m, idx) => {
                                const avgMs = m.firstMs / m.firstSamples;
                                const maxMs = analytics.latencyList[0].firstMs / analytics.latencyList[0].firstSamples;
                                // 最慢的模型瓶颈权重 100%，后续依次递减，条长完美单调递减
                                const bottleneckPct = Math.max(10, Math.min(100, Math.round((avgMs / maxMs) * 100)));
                                const color = avgMs > 5000 ? '#ef4444' : avgMs > 2000 ? '#f59e0b' : '#3b82f6';
                                return (_jsxs("div", { className: css.rankItem, children: [_jsxs("div", { className: css.rankItemTop, children: [_jsxs("div", { className: css.rankItemLeft, children: [_jsxs("span", { className: `${css.rankBadge} ${idx === 0 ? css.rankBadgeGold : ''}`, children: ["#", idx + 1] }), _jsx("span", { className: css.rankName, title: m.model, children: m.model })] }), _jsxs("span", { className: css.rankValMain, style: { color }, children: [(avgMs / 1000).toFixed(2), " \u79D2"] })] }), _jsx("div", { className: css.rankTrack, children: _jsx("div", { className: css.rankBar, style: { width: `${bottleneckPct}%`, background: color } }) }), _jsxs("div", { className: css.rankSubText, children: [_jsxs("span", { children: ["\u6392\u961F\u5EF6\u8FDF ", _jsxs("strong", { children: [(avgMs / 1000).toFixed(2), "s"] }), " (\u74F6\u9888\u6743\u91CD ", bottleneckPct, "%)"] }), _jsxs("span", { children: ["\u7D2F\u8BA1\u91C7\u6837 ", m.firstSamples, " \u6B21"] })] })] }, m.model));
                            }), analytics.latencyList.length === 0 ? (_jsx("div", { className: css.drilldownEmpty, children: "\u6682\u65E0\u6A21\u578B\u6392\u961F\u5EF6\u8FDF\u91C7\u6837\u6570\u636E\u3002" })) : null] })), activeDrilldown === 'thinking' && (_jsxs("div", { className: css.rankList, children: [analytics.thinkList.map((m, idx) => {
                                const totalTokens = (m.reasoning ?? 0) + (m.output ?? 0);
                                const thinkPct = totalTokens > 0 ? Math.round((m.reasoning / totalTokens) * 100) : 0;
                                return (_jsxs("div", { className: css.rankItem, children: [_jsxs("div", { className: css.rankItemTop, children: [_jsxs("div", { className: css.rankItemLeft, children: [_jsxs("span", { className: `${css.rankBadge} ${idx === 0 ? css.rankBadgeGold : ''}`, children: ["#", idx + 1] }), _jsx("span", { className: css.rankName, title: m.model, children: m.model })] }), _jsxs("span", { className: css.rankValMain, style: { color: '#8b5cf6' }, children: ["\u601D\u8003\u5360\u6BD4 ", thinkPct, "%"] })] }), _jsxs("div", { className: css.toolCompoundTrack, style: { height: '8px' }, children: [_jsx("div", { style: { width: `${thinkPct}%`, background: '#8b5cf6', height: '100%' }, title: `思考: ${thinkPct}%` }), _jsx("div", { style: { width: `${100 - thinkPct}%`, background: '#38bdf8', height: '100%' }, title: `正文: ${100 - thinkPct}%` })] }), _jsxs("div", { className: css.rankSubText, children: [_jsxs("span", { children: ["\u601D\u8003\u63A8\u5BFC ", _jsx("strong", { children: fmtCompact(m.reasoning) }), " Token (", thinkPct, "%)"] }), _jsxs("span", { children: ["\u6B63\u6587\u8F93\u51FA ", _jsx("strong", { children: fmtCompact(m.output) }), " Token"] })] })] }, m.model));
                            }), analytics.thinkList.length === 0 ? (_jsx("div", { className: css.drilldownEmpty, children: "\u5F53\u524D\u65F6\u95F4\u8303\u56F4\u5185\u672A\u68C0\u6D4B\u5230\u8C03\u7528\u5E26\u63A8\u5BFC\u601D\u8003\u8FC7\u7A0B\u7684\u6A21\u578B\u3002" })) : null] })), activeDrilldown === 'cache' && (_jsxs("div", { className: css.rankList, children: [analytics.cacheList.map((m, idx) => {
                                const totalIn = (m.input ?? 0) + (m.cacheRead ?? 0);
                                const hitPct = totalIn > 0 ? Math.round(((m.cacheRead ?? 0) / totalIn) * 100) : 0;
                                return (_jsxs("div", { className: css.rankItem, children: [_jsxs("div", { className: css.rankItemTop, children: [_jsxs("div", { className: css.rankItemLeft, children: [_jsxs("span", { className: `${css.rankBadge} ${idx === 0 ? css.rankBadgeGold : ''}`, children: ["#", idx + 1] }), _jsx("span", { className: css.rankName, title: m.model, children: m.model })] }), _jsxs("span", { className: css.rankValMain, style: { color: '#10b981' }, children: ["\u547D\u4E2D\u7387 ", hitPct, "%"] })] }), _jsxs("div", { className: css.toolCompoundTrack, style: { height: '8px' }, children: [_jsx("div", { style: { width: `${hitPct}%`, background: '#10b981', height: '100%' }, title: `缓存命中: ${hitPct}%` }), _jsx("div", { style: { width: `${100 - hitPct}%`, background: 'var(--dsw-alias-border-l3, #94a3b8)', height: '100%' }, title: `未命中: ${100 - hitPct}%` })] }), _jsxs("div", { className: css.rankSubText, children: [_jsxs("span", { children: ["\u547D\u4E2D\u590D\u7528 ", _jsx("strong", { children: fmtCompact(m.cacheRead ?? 0) }), " Token (", hitPct, "%)"] }), _jsxs("span", { children: ["\u5B9E\u4ED8\u8F93\u5165 ", _jsx("strong", { children: fmtCompact(m.input ?? 0) }), " Token"] })] })] }, m.model));
                            }), analytics.cacheList.length === 0 ? (_jsx("div", { className: css.drilldownEmpty, children: "\u6682\u65E0\u6A21\u578B\u7F13\u5B58\u4F7F\u7528\u8BB0\u5F55\u3002" })) : null] })), activeDrilldown === 'tool' && (_jsxs("div", { className: css.toolDrillSection, children: [_jsxs("div", { className: css.toolCompoundBox, children: [_jsxs("div", { className: css.toolCompoundTrack, children: [_jsx("div", { className: css.toolSliceBash, style: { width: `${analytics.bashPct}%` } }), _jsx("div", { className: css.toolSliceFile, style: { width: `${analytics.filePct}%` } })] }), _jsxs("div", { className: css.toolCompoundLegend, children: [_jsxs("span", { children: [_jsx("i", { className: css.dlDot, style: { background: 'var(--dsw-static-green-500, #10b981)' } }), " \u7EC8\u7AEF\u547D\u4EE4 (Bash): ", _jsxs("strong", { children: [Math.round(analytics.totalBashMs / 1000), "\u79D2 (", analytics.bashPct, "%)"] })] }), _jsxs("span", { children: [_jsx("i", { className: css.dlDot, style: { background: '#0ea5e9' } }), " \u6587\u4EF6\u4E0E\u901A\u7528\u8BFB\u5199: ", _jsxs("strong", { children: [Math.round(analytics.totalFileMs / 1000), "\u79D2 (", analytics.filePct, "%)"] })] })] })] }), _jsxs("div", { className: css.toolGridCards, children: [_jsxs("div", { className: css.toolMiniCard, children: [_jsxs("div", { className: css.toolMiniTitle, children: [_jsx("i", { className: css.dlDot, style: { background: 'var(--dsw-static-green-500, #10b981)' } }), _jsx("span", { children: "\u7EC8\u7AEF Bash \u547D\u4EE4 (\u6D4B\u8BD5/\u6784\u5EFA/\u811A\u672C)" })] }), _jsxs("div", { className: css.toolMiniNum, children: [Math.round(analytics.totalBashMs / 1000), " \u79D2"] }), _jsx("div", { className: css.toolMiniDesc, children: "\u5305\u542B npm run, cargo, git, Python \u4EE5\u53CA\u672C\u5730\u81EA\u52A8\u5316\u6D4B\u8BD5\u811A\u672C\u7B49\u9AD8\u8017\u65F6\u8FD0\u884C\u73AF\u8282\u3002" })] }), _jsxs("div", { className: css.toolMiniCard, children: [_jsxs("div", { className: css.toolMiniTitle, children: [_jsx("i", { className: css.dlDot, style: { background: '#0ea5e9' } }), _jsx("span", { children: "\u6587\u4EF6\u64CD\u4F5C\u4E0E\u5176\u4ED6\u5DE5\u5177 (\u8BFB\u5199/\u68C0\u7D22)" })] }), _jsxs("div", { className: css.toolMiniNum, children: [Math.round(analytics.totalFileMs / 1000), " \u79D2"] }), _jsx("div", { className: css.toolMiniDesc, children: "\u5305\u542B read, write, edit, glob, grep \u7B49\u8F7B\u91CF\u5FEB\u901F\u6587\u4EF6\u8BFB\u5199\u3002\u5355\u6B21\u8017\u65F6\u901A\u5E38\u5728\u6BEB\u79D2\u7EA7\u3002" })] })] }), analytics.topToolSessions && analytics.topToolSessions.length > 0 ? (_jsxs("div", { className: css.toolTopList, children: [_jsx("div", { className: css.toolTopListTitle, children: "\u5355\u4F1A\u8BDD\u5DE5\u5177\u603B\u8017\u65F6 TOP 3 (\u964D\u5E8F\u6392\u67E5)" }), analytics.topToolSessions.slice(0, 3).map((s, idx) => {
                                        const tMs = s.value?.totals?.toolMs ?? 0;
                                        const bMs = s.value?.totals?.bashMs ?? 0;
                                        const fMs = Math.max(0, tMs - bMs);
                                        const bPct = tMs > 0 ? Math.round((bMs / tMs) * 100) : 0;
                                        return (_jsxs("div", { className: css.rankItem, children: [_jsxs("div", { className: css.rankItemTop, children: [_jsxs("div", { className: css.rankItemLeft, children: [_jsxs("span", { className: `${css.rankBadge} ${idx === 0 ? css.rankBadgeGold : ''}`, children: ["#", idx + 1] }), _jsxs("span", { className: css.sessionIdTag, children: [s.sessionId.slice(0, 14), "\u2026"] }), _jsx("span", { className: css.rankName, title: s.value?.models?.[0]?.model, children: s.value?.models?.[0]?.model ?? '通用会话' })] }), _jsxs("span", { className: css.rankValMain, children: ["\u603B\u8BA1 ", Math.round(tMs / 1000), " \u79D2"] })] }), _jsxs("div", { className: css.toolCompoundTrack, style: { height: '8px' }, children: [_jsx("div", { style: { width: `${bPct}%`, background: 'var(--dsw-static-green-500, #10b981)', height: '100%' }, title: `终端命令: ${Math.round(bMs / 1000)}s` }), _jsx("div", { style: { width: `${100 - bPct}%`, background: '#0ea5e9', height: '100%' }, title: `文件读写: ${Math.round(fMs / 1000)}s` })] }), _jsxs("div", { className: css.rankSubText, children: [_jsxs("span", { children: ["\u7EC8\u7AEF Bash ", _jsxs("strong", { children: [Math.round(bMs / 1000), "s"] }), " (", bPct, "%)"] }), _jsxs("span", { children: ["\u6587\u4EF6\u8BFB\u5199 ", _jsxs("strong", { children: [Math.round(fMs / 1000), "s"] }), " (", 100 - bPct, "%)"] })] })] }, s.sessionId));
                                    })] })) : null] })), activeDrilldown === 'reliability' && (_jsx("div", { className: css.errorDrillSection, children: analytics.totalErrors === 0 && analytics.totalRetries === 0 ? (_jsx("div", { className: css.errorAllGoodBox, children: "\u2713 \u5168\u90E8\u4F1A\u8BDD\u5DE5\u5177\u6267\u884C 100% \u987A\u7545\uFF0C\u672A\u8BB0\u5F55\u5230\u4EFB\u4F55\u975E\u96F6\u9000\u51FA\u7801\u6216\u91CD\u8BD5\u5F02\u5E38\uFF01" })) : (_jsxs("div", { className: css.errorSessionList, children: [_jsx("div", { className: css.toolTopListTitle, children: "\u62A5\u9519\u4E0E\u91CD\u8BD5\u6392\u67E5\u5217\u8868 (\u6309\u5F02\u5E38\u4E25\u91CD\u5EA6\u964D\u5E8F)" }), analytics.errorSessions.map((s, idx) => (_jsxs("div", { className: css.errorSessionRow, children: [_jsxs("span", { className: `${css.rankBadge} ${idx === 0 ? css.rankBadgeGold : ''}`, children: ["#", idx + 1] }), _jsxs("span", { className: css.sessionIdTag, children: [s.sessionId.slice(0, 14), "\u2026"] }), _jsx("span", { className: css.rankName, children: s.value?.models?.[0]?.model ?? '通用对话' }), _jsx("span", { className: s.value?.totals?.toolErrors > 0 ? css.statusBad : css.statusOk, children: s.value?.totals?.toolErrors > 0 ? `${s.value.totals.toolErrors} 次报错` : '0 报错' }), _jsx("span", { className: s.value?.totals?.retries > 0 ? css.statusWarn : css.statusOk, children: s.value?.totals?.retries > 0 ? `${s.value.totals.retries} 次重试` : '0 重试' })] }, s.sessionId)))] })) }))] })) : null, _jsxs("div", { className: css.vizSplitGrid, children: [_jsxs("div", { className: css.vizPanel, children: [_jsxs("div", { className: css.vizHead, children: [_jsx("span", { className: css.vizTitle, children: "\u6A21\u578B\u652F\u51FA\u4EFD\u989D" }), _jsx("span", { className: css.vizSub, children: "\u6309\u6D88\u8017 Token \u964D\u5E8F\u6392\u5217" })] }), _jsxs("div", { className: css.donutWrap, children: [_jsxs("div", { className: css.donutSvgBox, children: [_jsxs("svg", { viewBox: "0 0 100 100", className: css.donutSvg, children: [_jsx("circle", { cx: "50", cy: "50", r: "38", fill: "none", stroke: "var(--dsw-alias-bg-layer-2)", strokeWidth: "12" }), _jsx("g", { transform: "rotate(-90 50 50)", children: (analytics?.donutSegments.length ?? 0) === 1 ? (_jsx("circle", { cx: "50", cy: "50", r: "38", fill: "none", stroke: analytics.donutSegments[0].color, strokeWidth: "12" })) : (analytics?.donutSegments.map((seg, idx) => (_jsx("circle", { cx: "50", cy: "50", r: "38", fill: "none", stroke: seg.color, strokeWidth: "12", strokeDasharray: seg.dasharray, strokeDashoffset: seg.dashoffset }, idx)))) })] }), _jsxs("div", { className: css.donutCenterText, children: [_jsx("div", { className: css.donutCenterNum, children: activeSeg ? `${activeSeg.pct}%` : topModel ? `${topModel.pct}%` : `${analytics?.donutSegments.length ?? 0}款` }), _jsx("div", { className: css.donutCenterSub, children: activeSeg ? '选中占比' : '主力占比' })] })] }), _jsx("div", { className: css.donutLegendList, children: analytics?.donutSegments.map((seg, idx) => (_jsxs("div", { className: `${css.donutLegendRow} ${hoveredIdx === idx ? css.donutLegendRowActive : ''}`, onMouseEnter: () => setHoveredIdx(idx), onMouseLeave: () => setHoveredIdx(null), children: [_jsxs("span", { className: css.dlLeft, children: [_jsx("i", { className: css.dlDot, style: { background: seg.color } }), _jsx("span", { className: css.dlName, title: seg.model, children: seg.model })] }), _jsxs("span", { className: css.dlRight, children: [fmtCompact(seg.tokens), " \u00B7 ", seg.pct, "%"] })] }, idx))) })] }), (activeSeg || topModel) ? (_jsxs("div", { className: css.donutInspectBar, children: [_jsx("i", { className: css.dlDot, style: { background: (activeSeg || topModel)?.color } }), _jsx("span", { className: css.donutInspectName, title: (activeSeg || topModel)?.model, children: (activeSeg || topModel)?.model }), _jsx("span", { className: css.donutInspectTag, children: activeSeg ? '当前高亮' : '全场主力' }), _jsxs("span", { className: css.donutInspectVal, children: [fmtCompact((activeSeg || topModel)?.tokens ?? 0), " Token (", (activeSeg || topModel)?.pct, "%)"] })] })) : null] }), _jsxs("div", { className: css.vizPanel, children: [_jsxs("div", { className: css.vizHead, children: [_jsx("span", { className: css.vizTitle, children: "\u6BCF\u65E5\u7F16\u7801\u6D3B\u8DC3\u5EA6" }), _jsxs("span", { className: css.vizSub, children: ["\u8FD1 ", range, " \u5929\u5206\u5E03"] })] }), _jsx("div", { className: `${css.dayStack} ${range === '7' ? css.dayStackWeek : ''}`, "aria-label": "\u6309\u65E5\u6D3B\u8DC3\u67F1\u56FE", children: (analytics?.daySeries ?? []).map(day => (_jsxs("div", { className: css.dayCol, title: `${day.key} · ${fmtCompact(day.total)} Token`, children: [_jsx("div", { className: css.dayColFill, children: day.total > 0 ? (day.segments.map(seg => (_jsx("div", { className: css.daySeg, style: {
                                                    height: `${(seg.tokens / analytics.dayMax) * 100}%`,
                                                    background: seg.color,
                                                } }, seg.model)))) : (_jsx("div", { className: css.dayEmptyDot })) }), _jsx("span", { className: css.dayLabel, children: day.label })] }, day.key))) }), _jsx("div", { className: css.chartFoot, children: "\u6BCF\u65E5\u67F1\u9AD8\u4EE3\u8868\u5F53\u5929\u6700\u540E\u6D3B\u52A8\u7684\u5BF9\u8BDD Token \u6C47\u603B\uFF0C\u5206\u8272\u5BF9\u5E94\u5DE6\u4FA7\u8C03\u7528\u6A21\u578B\u3002" })] })] }), _jsxs("div", { className: css.vizPanel, children: [_jsxs("div", { className: css.vizHead, children: [_jsxs("div", { className: css.tableTitleGroup, children: [_jsx("span", { className: css.vizTitle, children: "\u91CD\u70B9\u5BF9\u8BDD\u8D26\u5355" }), _jsxs("span", { className: css.vizSub, children: [sessionSort === 'tokens' && '按 Token 消耗由高到低严格排序', sessionSort === 'time' && '按执行总耗时由长到短严格排序', sessionSort === 'errors' && '按报错与重试次数降序排查'] })] }), _jsxs("div", { className: css.tableSortGroup, role: "group", "aria-label": "\u5BF9\u8BDD\u8D26\u5355\u6392\u5E8F\u5207\u6362", children: [_jsx("button", { type: "button", className: css.sortBtn, "data-active": sessionSort === 'tokens' ? '' : undefined, onClick: () => setSessionSort('tokens'), children: "Token \u6D88\u8017 \u2193" }), _jsx("button", { type: "button", className: css.sortBtn, "data-active": sessionSort === 'time' ? '' : undefined, onClick: () => setSessionSort('time'), children: "\u603B\u8017\u65F6 \u2193" }), _jsx("button", { type: "button", className: css.sortBtn, "data-active": sessionSort === 'errors' ? '' : undefined, onClick: () => setSessionSort('errors'), children: "\u6545\u969C\u6570 \u2193" })] })] }), sessions && sessions.rows.length > 0 ? (_jsxs("div", { className: css.sessionTableBox, children: [_jsxs("div", { className: css.sessionTableHeader, children: [_jsx("span", { children: "\u6392\u540D \u00B7 \u4F1A\u8BDDID" }), _jsx("span", { children: "\u4E3B\u7528\u6A21\u578B" }), _jsx("span", { style: { textAlign: 'right' }, children: "Token \u6D88\u8017" }), _jsx("span", { style: { textAlign: 'right' }, children: "\u603B\u8017\u65F6" }), _jsx("span", { style: { textAlign: 'center' }, children: "\u8FD0\u884C\u72B6\u6001" }), _jsx("span", {})] }), analytics?.sortedSessions.slice(0, 10).map((row, idx) => {
                                const val = row.value;
                                const isOpen = openSessionId === row.sessionId;
                                const errCount = val.totals.toolErrors ?? 0;
                                const retryCount = val.totals.retries ?? 0;
                                const modelMs = val.totals.modelMs ?? 0;
                                const toolMs = val.totals.toolMs ?? 0;
                                const totalMs = modelMs + toolMs;
                                const modelPct = totalMs > 0 ? Math.round((modelMs / totalMs) * 100) : 50;
                                const status = errCount > 0
                                    ? `${errCount} 次报错`
                                    : retryCount > 0 ? `${retryCount} 次重试` : '顺畅';
                                const tokenBarPct = Math.max(4, Math.round(((val.totals.tokens ?? 0) / analytics.maxSessionTokens) * 100));
                                return (_jsxs("div", { className: `${css.sessionItemRow} ${isOpen ? css.sessionItemOpen : ''}`, children: [_jsxs("button", { type: "button", className: css.sessionItemHead, onClick: () => setOpenSessionId(isOpen ? null : row.sessionId), children: [_jsxs("span", { className: css.sessionIdTag, title: row.sessionId, children: [_jsxs("strong", { className: css.tableRankNum, children: ["#", idx + 1] }), " ", row.sessionId.length > 12 ? `${row.sessionId.slice(0, 6)}…${row.sessionId.slice(-3)}` : row.sessionId] }), _jsx("span", { className: css.sessionModelCell, title: val.models?.[0]?.model, children: val.models?.[0]?.model ?? '未标注' }), _jsxs("div", { className: css.sessionTokenCell, children: [_jsx("span", { children: fmtCompact(val.totals.tokens) }), _jsx("div", { className: css.sessionTokenBar, style: { width: `${tokenBarPct}%` } })] }), _jsxs("span", { style: { textAlign: 'right' }, children: [Math.round(totalMs / 1000), " \u79D2"] }), _jsx("span", { style: { textAlign: 'center' }, className: errCount > 0 ? css.statusBad : retryCount > 0 ? css.statusWarn : css.statusOk, children: status }), _jsx("span", { className: css.arrowIcon, children: "\u203A" })] }), isOpen ? (_jsxs("div", { className: css.sessionItemDrawer, children: [_jsx("div", { className: css.drawerTitle, children: "\u8017\u65F6\u6784\u6210\u4E0B\u94BB\uFF1A\u6A21\u578B\u54CD\u5E94 vs \u672C\u5730\u5DE5\u5177" }), _jsxs("div", { className: css.drawerBarTrack, children: [_jsx("div", { className: css.drawerSliceModel, style: { width: `${modelPct}%` } }), _jsx("div", { className: css.drawerSliceTool, style: { width: `${100 - modelPct}%` } })] }), _jsxs("div", { className: css.drawerMetaRow, children: [_jsxs("span", { children: ["\u6A21\u578B ", Math.round(modelMs / 1000), " \u79D2 (\u9996\u54CD\u5E94\u5747\u503C ", val.totals.firstSamples ? (val.totals.firstMs / val.totals.firstSamples / 1000).toFixed(1) : 0, "s)"] }), _jsxs("span", { children: ["\u5DE5\u5177 ", Math.round(toolMs / 1000), " \u79D2 \u00B7 ", val.totals.tools, " \u6B21\u6267\u884C"] }), _jsxs("span", { children: ["\u7F13\u5B58\u547D\u4E2D\u7387 ", val.totals.input + val.totals.cacheRead > 0 ? Math.round((val.totals.cacheRead / (val.totals.input + val.totals.cacheRead)) * 100) : 0, "%"] })] })] })) : null] }, row.sessionId));
                            })] })) : (_jsx("div", { className: css.emptyScan, children: "\u6682\u65E0\u5DF2\u7F13\u5B58\u7684\u5BF9\u8BDD\u7EDF\u8BA1\u3002" }))] }), _jsxs("details", { className: css.settingsDrawer, children: [_jsx("summary", { className: css.settingsSummary, children: "\u2699 \u9AD8\u7EA7\u62A5\u8B66\u9608\u503C\u8BBE\u7F6E (\u9ED8\u8BA4\u5F00\u7BB1\u5373\u7528\uFF0C\u65E0\u9700\u9891\u7E41\u8C03\u6574)" }), _jsxs("div", { className: css.settingsDrawerContent, children: [_jsxs("label", { className: css.settingInlineItem, children: [_jsx("span", { children: "\u7B49\u591A\u4E45\u6CA1\u5B57\u7B97\u5361\u987F:" }), _jsx("input", { type: "number", min: 5, max: 300, className: css.settingsMiniInput, value: silence, onChange: e => setSilence(Number(e.target.value)) }), _jsx("span", { children: "\u79D2" })] }), _jsxs("label", { className: css.settingInlineItem, children: [_jsx("span", { children: "\u5355\u6B21\u63A8\u5BFC\u601D\u8003\u8D85\u65F6:" }), _jsx("input", { type: "number", min: 10, max: 600, className: css.settingsMiniInput, value: reasoning, onChange: e => setReasoning(Number(e.target.value)) }), _jsx("span", { children: "\u79D2" })] }), _jsx("button", { type: "button", className: css.settingsMiniSaveBtn, onClick: save, children: saved ? '已保存 ✓' : '保存' })] })] })] }));
}
//# sourceMappingURL=Insights.js.map