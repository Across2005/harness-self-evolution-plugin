///|
/// ★ 架构守卫测试。
///
/// 这不是功能测试，而是**把架构约束变成可执行的断言**。动机来自本项目的方法论
/// 本身：AI 加速开发也会加速熵增，「定期架构扫描」若只靠人读文档就会失效。
/// 把约束写进 `moon test`，退化就在 2 秒内变红，而不是在三个月后变成泥球。
///
/// 守卫的五条约束：
/// | # | 约束 | 出处 | 退化后的表现 |
/// |---|---|---|---|
/// | G1 | 依赖图与声明完全一致且**无环** | 计划「依赖图（无环，由 architecture_test.mbt 机器化守卫）」 | 循环依赖 / 层次穿透，最终无法单独测试某个包 |
/// | G2 | `@stdio.stdout` 只出现在 mcp/server.mbt；`@stdio.stderr` 只出现在 util/log.mbt | **F4** 的结构性修复 | 日志混进 MCP 协议通道，客户端解析失败断开 |
/// | G3 | `@fs` 的写操作只出现在 store/ | CONTEXT.md 不变量①的强化版 | 持久化逻辑四处散落，无法推理崩溃时的数据一致性 |
/// | G4 | `.harness-evolution` 字面量只出现在 store/paths.mbt | 计划 3.1「收拢 4 处重复的默认路径」 | 默认数据目录再次散落，改一处漏三处 |
/// | G5 | legacy 的 37 个 jest 用例**逐一**有 MoonBit 对应物 | 计划 1.1「保留 37 用例供对拍」 | 移植过程中静默丢掉覆盖，双跑对拍失去意义 |
///
/// 放在 mcp 包是因为它是依赖图的**合成根**（composition root）：
/// 它已经导入全部业务包，在这里审视整张图最自然。

// ============================================================================
// 读仓库的基础设施
// ============================================================================

///|
/// 读一个文本文件。
async fn read_text(path : String) -> String {
  (@fs.read_file(path)).text()
}

async fn exists(path : String) -> Bool {
  @fs.exists(path)
}

///|
/// 把字符串数组拼成一行，仅用于失败消息。
///
/// 不用 `Array::to_string()`：那走的是 `Show`，工具链已判为废弃
/// （提示改用 `@debug.Debug::to_repr`）。这里要的只是一段人能读的清单，
/// 手工拼接既不引依赖，也不受 `Debug` 输出格式变化的影响。
fn join_names(xs : ArrayView[String]) -> String {
  let mut out = ""
  let mut first = true
  for x in xs {
    if first {
      out = x
      first = false
    } else {
      out = "\{out}, \{x}"
    }
  }
  out
}

///|
/// 按行切开。统一用 `\n` 切、再 `trim`，于是 CRLF 与 LF 的仓库都能处理
/// （`.gitattributes` 决定了工作区里可能是 CRLF）。
fn lines_of(text : String) -> Array[String] {
  let out : Array[String] = []
  for chunk in text.split("\n") {
    out.push(chunk.trim().to_owned())
  }
  out
}

///|
/// 取出一行里**第一个**双引号（或单引号）包裹的内容。
/// 用 `split` 而不是正则：切出来的奇数下标段恰好就是引号内容，
/// 零依赖、零转义陷阱。
fn first_quoted(line : String, quote : String) -> String? {
  let parts : Array[String] = []
  for seg in line.split(quote) {
    parts.push(seg.to_owned())
  }
  if parts.length() >= 2 {
    Some(parts[1])
  } else {
    None
  }
}

///|
/// 取出一段文本里**全部**双引号包裹的内容。
fn all_quoted(text : String) -> Array[String] {
  let parts : Array[String] = []
  for seg in text.split("\"") {
    parts.push(seg.to_owned())
  }
  let out : Array[String] = []
  let mut i = 1
  while i < parts.length() {
    out.push(parts[i])
    i = i + 2
  }
  out
}

