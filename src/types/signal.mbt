///|
/// 进化信号模型。取代 legacy-ts/src/types/index.ts L95-119。
///
/// **本文件消灭的是 TS 版的第二条 stringly-typed 通道。**
/// 第一条是 `event_type` / `event_data` 拆分（已在 event.mbt 处理）；
/// 第二条是 `EvolutionSignal.evidence` —— TS 把它声明为裸 `string`，
/// 实际取值形如 `"session:sess_xxx"`（monitor L137, 231, 245）、
/// `"metrics:browser-use-0.4.1"`（monitor L271）、`"user:manual"`（server L182）。
/// 前缀语义只存在于约定里，编译器无从检查。这里提升为 `Evidence` 枚举。
///
/// 同时还消灭了一处**信息被编码两次**的浪费：TS 的 monitor L244 用模板串拼出
/// `` `Tool ${toolName} called ${loopCount} times in loop` ``，engine L357 再用
/// `/Tool (\w+) called/` 把工具名**反解**回来。同一个事实被序列化和反序列化各一次，
/// 且正则一旦与模板串漂移就会静默失效。新版给 `EvolutionSignal` 加了结构化的
/// `tool` 字段，monitor 直接填、engine 直接读，正则随之删除。

///|
/// 信号强度。对应 legacy-ts 的 `SignalStrength`（types L95）。
/// 语义见 CONTEXT.md：strong 立即触发、medium 累积触发、weak 仅记录。
pub(all) enum SignalStrength {
  Strong
  Medium
  Weak
} derive(Eq, Debug)

///|
/// 信号类别。对应 legacy-ts 的 `EvolutionSignal['category']`（types L99）。
/// CONTEXT.md L31-38 的「信号类别 → 进化类型」映射表以此为键。
pub(all) enum SignalCategory {
  Correction
  Preference
  Workflow
  Struggle
  Pattern
  Loop
} derive(Eq, Debug)

///|
/// 信号的证据来源。取代 TS 里 `"session:x"` / `"metrics:x"` / `"user:manual"`
/// 这类靠字符串前缀表达的结构。
///
/// 序列化采用手写的 `{"kind": ...}` 自描述对象形式（而非 derive 的 tagged-array），
/// 因为信号会进入 `signals.jsonl` 与提案文档，需要人类可读。
pub(all) enum Evidence {
  /// 来自本会话的内存事件，携带 session_id
  Session(String)
  /// 来自磁盘上的历史指标，携带 plugin_id
  Metrics(String)
  /// 用户在调用 propose_evolution 时手工提供
  UserManual
  /// 来自某个具体文件（如 session 日志）
  FilePath(String)
} derive(Eq, Debug)

///|
pub impl ToJson for Evidence with fn to_json(self : Evidence) -> Json {
  match self {
    Session(id) => { "kind": "session", "id": Json::string(id) }
    Metrics(plugin_id) =>
      { "kind": "metrics", "plugin_id": Json::string(plugin_id) }
    UserManual => { "kind": "user_manual" }
    FilePath(p) => { "kind": "file", "path": Json::string(p) }
  }
}

///|
pub impl @json.FromJson for Evidence with fn from_json(
  json : Json,
  path : @json.JsonPath,
) -> Evidence raise @json.JsonDecodeError {
  guard json is Object(obj) else {
    raise @json.JsonDecodeError((path, "Evidence: expected a JSON object"))
  }
  let kind_path = path.add_key("kind")
  let kind = match obj.get("kind") {
    Some(String(s)) => s
    _ =>
      raise @json.JsonDecodeError(
        (kind_path, "Evidence: missing or non-string \"kind\""),
      )
  }
  fn field(name : String) -> String raise @json.JsonDecodeError {
    match obj.get(name) {
      Some(String(s)) => s
      _ =>
        raise @json.JsonDecodeError(
          (path.add_key(name), "Evidence: missing \"\{name}\""),
        )
    }
  }
  match kind {
    "session" => Session(field("id"))
    "metrics" => Metrics(field("plugin_id"))
    "user_manual" => UserManual
    "file" => FilePath(field("path"))
    _ =>
      raise @json.JsonDecodeError(
        (
          kind_path,
          "Evidence: unknown kind \"\{kind}\"; expected session|metrics|user_manual|file",
        ),
      )
  }
}

