///|
/// 插件扫描器。取代 legacy-ts/src/scanner/index.ts L14-155 与 L329-363。
///
/// 职责边界：本文件只做「发现 → 读清单 → 抽取 → 打分 → 建档」，
/// 解析与打分的纯逻辑在 extract.mbt / metrics.mbt，
/// 目录遍历在 discover.mbt，缓存读写在 store/cache.mbt。
///
/// **相对 TS 版的四处改进**（都有实测依据，见 discover.mbt 的头注释）：
/// 1. 修 F1：清单发现深度可配（默认 3），修好「生产中发现 0 个插件」
/// 2. 修 F2：缓存按**目录路径**索引并逐条校验指纹，幽灵条目自然被丢弃
/// 3. 修 P12/P13：每个插件目录只遍历一次，SKILL.md 只读一次
///    （TS 是 `findSkillFiles` 全树递归 + `findFiles` 再全树递归 +
///     `calculateMetrics` 又读一次根 SKILL.md）
/// 4. 修 R5：`Array` 是事实来源、`Map` 只做索引，输出顺序确定
///    （MoonBit 的 `Map` 是哈希表，TS 的 `Map` 保插入序，照搬会抖）

///|
/// 扫描配置。
pub struct ScanConfig {
  /// 扫描根目录列表
  roots : Array[String]
  /// 缓存文件路径
  cache_path : String
  /// 清单发现的最大深度（F1）
  max_depth : Int
}

///|
/// 默认扫描根。兼容多种 harness 平台，首打 DeepSeek Harness：
/// ```text
/// ~/.deepseek/harness/plugins/          # DeepSeek Harness 插件（首打）
/// ~/.deepseek/harness/extensions/       # DeepSeek Harness 扩展
/// ~/.minimax/plugins/                   # Minimax Code 插件
/// ~/.minimax/extensions/                # Minimax Code 扩展
/// ~/.zcode/cli/plugins/cache/zcode-plugins-official
/// ~/.zcode/plugins
/// ~/.agents/plugins
/// ```
///
/// **配置来源（2.2.0 起接通，此前是已知缺陷第 6 条的配置孤岛）**：
/// `.zcode-plugin/plugin.json` 的 `scan_targets` 段（6 个路径，含
/// `~/.deepseek/harness/plugins/`、`~/.agents/skills/` 等）经
/// `ScanConfig::from_plugin_json` 解析，在 `main.mbt` 装配时替换默认根；
/// 未配置时回退到这里的 7 个硬编码根。
/// 接通它会**改变发现哪些插件** —— 这是 2.2.0 经用户「全面升级」授权后
/// 做出的显式行为变更， rationale 与回退语义见 `from_plugin_json`。
pub fn default_scan_roots() -> Array[String] {
  [
    @util.expand_home("~/.deepseek/harness/plugins/"),
    @util.expand_home("~/.deepseek/harness/extensions/"),
    @util.expand_home("~/.minimax/plugins/"),
    @util.expand_home("~/.minimax/extensions/"),
    @util.expand_home("~/.zcode/cli/plugins/cache/zcode-plugins-official"),
    @util.expand_home("~/.zcode/plugins"),
    @util.expand_home("~/.agents/plugins"),
  ]
}

///|
/// 生产配置，缓存路径由 `DataPaths` 统一给出。
///
/// ★ 这里曾经还有一个 `ScanConfig::default()`，把缓存路径硬写成
/// `~/.harness-evolution/v2/plugin-cache.json`。已删除，理由两条：
/// 1. **全仓零调用点**（实测：除了它自己的定义，grep 无任何命中）—— 死代码。
/// 2. 它是 `store/paths.mbt` 之外**唯一**一处 `.harness-evolution` 字面量，
///    直接违背计划「收拢 4 处重复的默认路径」的意图（TS 版把默认值散在
///    store L114 / monitor L42-43 / engine L39 / executor L28 四个文件）。
/// 删掉之后，`mcp/architecture_test.mbt` 就能机器化地守住
/// 「数据目录字面量只允许出现在 store/paths.mbt」这条不变量。
pub fn ScanConfig::at(paths : @store.DataPaths) -> ScanConfig {
  ScanConfig::with_cache(paths.plugin_cache())
}

