///|
/// 性能监控器。取代 legacy-ts/src/monitor/index.ts L28-399。
///
/// 职责：记录工具调用事件 → 检测进化信号 → 缓冲落盘 → 提供聚合统计。
///
/// **CONTEXT.md 不变量③在此被强化**：原文是「信号检测热路径不读磁盘」，
/// 新版进一步做到「热路径不做超过 O(1) 的工作」——
/// 失败/循环检测由 `trailing.mbt` 的增量计数器完成（见该文件的等价性论证），
/// 不再像 TS 那样每次调用都 `sessionEvents.filter(...)` 重扫最多 500 条事件
/// 并倒序遍历两遍。磁盘深度检查仍受 `deep_check_interval_ms` 节流，语义不变。
///
/// **相对 TS 的三处并发安全改进**：
/// 1. TS L55-57 的 `setInterval(() => { void this.flushBuffers() }, 5000)`
///    用 `void` 丢弃 Promise —— 异常无人处理，且 flush 可重入。
///    新版把循环交给结构化并发的 task group，串行执行、异常经
///    `allow_failure=true` 隔离，退出前由 `add_defer` 保证最后一次 flush。
/// 2. `flush_buffers` 严格「**先换出、后 await**」：换出与清空之间没有任何
///    await 点，而 MoonBit async 是单线程协作式调度、只在 await 处让出，
///    因此不需要互斥锁就不可能重入。
/// 3. TS 的 `sessionEvents` 环形副本（L23 / L35 / L374）在本仓**没有生产读取方**，
///    已整体删除 —— 它唯一的用途（反馈回填）在待落盘的 `event_buffer` 上完成，
///    会话内重复维护一份每次事件都搬移的副本是纯开销。

///|
let deep_check_interval_ms : Int64 = 30_000L // ← TS L26 DEEP_CHECK_INTERVAL_MS

///|
let flush_interval_ms : Int = 5000 // ← TS L57 setInterval 的周期

///|
/// 单个待落盘缓冲的上限。
///
/// 有了「写失败就把事件放回缓冲」之后，缓冲不再必然随 flush 归零 ——
/// 磁盘长期写不进去时，它等于替磁盘把内存吃光。故设上界：溢出时丢弃**最旧**的
/// 条目并告警。丢最旧是刻意的 —— 故障期间的历史已无法补救，而留给进化引擎的
/// 应该是最近的样本。1000 条 ≈ 正常节奏下约 5s/批 × 数十轮的量，
/// 不会在磁盘健康时误伤（健康时每轮 flush 都会清零）。
let max_buffered_items : Int = 1000

///|
/// 信号缓冲的有界上限。信号产生速率远低于事件（只有特定模式被检测到时才发射），
/// 故上限低于 `max_buffered_items`。磁盘长期写不进去时，溢出丢最旧的并告警。
let max_buffered_signals : Int = 500

///|
/// 会话 id 的进程内单调序号。
///
/// TS 用 `sess_${Date.now().toString(36)}_${Math.random().toString(36).slice(2,11)}`
/// （L396-398）。新版改用单调序号，理由有二：
/// · 同样保证进程内唯一（时间戳 + 序号）
/// · **可复现** —— 测试断言不必容忍随机性，双跑对拍也能逐字节比对
/// 代价是跨进程同毫秒启动时可能重复；但 session_id 只用于把事件归属到会话，
/// 全仓没有任何逻辑依赖它的跨进程唯一性。
let session_seq : @ref.Ref[Int] = @ref.Ref(0)

///|
/// 生成本进程的会话 id。
pub fn new_session_id() -> String {
  let n = session_seq.val
  session_seq.val = n + 1
  "sess_\{@util.now_ms().to_string(radix=36)}_\{n.to_string(radix=36)}"
}

// `fixed1` 与 `maybe_deep_check` 已拆分至 deep_check.mbt。

