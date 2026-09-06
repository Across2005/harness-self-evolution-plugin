///|
/// `Jsonl::trim_to`（窗口裁剪）的行为测试。
///
/// 背景见 CONTEXT.md「数据文件布局」与申报书「风险与应对」：
/// metrics.jsonl / signals.jsonl 是 append-only 的观测日志，
/// 没有保留上限时随使用无界增长，而 `get_metrics` / `get_signals_for_plugin`
/// 每次都是全量读盘解析 —— 增长直接变成每次查询的延迟。
/// 裁剪是 store 层的深模块能力：调用方（monitor）只给一个字节上限，
/// 「找行边界、至少保留最新一行、丢弃残行、原子重写」全部收在本包内。
///
/// 用例全部按**字节**精确构造（UTF-8 下中文行宽 ≠ 字符数，按字节裁
/// 才能保证磁盘上界真正成立），并配合一条 JSONL 级的往返用例。

///|
/// 把原始字节写进临时文件，返回 Jsonl 句柄与其路径。
/// 直接 write_file 而不走 append：裁剪用例需要精确控制字节数。
async fn write_raw(path : String, content : String) -> Unit {
  @fs.write_file(path, content, create_mode=CreateOrTruncate)
}

///|
/// 读回文件的原始文本。
async fn read_raw(path : String) -> String {
  @fs.read_file(path).text()
}

///|
/// 磁盘上的实际字节数 —— 裁剪的承诺是对**磁盘**做出的，按它断言。
/// close 用 `defer` 挂在作用域出口，与 `trim_to` 的预检同一惯用法：
/// `f.size()` 若 raise，句柄也能照常关闭。
async fn disk_size(path : String) -> Int64 {
  let f = @fs.open(path, mode=ReadOnly)
  defer f.close()
  f.size()
}

///|
async test "trim_to keeps the newest lines within the byte cap" {
  let dir = @fs.tmpdir(prefix="evo-trim-1-")
  defer @fs.rmdir(dir, recursive=true)
  let path = @util.path_join(dir, "log.jsonl")
  // 5 行 × 4 字节 = 20 字节；上限 8 → 恰好保住最后两行
  write_raw(path, "aaa\nbbb\nccc\nddd\neee\n")
  let store = Jsonl::new(path)
  assert_true(store.trim_to(8))
  assert_eq(read_raw(path), "ddd\neee\n")
  // 已在上限内 → 无操作
  assert_false(store.trim_to(8))
}

///|
async test "trim_to keeps at least the newest line even when it exceeds the cap" {
  let dir = @fs.tmpdir(prefix="evo-trim-2-")
  defer @fs.rmdir(dir, recursive=true)
  let path = @util.path_join(dir, "log.jsonl")
  // "aaa\n" + 一条 11 字节的行；上限 8 放不下任何完整行，
  // 此时的正确行为是保住最新一行（11 > 8），而不是裁成空文件
  write_raw(path, "aaa\nbbbbbbbbbb\n")
  let store = Jsonl::new(path)
  assert_true(store.trim_to(8))
  assert_eq(read_raw(path), "bbbbbbbbbb\n")
}

///|
async test "trim_to drops a trailing partial line" {
  let dir = @fs.tmpdir(prefix="evo-trim-3-")
  defer @fs.rmdir(dir, recursive=true)
  let path = @util.path_join(dir, "log.jsonl")
  // 末尾没有换行 = 崩溃残留的不完整行；load 本来就解析不了它，
  // 留着还会让下一次 append 把新行拼在它后面（毒化两行）。
  // 裁剪把完整区留下、残行丢掉，文件从此以换行结尾。
  // 残行清理是**裁剪发生时**顺带做的：文件 12 字节，上限取 8
  // —— 若取一个放得下全文件的宽上限，廉价预检会直接判定无需裁剪。
  write_raw(path, "aaa\nbbb\npart")
  let store = Jsonl::new(path)
  assert_true(store.trim_to(8))
  assert_eq(read_raw(path), "aaa\nbbb\n")
}

///|
async test "trim_to on a missing file is a no-op" {
  let dir = @fs.tmpdir(prefix="evo-trim-4-")
  defer @fs.rmdir(dir, recursive=true)
  let path = @util.path_join(dir, "absent.jsonl")
  assert_false(Jsonl::new(path).trim_to(100))
  assert_false(@fs.exists(path))
}

///|
async test "trim_to with a non-positive cap is a no-op" {
  let dir = @fs.tmpdir(prefix="evo-trim-5-")
  defer @fs.rmdir(dir, recursive=true)
  let path = @util.path_join(dir, "log.jsonl")
  write_raw(path, "aaa\nbbb\n")
  let store = Jsonl::new(path)
  assert_false(store.trim_to(0))
  assert_eq(read_raw(path), "aaa\nbbb\n")
}

///|
async test "trim_to preserves the byte width of multibyte content" {
  let dir = @fs.tmpdir(prefix="evo-trim-6-")
  defer @fs.rmdir(dir, recursive=true)
  let path = @util.path_join(dir, "log.jsonl")
  // 中文行：每行 2 个字符，UTF-8 下却是 6 字节 + 换行 = 7 字节。
  // 若按字符数裁，磁盘上界就不成立了 —— 本用例钉住「按字节」的语义。
  write_raw(path, "甲甲\n乙乙\n丙丙\n")
  // 全文件 21 字节；上限 14 → 保住最后两行（14 字节）
  let store = Jsonl::new(path)
  assert_true(store.trim_to(14))
  assert_eq(disk_size(path), 14L)
  assert_true(read_raw(path) == "乙乙\n丙丙\n")
}

