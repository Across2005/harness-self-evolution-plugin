///|
/// `iso_utc` 的验收判据：与 JS `new Date(ms).toISOString()` **逐字符相等**。
///
/// 下面每个 (毫秒, 期望串) 对都由 `node -e` 的真实输出抄录，不是人工推算。
/// 这条纪律在本文件编写时就救了一次错：最初手算的 1900-02-28 对应值偏了一天。
///
/// 这是全案唯一一个「没有 TS 原文可对照、只能靠外部基准验证」的组件，
/// 因此单列为硬门禁：本文件不绿，不得进入 Phase 2。
/// 黑盒测试用 `@util.` 前缀，顺带证明这些函数确实是 `pub` 的。
test "iso_utc matches Date.prototype.toISOString byte for byte" {
  // Unix 纪元
  assert_eq(@util.iso_utc(0L), "1970-01-01T00:00:00.000Z")
  // 带毫秒：@time 在此会输出 ".7" 而非 ".700"
  assert_eq(@util.iso_utc(1_757_000_000_700L), "2025-09-04T15:33:20.700Z")
  // 毫秒恰为 0：@time 在此会**完全省略**小数段（其 to_string 有 nanosecond > 0 守卫）
  assert_eq(@util.iso_utc(1_757_000_000_000L), "2025-09-04T15:33:20.000Z")
  // 1970 之前的负毫秒（**整点**，`rem == 0`，不经过「借一天」分支；
  // 非整点的负毫秒见下面的专门用例）
  assert_eq(@util.iso_utc(-2_208_988_800_000L), "1900-01-01T00:00:00.000Z")
}

///|
/// 负毫秒的**非整点**用例：`tdiv` 的向零截断 + `iso_utc` 的借一天分支
/// 在这里才真正被踩到（整点用例 `rem == 0`，两分支都不进）。
/// 期望值由 `node -e` 的真实输出抄录：
/// ```text
/// new Date(-1).toISOString()                 → "1969-12-31T23:59:59.999Z"
/// new Date(-86_400_001).toISOString()        → "1969-12-30T23:59:59.999Z"
/// new Date(-2_208_988_800_001).toISOString() → "1899-12-31T23:59:59.999Z"
/// ```
test "iso_utc handles negative milliseconds with nonzero remainder" {
  assert_eq(@util.iso_utc(-1L), "1969-12-31T23:59:59.999Z")
  assert_eq(@util.iso_utc(-86_400_001L), "1969-12-30T23:59:59.999Z")
  assert_eq(@util.iso_utc(-2_208_988_800_001L), "1899-12-31T23:59:59.999Z")
  // 三个串都是 24 字符（回归网：B1 修复前 -1L 会输出 28 字符的垃圾串）
  assert_eq(@util.iso_utc(-1L).length(), 24)
}

///|
/// 闰年规则的两个分支：
/// 1900 能被 100 但不能被 400 整除 → **不是**闰年，2 月只有 28 天；
/// 2000 能被 400 整除 → **是**闰年，2 月有 29 天。
test "iso_utc applies the 400-year leap rule correctly" {
  assert_eq(@util.iso_utc(-2_204_064_000_000L), "1900-02-27T00:00:00.000Z")
  assert_eq(@util.iso_utc(-2_203_977_600_000L), "1900-02-28T00:00:00.000Z")
  // 1900 的 2 月 28 日次日直接跳到 3 月 1 日
  assert_eq(@util.iso_utc(-2_203_891_200_000L), "1900-03-01T00:00:00.000Z")
  assert_eq(@util.iso_utc(951_696_000_000L), "2000-02-28T00:00:00.000Z")
  assert_eq(@util.iso_utc(951_782_400_000L), "2000-02-29T00:00:00.000Z")
  assert_eq(@util.iso_utc(951_868_800_000L), "2000-03-01T00:00:00.000Z")
}

///|
/// 一日之内与跨日边界，以及毫秒的进位。
test "iso_utc day and millisecond boundaries" {
  assert_eq(@util.iso_utc(1L), "1970-01-01T00:00:00.001Z")
  assert_eq(@util.iso_utc(999L), "1970-01-01T00:00:00.999Z")
  assert_eq(@util.iso_utc(1_000L), "1970-01-01T00:00:01.000Z")
  assert_eq(@util.iso_utc(1_757_030_399_999L), "2025-09-04T23:59:59.999Z")
  assert_eq(@util.iso_utc(1_757_030_400_000L), "2025-09-05T00:00:00.000Z")
}

///|
/// 输出恒为 24 字符 —— MCP 客户端与 execution.log 都依赖这一稳定宽度。
test "iso_utc is always 24 characters" {
  for ms in [0L, 1L, 999L, 1_000L, 1_757_000_000_700L, -2_208_988_800_000L] {
    assert_eq(@util.iso_utc(ms).length(), 24)
  }
}

///|
test "date_utc takes the calendar date prefix" {
  assert_eq(@util.date_utc(1_757_000_000_700L), "2025-09-04")
  assert_eq(@util.date_utc(0L), "1970-01-01")
  assert_eq(@util.date_utc(-2_208_988_800_000L), "1900-01-01")
}

///|
test "hours_to_ms converts hours to milliseconds" {
  assert_eq(@util.hours_to_ms(24), 86_400_000L)
  assert_eq(@util.hours_to_ms(0), 0L)
  assert_eq(@util.hours_to_ms(3), 10_800_000L)
}

///|
test "now_ms is a 13-digit unix millisecond value" {
  let ms = @util.now_ms()
  // 2001-09-09 之后、2286-11-20 之前
  assert_true(ms > 1_000_000_000_000L)
  assert_true(ms < 10_000_000_000_000L)
}

///|
test "elapsed_ms is monotonic non-negative" {
  let t0 = @util.now_ms()
  assert_true(@util.elapsed_ms(t0) >= 0L)
}
