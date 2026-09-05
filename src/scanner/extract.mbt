///|
/// 从 SKILL.md 与源码文本里抽取 capabilities / tools —— **纯函数，不碰文件系统**。
/// 取代 legacy-ts/src/scanner/index.ts L189-227（`parseSkillFile`）与
/// L232-263（`scanMCPTools`）里的解析部分。
///
/// 把解析从 I/O 里剥出来有两个直接收益：
/// 1. 9 条正则可以在**不建任何临时目录**的前提下逐条断言，
///    TS 版做不到（正则埋在 `fs.readFile` 之后）。
/// 2. 正则对象只在模块加载时编译一次。TS 版在 `parseSkillFile` /
///    `scanMCPTools` 里**每次调用、每个文件**都重新构造 7 个 `RegExp`
///    （L197-202、L243-247），对大插件树是纯浪费。
///
/// **9 条模式的移植规则**（TS 实为 9 条，不是 8 条）：
/// · `\s` → 显式 `[ \t\n\r]`，`\w` → 显式 `[A-Za-z0-9_]`。
///   JS 无 `u` flag 时 `\w` 就是 ASCII；MoonBit 的 `[[:word:]]` 按 core 文档
///   也是 ASCII-based（Phase 0 探针 P1 实测 `ascii_hits=0 posix_hits=0`，
///   两者对中文文本都是零命中），但显式 ASCII 类零成本消除歧义，
///   且让双跑对拍时的差异归因唯一。
/// · `i` flag → `(?i: ... )` 包裹（MoonBit 的 Regex 没有 flag 参数）。
/// · `g` flag → `Regex::find` 天然返回全部命中的惰性迭代器。
/// · TS 第 6 条 `/\.(ts|js|mjs)$/` **不再是正则**：改用 `@util.path_extname`
///   做后缀判断。MoonBit 的 `$` 是**整串锚点**而非多行锚点，
///   虽然对裸文件名恰好等价，但后缀判断更快也更直白。
/// · **R7/R8/R9 保持大小写敏感**（TS 原本就没有 `i` flag），不得「顺手」加 `(?i:)`。

///|
/// 抽取结果。`capabilities` 已转小写（对齐 TS L208），`tools` **未**转小写（对齐 TS L218）。
pub struct Extracted {
  capabilities : Array[String]
  tools : Array[String]
}

// R1-R4：SKILL.md 里的能力描述模式。四条独立保留而非合并成一条，
// 因为 TS L204-211 是「模式在外层循环、命中在内层循环」，
// 合并会改变 capabilities 数组的元素顺序。

///|
let re_can : @string.Regex = @string.Regex::unsafe_from_string(
  "(?i:can[ \t\n\r]+([A-Za-z0-9_]+))",
)

///|
let re_supports : @string.Regex = @string.Regex::unsafe_from_string(
  "(?i:supports?[ \t\n\r]+([A-Za-z0-9_]+))",
)

///|
let re_provides : @string.Regex = @string.Regex::unsafe_from_string(
  "(?i:provides?[ \t\n\r]+([A-Za-z0-9_]+))",
)

///|
let re_handles : @string.Regex = @string.Regex::unsafe_from_string(
  "(?i:handles?[ \t\n\r]+([A-Za-z0-9_]+))",
)

// R5：SKILL.md 里的 tool=xxx / tool:xxx 引用

///|
let re_tool_ref : @string.Regex = @string.Regex::unsafe_from_string(
  "(?i:tool[=:][ \t\n\r]*['\"`]?([A-Za-z0-9_]+)['\"`]?)",
)

// R7-R9：源码里的 MCP 工具注册。大小写敏感。

///|
let re_register_tool : @string.Regex = @string.Regex::unsafe_from_string(
  "registerTool[ \t\n\r]*\\([ \t\n\r]*['\"`]([^'\"`]+)['\"`]",
)

