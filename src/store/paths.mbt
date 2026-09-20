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
///
/// ──────────────────────────────────────────────────────────────────────
/// DSH user-scope path（用户级作用域路径的唯一收口点）
/// ──────────────────────────────────────────────────────────────────────
///
/// 本插件只服务 DeepSeek Harness（DSH）单一宿主。user 作用域目录由
/// `dsh_agents_dir()`（即 `<DSH home>/skills`）给出；`HARNESS_EVOLUTION_USER_DIR`
/// 可显式覆盖（测试注入 / 高级用户）。优先级：`USER_DIR` > `dsh_agents_dir()`。
///
/// 自 v3.0.0 起移除多宿主抽象（历史上曾声明支持 MiniMax Code，但 DSH 源码
/// 中不存在该宿主概念，属过度声明，已砍）。`dsh_home()` 是 DSH home 字面量的
/// **唯一**收口点；**不要**在 `tools.mbt` / `schema.mbt` / `factory.mbt` 等别处
/// 重复路径字面量 —— 这是仓库自身的反模式（见 `docs/dsh-compatibility.md §4.4` 反模式 1）。
///
/// 完整的用户级作用域路径说明：`docs/code-architecture.md`。
/// DSH 部署指南：`docs/deploy/deepseek-harness.md`。

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
/// （`C:\Users\<user>\AppData\Local\Temp\evo-scan-<rand>\cached-plugin`，随机段已脱敏）
/// —— 即缺陷 F2 的毒化缓存。
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
/// 结构化执行事件流（v2.7 可视化数据面）。与 `execution.log` **同源双写**：
/// 文本日志行格式一字不改（保对拍），这份 JSONL 供快照与浮窗机器消费。
/// 生产路径由 `ExecutionLog::at` 接线；`ExecutionLog::new` 的裸路径构造
/// 不启用双写（保持既有测试语义）。
pub fn DataPaths::execution_events(self : DataPaths) -> String {
  @util.path_join(self.root, "execution.jsonl")
}

///|
/// 子 Agent 定义目录（v2.1）：数据根下的 `agents/`。
/// scope=plugin 的定义写在这里；目录由 `AgentDefStore::ensure_dir` 惰性创建。
/// 路径字面量保持单点定义（G4 的精神），与 proposals() / metrics() 同一模式。
pub fn DataPaths::agent_defs(self : DataPaths) -> String {
  @util.path_join(self.root, "agents")
}

