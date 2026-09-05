///|
/// JSONL 存储：一行一个 JSON 文档。
/// 取代 legacy-ts/src/store/index.ts L25-84 的 `JsonlStore<T>`。
///
/// 这是 CONTEXT.md「架构不变量①」的物理载体：全部 5 个数据文件
/// （proposals / metrics / signals / plugin-cache / execution.log）的读写
/// 都必须经本包，任何其他模块不得直接触碰 `@fs`。
///
/// **为什么 `Jsonl` 不是泛型类型**：TS 版是 `JsonlStore<T>`，但 `T` 只出现在
/// 方法签名里、不出现在任何字段里 —— 在 MoonBit 里这叫**幻影类型参数**，
/// 工具链会以 `unused_type_variable` 警告标出，且它给不出任何运行时保证。
/// 于是改为「非泛型类型 + 泛型方法」：`Jsonl` 只知道路径，
/// `load[T]` / `append[T]` 在调用点由上下文确定 `T`。
/// 类型纪律并不因此丢失 —— 本包的调用方只有 `ProposalStore`、`monitor` 与
/// `executor`，每处都持有各自语义明确的 `Jsonl` 字段，
/// 「把 metrics 当 proposals 读」这类错误在那些结构体层面就已不可能。
///
/// **三处错误选型决策**（都是刻意的，不是疏漏）：
/// 1. `load` **不上抛**：损坏行跳过并告警（含行号与原因），返回其余条目。
///    容错是存储层的策略，不该变成每个调用方的负担。对齐 TS L41-45，
///    但 TS 只打路径不打原因，这里补上行号与解析错误详情。
/// 2. `append` / `append_many` 的 I/O 错误**直接透传 raise**。
///    写失败必须让调用方知道；用 `Result` 包装会污染 20+ 个调用点，
///    而绝大多数调用方对「写不进去」毫无补救手段。
///    唯一的例外是 `monitor.flush_buffers`：它是**有补救手段**的那个调用方
///    （批次会回填缓冲、下一轮重试），于是它按批 `try/catch` 并打告警 ——
///    注意是「接住后重试 + 告警」，不是吞掉。见 CONTEXT.md 的 H1。
/// 3. **不提供 `rewrite` / `update`**。TS 版有这两个方法（L63-83），
///    `update` = 全量 load + map + 全量 rewrite，`setStatus` 因此每次要
///    「读两遍全文件、写一遍全文件」。新版把提案状态改成
///    **append-only + 按 proposal_id 折叠（后写覆盖先写）**，
///    于是 `rewrite` 再无调用方。少一个方法，就少一类
///    「写到一半崩溃导致整个数据集损坏」的故障 ——
///    TS 的 `rewrite` 先 `writeFile` 截断再写，中途失败即全量丢失。
///
/// **`append_many` 必须是单次 `write_file`**：POSIX 的 `O_APPEND` 与
/// Windows 的 `FILE_APPEND_DATA` 都只保证**单次 write 调用**的原子性。
/// 分多次写会让并发进程的日志行交错成半行。
/// 所以「批量 flush」不只是吞吐优化，而是正确性要求。

///|
/// 一个 JSONL 文件。
pub struct Jsonl {
  path : String
}

///|
/// 构造。路径经 `expand_home` 展开，故可以直接传 `~/...`。
pub fn Jsonl::new(path : String) -> Jsonl {
  { path: @util.expand_home(path) }
}

///|
/// 实际使用的绝对路径（展开 `~` 并归一化分隔符之后）。
pub fn Jsonl::path(self : Jsonl) -> String {
  self.path
}

///|
/// 文件是否存在。
pub async fn Jsonl::exists(self : Jsonl) -> Bool {
  @fs.exists(self.path)
}

///|
/// 文件的修改时间戳；不存在时返回 `None`。
///
/// 供 `ProposalStore::refresh` 做「有没有被别人改过」的廉价判定 ——
/// 一次 stat 换掉一次全量读盘 + 全量解析。
pub async fn Jsonl::mtime(self : Jsonl) -> (Int64, Int)? {
  if !@fs.exists(self.path) {
    return None
  }
  Some(@fs.mtime(self.path))
}

