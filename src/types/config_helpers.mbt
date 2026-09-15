///|
/// 容错 JSON 取值 helper 和域校验函数。从 config.mbt 拆分，降低单文件复杂度。
///
/// 刻意不用 core/json 的 `Json::value` / `as_string` / `as_number` ——
/// 它们全部标记了 `#deprecated`（建议改用模式匹配）。
/// 也不用 `derive(FromJson)`：配置文件是**人写的、可能残缺**的输入，
/// 缺字段应回落默认值，而不是让整个插件启动失败。

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
/// 提取 JSON 数值字段。过滤 NaN/Infinity（JSON 规范不允许这些值，
/// 但手工构造的 `Json` 可以携带它们）：让它们走"字段缺失"路径
/// （回落默认值），与 H2 的"显式失效优于静默采纳"原则一致。
fn num_field(obj : Map[String, Json], key : String) -> Double? {
  match obj.get(key) {
    Some(Number(n, ..)) =>
      if n != n || n == 1.0 / 0.0 || n == -1.0 / 0.0 {
        None
      } else {
        Some(n)
      }
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
/// 这是「词汇即文档」用在配置上：配置文件和代码说同一套词汇，
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
/// 整数阈值：读出的是 Double，但消费方（`int_floor` 与检测判定）都要 Int。
/// 非整数（如 `2.5`）在 `.to_int()` 下会**静默截断**，写配置的人得不到任何
/// 反馈、检测灵敏度却已改变 —— 与 `int_domain` / `int_floor` 同一原则：
/// 回落 `fallback` 并产出点名告警，让失效可见。
fn threshold_int(
  st : Map[String, Json],
  flat_key : String,
  legacy_group : String,
  legacy_key : String,
  fallback : Int,
) -> (Int, String?) {
  let d = threshold_field(
    st,
    flat_key,
    legacy_group,
    legacy_key,
    fallback.to_double(),
  )
  integer_field("signal_thresholds.\{flat_key}", d, fallback)
}

///|
/// 整数配置字段：读出的是 Double，消费方要 Int。
/// 非整数（如 `0.5`）在 `.to_int()` 下会**静默截断**，写配置的人得不到任何
/// 反馈、引擎行为却已改变 —— 与 `threshold_int` 同一原则：
/// 回落 `fallback` 并产出点名告警，让失效可见。
///
/// ★ B1（mcp 评审）修复：`cooldown_hours` 与 `max_log_bytes` 过去直接
/// `n.to_int()`，`"cooldown_hours": 0.5` 会截断成 0（域内值，静默关掉冷却），
/// `"max_log_bytes": 2097152.9` 会截断成 2097152 —— 与 signal_thresholds
/// 的守卫不一致。现在统一走这里。
fn integer_field(name : String, d : Double, fallback : Int) -> (Int, String?) {
  if d == d.floor() {
    (d.to_int(), None)
  } else {
    (
      fallback,
      Some(
        "\{name}: \{d} is not an integer and fell back to the default \{fallback}",
      ),
    )
  }
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
