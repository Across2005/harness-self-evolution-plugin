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
  /// ★ S5（store 评审）：`load` 发现文件不以换行结尾（尾部有崩溃残行）置真，
  /// `append` / `append_many` 看到标志先把残行原子清掉再追加。
  /// 本仓的 JSONL 一律由 append 写出（恒以换行结尾），故「无换行结尾」
  /// 即残行，是成立的契约内判断。
  mut tainted : Bool
}

///|
/// 构造。路径经 `expand_home` 展开，故可以直接传 `~/...`。
pub fn Jsonl::new(path : String) -> Jsonl {
  { path: @util.expand_home(path), tainted: false }
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
/// 带 UTF-8 BOM 的文件先剥 BOM（★ S6）；尾部崩溃残行记入 `tainted`，
/// 由 append / append_many 清理（★ S5）。
///
/// 只约束 `FromJson`（不约束 `ToJson`）：读取路径不做序列化，
/// 多余的约束会被工具链判为 unused_trait_bound。
pub async fn[T : @json.FromJson] Jsonl::load(self : Jsonl) -> Array[T] {
  if !@fs.exists(self.path) {
    return []
  }
  let content = @fs.read_file(self.path).text()
  // ★ S6（store 评审）：剥掉 UTF-8 BOM（U+FEFF，磁盘上是 EF BB BF 三字节，
  // 解码为单个 UTF-16 码元，故按 1 个码元切掉）。带着它首行的 JSON 解析
  // 必然失败，整条记录会被当损坏行丢掉。
  let content = if content.has_prefix("\u{FEFF}") {
    content[1:].to_owned()
  } else {
    content
  }
  // ★ S5（store 评审）：文件不以换行结尾 = 尾部有崩溃残行（append 的
  // 单次写被进程死亡截断的唯一残留形态）。记下标志，追加前清理。
  self.tainted = content.length() > 0 && !content.has_suffix("\n")
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
  // close 用 `defer` 挂在**内层块**出口：`f.size()` 若 raise，手动 close 会被
  // 跳过、句柄就此泄漏 —— defer 保证两条路径都会关闭。
  // ★ S2（store 评审）：句柄必须在块内关闭 —— Windows 的 rename 不容忍
  // 目标还被本函数自己打开的只读句柄占着；旧实现 defer 到函数出口，
  // 晚于下面的 rename 触发，裁剪会随机性失败。
  let size = {
    let f = @fs.open(self.path, mode=ReadOnly)
    defer f.close()
    f.size()
  }
  if size <= max_bytes.to_int64() {
    return false
  }
  let raw = @fs.read_file(self.path).binary()
  let total = raw.length()
  let (cut, eff_end) = trim_window(raw, max_bytes)
  if cut == 0 && eff_end == total {
    // 整个有效区就是「最新的那一行」且它自己超过上限：按承诺整条保留，
    // 于是不需要重写（文件原样留着，字节数仍可能 > max_bytes）。
    // 这是「至少保住最新一条证据」优先于「严格不超上限」的唯一例外。
    return false
  }
  // ★ S9：tmp 路径由 `unique_tmp_path` 生成，rename 失败由
  // `rename_or_cleanup` 清残件 —— 与 write_json_atomic 同一配方。
  let tmp = unique_tmp_path(self.path)
  @fs.write_file(tmp, raw[cut:eff_end], create_mode=CreateOrTruncate)
  rename_or_cleanup(tmp, self.path)
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
/// · 都放不下 → 最新一行的起点（至少保住一行；整个文件只有一行时该起点就是 0）；
/// · 没有任何完整行（`eff_end == 0`）在上面「放得下」那条已提前返回，不会走到兜底分支。
///
/// ★ 修掉一处实测缺陷（评审 W2）：**空行不算候选行起点**。
/// JSONL 里一行 = 一条记录，空行要么是收尾换行的残留、要么是损坏痕迹。
/// 旧实现把空行也当候选：文件 `"aaa\nbbb\n\n"`、上限 4 字节时，
/// 空行起点（1 字节，放得下）会压过 `"bbb"` 行的起点（5 字节，放不下），
/// 于是裁完只剩一个 `"\n"` —— **最新的真实记录反而被丢了**。
/// 现在 `raw[start] == b'\n'` 的空行起点被跳过，`best_fit` / `last_start`
/// 都只跟踪非空行，保底语义不变（单行超限文件的起点仍是 0）。
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
      // 空行（下一个字符就是换行）不是记录，跳过 —— 见函数头注释
      if raw[start] != b'\n' {
        last_start = start
        if best_fit < 0 && eff_end - start <= max_bytes {
          best_fit = start
        }
      }
    }
    p += 1
  }
  if best_fit >= 0 {
    (best_fit, eff_end)
  } else {
    // 没有任何行起点放得下 -> 保住最新一行的起点。`last_start` 的初值 0
    // 正是「整个文件只有一行」时该行的起点，所以这里**不能**用
    // `last_start > 0` 当判据 —— 那样单行超限的文件会被裁成 0 字节。
    // 真正的「没有任何完整行」（eff_end == 0）在上面已提前返回，到不了这里。
    (last_start, eff_end)
  }
}

