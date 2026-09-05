///|
/// monitor 的测试。1-10 移植自 legacy-ts/tests/monitor.test.ts 的 10 个用例，
/// 11 起是本次改造新增的（O(1) 尾计数器、窗口聚合、时间窗过滤）。
///
/// 隔离方式对应 legacy 的 `beforeEach(fs.mkdtemp)` / `afterEach(fs.remove)`：
/// `@fs.tmpdir` + `defer @fs.rmdir(recursive=true)`。
/// TS 的 `beforeEach` 还会 `await monitor.start()`（启动 setInterval），
/// 本仓的 flush 循环改由 task group 托管（见 `run_flush_loop`），
/// 测试里不需要它 —— 直接调 `flush_buffers()` / `shutdown()` 即可，
/// 于是用例不依赖任何真实定时器，跑得又快又稳。

fn make_monitor(dir : String) -> PerformanceMonitor {
  PerformanceMonitor::new(
    @util.path_join(dir, "metrics.jsonl"),
    @util.path_join(dir, "signals.jsonl"),
  )
}

fn signals_path(dir : String) -> String {
  @util.path_join(dir, "signals.jsonl")
}

fn metrics_path(dir : String) -> String {
  @util.path_join(dir, "metrics.jsonl")
}

///|
/// 读回落盘的信号。对应 legacy 的
/// `new JsonlStore<EvolutionSignal>(signalsPath).load()`。
async fn load_signals(dir : String) -> Array[@types.EvolutionSignal] {
  let store = @store.Jsonl::new(signals_path(dir))
  store.load()
}

async fn load_events(dir : String) -> Array[@types.PerformanceEvent] {
  let store = @store.Jsonl::new(metrics_path(dir))
  store.load()
}

///|
/// 按类别挑出第一条信号。对应 legacy 的 `signals.find(s => s.category === 'x')`。
fn find_by_category(
  signals : ArrayView[@types.EvolutionSignal],
  category : @types.SignalCategory,
) -> @types.EvolutionSignal? {
  for s in signals {
    if s.category == category {
      return Some(s)
    }
  }
  None
}

// ----------------------------------------------------------------------------
// 测试辅助。
// 均为顶层函数：MoonBit 不允许在 test 块内嵌套定义 `fn`。
// ----------------------------------------------------------------------------

///|
/// 一份成功的最小工具调用数据。
fn tool_call(tool : String) -> @types.ToolCallData {
  {
    tool,
    params: Json::empty_object(),
    latency_ms: 1,
    success: true,
    token_usage: None,
    retry_count: 0,
    error_message: None,
  }
}

///|
/// 一份带指定错误消息的失败调用数据。
fn failed_call(msg : String) -> @types.ToolCallData {
  {
    tool: "a",
    params: Json::empty_object(),
    latency_ms: 1,
    success: false,
    token_usage: None,
    retry_count: 0,
    error_message: Some(msg),
  }
}

///|
/// 一条指定时间戳的工具调用事件（用于造历史数据而不靠真实等待）。
fn event_at(plugin_id : String, tool : String, ts : Int64) -> @types.PerformanceEvent {
  {
    session_id: "sess-old",
    plugin_id,
    ts,
    payload: @types.EventPayload::ToolCall(tool_call(tool)),
    context: {
      task_type: None,
      user_feedback: None,
      conversation_turn: 0,
      related_tools: None,
    },
  }
}

// ============================================================================
// 移植：recordToolCall + getStatistics（legacy L27-66）
// ============================================================================

///|
/// 移植：monitor.test.ts L28-39 "should aggregate success rate and latency"
async test "aggregates success rate and latency" {
  let dir = @fs.tmpdir(prefix="evo-mon-")
  defer @fs.rmdir(dir, recursive=true)
  let mon = make_monitor(dir)

  mon.record_tool_call("p-1", "navigate", Json::empty_object(), 100, true)
  mon.record_tool_call("p-1", "click", Json::empty_object(), 200, true)
  mon.record_tool_call(
    "p-1",
    "type",
    Json::empty_object(),
    300,
    false,
    error_message=Some("timeout"),
  )

  let stats = mon.get_statistics("p-1")
  assert_eq(stats.total_calls, 3)
  // toBeCloseTo(2/3)：双精度下逐位相等即可，但为稳健起见比到 1e-9
  // 注：MoonBit 没有 `1e-9` 这种指数字面量，必须写完整小数
  assert_true((stats.success_rate - 2.0 / 3.0).abs() < 0.000000001)
  assert_eq(stats.avg_latency_ms, 200.0)
  json_inspect(stats.error_types, content=[("timeout", 1)])
}