///|
/// 性能监控器。
pub struct PerformanceMonitor {
  metrics : @store.Jsonl
  signals : @store.Jsonl
  session_id : String
  /// 待落盘的性能事件（对应 TS L32 eventBuffer）
  event_buffer : Array[@types.PerformanceEvent]
  /// 待落盘的信号（对应 TS L33 signalBuffer）。
  /// 用 Deque：溢出丢最旧的 `pop_front` 是 O(1)，取代 `Array::remove(0)` 的 O(n) 搬移。
  signal_buffer : @deque.Deque[@types.EvolutionSignal]
  /// 每插件的 O(1) 尾计数器
  trailing : Map[String, TrailingState]
  /// 已发射过 loop 信号的 `plugin:tool` 集合（对应 TS L38 loopReported）。
  /// 用 Map 而非 Set：只需存在性，且 Map 的 remove/contains 已确认可用。
  /// 使用 @ref.Ref 包装，允许 check_threshold_and_report 辅助函数就地修改。
  loop_reported : @ref.Ref[Map[String, Unit]]
  /// 已发射过 struggle 信号的插件集合（解决已知缺陷#11）。
  /// 每个插件只报告一次 struggle 信号，直到连续失败解除后才能再次报告。
  /// 使用 @ref.Ref 包装，允许 check_threshold_and_report 辅助函数就地修改。
  struggle_reported : @ref.Ref[Map[String, Unit]]
  /// 每插件上次深度检查的时刻（对应 TS L36 lastDeepCheckAt）
  last_deep_check_at : Map[String, Int64]
  /// 信号阈值（默认取 TS 的三个硬编码常量，可由配置覆盖）
  thresholds : @types.SignalThresholds
  /// 观测日志（metrics / signals 两个 JSONL）的保留上限（字节），
  /// 来自 `EngineConfig.max_log_bytes`。0 = 不裁剪（测试豁免用）。
  max_log_bytes : Int
  /// 缓冲区是否有新数据未落盘（脏标记）
  buffers_dirty : @ref.Ref[Bool]
}

///|
/// 按文件路径构造。对应 legacy-ts 的
/// `new PerformanceMonitor(metricsPath, signalsPath)`（tests/monitor.test.ts L18）。
pub fn PerformanceMonitor::new(
  metrics_path : String,
  signals_path : String,
) -> PerformanceMonitor {
  PerformanceMonitor::with_thresholds(
    metrics_path,
    signals_path,
    @types.SignalThresholds::default(),
  )
}

///|
/// 带自定义阈值构造。阈值来自 `.zcode-plugin/plugin.json` 的
/// `evolution_config.signal_thresholds`（见 types/config.mbt）。
/// `max_log_bytes` 来自 `evolution_config.max_log_bytes`，缺省 32 MiB。
pub fn PerformanceMonitor::with_thresholds(
  metrics_path : String,
  signals_path : String,
  thresholds : @types.SignalThresholds,
  max_log_bytes? : Int = @types.default_max_log_bytes,
) -> PerformanceMonitor {
  {
    metrics: @store.Jsonl::new(metrics_path),
    signals: @store.Jsonl::new(signals_path),
    session_id: new_session_id(),
    event_buffer: [],
    signal_buffer: @deque.Deque([], capacity=max_buffered_signals),
    trailing: Map([]),
    loop_reported: @ref.Ref(Map([])),
    struggle_reported: @ref.Ref(Map([])),
    last_deep_check_at: Map([]),
    thresholds,
    max_log_bytes,
    buffers_dirty: @ref.Ref(false),
  }
}

///|
/// 用 `DataPaths` 构造（生产路径），并接上 `evolution_config`。
///
/// ★ **config 必须从这里进来**：`thresholds` 与 `max_log_bytes` 的消费方是
/// 本 monitor（`check_for_signals` / `flush_buffers`），而 engine 只读
/// `intensity` / `cooldown_hours`（`auto_approve` 无消费方，见
/// `types/config.mbt`）。过去这个构造点丢弃
/// config、转手走 `new()` 的默认值，于是「改 plugin.json 里的阈值或日志上限」
/// 在运行时一动不动 —— H2 把解析侧的配置孤岛修通了，构造侧却还留着
/// 同一个洞。可选参数带默认值，`at(paths)` 的老调用点行为不变。
pub fn PerformanceMonitor::at(
  paths : @store.DataPaths,
  config? : @types.EngineConfig = @types.EngineConfig::default(),
) -> PerformanceMonitor {
  let thresholds = config.thresholds
  let max_log_bytes = config.max_log_bytes
  PerformanceMonitor::with_thresholds(
    paths.metrics(),
    paths.signals(),
    thresholds,
    max_log_bytes~,
  )
}

