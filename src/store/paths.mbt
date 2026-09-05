///|
/// 数据文件布局的单一入口。
///
/// **这里收拢了一处重复**：legacy-ts 把 `~/.harness-evolution/...` 的默认值
/// 散落在 4 个文件里 —— store/index.ts L114、monitor/index.ts L42-43、
/// engine/index.ts L39、executor/index.ts L28。四处各写一遍，
/// 想换数据目录就得改四个地方，且没有任何机制保证它们一致。
///
/// 新版只有这一个入口，并支持 `HARNESS_EVOLUTION_HOME` 环境变量覆盖，
/// 使测试与「多套档案并存」的场景都不必构造 `~` 路径。
///
/// CONTEXT.md「架构不变量①」在本仓被强化为：
/// **所有持久化状态的文件 I/O 只存在于 store/**。
/// legacy-ts 有两处越界（scanner/index.ts L345-349 直接写 plugin-cache.json、
/// executor/index.ts L423-428 直接 appendFile execution.log），
/// 分别由本包的 cache.mbt 与 exec_log.mbt 收拢。

///|
/// 全部数据文件的根目录。
pub struct DataPaths {
  root : String
}

///|
/// 默认布局：`$HARNESS_EVOLUTION_HOME`，否则 `~/.harness-evolution/v2`。
///
/// **为什么是 `v2` 子目录**：本次移植重新设计了数据结构（时间戳从 ISO 字符串
/// 改为 Int64 毫秒、`event_type`+`event_data` 合并为单一枚举、`ProposedChanges`
/// 的 7 字段结构改为变体列表），与 v1 的 JSONL 不兼容。
/// 实测本机 `~/.harness-evolution/` 当前**只有**一个 526 字节的 `plugin-cache.json`，
/// 且其唯一条目指向一个早已被 jest `afterEach` 删除的临时目录
/// （`C:\Users\...\Temp\evo-scan-c8AcoZ\cached-plugin`）—— 即缺陷 F2 的毒化缓存。
/// 没有 `metrics/signals/proposals.jsonl`，所以自动迁移是空操作；
/// 而那个缓存丢弃重扫比迁移更安全。故：**只提示，不迁移**。
pub fn DataPaths::default() -> DataPaths {
  let root = match @env.get_env_var("HARNESS_EVOLUTION_HOME") {
    Some(h) if h.length() > 0 => @util.expand_home(h)
    _ => @util.expand_home("~/.harness-evolution/v2")
  }
  { root: @util.path_normalize(root), }
}

///|
/// 指定根目录。测试用它把数据隔离到 `@fs.tmpdir` 里，
/// 从而不必触碰真实的 home 目录 —— 这是全部 store 测试能并行安全的前提。
pub fn DataPaths::at(root : String) -> DataPaths {
  { root: @util.path_normalize(@util.expand_home(root)), }
}

///|
/// 根目录本身。
pub fn DataPaths::root(self : DataPaths) -> String {
  self.root
}

///|
/// 进化提案（`ProposalStore` 的唯一读写口）。
pub fn DataPaths::proposals(self : DataPaths) -> String {
  @util.path_join(self.root, "proposals.jsonl")
}

///|
/// 性能事件（monitor 写）。
pub fn DataPaths::metrics(self : DataPaths) -> String {
  @util.path_join(self.root, "metrics.jsonl")
}

///|
/// 进化信号（monitor 写、engine 读）。
pub fn DataPaths::signals(self : DataPaths) -> String {
  @util.path_join(self.root, "signals.jsonl")
}

///|
/// 扫描缓存（scanner 经 `PluginCache` 读写）。
pub fn DataPaths::plugin_cache(self : DataPaths) -> String {
  @util.path_join(self.root, "plugin-cache.json")
}

///|
/// 执行日志（executor 经 `ExecutionLog` 追加）。
pub fn DataPaths::execution_log(self : DataPaths) -> String {
  @util.path_join(self.root, "execution.log")
}

///|
/// 确保根目录存在。所有写入前调用一次即可（`@fs.mkdir` 缺省 `recursive=false`，
/// 且其递归回退仅在 ENOENT 时生效，故必须显式传 `recursive=true` —— Phase 0 门禁实测）。
pub async fn DataPaths::ensure_root(self : DataPaths) -> Unit {
  if !(@fs.exists(self.root)) {
    @fs.mkdir(self.root, recursive=true)
  }
}

///|
/// 若检测到 v1 数据目录且 v2 尚未建立，向 stderr 打一行提示。
/// 只提示、不迁移、不删除 —— v1 目录原样保留，用户可自行处置。
pub async fn DataPaths::warn_on_legacy_v1(self : DataPaths) -> Unit {
  let v1 = @util.expand_home("~/.harness-evolution")
  if v1 == self.root {
    return
  }
  if !(@fs.exists(v1)) {
    return
  }
  if @fs.exists(self.root) {
    return
  }
  @util.log_warn(
    "Store",
    "Found legacy data directory \{v1}; this version uses \{self.root} and does not migrate it. The legacy directory is left untouched.",
  )
}
