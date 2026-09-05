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
  /// **目前没有消费方**：1.0 只在 `types/index.ts:295` 声明了它、从未读过
  /// （2.0 忠实移植了这个孤岛）。人工审批是本插件压住「自动改代码失控」
  /// 这条最大风险的唯一闸门，所以这里刻意**不接通**它 —— 但也不再静默
  /// 采纳：`from_json_checked` 遇到 true 会告警并回落 false（见 H2 同款处理）。
  /// 默认 false。
  auto_approve : Bool
  thresholds : SignalThresholds
  /// 观测日志（metrics.jsonl 与 signals.jsonl）的保留上限（字节）。
  /// 两个文件各自独立裁到该上限，保留**最新的**完整行；提案与执行日志不裁。
  /// 0 在配置解析里不是合法值（见 min_max_log_bytes），直接构造结构体时
  /// 0 表示「不做保留裁剪」，仅供测试与显式豁免使用。
  max_log_bytes : Int
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 观测日志保留上限的默认值：32 MiB。
///
/// 定得过小会让裁剪在每轮 flush 都发生（读全文件 + 重写的「裁剪风暴」）；
/// 32 MiB 在单机插件生态的量级下（一次工具调用 ≈ 数百字节）足够容纳数周
/// 的历史，而磁盘占用与 `load()` 全量解析的成本都被钉死在这个上界。
pub let default_max_log_bytes : Int = 33_554_432

///|
/// 保留上限的下界（1 MiB）。低于它意味着裁剪几乎每轮 flush 都会触发，
/// 属于退化取值 —— 与 H2 同理，回落默认值并点名告警。
pub let min_max_log_bytes : Int = 1_048_576

///|
/// 保留上限的上界：Int 的饱和上界（~2 GiB）。再大，「有界」就失去了意义。
pub let max_max_log_bytes : Int = 2_147_483_647

