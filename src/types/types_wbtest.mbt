///|
/// wire 表的表驱动往返测试 —— **本包最重要的一份测试**。
///
/// 它守住的是「词汇表覆盖完整性」这一最易出错、且出错后最隐蔽的性质：
/// 若某张表漏了一个变体，`name_of` 会在**运行时** abort，
/// 而编译期一切正常。逐个变体走一遍 encode → parse → decode，
/// 就能把这类错误从生产环境挪到 CI。
///
/// 同时钉死 D3：wire 形式必须是 **JSON 字符串**，绝不能是 `derive(ToJson)`
/// 对 enum 生成的 tagged-array（`["InterfaceSimplification"]`）。
/// 这条断言一旦失败，说明有人图省事把某个枚举改回了 derive。
///
/// 用白盒测试（`_wbtest.mbt`）：一是可以直接引用包内的 18 张表，
/// 二是这些 impl 在本包编译单元内被真实使用，
/// 不会触发 unused_value 警告。

///|
/// 逐变体做 `to_json → stringify → parse → from_json` 往返，
/// 并断言 wire 形式是 JSON 字符串。
///
/// 签名带 `raise`：`@json.parse` 与 `@json.from_json` 都会抛错，
/// 而工具链要求「只能在自己也声明了错误类型的函数里调用带错函数」。
/// 往返失败本身就是测试失败，故不在此处 catch，直接向上抛。
fn[T : Eq + ToJson + @json.FromJson] round_trip(
  label : String,
  variants : Array[T],
) -> Unit raise {
  for v in variants {
    // `ToJson::to_json(v)` 而非 `v.to_json()`：后者是隐式提升，已 deprecated
    let json = ToJson::to_json(v)
    if not_is_string(json) {
      abort(
        "\{label}: wire form must be a JSON string, not a tagged array (see decision D3)",
      )
    }
    let text = json.stringify()
    let reparsed = @json.parse(text)
    let back : T = @json.from_json(reparsed)
    if back != v {
      abort("\{label}: round-trip failed for \{text}")
    }
  }
}

fn not_is_string(json : Json) -> Bool {
  match json {
    String(_) => false
    _ => true
  }
}

///|
/// 断言一张表的 wire 名无重复、且数量与枚举变体数一致。
/// 重复的 wire 名会让 decode 永远只命中第一个，是静默数据损坏。
///
/// 不带 `T : Eq` 约束：本函数只调 `names()`，不比较 `T` 值，
/// 多余的约束会被工具链判为 unused_trait_bound。
fn[T] check_table(
  label : String,
  table : @util.WireEnum[T],
  expected : Int,
) -> Unit {
  let names = table.names()
  if names.length() != expected {
    abort("\{label}: expected \{expected} wire names, got \{names.length()}")
  }
  let seen : Map[String, Unit] = Map([])
  for n in names {
    if seen.contains(n) {
      abort("\{label}: duplicate wire name \"\{n}\"")
    }
    seen.set(n, ())
  }
}

