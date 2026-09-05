///|
/// 每插件的 **O(1) 增量尾计数器**。
/// 取代 legacy-ts/src/monitor/index.ts L220-250（`checkForSignals`）里的
/// 两次 `countTrailing`（L282-292）与那次 `sessionEvents.filter(...)`（L221-223）。
///
/// **为什么这是热路径**：`recordToolCall` 每次工具调用都会走一遍
/// `checkForSignals`，而 TS 的实现是
/// ```ts
/// const recentToolCalls = this.sessionEvents.filter(e => e.plugin_id === pluginId && ...)
/// const consecutiveFailures = this.countTrailing(recentToolCalls, e => !e.event_data.success)
/// const loopCount = this.countTrailing(recentToolCalls, e => e.event_data.tool === toolName)
/// ```
/// 即 **每次工具调用都重新过滤全部会话事件（上限 500，L23）并倒序扫两遍** ——
/// O(500) 的内存遍历，稳态下每次调用都触发。
///
/// 新版把它降为 **3 个整数字段的读写**：
/// · `consecutive_failures` —— 失败则 +1，成功则清零
/// · `same_tool_run` / `last_tool` —— 工具名相同则 +1，否则重置为 1
///
/// **等价性论证**：`countTrailing(xs, p)` 返回「xs 尾部连续满足 p 的元素个数」。
/// 对谓词 `!success`，增量维护「失败 +1 / 成功清零」与之逐元素等价；
/// 对谓词 `tool == currentTool`，增量维护「同名 +1 / 异名重置 1」同样等价
/// ——因为 `currentTool` 就是最新那条事件的工具名，尾部连续同名段的长度
/// 必然等于「从最新往回数直到遇到不同名为止」的计数。
///
/// **一处已知的语义收窄**（已论证无害）：TS 的计数建立在被 500 上限裁剪过的
/// `sessionEvents` 上，若某插件的尾部连续段长于 500，TS 会低估。
/// 增量计数器没有这个上限，因此在这种极端情况下**更准确**。
/// 触发条件是「同一插件连续 500 次工具调用且全部失败 / 全部同名」，
/// 而这恰好是本模块要检测并上报的循环行为 —— 更准确是正确方向。
///
/// 这也**强化了 CONTEXT.md 不变量③**：原文是「信号检测热路径不读磁盘」，
/// 新版进一步做到「热路径不做超过 O(1) 的工作」。

///|
/// 一个插件的尾部计数状态。
pub(all) struct TrailingState {
  /// 尾部连续失败次数（对齐 TS L226-227，阈值 3）
  mut consecutive_failures : Int
  /// 上一次调用的工具名
  mut last_tool : String
  /// 尾部连续同名工具次数（对齐 TS L237-238，阈值 5）
  mut same_tool_run : Int
}

///|
/// 初始状态：还没有任何调用。
pub fn TrailingState::new() -> TrailingState {
  { consecutive_failures: 0, last_tool: "", same_tool_run: 0 }
}

///|
/// 消费一次工具调用，O(1) 更新全部计数。
///
/// 顺序不可调换：`same_tool_run` 的判定依赖**更新前**的 `last_tool`。
pub fn TrailingState::observe(
  self : TrailingState,
  tool : String,
  success : Bool,
) -> Unit {
  if success {
    self.consecutive_failures = 0
  } else {
    self.consecutive_failures += 1
  }
  if tool == self.last_tool {
    self.same_tool_run += 1
  } else {
    self.last_tool = tool
    self.same_tool_run = 1
  }
}