///|
/// 移植：monitor.test.ts L41-48 "should aggregate token usage"
async test "aggregates token usage" {
  let dir = @fs.tmpdir(prefix="evo-mon-")
  defer @fs.rmdir(dir, recursive=true)
  let mon = make_monitor(dir)

  mon.record_tool_call(
    "p-1",
    "navigate",
    Json::empty_object(),
    100,
    true,
    token_usage=Some({ input: 10, output: 20, total: 30 }),
  )
  mon.record_tool_call(
    "p-1",
    "click",
    Json::empty_object(),
    100,
    true,
    token_usage=Some({ input: 5, output: 5, total: 10 }),
  )

  assert_eq(mon.get_statistics("p-1").total_tokens, 40)
}

///|
/// 移植：monitor.test.ts L50-58 "should isolate statistics per plugin"
async test "isolates statistics per plugin" {
  let dir = @fs.tmpdir(prefix="evo-mon-")
  defer @fs.rmdir(dir, recursive=true)
  let mon = make_monitor(dir)

  mon.record_tool_call("p-1", "navigate", Json::empty_object(), 100, true)
  mon.record_tool_call("p-2", "navigate", Json::empty_object(), 999, true)

  let stats = mon.get_statistics("p-1")
  assert_eq(stats.total_calls, 1)
  assert_eq(stats.avg_latency_ms, 100.0)
}

///|
/// 移植：monitor.test.ts L60-65 "should return zeroed stats for an unknown plugin"
///
/// 新版这条路径**不触发任何磁盘访问**：TS 会先 `flushBuffers()` 落盘再全量 `load()`
/// （L149-150），即使该插件根本不存在。
async test "returns zeroed stats for an unknown plugin" {
  let dir = @fs.tmpdir(prefix="evo-mon-")
  defer @fs.rmdir(dir, recursive=true)
  let mon = make_monitor(dir)

  let stats = mon.get_statistics("nope")
  assert_eq(stats.total_calls, 0)
  assert_eq(stats.loop_detected, false)
  assert_eq(stats.success_rate, 0.0)
  assert_eq(stats.avg_latency_ms, 0.0)
  json_inspect(stats.error_types, content=[])
}

// ============================================================================
// 移植：signal detection（legacy L68-128）
// ============================================================================

///|
/// 移植：monitor.test.ts L69-80
/// "should emit a struggle signal after 3 consecutive failures"
async test "emits a struggle signal after 3 consecutive failures" {
  let dir = @fs.tmpdir(prefix="evo-mon-")
  defer @fs.rmdir(dir, recursive=true)
  let mon = make_monitor(dir)

  for _ in 0..<3 {
    mon.record_tool_call(
      "p-1",
      "a",
      Json::empty_object(),
      10,
      false,
      error_message=Some("runtime error"),
    )
  }
  mon.shutdown() // flush signal buffer（对应 legacy 的 await monitor.stop()）

  let signals = load_signals(dir)
  let struggle = find_by_category(signals, @types.SignalCategory::Struggle)
  assert_true(struggle is Some(_))
  match struggle {
    Some(s) => {
      assert_eq(s.strength, @types.SignalStrength::Strong)
      // toBeGreaterThanOrEqual(3)
      assert_true(s.count.unwrap_or(0) >= 3)
      assert_eq(s.description, "3 consecutive failures detected")
    }
    None => ()
  }
}

///|
/// 移植：monitor.test.ts L82-90
/// "should not emit a struggle signal for fewer than 3 consecutive failures"
async test "does not emit a struggle signal below the failure threshold" {
  let dir = @fs.tmpdir(prefix="evo-mon-")
  defer @fs.rmdir(dir, recursive=true)
  let mon = make_monitor(dir)

  mon.record_tool_call("p-1", "a", Json::empty_object(), 10, true)
  mon.record_tool_call(
    "p-1",
    "a",
    Json::empty_object(),
    10,
    false,
    error_message=Some("error"),
  )
  mon.shutdown()

  let signals = load_signals(dir)
  // legacy 断言的是 `s.category === 'struggle' && s.count` 的数量为 0
  let mut struggle_with_count = 0
  for s in signals {
    if s.category == @types.SignalCategory::Struggle && s.count is Some(_) {
      struggle_with_count += 1
    }
  }
  assert_eq(struggle_with_count, 0)
}

