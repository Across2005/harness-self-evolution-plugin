///|
/// 全部字符串枚举的 wire 表 —— **CONTEXT.md 词汇表在代码里的唯一副本**。
///
/// 每张表同时驱动三件事：
/// 1. JSONL 序列化（`impl ToJson` / `impl FromJson`）
/// 2. MCP `inputSchema` 的 `enum` 数组（`mcp/schema.mbt` 调 `<表>.names()`）
/// 3. 解码失败时错误消息里的合法值列表（`WireEnum::decode` 内部）
///
/// 于是「词汇表」不可能在文档、序列化格式、工具 schema 三处漂移。
/// 表被声明为 `pub let` 而非包内私有，正是为了让 mcp 包能直接复用 `names()`，
/// 而不是在 schema 里再抄一份字符串数组。
///
/// **为什么不用 `derive(ToJson)`**：见 util/wire.mbt 的头注释 ——
/// core/json 对 enum 生成 tagged-array（`["InterfaceSimplification"]`），
/// 会摧毁 CONTEXT.md 规定的 snake_case 词汇表。
///
/// **两条本文件遵守的硬约束**（都由 `moon check` 强制，不是风格偏好）：
/// · 每张表必须显式标注类型。`WireEnum::of` 的元素类型无法从字符串字面量反推，
///   工具链报 [4074] "Cannot infer the type of variable"。
/// · 所有构造器一律**限定书写**（`Confidence::High` 而非 `High`）。
///   本包内 `High`/`Medium`/`Low` 同时属于 `Confidence`、`MigrationEffort`、
///   `UsageFrequency`、`SignalStrength`，工具链报 [4124] "constructor is ambiguous"。
///   统一限定后，将来新增枚举即使撞名也不会波及本文件。
///
/// wire 名逐字取自 legacy-ts/src/types/index.ts 的字符串联合与
/// monitor/index.ts 的实际返回值，并对照 CONTEXT.md L29-59 的三张表校验。
///
/// **全部 impl 都是 `pub impl`**：不加 `pub` 时 impl 只在 types 包内可见，
/// 下游包（executor 序列化 `Array[Change]`、mcp 渲染枚举字段）会报
/// "does not implement trait ToJson: no impl is defined"。
/// 这个错误只会在下游包暴露，types 包自己 check 是绿的，故特别记一笔。

// ============================================================================
// 提案与进化
// ============================================================================

///|
/// CONTEXT.md L31-38 的「进化类型」列（源：types L141-147）。
pub let evolution_type_wire : @util.WireEnum[EvolutionType] = @util.WireEnum::of([
    ("interface_simplification", EvolutionType::InterfaceSimplification),
    ("behavior_optimization", EvolutionType::BehaviorOptimization),
    ("performance_tuning", EvolutionType::PerformanceTuning),
    ("documentation_enhancement", EvolutionType::DocumentationEnhancement),
    ("capability_extension", EvolutionType::CapabilityExtension),
    ("error_handling_improvement", EvolutionType::ErrorHandlingImprovement),
  ],
)

///|
pub impl ToJson for EvolutionType with fn to_json(self) {
  evolution_type_wire.encode(self)
}

///|
pub impl @json.FromJson for EvolutionType with fn from_json(json, path) {
  evolution_type_wire.decode(json, path)
}

///|
/// wire 名。用于拼 `signature`（engine L634 的 `evolutionType.replace(/_/g,'-')`
/// 以此为基础）与错误消息。
pub fn EvolutionType::wire_name(self : EvolutionType) -> String {
  evolution_type_wire.name_of(self)
}

///|
/// CONTEXT.md L19-25 状态机里的五个状态名（源：types L128）。
pub let proposal_status_wire : @util.WireEnum[ProposalStatus] = @util.WireEnum::of([
    ("pending", ProposalStatus::Pending),
    ("approved", ProposalStatus::Approved),
    ("rejected", ProposalStatus::Rejected),
    ("executing", ProposalStatus::Executing),
    ("completed", ProposalStatus::Completed),
  ],
)

///|
pub impl ToJson for ProposalStatus with fn to_json(self) {
  proposal_status_wire.encode(self)
}

///|
pub impl @json.FromJson for ProposalStatus with fn from_json(json, path) {
  proposal_status_wire.decode(json, path)
}

///|
pub fn ProposalStatus::wire_name(self : ProposalStatus) -> String {
  proposal_status_wire.name_of(self)
}

