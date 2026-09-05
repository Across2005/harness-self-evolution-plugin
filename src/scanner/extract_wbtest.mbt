///|
/// 9 条正则的逐条断言 —— **纯文本，无需文件系统**。
///
/// 每个期望值都由 legacy-ts/src/scanner/index.ts L197-202、L214、L243-247 的
/// **原始 RegExp** 在 node 里对同一份 fixture 跑出来，不是我推断的。
/// 这是必须的：正则语义差异是本移植里最隐蔽的风险源，
/// 而 TS 版把正则埋在 `fs.readFile` 之后，根本无法这样单独验证。
///
/// 其中两条基准值本身就是「不查就会写错」的例子：
/// · `tool = "type"` **不**被 R5 命中 —— `tool[=:]` 要求 `=` 紧跟 `tool`，
///   中间的空格让整条失配，故 tools 是 `[navigate, click, submit]` 而非四个。
/// · `all-four-patterns` 的输出顺序是 R1 的全部命中 → R2 的全部 → R3 → R4，
///   证实了「模式在外层循环、命中在内层循环」的顺序契约。
test "R1-R4: capability patterns on the legacy jest fixture" {
  // 逐字取自 legacy-ts/tests/scanner.test.ts L34
  let text = "# My Plugin\nThis tool can navigate and supports clicks."
  let extracted = extract_from_skill_text(text)
  json_inspect(extracted.capabilities, content=["navigate", "clicks"])
  // R5 不命中：这里的 "tool can" 后面不是 [=:]
  json_inspect(extracted.tools, content=[])
}

///|
test "R1-R4 are case-insensitive, and lower-case the capture" {
  let extracted = extract_from_skill_text("It CAN Navigate and Supports Clicks")
  json_inspect(extracted.capabilities, content=["navigate", "clicks"])
}

///|
/// ASCII 边界（决策 D8）：JS 无 `u` flag 时 `\w` == `[A-Za-z0-9_]`，
/// 故 `"can 扫描"` **不**命中。若这里用了 Unicode 感知的字符类，
/// capabilities 数量会变 → complexity_score 变 → engine L196 的 `> 7` 判定翻转。
test "R1 does not match CJK, exactly like JS \\w" {
  let extracted = extract_from_skill_text("This tool can 扫描 files")
  json_inspect(extracted.capabilities, content=[])
  json_inspect(extracted.tools, content=[])
}

///|
/// 顺序契约：R1 的全部命中 → R2 → R3 → R4（TS L204-211 的双层循环）。
/// 同时覆盖 `supports?` / `provides?` / `handles?` 的可选尾 s。
test "R1-R4 emit in pattern order, not in text order" {
  let text = "can a, supports b, support c, provides d, provide e, handles f, handle g"
  let extracted = extract_from_skill_text(text)
  json_inspect(extracted.capabilities, content=[
    "a", "b", "c", "d", "e", "f", "g",
  ])
}

///|
/// **不去重**契约：TS 在此处不去重，重复项会抬高 scanner L304 的
/// `capabilityComplexity`，从而改变 `complexity_score`。
/// 去重发生在存进 metadata 时（TS L140-142），不在这一步。
test "R1-R4 do not deduplicate (dedup happens later, in the metadata)" {
  let extracted = extract_from_skill_text("can x can x can x")
  json_inspect(extracted.capabilities, content=["x", "x", "x"])
}

///|
/// R5：`tool=xxx` / `tool: xxx` / `tool:'xxx'`。
/// 注意 `tool = "type"` **不**命中 —— `tool[=:]` 要求分隔符紧跟 `tool`。
/// 这条基准值最容易凭直觉写错，故由 node 跑原始正则确认。
test "R5 extracts tool references and keeps their case" {
  let text = "tool=navigate tool: click tool = \"type\" tool:'submit'"
  let extracted = extract_from_skill_text(text)
  json_inspect(extracted.capabilities, content=[])
  json_inspect(extracted.tools, content=["navigate", "click", "submit"])
}

///|
/// R5 的捕获**不**转小写（对齐 TS L218 —— 与 R1-R4 的 L208 相反）。
test "R5 preserves the original case of tool names" {
  let extracted = extract_from_skill_text("tool=GetMetrics")
  json_inspect(extracted.tools, content=["GetMetrics"])
}

///|
test "R7 extracts registerTool names from the legacy jest fixture" {
  // 逐字取自 legacy-ts/tests/scanner.test.ts L51-54
  let src = "\n  server.registerTool('scan_plugins', { description: 'scan' }, cb);\n  server.registerTool('propose_evolution', { description: 'propose' }, cb);\n"
  let tools : Array[String] = []
  extract_tools_from_source_text(src, tools)
  json_inspect(tools, content=["scan_plugins", "propose_evolution"])
}

///|
test "R8 extracts .tool() names with either quote style" {
  let src = "srv.tool(\"alpha\", h); srv.tool(`beta`, h);"
  let tools : Array[String] = []
  extract_tools_from_source_text(src, tools)
  json_inspect(tools, content=["alpha", "beta"])
}

///|
test "R9 extracts name: '...' fields" {
  let src = "const t = { name: 'gamma', h }; const u = { name: \"delta\" };"
  let tools : Array[String] = []
  extract_tools_from_source_text(src, tools)
  json_inspect(tools, content=["gamma", "delta"])
}

///|
/// TS L252 的 `$` 过滤：模板串占位符不是真实工具名。
test "R7 drops names containing a template placeholder" {
  let src = "server.registerTool(`${prefix}_scan`, h);"
  let tools : Array[String] = []
  extract_tools_from_source_text(src, tools)
  json_inspect(tools, content=[])
}

///|
/// R7/R8/R9 在 TS 里**没有** `i` flag，必须保持大小写敏感。
/// 「顺手」加 `(?i:)` 会把 `REGISTERTOOL` 之类的误报当成工具。
test "R7-R9 are case sensitive, unlike R1-R5" {
  let src = "server.REGISTERTOOL('nope', h); srv.TOOL('nope2', h);"
  let tools : Array[String] = []
  extract_tools_from_source_text(src, tools)
  json_inspect(tools, content=[])
}

///|
test "R7 accepts backtick-quoted names" {
  let src = "server.registerTool(`eps_tool`, h);"
  let tools : Array[String] = []
  extract_tools_from_source_text(src, tools)
  json_inspect(tools, content=["eps_tool"])
}

///|
/// 顺序契约：R7 的全部命中 → R8 → R9（TS L249-256 的模式外层循环）。
test "R7-R9 emit in pattern order across a mixed file" {
  let src = "a.tool('b1', h); server.registerTool('r1', h); const x = { name: 'n1' }; server.registerTool('r2', h);"
  let tools : Array[String] = []
  extract_tools_from_source_text(src, tools)
  // registerTool 的两个先出，然后 .tool 的，最后 name: 的
  json_inspect(tools, content=["r1", "r2", "b1", "n1"])
}

///|
/// 取代 TS L237 的 `/\.(ts|js|mjs)$/`（见 util/path.mbt 里为何不用正则）。
test "is_source_file accepts exactly .ts .js .mjs" {
  assert_eq(is_source_file("server.ts"), true)
  assert_eq(is_source_file("index.js"), true)
  assert_eq(is_source_file("cli.mjs"), true)
  assert_eq(is_source_file("server.TS"), true) // path_extname 会转小写
  assert_eq(is_source_file("README.md"), false)
  assert_eq(is_source_file("data.json"), false)
  assert_eq(is_source_file("noext"), false)
  assert_eq(is_source_file("archive.tsx"), false)
}