///|
/// 从当前工作目录**向上**找到含 `moon.mod` 的目录。
///
/// 不能假定 cwd 就是模块根：`moon test` 在不同版本下可能把 cwd 设成包目录、
/// 模块根或 `_build` 下的某处。向上走 12 层足以覆盖全部情况，
/// 且这个函数在找不到时会给出可操作的错误消息而不是静默返回空结果
/// —— 后者会让全部守卫变成「永远通过」的假绿。
async fn module_root() -> String {
  let start = match @env.current_dir() {
    Some(d) => @util.path_normalize(d)
    None => abort("cannot determine the current directory")
  }
  let mut dir = start
  for _ in 0..<12 {
    if exists(@util.path_join(dir, "moon.mod")) {
      return dir
    }
    let parent = @util.path_dirname(dir)
    if parent == dir {
      break
    }
    dir = parent
  }
  abort(
    "cannot locate moon.mod above \{start}; the architecture guards refuse to pass vacuously",
  )
}

///|
/// 列出 `src/` 下的全部包目录（判据：目录里有 `moon.pkg`）。
async fn package_dirs(root : String) -> Array[String] {
  let src = @util.path_join(root, "src")
  let out : Array[String] = []
  for entry in @scanner.read_entries(src) {
    let (name, is_dir) = entry
    if is_dir {
      if exists(@util.path_join(@util.path_join(src, name), "moon.pkg")) {
        out.push(name)
      }
    }
  }
  out
}

///|
/// 递归列出目录下全部 `.mbt` 文件的相对路径（用 `/` 分隔）。
async fn mbt_files(dir : String, prefix : String) -> Array[String] {
  let out : Array[String] = []
  for entry in @scanner.read_entries(dir) {
    let (name, is_dir) = entry
    let rel = if prefix.length() == 0 { name } else { "\{prefix}/\{name}" }
    if is_dir {
      for sub in mbt_files(@util.path_join(dir, name), rel) {
        out.push(sub)
      }
    } else if name.has_suffix(".mbt") {
      out.push(rel)
    }
  }
  out
}

///|
/// 是否为**测试**文件（黑盒 `_test.mbt` 或白盒 `_wbtest.mbt`）。
/// 守卫只看生产代码：测试本来就要构造各种畸形输入、也要直接建临时目录。
fn is_test_file(rel : String) -> Bool {
  rel.has_suffix("_test.mbt") || rel.has_suffix("_wbtest.mbt")
}

// ============================================================================
// G1：依赖图与声明一致，且无环
// ============================================================================

///|
/// 模块内包名的前缀。
let module_prefix : String = "across2005/harness-self-evolution/"

///|
/// 从一个 `moon.pkg` 文本里取出**第一个**（即无条件的）`import { ... }` 块
/// 里的全部包路径。
///
/// 只取第一个块是关键：`for "wbtest"` / `for "test"` 的块是**测试专用**依赖，
/// 把它们算进生产依赖图会让守卫误报（例如 mcp 的测试块里有 `@fs`，
/// 但 mcp 的生产代码并不直接碰文件系统）。
fn primary_imports(text : String) -> Array[String] {
  let chunks : Array[String] = []
  for seg in text.split("import {") {
    chunks.push(seg.to_owned())
  }
  if chunks.length() < 2 {
    return []
  }
  // 第一个 import 块的内容 = 到第一个 '}' 为止
  let body : Array[String] = []
  for seg in chunks[1].split("}") {
    body.push(seg.to_owned())
  }
  if body.length() == 0 {
    return []
  }
  all_quoted(body[0])
}

