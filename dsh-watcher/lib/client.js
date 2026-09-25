window.__ModuleLoader__.load({
	id: "dsh-watcher",
	factory: (require) => {
		var module = { exports: {} };
		var exports = module.exports;
		(() => {
			if (typeof document === 'undefined') return;
			const id = 'dsh-watcher';
			let style = document.querySelector('style[data-plugin-css="' + id + '"]');
			if (style === null) {
				style = document.createElement('style');
				style.dataset.plugin = id;
				style.dataset.pluginCss = id;
				(document.head ?? document.documentElement).appendChild(style);
			}
			style.textContent = ".H9LxLa_root {\n  --watcher-panel-max-height: min(680px, calc(100vh - 112px));\n  --watcher-motion-fast: .14s;\n  --watcher-motion-panel: .18s;\n  --watcher-ease-out: cubic-bezier(.2, .8, .2, 1);\n  position: relative;\n}\n\n.H9LxLa_trigger {\n  box-sizing: border-box;\n  border: 1px solid var(--dsw-alias-border-l2);\n  width: 32px;\n  height: 32px;\n  color: var(--dsw-alias-label-primary);\n  cursor: pointer;\n  transition: background-color var(--watcher-motion-fast) ease,\n    border-color var(--watcher-motion-fast) ease,\n    color var(--watcher-motion-fast) ease,\n    transform .1s ease;\n  background: none;\n  border-radius: 999px;\n  justify-content: center;\n  align-items: center;\n  padding: 0;\n  display: inline-flex;\n}\n\n.H9LxLa_trigger:hover:not(:disabled), .H9LxLa_trigger:focus-visible {\n  background: var(--dsw-alias-interactive-bg-hover);\n}\n\n.H9LxLa_trigger:active {\n  transform: scale(.96);\n}\n\n.H9LxLa_trigger:focus-visible {\n  outline: 2px solid var(--dsw-static-deepseek-450);\n  outline-offset: 2px;\n}\n\n.H9LxLa_trigger[data-open] {\n  border-color: var(--dsw-alias-button-ghost-active-border);\n  background: var(--dsw-alias-button-ghost-active-fill);\n  color: var(--dsw-static-deepseek-450);\n}\n\n.H9LxLa_trigger[data-live] {\n  color: var(--dsw-static-deepseek-450);\n}\n\n.H9LxLa_trigger[data-alert] {\n  color: var(--dsw-alias-state-error-primary);\n}\n\n.H9LxLa_eye, .H9LxLa_eyeBlink, .H9LxLa_eyePupil {\n  transform-box: fill-box;\n  transform-origin: center;\n  display: block;\n}\n\n.H9LxLa_trigger[data-live] .H9LxLa_eyePupil {\n  animation: H9LxLa_watcher-eye-scan 2.8s var(--watcher-ease-out) infinite;\n}\n\n.H9LxLa_trigger[data-live] .H9LxLa_eyeBlink {\n  animation: 5.2s ease-in-out infinite H9LxLa_watcher-eye-blink;\n}\n\n@keyframes H9LxLa_watcher-eye-scan {\n  0%, 12%, 92%, 100% {\n    transform: translateX(0);\n  }\n\n  30% {\n    transform: translateX(1.35px);\n  }\n\n  54% {\n    transform: translateX(-1.2px);\n  }\n\n  74% {\n    transform: translateX(.8px);\n  }\n}\n\n@keyframes H9LxLa_watcher-eye-blink {\n  0%, 42%, 44.5%, 100% {\n    transform: scaleY(1);\n  }\n\n  43.2% {\n    transform: scaleY(.12);\n  }\n}\n\n.H9LxLa_menu {\n  z-index: 1100;\n  --watcher-panel-max-height: min(680px, calc(100vh - 24px));\n  --watcher-motion-fast: .14s;\n  --watcher-motion-panel: .18s;\n  --watcher-ease-out: cubic-bezier(.2, .8, .2, 1);\n  box-sizing: border-box;\n  max-width: calc(100vw - 24px);\n  max-height: var(--watcher-panel-max-height);\n  border: 1px solid var(--dsw-alias-border-l2);\n  background: var(--dsw-specific-menu);\n  box-shadow: var(--dsw-shadow-lv3);\n  color: var(--dsw-alias-label-primary);\n  font-family: var(--dsw-font-family);\n  transform-origin: 100% 0;\n  animation: H9LxLa_watcher-panel-enter var(--watcher-motion-panel) var(--watcher-ease-out);\n  isolation: isolate;\n  border-radius: 12px;\n  align-items: stretch;\n  font-size: 13px;\n  line-height: 20px;\n  display: flex;\n  position: fixed;\n  top: auto;\n  left: auto;\n  right: auto;\n  overflow: hidden;\n}\n\n@keyframes H9LxLa_watcher-panel-enter {\n  from {\n    opacity: 0;\n    transform: translateY(-5px) scale(.992);\n  }\n\n  to {\n    opacity: 1;\n    transform: translateY(0) scale(1);\n  }\n}\n\n.H9LxLa_workPicture {\n  width: min(720px, 100vw - 32px);\n  min-width: 0;\n  min-height: 290px;\n  max-height: var(--watcher-panel-max-height);\n  background: var(--dsw-specific-menu);\n  flex-direction: column;\n  flex: none;\n  display: flex;\n}\n\n.H9LxLa_pictureHeader {\n  border-bottom: 1px solid var(--dsw-alias-border-l2);\n  flex: none;\n  justify-content: space-between;\n  align-items: flex-start;\n  gap: 12px;\n  padding: 16px 14px 14px 16px;\n  display: flex;\n}\n\n.H9LxLa_nowBlock {\n  min-width: 0;\n}\n\n.H9LxLa_eyebrow {\n  color: var(--dsw-static-deepseek-450);\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  align-items: center;\n  gap: 5px;\n  font-size: 12px;\n  font-weight: 500;\n  line-height: 18px;\n  display: flex;\n  overflow: hidden;\n}\n\n.H9LxLa_eyebrow[data-alert] {\n  color: var(--dsw-alias-state-error-primary);\n}\n\n.H9LxLa_now {\n  color: var(--dsw-alias-label-primary);\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  margin-top: 2px;\n  font-size: 17px;\n  font-weight: 600;\n  line-height: 24px;\n  overflow: hidden;\n}\n\n.H9LxLa_summary {\n  color: var(--dsw-alias-label-tertiary);\n  font-variant-numeric: tabular-nums;\n  flex-wrap: wrap;\n  align-items: center;\n  margin-top: 4px;\n  font-size: 12px;\n  line-height: 18px;\n  display: flex;\n}\n\n.H9LxLa_summary span + span:before {\n  content: \"·\";\n  color: var(--dsw-alias-label-dimmed);\n  margin: 0 6px;\n}\n\n.H9LxLa_summary [data-partial] {\n  color: var(--dsw-alias-state-warn-primary);\n}\n\n.H9LxLa_loadAllInlineBtn {\n  background: var(--dsw-specific-menu);\n  color: var(--dsw-static-deepseek-450);\n  cursor: pointer;\n  border: 1px solid #4d6bfe66;\n  border-radius: 4px;\n  align-items: center;\n  margin-left: 6px;\n  padding: 1px 7px;\n  font-size: 11px;\n  font-weight: 500;\n  line-height: 16px;\n  transition: all .12s;\n  display: inline-flex;\n}\n\n.H9LxLa_loadAllInlineBtn:hover {\n  background: var(--dsw-static-deepseek-450);\n  color: #fff;\n}\n\n.H9LxLa_sessionTiming {\n  border-bottom: 1px solid var(--dsw-alias-border-l2);\n  background: var(--dsw-alias-bg-layer-2);\n  flex: none;\n  grid-template-columns: repeat(3, minmax(0, 1fr));\n  margin: 0;\n  padding: 9px 10px;\n  display: grid;\n}\n\n.H9LxLa_sessionTimingMetric {\n  min-width: 0;\n  padding: 0 8px;\n}\n\n.H9LxLa_sessionTimingMetric + .H9LxLa_sessionTimingMetric {\n  border-left: 1px solid var(--dsw-alias-border-l2);\n}\n\n.H9LxLa_sessionTimingMetric dt, .H9LxLa_sessionTimingMetric dd {\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  margin: 0;\n  overflow: hidden;\n}\n\n.H9LxLa_sessionTimingMetric dt {\n  color: var(--dsw-alias-label-tertiary);\n  font-size: 12px;\n  line-height: 18px;\n}\n\n.H9LxLa_sessionTimingMetric dd {\n  color: var(--dsw-alias-label-primary);\n  font-variant-numeric: tabular-nums;\n  font-size: 13px;\n  font-weight: 600;\n  line-height: 19px;\n}\n\n.H9LxLa_viewToolbar {\n  border-bottom: 1px solid var(--dsw-alias-border-l2);\n  background: var(--dsw-specific-menu);\n  flex-wrap: wrap;\n  flex: none;\n  justify-content: space-between;\n  align-items: center;\n  gap: 6px 14px;\n  min-height: 42px;\n  padding: 6px 14px;\n  display: flex;\n}\n\n.H9LxLa_viewControl {\n  align-items: center;\n  gap: 6px;\n  min-width: 0;\n  display: flex;\n}\n\n.H9LxLa_viewToolbarLabel {\n  color: var(--dsw-alias-label-tertiary);\n  white-space: nowrap;\n  font-size: 12px;\n  line-height: 18px;\n}\n\n.H9LxLa_viewMode {\n  border: 1px solid var(--dsw-alias-border-l2);\n  background: var(--dsw-alias-bg-layer-2);\n  border-radius: 7px;\n  flex: none;\n  grid-template-columns: repeat(2, minmax(42px, 1fr));\n  padding: 2px;\n  display: inline-grid;\n}\n\n.H9LxLa_viewMode button {\n  min-height: 26px;\n  color: var(--dsw-alias-label-secondary);\n  font: inherit;\n  cursor: pointer;\n  background: none;\n  border: 0;\n  border-radius: 5px;\n  padding: 2px 9px;\n  font-size: 12px;\n  line-height: 18px;\n}\n\n.H9LxLa_viewMode button:hover {\n  color: var(--dsw-alias-label-primary);\n}\n\n.H9LxLa_viewMode button[data-active] {\n  background: var(--dsw-specific-menu);\n  box-shadow: inset 0 0 0 1px var(--dsw-alias-border-l2);\n  color: var(--dsw-alias-label-primary);\n  font-weight: 600;\n}\n\n.H9LxLa_historyNotice {\n  border-bottom: 1px solid var(--dsw-alias-border-l2);\n  background: var(--dsw-alias-bg-layer-2);\n  flex: none;\n  align-items: center;\n  gap: 10px;\n  min-height: 48px;\n  padding: 7px 14px 8px 16px;\n  display: flex;\n}\n\n.H9LxLa_historyNoticeCopy {\n  flex-direction: column;\n  flex: 1;\n  min-width: 0;\n  display: flex;\n}\n\n.H9LxLa_historyNoticeCopy strong {\n  color: var(--dsw-alias-label-primary);\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  font-size: 12px;\n  font-weight: 600;\n  line-height: 18px;\n  overflow: hidden;\n}\n\n.H9LxLa_historyNoticeCopy span {\n  color: var(--dsw-alias-label-tertiary);\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  font-size: 11px;\n  line-height: 16px;\n  overflow: hidden;\n}\n\n.H9LxLa_historyNotice button {\n  border: 1px solid var(--dsw-alias-button-ghost-active-border);\n  background: var(--dsw-specific-menu);\n  min-height: 28px;\n  color: var(--dsw-alias-label-primary);\n  font: inherit;\n  cursor: pointer;\n  border-radius: 7px;\n  flex: none;\n  padding: 3px 9px;\n  font-size: 12px;\n  line-height: 18px;\n}\n\n.H9LxLa_historyNotice button:hover:not(:disabled) {\n  background: var(--dsw-alias-button-ghost-active-hover);\n}\n\n.H9LxLa_historyNotice button:disabled {\n  color: var(--dsw-alias-label-tertiary);\n  cursor: progress;\n}\n\n.H9LxLa_follow {\n  white-space: nowrap;\n  flex: none;\n  margin-top: 2px;\n}\n\n.H9LxLa_unread {\n  border: 1px solid var(--dsw-alias-button-ghost-active-border);\n  background: var(--dsw-alias-button-ghost-active-fill);\n  width: calc(100% - 28px);\n  min-height: 34px;\n  color: var(--dsw-alias-label-primary);\n  font: inherit;\n  cursor: pointer;\n  border-radius: 8px;\n  justify-content: center;\n  align-items: center;\n  gap: 6px;\n  margin: 10px 14px 0;\n  font-size: 12px;\n  display: inline-flex;\n}\n\n.H9LxLa_unread:hover {\n  background: var(--dsw-alias-button-ghost-active-hover);\n}\n\n.H9LxLa_unread:focus-visible, .H9LxLa_turnToggle:focus-visible, .H9LxLa_phaseToggle:focus-visible, .H9LxLa_stepToggle:focus-visible, .H9LxLa_analysisClusterToggle:focus-visible, .H9LxLa_modelStageToggle:focus-visible, .H9LxLa_reasoningToggle:focus-visible, .H9LxLa_groupedModelToggle:focus-visible, .H9LxLa_viewMode button:focus-visible, .H9LxLa_historyNotice button:focus-visible, .H9LxLa_overviewOccurrence:focus-visible, .H9LxLa_inspectorBack:focus-visible, .H9LxLa_occurrence:focus-visible, .H9LxLa_tab:focus-visible, .H9LxLa_copyRaw:focus-visible {\n  outline: 2px solid var(--dsw-static-deepseek-450);\n  outline-offset: -2px;\n}\n\n.H9LxLa_railViewport {\n  overscroll-behavior: contain;\n  --dsh-scrollbar-thumb: var(--dsw-alias-scrollbar-bg-l2);\n  --dsh-scrollbar-thumb-hover: var(--dsw-alias-scrollbar-hover-l2);\n  flex: 1;\n  min-height: 0;\n  overflow: auto;\n}\n\n.H9LxLa_turns {\n  padding: 8px 10px 18px;\n}\n\n.H9LxLa_turn + .H9LxLa_turn {\n  border-top: 1px solid var(--dsw-alias-border-l2);\n  margin-top: 12px;\n  padding-top: 12px;\n}\n\n.H9LxLa_turnHeader {\n  padding: 0 2px 2px;\n}\n\n.H9LxLa_turnHeader h2 {\n  margin: 0;\n}\n\n.H9LxLa_turnToggle {\n  box-sizing: border-box;\n  width: 100%;\n  min-height: 50px;\n  color: inherit;\n  font: inherit;\n  text-align: left;\n  cursor: pointer;\n  background: none;\n  border: 0;\n  border-radius: 8px;\n  grid-template-columns: 14px minmax(0, 1fr) auto;\n  align-items: center;\n  gap: 7px;\n  padding: 6px 8px;\n  display: grid;\n}\n\n.H9LxLa_turnToggle:hover {\n  background: var(--dsw-alias-interactive-bg-hover);\n}\n\n.H9LxLa_turnChevron {\n  color: var(--dsw-alias-label-tertiary);\n  transition: transform var(--watcher-motion-fast) var(--watcher-ease-out);\n  transform: rotate(0);\n}\n\n.H9LxLa_turnToggle[aria-expanded=\"true\"] .H9LxLa_turnChevron {\n  transform: rotate(90deg);\n}\n\n.H9LxLa_turnCopy {\n  flex-direction: column;\n  min-width: 0;\n  display: flex;\n}\n\n.H9LxLa_turnTitleLine {\n  align-items: center;\n  gap: 6px;\n  min-width: 0;\n  display: flex;\n}\n\n.H9LxLa_turnTitle {\n  color: var(--dsw-alias-label-secondary);\n  font-size: 13px;\n  font-weight: 600;\n  line-height: 20px;\n}\n\n.H9LxLa_turnSummary, .H9LxLa_turnDuration {\n  color: var(--dsw-alias-label-tertiary);\n  font-variant-numeric: tabular-nums;\n  font-size: 12px;\n  font-weight: 400;\n  line-height: 18px;\n}\n\n.H9LxLa_turnSummary {\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  overflow: hidden;\n}\n\n.H9LxLa_turnPerformance {\n  white-space: nowrap;\n  flex-direction: column;\n  align-items: flex-end;\n  min-width: 62px;\n  display: flex;\n}\n\n.H9LxLa_turnDuration {\n  white-space: nowrap;\n}\n\n.H9LxLa_turnSpeed {\n  color: var(--dsw-alias-label-secondary);\n  font-variant-numeric: tabular-nums;\n  font-size: 12px;\n  font-weight: 500;\n  line-height: 18px;\n}\n\n.H9LxLa_turnMetrics {\n  background: var(--dsw-alias-bg-layer-2);\n  border-radius: 7px;\n  grid-template-columns: repeat(3, minmax(0, 1fr));\n  gap: 10px;\n  margin: 2px 8px 9px 36px;\n  padding: 7px 9px;\n  display: grid;\n}\n\n.H9LxLa_turnMetric {\n  min-width: 0;\n}\n\n.H9LxLa_turnMetric dt, .H9LxLa_turnMetric dd {\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  margin: 0;\n  overflow: hidden;\n}\n\n.H9LxLa_turnMetric dt {\n  color: var(--dsw-alias-label-tertiary);\n  font-size: 12px;\n  line-height: 17px;\n}\n\n.H9LxLa_turnMetric dd {\n  color: var(--dsw-alias-label-primary);\n  font-variant-numeric: tabular-nums;\n  font-size: 13px;\n  font-weight: 600;\n  line-height: 19px;\n}\n\n.H9LxLa_turnBody[hidden] {\n  display: none;\n}\n\n.H9LxLa_groupRail {\n  padding-left: 18px;\n  position: relative;\n}\n\n.H9LxLa_railLine {\n  background: var(--dsw-alias-border-l2);\n  pointer-events: none;\n  width: 1px;\n  position: absolute;\n  top: 18px;\n  bottom: 18px;\n  left: 23px;\n}\n\n.H9LxLa_phase {\n  z-index: 1;\n  box-sizing: border-box;\n  width: 100%;\n  padding: 3px 0 11px;\n  position: relative;\n}\n\n.H9LxLa_phase + .H9LxLa_phase {\n  margin-top: 4px;\n}\n\n.H9LxLa_phaseHeader {\n  position: relative;\n}\n\n.H9LxLa_phaseToggle {\n  box-sizing: border-box;\n  width: 100%;\n  min-height: 42px;\n  color: inherit;\n  font: inherit;\n  text-align: left;\n  cursor: pointer;\n  background: none;\n  border: 0;\n  border-radius: 7px;\n  grid-template-columns: 10px 12px minmax(0, 1fr);\n  align-items: center;\n  gap: 6px;\n  padding: 3px 8px 3px 0;\n  display: grid;\n  position: relative;\n}\n\n.H9LxLa_phaseToggle:hover {\n  background: var(--dsw-alias-interactive-bg-hover);\n}\n\n.H9LxLa_phase[data-now] > .H9LxLa_phaseHeader .H9LxLa_phaseToggle {\n  background: var(--dsw-alias-bg-layer-2);\n  border-radius: 7px;\n}\n\n.H9LxLa_phaseChevron, .H9LxLa_stepChevron, .H9LxLa_analysisClusterChevron {\n  color: var(--dsw-alias-label-tertiary);\n  transition: transform var(--watcher-motion-fast) var(--watcher-ease-out);\n  transform: rotate(0);\n}\n\n.H9LxLa_phaseToggle[aria-expanded=\"true\"] .H9LxLa_phaseChevron, .H9LxLa_stepToggle[aria-expanded=\"true\"] .H9LxLa_stepChevron, .H9LxLa_analysisClusterToggle[aria-expanded=\"true\"] .H9LxLa_analysisClusterChevron {\n  transform: rotate(90deg);\n}\n\n.H9LxLa_phaseMarker {\n  box-sizing: border-box;\n  background: var(--dsw-alias-label-tertiary);\n  width: 10px;\n  height: 10px;\n  box-shadow: 0 0 0 4px var(--dsw-specific-menu);\n  border-radius: 50%;\n  display: block;\n  position: relative;\n}\n\n.H9LxLa_phaseMarker[data-state=\"active\"], .H9LxLa_phaseMarker[data-state=\"current\"] {\n  background: var(--dsw-static-deepseek-450);\n}\n\n.H9LxLa_phaseMarker[data-state=\"waiting\"] {\n  background: var(--dsw-alias-state-warn-primary);\n}\n\n.H9LxLa_phaseMarker[data-state=\"failure\"], .H9LxLa_phaseMarker[data-state=\"interrupted\"] {\n  background: var(--dsw-alias-state-error-primary);\n}\n\n.H9LxLa_phaseMarker[data-state=\"partial\"] {\n  border: 1px dashed var(--dsw-alias-label-tertiary);\n  background: var(--dsw-specific-menu);\n}\n\n.H9LxLa_neutralDot {\n  border: 1px solid var(--dsw-alias-label-tertiary);\n  background: var(--dsw-alias-label-tertiary);\n  border-radius: 50%;\n  flex: none;\n  width: 10px;\n  height: 10px;\n  display: inline-block;\n  position: relative;\n}\n\n.H9LxLa_neutralDot[data-status=\"unknown\"] {\n  background: var(--dsw-specific-menu);\n  border-style: dashed;\n}\n\n.H9LxLa_phaseCopy, .H9LxLa_occurrenceCopy {\n  flex-direction: column;\n  min-width: 0;\n  display: flex;\n}\n\n.H9LxLa_phaseTitleLine {\n  align-items: center;\n  gap: 6px;\n  min-width: 0;\n  display: flex;\n}\n\n.H9LxLa_phaseTitle {\n  min-width: 0;\n  color: var(--dsw-alias-label-primary);\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  font-size: 15px;\n  font-weight: 550;\n  line-height: 21px;\n  overflow: hidden;\n}\n\n.H9LxLa_phaseMeta {\n  color: var(--dsw-alias-label-tertiary);\n  font-variant-numeric: tabular-nums;\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  margin-top: 1px;\n  font-size: 12px;\n  line-height: 18px;\n  overflow: hidden;\n}\n\n.H9LxLa_groupBadges {\n  flex: none;\n  align-items: center;\n  gap: 4px;\n  display: inline-flex;\n}\n\n.H9LxLa_groupBadges span, .H9LxLa_overviewTag, .H9LxLa_patternLabel, .H9LxLa_parallelLabel {\n  border: 1px solid var(--dsw-alias-border-l2);\n  min-height: 18px;\n  color: var(--dsw-alias-label-tertiary);\n  font-variant-numeric: tabular-nums;\n  white-space: nowrap;\n  border-radius: 999px;\n  align-items: center;\n  padding: 0 5px;\n  font-size: 11px;\n  font-weight: 500;\n  line-height: 16px;\n  display: inline-flex;\n}\n\n.H9LxLa_groupBadges [data-kind=\"retry\"] {\n  color: var(--dsw-alias-state-error-primary);\n}\n\n.H9LxLa_groupBadges [data-kind=\"parallel\"], .H9LxLa_overviewTag[data-state=\"active\"], .H9LxLa_overviewTag[data-state=\"current\"] {\n  color: var(--dsw-static-deepseek-450);\n}\n\n.H9LxLa_overviewTag[data-state=\"waiting\"] {\n  color: var(--dsw-alias-state-warn-primary);\n}\n\n.H9LxLa_overviewTag[data-state=\"failure\"], .H9LxLa_overviewTag[data-state=\"interrupted\"] {\n  color: var(--dsw-alias-state-error-primary);\n}\n\n.H9LxLa_overviewTag[data-state=\"partial\"] {\n  color: var(--dsw-alias-label-tertiary);\n}\n\n.H9LxLa_occurrenceChevron {\n  color: var(--dsw-alias-label-dimmed);\n  opacity: 0;\n  transition: opacity var(--watcher-motion-fast) ease, transform var(--watcher-motion-fast) ease;\n  flex: none;\n  transform: translateX(-2px);\n}\n\n.H9LxLa_occurrence:hover .H9LxLa_occurrenceChevron, .H9LxLa_occurrence[data-selected] .H9LxLa_occurrenceChevron, .H9LxLa_occurrence:focus-visible .H9LxLa_occurrenceChevron {\n  opacity: 1;\n  transform: translateX(0);\n}\n\n.H9LxLa_stepTimeline {\n  border-left: 1px solid var(--dsw-alias-border-l2);\n  margin: 1px 8px 0 28px;\n  padding-left: 11px;\n  position: relative;\n}\n\n.H9LxLa_overviewStep {\n  min-width: 0;\n  position: relative;\n}\n\n.H9LxLa_overviewStep + .H9LxLa_overviewStep {\n  margin-top: 10px;\n  padding-top: 8px;\n}\n\n.H9LxLa_overviewStep:before {\n  background: var(--dsw-alias-border-l2);\n  content: \"\";\n  width: 8px;\n  height: 1px;\n  position: absolute;\n  top: 13px;\n  left: -12px;\n}\n\n.H9LxLa_overviewStepHeader {\n  min-height: 29px;\n}\n\n.H9LxLa_stepToggle {\n  box-sizing: border-box;\n  width: 100%;\n  min-height: 29px;\n  color: inherit;\n  font: inherit;\n  text-align: left;\n  cursor: pointer;\n  background: none;\n  border: 0;\n  border-radius: 6px;\n  grid-template-columns: 12px minmax(0, 1fr) auto;\n  align-items: center;\n  gap: 5px;\n  padding: 2px 4px 2px 0;\n  display: grid;\n}\n\n.H9LxLa_stepToggle:hover {\n  background: var(--dsw-alias-interactive-bg-hover);\n}\n\n.H9LxLa_overviewStepLabel, .H9LxLa_overviewStepSignals {\n  color: var(--dsw-alias-label-tertiary);\n  font-variant-numeric: tabular-nums;\n  font-size: 12px;\n  line-height: 18px;\n}\n\n.H9LxLa_overviewStepLabel {\n  min-width: 0;\n  font-family: var(--dsw-font-mono);\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  overflow: hidden;\n}\n\n.H9LxLa_overviewStepSignals {\n  white-space: nowrap;\n  align-items: center;\n  gap: 6px;\n  display: inline-flex;\n}\n\n.H9LxLa_overviewOccurrences {\n  position: relative;\n}\n\n.H9LxLa_overviewStep[data-parallel] .H9LxLa_overviewOccurrences {\n  border-left: 1px solid var(--dsw-static-deepseek-450);\n  padding-left: 5px;\n}\n\n.H9LxLa_modelStage {\n  border-left: 2px solid var(--dsw-static-deepseek-450);\n  background: var(--dsw-alias-bg-layer-2);\n  border-radius: 0 7px 7px 0;\n  min-width: 0;\n  margin: 2px 2px 7px;\n  overflow: hidden;\n}\n\n.H9LxLa_modelStage[data-live] {\n  box-shadow: inset 0 0 0 1px var(--dsw-alias-button-ghost-active-border);\n}\n\n.H9LxLa_modelStageToggle {\n  box-sizing: border-box;\n  width: 100%;\n  min-height: 42px;\n  color: inherit;\n  font: inherit;\n  text-align: left;\n  cursor: pointer;\n  background: none;\n  border: 0;\n  grid-template-columns: 12px 8px minmax(0, 1fr);\n  align-items: center;\n  gap: 7px;\n  padding: 5px 9px 5px 7px;\n  display: grid;\n}\n\n.H9LxLa_modelStageToggle:hover, .H9LxLa_reasoningToggle:hover, .H9LxLa_groupedModelToggle:hover {\n  background: var(--dsw-alias-interactive-bg-hover);\n}\n\n.H9LxLa_modelStageChevron, .H9LxLa_reasoningChevron, .H9LxLa_groupedModelChevron {\n  color: var(--dsw-alias-label-tertiary);\n  transition: transform var(--watcher-motion-fast) var(--watcher-ease-out);\n}\n\n.H9LxLa_modelStageToggle[aria-expanded=\"true\"] .H9LxLa_modelStageChevron, .H9LxLa_reasoningToggle[aria-expanded=\"true\"] .H9LxLa_reasoningChevron, .H9LxLa_groupedModelToggle[aria-expanded=\"true\"] .H9LxLa_groupedModelChevron {\n  transform: rotate(90deg);\n}\n\n.H9LxLa_modelStageGlyph {\n  background: var(--dsw-static-deepseek-450);\n  width: 7px;\n  height: 7px;\n  box-shadow: 0 0 0 3px var(--dsw-alias-button-ghost-active-fill);\n  border-radius: 999px;\n}\n\n.H9LxLa_modelStageCopy {\n  grid-template-columns: auto minmax(0, 1fr);\n  align-items: baseline;\n  gap: 8px;\n  min-width: 0;\n  display: grid;\n}\n\n.H9LxLa_modelStageTitle {\n  color: var(--dsw-alias-label-primary);\n  white-space: nowrap;\n  font-size: 13px;\n  font-weight: 600;\n  line-height: 20px;\n}\n\n.H9LxLa_modelStageSummary {\n  color: var(--dsw-alias-label-tertiary);\n  font-variant-numeric: tabular-nums;\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  font-size: 12px;\n  line-height: 18px;\n  overflow: hidden;\n}\n\n.H9LxLa_modelStageBody {\n  padding: 2px 10px 10px 20px;\n}\n\n.H9LxLa_modelStageBar {\n  background: var(--dsw-alias-border-l2);\n  border-radius: 999px;\n  gap: 2px;\n  height: 5px;\n  margin: 2px 0 10px;\n  display: flex;\n  overflow: hidden;\n}\n\n.H9LxLa_modelStageBar > span {\n  border-radius: inherit;\n  min-width: 3px;\n}\n\n.H9LxLa_modelStageBar [data-segment=\"wait\"], .H9LxLa_modelStageSwatch[data-segment=\"wait\"] {\n  background: var(--dsw-alias-label-dimmed);\n}\n\n.H9LxLa_modelStageBar [data-segment=\"reasoning\"], .H9LxLa_modelStageSwatch[data-segment=\"reasoning\"] {\n  background: var(--dsw-static-deepseek-450);\n}\n\n.H9LxLa_modelStageBar [data-segment=\"output\"], .H9LxLa_modelStageSwatch[data-segment=\"output\"] {\n  background: var(--dsw-alias-label-secondary);\n}\n\n.H9LxLa_modelStageBar [data-segment=\"unattributed\"], .H9LxLa_modelStageSwatch[data-segment=\"unattributed\"] {\n  background: var(--dsw-alias-state-warn-primary);\n}\n\n.H9LxLa_modelStageLedger {\n  grid-template-columns: minmax(0, 1fr);\n  gap: 5px 12px;\n  margin: 0;\n  display: grid;\n}\n\n.H9LxLa_modelStageMetric {\n  min-width: 0;\n  color: var(--dsw-alias-label-tertiary);\n  font-variant-numeric: tabular-nums;\n  justify-content: space-between;\n  align-items: center;\n  gap: 8px;\n  font-size: 12px;\n  line-height: 18px;\n  display: flex;\n}\n\n.H9LxLa_modelStageMetric dt, .H9LxLa_modelStageMetric dd {\n  margin: 0;\n}\n\n.H9LxLa_modelStageMetric dt {\n  align-items: center;\n  gap: 6px;\n  min-width: 0;\n  display: inline-flex;\n}\n\n.H9LxLa_modelStageMetric dd {\n  color: var(--dsw-alias-label-secondary);\n  text-align: right;\n  flex: none;\n}\n\n.H9LxLa_modelStageSwatch {\n  border-radius: 999px;\n  flex: none;\n  width: 6px;\n  height: 6px;\n}\n\n.H9LxLa_modelStageNote {\n  color: var(--dsw-alias-label-tertiary);\n  margin: 8px 0 0;\n  font-size: 12px;\n  line-height: 18px;\n}\n\n.H9LxLa_reasoningAttempts {\n  border-top: 1px solid var(--dsw-alias-border-l2);\n  margin-top: 8px;\n  padding-top: 1px;\n}\n\n.H9LxLa_reasoningDisclosure {\n  border: 1px solid var(--dsw-alias-border-l2);\n  background: var(--dsw-alias-bg-layer-1);\n  border-radius: 6px;\n  min-width: 0;\n  margin-top: 5px;\n  overflow: hidden;\n}\n\n.H9LxLa_reasoningToggle {\n  box-sizing: border-box;\n  width: 100%;\n  min-height: 34px;\n  color: inherit;\n  font: inherit;\n  text-align: left;\n  cursor: pointer;\n  background: none;\n  border: 0;\n  grid-template-columns: 12px minmax(0, 1fr);\n  align-items: center;\n  gap: 6px;\n  padding: 5px 8px;\n  display: grid;\n}\n\n.H9LxLa_reasoningLabel {\n  color: var(--dsw-alias-label-primary);\n  font-size: 13px;\n  font-weight: 550;\n  line-height: 20px;\n}\n\n.H9LxLa_reasoningMeta {\n  color: var(--dsw-alias-label-tertiary);\n  font-variant-numeric: tabular-nums;\n  text-align: left;\n  white-space: normal;\n  grid-column: 2;\n  font-size: 12px;\n  line-height: 18px;\n  overflow: hidden;\n}\n\n.H9LxLa_reasoningBody {\n  box-sizing: border-box;\n  border-top: 1px solid var(--dsw-alias-border-l2);\n  background: var(--dsw-alias-markdown-code-block);\n  max-height: 320px;\n  color: var(--dsw-alias-label-primary);\n  overflow-wrap: anywhere;\n  --dsh-scrollbar-thumb: var(--dsw-alias-scrollbar-bg-l2);\n  --dsh-scrollbar-thumb-hover: var(--dsw-alias-scrollbar-hover-l2);\n  margin: 0;\n  padding: 10px 12px;\n  font-size: 13px;\n  line-height: 1.6;\n  overflow: auto;\n}\n\n.H9LxLa_reasoningBody > * {\n  margin-top: 0;\n  margin-bottom: 8px;\n}\n\n.H9LxLa_reasoningBody > :last-child {\n  margin-bottom: 0;\n}\n\n.H9LxLa_reasoningBody .md-code-block {\n  max-width: 100%;\n}\n\n.H9LxLa_groupedModelStages {\n  border: 1px solid var(--dsw-alias-border-l2);\n  background: var(--dsw-alias-bg-layer-2);\n  border-radius: 7px;\n  margin-bottom: 9px;\n  position: relative;\n  overflow: hidden;\n}\n\n.H9LxLa_groupedModelStages:before {\n  background: var(--dsw-alias-border-l2);\n  content: \"\";\n  width: 8px;\n  height: 1px;\n  position: absolute;\n  top: 20px;\n  left: -12px;\n}\n\n.H9LxLa_groupedModelToggle {\n  box-sizing: border-box;\n  width: 100%;\n  min-height: 44px;\n  color: inherit;\n  font: inherit;\n  text-align: left;\n  cursor: pointer;\n  background: none;\n  border: 0;\n  grid-template-columns: 12px minmax(0, 1fr);\n  align-items: center;\n  gap: 7px;\n  padding: 5px 9px;\n  display: grid;\n}\n\n.H9LxLa_groupedModelToggle > span {\n  justify-content: space-between;\n  align-items: baseline;\n  gap: 10px;\n  min-width: 0;\n  display: flex;\n}\n\n.H9LxLa_groupedModelToggle strong {\n  color: var(--dsw-alias-label-primary);\n  font-size: 13px;\n  line-height: 20px;\n}\n\n.H9LxLa_groupedModelToggle small {\n  color: var(--dsw-alias-label-tertiary);\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  font-size: 12px;\n  line-height: 18px;\n  overflow: hidden;\n}\n\n.H9LxLa_groupedModelList {\n  border-top: 1px solid var(--dsw-alias-border-l2);\n  padding: 0 7px 8px 22px;\n}\n\n.H9LxLa_groupedModelStep {\n  min-width: 0;\n  padding-top: 8px;\n}\n\n.H9LxLa_groupedModelStep + .H9LxLa_groupedModelStep {\n  border-top: 1px solid var(--dsw-alias-border-l2);\n}\n\n.H9LxLa_groupedModelStepLabel {\n  color: var(--dsw-alias-label-tertiary);\n  font-family: var(--dsw-font-mono);\n  margin: 0 2px 4px;\n  font-size: 12px;\n  line-height: 18px;\n  display: block;\n}\n\n.H9LxLa_analysisClusters {\n  border-left: 1px solid var(--dsw-alias-border-l2);\n  margin: 1px 8px 0 28px;\n  padding-left: 11px;\n  position: relative;\n}\n\n.H9LxLa_analysisCluster, .H9LxLa_analysisSingleton {\n  min-width: 0;\n  position: relative;\n}\n\n.H9LxLa_analysisCluster + .H9LxLa_analysisCluster, .H9LxLa_analysisCluster + .H9LxLa_analysisSingleton, .H9LxLa_analysisSingleton + .H9LxLa_analysisCluster, .H9LxLa_analysisSingleton + .H9LxLa_analysisSingleton {\n  margin-top: 6px;\n}\n\n.H9LxLa_analysisCluster:before, .H9LxLa_analysisSingleton:before {\n  background: var(--dsw-alias-border-l2);\n  content: \"\";\n  width: 8px;\n  height: 1px;\n  position: absolute;\n  top: 20px;\n  left: -12px;\n}\n\n.H9LxLa_analysisClusterToggle {\n  box-sizing: border-box;\n  width: 100%;\n  min-height: 46px;\n  color: inherit;\n  font: inherit;\n  text-align: left;\n  cursor: pointer;\n  background: none;\n  border: 1px solid #0000;\n  border-radius: 7px;\n  grid-template-columns: 12px 10px minmax(0, 1fr) auto;\n  align-items: center;\n  gap: 7px;\n  padding: 5px 6px 5px 4px;\n  display: grid;\n}\n\n.H9LxLa_analysisClusterToggle:hover {\n  background: var(--dsw-alias-interactive-bg-hover);\n}\n\n.H9LxLa_analysisCluster[data-open] > .H9LxLa_analysisClusterToggle {\n  border-color: var(--dsw-alias-border-l2);\n  background: var(--dsw-alias-bg-layer-2);\n}\n\n.H9LxLa_analysisClusterDotSlot {\n  width: 10px;\n  height: 10px;\n  display: block;\n  position: relative;\n}\n\n.H9LxLa_analysisClusterDot {\n  inset: 0;\n  position: absolute !important;\n}\n\n.H9LxLa_analysisClusterCopy {\n  flex-direction: column;\n  min-width: 0;\n  display: flex;\n}\n\n.H9LxLa_analysisClusterTitle {\n  color: var(--dsw-alias-label-primary);\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  font-size: 14px;\n  font-weight: 550;\n  line-height: 20px;\n  overflow: hidden;\n}\n\n.H9LxLa_analysisClusterMeta {\n  color: var(--dsw-alias-label-tertiary);\n  font-variant-numeric: tabular-nums;\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  font-size: 12px;\n  line-height: 18px;\n  overflow: hidden;\n}\n\n.H9LxLa_analysisClusterCount {\n  min-width: 28px;\n  color: var(--dsw-alias-label-secondary);\n  font-variant-numeric: tabular-nums;\n  text-align: right;\n  white-space: nowrap;\n  font-size: 12px;\n  font-weight: 600;\n  line-height: 18px;\n}\n\n.H9LxLa_analysisClusterItems {\n  border-left: 1px solid var(--dsw-alias-border-l2);\n  margin: 3px 0 8px 17px;\n  padding-left: 5px;\n}\n\n.H9LxLa_overviewOccurrence {\n  box-sizing: border-box;\n  width: 100%;\n  min-height: 45px;\n  color: inherit;\n  font: inherit;\n  text-align: left;\n  cursor: pointer;\n  transition: background-color var(--watcher-motion-fast) var(--watcher-ease-out),\n    border-color var(--watcher-motion-fast) var(--watcher-ease-out),\n    box-shadow var(--watcher-motion-fast) var(--watcher-ease-out);\n  animation: H9LxLa_watcher-live-append var(--watcher-motion-fast) var(--watcher-ease-out);\n  background: none;\n  border: 1px solid #0000;\n  border-radius: 7px;\n  grid-template-columns: 22px 10px minmax(0, 1fr) auto 12px;\n  align-items: center;\n  gap: 7px;\n  padding: 5px 5px 5px 7px;\n  display: grid;\n  position: relative;\n}\n\n.H9LxLa_overviewOccurrence + .H9LxLa_overviewOccurrence {\n  margin-top: 2px;\n}\n\n.H9LxLa_overviewOccurrence:hover {\n  background: var(--dsw-alias-interactive-bg-hover);\n}\n\n.H9LxLa_overviewOccurrence[data-current]:not([data-selected]) {\n  background: var(--dsw-alias-bg-layer-2);\n}\n\n.H9LxLa_overviewOccurrence[data-selected] {\n  border-color: var(--dsw-alias-button-ghost-active-border);\n  background: var(--dsw-alias-button-ghost-active-fill);\n  box-shadow: inset 2px 0 0 var(--dsw-static-deepseek-450);\n}\n\n.H9LxLa_overviewOccurrenceIndex {\n  color: var(--dsw-alias-label-dimmed);\n  font-family: var(--dsw-font-mono);\n  font-variant-numeric: tabular-nums;\n  text-align: right;\n  font-size: 11px;\n  line-height: 18px;\n}\n\n.H9LxLa_overviewOccurrenceDotSlot {\n  width: 10px;\n  height: 10px;\n  display: block;\n  position: relative;\n}\n\n.H9LxLa_overviewOccurrenceDot {\n  inset: 0;\n  position: absolute !important;\n}\n\n.H9LxLa_overviewOccurrenceCopy {\n  flex-direction: column;\n  min-width: 0;\n  display: flex;\n}\n\n.H9LxLa_overviewOccurrenceTitle {\n  color: var(--dsw-alias-label-primary);\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  font-size: 14px;\n  font-weight: 550;\n  line-height: 20px;\n  overflow: hidden;\n}\n\n.H9LxLa_overviewOccurrenceMeta {\n  color: var(--dsw-alias-label-tertiary);\n  font-family: var(--dsw-font-mono);\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  font-size: 12px;\n  line-height: 18px;\n  overflow: hidden;\n}\n\n.H9LxLa_overviewOccurrenceDuration {\n  color: var(--dsw-alias-label-tertiary);\n  font-variant-numeric: tabular-nums;\n  white-space: nowrap;\n  font-size: 12px;\n  line-height: 18px;\n}\n\n.H9LxLa_overviewOccurrenceChevron {\n  color: var(--dsw-alias-label-dimmed);\n  opacity: 0;\n  transition: opacity var(--watcher-motion-fast) ease, transform var(--watcher-motion-fast) ease;\n  transform: translateX(-2px);\n}\n\n.H9LxLa_overviewOccurrence:hover .H9LxLa_overviewOccurrenceChevron, .H9LxLa_overviewOccurrence[data-selected] .H9LxLa_overviewOccurrenceChevron, .H9LxLa_overviewOccurrence:focus-visible .H9LxLa_overviewOccurrenceChevron {\n  opacity: 1;\n  transform: translateX(0);\n}\n\n@keyframes H9LxLa_watcher-live-append {\n  from {\n    opacity: .5;\n    transform: translateY(-2px);\n  }\n\n  to {\n    opacity: 1;\n    transform: translateY(0);\n  }\n}\n\n.H9LxLa_empty {\n  min-height: 250px;\n  color: var(--dsw-alias-label-tertiary);\n  text-align: center;\n  flex-direction: column;\n  flex: 1;\n  justify-content: center;\n  align-items: center;\n  padding: 28px;\n  display: flex;\n}\n\n.H9LxLa_emptyEye {\n  color: var(--dsw-alias-label-secondary);\n  margin-bottom: 12px;\n  display: inline-flex;\n}\n\n.H9LxLa_empty strong {\n  color: var(--dsw-alias-label-secondary);\n  font-size: 14px;\n  font-weight: 600;\n  line-height: 21px;\n}\n\n.H9LxLa_empty > span:last-child {\n  margin-top: 4px;\n  font-size: 12px;\n  line-height: 18px;\n}\n\n.H9LxLa_inspector {\n  width: 438px;\n  min-width: 0;\n  max-height: var(--watcher-panel-max-height);\n  border-right: 1px solid var(--dsw-alias-border-l2);\n  background: var(--dsw-alias-bg-layer-1);\n  flex-direction: column;\n  flex: none;\n  display: flex;\n}\n\n.H9LxLa_inspectorHeader {\n  border-bottom: 1px solid var(--dsw-alias-border-l2);\n  flex: none;\n  padding: 16px 16px 14px;\n}\n\n.H9LxLa_inspectorBack {\n  min-height: 28px;\n  color: var(--dsw-alias-label-secondary);\n  font: inherit;\n  cursor: pointer;\n  background: none;\n  border: 0;\n  border-radius: 6px;\n  align-items: center;\n  gap: 5px;\n  margin: -4px 0 8px -6px;\n  padding: 0 7px 0 5px;\n  font-size: 12px;\n  display: none;\n}\n\n.H9LxLa_inspectorBack:hover {\n  background: var(--dsw-alias-interactive-bg-hover);\n}\n\n.H9LxLa_inspectorBack svg {\n  transform: rotate(180deg);\n}\n\n.H9LxLa_statusLine, .H9LxLa_detailStatus {\n  color: var(--dsw-alias-label-secondary);\n  align-items: center;\n  gap: 7px;\n  font-size: 12px;\n  line-height: 18px;\n  display: flex;\n}\n\n.H9LxLa_statusLine[data-status=\"failure\"], .H9LxLa_statusLine[data-status=\"interrupted\"], .H9LxLa_detailStatus[data-status=\"failure\"], .H9LxLa_detailStatus[data-status=\"interrupted\"] {\n  color: var(--dsw-alias-state-error-primary);\n}\n\n.H9LxLa_statusLine[data-status=\"running\"], .H9LxLa_detailStatus[data-status=\"running\"] {\n  color: var(--dsw-static-deepseek-450);\n}\n\n.H9LxLa_statusLine[data-status=\"waiting\"], .H9LxLa_detailStatus[data-status=\"waiting\"] {\n  color: var(--dsw-alias-state-warn-primary);\n}\n\n.H9LxLa_location {\n  color: var(--dsw-alias-label-tertiary);\n  font-variant-numeric: tabular-nums;\n  margin-left: auto;\n}\n\n.H9LxLa_inspectorTitle {\n  color: var(--dsw-alias-label-primary);\n  margin: 8px 0 0;\n  font-size: 18px;\n  font-weight: 600;\n  line-height: 25px;\n}\n\n.H9LxLa_inspectorSummary {\n  color: var(--dsw-alias-label-tertiary);\n  margin: 3px 0 0;\n  font-size: 12px;\n  line-height: 18px;\n}\n\n.H9LxLa_groupSignals {\n  flex-wrap: wrap;\n  gap: 6px;\n  margin-top: 10px;\n  display: flex;\n}\n\n.H9LxLa_groupSignals span {\n  color: var(--dsw-alias-label-tertiary);\n  font-variant-numeric: tabular-nums;\n  font-size: 12px;\n}\n\n.H9LxLa_groupSignals span + span:before {\n  content: \"·\";\n  color: var(--dsw-alias-label-dimmed);\n  margin-right: 6px;\n}\n\n.H9LxLa_groupSignals [data-retry] {\n  color: var(--dsw-alias-state-warn-primary);\n}\n\n.H9LxLa_groupSignals [data-error] {\n  color: var(--dsw-alias-state-error-primary);\n}\n\n.H9LxLa_inspectorBody {\n  overscroll-behavior: contain;\n  --dsh-scrollbar-thumb: var(--dsw-alias-scrollbar-bg-l2);\n  --dsh-scrollbar-thumb-hover: var(--dsw-alias-scrollbar-hover-l2);\n  flex: 1;\n  min-height: 0;\n  overflow: auto;\n}\n\n.H9LxLa_executionSection {\n  border-bottom: 1px solid var(--dsw-alias-border-l2);\n  padding: 14px 16px 16px;\n}\n\n.H9LxLa_sectionHeading {\n  justify-content: space-between;\n  align-items: center;\n  gap: 12px;\n  margin-bottom: 8px;\n  display: flex;\n}\n\n.H9LxLa_sectionHeading h3 {\n  color: var(--dsw-alias-label-secondary);\n  margin: 0;\n  font-size: 13px;\n  font-weight: 600;\n  line-height: 20px;\n}\n\n.H9LxLa_sectionHeading > span {\n  color: var(--dsw-alias-label-tertiary);\n  font-variant-numeric: tabular-nums;\n  font-size: 12px;\n}\n\n.H9LxLa_executionList {\n  max-height: 188px;\n  padding-right: 2px;\n  overflow: auto;\n}\n\n.H9LxLa_stepBlock + .H9LxLa_stepBlock {\n  border-top: 1px solid var(--dsw-alias-border-l2);\n  margin-top: 10px;\n  padding-top: 10px;\n}\n\n.H9LxLa_stepHeading {\n  min-height: 22px;\n  color: var(--dsw-alias-label-tertiary);\n  font-family: var(--dsw-font-mono);\n  font-variant-numeric: tabular-nums;\n  justify-content: space-between;\n  align-items: center;\n  gap: 8px;\n  padding: 0 3px;\n  font-size: 12px;\n  display: flex;\n}\n\n.H9LxLa_stepSignals {\n  align-items: center;\n  gap: 6px;\n  min-width: 0;\n  display: inline-flex;\n}\n\n.H9LxLa_stepDuration {\n  color: var(--dsw-alias-label-secondary);\n  font-family: var(--dsw-font-family);\n  font-variant-numeric: tabular-nums;\n  white-space: nowrap;\n}\n\n.H9LxLa_parallelLabel {\n  color: var(--dsw-static-deepseek-450);\n  font-family: var(--dsw-font-family);\n}\n\n.H9LxLa_occurrences {\n  margin-top: 4px;\n  position: relative;\n}\n\n.H9LxLa_stepBlock[data-parallel] .H9LxLa_occurrences {\n  border-left: 1px solid var(--dsw-static-deepseek-450);\n  padding-left: 10px;\n}\n\n.H9LxLa_occurrence {\n  box-sizing: border-box;\n  width: 100%;\n  min-height: 46px;\n  color: inherit;\n  font: inherit;\n  text-align: left;\n  cursor: pointer;\n  background: none;\n  border: 1px solid #0000;\n  border-radius: 8px;\n  grid-template-columns: 10px minmax(0, 1fr) auto 13px;\n  align-items: center;\n  gap: 8px;\n  padding: 6px 7px;\n  transition: background-color .14s, border-color .14s;\n  display: grid;\n}\n\n.H9LxLa_occurrenceDuration {\n  color: var(--dsw-alias-label-tertiary);\n  font-variant-numeric: tabular-nums;\n  white-space: nowrap;\n  font-size: 12px;\n  line-height: 18px;\n}\n\n.H9LxLa_occurrence + .H9LxLa_occurrence {\n  margin-top: 2px;\n}\n\n.H9LxLa_occurrence:hover {\n  background: var(--dsw-alias-interactive-bg-hover);\n}\n\n.H9LxLa_occurrence[data-selected] {\n  border-color: var(--dsw-alias-button-ghost-active-border);\n  background: var(--dsw-alias-button-ghost-active-fill);\n}\n\n.H9LxLa_occurrenceTitle {\n  color: var(--dsw-alias-label-primary);\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  font-size: 13px;\n  font-weight: 550;\n  line-height: 19px;\n  overflow: hidden;\n}\n\n.H9LxLa_occurrenceMeta {\n  color: var(--dsw-alias-label-tertiary);\n  font-family: var(--dsw-font-mono);\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  font-size: 12px;\n  line-height: 18px;\n  overflow: hidden;\n}\n\n.H9LxLa_detailSection {\n  padding: 16px;\n}\n\n.H9LxLa_detailHeader {\n  grid-template-columns: minmax(0, 1fr) auto;\n  align-items: start;\n  gap: 14px;\n  display: grid;\n}\n\n.H9LxLa_detailIdentity {\n  min-width: 0;\n}\n\n.H9LxLa_detailIdentity h3 {\n  overflow-wrap: anywhere;\n  color: var(--dsw-alias-label-primary);\n  margin: 6px 0 0;\n  font-size: 16px;\n  font-weight: 600;\n  line-height: 23px;\n}\n\n.H9LxLa_detailIdentity p {\n  overflow-wrap: anywhere;\n  color: var(--dsw-alias-label-tertiary);\n  font-family: var(--dsw-font-mono);\n  margin: 3px 0 0;\n  font-size: 12px;\n  line-height: 18px;\n}\n\n.H9LxLa_patternLabel {\n  color: var(--dsw-alias-state-warn-primary);\n}\n\n.H9LxLa_metrics {\n  font-variant-numeric: tabular-nums;\n  grid-template-columns: auto auto;\n  gap: 2px 8px;\n  margin: 0;\n  font-size: 12px;\n  line-height: 18px;\n  display: grid;\n}\n\n.H9LxLa_metrics dt {\n  color: var(--dsw-alias-label-tertiary);\n}\n\n.H9LxLa_metrics dd {\n  color: var(--dsw-alias-label-secondary);\n  text-align: right;\n  margin: 0;\n}\n\n.H9LxLa_metrics [data-error] {\n  color: var(--dsw-alias-state-error-primary);\n}\n\n.H9LxLa_tabs {\n  border-bottom: 1px solid var(--dsw-alias-border-l2);\n  align-items: end;\n  gap: 4px;\n  margin-top: 16px;\n  display: flex;\n}\n\n.H9LxLa_tab {\n  min-width: 56px;\n  min-height: 36px;\n  color: var(--dsw-alias-label-tertiary);\n  font: inherit;\n  cursor: pointer;\n  background: none;\n  border: 0;\n  padding: 0 10px;\n  font-size: 13px;\n  position: relative;\n}\n\n.H9LxLa_tab:hover {\n  color: var(--dsw-alias-label-primary);\n}\n\n.H9LxLa_tab[data-active] {\n  color: var(--dsw-alias-label-primary);\n  font-weight: 600;\n}\n\n.H9LxLa_tab[data-active]:after {\n  content: \"\";\n  background: var(--dsw-static-deepseek-450);\n  border-radius: 2px 2px 0 0;\n  height: 2px;\n  position: absolute;\n  bottom: -1px;\n  left: 9px;\n  right: 9px;\n}\n\n.H9LxLa_tabPanel {\n  --dsl-terminal-font: 400 13px/22px var(--dsw-font-mono);\n  min-height: 116px;\n  padding-top: 12px;\n}\n\n.H9LxLa_tabPanel > * {\n  margin-top: 0;\n  margin-bottom: 0;\n}\n\n.H9LxLa_jsonSurface {\n  font-size: 13px;\n  overflow: auto;\n}\n\n.H9LxLa_jsonSurface [role=\"tree\"] {\n  font-size: 13px;\n  line-height: 20px;\n}\n\n.H9LxLa_rawPanel pre {\n  box-sizing: border-box;\n  width: 100%;\n  color: var(--dsw-alias-label-primary);\n  font-family: var(--dsw-font-mono);\n  tab-size: 2;\n  margin: 0;\n  font-size: 13px;\n  line-height: 20px;\n  overflow: auto;\n}\n\n.H9LxLa_documentResult {\n  min-width: 0;\n  color: var(--dsw-alias-label-primary);\n  padding: 2px 2px 8px;\n}\n\n.H9LxLa_documentResult .md-code-block {\n  max-width: 100%;\n}\n\n.H9LxLa_documentResult blockquote {\n  color: var(--dsw-alias-label-secondary);\n}\n\n.H9LxLa_documentResult table {\n  font-variant-numeric: tabular-nums;\n}\n\n.H9LxLa_rawPanel {\n  border: 1px solid var(--dsw-alias-border-l2);\n  background: var(--dsw-alias-markdown-code-block);\n  border-radius: 8px;\n  overflow: hidden;\n}\n\n.H9LxLa_rawToolbar {\n  border-bottom: 1px solid var(--dsw-alias-border-l2);\n  min-height: 38px;\n  color: var(--dsw-alias-label-tertiary);\n  justify-content: space-between;\n  align-items: center;\n  gap: 12px;\n  padding: 0 10px 0 12px;\n  font-size: 12px;\n  display: flex;\n}\n\n.H9LxLa_copyRaw {\n  min-height: 28px;\n  color: var(--dsw-alias-label-secondary);\n  font: inherit;\n  cursor: pointer;\n  background: none;\n  border: 0;\n  border-radius: 6px;\n  align-items: center;\n  gap: 5px;\n  padding: 0 6px;\n  font-size: 12px;\n  display: inline-flex;\n}\n\n.H9LxLa_copyRaw:hover {\n  background: var(--dsw-alias-interactive-bg-hover);\n}\n\n.H9LxLa_rawPanel pre {\n  white-space: pre;\n  max-height: 320px;\n  padding: 12px;\n}\n\n.H9LxLa_artifactResult, .H9LxLa_detailEmpty {\n  border: 1px solid var(--dsw-alias-border-l2);\n  min-height: 116px;\n  color: var(--dsw-alias-label-tertiary);\n  text-align: center;\n  border-radius: 8px;\n  flex-direction: column;\n  justify-content: center;\n  align-items: center;\n  padding: 18px;\n  font-size: 13px;\n  display: flex;\n}\n\n.H9LxLa_artifactResult strong {\n  color: var(--dsw-alias-label-secondary);\n  margin-top: 6px;\n  font-size: 14px;\n}\n\n.H9LxLa_artifactResult > span {\n  margin-top: 2px;\n  font-size: 12px;\n}\n\n.H9LxLa_artifactResult .H9LxLa_jsonSurface {\n  text-align: left;\n  width: 100%;\n  margin-top: 12px;\n}\n\n.H9LxLa_artifactGlyph {\n  color: var(--dsw-static-deepseek-450);\n  font-size: 24px;\n  line-height: 28px;\n}\n\n.H9LxLa_inspectorFooter {\n  border-top: 1px solid var(--dsw-alias-border-l2);\n  color: var(--dsw-alias-label-tertiary);\n  flex: none;\n  padding: 9px 16px;\n  font-size: 12px;\n  line-height: 18px;\n}\n\n@media (prefers-reduced-motion: reduce) {\n  .H9LxLa_menu, .H9LxLa_trigger[data-live] .H9LxLa_eyePupil, .H9LxLa_trigger[data-live] .H9LxLa_eyeBlink {\n    animation: none;\n  }\n\n  .H9LxLa_trigger, .H9LxLa_overviewOccurrence, .H9LxLa_turnChevron, .H9LxLa_phaseChevron, .H9LxLa_stepChevron, .H9LxLa_analysisClusterChevron, .H9LxLa_modelStageChevron, .H9LxLa_reasoningChevron, .H9LxLa_groupedModelChevron, .H9LxLa_occurrence, .H9LxLa_overviewOccurrenceChevron, .H9LxLa_occurrenceChevron {\n    transition-duration: .01ms;\n  }\n\n  .H9LxLa_overviewOccurrence {\n    animation: none;\n  }\n\n  .H9LxLa_root [data-state=\"ongoing\"] rect, .H9LxLa_menu [data-state=\"ongoing\"] rect {\n    opacity: .55;\n    animation: none !important;\n  }\n}\n\n@media (width <= 860px) {\n  .H9LxLa_menu {\n    flex-direction: column-reverse;\n    width: min(720px, 100vw - 24px);\n    max-height: calc(100vh - 88px);\n  }\n\n  .H9LxLa_workPicture {\n    width: auto;\n    min-height: 250px;\n    max-height: none;\n  }\n\n  .H9LxLa_menu:not(:has(.H9LxLa_inspector)) {\n    height: min(680px, 100vh - 88px);\n  }\n\n  .H9LxLa_menu:not(:has(.H9LxLa_inspector)) .H9LxLa_workPicture {\n    flex: auto;\n  }\n\n  .H9LxLa_inspector {\n    border-right: 0;\n    width: auto;\n    max-height: none;\n  }\n\n  .H9LxLa_menu:has(.H9LxLa_inspector) {\n    height: min(680px, 100vh - 88px);\n  }\n\n  .H9LxLa_menu:has(.H9LxLa_inspector) .H9LxLa_workPicture {\n    display: none;\n  }\n\n  .H9LxLa_menu:has(.H9LxLa_inspector) .H9LxLa_inspector {\n    flex: auto;\n    min-height: 0;\n    max-height: none;\n  }\n\n  .H9LxLa_inspectorBack {\n    display: inline-flex;\n  }\n\n  .H9LxLa_inspectorHeader {\n    padding-top: 14px;\n  }\n\n  .H9LxLa_executionList {\n    max-height: 150px;\n  }\n}\n\n@media (width <= 520px) {\n  .H9LxLa_menu {\n    width: calc(100vw - 24px);\n  }\n\n  .H9LxLa_pictureHeader {\n    padding: 14px 12px;\n  }\n\n  .H9LxLa_now {\n    font-size: 16px;\n  }\n\n  .H9LxLa_turns {\n    padding-inline: 6px;\n  }\n\n  .H9LxLa_groupBadges span:nth-child(n+2) {\n    display: none;\n  }\n\n  .H9LxLa_inspectorHeader, .H9LxLa_executionSection, .H9LxLa_detailSection {\n    padding-inline: 12px;\n  }\n\n  .H9LxLa_detailHeader {\n    grid-template-columns: 1fr;\n  }\n\n  .H9LxLa_metrics {\n    grid-template-columns: auto 1fr;\n  }\n\n  .H9LxLa_metrics dd {\n    text-align: left;\n  }\n\n  .H9LxLa_modelStageCopy {\n    grid-template-columns: 1fr;\n    gap: 0;\n  }\n\n  .H9LxLa_modelStageSummary {\n    white-space: normal;\n  }\n\n  .H9LxLa_modelStageLedger {\n    grid-template-columns: 1fr;\n  }\n\n  .H9LxLa_reasoningToggle {\n    grid-template-columns: 12px minmax(0, 1fr);\n  }\n\n  .H9LxLa_reasoningMeta {\n    text-align: left;\n    white-space: normal;\n    grid-column: 2;\n  }\n\n  .H9LxLa_groupedModelToggle > span {\n    gap: 0;\n    display: grid;\n  }\n\n  .H9LxLa_groupedModelToggle small {\n    white-space: normal;\n  }\n\n  .H9LxLa_groupedModelList {\n    padding-left: 12px;\n  }\n}\n.kI5sgq_hudBox {\n  box-sizing: border-box;\n  border-bottom: 1px solid var(--dsw-alias-border-l2);\n  background: var(--dsw-specific-menu);\n  width: 100%;\n  font-family: var(--dsw-font-family);\n  flex: none;\n}\n\n.kI5sgq_hudTop {\n  background: var(--dsw-alias-bg-layer-2);\n  border-bottom: 1px solid var(--dsw-alias-border-l2);\n  flex-wrap: nowrap;\n  justify-content: space-between;\n  align-items: center;\n  gap: 12px;\n  padding: 8px 14px;\n  display: flex;\n}\n\n.kI5sgq_hudTopLeft {\n  flex-wrap: nowrap;\n  align-items: center;\n  gap: 8px;\n  min-width: 0;\n  display: flex;\n}\n\n.kI5sgq_hudHeading {\n  color: var(--dsw-alias-label-secondary);\n  white-space: nowrap;\n  font-size: 11px;\n  font-weight: 600;\n}\n\n.kI5sgq_currentModelTag {\n  background: var(--dsw-alias-interactive-bg-hover);\n  white-space: nowrap;\n  border-radius: 4px;\n  flex-shrink: 1;\n  align-items: center;\n  gap: 5px;\n  min-width: 0;\n  max-width: 100%;\n  padding: 1px 6px;\n  font-size: 11px;\n  display: inline-flex;\n}\n\n.kI5sgq_modelTagText {\n  color: var(--dsw-alias-label-primary);\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  min-width: 0;\n  font-weight: 600;\n  overflow: hidden;\n}\n\n.kI5sgq_effortTag {\n  color: var(--dsw-static-deepseek-450, #5686fe);\n  white-space: nowrap;\n  background: #5686fe1f;\n  border-radius: 3px;\n  flex-shrink: 0;\n  padding: 0 5px;\n  font-size: 10px;\n  font-weight: 600;\n  line-height: 14px;\n}\n\n.kI5sgq_contextTag {\n  color: var(--dsw-alias-label-secondary, #5f636d);\n  background: var(--dsw-alias-bg-layer-1, #fff);\n  border: 1px solid var(--dsw-alias-border-l2, #e2e8f0);\n  font-variant-numeric: tabular-nums;\n  white-space: nowrap;\n  border-radius: 4px;\n  flex-shrink: 0;\n  padding: 1px 7px;\n  font-size: 11px;\n}\n\n.kI5sgq_hudTopRight {\n  flex-shrink: 0;\n  align-items: center;\n  gap: 10px;\n  display: flex;\n}\n\n.kI5sgq_tokenStat {\n  color: var(--dsw-alias-label-secondary);\n  font-variant-numeric: tabular-nums;\n  white-space: nowrap;\n  font-size: 11px;\n}\n\n.kI5sgq_tokenStat strong {\n  color: var(--dsw-alias-label-primary);\n}\n\n.kI5sgq_scopeGroup {\n  border: 1px solid var(--dsw-alias-border-l2);\n  background: var(--dsw-alias-bg-layer-1);\n  border-radius: 5px;\n  gap: 1px;\n  padding: 1px;\n  display: inline-flex;\n}\n\n.kI5sgq_scopeBtn {\n  color: var(--dsw-alias-label-tertiary);\n  cursor: pointer;\n  white-space: nowrap;\n  background: none;\n  border: 0;\n  border-radius: 3px;\n  padding: 2px 7px;\n  font-size: 11px;\n  line-height: 14px;\n  transition: all .12s;\n}\n\n.kI5sgq_scopeBtn[data-active] {\n  background: var(--dsw-specific-menu);\n  color: var(--dsw-alias-label-primary);\n  box-shadow: var(--dsw-shadow-lv1);\n  font-weight: 600;\n}\n\n.kI5sgq_modelTabBar {\n  background: var(--dsw-alias-bg-layer-1);\n  border-bottom: 1px solid var(--dsw-alias-border-l2);\n  gap: 4px;\n  padding: 6px 14px;\n  display: flex;\n  overflow-x: auto;\n}\n\n.kI5sgq_modelTabBtn {\n  border: 1px solid var(--dsw-alias-border-l2);\n  background: var(--dsw-specific-menu);\n  color: var(--dsw-alias-label-secondary);\n  cursor: pointer;\n  white-space: nowrap;\n  border-radius: 4px;\n  padding: 2px 8px;\n  font-size: 11px;\n  transition: all .12s;\n}\n\n.kI5sgq_modelTabBtn[data-active] {\n  background: var(--dsw-static-deepseek-450, #5686fe);\n  color: #fff;\n  border-color: var(--dsw-static-deepseek-450, #5686fe);\n  font-weight: 600;\n}\n\n.kI5sgq_hudBody {\n  padding: 10px 14px;\n}\n\n.kI5sgq_alertSection {\n  flex-direction: column;\n  gap: 6px;\n  margin-top: 8px;\n  display: flex;\n}\n\n.kI5sgq_alertCard {\n  border-radius: 6px;\n  justify-content: space-between;\n  align-items: center;\n  gap: 8px;\n  padding: 8px 10px;\n  display: flex;\n}\n\n.kI5sgq_alertCardDanger {\n  background: #e5484d14;\n  border: 1px solid #e5484d40;\n}\n\n.kI5sgq_alertCardWarn {\n  background: #f59e0b14;\n  border: 1px solid #f59e0b40;\n}\n\n.kI5sgq_alertLeft {\n  align-items: center;\n  gap: 8px;\n  min-width: 0;\n  display: flex;\n}\n\n.kI5sgq_alertTag {\n  color: #fff;\n  border-radius: 3px;\n  flex: none;\n  padding: 1px 5px;\n  font-size: 10px;\n  font-weight: 600;\n}\n\n.kI5sgq_tagDanger {\n  background: var(--dsw-alias-state-error-primary, #e5484d);\n}\n\n.kI5sgq_tagWarn {\n  background: #f59e0b;\n}\n\n.kI5sgq_alertTexts {\n  flex-direction: column;\n  min-width: 0;\n  display: flex;\n}\n\n.kI5sgq_alertMainText {\n  color: var(--dsw-alias-label-primary);\n  font-size: 12px;\n  font-weight: 600;\n}\n\n.kI5sgq_alertSubText {\n  color: var(--dsw-alias-label-secondary);\n  font-size: 11px;\n}\n\n.kI5sgq_alertActionBtn {\n  color: var(--dsw-static-deepseek-450, #5686fe);\n  cursor: pointer;\n  white-space: nowrap;\n  background: none;\n  border: none;\n  padding: 2px 6px;\n  font-size: 11px;\n  font-weight: 600;\n}\n\n.kI5sgq_settingsContainer {\n  width: 100%;\n  min-width: 0;\n  max-width: 100%;\n  color: var(--dsw-alias-label-primary);\n  box-sizing: border-box;\n  flex-direction: column;\n  gap: 14px;\n  padding: 0 0 24px;\n  display: flex;\n  overflow-x: hidden;\n}\n\n.kI5sgq_cockpitHeader {\n  flex-wrap: wrap;\n  justify-content: space-between;\n  align-items: flex-end;\n  gap: 10px;\n  display: flex;\n}\n\n.kI5sgq_cockpitTitleArea h2 {\n  color: var(--dsw-alias-label-primary);\n  letter-spacing: -.3px;\n  margin: 0;\n  font-size: 17px;\n  font-weight: 700;\n}\n\n.kI5sgq_cockpitSubTitle {\n  color: var(--dsw-alias-label-tertiary);\n  margin: 3px 0 0;\n  font-size: 12px;\n}\n\n.kI5sgq_headerRightControls {\n  align-items: center;\n  gap: 8px;\n  display: flex;\n}\n\n.kI5sgq_rangeSwitchGroup {\n  background: var(--dsw-alias-bg-layer-2);\n  border: 1px solid var(--dsw-alias-border-l2);\n  border-radius: 6px;\n  padding: 2px;\n  display: flex;\n}\n\n.kI5sgq_rangeBtn {\n  color: var(--dsw-alias-label-secondary);\n  cursor: pointer;\n  background: none;\n  border: none;\n  border-radius: 4px;\n  padding: 3px 10px;\n  font-size: 11px;\n  font-weight: 600;\n  transition: all .12s;\n}\n\n.kI5sgq_rangeBtn[data-active] {\n  background: var(--dsw-specific-menu);\n  color: var(--dsw-alias-label-primary);\n  box-shadow: var(--dsw-shadow-lv1);\n}\n\n.kI5sgq_settingsScanBtn {\n  border: 1px solid var(--dsw-alias-border-l2);\n  background: var(--dsw-alias-bg-layer-1);\n  color: var(--dsw-alias-label-primary);\n  cursor: pointer;\n  border-radius: 6px;\n  padding: 4px 10px;\n  font-size: 11px;\n  font-weight: 500;\n  transition: all .12s;\n}\n\n.kI5sgq_heroStatsRow {\n  border-bottom: 1px solid var(--dsw-alias-border-l2);\n  flex-wrap: wrap;\n  justify-content: space-between;\n  align-items: baseline;\n  gap: 10px;\n  padding-bottom: 10px;\n  display: flex;\n}\n\n.kI5sgq_heroBigNum {\n  letter-spacing: -.5px;\n  color: var(--dsw-alias-label-primary);\n  font-variant-numeric: tabular-nums;\n  align-items: baseline;\n  gap: 6px;\n  font-size: 26px;\n  font-weight: 800;\n  display: flex;\n}\n\n.kI5sgq_heroUnit {\n  color: var(--dsw-alias-label-secondary);\n  font-size: 13px;\n  font-weight: 500;\n}\n\n.kI5sgq_heroMetaCol {\n  color: var(--dsw-alias-label-secondary);\n  white-space: nowrap;\n  flex-wrap: nowrap;\n  gap: 14px;\n  font-size: 12px;\n  display: flex;\n}\n\n.kI5sgq_heroMetaCol strong {\n  color: var(--dsw-alias-label-primary);\n}\n\n.kI5sgq_roastGrid {\n  box-sizing: border-box;\n  grid-template-columns: repeat(2, minmax(0, 1fr));\n  gap: 10px;\n  width: 100%;\n  display: grid;\n}\n\n@media (width <= 440px) {\n  .kI5sgq_roastGrid {\n    grid-template-columns: 1fr;\n  }\n}\n\n.kI5sgq_roastItem {\n  background: var(--dsw-specific-menu);\n  border: 1px solid var(--dsw-alias-border-l2);\n  min-height: 136px;\n  box-shadow: var(--dsw-shadow-lv1);\n  cursor: pointer;\n  user-select: none;\n  box-sizing: border-box;\n  border-radius: 8px;\n  flex-direction: column;\n  justify-content: space-between;\n  padding: 12px 14px;\n  transition: all .12s;\n  display: flex;\n}\n\n.kI5sgq_roastItem:hover {\n  background: var(--dsw-alias-bg-layer-2);\n  border-color: var(--dsw-alias-border-l3);\n  transform: translateY(-1px);\n}\n\n.kI5sgq_roastItemActive {\n  background: var(--dsw-alias-bg-layer-2);\n  box-shadow: 0 0 0 1px var(--dsw-static-deepseek-450, #5686fe);\n  border-color: var(--dsw-static-deepseek-450, #5686fe) !important;\n}\n\n.kI5sgq_roastHead {\n  justify-content: space-between;\n  align-items: center;\n  margin-bottom: 4px;\n  display: flex;\n}\n\n.kI5sgq_roastTag {\n  letter-spacing: .3px;\n  font-size: 11px;\n  font-weight: 700;\n}\n\n.kI5sgq_roastCategoryBadge {\n  color: var(--dsw-alias-label-tertiary);\n  background: var(--dsw-alias-bg-layer-2);\n  border: 1px solid var(--dsw-alias-border-l1, #0000000f);\n  border-radius: 3px;\n  padding: 1px 4px;\n  font-size: 9px;\n  line-height: 1.2;\n}\n\n.kI5sgq_roastTitle {\n  color: var(--dsw-alias-label-primary);\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  font-size: 13px;\n  font-weight: 700;\n  line-height: 18px;\n  overflow: hidden;\n}\n\n.kI5sgq_roastDesc {\n  color: var(--dsw-alias-label-tertiary);\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  margin-top: 2px;\n  font-size: 10px;\n  line-height: 15px;\n  overflow: hidden;\n}\n\n.kI5sgq_roastVal {\n  font-variant-numeric: tabular-nums;\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  margin-top: 6px;\n  font-size: 12px;\n  font-weight: 700;\n  overflow: hidden;\n}\n\n.kI5sgq_roastFooter {\n  border-top: 1px dashed var(--dsw-alias-border-l2);\n  color: var(--dsw-alias-label-tertiary);\n  justify-content: space-between;\n  align-items: center;\n  margin-top: 10px;\n  padding-top: 8px;\n  font-size: 10px;\n  line-height: 1;\n  display: flex;\n}\n\n.kI5sgq_roastFooterLeft {\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  max-width: 110px;\n  overflow: hidden;\n}\n\n.kI5sgq_roastAction {\n  color: var(--dsw-alias-label-secondary);\n  flex-shrink: 0;\n  font-weight: 600;\n  transition: color .12s;\n}\n\n.kI5sgq_roastItem:hover .kI5sgq_roastAction, .kI5sgq_roastItemActive .kI5sgq_roastAction {\n  color: var(--dsw-static-deepseek-450, #5686fe);\n}\n\n.kI5sgq_drilldownPanel {\n  background: var(--dsw-specific-menu);\n  border: 1px solid var(--dsw-static-deepseek-450, #5686fe);\n  box-shadow: var(--dsw-shadow-lv2, 0 4px 12px #00000014);\n  border-radius: 10px;\n  flex-direction: column;\n  gap: 12px;\n  min-width: 0;\n  padding: 14px 16px;\n  animation: .15s ease-out kI5sgq_slideDown;\n  display: flex;\n}\n\n@keyframes kI5sgq_slideDown {\n  from {\n    opacity: 0;\n    transform: translateY(-4px);\n  }\n\n  to {\n    opacity: 1;\n    transform: translateY(0);\n  }\n}\n\n.kI5sgq_drilldownHead {\n  border-bottom: 1px solid var(--dsw-alias-border-l2);\n  justify-content: space-between;\n  align-items: center;\n  gap: 12px;\n  min-width: 0;\n  padding-bottom: 8px;\n  display: flex;\n}\n\n.kI5sgq_drilldownTitleGroup {\n  flex-direction: column;\n  flex: 1;\n  gap: 2px;\n  min-width: 0;\n  display: flex;\n}\n\n.kI5sgq_drilldownTitle {\n  color: var(--dsw-alias-label-primary);\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  font-size: 13px;\n  font-weight: 700;\n  overflow: hidden;\n}\n\n.kI5sgq_drilldownSub {\n  color: var(--dsw-alias-label-tertiary);\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  font-size: 11px;\n  overflow: hidden;\n}\n\n.kI5sgq_drilldownCloseBtn {\n  border: 1px solid var(--dsw-alias-border-l2);\n  color: var(--dsw-alias-label-secondary);\n  cursor: pointer;\n  background: none;\n  border-radius: 4px;\n  flex-shrink: 0;\n  padding: 3px 8px;\n  font-size: 11px;\n  transition: all .12s;\n}\n\n.kI5sgq_drilldownCloseBtn:hover {\n  background: var(--dsw-alias-bg-layer-2);\n  color: var(--dsw-alias-label-primary);\n  border-color: var(--dsw-alias-border-l3);\n}\n\n.kI5sgq_drilldownEmpty {\n  text-align: center;\n  color: var(--dsw-alias-label-tertiary);\n  padding: 16px;\n  font-size: 12px;\n}\n\n.kI5sgq_rankList {\n  flex-direction: column;\n  gap: 8px;\n  display: flex;\n}\n\n.kI5sgq_rankItem {\n  background: var(--dsw-alias-bg-layer-2);\n  border: 1px solid var(--dsw-alias-border-l1, #0000000f);\n  border-radius: 6px;\n  flex-direction: column;\n  gap: 6px;\n  min-width: 0;\n  padding: 8px 12px;\n  display: flex;\n}\n\n.kI5sgq_rankItemTop {\n  justify-content: space-between;\n  align-items: center;\n  gap: 8px;\n  min-width: 0;\n  display: flex;\n}\n\n.kI5sgq_rankItemLeft {\n  flex: 1;\n  align-items: center;\n  gap: 8px;\n  min-width: 0;\n  display: flex;\n}\n\n.kI5sgq_rankBadge {\n  color: var(--dsw-alias-label-secondary);\n  background: var(--dsw-specific-menu);\n  border: 1px solid var(--dsw-alias-border-l2);\n  font-variant-numeric: tabular-nums;\n  border-radius: 3px;\n  flex-shrink: 0;\n  padding: 1px 5px;\n  font-size: 10px;\n  font-weight: 700;\n  line-height: 1.2;\n}\n\n.kI5sgq_rankBadgeGold {\n  color: #d97706;\n  background: #f59e0b1f;\n  border-color: #f59e0b66;\n}\n\n.kI5sgq_rankName {\n  color: var(--dsw-alias-label-primary);\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  font-size: 12px;\n  font-weight: 600;\n  overflow: hidden;\n}\n\n.kI5sgq_rankValMain {\n  color: var(--dsw-alias-label-primary);\n  font-variant-numeric: tabular-nums;\n  white-space: nowrap;\n  flex-shrink: 0;\n  font-size: 12px;\n  font-weight: 700;\n}\n\n.kI5sgq_rankTrack {\n  background: var(--dsw-specific-menu);\n  border-radius: 3px;\n  width: 100%;\n  height: 6px;\n  overflow: hidden;\n}\n\n.kI5sgq_rankBar {\n  border-radius: 3px;\n  height: 100%;\n  transition: width .2s;\n}\n\n.kI5sgq_rankSubText {\n  color: var(--dsw-alias-label-tertiary);\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  justify-content: space-between;\n  align-items: center;\n  gap: 8px;\n  font-size: 10px;\n  line-height: 1.2;\n  display: flex;\n  overflow: hidden;\n}\n\n.kI5sgq_rankSubText strong {\n  color: var(--dsw-alias-label-primary);\n}\n\n.kI5sgq_toolDrillSection {\n  flex-direction: column;\n  gap: 12px;\n  min-width: 0;\n  display: flex;\n}\n\n.kI5sgq_toolCompoundBox {\n  flex-direction: column;\n  gap: 6px;\n  display: flex;\n}\n\n.kI5sgq_toolCompoundTrack {\n  background: var(--dsw-alias-bg-layer-2);\n  border-radius: 4px;\n  gap: 1px;\n  height: 10px;\n  display: flex;\n  overflow: hidden;\n}\n\n.kI5sgq_toolSliceBash {\n  background: var(--dsw-static-green-500, #10b981);\n  height: 100%;\n}\n\n.kI5sgq_toolSliceFile {\n  background: #0ea5e9;\n  height: 100%;\n}\n\n.kI5sgq_toolCompoundLegend {\n  color: var(--dsw-alias-label-secondary);\n  flex-wrap: wrap;\n  gap: 16px;\n  font-size: 11px;\n  display: flex;\n}\n\n.kI5sgq_toolCompoundLegend span {\n  align-items: center;\n  gap: 6px;\n  display: flex;\n}\n\n.kI5sgq_toolCompoundLegend strong {\n  color: var(--dsw-alias-label-primary);\n}\n\n.kI5sgq_toolGridCards {\n  grid-template-columns: 1fr 1fr;\n  gap: 10px;\n  display: grid;\n}\n\n@media (width <= 600px) {\n  .kI5sgq_toolGridCards {\n    grid-template-columns: 1fr;\n  }\n}\n\n.kI5sgq_toolMiniCard {\n  background: var(--dsw-alias-bg-layer-2);\n  border: 1px solid var(--dsw-alias-border-l2);\n  border-radius: 6px;\n  flex-direction: column;\n  gap: 4px;\n  min-width: 0;\n  padding: 10px 12px;\n  display: flex;\n}\n\n.kI5sgq_toolMiniTitle {\n  color: var(--dsw-alias-label-primary);\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  align-items: center;\n  gap: 6px;\n  font-size: 11px;\n  font-weight: 600;\n  display: flex;\n  overflow: hidden;\n}\n\n.kI5sgq_toolMiniNum {\n  color: var(--dsw-alias-label-primary);\n  font-variant-numeric: tabular-nums;\n  margin: 2px 0;\n  font-size: 15px;\n  font-weight: 700;\n}\n\n.kI5sgq_toolMiniDesc {\n  color: var(--dsw-alias-label-tertiary);\n  font-size: 10px;\n  line-height: 14px;\n}\n\n.kI5sgq_toolTopList {\n  border-top: 1px dashed var(--dsw-alias-border-l2);\n  flex-direction: column;\n  gap: 6px;\n  padding-top: 8px;\n  display: flex;\n}\n\n.kI5sgq_toolTopListTitle {\n  color: var(--dsw-alias-label-secondary);\n  margin-bottom: 2px;\n  font-size: 11px;\n  font-weight: 600;\n}\n\n.kI5sgq_errorDrillSection {\n  flex-direction: column;\n  gap: 8px;\n  display: flex;\n}\n\n.kI5sgq_errorAllGoodBox {\n  color: var(--dsw-static-green-500, #10b981);\n  text-align: center;\n  background: #10b98114;\n  border: 1px solid #10b9814d;\n  border-radius: 6px;\n  padding: 16px;\n  font-size: 12px;\n  font-weight: 600;\n}\n\n.kI5sgq_errorSessionList {\n  flex-direction: column;\n  gap: 6px;\n  display: flex;\n}\n\n.kI5sgq_errorSessionRow {\n  background: var(--dsw-alias-bg-layer-2);\n  font-variant-numeric: tabular-nums;\n  border-radius: 4px;\n  grid-template-columns: 28px 110px 1fr 75px 75px;\n  align-items: center;\n  gap: 8px;\n  min-width: 0;\n  padding: 6px 10px;\n  font-size: 11px;\n  display: grid;\n}\n\n.kI5sgq_vizSplitGrid {\n  box-sizing: border-box;\n  grid-template-columns: 1fr;\n  gap: 12px;\n  width: 100%;\n  display: grid;\n}\n\n.kI5sgq_vizPanel {\n  background: var(--dsw-specific-menu);\n  border: 1px solid var(--dsw-alias-border-l2);\n  box-shadow: var(--dsw-shadow-lv1);\n  box-sizing: border-box;\n  border-radius: 10px;\n  flex-direction: column;\n  gap: 10px;\n  width: 100%;\n  min-width: 0;\n  padding: 12px 14px;\n  display: flex;\n  overflow: hidden;\n}\n\n.kI5sgq_vizHead {\n  justify-content: space-between;\n  align-items: center;\n  font-size: 12px;\n  display: flex;\n}\n\n.kI5sgq_vizTitle {\n  color: var(--dsw-alias-label-primary);\n  font-weight: 700;\n}\n\n.kI5sgq_vizSub {\n  color: var(--dsw-alias-label-secondary);\n  font-size: 10px;\n}\n\n.kI5sgq_donutWrap {\n  box-sizing: border-box;\n  flex-direction: row;\n  align-items: center;\n  gap: 20px;\n  width: 100%;\n  display: flex;\n}\n\n@media (width <= 480px) {\n  .kI5sgq_donutWrap {\n    flex-direction: column;\n    align-items: center;\n  }\n}\n\n.kI5sgq_donutSvgBox {\n  width: 140px;\n  height: 140px;\n  position: relative;\n}\n\n.kI5sgq_donutSvg {\n  width: 100%;\n  height: 100%;\n}\n\n.kI5sgq_donutCenterText {\n  text-align: center;\n  pointer-events: none;\n  flex-direction: column;\n  justify-content: center;\n  align-items: center;\n  width: 68px;\n  display: flex;\n  position: absolute;\n  top: 50%;\n  left: 50%;\n  transform: translate(-50%, -50%);\n}\n\n.kI5sgq_donutCenterNum {\n  color: var(--dsw-alias-label-primary);\n  font-variant-numeric: tabular-nums;\n  font-size: 17px;\n  font-weight: 800;\n  line-height: 1.1;\n}\n\n.kI5sgq_donutCenterSub {\n  color: var(--dsw-alias-label-tertiary);\n  white-space: nowrap;\n  margin-top: 2px;\n  font-size: 10px;\n  font-weight: 500;\n  line-height: 1;\n}\n\n.kI5sgq_donutLegendList {\n  flex-direction: column;\n  flex: 1;\n  gap: 3px;\n  width: 100%;\n  min-width: 0;\n  display: flex;\n}\n\n.kI5sgq_donutLegendRow {\n  cursor: pointer;\n  border-radius: 4px;\n  justify-content: space-between;\n  align-items: center;\n  min-width: 0;\n  padding: 3px 6px;\n  font-size: 11px;\n  transition: background .12s;\n  display: flex;\n}\n\n.kI5sgq_donutLegendRow:hover, .kI5sgq_donutLegendRowActive {\n  background: var(--dsw-alias-bg-layer-2);\n}\n\n.kI5sgq_dlLeft {\n  flex: 1;\n  align-items: center;\n  gap: 6px;\n  min-width: 0;\n  margin-right: 8px;\n  display: flex;\n}\n\n.kI5sgq_dlDot {\n  border-radius: 2px;\n  flex-shrink: 0;\n  width: 8px;\n  height: 8px;\n}\n\n.kI5sgq_dlName {\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  color: var(--dsw-alias-label-primary);\n  min-width: 0;\n  overflow: hidden;\n}\n\n.kI5sgq_dlRight {\n  font-variant-numeric: tabular-nums;\n  color: var(--dsw-alias-label-secondary);\n  white-space: nowrap;\n  flex-shrink: 0;\n  font-weight: 600;\n}\n\n.kI5sgq_donutInspectBar {\n  background: var(--dsw-alias-bg-layer-2);\n  border: 1px solid var(--dsw-alias-border-l2);\n  border-radius: 6px;\n  align-items: center;\n  gap: 8px;\n  min-width: 0;\n  margin-top: 2px;\n  padding: 6px 10px;\n  font-size: 11px;\n  display: flex;\n}\n\n.kI5sgq_donutInspectName {\n  color: var(--dsw-alias-label-primary);\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  flex: 1;\n  min-width: 0;\n  font-weight: 600;\n  overflow: hidden;\n}\n\n.kI5sgq_donutInspectTag {\n  color: var(--dsw-static-deepseek-450, #5686fe);\n  background: #5686fe1f;\n  border-radius: 3px;\n  flex-shrink: 0;\n  padding: 1px 5px;\n  font-size: 9px;\n  font-weight: 600;\n  line-height: 1.2;\n}\n\n.kI5sgq_donutInspectVal {\n  font-variant-numeric: tabular-nums;\n  color: var(--dsw-alias-label-secondary);\n  white-space: nowrap;\n  flex-shrink: 0;\n  font-size: 11px;\n  font-weight: 600;\n}\n\n.kI5sgq_dayStack {\n  align-items: stretch;\n  gap: 3px;\n  min-width: 0;\n  height: 160px;\n  display: flex;\n}\n\n.kI5sgq_dayStackWeek {\n  justify-content: center;\n  gap: 12px;\n}\n\n.kI5sgq_dayStackWeek .kI5sgq_dayCol {\n  max-width: 48px;\n}\n\n.kI5sgq_dayCol {\n  flex-direction: column;\n  flex: 1 1 0;\n  align-items: stretch;\n  gap: 4px;\n  min-width: 0;\n  display: flex;\n}\n\n.kI5sgq_dayColFill {\n  background: var(--dsw-alias-bg-layer-2);\n  border-radius: 4px;\n  flex-direction: column-reverse;\n  flex: 1;\n  justify-content: flex-start;\n  min-height: 0;\n  transition: filter .12s;\n  display: flex;\n  overflow: hidden;\n}\n\n.kI5sgq_dayColFill:hover {\n  filter: brightness(1.1);\n}\n\n.kI5sgq_daySeg {\n  flex: none;\n  width: 100%;\n  min-height: 0;\n}\n\n.kI5sgq_dayEmptyDot {\n  background: var(--dsw-alias-border-l2);\n  border-radius: 2px;\n  width: 100%;\n  height: 3px;\n  margin-top: auto;\n}\n\n.kI5sgq_dayLabel {\n  color: var(--dsw-alias-label-tertiary);\n  text-align: center;\n  white-space: nowrap;\n  font-size: 10px;\n  line-height: 1;\n  overflow: hidden;\n}\n\n.kI5sgq_chartAreaBox {\n  width: 100%;\n  height: 180px;\n  position: relative;\n}\n\n.kI5sgq_chartSvg {\n  width: 100%;\n  height: 100%;\n  overflow: visible;\n}\n\n.kI5sgq_chartAxisLabel {\n  fill: var(--dsw-alias-label-tertiary);\n  font-size: 9px;\n}\n\n.kI5sgq_chartGridLine {\n  stroke: var(--dsw-alias-border-l2);\n  stroke-dasharray: 2 3;\n}\n\n.kI5sgq_chartFoot {\n  color: var(--dsw-alias-label-tertiary);\n  border-top: 1px solid var(--dsw-alias-border-l2);\n  padding-top: 6px;\n  font-size: 10px;\n}\n\n.kI5sgq_tableTitleGroup {\n  flex-direction: column;\n  gap: 2px;\n  min-width: 0;\n  display: flex;\n}\n\n.kI5sgq_tableSortGroup {\n  background: var(--dsw-alias-bg-layer-2);\n  border: 1px solid var(--dsw-alias-border-l2);\n  border-radius: 6px;\n  flex-shrink: 0;\n  gap: 2px;\n  padding: 2px;\n  display: flex;\n}\n\n.kI5sgq_sortBtn {\n  color: var(--dsw-alias-label-tertiary);\n  cursor: pointer;\n  white-space: nowrap;\n  background: none;\n  border: none;\n  border-radius: 4px;\n  padding: 2px 7px;\n  font-size: 10px;\n  line-height: 16px;\n  transition: all .12s;\n}\n\n.kI5sgq_sortBtn:hover {\n  color: var(--dsw-alias-label-primary);\n}\n\n.kI5sgq_sortBtn[data-active] {\n  background: var(--dsw-specific-menu);\n  color: var(--dsw-alias-label-primary);\n  box-shadow: var(--dsw-shadow-lv1);\n  font-weight: 600;\n}\n\n.kI5sgq_sessionTableBox {\n  box-sizing: border-box;\n  flex-direction: column;\n  gap: 4px;\n  width: 100%;\n  display: flex;\n}\n\n.kI5sgq_sessionTableHeader {\n  color: var(--dsw-alias-label-tertiary);\n  border-bottom: 1px solid var(--dsw-alias-border-l2);\n  background: var(--dsw-alias-bg-layer-2);\n  box-sizing: border-box;\n  border-radius: 6px;\n  grid-template-columns: minmax(0, 1.2fr) minmax(0, 1.3fr) minmax(0, 1fr) minmax(0, .7fr) minmax(0, .7fr) 14px;\n  align-items: center;\n  gap: 6px;\n  padding: 6px 10px;\n  font-size: 10px;\n  font-weight: 600;\n  display: grid;\n}\n\n.kI5sgq_sessionItemRow {\n  border: 1px solid var(--dsw-alias-border-l2);\n  background: var(--dsw-alias-bg-layer-2);\n  border-radius: 6px;\n  transition: border-color .12s;\n  overflow: hidden;\n}\n\n.kI5sgq_sessionItemRow:hover {\n  border-color: var(--dsw-alias-border-l3);\n}\n\n.kI5sgq_tableRankNum {\n  color: var(--dsw-alias-label-secondary);\n  font-variant-numeric: tabular-nums;\n  margin-right: 4px;\n  font-size: 10px;\n}\n\n.kI5sgq_sessionItemHead {\n  width: 100%;\n  color: inherit;\n  text-align: left;\n  cursor: pointer;\n  font-variant-numeric: tabular-nums;\n  box-sizing: border-box;\n  background: none;\n  border: 0;\n  grid-template-columns: minmax(0, 1.2fr) minmax(0, 1.3fr) minmax(0, 1fr) minmax(0, .7fr) minmax(0, .7fr) 14px;\n  align-items: center;\n  gap: 6px;\n  padding: 8px 10px;\n  font-size: 11px;\n  display: grid;\n}\n\n.kI5sgq_sessionTokenCell {\n  flex-direction: column;\n  align-items: flex-end;\n  gap: 2px;\n  min-width: 0;\n  display: flex;\n}\n\n.kI5sgq_sessionTokenBar {\n  background: var(--dsw-static-deepseek-450, #5686fe);\n  border-radius: 1px;\n  max-width: 100%;\n  height: 2px;\n}\n\n.kI5sgq_sessionModelCell {\n  text-overflow: ellipsis;\n  white-space: nowrap;\n  overflow: hidden;\n}\n\n.kI5sgq_statusOk {\n  color: var(--dsw-static-green-500, #10b981);\n}\n\n.kI5sgq_statusWarn {\n  color: #b45309;\n}\n\n.kI5sgq_statusBad {\n  color: var(--dsw-alias-state-error-primary, #ef4444);\n  font-weight: 600;\n}\n\n.kI5sgq_sessionIdTag {\n  color: var(--dsw-alias-label-primary);\n  font-family: ui-monospace, monospace;\n  font-size: 11px;\n  font-weight: 600;\n}\n\n.kI5sgq_arrowIcon {\n  color: var(--dsw-alias-label-tertiary);\n  transition: transform .12s;\n}\n\n.kI5sgq_sessionItemOpen .kI5sgq_arrowIcon {\n  transform: rotate(90deg);\n}\n\n.kI5sgq_sessionItemDrawer {\n  background: var(--dsw-specific-menu);\n  border-top: 1px dashed var(--dsw-alias-border-l2);\n  padding: 10px 12px;\n  font-size: 11px;\n}\n\n.kI5sgq_drawerTitle {\n  color: var(--dsw-alias-label-primary);\n  margin-bottom: 6px;\n  font-weight: 600;\n}\n\n.kI5sgq_drawerBarTrack {\n  background: var(--dsw-alias-bg-layer-2);\n  border-radius: 4px;\n  gap: 1px;\n  height: 8px;\n  margin-bottom: 6px;\n  display: flex;\n  overflow: hidden;\n}\n\n.kI5sgq_drawerSliceModel {\n  background: var(--dsw-static-deepseek-450, #5686fe);\n  height: 100%;\n}\n\n.kI5sgq_drawerSliceTool {\n  background: var(--dsw-static-green-500, #10b981);\n  height: 100%;\n}\n\n.kI5sgq_drawerMetaRow {\n  color: var(--dsw-alias-label-secondary);\n  flex-wrap: wrap;\n  justify-content: space-between;\n  gap: 6px;\n  font-size: 10px;\n  display: flex;\n}\n\n.kI5sgq_settingsDrawer {\n  border: 1px solid var(--dsw-alias-border-l2);\n  color: var(--dsw-alias-label-tertiary);\n  background: var(--dsw-specific-menu);\n  border-radius: 8px;\n  padding: 8px 12px;\n  font-size: 11px;\n}\n\n.kI5sgq_settingsSummary {\n  cursor: pointer;\n  color: var(--dsw-alias-label-secondary);\n  font-weight: 500;\n}\n\n.kI5sgq_settingsDrawerContent {\n  flex-wrap: wrap;\n  align-items: center;\n  gap: 14px;\n  padding-top: 10px;\n  display: flex;\n}\n\n.kI5sgq_settingInlineItem {\n  align-items: center;\n  gap: 6px;\n  display: flex;\n}\n\n.kI5sgq_settingsMiniInput {\n  border: 1px solid var(--dsw-alias-border-l2);\n  background: var(--dsw-alias-bg-layer-1);\n  width: 50px;\n  color: var(--dsw-alias-label-primary);\n  text-align: right;\n  border-radius: 4px;\n  outline: none;\n  padding: 3px 6px;\n  font-size: 11px;\n}\n\n.kI5sgq_settingsMiniSaveBtn {\n  background: var(--dsw-static-deepseek-450, #5686fe);\n  color: #fff;\n  cursor: pointer;\n  border: none;\n  border-radius: 4px;\n  padding: 3px 10px;\n  font-size: 11px;\n}\n\n.kI5sgq_emptyScan {\n  text-align: center;\n  color: var(--dsw-alias-label-tertiary);\n  padding: 20px;\n  font-size: 12px;\n}\n.dVZKUa_panelBox {\n  --c-ttft: #94a3b8;\n  --c-think: #3b82f6;\n  --c-output: #38bdf8;\n  --c-bash: #059669;\n  --c-file: #34d399;\n  box-sizing: border-box;\n  background: var(--dsw-alias-bg-layer-2, #f5f6f8);\n  border: 1px solid var(--dsw-alias-border-l2, #e2e8f0);\n  border-radius: 8px;\n  width: 100%;\n  padding: 12px 14px;\n  position: relative;\n}\n\nbody[data-ds-dark-theme] .dVZKUa_panelBox {\n  --c-ttft: #64748b;\n  --c-think: #60a5fa;\n  --c-output: #38bdf8;\n  --c-bash: #10b981;\n  --c-file: #6ee7b7;\n}\n\n.dVZKUa_topRow {\n  white-space: nowrap;\n  justify-content: space-between;\n  align-items: center;\n  gap: 12px;\n  margin-bottom: 8px;\n  font-size: 11px;\n  display: flex;\n}\n\n.dVZKUa_titleArea {\n  white-space: nowrap;\n  flex-wrap: nowrap;\n  align-items: center;\n  gap: 8px;\n  min-width: 0;\n  display: flex;\n}\n\n.dVZKUa_mainTitle {\n  color: var(--dsw-alias-label-primary, #17181c);\n  white-space: nowrap;\n  font-size: 12px;\n  font-weight: 700;\n}\n\n.dVZKUa_liveSpeed {\n  background: var(--dsw-alias-bg-layer-1, #fff);\n  border: 1px solid var(--dsw-alias-border-l2, #e2e8f0);\n  color: var(--dsw-alias-label-primary, #17181c);\n  font-variant-numeric: tabular-nums;\n  white-space: nowrap;\n  border-radius: 4px;\n  align-items: center;\n  gap: 4px;\n  padding: 1px 6px;\n  font-size: 10px;\n  font-weight: 600;\n  display: inline-flex;\n}\n\n.dVZKUa_speedDot {\n  background: var(--c-output);\n  border-radius: 50%;\n  width: 5px;\n  height: 5px;\n  animation: 1.5s infinite dVZKUa_pulse;\n}\n\n.dVZKUa_totalDuration {\n  color: var(--dsw-alias-label-secondary, #5f636d);\n  font-variant-numeric: tabular-nums;\n  white-space: nowrap;\n}\n\n.dVZKUa_bottleneckText {\n  color: var(--dsw-alias-label-primary, #17181c);\n  font-variant-numeric: tabular-nums;\n  white-space: nowrap;\n  flex-shrink: 0;\n  font-size: 11px;\n  font-weight: 600;\n}\n\n.dVZKUa_chartBox {\n  width: 100%;\n  margin-bottom: 8px;\n  position: relative;\n}\n\n.dVZKUa_barTrack {\n  background: var(--dsw-alias-bg-layer-1, #e2e8f0);\n  cursor: crosshair;\n  border-radius: 5px;\n  gap: 1px;\n  width: 100%;\n  height: 20px;\n  display: flex;\n  overflow: hidden;\n  box-shadow: inset 0 1px 2px #0000000a;\n}\n\n.dVZKUa_modelCluster, .dVZKUa_toolCluster {\n  height: 100%;\n  transition: opacity .12s;\n  display: flex;\n  position: relative;\n}\n\n.dVZKUa_slice {\n  cursor: pointer;\n  height: 100%;\n  transition: all .12s;\n  position: relative;\n}\n\n.dVZKUa_slice:hover {\n  filter: brightness(1.15);\n  z-index: 5;\n  box-shadow: 0 0 6px #0003;\n}\n\n.dVZKUa_slice + .dVZKUa_slice {\n  border-left: 1px solid #ffffff59;\n}\n\n.dVZKUa_sliceTtft {\n  background: var(--c-ttft);\n}\n\n.dVZKUa_sliceThink {\n  background: var(--c-think);\n}\n\n.dVZKUa_sliceOutput {\n  background: var(--c-output);\n}\n\n.dVZKUa_sliceBash {\n  background: var(--c-bash);\n}\n\n.dVZKUa_sliceFile {\n  background: var(--c-file);\n}\n\n.dVZKUa_legendRow {\n  color: var(--dsw-alias-label-secondary, #5f636d);\n  white-space: nowrap;\n  flex-wrap: nowrap;\n  justify-content: space-between;\n  align-items: center;\n  gap: 8px;\n  font-size: 11px;\n  display: flex;\n}\n\n.dVZKUa_legendGroup {\n  white-space: nowrap;\n  flex-wrap: nowrap;\n  align-items: center;\n  gap: 12px;\n  display: flex;\n}\n\n.dVZKUa_legendItem {\n  cursor: pointer;\n  white-space: nowrap;\n  align-items: center;\n  gap: 4px;\n  transition: opacity .12s;\n  display: flex;\n}\n\n.dVZKUa_legendItem:hover {\n  opacity: .75;\n}\n\n.dVZKUa_dot {\n  border-radius: 2px;\n  flex-shrink: 0;\n  width: 7px;\n  height: 7px;\n}\n\n.dVZKUa_statusPill {\n  white-space: nowrap;\n  border-radius: 4px;\n  flex-shrink: 0;\n  align-items: center;\n  gap: 4px;\n  padding: 1px 7px;\n  font-size: 10px;\n  font-weight: 600;\n  display: inline-flex;\n}\n\n.dVZKUa_statusOk {\n  color: var(--dsw-static-green-500, #15803d);\n}\n\n.dVZKUa_statusWarn {\n  color: #b45309;\n  background: #f59e0b1f;\n}\n\n.dVZKUa_statusDanger {\n  color: #b91c1c;\n  background: #ef44441f;\n}\n\n.dVZKUa_popover {\n  color: #f8fafc;\n  pointer-events: none;\n  z-index: 50;\n  box-sizing: border-box;\n  white-space: nowrap;\n  background: #0f172a;\n  border-radius: 8px;\n  width: 360px;\n  max-width: calc(100% - 16px);\n  padding: 10px 14px;\n  font-size: 11px;\n  animation: .12s ease-out dVZKUa_popIn;\n  position: absolute;\n  top: auto;\n  bottom: calc(100% + 8px);\n  box-shadow: 0 8px 24px #00000059;\n}\n\n.dVZKUa_popover:after {\n  content: \"\";\n  bottom: -5px;\n  left: var(--arrow-left, 50%);\n  border: 5px solid #0000;\n  border-top-color: #0f172a;\n  border-bottom-width: 0;\n  position: absolute;\n  transform: translateX(-50%);\n}\n\n.dVZKUa_popTitle {\n  white-space: nowrap;\n  border-bottom: 1px solid #ffffff26;\n  justify-content: space-between;\n  align-items: center;\n  gap: 16px;\n  margin-bottom: 6px;\n  padding-bottom: 5px;\n  font-weight: 600;\n  display: flex;\n}\n\n.dVZKUa_popList {\n  flex-direction: column;\n  gap: 3px;\n  display: flex;\n}\n\n.dVZKUa_popRow {\n  white-space: nowrap;\n  justify-content: space-between;\n  align-items: center;\n  gap: 16px;\n  padding: 2px 0;\n  display: flex;\n}\n\n.dVZKUa_popLeft {\n  color: #ffffffd9;\n  white-space: nowrap;\n  flex-shrink: 0;\n  align-items: center;\n  gap: 6px;\n  display: flex;\n}\n\n.dVZKUa_popRight {\n  font-variant-numeric: tabular-nums;\n  color: #fff;\n  white-space: nowrap;\n  text-align: right;\n  flex-shrink: 0;\n  font-weight: 600;\n}\n\n.dVZKUa_activeVal {\n  color: #fbbf24;\n  font-weight: 700;\n}\n\n@keyframes dVZKUa_pulse {\n  0%, 100% {\n    opacity: 1;\n    transform: scale(1);\n  }\n\n  50% {\n    opacity: .4;\n    transform: scale(.85);\n  }\n}\n\n@keyframes dVZKUa_popIn {\n  from {\n    opacity: 0;\n    transform: translateY(4px);\n  }\n\n  to {\n    opacity: 1;\n    transform: translateY(0);\n  }\n}\n";
		})();

Object.defineProperty(exports, Symbol.toStringTag, { value: "Module" });
let react = require("react");
let react_dom = require("react-dom");
let _deepseek_ai_dsh_client_ui_primitives = require("@deepseek-ai/dsh-client-ui-primitives");
let react_jsx_runtime = require("react/jsx-runtime");
//#region src/hub/history.ts
/**
* Pull every older RC8 page in order. The Session remains the sole owner of
* history continuity; this helper only repeats its public, read-only paging
* verb and fails closed if one request does not advance the visible head.
*/
async function loadCompleteHistory({ read, loadOlder, signal, maxPages = 1e3 }) {
	let pages = 0;
	while (pages < maxPages) {
		if (signal.aborted) return {
			kind: "cancelled",
			pages
		};
		const before = read();
		if (!before.hasMore) return {
			kind: "complete",
			pages
		};
		if (before.loadingOlder) return {
			kind: "blocked",
			pages,
			reason: "busy"
		};
		await loadOlder();
		if (signal.aborted) return {
			kind: "cancelled",
			pages
		};
		const after = read();
		if (!after.hasMore) return {
			kind: "complete",
			pages: pages + 1
		};
		if (after.headKey === before.headKey) return {
			kind: "blocked",
			pages,
			reason: "no-progress"
		};
		pages += 1;
	}
	return {
		kind: "blocked",
		pages,
		reason: "page-limit"
	};
}
//#endregion
//#region src/hub/follow.ts
/**
* Follow versus pin state for the work rail.
*
* The rail follows the newest recorded occurrence by default. Selecting
* history or scrolling away pins the viewport; later occurrences and result
* updates increment `unread` without yanking the reader away from evidence.
*/
function createFollow() {
	let follow = true;
	let unread = 0;
	let selectedId = null;
	let lastCursor = null;
	let observedOccurrenceIds = [];
	function snapshot() {
		return {
			follow,
			unread,
			selectedId
		};
	}
	function catchUp() {
		follow = true;
		unread = 0;
		selectedId = null;
	}
	return {
		snapshot,
		/** Counts appended occurrences or a settled live result while pinned. */
		onPicture(picture) {
			const groups = picture.nodes;
			if (groups.length === 0) {
				lastCursor = null;
				observedOccurrenceIds = [];
				catchUp();
				return snapshot();
			}
			const occurrenceIds = groups.flatMap((group) => group.items.map((item) => `${group.id}:${item.id}`));
			const group = groups.at(-1);
			const item = group?.items.at(-1);
			const cursor = group === void 0 ? null : item === void 0 ? group.id : `${group.id}:${item.id}:${item.status}:${item.resultSeq ?? "open"}:${item.resultTime ?? "open"}`;
			if (cursor !== null && cursor !== lastCursor) {
				if (!follow && lastCursor !== null) {
					const previousIds = new Set(observedOccurrenceIds);
					const appended = occurrenceIds.filter((id) => !previousIds.has(id)).length;
					unread += Math.max(1, appended);
				}
				lastCursor = cursor;
				if (follow) selectedId = null;
			}
			observedOccurrenceIds = occurrenceIds;
			return snapshot();
		},
		onSelect(id) {
			follow = false;
			selectedId = id;
			return snapshot();
		},
		onScroll({ atBottom }) {
			if (atBottom) {
				if (unread === 0 && selectedId === null) follow = true;
			} else if (follow) follow = false;
			return snapshot();
		},
		setFollow(next) {
			if (next) catchUp();
			else follow = false;
			return snapshot();
		},
		backToLatest() {
			catchUp();
			return snapshot();
		},
		reset() {
			catchUp();
			lastCursor = null;
			observedOccurrenceIds = [];
			return snapshot();
		}
	};
}
//#endregion
//#region src/hub/aggregation.ts
function identityOf(item) {
	if (item.intentKey !== null) return {
		kind: "mutable-target",
		key: `target\u0000${item.intentKey}`
	};
	if (item.toolName === "read" && item.target !== null) return {
		kind: "shared-target",
		key: `target\u0000read\u0000${item.target}`
	};
	if (item.signature !== null) return {
		kind: "exact-call",
		key: `exact\u0000${item.signature}`
	};
	return {
		kind: "single",
		key: `single\u0000${item.id}`
	};
}
function emptyStatusCounts() {
	return {
		running: 0,
		waiting: 0,
		success: 0,
		failure: 0,
		returned: 0,
		interrupted: 0,
		unknown: 0
	};
}
function countStatuses(items) {
	const counts = emptyStatusCounts();
	for (const item of items) counts[item.status] += 1;
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
function clusterWorkItems(items) {
	const accumulators = /* @__PURE__ */ new Map();
	for (const item of items) {
		const identity = identityOf(item);
		const existing = accumulators.get(identity.key);
		if (existing === void 0) accumulators.set(identity.key, {
			basis: identity.kind,
			first: item,
			rest: []
		});
		else existing.rest.push(item);
	}
	const clusters = [];
	for (const accumulator of accumulators.values()) {
		const clusterItems = [accumulator.first, ...accumulator.rest];
		const latest = clusterItems[clusterItems.length - 1];
		if (latest === void 0) continue;
		clusters.push({
			id: `cluster:${accumulator.first.id}`,
			basis: accumulator.basis,
			title: accumulator.first.title,
			items: clusterItems,
			executionCount: clusterItems.length,
			stepCount: new Set(clusterItems.map((item) => item.step)).size,
			retryCount: clusterItems.filter((item) => item.retryOf !== null).length,
			iterationCount: clusterItems.filter((item) => item.iterationIndex > 0).length,
			latestStatus: latest.status,
			statusCounts: countStatuses(clusterItems)
		});
	}
	return clusters;
}
function clusterOutcomeSummary(cluster) {
	const counts = cluster.statusCounts;
	return [
		counts.running > 0 ? `${counts.running} 进行中` : null,
		counts.waiting > 0 ? `${counts.waiting} 等待` : null,
		counts.success > 0 ? `${counts.success} 成功` : null,
		counts.failure > 0 ? `${counts.failure} 失败` : null,
		counts.returned > 0 ? `${counts.returned} 已返回` : null,
		counts.interrupted > 0 ? `${counts.interrupted} 已中断` : null,
		counts.unknown > 0 ? `${counts.unknown} 未知` : null
	].filter((part) => part !== null).join(" · ");
}
//#endregion
//#region src/observation/model-trace.ts
function isRecord$1(value) {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}
function finiteNumber(value) {
	return typeof value === "number" && Number.isFinite(value) ? value : null;
}
function nonNegativeNumber(value) {
	const number = finiteNumber(value);
	return number !== null && number >= 0 ? number : null;
}
function locationOf(value) {
	const data = value.data;
	if (!isRecord$1(data)) return null;
	const turn = finiteNumber(data.turn);
	const step = finiteNumber(data.step);
	const seq = finiteNumber(value.seq);
	const time = finiteNumber(value.time);
	return turn === null || step === null || seq === null || time === null ? null : {
		turn,
		step,
		seq,
		time
	};
}
function reasoningTokensOf(value) {
	return isRecord$1(value) ? nonNegativeNumber(value.reasoningTokens) : null;
}
function reasoningTextOf(value) {
	if (!isRecord$1(value) || !Array.isArray(value.content)) return null;
	const parts = value.content.flatMap((block) => isRecord$1(block) && block.type === "reasoning" && typeof block.text === "string" ? [block.text] : []);
	return parts.length === 0 ? null : parts.join("\n\n");
}
/** Parse only the seven event shapes needed by the read-only model-stage fold. */
function modelTraceEventOf(value) {
	if (!isRecord$1(value) || typeof value.type !== "string") return null;
	const location = locationOf(value);
	if (location === null || !isRecord$1(value.data)) return null;
	const data = value.data;
	if (value.type === "step/start") return {
		...location,
		kind: "step-start"
	};
	if (value.type === "step/end") return {
		...location,
		kind: "step-end"
	};
	if (value.type === "llm/retry") {
		const retry = nonNegativeNumber(data.retry);
		const delayMs = nonNegativeNumber(data.delayMs);
		return retry === null || delayMs === null ? null : {
			...location,
			kind: "retry",
			retry,
			delayMs
		};
	}
	if (value.type === "assistant/message") return {
		...location,
		kind: "message",
		reasoningText: reasoningTextOf(data.message),
		reasoningTokens: reasoningTokensOf(data.usage)
	};
	if ([
		"chunkrow/reasoning-chunks",
		"chunkrow/text-chunks",
		"chunkrow/tool-call-chunks"
	].includes(value.type)) {
		const tool = value.type === "chunkrow/tool-call-chunks";
		const parts = tool ? data.args : data.texts;
		const gaps = data.dt;
		if (!Array.isArray(parts) || !parts.length || !parts.every((p) => typeof p === "string") || !Array.isArray(gaps) || gaps.length !== parts.length - 1 || !gaps.every(Number.isSafeInteger)) return null;
		let time = location.time;
		const fragments = [];
		for (let i = 0; i < parts.length; i++) {
			if (i > 0) time += gaps[i - 1];
			if (!Number.isSafeInteger(time)) return null;
			const text = parts[i];
			if (text !== "" || tool && typeof data.name === "string") fragments.push({
				seq: location.seq + i,
				time,
				text
			});
		}
		const first = fragments[0];
		if (!first) return null;
		const base = {
			...location,
			time: first.time,
			lastSeq: location.seq + parts.length - 1
		};
		return value.type === "chunkrow/reasoning-chunks" ? {
			...base,
			kind: "reasoning-delta",
			text: fragments.map((f) => f.text).join(""),
			fragments
		} : {
			...base,
			kind: "output-delta"
		};
	}
	if (value.type !== "assistant/chunk" || !isRecord$1(data.chunk) || typeof data.chunk.type !== "string") return null;
	const chunk = data.chunk;
	if (chunk.type === "reasoning-delta") return typeof chunk.text === "string" && chunk.text !== "" ? {
		...location,
		kind: "reasoning-delta",
		text: chunk.text
	} : null;
	if (chunk.type === "text-delta") return typeof chunk.text === "string" && chunk.text !== "" ? {
		...location,
		kind: "output-delta"
	} : null;
	if (chunk.type === "tool-call-delta") return typeof chunk.argumentsDelta === "string" && chunk.argumentsDelta !== "" || typeof chunk.name === "string" ? {
		...location,
		kind: "output-delta"
	} : null;
	if (chunk.type === "usage") return {
		...location,
		kind: "usage",
		reasoningTokens: reasoningTokensOf(chunk.usage)
	};
	return null;
}
function runningAttempt(attempt, startedAt) {
	return {
		kind: "running",
		attempt,
		startedAt,
		firstTokenTime: null,
		firstReasoningTime: null,
		lastReasoningTime: null,
		firstOutputTime: null,
		reasoningText: "",
		fragments: []
	};
}
function startModelStepTrace(event) {
	return {
		turn: event.turn,
		step: event.step,
		startSeq: event.seq,
		lastSeq: event.seq,
		startTime: event.time,
		attempts: [runningAttempt(1, event.time)],
		reasoningTokens: null
	};
}
function replaceLast(attempts, attempt) {
	if (attempts.length === 1) return [attempt];
	return [
		attempts[0],
		...attempts.slice(1, -1),
		attempt
	];
}
function appendAttempt(attempts, attempt) {
	return [...attempts, attempt];
}
function sameStep(trace, event) {
	return trace.turn === event.turn && trace.step === event.step;
}
/** Fold one normalized event without discarding reasoning from a retried attempt. */
function updateModelStepTrace(trace, event) {
	if (!sameStep(trace, event) || event.kind === "step-start") return trace;
	const current = {
		...trace,
		lastSeq: Math.max(trace.lastSeq, event.lastSeq ?? event.seq)
	};
	const attempt = trace.attempts.at(-1);
	if (attempt === void 0) return trace;
	if (event.kind === "usage") return event.reasoningTokens === null ? current : {
		...current,
		reasoningTokens: event.reasoningTokens
	};
	if (event.kind === "reasoning-delta") {
		if (attempt.kind !== "running") return current;
		const fragments = event.fragments ?? [{
			seq: event.seq,
			time: event.time,
			text: event.text
		}];
		return {
			...current,
			attempts: replaceLast(trace.attempts, {
				...attempt,
				firstTokenTime: attempt.firstTokenTime ?? event.time,
				firstReasoningTime: attempt.firstReasoningTime ?? event.time,
				lastReasoningTime: fragments.at(-1)?.time ?? event.time,
				reasoningText: attempt.reasoningText + event.text,
				fragments: [...attempt.fragments, ...fragments]
			})
		};
	}
	if (event.kind === "output-delta") {
		if (attempt.kind !== "running") return current;
		return {
			...current,
			attempts: replaceLast(trace.attempts, {
				...attempt,
				firstTokenTime: attempt.firstTokenTime ?? event.time,
				firstOutputTime: attempt.firstOutputTime ?? event.time
			})
		};
	}
	if (event.kind === "retry") {
		if (attempt.kind !== "running") return current;
		const retried = {
			...attempt,
			kind: "retried",
			endedAt: event.time,
			retry: event.retry,
			retryDelayMs: event.delayMs
		};
		return {
			...current,
			attempts: appendAttempt(replaceLast(trace.attempts, retried), runningAttempt(attempt.attempt + 1, null))
		};
	}
	if (event.kind === "message") {
		const reasoningTokens = event.reasoningTokens ?? trace.reasoningTokens;
		if (attempt.kind !== "running") return {
			...current,
			reasoningTokens
		};
		return {
			...current,
			reasoningTokens,
			attempts: replaceLast(trace.attempts, {
				...attempt,
				kind: "complete",
				endedAt: event.time,
				reasoningText: event.reasoningText ?? attempt.reasoningText
			})
		};
	}
	if (attempt.kind !== "running") return current;
	return {
		...current,
		attempts: replaceLast(trace.attempts, {
			...attempt,
			kind: "interrupted",
			endedAt: event.time
		})
	};
}
function attemptEnd(attempt, now) {
	return attempt.kind === "running" ? now : attempt.endedAt;
}
function firstTokenTime(trace) {
	for (const attempt of trace.attempts) if (attempt.firstTokenTime !== null) return attempt.firstTokenTime;
	return null;
}
function visibleReasoningDuration(trace, _now) {
	let sampled = false;
	let total = 0;
	for (const attempt of trace.attempts) {
		if (attempt.firstReasoningTime === null || attempt.lastReasoningTime === null) continue;
		if (attempt.firstOutputTime !== null && attempt.lastReasoningTime > attempt.firstOutputTime) continue;
		sampled = true;
		const end = attempt.lastReasoningTime;
		total += Math.max(0, end - attempt.firstReasoningTime);
	}
	return sampled ? total : null;
}
/** Derive additive display segments without calling unobserved latency Thinking. */
function modelStageMetrics(trace, now) {
	const last = trace.attempts.at(-1);
	const live = last?.kind === "running";
	const end = last === void 0 ? null : attemptEnd(last, now);
	const totalMs = trace.startTime === null || end === null ? null : Math.max(0, end - trace.startTime);
	const firstToken = firstTokenTime(trace);
	const firstResponseMs = trace.startTime === null || firstToken === null ? null : Math.max(0, firstToken - trace.startTime);
	const visibleReasoningMs = visibleReasoningDuration(trace, now);
	const finalReasoning = last?.lastReasoningTime ?? null;
	const outputStart = last?.firstOutputTime ?? null;
	const outputMs = outputStart === null || end === null || live && finalReasoning !== null && last?.firstOutputTime === null ? null : Math.max(0, end - outputStart);
	const attributed = (firstResponseMs ?? 0) + (visibleReasoningMs ?? 0) + (outputMs ?? 0);
	const unattributedMs = totalMs === null ? null : Math.max(0, totalMs - attributed);
	return {
		kind: trace.startTime === null ? "partial" : "measured",
		live,
		totalMs,
		firstResponseMs,
		visibleReasoningMs,
		outputMs,
		unattributedMs
	};
}
function hasReasoningEvidence(trace) {
	return trace.attempts.some((attempt) => attempt.reasoningText.trim() !== "" || attempt.fragments.length > 0);
}
//#endregion
//#region src/observation/fold.ts
const EMPTY_NOW = Object.freeze({
	phase: "other",
	label: "",
	status: "unknown"
});
const EMPTY_PICTURE = Object.freeze({
	nodes: [],
	turns: [],
	now: EMPTY_NOW,
	actionCount: 0,
	stepCount: 0,
	turnCount: 0,
	parallelStepCount: 0,
	retryCount: 0,
	iterationCount: 0,
	pendingCount: 0,
	unconfirmedFailureCount: 0,
	running: false,
	partialHistory: false
});
function isRecord(value) {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}
function recordAt(value, key) {
	if (!isRecord(value)) return null;
	const child = value[key];
	return isRecord(child) ? child : null;
}
function stringAt(value, key) {
	return isRecord(value) && typeof value[key] === "string" ? value[key] : null;
}
function numberAt(value, key) {
	return isRecord(value) && typeof value[key] === "number" && Number.isFinite(value[key]) ? value[key] : null;
}
function parseArgs(raw) {
	if (isRecord(raw)) return raw;
	if (typeof raw !== "string" || raw.trim() === "") return {};
	try {
		const parsed = JSON.parse(raw);
		return isRecord(parsed) ? parsed : {};
	} catch {
		return {};
	}
}
function stableValue(value) {
	if (Array.isArray(value)) return value.map(stableValue);
	if (!isRecord(value)) return value;
	return Object.fromEntries(Object.keys(value).sort().map((key) => [key, stableValue(value[key])]));
}
/** Stable exact signature used only for evidence-backed retry detection. */
function normalizedSignature(toolName, args) {
	return `${toolName}\u0000${JSON.stringify(stableValue(args))}`;
}
function safeStringify(value) {
	try {
		return JSON.stringify(value, null, 2);
	} catch {
		return String(value);
	}
}
function textFromContent(value, output = []) {
	if (Array.isArray(value)) {
		for (const child of value) textFromContent(child, output);
		return output;
	}
	if (!isRecord(value)) return output;
	if (value.type === "text" && typeof value.text === "string") {
		output.push(value.text);
		return output;
	}
	if (typeof value.output === "string") output.push(value.output);
	if (Array.isArray(value.content)) textFromContent(value.content, output);
	if (isRecord(value.message)) textFromContent(value.message, output);
	return output;
}
function resultText(value) {
	return textFromContent(value).filter(Boolean).join("\n");
}
function findNumberByKeys(value, keys, depth = 0) {
	if (depth > 8) return null;
	if (Array.isArray(value)) {
		for (const child of value) {
			const found = findNumberByKeys(child, keys, depth + 1);
			if (found !== null) return found;
		}
		return null;
	}
	if (!isRecord(value)) return null;
	for (const [key, child] of Object.entries(value)) if (keys.has(key) && typeof child === "number" && Number.isFinite(child)) return child;
	for (const child of Object.values(value)) {
		const found = findNumberByKeys(child, keys, depth + 1);
		if (found !== null) return found;
	}
	return null;
}
function findStringByKeys(value, keys, depth = 0) {
	if (depth > 8) return null;
	if (Array.isArray(value)) {
		for (const child of value) {
			const found = findStringByKeys(child, keys, depth + 1);
			if (found !== null) return found;
		}
		return null;
	}
	if (!isRecord(value)) return null;
	for (const [key, child] of Object.entries(value)) if (keys.has(key) && typeof child === "string") return child;
	for (const child of Object.values(value)) {
		const found = findStringByKeys(child, keys, depth + 1);
		if (found !== null) return found;
	}
	return null;
}
function findBooleanByKeys(value, keys, depth = 0) {
	if (depth > 6) return null;
	if (Array.isArray(value)) {
		for (const child of value) {
			const found = findBooleanByKeys(child, keys, depth + 1);
			if (found !== null) return found;
		}
		return null;
	}
	if (!isRecord(value)) return null;
	for (const [key, child] of Object.entries(value)) if (keys.has(key) && typeof child === "boolean") return child;
	for (const child of Object.values(value)) {
		const found = findBooleanByKeys(child, keys, depth + 1);
		if (found !== null) return found;
	}
	return null;
}
function exitCodeOf(...values) {
	const keys = /* @__PURE__ */ new Set(["exitCode", "exit_code"]);
	for (const value of values) {
		const found = findNumberByKeys(value, keys);
		if (found !== null) return found;
		const text = resultText(value);
		const marker = text.match(/\[exit code:\s*(-?\d+)\]/i) ?? text.match(/"(?:exitCode|exit_code)"\s*:\s*(-?\d+)/);
		if (marker?.[1] !== void 0) return Number(marker[1]);
	}
	return null;
}
function signalOf(...values) {
	const keys = /* @__PURE__ */ new Set(["signal"]);
	for (const value of values) {
		const found = findStringByKeys(value, keys);
		if (found !== null) return found;
	}
	return null;
}
function errorFlagOf(value) {
	return findBooleanByKeys(value, /* @__PURE__ */ new Set(["isError"])) === true;
}
function domainOutcomeOf(...values) {
	for (const value of values) {
		const boolean = findBooleanByKeys(value, /* @__PURE__ */ new Set(["ok", "success"]));
		if (boolean !== null) return boolean ? "success" : "failure";
		const status = findStringByKeys(value, /* @__PURE__ */ new Set(["status", "outcome"]))?.toLowerCase();
		if (status !== void 0 && status !== null) {
			if (/^(ok|success|succeeded|passed|done|completed)$/.test(status)) return "success";
			if (/^(error|failed|failure|denied|cancelled|canceled)$/.test(status)) return "failure";
		}
	}
	return null;
}
function parseJsonCandidate(text) {
	const trimmed = text.trim();
	if (!(trimmed.startsWith("{") || trimmed.startsWith("["))) return null;
	try {
		const parsed = JSON.parse(trimmed);
		return typeof parsed === "object" && parsed !== null ? parsed : null;
	} catch {
		return null;
	}
}
function baseName(path) {
	return path.replace(/[\\/]+$/, "").split(/[\\/]/).pop() || path;
}
function stringArg(args, ...keys) {
	for (const key of keys) {
		const value = args[key];
		if (typeof value === "string" && value.trim() !== "") return value;
	}
	return null;
}
function commandOf(args) {
	return stringArg(args, "command", "cmd") ?? "";
}
function commandPreview(command) {
	const oneLine = command.replace(/\s+/g, " ").trim();
	if (oneLine.length <= 52) return oneLine;
	return `${oneLine.slice(0, 49)}…`;
}
function targetOf(name, args) {
	const direct = stringArg(args, "file_path", "path", "url", "query", "pattern", "name", "plugin");
	if (direct !== null) return direct;
	if (name === "bash") return commandOf(args).match(/(?:^|\s)(\.?\.?\/[\w./-]+|\/[\w./-]+)/)?.[1] ?? null;
	return null;
}
function isVerificationCommand(command) {
	return /(?:^|\s)(?:test|typecheck|check|verify|lint|vitest|jest|tsc|build)(?:\s|$)|dshx\s+check/i.test(command);
}
function isActivationCommand(command) {
	return /dshx\s+(?:activation-plan|sync-artifact|ship|install|start)|dsh\s+plugin\s+(?:add|remove)/i.test(command);
}
function phaseOfTool(name, args, callView) {
	const kind = stringAt(callView, "kind");
	if (/^(skill|todo_write|create_goal|update_goal|get_goal|update_plan)$/.test(name)) return "plan";
	if (/^(read|grep|glob|find|search|web_search|web_fetch|web_open)$/.test(name)) return "investigate";
	if (/^(write|edit|apply_patch|imagegen|image_gen)/.test(name)) return "build";
	if (/^(dshx_activation_plan|dshx_sync_artifact|dshx_ship|dshx_install|dshx_start)/.test(name)) return "activate";
	if (/^(dshx_check|dshx_verify|dshx_which|dshx_status)/.test(name)) return "verify";
	if (name.startsWith("cua_") || name.includes("computer")) return "desktop";
	if (name === "bash") {
		const command = commandOf(args);
		if (isActivationCommand(command)) return "activate";
		if (isVerificationCommand(command)) return "verify";
		if (/\b(?:sed|head|tail|ls|find|rg|grep|git\s+(?:status|diff|log|show))\b/.test(command)) return "investigate";
		return "build";
	}
	if (kind === "read" || kind === "search" || kind === "fetch") return "investigate";
	if (kind === "edit" || kind === "delete" || kind === "move") return "build";
	if (kind === "execute") return "build";
	return "other";
}
function titleOfTool(name, args, callView) {
	const target = targetOf(name, args);
	if (name === "read") return `读取 ${target === null ? "文件" : baseName(target)}`;
	if (name === "grep") return `搜索 ${stringArg(args, "pattern") ?? "内容"}`;
	if (name === "glob") return `查找 ${stringArg(args, "pattern") ?? "文件"}`;
	if (name === "write") return `写入 ${target === null ? "文件" : baseName(target)}`;
	if (name === "edit") return `修改 ${target === null ? "文件" : baseName(target)}`;
	if (name === "apply_patch") return "应用代码补丁";
	if (name === "bash") {
		const description = stringArg(args, "description");
		if (description !== null) return description;
		const command = commandOf(args);
		return command === "" ? "运行命令" : `运行 ${commandPreview(command)}`;
	}
	if (name === "skill") return "读取工作说明";
	if (name === "todo_write" || name === "update_plan") return "更新工作计划";
	if (name === "create_goal") return "建立任务目标";
	if (name === "update_goal") return "更新任务目标";
	if (name === "get_goal") return "核对任务目标";
	if (name === "dshx_status" || name === "dshx_which") return "核对 DSHX 环境";
	if (name === "dshx_check") return "检查插件合同";
	if (name === "dshx_activation_plan") return "规划插件激活";
	if (name === "dshx_sync_artifact") return "同步插件产物";
	return stringAt(callView, "title") ?? (name.replaceAll("_", " ") || "未知执行");
}
function subtitleOfTool(name, args, target) {
	if (target !== null) return target;
	if (name === "bash") return commandOf(args) || name;
	return stringArg(args, "query", "pattern") ?? name;
}
function validReadPresentation(value) {
	if (!isRecord(value) || value.card !== "read" || !Array.isArray(value.lines)) return null;
	const lines = [];
	for (const line of value.lines) {
		if (!isRecord(line) || typeof line.number !== "number" || typeof line.text !== "string") return null;
		lines.push({
			number: line.number,
			text: line.text
		});
	}
	const totalLines = typeof value.totalLines === "number" ? value.totalLines : lines.length;
	return {
		kind: "read",
		label: typeof value.title === "string" ? value.title : typeof value.path === "string" ? value.path : "文件",
		lang: typeof value.lang === "string" ? value.lang : null,
		lines,
		totalLines
	};
}
function validReadMeta(value) {
	if (!isRecord(value) || !Array.isArray(value.lines) || typeof value.path !== "string") return null;
	const lines = [];
	for (const line of value.lines) {
		if (!isRecord(line) || typeof line.number !== "number" || typeof line.text !== "string") return null;
		lines.push({
			number: line.number,
			text: line.text
		});
	}
	return {
		kind: "read",
		label: value.path,
		lang: typeof value.lang === "string" ? value.lang : null,
		lines,
		totalLines: typeof value.totalLines === "number" ? value.totalLines : lines.length
	};
}
function validDiffs(value) {
	if (!Array.isArray(value)) return null;
	const diffs = [];
	for (const diff of value) {
		if (!isRecord(diff) || typeof diff.path !== "string" || typeof diff.newText !== "string") return null;
		if (diff.oldText !== null && typeof diff.oldText !== "string") return null;
		diffs.push({
			path: diff.path,
			oldText: diff.oldText,
			newText: diff.newText
		});
	}
	return diffs;
}
function diffFromArgs(name, args) {
	const path = stringArg(args, "file_path", "path");
	if (path === null) return null;
	if (name === "write" && typeof args.content === "string") return {
		kind: "diff",
		diffs: [{
			path,
			oldText: null,
			newText: args.content
		}]
	};
	if (name === "edit" && typeof args.old_string === "string" && typeof args.new_string === "string") return {
		kind: "diff",
		diffs: [{
			path,
			oldText: args.old_string,
			newText: args.new_string
		}]
	};
	return null;
}
function presentationOf(pair, rawText, exitCode, signal) {
	const call = isRecord(pair.callView) ? pair.callView : null;
	const result = isRecord(pair.resultView) ? pair.resultView : null;
	if (result?.card === "terminal" || pair.result === null && call?.card === "terminal" || pair.name === "bash") return {
		kind: "terminal",
		command: typeof result?.title === "string" ? result.title : typeof call?.title === "string" ? call.title : commandOf(pair.args),
		cwd: typeof call?.cwd === "string" ? call.cwd : stringArg(pair.args, "workdir", "cwd"),
		output: typeof result?.output === "string" ? result.output : rawText,
		exitCode,
		signal,
		running: pair.result === null
	};
	const read = validReadPresentation(result) ?? validReadMeta(pair.meta);
	if (read !== null) return read;
	const resultDiffs = result?.card === "diff" ? validDiffs(result.diffs) : null;
	const callDiffs = call?.card === "diff" ? validDiffs(call.diffs) : null;
	const diffs = resultDiffs ?? callDiffs;
	if (diffs !== null) return {
		kind: "diff",
		diffs
	};
	const argDiff = diffFromArgs(pair.name, pair.args);
	if (argDiff !== null) return argDiff;
	if (result !== null && result.card !== "generic") return {
		kind: "json",
		data: result
	};
	if (isRecord(pair.meta) || Array.isArray(pair.meta)) return {
		kind: "json",
		data: pair.meta
	};
	const parsed = parseJsonCandidate(rawText);
	if (parsed !== null) return {
		kind: "json",
		data: parsed
	};
	if (rawText !== "") return {
		kind: "text",
		text: rawText
	};
	return { kind: "empty" };
}
function recognizedResultView(value) {
	if (!isRecord(value) || typeof value.card !== "string") return false;
	return (/* @__PURE__ */ new Set([
		"generic",
		"terminal",
		"diff",
		"search",
		"read",
		"web"
	])).has(value.card);
}
function statusOfTool(pair, exitCode, signal) {
	if (pair.result === null) return "running";
	if (errorFlagOf(pair.result) || signal !== null || exitCode !== null && exitCode !== 0) return "failure";
	if (exitCode === 0) return "success";
	const domain = domainOutcomeOf(pair.meta, pair.resultView, pair.result);
	if (domain !== null) return domain;
	if (recognizedResultView(pair.resultView)) return "success";
	if (pair.orphan && pair.name === "") return "unknown";
	return "returned";
}
function mutableIntent(name) {
	return /^(write|edit|apply_patch|imagegen|image_gen)/.test(name);
}
function toolItem(pair) {
	const rawText = pair.result === null ? "" : resultText(pair.result);
	const exitCode = exitCodeOf(pair.resultView, pair.meta, pair.result);
	const signal = signalOf(pair.resultView, pair.meta, pair.result);
	const target = targetOf(pair.name, pair.args);
	const signature = pair.name === "" ? null : normalizedSignature(pair.name, pair.args);
	const intentKey = mutableIntent(pair.name) && target !== null ? `${pair.name}\u0000${target}` : null;
	const status = statusOfTool(pair, exitCode, signal);
	return {
		id: `tool:${pair.callId}`,
		seq: pair.seq,
		resultSeq: pair.resultSeq,
		time: pair.time,
		resultTime: pair.resultTime,
		turn: pair.turn,
		step: pair.step,
		source: "tool",
		phase: phaseOfTool(pair.name, pair.args, pair.callView),
		status,
		title: pair.orphan && pair.name === "" ? `未配对结果 ${pair.callId}` : titleOfTool(pair.name, pair.args, pair.callView),
		subtitle: subtitleOfTool(pair.name, pair.args, target),
		toolName: pair.name || null,
		callId: pair.callId,
		args: pair.args,
		argsRaw: pair.argsRaw || null,
		rawText,
		rawValue: pair.meta ?? pair.result,
		presentation: presentationOf(pair, rawText, exitCode, signal),
		durationMs: pair.resultTime === null ? null : Math.max(0, pair.resultTime - pair.time),
		exitCode,
		signal,
		signature,
		intentKey,
		target,
		retryOf: null,
		retryIndex: 0,
		iterationIndex: 0,
		recoveredBy: null
	};
}
function contentText(value) {
	if (!Array.isArray(value)) return "";
	return value.flatMap((block) => isRecord(block) && block.type === "text" && typeof block.text === "string" ? [block.text] : []).join("\n");
}
function messageItem(node, coordinates, source, text) {
	const phase = source === "user" ? "request" : source === "steering" ? "steering" : "answer";
	const title = source === "user" ? "用户提出任务" : source === "steering" ? "用户补充要求" : "完成回复";
	const clean = text.replace(/\s+/g, " ").trim();
	return {
		id: `${source}:${node.seq}`,
		seq: node.seq,
		resultSeq: null,
		time: node.time,
		resultTime: null,
		turn: coordinates.turn,
		step: coordinates.step,
		source,
		phase,
		status: "returned",
		title,
		subtitle: clean.length > 76 ? `${clean.slice(0, 73)}…` : clean,
		toolName: null,
		callId: null,
		args: {},
		argsRaw: null,
		rawText: text,
		rawValue: text,
		presentation: text === "" ? { kind: "empty" } : {
			kind: "text",
			text
		},
		durationMs: null,
		exitCode: null,
		signal: null,
		signature: null,
		intentKey: null,
		target: null,
		retryOf: null,
		retryIndex: 0,
		iterationIndex: 0,
		recoveredBy: null
	};
}
function imageItems(node, coordinates) {
	const items = [];
	let imageIndex = 0;
	for (const block of node.blocks) {
		if (block.kind !== "image") continue;
		imageIndex++;
		items.push({
			id: `artifact:${node.seq}:${imageIndex}`,
			seq: node.seq + imageIndex / 1e3,
			resultSeq: null,
			time: node.time,
			resultTime: null,
			turn: coordinates.turn,
			step: coordinates.step,
			source: "artifact",
			phase: "build",
			status: "success",
			title: "生成图片",
			subtitle: `图片附件 ${imageIndex}`,
			toolName: null,
			callId: null,
			args: {},
			argsRaw: null,
			rawText: "",
			rawValue: block.attachment,
			presentation: {
				kind: "image",
				attachment: block.attachment
			},
			durationMs: null,
			exitCode: null,
			signal: null,
			signature: null,
			intentKey: null,
			target: null,
			retryOf: null,
			retryIndex: 0,
			iterationIndex: 0,
			recoveredBy: null
		});
	}
	return items;
}
function turnStateItem(seq, time, coordinates, status, message) {
	return {
		id: `turn:${seq}`,
		seq,
		resultSeq: null,
		time,
		resultTime: null,
		turn: coordinates.turn,
		step: coordinates.step,
		source: "turn",
		phase: "failure",
		status,
		title: status === "interrupted" ? "本轮已中断" : "本轮失败",
		subtitle: message,
		toolName: null,
		callId: null,
		args: {},
		argsRaw: null,
		rawText: message,
		rawValue: message,
		presentation: {
			kind: "text",
			text: message
		},
		durationMs: null,
		exitCode: null,
		signal: null,
		signature: null,
		intentKey: null,
		target: null,
		retryOf: null,
		retryIndex: 0,
		iterationIndex: 0,
		recoveredBy: null
	};
}
function interactionItem(id, seq, time, coordinates, status, subtitle, durationMs, rawValue) {
	return {
		id: `interaction:${id}`,
		seq,
		resultSeq: null,
		time,
		resultTime: durationMs === null ? null : time + durationMs,
		turn: coordinates.turn,
		step: coordinates.step,
		source: "interaction",
		phase: "wait",
		status,
		title: status === "waiting" ? "等待你决定" : "你已作决定",
		subtitle,
		toolName: null,
		callId: null,
		args: {},
		argsRaw: null,
		rawText: safeStringify(rawValue),
		rawValue,
		presentation: isRecord(rawValue) ? {
			kind: "json",
			data: rawValue
		} : {
			kind: "text",
			text: String(rawValue)
		},
		durationMs,
		exitCode: null,
		signal: null,
		signature: null,
		intentKey: null,
		target: null,
		retryOf: null,
		retryIndex: 0,
		iterationIndex: 0,
		recoveredBy: null
	};
}
function modelItem(trace) {
	const attempt = trace.attempts.at(-1);
	const running = attempt?.kind === "running";
	const interrupted = attempt?.kind === "interrupted";
	const resultTime = attempt === void 0 || running ? null : attempt.endedAt;
	const time = trace.startTime ?? attempt?.firstTokenTime ?? attempt?.firstReasoningTime ?? resultTime ?? 0;
	return {
		id: `model:${trace.turn}:${trace.step}`,
		seq: trace.startSeq,
		resultSeq: running ? null : trace.lastSeq,
		time,
		resultTime,
		turn: trace.turn,
		step: trace.step,
		source: "model",
		phase: "model",
		status: running ? "running" : interrupted ? "interrupted" : "returned",
		title: running ? "模型正在生成" : "模型响应",
		subtitle: hasReasoningEvidence(trace) ? "包含可见推理记录" : "模型活动记录",
		toolName: null,
		callId: null,
		args: {},
		argsRaw: null,
		rawText: "",
		rawValue: trace,
		presentation: { kind: "empty" },
		durationMs: resultTime === null ? null : Math.max(0, resultTime - time),
		exitCode: null,
		signal: null,
		signature: null,
		intentKey: null,
		target: null,
		retryOf: null,
		retryIndex: 0,
		iterationIndex: 0,
		recoveredBy: null
	};
}
function withModelPlaceholders(items, traces) {
	const occupied = new Set(items.map((item) => `${item.turn}:${item.step}`));
	const next = [...items];
	for (const trace of traces) if (!occupied.has(`${trace.turn}:${trace.step}`)) next.push(modelItem(trace));
	return next;
}
function coordinatesOfLocation(value) {
	if (!isRecord(value)) return null;
	if (value.kind === "step") {
		const turn = recordAt(value, "turn");
		const step = recordAt(value, "step");
		if (typeof turn?.turn === "number" && typeof step?.step === "number") return {
			turn: turn.turn,
			step: step.step
		};
	}
	if (value.kind === "turn") {
		const turn = recordAt(value, "turn");
		if (typeof turn?.turn === "number") return {
			turn: turn.turn,
			step: 0
		};
	}
	return null;
}
function snapshotLocations(snapshot) {
	const locations = /* @__PURE__ */ new Map();
	const trajectory = snapshot.views.get("trajectory");
	if (isRecord(trajectory) && trajectory.eventLocations instanceof Map) for (const [seq, location] of trajectory.eventLocations) {
		if (typeof seq !== "number") continue;
		const coordinates = coordinatesOfLocation(location);
		if (coordinates !== null) locations.set(seq, coordinates);
	}
	for (const turnNumber of snapshot.chat.timeline.turnOrder) {
		const turn = snapshot.chat.timeline.turns.get(turnNumber);
		if (turn === void 0) continue;
		for (const step of turn.steps) for (const key of snapshot.chat.locations.getStep(turnNumber, step.step)) {
			const node = snapshot.chat.nodes.get(key);
			if (node === void 0) continue;
			const coordinates = {
				turn: turnNumber,
				step: step.step
			};
			if (!locations.has(node.anchorSeq)) locations.set(node.anchorSeq, coordinates);
			const root = recordAt(recordAt(node, "data"), "root");
			const resultSeq = root?.kind === "tool-result" ? numberAt(root, "seq") : null;
			if (resultSeq !== null && !locations.has(resultSeq)) locations.set(resultSeq, coordinates);
		}
	}
	return locations;
}
function trajectoryNodes(snapshot) {
	const trajectory = snapshot.views.get("trajectory");
	if (isRecord(trajectory) && Array.isArray(trajectory.eventNodes)) return trajectory.eventNodes;
	return snapshot.nodes;
}
function pairFromSettled(node) {
	const argsRaw = node.call?.argsRaw ?? "";
	return {
		callId: node.callId,
		seq: node.callTime === null ? node.seq : node.seq - .5,
		resultSeq: node.seq,
		time: node.callTime ?? node.time,
		resultTime: node.time,
		turn: 0,
		step: 0,
		name: node.call?.name ?? "",
		args: parseArgs(argsRaw),
		argsRaw,
		result: {
			content: node.content,
			isError: node.isError,
			error: node.error
		},
		meta: node.meta,
		callView: null,
		resultView: null,
		orphan: node.call === null
	};
}
function pairFromRunning(call, index) {
	return {
		callId: call.callId,
		seq: Number.MAX_SAFE_INTEGER - 1e3 + index,
		resultSeq: null,
		time: call.time,
		resultTime: null,
		turn: call.turn,
		step: call.step,
		name: call.name,
		args: parseArgs(call.argsRaw),
		argsRaw: call.argsRaw,
		result: null,
		meta: null,
		callView: null,
		resultView: null,
		orphan: false
	};
}
/** Public RC1 Session/Conversation projection to occurrence-preserving tool pairs. */
function pairsFromSnapshot(snapshot) {
	const locations = snapshotLocations(snapshot);
	const pairs = [];
	for (const node of trajectoryNodes(snapshot)) {
		if (node.kind !== "tool-result") continue;
		const pair = pairFromSettled(node);
		const coordinates = locations.get(node.seq);
		pair.turn = coordinates?.turn ?? 0;
		pair.step = coordinates?.step ?? 0;
		pairs.push(pair);
	}
	snapshot.runningCalls.forEach((call, index) => pairs.push(pairFromRunning(call, index)));
	pairs.sort((left, right) => left.seq - right.seq || left.time - right.time);
	return pairs;
}
function snapshotItems(snapshot) {
	const locations = snapshotLocations(snapshot);
	const items = pairsFromSnapshot(snapshot).map(toolItem);
	for (const node of trajectoryNodes(snapshot)) {
		const coordinates = locations.get(node.seq) ?? {
			turn: "turn" in node ? node.turn : 0,
			step: "step" in node ? node.step : 0
		};
		if (node.kind === "user") {
			if (stringAt(node.source, "kind") !== "user") continue;
			const text = contentText(node.content);
			if (text !== "") items.push(messageItem(node, coordinates, "user", text));
		} else if (node.kind === "steering") {
			const text = contentText(node.content);
			if (text !== "") items.push(messageItem(node, coordinates, "steering", text));
		} else if (node.kind === "assistant") {
			const hasTool = node.blocks.some((block) => block.kind === "tool-call");
			const text = node.blocks.flatMap((block) => block.kind === "text" ? [block.text] : []).join("\n");
			if (!hasTool && text.trim() !== "") items.push(messageItem(node, coordinates, "assistant", text));
			items.push(...imageItems(node, coordinates));
			if (node.interrupted === true) items.push(turnStateItem(node.seq + .9, node.time, coordinates, "interrupted", "Agent 输出在完成前停止"));
		} else if (node.kind === "turn-error") items.push(turnStateItem(node.seq, node.time, coordinates, "failure", node.message));
		else if (node.kind === "turn-max-tokens") items.push(turnStateItem(node.seq, node.time, coordinates, "interrupted", "达到本轮输出上限"));
	}
	const latestTurn = snapshot.chat.timeline.turnOrder.at(-1) ?? 0;
	const latestStep = snapshot.chat.timeline.turns.get(latestTurn)?.steps.at(-1)?.step ?? 0;
	snapshot.pending.forEach((pending, index) => {
		const name = pending.kind === "approval" ? "等待批准" : "等待回答问题";
		items.push(interactionItem(pending.key, Number.MAX_SAFE_INTEGER - 100 + index, Date.now(), {
			turn: latestTurn,
			step: latestStep
		}, "waiting", name, null, pending));
	});
	return withModelPlaceholders(items, snapshot.chat.timeline.turnOrder.flatMap((turn) => snapshot.chat.timeline.turns.get(turn)?.steps.flatMap((step) => {
		const model = step.data.get("dsh-watcher-model-stage");
		return model === void 0 ? [] : [model];
	}) ?? [])).sort((left, right) => left.seq - right.seq || left.time - right.time);
}
function withPatterns(items) {
	const next = items.map((item) => ({ ...item }));
	const lastBySignature = /* @__PURE__ */ new Map();
	const lastByIntent = /* @__PURE__ */ new Map();
	for (let index = 0; index < next.length; index++) {
		const item = next[index];
		if (item === void 0) continue;
		if (item.signature !== null) {
			const previousIndex = lastBySignature.get(item.signature);
			const previous = previousIndex === void 0 ? void 0 : next[previousIndex];
			if (previous !== void 0 && (previous.status === "failure" || previous.status === "unknown")) {
				item.retryOf = previous.id;
				item.retryIndex = previous.retryIndex + 1;
			}
			if (item.status === "success" && previous !== void 0 && previous.status === "failure") previous.recoveredBy = item.id;
			lastBySignature.set(item.signature, index);
		}
		if (item.intentKey !== null) {
			const previousIndex = lastByIntent.get(item.intentKey);
			const previous = previousIndex === void 0 ? void 0 : next[previousIndex];
			if (previous !== void 0 && previous.signature !== item.signature) item.iterationIndex = previous.iterationIndex + 1;
			lastByIntent.set(item.intentKey, index);
		}
	}
	return next;
}
function phasePriority(phase) {
	return {
		wait: 100,
		steering: 95,
		request: 90,
		failure: 85,
		activate: 80,
		verify: 70,
		build: 60,
		desktop: 55,
		investigate: 50,
		plan: 40,
		answer: 30,
		model: 25,
		other: 0
	}[phase];
}
function statusOfItems(items) {
	if (items.some((item) => item.status === "waiting")) return "waiting";
	if (items.some((item) => item.status === "running")) return "running";
	if (items.some((item) => item.status === "interrupted")) return "interrupted";
	if (items.some((item) => item.status === "failure" && item.recoveredBy === null)) return "failure";
	if (items.some((item) => item.status === "success")) return "success";
	if (items.some((item) => item.status === "returned")) return "returned";
	return "unknown";
}
function phaseTitle(phase) {
	return {
		request: "理解任务",
		steering: "接收用户补充",
		plan: "规划工作",
		investigate: "检查与理解",
		build: "修改实现",
		verify: "验证结果",
		activate: "激活插件",
		desktop: "操作界面",
		answer: "完成回复",
		model: "模型响应",
		wait: "等待你决定",
		failure: "处理异常",
		other: "执行其他工作"
	}[phase];
}
function compactTargets(items) {
	const values = [...new Set(items.map((item) => item.target).filter((value) => value !== null))];
	if (values.length === 0) return "";
	const head = values.slice(0, 2).map(baseName).join(" · ");
	return values.length > 2 ? `${head} · +${values.length - 2}` : head;
}
function stepOf(items, timing, model) {
	const first = items[0];
	if (first === void 0) throw new Error("work step requires at least one item");
	const phase = items.reduce((winner, item) => phasePriority(item.phase) > phasePriority(winner) ? item.phase : winner, first.phase);
	const executionCount = items.filter((item) => item.source === "tool").length;
	const parallel = executionCount > 1;
	const retryCount = items.filter((item) => item.retryOf !== null).length;
	const iterationCount = items.filter((item) => item.iterationIndex > 0).length;
	const unconfirmedFailureCount = items.filter((item) => item.status === "failure" && item.recoveredBy === null).length;
	const targets = compactTargets(items);
	const title = items.length === 1 ? first.title : `${phaseTitle(phase)}${parallel ? ` · ${executionCount} 项并行` : ""}`;
	const detail = [targets, executionCount > 0 ? `${executionCount} 次执行` : `${items.length} 条记录`].filter(Boolean).join(" · ");
	return {
		id: `turn:${first.turn}:step:${first.step}:seq:${first.seq}`,
		turn: first.turn,
		step: first.step,
		phase,
		status: statusOfItems(items),
		title,
		subtitle: detail,
		items,
		parallel,
		executionCount,
		retryCount,
		iterationCount,
		unconfirmedFailureCount,
		firstSeq: first.seq,
		lastSeq: items.at(-1)?.seq ?? first.seq,
		...timing,
		model
	};
}
function stepsOf(items, timingOf, modelOf) {
	const steps = [];
	let current = [];
	let key = "";
	for (const item of items) {
		const itemKey = `${item.turn}:${item.step}`;
		if (current.length > 0 && itemKey !== key) {
			const first = current[0];
			if (first !== void 0) steps.push(stepOf(current, timingOf?.(first.turn, first.step) ?? {
				startTime: null,
				endTime: null
			}, modelOf?.(first.turn, first.step) ?? null));
			current = [];
		}
		key = itemKey;
		current.push(item);
	}
	if (current.length > 0) {
		const first = current[0];
		if (first !== void 0) steps.push(stepOf(current, timingOf?.(first.turn, first.step) ?? {
			startTime: null,
			endTime: null
		}, modelOf?.(first.turn, first.step) ?? null));
	}
	return steps;
}
function groupOf(steps) {
	const first = steps[0];
	if (first === void 0) throw new Error("work group requires at least one step");
	const items = steps.flatMap((step) => step.items);
	const executionCount = steps.reduce((sum, step) => sum + step.executionCount, 0);
	const parallelStepCount = steps.filter((step) => step.parallel).length;
	const retryCount = steps.reduce((sum, step) => sum + step.retryCount, 0);
	const iterationCount = steps.reduce((sum, step) => sum + step.iterationCount, 0);
	const unconfirmedFailureCount = steps.reduce((sum, step) => sum + step.unconfirmedFailureCount, 0);
	const summary = [
		`${steps.length} 个步骤`,
		executionCount > 0 ? `${executionCount} 次执行` : null,
		parallelStepCount > 0 ? `${parallelStepCount} 次并行` : null
	].filter((part) => part !== null).join(" · ");
	return {
		id: `turn:${first.turn}:phase:${first.phase}:seq:${first.firstSeq}`,
		turn: first.turn,
		phase: first.phase,
		status: statusOfItems(items),
		title: phaseTitle(first.phase),
		subtitle: summary,
		steps,
		items,
		executionCount,
		parallelStepCount,
		retryCount,
		iterationCount,
		unconfirmedFailureCount,
		firstSeq: first.firstSeq,
		lastSeq: steps.at(-1)?.lastSeq ?? first.lastSeq,
		startTime: first.startTime,
		endTime: steps.at(-1)?.endTime ?? null
	};
}
function groupsOf(steps) {
	const groups = [];
	let current = [];
	let phase = null;
	let turn = null;
	for (const step of steps) {
		if (current.length > 0 && (step.phase !== phase || step.turn !== turn)) {
			groups.push(groupOf(current));
			current = [];
		}
		phase = step.phase;
		turn = step.turn;
		current.push(step);
	}
	if (current.length > 0) groups.push(groupOf(current));
	return groups;
}
function turnTimesFromSnapshot(snapshot, turn) {
	const location = snapshot.chat.timeline.turns.get(turn);
	const timing = snapshot.turnTimings.get(turn);
	return {
		startTime: location?.start?.time ?? timing?.startTime ?? null,
		endTime: location?.end?.time ?? timing?.endTime ?? null
	};
}
function stepTimesFromSnapshot(snapshot, turn, step) {
	const location = snapshot.chat.timeline.turns.get(turn)?.steps.find((value) => value.step === step);
	return {
		startTime: location?.start?.time ?? null,
		endTime: location?.end?.time ?? null
	};
}
function stepModelFromSnapshot(snapshot, turn, step) {
	return snapshot.chat.timeline.turns.get(turn)?.steps.find((value) => value.step === step)?.data.get("dsh-watcher-model-stage") ?? null;
}
function pictureOf(sourceItems, options) {
	if (sourceItems.length === 0) return {
		...EMPTY_PICTURE,
		running: options.running,
		partialHistory: options.partialHistory,
		pendingCount: options.pendingCount
	};
	const occupiedSteps = new Set(sourceItems.filter((item) => item.source !== "model").map((item) => `${item.turn}:${item.step}`));
	const items = withPatterns([...sourceItems.filter((item) => item.source !== "model" || !occupiedSteps.has(`${item.turn}:${item.step}`))].sort((left, right) => left.turn - right.turn || left.step - right.step || left.seq - right.seq || left.time - right.time));
	const steps = stepsOf(items, options.stepTimes, options.modelOf);
	const groups = groupsOf(steps);
	const turns = [];
	for (const turnNumber of [...new Set(groups.map((group) => group.turn))]) {
		const turnGroups = groups.filter((group) => group.turn === turnNumber);
		const timing = options.turnTimes?.(turnNumber) ?? {
			startTime: null,
			endTime: null
		};
		turns.push({
			turn: turnNumber,
			status: statusOfItems(turnGroups.flatMap((group) => group.items)),
			groups: turnGroups,
			...timing
		});
	}
	const latest = items.at(-1);
	return {
		nodes: groups,
		turns,
		now: latest === void 0 ? EMPTY_NOW : {
			phase: latest.phase,
			label: latest.status === "running" ? latest.title : options.running ? "等待 Agent 继续" : latest.title,
			status: latest.status === "running" ? "running" : options.running ? "running" : latest.status
		},
		actionCount: items.filter((item) => item.source === "tool").length,
		stepCount: steps.length,
		turnCount: turns.length,
		parallelStepCount: steps.filter((step) => step.parallel).length,
		retryCount: items.filter((item) => item.retryOf !== null).length,
		iterationCount: items.filter((item) => item.iterationIndex > 0).length,
		pendingCount: options.pendingCount,
		unconfirmedFailureCount: items.filter((item) => item.status === "failure" && item.recoveredBy === null).length,
		running: options.running,
		partialHistory: options.partialHistory
	};
}
/** Fold the official RC8 snapshot without flattening Turn/Step identity. */
function foldSnapshot(snapshot, options = {}) {
	if (snapshot.blank) return {
		...EMPTY_PICTURE,
		running: options.running === true || snapshot.running,
		partialHistory: snapshot.hasMore
	};
	return pictureOf(snapshotItems(snapshot), {
		running: options.running === true || snapshot.running,
		partialHistory: snapshot.hasMore,
		pendingCount: snapshot.pending.length,
		turnTimes: (turn) => turnTimesFromSnapshot(snapshot, turn),
		stepTimes: (turn, step) => stepTimesFromSnapshot(snapshot, turn, step),
		modelOf: (turn, step) => stepModelFromSnapshot(snapshot, turn, step)
	});
}
function itemsOfPicture(picture) {
	return picture.nodes.flatMap((group) => group.items);
}
function turnTimesOfPicture(picture) {
	return new Map(picture.turns.map((turn) => [turn.turn, {
		startTime: turn.startTime,
		endTime: turn.endTime
	}]));
}
function stepTimesOfPicture(picture) {
	return new Map(picture.nodes.flatMap((group) => group.steps.map((step) => [`${step.turn}:${step.step}`, {
		startTime: step.startTime,
		endTime: step.endTime
	}])));
}
function stepModelsOfPicture(picture) {
	return new Map(picture.nodes.flatMap((group) => group.steps.flatMap((step) => step.model === null ? [] : [[`${step.turn}:${step.step}`, step.model]])));
}
/**
* Retain every occurrence already observed in this mounted page while the
* official RC8 window advances. Latest evidence wins by stable occurrence id,
* so running → result updates one row instead of duplicating or removing it.
*/
function mergeObservedPictures(previous, current) {
	if (previous.nodes.length === 0) return current;
	if (current.nodes.length === 0) return {
		...previous,
		running: current.running,
		partialHistory: current.partialHistory,
		pendingCount: current.pendingCount
	};
	const items = /* @__PURE__ */ new Map();
	for (const item of itemsOfPicture(previous)) items.set(item.id, item);
	for (const item of itemsOfPicture(current)) items.set(item.id, item);
	const turns = turnTimesOfPicture(previous);
	for (const [turn, timing] of turnTimesOfPicture(current)) {
		const prior = turns.get(turn);
		turns.set(turn, {
			startTime: timing.startTime ?? prior?.startTime ?? null,
			endTime: timing.endTime ?? prior?.endTime ?? null
		});
	}
	const steps = stepTimesOfPicture(previous);
	for (const [key, timing] of stepTimesOfPicture(current)) {
		const prior = steps.get(key);
		steps.set(key, {
			startTime: timing.startTime ?? prior?.startTime ?? null,
			endTime: timing.endTime ?? prior?.endTime ?? null
		});
	}
	const models = stepModelsOfPicture(previous);
	for (const [key, model] of stepModelsOfPicture(current)) models.set(key, model);
	return pictureOf([...items.values()], {
		running: current.running,
		partialHistory: current.partialHistory,
		pendingCount: current.pendingCount,
		turnTimes: (turn) => turns.get(turn) ?? {
			startTime: null,
			endTime: null
		},
		stepTimes: (turn, step) => steps.get(`${turn}:${step}`) ?? {
			startTime: null,
			endTime: null
		},
		modelOf: (turn, step) => models.get(`${turn}:${step}`) ?? null
	});
}
//#endregion
//#region src/client/Watcher.module.css
var Watcher_module_default = {
	"analysisCluster": "H9LxLa_analysisCluster",
	"analysisClusterChevron": "H9LxLa_analysisClusterChevron",
	"analysisClusterCopy": "H9LxLa_analysisClusterCopy",
	"analysisClusterCount": "H9LxLa_analysisClusterCount",
	"analysisClusterDot": "H9LxLa_analysisClusterDot",
	"analysisClusterDotSlot": "H9LxLa_analysisClusterDotSlot",
	"analysisClusterItems": "H9LxLa_analysisClusterItems",
	"analysisClusterMeta": "H9LxLa_analysisClusterMeta",
	"analysisClusters": "H9LxLa_analysisClusters",
	"analysisClusterTitle": "H9LxLa_analysisClusterTitle",
	"analysisClusterToggle": "H9LxLa_analysisClusterToggle",
	"analysisSingleton": "H9LxLa_analysisSingleton",
	"artifactGlyph": "H9LxLa_artifactGlyph",
	"artifactResult": "H9LxLa_artifactResult",
	"copyRaw": "H9LxLa_copyRaw",
	"detailEmpty": "H9LxLa_detailEmpty",
	"detailHeader": "H9LxLa_detailHeader",
	"detailIdentity": "H9LxLa_detailIdentity",
	"detailSection": "H9LxLa_detailSection",
	"detailStatus": "H9LxLa_detailStatus",
	"documentResult": "H9LxLa_documentResult",
	"empty": "H9LxLa_empty",
	"emptyEye": "H9LxLa_emptyEye",
	"executionList": "H9LxLa_executionList",
	"executionSection": "H9LxLa_executionSection",
	"eye": "H9LxLa_eye",
	"eyeBlink": "H9LxLa_eyeBlink",
	"eyebrow": "H9LxLa_eyebrow",
	"eyePupil": "H9LxLa_eyePupil",
	"follow": "H9LxLa_follow",
	"groupBadges": "H9LxLa_groupBadges",
	"groupedModelChevron": "H9LxLa_groupedModelChevron",
	"groupedModelList": "H9LxLa_groupedModelList",
	"groupedModelStages": "H9LxLa_groupedModelStages",
	"groupedModelStep": "H9LxLa_groupedModelStep",
	"groupedModelStepLabel": "H9LxLa_groupedModelStepLabel",
	"groupedModelToggle": "H9LxLa_groupedModelToggle",
	"groupRail": "H9LxLa_groupRail",
	"groupSignals": "H9LxLa_groupSignals",
	"historyNotice": "H9LxLa_historyNotice",
	"historyNoticeCopy": "H9LxLa_historyNoticeCopy",
	"inspector": "H9LxLa_inspector",
	"inspectorBack": "H9LxLa_inspectorBack",
	"inspectorBody": "H9LxLa_inspectorBody",
	"inspectorFooter": "H9LxLa_inspectorFooter",
	"inspectorHeader": "H9LxLa_inspectorHeader",
	"inspectorSummary": "H9LxLa_inspectorSummary",
	"inspectorTitle": "H9LxLa_inspectorTitle",
	"jsonSurface": "H9LxLa_jsonSurface",
	"loadAllInlineBtn": "H9LxLa_loadAllInlineBtn",
	"location": "H9LxLa_location",
	"menu": "H9LxLa_menu",
	"metrics": "H9LxLa_metrics",
	"modelStage": "H9LxLa_modelStage",
	"modelStageBar": "H9LxLa_modelStageBar",
	"modelStageBody": "H9LxLa_modelStageBody",
	"modelStageChevron": "H9LxLa_modelStageChevron",
	"modelStageCopy": "H9LxLa_modelStageCopy",
	"modelStageGlyph": "H9LxLa_modelStageGlyph",
	"modelStageLedger": "H9LxLa_modelStageLedger",
	"modelStageMetric": "H9LxLa_modelStageMetric",
	"modelStageNote": "H9LxLa_modelStageNote",
	"modelStageSummary": "H9LxLa_modelStageSummary",
	"modelStageSwatch": "H9LxLa_modelStageSwatch",
	"modelStageTitle": "H9LxLa_modelStageTitle",
	"modelStageToggle": "H9LxLa_modelStageToggle",
	"neutralDot": "H9LxLa_neutralDot",
	"now": "H9LxLa_now",
	"nowBlock": "H9LxLa_nowBlock",
	"occurrence": "H9LxLa_occurrence",
	"occurrenceChevron": "H9LxLa_occurrenceChevron",
	"occurrenceCopy": "H9LxLa_occurrenceCopy",
	"occurrenceDuration": "H9LxLa_occurrenceDuration",
	"occurrenceMeta": "H9LxLa_occurrenceMeta",
	"occurrences": "H9LxLa_occurrences",
	"occurrenceTitle": "H9LxLa_occurrenceTitle",
	"overviewOccurrence": "H9LxLa_overviewOccurrence",
	"overviewOccurrenceChevron": "H9LxLa_overviewOccurrenceChevron",
	"overviewOccurrenceCopy": "H9LxLa_overviewOccurrenceCopy",
	"overviewOccurrenceDot": "H9LxLa_overviewOccurrenceDot",
	"overviewOccurrenceDotSlot": "H9LxLa_overviewOccurrenceDotSlot",
	"overviewOccurrenceDuration": "H9LxLa_overviewOccurrenceDuration",
	"overviewOccurrenceIndex": "H9LxLa_overviewOccurrenceIndex",
	"overviewOccurrenceMeta": "H9LxLa_overviewOccurrenceMeta",
	"overviewOccurrences": "H9LxLa_overviewOccurrences",
	"overviewOccurrenceTitle": "H9LxLa_overviewOccurrenceTitle",
	"overviewStep": "H9LxLa_overviewStep",
	"overviewStepHeader": "H9LxLa_overviewStepHeader",
	"overviewStepLabel": "H9LxLa_overviewStepLabel",
	"overviewStepSignals": "H9LxLa_overviewStepSignals",
	"overviewTag": "H9LxLa_overviewTag",
	"parallelLabel": "H9LxLa_parallelLabel",
	"patternLabel": "H9LxLa_patternLabel",
	"phase": "H9LxLa_phase",
	"phaseChevron": "H9LxLa_phaseChevron",
	"phaseCopy": "H9LxLa_phaseCopy",
	"phaseHeader": "H9LxLa_phaseHeader",
	"phaseMarker": "H9LxLa_phaseMarker",
	"phaseMeta": "H9LxLa_phaseMeta",
	"phaseTitle": "H9LxLa_phaseTitle",
	"phaseTitleLine": "H9LxLa_phaseTitleLine",
	"phaseToggle": "H9LxLa_phaseToggle",
	"pictureHeader": "H9LxLa_pictureHeader",
	"railLine": "H9LxLa_railLine",
	"railViewport": "H9LxLa_railViewport",
	"rawPanel": "H9LxLa_rawPanel",
	"rawToolbar": "H9LxLa_rawToolbar",
	"reasoningAttempts": "H9LxLa_reasoningAttempts",
	"reasoningBody": "H9LxLa_reasoningBody",
	"reasoningChevron": "H9LxLa_reasoningChevron",
	"reasoningDisclosure": "H9LxLa_reasoningDisclosure",
	"reasoningLabel": "H9LxLa_reasoningLabel",
	"reasoningMeta": "H9LxLa_reasoningMeta",
	"reasoningToggle": "H9LxLa_reasoningToggle",
	"root": "H9LxLa_root",
	"sectionHeading": "H9LxLa_sectionHeading",
	"sessionTiming": "H9LxLa_sessionTiming",
	"sessionTimingMetric": "H9LxLa_sessionTimingMetric",
	"statusLine": "H9LxLa_statusLine",
	"stepBlock": "H9LxLa_stepBlock",
	"stepChevron": "H9LxLa_stepChevron",
	"stepDuration": "H9LxLa_stepDuration",
	"stepHeading": "H9LxLa_stepHeading",
	"stepSignals": "H9LxLa_stepSignals",
	"stepTimeline": "H9LxLa_stepTimeline",
	"stepToggle": "H9LxLa_stepToggle",
	"summary": "H9LxLa_summary",
	"tab": "H9LxLa_tab",
	"tabPanel": "H9LxLa_tabPanel",
	"tabs": "H9LxLa_tabs",
	"trigger": "H9LxLa_trigger",
	"turn": "H9LxLa_turn",
	"turnBody": "H9LxLa_turnBody",
	"turnChevron": "H9LxLa_turnChevron",
	"turnCopy": "H9LxLa_turnCopy",
	"turnDuration": "H9LxLa_turnDuration",
	"turnHeader": "H9LxLa_turnHeader",
	"turnMetric": "H9LxLa_turnMetric",
	"turnMetrics": "H9LxLa_turnMetrics",
	"turnPerformance": "H9LxLa_turnPerformance",
	"turns": "H9LxLa_turns",
	"turnSpeed": "H9LxLa_turnSpeed",
	"turnSummary": "H9LxLa_turnSummary",
	"turnTitle": "H9LxLa_turnTitle",
	"turnTitleLine": "H9LxLa_turnTitleLine",
	"turnToggle": "H9LxLa_turnToggle",
	"unread": "H9LxLa_unread",
	"viewControl": "H9LxLa_viewControl",
	"viewMode": "H9LxLa_viewMode",
	"viewToolbar": "H9LxLa_viewToolbar",
	"viewToolbarLabel": "H9LxLa_viewToolbarLabel",
	"watcher-eye-blink": "H9LxLa_watcher-eye-blink",
	"watcher-eye-scan": "H9LxLa_watcher-eye-scan",
	"watcher-live-append": "H9LxLa_watcher-live-append",
	"watcher-panel-enter": "H9LxLa_watcher-panel-enter",
	"workPicture": "H9LxLa_workPicture"
};
//#endregion
//#region src/insights/presentation.mjs
/** Browser-safe analysis. No agent commands or model calls. */
/** @type {{silenceSeconds:number, reasoningSeconds:number}} */
const DEFAULT_LIMITS = Object.freeze({
	silenceSeconds: 30,
	reasoningSeconds: 90
});
function limitsOf(raw) {
	const safe = (v, fallback) => Number.isFinite(v) && v >= 5 && v <= 3600 ? Math.round(v) : fallback;
	return {
		silenceSeconds: safe(raw?.silenceSeconds, 30),
		reasoningSeconds: safe(raw?.reasoningSeconds, 90)
	};
}
/** @param {any} view @param {number} now @param {{running?:boolean,waiting?:boolean,limits?:{silenceSeconds:number,reasoningSeconds:number}}} options */
function alertsOf(view, now, { running = false, waiting = false, limits = DEFAULT_LIMITS } = {}) {
	if (!view) return [];
	const alerts = (view.findings ?? []).filter((f) => f.turn === view.turn?.number).slice(-3);
	const p = view.pending;
	if (!running || waiting || !p) return alerts;
	const last = p.lastContentAt ?? p.start;
	if (last !== null && now >= last && now - last >= limits.silenceSeconds * 1e3) alerts.push({
		id: "silence",
		kind: "silence",
		turn: p.turn,
		steps: [p.step],
		seqs: [],
		title: `${Math.floor((now - last) / 1e3)} 秒未收到模型内容`,
		detail: "可能是首响应等待、连接或服务端停顿；这不是内部思考时长，也不能据此确定空转。"
	});
	if (p.reasoningFirst !== null && p.reasoningLast !== null && p.reasoningLast - p.reasoningFirst >= limits.reasoningSeconds * 1e3) alerts.push({
		id: "reasoning-span",
		kind: "reasoning-span",
		turn: p.turn,
		steps: [p.step],
		seqs: [],
		title: `本次可见推理采样跨度 ${Math.round((p.reasoningLast - p.reasoningFirst) / 1e3)} 秒`,
		detail: "只按已收到片段的首末时间计算，可能包含片段间等待。时长偏长不是任务质量结论。"
	});
	return alerts;
}
/**
* RC1 follow() can promote a cold Session after its first yielded snapshot.
* Do NOT use follow() to scan sessions, even with early abort.
* list() provides attached projections and cold hints without Agent activation.
* @returns {Promise<{rows: any[], total: number, selected: number}>}
* @param {any} remote
* @param {{signal?:AbortSignal,limit?:number,onProgress?:(value:any)=>void}} options
*/
async function scanSessions(remote, { signal, limit = 30, onProgress = () => {} } = {}) {
	const res = await remote.session.list({}, signal);
	signal?.throwIfAborted();
	const rawItems = res?.value?.items ?? res?.items ?? res;
	if (!Array.isArray(rawItems)) throw new TypeError("Session list response has no items array");
	const unique = [...new Map(rawItems.filter((x) => typeof x.sessionId === "string" && !x.blank).map((x) => [x.sessionId, x])).values()];
	const picked = unique.slice(0, Math.min(100, Math.max(1, limit)));
	const result = {
		rows: picked.map((row) => {
			const candidate = row.projections?.values?.watcherInsights;
			let value = null, error = null;
			if (row.origin === "subagent") error = "直接子代理暂未纳入；避免重复计算继承前缀";
			else if (candidate?.version === 1 && candidate.sessionId === row.sessionId && candidate.totals && Array.isArray(candidate.models) && Array.isArray(candidate.findings)) value = candidate;
			else error = "尚无 Watcher 统计缓存；在加载插件后运行或打开此会话，再刷新统计";
			return {
				sessionId: row.sessionId,
				value,
				error,
				updatedAt: Number(row.updatedAt) || 0
			};
		}),
		total: unique.length,
		selected: picked.length
	};
	onProgress(result);
	return result;
}
//#endregion
//#region src/client/Insights.module.css
var Insights_module_default = {
	"alertActionBtn": "kI5sgq_alertActionBtn",
	"alertCard": "kI5sgq_alertCard",
	"alertCardDanger": "kI5sgq_alertCardDanger",
	"alertCardWarn": "kI5sgq_alertCardWarn",
	"alertLeft": "kI5sgq_alertLeft",
	"alertMainText": "kI5sgq_alertMainText",
	"alertSection": "kI5sgq_alertSection",
	"alertSubText": "kI5sgq_alertSubText",
	"alertTag": "kI5sgq_alertTag",
	"alertTexts": "kI5sgq_alertTexts",
	"arrowIcon": "kI5sgq_arrowIcon",
	"chartAreaBox": "kI5sgq_chartAreaBox",
	"chartAxisLabel": "kI5sgq_chartAxisLabel",
	"chartFoot": "kI5sgq_chartFoot",
	"chartGridLine": "kI5sgq_chartGridLine",
	"chartSvg": "kI5sgq_chartSvg",
	"cockpitHeader": "kI5sgq_cockpitHeader",
	"cockpitSubTitle": "kI5sgq_cockpitSubTitle",
	"cockpitTitleArea": "kI5sgq_cockpitTitleArea",
	"contextTag": "kI5sgq_contextTag",
	"currentModelTag": "kI5sgq_currentModelTag",
	"dayCol": "kI5sgq_dayCol",
	"dayColFill": "kI5sgq_dayColFill",
	"dayEmptyDot": "kI5sgq_dayEmptyDot",
	"dayLabel": "kI5sgq_dayLabel",
	"daySeg": "kI5sgq_daySeg",
	"dayStack": "kI5sgq_dayStack",
	"dayStackWeek": "kI5sgq_dayStackWeek",
	"dlDot": "kI5sgq_dlDot",
	"dlLeft": "kI5sgq_dlLeft",
	"dlName": "kI5sgq_dlName",
	"dlRight": "kI5sgq_dlRight",
	"donutCenterNum": "kI5sgq_donutCenterNum",
	"donutCenterSub": "kI5sgq_donutCenterSub",
	"donutCenterText": "kI5sgq_donutCenterText",
	"donutInspectBar": "kI5sgq_donutInspectBar",
	"donutInspectName": "kI5sgq_donutInspectName",
	"donutInspectTag": "kI5sgq_donutInspectTag",
	"donutInspectVal": "kI5sgq_donutInspectVal",
	"donutLegendList": "kI5sgq_donutLegendList",
	"donutLegendRow": "kI5sgq_donutLegendRow",
	"donutLegendRowActive": "kI5sgq_donutLegendRowActive",
	"donutSvg": "kI5sgq_donutSvg",
	"donutSvgBox": "kI5sgq_donutSvgBox",
	"donutWrap": "kI5sgq_donutWrap",
	"drawerBarTrack": "kI5sgq_drawerBarTrack",
	"drawerMetaRow": "kI5sgq_drawerMetaRow",
	"drawerSliceModel": "kI5sgq_drawerSliceModel",
	"drawerSliceTool": "kI5sgq_drawerSliceTool",
	"drawerTitle": "kI5sgq_drawerTitle",
	"drilldownCloseBtn": "kI5sgq_drilldownCloseBtn",
	"drilldownEmpty": "kI5sgq_drilldownEmpty",
	"drilldownHead": "kI5sgq_drilldownHead",
	"drilldownPanel": "kI5sgq_drilldownPanel",
	"drilldownSub": "kI5sgq_drilldownSub",
	"drilldownTitle": "kI5sgq_drilldownTitle",
	"drilldownTitleGroup": "kI5sgq_drilldownTitleGroup",
	"effortTag": "kI5sgq_effortTag",
	"emptyScan": "kI5sgq_emptyScan",
	"errorAllGoodBox": "kI5sgq_errorAllGoodBox",
	"errorDrillSection": "kI5sgq_errorDrillSection",
	"errorSessionList": "kI5sgq_errorSessionList",
	"errorSessionRow": "kI5sgq_errorSessionRow",
	"headerRightControls": "kI5sgq_headerRightControls",
	"heroBigNum": "kI5sgq_heroBigNum",
	"heroMetaCol": "kI5sgq_heroMetaCol",
	"heroStatsRow": "kI5sgq_heroStatsRow",
	"heroUnit": "kI5sgq_heroUnit",
	"hudBody": "kI5sgq_hudBody",
	"hudBox": "kI5sgq_hudBox",
	"hudHeading": "kI5sgq_hudHeading",
	"hudTop": "kI5sgq_hudTop",
	"hudTopLeft": "kI5sgq_hudTopLeft",
	"hudTopRight": "kI5sgq_hudTopRight",
	"modelTabBar": "kI5sgq_modelTabBar",
	"modelTabBtn": "kI5sgq_modelTabBtn",
	"modelTagText": "kI5sgq_modelTagText",
	"rangeBtn": "kI5sgq_rangeBtn",
	"rangeSwitchGroup": "kI5sgq_rangeSwitchGroup",
	"rankBadge": "kI5sgq_rankBadge",
	"rankBadgeGold": "kI5sgq_rankBadgeGold",
	"rankBar": "kI5sgq_rankBar",
	"rankItem": "kI5sgq_rankItem",
	"rankItemLeft": "kI5sgq_rankItemLeft",
	"rankItemTop": "kI5sgq_rankItemTop",
	"rankList": "kI5sgq_rankList",
	"rankName": "kI5sgq_rankName",
	"rankSubText": "kI5sgq_rankSubText",
	"rankTrack": "kI5sgq_rankTrack",
	"rankValMain": "kI5sgq_rankValMain",
	"roastAction": "kI5sgq_roastAction",
	"roastCategoryBadge": "kI5sgq_roastCategoryBadge",
	"roastDesc": "kI5sgq_roastDesc",
	"roastFooter": "kI5sgq_roastFooter",
	"roastFooterLeft": "kI5sgq_roastFooterLeft",
	"roastGrid": "kI5sgq_roastGrid",
	"roastHead": "kI5sgq_roastHead",
	"roastItem": "kI5sgq_roastItem",
	"roastItemActive": "kI5sgq_roastItemActive",
	"roastTag": "kI5sgq_roastTag",
	"roastTitle": "kI5sgq_roastTitle",
	"roastVal": "kI5sgq_roastVal",
	"scopeBtn": "kI5sgq_scopeBtn",
	"scopeGroup": "kI5sgq_scopeGroup",
	"sessionIdTag": "kI5sgq_sessionIdTag",
	"sessionItemDrawer": "kI5sgq_sessionItemDrawer",
	"sessionItemHead": "kI5sgq_sessionItemHead",
	"sessionItemOpen": "kI5sgq_sessionItemOpen",
	"sessionItemRow": "kI5sgq_sessionItemRow",
	"sessionModelCell": "kI5sgq_sessionModelCell",
	"sessionTableBox": "kI5sgq_sessionTableBox",
	"sessionTableHeader": "kI5sgq_sessionTableHeader",
	"sessionTokenBar": "kI5sgq_sessionTokenBar",
	"sessionTokenCell": "kI5sgq_sessionTokenCell",
	"settingInlineItem": "kI5sgq_settingInlineItem",
	"settingsContainer": "kI5sgq_settingsContainer",
	"settingsDrawer": "kI5sgq_settingsDrawer",
	"settingsDrawerContent": "kI5sgq_settingsDrawerContent",
	"settingsMiniInput": "kI5sgq_settingsMiniInput",
	"settingsMiniSaveBtn": "kI5sgq_settingsMiniSaveBtn",
	"settingsScanBtn": "kI5sgq_settingsScanBtn",
	"settingsSummary": "kI5sgq_settingsSummary",
	"slideDown": "kI5sgq_slideDown",
	"sortBtn": "kI5sgq_sortBtn",
	"statusBad": "kI5sgq_statusBad",
	"statusOk": "kI5sgq_statusOk",
	"statusWarn": "kI5sgq_statusWarn",
	"tableRankNum": "kI5sgq_tableRankNum",
	"tableSortGroup": "kI5sgq_tableSortGroup",
	"tableTitleGroup": "kI5sgq_tableTitleGroup",
	"tagDanger": "kI5sgq_tagDanger",
	"tagWarn": "kI5sgq_tagWarn",
	"tokenStat": "kI5sgq_tokenStat",
	"toolCompoundBox": "kI5sgq_toolCompoundBox",
	"toolCompoundLegend": "kI5sgq_toolCompoundLegend",
	"toolCompoundTrack": "kI5sgq_toolCompoundTrack",
	"toolDrillSection": "kI5sgq_toolDrillSection",
	"toolGridCards": "kI5sgq_toolGridCards",
	"toolMiniCard": "kI5sgq_toolMiniCard",
	"toolMiniDesc": "kI5sgq_toolMiniDesc",
	"toolMiniNum": "kI5sgq_toolMiniNum",
	"toolMiniTitle": "kI5sgq_toolMiniTitle",
	"toolSliceBash": "kI5sgq_toolSliceBash",
	"toolSliceFile": "kI5sgq_toolSliceFile",
	"toolTopList": "kI5sgq_toolTopList",
	"toolTopListTitle": "kI5sgq_toolTopListTitle",
	"vizHead": "kI5sgq_vizHead",
	"vizPanel": "kI5sgq_vizPanel",
	"vizSplitGrid": "kI5sgq_vizSplitGrid",
	"vizSub": "kI5sgq_vizSub",
	"vizTitle": "kI5sgq_vizTitle"
};
//#endregion
//#region src/client/TimingPanel.module.css
var TimingPanel_module_default = {
	"activeVal": "dVZKUa_activeVal",
	"barTrack": "dVZKUa_barTrack",
	"bottleneckText": "dVZKUa_bottleneckText",
	"chartBox": "dVZKUa_chartBox",
	"dot": "dVZKUa_dot",
	"legendGroup": "dVZKUa_legendGroup",
	"legendItem": "dVZKUa_legendItem",
	"legendRow": "dVZKUa_legendRow",
	"liveSpeed": "dVZKUa_liveSpeed",
	"mainTitle": "dVZKUa_mainTitle",
	"modelCluster": "dVZKUa_modelCluster",
	"panelBox": "dVZKUa_panelBox",
	"popIn": "dVZKUa_popIn",
	"popLeft": "dVZKUa_popLeft",
	"popList": "dVZKUa_popList",
	"popover": "dVZKUa_popover",
	"popRight": "dVZKUa_popRight",
	"popRow": "dVZKUa_popRow",
	"popTitle": "dVZKUa_popTitle",
	"pulse": "dVZKUa_pulse",
	"slice": "dVZKUa_slice",
	"sliceBash": "dVZKUa_sliceBash",
	"sliceFile": "dVZKUa_sliceFile",
	"sliceOutput": "dVZKUa_sliceOutput",
	"sliceThink": "dVZKUa_sliceThink",
	"sliceTtft": "dVZKUa_sliceTtft",
	"speedDot": "dVZKUa_speedDot",
	"statusDanger": "dVZKUa_statusDanger",
	"statusOk": "dVZKUa_statusOk",
	"statusPill": "dVZKUa_statusPill",
	"statusWarn": "dVZKUa_statusWarn",
	"titleArea": "dVZKUa_titleArea",
	"toolCluster": "dVZKUa_toolCluster",
	"topRow": "dVZKUa_topRow",
	"totalDuration": "dVZKUa_totalDuration"
};
//#endregion
//#region src/client/TimingPanel.tsx
const duration = (ms) => {
	if (ms < 1e3) return `${Math.round(ms)} ms`;
	if (ms < 6e4) return `${(ms / 1e3).toFixed(1)} 秒`;
	const seconds = Math.round(ms / 1e3);
	return `${Math.floor(seconds / 60)} 分 ${seconds % 60} 秒`;
};
const fmtNum = (n) => new Intl.NumberFormat("zh-CN", { maximumFractionDigits: 0 }).format(n);
function TimingPanel({ stats, scope, tokensPerSecond }) {
	const [hoverSlice, setHoverSlice] = (0, react.useState)(null);
	const [popoverLeft, setPopoverLeft] = (0, react.useState)(0);
	const [arrowLeft, setArrowLeft] = (0, react.useState)(120);
	const chartBoxRef = (0, react.useRef)(null);
	const ttftMs = stats.firstMs ?? 0;
	const thinkMs = stats.reasoningMs ?? 0;
	const modelTotalMs = stats.modelMs ?? 0;
	const outputMs = Math.max(0, modelTotalMs - ttftMs - thinkMs);
	const toolTotalMs = stats.toolMs ?? 0;
	const bashMs = stats.bashMs ?? 0;
	const fileMs = Math.max(0, toolTotalMs - bashMs);
	const combinedMs = modelTotalMs + toolTotalMs;
	const modelPct = combinedMs > 0 ? modelTotalMs / combinedMs * 100 : 50;
	const toolPct = combinedMs > 0 ? toolTotalMs / combinedMs * 100 : 50;
	const ttftSubPct = modelTotalMs > 0 ? Math.min(100, Math.round(ttftMs / modelTotalMs * 100)) : 0;
	const thinkSubPct = modelTotalMs > 0 ? Math.min(100 - ttftSubPct, Math.round(thinkMs / modelTotalMs * 100)) : 0;
	const outputSubPct = modelTotalMs > 0 ? Math.max(0, 100 - ttftSubPct - thinkSubPct) : 0;
	const bashSubPct = toolTotalMs > 0 ? Math.min(100, Math.round(bashMs / toolTotalMs * 100)) : toolTotalMs > 0 ? 100 : 0;
	const fileSubPct = toolTotalMs > 0 ? Math.max(0, 100 - bashSubPct) : 0;
	const totalGenTokens = (stats.output ?? 0) + (stats.reasoning ?? 0);
	const thinkTokenRatio = totalGenTokens > 0 ? Math.round((stats.reasoning ?? 0) / totalGenTokens * 100) : 0;
	const outputTokenRatio = totalGenTokens > 0 ? Math.max(0, 100 - thinkTokenRatio) : 0;
	const samples = stats.firstSamples ?? 0;
	const ttftAvg = samples > 0 ? ttftMs / samples : ttftMs;
	const ttftLabel = samples > 1 ? `平均首响应 ${duration(ttftAvg)} (共 ${samples} 次)` : `首响应 ${duration(ttftMs)}`;
	let bottleneck = "运行正常";
	if (combinedMs > 0) {
		if (bashMs > combinedMs * .4 && bashMs > 1e4) bottleneck = `终端命令占 ${Math.round(bashMs / combinedMs * 100)}%`;
		else if (thinkMs > combinedMs * .4 && thinkMs > 1e4) bottleneck = `深度思考占 ${Math.round(thinkMs / combinedMs * 100)}%`;
		else if (ttftMs > combinedMs * .4 && ttftMs > 8e3) bottleneck = `云端排队占 ${Math.round(ttftMs / combinedMs * 100)}%`;
		else if (modelTotalMs > toolTotalMs) bottleneck = `模型处理占 ${Math.round(modelPct)}%`;
		else bottleneck = `工具执行占 ${Math.round(toolPct)}%`;
	}
	const hasError = (stats.toolErrors ?? 0) > 0;
	const hasRetry = (stats.retries ?? 0) > 0;
	let statusText = "✓ 0 报错 · 0 重试 (稳定)";
	let statusClass = TimingPanel_module_default.statusOk;
	if (hasError && hasRetry) {
		statusText = `! ${stats.toolErrors} 报错 · ${stats.retries} 次重试`;
		statusClass = TimingPanel_module_default.statusDanger;
	} else if (hasError) {
		statusText = `! ${stats.toolErrors} 次工具报错`;
		statusClass = TimingPanel_module_default.statusDanger;
	} else if (hasRetry) {
		statusText = `! ${stats.retries} 次网络重试排队`;
		statusClass = TimingPanel_module_default.statusWarn;
	}
	const handleSliceHover = (slice, e) => {
		setHoverSlice(slice);
		if (chartBoxRef.current) {
			const rect = e.currentTarget.getBoundingClientRect();
			const parentRect = chartBoxRef.current.getBoundingClientRect();
			const sliceCenter = rect.left - parentRect.left + rect.width / 2;
			const popoverWidth = Math.min(360, Math.max(300, parentRect.width - 16));
			const left = Math.max(8, Math.min(parentRect.width - popoverWidth - 8, sliceCenter - popoverWidth / 2));
			setPopoverLeft(left);
			const arrowPos = Math.max(16, Math.min(popoverWidth - 16, sliceCenter - left));
			setArrowLeft(arrowPos);
		}
	};
	return /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
		className: TimingPanel_module_default.panelBox,
		children: [
			/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
				className: TimingPanel_module_default.topRow,
				children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
					className: TimingPanel_module_default.titleArea,
					children: [
						/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
							className: TimingPanel_module_default.mainTitle,
							children: "耗时分布与瓶颈"
						}),
						tokensPerSecond && tokensPerSecond > 0 ? /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
							className: TimingPanel_module_default.liveSpeed,
							title: "当前模型实际流式生成吞吐",
							children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("i", { className: TimingPanel_module_default.speedDot }), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: [tokensPerSecond >= 10 ? Math.round(tokensPerSecond) : tokensPerSecond.toFixed(1), " t/s"] })]
						}) : null,
						/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
							className: TimingPanel_module_default.totalDuration,
							children: [
								scope === "turn" ? "本轮" : "全会话",
								" 耗时 ",
								duration(combinedMs)
							]
						})
					]
				}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
					className: TimingPanel_module_default.bottleneckText,
					children: combinedMs > 0 ? `主要耗时：${bottleneck}` : "暂无耗时记录"
				})]
			}),
			/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
				className: TimingPanel_module_default.chartBox,
				ref: chartBoxRef,
				children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
					className: TimingPanel_module_default.barTrack,
					role: "img",
					"aria-label": "耗时复合柱图",
					children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
						className: TimingPanel_module_default.modelCluster,
						style: { width: `${modelPct}%` },
						children: [
							ttftSubPct > 0 ? /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
								className: `${TimingPanel_module_default.slice} ${TimingPanel_module_default.sliceTtft}`,
								style: { width: `${ttftSubPct}%` },
								onMouseEnter: (e) => handleSliceHover("ttft", e),
								onMouseLeave: () => setHoverSlice(null)
							}) : null,
							thinkSubPct > 0 ? /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
								className: `${TimingPanel_module_default.slice} ${TimingPanel_module_default.sliceThink}`,
								style: { width: `${thinkSubPct}%` },
								onMouseEnter: (e) => handleSliceHover("think", e),
								onMouseLeave: () => setHoverSlice(null)
							}) : null,
							outputSubPct > 0 ? /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
								className: `${TimingPanel_module_default.slice} ${TimingPanel_module_default.sliceOutput}`,
								style: { width: `${outputSubPct}%` },
								onMouseEnter: (e) => handleSliceHover("output", e),
								onMouseLeave: () => setHoverSlice(null)
							}) : null
						]
					}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
						className: TimingPanel_module_default.toolCluster,
						style: { width: `${toolPct}%` },
						children: [bashSubPct > 0 ? /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
							className: `${TimingPanel_module_default.slice} ${TimingPanel_module_default.sliceBash}`,
							style: { width: `${bashSubPct}%` },
							onMouseEnter: (e) => handleSliceHover("bash", e),
							onMouseLeave: () => setHoverSlice(null)
						}) : null, fileSubPct > 0 ? /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
							className: `${TimingPanel_module_default.slice} ${TimingPanel_module_default.sliceFile}`,
							style: { width: `${fileSubPct}%` },
							onMouseEnter: (e) => handleSliceHover("file", e),
							onMouseLeave: () => setHoverSlice(null)
						}) : null]
					})]
				}), hoverSlice ? /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
					className: TimingPanel_module_default.popover,
					style: {
						left: `${popoverLeft}px`,
						["--arrow-left"]: `${arrowLeft}px`
					},
					children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
						className: TimingPanel_module_default.popTitle,
						children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: [
							hoverSlice === "think" && "深度推导阶段 (思考过程)",
							hoverSlice === "ttft" && "首字排队响应 (TTFT)",
							hoverSlice === "output" && "正文流式输出阶段",
							hoverSlice === "bash" && "本地终端命令 (Bash)",
							hoverSlice === "file" && "文件读写与其它工具"
						] }), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: [
							hoverSlice === "think" && `${duration(thinkMs)} (${thinkSubPct}%)`,
							hoverSlice === "ttft" && `${duration(ttftMs)} (${ttftSubPct}%)`,
							hoverSlice === "output" && `${duration(outputMs)} (${outputSubPct}%)`,
							hoverSlice === "bash" && `${duration(bashMs)} (${bashSubPct}%)`,
							hoverSlice === "file" && `${duration(fileMs)} (${fileSubPct}%)`
						] })]
					}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
						className: TimingPanel_module_default.popList,
						children: [
							hoverSlice === "think" && /* @__PURE__ */ (0, react_jsx_runtime.jsxs)(react_jsx_runtime.Fragment, { children: [
								/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: TimingPanel_module_default.popRow,
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
										className: TimingPanel_module_default.popLeft,
										children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("i", {
											className: TimingPanel_module_default.dot,
											style: { background: "var(--c-think)" }
										}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "推导思考总耗时" })]
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
										className: TimingPanel_module_default.popRight,
										children: [
											duration(thinkMs),
											" (占模型 ",
											thinkSubPct,
											"%)"
										]
									})]
								}),
								stats.reasoning ? /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: TimingPanel_module_default.popRow,
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
										className: TimingPanel_module_default.popLeft,
										children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "思考 Token 用量" })
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
										className: TimingPanel_module_default.popRight,
										children: [fmtNum(stats.reasoning), " Token"]
									})]
								}) : null,
								/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: TimingPanel_module_default.popRow,
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
										className: TimingPanel_module_default.popLeft,
										children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "生成算力分配" })
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
										className: TimingPanel_module_default.popRight,
										children: totalGenTokens > 0 ? `思考占 ${thinkTokenRatio}% · 正文占 ${outputTokenRatio}%` : "—"
									})]
								}),
								thinkMs > 0 && stats.reasoning ? /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: TimingPanel_module_default.popRow,
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
										className: TimingPanel_module_default.popLeft,
										children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "推导生成速率" })
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
										className: TimingPanel_module_default.popRight,
										children: [Math.round(stats.reasoning / (thinkMs / 1e3)), " Token/秒"]
									})]
								}) : null,
								/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: TimingPanel_module_default.popRow,
									style: {
										borderTop: "1px dashed rgba(255,255,255,0.15)",
										marginTop: "4px",
										paddingTop: "4px"
									},
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
										className: TimingPanel_module_default.popLeft,
										children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "思考耗时诊断" })
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
										className: TimingPanel_module_default.popRight,
										children: thinkMs > 25e3 ? "推导耗时较长，任务较复杂" : "推导节奏健康，无卡顿停顿"
									})]
								})
							] }),
							hoverSlice === "ttft" && /* @__PURE__ */ (0, react_jsx_runtime.jsxs)(react_jsx_runtime.Fragment, { children: [
								/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: TimingPanel_module_default.popRow,
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
										className: TimingPanel_module_default.popLeft,
										children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("i", {
											className: TimingPanel_module_default.dot,
											style: { background: "var(--c-ttft)" }
										}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "首响应排队延迟" })]
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
										className: TimingPanel_module_default.popRight,
										children: [
											duration(ttftMs),
											" (占模型 ",
											ttftSubPct,
											"%)"
										]
									})]
								}),
								/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: TimingPanel_module_default.popRow,
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
										className: TimingPanel_module_default.popLeft,
										children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "采样统计详情" })
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
										className: TimingPanel_module_default.popRight,
										children: samples > 1 ? `累计 ${samples} 次 (均值 ${(ttftAvg / 1e3).toFixed(2)}s)` : "单次握手"
									})]
								}),
								/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: TimingPanel_module_default.popRow,
									style: {
										borderTop: "1px dashed rgba(255,255,255,0.15)",
										marginTop: "4px",
										paddingTop: "4px"
									},
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
										className: TimingPanel_module_default.popLeft,
										children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "网络排队诊断" })
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
										className: TimingPanel_module_default.popRight,
										children: ttftAvg < 1e3 ? "极度敏捷 (网络与云端极速响应)" : ttftAvg < 3e3 ? "正常 (标准网络往返与握手)" : "排队偏长 (云端并发高或网络延迟)"
									})]
								})
							] }),
							hoverSlice === "output" && /* @__PURE__ */ (0, react_jsx_runtime.jsxs)(react_jsx_runtime.Fragment, { children: [
								/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: TimingPanel_module_default.popRow,
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
										className: TimingPanel_module_default.popLeft,
										children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("i", {
											className: TimingPanel_module_default.dot,
											style: { background: "var(--c-output)" }
										}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "正文与代码耗时" })]
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
										className: TimingPanel_module_default.popRight,
										children: [
											duration(outputMs),
											" (占模型 ",
											outputSubPct,
											"%)"
										]
									})]
								}),
								/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: TimingPanel_module_default.popRow,
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
										className: TimingPanel_module_default.popLeft,
										children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "实付正文输出量" })
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
										className: TimingPanel_module_default.popRight,
										children: [fmtNum(stats.output), " Token"]
									})]
								}),
								/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: TimingPanel_module_default.popRow,
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
										className: TimingPanel_module_default.popLeft,
										children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "实际生成速率" })
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
										className: TimingPanel_module_default.popRight,
										children: tokensPerSecond && tokensPerSecond > 0 ? `${tokensPerSecond >= 10 ? Math.round(tokensPerSecond) : tokensPerSecond.toFixed(1)} Token/秒 (实时)` : outputMs > 0 ? `${Math.round(stats.output / (outputMs / 1e3))} Token/秒 (均值)` : "—"
									})]
								}),
								/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: TimingPanel_module_default.popRow,
									style: {
										borderTop: "1px dashed rgba(255,255,255,0.15)",
										marginTop: "4px",
										paddingTop: "4px"
									},
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
										className: TimingPanel_module_default.popLeft,
										children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "生成算力分配" })
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
										className: TimingPanel_module_default.popRight,
										children: totalGenTokens > 0 ? `正文占 ${outputTokenRatio}% · 思考占 ${thinkTokenRatio}%` : "—"
									})]
								})
							] }),
							hoverSlice === "bash" && /* @__PURE__ */ (0, react_jsx_runtime.jsxs)(react_jsx_runtime.Fragment, { children: [
								/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: TimingPanel_module_default.popRow,
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
										className: TimingPanel_module_default.popLeft,
										children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("i", {
											className: TimingPanel_module_default.dot,
											style: { background: "var(--c-bash)" }
										}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "终端 Bash 总耗时" })]
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
										className: TimingPanel_module_default.popRight,
										children: [
											duration(bashMs),
											" (占工具 ",
											bashSubPct,
											"%)"
										]
									})]
								}),
								/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: TimingPanel_module_default.popRow,
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
										className: TimingPanel_module_default.popLeft,
										children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "占轮次总时间比" })
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
										className: TimingPanel_module_default.popRight,
										children: combinedMs > 0 ? `${Math.round(bashMs / combinedMs * 100)}%` : "0%"
									})]
								}),
								/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: TimingPanel_module_default.popRow,
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
										className: TimingPanel_module_default.popLeft,
										children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "命令可靠度监控" })
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
										className: TimingPanel_module_default.popRight,
										children: [
											stats.tools,
											" 次 (",
											stats.toolErrors > 0 ? `${stats.toolErrors} 次报错中断` : "零非零退出码",
											")"
										]
									})]
								}),
								/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: TimingPanel_module_default.popRow,
									style: {
										borderTop: "1px dashed rgba(255,255,255,0.15)",
										marginTop: "4px",
										paddingTop: "4px"
									},
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
										className: TimingPanel_module_default.popLeft,
										children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "耗时瓶颈归因" })
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
										className: TimingPanel_module_default.popRight,
										children: bashMs > modelTotalMs ? "本地环境为主要瓶颈 (耗时超模型)" : "本地开销极小 (主要耗时在云端)"
									})]
								})
							] }),
							hoverSlice === "file" && /* @__PURE__ */ (0, react_jsx_runtime.jsxs)(react_jsx_runtime.Fragment, { children: [
								/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: TimingPanel_module_default.popRow,
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
										className: TimingPanel_module_default.popLeft,
										children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("i", {
											className: TimingPanel_module_default.dot,
											style: { background: "var(--c-file)" }
										}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "文件读写总耗时" })]
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
										className: TimingPanel_module_default.popRight,
										children: [
											duration(fileMs),
											" (占工具 ",
											fileSubPct,
											"%)"
										]
									})]
								}),
								/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: TimingPanel_module_default.popRow,
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
										className: TimingPanel_module_default.popLeft,
										children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "占轮次总时间比" })
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
										className: TimingPanel_module_default.popRight,
										children: combinedMs > 0 ? `${Math.round(fileMs / combinedMs * 100)}%` : "0%"
									})]
								}),
								/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: TimingPanel_module_default.popRow,
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
										className: TimingPanel_module_default.popLeft,
										children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "单次调用平均耗时" })
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
										className: TimingPanel_module_default.popRight,
										children: [Math.round(fileMs / Math.max(1, stats.tools)), " ms / 次"]
									})]
								}),
								/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: TimingPanel_module_default.popRow,
									style: {
										borderTop: "1px dashed rgba(255,255,255,0.15)",
										marginTop: "4px",
										paddingTop: "4px"
									},
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
										className: TimingPanel_module_default.popLeft,
										children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "文件 IO 评价" })
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
										className: TimingPanel_module_default.popRight,
										children: fileMs < 2e3 ? "毫秒级极速读写，无性能损耗" : "读写较为密集，轻微耗时累积"
									})]
								})
							] })
						]
					})]
				}) : null]
			}),
			/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
				className: TimingPanel_module_default.legendRow,
				children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
					className: TimingPanel_module_default.legendGroup,
					children: [
						/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
							className: TimingPanel_module_default.legendItem,
							children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("i", {
								className: TimingPanel_module_default.dot,
								style: { background: "var(--c-ttft)" }
							}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: ttftLabel })]
						}),
						/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
							className: TimingPanel_module_default.legendItem,
							children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("i", {
								className: TimingPanel_module_default.dot,
								style: { background: "var(--c-think)" }
							}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: ["思考 ", duration(thinkMs)] })]
						}),
						/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
							className: TimingPanel_module_default.legendItem,
							children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("i", {
								className: TimingPanel_module_default.dot,
								style: { background: "var(--c-output)" }
							}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: ["输出 ", duration(outputMs)] })]
						}),
						/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
							className: TimingPanel_module_default.legendItem,
							children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("i", {
								className: TimingPanel_module_default.dot,
								style: { background: "var(--c-bash)" }
							}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: ["工具 ", duration(toolTotalMs)] })]
						})
					]
				}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
					className: `${TimingPanel_module_default.statusPill} ${statusClass}`,
					children: statusText
				})]
			})
		]
	});
}
//#endregion
//#region src/client/Insights.tsx
const scanSessionsTyped = scanSessions;
const STORAGE = "dsh-watcher:insights-display:v1";
function readLimits() {
	try {
		return limitsOf(JSON.parse(localStorage.getItem(STORAGE) ?? "{}"));
	} catch {
		return { ...DEFAULT_LIMITS };
	}
}
function useLimits() {
	const [limits, setLimits] = (0, react.useState)(readLimits);
	(0, react.useEffect)(() => {
		const update = () => setLimits(readLimits());
		window.addEventListener("watcher-insights-settings", update);
		return () => window.removeEventListener("watcher-insights-settings", update);
	}, []);
	return limits;
}
const fmt = (n) => new Intl.NumberFormat("zh-CN", { maximumFractionDigits: 0 }).format(n);
const fmtCompact = (n) => {
	if (!Number.isFinite(n) || n <= 0) return "0";
	if (n >= 1e8) return `${(n / 1e8).toFixed(1)} 亿`;
	if (n >= 1e4) return `${(n / 1e4).toFixed(1)} 万`;
	return fmt(n);
};
const dayKey = (ms) => {
	const d = new Date(ms);
	return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
};
const dayLabel = (key) => {
	const [, m, d] = key.split("-");
	return `${Number(m)}/${Number(d)}`;
};
const PALETTE = [
	"#3b82f6",
	"#8b5cf6",
	"#f59e0b",
	"#10b981",
	"#ec4899",
	"#6366f1"
];
function effortLabel(effort) {
	if (!effort) return "";
	return {
		high: "高",
		medium: "中",
		low: "低"
	}[effort.toLowerCase()] ?? effort;
}
function SessionInsights({ value, now, running, waiting, onEvidence }) {
	const limits = useLimits();
	const [scope, setScope] = (0, react.useState)("turn");
	const [modelFilter, setModelFilter] = (0, react.useState)("all");
	if (!value) return null;
	const isMultiModel = (value.models?.length ?? 0) > 1;
	const selectedModel = scope === "session" && modelFilter !== "all" && value.models[modelFilter] ? value.models[modelFilter] : void 0;
	const stats = scope === "turn" && value.turn ? value.turn.stats : selectedModel ?? value.totals;
	const alerts = alertsOf(value, now, {
		running,
		waiting,
		limits
	});
	const currentRoute = value.turn?.route ?? (value.models && value.models.length > 0 ? value.models[0] : void 0);
	const totalIn = (stats.input ?? 0) + (stats.cacheRead ?? 0);
	const cachePct = totalIn > 0 ? Math.round((stats.cacheRead ?? 0) / totalIn * 100) : 0;
	return /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("section", {
		className: Insights_module_default.hudBox,
		"aria-label": "耗时分布与运行健康度",
		children: [
			/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
				className: Insights_module_default.hudTop,
				children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
					className: Insights_module_default.hudTopLeft,
					children: [
						/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
							className: Insights_module_default.hudHeading,
							children: scope === "turn" ? "本轮" : selectedModel ? `模型: ${selectedModel.model}` : "全会话"
						}),
						scope === "turn" && currentRoute?.model ? /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
							className: Insights_module_default.currentModelTag,
							title: currentRoute.model,
							children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("strong", {
								className: Insights_module_default.modelTagText,
								children: currentRoute.model
							}), currentRoute.effort ? /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
								className: Insights_module_default.effortTag,
								children: ["思考: ", effortLabel(currentRoute.effort)]
							}) : null]
						}) : null,
						/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
							className: Insights_module_default.contextTag,
							children: [
								"上下文 ",
								/* @__PURE__ */ (0, react_jsx_runtime.jsx)("strong", { children: fmt(stats.input ?? 0) }),
								" Token"
							]
						})
					]
				}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
					className: Insights_module_default.hudTopRight,
					children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
						className: Insights_module_default.tokenStat,
						children: [
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("strong", { children: fmt(stats.tokens ?? 0) }),
							" Token (",
							cachePct,
							"% 命中)"
						]
					}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
						className: Insights_module_default.scopeGroup,
						role: "group",
						"aria-label": "统计范围切换",
						children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("button", {
							type: "button",
							className: Insights_module_default.scopeBtn,
							"data-active": scope === "turn" ? "" : void 0,
							onClick: () => {
								setScope("turn");
								setModelFilter("all");
							},
							children: "本轮"
						}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("button", {
							type: "button",
							className: Insights_module_default.scopeBtn,
							"data-active": scope === "session" ? "" : void 0,
							onClick: () => setScope("session"),
							children: "全会话"
						})]
					})]
				})]
			}),
			scope === "session" && isMultiModel ? /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
				className: Insights_module_default.modelTabBar,
				role: "tablist",
				"aria-label": "多模型切换",
				children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("button", {
					type: "button",
					className: Insights_module_default.modelTabBtn,
					"data-active": modelFilter === "all" ? "" : void 0,
					onClick: () => setModelFilter("all"),
					children: [
						"全部模型汇总 (",
						value.models.length,
						")"
					]
				}), value.models.map((m, idx) => /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("button", {
					type: "button",
					className: Insights_module_default.modelTabBtn,
					"data-active": modelFilter === idx ? "" : void 0,
					onClick: () => setModelFilter(idx),
					children: [
						m.model,
						" (",
						m.calls,
						"次)"
					]
				}, idx))]
			}) : null,
			/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
				className: Insights_module_default.hudBody,
				children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)(TimingPanel, {
					stats,
					scope
				}), alerts.length > 0 ? /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
					className: Insights_module_default.alertSection,
					"aria-live": "polite",
					children: alerts.map((a) => {
						const isRepeat = a.kind === "repeated-failure" || a.id.startsWith("repeat");
						const isSilence = a.id === "silence";
						const isReason = a.id === "reasoning-span";
						const tag = isRepeat ? "连续报错" : isSilence ? "网络停顿" : isReason ? "思考超时" : "异常";
						return /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
							className: `${Insights_module_default.alertCard} ${isRepeat ? Insights_module_default.alertCardDanger : Insights_module_default.alertCardWarn}`,
							children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Insights_module_default.alertLeft,
								children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: `${Insights_module_default.alertTag} ${isRepeat ? Insights_module_default.tagDanger : Insights_module_default.tagWarn}`,
									children: tag
								}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: Insights_module_default.alertTexts,
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("strong", {
										className: Insights_module_default.alertMainText,
										children: a.title
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
										className: Insights_module_default.alertSubText,
										children: a.detail
									})]
								})]
							}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("button", {
								type: "button",
								className: Insights_module_default.alertActionBtn,
								onClick: () => onEvidence(a),
								children: "定位现场"
							})]
						}, a.id);
					})
				}) : null]
			})
		]
	});
}
function InsightsSettings(props) {
	const limits = useLimits();
	const [silence, setSilence] = (0, react.useState)(limits.silenceSeconds);
	const [reasoning, setReasoning] = (0, react.useState)(limits.reasoningSeconds);
	const [saved, setSaved] = (0, react.useState)(false);
	const [userPickedRange, setUserPickedRange] = (0, react.useState)(false);
	const [range, setRange] = (0, react.useState)("7");
	const [sessionSort, setSessionSort] = (0, react.useState)("tokens");
	const [loading, setLoading] = (0, react.useState)(false);
	const [sessions, setSessions] = (0, react.useState)(null);
	const [openSessionId, setOpenSessionId] = (0, react.useState)(null);
	const [hoveredIdx, setHoveredIdx] = (0, react.useState)(null);
	const [activeDrilldown, setActiveDrilldown] = (0, react.useState)(null);
	(0, react.useEffect)(() => {
		if (!props.remote) return;
		let active = true;
		setLoading(true);
		scanSessionsTyped(props.remote, { limit: 100 }).then((res) => {
			if (active) {
				setSessions(res);
				if (!userPickedRange) {
					const times = (res?.rows ?? []).map((r) => r.updatedAt).filter((t) => typeof t === "number" && t > 0);
					if (times.length >= 2) {
						if (Math.max(...times) - Math.min(...times) > 6048e5) setRange("30");
					}
				}
			}
		}).catch(console.error).finally(() => {
			if (active) setLoading(false);
		});
		return () => {
			active = false;
		};
	}, [props.remote, userPickedRange]);
	const refresh = () => {
		if (!props.remote || loading) return;
		setLoading(true);
		scanSessionsTyped(props.remote, { limit: 100 }).then(setSessions).catch(console.error).finally(() => setLoading(false));
	};
	const save = () => {
		localStorage.setItem(STORAGE, JSON.stringify({
			silenceSeconds: silence,
			reasoningSeconds: reasoning
		}));
		window.dispatchEvent(new CustomEvent("watcher-insights-settings"));
		setSaved(true);
		setTimeout(() => setSaved(false), 2e3);
	};
	const analytics = (0, react.useMemo)(() => {
		if (!sessions) return null;
		const days = Number(range);
		const cutoff = Date.now() - days * 864e5;
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
		const toolTimePct = totalWallMs > 0 ? Math.round(totalToolMs / totalWallMs * 100) : 0;
		const totalFileMs = Math.max(0, totalToolMs - totalBashMs);
		const bashPct = totalToolMs > 0 ? Math.round(totalBashMs / totalToolMs * 100) : 0;
		const filePct = Math.max(0, 100 - bashPct);
		const totalInAll = totalInput + totalCacheRead;
		const cacheHitPct = totalInAll > 0 ? Math.round(totalCacheRead / totalInAll * 100) : 0;
		const modelMap = /* @__PURE__ */ new Map();
		for (const view of validViews) for (const m of view.models ?? []) {
			const name = m.model || "未标注";
			let row = modelMap.get(name);
			if (!row) {
				row = {
					model: name,
					calls: 0,
					tokens: 0,
					input: 0,
					output: 0,
					cacheRead: 0,
					cacheWrite: 0,
					reasoning: 0,
					modelMs: 0,
					firstMs: 0,
					firstSamples: 0
				};
				modelMap.set(name, row);
			}
			for (const k of [
				"calls",
				"tokens",
				"input",
				"output",
				"cacheRead",
				"cacheWrite",
				"reasoning",
				"modelMs",
				"firstMs",
				"firstSamples"
			]) if (typeof m[k] === "number" && Number.isFinite(m[k])) row[k] += m[k];
		}
		const uniqueModels = [...modelMap.values()];
		const speedList = uniqueModels.filter((m) => (m.firstSamples ?? 0) > 0 && (m.firstMs ?? 0) > 0).sort((a, b) => a.firstMs / a.firstSamples - b.firstMs / b.firstSamples);
		const latencyList = uniqueModels.filter((m) => (m.firstSamples ?? 0) > 0 && (m.firstMs ?? 0) > 0).sort((a, b) => b.firstMs / b.firstSamples - a.firstMs / a.firstSamples);
		const thinkList = uniqueModels.filter((m) => (m.reasoning ?? 0) > 0).sort((a, b) => {
			const ratioA = a.reasoning / ((a.reasoning ?? 0) + (a.output ?? 0) || 1);
			return b.reasoning / ((b.reasoning ?? 0) + (b.output ?? 0) || 1) - ratioA || b.reasoning - a.reasoning;
		});
		const cacheList = uniqueModels.filter((m) => (m.tokens ?? 0) > 0).sort((a, b) => {
			const rateA = (a.cacheRead ?? 0) / ((a.input ?? 0) + (a.cacheRead ?? 0) || 1);
			return (b.cacheRead ?? 0) / ((b.input ?? 0) + (b.cacheRead ?? 0) || 1) - rateA || (b.cacheRead ?? 0) - (a.cacheRead ?? 0);
		});
		const fastKing = speedList[0];
		const slowKing = latencyList[0];
		const thinkKing = thinkList[0];
		const bestCacheModel = cacheList[0];
		const topToolSessions = [...validRows].filter((r) => (r.value?.totals?.toolMs ?? 0) > 0).sort((a, b) => (b.value.totals.toolMs ?? 0) - (a.value.totals.toolMs ?? 0)).slice(0, 3);
		const errorSessions = [...validRows].filter((r) => (r.value?.totals?.toolErrors ?? 0) > 0 || (r.value?.totals?.retries ?? 0) > 0).sort((a, b) => {
			const scoreA = (a.value.totals.toolErrors ?? 0) * 100 + (a.value.totals.retries ?? 0);
			return (b.value.totals.toolErrors ?? 0) * 100 + (b.value.totals.retries ?? 0) - scoreA;
		}).slice(0, 6);
		const sortedSessions = [...validRows].sort((a, b) => {
			const va = a.value.totals;
			const vb = b.value.totals;
			if (sessionSort === "tokens") return (vb.tokens ?? 0) - (va.tokens ?? 0);
			if (sessionSort === "time") {
				const timeA = (va.modelMs ?? 0) + (va.toolMs ?? 0);
				return (vb.modelMs ?? 0) + (vb.toolMs ?? 0) - timeA;
			}
			if (sessionSort === "errors") {
				const scoreA = (va.toolErrors ?? 0) * 100 + (va.retries ?? 0);
				return (vb.toolErrors ?? 0) * 100 + (vb.retries ?? 0) - scoreA || (vb.tokens ?? 0) - (va.tokens ?? 0);
			}
			return (b.updatedAt ?? 0) - (a.updatedAt ?? 0);
		});
		const maxSessionTokens = Math.max(1, ...sortedSessions.map((s) => s.value?.totals?.tokens ?? 0));
		const tokenRankedModels = [...uniqueModels].sort((a, b) => b.tokens - a.tokens);
		const topModels = tokenRankedModels.slice(0, 4);
		const restTokens = tokenRankedModels.slice(4).reduce((sum, m) => sum + (m.tokens ?? 0), 0);
		const donutModels = [...topModels];
		if (restTokens > 0) donutModels.push({
			model: "其他模型",
			tokens: restTokens
		});
		donutModels.sort((a, b) => (b.tokens ?? 0) - (a.tokens ?? 0));
		const donutTotal = donutModels.reduce((sum, m) => sum + (m.tokens ?? 0), 0);
		const colorOf = (name) => {
			const found = donutModels.findIndex((m) => m.model === name);
			return PALETTE[(found >= 0 ? found : 0) % PALETTE.length];
		};
		const circumference = 2 * Math.PI * 38;
		let accumulated = 0;
		const donutSegments = donutTotal <= 0 ? [] : donutModels.map((m, idx) => {
			const pctRatio = m.tokens / donutTotal;
			const strokeLength = idx === donutModels.length - 1 ? Math.max(0, circumference - accumulated) : pctRatio * circumference;
			const gapLength = Math.max(0, circumference - strokeLength);
			const offset = -accumulated;
			accumulated += strokeLength;
			return {
				model: m.model,
				tokens: m.tokens,
				pct: Math.round(pctRatio * 100),
				color: PALETTE[idx % PALETTE.length],
				dasharray: `${strokeLength} ${gapLength}`,
				dashoffset: offset
			};
		});
		const keys = [];
		for (let i = days - 1; i >= 0; i--) keys.push(dayKey(Date.now() - i * 864e5));
		const byDay = new Map(keys.map((k) => [k, /* @__PURE__ */ new Map()]));
		validRows.forEach((row) => {
			const key = row.updatedAt ? dayKey(row.updatedAt) : keys[keys.length - 1];
			const bucket = byDay.get(key);
			if (!bucket) return;
			(row.value.models?.length ? row.value.models : [{
				model: "未标注",
				tokens: row.value.totals.tokens ?? 0
			}]).forEach((m) => {
				bucket.set(m.model, (bucket.get(m.model) ?? 0) + (m.tokens ?? 0));
			});
		});
		const todayStr = dayKey(Date.now());
		const yesterdayStr = dayKey(Date.now() - 864e5);
		const daySeries = keys.map((key) => {
			const segments = [...(byDay.get(key) ?? /* @__PURE__ */ new Map()).entries()].map(([model, tokens]) => ({
				model,
				tokens,
				color: colorOf(model)
			})).sort((a, b) => b.tokens - a.tokens);
			return {
				key,
				label: range === "7" ? key === todayStr ? "今天" : key === yesterdayStr ? "昨天" : dayLabel(key) : key.endsWith("01") || key.endsWith("05") || key.endsWith("10") || key.endsWith("15") || key.endsWith("20") || key.endsWith("25") ? dayLabel(key) : "",
				total: segments.reduce((s, x) => s + x.tokens, 0),
				segments
			};
		});
		const dayMax = Math.max(1, ...daySeries.map((d) => d.total));
		return {
			validCount: validRows.length,
			listed: sessions.total,
			totalTokens,
			totalTimeHours: ((totalModelMs + totalToolMs) / 36e5).toFixed(1),
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
			dayMax
		};
	}, [
		sessions,
		range,
		sessionSort
	]);
	const cacheNote = !analytics ? "" : analytics.cacheHitPct >= 70 ? "命中较高" : analytics.cacheHitPct >= 40 ? "一般" : "命中偏低";
	const activeSeg = hoveredIdx !== null && analytics?.donutSegments[hoveredIdx] ? analytics.donutSegments[hoveredIdx] : null;
	const topModel = analytics?.donutSegments[0];
	return /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
		className: Insights_module_default.settingsContainer,
		children: [
			/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
				className: Insights_module_default.cockpitHeader,
				children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
					className: Insights_module_default.cockpitTitleArea,
					children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("h2", {
						className: Insights_module_default.cockpitMainTitle,
						children: "对话开销与模型风云榜"
					}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("p", {
						className: Insights_module_default.cockpitSubTitle,
						children: "只读汇总本地已缓存的对话。按活动日期归组，无额外后台开销。"
					})]
				}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
					className: Insights_module_default.headerRightControls,
					children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
						className: Insights_module_default.rangeSwitchGroup,
						children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("button", {
							type: "button",
							className: Insights_module_default.rangeBtn,
							"data-active": range === "7" ? "" : void 0,
							onClick: () => {
								setUserPickedRange(true);
								setRange("7");
							},
							children: "近 7 天"
						}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("button", {
							type: "button",
							className: Insights_module_default.rangeBtn,
							"data-active": range === "30" ? "" : void 0,
							onClick: () => {
								setUserPickedRange(true);
								setRange("30");
							},
							children: "近 30 天"
						})]
					}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("button", {
						type: "button",
						className: Insights_module_default.settingsScanBtn,
						onClick: refresh,
						disabled: loading || !props.remote,
						children: loading ? "正在刷新" : "刷新"
					})]
				})]
			}),
			/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
				className: Insights_module_default.heroStatsRow,
				children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
					className: Insights_module_default.heroBigNum,
					children: [
						analytics ? fmtCompact(analytics.totalTokens) : "-",
						" ",
						/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
							className: Insights_module_default.heroUnit,
							children: "Token"
						})
					]
				}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
					className: Insights_module_default.heroMetaCol,
					children: [
						/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: ["累计耗时 ", /* @__PURE__ */ (0, react_jsx_runtime.jsx)("strong", { children: analytics ? `${analytics.totalTimeHours} 小时` : "-" })] }),
						/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: ["缓存命中 ", /* @__PURE__ */ (0, react_jsx_runtime.jsx)("strong", { children: analytics ? `${analytics.cacheHitPct}% (${cacheNote})` : "-" })] }),
						/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: ["有统计的对话 ", /* @__PURE__ */ (0, react_jsx_runtime.jsx)("strong", { children: analytics ? `${analytics.validCount} / ${analytics.listed}` : "-" })] })
					]
				})]
			}),
			/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
				className: Insights_module_default.roastGrid,
				children: [
					/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
						className: `${Insights_module_default.roastItem} ${activeDrilldown === "speed" ? Insights_module_default.roastItemActive : ""}`,
						onClick: () => setActiveDrilldown(activeDrilldown === "speed" ? null : "speed"),
						children: [
							/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Insights_module_default.roastHead,
								children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Insights_module_default.roastTag,
									style: { color: "#10b981" },
									children: "极致打字机"
								}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Insights_module_default.roastCategoryBadge,
									children: "速度王者"
								})]
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
								className: Insights_module_default.roastTitle,
								title: analytics?.fastKing?.model,
								children: analytics?.fastKing?.model ?? "暂无数据"
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
								className: Insights_module_default.roastDesc,
								title: "首字响应最迅速，轻量改错利器",
								children: "首字响应最迅速，轻量改错利器"
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
								className: Insights_module_default.roastVal,
								style: { color: "#10b981" },
								children: analytics?.fastKing?.firstSamples ? `首字均值 ${(analytics.fastKing.firstMs / analytics.fastKing.firstSamples / 1e3).toFixed(2)} 秒` : "暂无数据"
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Insights_module_default.roastFooter,
								children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Insights_module_default.roastFooterLeft,
									children: "首响应耗时"
								}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Insights_module_default.roastAction,
									children: activeDrilldown === "speed" ? "收起透视 ▴" : "透视详情 ›"
								})]
							})
						]
					}),
					/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
						className: `${Insights_module_default.roastItem} ${activeDrilldown === "latency" ? Insights_module_default.roastItemActive : ""}`,
						onClick: () => setActiveDrilldown(activeDrilldown === "latency" ? null : "latency"),
						children: [
							/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Insights_module_default.roastHead,
								children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Insights_module_default.roastTag,
									style: { color: "#d97706" },
									children: "最慢树懒"
								}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Insights_module_default.roastCategoryBadge,
									children: "延迟瓶颈"
								})]
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
								className: Insights_module_default.roastTitle,
								title: analytics?.slowKing?.model,
								children: analytics?.slowKing?.model ?? "暂无数据"
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
								className: Insights_module_default.roastDesc,
								title: "首字排队最久，点根烟等它开工",
								children: "首字排队最久，点根烟等它开工"
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
								className: Insights_module_default.roastVal,
								style: { color: "#d97706" },
								children: analytics?.slowKing?.firstSamples ? `首字均值 ${(analytics.slowKing.firstMs / analytics.slowKing.firstSamples / 1e3).toFixed(2)} 秒` : "暂无数据"
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Insights_module_default.roastFooter,
								children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Insights_module_default.roastFooterLeft,
									children: "排队瓶颈"
								}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Insights_module_default.roastAction,
									children: activeDrilldown === "latency" ? "收起透视 ▴" : "透视详情 ›"
								})]
							})
						]
					}),
					/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
						className: `${Insights_module_default.roastItem} ${activeDrilldown === "thinking" ? Insights_module_default.roastItemActive : ""}`,
						onClick: () => setActiveDrilldown(activeDrilldown === "thinking" ? null : "thinking"),
						children: [
							/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Insights_module_default.roastHead,
								children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Insights_module_default.roastTag,
									style: { color: "#8b5cf6" },
									children: "深度沉思狂"
								}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Insights_module_default.roastCategoryBadge,
									children: "推理硬核"
								})]
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
								className: Insights_module_default.roastTitle,
								title: analytics?.thinkKing?.model,
								children: analytics?.thinkKing?.model ?? "暂无思考记录"
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
								className: Insights_module_default.roastDesc,
								title: "思考 Token 占自身输出比例最高",
								children: "思考 Token 占自身输出比例最高"
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
								className: Insights_module_default.roastVal,
								style: { color: "#8b5cf6" },
								children: analytics?.thinkKing ? `思考占比 ${Math.round((analytics.thinkKing.reasoning ?? 0) / ((analytics.thinkKing.reasoning ?? 0) + (analytics.thinkKing.output ?? 0) || 1) * 100)}%` : "无推理记录"
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Insights_module_default.roastFooter,
								children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Insights_module_default.roastFooterLeft,
									children: "推导占比"
								}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Insights_module_default.roastAction,
									children: activeDrilldown === "thinking" ? "收起透视 ▴" : "透视详情 ›"
								})]
							})
						]
					}),
					/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
						className: `${Insights_module_default.roastItem} ${activeDrilldown === "cache" ? Insights_module_default.roastItemActive : ""}`,
						onClick: () => setActiveDrilldown(activeDrilldown === "cache" ? null : "cache"),
						children: [
							/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Insights_module_default.roastHead,
								children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Insights_module_default.roastTag,
									style: { color: (analytics?.cacheHitPct ?? 0) >= 40 ? "#10b981" : "#f59e0b" },
									children: (analytics?.cacheHitPct ?? 0) >= 40 ? "省流小能手" : "缓存待提升"
								}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Insights_module_default.roastCategoryBadge,
									children: "成本控制"
								})]
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
								className: Insights_module_default.roastTitle,
								title: analytics?.bestCacheModel?.model,
								children: (analytics?.cacheHitPct ?? 0) >= 40 ? analytics?.bestCacheModel?.model ?? "上下文复用" : "上下文重传较多"
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
								className: Insights_module_default.roastDesc,
								title: (analytics?.cacheHitPct ?? 0) >= 40 ? "前缀缓存命中率高，大幅节约 Token" : "较多长文本全量重传，可利用前缀缓存",
								children: (analytics?.cacheHitPct ?? 0) >= 40 ? "前缀缓存命中率高，大幅节约 Token" : "较多长文本全量重传，可利用前缀缓存"
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
								className: Insights_module_default.roastVal,
								style: { color: (analytics?.cacheHitPct ?? 0) >= 40 ? "#10b981" : "#f59e0b" },
								children: analytics ? `命中 ${analytics.cacheHitPct}% (${fmtCompact(analytics.totalCacheRead)} Token)` : "-"
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Insights_module_default.roastFooter,
								children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Insights_module_default.roastFooterLeft,
									children: "缓存效率"
								}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Insights_module_default.roastAction,
									children: activeDrilldown === "cache" ? "收起透视 ▴" : "透视详情 ›"
								})]
							})
						]
					}),
					/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
						className: `${Insights_module_default.roastItem} ${activeDrilldown === "tool" ? Insights_module_default.roastItemActive : ""}`,
						onClick: () => setActiveDrilldown(activeDrilldown === "tool" ? null : "tool"),
						children: [
							/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Insights_module_default.roastHead,
								children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Insights_module_default.roastTag,
									style: { color: (analytics?.toolTimePct ?? 0) >= 30 ? "#f59e0b" : "#3b82f6" },
									children: (analytics?.toolTimePct ?? 0) >= 30 ? "终端耗时狂" : "秒级放行"
								}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Insights_module_default.roastCategoryBadge,
									children: "工程归因"
								})]
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
								className: Insights_module_default.roastTitle,
								children: (analytics?.toolTimePct ?? 0) >= 30 ? `本地命令占 ${analytics?.toolTimePct}% 耗时` : `本地损耗仅 ${analytics?.toolTimePct ?? 0}%`
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
								className: Insights_module_default.roastDesc,
								title: (analytics?.toolTimePct ?? 0) >= 30 ? "很多时候不是模型卡，是本地脚本跑太久" : "本地工具极速执行，等待时间主要在云端",
								children: (analytics?.toolTimePct ?? 0) >= 30 ? "很多时候不是模型卡，是本地脚本跑太久" : "本地工具极速执行，等待时间主要在云端"
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
								className: Insights_module_default.roastVal,
								style: { color: (analytics?.toolTimePct ?? 0) >= 30 ? "#f59e0b" : "#3b82f6" },
								children: analytics ? `工具耗时 ${Math.round(analytics.totalToolMs / 1e3)} 秒 (${analytics.totalTools} 次)` : "-"
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Insights_module_default.roastFooter,
								children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Insights_module_default.roastFooterLeft,
									children: "本地耗时"
								}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Insights_module_default.roastAction,
									children: activeDrilldown === "tool" ? "收起透视 ▴" : "透视详情 ›"
								})]
							})
						]
					}),
					/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
						className: `${Insights_module_default.roastItem} ${activeDrilldown === "reliability" ? Insights_module_default.roastItemActive : ""}`,
						onClick: () => setActiveDrilldown(activeDrilldown === "reliability" ? null : "reliability"),
						children: [
							/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Insights_module_default.roastHead,
								children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Insights_module_default.roastTag,
									style: { color: (analytics?.totalErrors ?? 0) > 0 ? "#ef4444" : "#10b981" },
									children: (analytics?.totalErrors ?? 0) > 0 ? "翻车排查" : "运行可靠度"
								}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Insights_module_default.roastCategoryBadge,
									children: "稳定性"
								})]
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
								className: Insights_module_default.roastTitle,
								title: (analytics?.totalErrors ?? 0) > 0 ? "存在工具报错" : "执行顺畅",
								children: (analytics?.totalErrors ?? 0) > 0 ? `${analytics?.totalErrors} 次工具报错` : "100% 顺畅"
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
								className: Insights_module_default.roastDesc,
								title: (analytics?.totalErrors ?? 0) > 0 ? "命令执行或参数错误，注意环境排查" : "未发生命令报错或异常，执行稳健",
								children: (analytics?.totalErrors ?? 0) > 0 ? "命令执行或参数错误，注意环境排查" : "未发生命令报错或异常，执行稳健"
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
								className: Insights_module_default.roastVal,
								style: { color: (analytics?.totalErrors ?? 0) > 0 ? "#ef4444" : "#10b981" },
								children: (analytics?.totalErrors ?? 0) > 0 ? `${analytics?.totalErrors} 次报错 · ${analytics?.totalRetries} 次重试` : "0 报错 · 0 重试"
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Insights_module_default.roastFooter,
								children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Insights_module_default.roastFooterLeft,
									children: "异常检测"
								}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Insights_module_default.roastAction,
									children: activeDrilldown === "reliability" ? "收起透视 ▴" : "透视详情 ›"
								})]
							})
						]
					})
				]
			}),
			activeDrilldown && analytics ? /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
				className: Insights_module_default.drilldownPanel,
				children: [
					/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
						className: Insights_module_default.drilldownHead,
						children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
							className: Insights_module_default.drilldownTitleGroup,
							children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
								className: Insights_module_default.drilldownTitle,
								children: [
									activeDrilldown === "speed" && "⚡ 模型首字响应延迟对比 (TTFT)",
									activeDrilldown === "latency" && "🐢 模型首字排队耗时排行榜",
									activeDrilldown === "thinking" && "🧠 深度推导算力分配明细",
									activeDrilldown === "cache" && "💰 前缀缓存命中率排行榜",
									activeDrilldown === "tool" && "⏱️ 本地工具与终端命令耗时全景拆解",
									activeDrilldown === "reliability" && "🛡️ 运行可靠度与报错排查"
								]
							}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
								className: Insights_module_default.drilldownSub,
								children: [
									activeDrilldown === "speed" && "按首响应延迟升序排列（最快在上，首字响应最迅速）",
									activeDrilldown === "latency" && "按排队耗时降序排列（排队最久在上，定位卡顿瓶颈）",
									activeDrilldown === "thinking" && "按思考 Token 占比降序排列（对比自我推导与正文算力比重）",
									activeDrilldown === "cache" && "按前缀缓存命中率降序排列（直接决定上下文成本与省钱效率）",
									activeDrilldown === "tool" && "本地工具耗时全景拆解（按单会话本地执行耗时由大到小降序排查）",
									activeDrilldown === "reliability" && "按报错与重试次数降序排查（优先定位最高频故障会话）"
								]
							})]
						}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("button", {
							type: "button",
							className: Insights_module_default.drilldownCloseBtn,
							onClick: () => setActiveDrilldown(null),
							children: "收起 ✕"
						})]
					}),
					activeDrilldown === "speed" && /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
						className: Insights_module_default.rankList,
						children: [analytics.speedList.map((m, idx) => {
							const avgMs = m.firstMs / m.firstSamples;
							const minMs = analytics.speedList[0].firstMs / analytics.speedList[0].firstSamples;
							const score = Math.max(10, Math.min(100, Math.round(minMs / avgMs * 100)));
							const color = avgMs < 1e3 ? "#10b981" : avgMs < 3e3 ? "#3b82f6" : "#f59e0b";
							return /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Insights_module_default.rankItem,
								children: [
									/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
										className: Insights_module_default.rankItemTop,
										children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
											className: Insights_module_default.rankItemLeft,
											children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
												className: `${Insights_module_default.rankBadge} ${idx === 0 ? Insights_module_default.rankBadgeGold : ""}`,
												children: ["#", idx + 1]
											}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
												className: Insights_module_default.rankName,
												title: m.model,
												children: m.model
											})]
										}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
											className: Insights_module_default.rankValMain,
											style: { color },
											children: [(avgMs / 1e3).toFixed(2), " 秒"]
										})]
									}),
									/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
										className: Insights_module_default.rankTrack,
										children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
											className: Insights_module_default.rankBar,
											style: {
												width: `${score}%`,
												background: color
											}
										})
									}),
									/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
										className: Insights_module_default.rankSubText,
										children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: [
											"速度敏捷得分 ",
											/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("strong", { children: [score, "分"] }),
											" (首字均值 ",
											(avgMs / 1e3).toFixed(2),
											"s)"
										] }), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: [
											"累计采样 ",
											m.firstSamples,
											" 次"
										] })]
									})
								]
							}, m.model);
						}), analytics.speedList.length === 0 ? /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
							className: Insights_module_default.drilldownEmpty,
							children: "暂无模型首字响应延迟采样数据。"
						}) : null]
					}),
					activeDrilldown === "latency" && /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
						className: Insights_module_default.rankList,
						children: [analytics.latencyList.map((m, idx) => {
							const avgMs = m.firstMs / m.firstSamples;
							const maxMs = analytics.latencyList[0].firstMs / analytics.latencyList[0].firstSamples;
							const bottleneckPct = Math.max(10, Math.min(100, Math.round(avgMs / maxMs * 100)));
							const color = avgMs > 5e3 ? "#ef4444" : avgMs > 2e3 ? "#f59e0b" : "#3b82f6";
							return /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Insights_module_default.rankItem,
								children: [
									/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
										className: Insights_module_default.rankItemTop,
										children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
											className: Insights_module_default.rankItemLeft,
											children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
												className: `${Insights_module_default.rankBadge} ${idx === 0 ? Insights_module_default.rankBadgeGold : ""}`,
												children: ["#", idx + 1]
											}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
												className: Insights_module_default.rankName,
												title: m.model,
												children: m.model
											})]
										}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
											className: Insights_module_default.rankValMain,
											style: { color },
											children: [(avgMs / 1e3).toFixed(2), " 秒"]
										})]
									}),
									/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
										className: Insights_module_default.rankTrack,
										children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
											className: Insights_module_default.rankBar,
											style: {
												width: `${bottleneckPct}%`,
												background: color
											}
										})
									}),
									/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
										className: Insights_module_default.rankSubText,
										children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: [
											"排队延迟 ",
											/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("strong", { children: [(avgMs / 1e3).toFixed(2), "s"] }),
											" (瓶颈权重 ",
											bottleneckPct,
											"%)"
										] }), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: [
											"累计采样 ",
											m.firstSamples,
											" 次"
										] })]
									})
								]
							}, m.model);
						}), analytics.latencyList.length === 0 ? /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
							className: Insights_module_default.drilldownEmpty,
							children: "暂无模型排队延迟采样数据。"
						}) : null]
					}),
					activeDrilldown === "thinking" && /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
						className: Insights_module_default.rankList,
						children: [analytics.thinkList.map((m, idx) => {
							const totalTokens = (m.reasoning ?? 0) + (m.output ?? 0);
							const thinkPct = totalTokens > 0 ? Math.round(m.reasoning / totalTokens * 100) : 0;
							return /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Insights_module_default.rankItem,
								children: [
									/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
										className: Insights_module_default.rankItemTop,
										children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
											className: Insights_module_default.rankItemLeft,
											children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
												className: `${Insights_module_default.rankBadge} ${idx === 0 ? Insights_module_default.rankBadgeGold : ""}`,
												children: ["#", idx + 1]
											}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
												className: Insights_module_default.rankName,
												title: m.model,
												children: m.model
											})]
										}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
											className: Insights_module_default.rankValMain,
											style: { color: "#8b5cf6" },
											children: [
												"思考占比 ",
												thinkPct,
												"%"
											]
										})]
									}),
									/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
										className: Insights_module_default.toolCompoundTrack,
										style: { height: "8px" },
										children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
											style: {
												width: `${thinkPct}%`,
												background: "#8b5cf6",
												height: "100%"
											},
											title: `思考: ${thinkPct}%`
										}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
											style: {
												width: `${100 - thinkPct}%`,
												background: "#38bdf8",
												height: "100%"
											},
											title: `正文: ${100 - thinkPct}%`
										})]
									}),
									/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
										className: Insights_module_default.rankSubText,
										children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: [
											"思考推导 ",
											/* @__PURE__ */ (0, react_jsx_runtime.jsx)("strong", { children: fmtCompact(m.reasoning) }),
											" Token (",
											thinkPct,
											"%)"
										] }), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: [
											"正文输出 ",
											/* @__PURE__ */ (0, react_jsx_runtime.jsx)("strong", { children: fmtCompact(m.output) }),
											" Token"
										] })]
									})
								]
							}, m.model);
						}), analytics.thinkList.length === 0 ? /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
							className: Insights_module_default.drilldownEmpty,
							children: "当前时间范围内未检测到调用带推导思考过程的模型。"
						}) : null]
					}),
					activeDrilldown === "cache" && /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
						className: Insights_module_default.rankList,
						children: [analytics.cacheList.map((m, idx) => {
							const totalIn = (m.input ?? 0) + (m.cacheRead ?? 0);
							const hitPct = totalIn > 0 ? Math.round((m.cacheRead ?? 0) / totalIn * 100) : 0;
							return /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Insights_module_default.rankItem,
								children: [
									/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
										className: Insights_module_default.rankItemTop,
										children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
											className: Insights_module_default.rankItemLeft,
											children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
												className: `${Insights_module_default.rankBadge} ${idx === 0 ? Insights_module_default.rankBadgeGold : ""}`,
												children: ["#", idx + 1]
											}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
												className: Insights_module_default.rankName,
												title: m.model,
												children: m.model
											})]
										}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
											className: Insights_module_default.rankValMain,
											style: { color: "#10b981" },
											children: [
												"命中率 ",
												hitPct,
												"%"
											]
										})]
									}),
									/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
										className: Insights_module_default.toolCompoundTrack,
										style: { height: "8px" },
										children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
											style: {
												width: `${hitPct}%`,
												background: "#10b981",
												height: "100%"
											},
											title: `缓存命中: ${hitPct}%`
										}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
											style: {
												width: `${100 - hitPct}%`,
												background: "var(--dsw-alias-border-l3, #94a3b8)",
												height: "100%"
											},
											title: `未命中: ${100 - hitPct}%`
										})]
									}),
									/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
										className: Insights_module_default.rankSubText,
										children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: [
											"命中复用 ",
											/* @__PURE__ */ (0, react_jsx_runtime.jsx)("strong", { children: fmtCompact(m.cacheRead ?? 0) }),
											" Token (",
											hitPct,
											"%)"
										] }), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: [
											"实付输入 ",
											/* @__PURE__ */ (0, react_jsx_runtime.jsx)("strong", { children: fmtCompact(m.input ?? 0) }),
											" Token"
										] })]
									})
								]
							}, m.model);
						}), analytics.cacheList.length === 0 ? /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
							className: Insights_module_default.drilldownEmpty,
							children: "暂无模型缓存使用记录。"
						}) : null]
					}),
					activeDrilldown === "tool" && /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
						className: Insights_module_default.toolDrillSection,
						children: [
							/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Insights_module_default.toolCompoundBox,
								children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: Insights_module_default.toolCompoundTrack,
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
										className: Insights_module_default.toolSliceBash,
										style: { width: `${analytics.bashPct}%` }
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
										className: Insights_module_default.toolSliceFile,
										style: { width: `${analytics.filePct}%` }
									})]
								}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: Insights_module_default.toolCompoundLegend,
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: [
										/* @__PURE__ */ (0, react_jsx_runtime.jsx)("i", {
											className: Insights_module_default.dlDot,
											style: { background: "var(--dsw-static-green-500, #10b981)" }
										}),
										" 终端命令 (Bash): ",
										/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("strong", { children: [
											Math.round(analytics.totalBashMs / 1e3),
											"秒 (",
											analytics.bashPct,
											"%)"
										] })
									] }), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: [
										/* @__PURE__ */ (0, react_jsx_runtime.jsx)("i", {
											className: Insights_module_default.dlDot,
											style: { background: "#0ea5e9" }
										}),
										" 文件与通用读写: ",
										/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("strong", { children: [
											Math.round(analytics.totalFileMs / 1e3),
											"秒 (",
											analytics.filePct,
											"%)"
										] })
									] })]
								})]
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Insights_module_default.toolGridCards,
								children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: Insights_module_default.toolMiniCard,
									children: [
										/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
											className: Insights_module_default.toolMiniTitle,
											children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("i", {
												className: Insights_module_default.dlDot,
												style: { background: "var(--dsw-static-green-500, #10b981)" }
											}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "终端 Bash 命令 (测试/构建/脚本)" })]
										}),
										/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
											className: Insights_module_default.toolMiniNum,
											children: [Math.round(analytics.totalBashMs / 1e3), " 秒"]
										}),
										/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
											className: Insights_module_default.toolMiniDesc,
											children: "包含 npm run, cargo, git, Python 以及本地自动化测试脚本等高耗时运行环节。"
										})
									]
								}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: Insights_module_default.toolMiniCard,
									children: [
										/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
											className: Insights_module_default.toolMiniTitle,
											children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("i", {
												className: Insights_module_default.dlDot,
												style: { background: "#0ea5e9" }
											}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "文件操作与其他工具 (读写/检索)" })]
										}),
										/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
											className: Insights_module_default.toolMiniNum,
											children: [Math.round(analytics.totalFileMs / 1e3), " 秒"]
										}),
										/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
											className: Insights_module_default.toolMiniDesc,
											children: "包含 read, write, edit, glob, grep 等轻量快速文件读写。单次耗时通常在毫秒级。"
										})
									]
								})]
							}),
							analytics.topToolSessions && analytics.topToolSessions.length > 0 ? /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Insights_module_default.toolTopList,
								children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
									className: Insights_module_default.toolTopListTitle,
									children: "单会话工具总耗时 TOP 3 (降序排查)"
								}), analytics.topToolSessions.slice(0, 3).map((s, idx) => {
									const tMs = s.value?.totals?.toolMs ?? 0;
									const bMs = s.value?.totals?.bashMs ?? 0;
									const fMs = Math.max(0, tMs - bMs);
									const bPct = tMs > 0 ? Math.round(bMs / tMs * 100) : 0;
									return /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
										className: Insights_module_default.rankItem,
										children: [
											/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
												className: Insights_module_default.rankItemTop,
												children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
													className: Insights_module_default.rankItemLeft,
													children: [
														/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
															className: `${Insights_module_default.rankBadge} ${idx === 0 ? Insights_module_default.rankBadgeGold : ""}`,
															children: ["#", idx + 1]
														}),
														/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
															className: Insights_module_default.sessionIdTag,
															children: [s.sessionId.slice(0, 14), "…"]
														}),
														/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
															className: Insights_module_default.rankName,
															title: s.value?.models?.[0]?.model,
															children: s.value?.models?.[0]?.model ?? "通用会话"
														})
													]
												}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
													className: Insights_module_default.rankValMain,
													children: [
														"总计 ",
														Math.round(tMs / 1e3),
														" 秒"
													]
												})]
											}),
											/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
												className: Insights_module_default.toolCompoundTrack,
												style: { height: "8px" },
												children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
													style: {
														width: `${bPct}%`,
														background: "var(--dsw-static-green-500, #10b981)",
														height: "100%"
													},
													title: `终端命令: ${Math.round(bMs / 1e3)}s`
												}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
													style: {
														width: `${100 - bPct}%`,
														background: "#0ea5e9",
														height: "100%"
													},
													title: `文件读写: ${Math.round(fMs / 1e3)}s`
												})]
											}),
											/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
												className: Insights_module_default.rankSubText,
												children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: [
													"终端 Bash ",
													/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("strong", { children: [Math.round(bMs / 1e3), "s"] }),
													" (",
													bPct,
													"%)"
												] }), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: [
													"文件读写 ",
													/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("strong", { children: [Math.round(fMs / 1e3), "s"] }),
													" (",
													100 - bPct,
													"%)"
												] })]
											})
										]
									}, s.sessionId);
								})]
							}) : null
						]
					}),
					activeDrilldown === "reliability" && /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
						className: Insights_module_default.errorDrillSection,
						children: analytics.totalErrors === 0 && analytics.totalRetries === 0 ? /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
							className: Insights_module_default.errorAllGoodBox,
							children: "✓ 全部会话工具执行 100% 顺畅，未记录到任何非零退出码或重试异常！"
						}) : /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
							className: Insights_module_default.errorSessionList,
							children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
								className: Insights_module_default.toolTopListTitle,
								children: "报错与重试排查列表 (按异常严重度降序)"
							}), analytics.errorSessions.map((s, idx) => /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Insights_module_default.errorSessionRow,
								children: [
									/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
										className: `${Insights_module_default.rankBadge} ${idx === 0 ? Insights_module_default.rankBadgeGold : ""}`,
										children: ["#", idx + 1]
									}),
									/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
										className: Insights_module_default.sessionIdTag,
										children: [s.sessionId.slice(0, 14), "…"]
									}),
									/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
										className: Insights_module_default.rankName,
										children: s.value?.models?.[0]?.model ?? "通用对话"
									}),
									/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
										className: s.value?.totals?.toolErrors > 0 ? Insights_module_default.statusBad : Insights_module_default.statusOk,
										children: s.value?.totals?.toolErrors > 0 ? `${s.value.totals.toolErrors} 次报错` : "0 报错"
									}),
									/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
										className: s.value?.totals?.retries > 0 ? Insights_module_default.statusWarn : Insights_module_default.statusOk,
										children: s.value?.totals?.retries > 0 ? `${s.value.totals.retries} 次重试` : "0 重试"
									})
								]
							}, s.sessionId))]
						})
					})
				]
			}) : null,
			/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
				className: Insights_module_default.vizSplitGrid,
				children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
					className: Insights_module_default.vizPanel,
					children: [
						/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
							className: Insights_module_default.vizHead,
							children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
								className: Insights_module_default.vizTitle,
								children: "模型支出份额"
							}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
								className: Insights_module_default.vizSub,
								children: "按消耗 Token 降序排列"
							})]
						}),
						/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
							className: Insights_module_default.donutWrap,
							children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Insights_module_default.donutSvgBox,
								children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("svg", {
									viewBox: "0 0 100 100",
									className: Insights_module_default.donutSvg,
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("circle", {
										cx: "50",
										cy: "50",
										r: "38",
										fill: "none",
										stroke: "var(--dsw-alias-bg-layer-2)",
										strokeWidth: "12"
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("g", {
										transform: "rotate(-90 50 50)",
										children: (analytics?.donutSegments.length ?? 0) === 1 ? /* @__PURE__ */ (0, react_jsx_runtime.jsx)("circle", {
											cx: "50",
											cy: "50",
											r: "38",
											fill: "none",
											stroke: analytics.donutSegments[0].color,
											strokeWidth: "12"
										}) : analytics?.donutSegments.map((seg, idx) => /* @__PURE__ */ (0, react_jsx_runtime.jsx)("circle", {
											cx: "50",
											cy: "50",
											r: "38",
											fill: "none",
											stroke: seg.color,
											strokeWidth: "12",
											strokeDasharray: seg.dasharray,
											strokeDashoffset: seg.dashoffset
										}, idx))
									})]
								}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: Insights_module_default.donutCenterText,
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
										className: Insights_module_default.donutCenterNum,
										children: activeSeg ? `${activeSeg.pct}%` : topModel ? `${topModel.pct}%` : `${analytics?.donutSegments.length ?? 0}款`
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
										className: Insights_module_default.donutCenterSub,
										children: activeSeg ? "选中占比" : "主力占比"
									})]
								})]
							}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
								className: Insights_module_default.donutLegendList,
								children: analytics?.donutSegments.map((seg, idx) => /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: `${Insights_module_default.donutLegendRow} ${hoveredIdx === idx ? Insights_module_default.donutLegendRowActive : ""}`,
									onMouseEnter: () => setHoveredIdx(idx),
									onMouseLeave: () => setHoveredIdx(null),
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
										className: Insights_module_default.dlLeft,
										children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("i", {
											className: Insights_module_default.dlDot,
											style: { background: seg.color }
										}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
											className: Insights_module_default.dlName,
											title: seg.model,
											children: seg.model
										})]
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
										className: Insights_module_default.dlRight,
										children: [
											fmtCompact(seg.tokens),
											" · ",
											seg.pct,
											"%"
										]
									})]
								}, idx))
							})]
						}),
						activeSeg || topModel ? /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
							className: Insights_module_default.donutInspectBar,
							children: [
								/* @__PURE__ */ (0, react_jsx_runtime.jsx)("i", {
									className: Insights_module_default.dlDot,
									style: { background: (activeSeg || topModel)?.color }
								}),
								/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Insights_module_default.donutInspectName,
									title: (activeSeg || topModel)?.model,
									children: (activeSeg || topModel)?.model
								}),
								/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Insights_module_default.donutInspectTag,
									children: activeSeg ? "当前高亮" : "全场主力"
								}),
								/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
									className: Insights_module_default.donutInspectVal,
									children: [
										fmtCompact((activeSeg || topModel)?.tokens ?? 0),
										" Token (",
										(activeSeg || topModel)?.pct,
										"%)"
									]
								})
							]
						}) : null
					]
				}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
					className: Insights_module_default.vizPanel,
					children: [
						/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
							className: Insights_module_default.vizHead,
							children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
								className: Insights_module_default.vizTitle,
								children: "每日编码活跃度"
							}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
								className: Insights_module_default.vizSub,
								children: [
									"近 ",
									range,
									" 天分布"
								]
							})]
						}),
						/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
							className: `${Insights_module_default.dayStack} ${range === "7" ? Insights_module_default.dayStackWeek : ""}`,
							"aria-label": "按日活跃柱图",
							children: (analytics?.daySeries ?? []).map((day) => /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Insights_module_default.dayCol,
								title: `${day.key} · ${fmtCompact(day.total)} Token`,
								children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
									className: Insights_module_default.dayColFill,
									children: day.total > 0 ? day.segments.map((seg) => /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
										className: Insights_module_default.daySeg,
										style: {
											height: `${seg.tokens / analytics.dayMax * 100}%`,
											background: seg.color
										}
									}, seg.model)) : /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", { className: Insights_module_default.dayEmptyDot })
								}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Insights_module_default.dayLabel,
									children: day.label
								})]
							}, day.key))
						}),
						/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
							className: Insights_module_default.chartFoot,
							children: "每日柱高代表当天最后活动的对话 Token 汇总，分色对应左侧调用模型。"
						})
					]
				})]
			}),
			/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
				className: Insights_module_default.vizPanel,
				children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
					className: Insights_module_default.vizHead,
					children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
						className: Insights_module_default.tableTitleGroup,
						children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
							className: Insights_module_default.vizTitle,
							children: "重点对话账单"
						}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
							className: Insights_module_default.vizSub,
							children: [
								sessionSort === "tokens" && "按 Token 消耗由高到低严格排序",
								sessionSort === "time" && "按执行总耗时由长到短严格排序",
								sessionSort === "errors" && "按报错与重试次数降序排查"
							]
						})]
					}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
						className: Insights_module_default.tableSortGroup,
						role: "group",
						"aria-label": "对话账单排序切换",
						children: [
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("button", {
								type: "button",
								className: Insights_module_default.sortBtn,
								"data-active": sessionSort === "tokens" ? "" : void 0,
								onClick: () => setSessionSort("tokens"),
								children: "Token 消耗 ↓"
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("button", {
								type: "button",
								className: Insights_module_default.sortBtn,
								"data-active": sessionSort === "time" ? "" : void 0,
								onClick: () => setSessionSort("time"),
								children: "总耗时 ↓"
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("button", {
								type: "button",
								className: Insights_module_default.sortBtn,
								"data-active": sessionSort === "errors" ? "" : void 0,
								onClick: () => setSessionSort("errors"),
								children: "故障数 ↓"
							})
						]
					})]
				}), sessions && sessions.rows.length > 0 ? /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
					className: Insights_module_default.sessionTableBox,
					children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
						className: Insights_module_default.sessionTableHeader,
						children: [
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "排名 · 会话ID" }),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "主用模型" }),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
								style: { textAlign: "right" },
								children: "Token 消耗"
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
								style: { textAlign: "right" },
								children: "总耗时"
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
								style: { textAlign: "center" },
								children: "运行状态"
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {})
						]
					}), analytics?.sortedSessions.slice(0, 10).map((row, idx) => {
						const val = row.value;
						const isOpen = openSessionId === row.sessionId;
						const errCount = val.totals.toolErrors ?? 0;
						const retryCount = val.totals.retries ?? 0;
						const modelMs = val.totals.modelMs ?? 0;
						const toolMs = val.totals.toolMs ?? 0;
						const totalMs = modelMs + toolMs;
						const modelPct = totalMs > 0 ? Math.round(modelMs / totalMs * 100) : 50;
						const status = errCount > 0 ? `${errCount} 次报错` : retryCount > 0 ? `${retryCount} 次重试` : "顺畅";
						const tokenBarPct = Math.max(4, Math.round((val.totals.tokens ?? 0) / analytics.maxSessionTokens * 100));
						return /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
							className: `${Insights_module_default.sessionItemRow} ${isOpen ? Insights_module_default.sessionItemOpen : ""}`,
							children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("button", {
								type: "button",
								className: Insights_module_default.sessionItemHead,
								onClick: () => setOpenSessionId(isOpen ? null : row.sessionId),
								children: [
									/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
										className: Insights_module_default.sessionIdTag,
										title: row.sessionId,
										children: [
											/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("strong", {
												className: Insights_module_default.tableRankNum,
												children: ["#", idx + 1]
											}),
											" ",
											row.sessionId.length > 12 ? `${row.sessionId.slice(0, 6)}…${row.sessionId.slice(-3)}` : row.sessionId
										]
									}),
									/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
										className: Insights_module_default.sessionModelCell,
										title: val.models?.[0]?.model,
										children: val.models?.[0]?.model ?? "未标注"
									}),
									/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
										className: Insights_module_default.sessionTokenCell,
										children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: fmtCompact(val.totals.tokens) }), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
											className: Insights_module_default.sessionTokenBar,
											style: { width: `${tokenBarPct}%` }
										})]
									}),
									/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
										style: { textAlign: "right" },
										children: [Math.round(totalMs / 1e3), " 秒"]
									}),
									/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
										style: { textAlign: "center" },
										className: errCount > 0 ? Insights_module_default.statusBad : retryCount > 0 ? Insights_module_default.statusWarn : Insights_module_default.statusOk,
										children: status
									}),
									/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
										className: Insights_module_default.arrowIcon,
										children: "›"
									})
								]
							}), isOpen ? /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Insights_module_default.sessionItemDrawer,
								children: [
									/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
										className: Insights_module_default.drawerTitle,
										children: "耗时构成下钻：模型响应 vs 本地工具"
									}),
									/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
										className: Insights_module_default.drawerBarTrack,
										children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
											className: Insights_module_default.drawerSliceModel,
											style: { width: `${modelPct}%` }
										}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
											className: Insights_module_default.drawerSliceTool,
											style: { width: `${100 - modelPct}%` }
										})]
									}),
									/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
										className: Insights_module_default.drawerMetaRow,
										children: [
											/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: [
												"模型 ",
												Math.round(modelMs / 1e3),
												" 秒 (首响应均值 ",
												val.totals.firstSamples ? (val.totals.firstMs / val.totals.firstSamples / 1e3).toFixed(1) : 0,
												"s)"
											] }),
											/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: [
												"工具 ",
												Math.round(toolMs / 1e3),
												" 秒 · ",
												val.totals.tools,
												" 次执行"
											] }),
											/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: [
												"缓存命中率 ",
												val.totals.input + val.totals.cacheRead > 0 ? Math.round(val.totals.cacheRead / (val.totals.input + val.totals.cacheRead) * 100) : 0,
												"%"
											] })
										]
									})
								]
							}) : null]
						}, row.sessionId);
					})]
				}) : /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
					className: Insights_module_default.emptyScan,
					children: "暂无已缓存的对话统计。"
				})]
			}),
			/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("details", {
				className: Insights_module_default.settingsDrawer,
				children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("summary", {
					className: Insights_module_default.settingsSummary,
					children: "⚙ 高级报警阈值设置 (默认开箱即用，无需频繁调整)"
				}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
					className: Insights_module_default.settingsDrawerContent,
					children: [
						/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("label", {
							className: Insights_module_default.settingInlineItem,
							children: [
								/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "等多久没字算卡顿:" }),
								/* @__PURE__ */ (0, react_jsx_runtime.jsx)("input", {
									type: "number",
									min: 5,
									max: 300,
									className: Insights_module_default.settingsMiniInput,
									value: silence,
									onChange: (e) => setSilence(Number(e.target.value))
								}),
								/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "秒" })
							]
						}),
						/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("label", {
							className: Insights_module_default.settingInlineItem,
							children: [
								/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "单次推导思考超时:" }),
								/* @__PURE__ */ (0, react_jsx_runtime.jsx)("input", {
									type: "number",
									min: 10,
									max: 600,
									className: Insights_module_default.settingsMiniInput,
									value: reasoning,
									onChange: (e) => setReasoning(Number(e.target.value))
								}),
								/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "秒" })
							]
						}),
						/* @__PURE__ */ (0, react_jsx_runtime.jsx)("button", {
							type: "button",
							className: Insights_module_default.settingsMiniSaveBtn,
							onClick: save,
							children: saved ? "已保存 ✓" : "保存"
						})
					]
				})]
			})
		]
	});
}
//#endregion
//#region src/hub/overview.ts
const OVERVIEW_STATE_LABEL = Object.freeze({
	active: "进行中",
	current: "当前",
	waiting: "等待你",
	failure: "有失败记录",
	interrupted: "已中断",
	settled: "已结束",
	partial: "数据不完整"
});
/** Project evidence status into the one question overview markers answer: where should the user look? */
function overviewStateOf(status, isLatest) {
	if (status === "waiting") return "waiting";
	if (status === "failure") return "failure";
	if (status === "interrupted") return "interrupted";
	if (status === "running") return "active";
	if (status === "unknown") return "partial";
	return isLatest ? "current" : "settled";
}
function turnOverviewSummary(turn) {
	const executionCount = turn.groups.reduce((sum, group) => sum + group.executionCount, 0);
	return [`${turn.groups.length} 个阶段`, executionCount > 0 ? `${executionCount} 次执行` : null].filter((part) => part !== null).join(" · ");
}
function turnNeedsDefaultDisclosure(state, isLatest) {
	return isLatest || state === "active" || state === "waiting" || state === "partial";
}
//#endregion
//#region src/observation/performance.ts
function outputTokensOf(usage) {
	if (typeof usage !== "object" || usage === null || !("outputTokens" in usage)) return null;
	const value = usage.outputTokens;
	return typeof value === "number" && Number.isFinite(value) && value >= 0 ? value : null;
}
function toolDurationOf(turn) {
	let durationMs = 0;
	let sampled = false;
	for (const group of turn.groups) for (const item of group.items) {
		if (item.source !== "tool" || item.durationMs === null) continue;
		durationMs += item.durationMs;
		sampled = true;
	}
	return sampled ? durationMs : null;
}
function foldAssistantNodes(nodes) {
	const folds = /* @__PURE__ */ new Map();
	for (const node of nodes) {
		if (node.kind !== "assistant") continue;
		const timing = node.timing;
		const ttftMs = timing !== void 0 && timing.stepStartTime !== null && timing.firstTokenTime !== null ? Math.max(0, timing.firstTokenTime - timing.stepStartTime) : null;
		const modelMs = timing !== void 0 && timing.stepStartTime !== null ? Math.max(0, timing.completedTime - timing.stepStartTime) : null;
		const decodeMs = timing !== void 0 && timing.firstTokenTime !== null ? Math.max(0, timing.completedTime - timing.firstTokenTime) : null;
		const outputTokens = outputTokensOf(node.usage);
		let fold = folds.get(node.turn);
		if (fold === void 0) {
			fold = {
				firstStep: node.step,
				firstStepTtftMs: ttftMs,
				modelMs: 0,
				modelSampled: false,
				decodeMs: 0,
				outputTokens: 0,
				decodeSampled: false
			};
			folds.set(node.turn, fold);
		} else if (node.step < fold.firstStep) {
			fold.firstStep = node.step;
			fold.firstStepTtftMs = ttftMs;
		}
		if (modelMs !== null) {
			fold.modelMs += modelMs;
			fold.modelSampled = true;
		}
		if (decodeMs !== null && outputTokens !== null) {
			fold.decodeMs += decodeMs;
			fold.outputTokens += outputTokens;
			fold.decodeSampled = true;
		}
	}
	return folds;
}
/**
* Correlate durable assistant timing/usage with Watcher's occurrence-preserving Turns.
* Missing timing or provider usage stays unavailable; this function never estimates it.
*/
function deriveTurnPerformance(nodes, turns) {
	const assistantFolds = foldAssistantNodes(nodes);
	const performance = /* @__PURE__ */ new Map();
	for (const turn of turns) {
		const fold = assistantFolds.get(turn.turn);
		const throughput = fold !== void 0 && fold.decodeSampled && fold.decodeMs > 0 ? {
			kind: "measured",
			decodeMs: fold.decodeMs,
			outputTokens: fold.outputTokens,
			tokensPerSecond: fold.outputTokens / (fold.decodeMs / 1e3)
		} : { kind: "unavailable" };
		performance.set(turn.turn, {
			modelMs: fold?.modelSampled === true ? fold.modelMs : null,
			toolMs: toolDurationOf(turn),
			ttftMs: fold?.firstStepTtftMs ?? null,
			throughput
		});
	}
	return performance;
}
function itemEndTime(item) {
	return item.resultTime ?? item.time;
}
function observedTurnRange(turn, live, now) {
	const items = turn.groups.flatMap((group) => group.items);
	const observedStarts = [...turn.groups.flatMap((group) => group.startTime === null ? [] : [group.startTime]), ...items.map((item) => item.time)];
	const observedEnds = [...turn.groups.flatMap((group) => group.endTime === null ? [] : [group.endTime]), ...items.map(itemEndTime)];
	const fallbackStart = observedStarts.length === 0 ? null : Math.min(...observedStarts);
	const fallbackEnd = observedEnds.length === 0 ? null : Math.max(...observedEnds);
	const startTime = turn.startTime ?? fallbackStart;
	const endTime = turn.endTime ?? (live ? now : fallbackEnd);
	if (startTime === null || endTime === null) return null;
	return {
		startTime,
		endTime: Math.max(startTime, endTime),
		exactBounds: turn.startTime !== null && (turn.endTime !== null || live)
	};
}
/** Settled Turn duration, live current duration, or a lower bound for a clipped Turn start. */
function turnElapsedReading(turn, live, now) {
	const range = observedTurnRange(turn, live, now);
	if (range === null) return { kind: "unavailable" };
	return {
		kind: range.exactBounds ? "exact" : "lower-bound",
		durationMs: range.endTime - range.startTime
	};
}
function boundedElapsed(startTime, endTime, live, now) {
	if (startTime === null) return null;
	const end = endTime ?? (live ? now : null);
	return end === null ? null : Math.max(0, end - startTime);
}
/** One phase's wall-clock span from its first Step start to its last Step end. */
function groupElapsedMs(group, live, now) {
	return boundedElapsed(group.startTime, group.endTime, live, now);
}
/** One Step's wall-clock span, including model, tools, and in-step waits. */
function stepElapsedMs(step, live, now) {
	return boundedElapsed(step.startTime, step.endTime, live, now);
}
/** One execution's settled duration or live elapsed interval. */
function itemElapsedMs(item, live, now) {
	return item.durationMs ?? (live ? Math.max(0, now - item.time) : null);
}
/** Whole tokens from ten up, one decimal below, matching DSH's RC8 chat chrome. */
function formatTokensPerSecond(tokensPerSecond) {
	const clamped = Math.max(0, tokensPerSecond);
	return clamped >= 10 ? String(Math.round(clamped)) : String(Math.round(clamped * 10) / 10);
}
//#endregion
//#region src/client/step-timeline.ts
/** Compose the visible rows owned by one authoritative DSH Step. */
function stepTimelineEntries(step) {
	const occurrences = step.items.filter((item) => item.source !== "model").map((item, occurrenceIndex) => ({
		kind: "occurrence",
		item,
		occurrenceIndex
	}));
	if (step.model === null) return occurrences;
	const firstAgentOccurrence = occurrences.findIndex((entry) => entry.item.source !== "user");
	const modelIndex = firstAgentOccurrence < 0 ? occurrences.length : firstAgentOccurrence;
	return [
		...occurrences.slice(0, modelIndex),
		{
			kind: "model",
			trace: step.model
		},
		...occurrences.slice(modelIndex)
	];
}
//#endregion
//#region src/client/disclosure-depth.ts
function emptyLayerOverrides() {
	return {
		phase: {},
		step: {},
		cluster: {},
		model: {},
		reasoning: {}
	};
}
function createDisclosureState(depth = "overview") {
	return {
		depth,
		turns: {},
		layers: emptyLayerOverrides()
	};
}
/** Overview keeps the automatic Turn policy; detail opens every Turn by default. */
function turnDisclosureOpen(state, turn, overviewDefaultOpen) {
	return state.turns[turn] ?? (state.depth === "detail" || overviewDefaultOpen);
}
/** Overview stops at phase headers; detail opens every nested level by default. */
function layerDisclosureOpen(state, layer, key) {
	return state.layers[layer][key] ?? state.depth === "detail";
}
function setLayerDisclosure(state, layer, key, open) {
	return {
		...state,
		layers: {
			...state.layers,
			[layer]: {
				...state.layers[layer],
				[key]: open
			}
		}
	};
}
function toggleTurnDisclosure(state, turn, overviewDefaultOpen) {
	return {
		...state,
		turns: {
			...state.turns,
			[turn]: !turnDisclosureOpen(state, turn, overviewDefaultOpen)
		}
	};
}
function toggleLayerDisclosure(state, layer, key) {
	return setLayerDisclosure(state, layer, key, !layerDisclosureOpen(state, layer, key));
}
/** Choosing a depth applies it immediately instead of inheriting stale manual folds. */
function chooseDisclosureDepth(depth) {
	return createDisclosureState(depth);
}
/** Session-specific ids may change, while the user's chosen depth remains useful. */
function resetDisclosureOverrides(state) {
	return createDisclosureState(state.depth);
}
//#endregion
//#region src/client/Watcher.tsx
const PANEL_GAP = 8;
const PANEL_MARGIN = 12;
const UNPLACED_PANEL_STYLE = {
	visibility: "hidden",
	left: 0,
	top: 0
};
const MARKDOWN_LABELS = Object.freeze({
	code: Object.freeze({
		copyLabel: "复制",
		copiedLabel: "已复制"
	}),
	footnotes: "脚注"
});
const TERMINAL_LABELS = Object.freeze({
	signal: (signal) => `信号 ${signal}`,
	exitCode: (exitCode) => `退出码 ${exitCode}`,
	running: "运行中",
	failed: "失败",
	done: "完成",
	copy: "复制",
	copied: "已复制",
	noOutput: "没有输出",
	collapseAria: "收起终端输出",
	collapse: "收起",
	expandAria: (hidden) => `展开其余 ${hidden} 行终端输出`,
	expand: (hidden) => `展开 ${hidden} 行`
});
const READ_LABELS = Object.freeze({
	window: (shown, total) => `显示 ${shown}/${total} 行`,
	copy: "复制",
	copied: "已复制",
	collapseAria: "收起文件内容",
	expandAria: (hidden) => `展开其余 ${hidden} 行文件内容`,
	collapse: "收起",
	expand: (hidden) => `展开 ${hidden} 行`
});
const DIFF_LABELS = Object.freeze({
	copy: "复制",
	copied: "已复制",
	collapseAria: "收起变更内容",
	expandAria: (hidden) => `展开其余 ${hidden} 行变更`,
	collapse: "收起",
	expand: (hidden) => `展开 ${hidden} 行`,
	files: (count) => `${count} 个文件`
});
const JSON_LABELS = Object.freeze({
	copyValue: "复制值",
	copyJson: "复制 JSON",
	copyPath: "复制路径",
	copyPrettyJson: "复制格式化 JSON",
	copyCompactJson: "复制紧凑 JSON",
	copied: "已复制",
	copyFailed: "复制失败",
	collapseNode: "收起节点",
	expandNode: "展开节点",
	copyButtonTitle: (action) => action
});
const STATUS_LABEL = {
	running: "进行中",
	waiting: "等待你",
	success: "成功",
	failure: "失败",
	returned: "已返回",
	interrupted: "已中断",
	unknown: "未知"
};
function dotState(status) {
	if (status === "running") return "ongoing";
	if (status === "waiting") return "warning";
	if (status === "failure" || status === "interrupted") return "error";
	if (status === "success") return "done";
	return null;
}
function StatusMark({ status, className }) {
	const state = dotState(status);
	return state === null ? /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
		className: `${Watcher_module_default.neutralDot}${className === void 0 ? "" : ` ${className}`}`,
		"data-status": status,
		"aria-hidden": "true"
	}) : /* @__PURE__ */ (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.StateDot, {
		state,
		size: 10,
		className
	});
}
function formatDuration(durationMs) {
	if (durationMs === null) return null;
	if (durationMs < 1e3) return `${Math.round(durationMs)} ms`;
	const secondsWithDecimal = Math.round(durationMs / 100) / 10;
	if (secondsWithDecimal < 60) return `${secondsWithDecimal < 10 ? secondsWithDecimal.toFixed(1) : Math.round(secondsWithDecimal)} s`;
	const totalSeconds = Math.round(durationMs / 1e3);
	const minutes = Math.floor(totalSeconds / 60);
	const seconds = totalSeconds % 60;
	if (minutes >= 60) return `${Math.floor(minutes / 60)}h ${minutes % 60}m`;
	return `${minutes}m ${seconds}s`;
}
function turnDuration(turn, live, now) {
	const reading = turnElapsedReading(turn, live, now);
	if (reading.kind === "unavailable") return null;
	const duration = formatDuration(reading.durationMs);
	if (duration === null) return null;
	return {
		kind: reading.kind === "exact" ? "exact" : "partial",
		value: duration
	};
}
function useLiveClock(enabled) {
	const [now, setNow] = (0, react.useState)(() => Date.now());
	(0, react.useEffect)(() => {
		if (!enabled) return;
		setNow(Date.now());
		const timer = setInterval(() => setNow(Date.now()), 1e3);
		return () => clearInterval(timer);
	}, [enabled]);
	return now;
}
function TurnMetricStrip({ performance }) {
	const metrics = [
		["模型", formatDuration(performance.modelMs)],
		["工具", formatDuration(performance.toolMs)],
		["首 token", formatDuration(performance.ttftMs)]
	].filter((metric) => metric[1] !== null);
	if (metrics.length === 0) return null;
	return /* @__PURE__ */ (0, react_jsx_runtime.jsx)("dl", {
		className: Watcher_module_default.turnMetrics,
		"aria-label": "对话轮次性能分解",
		children: metrics.map(([label, value]) => /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
			className: Watcher_module_default.turnMetric,
			children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("dt", { children: label }), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("dd", { children: value })]
		}, label))
	});
}
function rawOf(item) {
	if (item.rawText.trim() !== "") return item.rawText;
	try {
		return JSON.stringify(item.rawValue, null, 2) ?? String(item.rawValue);
	} catch {
		return String(item.rawValue);
	}
}
function isJsonValue(value) {
	return typeof value === "object" && value !== null;
}
function CopyRawButton({ text }) {
	const [copied, setCopied] = (0, react.useState)(false);
	const timerRef = (0, react.useRef)(null);
	(0, react.useEffect)(() => () => {
		if (timerRef.current !== null) clearTimeout(timerRef.current);
	}, []);
	const copy = () => {
		(0, _deepseek_ai_dsh_client_ui_primitives.writeClipboard)(text).then((ok) => {
			if (!ok) return;
			setCopied(true);
			if (timerRef.current !== null) clearTimeout(timerRef.current);
			timerRef.current = setTimeout(() => setCopied(false), 1500);
		});
	};
	return /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("button", {
		type: "button",
		className: Watcher_module_default.copyRaw,
		onClick: copy,
		"aria-label": copied ? "原始数据已复制" : "复制原始数据",
		children: [copied ? /* @__PURE__ */ (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.IconCheckOutline16, { size: 14 }) : /* @__PURE__ */ (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.IconCopyOutline16, { size: 14 }), copied ? "已复制" : "复制"]
	});
}
function ResultPresentation({ presentation }) {
	switch (presentation.kind) {
		case "terminal": return /* @__PURE__ */ (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.TerminalBlock, {
			command: presentation.command,
			cwd: presentation.cwd ?? void 0,
			output: presentation.output,
			exitCode: presentation.exitCode ?? void 0,
			signal: presentation.signal ?? void 0,
			running: presentation.running,
			maxLines: 18,
			labels: TERMINAL_LABELS
		});
		case "read": return /* @__PURE__ */ (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.ReadBlock, {
			label: presentation.label,
			lang: presentation.lang ?? void 0,
			lines: presentation.lines,
			totalLines: presentation.totalLines,
			maxLines: 18,
			labels: READ_LABELS
		});
		case "diff": return /* @__PURE__ */ (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.DiffBlock, {
			diffs: presentation.diffs,
			maxLines: 18,
			labels: DIFF_LABELS
		});
		case "json": return /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
			className: Watcher_module_default.jsonSurface,
			children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.JsonTree, {
				data: presentation.data,
				label: "结构化结果",
				labels: JSON_LABELS
			})
		});
		case "text": return /* @__PURE__ */ (0, react_jsx_runtime.jsx)("article", {
			className: Watcher_module_default.documentResult,
			"data-watcher-document": "",
			children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.MarkdownText, {
				text: presentation.text,
				labels: MARKDOWN_LABELS
			})
		});
		case "image": return /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
			className: Watcher_module_default.artifactResult,
			children: [
				/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
					className: Watcher_module_default.artifactGlyph,
					"aria-hidden": "true",
					children: "▧"
				}),
				/* @__PURE__ */ (0, react_jsx_runtime.jsx)("strong", { children: "图片附件" }),
				/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "附件已保留在本次会话记录中" }),
				isJsonValue(presentation.attachment) ? /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
					className: Watcher_module_default.jsonSurface,
					children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.JsonTree, {
						data: presentation.attachment,
						label: "图片附件信息",
						labels: JSON_LABELS
					})
				}) : null
			]
		});
		case "empty": return /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
			className: Watcher_module_default.detailEmpty,
			children: "这次执行还没有可显示的结果"
		});
	}
}
function preferredItem(group) {
	return group.items.find((item) => item.status === "failure" && item.recoveredBy === null) ?? group.items.find((item) => item.status === "waiting" || item.status === "running") ?? group.items.at(-1) ?? null;
}
function groupStatusLabel(group) {
	return group.status === "failure" ? "含失败记录" : STATUS_LABEL[group.status];
}
function itemPattern(item) {
	if (item.retryIndex > 0) return `重试 ${item.retryIndex} 次`;
	if (item.iterationIndex > 0) return `迭代第 ${item.iterationIndex + 1} 版`;
	if (item.recoveredBy !== null) return "后续已恢复";
	return null;
}
function ExecutionInspector({ group, selectedItemId, live, now, onSelectItem, onBack }) {
	const [tab, setTab] = (0, react.useState)("result");
	const fallback = preferredItem(group);
	const selected = group.items.find((item) => item.id === selectedItemId) ?? fallback;
	(0, react.useEffect)(() => setTab("result"), [group.id, selected?.id]);
	if (selected === null) return null;
	const duration = formatDuration(itemElapsedMs(selected, live && selected.status === "running", now));
	const groupDuration = formatDuration(groupElapsedMs(group, live, now));
	const raw = rawOf(selected);
	const hasInput = Object.keys(selected.args).length > 0;
	const pattern = itemPattern(selected);
	return /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("aside", {
		className: Watcher_module_default.inspector,
		"aria-label": `${group.title} 的执行详情`,
		"data-ud-check": "watcher-inspector",
		"data-ud-role": "panel",
		children: [
			/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("header", {
				className: Watcher_module_default.inspectorHeader,
				children: [
					/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("button", {
						type: "button",
						className: Watcher_module_default.inspectorBack,
						onClick: onBack,
						"aria-label": "返回工作路径",
						children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.IconChevronRightOutline14, {
							size: 13,
							"aria-hidden": "true"
						}), "工作路径"]
					}),
					/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
						className: Watcher_module_default.statusLine,
						"data-status": group.status,
						children: [
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)(StatusMark, { status: group.status }),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: groupStatusLabel(group) }),
							/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
								className: Watcher_module_default.location,
								children: [
									"对话轮次 ",
									group.turn || "—",
									" · ",
									group.steps.length,
									" 个步骤",
									groupDuration === null ? "" : ` · ${groupDuration}`
								]
							})
						]
					}),
					/* @__PURE__ */ (0, react_jsx_runtime.jsx)("h2", {
						className: Watcher_module_default.inspectorTitle,
						children: group.title
					}),
					/* @__PURE__ */ (0, react_jsx_runtime.jsx)("p", {
						className: Watcher_module_default.inspectorSummary,
						children: group.subtitle
					}),
					/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
						className: Watcher_module_default.groupSignals,
						"aria-label": "工作模式",
						children: [
							group.parallelStepCount > 0 ? /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: [
								"并行 ",
								group.parallelStepCount,
								" 次"
							] }) : null,
							group.retryCount > 0 ? /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
								"data-retry": "",
								children: [
									"重试 ",
									group.retryCount,
									" 次"
								]
							}) : null,
							group.iterationCount > 0 ? /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: [
								"有 ",
								group.iterationCount,
								" 次迭代"
							] }) : null,
							group.unconfirmedFailureCount > 0 ? /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
								"data-error": "",
								children: [group.unconfirmedFailureCount, " 条失败后未见成功证据"]
							}) : null
						]
					})
				]
			}),
			/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
				className: Watcher_module_default.inspectorBody,
				children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("section", {
					className: Watcher_module_default.executionSection,
					"aria-labelledby": `execution-title-${group.id}`,
					children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
						className: Watcher_module_default.sectionHeading,
						children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("h3", {
							id: `execution-title-${group.id}`,
							children: "执行路径"
						}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: [group.items.length, " 条记录"] })]
					}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
						className: Watcher_module_default.executionList,
						children: group.steps.map((step, stepIndex) => {
							const stepLive = live && stepIndex === group.steps.length - 1;
							const stepDuration = formatDuration(stepElapsedMs(step, stepLive, now));
							return /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Watcher_module_default.stepBlock,
								"data-parallel": step.parallel ? "" : void 0,
								children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: Watcher_module_default.stepHeading,
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: ["步骤 ", step.step || "—"] }), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
										className: Watcher_module_default.stepSignals,
										children: [stepDuration === null ? null : /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
											className: Watcher_module_default.stepDuration,
											children: stepDuration
										}), step.parallel ? /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
											className: Watcher_module_default.parallelLabel,
											children: [step.executionCount, " 项并行"]
										}) : null]
									})]
								}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
									className: Watcher_module_default.occurrences,
									children: step.items.map((item, itemIndex) => {
										const itemDuration = formatDuration(itemElapsedMs(item, stepLive && item.status === "running", now));
										return /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("button", {
											type: "button",
											className: Watcher_module_default.occurrence,
											"data-selected": item.id === selected.id ? "" : void 0,
											"data-status": item.status,
											"aria-pressed": item.id === selected.id,
											onClick: () => onSelectItem(item.id),
											children: [
												/* @__PURE__ */ (0, react_jsx_runtime.jsx)(StatusMark, {
													status: item.status,
													className: Watcher_module_default.occurrenceDot
												}),
												/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
													className: Watcher_module_default.occurrenceCopy,
													children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
														className: Watcher_module_default.occurrenceTitle,
														children: item.title
													}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
														className: Watcher_module_default.occurrenceMeta,
														children: [
															item.toolName ?? item.source,
															step.items.length > 1 ? ` · 分支 ${itemIndex + 1}` : "",
															itemPattern(item) === null ? "" : ` · ${itemPattern(item)}`
														]
													})]
												}),
												itemDuration === null ? null : /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
													className: Watcher_module_default.occurrenceDuration,
													children: itemDuration
												}),
												/* @__PURE__ */ (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.IconChevronRightOutline14, {
													size: 12,
													className: Watcher_module_default.occurrenceChevron
												})
											]
										}, item.id);
									})
								})]
							}, step.id);
						})
					})]
				}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("section", {
					className: Watcher_module_default.detailSection,
					"aria-labelledby": `detail-title-${selected.id}`,
					children: [
						/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
							className: Watcher_module_default.detailHeader,
							children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Watcher_module_default.detailIdentity,
								children: [
									/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
										className: Watcher_module_default.detailStatus,
										"data-status": selected.status,
										children: [
											/* @__PURE__ */ (0, react_jsx_runtime.jsx)(StatusMark, { status: selected.status }),
											/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: STATUS_LABEL[selected.status] }),
											pattern === null ? null : /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
												className: Watcher_module_default.patternLabel,
												children: pattern
											})
										]
									}),
									/* @__PURE__ */ (0, react_jsx_runtime.jsx)("h3", {
										id: `detail-title-${selected.id}`,
										children: selected.title
									}),
									/* @__PURE__ */ (0, react_jsx_runtime.jsx)("p", {
										title: selected.subtitle,
										children: selected.subtitle || "没有补充说明"
									})
								]
							}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("dl", {
								className: Watcher_module_default.metrics,
								children: [
									duration === null ? null : /* @__PURE__ */ (0, react_jsx_runtime.jsxs)(react_jsx_runtime.Fragment, { children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("dt", { children: "耗时" }), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("dd", { children: duration })] }),
									selected.exitCode === null ? null : /* @__PURE__ */ (0, react_jsx_runtime.jsxs)(react_jsx_runtime.Fragment, { children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("dt", { children: "退出码" }), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("dd", {
										"data-error": selected.exitCode === 0 ? void 0 : "",
										children: selected.exitCode
									})] }),
									selected.signal === null ? null : /* @__PURE__ */ (0, react_jsx_runtime.jsxs)(react_jsx_runtime.Fragment, { children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("dt", { children: "信号" }), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("dd", {
										"data-error": "",
										children: selected.signal
									})] })
								]
							})]
						}),
						/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
							className: Watcher_module_default.tabs,
							role: "tablist",
							"aria-label": "执行数据",
							children: [
								["result", "结果"],
								["input", "输入"],
								["raw", "原始"]
							].map(([id, label]) => /* @__PURE__ */ (0, react_jsx_runtime.jsx)("button", {
								type: "button",
								role: "tab",
								"aria-selected": tab === id,
								className: Watcher_module_default.tab,
								"data-active": tab === id ? "" : void 0,
								onClick: () => setTab(id),
								children: label
							}, id))
						}),
						/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
							className: Watcher_module_default.tabPanel,
							role: "tabpanel",
							children: [
								tab === "result" ? /* @__PURE__ */ (0, react_jsx_runtime.jsx)(ResultPresentation, { presentation: selected.presentation }) : null,
								tab === "input" ? hasInput ? /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
									className: Watcher_module_default.jsonSurface,
									children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.JsonTree, {
										data: selected.args,
										label: "执行输入",
										labels: JSON_LABELS
									})
								}) : /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
									className: Watcher_module_default.detailEmpty,
									children: "这条记录没有工具输入"
								}) : null,
								tab === "raw" ? /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: Watcher_module_default.rawPanel,
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
										className: Watcher_module_default.rawToolbar,
										children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "完整原始数据 · 不截断" }), /* @__PURE__ */ (0, react_jsx_runtime.jsx)(CopyRawButton, { text: raw })]
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("pre", { children: raw || "没有原始数据" })]
								}) : null
							]
						})
					]
				})]
			}),
			/* @__PURE__ */ (0, react_jsx_runtime.jsx)("footer", {
				className: Watcher_module_default.inspectorFooter,
				children: "只读观察 · 不会改变 Agent"
			})
		]
	});
}
/** The pupil scans only while live; the complete eye remains a useful static glyph. */
function IconLivingEye({ size = 17 }) {
	return /* @__PURE__ */ (0, react_jsx_runtime.jsx)("svg", {
		className: Watcher_module_default.eye,
		"data-ud-motion": "watcher-eye-scan",
		width: size,
		height: size,
		viewBox: "0 0 18 18",
		fill: "none",
		"aria-hidden": "true",
		children: /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("g", {
			className: Watcher_module_default.eyeBlink,
			children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("path", {
				className: Watcher_module_default.eyeOutline,
				fill: "currentColor",
				fillRule: "evenodd",
				d: "M9 3.25c-3.93 0-7.03 2.88-7.9 5.75.87 2.87 3.97 5.75 7.9 5.75s7.03-2.88 7.9-5.75C16.03 6.13 12.93 3.25 9 3.25Zm0 9.95A4.2 4.2 0 1 1 9 4.8a4.2 4.2 0 0 1 0 8.4Z"
			}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("g", {
				className: Watcher_module_default.eyePupil,
				children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("circle", {
					cx: "9",
					cy: "9",
					r: "2.05",
					fill: "currentColor"
				}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("circle", {
					cx: "9.65",
					cy: "8.35",
					r: "0.45",
					fill: "var(--dsw-specific-menu)",
					opacity: "0.9"
				})]
			})]
		})
	});
}
function groupBadges(group) {
	return /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
		className: Watcher_module_default.groupBadges,
		"aria-hidden": "true",
		children: [
			group.parallelStepCount > 0 ? /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
				"data-kind": "parallel",
				children: group.parallelStepCount === 1 ? "并行" : `并行 ${group.parallelStepCount} 组`
			}) : null,
			group.retryCount > 0 ? /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
				"data-kind": "retry",
				children: ["重试 ", group.retryCount]
			}) : null,
			group.iterationCount > 0 ? /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
				"data-kind": "iteration",
				children: ["迭代 ", group.iterationCount]
			}) : null
		]
	});
}
function showOverviewTag(state) {
	return state === "waiting" || state === "failure" || state === "interrupted" || state === "partial";
}
function itemMeta(item, { branch, step }) {
	return [
		step === null ? null : `步骤 ${step || "—"}`,
		item.toolName ?? item.source,
		branch === null ? null : `分支 ${branch}`,
		itemPattern(item)
	].filter((part) => part !== null && part !== "").join(" · ");
}
function branchNumberOf(step, item) {
	if (!step.parallel) return null;
	const index = step.items.findIndex((candidate) => candidate.id === item.id);
	return index < 0 ? null : index + 1;
}
function clusterBasisLabel(cluster) {
	if (cluster.executionCount < 2) return null;
	if (cluster.basis === "mutable-target" || cluster.basis === "shared-target") return "同一目标";
	if (cluster.basis === "exact-call") return "同一指令";
	return null;
}
function reasoningAttemptDuration(attempt, now) {
	if (attempt.firstReasoningTime === null || attempt.lastReasoningTime === null) return null;
	const end = attempt.kind === "running" && attempt.firstOutputTime === null ? now : attempt.lastReasoningTime;
	return Math.max(0, end - attempt.firstReasoningTime);
}
function reasoningAttemptState(attempt) {
	if (attempt.kind === "running") return "生成中";
	if (attempt.kind === "retried") return "已重试";
	if (attempt.kind === "interrupted") return "已中断";
	return "已完成";
}
function ModelStage({ trace, stepId, now, open, disclosure, onToggle, onToggleReasoning }) {
	const metrics = modelStageMetrics(trace, now);
	const hasReasoning = hasReasoningEvidence(trace);
	const total = formatDuration(metrics.totalMs);
	const visibleReasoning = formatDuration(metrics.visibleReasoningMs);
	const reasoningAttempts = trace.attempts.filter((attempt) => attempt.reasoningText.trim() !== "");
	const summary = [
		total === null ? "时间不完整" : `模型 ${total}`,
		hasReasoning ? visibleReasoning === null ? "可见推理已记录" : `可见推理 ${visibleReasoning}` : null,
		trace.reasoningTokens === null ? null : `${trace.reasoningTokens.toLocaleString("zh-CN")} 推理 token`,
		metrics.live ? "进行中" : null
	].filter((value) => value !== null).join(" · ");
	const segments = [
		{
			key: "wait",
			label: "首响应等待",
			durationMs: metrics.firstResponseMs,
			unavailableLabel: "时间戳不可用"
		},
		{
			key: "reasoning",
			label: "可见推理",
			durationMs: metrics.visibleReasoningMs,
			unavailableLabel: hasReasoning ? "分段耗时不可用" : "未记录"
		},
		{
			key: "output",
			label: "输出 / 工具意图",
			durationMs: metrics.outputMs,
			unavailableLabel: "时间戳不可用"
		},
		...metrics.unattributedMs !== null && metrics.unattributedMs > 0 ? [{
			key: "unattributed",
			label: "重试 / 未归因",
			durationMs: metrics.unattributedMs,
			unavailableLabel: "不可用"
		}] : []
	];
	const measuredSegments = segments.filter((segment) => segment.durationMs !== null && segment.durationMs > 0);
	const bodyId = `watcher-model-stage-${stepId}`;
	return /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("section", {
		className: Watcher_module_default.modelStage,
		"data-live": metrics.live ? "" : void 0,
		children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("button", {
			type: "button",
			className: Watcher_module_default.modelStageToggle,
			"aria-expanded": open,
			"aria-controls": bodyId,
			title: "模型阶段只使用 DSH 会话中供应商公开写入的事件",
			onClick: onToggle,
			children: [
				/* @__PURE__ */ (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.IconChevronRightOutline14, {
					size: 11,
					className: Watcher_module_default.modelStageChevron
				}),
				/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
					className: Watcher_module_default.modelStageGlyph,
					"aria-hidden": "true"
				}),
				/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
					className: Watcher_module_default.modelStageCopy,
					children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
						className: Watcher_module_default.modelStageTitle,
						children: "模型阶段"
					}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
						className: Watcher_module_default.modelStageSummary,
						children: summary
					})]
				})
			]
		}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
			id: bodyId,
			className: Watcher_module_default.modelStageBody,
			hidden: !open,
			children: [
				measuredSegments.length === 0 ? null : /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
					className: Watcher_module_default.modelStageBar,
					"aria-label": "模型阶段耗时比例",
					children: measuredSegments.map((segment) => /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
						"data-segment": segment.key,
						style: { flexGrow: Math.max(segment.durationMs, 1) },
						title: `${segment.label} ${formatDuration(segment.durationMs) ?? ""}`
					}, segment.key))
				}),
				/* @__PURE__ */ (0, react_jsx_runtime.jsx)("dl", {
					className: Watcher_module_default.modelStageLedger,
					children: segments.map((segment) => /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
						className: Watcher_module_default.modelStageMetric,
						children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("dt", { children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
							className: Watcher_module_default.modelStageSwatch,
							"data-segment": segment.key,
							"aria-hidden": "true"
						}), segment.label] }), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("dd", { children: formatDuration(segment.durationMs) ?? segment.unavailableLabel })]
					}, segment.key))
				}),
				reasoningAttempts.length === 0 ? /* @__PURE__ */ (0, react_jsx_runtime.jsx)("p", {
					className: Watcher_module_default.modelStageNote,
					children: "本 Step 没有供应商可见推理记录"
				}) : /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
					className: Watcher_module_default.reasoningAttempts,
					children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("p", {
						className: Watcher_module_default.modelStageNote,
						children: "仅展示供应商写入 DSH 会话的可见 reasoning；不补写未记录内容。"
					}), reasoningAttempts.map((attempt) => {
						const key = `${stepId}:attempt:${attempt.attempt}`;
						const reasoningOpen = layerDisclosureOpen(disclosure, "reasoning", key);
						const duration = formatDuration(reasoningAttemptDuration(attempt, now));
						const meta = [
							reasoningAttemptState(attempt),
							duration ?? "分段耗时不可用",
							`${attempt.fragments.length} 个流片段`,
							attempt.kind === "retried" ? `等待重试 ${formatDuration(attempt.retryDelayMs) ?? "—"}` : null
						].filter((value) => value !== null).join(" · ");
						return /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("section", {
							className: Watcher_module_default.reasoningDisclosure,
							"data-open": reasoningOpen ? "" : void 0,
							children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("button", {
								type: "button",
								className: Watcher_module_default.reasoningToggle,
								"aria-expanded": reasoningOpen,
								"aria-controls": `watcher-reasoning-${key}`,
								onClick: () => onToggleReasoning(key),
								children: [
									/* @__PURE__ */ (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.IconChevronRightOutline14, {
										size: 11,
										className: Watcher_module_default.reasoningChevron
									}),
									/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
										className: Watcher_module_default.reasoningLabel,
										children: reasoningAttempts.length === 1 ? "推理记录" : `尝试 ${attempt.attempt}`
									}),
									/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
										className: Watcher_module_default.reasoningMeta,
										children: meta
									})
								]
							}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("article", {
								id: `watcher-reasoning-${key}`,
								className: Watcher_module_default.reasoningBody,
								hidden: !reasoningOpen,
								children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.MarkdownText, {
									text: attempt.reasoningText,
									labels: MARKDOWN_LABELS
								})
							})]
						}, key);
					})]
				})
			]
		})]
	});
}
function OverviewOccurrenceButton({ item, occurrenceNumber, branch, step, live, selected, now, onSelect }) {
	const duration = formatDuration(itemElapsedMs(item, live, now));
	const meta = itemMeta(item, {
		branch,
		step
	});
	return /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("button", {
		type: "button",
		className: Watcher_module_default.overviewOccurrence,
		"data-selected": selected ? "" : void 0,
		"data-current": live ? "" : void 0,
		"data-status": item.status,
		"data-ud-motion": "watcher-live-append",
		"aria-current": live ? "step" : void 0,
		"aria-pressed": selected,
		"aria-label": `记录 ${occurrenceNumber}，${item.title}，${meta}${duration === null ? "" : `，耗时 ${duration}`}，${STATUS_LABEL[item.status]}`,
		onClick: onSelect,
		children: [
			/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
				className: Watcher_module_default.overviewOccurrenceIndex,
				children: String(occurrenceNumber).padStart(2, "0")
			}),
			/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
				className: Watcher_module_default.overviewOccurrenceDotSlot,
				"aria-hidden": "true",
				children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)(StatusMark, {
					status: item.status,
					className: Watcher_module_default.overviewOccurrenceDot
				})
			}),
			/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
				className: Watcher_module_default.overviewOccurrenceCopy,
				children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
					className: Watcher_module_default.overviewOccurrenceTitle,
					children: item.title
				}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
					className: Watcher_module_default.overviewOccurrenceMeta,
					children: meta
				})]
			}),
			duration === null ? null : /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
				className: Watcher_module_default.overviewOccurrenceDuration,
				children: duration
			}),
			/* @__PURE__ */ (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.IconChevronRightOutline14, {
				size: 12,
				className: Watcher_module_default.overviewOccurrenceChevron
			})
		]
	});
}
function PhaseOverview({ group, isNow, running, now, selectedGroup, selectedItemId, observationMode, open, disclosure, onToggle, onToggleLayer, onToggleReasoning, onSelectItem }) {
	const phaseState = overviewStateOf(group.status, isNow);
	const phaseDuration = formatDuration(groupElapsedMs(group, isNow && running, now));
	const phaseSummary = [
		`${group.steps.length} 个步骤`,
		`${group.executionCount} 次执行`,
		phaseDuration
	].filter((part) => part !== null).join(" · ");
	const latestItemId = group.items.at(-1)?.id ?? null;
	const clusters = clusterWorkItems(group.items.filter((item) => item.source !== "model"));
	const modelSteps = group.steps.filter((step) => step.model !== null);
	const groupedModelsKey = `${group.id}:model-list`;
	const groupedModelsOpen = layerDisclosureOpen(disclosure, "model", groupedModelsKey);
	return /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("section", {
		className: Watcher_module_default.phase,
		"data-selected": selectedGroup ? "" : void 0,
		"data-now": isNow ? "" : void 0,
		"data-overview-state": phaseState,
		"aria-label": `${group.title}，${phaseSummary}，${OVERVIEW_STATE_LABEL[phaseState]}`,
		children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("header", {
			className: Watcher_module_default.phaseHeader,
			children: /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("button", {
				type: "button",
				className: Watcher_module_default.phaseToggle,
				"aria-expanded": open,
				"aria-controls": `watcher-phase-body-${group.id}`,
				"aria-label": `${group.title}，${phaseSummary}，${open ? "收起阶段" : "展开阶段"}`,
				onClick: onToggle,
				children: [
					/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
						className: Watcher_module_default.phaseMarker,
						"data-state": phaseState,
						"aria-hidden": "true"
					}),
					/* @__PURE__ */ (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.IconChevronRightOutline14, {
						size: 12,
						className: Watcher_module_default.phaseChevron
					}),
					/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
						className: Watcher_module_default.phaseCopy,
						children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
							className: Watcher_module_default.phaseTitleLine,
							children: [
								/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Watcher_module_default.phaseTitle,
									"data-watcher-group-title": "",
									children: group.title
								}),
								groupBadges(group),
								showOverviewTag(phaseState) ? /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Watcher_module_default.overviewTag,
									"data-state": phaseState,
									children: OVERVIEW_STATE_LABEL[phaseState]
								}) : null
							]
						}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
							className: Watcher_module_default.phaseMeta,
							children: phaseSummary
						})]
					})
				]
			})
		}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
			id: `watcher-phase-body-${group.id}`,
			hidden: !open,
			children: observationMode === "itemized" ? /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
				className: Watcher_module_default.stepTimeline,
				"data-observation-mode": "itemized",
				children: group.steps.map((step) => {
					const stepLive = isNow && running && step.items.some((item) => item.id === latestItemId && item.status === "running");
					const stepDuration = formatDuration(stepElapsedMs(step, stepLive, now));
					const stepOpen = layerDisclosureOpen(disclosure, "step", step.id);
					const modelDuration = formatDuration((step.model === null ? null : modelStageMetrics(step.model, now))?.totalMs ?? null);
					const showStepTotal = stepDuration !== null && stepDuration !== modelDuration;
					const modelOpen = layerDisclosureOpen(disclosure, "model", step.id);
					const timelineEntries = stepTimelineEntries(step);
					return /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("section", {
						className: Watcher_module_default.overviewStep,
						"data-current": stepLive ? "" : void 0,
						"data-parallel": step.parallel ? "" : void 0,
						children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("header", {
							className: Watcher_module_default.overviewStepHeader,
							children: /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("button", {
								type: "button",
								className: Watcher_module_default.stepToggle,
								"aria-expanded": stepOpen,
								"aria-controls": `watcher-step-body-${step.id}`,
								"aria-label": `步骤 ${step.step || "—"}，${step.executionCount} 次执行${stepDuration === null ? "" : `，耗时 ${stepDuration}`}，${stepOpen ? "收起步骤" : "展开步骤"}`,
								onClick: () => onToggleLayer("step", step.id),
								children: [
									/* @__PURE__ */ (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.IconChevronRightOutline14, {
										size: 11,
										className: Watcher_module_default.stepChevron
									}),
									/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
										className: Watcher_module_default.overviewStepLabel,
										children: ["步骤 ", step.step || "—"]
									}),
									/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
										className: Watcher_module_default.overviewStepSignals,
										children: [
											step.executionCount > 0 ? /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: [step.executionCount, " 次"] }) : null,
											step.parallel ? /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
												className: Watcher_module_default.parallelLabel,
												children: [step.executionCount, " 项并行"]
											}) : null,
											modelDuration === null ? null : /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: ["模型 ", modelDuration] }),
											showStepTotal ? /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: ["总 ", stepDuration] }) : null
										]
									})
								]
							})
						}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
							id: `watcher-step-body-${step.id}`,
							className: Watcher_module_default.overviewOccurrences,
							hidden: !stepOpen,
							children: timelineEntries.map((entry) => {
								if (entry.kind === "model") return /* @__PURE__ */ (0, react_jsx_runtime.jsx)(ModelStage, {
									trace: entry.trace,
									stepId: step.id,
									now,
									open: modelOpen,
									disclosure,
									onToggle: () => onToggleLayer("model", step.id),
									onToggleReasoning: (key) => onToggleReasoning(key, step.id)
								}, `model:${step.id}`);
								const item = entry.item;
								return /* @__PURE__ */ (0, react_jsx_runtime.jsx)(OverviewOccurrenceButton, {
									item,
									occurrenceNumber: group.items.findIndex((candidate) => candidate.id === item.id) + 1,
									branch: step.parallel ? entry.occurrenceIndex + 1 : null,
									step: null,
									live: stepLive && item.id === latestItemId && item.status === "running",
									selected: selectedGroup && selectedItemId === item.id,
									now,
									onSelect: () => onSelectItem(item)
								}, item.id);
							})
						})]
					}, step.id);
				})
			}) : /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
				className: Watcher_module_default.analysisClusters,
				"data-observation-mode": "grouped",
				children: [modelSteps.length === 0 ? null : /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("section", {
					className: Watcher_module_default.groupedModelStages,
					"data-open": groupedModelsOpen ? "" : void 0,
					children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("button", {
						type: "button",
						className: Watcher_module_default.groupedModelToggle,
						"aria-expanded": groupedModelsOpen,
						"aria-controls": `watcher-grouped-models-${group.id}`,
						onClick: () => onToggleLayer("model", groupedModelsKey),
						children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.IconChevronRightOutline14, {
							size: 11,
							className: Watcher_module_default.groupedModelChevron
						}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("strong", { children: "模型阶段汇总" }), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("small", { children: [modelSteps.length, " 个 Step · 按 Step 保留，不合并推理"] })] })]
					}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
						id: `watcher-grouped-models-${group.id}`,
						className: Watcher_module_default.groupedModelList,
						hidden: !groupedModelsOpen,
						children: modelSteps.map((step) => {
							const modelOpen = layerDisclosureOpen(disclosure, "model", step.id);
							return /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Watcher_module_default.groupedModelStep,
								children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
									className: Watcher_module_default.groupedModelStepLabel,
									children: ["步骤 ", step.step || "—"]
								}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)(ModelStage, {
									trace: step.model,
									stepId: `${step.id}:grouped`,
									now,
									open: modelOpen,
									disclosure,
									onToggle: () => onToggleLayer("model", step.id),
									onToggleReasoning: (key) => onToggleReasoning(key, step.id)
								})]
							}, step.id);
						})
					})]
				}), clusters.map((cluster) => {
					if (cluster.executionCount === 1) {
						const item = cluster.items[0];
						const sourceStep = group.steps.find((step) => step.items.some((candidate) => candidate.id === item.id));
						const branch = sourceStep === void 0 ? null : branchNumberOf(sourceStep, item);
						return /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
							className: Watcher_module_default.analysisSingleton,
							children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)(OverviewOccurrenceButton, {
								item,
								occurrenceNumber: group.items.findIndex((candidate) => candidate.id === item.id) + 1,
								branch,
								step: item.step,
								live: isNow && running && item.id === latestItemId && item.status === "running",
								selected: selectedGroup && selectedItemId === item.id,
								now,
								onSelect: () => onSelectItem(item)
							})
						}, cluster.id);
					}
					const clusterOpen = layerDisclosureOpen(disclosure, "cluster", cluster.id);
					const basisLabel = clusterBasisLabel(cluster);
					const outcome = clusterOutcomeSummary(cluster);
					const clusterMeta = [
						basisLabel,
						`${cluster.executionCount} 次执行`,
						`${cluster.stepCount} 个步骤`,
						outcome
					].filter((part) => part !== null && part !== "").join(" · ");
					return /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("section", {
						className: Watcher_module_default.analysisCluster,
						"data-open": clusterOpen ? "" : void 0,
						children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("button", {
							type: "button",
							className: Watcher_module_default.analysisClusterToggle,
							"aria-expanded": clusterOpen,
							"aria-controls": `watcher-cluster-body-${cluster.id}`,
							"aria-label": `${cluster.title}，${clusterMeta}，${clusterOpen ? "收起同类执行" : "展开同类执行"}`,
							onClick: () => onToggleLayer("cluster", cluster.id),
							children: [
								/* @__PURE__ */ (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.IconChevronRightOutline14, {
									size: 11,
									className: Watcher_module_default.analysisClusterChevron
								}),
								/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
									className: Watcher_module_default.analysisClusterDotSlot,
									"aria-hidden": "true",
									children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)(StatusMark, {
										status: cluster.latestStatus,
										className: Watcher_module_default.analysisClusterDot
									})
								}),
								/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
									className: Watcher_module_default.analysisClusterCopy,
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
										className: Watcher_module_default.analysisClusterTitle,
										children: cluster.title
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
										className: Watcher_module_default.analysisClusterMeta,
										children: clusterMeta
									})]
								}),
								cluster.executionCount > 1 ? /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
									className: Watcher_module_default.analysisClusterCount,
									children: ["×", cluster.executionCount]
								}) : null
							]
						}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
							id: `watcher-cluster-body-${cluster.id}`,
							className: Watcher_module_default.analysisClusterItems,
							hidden: !clusterOpen,
							children: cluster.items.map((item) => {
								const sourceStep = group.steps.find((step) => step.items.some((candidate) => candidate.id === item.id));
								const branch = sourceStep === void 0 ? null : branchNumberOf(sourceStep, item);
								return /* @__PURE__ */ (0, react_jsx_runtime.jsx)(OverviewOccurrenceButton, {
									item,
									occurrenceNumber: group.items.findIndex((candidate) => candidate.id === item.id) + 1,
									branch,
									step: item.step,
									live: isNow && running && item.id === latestItemId && item.status === "running",
									selected: selectedGroup && selectedItemId === item.id,
									now,
									onSelect: () => onSelectItem(item)
								}, item.id);
							})
						})]
					}, cluster.id);
				})]
			})
		})]
	});
}
/** Native session-header utility: exact work picture, typed evidence, no steering. */
function Watcher(props) {
	const conversation = props.useConversation((state) => state);
	const chat = conversation?.views?.get("chat");
	if (chat === void 0) return /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
		role: "status",
		children: "Watcher 正在等待会话记录…"
	});
	return /* @__PURE__ */ (0, react_jsx_runtime.jsx)(ReadyWatcher, {
		...props,
		chat,
		views: conversation.views
	});
}
function ReadyWatcher({ useSession, useSessionPendingInteraction, useProjection, sessionId, loadAllHistory, chat, views }) {
	const sessionSnapshot = useSession((state) => state);
	const pending = useSessionPendingInteraction((state) => state.get(sessionId));
	const snapshot = (0, react.useMemo)(() => ({
		views,
		chat,
		nodes: chat.legacy.nodes,
		turnTimings: chat.legacy.turnTimings,
		runningCalls: chat.legacy.runningCalls,
		pending: pending === void 0 ? [] : [pending],
		blank: sessionSnapshot.blank,
		running: sessionSnapshot.running,
		hasMore: sessionSnapshot.hasMore
	}), [
		chat,
		views,
		pending,
		sessionSnapshot.blank,
		sessionSnapshot.hasMore,
		sessionSnapshot.running
	]);
	const running = snapshot.running;
	const wholeSessionStats = useProjection("sessionStats");
	const wholeSessionInsights = useProjection("watcherInsights");
	const snapshotPicture = (0, react.useMemo)(() => foldSnapshot(snapshot, { running }), [snapshot, running]);
	const observedRef = (0, react.useRef)(null);
	const picture = (0, react.useMemo)(() => {
		const previous = observedRef.current?.sessionId === sessionId ? observedRef.current.picture : null;
		const next = previous === null ? snapshotPicture : mergeObservedPictures(previous, snapshotPicture);
		observedRef.current = {
			sessionId,
			picture: next
		};
		return next;
	}, [sessionId, snapshotPicture]);
	const performanceByTurn = (0, react.useMemo)(() => deriveTurnPerformance(snapshot.nodes, picture.turns), [snapshot.nodes, picture.turns]);
	const lastGroup = picture.nodes.at(-1);
	const lastGroupId = lastGroup?.id ?? null;
	const lastItem = lastGroup?.items.at(-1);
	const latestActivityKey = lastItem === void 0 ? lastGroupId : `${lastGroupId}:${lastItem.id}:${lastItem.seq}:${lastItem.status}:${lastItem.resultSeq ?? "open"}:${lastItem.resultTime ?? "open"}`;
	const [open, setOpen] = (0, react.useState)(false);
	const [ui, setUi] = (0, react.useState)(() => ({
		follow: true,
		unread: 0,
		selectedId: null
	}));
	const [selectedItemId, setSelectedItemId] = (0, react.useState)(null);
	const [observationMode, setObservationMode] = (0, react.useState)("itemized");
	const [disclosure, setDisclosure] = (0, react.useState)(createDisclosureState);
	const [historyLoad, setHistoryLoad] = (0, react.useState)({ kind: "idle" });
	const now = useLiveClock(open && picture.running);
	const followRef = (0, react.useRef)(createFollow());
	const rootRef = (0, react.useRef)(null);
	const triggerRef = (0, react.useRef)(null);
	const panelRef = (0, react.useRef)(null);
	const railRef = (0, react.useRef)(null);
	const programmaticScrollRef = (0, react.useRef)(false);
	const historyAbortRef = (0, react.useRef)(null);
	const panelPosition = (0, _deepseek_ai_dsh_client_ui_primitives.useAnchoredPosition)({
		open,
		anchorRef: triggerRef,
		panelRef,
		gap: PANEL_GAP,
		margin: PANEL_MARGIN
	});
	(0, react.useEffect)(() => {
		if (!open) return;
		const closeOutside = (event) => {
			if (!(event.target instanceof Node)) return;
			if (rootRef.current?.contains(event.target) === true) return;
			if (panelRef.current?.contains(event.target) === true) return;
			setOpen(false);
		};
		const closeOnEscape = (event) => {
			if (event.key !== "Escape") return;
			event.preventDefault();
			setOpen(false);
			triggerRef.current?.focus();
		};
		document.addEventListener("pointerdown", closeOutside);
		document.addEventListener("keydown", closeOnEscape);
		return () => {
			document.removeEventListener("pointerdown", closeOutside);
			document.removeEventListener("keydown", closeOnEscape);
		};
	}, [open]);
	(0, react.useLayoutEffect)(() => {
		historyAbortRef.current?.abort();
		historyAbortRef.current = null;
		setHistoryLoad({ kind: "idle" });
		followRef.current.reset();
		setUi(followRef.current.snapshot());
		setSelectedItemId(null);
		setDisclosure(resetDisclosureOverrides);
	}, [sessionId]);
	(0, react.useEffect)(() => () => {
		historyAbortRef.current?.abort();
	}, []);
	(0, react.useLayoutEffect)(() => {
		setUi(followRef.current.onPicture(picture));
	}, [latestActivityKey]);
	(0, react.useLayoutEffect)(() => {
		const rail = railRef.current;
		if (!rail || !open || !ui.follow) return;
		programmaticScrollRef.current = true;
		rail.scrollTop = rail.scrollHeight;
		const frame = requestAnimationFrame(() => {
			programmaticScrollRef.current = false;
		});
		return () => {
			cancelAnimationFrame(frame);
			programmaticScrollRef.current = false;
		};
	}, [
		ui.follow,
		latestActivityKey,
		observationMode,
		open
	]);
	const selected = ui.selectedId === null ? void 0 : picture.nodes.find((group) => group.id === ui.selectedId);
	const latestTurnNumber = picture.turns.at(-1)?.turn ?? null;
	const totalTurnCount = Math.max(picture.turnCount, wholeSessionStats?.turns ?? 0);
	const totalStepCount = Math.max(picture.stepCount, wholeSessionStats?.steps ?? 0);
	const historyProgress = totalStepCount > picture.stepCount ? `${picture.stepCount}/${totalStepCount} 个步骤` : totalTurnCount > picture.turnCount ? `${picture.turnCount}/${totalTurnCount} 个对话轮次` : `${picture.stepCount} 个步骤已载入`;
	const hasEdgeAlert = picture.pendingCount > 0 || picture.now.status === "failure" || picture.now.status === "interrupted";
	const summaryState = picture.pendingCount > 0 ? "等待确认" : picture.running ? "正在执行" : picture.now.status === "failure" ? "执行失败" : picture.now.status === "interrupted" ? "已中断" : picture.nodes.length > 0 ? "就绪" : "待命";
	const nowLabel = picture.now.label || (picture.nodes.length > 0 ? "执行路径已就绪" : "等待指令");
	const selectItem = (group, item) => {
		setUi(followRef.current.onSelect(group.id));
		setSelectedItemId(item.id);
	};
	const onRailScroll = () => {
		if (programmaticScrollRef.current) return;
		const rail = railRef.current;
		if (rail === null) return;
		const atBottom = rail.scrollHeight - rail.scrollTop - rail.clientHeight < 24;
		setUi(followRef.current.onScroll({ atBottom }));
	};
	const backToLatest = () => {
		programmaticScrollRef.current = true;
		setUi(followRef.current.backToLatest());
	};
	const pinForDisclosure = () => {
		if (ui.follow) setUi(followRef.current.setFollow(false));
	};
	const chooseObservationMode = (mode) => {
		if (mode === observationMode) return;
		if (ui.follow) programmaticScrollRef.current = true;
		setObservationMode(mode);
	};
	const chooseDepth = (depth) => {
		if (depth === disclosure.depth) return;
		pinForDisclosure();
		setDisclosure(chooseDisclosureDepth(depth));
	};
	const startHistoryLoad = () => {
		if (historyLoad.kind === "loading" || historyLoad.kind === "complete") return;
		historyAbortRef.current?.abort();
		const controller = new AbortController();
		historyAbortRef.current = controller;
		setHistoryLoad({ kind: "loading" });
		loadAllHistory(controller.signal).then((result) => {
			if (historyAbortRef.current !== controller) return;
			if (result.kind === "blocked") {
				const message = result.reason === "busy" ? "主会话正在载入历史，请稍后重试" : result.reason === "page-limit" ? "历史页数超出安全上限，请分次重试" : "历史分页没有继续前进，请重试";
				setHistoryLoad({
					kind: "error",
					message
				});
			} else if (result.kind === "complete") setHistoryLoad({ kind: "complete" });
			else setHistoryLoad({ kind: "idle" });
		}).catch((error) => {
			if (historyAbortRef.current !== controller || controller.signal.aborted) return;
			setHistoryLoad({
				kind: "error",
				message: error instanceof Error ? error.message : String(error)
			});
		}).finally(() => {
			if (historyAbortRef.current === controller) historyAbortRef.current = null;
		});
	};
	(0, react.useEffect)(() => {
		if (!open || !snapshot.hasMore || historyLoad.kind !== "idle") return;
	}, [
		open,
		snapshot.hasMore,
		historyLoad.kind,
		sessionId
	]);
	(0, react.useEffect)(() => {
		if (historyLoad.kind !== "complete" || snapshot.hasMore) return;
		setHistoryLoad({ kind: "idle" });
	}, [historyLoad.kind, snapshot.hasMore]);
	return /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
		ref: rootRef,
		className: Watcher_module_default.root,
		"data-dsh-watcher": "header",
		children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("button", {
			ref: triggerRef,
			type: "button",
			className: Watcher_module_default.trigger,
			"data-open": open ? "" : void 0,
			"data-live": picture.running && picture.nodes.length > 0 ? "" : void 0,
			"data-alert": hasEdgeAlert ? "" : void 0,
			"aria-expanded": open,
			"aria-label": `Watcher，${summaryState}`,
			title: "Watcher",
			onClick: () => setOpen((value) => !value),
			children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)(IconLivingEye, {})
		}), open ? (0, react_dom.createPortal)(/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
			ref: panelRef,
			className: Watcher_module_default.menu,
			style: panelPosition ?? UNPLACED_PANEL_STYLE,
			role: "dialog",
			"aria-modal": "false",
			"aria-label": "Watcher 工作图",
			"data-dsh-watcher-panel": "",
			"data-ud-motion": "watcher-panel-enter",
			children: [selected === void 0 ? null : /* @__PURE__ */ (0, react_jsx_runtime.jsx)(ExecutionInspector, {
				group: selected,
				selectedItemId,
				live: picture.running && selected.id === lastGroupId,
				now,
				onSelectItem: setSelectedItemId,
				onBack: () => {
					backToLatest();
					setSelectedItemId(null);
				}
			}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("section", {
				className: Watcher_module_default.workPicture,
				"aria-label": "Agent 工作路径",
				"data-ud-check": "watcher-work-picture",
				"data-ud-role": "panel",
				children: [
					/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("header", {
						className: Watcher_module_default.pictureHeader,
						children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
							className: Watcher_module_default.nowBlock,
							"aria-live": "polite",
							children: [
								picture.running || hasEdgeAlert || summaryState !== "就绪" ? /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
									className: Watcher_module_default.eyebrow,
									"data-alert": hasEdgeAlert ? "" : void 0,
									children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: summaryState })
								}) : null,
								/* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
									className: Watcher_module_default.now,
									title: picture.running ? nowLabel : "DSH-Watcher",
									children: picture.running ? nowLabel : "DSH-Watcher"
								}),
								/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
									className: Watcher_module_default.summary,
									children: [
										/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: snapshot.hasMore && totalTurnCount > picture.turnCount ? `已载入 ${picture.turnCount}/${totalTurnCount} 轮` : `${picture.turnCount} 轮` }),
										/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: snapshot.hasMore && totalStepCount > picture.stepCount ? `${picture.stepCount}/${totalStepCount} 步` : `${picture.stepCount} 步` }),
										/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", { children: [picture.actionCount, " 次执行"] }),
										snapshot.hasMore || historyLoad.kind === "loading" || historyLoad.kind === "error" ? /* @__PURE__ */ (0, react_jsx_runtime.jsx)("button", {
											type: "button",
											className: Watcher_module_default.loadAllInlineBtn,
											onClick: startHistoryLoad,
											disabled: historyLoad.kind === "loading",
											children: historyLoad.kind === "loading" ? "正在补齐历史…" : historyLoad.kind === "error" ? "重试载入" : "载入全部历史 →"
										}) : null,
										historyLoad.kind === "loading" || historyLoad.kind === "error" ? /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
											role: "status",
											children: historyLoad.kind === "error" ? historyLoad.message : `已载入 ${historyProgress}`
										}) : null
									]
								})
							]
						}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)(_deepseek_ai_dsh_client_ui_primitives.Pill, {
							className: Watcher_module_default.follow,
							active: ui.follow,
							"aria-pressed": ui.follow,
							"aria-label": ui.follow ? "停止跟随最新工作" : "跟随最新工作",
							onClick: () => {
								if (!ui.follow) programmaticScrollRef.current = true;
								setUi(followRef.current.setFollow(!ui.follow));
							},
							children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.IconRefreshOutline14, { size: 12 }), ui.follow ? "自动跟随" : "浏览历史"]
						})]
					}),
					/* @__PURE__ */ (0, react_jsx_runtime.jsx)(SessionInsights, {
						value: wholeSessionInsights,
						now,
						running: picture.running,
						waiting: picture.pendingCount > 0,
						onEvidence: (e) => {
							pinForDisclosure();
							setDisclosure(chooseDisclosureDepth("detail"));
							requestAnimationFrame(() => document.getElementById("watcher-turn-" + e.turn)?.scrollIntoView({ block: "nearest" }));
						}
					}),
					/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
						className: Watcher_module_default.viewToolbar,
						"aria-label": "路径视图设置",
						children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
							className: Watcher_module_default.viewControl,
							children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
								className: Watcher_module_default.viewToolbarLabel,
								children: "组织"
							}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Watcher_module_default.viewMode,
								role: "group",
								"aria-label": "路径组织方式",
								children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("button", {
									type: "button",
									"data-active": observationMode === "itemized" ? "" : void 0,
									"aria-pressed": observationMode === "itemized",
									title: "按时间顺序展示每个步骤和每次执行",
									onClick: () => chooseObservationMode("itemized"),
									children: "逐项"
								}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("button", {
									type: "button",
									"data-active": observationMode === "grouped" ? "" : void 0,
									"aria-pressed": observationMode === "grouped",
									title: "按同一目标或完全相同的指令归类，展开仍可查看原始执行",
									onClick: () => chooseObservationMode("grouped"),
									children: "归类"
								})]
							})]
						}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
							className: Watcher_module_default.viewControl,
							children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
								className: Watcher_module_default.viewToolbarLabel,
								children: "层级"
							}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
								className: Watcher_module_default.viewMode,
								role: "group",
								"aria-label": "路径展开深度",
								children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("button", {
									type: "button",
									"data-active": disclosure.depth === "overview" ? "" : void 0,
									"aria-pressed": disclosure.depth === "overview",
									title: "展开当前轮次，展示阶段概览；阶段内部保持收起",
									onClick: () => chooseDepth("overview"),
									children: "概览"
								}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("button", {
									type: "button",
									"data-active": disclosure.depth === "detail" ? "" : void 0,
									"aria-pressed": disclosure.depth === "detail",
									title: "展开所有轮次、阶段、步骤、模型与推理记录",
									onClick: () => chooseDepth("detail"),
									children: "详情"
								})]
							})]
						})]
					}),
					!ui.follow && ui.unread > 0 ? /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("button", {
						type: "button",
						className: Watcher_module_default.unread,
						onClick: backToLatest,
						children: [
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.IconRefreshOutline14, { size: 12 }),
							ui.unread,
							" 条新进展 · 查看最新"
						]
					}) : null,
					picture.nodes.length === 0 ? /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
						className: Watcher_module_default.empty,
						children: [
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
								className: Watcher_module_default.emptyEye,
								"aria-hidden": "true",
								children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)(IconLivingEye, { size: 22 })
							}),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("strong", { children: "还没有工作记录" }),
							/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", { children: "第一轮对话开始后，路径会从这里生长" })
						]
					}) : /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
						ref: railRef,
						className: Watcher_module_default.railViewport,
						onScroll: onRailScroll,
						children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)("div", {
							className: Watcher_module_default.turns,
							children: picture.turns.map((turn) => {
								const isLatestTurn = turn.turn === latestTurnNumber;
								const turnState = overviewStateOf(turn.status, isLatestTurn);
								const automaticDefaultOpen = turnNeedsDefaultDisclosure(turnState, isLatestTurn);
								const turnOpen = turnDisclosureOpen(disclosure, turn.turn, automaticDefaultOpen);
								const turnTitle = turn.turn === 0 ? "会话准备" : `对话轮次 ${turn.turn}`;
								const turnSummary = turnOverviewSummary(turn);
								const performance = performanceByTurn.get(turn.turn);
								const duration = turnDuration(turn, isLatestTurn && picture.running, now);
								const tokenSpeed = performance?.throughput.kind === "measured" ? `${formatTokensPerSecond(performance.throughput.tokensPerSecond)} tok/s` : null;
								const durationAria = duration === null ? "" : duration.kind === "exact" ? `，总耗时 ${duration.value}` : `，已记录 ${duration.value}，开头未载入`;
								const secondaryPerformance = [duration?.kind === "partial" ? "开头未载入" : null, tokenSpeed].filter((value) => value !== null).join(" · ");
								return /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("section", {
									className: Watcher_module_default.turn,
									"aria-labelledby": `watcher-turn-${turn.turn}`,
									children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("header", {
										className: Watcher_module_default.turnHeader,
										children: /* @__PURE__ */ (0, react_jsx_runtime.jsx)("h2", {
											id: `watcher-turn-${turn.turn}`,
											children: /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("button", {
												type: "button",
												className: Watcher_module_default.turnToggle,
												"aria-expanded": turnOpen,
												"aria-controls": `watcher-turn-body-${turn.turn}`,
												"aria-label": `${turnTitle}，${OVERVIEW_STATE_LABEL[turnState]}，${turnSummary}${durationAria}${tokenSpeed === null ? "" : `，生成速度 ${tokenSpeed}`}，${turnOpen ? "收起轮次" : "展开轮次"}`,
												title: turnOpen ? "收起此轮次；新进展仍会继续更新" : "展开此轮次",
												onClick: () => {
													pinForDisclosure();
													setDisclosure((current) => toggleTurnDisclosure(current, turn.turn, automaticDefaultOpen));
												},
												children: [
													/* @__PURE__ */ (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.IconChevronRightOutline14, {
														size: 13,
														className: Watcher_module_default.turnChevron
													}),
													/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
														className: Watcher_module_default.turnCopy,
														children: [/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
															className: Watcher_module_default.turnTitleLine,
															children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
																className: Watcher_module_default.turnTitle,
																children: turnTitle
															}), showOverviewTag(turnState) ? /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
																className: Watcher_module_default.overviewTag,
																"data-state": turnState,
																children: OVERVIEW_STATE_LABEL[turnState]
															}) : null]
														}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
															className: Watcher_module_default.turnSummary,
															children: turnSummary
														})]
													}),
													/* @__PURE__ */ (0, react_jsx_runtime.jsxs)("span", {
														className: Watcher_module_default.turnPerformance,
														children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
															className: Watcher_module_default.turnDuration,
															children: duration === null ? OVERVIEW_STATE_LABEL[turnState] : duration.kind === "exact" ? `总 ${duration.value}` : `已记录 ${duration.value}`
														}), secondaryPerformance === "" ? null : /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
															className: Watcher_module_default.turnSpeed,
															children: secondaryPerformance
														})]
													})
												]
											})
										})
									}), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
										id: `watcher-turn-body-${turn.turn}`,
										className: Watcher_module_default.turnBody,
										hidden: !turnOpen,
										children: [performance === void 0 ? null : /* @__PURE__ */ (0, react_jsx_runtime.jsx)(TurnMetricStrip, { performance }), /* @__PURE__ */ (0, react_jsx_runtime.jsxs)("div", {
											className: Watcher_module_default.groupRail,
											children: [/* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {
												className: Watcher_module_default.railLine,
												"aria-hidden": "true"
											}), turn.groups.map((group) => {
												const isNow = group.id === lastGroupId;
												const selectedGroup = ui.selectedId === group.id;
												const phaseOpen = layerDisclosureOpen(disclosure, "phase", group.id);
												return /* @__PURE__ */ (0, react_jsx_runtime.jsx)(PhaseOverview, {
													group,
													isNow,
													running: picture.running,
													now,
													selectedGroup,
													selectedItemId,
													observationMode,
													open: phaseOpen,
													disclosure,
													onToggle: () => {
														pinForDisclosure();
														setDisclosure((current) => toggleLayerDisclosure(current, "phase", group.id));
													},
													onToggleLayer: (layer, key) => {
														pinForDisclosure();
														setDisclosure((current) => toggleLayerDisclosure(current, layer, key));
													},
													onToggleReasoning: (key, modelKey) => {
														pinForDisclosure();
														setDisclosure((current) => {
															return toggleLayerDisclosure(layerDisclosureOpen(current, "reasoning", key) ? current : setLayerDisclosure(current, "model", modelKey, true), "reasoning", key);
														});
													},
													onSelectItem: (item) => selectItem(group, item)
												}, group.id);
											})]
										})]
									})]
								}, turn.turn);
							})
						})
					})
				]
			})]
		}), document.body) : null]
	});
}
//#endregion
//#region src/client/model-trace-definition.ts
const modelTraceDefinition = {
	kind: "dsh-watcher-model-stage",
	match: (event) => {
		const normalized = modelTraceEventOf(event);
		if (normalized === null) return null;
		return {
			id: `${normalized.turn}:${normalized.step}`,
			role: normalized.kind === "step-start" ? "start" : "update"
		};
	},
	start: (_context, match) => {
		const event = modelTraceEventOf(match.event);
		if (event === null || event.kind !== "step-start") throw new Error("dsh-watcher-model-stage start requires step/start");
		return startModelStepTrace(event);
	},
	update: (context, match) => {
		const event = modelTraceEventOf(match.event);
		return event === null ? context.state : updateModelStepTrace(context.state, event);
	},
	publication: (match) => {
		if (match.event.type === "step/start") return "none";
		if (match.event.type !== "assistant/chunk") return "immediate";
		return match.event.data.chunk.type === "usage" ? "none" : "animation-frame";
	},
	buildLocationData: (context, scope) => {
		if (scope !== "step" || context.state === void 0) return null;
		return {
			kind: "step",
			turn: context.state.turn,
			step: context.state.step,
			key: "dsh-watcher-model-stage",
			value: context.state
		};
	}
};
/** Register the Step-scoped, read-only model-stage projection. */
function registerModelTraceDefinition(ctx) {
	ctx.uiConversation.events.register(modelTraceDefinition);
}
//#endregion
//#region src/client/index.tsx
const name = "dsh-watcher-client";
const inject = [
	"slots",
	"sessions",
	"uiConversation"
];
/**
* Native session-header utility. Order 50 sits after Session log (0)
* and before the files-panel toggle (110). No overlay glyph.
*/
function apply(ctx) {
	registerModelTraceDefinition(ctx);
	ctx.inject(["remote", "remote.session"], (c) => {
		c.slots.inject("settings.section", () => c.slots.register({
			name: "settings.section",
			id: "watcher-insights",
			order: 85,
			label: "Watcher",
			inject: () => ({ remote: c.remote })
		}, InsightsSettings));
	});
	ctx.slots.inject("conversation.session.header.utilities", () => ctx.slots.register({
		name: "conversation.session.header.utilities",
		id: "dsh-watcher",
		order: 50,
		label: "Watcher",
		inject: (sessionId) => {
			const session = ctx.sessions.binding?.(sessionId)?.session;
			if (session === void 0) throw new Error(`dsh-watcher: session "${sessionId}" is unavailable`);
			return { loadAllHistory: (signal) => loadCompleteHistory({
				signal,
				loadOlder: () => session.loadOlder(),
				read: () => {
					const sessionSnapshot = session.getSnapshot();
					const chat = ctx.uiConversation.binding(sessionId).snapshot.getSnapshot().views.get("chat");
					if (chat === void 0) throw new Error("dsh-watcher: Chat conversation target is unavailable");
					const firstNode = chat.legacy.nodes[0];
					const firstTurn = chat.timeline.turnOrder[0];
					return {
						hasMore: sessionSnapshot.hasMore,
						loadingOlder: sessionSnapshot.loadingOlder,
						headKey: `${firstTurn ?? "none"}:${firstNode?.seq ?? "none"}:${chat.legacy.nodes.length}`
					};
				}
			}) };
		}
	}, Watcher));
}
//#endregion
exports.apply = apply;
exports.inject = inject;
exports.name = name;

		return module.exports;
	}
});

//# sourceMappingURL=client.js.map