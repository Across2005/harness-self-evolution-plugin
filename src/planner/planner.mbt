///|
/// 计划生成模块
///
/// 负责将已批准的提案转化为可执行的计划。
/// 提案批准后，Planner 自动生成执行计划，再传给 Executor 执行。
///
/// **设计理念**：
/// - 职责分离：Planner 负责"想"，Executor 负责"做"
/// - 计划可独立测试、可复用（支持 dry_run 只生成计划）
/// - 符合 Matt Pocock "Deep Module" 原则

///|
/// 生成执行计划
///
/// 将已批准的提案转化为可执行的计划。
///
/// **计划生成流程**：
/// 1. 分析提案 — 解析 `proposed_changes`，提取变更类型
/// 2. 评估复杂度 — 基于变更数量、依赖关系、插件规模
/// 3. 生成步骤 — 每个变更类型映射到对应的 Agent 类型和步骤
/// 4. 构建依赖图 — 分析步骤间的依赖关系
/// 5. 输出计划 — 生成 `ExecutionPlan` 结构
pub fn generate_plan(
  proposal : @types.EvolutionProposal,
) -> @types.ExecutionPlan {
  let steps : Array[@types.PlanStep] = []
  let mut step_index = 0
  
  // 为每个变更生成步骤
  for change in proposal.proposed_changes {
    let step = generate_step(change, proposal, step_index)
    steps.push(step)
    step_index = step_index + 1
  }
  
  // 添加验证步骤
  let validation_step : @types.PlanStep = {
    step_id: "validation-\{step_index}",
    agent_type: @types.AgentType::Validator,
    description: "执行三级验证（T0/T1/T2）",
    dependencies: steps.map(fn(s : @types.PlanStep) { s.step_id }),
    input: Json::empty_object(),
    timeout_ms: 300000,
  }
  steps.push(validation_step)
  
  // 生成计划 ID
  let plan_id = "plan-\{proposal.proposal_id}"
  
  // 估算总耗时
  // 变更步骤可以并行执行，取最大超时
  // 验证步骤串行执行，累加超时
  let mut max_change_timeout = 0L
  let mut validation_timeout = 0L
  for step in steps {
    if step.agent_type == @types.AgentType::Validator {
      validation_timeout = validation_timeout + step.timeout_ms.to_int64()
    } else {
      let t = step.timeout_ms.to_int64()
      if t > max_change_timeout {
        max_change_timeout = t
      }
    }
  }
  
  {
    plan_id,
    proposal_id: proposal.proposal_id,
    steps,
    estimated_duration_ms: max_change_timeout + validation_timeout,
    created_at: @util.now_ms(),
  }
}

///|
/// 为单个变更生成步骤
fn generate_step(
  change : @types.Change,
  proposal : @types.EvolutionProposal,
  index : Int,
) -> @types.PlanStep {
  let (agent_type, description, timeout_ms) = match change {
    @types.Change::MergeTools(_) =>
      (@types.AgentType::CodeGenerator, "实现工具合并", 120000)
    @types.Change::SimplifyParams(_) =>
      (@types.AgentType::CodeGenerator, "简化工具参数", 60000)
    @types.Change::AddMiddleware(_) =>
      (@types.AgentType::CodeGenerator, "添加中间件", 60000)
    @types.Change::OptimizeFlow(_) =>
      (@types.AgentType::CodeGenerator, "优化工具流程", 90000)
    @types.Change::UpdateDocumentation(_) =>
      (@types.AgentType::DocWriter, "更新文档", 60000)
    @types.Change::AddCapability(_) =>
      (@types.AgentType::CodeGenerator, "添加新能力", 120000)
    @types.Change::ImproveErrorHandling(_) =>
      (@types.AgentType::CodeGenerator, "改进错误处理", 60000)
  }
  
  {
    step_id: "\{agent_type.wire_name()}-\{index}",
    agent_type,
    description: "\{description}: \{proposal.proposal_id}",
    dependencies: [],
    input: Json::empty_object(),
    timeout_ms,
  }
}

///|
/// 清理已完成提案的计划细节
///
/// 提案状态变为 `completed` 后，自动清除 `plan` 字段：
/// - 保留提案元数据
/// - 只清除计划细节
/// - 避免残留上下文被反复读取
pub fn cleanup_completed_plan(
  proposal : @types.EvolutionProposal,
) -> @types.EvolutionProposal {
  // 只有 completed 状态的提案才清理计划
  // 避免 pending/approved/executing 状态的提案计划被意外清除
  if proposal.status == @types.ProposalStatus::Completed {
    {
      ..proposal,
      plan: None,
    }
  } else {
    proposal
  }
}