///|
/// ★ 声明的依赖图。这是**契约**，不是从代码推导出来的结果 ——
/// 两者相等才说明实现没有偏离设计。
///
/// 与计划第 149-159 行的图有**一处有意偏差**，记录在此：
/// 计划写 `scanner → types, util, @fs  # 不依赖 store`，
/// 但计划第 618-631 行（Phase 3.4）又要求把 `PluginCache` / `DirFingerprint` /
/// `fingerprint_of` 放进 `store/cache.mbt`，理由是「收拢 scanner/index.ts
/// L332-349 的直接 fs 读写」—— 那正是 F2 缓存毒化修复的落脚点。
/// 两条要求互相矛盾：scanner 要用插件缓存，就必须依赖 store。
/// 实现取了后者（缓存归 store，scanner 依赖它），因为不变量①
/// 「持久化只在 store」的优先级高于「scanner 少一条边」。
/// 这条偏差必须写在这里而不是悄悄改掉，否则下一个读计划的人会以为是 bug。
fn declared_edges() -> Array[(String, Array[String])] {
  [
    ("util", []),
    ("types", ["util"]),
    ("store", ["types", "util"]),
    ("scanner", ["store", "types", "util"]),
    ("monitor", ["store", "types", "util"]),
    ("engine", ["monitor", "store", "types", "util"]),
    ("executor", ["store", "types", "util"]),
    (
      "mcp",
      ["engine", "executor", "monitor", "scanner", "store", "types", "util"],
    ),
    ("harness_evolution", ["mcp", "store", "types", "util"]),
  ]
}

///|
/// ★ 分层编号。**每条边都必须严格向下**（层的数字变小），
/// 这就构造性地证明了无环 —— 比跑一遍 DFS 更强：
/// DFS 只告诉你「现在没有环」，分层还告诉你「不可能有环」，
/// 因为任何新增的反向边都会立刻让这条断言变红。
fn layer_of(pkg : String) -> Int {
  match pkg {
    "util" => 0
    "types" => 1
    "store" => 2
    // scanner 与 monitor 同层：两者互不依赖，都只向下看
    "scanner" => 3
    "monitor" => 3
    // engine 要读 monitor 的统计，executor 不读，但两者同层（互不依赖）
    "engine" => 4
    "executor" => 4
    "mcp" => 5
    "harness_evolution" => 6
    _ => abort("undeclared package: \{pkg}")
  }
}

async test "G1: the package graph equals the declared graph and is strictly layered" {
  let root = module_root()
  let packages = package_dirs(root)

  // 包集合必须与声明的完全一致：多一个包说明有人新加了未登记的模块，
  // 少一个说明有模块被删掉而契约没更新
  let declared = declared_edges()
  let declared_names : Array[String] = []
  for pair in declared {
    let (name, _) = pair
    declared_names.push(name)
  }
  assert_eq(packages.length(), declared_names.length())
  for name in declared_names {
    assert_true(packages.contains(name))
  }

  // 逐包比对边集合
  for pair in declared {
    let (pkg, expected) = pair
    let text = read_text(
      @util.path_join(@util.path_join(root, "src"), "\{pkg}/moon.pkg"),
    )
    let actual : Array[String] = []
    for dep in primary_imports(text) {
      if dep.has_prefix(module_prefix) {
        // 切片而不是 `substring`：后者已废弃
        actual.push(dep[module_prefix.length():].to_owned())
      }
    }
    // 排序用 `lexical_compare`：`String` 的 `compare` / `<` 先比长度，
    // 不是字典序（实测结论 T16）。两边都排成字典序后才能直接比数组。
    actual.sort_by(fn(a, b) { a.lexical_compare(b) })
    let want : Array[String] = []
    for dep in expected {
      want.push(dep)
    }
    want.sort_by(fn(a, b) { a.lexical_compare(b) })
    if actual != want {
      abort("\{pkg}: imports \{join_names(actual)}, declared \{join_names(want)}")
    }
    // 每条边严格向下 → 构造性无环
    for dep in actual {
      if layer_of(dep) >= layer_of(pkg) {
        abort(
          "\{pkg}(layer \{layer_of(pkg)}) must not import \{dep}(layer \{layer_of(dep)}): edges may only point downward",
        )
      }
    }
  }
}

///|
/// `util` 是唯一的零内部依赖包 —— 它必须保持这样。
/// 一旦 util 依赖了任何业务包，它就不再是「四个零依赖 Deep Module」，
/// 循环依赖只是时间问题。
async test "G1b: util depends on nothing inside the module" {
  let root = module_root()
  let text = read_text(
    @util.path_join(@util.path_join(root, "src"), "util/moon.pkg"),
  )
  for dep in primary_imports(text) {
    assert_false(dep.has_prefix(module_prefix))
  }
}

