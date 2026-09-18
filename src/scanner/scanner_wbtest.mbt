///|
/// scanner 的端到端测试。移植自 legacy-ts/tests/scanner.test.ts 的 5 个用例，
/// 另加 5 个覆盖本次修复（F1 深度发现、F2 缓存毒化、F3 清单形态、
/// P14 剪枝、TS L115-117 先到先得）的用例。
///
/// 全部用 `@fs.tmpdir` 隔离，扫描根与缓存路径都注入到临时目录里 ——
/// 对应 legacy-ts 的 `new PluginScanner([tmpDir], cachePath)`（L15）。
/// 这是「测试绝不触碰真实插件目录」的前提，也是它们能并行安全的前提。

///|
/// 在 `root/name` 下造一批文件（自动建父目录），返回该目录路径。
/// 对应 legacy-ts/tests/scanner.test.ts L22-28 的 `makePluginDir`。
async fn make_plugin(
  root : String,
  name : String,
  files : Array[(String, String)],
) -> String {
  let dir = @util.path_join(root, name)
  for pair in files {
    let (rel, content) = pair
    let full = @util.path_join(dir, rel)
    let parent = @util.path_dirname(full)
    if !@fs.exists(parent) {
      @fs.mkdir(parent, recursive=true)
    }
    @fs.write_file(full, content, create_mode=CreateOrTruncate)
  }
  dir
}

///|
fn test_scanner(root : String) -> PluginScanner {
  PluginScanner::new(
    ScanConfig::custom([root], @util.path_join(root, "plugin-cache.json")),
  )
}

// ============================================================================
// 移植自 legacy-ts/tests/scanner.test.ts
// ============================================================================

///|
/// 移植：scanner.test.ts L31-46
/// "should discover a plugin with a package.json and SKILL.md"
async test "discovers a plugin with a package.json and SKILL.md" {
  let tmp = @fs.tmpdir(prefix="evo-scan-")
  defer @fs.rmdir(tmp, recursive=true)

  let pkg =
    #|{"name":"my-plugin","version":"2.1.0"}
  let skill = "# My Plugin\nThis tool can navigate and supports clicks."
  ignore(
    make_plugin(tmp, "my-plugin", [("package.json", pkg), ("SKILL.md", skill)]),
  )

  let scanner = test_scanner(tmp)
  scanner.scan_root(tmp, @types.PluginKind::Community)

  assert_eq(scanner.count(), 1)
  let plugin = scanner.get("my-plugin-2.1.0").unwrap()
  assert_eq(plugin.name, "my-plugin")
  assert_eq(plugin.version, "2.1.0")
  assert_eq(plugin.kind, @types.PluginKind::Community)
  // 抽取结果对齐 extract_wbtest 里同一 fixture 的 node 基准
  json_inspect(plugin.capabilities, content=["navigate", "clicks"])
}

///|
/// 移植：scanner.test.ts L48-62
/// "should extract tools from MCP registerTool calls in source files"
async test "extracts tools from MCP registerTool calls in source files" {
  let tmp = @fs.tmpdir(prefix="evo-scan-")
  defer @fs.rmdir(tmp, recursive=true)

  let pkg =
    #|{"name":"mcp-plugin","version":"1.0.0"}
  let server = "\n  server.registerTool('scan_plugins', { description: 'scan' }, cb);\n  server.registerTool('propose_evolution', { description: 'propose' }, cb);\n"
  ignore(
    make_plugin(tmp, "mcp-plugin", [
      ("package.json", pkg),
      ("src/server.ts", server),
    ]),
  )

  let scanner = test_scanner(tmp)
  scanner.scan_root(tmp, @types.PluginKind::Official)

  let plugin = scanner.get("mcp-plugin-1.0.0").unwrap()
  assert_true(plugin.tools.contains("scan_plugins"))
  assert_true(plugin.tools.contains("propose_evolution"))
}

///|
/// 移植：scanner.test.ts L64-70
/// "should ignore directories without any manifest" —— CONTEXT.md 不变量⑤。
async test "ignores directories without any manifest" {
  let tmp = @fs.tmpdir(prefix="evo-scan-")
  defer @fs.rmdir(tmp, recursive=true)
  ignore(make_plugin(tmp, "empty-dir", [("README.md", "not a plugin")]))

  let scanner = test_scanner(tmp)
  scanner.scan_root(tmp, @types.PluginKind::Community)

  assert_eq(scanner.count(), 0)
}

