///|
/// 提案变更模型。取代 legacy-ts/src/types/index.ts L157-221。
///
/// **本文件解决的是一个硬阻塞，不只是风格改进。**
/// TS 的 `ProposedChanges`（types L157-165）是 7 个可选数组字段：
/// ```ts
/// export interface ProposedChanges {
///   merge_tools?: ToolMerge[]
///   simplify_params?: ParamSimplification[]
///   ... // 共 7 个
/// }
/// ```
/// 于是 `engine/index.ts` L615 为了统计「有几类变更」写下了
/// ```ts
/// const changeCount = Object.values(changes).filter(v => v && v.length > 0).length
/// ```
/// —— 依赖 **JS 运行时对象反射**。MoonBit 是静态编译语言，没有 `Object.values`，
/// 这行代码**无法移植**。改成 `Array[Change]` 变体列表后，
/// 变更种类数就是 `changes_kinds(cs).length()`，且新增变更种类时
/// 编译器会强制更新所有 `match` 消费点（穷尽性检查）。
///
/// 同时收敛掉另外两处结构性债务：
/// · `executor/index.ts` L142-206 的 5 段近乎相同的 `if (changes.x && changes.x.length > 0)`
///   → 一次穷尽 match
/// · `engine/index.ts` L592-606 `checkBackwardCompatibility` 在「空变更集」时
///   两个 `?.every()` 都返回 `undefined` → 整体 `false`，但「无变更」显然向后兼容；
///   而 `merge_tools: []` 时 `[].every()` 为 `true` → 返回 `true`。同为空却结论相反。
///   新版对空集统一返回 `true`（这是一处**有意的语义修正**，已记入 CONTEXT.md）。

///|
/// 变更种类。wire 名与 TS 的字段名逐字一致，保证 JSONL 可读性与文档连续性。
pub(all) enum ChangeKind {
  MergeTools
  SimplifyParams
  AddMiddleware
  OptimizeFlow
  UpdateDocumentation
  AddCapability
  ImproveErrorHandling
} derive(Eq, Debug)

///|
/// 一条提案变更。取代 TS 的 `ProposedChanges` 7 字段结构。
///
/// 序列化采用手写的 `{"kind": ..., "items": [...]}` 自描述形式：
/// `proposals.jsonl` 是低频、面向人类审批决策的文档，可读性优先。
pub(all) enum Change {
  MergeTools(Array[ToolMerge])
  SimplifyParams(Array[ParamSimplification])
  AddMiddleware(Array[MiddlewareAddition])
  OptimizeFlow(Array[FlowOptimization])
  UpdateDocumentation(Array[DocumentationUpdate])
  AddCapability(Array[CapabilityAddition])
  ImproveErrorHandling(Array[ErrorHandlingImprovement])
} derive(Eq, Debug)

///|
/// 该变更属于哪一类。
///
/// 右侧构造器全部限定为 `ChangeKind::X`：`Change` 与 `ChangeKind` 共享全部 7 个
/// 变体名，不限定会报 [4124] "constructor is ambiguous"。
pub fn Change::kind(self : Change) -> ChangeKind {
  match self {
    MergeTools(_) => ChangeKind::MergeTools
    SimplifyParams(_) => ChangeKind::SimplifyParams
    AddMiddleware(_) => ChangeKind::AddMiddleware
    OptimizeFlow(_) => ChangeKind::OptimizeFlow
    UpdateDocumentation(_) => ChangeKind::UpdateDocumentation
    AddCapability(_) => ChangeKind::AddCapability
    ImproveErrorHandling(_) => ChangeKind::ImproveErrorHandling
  }
}

///|
/// 该变更是否为空（`items` 长度为 0）。空变更不应进入提案。
pub fn Change::is_empty(self : Change) -> Bool {
  match self {
    MergeTools(xs) => xs.is_empty()
    SimplifyParams(xs) => xs.is_empty()
    AddMiddleware(xs) => xs.is_empty()
    OptimizeFlow(xs) => xs.is_empty()
    UpdateDocumentation(xs) => xs.is_empty()
    AddCapability(xs) => xs.is_empty()
    ImproveErrorHandling(xs) => xs.is_empty()
  }
}

///|
/// 取出**非空**变更的种类，保持原顺序。
/// 于是「变更种类数」= `changes_kinds(cs).length()`，
/// 直接替换 engine L615 的 `Object.values(...).filter(...).length`。
pub fn changes_kinds(cs : ArrayView[Change]) -> Array[ChangeKind] {
  let out : Array[ChangeKind] = []
  for c in cs {
    if !c.is_empty() {
      out.push(c.kind())
    }
  }
  out
}

