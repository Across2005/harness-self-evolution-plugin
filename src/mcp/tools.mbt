///|
/// 13 个 MCP 工具的定义、派发与集中式错误处理。
/// 取代 legacy-ts/src/mcp/server.ts L57-290。
///
/// 前 7 个与 legacy-ts/package.json 的 `mcp.tools` 逐项同序；
/// 后 3 个（create / list / delete_sub_agent）是 v2.1 子 Agent 工厂新增，
/// 无 legacy 对应物（见 docs/subagent-factory.md）；
/// 再后 3 个（analyze_plugins / evolve_plugin / manage_sub_agent）是 v2.3 合并工具。
///
/// **CONTEXT.md 不变量④在此落地**：工具 handler 内部**一个 try/catch 都不写**，
/// 错误统一由 `call_tool` 这一处包装器转成标准的 `isError` 响应。
/// 这与 TS 版 `defineTool`（L103-122）的结构一致，但从「每个工具注册时套一层闭包」
/// 变成「派发表外侧单点处理」，少了 7 层闭包分配。
///
/// 顺带修掉一处**配置孤岛**：TS 的 `scan_plugins` schema 声明了 `target_paths`
/// 参数（server.ts L29），但 handler（L131）只把 `force_rescan` 传给 scanner，
/// `target_paths` 从未被使用。新版让它真正生效。

///|
/// 服务状态。持有全部子系统，以及 `scan_plugins` 填充的插件注册表。
pub struct ServerState {
  paths : @store.DataPaths
  scanner : @scanner.PluginScanner
  monitor : @monitor.PerformanceMonitor
  engine : @engine.EvolutionEngine
  executor : @executor.UpgradeExecutor
  proposals : @store.ProposalStore
  /// 子 Agent 工厂（v2.1）：管理 plugin / user 两个作用域的定义文件
  factory : @factory.AgentFactory
  /// 插件注册表（对应 server.ts L81 的 `pluginRegistry`）。
  /// 用 `Array` 作事实来源、`Map` 只作 id → 下标索引（决策 D10）：
  /// TS 靠 JS Map 的插入序保证 `Array.from(plugins.values())`（L137）的顺序稳定，
  /// MoonBit 的 Map 是哈希表、迭代序不定，照搬会让每次响应顺序都不同。
  registry : Array[@types.PluginMetadata]
  registry_index : Map[String, Int]
}

///|
/// 用 `DataPaths` 装配整套子系统（生产路径，扫描根取机器默认值）。
pub fn ServerState::at(
  paths : @store.DataPaths,
  config? : @types.EngineConfig = @types.EngineConfig::default(),
) -> ServerState {
  ServerState::with_scan_config(paths, @scanner.ScanConfig::at(paths), config~)
}

///|
/// 用**显式扫描配置**装配 —— 测试与多档案场景的 DI 缝。
///
/// 为什么需要它：`ServerState::at` 的扫描根来自 `default_scan_roots()`
/// （真实机器上的 zcode 插件缓存），端到端用例无法把它指向 `@fs.tmpdir`，
/// 于是「scan → propose → approve → execute → list」这条主链路只能靠手测。
/// 把「数据目录」与「扫描根」两个关注点拆开后，整条链路可以在完全隔离的
/// 临时目录里跑完，`moon test` 就是它的反馈环。
///
/// ★ **`ProposalStore` 只构造一次**，engine / executor / 工具三方共享同一个实例
/// （对应 server.ts L89-94 的注释 "Single source of truth shared by engine,
/// executor and the tools below"）。这是 CONTEXT.md 不变量②的物理保证：
/// 若各自 `ProposalStore::at(paths)`，三个实例的内存索引会互相看不见对方的写入，
/// 状态机校验也就形同虚设。
pub fn ServerState::with_scan_config(
  paths : @store.DataPaths,
  scan : @scanner.ScanConfig,
  config? : @types.EngineConfig = @types.EngineConfig::default(),
) -> ServerState {
  let proposals = @store.ProposalStore::at(paths)
  let monitor = @monitor.PerformanceMonitor::at(paths, config~)
  {
    paths,
    scanner: @scanner.PluginScanner::new(scan),
    monitor,
    engine: @engine.EvolutionEngine::new(
      monitor,
      proposals,
      @store.Jsonl::new(paths.signals()),
      config,
    ),
    executor: @executor.UpgradeExecutor::new(
      proposals,
      @store.ExecutionLog::at(paths),
    ),
    proposals,
    factory: @factory.AgentFactory::at(paths),
    registry: [],
    registry_index: Map([]),
  }
}

///|
/// 用 `HarnessConfig` 装配 —— 接受完整配置（含 monitoring 段）。
///
/// 与 `with_scan_config` 的区别：本构造器接受 `HarnessConfig`，
/// 内部提取 `engine` 配置传递给 monitor/engine，
/// 并将 `monitoring` 配置记录在日志中（当前无消费方，见已知缺陷 #9）。
/// 向后兼容：`with_scan_config` 和 `at` 仍然工作，内部使用默认 `EngineConfig`。
pub fn ServerState::with_harness_config(
  paths : @store.DataPaths,
  scan : @scanner.ScanConfig,
  harness_cfg : @types.HarnessConfig,
) -> ServerState {
  let proposals = @store.ProposalStore::at(paths)
  let monitor = @monitor.PerformanceMonitor::at(paths, config=harness_cfg.engine)
  {
    paths,
    scanner: @scanner.PluginScanner::new(scan),
    monitor,
    engine: @engine.EvolutionEngine::new(
      monitor,
      proposals,
      @store.Jsonl::new(paths.signals()),
      harness_cfg.engine,
    ),
    executor: @executor.UpgradeExecutor::new(
      proposals,
      @store.ExecutionLog::at(paths),
    ),
    proposals,
    factory: @factory.AgentFactory::at(paths),
    registry: [],
    registry_index: Map([]),
  }
}