///|
/// DSH home 的解析（★ v2.7 路由收敛：双 profile 树的唯一收口点）。
///
/// **问题**：DSH 的 home 不一定是 `~/.dsh`。宿主自己按 `resolveDshHome` 解析，
/// 优先级 `configured > $DSH_HOME > ~/.dsh`，空或纯空白的 `$DSH_HOME` 视为未设置
/// （源码：`@deepseek-ai/dsh-home-paths/lib/index.js` 的 `resolveDshHome` /
/// `defaultDshHome` / `expandHomePath`）。本插件看不到宿主的 `configured` 层，
/// 故只镜像后两档。
///
/// **不镜像的实测后果**：拉起本插件的 MCP launcher 用
/// `DSH_HOME=<pluginData>/dsh-home` 启动 `dsh web`（launcher `server.mjs`
/// 的 `startHarness`），而本插件此前把 user 作用域写死成 `~/.dsh/skills/` ——
/// `create_sub_agent(scope=user)` 的定义落进宿主**根本不读**的另一棵树。
///
/// **`$DSH_HOME` 从哪来**：宿主 spawn MCP 子进程时用 `scrubbedParentEnv()`
/// 丢弃**全部** `DSH_*`（源码：`@deepseek-ai/dsh-subprocess/lib/index.js`，
/// 以及 `@deepseek-ai/dsh-mcp-client/lib/index.js` 里「配置的 `env` 在清洗**之后**
/// 合并」的写法），所以它必须由挂载行的 `env` **显式**转发 —— 继承是拿不到的。
/// 见 `cordis.patch.yml` 的 `DSH_HOME` 行与 `docs/deploy/deepseek-harness.md`。
///
/// 宿主取值的**逐字**语义（`dsh-home-paths/lib/index.js::resolveDshHome`）：
/// `resolve(expandHomePath(configured ?? (trim($DSH_HOME) 非空 ? $DSH_HOME : ~/.dsh)))`。
/// 本函数镜像「去空白判空 + `expandHomePath`」两层，然后**要求结果为绝对路径**
/// （宿主的 `path.resolve` 那一层不镜像，见下）。
///
/// **两处有意偏离宿主**（都因「cwd 不同源」）：
/// 1. 相对路径与盘符相对路径（`C:rel`）不采用。宿主用 `path.resolve` 以**宿主自己的**
///    cwd 为基准；本插件进程的 cwd 是挂载行 `cwd:` 指定的插件位置，两者不同源，
///    采用就会把 user 作用域定义写进插件仓库。
/// 2. `~` 的展开基准：宿主用 Node `os.homedir()`（Windows 上取 `USERPROFILE`），
///    这里是 `@util.expand_home` → `home_dir()`（`HOME` → `USERPROFILE` → cwd）。
///    仅当进程里存在 `HOME` 且与 `USERPROFILE` 不同源时才会有差异。
///    `~` / `~/` / `~\` 三种写法的展开规则与宿主 `expandHomePath` 等价。
fn dsh_home() -> String {
  let fallback = @util.expand_home("~/.dsh")
  match @env.get_env_var("DSH_HOME") {
    // 空或纯空白视为未设置 —— 对齐宿主「blank override never resolves to cwd」
    Some(h) if h.trim().length() > 0 => {
      // 展开前先 trim：判空用 h.trim()，展开也用同一裁剪后的值。这是对宿主的
      // **有意更安全偏离**：DSH 的 resolveDshHome 只用 trim 判空、实际使用未裁剪的
      // 原值（index.js:75），带首尾空白的绝对路径会被它的 path.resolve 拼成 cwd 相对
      // 垃圾路径；我们裁剪后若仍非绝对则回落 ~/.dsh。
      let expanded = @util.expand_home(h.trim().to_owned())
      if is_absolute_path(expanded) {
        expanded
      } else {
        fallback
      }
    }
    _ => fallback
  }
}

///|
/// 是否是**绝对**路径。输入假定已过 `@util.path_normalize`（`\` → `/`、折叠分隔符），
/// 故判据对齐 `@util.path_normalize` 的输出形状：
/// - `/…`（POSIX 根，同时覆盖 `//…` 的 UNC）
/// - `X:/…`（Windows 盘符；`C:foo` 是盘符相对路径，不算绝对，故还要求第三位是 `/`）
fn is_absolute_path(p : String) -> Bool {
  if p.has_prefix("/") {
    return true
  }
  p.length() >= 3 && p[1:2].to_owned() == ":" && p[2:3].to_owned() == "/"
}

///|
/// DSH 的用户级定义目录：`<dsh home>/skills`。宿主只从这里扫描发现 skill，
/// 所以 user 作用域的定义以 skill 形式落在这里。字面量集中在 `dsh_home()` 一处。
fn dsh_agents_dir() -> String {
  @util.path_join(dsh_home(), "skills")
}

///|
/// 用户级子 Agent 定义目录（v2.1）。**跨出插件数据根**：DSH 单一宿主下即
/// `<DSH home>/skills/`（见 `dsh_agents_dir`，home 由 `dsh_home()` 解析，宿主只从
/// 这里扫描发现 skill，user-scope 定义以 skill 形式落盘、宿主在后续会话经 skills
/// 发现加载）。`HARNESS_EVOLUTION_USER_DIR` 显式覆盖优先级最高 —— 测试经
/// `AgentFactory::with_dirs` 注入临时目录，绝不触碰真实的用户 home。
/// 自 v3.0.0 起移除 `HARNESS_EVOLUTION_HOST` / `host_agents_dir` 多宿主分发。
pub fn user_agents_dir() -> String {
  match @env.get_env_var("HARNESS_EVOLUTION_USER_DIR") {
    Some(d) if d.length() > 0 => @util.expand_home(d)
    _ => dsh_agents_dir()
  }
}

///|
/// 确保根目录存在。所有写入前调用一次即可（`@fs.mkdir` 缺省 `recursive=false`，
/// 且其递归回退仅在 ENOENT 时生效，故必须显式传 `recursive=true` —— Phase 0 门禁实测）。
pub async fn DataPaths::ensure_root(self : DataPaths) -> Unit {
  if !@fs.exists(self.root) {
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
  if !@fs.exists(v1) {
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