///|
/// 移植：scanner.test.ts L72-77
/// "should skip directories it cannot parse instead of throwing"
///
/// TS 的做法是在期望目录的位置放一个**文件**（名为 `blocked`）。
/// 新版 `read_entries` 直接给出 `is_dir`，非目录项被跳过，天然不会抛。
async test "skips entries it cannot treat as directories instead of raising" {
  let tmp = @fs.tmpdir(prefix="evo-scan-")
  defer @fs.rmdir(tmp, recursive=true)
  @fs.write_file(
    @util.path_join(tmp, "blocked"),
    "not a directory",
    create_mode=CreateOrTruncate,
  )

  let scanner = test_scanner(tmp)
  scanner.scan_root(tmp, @types.PluginKind::Community)
  assert_eq(scanner.count(), 0)

  // 扫描根本身不存在时也只打日志、不抛（对齐 TS L62-65）
  scanner.scan_root(@util.path_join(tmp, "nope"), @types.PluginKind::Official)
  assert_eq(scanner.count(), 0)
}

///|
/// 移植并**改写**：scanner.test.ts L81-95
/// "should write the cache file after scanning"
///
/// TS 的后半段断言（L91-94）把缺陷 F2 固化成了契约：
/// 它让第二个 scanner 指向一个**不存在**的根，然后断言仍能从缓存里拿到 1 个插件
/// —— 也就是「只要缓存非空就整份返回、永不重扫」。
/// 新版按目录路径校验指纹，不存在的根发现不了任何插件，缓存自然无从命中，
/// 因此这条断言被替换为「同一根、目录未变 → 结果稳定」这个**真正的契约**，
/// 并补上「目录变化 → 缓存失效」与「目录消失 → 幽灵条目被丢弃」两条。
async test "writes the cache and keeps results stable across scanner instances" {
  let tmp = @fs.tmpdir(prefix="evo-scan-")
  defer @fs.rmdir(tmp, recursive=true)

  let pkg =
    #|{"name":"cached-plugin","version":"0.1.0"}
  let plugin_dir = make_plugin(tmp, "cached-plugin", [("package.json", pkg)])

  let cache_path = @util.path_join(tmp, "plugin-cache.json")
  let first = PluginScanner::new(ScanConfig::custom([tmp], cache_path))
  first.scan_all(force_rescan=true)

  assert_eq(first.count(), 1)
  assert_eq(@fs.exists(cache_path), true)

  // 同一根、目录未变 → 新实例得到完全相同的结果
  let second = PluginScanner::new(ScanConfig::custom([tmp], cache_path))
  second.scan_all(force_rescan=false)
  assert_eq(second.count(), 1)
  assert_eq(
    second.get("cached-plugin-0.1.0").unwrap().plugin_id,
    "cached-plugin-0.1.0",
  )

  // 目录内容变化 → 指纹失效 → 重扫并反映新状态
  @fs.write_file(
    @util.path_join(plugin_dir, "SKILL.md"),
    "can fly",
    create_mode=CreateOrTruncate,
  )
  let third = PluginScanner::new(ScanConfig::custom([tmp], cache_path))
  third.scan_all(force_rescan=false)
  assert_eq(third.count(), 1)
  json_inspect(third.get("cached-plugin-0.1.0").unwrap().capabilities, content=[
    "fly",
  ])
}

// ============================================================================
// 本次修复的回归测试
// ============================================================================