///|
/// 确保父目录存在。
/// `@fs.mkdir` 缺省 `recursive=false`，且其递归回退**仅在 ENOENT 时生效**
/// （Phase 0 门禁实测：`mkdir("a/b")` 在 `a` 不存在时直接失败），故必须显式传。
/// 已存在时跳过，避免 EEXIST。
async fn Jsonl::ensure_parent(self : Jsonl) -> Unit {
  let dir = @util.path_dirname(self.path)
  if dir == "." || dir == "/" {
    return
  }
  if !@fs.exists(dir) {
    @fs.mkdir(dir, recursive=true)
  }
}

///|
/// 序列化一条记录为一行（不含换行符）。
///
/// 用 `ToJson::to_json(x)` 而非 `x.to_json()`：后者是「从 impl 隐式提升为方法」，
/// 本工具链已标为 deprecated。
fn[T : ToJson] encode_line(item : T) -> String {
  ToJson::to_json(item).stringify()
}

///|
/// 读取全部记录。文件不存在 → 空数组。
/// 空行跳过；损坏行告警后跳过，**不中断**其余行的解析。
///
/// 只约束 `FromJson`（不约束 `ToJson`）：读取路径不做序列化，
/// 多余的约束会被工具链判为 unused_trait_bound。
pub async fn[T : @json.FromJson] Jsonl::load(self : Jsonl) -> Array[T] {
  if !@fs.exists(self.path) {
    return []
  }
  let content = @fs.read_file(self.path).text()
  let out : Array[T] = []
  let mut lineno = 0
  for line in content.split("\n") {
    lineno += 1
    let trimmed = line.trim().to_owned()
    if trimmed.length() == 0 {
      continue
    }
    // 解析与解码分两步，两者的失败都归入「损坏行」：
    // 前者是 JSON 语法坏了，后者是结构/词汇不符（如未知的 enum wire 名）。
    let decoded : Result[T, String] = Ok(@json.from_json(@json.parse(trimmed))) catch {
      e => Err(e.to_string())
    }
    match decoded {
      Ok(item) => out.push(item)
      Err(reason) =>
        @util.log_warn(
          "Store",
          "Skipping corrupt line \{lineno} in \{self.path}: \{reason}",
        )
    }
  }
  out
}

///|
/// 窗口裁剪：把文件裁到只保留**最新的** `max_bytes` 字节内的完整行。
///
/// 语义（按字节计，非字符 —— 磁盘上界只有按字节承诺才成立）：
/// · 保留区从某个**行边界**开始，到有效内容区末尾止，字节数 ≤ `max_bytes`；
/// · 在放得下的前提下保留**尽量多**的最新数据；
/// · **至少保留最新的一个完整行**，哪怕它自己就超过上限 ——
///   裁成空文件会让「保留最近一条证据」的承诺落空；
/// · 文件末尾若是不完整行（append 单次写原子性被崩溃破坏的残留），
///   一并丢弃 —— `load` 本来就解析不了它，留着还会让下一次 append
///   把新行拼接在它后面，毒化两行；
/// · 文件不存在、或在上限之内、或 `max_bytes <= 0`：无操作，返回 `false`。
///
/// 返回是否真的发生了裁剪。重写走「临时文件 + rename」，与
/// `write_json_atomic` 同一套原子性论证 —— 读者永远看不到半成品。
///
/// **并发边界**：本方法是「读全文件 → 原子重写」，与 append 不是原子的
/// 复合操作。在单写者（monitor 的 flush 循环）下两者天然串行；若未来出现
/// 第二个并发 append 方，裁剪窗口内的那次 append 可能被重写覆盖 ——
/// 调用方必须保证裁剪与 append 出自同一条写入路径。
pub async fn Jsonl::trim_to(self : Jsonl, max_bytes : Int) -> Bool {
  if max_bytes <= 0 {
    return false
  }
  if !@fs.exists(self.path) {
    return false
  }
  // 廉价预检：开只读句柄查一次大小，没超上限就整体不动。
  // `@fs` 没有路径级 stat 的 size（只有句级 `File::size`），这样已是最廉价的查法。
  let f = @fs.open(self.path, mode=ReadOnly)
  let size = f.size()
  f.close()
  if size <= max_bytes.to_int64() {
    return false
  }
  let raw = @fs.read_file(self.path).binary()
  let total = raw.length()
  let (cut, eff_end) = trim_window(raw, max_bytes)
  if cut == 0 && eff_end == total {
    // 不可达（前置已保证 size > max_bytes）；防御性返回，避免无意义重写
    return false
  }
  let tmp = self.path + ".tmp"
  @fs.write_file(tmp, raw[cut:eff_end], create_mode=CreateOrTruncate)
  @fs.rename(tmp, self.path)
  @util.log_info(
    "Store",
    "Trimmed \{self.path}: kept \{eff_end - cut} of \{total} bytes",
  )
  true
}

