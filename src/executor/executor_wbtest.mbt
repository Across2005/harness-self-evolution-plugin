///|
/// executor 的测试。1-7 移植自 legacy-ts/tests/executor.test.ts 的 7 个 `execute` 用例
/// （另外 3 个 ProposalStore 状态机用例已按「测试紧邻被测代码」归位到 store 包），
/// 8 起是本次改造新增的（DAG 分层、环检测、真超时、注入缝）。

///|
/// 对应 legacy 的 `makeProposal`（executor.test.ts L13-59）。
/// 默认形态：approved + 一条 merge_tools 变更 + T0/T1/T2 三级验证。
fn make_proposal(
  proposal_id? : String = "evo-test-1",
  status? : @types.ProposalStatus = @types.ProposalStatus::Approved,
  changes? : Array[@types.Change] = [merge_change()],
  levels? : Array[@types.ValidationLevel] = default_levels(),
) -> @types.EvolutionProposal {
  {
    proposal_id,
    plugin_id: "test-plugin-1.0.0",
    status,
    created_at: @util.now_ms(),
    trigger_signals: [],
    evolution_type: @types.EvolutionType::InterfaceSimplification,
    matt_pocock_principle: @types.MattPocockPrinciple::DeepModule,
    proposed_changes: changes,
    expected_benefits: @types.EvolutionType::InterfaceSimplification.expected_benefits(),
    validation_plan: {
      test_scenarios: ["form filling"],
      success_criteria: "success_rate >= 95%",
      rollback_strategy: "keep previous version 30 days",
      validation_levels: levels,
    },
    risk_assessment: {
      breaking_changes: false,
      backward_compatible: true,
      migration_effort: @types.MigrationEffort::Low,
      affected_users: 0,
      rollback_complexity: @types.RollbackComplexity::Simple,
    },
    signature: "test-plugin-interface-simplification",
    confidence: @types.Confidence::Medium,
  }
}

///|
/// legacy makeProposal L23-33 里的那条 smart_fill 合并变更。
fn merge_change() -> @types.Change {
  @types.Change::MergeTools([
    {
      new_tool: "smart_fill",
      merged_from: ["navigate", "click", "type"],
      new_interface: {
        params: ["url", "selector", "text"],
        description: "One-stop form filling",
        defaults: None,
      },
      backward_compatible: true,
    },
  ])
}

///|
/// legacy makeProposal L42-46 的三级验证（无 timeout_ms）。
fn default_levels() -> Array[@types.ValidationLevel] {
  [
    {
      level: @types.ValidationLevelTag::T0,
      description: "Syntax",
      automated: true,
      timeout_ms: None,
    },
    {
      level: @types.ValidationLevelTag::T1,
      description: "Functionality",
      automated: true,
      timeout_ms: None,
    },
    {
      level: @types.ValidationLevelTag::T2,
      description: "Regression",
      automated: true,
      timeout_ms: None,
    },
  ]
}

///|
/// 对应 legacy 的 beforeEach（L61-68）：ProposalStore + UpgradeExecutor 共享一个临时目录。
fn make_executor(
  dir : String,
) -> (UpgradeExecutor, @store.ProposalStore, @store.ExecutionLog) {
  let proposals = @store.ProposalStore::new(
    @util.path_join(dir, "proposals.jsonl"),
  )
  let log = @store.ExecutionLog::new(@util.path_join(dir, "execution.log"))
  (UpgradeExecutor::new(proposals, log), proposals, log)
}

///|
fn has_agent(
  results : ArrayView[@types.SubAgentResult],
  agent : @types.AgentType,
) -> Bool {
  for r in results {
    if r.agent == agent {
      return true
    }
  }
  false
}

// ============================================================================
// 移植：execute（legacy L74-152）
// ============================================================================

