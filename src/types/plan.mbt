///|
/// 执行计划模型。
///
/// 负责将已批准的提案转化为可执行的计划。
/// 提案批准后，Planner 自动生成执行计划，再传给 Executor 执行。
///
/// **设计理念**：
/// - 职责分离：Planner 负责"想"，Executor 负责"做"
/// - 计划可独立测试、可复用（支持 dry_run 只生成计划）
/// - 符合 Matt Pocock "Deep Module" 原则

///|
/// 执行计划
pub(all) struct ExecutionPlan {
  /// 计划唯一标识
  plan_id : String
  /// 关联的提案 ID
  proposal_id : String
  /// 计划步骤
  steps : Array[PlanStep]
  /// 预估耗时（毫秒）
  estimated_duration_ms : Int64
  /// 创建时间
  created_at : Int64
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 计划步骤
pub(all) struct PlanStep {
  /// 步骤 ID
  step_id : String
  /// 执行的子 Agent 类型
  agent_type : AgentType
  /// 步骤描述
  description : String
  /// 依赖的步骤 ID 列表
  dependencies : Array[String]
  /// 输入参数
  input : Json
  /// 超时时间（毫秒）
  timeout_ms : Int
} derive(Eq, Debug, ToJson, @json.FromJson)