///|
/// 本监控器的会话 id。
pub fn PerformanceMonitor::session_id(self : PerformanceMonitor) -> String {
  self.session_id
}

// ============================================================================
// 记录
// ============================================================================

///|
/// 记录一次工具调用。取代 legacy-ts L79-117。
///
/// 参数顺序与 TS 一致；可选参数用标签形式，调用点得以只写关心的那几个
/// （TS 版因为位置参数，测试里要写 `recordToolCall('p-1','a',{},10,false,undefined,0,'error')`
/// 这种一串 undefined 的形式）。
pub async fn PerformanceMonitor::record_tool_call(
  self : PerformanceMonitor,
  plugin_id : String,
  tool : String,
  params : Json,
  latency_ms : Int,
  success : Bool,
  token_usage? : @types.TokenUsage? = None,
  retry_count? : Int = 0,
  error_message? : String? = None,
  context? : @types.EventContext? = None,
) -> Unit {
  let event : @types.PerformanceEvent = {
    session_id: self.session_id,
    plugin_id,
    ts: @util.now_ms(),
    payload: @types.EventPayload::ToolCall({
      tool,
      params,
      latency_ms,
      success,
      token_usage,
      retry_count,
      error_message,
    }),
    context: match context {
      Some(c) => c
      // 对齐 TS L104-109：conversation_turn 缺省 0，其余缺省空
      None =>
        {
          task_type: None,
          user_feedback: None,
          conversation_turn: 0,
          related_tools: None,
        }
    },
  }

  self.event_buffer.push(event)
  self.buffers_dirty.val = true
  self.check_for_signals(plugin_id, tool, success)
}

///|
/// 记录用户反馈。取代 legacy-ts L122-139。
///
/// 两件事：① 回填该插件最近一条事件的 `user_feedback`；② 负面反馈发 strong/correction 信号。
///
/// 回填作用于待落盘的 `event_buffer`：TS 里 `sessionEvents` 与 `eventBuffer`
/// 持有**同一个对象引用**，改 `lastEvent.context.user_feedback`（L130）会同时反映到
/// 两边；本仓不设环形副本，回填只落在缓冲上，随下一次 flush 成为生产可见的状态 ——
/// 这正是 legacy 测试 L117-127 含糊带过（"the in-memory update is exercised for
/// absence of errors"）的那处行为，此处做实。
/// 这里**刻意不是** `async fn`：回填与信号入缓冲都是纯内存操作，
/// 不做任何 I/O（落盘统一由 `flush_buffers` 负责）。
/// 保留无意义的 `async` 会被工具链判为 unused_async，
/// 也会给调用方制造「这里有等待点」的错误印象。
pub fn PerformanceMonitor::record_user_feedback(
  self : PerformanceMonitor,
  plugin_id : String,
  feedback : @types.UserFeedback,
  context? : String? = None,
) -> Unit {
  // ① 回填：待落盘缓冲（后写覆盖）
  patch_last_feedback(self.event_buffer, plugin_id, feedback)

  // ② 负面反馈 → strong/correction 信号（对齐 TS L134-138）
  if feedback == @types.UserFeedback::Negative {
    let detail = match context {
      Some(c) => c
      None => "no details"
    }
    self.enqueue_signal(
      make_signal(
        plugin_id,
        @types.SignalStrength::Strong,
        @types.SignalCategory::Correction,
        "User gave negative feedback: \{detail}",
        @types.Evidence::Session(self.session_id),
        None,
        None,
      ),
    )
  }
}

///|
/// 在数组里找到该插件的**最后一条**事件并回填反馈；找不到则静默返回。
/// 写成自由函数而非方法：它不读任何实例状态。
/// 返回 `Unit` 而不是「是否改到了」的 `Bool`：唯一调用点对结果只 `ignore`，
/// 回填本是尽力而为的内存操作，布尔返回值只会逼出一个多余的 ignore。
fn patch_last_feedback(
  events : Array[@types.PerformanceEvent],
  plugin_id : String,
  feedback : @types.UserFeedback,
) -> Unit {
  for i = events.length() - 1; i >= 0; i = i - 1 {
    if events[i].plugin_id == plugin_id {
      events[i] = with_feedback(events[i], feedback)
      return
    }
  }
}

