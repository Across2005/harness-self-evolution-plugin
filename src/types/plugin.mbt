///|
/// 插件档案模型。取代 legacy-ts/src/types/index.ts L14-33。

///|
/// 插件来源。对应 legacy-ts 的 `PluginMetadata['type']`（types L18）。
/// 字段名从 `type` 改为 `kind`：`type` 在 MoonBit 里是类型声明关键字，
/// 且 `plugin.kind` 比 `plugin.type` 表意更准确。
pub(all) enum PluginKind {
  Official
  Community
  Custom
} derive(Eq, Debug)

///|
/// 使用频率档位。对应 legacy-ts 的 `PluginMetrics['usage_frequency']`（types L32）。
pub(all) enum UsageFrequency {
  High
  Medium
  Low
  Idle
} derive(Eq, Debug)

///|
/// 一份插件档案。对应 legacy-ts 的 `PluginMetadata`（types L14-26）。
///
/// `capabilities` / `tools` / `events` 保持 `Array[String]` 而非 `Set`：
/// legacy-ts 的去重时机很微妙 —— scanner L132 把**未去重**的数组传给
/// `calculateMetrics`（重复项会抬高 L304 的 `capabilityComplexity`），
/// 而 L140-142 存进 metadata 时才 `[...new Set(...)]`。
/// 换成 Set 会让「算指标用的数量」与「档案里存的数量」变成同一个值，
/// 静默改变 `complexity_score`，进而翻转 engine L196 的 `> 7` 判定。
/// 用 Array 才能把这两个时机分开表达。
pub(all) struct PluginMetadata {
  /// `name-version`，如 `browser-use-0.4.1`
  plugin_id : String
  name : String
  version : String
  kind : PluginKind
  capabilities : Array[String]
  tools : Array[String]
  events : Array[String]
  dependencies : Array[String]
  /// 原 `scan_timestamp : string`（types L23）→ Unix 毫秒
  scanned_at : Int64
  path : String
  initial_metrics : PluginMetrics
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 插件的初始启发式指标。对应 legacy-ts 的 `PluginMetrics`（types L28-33）。
/// 三项评分的计算公式见 scanner/metrics.mbt。
pub(all) struct PluginMetrics {
  /// 0-10，越高越复杂
  complexity_score : Double
  /// 0-10，越高接口越清晰
  interface_clarity : Double
  /// 0-10，越高文档越好
  documentation_quality : Double
  /// 由 monitor 后续更新；扫描阶段恒为 `Some(Idle)`
  usage_frequency : UsageFrequency?
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 去重并保持首次出现顺序。取代 legacy-ts 的 `[...new Set(xs)]`（scanner L140-142）。
///
/// MoonBit 的 `Map` / `Set` 是哈希表、迭代序不定，直接用它们做去重会让
/// `capabilities` 数组顺序在不同运行间抖动 —— 既破坏双跑对拍，
/// 也让 MCP 每次返回给 LLM 的插件档案顺序不同。故用「已见集合 + 顺序数组」手写。
pub fn dedup_ordered(xs : ArrayView[String]) -> Array[String] {
  // 用 Map([]) 而非 {}：后者在本工具链下会在「空 Map 字面量 / 空块表达式 /
  // 空 struct 字面量 / 空 JSON 对象」四者间报 ambiguous_braces 警告。
  let seen : Map[String, Unit] = Map([])
  let out : Array[String] = []
  for x in xs {
    if seen.contains(x) {
      continue
    }
    seen.set(x, ())
    out.push(x)
  }
  out
}