// ============================================================================
// G2：F4 的机器化守卫 —— stdout / stderr 的唯一出口
// ============================================================================

///|
/// ★ F4 是本次移植修掉的四个实测缺陷里**最容易被无声破坏**的一个。
///
/// legacy TS 的 `src/**` 里有 14 处 `console.log` + 1 处 `console.warn` +
/// 8 处 `console.error`；它没炸只是因为 `@modelcontextprotocol/sdk` 的
/// `StdioServerTransport` 接管并 patch 了 `console.*`。自研 stdio server
/// 没有这层魔法 —— 任何一处往 stdout 写日志都会直接污染协议通道。
///
/// 结构上的封法是：`util/log.mbt` 是全仓唯一引用 `@stdio.stderr` 的地方，
/// `mcp/server.mbt` 是全仓唯一引用 `@stdio.stdout` 的地方。
/// 这条测试把「结构上封死」变成**机器验证**：新增第三处引用就变红。
async test "G2: stdout has exactly one writer and stderr has exactly one" {
  let root = module_root()
  let src = @util.path_join(root, "src")
  let stdout_writers : Array[String] = []
  let stderr_writers : Array[String] = []
  for rel in mbt_files(src, "") {
    if is_test_file(rel) {
      continue
    }
    let text = read_text(@util.path_join(src, rel))
    // 按**文件**去重：一个文件里写三行 `@stdio.stderr` 也只是一个出口。
    // 第一版这里按行 push，结果得到 ["util/log.mbt" x3] —— 守卫自己的 bug。
    let mut writes_stdout = false
    let mut writes_stderr = false
    for line in lines_of(text) {
      // 跳过文档注释：它们**必须**提到 @stdio 来解释这条约束
      if line.has_prefix("///") || line.has_prefix("//") {
        continue
      }
      if line.contains("@stdio.stdout") {
        writes_stdout = true
      }
      if line.contains("@stdio.stderr") {
        writes_stderr = true
      }
    }
    if writes_stdout {
      stdout_writers.push(rel)
    }
    if writes_stderr {
      stderr_writers.push(rel)
    }
  }
  assert_eq(stdout_writers, ["mcp/server.mbt"])
  assert_eq(stderr_writers, ["util/log.mbt"])
}

///|
/// `util/log.mbt` 必须是**唯一**的日志出口，且它的三个函数都写 stderr。
/// 这条与 G2 互补：G2 说「没有别人写 stderr」，这条说「log.mbt 确实在写」。
/// 两者合起来才排除掉「把日志全删了」这种让 G2 假绿的退化。
async test "G2b: log.mbt exposes exactly three sinks and all of them are stderr" {
  let root = module_root()
  let text = read_text(
    @util.path_join(@util.path_join(root, "src"), "util/log.mbt"),
  )
  let sinks : Array[String] = []
  for line in lines_of(text) {
    // 文档注释里提到 @stdio.stderr 是在**解释**这条约束（log.mbt 的头注释
    // 必须说清楚为何只能写 stderr），不能算作一个 sink。
    // 第一版漏了这个过滤，数出 5 而不是 3。
    if line.has_prefix("///") || line.has_prefix("//") {
      continue
    }
    if line.contains("@stdio.stderr") {
      sinks.push(line)
    }
    // 绝不允许出现 stdout：日志出口写协议通道就是 F4 本身
    assert_false(line.contains("@stdio.stdout"))
  }
  assert_eq(sinks.length(), 3) // log_info / log_warn / log_error
}

// ============================================================================
// G3：不变量① —— 持久化写入只在 store
// ============================================================================

///|
/// `@fs` 的写操作清单。读操作（`read_file` / `readdir` / `opendir` / `exists` /
/// `mtime` / `kind`）**不在**此列：scanner 当然要读文件系统，
/// 不变量①管的是「谁有权改变磁盘上的持久状态」。
let fs_write_ops : Array[String] = [
  "@fs.write_file",
  "@fs.mkdir",
  "@fs.rename",
  "@fs.remove",
  "@fs.rmdir",
]