///|
/// **缺陷 F1 的回归测试。**
/// 实测某个已部署宿主的插件缓存根下 10 个插件第 1 层全部零文件，
/// 真实布局是 `<plugin>/<version>/`；
/// 而 TS 的 `scanPath` 只下探一层，于是**生产中发现 0 个插件**。
async test "F1: discovers plugins nested at <plugin>/<version>/" {
  let tmp = @fs.tmpdir(prefix="evo-scan-")
  defer @fs.rmdir(tmp, recursive=true)

  // 复刻实测布局：顶层目录零文件，清单在第 2 层
  // 注：`#|` 多行串**没有闭合符**，每行以 `#|` 开头即为全部内容；
  // 多写一个结尾 `|` 会把它带进字符串里，让 JSON 静默失效。故统一先 `let` 绑定。
  let seed_041 =
    #|{"name":"browser-use","version":"0.4.1"}
  let seed_031 =
    #|{"name":"browser-use","version":"0.3.1"}
  let seed_inner =
    #|{"name":"inner","version":"9.9.9"}
  ignore(
    make_plugin(tmp, "browser-use/0.4.1", [("package.json", seed_041)]),
  )
  ignore(
    make_plugin(tmp, "browser-use/0.3.1", [("package.json", seed_031)]),
  )
  // 第 3 层也要能发现（max_discovery_depth = 3）
  ignore(make_plugin(tmp, "deep/nest/inner", [("package.json", seed_inner)]))

  let scanner = test_scanner(tmp)
  scanner.scan_root(tmp, @types.PluginKind::Official)

  assert_eq(scanner.count(), 3)
  // 用 `is Some(_)` 而不是 `Option::is_empty()`（后者已 deprecated）
  assert_true(scanner.get("browser-use-0.4.1") is Some(_))
  assert_true(scanner.get("browser-use-0.3.1") is Some(_))
  assert_true(scanner.get("inner-9.9.9") is Some(_))
  // 顶层的 browser-use 目录本身没有清单 → 不算插件（不变量⑤仍然成立）
  let ids = scanner.all().map(fn(p) { p.plugin_id })
  assert_eq(ids.contains("browser-use-0.0.0"), false)
}

///|
/// **缺陷 F3 的回归测试。**
/// 实测样本里有插件既无 `package.json` 也无根 `SKILL.md`，只有
/// `.claude-plugin/plugin.json`、`.mcp.json` 这类清单；
/// TS 的清单集合只有 `{package.json, SKILL.md}`，会把它们整个漏掉。
async test "F3: accepts the four manifest forms, in priority order" {
  let tmp = @fs.tmpdir(prefix="evo-scan-")
  defer @fs.rmdir(tmp, recursive=true)

  let package_seed =
    #|{"name":"from-package","version":"2.2.2"}
  let claude_seed =
    #|{"name":"from-claude","version":"3.3.3"}
  let mcp_seed =
    #|{"mcpServers":{"demo":{"command":"demo"}}}
  let loser_seed =
    #|{"name":"should-lose","version":"9.9.9"}
  let winner_seed =
    #|{"name":"should-win","version":"8.8.8"}

  // ① package.json（manifest_priority 第一项）
  ignore(make_plugin(tmp, "pkg-form", [("package.json", package_seed)]))
  // ② 只有 .claude-plugin/plugin.json —— 无 package.json、无根 SKILL.md
  ignore(
    make_plugin(tmp, "claude-form", [(".claude-plugin/plugin.json", claude_seed)]),
  )
  // ③ 只有 .mcp.json：结构无 name/version → 回退目录名 + 0.0.0
  ignore(make_plugin(tmp, "mcp-only", [(".mcp.json", mcp_seed)]))
  // ④ 只有 SKILL.md（最低优先级）：没有 JSON 元数据 → 同样回退
  ignore(
    make_plugin(tmp, "skill-only", [("SKILL.md", "# Just a skill\ncan read")]),
  )
  // ⑤ 同时存在 package.json 与 .claude-plugin/plugin.json：前者优先
  ignore(
    make_plugin(tmp, "priority-form", [
      (".claude-plugin/plugin.json", loser_seed),
      ("package.json", winner_seed),
    ]),
  )
  // ⑥ .mcp.json 与 SKILL.md 同目录：清单胜出，SKILL.md 不顶掉它
  ignore(
    make_plugin(tmp, "manifest-above-skill", [
      (".mcp.json", mcp_seed),
      ("SKILL.md", "# seed\ncan read"),
    ]),
  )

  let scanner = test_scanner(tmp)
  scanner.scan_root(tmp, @types.PluginKind::Official)

  assert_eq(scanner.count(), 6)
  assert_true(scanner.get("from-package-2.2.2") is Some(_))
  assert_true(scanner.get("from-claude-3.3.3") is Some(_))
  // .mcp.json 无 name/version → 回退
  assert_true(scanner.get("mcp-only-0.0.0") is Some(_))
  // SKILL.md 只能证明「这是个插件」，提供不了 name/version → 回退
  let fallback = scanner.get("skill-only-0.0.0").unwrap()
  assert_eq(fallback.name, "skill-only")
  assert_eq(fallback.version, "0.0.0")
  json_inspect(fallback.capabilities, content=["read"])
  // 优先级方向：package.json 胜过 .claude-plugin/plugin.json
  assert_true(scanner.get("should-win-8.8.8") is Some(_))
  assert_eq(scanner.get("should-lose-9.9.9"), None)
  // 清单与 SKILL.md 同目录时只算一个插件（count()==6 已钉住），且用清单目录名回退
  assert_true(scanner.get("manifest-above-skill-0.0.0") is Some(_))
}

