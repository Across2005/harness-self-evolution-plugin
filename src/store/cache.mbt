///|
/// 插件扫描缓存。收拢 legacy-ts/src/scanner/index.ts L332-349 的直接文件读写
/// （那里 `fs.readFile` / `fs.ensureDir` / `fs.writeFile` 绕过 store 直接落盘，
/// 违反 CONTEXT.md 不变量①的精神）。
///
/// **同时修掉缺陷 F2：缓存永久毒化。**
/// 实测本机 `~/.harness-evolution/plugin-cache.json`（526 字节）的唯一条目是
/// （用户名与临时目录随机段已脱敏，结构与原文件一致）
/// ```json
/// { "cached-plugin-0.1.0": { ...,
///     "path": "C:\\Users\\<user>\\AppData\\Local\\Temp\\evo-scan-<rand>\\cached-plugin" } }
/// ```
/// 那是 jest 测试的残留，指向一个早已被 `tests/scanner.test.ts` L19 的
/// `afterEach(fs.remove)` 删除的临时目录。而 TS 的 `scanAll`（L36-42）
/// 命中缓存的条件仅仅是 `cached.size > 0` —— 于是**每次启动都直接返回这条幽灵记录，
/// 永不重扫**，且 `tests/scanner.test.ts` L92-94 恰好把这个行为固化成了断言。
///
/// 修法：每个缓存条目携带**目录指纹**（mtime + 直接子项数），
/// `validate` 逐条校验；路径不存在 → 丢弃并告警，指纹变化 → 只重扫该子树。
///
/// **文件格式用数组而非对象**：TS 存的是 `Object.fromEntries(map)`，
/// 依赖 JS 对象的键序（即 Map 插入序）。MoonBit 的 `Map` 是哈希表、迭代序不定，
/// 若照搬会让缓存文件的键序在每次运行时抖动，既破坏双跑对拍也无谓地产生 diff。