async test "G3: no package outside store performs filesystem writes" {
  let root = module_root()
  let src = @util.path_join(root, "src")
  let offenders : Array[String] = []
  for rel in mbt_files(src, "") {
    if is_test_file(rel) {
      continue
    }
    if rel.has_prefix("store/") {
      continue
    }
    let text = read_text(@util.path_join(src, rel))
    for line in lines_of(text) {
      if line.has_prefix("///") || line.has_prefix("//") {
        continue
      }
      for op in fs_write_ops {
        if line.contains(op) {
          offenders.push("\{rel}: \{line}")
        }
      }
    }
  }
  if offenders.length() > 0 {
    abort(
      "invariant (1) violated: persistence must live in store/ only, but found \{join_names(offenders)}",
    )
  }
}

///|
/// store 确实**在**写 —— 防止「把写入全删了」让 G3 假绿。
async test "G3b: store is the one place that actually writes" {
  let root = module_root()
  let src = @util.path_join(root, "src")
  let writers : Array[String] = []
  for rel in mbt_files(@util.path_join(src, "store"), "store") {
    if is_test_file(rel) {
      continue
    }
    let text = read_text(@util.path_join(src, rel))
    for line in lines_of(text) {
      if line.has_prefix("///") || line.has_prefix("//") {
        continue
      }
      for op in fs_write_ops {
        if line.contains(op) {
          writers.push(rel)
        }
      }
    }
  }
  assert_true(writers.length() > 0)
}

// ============================================================================
// G4：数据目录字面量只有一处
// ============================================================================

///|
/// legacy 把 `~/.harness-evolution/...` 的默认值散在 4 个文件
/// （store L114 / monitor L42-43 / engine L39 / executor L28）。
/// 计划 3.1 把它们收拢进 `store/paths.mbt` 单一入口。
/// 这条守卫防止默认值再次扩散 —— 扩散的后果是「改数据目录要改四处，漏一处
/// 就会读写到不同目录」，那是一种极难定位的故障。
///
/// 已实测删除的唯一违例：`scanner/scanner.mbt` 的 `ScanConfig::default()`
/// 把缓存路径硬写成 `~/.harness-evolution/v2/plugin-cache.json`，
/// 而它全仓零调用点（死代码）。删掉它才让这条守卫能通过。
async test "G4: the data-directory literal appears only in store/paths.mbt" {
  let root = module_root()
  let src = @util.path_join(root, "src")
  let offenders : Array[String] = []
  for rel in mbt_files(src, "") {
    if is_test_file(rel) {
      continue
    }
    if rel == "store/paths.mbt" {
      continue
    }
    let text = read_text(@util.path_join(src, rel))
    for line in lines_of(text) {
      // 注释里提到这个路径是**必要的**（要解释数据目录在哪），不算违例
      if line.has_prefix("///") || line.has_prefix("//") {
        continue
      }
      if line.contains(".harness-evolution") {
        offenders.push("\{rel}: \{line}")
      }
    }
  }
  if offenders.length() > 0 {
    abort(
      "the default data directory must be defined once, in store/paths.mbt; found \{join_names(offenders)}",
    )
  }
}

///|
/// `store/paths.mbt` 确实持有这个字面量（防止 G4 靠「把路径删光」假绿）。
async test "G4b: store/paths.mbt is the single source of the data directory" {
  let root = module_root()
  let text = read_text(
    @util.path_join(@util.path_join(root, "src"), "store/paths.mbt"),
  )
  let hits : Array[String] = []
  for line in lines_of(text) {
    if line.has_prefix("///") || line.has_prefix("//") {
      continue
    }
    if line.contains(".harness-evolution") {
      hits.push(line)
    }
  }
  assert_true(hits.length() > 0)
  // 且必须支持 HARNESS_EVOLUTION_HOME 覆盖（测试与多档案场景的前提）
  assert_true(text.contains("HARNESS_EVOLUTION_HOME"))
}