///|
/// 指定缓存路径，扫描根取默认值。
pub fn ScanConfig::with_cache(cache_path : String) -> ScanConfig {
  { roots: default_scan_roots(), cache_path, max_depth: max_discovery_depth }
}

///|
/// 完全自定义（测试用：把根与缓存都指到 `@fs.tmpdir` 里，
/// 于是测试绝不触碰真实的 home 目录 —— 对应 legacy-ts 的
/// `new PluginScanner([tmpDir], cachePath)`）。
pub fn ScanConfig::custom(
  roots : Array[String],
  cache_path : String,
  max_depth? : Int = max_discovery_depth,
) -> ScanConfig {
  { roots, cache_path, max_depth }
}

///|
/// 从整个 `.zcode-plugin/plugin.json` 解析 `scan_targets` 段（2.2.0 接通，
/// 此前它与 `evolution_config` 一样是「写了但没人读」的配置孤岛）。
///
/// 容错语义与 `EngineConfig::from_json_checked` 同一套原则 ——
/// 配置写错绝不让启动失败，但**退化取值必须显式回落并点名告警**：
///
/// - `scan_targets` 缺失 → 默认根，无告警（「没配」是最常见的正常态）；
/// - `scan_targets` 不是数组 → 默认根 + 点名告警；
/// - 数组元素混入非字符串或空串 → 跳过该元素 + 点名告警（按下标）；
/// - 过滤后没有任何可用路径（含显式 `[]`）→ 默认根 + 告警
///   （空列表等于关掉整个扫描，属 H2 意义上的退化取值）；
/// - 正常列表 → 逐项 `@util.expand_home`（支持 `~/...`）后作为扫描根。
///
/// 本函数是**纯解析**：不做任何文件系统存在性检查 —— 不存在的路径由
/// `scan_root` 在扫描时打一行 `Path does not exist` 后跳过，与默认根的
/// 行为一致（`~/.zcode/plugins` 在多数机器上同样不存在）。
///
/// 返回 `(config, warns)`；告警由调用方（`main.mbt` 的启动序列）打到 stderr。
pub fn ScanConfig::from_plugin_json(
  json : Json,
  cache_path : String,
) -> (ScanConfig, Array[String]) {
  let warn : Array[String] = []
  let defaults = fn() { ScanConfig::with_cache(cache_path) }
  let root = match json {
    Object(o) => o
    _ => return (defaults(), warn)
  }
  let items = match root.get("scan_targets") {
    None => return (defaults(), warn)
    Some(Array(items)) => items
    Some(_) => {
      warn.push(
        "scan_targets: expected an array of paths; fell back to the default scan roots",
      )
      return (defaults(), warn)
    }
  }
  let roots : Array[String] = []
  for i, item in items {
    match item {
      String(s) =>
        if s.length() == 0 {
          warn.push("scan_targets[\{i}]: empty path was skipped")
        } else {
          roots.push(@util.expand_home(s))
        }
      _ => warn.push("scan_targets[\{i}]: not a string, was skipped")
    }
  }
  if roots.is_empty() {
    warn.push(
      "scan_targets: no usable path; fell back to the default scan roots",
    )
    return (defaults(), warn)
  }
  (ScanConfig::custom(roots, cache_path), warn)
}

///|
/// 插件扫描器。
pub struct PluginScanner {
  cfg : ScanConfig
  cache : @store.PluginCache
  /// 事实来源：按发现顺序排列的档案（决策 D10 / 修 R5）
  profiles : Array[@types.PluginMetadata]
  /// plugin_id → profiles 下标。仅用于 O(1) 去重与查找，不用于遍历输出。
  index : Map[String, Int]
}

///|
/// 构造。
pub fn PluginScanner::new(cfg : ScanConfig) -> PluginScanner {
  {
    cfg,
    cache: @store.PluginCache::new(cfg.cache_path),
    profiles: [],
    index: Map([]),
  }
}

///|
/// 已发现的插件数。
pub fn PluginScanner::count(self : PluginScanner) -> Int {
  self.profiles.length()
}