///|
/// 目录指纹。用于判定缓存条目是否仍然有效。
/// `pub(all)` 而非 `pub`：scanner 需要**构造**它（不只是读），
/// 而 MoonBit 的 `pub struct` 在包外是只读的。
///
/// 三个分量各有分工：
/// · `mtime_sec` / `mtime_nsec` —— 目录自身的修改时间，捕捉子项的**增删改名**
/// · `entry_count` —— 直接子项数，与 mtime 互补（某些文件系统上 mtime 粒度很粗）
/// · `child_mtime_sec` —— 直接子项中**最新**的 mtime，捕捉「文件被就地改写
///   但目录结构未变」的情形。没这一项的话，作者改了 `SKILL.md` 内容
///   而没增删文件，缓存就会陈旧 —— 对一个以「察觉插件变化」为职责的
///   工具而言是不可接受的。成本是每个直接子项一次 stat（典型 < 20 次），
///   远低于重扫所需的递归遍历 + 全文正则。
///
/// 已知局限（已记录）：**嵌套**文件的就地改写（如 `skills/foo/SKILL.md`）
/// 仍不会被察觉，因为它们不是插件根的直接子项。逃生门是
/// MCP 工具 `scan_plugins` 的 `force_rescan` 参数。
pub(all) struct DirFingerprint {
  mtime_sec : Int64
  mtime_nsec : Int
  entry_count : Int
  child_mtime_sec : Int64
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 一条缓存记录 = 插件档案 + 其目录指纹。
pub(all) struct CachedProfile {
  profile : @types.PluginMetadata
  fingerprint : DirFingerprint
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 缓存文件的顶层结构。带 `version` 以便将来演进时能识别旧格式并直接丢弃。
struct CacheFile {
  version : Int
  plugins : Array[CachedProfile]
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
let cache_version : Int = 2

///|
/// 扫描缓存。
pub struct PluginCache {
  path : String
}

///|
/// 按文件路径构造。
pub fn PluginCache::new(path : String) -> PluginCache {
  { path: @util.expand_home(path) }
}

///|
/// 用 `DataPaths` 构造（生产路径）。
pub fn PluginCache::at(paths : DataPaths) -> PluginCache {
  PluginCache::new(paths.plugin_cache())
}

///|
/// 计算某目录的指纹；目录不存在时返回 `None`。
///
/// 成本是 2 次 stat + 1 次 readdir + 每个直接子项 1 次 stat，
/// **不读任何文件内容** —— 这正是「指纹校验」比「全量重扫」
/// 便宜几个数量级的原因（重扫要递归遍历 + 读文件 + 跑 9 条正则）。
pub async fn fingerprint_of(dir : String) -> DirFingerprint? {
  if !@fs.exists(dir) {
    return None
  }
  let (sec, nsec) = @fs.mtime(dir)
  // readdir 失败（权限、竞态删除）时直接当作无法指纹 → 上层会重扫。
  // 宁可多扫一次，也不要沿用一份无法核实的缓存。
  let names : Array[String] = @fs.readdir(dir, include_hidden=true, sort=true) catch {
    _ => return None
  }
  // 直接子项中最新的 mtime（见 DirFingerprint 的文档：捕捉就地改写）
  let mut newest : Int64 = 0L
  for name in names {
    let child = @util.path_join(dir, name)
    let stamp : (Int64, Int)? = Some(@fs.mtime(child)) catch { _ => None }
    match stamp {
      Some((csec, _)) => if csec > newest { newest = csec }
      None => ()
    }
  }
  Some({
    mtime_sec: sec,
    mtime_nsec: nsec,
    entry_count: names.length(),
    child_mtime_sec: newest,
  })
}

///|
/// 读取缓存。文件不存在、版本不符或解析失败都返回空数组
/// （对齐 legacy-ts scanner L337-339 的「缓存坏了就当没有」）。
///
/// 缓存是**派生数据**：丢弃它只会触发一次重扫，绝不影响正确性。
/// 所以这里的所有失败路径都选择「返回空」而不是上抛。
pub async fn PluginCache::load(self : PluginCache) -> Array[CachedProfile] {
  let json = match read_json(self.path) {
    Some(j) => j
    None => return []
  }
  let parsed : Result[CacheFile, String] = Ok(@json.from_json(json)) catch {
    e => Err(e.to_string())
  }
  match parsed {
    Ok(file) =>
      if file.version != cache_version {
        @util.log_warn(
          "Store",
          "Ignoring plugin cache \{self.path}: version \{file.version}, expected \{cache_version}",
        )
        []
      } else {
        file.plugins
      }
    Err(reason) => {
      @util.log_warn(
        "Store",
        "Ignoring unreadable plugin cache \{self.path}: \{reason}",
      )
      []
    }
  }
}

///|
/// 写入缓存（原子替换：写 `.tmp` 再 rename）。
/// 用 `indent=2`，因为这个文件是给人看的调试产物，不是高频遥测。
pub async fn PluginCache::save(
  self : PluginCache,
  entries : ArrayView[CachedProfile],
) -> Unit {
  let file : CacheFile = { version: cache_version, plugins: entries.to_owned() }
  write_json_atomic(self.path, ToJson::to_json(file))
}

///|
/// 校验单条缓存是否仍然有效：目录还在，且指纹未变。
///
/// 这是修掉 F2 的关键：TS 只看「缓存非空」，此处逐条核对物理现实。
/// 目录消失（例如那条指向已删除 jest 临时目录的幽灵记录）→ 返回 `false` 并告警。
pub async fn PluginCache::validate(entry : CachedProfile) -> Bool {
  let dir = entry.profile.path
  let current = match fingerprint_of(dir) {
    Some(fp) => fp
    None => {
      @util.log_warn(
        "Store",
        "Discarding stale plugin cache entry \{entry.profile.plugin_id}: directory \{dir} no longer exists",
      )
      return false
    }
  }
  if current != entry.fingerprint {
    return false
  }
  true
}
