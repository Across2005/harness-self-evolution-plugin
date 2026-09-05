///|
/// 升级执行器。取代 legacy-ts/src/executor/index.ts L22-223 与 L406-428。
///
/// 职责：校验提案状态 → 分解为 Sub-Agent 任务 → **分层并行**执行 →
/// 三级验证 → 成功置 completed / 失败回滚到 pending → 全程写执行日志。
///
/// **相对 TS 的四处改进**（都有实测或源码依据）：
/// 1. **分层并行**取代纯串行（TS L76）。TS 的 `dependencies` 字段是死的，
///    见 dag.mbt 的头注释。
/// 2. **真超时**：TS 声明了 `timeout_ms`（L147/156/165/174/183/194/204/218）
///    却从未执行过；新版用 `@async.with_timeout_opt` 强制，超时会**真正取消**
///    被放弃的任务 —— 接真实 LLM Sub-Agent 后这直接等于省钱。
/// 3. **可注入的执行/验证实现**（见 runner.mbt）：`dry_run` 从散落三处的 `if`
///    收敛为构造时选哪一对实现，并让「失败 → 回滚」这条路径第一次可测。
/// 4. **回滚不再是空壳里的空壳**：TS 的 `rollback`（L409-418）只写一行日志，
///    注释里列了三件该做的事却一件没做。新版保持同样的行为边界
///    （本仓并不真的改写插件文件，故无文件可回滚），但把这一点写在明处，
///    而不是藏在一段 "In production, this would: ..." 的注释里。

///|
/// 执行结果。字段与 TS `execute` 的返回对象
/// `{ success, results, error? }`（L37-41）逐一对应，
/// 于是 `mcp/server.ts` L222-232 的响应形状无需改动。
pub(all) struct ExecutionResult {
  success : Bool
  results : Array[@types.SubAgentResult]
  error : String?
} derive(Eq, Debug, ToJson)

///|
/// 默认的层内并行度。
///
/// 取 4 而不是无限：Sub-Agent 将来可能是 LLM 调用，
/// 无节制并发会同时撞上速率限制与本地句柄上限。
let default_max_parallel : Int = 4

///|
/// 验证级别的兜底超时（毫秒）。`ValidationLevel.timeout_ms` 缺省时使用。
let default_validation_timeout_ms : Int = 120_000

///|
/// 升级执行器。
pub struct UpgradeExecutor {
  proposals : @store.ProposalStore
  log : @store.ExecutionLog
  /// 非 dry-run 时使用的任务执行器。可注入，见 runner.mbt。
  run_task : async (@types.SubAgentTask) -> Json
  /// 非 dry-run 时使用的验证器。可注入，见 runner.mbt。
  validate_level : async (
    @types.ValidationLevelTag,
    @types.EvolutionProposal,
  ) -> (Bool, String)
  max_parallel : Int
}

///|
/// 构造。`run_task` / `validate_level` 缺省为模拟实现（对应 TS 的
/// `simulateSubAgent` L274-290 与 `runValidationLevel` L346-384）。
pub fn UpgradeExecutor::new(
  proposals : @store.ProposalStore,
  log : @store.ExecutionLog,
  run_task~ : async (@types.SubAgentTask) -> Json = simulated_task,
  validate_level~ : async (
    @types.ValidationLevelTag,
    @types.EvolutionProposal,
  ) -> (Bool, String) = simulated_validation,
  max_parallel~ : Int = default_max_parallel,
) -> UpgradeExecutor {
  { proposals, log, run_task, validate_level, max_parallel }
}

///|
/// 用 `DataPaths` 构造（生产路径）。
pub fn UpgradeExecutor::at(paths : @store.DataPaths) -> UpgradeExecutor {
  UpgradeExecutor::new(
    @store.ProposalStore::at(paths),
    @store.ExecutionLog::at(paths),
  )
}

