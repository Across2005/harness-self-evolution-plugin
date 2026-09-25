import { jsx as _jsx, jsxs as _jsxs, Fragment as _Fragment } from "react/jsx-runtime";
import { useState, useRef } from 'react';
import css from './TimingPanel.module.css';
const duration = (ms) => {
    if (ms < 1000)
        return `${Math.round(ms)} ms`;
    if (ms < 60000)
        return `${(ms / 1000).toFixed(1)} 秒`;
    const seconds = Math.round(ms / 1000);
    return `${Math.floor(seconds / 60)} 分 ${seconds % 60} 秒`;
};
const fmtNum = (n) => new Intl.NumberFormat('zh-CN', { maximumFractionDigits: 0 }).format(n);
export function TimingPanel({ stats, scope, tokensPerSecond, }) {
    const [hoverSlice, setHoverSlice] = useState(null);
    const [popoverLeft, setPopoverLeft] = useState(0);
    const [arrowLeft, setArrowLeft] = useState(120);
    const chartBoxRef = useRef(null);
    // 1. 各项绝对耗时
    const ttftMs = stats.firstMs ?? 0;
    const thinkMs = stats.reasoningMs ?? 0;
    const modelTotalMs = stats.modelMs ?? 0;
    // 输出耗时为模型总耗时减去首字等待与推理（如果模型总耗时充分），否则按剩余值
    const outputMs = Math.max(0, modelTotalMs - ttftMs - thinkMs);
    const toolTotalMs = stats.toolMs ?? 0;
    const bashMs = stats.bashMs ?? 0;
    const fileMs = Math.max(0, toolTotalMs - bashMs);
    // 2. 总耗时（以模型总耗时与工具耗时为两大互斥主体计算比例）
    const combinedMs = modelTotalMs + toolTotalMs;
    // 如果总耗时为0，给个占位
    const modelPct = combinedMs > 0 ? (modelTotalMs / combinedMs) * 100 : 50;
    const toolPct = combinedMs > 0 ? (toolTotalMs / combinedMs) * 100 : 50;
    // 3. 内部切片相对各自父级的耗时占比（严格 <= 100%）
    const ttftSubPct = modelTotalMs > 0 ? Math.min(100, Math.round((ttftMs / modelTotalMs) * 100)) : 0;
    const thinkSubPct = modelTotalMs > 0 ? Math.min(100 - ttftSubPct, Math.round((thinkMs / modelTotalMs) * 100)) : 0;
    const outputSubPct = modelTotalMs > 0 ? Math.max(0, 100 - ttftSubPct - thinkSubPct) : 0;
    const bashSubPct = toolTotalMs > 0 ? Math.min(100, Math.round((bashMs / toolTotalMs) * 100)) : (toolTotalMs > 0 ? 100 : 0);
    const fileSubPct = toolTotalMs > 0 ? Math.max(0, 100 - bashSubPct) : 0;
    // 4. Token 生成算力分配计算（思考 vs 正文，分子为单项，分母为总生成，绝对 <= 100%）
    const totalGenTokens = (stats.output ?? 0) + (stats.reasoning ?? 0);
    const thinkTokenRatio = totalGenTokens > 0 ? Math.round(((stats.reasoning ?? 0) / totalGenTokens) * 100) : 0;
    const outputTokenRatio = totalGenTokens > 0 ? Math.max(0, 100 - thinkTokenRatio) : 0;
    // 5. 首响应标注：单次还是平均
    const samples = stats.firstSamples ?? 0;
    const ttftAvg = samples > 0 ? ttftMs / samples : ttftMs;
    const ttftLabel = samples > 1
        ? `平均首响应 ${duration(ttftAvg)} (共 ${samples} 次)`
        : `首响应 ${duration(ttftMs)}`;
    // 6. 判断主要耗时瓶颈
    let bottleneck = '运行正常';
    if (combinedMs > 0) {
        if (bashMs > combinedMs * 0.4 && bashMs > 10000) {
            bottleneck = `终端命令占 ${Math.round((bashMs / combinedMs) * 100)}%`;
        }
        else if (thinkMs > combinedMs * 0.4 && thinkMs > 10000) {
            bottleneck = `深度思考占 ${Math.round((thinkMs / combinedMs) * 100)}%`;
        }
        else if (ttftMs > combinedMs * 0.4 && ttftMs > 8000) {
            bottleneck = `云端排队占 ${Math.round((ttftMs / combinedMs) * 100)}%`;
        }
        else if (modelTotalMs > toolTotalMs) {
            bottleneck = `模型处理占 ${Math.round(modelPct)}%`;
        }
        else {
            bottleneck = `工具执行占 ${Math.round(toolPct)}%`;
        }
    }
    // 7. 状态胶囊计算（是否有暗中重试或报错）
    const hasError = (stats.toolErrors ?? 0) > 0;
    const hasRetry = (stats.retries ?? 0) > 0;
    let statusText = '✓ 0 报错 · 0 重试 (稳定)';
    let statusClass = css.statusOk;
    if (hasError && hasRetry) {
        statusText = `! ${stats.toolErrors} 报错 · ${stats.retries} 次重试`;
        statusClass = css.statusDanger;
    }
    else if (hasError) {
        statusText = `! ${stats.toolErrors} 次工具报错`;
        statusClass = css.statusDanger;
    }
    else if (hasRetry) {
        statusText = `! ${stats.retries} 次网络重试排队`;
        statusClass = css.statusWarn;
    }
    const handleSliceHover = (slice, e) => {
        setHoverSlice(slice);
        if (chartBoxRef.current) {
            const rect = e.currentTarget.getBoundingClientRect();
            const parentRect = chartBoxRef.current.getBoundingClientRect();
            const sliceCenter = rect.left - parentRect.left + (rect.width / 2);
            // 适度舒展浮层宽度至 360px，充分利用父容器宽度，杜绝文字拥挤换行
            const popoverWidth = Math.min(360, Math.max(300, parentRect.width - 16));
            const left = Math.max(8, Math.min(parentRect.width - popoverWidth - 8, sliceCenter - (popoverWidth / 2)));
            setPopoverLeft(left);
            // 计算箭头在浮层内部的相对横坐标，确保无论浮层被边缘怎么限制，箭头都 100% 精确垂直对准切片中心
            const arrowPos = Math.max(16, Math.min(popoverWidth - 16, sliceCenter - left));
            setArrowLeft(arrowPos);
        }
    };
    return (_jsxs("div", { className: css.panelBox, children: [_jsxs("div", { className: css.topRow, children: [_jsxs("div", { className: css.titleArea, children: [_jsx("span", { className: css.mainTitle, children: "\u8017\u65F6\u5206\u5E03\u4E0E\u74F6\u9888" }), tokensPerSecond && tokensPerSecond > 0 ? (_jsxs("span", { className: css.liveSpeed, title: "\u5F53\u524D\u6A21\u578B\u5B9E\u9645\u6D41\u5F0F\u751F\u6210\u541E\u5410", children: [_jsx("i", { className: css.speedDot }), _jsxs("span", { children: [tokensPerSecond >= 10 ? Math.round(tokensPerSecond) : tokensPerSecond.toFixed(1), " t/s"] })] })) : null, _jsxs("span", { className: css.totalDuration, children: [scope === 'turn' ? '本轮' : '全会话', " \u8017\u65F6 ", duration(combinedMs)] })] }), _jsx("div", { className: css.bottleneckText, children: combinedMs > 0 ? `主要耗时：${bottleneck}` : '暂无耗时记录' })] }), _jsxs("div", { className: css.chartBox, ref: chartBoxRef, children: [_jsxs("div", { className: css.barTrack, role: "img", "aria-label": "\u8017\u65F6\u590D\u5408\u67F1\u56FE", children: [_jsxs("div", { className: css.modelCluster, style: { width: `${modelPct}%` }, children: [ttftSubPct > 0 ? (_jsx("div", { className: `${css.slice} ${css.sliceTtft}`, style: { width: `${ttftSubPct}%` }, onMouseEnter: e => handleSliceHover('ttft', e), onMouseLeave: () => setHoverSlice(null) })) : null, thinkSubPct > 0 ? (_jsx("div", { className: `${css.slice} ${css.sliceThink}`, style: { width: `${thinkSubPct}%` }, onMouseEnter: e => handleSliceHover('think', e), onMouseLeave: () => setHoverSlice(null) })) : null, outputSubPct > 0 ? (_jsx("div", { className: `${css.slice} ${css.sliceOutput}`, style: { width: `${outputSubPct}%` }, onMouseEnter: e => handleSliceHover('output', e), onMouseLeave: () => setHoverSlice(null) })) : null] }), _jsxs("div", { className: css.toolCluster, style: { width: `${toolPct}%` }, children: [bashSubPct > 0 ? (_jsx("div", { className: `${css.slice} ${css.sliceBash}`, style: { width: `${bashSubPct}%` }, onMouseEnter: e => handleSliceHover('bash', e), onMouseLeave: () => setHoverSlice(null) })) : null, fileSubPct > 0 ? (_jsx("div", { className: `${css.slice} ${css.sliceFile}`, style: { width: `${fileSubPct}%` }, onMouseEnter: e => handleSliceHover('file', e), onMouseLeave: () => setHoverSlice(null) })) : null] })] }), hoverSlice ? (_jsxs("div", { className: css.popover, style: {
                            left: `${popoverLeft}px`,
                            ['--arrow-left']: `${arrowLeft}px`,
                        }, children: [_jsxs("div", { className: css.popTitle, children: [_jsxs("span", { children: [hoverSlice === 'think' && '深度推导阶段 (思考过程)', hoverSlice === 'ttft' && '首字排队响应 (TTFT)', hoverSlice === 'output' && '正文流式输出阶段', hoverSlice === 'bash' && '本地终端命令 (Bash)', hoverSlice === 'file' && '文件读写与其它工具'] }), _jsxs("span", { children: [hoverSlice === 'think' && `${duration(thinkMs)} (${thinkSubPct}%)`, hoverSlice === 'ttft' && `${duration(ttftMs)} (${ttftSubPct}%)`, hoverSlice === 'output' && `${duration(outputMs)} (${outputSubPct}%)`, hoverSlice === 'bash' && `${duration(bashMs)} (${bashSubPct}%)`, hoverSlice === 'file' && `${duration(fileMs)} (${fileSubPct}%)`] })] }), _jsxs("div", { className: css.popList, children: [hoverSlice === 'think' && (_jsxs(_Fragment, { children: [_jsxs("div", { className: css.popRow, children: [_jsxs("div", { className: css.popLeft, children: [_jsx("i", { className: css.dot, style: { background: 'var(--c-think)' } }), _jsx("span", { children: "\u63A8\u5BFC\u601D\u8003\u603B\u8017\u65F6" })] }), _jsxs("span", { className: css.popRight, children: [duration(thinkMs), " (\u5360\u6A21\u578B ", thinkSubPct, "%)"] })] }), stats.reasoning ? (_jsxs("div", { className: css.popRow, children: [_jsx("div", { className: css.popLeft, children: _jsx("span", { children: "\u601D\u8003 Token \u7528\u91CF" }) }), _jsxs("span", { className: css.popRight, children: [fmtNum(stats.reasoning), " Token"] })] })) : null, _jsxs("div", { className: css.popRow, children: [_jsx("div", { className: css.popLeft, children: _jsx("span", { children: "\u751F\u6210\u7B97\u529B\u5206\u914D" }) }), _jsx("span", { className: css.popRight, children: totalGenTokens > 0
                                                            ? `思考占 ${thinkTokenRatio}% · 正文占 ${outputTokenRatio}%`
                                                            : '—' })] }), thinkMs > 0 && stats.reasoning ? (_jsxs("div", { className: css.popRow, children: [_jsx("div", { className: css.popLeft, children: _jsx("span", { children: "\u63A8\u5BFC\u751F\u6210\u901F\u7387" }) }), _jsxs("span", { className: css.popRight, children: [Math.round(stats.reasoning / (thinkMs / 1000)), " Token/\u79D2"] })] })) : null, _jsxs("div", { className: css.popRow, style: { borderTop: '1px dashed rgba(255,255,255,0.15)', marginTop: '4px', paddingTop: '4px' }, children: [_jsx("div", { className: css.popLeft, children: _jsx("span", { children: "\u601D\u8003\u8017\u65F6\u8BCA\u65AD" }) }), _jsx("span", { className: css.popRight, children: thinkMs > 25000 ? '推导耗时较长，任务较复杂' : '推导节奏健康，无卡顿停顿' })] })] })), hoverSlice === 'ttft' && (_jsxs(_Fragment, { children: [_jsxs("div", { className: css.popRow, children: [_jsxs("div", { className: css.popLeft, children: [_jsx("i", { className: css.dot, style: { background: 'var(--c-ttft)' } }), _jsx("span", { children: "\u9996\u54CD\u5E94\u6392\u961F\u5EF6\u8FDF" })] }), _jsxs("span", { className: css.popRight, children: [duration(ttftMs), " (\u5360\u6A21\u578B ", ttftSubPct, "%)"] })] }), _jsxs("div", { className: css.popRow, children: [_jsx("div", { className: css.popLeft, children: _jsx("span", { children: "\u91C7\u6837\u7EDF\u8BA1\u8BE6\u60C5" }) }), _jsx("span", { className: css.popRight, children: samples > 1 ? `累计 ${samples} 次 (均值 ${(ttftAvg / 1000).toFixed(2)}s)` : '单次握手' })] }), _jsxs("div", { className: css.popRow, style: { borderTop: '1px dashed rgba(255,255,255,0.15)', marginTop: '4px', paddingTop: '4px' }, children: [_jsx("div", { className: css.popLeft, children: _jsx("span", { children: "\u7F51\u7EDC\u6392\u961F\u8BCA\u65AD" }) }), _jsx("span", { className: css.popRight, children: ttftAvg < 1000
                                                            ? '极度敏捷 (网络与云端极速响应)'
                                                            : ttftAvg < 3000
                                                                ? '正常 (标准网络往返与握手)'
                                                                : '排队偏长 (云端并发高或网络延迟)' })] })] })), hoverSlice === 'output' && (_jsxs(_Fragment, { children: [_jsxs("div", { className: css.popRow, children: [_jsxs("div", { className: css.popLeft, children: [_jsx("i", { className: css.dot, style: { background: 'var(--c-output)' } }), _jsx("span", { children: "\u6B63\u6587\u4E0E\u4EE3\u7801\u8017\u65F6" })] }), _jsxs("span", { className: css.popRight, children: [duration(outputMs), " (\u5360\u6A21\u578B ", outputSubPct, "%)"] })] }), _jsxs("div", { className: css.popRow, children: [_jsx("div", { className: css.popLeft, children: _jsx("span", { children: "\u5B9E\u4ED8\u6B63\u6587\u8F93\u51FA\u91CF" }) }), _jsxs("span", { className: css.popRight, children: [fmtNum(stats.output), " Token"] })] }), _jsxs("div", { className: css.popRow, children: [_jsx("div", { className: css.popLeft, children: _jsx("span", { children: "\u5B9E\u9645\u751F\u6210\u901F\u7387" }) }), _jsx("span", { className: css.popRight, children: tokensPerSecond && tokensPerSecond > 0
                                                            ? `${tokensPerSecond >= 10 ? Math.round(tokensPerSecond) : tokensPerSecond.toFixed(1)} Token/秒 (实时)`
                                                            : outputMs > 0
                                                                ? `${Math.round(stats.output / (outputMs / 1000))} Token/秒 (均值)`
                                                                : '—' })] }), _jsxs("div", { className: css.popRow, style: { borderTop: '1px dashed rgba(255,255,255,0.15)', marginTop: '4px', paddingTop: '4px' }, children: [_jsx("div", { className: css.popLeft, children: _jsx("span", { children: "\u751F\u6210\u7B97\u529B\u5206\u914D" }) }), _jsx("span", { className: css.popRight, children: totalGenTokens > 0 ? `正文占 ${outputTokenRatio}% · 思考占 ${thinkTokenRatio}%` : '—' })] })] })), hoverSlice === 'bash' && (_jsxs(_Fragment, { children: [_jsxs("div", { className: css.popRow, children: [_jsxs("div", { className: css.popLeft, children: [_jsx("i", { className: css.dot, style: { background: 'var(--c-bash)' } }), _jsx("span", { children: "\u7EC8\u7AEF Bash \u603B\u8017\u65F6" })] }), _jsxs("span", { className: css.popRight, children: [duration(bashMs), " (\u5360\u5DE5\u5177 ", bashSubPct, "%)"] })] }), _jsxs("div", { className: css.popRow, children: [_jsx("div", { className: css.popLeft, children: _jsx("span", { children: "\u5360\u8F6E\u6B21\u603B\u65F6\u95F4\u6BD4" }) }), _jsx("span", { className: css.popRight, children: combinedMs > 0 ? `${Math.round((bashMs / combinedMs) * 100)}%` : '0%' })] }), _jsxs("div", { className: css.popRow, children: [_jsx("div", { className: css.popLeft, children: _jsx("span", { children: "\u547D\u4EE4\u53EF\u9760\u5EA6\u76D1\u63A7" }) }), _jsxs("span", { className: css.popRight, children: [stats.tools, " \u6B21 (", stats.toolErrors > 0 ? `${stats.toolErrors} 次报错中断` : '零非零退出码', ")"] })] }), _jsxs("div", { className: css.popRow, style: { borderTop: '1px dashed rgba(255,255,255,0.15)', marginTop: '4px', paddingTop: '4px' }, children: [_jsx("div", { className: css.popLeft, children: _jsx("span", { children: "\u8017\u65F6\u74F6\u9888\u5F52\u56E0" }) }), _jsx("span", { className: css.popRight, children: bashMs > modelTotalMs ? '本地环境为主要瓶颈 (耗时超模型)' : '本地开销极小 (主要耗时在云端)' })] })] })), hoverSlice === 'file' && (_jsxs(_Fragment, { children: [_jsxs("div", { className: css.popRow, children: [_jsxs("div", { className: css.popLeft, children: [_jsx("i", { className: css.dot, style: { background: 'var(--c-file)' } }), _jsx("span", { children: "\u6587\u4EF6\u8BFB\u5199\u603B\u8017\u65F6" })] }), _jsxs("span", { className: css.popRight, children: [duration(fileMs), " (\u5360\u5DE5\u5177 ", fileSubPct, "%)"] })] }), _jsxs("div", { className: css.popRow, children: [_jsx("div", { className: css.popLeft, children: _jsx("span", { children: "\u5360\u8F6E\u6B21\u603B\u65F6\u95F4\u6BD4" }) }), _jsx("span", { className: css.popRight, children: combinedMs > 0 ? `${Math.round((fileMs / combinedMs) * 100)}%` : '0%' })] }), _jsxs("div", { className: css.popRow, children: [_jsx("div", { className: css.popLeft, children: _jsx("span", { children: "\u5355\u6B21\u8C03\u7528\u5E73\u5747\u8017\u65F6" }) }), _jsxs("span", { className: css.popRight, children: [Math.round(fileMs / Math.max(1, stats.tools)), " ms / \u6B21"] })] }), _jsxs("div", { className: css.popRow, style: { borderTop: '1px dashed rgba(255,255,255,0.15)', marginTop: '4px', paddingTop: '4px' }, children: [_jsx("div", { className: css.popLeft, children: _jsx("span", { children: "\u6587\u4EF6 IO \u8BC4\u4EF7" }) }), _jsx("span", { className: css.popRight, children: fileMs < 2000 ? '毫秒级极速读写，无性能损耗' : '读写较为密集，轻微耗时累积' })] })] }))] })] })) : null] }), _jsxs("div", { className: css.legendRow, children: [_jsxs("div", { className: css.legendGroup, children: [_jsxs("span", { className: css.legendItem, children: [_jsx("i", { className: css.dot, style: { background: 'var(--c-ttft)' } }), _jsx("span", { children: ttftLabel })] }), _jsxs("span", { className: css.legendItem, children: [_jsx("i", { className: css.dot, style: { background: 'var(--c-think)' } }), _jsxs("span", { children: ["\u601D\u8003 ", duration(thinkMs)] })] }), _jsxs("span", { className: css.legendItem, children: [_jsx("i", { className: css.dot, style: { background: 'var(--c-output)' } }), _jsxs("span", { children: ["\u8F93\u51FA ", duration(outputMs)] })] }), _jsxs("span", { className: css.legendItem, children: [_jsx("i", { className: css.dot, style: { background: 'var(--c-bash)' } }), _jsxs("span", { children: ["\u5DE5\u5177 ", duration(toolTotalMs)] })] })] }), _jsx("div", { className: `${css.statusPill} ${statusClass}`, children: statusText })] })] }));
}
//# sourceMappingURL=TimingPanel.js.map