///|
/// 移植：monitor.test.ts L92-103
/// "should emit a loop signal after 5 consecutive calls of the same tool"
async test "emits a loop signal after 5 consecutive calls of the same tool" {
  let dir = @fs.tmpdir(prefix="evo-mon-")
  defer @fs.rmdir(dir, recursive=true)
  let mon = make_monitor(dir)

  for _ in 0..<5 {
    mon.record_tool_call("p-1", "navigate", Json::empty_object(), 10, true)
  }
  mon.shutdown()

  let signals = load_signals(dir)
  let loop_signal = find_by_category(signals, @types.SignalCategory::Loop)
  assert_true(loop_signal is Some(_))
  match loop_signal {
    Some(s) => {
      assert_eq(s.strength, @types.SignalStrength::Medium)
      // toContain('navigate')
      assert_true(s.description.contains("navigate"))
      assert_eq(s.description, "Tool navigate called 5 times in loop")
      // ★ 新增字段：工具名是结构化的，engine 不必再用正则从描述里反解
      assert_eq(s.tool, Some("navigate"))
      assert_eq(s.count, Some(5))
    }
    None => ()
  }
}

///|
/// TS L238-246 的 `loopReported` 去重：同一段循环**只上报一次**，
/// 否则连续调用 20 次会产生 16 条重复信号刷屏。
/// 低于阈值时标记被清除，于是下一段循环能再次上报。
async test "emits the loop signal once per episode, then re-arms" {
  let dir = @fs.tmpdir(prefix="evo-mon-")
  defer @fs.rmdir(dir, recursive=true)
  let mon = make_monitor(dir)

  // 8 次同名调用：只在第 5 次发一条
  for _ in 0..<8 {
    mon.record_tool_call("p-1", "navigate", Json::empty_object(), 10, true)
  }
  // 换一个工具，把 same_tool_run 打断（降到阈值以下 → 清除已报告标记）
  mon.record_tool_call("p-1", "click", Json::empty_object(), 10, true)
  // 再来 5 次 navigate：应当再次上报
  for _ in 0..<5 {
    mon.record_tool_call("p-1", "navigate", Json::empty_object(), 10, true)
  }
  mon.shutdown()

  let signals = load_signals(dir)
  let mut loop_count = 0
  for s in signals {
    if s.category == @types.SignalCategory::Loop {
      loop_count += 1
    }
  }
  assert_eq(loop_count, 2)
}

///|
/// 移植：monitor.test.ts L105-115
/// "should emit a correction signal on negative user feedback"
async test "emits a correction signal on negative user feedback" {
  let dir = @fs.tmpdir(prefix="evo-mon-")
  defer @fs.rmdir(dir, recursive=true)
  let mon = make_monitor(dir)

  mon.record_tool_call("p-1", "a", Json::empty_object(), 10, true)
  mon.record_user_feedback(
    "p-1",
    @types.UserFeedback::Negative,
    context=Some("wrong behavior"),
  )
  mon.shutdown()

  let signals = load_signals(dir)
  let correction = find_by_category(signals, @types.SignalCategory::Correction)
  assert_true(correction is Some(_))
  match correction {
    Some(s) => {
      assert_eq(s.strength, @types.SignalStrength::Strong)
      assert_eq(s.description, "User gave negative feedback: wrong behavior")
    }
    None => ()
  }
}