///|
/// 执行一份已审批的提案。取代 TS L37-132。
///
/// 状态流转严格对齐 TS，且全部经 `ProposalStore.set_status`
/// （CONTEXT.md 不变量②）：
/// ```text
/// find → 校验 status == approved → executing → [任务 + 验证]
///   ├─ 全通过 → completed
///   └─ 任一失败 → 回滚 + pending
/// ```
/// 错误消息逐字保留 TS 的三条（L47-51、L56-60、L89/L108），
/// 因为 legacy 测试是按子串匹配的：`"not found"`、`"completed"`、
/// `"rejected"`、`"expected 'approved'"`。
pub async fn UpgradeExecutor::execute(
  self : UpgradeExecutor,
  proposal_id : String,
  dry_run~ : Bool = false,
) -> ExecutionResult {
  @util.log_info("Executor", "Executing proposal: \{proposal_id}")

  let proposal = match self.proposals.find(proposal_id) {
    Some(p) => p
    None =>
      return {
        success: false,
        results: [],
        error: Some("Proposal not found: \{proposal_id}"),
      }
  }

  // 只有 approved 才能执行（TS L55-61）
  if proposal.status != @types.ProposalStatus::Approved {
    return {
      success: false,
      results: [],
      error: Some(
        "Proposal status is \{proposal.status.wire_name()}, expected 'approved'",
      ),
    }
  }

  ignore(self.proposals.set_status(proposal_id, @types.ProposalStatus::Executing))
  self.log.append(
    proposal_id,
    @store.ExecEvent::Start,
    "Starting execution of \{proposal_id}",
  )

  // 外层兜住一切意外（TS L121-131）。
  // 这一层必不可少：native 后端下**未捕获异常的信息会被打到 stdout**
  // （Phase 0 门禁实测），而 stdout 是 MCP 的协议通道。
  let outcome : ExecutionResult = try {
    self.run_pipeline(proposal, dry_run)
  } catch {
    e => {
      let msg = e.to_string()
      self.log.append(proposal_id, @store.ExecEvent::Error, "Unexpected error: \{msg}")
      // executing → pending 是合法迁移（失败自动回滚，见 CONTEXT.md L24）
      ignore(self.proposals.set_status(proposal_id, @types.ProposalStatus::Pending))
      { success: false, results: [], error: Some("Unexpected error: \{msg}") }
    }
  }
  outcome
}

///|
/// 任务分层执行 + 三级验证。取代 TS L69-119。
async fn UpgradeExecutor::run_pipeline(
  self : UpgradeExecutor,
  proposal : @types.EvolutionProposal,
  dry_run : Bool,
) -> ExecutionResult raise {
  // dry_run 在此处一次性选定实现，而不是像 TS 那样在三处分别 if
  let runner = if dry_run { dry_run_task } else { self.run_task }
  let validator = if dry_run {
    dry_run_validation
  } else {
    self.validate_level
  }

  let tasks = decompose_tasks(proposal)
  let layers = topo_layers(tasks)

  let results : Array[@types.SubAgentResult] = []
  for layer in layers {
    // 层内并行。@async.all 是 fail-fast：任一任务抛错即取消同层其余任务。
    // 但 run_with_timeout 内部已经把抛错归一化成 success=false 的结果，
    // 所以这里不会因为单个任务失败而丢掉同层其他任务的结果。
    let jobs : Array[async () -> @types.SubAgentResult] = []
    for index in layer {
      let task = tasks[index]
      jobs.push(() => run_with_timeout(runner, task))
    }
    let layer_results = @async.all(jobs, max_concurrent=self.max_parallel)
    for r in layer_results {
      results.push(r)
    }

    match first_failure(layer_results) {
      Some(failed) => {
        let detail = failed.error.unwrap_or("unknown error")
        let label = failed.agent.wire_name()
        self.log.append(
          proposal.proposal_id,
          @store.ExecEvent::Error,
          "Task \{label} failed: \{detail}",
        )
        self.rollback(proposal)
        ignore(
          self.proposals.set_status(
            proposal.proposal_id,
            @types.ProposalStatus::Pending,
          ),
        )
        return {
          success: false,
          results,
          error: Some("Task \{label} failed: \{detail}"),
        }
      }
      None => ()
    }
    self.log.append(
      proposal.proposal_id,
      @store.ExecEvent::Progress,
      "Layer completed (\{layer.length()} task(s))",
    )
  }

  // 三级验证。T0 → T1 → T2 保持**串行**：这是语义门控
  // （T0 语法不过就没必要跑 T1 功能测试），不是 dag.mbt 里那种
  // 「无依赖却串行」的性能缺陷。强行并行会把 T0 失败时本可省掉的
  // T1/T2 时间也花掉，是负优化。
  let validation : Array[@types.SubAgentResult] = []
  for spec in proposal.validation_plan.validation_levels {
    let result = self.run_validation_level(validator, spec, proposal)
    validation.push(result)
    if !result.success {
      let detail = result.error.unwrap_or("unknown error")
      let label = spec.level.wire_name()
      self.log.append(
        proposal.proposal_id,
        @store.ExecEvent::Error,
        "Validation failed: \{label} \{detail}",
      )
      self.rollback(proposal)
      ignore(
        self.proposals.set_status(
          proposal.proposal_id,
          @types.ProposalStatus::Pending,
        ),
      )
      let all = results.copy()
      for r in validation {
        all.push(r)
      }
      return {
        success: false,
        results: all,
        error: Some("\{label} validation failed: \{detail}"),
      }
    }
  }

  ignore(
    self.proposals.set_status(
      proposal.proposal_id,
      @types.ProposalStatus::Completed,
    ),
  )
  self.log.append(
    proposal.proposal_id,
    @store.ExecEvent::Complete,
    "Execution completed successfully",
  )
  let all = results.copy()
  for r in validation {
    all.push(r)
  }
  { success: true, results: all, error: None }
}

