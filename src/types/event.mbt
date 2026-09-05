///|
/// 性能事件模型。取代 legacy-ts/src/types/index.ts L39-89。
///
/// **本文件消灭的是 TS 版最大的一处类型漏洞。**
/// TS 把 `event_type`（字符串）与 `event_data`（4 元判别联合）拆成两个**互不关联**的
/// 字段（types/index.ts L43-44），编译器无法保证二者一致，于是 monitor/index.ts
/// 里出现了 **9 处** `(e.event_data as any).xxx`（实测行号：L186, 187, 189, 192,
/// 197, 226, 235, 237, 324）。每一处都是「运行时才发现字段不存在」的机会。
///
/// 合并为单一 `EventPayload` 枚举后，所有消费点都变成穷尽 `match`，
/// 这类漏洞在语言层面不再可能存在。
///
/// 变体**持有 struct** 而非直接用带名字段的变体：这样 `match p { ToolCall(d) => d.tool }`
/// 的写法无歧义，且 struct 与 TS 的 `ToolCallData` / `EventData` / `CapabilityData` /
/// `ErrorData` 四个 interface（L48-76）逐一对应，便于 diff。

///|
/// 一次工具调用的原始数据。对应 legacy-ts 的 `ToolCallData`（types L48-56）。
pub(all) struct ToolCallData {
  tool : String
  params : Json
  latency_ms : Int
  success : Bool
  token_usage : TokenUsage?
  retry_count : Int
  error_message : String?
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 一次事件触发。对应 legacy-ts 的 `EventData`（types L58-62）。
pub(all) struct EventFiredData {
  event_name : String
  payload : Json
  processing_time_ms : Int
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 一次能力使用。对应 legacy-ts 的 `CapabilityData`（types L64-69）。
pub(all) struct CapabilityData {
  capability : String
  operation : String
  duration_ms : Int
  success : Bool
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 一次错误。对应 legacy-ts 的 `ErrorData`（types L71-76）。
pub(all) struct ErrorData {
  error_kind : ErrorKind
  message : String
  stack_trace : String?
  recovery_attempted : Bool
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 事件载荷。四个变体分别对应 TS 的 `event_type` 取值
/// `'tool_call' | 'event_fired' | 'capability_used' | 'error'`。
///
/// 序列化用 `derive`（tagged-array，形如 `["ToolCall",{...}]`）而非手写
/// `{"kind":...}` 对象形式 —— 这是有意区分：`metrics.jsonl` 是**高频遥测**
/// （设计上要能撑到百万行），机器消费为主；而 `proposals.jsonl` 是**低频、
/// 面向人类审批决策**的文档，故 `Change` / `Evidence` 采用手写的自描述对象形式。
pub(all) enum EventPayload {
  ToolCall(ToolCallData)
  EventFired(EventFiredData)
  CapabilityUsed(CapabilityData)
  Failed(ErrorData)
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 一条性能事件。对应 legacy-ts 的 `PerformanceEvent`（types L39-46）。
pub(all) struct PerformanceEvent {
  session_id : String
  plugin_id : String
  /// 原 `timestamp : string`（types L42）→ Unix 毫秒。
  /// 消灭 monitor L154 的 `new Date(e.timestamp)` 解析。
  ts : Int64
  /// 原 `event_type` + `event_data` 两个字段（types L43-44）合并为一个枚举。
  payload : EventPayload
  context : EventContext
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// Token 消耗。对应 legacy-ts 的 `TokenUsage`（types L78-82）。
pub(all) struct TokenUsage {
  input : Int
  output : Int
  total : Int
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 事件上下文。对应 legacy-ts 的 `EventContext`（types L84-89）。
pub(all) struct EventContext {
  task_type : String?
  /// TS 的类型是 `'positive' | 'negative' | 'neutral' | null`，
  /// 而字段本身又是可选的 —— JS 的 `null` 与 `undefined` 双重「空」。
  /// MoonBit 用单一 `Option` 合并这两者，语义更干净。
  user_feedback : UserFeedback?
  conversation_turn : Int
  related_tools : Array[String]?
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 用户反馈极性。
pub(all) enum UserFeedback {
  Positive
  Negative
  Neutral
} derive(Eq, Debug)

///|
/// 错误分类。
///
/// **这里修掉了一处 TS 的真实 bug**：`types/index.ts` L72 把 `error_type` 声明为
/// `'timeout' | 'parameter_error' | 'permission_error' | 'runtime_error' | 'unknown'`，
/// 而 `monitor/index.ts` L345-349 实际返回的是
/// `timeout / parameter_error / permission_error / not_found / runtime_error` ——
/// `not_found` **不在**声明的联合里，`unknown` 则**从不**被产出。
/// 因为聚合结果存进 `Record<string, number>`，这个矛盾在 TS 里完全不可见。
/// 闭合枚举把两个集合统一，并保留 `Unknown` 以覆盖将来的分类失败。
pub(all) enum ErrorKind {
  Timeout
  ParameterError
  PermissionError
  NotFound
  RuntimeError
  Unknown
} derive(Eq, Debug)

///|
/// 从错误消息文本分类。取代 legacy-ts/src/monitor/index.ts L344-350。
///
/// **大小写敏感**，与 TS 的 `String.prototype.includes` 严格一致。
/// 这里若「顺手」加一次 `to_lower()`，`"Timeout"` 就会从 `runtime_error`
/// 变成 `timeout` —— 属于会静默改变统计输出的行为变更，故明确不做。
///
/// 5 个分支的**判定顺序不可调换**（一条同时含 "timeout" 与 "permission"
/// 的消息必须归为 Timeout，与 TS 一致）。
pub fn ErrorKind::classify(msg : String) -> ErrorKind {
  if msg.contains("timeout") {
    return Timeout
  }
  if msg.contains("parameter") || msg.contains("param") {
    return ParameterError
  }
  if msg.contains("permission") || msg.contains("access") {
    return PermissionError
  }
  if msg.contains("not found") || msg.contains("does not exist") {
    return NotFound
  }
  RuntimeError
}

///|
/// 深模块窄接口：统计层只需这三个投影，对 `EventPayload` 的 `match`
/// 只在本文件出现一次，其余模块无需知道载荷有几个变体。
pub fn EventPayload::tool_name(self : EventPayload) -> String? {
  match self {
    ToolCall(d) => Some(d.tool)
    _ => None
  }
}

///|
/// 该载荷是否有「成功」语义。`EventFired` 与 `Failed` 没有，返回 `None`。
pub fn EventPayload::succeeded(self : EventPayload) -> Bool? {
  match self {
    ToolCall(d) => Some(d.success)
    CapabilityUsed(d) => Some(d.success)
    EventFired(_) => None
    Failed(_) => None
  }
}

///|
/// 该载荷的耗时（毫秒）。`EventFired` 用 processing_time，其余用各自的时长字段。
pub fn EventPayload::duration_ms(self : EventPayload) -> Int? {
  match self {
    ToolCall(d) => Some(d.latency_ms)
    EventFired(d) => Some(d.processing_time_ms)
    CapabilityUsed(d) => Some(d.duration_ms)
    Failed(_) => None
  }
}
