///|
/// 落盘与会话生命周期。从 monitor.mbt 拆分，降低单文件复杂度。
///
/// 包含：flush_buffers / trim_quietly / bounded_requeue / requeue_into
///       / requeue_into_deque / shutdown / run_flush_loop。

///|
/// 把两个缓冲落盘；写成功才清空，写失败则回填等下一轮重试。
/// 取代 legacy-ts L381-391（那边的行为差异见下文 ★ 与 CONTEXT.md 的 H1）。
///
/// ★ **必须「先换出、后 await」**：换出与清空之间没有任何 await 点，
/// 而 MoonBit async 是单线程协作式调度、只在 await 处让出，
/// 故不可能有另一个任务在中间插入 → 无需互斥锁，也不可能重入。
/// 对比 TS L56 的 `void this.flushBuffers()`：丢弃 Promise 既吞掉异常，
/// 又允许定时器与手动调用重入。
///
/// ★ **落盘失败时不丢数据也不上抛**（对原实现的修正，见 CONTEXT.md）：
/// `store/jsonl.mbt` 有意把 `append` / `append_many` 的 I/O 错误直接 raise，
/// 但原来的调用方正是最不该接这个 raise 的地方 —— 事件已经 `clear` 出缓冲，
/// 一抛就永久丢失；而 `run_flush_loop` 的循环体没有兜错，
/// 任务一抛整个 flush 就再也不跑（`allow_failure=true` 只保证不连累 group）。
/// 现在 metrics 与 signals **各自独立兜错**：写不进去的批次按时间序放回缓冲
/// 头部等下一轮重试，超过 `max_buffered_items` 才丢弃最旧的并告警。
/// 本函数因此不 raise，I/O 错误以告警的形式可见。
pub async fn PerformanceMonitor::flush_buffers(
  self : PerformanceMonitor,
) -> Unit {
  // 空缓冲短路：两个缓冲都为空时，跳过 copy/clear/trim 的全部开销。
  // 不影响语义 —— 空缓冲的 flush 本来就是 no-op。
  if self.event_buffer.length() == 0 && self.signal_buffer.length() == 0 {
    return
  }
  let events = self.event_buffer.copy()
  self.event_buffer.clear()
  // 信号缓冲是 Deque：先转成 Array（保序：最旧在前），再走同一条落盘路径
  let signals = self.signal_buffer.to_array()
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
  // 窗口裁剪挂在唯一的写入路径上：append 成功后才检查上限，
  // 且走 trim_quietly 兜错 —— append 已成功的事件不能因裁剪出错被
  // 判回填（重复落盘），flush_buffers 更不能因此重新开始抛错（H1 承诺）。
  if events_ok {
    // ★ S1：成功落盘的事件并入深度检查缓存（见 deep_check.mbt）。
    // 这是缓存语义的关键一环 —— 缓存 = 最近装载的文件快照 ∪ 此后
    // 所有成功 flush 的事件，于是复用缓存的后来者也能看到刚写入的事件。
    // requeue（写失败）的批次不入缓存，缓存始终是文件内容的超集。
    self.absorb_deep_events(events)
    self.trim_quietly(self.metrics)
  }
  if signals_ok {
    self.trim_quietly(self.signals)
  }
  if !events_ok {
    requeue_into(events, self.event_buffer, "events")
  }
  if !signals_ok {
    requeue_into_deque(signals, self.signal_buffer, "signals")
  }
  // 维护脏标记：仅当两个缓冲确实清空时才清除。
  // 若有批次写失败被回填（requeue），脏标记必须保持 true ——
  // 否则回填的数据要等到下一次 record_* 才有机会落盘。
  self.buffers_dirty.val = self.event_buffer.length() > 0 || self.signal_buffer.length() > 0
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
/// 顺序是 `unsaved ++ buffered`：`unsaved` 是最早换出的那批，而 `buffered`
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
/// 把写失败的批次回填到 Array 缓冲头部，溢出时丢弃最旧的并告警。
/// 封装 `bounded_requeue` + `clear` + `push` + `log_warn` 的固定模式，
/// 消除 events 路径的结构重复。
async fn[A] requeue_into(
  unsaved : Array[A],
  buffer : Array[A],
  label : String,
) -> Unit {
  let (back, dropped) = bounded_requeue(unsaved, buffer)
  buffer.clear()
  for x in back {
    buffer.push(x)
  }
  if dropped > 0 {
    @util.log_warn(
      "Monitor",
      "Dropped \{dropped} oldest buffered \{label} (cap \{max_buffered_items})",
    )
  }
}

///|
/// 同 `requeue_into`，但缓冲是 Deque（`signal_buffer`）。
/// 回填与裁剪语义完全一致：保时间序、超上限丢最旧并告警。
async fn[A] requeue_into_deque(
  unsaved : Array[A],
  buffer : @deque.Deque[A],
  label : String,
) -> Unit {
  let (back, dropped) = bounded_requeue(unsaved, buffer.to_array())
  buffer.clear()
  for x in back {
    buffer.push_back(x)
  }
  if dropped > 0 {
    @util.log_warn(
      "Monitor",
      "Dropped \{dropped} oldest buffered \{label} (cap \{max_buffered_items})",
    )
  }
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
/// ★ **返回 `Task` 供调用方取消** —— 这是必需而非可选的：
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
      // flush_buffers 不 raise（见函数 ★ 注释），所以这个循环不会因为
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