///|
/// 跑一级验证，带真超时。取代 TS L329-404。
///
/// TS 那 75 行是三段近似重复的 `if (level === 'T0') {...}`，
/// 且 `setTimeout(50/100/150)` 只是**假装**在验证。
/// 新版把「验什么」交给可注入的 `validator`，本函数只负责计时、超时与结果归一化。
async fn UpgradeExecutor::run_validation_level(
  self : UpgradeExecutor,
  validator : async (
    @types.ValidationLevelTag,
    @types.EvolutionProposal,
  ) -> (Bool, String),
  spec : @types.ValidationLevel,
  proposal : @types.EvolutionProposal,
) -> @types.SubAgentResult {
  ignore(self)
  let timeout = spec.timeout_ms.unwrap_or(default_validation_timeout_ms)
  let started = @util.now_ms()
  let outcome : Result[(Bool, String)?, String] = try {
    Ok(@async.with_timeout_opt(timeout, () => validator(spec.level, proposal)))
  } catch {
    e => Err(e.to_string())
  }
  let finished = @util.now_ms()
  let label = spec.level.wire_name()
  match outcome {
    Ok(Some((ok, message))) =>
      {
        task_id: "validation-\{label}-\{finished}",
        agent: @types.AgentType::Validator,
        success: ok,
        output: Some(Json::string(message)),
        error: if ok { None } else { Some(message) },
        duration_ms: finished - started,
      }
    Ok(None) =>
      {
        task_id: "validation-\{label}-\{finished}",
        agent: @types.AgentType::Validator,
        success: false,
        output: None,
        error: Some("timeout after \{timeout}ms"),
        duration_ms: finished - started,
      }
    Err(msg) =>
      {
        task_id: "validation-\{label}-\{finished}",
        agent: @types.AgentType::Validator,
        success: false,
        output: None,
        error: Some(msg),
        duration_ms: finished - started,
      }
  }
}

