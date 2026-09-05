///|
/// 提案模型 + 提案状态机。取代 legacy-ts/src/types/index.ts L125-251
/// 与 store/index.ts L90, L104-110。
///
/// 本文件把 CONTEXT.md 里的两张表变成**可执行代码**：
/// · L19-25 的提案状态机 → `ProposalStatus::can_transition_to`
/// · L40-49 的「进化类型 ↔ Matt Pocock 原则」映射 → `EvolutionType::principle`
/// 于是文档与实现不可能漂移：改了表就必须改代码，反之亦然。

///|
/// 提案状态。对应 legacy-ts 的 `EvolutionProposal['status']`（types L128）。
pub(all) enum ProposalStatus {
  Pending
  Approved
  Rejected
  Executing
  Completed
} derive(Eq, Debug)

///|
/// CONTEXT.md L19-25 状态机的可执行形式：
/// ```text
/// pending ──approve──▶ approved ──execute──▶ executing ──▶ completed
///    ▲                    │                     │
///    └────── reject ──▶ rejected                └── 失败自动回滚 ──▶ pending
/// ```
/// 穷尽 match 使 5×5 = 25 种组合全部被编译器检查，
/// 取代 store/index.ts L104-110 的 Record 字面量，
/// 并天然消除 L145 `legalTransitions[current.status] ?? []` 的死分支。
pub fn ProposalStatus::can_transition_to(
  self : ProposalStatus,
  next : ProposalStatus,
) -> Bool {
  match self {
    Pending => next == Approved || next == Rejected
    Approved => next == Executing
    Executing => next == Completed || next == Pending
    // 终态：不允许任何迁移
    Completed => false
    Rejected => false
  }
}

///|
/// 进化类型。对应 legacy-ts 的 `EvolutionType`（types L141-147）。
/// wire 名见 CONTEXT.md L31-38。
pub(all) enum EvolutionType {
  InterfaceSimplification
  BehaviorOptimization
  PerformanceTuning
  DocumentationEnhancement
  CapabilityExtension
  ErrorHandlingImprovement
} derive(Eq, Debug)

///|
/// Matt Pocock 六大工程原则。对应 legacy-ts 的 `MattPocockPrinciple`（types L149-155）。
///
/// **wire 名是 6 个中文字面量，原样保留**（CONTEXT.md L44-49 的「词汇即文档」）。
/// MoonBit 的枚举变体必须 PascalCase 且不宜用非 ASCII 标识符，
/// 故源码里用英文变体名，中文串由 `wire_tables.mbt` 的表提供。
pub(all) enum MattPocockPrinciple {
  /// 「先对齐，再动手」
  AlignFirst
  /// 「垂直切片 > 水平切片」
  VerticalSlice
  /// 「紧反馈环 > 盲目试错」
  TightFeedback
  /// 「Deep Module > 浅模块」
  DeepModule
  /// 「定期架构扫描」
  RegularScan
  /// 「词汇即文档」
  VocabularyAsDocs
} derive(Eq, Debug)

///|
/// CONTEXT.md L40-49 映射表的可执行形式。取代 engine/index.ts L231-257。
///
/// 闭合枚举使 TS 版 L254-256 的 `default` 分支被删除 ——
/// 那是个永远走不到的兜底，只会掩盖「新增类型忘了配原则」的错误。
/// 注意 behavior_optimization 与 error_handling_improvement **都**映射到
/// 「紧反馈环 > 盲目试错」，这是 CONTEXT.md 的原始规定，不是笔误。
pub fn EvolutionType::principle(self : EvolutionType) -> MattPocockPrinciple {
  match self {
    InterfaceSimplification => DeepModule
    BehaviorOptimization => TightFeedback
    PerformanceTuning => VerticalSlice
    DocumentationEnhancement => VocabularyAsDocs
    CapabilityExtension => AlignFirst
    ErrorHandlingImprovement => TightFeedback
  }
}

