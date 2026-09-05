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
/// 3. 用 `Deque` 环形缓冲取代 TS L374 的 `sessionEvents.splice(0, len-500)`
///    —— 后者稳态下每次事件都 O(n) 搬移整个数组。
let max_session_events : Int = 500 // ← TS L23 MAX_SESSION_EVENTS

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

///|
/// `Double` 保留 1 位小数的定点格式化，对齐 JS 的 `toFixed(1)`。
/// 仅用于 `Latency increased by X%` 这条信号描述（TS L270）。
///
/// 只对**非负**入参正确（JS 的 toFixed 对负数另有规则）；
/// 调用点的 `increase` 恒 > 0.2，故安全。
fn fixed1(d : Double) -> String {
  let scaled = d * 10.0 + 0.5
  let rounded = scaled.to_int()
  "\{rounded / 10}.\{rounded % 10}"
}

///|
/// 性能监控器。
pub struct PerformanceMonitor {
  metrics : @store.Jsonl
  signals : @store.Jsonl
  session_id : String
  /// 待落盘的性能事件（对应 TS L32 eventBuffer）
  event_buffer : Array[@types.PerformanceEvent]
  /// 待落盘的信号（对应 TS L33 signalBuffer）
  signal_buffer : Array[@types.EvolutionSignal]
  /// 本会话事件的环形副本，上限 `max_session_events`（对应 TS L35 sessionEvents）。
  /// 用 Deque 使两端操作都是 O(1)，取代 TS L374 的 splice。
  session_events : @deque.Deque[@types.PerformanceEvent]
  /// 每插件的 O(1) 尾计数器
  trailing : Map[String, TrailingState]
  /// 已发射过 loop 信号的 `plugin:tool` 集合（对应 TS L38 loopReported）。
  /// 用 Map 而非 Set：只需存在性，且 Map 的 remove/contains 已确认可用。
  loop_reported : Map[String, Unit]
  /// 每插件上次深度检查的时刻（对应 TS L36 lastDeepCheckAt）
  last_deep_check_at : Map[String, Int64]
  /// 信号阈值（默认取 TS 的三个硬编码常量，可由配置覆盖）
  thresholds : @types.SignalThresholds
  /// 观测日志（metrics / signals 两个 JSONL）的保留上限（字节），
  /// 来自 `EngineConfig.max_log_bytes`。0 = 不裁剪（测试豁免用）。
  max_log_bytes : Int
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
    signal_buffer: [],
    session_events: @deque.Deque([], capacity=max_session_events),
    trailing: Map([]),
    loop_reported: Map([]),
    last_deep_check_at: Map([]),
    thresholds,
    max_log_bytes,
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
  self.push_session_event(event)
  self.check_for_signals(plugin_id, tool, success)
}