///|
/// 计算裁剪窗口：返回 `(cut, eff_end)`，保留区为 `raw[cut:eff_end]`。
///
/// `eff_end` 是**有效内容区**的终点：文件以换行结尾时即全长；否则是
/// 最后一个换行之后（残行丢弃）。`cut` 的选取：
/// · 整个有效区放得下 → `0`（只丢残行）；
/// · 否则取**最小的**、使保留区 ≤ 上限的行起点（保留尽量多）；
/// · 都放不下 → 最新一行的起点（至少保住一行）；
/// · 没有任何完整行 → `eff_end`（裁空）。
fn trim_window(raw : Bytes, max_bytes : Int) -> (Int, Int) {
  let total = raw.length()
  let mut eff_end = total
  if total > 0 && raw[total - 1] != b'\n' {
    let mut p = total - 1
    while p >= 0 && raw[p] != b'\n' {
      p -= 1
    }
    eff_end = p + 1
  }
  if eff_end <= max_bytes {
    return (0, eff_end)
  }
  let mut best_fit = -1
  let mut last_start = 0
  let mut p = 0
  while p < eff_end {
    if raw[p] == b'\n' && p + 1 < eff_end {
      let start = p + 1
      last_start = start
      if best_fit < 0 && eff_end - start <= max_bytes {
        best_fit = start
      }
    }
    p += 1
  }
  if best_fit >= 0 {
    (best_fit, eff_end)
  } else if last_start > 0 {
    (last_start, eff_end)
  } else {
    (eff_end, eff_end)
  }
}

///|
/// 追加一条记录。自动创建父目录。
pub async fn[T : ToJson] Jsonl::append(self : Jsonl, item : T) -> Unit {
  self.ensure_parent()
  let line = encode_line(item) + "\n"
  // create_mode 必须显式传：0.20.1 的 write_file 缺省会落到 TruncateExisting，
  // 其语义是「文件不存在则失败」（Phase 0 门禁实测）。追加要用 OpenOrCreate。
  @fs.write_file(self.path, line, create_mode=OpenOrCreate, append=true)
}

///|
/// 批量追加。空数组短路（连父目录都不创建，对齐 TS L57）。
///
/// **单次 `write_file`**：见文件头注释关于 append 原子性的论证。
pub async fn[T : ToJson] Jsonl::append_many(
  self : Jsonl,
  items : ArrayView[T],
) -> Unit {
  if items.length() == 0 {
    return
  }
  self.ensure_parent()
  let buf = StringBuilder::new(size_hint=items.length() * 64)
  for item in items {
    buf.write_string(encode_line(item))
    buf.write_char('\n')
  }
  @fs.write_file(
    self.path,
    buf.to_string(),
    create_mode=OpenOrCreate,
    append=true,
  )
}

///|
/// 原子地整体覆写一个**非 JSONL** 的 JSON 文件（写临时文件再 rename）。
///
/// 只给 `PluginCache` 用 —— 缓存是派生数据，整体重建是它的正常写入模式，
/// 与提案/指标的 append-only 语义不同。
/// `rename` 在同一文件系统内是原子的，故读者永远看不到半成品。
pub async fn write_json_atomic(path : String, json : Json) -> Unit {
  let target = @util.expand_home(path)
  let dir = @util.path_dirname(target)
  if dir != "." && dir != "/" && !@fs.exists(dir) {
    @fs.mkdir(dir, recursive=true)
  }
  let tmp = "\{target}.tmp"
  @fs.write_file(
    tmp,
    json.stringify(indent=2) + "\n",
    create_mode=CreateOrTruncate,
  )
  @fs.rename(tmp, target)
}

///|
/// 读取一个 JSON 文件；不存在或解析失败都返回 `None`。
/// 对齐 legacy-ts scanner L337-339 的「缓存坏了就当没有」。
pub async fn read_json(path : String) -> Json? {
  let target = @util.expand_home(path)
  if !@fs.exists(target) {
    return None
  }
  Some(@json.parse(@fs.read_file(target).text())) catch {
    e => {
      @util.log_warn("Store", "Cannot parse \{target}: \{e.to_string()}")
      None
    }
  }
}