///|
/// 按 id 查注册表。
pub fn ServerState::find_plugin(
  self : ServerState,
  plugin_id : String,
) -> @types.PluginMetadata? {
  match self.registry_index.get(plugin_id) {
    Some(i) => Some(self.registry[i])
    None => None
  }
}

///|
/// 把周期性 flush 挂到入口的 task group 上，**并返回其 Task 句柄**。
///
/// 返回句柄是必需的：`with_task_group` 会等全部子任务结束才退出，
/// 而 flush 循环永不自行结束。入口必须在 stdin EOF 后 `cancel()` 它，
/// 否则进程挂死（宿主永远收不到退出）。详见 monitor 里 `run_flush_loop` 的注释。
///
/// 提供这个方法而不让 main 直接读 `state.monitor`，是为了让 `ServerState`
/// 的字段保持包内私有 —— 入口只需要「启动后台循环」与「收尾」两个动作，
/// 不需要知道背后是哪个子系统在做。
pub fn ServerState::run_background_tasks(
  self : ServerState,
  group : @async.TaskGroup[Unit],
) -> @async.Task[Unit] {
  self.monitor.run_flush_loop(group)
}

///|
/// 关停前的最后一次落盘。幂等（缓冲已空时为 no-op），
/// 故即使 task group 的 `add_defer` 已经跑过也无害。
pub async fn ServerState::shutdown(self : ServerState) -> Unit {
  self.monitor.shutdown()
}

///|
/// 用扫描结果重建注册表（全量替换）。
fn ServerState::adopt(
  self : ServerState,
  profiles : ArrayView[@types.PluginMetadata],
) -> Unit {
  self.registry.clear()
  self.registry_index.clear()
  for p in profiles {
    let i = self.registry.length()
    self.registry.push(p)
    self.registry_index.set(p.plugin_id, i)
  }
}

///|
/// 合并扫描结果到注册表（增量更新）。
/// 已存在的 plugin_id 被更新，不存在的被追加。
/// 用于 `plugin_ids` 定向重扫场景：只更新命中的插件，不影响其他已缓存的。
fn ServerState::merge(
  self : ServerState,
  profiles : ArrayView[@types.PluginMetadata],
) -> Unit {
  for p in profiles {
    match self.registry_index.get(p.plugin_id) {
      Some(i) => {
        // 更新已有条目
        self.registry[i] = p
      }
      None => {
        // 追加新条目
        let i = self.registry.length()
        self.registry.push(p)
        self.registry_index.set(p.plugin_id, i)
      }
    }
  }
}

///|
/// 一个 MCP 工具。
pub struct Tool {
  name : String
  description : String
  schema : Json
  /// handler **不得**写 try/catch（不变量④）：
  /// 抛出的任何错误都由 `call_tool` 统一转成 isError 响应。
  handler : async (ServerState, Json) -> Json
}

// ----------------------------------------------------------------------------
// 统一的返回体形状（对应 server.ts L57-72 的 jsonOk / jsonError）
// ----------------------------------------------------------------------------

///|
/// 成功返回体。`text` 用 `indent=2` 渲染，与 TS L64 的
/// `JSON.stringify(value, null, 2)` 逐字节对齐（决策 D14）。
pub fn json_ok(value : Json) -> Json {
  {
    "content": Json::array([
      { "type": "text", "text": Json::string(value.stringify(indent=2)) },
    ]),
  }
}

///|
/// 错误返回体。形状与 TS L67-72 一致：`isError: true` +
/// 一段 `{"success":false,"error":...}` 的 JSON 文本。
pub fn json_error(message : String) -> Json {
  // 必须显式标注 `: Json`：否则 `{ "success": false, ... }` 会被当成
  // struct 字面量推断（工具链报 "Type Map[String, Bool] has no method stringify"）。
  let body : Json = { "success": false, "error": Json::string(message) }
  {
    "content": Json::array([
      { "type": "text", "text": Json::string(body.stringify(indent=2)) },
    ]),
    "isError": true,
  }
}