///|
/// 默认配置，逐一对应 legacy-ts 的实际生效值。
pub fn EngineConfig::default() -> EngineConfig {
  {
    intensity: Half,
    cooldown_hours: 24,
    auto_approve: false,
    thresholds: SignalThresholds::default(),
    max_log_bytes: default_max_log_bytes,
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

///|
fn str_field(obj : Map[String, Json], key : String) -> String? {
  match obj.get(key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

///|
fn bool_field(obj : Map[String, Json], key : String) -> Bool? {
  match obj.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}

///|
fn num_field(obj : Map[String, Json], key : String) -> Double? {
  match obj.get(key) {
    Some(Number(n, ..)) => Some(n)
    _ => None
  }
}

///|
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

///|
fn threshold_int(
  st : Map[String, Json],
  flat_key : String,
  legacy_group : String,
  legacy_key : String,
  fallback : Int,
) -> Int {
  threshold_field(st, flat_key, legacy_group, legacy_key, fallback.to_double()).to_int()
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
///
/// **取值域越界的字段（如 `consecutive_failures: 0`）会被回落成默认值并告警**，
/// 见 `from_json_checked`。本函数丢掉告警，签名保持同步。
pub fn EngineConfig::from_json(json : Json) -> EngineConfig {
  let (cfg, _warn) = EngineConfig::from_json_checked(json)
  cfg
}

///|
/// `cooldown_hours` 的上界（10 年）。放这么宽只为了挡住明显的笔误 ——
/// 负数会让冷却终点算到过去、冷却形同不存在；`1e9` 则是近乎永久卡死。
let max_cooldown_hours : Int = 87_600

///|
/// 整数字段：落在 `[lo, hi]` 内则原样接受，否则回落 `dflt` 并产出一条告警。
fn int_domain(
  name : String,
  value : Int,
  lo : Int,
  hi : Int,
  dflt : Int,
) -> (Int, String?) {
  if value >= lo && value <= hi {
    (value, None)
  } else {
    (
      dflt,
      Some(
        "\{name}: \{value} is outside [\{lo}, \{hi}] and fell back to the default \{dflt}",
      ),
    )
  }
}

///|
/// 阈值下限：低于 `lo` 会让对应的检测恒真，故不 clamp 到 `lo` 而是回落默认值。
fn int_floor(
  name : String,
  value : Int,
  lo : Int,
  dflt : Int,
) -> (Int, String?) {
  if value >= lo {
    (value, None)
  } else {
    (
      dflt,
      Some(
        "\{name}: \{value} is below the minimum \{lo}, which makes the check always fire; it fell back to the default \{dflt}",
      ),
    )
  }
}

///|
/// 百分比字段：必须落在 `(0, 100]`。
fn ratio_domain(
  name : String,
  value : Double,
  dflt : Double,
) -> (Double, String?) {
  if value > 0.0 && value <= 100.0 {
    (value, None)
  } else {
    (
      dflt,
      Some(
        "\{name}: \{value} is outside (0, 100] and fell back to the default \{dflt}",
      ),
    )
  }
}

///|
/// 与 `from_json` 完全相同的解析结果，但额外返回一个告警数组。
///
/// **为什么要单独有这一层**：`from_json` 对缺失/类型不符的字段一律回落默认值，
/// 这是有意的（配置写错不该让引擎起不来，见 `harness_evolution/main.mbt`）。
/// 但「写成了退化值」和「没写」后果完全不同 —— 那些值会静默改变引擎行为：
///
/// - `consecutive_failures: 0`：成功调用会把失败计数清成 0，而判定是 `>=`
///   （`monitor.mbt` L321），于是**每次成功都发一条 strong 故障信号**；
/// - `loop_detection: 0 / 1`：达到阈值的分支恒真，而「清除已报告标记」
///   的分支要求 `same_tool_run < 阈值`（`monitor.mbt` L349）→ 永不可达，
///   于是每个工具的**第一次**调用就被报成循环；
/// - `latency_regression: 0`：任何延迟抖动都算性能退化（L476 是 `>`）；
/// - `cooldown_hours: -1`：`hours_to_ms` 得到负的窗口，而判定是
///   `now - created_at < cooldown_ms`（`store/proposals.mbt` 的
///   `recent_for_plugin`，由 `engine.mbt` L167-168 调用）→ 对任何历史提案都恒假
///   → 冷却等于不存在。
///
/// 引擎会拿着这些垃圾信号去改真实插件，比崩掉更糟。所以这里把这些取值挑出来
/// **回落默认值 + 点名字段告警**，由 `main.mbt` 在启动时打到 stderr。
///
/// 只对「取值域越界」告警：缺失与类型不符继续静默回落（太常见，
/// 为它们告警会淹没要紧的那几条）。
pub fn EngineConfig::from_json_checked(
  json : Json,
) -> (EngineConfig, Array[String]) {
  let warn : Array[String] = []
  let defaults = EngineConfig::default()
  let root = match json {
    Object(o) => o
    _ => return (defaults, warn)
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
  let cooldown_raw = match num_field(cfg, "cooldown_hours") {
    Some(n) => n.to_int()
    None => defaults.cooldown_hours
  }
  // 与 H2 同一套原则：非法/做不到的取值不能静默采纳。`auto_approve` 的
  // 「非法」不在于格式，而在于**没有消费方** —— 写 true 的人会以为绕过了审批，
  // 而审批其实照旧必经。所以显式告警 + 回落到 false，让失效变成可见的失效。
  let auto_approve = match bool_field(cfg, "auto_approve") {
    Some(true) => {
      warn.push(
        "auto_approve: true is not supported (approval is always manual), using false",
      )
      false
    }
    Some(false) => defaults.auto_approve
    None => defaults.auto_approve
  }
  let max_log_raw = match num_field(cfg, "max_log_bytes") {
    Some(n) => n.to_int()
    None => defaults.max_log_bytes
  }

  let td = defaults.thresholds
  let raw_thresholds = match obj_field(cfg, "signal_thresholds") {
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

  let (cooldown, w_cooldown) = int_domain(
    "cooldown_hours",
    cooldown_raw,
    0,
    max_cooldown_hours,
    defaults.cooldown_hours,
  )
  let (cf, w_cf) = int_floor(
    "signal_thresholds.consecutive_failures",
    raw_thresholds.consecutive_failures,
    1,
    td.consecutive_failures,
  )
  let (loop_n, w_loop) = int_floor(
    "signal_thresholds.loop_detection",
    raw_thresholds.loop_detection,
    2,
    td.loop_detection,
  )
  let (latency, w_latency) = ratio_domain(
    "signal_thresholds.latency_regression",
    raw_thresholds.latency_regression,
    td.latency_regression,
  )
  let (max_log, w_max_log) = int_domain(
    "max_log_bytes",
    max_log_raw,
    min_max_log_bytes,
    max_max_log_bytes,
    defaults.max_log_bytes,
  )
  for w in [w_cooldown, w_cf, w_loop, w_latency, w_max_log] {
    match w {
      Some(msg) => warn.push(msg)
      None => ()
    }
  }
  let out = {
    intensity,
    cooldown_hours: cooldown,
    auto_approve,
    thresholds: {
      consecutive_failures: cf,
      loop_detection: loop_n,
      latency_regression: latency,
    },
    max_log_bytes: max_log,
  }
  (out, warn)
}
