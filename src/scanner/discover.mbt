///|
/// 插件发现与目录遍历。取代 legacy-ts/src/scanner/index.ts L61-117（`scanPath` +
/// `scanPluginDirectory` 的前半段）、L160-184（`findSkillFiles`）、
/// L268-292（`findFiles`）。
///
/// **本文件修掉三个实测缺陷：**
///
/// · **F1 —— TS 版在生产中发现 0 个插件。**
///   实测 `~/.zcode/cli/plugins/cache/zcode-plugins-official` 下 10 个插件
///   （android-emulator / browser-use / computer-use / document-skills /
///   ios-simulator / mimosa / restore-legacy-sessions / skill-creator /
///   zcode-cua / zcode-guide）**第 1 层全部零文件**，真实布局是
///   `<plugin>/<version>/`（browser-use 有 4 个版本、document-skills 有 3 个）。
///   而 TS 的 `scanPath`（L69-74）只下探一层就调 `scanPluginDirectory`，
///   后者在 L83-91 直接找 `<root>/<entry>/package.json|SKILL.md` →
///   被「无清单目录不是插件」（CONTEXT.md 不变量⑤）全部误杀。
///   修法：清单发现深度可配（默认 3 层），命中后**认领子树**不再下探。
///
/// · **F3 —— 清单形态覆盖不足。**
///   实测 `browser-use\0.4.1\` 根目录**没有** SKILL.md（清单在
///   `.zcode-plugin/plugin.json`，技能文件在 `skills/*/SKILL.md`）；
///   `mimosa\1.0.3\` **既无 package.json 也无根 SKILL.md**，只有
///   `.zcode-plugin/plugin.json`、`.claude-plugin/`、`.mcp.json`。
///   修法：清单集合从 2 种扩到 6 种，按优先级取元数据。
///   **注意这不是放松不变量⑤** —— 「无清单目录不是插件」依然成立，
///   只是「清单」的定义变准确了。
///
/// · **P14 —— 两条递归路径剪枝行为不一致。**
///   TS 的 `findFiles`（L277）跳过 `.` 开头目录与 `node_modules`，
///   而 `findSkillFiles`（L163-175）**完全不剪枝** → 会穿透整棵依赖树。
///   实测本仓 `node_modules` 有 12271 文件 / 1704 目录、其中 SKILL.md 为 0 个，
///   一旦成为扫描根就是 1704 次纯亏损的 readdir。新版两条路径统一剪枝。
///
/// **为什么手写递归而不用 `@fs.walk`**（决策 D9，Phase 0 探针 P4 已实机确认）：
/// `@fs.walk` 内部是 `group.spawn_bg` + `Semaphore` 的**并发**遍历，
/// 回调触发顺序不确定；而 scanner 的「同 plugin_id 先到先得」（TS L115-117）
/// 与 capabilities/tools 的数组顺序都依赖确定的遍历序。
/// 另外 `walk` 回调的 `names` **混合了文件与子目录名**（源码里
/// `if ent.is_dir { handle_path(..) }` 之后无条件 `files.push(ent.name)`），
/// 拿不到 is_dir 信息还得再 stat 一次。

///|
/// 清单发现的最大深度。1 = `<root>/<x>`，2 = `<root>/<x>/<y>`。
/// 默认 3 足以覆盖 F1 实测的 `<plugin>/<version>/` 两层布局并留一层余量。
pub let max_discovery_depth : Int = 3

///|
/// 清单文件的相对路径，按优先级排列（F3）。
/// 第一个存在的即为该插件的元数据来源。
pub let manifest_priority : Array[String] = [
  ".zcode-plugin/plugin.json",
  "package.json",
  ".claude-plugin/plugin.json",
  ".mcp.json",
  ".zcode-plugin-seed.json",
  "SKILL.md",
]

///|
/// 遍历时剪掉的目录名（P14）。
pub let pruned_dirs : Array[String] = [
  "node_modules",
  ".git",
  "dist",
  "target",
  "_build",
  ".mooncakes",
  ".venv",
  "__pycache__",
  "coverage",
]