///|
/// CONTEXT.md L40-49 的「应用原则」列。
///
/// **wire 名是 6 个中文字面量，逐字取自 legacy-ts/src/types/index.ts L149-155**
/// —— 这正是「词汇即文档」：提案文档里写的就是这六句话本身，
/// 不做任何英文化改写。`RegularScan`（定期架构扫描）在 TS 里声明了但
/// `selectMattPocockPrinciple`（engine L235-256）从不返回它；
/// 保留在表内是因为类型声明了该变体，删掉会让 wire 表不完整。
pub let principle_wire : @util.WireEnum[MattPocockPrinciple] = @util.WireEnum::of([
    ("先对齐，再动手", MattPocockPrinciple::AlignFirst),
    ("垂直切片 > 水平切片", MattPocockPrinciple::VerticalSlice),
    ("紧反馈环 > 盲目试错", MattPocockPrinciple::TightFeedback),
    ("Deep Module > 浅模块", MattPocockPrinciple::DeepModule),
    ("定期架构扫描", MattPocockPrinciple::RegularScan),
    ("词汇即文档", MattPocockPrinciple::VocabularyAsDocs),
  ],
)

///|
pub impl ToJson for MattPocockPrinciple with fn to_json(self) {
  principle_wire.encode(self)
}

///|
pub impl @json.FromJson for MattPocockPrinciple with fn from_json(json, path) {
  principle_wire.decode(json, path)
}

///|
pub fn MattPocockPrinciple::wire_name(self : MattPocockPrinciple) -> String {
  principle_wire.name_of(self)
}

///|
/// 置信度（源：types L138）。
pub let confidence_wire : @util.WireEnum[Confidence] = @util.WireEnum::of([
  ("high", Confidence::High),
  ("medium", Confidence::Medium),
  ("low", Confidence::Low),
])

///|
pub impl ToJson for Confidence with fn to_json(self) {
  confidence_wire.encode(self)
}

///|
pub impl @json.FromJson for Confidence with fn from_json(json, path) {
  confidence_wire.decode(json, path)
}

///|
pub fn Confidence::wire_name(self : Confidence) -> String {
  confidence_wire.name_of(self)
}

// ============================================================================
// 信号
// ============================================================================

///|
/// 信号强度（源：types L95）。语义见 CONTEXT.md L13。
pub let signal_strength_wire : @util.WireEnum[SignalStrength] = @util.WireEnum::of([
    ("strong", SignalStrength::Strong),
    ("medium", SignalStrength::Medium),
    ("weak", SignalStrength::Weak),
  ],
)

///|
pub impl ToJson for SignalStrength with fn to_json(self) {
  signal_strength_wire.encode(self)
}

///|
pub impl @json.FromJson for SignalStrength with fn from_json(json, path) {
  signal_strength_wire.decode(json, path)
}

///|
pub fn SignalStrength::wire_name(self : SignalStrength) -> String {
  signal_strength_wire.name_of(self)
}

///|
/// 信号类别（源：types L99）。CONTEXT.md L31-38 映射表的键。
pub let signal_category_wire : @util.WireEnum[SignalCategory] = @util.WireEnum::of([
    ("correction", SignalCategory::Correction),
    ("preference", SignalCategory::Preference),
    ("workflow", SignalCategory::Workflow),
    ("struggle", SignalCategory::Struggle),
    ("pattern", SignalCategory::Pattern),
    ("loop", SignalCategory::Loop),
  ],
)

///|
pub impl ToJson for SignalCategory with fn to_json(self) {
  signal_category_wire.encode(self)
}

///|
pub impl @json.FromJson for SignalCategory with fn from_json(json, path) {
  signal_category_wire.decode(json, path)
}

///|
pub fn SignalCategory::wire_name(self : SignalCategory) -> String {
  signal_category_wire.name_of(self)
}

// ============================================================================
// 事件
// ============================================================================

///|
/// 错误分类。wire 名取自 monitor/index.ts L345-349 的**实际返回值**
/// （`timeout` / `parameter_error` / `permission_error` / `not_found` /
/// `runtime_error`），并补上 types L72 声明却从不产出的 `unknown`。
pub let error_kind_wire : @util.WireEnum[ErrorKind] = @util.WireEnum::of([
  ("timeout", ErrorKind::Timeout),
  ("parameter_error", ErrorKind::ParameterError),
  ("permission_error", ErrorKind::PermissionError),
  ("not_found", ErrorKind::NotFound),
  ("runtime_error", ErrorKind::RuntimeError),
  ("unknown", ErrorKind::Unknown),
])

///|
pub impl ToJson for ErrorKind with fn to_json(self) {
  error_kind_wire.encode(self)
}

///|
pub impl @json.FromJson for ErrorKind with fn from_json(json, path) {
  error_kind_wire.decode(json, path)
}