///|
/// 移植：executor.test.ts L75-80 "should fail when the proposal does not exist"
async test "fails when the proposal does not exist" {
  let dir = @fs.tmpdir(prefix="evo-exec-")
  defer @fs.rmdir(dir, recursive=true)
  let (executor, _, _) = make_executor(dir)

  let result = executor.execute("does-not-exist")
  assert_eq(result.success, false)
  // toContain('not found')
  assert_true(result.error.unwrap_or("").contains("not found"))
  assert_eq(result.results.length(), 0)
}

///|
/// 移植：executor.test.ts L82-89 "should fail when the proposal is already completed"
async test "fails when the proposal is already completed" {
  let dir = @fs.tmpdir(prefix="evo-exec-")
  defer @fs.rmdir(dir, recursive=true)
  let (executor, proposals, _) = make_executor(dir)
  proposals.save(make_proposal(status=@types.ProposalStatus::Completed))

  let result = executor.execute("evo-test-1")
  assert_eq(result.success, false)
  assert_true(result.error.unwrap_or("").contains("completed"))
  // 错误消息必须点明期望状态，便于 LLM 自我纠正
  assert_true(result.error.unwrap_or("").contains("expected 'approved'"))
}

///|
/// 移植：executor.test.ts L91-98 "should fail when the proposal is rejected"
async test "fails when the proposal is rejected" {
  let dir = @fs.tmpdir(prefix="evo-exec-")
  defer @fs.rmdir(dir, recursive=true)
  let (executor, proposals, _) = make_executor(dir)
  proposals.save(make_proposal(status=@types.ProposalStatus::Rejected))

  let result = executor.execute("evo-test-1")
  assert_eq(result.success, false)
  assert_true(result.error.unwrap_or("").contains("rejected"))
}

///|
/// 移植：executor.test.ts L100-110
/// "should complete a dry run over an approved proposal"
async test "completes a dry run over an approved proposal" {
  let dir = @fs.tmpdir(prefix="evo-exec-")
  defer @fs.rmdir(dir, recursive=true)
  let (executor, proposals, _) = make_executor(dir)
  proposals.save(make_proposal())

  let result = executor.execute("evo-test-1", dry_run=true)
  assert_eq(result.success, true)
  assert_eq(result.error, None)
  // code-generator + test-writer + integration + 三级验证
  assert_true(result.results.length() > 0)
  assert_true(has_agent(result.results, @types.AgentType::CodeGenerator))
  assert_true(has_agent(result.results, @types.AgentType::TestWriter))
  assert_true(has_agent(result.results, @types.AgentType::Integration))
  assert_true(has_agent(result.results, @types.AgentType::Validator))
}

///|
/// 移植：executor.test.ts L112-119
/// "should mark the proposal completed after a successful run"
async test "marks the proposal completed after a successful run" {
  let dir = @fs.tmpdir(prefix="evo-exec-")
  defer @fs.rmdir(dir, recursive=true)
  let (executor, proposals, _) = make_executor(dir)
  proposals.save(make_proposal())

  ignore(executor.execute("evo-test-1", dry_run=true))
  match proposals.find("evo-test-1") {
    Some(p) => assert_eq(p.status, @types.ProposalStatus::Completed)
    None => abort("proposal vanished")
  }
}