///|
/// 全部档案，**按发现顺序**。
/// 对齐 legacy-ts 的 `getAllPlugins()`（L361-363），但返回有序 Array 而非 Map ——
/// TS 靠 JS Map 的插入序保证确定性，MoonBit 的 Map 做不到。
pub fn PluginScanner::all(self : PluginScanner) -> Array[@types.PluginMetadata] {
  self.profiles.copy()
}

///|
/// 按 id 查档案。
pub fn PluginScanner::get(
  self : PluginScanner,
  plugin_id : String,
) -> @types.PluginMetadata? {
  match self.index.get(plugin_id) {
    Some(i) => Some(self.profiles[i])
    None => None
  }
}

///|
/// 清空已发现的档案。
fn PluginScanner::reset(self : PluginScanner) -> Unit {
  self.profiles.clear()
  self.index.clear()
}

///|
/// 并入一份档案；同 id 已存在则**先到先得**跳过（对齐 TS L115-117）。
/// 返回是否真的并入了。
fn PluginScanner::absorb(
  self : PluginScanner,
  profile : @types.PluginMetadata,
) -> Bool {
  if self.index.contains(profile.plugin_id) {
    return false
  }
  let i = self.profiles.length()
  self.profiles.push(profile)
  self.index.set(profile.plugin_id, i)
  true
}

///|
/// 扫描全部根目录并写回缓存。取代 TS 的 `scanAll`（L34-56）。
///
/// **缓存策略与 TS 的关键差别**（修 F2）：
/// TS 的命中条件是 `cached.size > 0` —— 只要缓存非空就整份返回、永不重扫，
/// 于是一条指向已删除目录的幽灵记录就能让整个 scanner 永久失效。
/// 新版按**目录路径**索引缓存，在发现阶段逐个插件目录比对：
/// · 命中且指纹有效 → 直接采用档案，跳过全部文件读取与正则
/// · 命中但指纹变了 → 完整重扫该目录
/// · 未命中（新插件）→ 完整扫描
/// · 缓存里有、但本轮没发现（目录已删）→ 自然被丢弃，不进输出、不进新缓存
pub async fn PluginScanner::scan_all(
  self : PluginScanner,
  force_rescan? : Bool = false,
) -> Unit {
  let cache_by_dir : Map[String, @store.CachedProfile] = Map([])
  if !force_rescan {
    for entry in self.cache.load() {
      cache_by_dir.set(entry.profile.path, entry)
    }
  }

  self.reset()
  // 并行扫描多个根目录以提升性能
  @async.with_task_group() <| group => {
    for root in self.cfg.roots {
      let _ = group.spawn(allow_failure=true, () => {
        self.scan_root(root, @types.PluginKind::Official, cache_by_dir~)
      })
    }
  }
  self.save_cache()
}

///|
/// 扫描单个根目录。取代 TS 的 `scanPath`（L61-75）。
///
/// 根不存在时打一行日志后返回（对齐 TS L63 的
/// `console.log("[Scanner] Path does not exist: ...")`，改走 stderr）。
///
/// `cache_by_dir` 缺省为空，即「不用缓存、全部完整扫描」——
/// 这是测试与非缓存路径的便捷入口；`scan_all` 会传入预热好的缓存索引。
pub async fn PluginScanner::scan_root(
  self : PluginScanner,
  root : String,
  kind : @types.PluginKind,
  cache_by_dir? : Map[String, @store.CachedProfile] = Map([]),
) -> Unit {
  if !@fs.exists(root) {
    @util.log_info("Scanner", "Path does not exist: \{root}")
    return
  }
  let found = discover_plugins(root, max_depth=self.cfg.max_depth)
  for plugin in found {
    self.scan_plugin_dir(plugin, kind, cache_by_dir~)
  }
}