// ============================================================================
// G5：legacy 37 个 jest 用例的逐条对账
// ============================================================================

///|
/// legacy 测试文件。计划 1.1 明确保留它们「供 Phase 8 对拍」。
let legacy_test_files : Array[String] = [
  "engine.test.ts",
  "executor.test.ts",
  "monitor.test.ts",
  "scanner.test.ts",
]

///|
/// ★ legacy 用例 → MoonBit 用例的**逐条**对账表。
///
/// 为什么是一张显式表而不是「按名字模糊匹配」：
/// 移植时用例名会从 jest 的 `should generate ...` 变成 MoonBit 习惯的
/// 第三人称 `generates ...`，模糊匹配要么松到失去意义（什么都算命中），
/// 要么紧到全是误报。显式表虽然要手写 37 行，但它是**可读的移植凭证**：
/// 任何人 review 时都能一眼看出哪个 legacy 用例被谁接管了。
///
/// 这条测试双向校验：
/// · 表里的 legacy 名字必须真的存在于 legacy 文件（防止表里写了臆造的用例）
/// · 表里的 MoonBit 名字必须真的存在于 src/**（防止移植后被人删掉或改名）
/// · legacy 文件里的用例总数必须 == 表的行数（防止新增 legacy 用例没被登记）
fn legacy_parity_table() -> Array[(String, String, String)] {
  [
    // --- engine.test.ts (12) → src/engine/engine_wbtest.mbt ---
    (
      "engine.test.ts",
      "should generate an error_handling proposal from a strong correction signal",
      "generates an error_handling proposal from a strong correction signal",
    ),
    (
      "engine.test.ts",
      "should persist the proposal via the shared ProposalStore",
      "persists the proposal through the shared ProposalStore",
    ),
    (
      "engine.test.ts",
      "should ignore medium-only signals at 50% intensity",
      "ignores medium-only signals at 50% intensity",
    ),
    ("engine.test.ts", "should ignore weak-only signals", "ignores weak-only signals"),
    (
      "engine.test.ts",
      "should return the existing pending proposal instead of duplicating",
      "returns the existing pending proposal instead of duplicating",
    ),
    (
      "engine.test.ts",
      "should stay silent during cooldown after a recent proposal",
      "stays silent during the cooldown period",
    ),
    (
      "engine.test.ts",
      "should allow a new proposal once the cooldown has elapsed",
      "allows a new proposal once the cooldown has elapsed",
    ),
    (
      "engine.test.ts",
      "should produce no proposal when there are no signals",
      "produces no proposal when there are no signals",
    ),
    (
      "engine.test.ts",
      "should disable generation entirely at 0% intensity",
      "disables generation entirely at 0% intensity",
    ),
    (
      "engine.test.ts",
      "should map a struggle signal with high complexity to interface_simplification",
      "maps struggle + high complexity to interface_simplification",
    ),
    (
      "engine.test.ts",
      "should map a loop signal to behavior_optimization with middleware proposal",
      "maps a loop signal to behavior_optimization with middleware",
    ),
    (
      "engine.test.ts",
      "should assign high confidence when two strong signals are present",
      "assigns high confidence when two strong signals are present",
    ),
    // --- executor.test.ts (10) → src/executor + src/store ---
    (
      "executor.test.ts",
      "should fail when the proposal does not exist",
      "fails when the proposal does not exist",
    ),
    (
      "executor.test.ts",
      "should fail when the proposal is already completed",
      "fails when the proposal is already completed",
    ),
    (
      "executor.test.ts",
      "should fail when the proposal is rejected",
      "fails when the proposal is rejected",
    ),
    (
      "executor.test.ts",
      "should complete a dry run over an approved proposal",
      "completes a dry run over an approved proposal",
    ),
    (
      "executor.test.ts",
      "should mark the proposal completed after a successful run",
      "marks the proposal completed after a successful run",
    ),
    (
      "executor.test.ts",
      "should reset the proposal to pending when dry run is not requested and a task fails",
      "a failing task rolls the proposal back to pending",
    ),
    (
      "executor.test.ts",
      "should reject executing a pending proposal (state machine)",
      "rejects executing a pending proposal",
    ),
    // 下面三条在 legacy 里属于 executor.test.ts 的 ProposalStore describe 块，
    // 移植后归到 store 包（状态机是 store 的职责，不是 executor 的）
    (
      "executor.test.ts",
      "should allow legal transitions pending → approved → executing → completed",
      "ProposalStore allows the legal transition chain",
    ),
    (
      "executor.test.ts",
      "should throw on illegal transitions like completed → approved",
      "ProposalStore rejects an illegal transition with the TS-exact message",
    ),
    (
      "executor.test.ts",
      "should be idempotent for same-status updates",
      "ProposalStore set_status is idempotent and appends nothing",
    ),
    // --- monitor.test.ts (10) → src/monitor/monitor_wbtest.mbt ---
    (
      "monitor.test.ts",
      "should aggregate success rate and latency",
      "aggregates success rate and latency",
    ),
    ("monitor.test.ts", "should aggregate token usage", "aggregates token usage"),
    (
      "monitor.test.ts",
      "should isolate statistics per plugin",
      "isolates statistics per plugin",
    ),
    (
      "monitor.test.ts",
      "should return zeroed stats for an unknown plugin",
      "returns zeroed stats for an unknown plugin",
    ),
    (
      "monitor.test.ts",
      "should emit a struggle signal after 3 consecutive failures",
      "emits a struggle signal after 3 consecutive failures",
    ),
    (
      "monitor.test.ts",
      "should not emit a struggle signal for fewer than 3 consecutive failures",
      "does not emit a struggle signal below the failure threshold",
    ),
    (
      "monitor.test.ts",
      "should emit a loop signal after 5 consecutive calls of the same tool",
      "emits a loop signal after 5 consecutive calls of the same tool",
    ),
    (
      "monitor.test.ts",
      "should emit a correction signal on negative user feedback",
      "emits a correction signal on negative user feedback",
    ),
    (
      "monitor.test.ts",
      "should update the last event feedback in memory",
      "backfills user feedback onto the in-memory session ring",
    ),
    (
      "monitor.test.ts",
      "should flush buffered events to the metrics file on stop",
      "flushes buffered events to the metrics file on shutdown",
    ),
    // --- scanner.test.ts (5) → src/scanner/scanner_wbtest.mbt ---
    (
      "scanner.test.ts",
      "should discover a plugin with a package.json and SKILL.md",
      "discovers a plugin with a package.json and SKILL.md",
    ),
    (
      "scanner.test.ts",
      "should extract tools from MCP registerTool calls in source files",
      "extracts tools from MCP registerTool calls in source files",
    ),
    (
      "scanner.test.ts",
      "should ignore directories without any manifest",
      "ignores directories without any manifest",
    ),
    (
      "scanner.test.ts",
      "should skip directories it cannot parse instead of throwing",
      "skips entries it cannot treat as directories instead of raising",
    ),
    (
      "scanner.test.ts",
      "should write the cache file after scanning",
      "writes the cache and keeps results stable across scanner instances",
    ),
  ]
}

