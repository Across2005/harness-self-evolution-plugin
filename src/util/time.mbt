///|
/// 时间工具：时间戳的唯一内部表示是 **Unix 毫秒（Int64）**。
///
/// 为什么不用 `moonbitlang/x/time`：实测 `x/time/plain_time.mbt` 的 `to_string`
/// 仅在 `nanosecond > 0` 时才写小数段，且 `x/time/util.mbt` 的 `format_nanos`
/// 会剥掉尾随零（`format_nanos(100_000_000)` → `".1"`），而
/// `ZonedDateTime::to_string` 还会追加 offset 与 `[时区缩写]`。
/// JS 的 `Date.prototype.toISOString()` 恒为 `YYYY-MM-DDTHH:mm:ss.mmmZ`（三位毫秒 + Z），
/// 两者必然不符。且 `x/time` **没有 `Instant`、没有任何 `now()`**，是纯日历库。
/// 于是自写 60 行换掉一个 1.4 万行依赖，且完全可单测。
///
/// 为什么内部一律用 Int64 毫秒：机器侧的比较（cooldown、延迟回归、时间窗过滤）
/// 全部变成纯整数减法，彻底消除 legacy-ts 里 `new Date(str).getTime()`
/// 解析失败这一整类故障（store/index.ts L172、monitor/index.ts L154）。
/// 仅在 JSON 输出边界调 `iso_utc` 格式化。
///
/// 时钟源用 `@env.now()`（`core/env/env.mbt` 注释明示为 "milliseconds since the Unix
/// epoch"），**不用** `@async.now()` —— 后者已 `#deprecated("use @env.now() ...")`。

let ms_per_second : Int64 = 1_000L

let ms_per_minute : Int64 = 60_000L

let ms_per_hour : Int64 = 3_600_000L

let ms_per_day : Int64 = 86_400_000L

///|
/// 当前 Unix 毫秒。`@env.now()` 返回 `UInt64`；毫秒级时间戳远小于 2^63，
/// 位模式 reinterpret 安全，且转成 Int64 后才能做无下溢的减法。
pub fn now_ms() -> Int64 {
  @env.now().reinterpret_as_int64()
}

///|
/// 自 `from` 以来经过的毫秒数。
pub fn elapsed_ms(from : Int64) -> Int64 {
  now_ms() - from
}

///|
/// 小时 → 毫秒。供 engine 的 cooldown 配置使用。
pub fn hours_to_ms(h : Int) -> Int64 {
  h.to_int64() * ms_per_hour
}

///|
/// 分钟 → 毫秒。
pub fn minutes_to_ms(m : Int) -> Int64 {
  m.to_int64() * ms_per_minute
}

///|
/// C 语义的截断除法（向零取整）。
///
/// Hinnant 的 civil_from_days 算法依赖此语义来处理 1970 之前的负天数
/// （它通过 `if z >= 0 { z } else { z - 146096 }` 预先把负值推入正确的商区间）。
/// 显式实现一次，就不必依赖语言默认的取整方向。
fn tdiv(a : Int64, b : Int64) -> Int64 {
  let q = a / b
  if (a < 0L) != (b < 0L) && q * b != a {
    q + 1L
  } else {
    q
  }
}

///|
/// Howard Hinnant 的 days-from-civil 逆运算：把「自 1970-01-01 起的天数」
/// 换算为公历 (年, 月, 日)。约 12 行纯整数运算，无外部依赖、无 raise。
/// 返回的年份已按「1、2 月属于上一年」的历法惯例修正。
fn civil_from_days(z : Int64) -> (Int64, Int64, Int64) {
  let zz = z + 719_468L
  let era = tdiv(if zz >= 0L { zz } else { zz - 146_096L }, 146_097L)
  let doe = zz - era * 146_097L // [0, 146096]
  let yoe = tdiv(
    doe - tdiv(doe, 1_460L) + tdiv(doe, 36_524L) - tdiv(doe, 146_096L),
    365L,
  ) // [0, 399]
  let doy = doe - (365L * yoe + tdiv(yoe, 4L) - tdiv(yoe, 100L)) // [0, 365]
  let mp = tdiv(5L * doy + 2L, 153L) // [0, 11]
  let d = doy - tdiv(153L * mp + 2L, 5L) + 1L // [1, 31]
  let m = mp + (if mp < 10L { 3L } else { -9L }) // [1, 12]
  (yoe + era * 400L + (if m <= 2L { 1L } else { 0L }), m, d)
}

fn pad(n : Int64, width : Int) -> String {
  n.to_string().pad_start(width, '0')
}

///|
/// 格式化为恰好 24 字符的 `YYYY-MM-DDTHH:mm:ss.mmmZ`（纯 UTC）。
///
/// 与 JS `new Date(ms).toISOString()` 逐字符等价 —— 这是硬性验收判据，
/// 由 `time_test.mbt` 用 `node -e` 的真实输出对拍。
pub fn iso_utc(ms : Int64) -> String {
  let raw_days = tdiv(ms, ms_per_day)
  let rem = ms - raw_days * ms_per_day
  // 1970 之前的负毫秒：余数为负，借一天使其落回 [0, 86400000)
  let (days, ms_of_day) = if rem < 0L {
    (raw_days - 1L, rem + ms_per_day)
  } else {
    (raw_days, rem)
  }
  let (y, m, d) = civil_from_days(days)
  let sec_total = tdiv(ms_of_day, ms_per_second)
  let milli = ms_of_day - sec_total * ms_per_second
  let hh = tdiv(sec_total, 3_600L)
  let mm = tdiv(sec_total - hh * 3_600L, 60L)
  let ss = sec_total - hh * 3_600L - mm * 60L
  "\{pad(y, 4)}-\{pad(m, 2)}-\{pad(d, 2)}T\{pad(hh, 2)}:\{pad(mm, 2)}:\{pad(ss, 2)}.\{pad(milli, 3)}Z"
}

///|
/// 取 UTC 日期部分 `YYYY-MM-DD`。
/// 供 engine 拼 `proposal_id`（legacy-ts/src/engine/index.ts L130 的
/// `new Date().toISOString().split('T')[0]`）。
pub fn date_utc(ms : Int64) -> String {
  iso_utc(ms)[:10].to_owned()
}