///|
/// 记录用户反馈。取代 legacy-ts L122-139。
///
/// 两件事：① 回填该插件最近一条事件的 `user_feedback`；② 负面反馈发 strong/correction 信号。
///
/// **一处 MoonBit 特有的实现差异**：TS 里 `sessionEvents` 与 `eventBuffer`
/// 持有的是**同一个对象引用**，所以改 `lastEvent.context.user_feedback`（L130）
/// 会同时反映到待落盘的缓冲里。MoonBit 的值语义下必须**两处都改**，
/// 否则已缓冲但未落盘的事件拿不到反馈 —— 这正是 legacy 测试
/// L117-127 含糊带过（"the in-memory update is exercised for absence of errors"）
/// 的那处行为，此处做实。
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
  // ① 回填：待落盘缓冲（后写覆盖）与会话环形副本都要更新
  ignore(patch_last_feedback(self.event_buffer, plugin_id, feedback))
  ignore(self.patch_last_session_feedback(plugin_id, feedback))

  // ② 负面反馈 → strong/correction 信号（对齐 TS L134-138）
  if feedback == @types.UserFeedback::Negative {
    let detail = match context {
      Some(c) => c
      None => "no details"
    }
    self.signal_buffer.push(
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
/// 在数组里找到该插件的**最后一条**事件并回填反馈。返回是否改到了。
/// 写成自由函数而非方法：它不读任何实例状态，
/// 带着 `self` 参数只会让工具链报 unused_value。
fn patch_last_feedback(
  events : Array[@types.PerformanceEvent],
  plugin_id : String,
  feedback : @types.UserFeedback,
) -> Bool {
  for i = events.length() - 1; i >= 0; i = i - 1 {
    if events[i].plugin_id == plugin_id {
      events[i] = with_feedback(events[i], feedback)
      return true
    }
  }
  false
}

///|
/// 同上，但作用于 `Deque` 环形副本。
fn PerformanceMonitor::patch_last_session_feedback(
  self : PerformanceMonitor,
  plugin_id : String,
  feedback : @types.UserFeedback,
) -> Bool {
  let n = self.session_events.length()
  for i = n - 1; i >= 0; i = i - 1 {
    let event = self.session_events.at(i)
    if event.plugin_id == plugin_id {
      self.session_events.set(i, with_feedback(event, feedback))
      return true
    }
  }
  false
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

///|
/// 把事件并入会话环形副本，超过上限时从头部丢弃。
/// `Deque` 两端都是 O(1)，取代 TS L374 的 `splice`（O(n) 搬移）。
fn PerformanceMonitor::push_session_event(
  self : PerformanceMonitor,
  event : @types.PerformanceEvent,
) -> Unit {
  self.session_events.push_back(event)
  while self.session_events.length() > max_session_events {
    ignore(self.session_events.pop_front())
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
  if state.consecutive_failures >= self.thresholds.consecutive_failures {
    self.signal_buffer.push(
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

  // 连续同名工具（对齐 TS L235-246）：
  // 低于阈值时清除「已报告」标记，于是下一轮循环能再次上报；
  // 达到阈值且本轮尚未报告过时，只发一次 medium/loop。
  let loop_key = "\{plugin_id}:\{tool}"
  if state.same_tool_run < self.thresholds.loop_detection {
    self.loop_reported.remove(loop_key)
  } else if !self.loop_reported.contains(loop_key) {
    self.loop_reported.set(loop_key, ())
    self.signal_buffer.push(
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
  self.flush_buffers()
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

// ============================================================================
// 深度检查（受节流的磁盘对比）
// ============================================================================

///|
/// 节流的延迟回归检查。取代 legacy-ts L255-277。
///
/// 保留 TS 的语义：日平均延迟相对周基线上涨超过阈值 → strong/struggle 信号，
/// 证据来源标为 `Metrics(plugin_id)`（对应 TS L271 的 `metrics:${pluginId}`）。
///
/// 失败只记日志、不上抛（对齐 TS L274-276 的 try/catch + console.error）：
/// 深度检查是**附加**信号源，它坏了不该让 `recordToolCall` 整条失败。
async fn PerformanceMonitor::maybe_deep_check(
  self : PerformanceMonitor,
  plugin_id : String,
) -> Unit {
  let now = @util.now_ms()
  let last = self.last_deep_check_at.get(plugin_id).unwrap_or(0L)
  if now - last < deep_check_interval_ms {
    return
  }
  self.last_deep_check_at.set(plugin_id, now)

  let outcome : Result[Unit, String] = try {
    let day = self.get_statistics(
      plugin_id,
      time_range=@types.TimeRange::LastDay,
    )
    let week = self.get_statistics(
      plugin_id,
      time_range=@types.TimeRange::LastWeek,
    )
    if week.avg_latency_ms > 0.0 {
      let increase = (day.avg_latency_ms - week.avg_latency_ms) /
        week.avg_latency_ms
      if increase > self.thresholds.latency_regression {
        self.signal_buffer.push(
          make_signal(
            plugin_id,
            @types.SignalStrength::Strong,
            @types.SignalCategory::Struggle,
            "Latency increased by \{fixed1(increase * 100.0)}%",
            @types.Evidence::Metrics(plugin_id),
            None,
            None,
          ),
        )
      }
    }
    Ok(())
  } catch {
    e => Err(e.to_string())
  }
  match outcome {
    Ok(_) => ()
    Err(msg) => @util.log_error("Monitor", "Deep check failed: \{msg}")
  }
}

// ============================================================================
// 落盘与生命周期
// ============================================================================

///|
/// 把两个缓冲落盘；写成功才清空，写失败则回填等下一轮重试。
/// 取代 legacy-ts L381-391（那边的行为差异见下方 ★ 与 CONTEXT.md 的 H1）。
///
/// ★ **必须「先换出、后 await」**：换出与清空之间没有任何 await 点，
/// 而 MoonBit async 是单线程协作式调度、只在 await 处让出，
/// 故不可能有另一个任务在中间插入 → 无需互斥锁，也不可能重入。
/// 对比 TS L56 的 `void this.flushBuffers()`：丢弃 Promise 既吞掉异常，
/// 又允许定时器与手动调用重入。
///
/// ★ **落盘失败既不丢数据也不外抛**（对原实现的修正，见 CONTEXT.md）：
/// `store/jsonl.mbt` 有意把 `append` / `append_many` 的 I/O 错误直接 raise，
/// 但原来的调用方正是最不该接这个 raise 的地方 —— 事件已经 `clear` 出缓冲，
/// 一抛就永久丢失；而 `run_flush_loop` 的循环体没有兜错，
/// 任务一抛周期 flush 就再也不跑（`allow_failure=true` 只保证不连累 group）。
/// 现在 metrics 与 signals **各自独立兜错**：写不进去的批次按时间序放回缓冲
/// 头部等下一轮重试，超过 `max_buffered_items` 才丢弃最旧的并告警。
/// 本函数因此不再 raise，I/O 错误以告警的形式可见。
pub async fn PerformanceMonitor::flush_buffers(
  self : PerformanceMonitor,
) -> Unit {
  let events = self.event_buffer.copy()
  self.event_buffer.clear()
  let signals = self.signal_buffer.copy()
  self.signal_buffer.clear()
  let events_ok = if events.length() == 0 {
    true
  } else {
    try {
      self.metrics.append_many(events)
      true
    } catch {
      err => {
        @util.log_warn(
          "Monitor",
          "Cannot append metrics.jsonl, \{events.length()} events stay buffered: \{err.to_string()}",
        )
        false
      }
    }
  }
  let signals_ok = if signals.length() == 0 {
    true
  } else {
    try {
      self.signals.append_many(signals)
      true
    } catch {
      err => {
        @util.log_warn(
          "Monitor",
          "Cannot append signals.jsonl, \{signals.length()} signals stay buffered: \{err.to_string()}",
        )
        false
      }
    }
  }
  // 窗口裁剪挂在唯一的写入路径上：append 成功后才检查上界，
  // 且走 trim_quietly 兜错 —— append 已成功的事件不能因裁剪出错被
  // 判回填（重复落盘），flush_buffers 更不能因此重新开始抛错（H1 承诺）。
  if events_ok {
    self.trim_quietly(self.metrics)
  }
  if signals_ok {
    self.trim_quietly(self.signals)
  }
  if !events_ok {
    let (back, dropped) = bounded_requeue(events, self.event_buffer)
    // 不重新绑定字段（`event_buffer` 不是 `mut` 字段），而是原地改写：
    // Array 本身可变，clear + push 与本函数开头的 copy + clear 是同一套操作。
    self.event_buffer.clear()
    for x in back {
      self.event_buffer.push(x)
    }
    if dropped > 0 {
      @util.log_warn(
        "Monitor",
        "Dropped \{dropped} oldest buffered events (cap \{max_buffered_items})",
      )
    }
  }
  if !signals_ok {
    let (back, dropped) = bounded_requeue(signals, self.signal_buffer)
    self.signal_buffer.clear()
    for x in back {
      self.signal_buffer.push(x)
    }
    if dropped > 0 {
      @util.log_warn(
        "Monitor",
        "Dropped \{dropped} oldest buffered signals (cap \{max_buffered_items})",
      )
    }
  }
}

///|
/// 裁剪的兜错层：I/O 失败只告警，绝不抛出。
///
/// append 已成功的前提下，`Jsonl::trim_to` 的 I/O 错误若沿 raise 逃出
/// `flush_buffers`，就破坏了 H1 的「flush 不 raise」承诺；若被当成
/// append 失败处理，已落盘的事件会回填重试造成重复 —— 两边都错，
/// 所以在这里收口。`max_log_bytes <= 0` 表示显式豁免，不碰文件。
async fn PerformanceMonitor::trim_quietly(
  self : PerformanceMonitor,
  store : @store.Jsonl,
) -> Unit {
  if self.max_log_bytes <= 0 {
    return
  }
  let outcome : Result[Bool, String] = Ok(store.trim_to(self.max_log_bytes)) catch {
    err => Err(err.to_string())
  }
  match outcome {
    Ok(_) => ()
    Err(msg) => @util.log_warn("Monitor", "Cannot trim \{store.path()}: \{msg}")
  }
}

///|
/// 把「没写进去的一批」按时间序放回缓冲头部，并裁剪到 `max_buffered_items`。
/// 顺序是 `unsaved ++ buffered`：`unsaved` 是更早换出的那批，而 `buffered`
/// 里的条目是换出之后新记录的，必然更新 —— 反过来就会打乱时间序，
/// 让 `get_metrics` / 统计看到「先后的事件倒着发生」。
/// 裁剪时从头丢起（丢的就是 `unsaved` 里最旧的），故返回 `(缓冲, 丢弃条数)`。
fn[A] bounded_requeue(
  unsaved : Array[A],
  buffered : Array[A],
) -> (Array[A], Int) {
  let merged : Array[A] = []
  for x in unsaved {
    merged.push(x)
  }
  for x in buffered {
    merged.push(x)
  }
  let overflow = merged.length() - max_buffered_items
  if overflow <= 0 {
    return (merged, 0)
  }
  let kept : Array[A] = []
  let mut i = overflow
  while i < merged.length() {
    kept.push(merged[i])
    i += 1
  }
  (kept, overflow)
}

///|
/// 停止监控：最后一次 flush。取代 legacy-ts L65-74 的 `stop()`。
///
/// 幂等 —— 缓冲已空时是 no-op，故测试里可以随意多调。
pub async fn PerformanceMonitor::shutdown(self : PerformanceMonitor) -> Unit {
  self.flush_buffers()
}

///|
/// 启动周期性 flush。取代 legacy-ts L53-60 的 `start()` + `setInterval(5000)`。
///
/// **为什么用 `spawn` + `sleep` 而不是 `Timer::refresh`**：
/// `Timer::refresh` 是**非 async 的状态突变**，若由另一个任务在 `Timer::wait`
/// 挂起期间调用，就会在协程挂起状态下改写 timer 内部状态，
/// 产生唤醒丢失或重复唤醒的竞态。`sleep(interval)` 的语义是
/// 「上一轮完成后再等 interval」（固定**间隔**而非固定**频率**），
/// 对 flush 场景完全够用且无竞态。
///
/// ★ **返回 `Task` 句柄给调用方取消** —— 这是必需而非可选的：
/// `with_task_group` 会等**全部**子任务结束才退出，而这个循环是 `for ;;`
/// 永不自行结束的。若不在 stdin EOF 后显式 `cancel()`，
/// group 就会永远等下去 —— 实测表现为 MCP 客户端关闭 stdin 后
/// 进程挂死（宿主永远收不到退出）。
///
/// 为何不用 `group.return_immediately`：它会 `raise Cancelled`，
/// 而 `with_task_group` 的回调签名是 `async (TaskGroup[X]) -> X`（不带 raise），
/// 在其内部抛错无法通过类型检查。`Task::cancel` 是纯状态突变，不抛错。
pub fn PerformanceMonitor::run_flush_loop(
  self : PerformanceMonitor,
  group : @async.TaskGroup[Unit],
) -> @async.Task[Unit] {
  // 用箭头函数而不是 `fn() { ... }`：后者是 async 却未标注，
  // 工具链会以 deprecated_syntax 警告「effect inference is deprecated」。
  let task = group.spawn(allow_failure=true, () => {
    for ;; {
      @async.sleep(flush_interval_ms)
      if @async.is_being_cancelled() {
        break
      }
      // flush_buffers 不 raise（见其 ★ 注释），所以这个循环不会因为
      // 一次瞬时写失败就终止 —— 原实现会：异常逃出循环体，任务结束，
      // 此后只剩 add_defer 里最后一次同样可能失败的 flush。
      self.flush_buffers()
    }
  })
  // 退出前做最后一次 flush。`protect_from_cancel` 是 `add_defer` 文档明写的建议：
  // 若整个 group 被外部取消，defer 里的 async 操作会被立即取消，
  // 导致最后这批事件丢失 —— 而这正是 defer 存在的唯一目的。
  group.add_defer(() => @async.protect_from_cancel(() => self.flush_buffers()))
  task
}