///|
/// 清理文件尾的崩溃残行（★ S5 的执行侧）。
///
/// 读全文、截掉最后一个换行之后的字节、原子重写。「截掉」的依据是
/// 契约内判断：本仓 JSONL 只由 append 写出（恒以换行结尾），无换行结尾的
/// 尾巴只可能是崩溃残行 —— `load` 也从未把它交还给调用方。
async fn Jsonl::heal_tainted_tail(self : Jsonl) -> Unit {
  let raw = @fs.read_file(self.path).binary()
  let mut end = raw.length()
  while end > 0 && raw[end - 1] != b'\n' {
    end -= 1
  }
  let tmp = unique_tmp_path(self.path)
  @fs.write_file(tmp, raw[0:end], create_mode=CreateOrTruncate)
  rename_or_cleanup(tmp, self.path)
  self.tainted = false
}

///|
/// 追加一条记录。自动创建父目录。
/// 尾部有崩溃残行时先原子清掉再追加，新记录绝不与残行拼接（★ S5）。
pub async fn[T : ToJson] Jsonl::append(self : Jsonl, item : T) -> Unit {
  self.ensure_parent()
  if self.tainted {
    self.heal_tainted_tail()
  }
  let line = encode_line(item) + "\n"
  // create_mode 必须显式传：0.20.1 的 write_file 缺省会落到 TruncateExisting，
  // 其语义是「文件不存在则失败」（Phase 0 门禁实测）。追加要用 OpenOrCreate。
  @fs.write_file(self.path, line, create_mode=OpenOrCreate, append=true)
}

///|
/// 批量追加。空数组短路（连父目录都不创建，对齐 TS L57）。
/// 尾部有崩溃残行时先原子清掉再追加，同 `append`（★ S5）。
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
  if self.tainted {
    self.heal_tainted_tail()
  }
  let buf = StringBuilder(size_hint=items.length() * 64)
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
/// 临时文件路径的进程内序号。MoonBit 的 `mut` 只允许出现在局部绑定、
/// 全局绑定不可变，故用「不可变全局绑定 + struct 可变字段」承载；
/// 单线程协作式调度下自增与读取之间没有 await 点，天然原子。
priv struct TmpPathSeq {
  mut seq : Int
}

///|
let tmp_path_seq : TmpPathSeq = { seq: 0 }

///|
/// 生成唯一临时文件路径：`<target>.<now_ms>.<seq>.tmp`（★ S9）。
///
/// 旧的固定 `<target>.tmp` 在两个原子写交错时会互相踩踏
/// （A 写 tmp → B 写同一 tmp → A rename 改走了 B 的半成品）；
/// 计数器 + 毫秒时间戳保证每次调用拿到的路径都不同。
fn unique_tmp_path(target : String) -> String {
  tmp_path_seq.seq += 1
  "\{target}.\{@util.now_ms()}.\{tmp_path_seq.seq}.tmp"
}

///|
/// rename 失败时尽力删除残留 tmp 再重新抛出（★ S9）。
/// rename 是原子替换的最后一步，它失败时 tmp 里只留下无主半成品，
/// 不清理会随失败重试不断堆积。
///
/// 必须是 async：`@fs.rename` / `@fs.remove` 都是 async 且会 raise，
/// 同步且无错误类型的函数体里既调不动也 raise 不出去。
/// 在 rename 失败的带错退出路径上清理残留 tmp（先删 tmp 再继续抛原始
/// 错误），成功路径不触发。
/// 注：moon 0.1.20260904 实测支持 `errdefer`（2026-09-15，此前
/// 0.1.20260819 会 Parse error），错误路径清理改用官方推荐的
/// errdefer 写法——仅在带错退出时执行，成功路径不触发，
/// 与原「catch 捕获 + 清理 + 重抛」结构语义等价。
/// 清理本身用 `catch { _ => () }` 吞错：tmp 已不存在等清理失败
/// 不该掩盖原始的 rename 错误。
async fn rename_or_cleanup(tmp : String, target : String) -> Unit {
  errdefer {
    @fs.remove(tmp) catch { _ => () }
  }
  @fs.rename(tmp, target)
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
  let tmp = unique_tmp_path(target)
  @fs.write_file(
    tmp,
    json.stringify(indent=2) + "\n",
    create_mode=CreateOrTruncate,
  )
  rename_or_cleanup(tmp, target)
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