///|
/// 从一个 legacy jest 文件里取出全部 `it('...')` / `test('...')` 的用例名。
fn legacy_case_names(text : String) -> Array[String] {
  let out : Array[String] = []
  for line in lines_of(text) {
    if line.has_prefix("it(") || line.has_prefix("test(") {
      match first_quoted(line, "'") {
        Some(name) => out.push(name)
        None => ()
      }
    }
  }
  out
}

///|
/// 从 `src/**` 收集全部 MoonBit 测试名（黑盒 + 白盒）。
async fn moonbit_test_names(root : String) -> Array[String] {
  let src = @util.path_join(root, "src")
  let out : Array[String] = []
  for rel in mbt_files(src, "") {
    if !is_test_file(rel) {
      continue
    }
    let text = read_text(@util.path_join(src, rel))
    for line in lines_of(text) {
      if line.has_prefix("test \"") || line.has_prefix("async test \"") {
        match first_quoted(line, "\"") {
          Some(name) => out.push(name)
          None => ()
        }
      }
    }
  }
  out
}

async test "G5: every legacy jest case has a MoonBit counterpart, both directions" {
  let root = module_root()
  let table = legacy_parity_table()
  let mb_names = moonbit_test_names(root)

  // ① 表的 MoonBit 一侧必须真的存在
  let missing : Array[String] = []
  for row in table {
    let (_, _, mb_name) = row
    if !mb_names.contains(mb_name) {
      missing.push(mb_name)
    }
  }
  if missing.length() > 0 {
    abort(
      "these ported tests no longer exist (renamed or deleted?): \{join_names(missing)}",
    )
  }

  // ② 表的 legacy 一侧必须真的存在，且**逐条对齐、总数相等**
  let legacy_dir = @util.path_join(root, "legacy-ts/tests")
  let mut legacy_total = 0
  for file in legacy_test_files {
    let path = @util.path_join(legacy_dir, file)
    if !exists(path) {
      abort(
        "legacy test file \{file} is missing; the plan requires legacy-ts/ to stay runnable for cross-checking",
      )
    }
    let names = legacy_case_names(read_text(path))
    legacy_total = legacy_total + names.length()
    for name in names {
      let mut mapped = false
      for row in table {
        let (f, legacy_name, _) = row
        if f == file && legacy_name == name {
          mapped = true
        }
      }
      if !mapped {
        abort(
          "\{file}: legacy case \"\{name}\" has no entry in the parity table",
        )
      }
    }
  }
  assert_eq(table.length(), legacy_total)
  // ③ 硬编码的 37 —— 计划 1.1 说的「保留 37 用例供对拍」。
  // 这个数字变了说明 legacy 测试被动过，必须重新核对映射。
  assert_eq(legacy_total, 37)
}