///|
/// 移植并**加强**：monitor.test.ts L117-127
/// "should update the last event feedback in memory"
///
/// legacy 那条用例的注释承认它只验证「不报错」（`events.length` 为 1），
/// 并明说 "flushed events keep whatever feedback the buffer had at flush time"。
/// 这不是偷懒 —— 而是因为这个回填**对已落盘的事件确实不可见**：
/// 首次 `record_tool_call` 会触发 `maybe_deep_check` → `get_statistics`
/// → `get_metrics` → `flush_buffers`（TS L249 → L262 → L149 的同一条链），
/// 所以等到 `record_user_feedback` 时事件已经在磁盘上了。
///
/// 因此本用例断言的是**会话环形副本**（回填真正生效的地方），
/// 而不是落盘内容 —— 后者只会得到 `user_feedback: None`，TS 也一样。
/// MoonBit 的值语义让这块内存状态第一次变得可直接断言（TS 靠对象引用
/// 共享隐式生效，从外部观察不到）。
async test "backfills user feedback onto the in-memory session ring" {
  let dir = @fs.tmpdir(prefix="evo-mon-")
  defer @fs.rmdir(dir, recursive=true)
  let mon = make_monitor(dir)

  mon.record_tool_call("p-1", "a", Json::empty_object(), 10, true)
  mon.record_tool_call("p-2", "b", Json::empty_object(), 10, true)
  // 只回填 p-1；p-2 不应受影响
  mon.record_user_feedback("p-1", @types.UserFeedback::Positive)

  // 环形副本里 p-1 的最后一条拿到了反馈，p-2 的仍为空
  assert_eq(
    feedback_in_ring(mon, "p-1"),
    Some(@types.UserFeedback::Positive),
  )
  assert_eq(feedback_in_ring(mon, "p-2"), None)

  // legacy 的可观察断言：两条事件最终都落盘了
  mon.shutdown()
  let events = load_events(dir)
  assert_eq(events.length(), 2)
}

///|
/// 从会话环形副本里取某插件最后一条事件的反馈。
/// 白盒访问 `session_events` 私有字段 —— 这正是白盒测试的用途。
fn feedback_in_ring(
  mon : PerformanceMonitor,
  plugin_id : String,
) -> @types.UserFeedback? {
  let n = mon.session_events.length()
  for i = n - 1; i >= 0; i = i - 1 {
    let event = mon.session_events.at(i)
    if event.plugin_id == plugin_id {
      return event.context.user_feedback
    }
  }
  None
}

///|
/// 移植：monitor.test.ts L131-138
/// "should flush buffered events to the metrics file on stop"
async test "flushes buffered events to the metrics file on shutdown" {
  let dir = @fs.tmpdir(prefix="evo-mon-")
  defer @fs.rmdir(dir, recursive=true)
  let mon = make_monitor(dir)

  mon.record_tool_call("p-1", "navigate", Json::empty_object(), 50, true)
  mon.shutdown()

  let events = load_events(dir)
  assert_eq(events.length(), 1)
  // 对应 legacy 的 toMatchObject({ tool: 'navigate', success: true })
  match events[0].payload {
    @types.EventPayload::ToolCall(d) => {
      assert_eq(d.tool, "navigate")
      assert_eq(d.success, true)
      assert_eq(d.latency_ms, 50)
    }
    _ => abort("expected a ToolCall payload")
  }
}

///|
/// ★ 钉住一个**反直觉但忠实于 TS** 的行为：
/// 某插件的**首次** `record_tool_call` 会立即把缓冲落盘。
///
/// 链路：`record_tool_call` → `check_for_signals` → `maybe_deep_check`
/// → `get_statistics` → `get_metrics` → `flush_buffers`，
/// 逐一对应 TS 的 L116 → L249 → L262 → L171 → L149。
/// 而 `maybe_deep_check` 的节流判定是 `now - last < 30_000`（TS L258），
/// `last` 初始为 0 → 首次必然通过。
///
/// 把它写成用例有两个理由：
/// 1. 它解释了「为何 `pending_event_count()` 常常是 0」，
///    否则很容易被当成丢事件的 bug 去「修」，反而偏离 TS 行为；
/// 2. 第二次调用被节流挡住 → 事件留在缓冲里，证明节流真的生效。
async test "the first tool call per plugin flushes eagerly via the deep check" {
  let dir = @fs.tmpdir(prefix="evo-mon-")
  defer @fs.rmdir(dir, recursive=true)
  let mon = make_monitor(dir)

  mon.record_tool_call("p-1", "a", Json::empty_object(), 10, true)
  // 深度检查立即触发 → 缓冲已被清空，事件已在磁盘上
  assert_eq(mon.pending_event_count(), 0)
  assert_eq((load_events(dir)).length(), 1)

  // 第二次调用被 30s 节流挡住 → 事件留在缓冲里，尚未落盘
  mon.record_tool_call("p-1", "b", Json::empty_object(), 10, true)
  assert_eq(mon.pending_event_count(), 1)
  assert_eq((load_events(dir)).length(), 1)

  // 另一个插件有自己的节流计时，故它的首次调用同样会提前 flush
  mon.record_tool_call("p-2", "c", Json::empty_object(), 10, true)
  assert_eq(mon.pending_event_count(), 0)
  assert_eq((load_events(dir)).length(), 3)
}