///|
/// **缺陷 F2 的回归测试（scanner 侧）。**
/// store 侧已有一条针对 `PluginCache::validate` 的用例；
/// 这一条覆盖完整链路：`scan_all` 不得因为缓存里有一条幽灵记录就整份返回它。
async test "F2: a ghost cache entry does not resurrect itself on the next scan" {
  let tmp = @fs.tmpdir(prefix="evo-scan-")
  defer @fs.rmdir(tmp, recursive=true)
  let cache_path = @util.path_join(tmp, "plugin-cache.json")

  // 手工写一份毒化缓存：条目指向一个不存在的目录（复刻实测的那份 526 字节文件）
  // 格式必须与当前 cache_version 一致，否则在版本校验处就被整份丢弃，
  // 这条用例就测不到「幽灵条目被逐条判无效」的 validate 路径了。
  let poisoned =
    #|{"version":3,"plugins":[{"profile":{"plugin_id":"cached-plugin-0.1.0","name":"cached-plugin","version":"0.1.0","kind":"official","capabilities":[],"tools":[],"events":[],"dependencies":[],"scanned_at":"1757000000000","path":"__GHOST__/cached-plugin","initial_metrics":{"complexity_score":2.0,"interface_clarity":9.0,"documentation_quality":5.0,"usage_frequency":"idle"}},"fingerprint":{"mtime_sec":"1","mtime_nsec":0,"entry_count":3,"child_mtime_ns":"1000000000"}}]}
  let ghost = poisoned.replace_all(
    old="__GHOST__",
    new=@util.path_join(tmp, "already-deleted"),
  )
  @fs.write_file(cache_path, ghost, create_mode=CreateOrTruncate)

  // 空的扫描根：没有任何真实插件
  let empty_root = @util.path_join(tmp, "roots")
  @fs.mkdir(empty_root, recursive=true)

  let scanner = PluginScanner::new(ScanConfig::custom([empty_root], cache_path))
  scanner.scan_all(force_rescan=false)

  // TS 版会返回 1（整份缓存），新版必须返回 0
  assert_eq(scanner.count(), 0)
  assert_eq(scanner.get("cached-plugin-0.1.0"), None)
  // 且幽灵条目不会又被写回缓存
  let after = @store.PluginCache::new(cache_path).load()
  assert_eq(after.length(), 0)
}

///|
/// **P14 的回归测试。**
/// TS 的 `findFiles`（L277）剪枝而 `findSkillFiles`（L163-175）不剪枝，
/// 两条递归路径行为不一致；实测本仓 `node_modules` 有 12271 文件 / 1704 目录。
async test "P14: prunes node_modules and dot-directories on both traversals" {
  let tmp = @fs.tmpdir(prefix="evo-scan-")
  defer @fs.rmdir(tmp, recursive=true)

  let plug_pkg =
    #|{"name":"plug","version":"1.0.0"}
  ignore(
    make_plugin(tmp, "plug", [
      ("package.json", plug_pkg),
      ("SKILL.md", "can real"),
      // 这些都不该被计入
      ("node_modules/dep/SKILL.md", "can leaked_via_node_modules"),
      (".git/hooks/SKILL.md", "can leaked_via_git"),
      ("dist/bundle.js", "server.registerTool('leaked_dist', h)"),
      // 这个应该被计入
      ("src/real.ts", "server.registerTool('real_tool', h)"),
    ]),
  )

  let scanner = test_scanner(tmp)
  scanner.scan_root(tmp, @types.PluginKind::Official)

  let plugin = scanner.get("plug-1.0.0").unwrap()
  json_inspect(plugin.capabilities, content=["real"])
  json_inspect(plugin.tools, content=["real_tool"])
}