///|
/// 带超时与错误归一化地跑一个任务。取代 TS L228-269。
///
/// ★ **这里第一次真正强制执行了 `timeout_ms`**。TS 版声明了该字段却从不使用，
/// 属纯装饰。用 `with_timeout_opt`（返回 `X?`）而不是 `with_timeout`（抛 TimeoutError）：
/// 超时是**预期内的业务结果**而非异常，直接映射成 `success=false` + 明确的错误文本，
/// 与 TS L259-268 的 catch 分支输出格式一致，便于测试断言。
/// `with_timeout_opt` 内部会**真正取消**被放弃的任务，
/// 这对将来的 LLM Sub-Agent 至关重要（不为已放弃的任务继续付费）。
async fn run_with_timeout(
  runner : async (@types.SubAgentTask) -> Json,
  task : @types.SubAgentTask,
) -> @types.SubAgentResult {
  @util.log_info(
    "Executor",
    "Executing task: \{task.agent.wire_name()} - \{task.task}",
  )
  let started = @util.now_ms()
  let outcome : Result[Json?, String] = try {
    Ok(@async.with_timeout_opt(task.timeout_ms, () => runner(task)))
  } catch {
    e => Err(e.to_string())
  }
  let finished = @util.now_ms()
  // task_id 沿用 TS 的 `${agent}-${Date.now()}` 形式（L237/253/261）
  let task_id = "\{task.agent.wire_name()}-\{finished}"
  match outcome {
    Ok(Some(output)) =>
      {
        task_id,
        agent: task.agent,
        success: true,
        output: Some(output),
        error: None,
        duration_ms: finished - started,
      }
    Ok(None) =>
      {
        task_id,
        agent: task.agent,
        success: false,
        output: None,
        error: Some("timeout after \{task.timeout_ms}ms"),
        duration_ms: finished - started,
      }
    Err(msg) =>
      {
        task_id,
        agent: task.agent,
        success: false,
        output: None,
        error: Some(msg),
        duration_ms: finished - started,
      }
  }
}

///|
/// 找出第一个失败的结果。
fn first_failure(
  results : ArrayView[@types.SubAgentResult],
) -> @types.SubAgentResult? {
  for r in results {
    if !r.success {
      return Some(r)
    }
  }
  None
}

///|
/// 回滚。取代 TS L409-418。
///
/// **行为边界说明**：TS 的实现只写一行日志，注释里列了三件该做的事
/// （revert file changes / restore from backup / clean temp files）却一件没做。
/// 这不是遗漏 —— 本仓的 Sub-Agent 执行是**模拟**的，从来没有真的改写过
/// 任何插件文件，因此确实无文件可回滚。新版保持同样的行为，
/// 但把这一点写在明处，而不是藏在一段 "In production, this would: ..." 里。
/// 真正的状态回滚（提案回到 pending）由 `execute` 的调用点负责，
/// 那是有实际效果的部分。
///
/// 将来接入真实 Sub-Agent 时，这里就是挂「恢复备份」逻辑的位置。
async fn UpgradeExecutor::rollback(
  self : UpgradeExecutor,
  proposal : @types.EvolutionProposal,
) -> Unit {
  @util.log_info("Executor", "Rolling back changes...")
  self.log.append(
    proposal.proposal_id,
    @store.ExecEvent::Rollback,
    "Changes rolled back",
  )
}

// ============================================================================
// 任务分解
// ============================================================================

///|
/// 取出某一类变更的 items（JSON 形式）；不存在或为空则 `None`。
fn items_of(
  changes : ArrayView[@types.Change],
  kind : @types.ChangeKind,
) -> Json? {
  for c in changes {
    if c.kind() == kind && !c.is_empty() {
      return match c {
        @types.Change::MergeTools(xs) => Some(ToJson::to_json(xs))
        @types.Change::SimplifyParams(xs) => Some(ToJson::to_json(xs))
        @types.Change::AddMiddleware(xs) => Some(ToJson::to_json(xs))
        @types.Change::OptimizeFlow(xs) => Some(ToJson::to_json(xs))
        @types.Change::UpdateDocumentation(xs) => Some(ToJson::to_json(xs))
        @types.Change::AddCapability(xs) => Some(ToJson::to_json(xs))
        @types.Change::ImproveErrorHandling(xs) => Some(ToJson::to_json(xs))
      }
    }
  }
  None
}

///|
/// 若该类变更存在则追加一个任务。
/// 把 TS L142-206 那 5 段近乎相同的 `if (changes.x && changes.x.length > 0)`
/// 收敛为一处。
fn push_task(
  tasks : Array[@types.SubAgentTask],
  changes : ArrayView[@types.Change],
  kind : @types.ChangeKind,
  id : String,
  agent : @types.AgentType,
  description : String,
  timeout_ms : Int,
) -> Unit {
  match items_of(changes, kind) {
    Some(input) =>
      tasks.push({ id, agent, task: description, input, deps: [], timeout_ms })
    None => ()
  }
}