///|
/// ★ 全仓**唯一**的工具错误处理点（不变量④）。
///
/// 一处 try/catch 覆盖三类失败：
/// · 参数解码失败（`@json.JsonDecodeError`，如缺必填字段、枚举取值非法）
/// · 业务错误（handler 主动 `raise Failure(...)`，如插件/提案不存在）
/// · 任何未预期错误
///
/// 这层兜底还有一条硬理由：native 后端下**未捕获异常的信息会被打到 stdout**
/// （Phase 0 门禁实测），而 stdout 是 MCP 的协议通道 —— 让异常逃出去
/// 等于直接污染协议流。
///
/// ★★ **为何必须对错误构造器做模式匹配，而不能直接用 `e.to_string()`**：
/// `Error::to_string` 会带上构造器名 —— `raise Failure("x")` 得到的是
/// `"Failure(x)"` 而不是 `"x"`。而 legacy 对外暴露的是**裸消息**
/// （server.ts L114-118 的 `error instanceof Error ? error.message : String(error)`）。
/// 两处 legacy 测试直接按裸消息断言，包一层就全部对不上：
/// · server.ts L173 "Plugin not found: X. Run scan_plugins first."
/// · store/index.ts L147 "Illegal proposal status transition: a → b"
///   （legacy tests/executor.test.ts L166-171 就是按这个串断言的）
/// MoonBit 的 catch 块允许对错误构造器做模式匹配（实测），
/// 但**只能匹配该 try 体声明过的 raise 类型** —— 匹配不在集合里的构造器
/// 会报 "Constr Type Mismatch"，所以下面三个分支缺一不可。
pub async fn call_tool(state : ServerState, tool : Tool, args : Json) -> Json {
  let outcome : Result[Json, String] = Ok(
    // 函数型字段必须加括号调用：`tool.handler(..)` 会被当成方法查找
    // 而报 "Type Tool has no method handler"。
    (tool.handler)(state, args),
  ) catch {
    // 业务错误走内置 `Failure`（携带一个 String）—— 取出裸消息
    Failure(message) => Err(message)
    // 参数解码失败：载荷是 (路径, 消息) 二元组。
    // 丢掉路径只留消息：路径对 LLM 没有价值，而消息里已经带了
    // 「expected one of: ...」的合法值列表（wire 表的第三处消费，
    // 见 util/wire.mbt 的头注释）。
    @json.JsonDecodeError((_, message)) => Err("Invalid arguments: \{message}")
    // 其余任何未预期错误：保留完整信息用于诊断
    e => Err(e.to_string())
  }
  match outcome {
    Ok(value) => json_ok(value)
    Err(message) => {
      // 对齐 server.ts L117 的日志文案
      @util.log_error("Server", "Tool \{tool.name} failed: \{message}")
      json_error(message)
    }
  }
}

// ----------------------------------------------------------------------------
// 13 个工具（前 7 个与 legacy-ts/package.json mcp.tools 逐项同序，
// 后 3 个为 2.1 子 Agent 工厂新增，再后 3 个为 2.3 合并工具）
// ----------------------------------------------------------------------------

///|
/// 全部工具，顺序即 `tools/list` 的返回顺序。
/// 名字与 legacy-ts/package.json L58-66 的 `mcp.tools` 列表逐项、同序一致
/// （前 7 个）；后 3 个为 v2.1 新增，追加在 legacy 顺序之后。
pub fn tools() -> Array[Tool] {
  [
    {
      name: "scan_plugins",
      description: "扫描 harness 插件并建立档案。支持三种模式：定向重扫（plugin_ids 只扫描指定插件的目录）、路径重定向（target_paths 自定义扫描路径）、全量扫描（默认扫描所有配置的根目录）。返回发现的插件列表及其元数据。",
      schema: scan_plugins_schema(),
      handler: handle_scan_plugins,
    },
    {
      name: "get_plugin_metrics",
      description: "获取指定插件的性能指标，包括调用次数、成功率、延迟、Token 消耗等。",
      schema: get_metrics_schema(),
      handler: handle_get_plugin_metrics,
    },
    {
      name: "propose_evolution",
      description: "为指定插件生成进化提案。基于性能数据和信号，应用 Matt Pocock 工程原则生成优化建议。",
      schema: propose_evolution_schema(),
      handler: handle_propose_evolution,
    },
    {
      name: "execute_evolution",
      description: "执行已审批的进化提案。协调 Sub-Agent 完成代码生成、测试、文档更新和验证。",
      schema: execute_evolution_schema(),
      handler: handle_execute_evolution,
    },
    {
      name: "list_proposals",
      description: "列出所有进化提案，可按状态和插件过滤。",
      schema: list_proposals_schema(),
      handler: handle_list_proposals,
    },
    {
      name: "approve_proposal",
      description: "批准一个进化提案，使其可以被执行。",
      schema: proposal_id_schema(),
      handler: handle_approve_proposal,
    },
    {
      name: "reject_proposal",
      description: "拒绝一个进化提案。",
      schema: proposal_id_schema(),
      handler: handle_reject_proposal,
    },
    {
      name: "create_sub_agent",
      description: "创建一个子 Agent 定义文件（Markdown + YAML frontmatter，含名称、职责描述与系统提示词）。scope=plugin 写入插件数据目录（默认）；scope=user 会写入宿主的 ~/.zcode/agents/——这跨出插件数据根，宿主会在后续会话中加载该定义，其内容将成为可被调用的 agent 系统提示词。注意：创建只是产出定义文件，不等于立即派发执行，宿主何时加载由宿主决定。插件自带的 5 个出厂角色模板随插件 agents/ 目录分发，不在本工具的两个可写目录内。",
      schema: create_sub_agent_schema(),
      handler: handle_create_sub_agent,
    },
    {
      name: "list_sub_agents",
      description: "列出子 Agent 定义。scope 缺省时同时列出插件数据目录与宿主用户目录（~/.zcode/agents/）两个作用域；每项含名称、描述、可选的 color/tools、作用域与路径。解析失败的文件会被跳过并在日志告警，不影响其余条目。",
      schema: list_sub_agents_schema(),
      handler: handle_list_sub_agents,
    },
    {
      name: "delete_sub_agent",
      description: "删除一个子 Agent 定义文件。只删除两个可写目录（插件数据目录的 agents/、宿主的 ~/.zcode/agents/）里的定义；插件自带的出厂模板不在这两个目录内，天然不受本工具影响。scope 缺省为 plugin。",
      schema: delete_sub_agent_schema(),
      handler: handle_delete_sub_agent,
    },
    // v2.3 合并工具（推荐使用）
    {
      name: "analyze_plugins",
      description: "分析插件：扫描并/或获取性能指标。mode=scan 仅扫描，mode=metrics 仅获取指标，mode=both 两者都做。支持 plugin_ids 定向重扫和 target_paths 路径重定向。",
      schema: analyze_plugins_schema(),
      handler: handle_analyze_plugins,
    },
    {
      name: "evolve_plugin",
      description: "进化插件：生成或执行进化提案。action=propose 生成提案，action=execute 执行已审批的提案。",
      schema: evolve_plugin_schema(),
      handler: handle_evolve_plugin,
    },
    {
      name: "manage_sub_agent",
      description: "管理子 Agent：创建、列出或删除定义。action=create 创建，action=list 列出，action=delete 删除。",
      schema: manage_sub_agent_schema(),
      handler: handle_manage_sub_agent,
    },
  ]
}