///|
/// 移植并**改写**：executor.test.ts L121-142
/// "should reset the proposal to pending when dry run is not requested and a task fails"
///
/// legacy 的注释坦白说：非 dry-run 路径的模拟 Sub-Agent 恒成功，
/// 所以它只能靠一个 `{ level: 'T9' as any }` 的**类型系统外伪造值**
/// 去触发 "Unknown validation level" 分支。
/// `ValidationLevelTag` 闭合后 `T9` 不可构造，
/// 新版改为注入 `failing_validation` —— 覆盖的是「验证失败」这一**真实语义**，
/// 而不是「等级名拼错」这一实现巧合。这比 legacy 那条用例更强。
async test "resets the proposal to pending when validation fails" {
  let dir = @fs.tmpdir(prefix="evo-exec-")
  defer @fs.rmdir(dir, recursive=true)
  let proposals = @store.ProposalStore::new(
    @util.path_join(dir, "proposals.jsonl"),
  )
  let log = @store.ExecutionLog::new(@util.path_join(dir, "execution.log"))
  let executor = UpgradeExecutor::new(
    proposals,
    log,
    validate_level=failing_validation,
  )
  proposals.save(make_proposal())

  // 注意：dry_run=false，走注入的 failing_validation
  let result = executor.execute("evo-test-1", dry_run=false)
  assert_eq(result.success, false)
  assert_true(result.error.unwrap_or("").contains("T0 validation failed"))
  match proposals.find("evo-test-1") {
    Some(p) => assert_eq(p.status, @types.ProposalStatus::Pending)
    None => abort("proposal vanished")
  }
  // 回滚必须留下痕迹
  let lines = log.read()
  let mut saw_rollback = false
  for line in lines {
    if line.contains("[rollback]") {
      saw_rollback = true
    }
  }
  assert_true(saw_rollback)
}

///|
/// 移植：executor.test.ts L144-151
/// "should reject executing a pending proposal (state machine)"
async test "rejects executing a pending proposal" {
  let dir = @fs.tmpdir(prefix="evo-exec-")
  defer @fs.rmdir(dir, recursive=true)
  let (executor, proposals, _) = make_executor(dir)
  proposals.save(make_proposal(status=@types.ProposalStatus::Pending))

  let result = executor.execute("evo-test-1")
  assert_eq(result.success, false)
  assert_true(result.error.unwrap_or("").contains("expected 'approved'"))
  // 状态不得被改动
  match proposals.find("evo-test-1") {
    Some(p) => assert_eq(p.status, @types.ProposalStatus::Pending)
    None => abort("proposal vanished")
  }
}

// ============================================================================
// 新增：任务分解与 DAG 分层
// ============================================================================

///|
/// legacy 形态（只有 merge_tools）分解为 3 个任务、3 层。
/// 与 TS 的串行 3 步任务数相同 —— 收益要在有 doc-writer 时才显现（见下一例）。
test "decompose_tasks reproduces the legacy task set for a merge-only proposal" {
  let tasks = decompose_tasks(make_proposal())
  json_inspect(tasks.map(fn(t) { t.id }), content=["cg-merge", "tw", "integ"])
  json_inspect(tasks.map(fn(t) { t.agent.wire_name() }), content=[
    "code-generator", "test-writer", "integration",
  ])
  // ★ deps 引用的是**任务 id**，不是 TS L193/L217 那种 agent 类型名
  json_inspect(tasks[1].deps, content=["cg-merge"])
  json_inspect(tasks[2].deps, content=["cg-merge", "tw"])
  // timeout_ms 有实值（TS 声明了却从不执行）
  assert_eq(tasks[0].timeout_ms, 120_000)

  let layers = topo_layers(tasks)
  assert_eq(critical_path_len(layers), 3)
  assert_eq(task_count(layers), 3)
}

///|
/// ★ **分层并行的收益点**：文档更新与代码生成之间没有真实依赖，
/// 于是能与 `cg-*` 同层并行。TS 的串行队列里 `dw` 只能排在后面。
///
/// 注意 `plan_changes` 每种进化类型只产出一组变更，
/// 所以这种多组变更的提案要靠外部（或将来更强的规划器）构造 ——
/// 本用例直接构造 `Array[Change]` 来验证 DAG 机制本身。
test "doc-writer runs in the same layer as code-generator" {
  let changes = [
    merge_change(),
    @types.Change::UpdateDocumentation([
      {
        file: "SKILL.md",
        section: "Usage Examples",
        new_content: "c",
        reason: "r",
      },
    ]),
  ]
  let tasks = decompose_tasks(make_proposal(changes~))
  json_inspect(tasks.map(fn(t) { t.id }), content=[
    "cg-merge", "tw", "dw", "integ",
  ])
  // dw 无依赖 → 与 cg-merge 同层
  json_inspect(tasks[2].deps, content=[])

  let layers = topo_layers(tasks)
  // TS 串行 4 步；新版 3 层，且第 0 层并行 2 个任务
  assert_eq(critical_path_len(layers), 3)
  assert_eq(task_count(layers), 4)
  json_inspect(layers[0], content=[0, 2]) // cg-merge 与 dw
  json_inspect(layers[1], content=[1]) // tw
  json_inspect(layers[2], content=[3]) // integ
}