///|
pub fn ErrorKind::wire_name(self : ErrorKind) -> String {
  error_kind_wire.name_of(self)
}

///|
/// 用户反馈极性（源：types L86）。
pub let user_feedback_wire : @util.WireEnum[UserFeedback] = @util.WireEnum::of([
  ("positive", UserFeedback::Positive),
  ("negative", UserFeedback::Negative),
  ("neutral", UserFeedback::Neutral),
])

///|
pub impl ToJson for UserFeedback with fn to_json(self) {
  user_feedback_wire.encode(self)
}

///|
pub impl @json.FromJson for UserFeedback with fn from_json(json, path) {
  user_feedback_wire.decode(json, path)
}

///|
pub fn UserFeedback::wire_name(self : UserFeedback) -> String {
  user_feedback_wire.name_of(self)
}

///|
/// 时间窗（源：types L312、monitor L146）。
/// 同时是 MCP `get_plugin_metrics` 的 `time_range` 参数取值域。
pub let time_range_wire : @util.WireEnum[TimeRange] = @util.WireEnum::of([
  ("last_hour", TimeRange::LastHour),
  ("last_day", TimeRange::LastDay),
  ("last_week", TimeRange::LastWeek),
  ("all", TimeRange::All),
])

///|
pub impl ToJson for TimeRange with fn to_json(self) {
  time_range_wire.encode(self)
}

///|
pub impl @json.FromJson for TimeRange with fn from_json(json, path) {
  time_range_wire.decode(json, path)
}

///|
pub fn TimeRange::wire_name(self : TimeRange) -> String {
  time_range_wire.name_of(self)
}

// ============================================================================
// 变更
// ============================================================================

///|
/// 变更种类。wire 名 = legacy-ts `ProposedChanges` 的 7 个字段名（types L158-164），
/// 逐字保留，使新旧 `proposals.jsonl` 在人类眼里仍然对得上。
/// 被 change.mbt 的手写 `FromJson` 引用。
pub let change_kind_wire : @util.WireEnum[ChangeKind] = @util.WireEnum::of([
  ("merge_tools", ChangeKind::MergeTools),
  ("simplify_params", ChangeKind::SimplifyParams),
  ("add_middleware", ChangeKind::AddMiddleware),
  ("optimize_flow", ChangeKind::OptimizeFlow),
  ("update_documentation", ChangeKind::UpdateDocumentation),
  ("add_capability", ChangeKind::AddCapability),
  ("improve_error_handling", ChangeKind::ImproveErrorHandling),
])

///|
pub impl ToJson for ChangeKind with fn to_json(self) {
  change_kind_wire.encode(self)
}

///|
pub impl @json.FromJson for ChangeKind with fn from_json(json, path) {
  change_kind_wire.decode(json, path)
}

///|
pub fn ChangeKind::wire_name(self : ChangeKind) -> String {
  change_kind_wire.name_of(self)
}

///|
/// 优化手段（源：types L196）。
pub let optimization_kind_wire : @util.WireEnum[OptimizationKind] = @util.WireEnum::of([
    ("caching", OptimizationKind::Caching),
    ("parallelization", OptimizationKind::Parallelization),
    ("lazy_loading", OptimizationKind::LazyLoading),
    ("batching", OptimizationKind::Batching),
  ],
)

///|
pub impl ToJson for OptimizationKind with fn to_json(self) {
  optimization_kind_wire.encode(self)
}

///|
pub impl @json.FromJson for OptimizationKind with fn from_json(json, path) {
  optimization_kind_wire.decode(json, path)
}

///|
pub fn OptimizationKind::wire_name(self : OptimizationKind) -> String {
  optimization_kind_wire.name_of(self)
}

// ============================================================================
// 风险与验证
// ============================================================================

///|
/// 迁移成本（源：types L248）。
pub let migration_effort_wire : @util.WireEnum[MigrationEffort] = @util.WireEnum::of([
    ("low", MigrationEffort::Low),
    ("medium", MigrationEffort::Medium),
    ("high", MigrationEffort::High),
  ],
)

///|
pub impl ToJson for MigrationEffort with fn to_json(self) {
  migration_effort_wire.encode(self)
}

///|
pub impl @json.FromJson for MigrationEffort with fn from_json(json, path) {
  migration_effort_wire.decode(json, path)
}

///|
pub fn MigrationEffort::wire_name(self : MigrationEffort) -> String {
  migration_effort_wire.name_of(self)
}

///|
/// 回滚复杂度（源：types L250）。
pub let rollback_complexity_wire : @util.WireEnum[RollbackComplexity] = @util.WireEnum::of([
    ("simple", RollbackComplexity::Simple),
    ("moderate", RollbackComplexity::Moderate),
    ("complex", RollbackComplexity::Complex),
  ],
)