///|
/// 按名字找工具。O(n) 但 n == 13，比维护一张 Map 更直白。
pub fn find_tool(name : String) -> Tool? {
  for t in tools() {
    if t.name == name {
      return Some(t)
    }
  }
  None
}

///|
/// `tools/list` 的响应体。不分页（省略 `nextCursor`）—— 13 个工具远小于任何客户端的页大小。
pub fn tools_list_result() -> Json {
  let list : Array[Json] = []
  for t in tools() {
    list.push({
      "name": Json::string(t.name),
      "description": Json::string(t.description),
      "inputSchema": t.schema,
    })
  }
  { "tools": Json::array(list) }
}

// ----------------------------------------------------------------------------
// handler 实现
// ----------------------------------------------------------------------------

///|
/// `scan_plugins`（对应 server.ts L126-147）。
///
/// 三种扫描模式（用户自主决策，非硬编码全盘扫描）：
/// 1. **定向重扫**（`plugin_ids`）：只扫描包含指定插件的目录，其他已缓存插件保留
/// 2. **路径重定向**（`target_paths`）：扫描指定路径替换默认扫描根
/// 3. **全量扫描**（默认）：扫描所有配置的根目录
///
/// `force_rescan` 控制缓存行为：
/// - `false`（默认）：利用缓存跳过未变化的插件
/// - `true`：忽略缓存，强制完整重扫
async fn handle_scan_plugins(state : ServerState, args : Json) -> Json {
  let a : ScanPluginsArgs = @json.from_json(args)
  let force = a.force_rescan.unwrap_or(default_force_rescan)

  // 模式 1：定向重扫 —— 只扫描包含指定 plugin_ids 的目录
  match a.plugin_ids {
    Some(ids) if !ids.is_empty() => {
      // 从注册表和缓存中查找 plugin_id → 目录的映射
      let target_dirs : Array[String] = []
      for pid in ids {
        let mut found = false
        for entry in state.registry {
          if entry.plugin_id == pid {
            target_dirs.push(entry.path)
            found = true
            break
          }
        }
        if !found {
          // 注册表里没有，尝试从缓存查找
          for entry in state.scanner.cache_entries() {
            if entry.profile.plugin_id == pid {
              target_dirs.push(entry.profile.path)
              found = true
              break
            }
          }
        }
        if !found {
          @util.log_warn("Scanner", "插件 \{pid} 不在注册表或缓存中，跳过定向重扫")
        }
      }

      if target_dirs.is_empty() {
        return {
          "success": Json::boolean(true),
          "message": Json::string("所有指定的 plugin_ids 均未找到，无目录可扫描"),
          "plugin_count": Json::number(state.registry.length().to_double()),
          "plugins": Json::array([]),
        }
      }

      // 用独立 scanner 扫描目标目录（不影响主缓存）；
      // force 尊重客户端传入的 force_rescan，定向重扫不再无条件强制
      let tmp_cache = "\{state.paths.plugin_cache()}.incremental"
      let scanner = @scanner.PluginScanner::new(
        @scanner.ScanConfig::custom(target_dirs, tmp_cache),
      )
      scanner.scan_all(force_rescan=force)
      // merge 模式：不清除已有注册表条目，只更新命中的插件
      state.merge(scanner.all())

      @util.log_info(
        "Scanner",
        "Incremental rescan: \{ids.length()} plugin_ids → \{target_dirs.length()} dirs → \{scanner.count()} plugins",
      )
    }
    _ => {
      // 模式 2：路径重定向
      match a.target_paths {
        Some(custom) if !custom.is_empty() => {
          let scanner = @scanner.PluginScanner::new(
            @scanner.ScanConfig::custom(custom, state.paths.plugin_cache()),
          )
          scanner.scan_all(force_rescan=force)
          state.adopt(scanner.all())
        }
        _ => {
          // 模式 3：全量扫描
          state.scanner.scan_all(force_rescan=force)
          state.adopt(state.scanner.all())
        }
      }
    }
  }

  let plugins : Array[Json] = []
  for p in state.registry {
    plugins.push({
      "plugin_id": Json::string(p.plugin_id),
      "name": Json::string(p.name),
      "version": Json::string(p.version),
      // 响应里的键名仍是 `type`（不是 `kind`）：这是对外契约，
      // 与 TS L141 一致，改它会让既有客户端读不到字段。
      "type": ToJson::to_json(p.kind),
      "capabilities": ToJson::to_json(p.capabilities),
      "tools_count": Json::number(p.tools.length().to_double()),
    })
  }
  {
    "success": true,
    "plugin_count": Json::number(state.registry.length().to_double()),
    "plugins": Json::array(plugins),
  }
}