///|
/// 只有文档变更时**不产生** integration 任务 —— TS L209 的条件是
/// `tasks.length > 1`（严格大于），单个 dw 任务不满足。
test "a documentation-only proposal yields exactly one task and no integration" {
  let changes = [
    @types.Change::UpdateDocumentation([
      { file: "SKILL.md", section: "Workflow", new_content: "c", reason: "r" },
    ]),
  ]
  let tasks = decompose_tasks(make_proposal(changes~))
  json_inspect(tasks.map(fn(t) { t.id }), content=["dw"])
  // 没有 code-generator → 也不产生 test-writer（TS L188 的条件）
  assert_eq(has_agent([], @types.AgentType::TestWriter), false)

  let layers = topo_layers(tasks)
  assert_eq(critical_path_len(layers), 1)
}

///|
/// 空变更集 → 零任务、零层。执行应直接进验证阶段。
test "an empty change set decomposes to no tasks" {
  let tasks = decompose_tasks(make_proposal(changes=[]))
  assert_eq(tasks.length(), 0)
  assert_eq(topo_layers(tasks).length(), 0)
}

///|
/// 环检测：自环与互环都必须被拒绝，并带上具体任务 id。
test "topo_layers rejects cyclic dependencies" {
  // 自环
  let self_loop : Array[@types.SubAgentTask] = [
    {
      id: "a",
      agent: @types.AgentType::CodeGenerator,
      task: "t",
      input: Json::null(),
      deps: ["a"],
      timeout_ms: 1000,
    },
  ]
  let msg = try {
    ignore(topo_layers(self_loop))
    ""
  } catch {
    e => e.to_string()
  }
  assert_true(msg.contains("Cyclic dependency"))
  assert_true(msg.contains("a"))

  // 互环 a → b → a
  let mutual : Array[@types.SubAgentTask] = [
    {
      id: "a",
      agent: @types.AgentType::CodeGenerator,
      task: "t",
      input: Json::null(),
      deps: ["b"],
      timeout_ms: 1000,
    },
    {
      id: "b",
      agent: @types.AgentType::TestWriter,
      task: "t",
      input: Json::null(),
      deps: ["a"],
      timeout_ms: 1000,
    },
  ]
  let msg2 = try {
    ignore(topo_layers(mutual))
    ""
  } catch {
    e => e.to_string()
  }
  assert_true(msg2.contains("Cyclic dependency"))
}

///|
/// 依赖了不存在的任务 id 必须被拒绝 —— 这正是 TS 那个
/// `dependencies: ['code-generator']`（agent 类型名而非任务 id）会犯的错误，
/// 只是 TS 从不读该字段，所以从未暴露。
test "topo_layers rejects unknown dependencies" {
  let tasks : Array[@types.SubAgentTask] = [
    {
      id: "a",
      agent: @types.AgentType::CodeGenerator,
      task: "t",
      input: Json::null(),
      deps: ["ghost"],
      timeout_ms: 1000,
    },
  ]
  let msg = try {
    ignore(topo_layers(tasks))
    ""
  } catch {
    e => e.to_string()
  }
  assert_true(msg.contains("unknown task"))
  assert_true(msg.contains("ghost"))
}

