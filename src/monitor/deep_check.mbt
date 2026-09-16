///|
/// 深度检查（受节流的磁盘对比）。从 monitor.mbt 拆分，降低单文件复杂度。
///
/// 包含：fixed1 / absorb_deep_events / maybe_deep_check。
///
/// ★ W3：本文件旧版注释因编码错乱不可读，按原语义重写为 UTF-8。
///
/// ★ S1（全局装载缓存）：旧实现每次深度检查都 `flush_buffers() → load()`
/// 全量读盘 + JSON 解析；而深度检查按**每插件** 30 s 节流，N 个插件活跃时
/// 一个窗口内就有 N 次全量读盘。现改为 monitor 级共享缓存：
///     deep_events = 最近一次 `metrics.load()` 的快照
///                   ∪ 此后所有成功 flush 的事件
/// 同一 `deep_check_interval_ms` 窗口内的后续插件直接复用，不再读盘。
///
/// 语义边界（已知且可接受）：
/// · flush 失败（requeue）的事件不入缓存 —— 与文件内容保持一致；
/// · 文件被 `trim` 掉的行在缓存中最多保留到下次装载（≤ 30 s）；
/// · 单写者假设：其他进程向 metrics.jsonl 追加的内容 ≤ 30 s 才可见。

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
/// 把一批**已成功落盘**的事件并入深度检查缓存（★ S1 的核心）。
///
/// 由 `flush_buffers` 在 `append_many` 成功后调用 —— 只有真正写进
/// metrics.jsonl 的事件才允许入缓存；写失败（requeue）的批次不入，
/// 缓存因此始终是「文件内容的超集」，绝不出现文件里没有的幽灵事件。
/// 缓存未激活（尚未装载，`deep_cache_at == 0`）时跳过：
/// 首批 flush 的事件会由紧随其后的首次全量装载读到，不会丢失。
fn PerformanceMonitor::absorb_deep_events(
  self : PerformanceMonitor,
  events : Array[@types.PerformanceEvent],
) -> Unit {
  if self.deep_cache_at.val == 0L {
    return
  }
  let week_cutoff = @types.TimeRange::LastWeek.cutoff_ms(@util.now_ms())
  for event in events {
    if event.ts >= week_cutoff {
      self.deep_events.val.push(event)
    }
  }
}

///|
/// 节流的延迟回归检查。取自 legacy-ts L255-277。
///
/// 保留 TS 的语义：日平均延迟相对周基线上涨超过阈值 → strong/struggle 信号，
/// 证据来源标为 `Metrics(plugin_id)`（对应 TS L271 的 `metrics:${pluginId}`）。
///
/// 失败只记日志、不上抛（对齐 TS L274-276 的 try/catch + console.error）：
/// 深度检查是**附加**信号源，它坏了不该让 `recordToolCall` 整条失败。
///
/// ★ **单次读盘优化**：TS 版调 `getStatistics` 两次（day / week），每次都走
/// `flushBuffers() → load()` 全量读盘 + JSON 解析。本版先 flush 一次，
/// 再从同一批原始事件里按两个时间窗口分别过滤、分别 summarize
/// （外部语义完全不变：仍是「先 flush 后算」）；S1 再把同一窗口内
/// N 个插件各读一次的重复 I/O 降为「一次装载 + 缓存复用」。
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
    // 先 flush：统计必须包含本会话尚未落盘的事件（含本次 record 的事件）。
    // 这些事件成功落盘时已被 absorb_deep_events 并入缓存，
    // 故下方「复用缓存」路径同样能看到它们。
    self.flush_buffers()
    let cache_fresh = now - self.deep_cache_at.val < deep_check_interval_ms
    let all : Array[@types.PerformanceEvent] = if cache_fresh {
      // 缓存新鲜：直接复用（本窗口内已有其他插件装载过）
      self.deep_events.val
    } else {
      // 缓存过期或从未装载：全量读盘，按周窗口裁剪后写回缓存
      let loaded : Array[@types.PerformanceEvent] = self.metrics.load()
      let load_cutoff = @types.TimeRange::LastWeek.cutoff_ms(now)
      let pruned : Array[@types.PerformanceEvent] = []
      for event in loaded {
        if event.ts >= load_cutoff {
          pruned.push(event)
        }
      }
      self.deep_events.val = pruned
      self.deep_cache_at.val = now
      self.deep_reloads.val = self.deep_reloads.val + 1
      pruned
    }
    let now_ms = @util.now_ms()
    let day_cutoff = @types.TimeRange::LastDay.cutoff_ms(now_ms)
    let week_cutoff = @types.TimeRange::LastWeek.cutoff_ms(now_ms)
    let day_calls : Array[@types.ToolCallData] = []
    let week_calls : Array[@types.ToolCallData] = []
    for event in all {
      if event.plugin_id != plugin_id {
        continue
      }
      match event.payload {
        @types.EventPayload::ToolCall(d) => {
          if event.ts >= week_cutoff {
            week_calls.push(d)
          }
          if event.ts >= day_cutoff {
            day_calls.push(d)
          }
        }
        _ => ()
      }
    }
    let day = summarize(day_calls)
    let week = summarize(week_calls)
    // 最小样本量保护：任一窗口不足 5 个样本就不做回归对比。
    // 没有这道闸时，各 1 条样本（基线 10ms vs 今次 1000ms）就能算出 ~98% 的
    // 「涨幅」，单次抖动即触发 strong/struggle 强信号 —— 纯误报。
    // 样本不足时跳过，保持「无信号」的原有行为。
    if day.total_calls >= 5 &&
      week.total_calls >= 5 &&
      week.avg_latency_ms > 0.0 {
      let increase = (day.avg_latency_ms - week.avg_latency_ms) /
        week.avg_latency_ms
      if increase > self.thresholds.latency_regression {
        self.enqueue_signal(
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
