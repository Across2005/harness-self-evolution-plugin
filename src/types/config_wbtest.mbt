///|
/// 配置解析的边界情况测试。
///
/// 测试 `EngineConfig::from_json_checked` 对非法配置值的容错处理，
/// 确保非法值回落默认值并产生告警，而不是静默采纳或崩溃。
///
/// 这些测试补充了 `types_wbtest.mbt` 中的往返测试，
/// 专门覆盖配置解析的边界情况。

///|
/// 测试非整数的 `cooldown_hours` 应被截断并告警。
test "non-integer cooldown_hours falls back to default with warning" {
  let json = Json::object(Map([
    ("cooldown_hours", Json::number(23.9)),
  ]))
  let (cfg, warnings) = EngineConfig::from_json_checked(json)
  // 非整数应回落到默认值 24
  assert_eq(cfg.cooldown_hours, 24)
  // 应产生告警
  assert_true(warnings.length() > 0)
  assert_true(warnings[0].contains("cooldown_hours"))
  assert_true(warnings[0].contains("23.9"))
}

///|
/// 测试负数的 `max_log_bytes` 应回落默认值。
test "negative max_log_bytes falls back to default" {
  let json = Json::object(Map([
    ("max_log_bytes", Json::number(-1000.0)),
  ]))
  let (cfg, warnings) = EngineConfig::from_json_checked(json)
  // 负数应回落到默认值
  assert_eq(cfg.max_log_bytes, default_max_log_bytes)
  // 应产生告警
  assert_true(warnings.length() > 0)
  assert_true(warnings[0].contains("max_log_bytes"))
}

///|
/// 测试 `auto_approve: true`（布尔值 true）应回落 false 并告警。
test "auto_approve true falls back to false with warning" {
  let json = Json::object(Map([
    ("auto_approve", Json::boolean(true)),
  ]))
  let (cfg, warnings) = EngineConfig::from_json_checked(json)
  // auto_approve: true 应回落到 false（因为没有消费方）
  assert_eq(cfg.auto_approve, false)
  // 应产生告警
  assert_true(warnings.length() > 0)
  assert_true(warnings[0].contains("auto_approve"))
}

///|
/// 测试 `auto_approve: false`（布尔值 false）应被接受。
test "auto_approve false is accepted" {
  let json = Json::object(Map([
    ("auto_approve", Json::boolean(false)),
  ]))
  let (cfg, warnings) = EngineConfig::from_json_checked(json)
  assert_eq(cfg.auto_approve, false)
  // 不应产生告警
  assert_eq(warnings.length(), 0)
}

///|
/// 测试 `intensity: "100%"`（正确的枚举值）应被接受为 Full。
test "intensity 100% is accepted as Full" {
  let json = Json::object(Map([
    ("intensity", Json::string("100%")),
  ]))
  let (cfg, warnings) = EngineConfig::from_json_checked(json)
  // "100%" 是有效的枚举值，应被解析为 Full
  assert_eq(cfg.intensity, Full)
  // 不应产生告警
  assert_eq(warnings.length(), 0)
}

///|
/// 测试 `intensity: "50%"`（正确的枚举值）应被接受为 Half。
test "intensity 50% is accepted as Half" {
  let json = Json::object(Map([
    ("intensity", Json::string("50%")),
  ]))
  let (cfg, warnings) = EngineConfig::from_json_checked(json)
  // "50%" 是有效的枚举值，应被解析为 Half
  assert_eq(cfg.intensity, Half)
  // 不应产生告警
  assert_eq(warnings.length(), 0)
}

///|
/// 测试 `intensity: "0%"`（正确的枚举值）应被接受为 Off。
test "intensity 0% is accepted as Off" {
  let json = Json::object(Map([
    ("intensity", Json::string("0%")),
  ]))
  let (cfg, warnings) = EngineConfig::from_json_checked(json)
  // "0%" 是有效的枚举值，应被解析为 Off
  assert_eq(cfg.intensity, Off)
  // 不应产生告警
  assert_eq(warnings.length(), 0)
}

///|
/// 测试 `intensity: "full"`（无效的枚举值）应回落默认值。
test "intensity invalid value falls back to default" {
  let json = Json::object(Map([
    ("intensity", Json::string("full")),
  ]))
  let (cfg, warnings) = EngineConfig::from_json_checked(json)
  // "full" 不是有效的枚举值（应该是 "100%"），应回落到默认值 Half
  assert_eq(cfg.intensity, Half)
  // 不应产生告警（缺失/类型不符静默回落）
  assert_eq(warnings.length(), 0)
}

///|
/// 测试 `intensity: "Full"`（无效的枚举值）应回落默认值。
test "intensity Full falls back to default" {
  let json = Json::object(Map([
    ("intensity", Json::string("Full")),
  ]))
  let (cfg, warnings) = EngineConfig::from_json_checked(json)
  // "Full" 不是有效的枚举值（应该是 "100%"），应回落到默认值 Half
  assert_eq(cfg.intensity, Half)
  // 不应产生告警（缺失/类型不符静默回落）
  assert_eq(warnings.length(), 0)
}

///|
/// 测试 `cooldown_hours: 0`（边界值）应被接受。
test "cooldown_hours 0 is accepted" {
  let json = Json::object(Map([
    ("cooldown_hours", Json::number(0.0)),
  ]))
  let (cfg, warnings) = EngineConfig::from_json_checked(json)
  // 0 是有效的整数，应被接受
  assert_eq(cfg.cooldown_hours, 0)
  // 不应产生告警
  assert_eq(warnings.length(), 0)
}