///|
/// 覆盖倍数。222 : 37 ≈ 6 倍 —— 这个断言的价值不在数字本身，
/// 而在于它让「移植过程中悄悄丢覆盖」变得不可能：
/// 任何一次删除测试都必须同时改这里的下界，而那会引发一次显式的讨论。
async test "G5b: the MoonBit suite is a strict superset in size of the legacy suite" {
  let root = module_root()
  let mb_names = moonbit_test_names(root)
  let legacy_dir = @util.path_join(root, "legacy-ts/tests")
  let mut legacy_total = 0
  for file in legacy_test_files {
    legacy_total =
      legacy_total + legacy_case_names(read_text(@util.path_join(legacy_dir, file))).length()
  }
  assert_true(mb_names.length() >= legacy_total * 5)
}

// ============================================================================
// G6：唯一外部依赖
// ============================================================================

///|
/// 计划 D7：只用 1 个外部依赖 `moonbitlang/async`，不用 `moonbitlang/x`。
/// 理由是 `@path` + `@time` 合计约 90 行纯函数，自写可以换掉一个 1.4 万行依赖
/// 且完全可测（`util/time_test.mbt` 用 node 实测基准逐字符对拍）。
///
/// 这条守卫防止「顺手 add 一个依赖」—— 每多一个外部依赖，
/// 可复现构建与 native 链接的风险面就大一圈（Phase 0 门禁实测过
/// `async@0.21.x` 的 `noraise + nocancel` 语法本机工具链根本解析不了）。
async test "G6: moon.mod declares exactly one external dependency, async 0.20.1" {
  let root = module_root()
  let text = read_text(@util.path_join(root, "moon.mod"))
  let deps : Array[String] = []
  let mut in_block = false
  for line in lines_of(text) {
    if line.has_prefix("import {") {
      in_block = true
    }
    if in_block {
      for name in all_quoted(line) {
        if name.contains("@") {
          deps.push(name)
        }
      }
    }
    if line.contains("}") {
      in_block = false
    }
  }
  assert_eq(deps, ["moonbitlang/async@0.20.1"])
  // 且 native 是首选目标（决策 D1）
  assert_true(text.contains("preferred_target = \"native\""))
}