///|
let re_dot_tool : @string.Regex = @string.Regex::unsafe_from_string(
  "\\.tool[ \t\n\r]*\\([ \t\n\r]*['\"`]([^'\"`]+)['\"`]",
)

///|
let re_name_field : @string.Regex = @string.Regex::unsafe_from_string(
  "name:[ \t\n\r]*['\"`]([^'\"`]+)['\"`]",
)

///|
/// 取出全部命中的第 1 捕获组。
///
/// `MatchResult::group` 返回 `StringView`（借用源串），必须**立即 `.to_owned()`**
/// 再放进结果数组，否则源串离开作用域后就是悬垂借用。
///
/// 空捕获跳过（对齐 TS L207/L217 的 `if (match[1])` —— JS 把空串当 falsy）。
/// 本文件的 9 条模式捕获组全用 `+`（至少 1 字符），理论上不会产生空捕获，
/// 但保留这道判断，以防将来有人把某条改成 `*`。
fn capture1(re : @string.Regex, text : String) -> Array[String] {
  let out : Array[String] = []
  for m in @string.Regex::find(re, text) {
    match m.group(1) {
      Some(g) => if g.length() > 0 { out.push(g.to_owned()) }
      None => ()
    }
  }
  out
}

///|
/// 从 SKILL.md 全文抽取 capabilities 与 tools。
/// 取代 legacy-ts scanner L189-227。
///
/// **顺序契约**：TS 是「4 条能力模式依次全文扫描，各自把命中 push 进同一个数组」，
/// 所以 capabilities 的顺序是 R1 的全部命中 → R2 的全部命中 → R3 → R4。
/// 这里逐条照搬，不做「合并成一条正则」的优化 —— 那会改变顺序。
///
/// **不去重**：TS 在此处不去重（去重发生在 L140-142 存进 metadata 时），
/// 而 L132 把**未去重**的数组传给了 `calculateMetrics`，
/// 重复项会抬高 L304 的 `capabilityComplexity`。
/// 「顺手去重」会静默改变 `complexity_score`，进而翻转 engine L196 的 `> 7` 判定。
pub fn extract_from_skill_text(text : String) -> Extracted {
  let capabilities : Array[String] = []
  // R1-R4：能力模式。顺序即 TS L197-202 数组的顺序。
  for re in [re_can, re_supports, re_provides, re_handles] {
    for cap in capture1(re, text) {
      capabilities.push(cap.to_lower()) // 对齐 TS L208 的 toLowerCase()
    }
  }
  // R5：工具引用。**不**转小写（对齐 TS L218）
  let tools = capture1(re_tool_ref, text)
  { capabilities, tools }
}

///|
/// 从源码全文抽取 MCP 工具名，追加进 `into`。
/// 取代 legacy-ts scanner L239-257。
///
/// 保留 TS L252 的 `$` 过滤：`registerTool(\`${prefix}_scan\`)` 这类
/// 模板串占位符不是真实工具名，必须排除。
///
/// **顺序契约**：TS 是「每条模式依次全文扫描」（L249-256 的模式外层循环），
/// 故顺序为 R7 的全部命中 → R8 → R9。
pub fn extract_tools_from_source_text(
  text : String,
  into : Array[String],
) -> Unit {
  for re in [re_register_tool, re_dot_tool, re_name_field] {
    for name in capture1(re, text) {
      // 对齐 TS L252：`if (match[1] && !match[1].includes('$'))`
      if !name.contains("$") {
        into.push(name)
      }
    }
  }
}

///|
/// 该文件名是否是待扫描的源码文件。
/// 取代 legacy-ts scanner L237 的 `/\.(ts|js|mjs)$/` + L279 的 `pattern.test(entry.name)`。
pub fn is_source_file(name : String) -> Bool {
  match @util.path_extname(name) {
    ".ts" => true
    ".js" => true
    ".mjs" => true
    _ => false
  }
}