///|
/// 完全独立的任务应全部落在第 0 层（最大并行）。
test "independent tasks all land in the first layer" {
  let tasks : Array[@types.SubAgentTask] = [
    {
      id: "a",
      agent: @types.AgentType::CodeGenerator,
      task: "t",
      input: Json::null(),
      deps: [],
      timeout_ms: 1000,
    },
    {
      id: "b",
      agent: @types.AgentType::DocWriter,
      task: "t",
      input: Json::null(),
      deps: [],
      timeout_ms: 1000,
    },
    {
      id: "c",
      agent: @types.AgentType::TestWriter,
      task: "t",
      input: Json::null(),
      deps: [],
      timeout_ms: 1000,
    },
  ]
  let layers = topo_layers(tasks)
  assert_eq(critical_path_len(layers), 1)
  json_inspect(layers[0], content=[0, 1, 2])
}

// ============================================================================
// 新增：真超时与注入缝
// ============================================================================

///|
/// ★ **`timeout_ms` 第一次被真正强制执行。**
/// TS 在 8 处声明了该字段（L147/156/165/174/183/194/204/218）却从不使用；
/// 新版用 `with_timeout_opt`，超时会**真正取消**被放弃的任务 ——
/// 接真实 LLM Sub-Agent 后这直接等于不为已放弃的任务付费。
async test "run_with_timeout enforces timeout_ms and cancels the task" {
  let task : @types.SubAgentTask = {
    id: "cg-slow",
    agent: @types.AgentType::CodeGenerator,
    task: "a task that never finishes in time",
    input: Json::null(),
    deps: [],
    timeout_ms: 50,
  }
  let started = @util.now_ms()
  let result = run_with_timeout(hanging_task, task)
  let elapsed = @util.elapsed_ms(started)

  assert_eq(result.success, false)
  assert_eq(result.error, Some("timeout after 50ms"))
  assert_eq(result.agent, @types.AgentType::CodeGenerator)
  // hanging_task 睡 60 秒；若超时没有真正取消它，这里会等满 60 秒。
  // 留足余量断言：必须在 5 秒内返回。
  assert_true(elapsed < 5_000L)
}

///|
/// 正常完成的任务不受超时影响。
async test "run_with_timeout passes through a successful result" {
  let task : @types.SubAgentTask = {
    id: "cg-ok",
    agent: @types.AgentType::CodeGenerator,
    task: "quick",
    input: Json::null(),
    deps: [],
    timeout_ms: 60_000,
  }
  let result = run_with_timeout(dry_run_task, task)
  assert_eq(result.success, true)
  assert_eq(result.error, None)
  assert_true(result.output is Some(_))
  // task_id 沿用 TS 的 `${agent}-${Date.now()}` 形式（L237/253/261）
  assert_true(result.task_id.has_prefix("code-generator-"))
}

///|
/// 任务执行器抛错时被归一化成 `success=false`，
/// 进而触发「回滚 + 回 pending」。这条路径在 legacy 测试里**完全没有覆盖**
/// （TS 的模拟 Sub-Agent 恒成功）。
async test "a failing task rolls the proposal back to pending" {
  let dir = @fs.tmpdir(prefix="evo-exec-")
  defer @fs.rmdir(dir, recursive=true)
  let proposals = @store.ProposalStore::new(
    @util.path_join(dir, "proposals.jsonl"),
  )
  let log = @store.ExecutionLog::new(@util.path_join(dir, "execution.log"))
  let executor = UpgradeExecutor::new(
    proposals,
    log,
    run_task=failing_task,
    validate_level=failing_validation,
  )
  proposals.save(make_proposal())

  let result = executor.execute("evo-test-1", dry_run=false)
  assert_eq(result.success, false)
  assert_true(result.error.unwrap_or("").contains("Task code-generator failed"))
  match proposals.find("evo-test-1") {
    Some(p) => assert_eq(p.status, @types.ProposalStatus::Pending)
    None => abort("proposal vanished")
  }
}

// ============================================================================
// 新增：执行日志
// ============================================================================