///|
/// TS L115-117 的「同 plugin_id 先到先得」。
/// 遍历顺序已排序（见 discover.mbt 的 `read_entries`），故结果确定：
/// 字典序靠前的目录胜出。
async test "first-wins on duplicate plugin_id, deterministically" {
  let tmp = @fs.tmpdir(prefix="evo-scan-")
  defer @fs.rmdir(tmp, recursive=true)

  // 两个目录声明了同一个 name+version
  let dup_pkg =
    #|{"name":"dup","version":"1.0.0"}
  ignore(
    make_plugin(tmp, "aaa-first", [
      ("package.json", dup_pkg),
      ("SKILL.md", "can from_aaa"),
    ]),
  )
  ignore(
    make_plugin(tmp, "zzz-second", [
      ("package.json", dup_pkg),
      ("SKILL.md", "can from_zzz"),
    ]),
  )

  let scanner = test_scanner(tmp)
  scanner.scan_root(tmp, @types.PluginKind::Official)

  assert_eq(scanner.count(), 1)
  // 排序后 aaa-first 在前，故它的 capabilities 胜出
  json_inspect(scanner.get("dup-1.0.0").unwrap().capabilities, content=[
    "from_aaa",
  ])
}

///|
/// `read_entries` 必须按**字典序**返回，而不是按长度或文件系统顺序。
/// 这是「先到先得」（TS L115-117）与输出顺序可复现的前提。
///
/// 本用例是回归网：前两版实现先后用了 `<` 运算符与 `String::compare`，
/// 而 MoonBit 的 `impl Compare for String` 是**先比长度**的（详见
/// `util/path_test.mbt` 的语义探针），结果排序退化成按长度升序
/// （mid, zeta, alpha），直到本用例失败才被发现。现用 `lexical_compare`。
/// 下面的命名故意让「长度序」与「字典序」相反，否则这个 bug 测不出来。
async test "read_entries sorts lexicographically, not by length" {
  let tmp = @fs.tmpdir(prefix="evo-order-")
  defer @fs.rmdir(tmp, recursive=true)
  // 字典序：alpha < mid < zeta；长度序：mid(3) < zeta(4) < alpha(5) —— 两者相反
  for name in ["zeta", "alpha", "mid"] {
    @fs.mkdir(@util.path_join(tmp, name), recursive=true)
  }
  // 再混入一个文件，确认文件与目录都在结果里（且不会干扰排序）
  @fs.write_file(
    @util.path_join(tmp, "a-file.txt"),
    "x",
    create_mode=CreateOrTruncate,
  )

  let entries = read_entries(tmp)
  json_inspect(entries.map(fn(e) { e.0 }), content=[
    "a-file.txt", "alpha", "mid", "zeta",
  ])
  // 目录/文件标志必须准确（walk 的 names 混淆两者，正是 D9 不用它的原因）
  json_inspect(entries.map(fn(e) { e.1 }), content=[false, true, true, true])
}

///|
/// `all()` 必须是**发现顺序**的 Array，而不是无序 Map 的 values ——
/// 决策 D10 / 修 R5：MoonBit 的 `Map` 是哈希表、迭代序不定，
/// 照搬 TS 的 `Array.from(map.values())` 会让 MCP 每次返回的顺序都不同。
async test "all() returns profiles in deterministic discovery order" {
  let tmp = @fs.tmpdir(prefix="evo-scan-")
  defer @fs.rmdir(tmp, recursive=true)
  for name in ["zeta", "alpha", "mid"] {
    let pkg =
      #|{"name":"__N__","version":"1.0.0"}
    ignore(
      make_plugin(tmp, name, [
        ("package.json", pkg.replace_all(old="__N__", new=name)),
      ]),
    )
  }

  let scanner = test_scanner(tmp)
  // 连扫两次，顺序必须完全一致
  scanner.scan_root(tmp, @types.PluginKind::Official)
  let first_run = scanner.all().map(fn(p) { p.plugin_id })
  let again = test_scanner(tmp)
  again.scan_root(tmp, @types.PluginKind::Official)
  let second_run = again.all().map(fn(p) { p.plugin_id })

  json_inspect(first_run, content=["alpha-1.0.0", "mid-1.0.0", "zeta-1.0.0"])
  // content= 只接受字面量，比对两个运行时数组用 assert_eq
  assert_eq(second_run, first_run)
}

