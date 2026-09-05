///|
/// 路径工具的纯函数断言。全部无需文件系统。
/// 对应 legacy-ts/src/store/index.ts L13-19 的 `expandPath` 与 scanner 里的
/// `path.join` / `path.basename` / `path.dirname` 调用。
test "path_normalize unifies separators and collapses duplicates" {
  assert_eq(@util.path_normalize("C:\\Users\\x\\y"), "C:/Users/x/y")
  assert_eq(@util.path_normalize("a//b///c"), "a/b/c")
  assert_eq(@util.path_normalize("/a/b/"), "/a/b")
  assert_eq(@util.path_normalize(""), "")
  // UNC 前缀必须保留，否则 //server/share 会退化成 /server/share
  assert_eq(@util.path_normalize("\\\\server\\share"), "//server/share")
}

///|
test "path_join normalizes both sides" {
  assert_eq(@util.path_join("a", "b"), "a/b")
  assert_eq(@util.path_join("a/", "b"), "a/b")
  assert_eq(@util.path_join("a\\", "b"), "a/b")
  assert_eq(@util.path_join("", "b"), "b")
  assert_eq(@util.path_join("a", ""), "a")
  assert_eq(
    @util.path_join("C:\\Users\\x", ".harness-evolution"),
    "C:/Users/x/.harness-evolution",
  )
}

///|
test "path_dirname mirrors Node path.dirname for the cases we use" {
  assert_eq(@util.path_dirname("a/b/c"), "a/b")
  assert_eq(@util.path_dirname("a/b/c/"), "a/b")
  assert_eq(@util.path_dirname("c"), ".")
  assert_eq(@util.path_dirname("/c"), "/")
  assert_eq(@util.path_dirname("C:\\Users\\x\\y.jsonl"), "C:/Users/x")
}

///|
test "path_basename mirrors Node path.basename" {
  assert_eq(@util.path_basename("a/b/c.txt"), "c.txt")
  // 尾分隔符先被 trim_end 掉，故 "a/b/" 的 basename 是 "b"
  assert_eq(@util.path_basename("a/b/"), "b")
  assert_eq(@util.path_basename("c.txt"), "c.txt")
  assert_eq(
    @util.path_basename("C:\\Users\\x\\proposals.jsonl"),
    "proposals.jsonl",
  )
}

///|
test "path_extname replaces the scanner's /\\.(ts|js|mjs)$/ regex" {
  assert_eq(@util.path_extname("a/b/x.TS"), ".ts")
  assert_eq(@util.path_extname("x.mjs"), ".mjs")
  assert_eq(@util.path_extname("x"), "")
  // 点开头的文件没有扩展名（否则 ".gitignore" 会被当成扩展名 ".gitignore"）
  assert_eq(@util.path_extname(".gitignore"), "")
  assert_eq(@util.path_extname("a.b.c"), ".c")
}

///|
test "expand_home resolves ~ against HOME/USERPROFILE/cwd in that order" {
  let home = @util.home_dir()
  assert_true(home.length() > 0)
  assert_eq(@util.expand_home("~"), home)
  assert_eq(@util.expand_home("~/x"), @util.path_join(home, "x"))
  // Windows 风格的 ~\ 同样要展开（先归一化再判定）
  assert_eq(@util.expand_home("~\\x"), @util.path_join(home, "x"))
  assert_eq(
    @util.expand_home("~/.harness-evolution/v2/proposals.jsonl"),
    @util.path_join(home, ".harness-evolution/v2/proposals.jsonl"),
  )
  // 非 ~ 开头的路径原样归一化返回，不做展开
  assert_eq(@util.expand_home("a/b"), "a/b")
  assert_eq(@util.expand_home("C:\\x"), "C:/x")
  assert_eq(@util.expand_home("~x"), "~x")
}

///|
/// ★ **字符串排序语义陷阱（实测结论，非推测）。**
///
/// `core/builtin/string.mbt` L221 的 `impl Compare for String` 实现是：
/// ```moonbit nocheck
/// let len = self.length()
/// match len.compare(other.length()) {
///   0 => { /* 逐字符比较 */ }
///   // 长度不同 → 直接返回长度的比较结果
/// }
/// ```
/// 即 **`compare` / `<` / `>` / `sort_by(compare)` 全部是「先比长度」的序**，
/// 不是字典序。要字典序必须用 `String::lexical_compare`。
///
/// 本仓有三处依赖字典序：scanner 的目录遍历顺序（决定「同 plugin_id
/// 先到先得」的结果与 MCP 返回给 LLM 的插件顺序）、`read_manifest_meta`
/// 的 dependencies 排序。它们均使用 `lexical_compare`。
///
/// 本用例把两种语义同时钉死：若将来 core 修正了 `Compare for String`，
/// 这里会先失败，提醒重新审视那三处。
test "String compare is length-first; lexical_compare is lexicographic" {
  // compare：先比长度。"alpha"(5) vs "mid"(3) → 正数，而非字典序的负数
  assert_true("alpha".compare("mid") > 0)
  assert_true("mid".compare("zeta") < 0)
  assert_true("zeta".compare("alpha") < 0)
  // 等长时才逐字符比较
  assert_true("abc".compare("abd") < 0)
  assert_eq("same".compare("same"), 0)

  // 用 compare 排序会得到长度升序 —— 这就是曾经的 bug 形态
  let by_length = ["zeta", "alpha", "mid"]
  by_length.sort_by(fn(a, b) { a.compare(b) })
  json_inspect(by_length, content=["mid", "zeta", "alpha"])

  // lexical_compare 才是真正的字典序
  assert_true("alpha".lexical_compare("mid") < 0)
  assert_true("mid".lexical_compare("zeta") < 0)
  assert_true("a-file.txt".lexical_compare("alpha") < 0)
  assert_eq("same".lexical_compare("same"), 0)

  let lexicographic = ["zeta", "alpha", "mid"]
  lexicographic.sort_by(fn(a, b) { a.lexical_compare(b) })
  json_inspect(lexicographic, content=["alpha", "mid", "zeta"])

  // 元组数组按第一个分量字典序排（read_entries 的实际用法）
  let pairs : Array[(String, Bool)] = [
    ("zeta", true),
    ("a-file.txt", false),
    ("alpha", true),
    ("mid", true),
  ]
  pairs.sort_by(fn(a, b) { a.0.lexical_compare(b.0) })
  json_inspect(pairs.map(fn(p) { p.0 }), content=[
    "a-file.txt", "alpha", "mid", "zeta",
  ])
}

///|
test "path_depth_from counts segments below the root" {
  assert_eq(@util.path_depth_from("a", "a"), 0)
  assert_eq(@util.path_depth_from("a", "a/"), 0)
  assert_eq(@util.path_depth_from("a", "a/b"), 1)
  assert_eq(@util.path_depth_from("a", "a/b/c"), 2)
  assert_eq(@util.path_depth_from("a/", "a/b/c"), 2)
  assert_eq(@util.path_depth_from("a", "a/b/"), 1)
  // 不在 root 下 → -1，供 scanner 拒绝越界路径
  assert_eq(@util.path_depth_from("a", "z/b"), -1)
  // 段边界：兄弟目录 "ab" 不属于 "a" 的子树
  assert_eq(@util.path_depth_from("a", "ab/c"), -1)
}