///|
/// `get_plugin_metrics`（对应 server.ts L150-163）。
/// 字段顺序对齐 legacy-ts/src/monitor/index.ts L204-212 的返回对象。
async fn handle_get_plugin_metrics(state : ServerState, args : Json) -> Json {
  let a : GetMetricsArgs = @json.from_json(args)
  let range = a.time_range.unwrap_or(default_time_range)
  let stats = state.monitor.get_statistics(a.plugin_id, time_range=range)
  {
    "success": true,
    "plugin_id": Json::string(a.plugin_id),
    "time_range": ToJson::to_json(range),
    "statistics": {
      "total_calls": Json::number(stats.total_calls.to_double()),
      "success_rate": Json::number(stats.success_rate),
      "avg_latency_ms": Json::number(stats.avg_latency_ms),
      "total_tokens": Json::number(stats.total_tokens.to_double()),
      "avg_retry_count": Json::number(stats.avg_retry_count),
      "error_types": stats.error_types_object(),
      "loop_detected": Json::boolean(stats.loop_detected),
    },
  }
}

///|
/// `propose_evolution`（对应 server.ts L166-213）。
///
/// 三条返回路径与 TS 一一对应：
/// · 插件不在注册表 → isError，消息含 "Run scan_plugins first."（TS L173）
/// · 没有产出提案 → `success: true` + message（TS L194-199，**不是** error）
/// · 产出/复用提案 → `success: true` + proposal 摘要（TS L201-211）
async fn handle_propose_evolution(state : ServerState, args : Json) -> Json {
  let a : ProposeEvolutionArgs = @json.from_json(args)
  let plugin = match state.find_plugin(a.plugin_id) {
    Some(p) => p
    // 抛错即走 call_tool 的 isError 路径，消息与 TS L173 逐字一致
    None =>
      raise Failure("Plugin not found: \{a.plugin_id}. Run scan_plugins first.")
  }

  // 手动提供的信号描述 → strong/pattern 信号（对应 TS L177-186）
  // F5 修复：手动信号原为 Medium，被默认50%强度过滤掉。
  // 用户显式请求提案时，强度门控不应阻止，故升级为 Strong。
  let manual : Array[@types.EvolutionSignal]? = match a.signals {
    Some(descriptions) => {
      let now = @util.now_ms()
      let out : Array[@types.EvolutionSignal] = []
      for description in descriptions {
        out.push({
          strength: @types.SignalStrength::Strong,
          category: @types.SignalCategory::Pattern,
          description,
          evidence: @types.Evidence::UserManual,
          ts: now,
          plugin_id: a.plugin_id,
          count: None,
          tool: None,
          decay_factor: 1.0,
        })
      }
      Some(out)
    }
    None => None
  }

  let outcome = state.engine.generate_proposal(plugin, signals=manual)
  match outcome.proposal() {
    None =>
      {
        "success": true,
        // 原文案逐字保留（TS L197），另加一个 reason 字段说清到底是哪种原因 ——
        // 这正是 ProposalOutcome 枚举相对 `null` 的价值。新增字段是**追加**，
        // 不改动既有字段，故对既有客户端完全兼容。
        "message": "No evolution proposal generated (insufficient signals, cooldown, or duplicate)",
        "reason": Json::string(outcome.reason()),
      }
    Some(p) =>
      {
        "success": true,
        "proposal": {
          "proposal_id": Json::string(p.proposal_id),
          "evolution_type": ToJson::to_json(p.evolution_type),
          "matt_pocock_principle": ToJson::to_json(p.matt_pocock_principle),
          "confidence": ToJson::to_json(p.confidence),
          "expected_benefits": ToJson::to_json(p.expected_benefits),
          "status": ToJson::to_json(p.status),
        },
      }
  }
}

///|
/// `execute_evolution`（对应 server.ts L216-234）。
async fn handle_execute_evolution(state : ServerState, args : Json) -> Json {
  let a : ExecuteEvolutionArgs = @json.from_json(args)
  let dry_run = a.dry_run.unwrap_or(default_dry_run)
  let result = state.executor.execute(a.proposal_id, dry_run~)

  let items : Array[Json] = []
  for r in result.results {
    let base : Json = {
      "agent": ToJson::to_json(r.agent),
      "success": Json::boolean(r.success),
      "duration_ms": Json::number(r.duration_ms.to_double()),
    }
    // TS L229 把 `error: undefined` 交给 JSON.stringify，键会被省略；
    // 这里显式复刻该行为（None → 不写这个键，而不是写 null）。
    items.push(
      match r.error {
        Some(msg) => with_key(base, "error", Json::string(msg))
        None => base
      },
    )
  }
  let body : Json = {
    "success": Json::boolean(result.success),
    "proposal_id": Json::string(a.proposal_id),
    "results": Json::array(items),
  }
  match result.error {
    Some(msg) =>
      // 追加 error 键（TS L231 也是「有则写、无则省略」）
      with_key(body, "error", Json::string(msg))
    None => body
  }
}