// 下面两个 impl 必须是 `pub impl`：不加 pub 时它们只在 types 包内可见，
// 于是 executor 跳包调 `ToJson::to_json(Array[Change])` 会报
// "type Change does not implement trait ToJson: no impl is defined"。
// （types 包内部的 derive 能看见它们，所以这个错误只会在下游包暴露。）
pub impl ToJson for Change with fn to_json(self : Change) -> Json {
  // "kind" 一律取自 `ChangeKind` 的 wire 表，**不在本文件重写字面量** ——
  // 否则词汇表就有了两份副本，正是 util/wire.mbt 要消除的问题。
  //
  // 用 `ToJson::to_json(x)` 而非 `x.to_json()`：后者是「从 impl 隐式提升为方法」，
  // 本工具链已标为 deprecated。
  let kind = ToJson::to_json(self.kind())
  let items = match self {
    MergeTools(xs) => ToJson::to_json(xs)
    SimplifyParams(xs) => ToJson::to_json(xs)
    AddMiddleware(xs) => ToJson::to_json(xs)
    OptimizeFlow(xs) => ToJson::to_json(xs)
    UpdateDocumentation(xs) => ToJson::to_json(xs)
    AddCapability(xs) => ToJson::to_json(xs)
    ImproveErrorHandling(xs) => ToJson::to_json(xs)
  }
  { "kind": kind, "items": items }
}

pub impl @json.FromJson for Change with fn from_json(
  json : Json,
  path : @json.JsonPath,
) -> Change raise @json.JsonDecodeError {
  guard json is Object(obj) else {
    raise @json.JsonDecodeError((path, "Change: expected a JSON object"))
  }
  let kind_path = path.add_key("kind")
  let kind_json = match obj.get("kind") {
    Some(j) => j
    None => raise @json.JsonDecodeError((kind_path, "Change: missing \"kind\""))
  }
  // 走 ChangeKind 的公开 FromJson impl（它内部转发给 wire 表）。
  // 刻意不在此直接调 `change_kind_wire.decode`：那会多出一条与 impl 平行的
  // 解码路径，两者一旦行为不一致就无从发现。单一入口 = 单一事实来源。
  // 未知 kind 的错误消息（含全部合法值）由表自动给出。
  let kind : ChangeKind = @json.from_json(kind_json, path=kind_path)
  let items_path = path.add_key("items")
  let items = match obj.get("items") {
    Some(j) => j
    None => raise @json.JsonDecodeError((items_path, "Change: missing \"items\""))
  }
  match kind {
    ChangeKind::MergeTools =>
      Change::MergeTools(@json.from_json(items, path=items_path))
    ChangeKind::SimplifyParams =>
      Change::SimplifyParams(@json.from_json(items, path=items_path))
    ChangeKind::AddMiddleware =>
      Change::AddMiddleware(@json.from_json(items, path=items_path))
    ChangeKind::OptimizeFlow =>
      Change::OptimizeFlow(@json.from_json(items, path=items_path))
    ChangeKind::UpdateDocumentation =>
      Change::UpdateDocumentation(@json.from_json(items, path=items_path))
    ChangeKind::AddCapability =>
      Change::AddCapability(@json.from_json(items, path=items_path))
    ChangeKind::ImproveErrorHandling =>
      Change::ImproveErrorHandling(@json.from_json(items, path=items_path))
  }
}

// ============================================================================
// 以下 7 个 struct 与 legacy-ts/src/types/index.ts L167-221 逐字段、逐顺序对应。
// 字段声明顺序决定 Json 输出顺序，是双跑对拍能对齐的前提，不得重排。
// ============================================================================

///|
/// 工具合并。对应 TS 的 `ToolMerge`（types L167-176）。
pub(all) struct ToolMerge {
  new_tool : String
  merged_from : Array[String]
  new_interface : NewToolInterface
  backward_compatible : Bool
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 合并后新工具的接口描述。对应 TS 的 `ToolMerge['new_interface']`（types L170-174）。
pub(all) struct NewToolInterface {
  params : Array[String]
  description : String
  defaults : Json?
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 参数简化。对应 TS 的 `ParamSimplification`（types L178-183）。
pub(all) struct ParamSimplification {
  tool : String
  remove_params : Array[String]
  defaults : Json
  reason : String
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 中间件新增。对应 TS 的 `MiddlewareAddition`（types L185-192）。
pub(all) struct MiddlewareAddition {
  name : String
  target_tool : String?
  target_event : String?
  threshold : Int?
  intervention : String
  priority : Int
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 流程优化。对应 TS 的 `FlowOptimization`（types L194-199）。
pub(all) struct FlowOptimization {
  tool : String
  optimization : OptimizationKind
  implementation : String
  expected_improvement : String
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 优化手段。对应 TS 的 `FlowOptimization['optimization_type']`（types L196）。
pub(all) enum OptimizationKind {
  Caching
  Parallelization
  LazyLoading
  Batching
} derive(Eq, Debug)

///|
/// 文档更新。对应 TS 的 `DocumentationUpdate`（types L201-206）。
pub(all) struct DocumentationUpdate {
  file : String
  section : String
  new_content : String
  reason : String
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 能力扩展。对应 TS 的 `CapabilityAddition`（types L208-213）。
pub(all) struct CapabilityAddition {
  capability_name : String
  description : String
  implementation : String
  dependencies : Array[String]
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 错误处理改进。对应 TS 的 `ErrorHandlingImprovement`（types L215-221）。
pub(all) struct ErrorHandlingImprovement {
  error_type : String
  current_behavior : String
  improved_behavior : String
  user_message : String
  recovery_strategy : String
} derive(Eq, Debug, ToJson, @json.FromJson)