///|
/// 把提案分解为 Sub-Agent 任务。取代 TS L137-223。
///
/// 任务的**追加顺序**与 TS 一致：
/// 代码生成（merge → middleware → flow → capability → error-handling）
/// → 测试编写（仅当存在代码生成任务）→ 文档更新 → 集成（仅当任务数 > 1）。
///
/// 与 TS 的三处差异，都是修正而非改变行为：
/// · 每个任务有稳定 `id`（`cg-merge` / `tw` / `dw` / `integ`），
///   `deps` 引用的是**任务 id** 而不是 agent 类型名（修 TS L193/L217 的语义错误）
/// · `dw`（文档更新）的 `deps` 为空 —— 它与代码生成之间没有真实依赖，
///   于是能与 `cg-*` 同层并行
/// · `integ` 依赖全部 `cg-*` 与 `tw`（TS 写的是含糊的
///   `['code-generator','test-writer']`）
pub fn decompose_tasks(
  proposal : @types.EvolutionProposal,
) -> Array[@types.SubAgentTask] {
  let tasks : Array[@types.SubAgentTask] = []
  let changes = proposal.proposed_changes

  // 代码生成任务（TS L142-185 的固定顺序）
  push_task(
    tasks,
    changes,
    @types.ChangeKind::MergeTools,
    "cg-merge",
    @types.AgentType::CodeGenerator,
    "实现工具合并：创建新工具并保留向后兼容性",
    120_000,
  )
  push_task(
    tasks,
    changes,
    @types.ChangeKind::AddMiddleware,
    "cg-middleware",
    @types.AgentType::CodeGenerator,
    "实现中间件：添加行为优化逻辑",
    60_000,
  )
  push_task(
    tasks,
    changes,
    @types.ChangeKind::OptimizeFlow,
    "cg-flow",
    @types.AgentType::CodeGenerator,
    "实现性能优化：优化工具调用流程",
    90_000,
  )
  push_task(
    tasks,
    changes,
    @types.ChangeKind::AddCapability,
    "cg-capability",
    @types.AgentType::CodeGenerator,
    "实现新能力：扩展插件功能",
    120_000,
  )
  push_task(
    tasks,
    changes,
    @types.ChangeKind::ImproveErrorHandling,
    "cg-error",
    @types.AgentType::CodeGenerator,
    "改进错误处理：增强用户体验",
    60_000,
  )

  // 测试编写：仅当存在 code-generator 任务（TS L188-196）
  let cg_ids : Array[String] = []
  for t in tasks {
    cg_ids.push(t.id)
  }
  if !cg_ids.is_empty() {
    tasks.push(
      {
        id: "tw",
        agent: @types.AgentType::TestWriter,
        task: "编写测试用例：验证新功能",
        input: ToJson::to_json(proposal.validation_plan.test_scenarios),
        deps: cg_ids.copy(),
        timeout_ms: 90_000,
      },
    )
  }

  // 文档更新（TS L199-206）。deps 为空 → 可与代码生成并行
  push_task(
    tasks,
    changes,
    @types.ChangeKind::UpdateDocumentation,
    "dw",
    @types.AgentType::DocWriter,
    "更新文档：记录变更和使用说明",
    60_000,
  )

  // 集成：仅当任务数 > 1（TS L209 的 `tasks.length > 1`，注意是 > 不是 >=）
  if tasks.length() > 1 {
    let deps = cg_ids.copy()
    if !cg_ids.is_empty() {
      deps.push("tw")
    }
    tasks.push(
      {
        id: "integ",
        agent: @types.AgentType::Integration,
        task: "集成变更：处理依赖关系和兼容性",
        input: {
          "plugin_id": Json::string(proposal.plugin_id),
          "changes": ToJson::to_json(changes),
        },
        deps,
        timeout_ms: 90_000,
      },
    )
  }

  tasks
}