///|
/// ★ W10（scanner 评审）的回归网：`list_files_recursive` 必须有深度上限。
/// 旧实现没有深度边界 —— Windows 的目录 junction 可以构成环
/// （`a/junction → a`），递归会无限下钻直到栈溢出崩溃。
/// junction 无法在 MoonBit 测试里创建（`@fs` 无 symlink API），
/// 于是用**超过上限的深链**等价地踩同一条代码路径：
/// 若上限失效，40 层深链会递归 40 层（旧实现还会继续），
/// 而正确的实现停在 `max_files_depth` 并告警。
/// 断言「深处文件的查找结果是确定且有限的」—— 不依赖具体层数。
async test "list_files_recursive stops at the depth cap (W10)" {
  let tmp = @fs.tmpdir(prefix="evo-scan-")
  defer @fs.rmdir(tmp, recursive=true)

  // 造一条 40 层深的链，最深处放一个 SKILL.md
  let mut deep = tmp
  for i in 0..<40 {
    deep = @util.path_join(deep, "d\{i}")
  }
  @fs.mkdir(deep, recursive=true)
  @fs.write_file(
    @util.path_join(deep, "SKILL.md"),
    "# deep",
    create_mode=CreateOrTruncate,
  )
  // 浅处也放一个：深度上限不应挡掉正常布局的文件
  @fs.write_file(
    @util.path_join(tmp, "SKILL.md"),
    "# shallow",
    create_mode=CreateOrTruncate,
  )

  // 必须终止（旧实现这里会栈溢出/挂死），且能正常找到浅处文件
  let files = list_files_recursive(tmp, fn(name) { name == "SKILL.md" })
  assert_true(files.contains(@util.path_join(tmp, "SKILL.md")))
  // 深处文件在 32 层上限之外，不得被找到
  let too_deep = @util.path_join(deep, "SKILL.md")
  assert_false(files.contains(too_deep))
}

///|
/// **N8 的回归测试：多 root 扫描的确定性。**
/// 修复前：`scan_all` 并行 spawn 后各 task 直接往 `self` 吸收，「同 id 先到先得」
/// 退化成 task 交错先后的竞速 —— 跨 root 撞 `plugin_id` 时胜者与输出顺序都不确定。
/// 修复后：每 root 扫进自己的桶，group 结束后按 `cfg.roots` 顺序合并：
/// 先 root 优先、输出顺序 = root 顺序 + root 内发现顺序。
///
/// 命名刻意反向：root_b 里撞 id 的目录叫 `a-first`（字典序占先），
/// 修复前它若先被吸收就会赢；修复后胜负只由 root 顺序决定。
async test "N8: multi-root scan merges in root order, first root wins on id clash" {
  let tmp = @fs.tmpdir(prefix="evo-scan-n8-")
  defer @fs.rmdir(tmp, recursive=true)

  let root_a = @util.path_join(tmp, "root-a")
  let root_b = @util.path_join(tmp, "root-b")
  @fs.mkdir(root_a, recursive=true)
  @fs.mkdir(root_b, recursive=true)

  // 两个 root 声明同一个 plugin_id（dup-1.0.0）
  let dup_pkg =
    #|{"name":"dup","version":"1.0.0"}
  ignore(
    make_plugin(root_a, "z-later", [
      ("package.json", dup_pkg),
      ("SKILL.md", "can from_root_a"),
    ]),
  )
  ignore(
    make_plugin(root_b, "a-first", [
      ("package.json", dup_pkg),
      ("SKILL.md", "can from_root_b"),
    ]),
  )
  // 再各放一个不同 id 的插件，钉住输出顺序 = root 顺序 + root 内字典序
  let solo_a =
    #|{"name":"solo-a","version":"1.0.0"}
  let solo_b =
    #|{"name":"solo-b","version":"1.0.0"}
  ignore(make_plugin(root_a, "m-solo", [("package.json", solo_a)]))
  ignore(make_plugin(root_b, "m-solo", [("package.json", solo_b)]))

  let cache_path = @util.path_join(tmp, "plugin-cache.json")
  let scanner = PluginScanner::new(ScanConfig::custom([root_a, root_b], cache_path))
  scanner.scan_all(force_rescan=true)

  assert_eq(scanner.count(), 3)
  // 胜者确定：先 root（root_a）的 z-later 胜出 —— 与目录名字典序无关
  json_inspect(scanner.get("dup-1.0.0").unwrap().capabilities, content=[
    "from_root_a",
  ])
  // 输出顺序可复现：root_a 的全部（m-solo < z-later）→ root_b 的全部
  json_inspect(scanner.all().map(fn(p) { p.plugin_id }), content=[
    "solo-a-1.0.0", "dup-1.0.0", "solo-b-1.0.0",
  ])

  // 第二个实例走缓存命中路径，合并顺序必须与首次扫描完全一致
  let second = PluginScanner::new(ScanConfig::custom([root_a, root_b], cache_path))
  second.scan_all(force_rescan=false)
  assert_eq(
    second.all().map(fn(p) { p.plugin_id }),
    scanner.all().map(fn(p) { p.plugin_id }),
  )
}
