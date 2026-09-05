///|
/// 路径工具：全仓统一以 `/` 为分隔符。
///
/// 为什么统一：Win32 API 同时接受 `/` 与 `\`，而 `@fs` 内部拼接**硬编码** `/`
/// （见 async/src/fs/dir.mbt 的 walk 实现：`"\{path}/\{ent.name}"`）。
/// `@env.get_env_var("USERPROFILE")` 返回的却是 `C:\Users\...`。
/// 不在入口归一化就会得到 `C:\Users\x/.harness-evolution/y.jsonl` 这类混合串，
/// 虽然 Win32 能容忍，但会让缓存文件里的路径字段在不同机器上产生无意义的 diff。
///
/// 取代 legacy-ts/src/store/index.ts L13-19 的 `expandPath`，
/// 以及 scanner 里全部的 `path.join` / `path.basename` / `path.dirname`。
/// 不引入 `moonbitlang/x/path`：本仓只需 7 个纯函数，自写即可完全单测。

///|
/// 把 `\` 全部换成 `/`，并折叠重复分隔符（保留 UNC 前缀 `//`）。
pub fn path_normalize(p : String) -> String {
  let s = p.replace_all(old="\\", new="/")
  let unc = s.has_prefix("//")
  let absolute = s.has_prefix("/")
  let segments : Array[String] = []
  for seg in s.split("/") {
    let t = seg.to_owned()
    if t.length() > 0 {
      segments.push(t)
    }
  }
  let prefix = if unc { "//" } else if absolute { "/" } else { "" }
  prefix + segments.join("/")
}

///|
/// 拼接两段路径并归一化。任一侧为空则返回另一侧。
pub fn path_join(a : String, b : String) -> String {
  if a.length() == 0 {
    path_normalize(b)
  } else if b.length() == 0 {
    path_normalize(a)
  } else {
    path_normalize("\{a}/\{b}")
  }
}

///|
/// 取父目录。无分隔符时返回 `"."`，根目录返回 `"/"`。
/// 对齐 Node `path.dirname` 在本仓用到的行为。
pub fn path_dirname(p : String) -> String {
  let s = path_normalize(p).trim_end(chars="/").to_owned()
  match s.rev_find("/") {
    None => "."
    Some(0) => "/"
    Some(i) => s[:i].to_owned()
  }
}

///|
/// 取最后一段名字。对齐 Node `path.basename`。
pub fn path_basename(p : String) -> String {
  let s = path_normalize(p).trim_end(chars="/").to_owned()
  match s.rev_find("/") {
    None => s
    Some(i) => s[i + 1:].to_owned()
  }
}

///|
/// 取扩展名（含点、转小写）；无扩展名或以点开头的名字返回空串。
///
/// 取代 legacy-ts/src/scanner/index.ts L237 的 `/\.(ts|js|mjs)$/`：
/// 直接后缀判断更快也更清晰，且规避了 MoonBit Regex 的 `$` 是**整串锚点**
/// 而非多行锚点这一语义差异（`core/string/regex.mbt` 文档明示）。
pub fn path_extname(p : String) -> String {
  let name = path_basename(p)
  match name.rev_find(".") {
    None => ""
    Some(0) => "" // ".gitignore" 这类点开头文件没有扩展名
    Some(i) => name[i:].to_owned().to_lower()
  }
}

///|
/// 用户主目录：`HOME` → `USERPROFILE` → 当前工作目录。
/// 与 legacy-ts 的 `process.env.HOME || process.env.USERPROFILE || process.cwd()` 同序。
pub fn home_dir() -> String {
  let home = @env.get_env_var("HOME").unwrap_or("")
  if home.length() > 0 {
    return path_normalize(home)
  }
  let profile = @env.get_env_var("USERPROFILE").unwrap_or("")
  if profile.length() > 0 {
    return path_normalize(profile)
  }
  path_normalize(@env.current_dir().unwrap_or("."))
}

///|
/// 把 `~` / `~/...` 展开为绝对路径；其余原样归一化返回。
/// 取代 legacy-ts/src/store/index.ts L13-19 的 `expandPath`。
///
/// 不用正则：TS 版的 `/^[/\\]/` 依赖行首锚点，而 MoonBit Regex 的 `^` 是整串锚点，
/// 语义在此处虽恰好等价，但切片更直白且没有模式串编译期风险。
pub fn expand_home(p : String) -> String {
  let s = path_normalize(p)
  guard s == "~" || s.has_prefix("~/") else { return s }
  let tail = if s == "~" { "" } else { s[2:].to_owned() }
  let home = home_dir()
  if tail.length() == 0 {
    home
  } else {
    path_join(home, tail)
  }
}

///|
/// `p` 相对 `root` 的深度：`root` 自身为 0，直接子项为 1，以此类推。
/// `p` 不在 `root` 下时返回 -1。供 scanner 的清单发现深度限制（缺陷 F1）使用。
///
/// 前缀匹配必须要求段边界：否则 `path_depth_from("a", "ab/c")` 会把
/// 兄弟目录 `ab` 误认为 `a` 的子树。
pub fn path_depth_from(root : String, p : String) -> Int {
  let r = path_normalize(root).trim_end(chars="/").to_owned()
  let full = path_normalize(p)
  if full == r {
    return 0
  }
  // 严格段边界：full 必须以 "<r>/" 开头
  guard full.has_prefix("\{r}/") else { return -1 }
  let rest = full[r.length() + 1:].trim_start(chars="/").to_owned()
  if rest.length() == 0 {
    return 0
  }
  rest.split("/").count()
}
