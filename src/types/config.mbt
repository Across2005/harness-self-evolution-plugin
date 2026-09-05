///|
/// 进化引擎配置。取代 legacy-ts/src/types/index.ts L293-299 的 `EvolutionConfig`
/// 与 engine/index.ts L29-49 的内联 config 字段。
///
/// **这里修掉了一处配置孤岛**：legacy-ts 的 `.zcode-plugin/plugin.json` L48-66
/// 写了一整段 `evolution_config`（含 `signal_thresholds`），
/// 但 `src/**` 里**没有任何代码读取它** —— engine 用的是构造函数默认值
/// （L45-47 的 `'50%'` / 3 / 24），monitor 用的是硬编码常量（L227/238/267）。
/// 于是「改配置文件」这个用户可见的操作实际上是空操作。
/// 新版由 `EngineConfig::from_json` 真正读取，配置文件重新生效。
///
/// **有意删除的字段**：`max_proposals_per_session`。
/// TS 在 engine L46 赋值后从未参与任何判定（实测全仓无读取点），
/// 而 README L113 与 SKILL.md L386 却把它写成了用户可配的行为。
/// 移植时保持等价（即不实现），并在 README 里标注为已知缺口 ——
/// 「顺手实现」会改变提案产出频率，属于超出移植范围的行为变更。

///|
/// 进化强度。对应 legacy-ts 的 `'100%' | '50%' | '0%'`（types L294）。
/// 语义见 CONTEXT.md L15：100% 响应全部信号 / 50% 仅强信号 / 0% 禁用。
pub(all) enum Intensity {
  /// 积极：强信号与中信号都触发（engine L164-166）
  Full
  /// 审慎：仅强信号触发（engine L168-171）
  Half
  /// 关闭：不做任何进化检查（engine L60-63）
  Off
} derive(Eq, Debug)

///|
/// 引擎配置。
pub(all) struct EngineConfig {
  intensity : Intensity
  /// 同一插件两次提案之间的最短间隔（小时）。默认 24（engine L47）
  cooldown_hours : Int
  /// 是否跳过人工审批。默认 false —— CONTEXT.md「审批强制」不变量
  auto_approve : Bool
  thresholds : SignalThresholds
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 默认配置，逐一对应 legacy-ts 的实际生效值。
pub fn EngineConfig::default() -> EngineConfig {
  {
    intensity: Half,
    cooldown_hours: 24,
    auto_approve: false,
    thresholds: SignalThresholds::default(),
  }
}

// ----------------------------------------------------------------------------
// 容错 JSON 取值 helper。
//
// 刻意不用 core/json 的 `Json::value` / `as_string` / `as_number` ——
// 它们全部标记了 `#deprecated`（建议改用模式匹配）。
// 也不用 `derive(FromJson)`：配置文件是**人写的、可能残缺**的输入，
// 缺字段应回退默认值，而不是让整个插件启动失败。
// ----------------------------------------------------------------------------

fn str_field(obj : Map[String, Json], key : String) -> String? {
  match obj.get(key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

fn bool_field(obj : Map[String, Json], key : String) -> Bool? {
  match obj.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}

fn num_field(obj : Map[String, Json], key : String) -> Double? {
  match obj.get(key) {
    Some(Number(n, ..)) => Some(n)
    _ => None
  }
}

fn obj_field(obj : Map[String, Json], key : String) -> Map[String, Json]? {
  match obj.get(key) {
    Some(Object(o)) => Some(o)
    _ => None
  }
}

///|
/// 读一个阈值：**先扁平、后 1.0 的嵌套形状**。
///
/// 扁平形状（`signal_thresholds.consecutive_failures`）是 2.0 的规范形状，
/// 它的键名与 `SignalThresholds` 的字段名**逐字相同** ——
/// 这是「词汇即文档」用在配置上：配置文件和代码说同一套词，
/// 读配置的人不需要在脑子里做一次映射。
///
/// 嵌套形状（`.strong.consecutive_failures` / `.medium.loop_detection` /
/// `.strong.performance_drop`）是 1.0 的 plugin.json L53-65 写的，
/// 保留它作为回退，让旧的配置文件继续生效。
/// 注意 1.0 的键名与结构体字段并不同名（`performance_drop` vs
/// `latency_regression`），那份映射是手写的 —— 这也正是要换成扁平形状的理由。
///
/// 两条路径都读不到时返回 `fallback`（即 `SignalThresholds::default()` 的对应项）。
fn threshold_field(
  st : Map[String, Json],
  flat_key : String,
  legacy_group : String,
  legacy_key : String,
  fallback : Double,
) -> Double {
  match num_field(st, flat_key) {
    Some(n) => n
    None =>
      match obj_field(st, legacy_group) {
        Some(g) =>
          match num_field(g, legacy_key) {
            Some(n) => n
            None => fallback
          }
        None => fallback
      }
  }
}

fn threshold_int(
  st : Map[String, Json],
  flat_key : String,
  legacy_group : String,
  legacy_key : String,
  fallback : Int,
) -> Int {
  threshold_field(
    st,
    flat_key,
    legacy_group,
    legacy_key,
    fallback.to_double(),
  ).to_int()
}

///|
/// 从 `.zcode-plugin/plugin.json` 的 `evolution_config` 段解析配置。
///
/// 入参可以是整个 plugin.json，也可以是 `evolution_config` 子对象 ——
/// 前者会自动下钻一层。任何缺失或类型不符的字段都回退到默认值。
///
/// `signal_thresholds` 同时接受两种形状（见 `threshold_field`）：
/// 2.0 的**扁平**形状（键名与 `SignalThresholds` 字段逐字相同）优先，
/// 1.0 的**嵌套**形状（`.strong.consecutive_failures` / `.medium.loop_detection`
/// / `.strong.performance_drop`，即 plugin.json L53-65）作为回退。
/// 两者都读不到才落到默认阈值。
pub fn EngineConfig::from_json(json : Json) -> EngineConfig {
  let defaults = EngineConfig::default()
  let root = match json {
    Object(o) => o
    _ => return defaults
  }
  // 允许传入整个 plugin.json：自动下钻到 evolution_config
  let cfg = match obj_field(root, "evolution_config") {
    Some(inner) => inner
    None => root
  }

  let intensity = match str_field(cfg, "intensity") {
    Some(s) => intensity_wire.find_by_name(s).unwrap_or(defaults.intensity)
    None => defaults.intensity
  }
  let cooldown = match num_field(cfg, "cooldown_hours") {
    Some(n) => n.to_int()
    None => defaults.cooldown_hours
  }
  let auto_approve = bool_field(cfg, "auto_approve").unwrap_or(
    defaults.auto_approve,
  )

  let td = defaults.thresholds
  let thresholds = match obj_field(cfg, "signal_thresholds") {
    None => td
    Some(st) =>
      {
        consecutive_failures: threshold_int(
          st,
          "consecutive_failures",
          "strong",
          "consecutive_failures",
          td.consecutive_failures,
        ),
        loop_detection: threshold_int(
          st,
          "loop_detection",
          "medium",
          "loop_detection",
          td.loop_detection,
        ),
        latency_regression: threshold_field(
          st,
          "latency_regression",
          "strong",
          "performance_drop",
          td.latency_regression,
        ),
      }
  }

  { intensity, cooldown_hours: cooldown, auto_approve, thresholds, }
}
