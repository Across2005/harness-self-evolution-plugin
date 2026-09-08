///|
/// 娣卞害妫€鏌ワ紙鍙楄妭娴佺殑纾佺洏瀵规瘮锛夈€備粠 monitor.mbt 鎷嗗垎锛岄檷浣庡崟鏂囦欢澶嶆潅搴︺€?
///
/// 鍖呭惈锛歠ixed1 / maybe_deep_check銆?

///|
/// `Double` 淇濈暀 1 浣嶅皬鏁扮殑瀹氱偣鏍煎紡鍖栵紝瀵归綈 JS 鐨?`toFixed(1)`銆?
/// 浠呯敤浜?`Latency increased by X%` 杩欐潯淇″彿鎻忚堪锛圱S L270锛夈€?
///
/// 鍙**闈炶礋**鍏ュ弬姝ｇ‘锛圝S 鐨?toFixed 瀵硅礋鏁板彟鏈夎鍒欙級锛?
/// 璋冪敤鐐圭殑 `increase` 鎭?> 0.2锛屾晠瀹夊叏銆?
fn fixed1(d : Double) -> String {
  let scaled = d * 10.0 + 0.5
  let rounded = scaled.to_int()
  "\{rounded / 10}.\{rounded % 10}"
}

///|
/// 鑺傛祦鐨勫欢杩熷洖褰掓鏌ャ€傚彇浠?legacy-ts L255-277銆?
///
/// 淇濈暀 TS 鐨勮涔夛細鏃ュ钩鍧囧欢杩熺浉瀵瑰懆鍩虹嚎涓婃定瓒呰繃闃堝€?鈫?strong/struggle 淇″彿锛?
/// 璇佹嵁鏉ユ簮鏍囦负 `Metrics(plugin_id)`锛堝搴?TS L271 鐨?`metrics:${pluginId}`锛夈€?
///
/// 澶辫触鍙鏃ュ織銆佷笉涓婃姏锛堝榻?TS L274-276 鐨?try/catch + console.error锛夛細
/// 娣卞害妫€鏌ユ槸**闄勫姞**淇″彿婧愶紝瀹冨潖浜嗕笉璇ヨ `recordToolCall` 鏁存潯澶辫触銆?
///
/// 鈽?**鍗曟璇荤洏浼樺寲**锛歍S 鐗堣皟 `getStatistics` 涓ゆ锛坉ay / week锛夛紝姣忔閮借蛋
/// `flushBuffers() 鈫?load()` 鍏ㄩ噺璇荤洏 + JSON 瑙ｆ瀽銆傛繁搴︽鏌ヨ鑺傛祦鍒?30s 涓€娆★紝
/// 浣嗕竴娆℃鏌ュ唴鐨勪袱娆?`load()` 浠嶆槸绾补鐨勯噸澶?I/O銆?
/// 鏀逛负锛氬厛 flush 涓€娆?+ load 涓€娆★紝鍐嶄粠鍚屼竴鎵瑰師濮嬩簨浠堕噷鎸変袱涓椂闂寸獥鍙?
/// 鍒嗗埆杩囨护銆佸垎鍒?summarize銆傚閮ㄨ涔夊畬鍏ㄤ笉鍙橈紙鍏?flush 鍚庣畻锛夛紝
/// 鍐呴儴 I/O 鍑忓崐銆?
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
    // 鍗曟 flush + load锛氭妸涓ゆ get_statistics 鐨勫叡鐢ㄨ矾寰勬彁鍑烘潵
    self.flush_buffers()
    let all : Array[@types.PerformanceEvent] = self.metrics.load()
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
    if week.avg_latency_ms > 0.0 {
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
