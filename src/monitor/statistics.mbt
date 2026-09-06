///|
/// 指标聚合 —— **0 处类型强转**。
/// 取代 legacy-ts/src/monitor/index.ts L162-213（`getStatistics`）与
/// L319-339（`detectLoops`）。
///
/// TS 版在这两段里有 5 处 `(e.event_data as any).xxx`
/// （L186, 187, 189, 192, 197），因为 `event_type` 与 `event_data` 是两个
/// 互不关联的字段。新版入参直接是 `ArrayView[ToolCallData]` ——
/// 调用方先用一次 `filter_map` 拿到强类型数组，此后全部聚合都在闭合类型上进行，
/// 字段名写错会直接编译失败。

///|
/// 一个插件在某个时间窗内的聚合指标。
/// 字段与 legacy-ts `getStatistics` 的返回对象逐一对应。
pub(all) struct Statistics {
  total_calls : Int
  success_rate : Double
  avg_latency_ms : Double
  total_tokens : Int
  avg_retry_count : Double
  /// 错误类型直方图，键是 `ErrorKind` 的 wire 名。
  /// 用**按 wire 名字典序排列的数组**而不是 `Map`：
  /// MoonBit 的 Map 是哈希表、迭代序不定，直接序列化会让 MCP 每次
  /// 返回给 LLM 的字段顺序都可能不同（决策 D10 / 修 R5）。
  /// 需要确定键序的消费者应读本数组字段；
  /// `error_types_object` 渲染出的 JSON 对象键序不保证字典序（见该函数注释）。
  error_types : Array[(String, Int)]
  loop_detected : Bool
} derive(Eq, Debug)

///|
/// 全零统计。对应 legacy-ts L174-183：无工具调用时返回的那组零值。
///
/// 注意这条路径**不触发任何磁盘访问** —— TS 版会先 `flushBuffers()` 落盘
/// 再 `load()` 全量读回（L149-150），即使该插件根本不存在。
pub fn Statistics::empty() -> Statistics {
  {
    total_calls: 0,
    success_rate: 0.0,
    avg_latency_ms: 0.0,
    total_tokens: 0,
    avg_retry_count: 0.0,
    error_types: [],
    loop_detected: false,
  }
}

///|
/// 把错误直方图渲染为 JSON 对象。
/// 供 MCP 的 `get_plugin_metrics` 响应使用 —— TS 版返回的是
/// `Record<string, number>`，即 JSON 对象，故此处也渲染成对象而不是数组。
///
/// **键序说明**：排序好的数组在此被重新塞进 `Map[String, Json]`，
/// `Json::object` 序列化对象时按 Map 的哈希序输出键 —— 固定键集在
/// 确定性 String 哈希下跨运行稳定，但**既非字典序也非插入序**。
/// 需要确定顺序的消费者应读 `error_types` 数组字段（按 wire 名字典序）。
pub fn Statistics::error_types_object(self : Statistics) -> Json {
  let obj : Map[String, Json] = Map([])
  for pair in self.error_types {
    let (kind, count) = pair
    obj.set(kind, Json::number(count.to_double()))
  }
  Json::object(obj)
}

///|
/// 聚合一批工具调用。取代 legacy-ts L162-213。
///
/// 逐项对应 TS 的实现：
/// · `success_rate` = 成功数 / 总数（L186, L206）
/// · `avg_latency_ms` = 延迟总和 / 总数（L187, L207）
/// · `total_tokens` = Σ `token_usage.total || (input + output)`（L188-191）
///   —— 注意 JS 的 `||`：`total` 为 **0** 时视为 falsy，回退到 input+output。
///   这个「0 当作缺失」的怪癖被原样保留，因为它会改变统计结果。
/// · `avg_retry_count` = 重试总和 / 总数（L192, L209）
/// · `error_types` = 按 `error_message` 分类计数（L196-202）
/// · `loop_detected` = `detect_loops`（L211）
pub fn summarize(tool_calls : ArrayView[@types.ToolCallData]) -> Statistics {
  let n = tool_calls.length()
  if n == 0 {
    return Statistics::empty()
  }

  let mut success = 0
  let mut total_latency = 0
  let mut total_tokens = 0
  let mut total_retries = 0
  // 计数阶段用 Map（O(1) 累加），输出阶段再排序成数组（确定性）
  let counts : Map[String, Int] = Map([])

  for tc in tool_calls {
    if tc.success {
      success += 1
    }
    total_latency += tc.latency_ms
    total_retries += tc.retry_count
    total_tokens += match tc.token_usage {
      Some(u) =>
        // 对齐 TS L190 的 `tokenUsage.total || (input + output)`：
        // total 为 0 时回退到分项之和
        if u.total != 0 {
          u.total
        } else {
          u.input + u.output
        }
      None => 0
    }
    match tc.error_message {
      Some(msg) => {
        let kind = @types.ErrorKind::classify(msg).wire_name()
        counts.set(kind, counts.get(kind).unwrap_or(0) + 1)
      }
      None => ()
    }
  }

  let error_types : Array[(String, Int)] = []
  for pair in counts {
    error_types.push(pair)
  }
  error_types.sort_by(fn(a, b) { a.0.lexical_compare(b.0) })

  let denominator = n.to_double()
  {
    total_calls: n,
    success_rate: success.to_double() / denominator,
    avg_latency_ms: total_latency.to_double() / denominator,
    total_tokens,
    avg_retry_count: total_retries.to_double() / denominator,
    error_types,
    loop_detected: detect_loops(tool_calls),
  }
}

///|
/// 循环检测。取代 legacy-ts L319-339。
///
/// 语义逐条对齐：
/// · 不足 5 条 → false（L320）
/// · 只看**最近 10 条**（L323 的 `slice(-10)`）
/// · 该窗口内任一工具出现 **>= 5 次** → true（L332）
///
/// 注意这与 `trailing.mbt` 里「连续同名工具 >= 5」是**两个不同的判定**：
/// 本函数看的是窗口内频次（可以不连续），用于 `Statistics.loop_detected`；
/// `TrailingState` 看的是尾部连续次数，用于发 medium/loop 信号（TS L237-246）。
/// TS 版就是这样两套并存，此处原样保留。
pub fn detect_loops(tool_calls : ArrayView[@types.ToolCallData]) -> Bool {
  let n = tool_calls.length()
  if n < 5 {
    return false
  }
  let start = if n > 10 { n - 10 } else { 0 }
  let counts : Map[String, Int] = Map([])
  for i in start..<n {
    let tool = tool_calls[i].tool
    let next = counts.get(tool).unwrap_or(0) + 1
    counts.set(tool, next)
    if next >= 5 {
      return true
    }
  }
  false
}