///|
/// 一个被发现的插件。
pub struct DiscoveredPlugin {
  /// 插件根目录（清单所在的那一层）
  dir : String
  /// 命中的清单相对路径，取自 `manifest_priority`
  manifest : String
  /// 相对扫描根的深度，1 起
  depth : Int
} derive(Eq, Debug)

///|
/// 该目录名是否应被剪枝。
pub fn is_pruned(name : String) -> Bool {
  if name.has_prefix(".") {
    return true // 对齐 TS L277 的 `!entry.name.startsWith('.')`
  }
  pruned_dirs.contains(name)
}

///|
/// 读出一个目录的直接子项 `(名字, 是否目录)`，**按名字排序**。
///
/// 排序是刻意的：`@fs.readdir` / `opendir` 的原始顺序依赖文件系统实现，
/// 在不同机器甚至同一机器的不同时刻都可能不同。排序后遍历完全确定，
/// 于是「先到先得」与数组顺序都可复现 —— 这既是双跑对拍的前提，
/// 也让 MCP 每次返回给 LLM 的插件顺序稳定。
///
/// 目录不可读（权限、竞态删除）时返回空数组而**不上抛**，
/// 对齐 TS L285-289 的 `try { scanDir } catch { /* Ignore */ }`
/// 与 legacy-ts/tests/scanner.test.ts L72-77 的
/// "should skip directories it cannot parse instead of throwing"。
///
/// 用 `opendir` + `Directory::next` 而非 `readdir` + 逐项 `kind()`：
/// 前者的 `DirectoryEntry` 直接带 `is_dir`，省掉每个子项一次 stat。
pub async fn read_entries(dir : String) -> Array[(String, Bool)] {
  let collected : Result[Array[(String, Bool)], Unit] = try {
    let handle = @fs.opendir(dir)
    defer handle.close()
    let out : Array[(String, Bool)] = []
    while handle.next(include_hidden=true) is Some(entry) {
      out.push((entry.name, entry.is_dir))
    }
    Ok(out)
  } catch {
    _ => Err(())
  }
  match collected {
    Ok(xs) => {
      // ★ 必须用 `lexical_compare`，不能用 `compare` / `<` / `>`。
      // 实测 core/builtin/string.mbt L221 的 `impl Compare for String` 是
      // **先比长度、长度相同才逐字符比较**：
      //   "alpha".compare("mid") > 0   // 5 > 3，而不是字典序的 < 0
      // 用它排序会得到 mid, zeta, alpha（按长度升序），
      // 而不是 alpha, mid, zeta —— 曾使插件输出顺序错乱。
      // `String::lexical_compare` 才是真正的字典序。
      // 字典序是这里唯一想要的语义：它保证遍历与「先到先得」可复现。
      xs.sort_by(fn(a, b) { a.0.lexical_compare(b.0) })
      xs
    }
    Err(_) => []
  }
}

///|
/// 按优先级找出该目录的清单；一个都没有则返回 `None`。
pub async fn find_manifest(dir : String) -> String? {
  for rel in manifest_priority {
    if @fs.exists(@util.path_join(dir, rel)) {
      return Some(rel)
    }
  }
  None
}

///|
/// 发现一个扫描根下的全部插件。
///
/// 与 TS 的 `scanPath` 一致：**扫描根本身不算插件**，从它的直接子项开始判定。
/// 命中清单的目录被「认领」—— 不再向下寻找嵌套插件，
/// 于是 `browser-use` 与 `browser-use/0.4.1` 不会被同时计入。
pub async fn discover_plugins(
  root : String,
  max_depth~ : Int = max_discovery_depth,
) -> Array[DiscoveredPlugin] {
  let out : Array[DiscoveredPlugin] = []
  scan_children(root, 1, max_depth, out)
  out
}

