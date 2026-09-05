///|
/// 7 个 MCP 工具的定义、派发与集中式错误处理。
/// 取代 legacy-ts/src/mcp/server.ts L57-290。
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
/// 用扫描结果重建注册表。
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
// 7 个工具
// ----------------------------------------------------------------------------

///|
/// 全部工具，顺序即 `tools/list` 的返回顺序。
/// 名字与 legacy-ts/package.json L58-66 的 `mcp.tools` 列表逐项、同序一致。
pub fn tools() -> Array[Tool] {
  [
    {
      name: "scan_plugins",
      description: "扫描所有 harness 插件并建立档案。返回发现的插件列表及其元数据。",
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
  ]
}

///|
/// 按名字找工具。O(n) 但 n == 7，比维护一张 Map 更直白。
pub fn find_tool(name : String) -> Tool? {
  for t in tools() {
    if t.name == name {
      return Some(t)
    }
  }
  None
}

///|
/// `tools/list` 的响应体。不分页（省略 `nextCursor`）—— 7 个工具远小于任何客户端的页大小。
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
/// ★ 修掉一处配置孤岛：TS 的 schema 声明了 `target_paths`（L29），
/// 但 handler 只把 `force_rescan` 传给 scanner（L131），`target_paths` 从未生效。
/// 新版在提供了 `target_paths` 时用它们替换默认扫描根。
async fn handle_scan_plugins(state : ServerState, args : Json) -> Json {
  let a : ScanPluginsArgs = @json.from_json(args)
  let force = a.force_rescan.unwrap_or(default_force_rescan)

  match a.target_paths {
    Some(custom) if !custom.is_empty() => {
      let scanner = @scanner.PluginScanner::new(
        @scanner.ScanConfig::custom(custom, state.paths.plugin_cache()),
      )
      scanner.scan_all(force_rescan=force)
      state.adopt(scanner.all())
    }
    _ => {
      state.scanner.scan_all(force_rescan=force)
      state.adopt(state.scanner.all())
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

  // 手动提供的信号描述 → medium/pattern 信号（对应 TS L177-186）
  let manual : Array[@types.EvolutionSignal]? = match a.signals {
    Some(descriptions) => {
      let now = @util.now_ms()
      let out : Array[@types.EvolutionSignal] = []
      for description in descriptions {
        out.push({
          strength: @types.SignalStrength::Medium,
          category: @types.SignalCategory::Pattern,
          description,
          evidence: @types.Evidence::UserManual,
          ts: now,
          plugin_id: a.plugin_id,
          count: None,
          tool: None,
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
// 消息派发
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
/// | `tools/list` | 7 个工具 |
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
