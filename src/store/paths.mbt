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
/// Per-host path split（分路径加载的核心收口点）
/// ──────────────────────────────────────────────────────────────────────
///
/// 这是「分路径加载」原则在源码中的**唯一收口点**。`HARNESS_EVOLUTION_HOST`
/// 决定宿主类型；`HARNESS_EVOLUTION_USER_DIR` 显式覆盖 user 作用域目录。
/// 优先级：`USER_DIR` > `HOST 推导` > 默认 DSH。
///
/// `host_agents_dir` 是**唯一**允许写宿主目录字面量的地方。如果你想把 user
/// 作用域写到别的目录，请改这里并加单测；**不要**在 `tools.mbt` /
/// `schema.mbt` / `factory.mbt` 等别处重复字面量 —— 这是仓库自身的反模式
/// （见 `docs/dsh-compatibility.md §4.4` 反模式 1）。
///
/// 完整的分路径加载架构说明：`docs/code-architecture.md`。
/// 每个宿主的部署指南：`docs/deploy/<host>.md`（DSH 已验证、Minimax Code 已验证）。

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
/// 宿主类型 → 用户级子 Agent 定义目录的**单一来源**（★ S6）。
/// 返回值 `None` 表示宿主名不被识别（由调用方决定如何回落与是否告警）。
///
/// 每个分支前的注释标了**实证日期**与**已验证的宿主版本**——这是计划落地代码层的
/// 唯一收口点。当前支持的两个宿主都已在真机上端到端验证：撤销「声明式支持」的宿主
/// 之后，分支里只保留已验证项，不再有 declared/awaiting 状态。详情：
///
/// - DSH: `docs/deploy/deepseek-harness.md` § 验证
/// - Minimax Code: `docs/deploy/mavis.md` § 验证
///
/// - DeepSeek Harness（默认——本插件是 DSH 插件，DSH 是第一宿主）: `~/.dsh/skills/`
///   （DSH 0.1.6 真实用户目录是 `~/.dsh`，且**没有独立的「用户级 agents 目录」概念**——
///   宿主只从 `~/.dsh/skills/` 扫描发现 skill。故 user-scope 定义以 skill 形式落盘，
///   宿主在后续会话经 skills 发现加载，见 `docs/subagent-factory.md`。）
/// - Minimax Code: `~/.minimax/agents/`
fn host_agents_dir(host : String) -> String? {
  match host {
    // Verified 2026-09-17 (Minimax Code — MCP + Plugin V1 + Mini App end-to-end)
    "minimax-code" => Some(@util.expand_home("~/.minimax/agents/"))
    // Verified 2026-09-17 (DSH 0.1.6-alpha.1 web profile — propose→approve→execute loop)
    "deepseek-harness" => Some(@util.expand_home("~/.dsh/skills/"))
    _ => None
  }
}

///|
/// 宿主的用户级子 Agent 定义目录（v2.1）。**跨出插件数据根**：
/// 根据宿主类型选择不同的路径，支持多种 harness 平台（见 `host_agents_dir`）。
/// 默认回落 DeepSeek 路径（★ 修订 S13：v2.5 开发中曾把缺省改成**非主宿主**以求与
/// 文档描述对齐，但默认宿主必须是 DSH —— 这与 v2.4 行为一致，不构成破坏性
/// 变更；schema/CONTEXT 等处的文档描述已同步改为按宿主列举）。
/// 可通过环境变量 `HARNESS_EVOLUTION_HOST` 覆盖；未知取值仍回落 DSH 路径
/// （行为不变）—— 告警由 `unknown_host_warning` 在启动序列给出，
/// 因为本函数是同步函数而 `@util.log_warn` 是 async，不能在这里打日志。
/// ★ 修订 S14（DSH 0.1.6 兼容）：新增 `HARNESS_EVOLUTION_USER_DIR` 显式覆盖，
/// 优先级最高 —— 直接指定 user 作用域目录，避免再次硬编码宿主目录漂移。
/// 测试经 `AgentFactory::with_dirs` 注入临时目录，绝不触碰真实的用户 home。
pub fn user_agents_dir() -> String {
  let host = match @env.get_env_var("HARNESS_EVOLUTION_HOST") {
    Some(h) if h.length() > 0 => h
    _ => "deepseek-harness"
  }
  match @env.get_env_var("HARNESS_EVOLUTION_USER_DIR") {
    Some(d) if d.length() > 0 => @util.expand_home(d)
    _ =>
      match host_agents_dir(host) {
        Some(dir) => dir
        // ★ 收口：fallback 路径由 `host_agents_dir("deepseek-harness")` 派生，
        // 唯一字面量保留在该函数 DSH 分支内（paths.mbt::host_agents_dir）。
        // 下面这一行 `expand_home` 只是兜底，按 host_agents_dir 的实现不会触发。
        None =>
          match host_agents_dir("deepseek-harness") {
            Some(dir) => dir
            None => @util.expand_home("~/.dsh/skills/")
          }
      }
  }
}

