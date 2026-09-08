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

// 容错 JSON 取值 helper 和域校验函数已拆分至 config_helpers.mbt。

///|
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
/// 只对「取值域越界」与「非整数阈值」告警（后者会经 `.to_int()` 静默截断，
/// 同样是静默改行为，见 `threshold_int`）：
/// 缺失与类型不符继续静默回落（太常见，为它们告警会淹没要紧的那几条）。
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
  let (cooldown_raw, w_cooldown_int) = match num_field(cfg, "cooldown_hours") {
    Some(n) => integer_field("cooldown_hours", n, defaults.cooldown_hours)
    None => (defaults.cooldown_hours, None)
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
  let (max_log_raw, w_max_log_int) = match num_field(cfg, "max_log_bytes") {
    Some(n) => integer_field("max_log_bytes", n, defaults.max_log_bytes)
    None => (defaults.max_log_bytes, None)
  }

  let td = defaults.thresholds
  let no_warn : Array[String] = []
  // 原始阈值 + 非整数告警（在 int_floor 的取值域校验之前产生）
  let (cf_raw, loop_raw, latency_raw, w_threshold) = match
    obj_field(cfg, "signal_thresholds") {
    None =>
      (
        td.consecutive_failures,
        td.loop_detection,
        td.latency_regression,
        no_warn,
      )
    Some(st) => {
      let (cf_raw, w_cf_int) = threshold_int(
        st,
        "consecutive_failures",
        "strong",
        "consecutive_failures",
        td.consecutive_failures,
      )
      let (loop_raw, w_loop_int) = threshold_int(
        st,
        "loop_detection",
        "medium",
        "loop_detection",
        td.loop_detection,
      )
      let latency_raw = threshold_field(
        st,
        "latency_regression",
        "strong",
        "performance_drop",
        td.latency_regression,
      )
      let ws : Array[String] = []
      for w in [w_cf_int, w_loop_int] {
        match w {
          Some(msg) => ws.push(msg)
          None => ()
        }
      }
      (cf_raw, loop_raw, latency_raw, ws)
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
    cf_raw,
    1,
    td.consecutive_failures,
  )
  let (loop_n, w_loop) = int_floor(
    "signal_thresholds.loop_detection",
    loop_raw,
    2,
    td.loop_detection,
  )
  let (latency, w_latency) = ratio_domain(
    "signal_thresholds.latency_regression",
    latency_raw,
    td.latency_regression,
  )
  let (max_log, w_max_log) = int_domain(
    "max_log_bytes",
    max_log_raw,
    min_max_log_bytes,
    max_max_log_bytes,
    defaults.max_log_bytes,
  )
  // 非整数阈值告警先入列（对应原始解析阶段），随后是取值域越界告警
  for msg in w_threshold {
    warn.push(msg)
  }
  for
    w in [
      w_cooldown_int, w_max_log_int, w_cooldown, w_cf, w_loop, w_latency, w_max_log,
    ] {
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

///|
/// 监控配置。对应 `.zcode-plugin/plugin.json` 的 `monitoring` 段。
///
/// **当前状态**：声明但未被插件自身消费（已知缺陷 #9）。
/// 监控事件由宿主经 MCP 工具调用链埋点（`record_tool_call` / `record_user_feedback`），
/// 插件进程自己没有事件源。`enabled` / `sample_rate` 尚无消费方。
/// 此结构体用于**解析与验证**配置文件中的 monitoring 段，
/// 为未来的真实监控数据源接入做准备。
pub(all) struct MonitoringConfig {
  /// 是否启用监控。默认 true。
  enabled : Bool
  /// 采样率 (0.0, 1.0]。默认 1.0（全量采集）。
  sample_rate : Double
  /// 采集的指标列表。当前仅用于文档目的。
  metrics : Array[String]
} derive(Eq, Debug)

///|
/// 监控配置的默认值。
pub fn MonitoringConfig::default() -> MonitoringConfig {
  {
    enabled: true,
    sample_rate: 1.0,
    metrics: ["latency", "success_rate", "token_usage", "retry_count", "user_feedback"],
  }
}

///|
/// 从 JSON 对象解析监控配置。缺失或类型不符的字段回退默认值。
pub fn MonitoringConfig::from_json_obj(obj : Map[String, Json]) -> MonitoringConfig {
  let defaults = MonitoringConfig::default()
  let enabled = match bool_field(obj, "enabled") {
    Some(b) => b
    None => defaults.enabled
  }
  let sample_rate = match num_field(obj, "sample_rate") {
    Some(r) if r > 0.0 && r <= 1.0 => r
    _ => defaults.sample_rate
  }
  let metrics = match obj.get("metrics") {
    Some(Array(arr)) => {
      let out : Array[String] = []
      for item in arr {
        match item {
          String(s) => out.push(s)
          _ => ()
        }
      }
      if out.length() > 0 { out } else { defaults.metrics }
    }
    _ => defaults.metrics
  }
  { enabled, sample_rate, metrics }
}

///|
/// 从 JSON 解析监控配置。自动下钻到对象层。
pub fn MonitoringConfig::from_json(json : Json) -> MonitoringConfig {
  let defaults = MonitoringConfig::default()
  let obj = match json {
    Object(o) => o
    _ => return defaults
  }
  MonitoringConfig::from_json_obj(obj)
}

///|
/// 统一的 Harness 配置。包装 `EngineConfig`、`ScanConfig` 和 `MonitoringConfig`。
///
/// **设计意图**：将 `.zcode-plugin/plugin.json` 的三个配置段合并为一个结构体，
/// 消除配置来源的碎片化。`load_config` 返回此结构体，`ServerState` 接受此结构体。
/// 向后兼容：`ServerState::with_scan_config` 和 `ServerState::at` 仍然工作，
/// 内部转换为 `HarnessConfig`。
pub struct HarnessConfig {
  /// 进化引擎配置（`evolution_config` 段）
  engine : EngineConfig
  /// 监控配置（`monitoring` 段）
  monitoring : MonitoringConfig
} derive(Eq, Debug)

///|
/// 统一配置的默认值。
pub fn HarnessConfig::default() -> HarnessConfig {
  {
    engine: EngineConfig::default(),
    monitoring: MonitoringConfig::default(),
  }
}

///|
/// 从 JSON 解析统一配置。自动下钻到 `evolution_config` 和 `monitoring` 段。
pub fn HarnessConfig::from_json(json : Json) -> HarnessConfig {
  let engine = EngineConfig::from_json(json)
  let root = match json {
    Object(o) => o
    _ => return { engine, monitoring: MonitoringConfig::default() }
  }
  let monitoring = match obj_field(root, "monitoring") {
    Some(m) => MonitoringConfig::from_json_obj(m)
    None => MonitoringConfig::default()
  }
  { engine, monitoring }
}

///|
/// 从 JSON 解析统一配置，返回告警列表。
pub fn HarnessConfig::from_json_checked(json : Json) -> (HarnessConfig, Array[String]) {
  let (engine, warns) = EngineConfig::from_json_checked(json)
  let root = match json {
    Object(o) => o
    _ => return ({ engine, monitoring: MonitoringConfig::default() }, warns)
  }
  let monitoring = match obj_field(root, "monitoring") {
    Some(m) => MonitoringConfig::from_json_obj(m)
    None => MonitoringConfig::default()
  }
  ({ engine, monitoring }, warns)
}