///|
/// 一条进化信号。对应 legacy-ts 的 `EvolutionSignal`（types L97-105）。
pub(all) struct EvolutionSignal {
  /// 原字段名 `type`（types L98）。改名避开与 MoonBit 的类型语义混淆，
  /// 也让 `signal.strength` 读起来比 `signal.type` 更准确。
  strength : SignalStrength
  category : SignalCategory
  description : String
  evidence : Evidence
  /// 原 `timestamp : string` → Unix 毫秒
  ts : Int64
  plugin_id : String
  /// 累积型信号的计数（如「连续失败 3 次」的 3）
  count : Int?
  /// ★ 循环信号携带的工具名。monitor 生成时直接填入、engine 直接读取，
  /// 取代 engine L357 的 `/Tool (\w+) called/` 正则反解。
  /// 非循环信号为 None。
  tool : String?
  /// 信号强度衰减因子（0.0-1.0），用于信号聚合时的强度衰减计算。
  /// 新信号默认为 1.0（无衰减），随时间推移可被衰减。
  decay_factor : Double
} derive(Eq, Debug, ToJson)

///|
/// 与 `EvolutionSignal` 同形，但 `decay_factor` 可缺省 —— **只用于解码旧行**。
///
/// **为什么需要它**（实测 2026-09-18）：`decay_factor` 是后加的字段，本机
/// `proposals.jsonl` 里最老那条提案的 4 行是旧 schema 写的（没有这个字段），
/// 派生解码器把**整行**判为 corrupt 丢掉 → `get_runtime_snapshot` 报 2 条提案，
/// 而面板（只按 `proposal_id` 折叠、不解析 `trigger_signals`）报 3 条：同一份文件两个数字。
/// 容忍缺失比丢数据好——缺省 1.0 正是「无衰减」，与仓内所有构造点一致，
/// 且 `decay_factor` 目前没有消费方（engine 只在聚合时按时间算衰减）。
priv struct EvolutionSignalWire {
  strength : SignalStrength
  category : SignalCategory
  description : String
  evidence : Evidence
  ts : Int64
  plugin_id : String
  count : Int?
  tool : String?
  decay_factor : Double?
} derive(@json.FromJson)

///|
/// 解码 `EvolutionSignal`：**只**对 `decay_factor` 放宽（缺失 → 1.0），其余与派生语义一致。
///
/// `path` 不参与中转（`@json.from_json` 的显式调用形式不接 path）；
/// 出错的定位由外层调用方补足 —— 这里刻意只做「一个字段的容错」，不做整行宽松。
pub impl @json.FromJson for EvolutionSignal with fn from_json(
  json : Json,
  path : @json.JsonPath,
) -> EvolutionSignal raise @json.JsonDecodeError {
  ignore(path)
  let wire : EvolutionSignalWire = @json.from_json(json)
  {
    strength: wire.strength,
    category: wire.category,
    description: wire.description,
    evidence: wire.evidence,
    ts: wire.ts,
    plugin_id: wire.plugin_id,
    count: wire.count,
    tool: wire.tool,
    decay_factor: wire.decay_factor.unwrap_or(1.0),
  }
}

///|
/// 信号触发阈值。
///
/// **这里收拢了一处配置孤岛**：legacy-ts 里同一组阈值存在两份平行定义 ——
/// 自述清单（`plugin.json`）L53-65 的 `signal_thresholds`，与
/// `types/index.ts` L107-119 的 `SignalThresholds` interface，而**后者全仓无读取点**，
/// 真正生效的是 monitor 里的硬编码常量（L227 的 3、L238 的 5、L267 的 0.2）。
/// 新版只保留这一份定义，默认值即那三个硬编码常量，并可由 plugin.json 覆盖。
pub(all) struct SignalThresholds {
  /// 连续失败多少次算 strong/struggle。默认 3（monitor L227）
  consecutive_failures : Int
  /// 同一工具连续调用多少次算 medium/loop。默认 5（monitor L238）
  loop_detection : Int
  /// 日延迟相对周基线上涨多少算 strong/struggle。默认 0.2（monitor L267）
  latency_regression : Double
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 默认阈值，逐一对应 legacy-ts 里 monitor 的硬编码常量。
pub fn SignalThresholds::default() -> SignalThresholds {
  { consecutive_failures: 3, loop_detection: 5, latency_regression: 0.2 }
}