///|
/// JSONL 级往返：裁剪后的文件必须仍是合法 JSONL，
/// 且幸存的是**最新**的条目（append-only 日志的新行在文件末尾）。
async test "trim_to keeps the newest records loadable" {
  let dir = @fs.tmpdir(prefix="evo-trim-7-")
  defer @fs.rmdir(dir, recursive=true)
  let path = @util.path_join(dir, "events.jsonl")
  let store = Jsonl::new(path)
  let items : Array[Json] = [
    Json::string("e0"),
    Json::string("e1"),
    Json::string("e2"),
    Json::string("e3"),
  ]
  store.append_many(items)
  // 每行 `"eN"` + 换行 = 5 字节；上限 10 → 保住最后两行
  assert_true(store.trim_to(10))
  let loaded : Array[Json] = store.load()
  assert_eq(loaded.length(), 2)
  assert_eq(loaded[0], Json::string("e2"))
  assert_eq(loaded[1], Json::string("e3"))
}

///|
/// ★ 评审 W2 的回归网：**文件以空行结尾**时，旧实现把「空行起点」
/// 也算进候选窗口 —— 空行（1 字节）放得下、紧挨着它的真实记录
/// （`"bb"` 行 = 5 字节）放不下，于是裁完只剩一个 `"\n"`，最新记录反而被丢。
/// 这钉住的是「保留**最新的真实记录**」而非「保留最小的可行窗口」。
async test "trim_to does not keep a trailing empty line over the newest record" {
  let dir = @fs.tmpdir(prefix="evo-trim-10-")
  defer @fs.rmdir(dir, recursive=true)
  let path = @util.path_join(dir, "log.jsonl")
  // 内容 = `"a"` 行（4 字节）+ `"bb"` 行（5 字节）+ 一个多余的收尾空行。
  // 上限 4：空行（1 字节）放得下，而 `"bb"` 行（5 字节）放不下。
  write_raw(path, "\"a\"\n\"bb\"\n\n")
  let store = Jsonl::new(path)
  assert_true(store.trim_to(4))
  // 正确结果必须保住 `"bb"` 那行（`"bb"\n\n`，哪怕超出上限），而不是只留 "\n"。
  // 裁后的收尾空行无害：load 跳过空行。
  assert_eq(read_raw(path), "\"bb\"\n\n")
  let loaded : Array[Json] = store.load()
  assert_eq(loaded.length(), 1)
  assert_eq(loaded[0], Json::string("bb"))
}

///|
/// ★ W2 的第二个形状：文件末尾是**多个**空行时同样不得污染窗口选择。
async test "trim_to skips multiple trailing blank lines" {
  let dir = @fs.tmpdir(prefix="evo-trim-11-")
  defer @fs.rmdir(dir, recursive=true)
  let path = @util.path_join(dir, "log.jsonl")
  write_raw(path, "\"a\"\n\"bb\"\n\n\n")
  let store = Jsonl::new(path)
  assert_true(store.trim_to(4))
  assert_eq(read_raw(path), "\"bb\"\n\n\n")
  let loaded : Array[Json] = store.load()
  assert_eq(loaded.length(), 1)
  assert_eq(loaded[0], Json::string("bb"))
}

///|
/// 单行文件、且这一行自己就超过上限。`last_start` 只记「某个换行之后的起点」，
/// 对单行文件它永远取不到值（唯一那行的起点是 0），旧实现于是落到「裁空」分支，
/// 把仅存的一条证据抹掉。这钉的是 `trim_to` 文档里
/// 「**至少保留最新的一个完整行**，哪怕它自己就超过上限」那条承诺。
async test "trim_to keeps the newest line when it is also the first line" {
  let dir = @fs.tmpdir(prefix="evo-trim-8-")
  defer @fs.rmdir(dir, recursive=true)
  let path = @util.path_join(dir, "log.jsonl")
  write_raw(path, "bbbbbbbbbb\n")
  let store = Jsonl::new(path)
  // 返回 false：唯一那行必须整条留下，也就是「无需重写」。
  // trim_to 的返回值语义是「是否真的发生了裁剪」，不是「文件是否超限」。
  assert_false(store.trim_to(8))
  assert_eq(read_raw(path), "bbbbbbbbbb\n")
}

///|
/// 同一处缺陷在 signals 上的表现：裁剪后文件必须还能 `load` 出一条记录。
/// 旧实现返回空窗口，磁盘变 0 字节，`load()` 得到空数组 ——
/// 「保留最近一条证据」在监控日志上彻底落空。
async test "trim_to leaves a single oversized record loadable" {
  let dir = @fs.tmpdir(prefix="evo-trim-9-")
  defer @fs.rmdir(dir, recursive=true)
  let path = @util.path_join(dir, "signals.jsonl")
  let store = Jsonl::new(path)
  // 一条 `"s0"` + 换行 = 5 字节；上限 2 → 没有任何窗口放得下它
  store.append_many([Json::string("s0")])
  // 同上：唯一一条记录整条保留、不发生重写，但磁盘仍在上限之上 ——
  // 这是「至少保住最新一条证据」优先于「严格不超上限」的取舍。
  assert_false(store.trim_to(2))
  assert_eq(disk_size(path), 5L)
  let loaded : Array[Json] = store.load()
  assert_eq(loaded.length(), 1)
  assert_eq(loaded[0], Json::string("s0"))
}