///|
/// 测试 `cooldown_hours: 100000`（超过上限）应回落默认值。
test "cooldown_hours over limit falls back to default" {
  let json = Json::object(Map([
    ("cooldown_hours", Json::number(100000.0)),
  ]))
  let (cfg, warnings) = EngineConfig::from_json_checked(json)
  // 超过上限应回落到默认值 24
  assert_eq(cfg.cooldown_hours, 24)
  // 应产生告警
  assert_true(warnings.length() > 0)
  assert_true(warnings[0].contains("cooldown_hours"))
}

///|
/// 测试 `max_log_bytes: 0`（边界值）应回落默认值。
test "max_log_bytes 0 falls back to default" {
  let json = Json::object(Map([
    ("max_log_bytes", Json::number(0.0)),
  ]))
  let (cfg, warnings) = EngineConfig::from_json_checked(json)
  // 0 是非法值（低于下界），应回落到默认值
  assert_eq(cfg.max_log_bytes, default_max_log_bytes)
  // 应产生告警
  assert_true(warnings.length() > 0)
  assert_true(warnings[0].contains("max_log_bytes"))
}

///|
/// 测试 `max_log_bytes: 500000`（低于下界）应回落默认值。
test "max_log_bytes below minimum falls back to default" {
  let json = Json::object(Map([
    ("max_log_bytes", Json::number(500000.0)),
  ]))
  let (cfg, warnings) = EngineConfig::from_json_checked(json)
  // 低于下界（1 MiB）应回落到默认值
  assert_eq(cfg.max_log_bytes, default_max_log_bytes)
  // 应产生告警
  assert_true(warnings.length() > 0)
  assert_true(warnings[0].contains("max_log_bytes"))
}

///|
/// 测试完整的合法配置应被接受。
test "valid complete config is accepted without warnings" {
  let json = Json::object(Map([
    ("intensity", Json::string("50%")),
    ("cooldown_hours", Json::number(12.0)),
    ("auto_approve", Json::boolean(false)),
    ("max_log_bytes", Json::number(16777216.0)),
    ("signal_thresholds", Json::object(Map([
      ("consecutive_failures", Json::number(5.0)),
      ("loop_detection", Json::number(10.0)),
      ("latency_regression", Json::number(0.3)),
    ]))),
  ]))
  let (cfg, warnings) = EngineConfig::from_json_checked(json)
  assert_eq(cfg.intensity, Half)
  assert_eq(cfg.cooldown_hours, 12)
  assert_eq(cfg.auto_approve, false)
  assert_eq(cfg.max_log_bytes, 16777216)
  assert_eq(cfg.thresholds.consecutive_failures, 5)
  assert_eq(cfg.thresholds.loop_detection, 10)
  assert_eq(cfg.thresholds.latency_regression, 0.3)
  // 不应产生告警
  assert_eq(warnings.length(), 0)
}

///|
/// 测试空对象应返回默认配置。
test "empty object returns default config" {
  let json = Json::object(Map([]))
  let (cfg, warnings) = EngineConfig::from_json_checked(json)
  let defaults = EngineConfig::default()
  assert_eq(cfg.intensity, defaults.intensity)
  assert_eq(cfg.cooldown_hours, defaults.cooldown_hours)
  assert_eq(cfg.auto_approve, defaults.auto_approve)
  assert_eq(cfg.max_log_bytes, defaults.max_log_bytes)
  // 不应产生告警
  assert_eq(warnings.length(), 0)
}

///|
/// 测试非对象输入应返回默认配置。
test "non-object input returns default config" {
  let json = Json::string("not an object")
  let (cfg, warnings) = EngineConfig::from_json_checked(json)
  let defaults = EngineConfig::default()
  assert_eq(cfg.intensity, defaults.intensity)
  assert_eq(cfg.cooldown_hours, defaults.cooldown_hours)
  assert_eq(cfg.auto_approve, defaults.auto_approve)
  assert_eq(cfg.max_log_bytes, defaults.max_log_bytes)
  // 非对象输入会产生一条告警（BUG-06 修复：原来是静默返回默认值）
  assert_eq(warnings.length(), 1)
}

///|
/// 测试 `intensity: "invalid"`（无效的枚举值）应回落默认值。
test "intensity invalid string falls back to default" {
  let json = Json::object(Map([
    ("intensity", Json::string("invalid")),
  ]))
  let (cfg, warnings) = EngineConfig::from_json_checked(json)
  // "invalid" 不是有效的枚举值，应回落到默认值 Half
  assert_eq(cfg.intensity, Half)
  // 不应产生告警（缺失/类型不符静默回落）
  assert_eq(warnings.length(), 0)
}

///|
/// 测试 `cooldown_hours: -1`（负数）应回落默认值。
test "cooldown_hours negative falls back to default" {
  let json = Json::object(Map([
    ("cooldown_hours", Json::number(-1.0)),
  ]))
  let (cfg, warnings) = EngineConfig::from_json_checked(json)
  // 负数应回落到默认值 24
  assert_eq(cfg.cooldown_hours, 24)
  // 应产生告警
  assert_true(warnings.length() > 0)
  assert_true(warnings[0].contains("cooldown_hours"))
}

///|
/// 测试 `max_log_bytes: 2147483647`（上界）应被接受。
test "max_log_bytes at upper bound is accepted" {
  let json = Json::object(Map([
    ("max_log_bytes", Json::number(2147483647.0)),
  ]))
  let (cfg, warnings) = EngineConfig::from_json_checked(json)
  // 上界值应被接受
  assert_eq(cfg.max_log_bytes, 2147483647)
  // 不应产生告警
  assert_eq(warnings.length(), 0)
}