// ============================================================================
// 新增：本次改造引入的机制
// ============================================================================

///|
/// O(1) 增量尾计数器的纯函数断言。
/// 它必须与 TS 的 `countTrailing` 逐元素等价（见 trailing.mbt 的等价性论证）。
test "TrailingState matches countTrailing semantics" {
  let st = TrailingState::new()
  assert_eq(st.consecutive_failures, 0)
  assert_eq(st.same_tool_run, 0)

  // 失败累加
  st.observe("a", false)
  st.observe("a", false)
  assert_eq(st.consecutive_failures, 2)
  assert_eq(st.same_tool_run, 2)
  st.observe("a", false)
  assert_eq(st.consecutive_failures, 3)

  // 成功清零失败计数，但同名连续段继续
  st.observe("a", true)
  assert_eq(st.consecutive_failures, 0)
  assert_eq(st.same_tool_run, 4)

  // 换工具 → 同名段重置为 1
  st.observe("b", true)
  assert_eq(st.same_tool_run, 1)
  assert_eq(st.last_tool, "b")

  // 再失败
  st.observe("b", false)
  assert_eq(st.consecutive_failures, 1)
  assert_eq(st.same_tool_run, 2)
}

///|
/// `detect_loops` 的窗口语义（TS L319-339）：不足 5 条为 false；
/// 只看最近 10 条；窗口内任一工具 >= 5 次即 true（**不要求连续**）。
test "detect_loops counts within the last ten, not necessarily consecutive" {
  // 不足 5 条
  assert_eq(
    detect_loops(
      [tool_call("a"), tool_call("a"), tool_call("a"), tool_call("a")],
    ),
    false,
  )
  // 恰好 5 条同名
  assert_eq(
    detect_loops(
      [tool_call("a"), tool_call("a"), tool_call("a"), tool_call("a"), tool_call("a")],
    ),
    true,
  )
  // 5 次同名但**不连续** —— 窗口频次判定，与 TrailingState 的连续判定不同
  assert_eq(
    detect_loops(
      [
        tool_call("a"), tool_call("b"), tool_call("a"), tool_call("b"),
        tool_call("a"), tool_call("b"), tool_call("a"), tool_call("b"),
        tool_call("a"),
      ],
    ),
    true,
  )
  // 只看最近 10 条：前 5 条 "old" 已滑出窗口，窗内全是 "new"
  let many : Array[@types.ToolCallData] = []
  for _ in 0..<5 {
    many.push(tool_call("old"))
  }
  for _ in 0..<10 {
    many.push(tool_call("new"))
  }
  assert_eq(detect_loops(many), true)

  // 窗口内每个工具都只有 4 次 → false
  let mixed : Array[@types.ToolCallData] = []
  for _ in 0..<4 {
    mixed.push(tool_call("x"))
  }
  for _ in 0..<4 {
    mixed.push(tool_call("y"))
  }
  for _ in 0..<2 {
    mixed.push(tool_call("z"))
  }
  assert_eq(mixed.length(), 10)
  assert_eq(detect_loops(mixed), false)
}

///|
/// `summarize` 保留 JS `tokenUsage.total || (input + output)` 的怪癖：
/// `total` 为 **0** 时被视为 falsy，回退到分项之和。
test "summarize treats a zero token total as absent, like JS ||" {
  let zero_total : @types.ToolCallData = {
    tool: "a",
    params: Json::empty_object(),
    latency_ms: 10,
    success: true,
    token_usage: Some({ input: 7, output: 3, total: 0 }),
    retry_count: 0,
    error_message: None,
  }
  assert_eq(summarize([zero_total]).total_tokens, 10)

  let real_total : @types.ToolCallData = {
    tool: "a",
    params: Json::empty_object(),
    latency_ms: 10,
    success: true,
    token_usage: Some({ input: 7, output: 3, total: 99 }),
    retry_count: 0,
    error_message: None,
  }
  assert_eq(summarize([real_total]).total_tokens, 99)

  let no_usage : @types.ToolCallData = {
    tool: "a",
    params: Json::empty_object(),
    latency_ms: 10,
    success: false,
    token_usage: None,
    retry_count: 2,
    error_message: Some("permission denied"),
  }
  let stats = summarize([no_usage])
  assert_eq(stats.total_tokens, 0)
  assert_eq(stats.avg_retry_count, 2.0)
  assert_eq(stats.success_rate, 0.0)
  json_inspect(stats.error_types, content=[("permission_error", 1)])
}