///|
/// 返回一份把 `context.user_feedback` 换成 `feedback` 的事件副本。
fn with_feedback(
  event : @types.PerformanceEvent,
  feedback : @types.UserFeedback,
) -> @types.PerformanceEvent {
  {
    session_id: event.session_id,
    plugin_id: event.plugin_id,
    ts: event.ts,
    payload: event.payload,
    context: {
      task_type: event.context.task_type,
      user_feedback: Some(feedback),
      conversation_turn: event.context.conversation_turn,
      related_tools: event.context.related_tools,
    },
  }
}

// ============================================================================
// 信号检测（热路径，O(1)，零磁盘）
// ============================================================================

///|
/// 检测进化信号。取代 legacy-ts L220-250。
///
/// 失败与循环两个判定走 `TrailingState` 的 O(1) 增量计数，**零磁盘、零遍历**；
/// 末尾的 `maybe_deep_check` 才读磁盘，但它受 `deep_check_interval_ms`（30 s）节流，
/// 所以热路径的**摊销**成本仍是 O(1)。这与 CONTEXT.md 不变量③的原文一致：
/// 「失败/循环检测基于内存会话事件；磁盘深度检查受 DEEP_CHECK_INTERVAL_MS 节流」。
async fn PerformanceMonitor::check_for_signals(
  self : PerformanceMonitor,
  plugin_id : String,
  tool : String,
  success : Bool,
) -> Unit {
  let state = self.trailing.get_or_init(plugin_id, TrailingState::new)
  state.observe(tool, success)

  // 连续失败 >= 阈值 → strong/struggle（对齐 TS L227-232）
  // 添加去重机制：每个插件只报告一次 struggle 信号，直到连续失败解除后才能再次报告
  let should_emit_struggle = check_threshold_and_report(
    self.struggle_reported,
    plugin_id,
    self.thresholds.consecutive_failures,
    state.consecutive_failures,
  )
  if should_emit_struggle {
    self.enqueue_signal(
      make_signal(
        plugin_id,
        @types.SignalStrength::Strong,
        @types.SignalCategory::Struggle,
        "\{state.consecutive_failures} consecutive failures detected",
        @types.Evidence::Session(self.session_id),
        Some(state.consecutive_failures),
        None,
      ),
    )
  }

  // 连续同名工具（对齐 TS L235-246）
  let loop_key = "\{plugin_id}:\{tool}"
  let should_emit_loop = check_threshold_and_report(
    self.loop_reported,
    loop_key,
    self.thresholds.loop_detection,
    state.same_tool_run,
  )
  if should_emit_loop {
    self.enqueue_signal(
      make_signal(
        plugin_id,
        @types.SignalStrength::Medium,
        @types.SignalCategory::Loop,
        // 描述文案与 TS L244 逐字一致；但工具名**另外**放进结构化的
        // `tool` 字段，于是 engine 不必再用 /Tool (\w+) called/ 反解它。
        "Tool \{tool} called \{state.same_tool_run} times in loop",
        @types.Evidence::Session(self.session_id),
        Some(state.same_tool_run),
        Some(tool),
      ),
    )
  }

  // 深度检查：延迟回归对比（对齐 TS L249 的 `await this.maybeDeepCheck(pluginId)`）
  self.maybe_deep_check(plugin_id)
}

///|
/// 通用阈值检查与去重逻辑。封装 struggle/loop 两处共享的模式：
/// · 低于阈值时清除「已报告」标记，于是下一轮循环能再次上报
/// · 达到阈值且本轮尚未报告过时，设置标记并返回 true（应发射信号）
/// · 其他情况返回 false
///
/// 使用 `@ref.Ref` 包装 Map，允许就地修改（MoonBit 的 Map 是值类型）。
fn check_threshold_and_report(
  reported : @ref.Ref[Map[String, Unit]],
  key : String,
  threshold : Int,
  current_value : Int,
) -> Bool {
  if current_value < threshold {
    reported.val.remove(key)
    false
  } else if !reported.val.contains(key) {
    reported.val.set(key, ())
    true
  } else {
    false
  }
}