///|
/// 执行日志的行格式与事件序列。取代 TS L423-428 的直接 `fs.appendFile`
/// （那是 CONTEXT.md 不变量①的越界，已收拢到 store/exec_log.mbt）。
async test "writes an execution log with the legacy line format" {
  let dir = @fs.tmpdir(prefix="evo-exec-")
  defer @fs.rmdir(dir, recursive=true)
  let (executor, proposals, log) = make_executor(dir)
  proposals.save(make_proposal())

  ignore(executor.execute("evo-test-1", dry_run=true))

  let lines = log.read()
  assert_true(lines.length() >= 2)
  // 首行是 start，末行是 complete
  assert_true(
    lines[0].contains("[evo-test-1] [start] Starting execution of evo-test-1"),
  )
  let last = lines[lines.length() - 1]
  assert_true(
    last.contains("[evo-test-1] [complete] Execution completed successfully"),
  )
  // 每层一条 progress
  let mut progress = 0
  for line in lines {
    if line.contains("[progress]") {
      progress += 1
    }
  }
  assert_eq(progress, 3) // cg-merge / tw / integ 三层
}

///|
/// P3（成功面）：执行日志写不进去时，一次**已经成功**的执行不能被改判，
/// 也不能让异常逸出 —— native 后端下未捕获异常会打到 **stdout**，而 stdout
/// 是 MCP 的协议通道（`execute` 自己的注释里就记着这条 Phase 0 实测结论）。
/// 夹具与 H1 同款：把日志路径做成一个目录，`@fs.write_file` 对它必然失败。
/// 修之前的失败点：`executor.mbt` 的 Start 记账落在「兜住一切意外」的
/// catch **之前**，异常直接从 `execute` 逃出去。
async test "an unwritable execution log does not abort a successful execution" {
  let dir = @fs.tmpdir(prefix="evo-exec-")
  defer @fs.rmdir(dir, recursive=true)
  let proposals = @store.ProposalStore::new(
    @util.path_join(dir, "proposals.jsonl"),
  )
  let log_path = @util.path_join(dir, "execution.log")
  @fs.mkdir(log_path, recursive=true)
  let executor = UpgradeExecutor::new(
    proposals,
    @store.ExecutionLog::new(log_path),
  )
  proposals.save(make_proposal())

  let result = executor.execute("evo-test-1", dry_run=true)
  assert_true(result.success)
  match proposals.find("evo-test-1") {
    Some(p) => assert_eq(p.status, @types.ProposalStatus::Completed)
    None => abort("proposal vanished")
  }
}

///|
/// P3（失败面）：验证失败 **且** 日志写不进去时，报告里必须是「验证失败」
/// 这个真实原因，而不是被记账异常顶掉的「Unexpected error」，更不能逸出。
/// 这一条同时钉住 catch 臂自身：它里面也有两处会 raise 的记账写入。
async test "a validation failure is still reported when the log is unwritable" {
  let dir = @fs.tmpdir(prefix="evo-exec-")
  defer @fs.rmdir(dir, recursive=true)
  let proposals = @store.ProposalStore::new(
    @util.path_join(dir, "proposals.jsonl"),
  )
  let log_path = @util.path_join(dir, "execution.log")
  @fs.mkdir(log_path, recursive=true)
  let executor = UpgradeExecutor::new(
    proposals,
    @store.ExecutionLog::new(log_path),
    validate_level=failing_validation,
  )
  proposals.save(make_proposal())

  let result = executor.execute("evo-test-1", dry_run=false)
  assert_eq(result.success, false)
  let reason = result.error.unwrap_or("")
  assert_true(
    reason.contains("T0 validation failed"),
    msg="期望真实的验证失败原因，实际得到: " + reason,
  )
  match proposals.find("evo-test-1") {
    Some(p) => assert_eq(p.status, @types.ProposalStatus::Pending)
    None => abort("proposal vanished")
  }
}