///|
/// `error_types` 必须按 wire 名**字典序**排列 —— MoonBit 的 Map 迭代序不定，
/// 直接序列化会让 MCP 每次返回的字段顺序都可能不同（决策 D10 / 修 R5）。
test "error_types is sorted lexicographically for deterministic output" {
  let stats = summarize(
    [
      failed_call("permission denied"),
      failed_call("timeout"),
      failed_call("not found"),
      failed_call("timeout"),
      failed_call("weird"),
    ],
  )
  json_inspect(
    stats.error_types,
    content=[
      ("not_found", 1),
      ("permission_error", 1),
      ("runtime_error", 1),
      ("timeout", 2),
    ],
  )
}

///|
/// 时间窗过滤：`last_hour` 只看最近一小时。
/// 这里用**直接落盘**的历史事件构造时间差，不依赖真实等待。
async test "time range filtering excludes older events" {
  let dir = @fs.tmpdir(prefix="evo-mon-")
  defer @fs.rmdir(dir, recursive=true)
  let metrics = @store.Jsonl::new(metrics_path(dir))
  let mon = make_monitor(dir)

  let now = @util.now_ms()
  let hour : Int64 = 3_600_000L
  // 两条历史事件：2 小时前（在 last_week 内）与 8 天前（在 last_week 外）
  metrics.append(event_at("p-1", "old-hour", now - 2 * hour))
  metrics.append(event_at("p-1", "old-day", now - 8 * 24 * hour))
  // 一条当前事件
  mon.record_tool_call("p-1", "fresh", Json::empty_object(), 100, true)

  let all = mon.get_metrics("p-1")
  assert_eq(all.length(), 3)
  let last_hour = mon.get_metrics("p-1", time_range=@types.TimeRange::LastHour)
  assert_eq(last_hour.length(), 1)
  assert_true(last_hour[0].payload is @types.EventPayload::ToolCall(_))
  let last_week = mon.get_metrics("p-1", time_range=@types.TimeRange::LastWeek)
  assert_eq(last_week.length(), 2)

  // 统计也遵循同一窗口
  assert_eq(mon.get_statistics("p-1").total_calls, 3)
  assert_eq(
    mon.get_statistics("p-1", time_range=@types.TimeRange::LastHour).total_calls,
    1,
  )
}

///|
/// `session_id` 必须在同进程内唯一（TS 用 Math.random，本仓用单调序号）。
/// 若两个 monitor 拿到同一个 id，事件归属就会混在一起。
async test "session ids are unique within a process" {
  let dir = @fs.tmpdir(prefix="evo-mon-")
  defer @fs.rmdir(dir, recursive=true)
  let a = make_monitor(dir)
  let b = make_monitor(dir)
  assert_true(a.session_id() != b.session_id())
  assert_true(a.session_id().has_prefix("sess_"))
}

///|
/// 会话环形副本的上限：超过 500 条后从头部丢弃，`Deque` 两端都是 O(1)
/// （取代 TS L374 的 `splice`，那是稳态下每次事件都 O(n) 搬移）。
///
/// 真正的不变量是「一条事件也不丢」：上限只约束**会话副本**（供反馈回填用），
/// 不约束待落盘缓冲。后者最终全部进磁盘。
async test "session event ring is capped without losing events" {
  let dir = @fs.tmpdir(prefix="evo-mon-")
  defer @fs.rmdir(dir, recursive=true)
  let mon = make_monitor(dir)

  for i in 0..<600 {
    mon.record_tool_call(
      "p-1",
      "tool\{i % 3}",
      Json::empty_object(),
      10,
      true,
    )
  }
  // 环形副本被上限截断到 500
  assert_eq(mon.session_events.length(), max_session_events_for_test)
  // 但事件一条不丢：首次调用因 maybe_deep_check 提前 flush 了一条，
  // 其余留在缓冲里，shutdown 后全部落盘
  mon.shutdown()
  assert_eq((load_events(dir)).length(), 600)
}

///|
/// `max_session_events` 是包内私有常量，白盒测试里用同值镜像一份。
/// 若两者不一致，上面那条断言会立即失败。
let max_session_events_for_test : Int = 500