///|
/// 造一条信号，填好公共字段。取代 legacy-ts L297-314 的 `createSignal`。
/// 写成自由函数：它不读任何实例状态（证据由调用方传入）。
fn make_signal(
  plugin_id : String,
  strength : @types.SignalStrength,
  category : @types.SignalCategory,
  description : String,
  evidence : @types.Evidence,
  count : Int?,
  tool : String?,
) -> @types.EvolutionSignal {
  {
    strength,
    category,
    description,
    evidence,
    ts: @util.now_ms(),
    plugin_id,
    count,
    tool,
    decay_factor: 1.0,
  }
}

///|
/// 往 `signal_buffer` 压入一条信号，溢出时丢弃最旧的。
/// 与 `event_buffer` 的 `max_buffered_items` 对称，但上限是 `max_buffered_signals`。
/// 不记日志：`record_user_feedback` 不是 async，无法调用 `log_warn`；
/// 信号产生速率极低，溢出罕见，静默丢弃即可。
fn PerformanceMonitor::enqueue_signal(
  self : PerformanceMonitor,
  signal : @types.EvolutionSignal,
) -> Unit {
  self.signal_buffer.push_back(signal)
  self.buffers_dirty.val = true
  if self.signal_buffer.length() > max_buffered_signals {
    ignore(self.signal_buffer.pop_front())
  }
}

// ============================================================================
// 查询
// ============================================================================

///|
/// 取某插件在时间窗内的原始事件。取代 legacy-ts L144-157。
///
/// 先 flush 再读，保证统计包含本会话尚未落盘的事件（对齐 TS L149 的注释）。
/// 时间过滤是纯 Int64 比较 —— TS 每条都要 `new Date(e.timestamp)` 解析一次。
pub async fn PerformanceMonitor::get_metrics(
  self : PerformanceMonitor,
  plugin_id : String,
  time_range? : @types.TimeRange = @types.TimeRange::All,
) -> Array[@types.PerformanceEvent] {
  // 只在缓冲区有新数据时才 flush，减少不必要的磁盘 I/O。
  // 脏标记本身由 flush_buffers 维护：缓冲真正清空时置 false，
  // 写失败回填时保持 true，这里不做任何额外处理。
  if self.buffers_dirty.val {
    self.flush_buffers()
  }
  let all : Array[@types.PerformanceEvent] = self.metrics.load()
  let cutoff = time_range.cutoff_ms(@util.now_ms())
  let out : Array[@types.PerformanceEvent] = []
  for event in all {
    if event.plugin_id == plugin_id && event.ts >= cutoff {
      out.push(event)
    }
  }
  out
}

///|
/// 取聚合统计。取代 legacy-ts L162-213。
///
/// 先用一次遍历把强类型的 `ToolCallData` 挑出来，此后全部聚合都在闭合类型上进行
/// —— TS 版在这段里有 5 处 `(e.event_data as any).xxx`。
pub async fn PerformanceMonitor::get_statistics(
  self : PerformanceMonitor,
  plugin_id : String,
  time_range? : @types.TimeRange = @types.TimeRange::All,
) -> Statistics {
  let events = self.get_metrics(plugin_id, time_range~)
  let tool_calls : Array[@types.ToolCallData] = []
  for event in events {
    match event.payload {
      @types.EventPayload::ToolCall(d) => tool_calls.push(d)
      _ => ()
    }
  }
  summarize(tool_calls)
}

///|
/// 本会话尚未落盘的事件数。测试用它断言缓冲与节流行为。
pub fn PerformanceMonitor::pending_event_count(
  self : PerformanceMonitor,
) -> Int {
  self.event_buffer.length()
}

// 深度检查函数已拆分至 deep_check.mbt（fixed1 / maybe_deep_check）。

// 落盘与生命周期相关函数已拆分至 flush.mbt（flush_buffers / trim_quietly /
// bounded_requeue / requeue_into / shutdown / run_flush_loop）。