///|
/// 往一个 JSON 对象上追加一个键，返回**新**对象。
///
/// 不用 `Map::copy`（本工具链的可用性未经验证），而是逐项重建 ——
/// 对象规模只有几个键，重建成本可忽略，且不引入对未核实 API 的依赖。
fn with_key(json : Json, key : String, value : Json) -> Json {
  let obj : Map[String, Json] = Map([])
  match json {
    Object(existing) =>
      for pair in existing {
        let (k, v) = pair
        obj.set(k, v)
      }
    _ => ()
  }
  obj.set(key, value)
  Json::object(obj)
}

///|
/// `list_proposals`（对应 server.ts L237-261）。
async fn handle_list_proposals(state : ServerState, args : Json) -> Json {
  let a : ListProposalsArgs = @json.from_json(args)
  let filter : @store.ProposalFilter = {
    status: a.status,
    plugin_id: a.plugin_id,
    limit: Some(a.limit.unwrap_or(default_limit)),
  }
  let proposals = state.proposals.list(filter)

  let items : Array[Json] = []
  for p in proposals {
    items.push({
      "proposal_id": Json::string(p.proposal_id),
      "plugin_id": Json::string(p.plugin_id),
      "evolution_type": ToJson::to_json(p.evolution_type),
      "status": ToJson::to_json(p.status),
      // 内部表示是 Int64 毫秒，但**对外仍输出 ISO-8601 字符串**：
      // TS L256 返回的就是 `created_at` 原文（ISO 串），保持响应形状不变，
      // 而且 ISO 串对读它的人和 LLM 都更有用。
      "created_at": Json::string(@util.iso_utc(p.created_at)),
      "confidence": ToJson::to_json(p.confidence),
    })
  }
  {
    "success": true,
    "count": Json::number(proposals.length().to_double()),
    "proposals": Json::array(items),
  }
}

///|
/// `approve_proposal`（对应 server.ts L264-275）。
///
/// 非法状态迁移会由 `ProposalStore.set_status` 抛出，
/// 经 `call_tool` 变成 isError 响应 —— handler 自己不写 try/catch（不变量④）。
async fn handle_approve_proposal(state : ServerState, args : Json) -> Json {
  let a : ProposalIdArgs = @json.from_json(args)
  let updated = state.proposals.set_status(
    a.proposal_id,
    @types.ProposalStatus::Approved,
  )
  if !updated {
    raise Failure("Proposal not found: \{a.proposal_id}")
  }
  {
    "success": true,
    "message": Json::string("Proposal \{a.proposal_id} approved"),
  }
}

///|
/// `reject_proposal`（对应 server.ts L278-289）。
async fn handle_reject_proposal(state : ServerState, args : Json) -> Json {
  let a : ProposalIdArgs = @json.from_json(args)
  let updated = state.proposals.set_status(
    a.proposal_id,
    @types.ProposalStatus::Rejected,
  )
  if !updated {
    raise Failure("Proposal not found: \{a.proposal_id}")
  }
  {
    "success": true,
    "message": Json::string("Proposal \{a.proposal_id} rejected"),
  }
}

// ----------------------------------------------------------------------------
// v2.1 新增：子 Agent 工厂的 3 个 handler
// （业务失败一律 raise Failure，由 call_tool 统一转 isError —— 不变量④）
// ----------------------------------------------------------------------------

///|
/// `create_sub_agent`（v2.1）。
///
/// tools 传出的**空数组按未指定处理**（与 factory 的语义一致），
/// scope 缺省 plugin，overwrite 缺省 false —— 已存在时 raise，
/// 消息含 "already exists"，LLM 可据此决定是否带 overwrite=true 重试。
async fn handle_create_sub_agent(state : ServerState, args : Json) -> Json {
  let a : CreateSubAgentArgs = @json.from_json(args)
  let def : @factory.AgentDefinition = {
    name: a.name,
    description: a.description,
    system_prompt: a.system_prompt,
    tools: a.tools.unwrap_or([]),
    color: a.color,
  }
  let scope = a.scope.unwrap_or(default_sub_agent_scope)
  let overwrite = a.overwrite.unwrap_or(default_sub_agent_overwrite)
  let (path, overwritten) = state.factory.create(def, scope, overwrite~)
  {
    "success": true,
    "path": Json::string(path),
    "name": Json::string(a.name),
    "scope": ToJson::to_json(scope),
    "overwritten": Json::boolean(overwritten),
  }
}

///|
/// `list_sub_agents`（v2.1）。
///
/// scope 缺省 = 两个作用域都列。color / tools 是可选字段：
/// 有才写键、无则省略 —— 复用 `with_key`（对齐 execute_evolution 的风格，
/// None → 不写这个键而不是写 null）。
async fn handle_list_sub_agents(state : ServerState, args : Json) -> Json {
  let a : ListSubAgentsArgs = @json.from_json(args)
  let found = state.factory.list(a.scope)
  let items : Array[Json] = []
  for entry in found {
    let (scope, def, path) = entry
    let base : Json = {
      "name": Json::string(def.name),
      "description": Json::string(def.description),
    }
    let with_color = match def.color {
      Some(c) => with_key(base, "color", Json::string(c))
      None => base
    }
    let with_tools = if def.tools.length() > 0 {
      with_key(with_color, "tools", ToJson::to_json(def.tools))
    } else {
      with_color
    }
    let with_scope = with_key(with_tools, "scope", ToJson::to_json(scope))
    items.push(with_key(with_scope, "path", Json::string(path)))
  }
  {
    "success": true,
    "count": Json::number(found.length().to_double()),
    "agents": Json::array(items),
  }
}

