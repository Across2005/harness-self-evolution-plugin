///|
/// Sub-Agent 编排模型。取代 legacy-ts/src/types/index.ts L257-279。
///
/// **这里修掉了一处语义错误的死字段。**
/// TS 的 `SubAgentTask.dependencies`（types L261）注释写着 "Other task IDs"，
/// 但 `executor/index.ts` 实际填的是 **AgentType 字符串**：
/// L193 `dependencies: [tasks[tasks.length - 1].agent]`、
/// L217 `dependencies: ['code-generator', 'test-writer']`。
/// 而当提案同时含多类变更时，`decomposeTasks` 会产出**最多 5 个** code-generator
/// 任务（L142-185），此时「依赖 code-generator」到底是哪一个完全歧义。
/// 更要紧的是：该字段**全仓无任何读取点**，从未被用于排序 ——
/// 所以 executor L76 的任务是纯串行执行的，尽管其中大部分并无真实依赖。
///
/// 新版给出稳定的任务 `id` 与真正的 task-id `deps`，
/// 由 executor/dag.mbt 做拓扑分层、层内并行，并用 `timeout_ms` 强制真超时
/// （TS 的 `timeout_ms` 同样从未被强制执行）。

///|
/// Sub-Agent 角色。对应 legacy-ts 的 `AgentType`（types L265-270），
/// wire 名见 CONTEXT.md L51-59 的角色表。
pub(all) enum AgentType {
  CodeGenerator
  TestWriter
  DocWriter
  Integration
  Validator
} derive(Eq, Debug)

///|
/// 一个 Sub-Agent 任务。
pub(all) struct SubAgentTask {
  /// 稳定标识，供 `deps` 引用。形如 `cg-merge` / `tw` / `dw` / `integ`。
  id : String
  agent : AgentType
  /// 交给该 Agent 的自然语言任务描述
  task : String
  /// 任务输入（原 TS 为 `any`）
  input : Json
  /// 依赖的**任务 id** 列表（不是 agent 类型名）。空数组表示可立即执行。
  deps : Array[String]
  /// 超时毫秒数。由 executor 经 `@async.with_timeout_opt` **真正强制**，
  /// 超时即视为任务失败并触发回滚。
  timeout_ms : Int
} derive(Eq, Debug, ToJson)

///|
/// 一个 Sub-Agent 任务的执行结果。对应 legacy-ts 的 `SubAgentResult`（types L272-279）。
pub(all) struct SubAgentResult {
  task_id : String
  agent : AgentType
  success : Bool
  output : Json?
  error : String?
  duration_ms : Int64
} derive(Eq, Debug, ToJson)