///|
/// 未知 `HARNESS_EVOLUTION_HOST` 取值的启动告警（★ S6）。
///
/// 旧实现把无法识别的宿主名静默回落到 DSH 路径 —— 用户设了
/// `HARNESS_EVOLUTION_HOST=cursor` 却拿到 `~/.dsh/...`，没有任何提示。
/// 返回 `Some(文案)` 时由 async 的启动序列打 stderr 告警；
/// 未设置、空串或已识别的宿主都返回 `None`（无需告警）。
pub fn unknown_host_warning() -> String? {
  let host = match @env.get_env_var("HARNESS_EVOLUTION_HOST") {
    Some(h) if h.length() > 0 => h
    _ => return None
  }
  match host_agents_dir(host) {
    Some(_) => None
    // ★ 收口：告警文案里的回落路径由 `host_agents_dir("deepseek-harness")`
    // 派生，唯一字面量保留在 host_agents_dir 的 DSH 分支内。
    None =>
      match host_agents_dir("deepseek-harness") {
        Some(fallback) =>
          Some(
            "Unknown HARNESS_EVOLUTION_HOST '\{host}'; falling back to the default DeepSeek Harness directory (\{fallback}). Supported values: minimax-code, deepseek-harness.",
          )
        None => None
      }
  }
}

///|
/// 启动序列点名：当前 `HARNESS_EVOLUTION_HOST` 是否已在真机上验证过端到端
/// （propose→approve→execute 闭环 + 落盘 + 宿主热发现）。返回 `Some(文案)` 时由
/// `main.mbt::main` 打到日志（INFO 级别；已验证的宿主可被宿主页面/Mini App 看到）。
///
/// 这是「计划落地代码层」—— 当前支持的两个宿主都已端到端验证，因此每个分支的文案
/// 都以 `verified` 开头，并写明**在哪个宿主版本、哪一天**验证的。
///
/// 与 `unknown_host_warning` 互补：本函数返回 `Some` 表示宿主**已被识别**，
/// 但是否已实证是另一回事；`unknown_host_warning` 处理的是宿主名未识别的情况。
///
/// 新增宿主或改变验证状态时：更新本函数的对应分支、`host_agents_dir` 的注释，以及
/// `src/store/store_wbtest.mbt` 里钉住验证矩阵的用例（那份用例会强制两份文件同时改，
/// 见 `docs/code-architecture.md` § Adding a new host）。
pub fn host_verification_notice() -> String? {
  let host = match @env.get_env_var("HARNESS_EVOLUTION_HOST") {
    Some(h) if h.length() > 0 => h
    _ => "deepseek-harness"
  }
  match host {
    // Verified 2026-09-17 on DSH 0.1.6-alpha.1 web profile:
    //   - scan_plugins → propose → approve → execute full loop
    //   - create_sub_agent(scope=user) wrote ~/.dsh/skills/evo-compat-test.md
    //     and DSH hot-discovered it as a skill in the same session
    "deepseek-harness" =>
      Some(
        "Host: DeepSeek Harness ≥ 0.1.6 — verified end-to-end 2026-09-17 (web profile, propose→approve→execute loop + user-scope skill hot discovery).",
      )
    // Verified 2026-09-17 on Minimax Code:
    //   - mcp.json-registered stdio server, 14 tools exposed as mcp__harness_evolution__*
    //   - Plugin V1 package installed at ~/.minimax/plugins/harness-evolution/
    //   - Mini App floating panel rendered with live tool grid at
    //     http://127.0.0.1:63757/dashboard (Mavis-assigned port)
    "minimax-code" =>
      Some(
        "Host: Minimax Code — verified end-to-end 2026-09-17 (MCP server + Plugin V1 + Mini App floating panel with 14-tool live grid).",
      )
    _ => None  // unknown hosts are handled by unknown_host_warning; do not double-warn
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