///|
/// `delete_sub_agent`（v2.1）。scope 缺省 plugin；
/// 名字不存在时 factory.delete raise（消息含 "not found"）→ isError。
async fn handle_delete_sub_agent(state : ServerState, args : Json) -> Json {
  let a : DeleteSubAgentArgs = @json.from_json(args)
  let scope = a.scope.unwrap_or(default_sub_agent_scope)
  let deleted = state.factory.delete(a.name, scope)
  {
    "success": true,
    "name": Json::string(a.name),
    "scope": ToJson::to_json(scope),
    "deleted": Json::string(deleted),
  }
}

// ----------------------------------------------------------------------------
// 消息派发
// ----------------------------------------------------------------------------

// v2.3 合并工具的 handler
// 这些工具通过构造对应的参数 JSON 来委托给现有的 handler 实现，
// 避免重复代码并保持向后兼容性。
// ----------------------------------------------------------------------------

///|
/// `analyze_plugins`（v2.3 合并工具）。
/// 合并了 `scan_plugins` 和 `get_plugin_metrics` 的功能。
/// mode="scan" 执行扫描，mode="metrics" 获取指标，mode="both" 两者都做。
async fn handle_analyze_plugins(state : ServerState, args : Json) -> Json {
  let a : AnalyzePluginsArgs = @json.from_json(args)
  // mode 缺省取 schema 声明的默认值（default_analyze_mode，唯一定义处），
  // 再经 wire 表归一成枚举：未知取值在此 raise，而不是静默返回成功形状。
  let mode_name = a.mode.unwrap_or(default_analyze_mode.wire_name())
  let mode = match @types.scan_mode_wire.find_by_name(mode_name) {
    Some(m) => m
    None =>
      raise Failure(
        "Unknown mode: \{mode_name}. Use one of: \{@types.scan_mode_wire.names().join(", ")}.",
      )
  }

  // scan / both 模式：委托给 handle_scan_plugins
  match mode {
    @types.ScanMode::Scan | @types.ScanMode::Both => {
      let force_val = a.force_rescan.unwrap_or(default_force_rescan)
      // 按参数组合构建 scan_args
      let has_ids = match a.plugin_ids {
        Some(ids) if !ids.is_empty() => true
        _ => false
      }
      let has_paths = match a.target_paths {
        Some(ps) if !ps.is_empty() => true
        _ => false
      }
      let scan_args : Json = if has_ids && has_paths {
        {
          "force_rescan": Json::boolean(force_val),
          "plugin_ids": Json::array(a.plugin_ids.unwrap().map(fn(s) { Json::string(s) })),
          "target_paths": Json::array(a.target_paths.unwrap().map(fn(s) { Json::string(s) })),
        }
      } else if has_ids {
        {
          "force_rescan": Json::boolean(force_val),
          "plugin_ids": Json::array(a.plugin_ids.unwrap().map(fn(s) { Json::string(s) })),
        }
      } else if has_paths {
        {
          "force_rescan": Json::boolean(force_val),
          "target_paths": Json::array(a.target_paths.unwrap().map(fn(s) { Json::string(s) })),
        }
      } else {
        { "force_rescan": Json::boolean(force_val) }
      }
      ignore(handle_scan_plugins(state, scan_args))
    }
    @types.ScanMode::Metrics => ()
  }

  // metrics / both 模式：委托给 handle_get_plugin_metrics
  match mode {
    @types.ScanMode::Metrics | @types.ScanMode::Both =>
      // metrics 与 both 对缺 plugin_id 一致报错：both 静默跳过指标
      // 会让调用方把「扫描成功」误当成「全部完成」。
      match a.plugin_id {
        Some(plugin_id) => {
          let metrics_args : Json = {
            "plugin_id": Json::string(plugin_id),
            "time_range": Json::string(a.time_range.unwrap_or(default_time_range).wire_name()),
          }
          return handle_get_plugin_metrics(state, metrics_args)
        }
        None => raise Failure("plugin_id is required for metrics/both mode")
      }
    @types.ScanMode::Scan => ()
  }

  // scan 模式返回扫描结果
  let plugins : Array[Json] = []
  for p in state.registry {
    plugins.push({
      "plugin_id": Json::string(p.plugin_id),
      "name": Json::string(p.name),
      "version": Json::string(p.version),
    })
  }
  { "plugins": Json::array(plugins) }
}

///|
/// `evolve_plugin`（v2.3 合并工具）。
/// 合并了 `propose_evolution` 和 `execute_evolution` 的功能。
/// action="propose" 生成提案，action="execute" 执行提案。
async fn handle_evolve_plugin(state : ServerState, args : Json) -> Json {
  let a : EvolvePluginArgs = @json.from_json(args)
  // action 缺省取 schema 声明的默认值（default_evolve_action，唯一定义处），
  // 再经 wire 表归一成枚举：未知取值在此 raise。
  let action_name = a.action.unwrap_or(default_evolve_action.wire_name())
  let action = match @types.evolve_action_wire.find_by_name(action_name) {
    Some(x) => x
    None =>
      raise Failure(
        "Unknown action: \{action_name}. Use one of: \{@types.evolve_action_wire.names().join(", ")}.",
      )
  }

  match action {
    @types.EvolveAction::Propose =>
      match a.plugin_id {
        Some(plugin_id) => {
          // signals 已声明就透传，委托时不得丢弃；无则省键（None → 不写 null）
          let base : Json = { "plugin_id": Json::string(plugin_id) }
          let propose_args = match a.signals {
            Some(sig) =>
              with_key(
                base, "signals", Json::array(sig.map(fn(s) { Json::string(s) })),
              )
            None => base
          }
          return handle_propose_evolution(state, propose_args)
        }
        None => raise Failure("plugin_id is required for propose action")
      }
    @types.EvolveAction::Execute =>
      match a.proposal_id {
        Some(proposal_id) => {
          let execute_args : Json = {
            "proposal_id": Json::string(proposal_id),
            "dry_run": Json::boolean(a.dry_run.unwrap_or(default_dry_run)),
          }
          return handle_execute_evolution(state, execute_args)
        }
        None => raise Failure("proposal_id is required for execute action")
      }
  }
}