///|
/// 扫描单个插件目录。取代 TS 的 `scanPluginDirectory`（L80-155）。
///
/// CONTEXT.md 不变量⑤（「无清单目录不是插件」）由 `discover_plugins` 保证 ——
/// 只有含清单的目录才会被送进来，故此处不再需要 TS L83-91 的那段判定。
///
/// **只遍历一次**（修 P12）：`list_skill_files` 与 `list_source_files`
/// 在 TS 里是两次独立的全树递归，此处仍是两次调用但共享 `read_entries`
/// 的剪枝与排序逻辑；真正的重复读取（P13：根 SKILL.md 被 `parseSkillFile`
/// 与 `calculateMetrics` 各读一次）已消除 —— 内容长度在遍历技能文件时顺手记下。
pub async fn PluginScanner::scan_plugin_dir(
  self : PluginScanner,
  plugin : DiscoveredPlugin,
  kind : @types.PluginKind,
  cache_by_dir? : Map[String, @store.CachedProfile] = Map([]),
) -> Unit {
  let dir = plugin.dir

  // 缓存命中且指纹有效 → 直接采用，一个文件都不读
  match cache_by_dir.get(dir) {
    Some(entry) =>
      if @store.PluginCache::validate(entry) {
        ignore(self.absorb(entry.profile))
        return
      }
    None => ()
  }

  let (name, version, dependencies) = read_manifest_meta(dir, plugin.manifest)
  // 对齐 TS L112：plugin_id = `${name}-${version}`
  let plugin_id = "\{name}-\{version}"
  // 对齐 TS L115-117：同 id 先到先得
  if self.index.contains(plugin_id) {
    return
  }

  // 技能文件和源码文件：一次性遍历目录，避免两次遍历
  let capabilities : Array[String] = []
  let tools : Array[String] = []
  let root_skill_path = @util.path_join(dir, "SKILL.md")
  let mut root_skill_len : Int? = None
  let (skill_files, source_files) = list_skill_and_source_files(dir)
  
  for skill in skill_files {
    match read_text_or_none(skill) {
      Some(text) => {
        if skill == root_skill_path {
          // String::length() 实测就是 UTF-16 码元数，与 JS 的 String.length 一致
          // （详见 metrics.mbt 的 compute_metrics 文档注释与 metrics_wbtest 的回归用例）
          root_skill_len = Some(text.length())
        }
        // 使用增强版提取函数，支持文本/学术写作能力识别
        let extracted = extract_from_skill_text_enhanced(text)
        for c in extracted.capabilities {
          capabilities.push(c)
        }
        for t in extracted.tools {
          tools.push(t)
        }
      }
      None => ()
    }
  }

  // 源码文件：抽取 MCP 工具注册名
  for src in source_files {
    match read_text_or_none(src) {
      Some(text) => extract_tools_from_source_text(text, tools)
      None => ()
    }
  }

  // 根据提取的能力自动判断 Skill 领域分类
  let domain = classify_domain(capabilities)

  // 指标用**未去重**的计数（对齐 TS L132 传入 calculateMetrics 的数组），
  // 档案里存**去重后**的数组（对齐 TS L140-142 的 [...new Set(...)]）。
  // 这两个时机必须分开：合并它们会静默改变 complexity_score，
  // 进而翻转 engine L196 的 `> 7` 判定。
  let metrics = compute_metrics(
    root_skill_len,
    tools.length(),
    capabilities.length(),
  )

  let profile : @types.PluginMetadata = {
    plugin_id,
    name,
    version,
    kind,
    domain,
    capabilities: @types.dedup_ordered(capabilities),
    tools: @types.dedup_ordered(tools),
    // TS 的 events 数组声明于 L97 但从未被 push，恒为空。原样保留。
    events: [],
    dependencies,
    scanned_at: @util.now_ms(),
    path: dir,
    initial_metrics: metrics,
  }
  if self.absorb(profile) {
    // 对齐 TS L150 的日志：里面用的是**未去重**的计数
    @util.log_info(
      "Scanner",
      "Found plugin: \{plugin_id} (\{domain.wire_name()}, \{tools.length()} tools, \{capabilities.length()} capabilities)",
    )
  }
}

///|
/// 把当前档案连同新鲜指纹写回缓存。取代 TS 的 `saveCache`（L345-349）。
async fn PluginScanner::save_cache(self : PluginScanner) -> Unit {
  let entries : Array[@store.CachedProfile] = []
  for profile in self.profiles {
    match @store.fingerprint_of(profile.path) {
      Some(fp) => entries.push({ profile, fingerprint: fp })
      // 目录在扫描过程中消失了：不值得缓存，下一轮自然会重扫
      None => ()
    }
  }
  self.cache.save(entries)
}