///|
/// 各进化类型的预期收益。取代 engine/index.ts L452-496。
/// 数值区间逐字保留 —— 它们会出现在提案文档里给用户看。
///
/// 字段全为 `Option`，`None` 时 derive 会自动省略该键
/// （实证：core/json/to_json_test.mbt 的 "optional field" 用例
/// `{x:None,t:None}` → `{}`），与 TS 里「不写这个键」的行为一致。
pub fn EvolutionType::expected_benefits(self : EvolutionType) -> ExpectedBenefits {
  match self {
    InterfaceSimplification =>
      {
        latency_improvement: Some("30-40%"),
        token_reduction: Some("25-35%"),
        user_satisfaction: Some("+15-25%"),
        success_rate: None,
        error_reduction: None,
      }
    BehaviorOptimization =>
      {
        latency_improvement: None,
        token_reduction: Some("40-60%"),
        user_satisfaction: None,
        success_rate: None,
        error_reduction: Some("-50%"),
      }
    PerformanceTuning =>
      {
        latency_improvement: Some("20-30%"),
        token_reduction: None,
        user_satisfaction: None,
        success_rate: Some("+5-10%"),
        error_reduction: None,
      }
    DocumentationEnhancement =>
      {
        latency_improvement: None,
        token_reduction: None,
        user_satisfaction: Some("+10-20%"),
        success_rate: None,
        error_reduction: None,
      }
    CapabilityExtension =>
      {
        latency_improvement: None,
        token_reduction: None,
        user_satisfaction: Some("+20-30%"),
        success_rate: Some("+10-15%"),
        error_reduction: None,
      }
    ErrorHandlingImprovement =>
      {
        latency_improvement: None,
        token_reduction: None,
        user_satisfaction: Some("+10-15%"),
        success_rate: None,
        error_reduction: Some("-40-60%"),
      }
  }
}

///|
/// 各进化类型专属的验证场景。取代 engine/index.ts L531-542 的 switch。
/// 插件能力相关的场景由 engine 另行追加（取 capabilities 前 3 个）。
pub fn EvolutionType::extra_scenarios(self : EvolutionType) -> Array[String] {
  match self {
    InterfaceSimplification => ["测试新工具接口", "测试向后兼容性"]
    BehaviorOptimization => ["测试循环检测", "测试干预提示"]
    PerformanceTuning => ["性能基准测试", "负载测试"]
    DocumentationEnhancement => []
    CapabilityExtension => []
    ErrorHandlingImprovement => []
  }
}

///|
/// 置信度。对应 legacy-ts 的 `EvolutionProposal['confidence']`（types L138）。
pub(all) enum Confidence {
  High
  Medium
  Low
} derive(Eq, Debug)