///|
/// `manage_sub_agent`（v2.3 合并工具）。
/// 合并了 `create_sub_agent`、`list_sub_agents` 和 `delete_sub_agent` 的功能。
/// action="create" 创建，action="list" 列出，action="delete" 删除。
async fn handle_manage_sub_agent(state : ServerState, args : Json) -> Json {
  let a : ManageSubAgentArgs = @json.from_json(args)
  // action 缺省取 schema 声明的默认值（default_manage_action，唯一定义处），
  // 再经 wire 表归一成枚举：未知取值在此 raise。
  let action_name = a.action.unwrap_or(default_manage_action.wire_name())
  let action = match @types.manage_action_wire.find_by_name(action_name) {
    Some(x) => x
    None =>
      raise Failure(
        "Unknown action: \{action_name}. Use one of: \{@types.manage_action_wire.names().join(", ")}.",
      )
  }

  match action {
    @types.ManageAction::Create =>
      match (a.name, a.description, a.system_prompt) {
        (Some(name), Some(description), Some(system_prompt)) => {
          let base : Json = {
            "name": Json::string(name),
            "description": Json::string(description),
            "system_prompt": Json::string(system_prompt),
            "scope": Json::string(a.scope.unwrap_or(default_sub_agent_scope).wire_name()),
            "overwrite": Json::boolean(a.overwrite.unwrap_or(default_sub_agent_overwrite)),
          }
          // color / tools 已声明就透传，委托时不得丢弃；无则省键（None → 不写 null）
          let with_color = match a.color {
            Some(c) => with_key(base, "color", Json::string(c))
            None => base
          }
          let create_args = match a.tools {
            Some(t) =>
              with_key(
                with_color, "tools", Json::array(t.map(fn(s) { Json::string(s) })),
              )
            None => with_color
          }
          return handle_create_sub_agent(state, create_args)
        }
        _ => raise Failure("name, description, and system_prompt are required for create action")
      }
    @types.ManageAction::List => {
      let list_args : Json = Json::empty_object()
      return handle_list_sub_agents(state, list_args)
    }
    @types.ManageAction::Delete =>
      match a.name {
        Some(name) => {
          let delete_args : Json = {
            "name": Json::string(name),
            "scope": Json::string(a.scope.unwrap_or(default_sub_agent_scope).wire_name()),
          }
          return handle_delete_sub_agent(state, delete_args)
        }
        None => raise Failure("name is required for delete action")
      }
  }
}

// ----------------------------------------------------------------------------

///|
/// 解析 `tools/call` 的 params，取出目标工具与参数。
/// 失败时返回错误消息（由调用方转成 `-32602 Invalid params`）。
fn tool_call_target(params : Json) -> Result[(Tool, Json), String] {
  let obj = match params {
    Object(o) => o
    _ => return Err("tools/call requires an object params")
  }
  let name = match obj.get("name") {
    Some(String(s)) => s
    _ => return Err("tools/call requires params.name to be a string")
  }
  let arguments = obj.get("arguments").unwrap_or(Json::empty_object())
  match find_tool(name) {
    Some(tool) => Ok((tool, arguments))
    // 未知工具是**协议层**错误（-32602），不是工具执行错误（isError）。
    // 这与官方 MCP SDK 的行为一致：isError 表示「工具跑了但失败了」，
    // 而「没有这个工具」属于请求本身不合法。
    None => Err("Unknown tool: \{name}")
  }
}

///|
/// 处理一条消息。返回 `None` 表示**这是通知，不要回应**（协议细节 1）。
///
/// 分派表：
/// | method | 响应 |
/// |---|---|
/// | `initialize` | protocolVersion（回显）+ capabilities.tools + serverInfo |
/// | `ping` | `{}` |
/// | `tools/list` | 13 个工具 |
/// | `tools/call` | 工具结果或 isError |
/// | 其他 | `-32601 Method not found` |
pub async fn handle_message(state : ServerState, req : RpcRequest) -> Json? {
  if req.is_notification() {
    // notifications/initialized、notifications/cancelled 等一律不回应
    return None
  }
  match req.method_name {
    "initialize" => Some(result_msg(req.id, initialize_result(req.params)))
    "ping" => Some(result_msg(req.id, Json::empty_object()))
    "tools/list" => Some(result_msg(req.id, tools_list_result()))
    "tools/call" =>
      match tool_call_target(req.params) {
        Ok((tool, arguments)) =>
          Some(result_msg(req.id, call_tool(state, tool, arguments)))
        Err(message) => Some(error_msg(req.id, code_invalid_params, message))
      }
    _ =>
      Some(
        error_msg(
          req.id,
          code_method_not_found,
          "Method not found: \{req.method_name}",
        ),
      )
  }
}