test "every string enum round-trips through its wire table" {
  round_trip(
    "EvolutionType",
    [
      EvolutionType::InterfaceSimplification,
      EvolutionType::BehaviorOptimization,
      EvolutionType::PerformanceTuning,
      EvolutionType::DocumentationEnhancement,
      EvolutionType::CapabilityExtension,
      EvolutionType::ErrorHandlingImprovement,
    ],
  )
  round_trip(
    "ProposalStatus",
    [
      ProposalStatus::Pending,
      ProposalStatus::Approved,
      ProposalStatus::Rejected,
      ProposalStatus::Executing,
      ProposalStatus::Completed,
    ],
  )
  round_trip(
    "MattPocockPrinciple",
    [
      MattPocockPrinciple::AlignFirst,
      MattPocockPrinciple::VerticalSlice,
      MattPocockPrinciple::TightFeedback,
      MattPocockPrinciple::DeepModule,
      MattPocockPrinciple::RegularScan,
      MattPocockPrinciple::VocabularyAsDocs,
    ],
  )
  round_trip(
    "Confidence",
    [Confidence::High, Confidence::Medium, Confidence::Low],
  )
  round_trip(
    "SignalStrength",
    [SignalStrength::Strong, SignalStrength::Medium, SignalStrength::Weak],
  )
  round_trip(
    "SignalCategory",
    [
      SignalCategory::Correction,
      SignalCategory::Preference,
      SignalCategory::Workflow,
      SignalCategory::Struggle,
      SignalCategory::Pattern,
      SignalCategory::Loop,
    ],
  )
  round_trip(
    "ErrorKind",
    [
      ErrorKind::Timeout,
      ErrorKind::ParameterError,
      ErrorKind::PermissionError,
      ErrorKind::NotFound,
      ErrorKind::RuntimeError,
      ErrorKind::Unknown,
    ],
  )
  round_trip(
    "UserFeedback",
    [UserFeedback::Positive, UserFeedback::Negative, UserFeedback::Neutral],
  )
  round_trip(
    "TimeRange",
    [
      TimeRange::LastHour,
      TimeRange::LastDay,
      TimeRange::LastWeek,
      TimeRange::All,
    ],
  )
  round_trip(
    "ChangeKind",
    [
      ChangeKind::MergeTools,
      ChangeKind::SimplifyParams,
      ChangeKind::AddMiddleware,
      ChangeKind::OptimizeFlow,
      ChangeKind::UpdateDocumentation,
      ChangeKind::AddCapability,
      ChangeKind::ImproveErrorHandling,
    ],
  )
  round_trip(
    "OptimizationKind",
    [
      OptimizationKind::Caching,
      OptimizationKind::Parallelization,
      OptimizationKind::LazyLoading,
      OptimizationKind::Batching,
    ],
  )
  round_trip(
    "MigrationEffort",
    [MigrationEffort::Low, MigrationEffort::Medium, MigrationEffort::High],
  )
  round_trip(
    "RollbackComplexity",
    [
      RollbackComplexity::Simple,
      RollbackComplexity::Moderate,
      RollbackComplexity::Complex,
    ],
  )
  round_trip(
    "ValidationLevelTag",
    [ValidationLevelTag::T0, ValidationLevelTag::T1, ValidationLevelTag::T2],
  )
  round_trip(
    "PluginKind",
    [PluginKind::Official, PluginKind::Community, PluginKind::Custom],
  )
  round_trip(
    "UsageFrequency",
    [
      UsageFrequency::High,
      UsageFrequency::Medium,
      UsageFrequency::Low,
      UsageFrequency::Idle,
    ],
  )
  round_trip(
    "AgentType",
    [
      AgentType::CodeGenerator,
      AgentType::TestWriter,
      AgentType::DocWriter,
      AgentType::Integration,
      AgentType::Validator,
    ],
  )
  round_trip("Intensity", [Intensity::Full, Intensity::Half, Intensity::Off])
}

test "every wire table is complete and has no duplicate names" {
  check_table("evolution_type_wire", evolution_type_wire, 6)
  check_table("proposal_status_wire", proposal_status_wire, 5)
  check_table("principle_wire", principle_wire, 6)
  check_table("confidence_wire", confidence_wire, 3)
  check_table("signal_strength_wire", signal_strength_wire, 3)
  check_table("signal_category_wire", signal_category_wire, 6)
  check_table("error_kind_wire", error_kind_wire, 6)
  check_table("user_feedback_wire", user_feedback_wire, 3)
  check_table("time_range_wire", time_range_wire, 4)
  check_table("change_kind_wire", change_kind_wire, 7)
  check_table("optimization_kind_wire", optimization_kind_wire, 4)
  check_table("migration_effort_wire", migration_effort_wire, 3)
  check_table("rollback_complexity_wire", rollback_complexity_wire, 3)
  check_table("validation_level_wire", validation_level_wire, 3)
  check_table("plugin_kind_wire", plugin_kind_wire, 3)
  check_table("usage_frequency_wire", usage_frequency_wire, 4)
  check_table("agent_type_wire", agent_type_wire, 5)
  check_table("intensity_wire", intensity_wire, 3)
}