async fn scan_children(
  dir : String,
  depth : Int,
  max_depth : Int,
  out : Array[DiscoveredPlugin],
) -> Unit {
  for entry in read_entries(dir) {
    let (name, is_dir) = entry
    if is_pruned(name) {
      continue
    }
    if !is_dir {
      continue
    }
    let child = @util.path_join(dir, name)
    match find_manifest(child) {
      Some(manifest) => out.push({ dir: child, manifest, depth, })
      None =>
        if depth < max_depth {
          scan_children(child, depth + 1, max_depth, out)
        }
    }
  }
}

///|
/// 从清单文件读出 `(name, version, dependencies)`。
///
/// 取代 TS L100-109：那里只认 `package.json`，其余情况一律回退到
/// `basename(dir)` + `"0.0.0"`。新版按 `manifest_priority` 认 6 种清单，
/// 但**元数据提取规则不变**：读 JSON 的 `name` / `version` / `dependencies`，
/// 缺失或类型不符就回退。
///
/// 于是 `.mcp.json`（结构是 `{"mcpServers":{...}}`，没有 name/version）
/// 与 `SKILL.md`（根本不是 JSON）都自然落到回退分支 —— 它们只证明
/// 「这是个插件」，不提供元数据。
pub async fn read_manifest_meta(
  dir : String,
  manifest : String,
) -> (String, String, Array[String]) {
  let fallback_name = @util.path_basename(dir)
  let json = match @store.read_json(@util.path_join(dir, manifest)) {
    Some(j) => j
    None => return (fallback_name, "0.0.0", [])
  }
  let obj = match json {
    Object(o) => o
    _ => return (fallback_name, "0.0.0", [])
  }
  let name = match obj.get("name") {
    Some(String(s)) if s.length() > 0 => s
    _ => fallback_name
  }
  let version = match obj.get("version") {
    Some(String(s)) if s.length() > 0 => s
    _ => "0.0.0"
  }
  // 对齐 TS L105 的 `Object.keys(packageJson.dependencies || {})`。
  // JS 的 Object.keys 保插入序，而 MoonBit 的 Map 迭代序不定 → 排序以保证确定性。
  let deps : Array[String] = match obj.get("dependencies") {
    Some(Object(d)) => {
      let keys : Array[String] = []
      for kv in d {
        keys.push(kv.0)
      }
      keys.sort_by(fn(a, b) { a.lexical_compare(b) })
      keys
    }
    _ => []
  }
  (name, version, deps)
}

///|
/// 递归收集目录下所有满足 `accept` 的**文件**的完整路径，按遍历顺序（已排序）。
///
/// 一次实现同时取代 TS 的 `findSkillFiles`（L160-184）与 `findFiles`（L268-292）——
/// 那两个函数是同一棵树上跑两遍的近似重复代码（P12），
/// 且剪枝行为还不一致（P14）。
pub async fn list_files_recursive(
  dir : String,
  accept : (String) -> Bool,
) -> Array[String] {
  let out : Array[String] = []
  walk_into(dir, accept, out)
  out
}

async fn walk_into(
  dir : String,
  accept : (String) -> Bool,
  out : Array[String],
) -> Unit {
  for entry in read_entries(dir) {
    let (name, is_dir) = entry
    let full = @util.path_join(dir, name)
    if is_dir {
      if is_pruned(name) {
        continue
      }
      walk_into(full, accept, out)
    } else if accept(name) {
      out.push(full)
    }
  }
}

///|
/// 找出目录下所有 `SKILL.md`（含子目录）。取代 TS L160-184。
pub async fn list_skill_files(dir : String) -> Array[String] {
  list_files_recursive(dir, fn(name) { name == "SKILL.md" })
}

///|
/// 找出目录下所有 `.ts` / `.js` / `.mjs` 源码文件。取代 TS L268-292。
pub async fn list_source_files(dir : String) -> Array[String] {
  list_files_recursive(dir, is_source_file)
}

///|
/// 读取文本文件；不存在或不可读返回 `None`（不上抛）。
pub async fn read_text_or_none(path : String) -> String? {
  if !(@fs.exists(path)) {
    return None
  }
  try {
    Some(@fs.read_file(path).text())
  } catch {
    e => {
      @util.log_warn("Scanner", "Cannot read \{path}: \{e.to_string()}")
      None
    }
  }
}
