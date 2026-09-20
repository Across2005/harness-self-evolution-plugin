///|
/// `store/config_watch.mbt` 的行为测试 —— 钉住缺陷 3a「ConfigWatcher
/// 首轮必然误报 `Config file changed`」的修复契约。
///
/// 修复点在 `src/harness_evolution/main.mbt` 的 `config_watcher_loop`：
/// 它现在进 `while` **之前**先调 `config_mtime` 预置基线，而不是把基线初始化为 `None`。
/// 由于 main 是 executable 包放不了测试，本文件测的是从那里抽出来的两个原语，
/// 并由第 4 条用例把「预置基线 → 首轮不报」与「不预置 → 必报」并列断言 ——
/// 这正是修复前/后唯一的可观测差异。
///
/// main.mbt 那一行若被改回 `None`，第 4 条的对照断言仍会通过（它只描述旧行为），
/// 所以另有源码守卫 `G7`（`src/mcp/architecture_test.mbt`）直接盯住 `main.mbt`。
///
/// 用例全部用 `@fs.tmpdir` 隔离，不触碰真实 home 目录。

///|
/// 缺文件必须是 `None` 而不是崩溃：watcher 会在配置尚未落盘的部署里跑很久，
/// `mtime` 抛错若逃出去，`allow_failure=true` 的 spawn 会静默丢掉整个监听任务。
async test "config_mtime reports no baseline for a missing config file" {
  let dir = @fs.tmpdir(prefix="evo-cfgwatch-")
  defer @fs.rmdir(dir, recursive=true)
  let missing = @util.path_join(dir, "plugin.json")
  let expected : (Int64, Int)? = None
  assert_eq(config_mtime(missing), expected)
}

///|
/// 文件存在时必须拿到快照 —— 这是「预置基线」能起作用的前提。
async test "config_mtime reports a baseline for an existing config file" {
  let dir = @fs.tmpdir(prefix="evo-cfgwatch-")
  defer @fs.rmdir(dir, recursive=true)
  let path = @util.path_join(dir, "plugin.json")
  @fs.write_file(path, "{}", create_mode=CreateOrTruncate)
  assert_true(config_mtime(path) is Some(_))
}

///|
/// 纯函数穷举四种组合：用字面量元组而不是真实文件，避免依赖文件系统
/// 时间戳精度（同一毫秒内两次写入无法区分，那样的用例会 flaky）。
async test "config_changed covers creation, deletion and both mtime fields" {
  let baseline : (Int64, Int)? = Some((1_000L, 500))
  // 两轮都没有文件 → 无变化
  assert_false(config_changed(None, None))
  // ★ 文件在监听期间被创建 → 变化。
  //   这一支必须**保持** true：缺陷 3a 的修复走「预置基线」，
  //   而不是把这一支改成 false —— 后者会吃掉真实的「先删除、再重新创建」场景。
  assert_true(config_changed(None, baseline))
  // 文件被删除 → 变化
  assert_true(config_changed(baseline, None))
  // 时间戳逐字相同 → 无变化
  assert_false(config_changed(baseline, Some((1_000L, 500))))
  // 纳秒段变化（同一秒内的快速改动）→ 变化
  assert_true(config_changed(baseline, Some((1_000L, 501))))
  // 秒段变化 → 变化
  assert_true(config_changed(baseline, Some((1_001L, 500))))
}

///|
/// 缺陷 3a 的回归用例。
///
/// 用真实文件演示修复前后的差异：同一个「启动时就存在且从未改动」的配置文件，
/// 预置基线的首轮**不报**、基线为 `None` 的首轮**必报**。
/// 后一半即旧实现的行为，也是实测日志里那 10 条
/// `Config file changed, restart required` 的成因。
async test "a pre-seeded baseline keeps the first watcher round silent" {
  let dir = @fs.tmpdir(prefix="evo-cfgwatch-")
  defer @fs.rmdir(dir, recursive=true)
  let path = @util.path_join(dir, "plugin.json")
  @fs.write_file(path, "{}", create_mode=CreateOrTruncate)

  // 修复后的首轮：基线取自启动瞬间的快照 → 文件没动过 ⇒ 不报
  let pre_seeded = config_mtime(path)
  assert_true(pre_seeded is Some(_))
  assert_false(config_changed(pre_seeded, config_mtime(path)))

  // 对照（旧实现）：基线恒为 None → 同一个没动过的文件被判成「刚被创建」⇒ 误报
  assert_true(config_changed(None, config_mtime(path)))
}