///|
/// 上面的 `round_trip` 是泛型 helper，工具链的 unused_value lint 看不到
/// 单态化后的具体 impl 使用。本用例用**具体类型标注**走一遍公开编解码路径 ——
/// 这也正是生产代码（monitor 的统计响应、mcp 的工具参数解码）实际走的路径。
///
/// 针对的是两个目前尚无业务消费者的枚举：
/// · `TimeRange` —— Phase 5 的 `get_plugin_metrics` 会回显它，Phase 8 的
///   `GetMetricsArgs` 会从它解码
/// · `AgentType` —— Phase 7 的 `SubAgentResult` 会携带它
test "TimeRange and AgentType encode/decode through their public impls" {
  // ToJson
  inspect(
    ToJson::to_json(TimeRange::LastWeek).stringify(),
    content="\"last_week\"",
  )
  inspect(ToJson::to_json(TimeRange::All).stringify(), content="\"all\"")
  inspect(
    ToJson::to_json(AgentType::CodeGenerator).stringify(),
    content="\"code-generator\"",
  )
  // FromJson
  let week_raw = #|"last_week"
  let week : TimeRange = @json.from_json(@json.parse(week_raw))
  assert_eq(week, TimeRange::LastWeek)

  let hour_raw = #|"last_hour"
  let hour : TimeRange = @json.from_json(@json.parse(hour_raw))
  assert_eq(hour, TimeRange::LastHour)

  // AgentType 的 wire 名是连字符形式（CONTEXT.md L51-59），与其余表不同
  let cg_raw = #|"code-generator"
  let cg : AgentType = @json.from_json(@json.parse(cg_raw))
  assert_eq(cg, AgentType::CodeGenerator)

  let validator_raw = #|"validator"
  let validator : AgentType = @json.from_json(@json.parse(validator_raw))
  assert_eq(validator, AgentType::Validator)
}

///|
/// CONTEXT.md L29-49 的词汇表必须与代码逐字一致。
/// 这条测试是「词汇即文档」的机器化守卫：改了 CONTEXT.md 就必须改这里，反之亦然。
test "wire names match the CONTEXT.md vocabulary verbatim" {
  json_inspect(
    evolution_type_wire.names(),
    content=[
      "interface_simplification",
      "behavior_optimization",
      "performance_tuning",
      "documentation_enhancement",
      "capability_extension",
      "error_handling_improvement",
    ],
  )
  // CONTEXT.md L40-49 的「应用原则」列。注意 behavior_optimization 与
  // error_handling_improvement 都映射到「紧反馈环 > 盲目试错」。
  json_inspect(
    [
      EvolutionType::InterfaceSimplification.principle().wire_name(),
      EvolutionType::BehaviorOptimization.principle().wire_name(),
      EvolutionType::PerformanceTuning.principle().wire_name(),
      EvolutionType::DocumentationEnhancement.principle().wire_name(),
      EvolutionType::CapabilityExtension.principle().wire_name(),
      EvolutionType::ErrorHandlingImprovement.principle().wire_name(),
    ],
    content=[
      "Deep Module > 浅模块",
      "紧反馈环 > 盲目试错",
      "垂直切片 > 水平切片",
      "词汇即文档",
      "先对齐，再动手",
      "紧反馈环 > 盲目试错",
    ],
  )
  // CONTEXT.md L51-59 的 Sub-Agent 角色表用连字符，与其余表的下划线风格不同
  json_inspect(
    agent_type_wire.names(),
    content=[
      "code-generator",
      "test-writer",
      "doc-writer",
      "integration",
      "validator",
    ],
  )
  // monitor L345-349 的实际返回值，含 types L72 遗漏的 not_found
  json_inspect(
    error_kind_wire.names(),
    content=[
      "timeout",
      "parameter_error",
      "permission_error",
      "not_found",
      "runtime_error",
      "unknown",
    ],
  )
}

///|
/// 未知 wire 名必须被拒绝，且错误消息列出全部合法值 ——
/// 这条消息会经 MCP 的 isError 响应回到 LLM 面前，让它能自我纠正。
test "decoding an unknown wire name fails with the legal value list" {
  let msg = try {
    let _v : EvolutionType = @json.from_json(Json::string("nonsense"))
    ignore(_v)
    ""
  } catch {
    e => e.to_string()
  }
  assert_true(msg.contains("nonsense"))
  assert_true(msg.contains("interface_simplification"))
  assert_true(msg.contains("error_handling_improvement"))
}