///|
pub impl ToJson for RollbackComplexity with fn to_json(self) {
  rollback_complexity_wire.encode(self)
}

///|
pub impl @json.FromJson for RollbackComplexity with fn from_json(json, path) {
  rollback_complexity_wire.decode(json, path)
}

///|
pub fn RollbackComplexity::wire_name(self : RollbackComplexity) -> String {
  rollback_complexity_wire.name_of(self)
}

///|
/// 三级验证标签（源：types L239）。大写形式，与 DESIGN.md 的 T0/T1/T2 一致。
pub let validation_level_wire : @util.WireEnum[ValidationLevelTag] = @util.WireEnum::of([
    ("T0", ValidationLevelTag::T0),
    ("T1", ValidationLevelTag::T1),
    ("T2", ValidationLevelTag::T2),
  ],
)

///|
pub impl ToJson for ValidationLevelTag with fn to_json(self) {
  validation_level_wire.encode(self)
}

///|
pub impl @json.FromJson for ValidationLevelTag with fn from_json(json, path) {
  validation_level_wire.decode(json, path)
}

///|
pub fn ValidationLevelTag::wire_name(self : ValidationLevelTag) -> String {
  validation_level_wire.name_of(self)
}

// ============================================================================
// 插件与编排
// ============================================================================

///|
/// 插件来源（源：types L18）。
pub let plugin_kind_wire : @util.WireEnum[PluginKind] = @util.WireEnum::of([
  ("official", PluginKind::Official),
  ("community", PluginKind::Community),
  ("custom", PluginKind::Custom),
])

///|
pub impl ToJson for PluginKind with fn to_json(self) {
  plugin_kind_wire.encode(self)
}

///|
pub impl @json.FromJson for PluginKind with fn from_json(json, path) {
  plugin_kind_wire.decode(json, path)
}

///|
pub fn PluginKind::wire_name(self : PluginKind) -> String {
  plugin_kind_wire.name_of(self)
}

///|
/// 使用频率档位（源：types L32）。
pub let usage_frequency_wire : @util.WireEnum[UsageFrequency] = @util.WireEnum::of([
    ("high", UsageFrequency::High),
    ("medium", UsageFrequency::Medium),
    ("low", UsageFrequency::Low),
    ("idle", UsageFrequency::Idle),
  ],
)

///|
pub impl ToJson for UsageFrequency with fn to_json(self) {
  usage_frequency_wire.encode(self)
}

///|
pub impl @json.FromJson for UsageFrequency with fn from_json(json, path) {
  usage_frequency_wire.decode(json, path)
}

///|
pub fn UsageFrequency::wire_name(self : UsageFrequency) -> String {
  usage_frequency_wire.name_of(self)
}

///|
/// Sub-Agent 角色（源：types L265-270）。wire 名见 CONTEXT.md L51-59 的角色表，
/// 注意是**连字符**形式（`code-generator`），与其余表的下划线风格不同 ——
/// 这是 TS 原样，保持不改以免破坏 execution.log 与提案文档的连续性。
pub let agent_type_wire : @util.WireEnum[AgentType] = @util.WireEnum::of([
  ("code-generator", AgentType::CodeGenerator),
  ("test-writer", AgentType::TestWriter),
  ("doc-writer", AgentType::DocWriter),
  ("integration", AgentType::Integration),
  ("validator", AgentType::Validator),
])

///|
pub impl ToJson for AgentType with fn to_json(self) {
  agent_type_wire.encode(self)
}

///|
pub impl @json.FromJson for AgentType with fn from_json(json, path) {
  agent_type_wire.decode(json, path)
}

///|
pub fn AgentType::wire_name(self : AgentType) -> String {
  agent_type_wire.name_of(self)
}

///|
/// 进化强度（源：types L294）。wire 名是带百分号的字面量，与 README L107-110
/// 和 SKILL.md L380-383 的用户可见文案完全一致。
pub let intensity_wire : @util.WireEnum[Intensity] = @util.WireEnum::of([
  ("100%", Intensity::Full),
  ("50%", Intensity::Half),
  ("0%", Intensity::Off),
])

///|
pub impl ToJson for Intensity with fn to_json(self) {
  intensity_wire.encode(self)
}

///|
pub impl @json.FromJson for Intensity with fn from_json(json, path) {
  intensity_wire.decode(json, path)
}

///|
pub fn Intensity::wire_name(self : Intensity) -> String {
  intensity_wire.name_of(self)
}