///|
/// 一份进化提案。对应 legacy-ts 的 `EvolutionProposal`（types L125-139）。
/// 字段顺序与 TS interface 一致 —— 这是 `proposals.jsonl` 与 MCP 输出
/// 能与 TS 版对拍的前提。
pub(all) struct EvolutionProposal {
  /// 形如 `evo-2026-09-04-browser-use-interface-simplification`
  proposal_id : String
  plugin_id : String
  status : ProposalStatus
  /// 原 `created_at : string`（types L129）→ Unix 毫秒。
  /// 消灭 store/index.ts L172 的 `new Date(p.created_at).getTime()`。
  created_at : Int64
  trigger_signals : Array[EvolutionSignal]
  evolution_type : EvolutionType
  matt_pocock_principle : MattPocockPrinciple
  /// 原 `ProposedChanges`（types L133 / L157-165）→ 变体列表。见 change.mbt。
  proposed_changes : Array[Change]
  expected_benefits : ExpectedBenefits
  validation_plan : ValidationPlan
  risk_assessment : RiskAssessment
  /// 去重签名，形如 `<plugin-name>-<evolution-type>`
  signature : String
  confidence : Confidence
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 预期收益。对应 legacy-ts 的 `ExpectedBenefits`（types L223-229）。
pub(all) struct ExpectedBenefits {
  latency_improvement : String?
  token_reduction : String?
  user_satisfaction : String?
  success_rate : String?
  error_reduction : String?
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 验证计划。对应 legacy-ts 的 `ValidationPlan`（types L231-236）。
pub(all) struct ValidationPlan {
  test_scenarios : Array[String]
  success_criteria : String
  rollback_strategy : String
  validation_levels : Array[ValidationLevel]
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 单级验证。对应 legacy-ts 的 `ValidationLevel`（types L238-243）。
pub(all) struct ValidationLevel {
  level : ValidationLevelTag
  description : String
  automated : Bool
  timeout_ms : Int?
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 三级验证标签。对应 legacy-ts 的 `'T0' | 'T1' | 'T2'`（types L239）。
///
/// 闭合后 `'T9'` **不可构造** —— 这直接影响 executor 的一个测试：
/// legacy-ts/tests/executor.test.ts L121-142 正是靠 `'T9' as any`
/// 触发 executor L386-393 的 "Unknown validation level" 分支，
/// 进而覆盖「失败 → 回滚 → 回 pending」这条路径。
/// 解法见 executor/runner.mbt 的 `LevelValidator` trait 注入缝：
/// 测试注入一个必定失败的实现，覆盖的是「验证失败」这一**真实语义**，
/// 而不是「等级名拼错」这一实现巧合 —— 比 TS 版更强。
pub(all) enum ValidationLevelTag {
  T0
  T1
  T2
} derive(Eq, Debug)

///|
/// 风险评估。对应 legacy-ts 的 `RiskAssessment`（types L245-251）。
pub(all) struct RiskAssessment {
  breaking_changes : Bool
  backward_compatible : Bool
  migration_effort : MigrationEffort
  affected_users : Int
  rollback_complexity : RollbackComplexity
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 迁移成本。对应 legacy-ts 的 `'low' | 'medium' | 'high'`（types L248）。
pub(all) enum MigrationEffort {
  Low
  Medium
  High
} derive(Eq, Debug)

///|
/// 回滚复杂度。对应 legacy-ts 的 `'simple' | 'moderate' | 'complex'`（types L250）。
pub(all) enum RollbackComplexity {
  Simple
  Moderate
  Complex
} derive(Eq, Debug)

///|
/// 取代 engine/index.ts L568 的嵌套三元表达式
/// `migrationEffort === 'low' ? 'simple' : migrationEffort === 'medium' ? 'moderate' : 'complex'`。
pub fn MigrationEffort::rollback_complexity(
  self : MigrationEffort,
) -> RollbackComplexity {
  match self {
    MigrationEffort::Low => RollbackComplexity::Simple
    MigrationEffort::Medium => RollbackComplexity::Moderate
    MigrationEffort::High => RollbackComplexity::Complex
  }
}

///|
/// 查询指标的时间窗。对应 legacy-ts 的
/// `'last_hour' | 'last_day' | 'last_week' | 'all'`（types L312、monitor L146）。
///
/// 定义在 types 而非 monitor：它同时是 MCP `get_plugin_metrics` 的
/// `inputSchema.enum` 取值，属于跨模块共享的领域词汇。
pub(all) enum TimeRange {
  LastHour
  LastDay
  LastWeek
  All
} derive(Eq, Debug)

///|
/// 该时间窗对应的毫秒跨度；`All` 返回 0（即不设下界）。
/// 取代 monitor/index.ts L355-366 的 `calculateCutoff` switch。
pub fn TimeRange::span_ms(self : TimeRange) -> Int64 {
  match self {
    LastHour => 3_600_000L
    LastDay => 86_400_000L
    LastWeek => 604_800_000L
    All => 0L
  }
}

///|
/// 以 `now` 为基准的截止时间戳；`All` 返回 0，即接受全部历史。
pub fn TimeRange::cutoff_ms(self : TimeRange, now : Int64) -> Int64 {
  let span = self.span_ms()
  if span == 0L {
    0L
  } else {
    // now - span 可能为负（时钟异常或 span 大于纪元至今），夹到 0
    let cutoff = now - span
    if cutoff < 0L {
      0L
    } else {
      cutoff
    }
  }
}
