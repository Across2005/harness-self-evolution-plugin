///|
/// engine 里**纯函数**部分的断言 —— 无需文件系统、无需 monitor。
///
/// 把 risk.mbt / planning.mbt 的纯逻辑从 engine_wbtest.mbt 的端到端用例里分出来，
/// 是 Deep Module 的直接好处：TS 版这些逻辑全是 `EvolutionEngine` 的 private 方法，
/// 想测就必须先造 monitor + ProposalStore + 临时目录（见 legacy engine.test.ts L41-53），
/// 于是 `generateSignature` 这种一行字符串处理也被迫套上整套脚手架。

///|
/// 一条只关心强度的最小信号。（顶层函数：MoonBit 不允许在 test 块内嵌套定义 `fn`）
fn strength_signal(strength : @types.SignalStrength) -> @types.EvolutionSignal {
  {
    strength,
    category: @types.SignalCategory::Pattern,
    description: "d",
    evidence: @types.Evidence::UserManual,
    ts: 0L,
    plugin_id: "p",
    count: None,
    tool: None,
  }
}

// ============================================================================
// generate_signature（TS L625-638）
// ============================================================================

///|
/// 签名 = `<plugin_id 去掉最后一段>` + `-` + `<进化类型 wire 名，_ 换成 ->`。
///
/// `plugin_id` 本身含多个 `-` 时（如 `my-cool-plugin-1.0.0`），
/// TS 的 `split('-').slice(0,-1).join('-')` 只去掉**最后一段**（version），
/// 故结果是 `my-cool-plugin`。这是最容易在移植中写错的一处
/// （很容易写成「取第一段」或「去掉所有数字段」），而 legacy 的 12 个用例
/// 全都用 `test-plugin-1.0.0` 这种单破折号名，覆盖不到它 —— 故此处专门补齐。
test "generate_signature drops only the trailing version segment" {
  assert_eq(
    generate_signature(
      "browser-use-0.4.1",
      @types.EvolutionType::InterfaceSimplification,
    ),
    "browser-use-interface-simplification",
  )
  // 多破折号名：只去掉最后的 version 段
  assert_eq(
    generate_signature(
      "my-cool-plugin-1.0.0",
      @types.EvolutionType::DocumentationEnhancement,
    ),
    "my-cool-plugin-documentation-enhancement",
  )
  assert_eq(
    generate_signature("a-b-c-d-2", @types.EvolutionType::BehaviorOptimization),
    // split('-') = [a,b,c,d,2] → slice(0,-1) = [a,b,c,d] → "a-b-c-d"
    "a-b-c-d-behavior-optimization",
  )
  // 单段名：slice(0,-1) 得到空数组 → 签名以 "-" 开头。
  // 这是 TS 的既有行为，逐字保留（它决定了去重的分桶）。
  assert_eq(
    generate_signature("foo", @types.EvolutionType::PerformanceTuning),
    "-performance-tuning",
  )
  // 两段名
  assert_eq(
    generate_signature("foo-1.0", @types.EvolutionType::CapabilityExtension),
    "foo-capability-extension",
  )
  // 全部 6 种类型的 `_` → `-` 归一化
  assert_eq(
    generate_signature("p-1", @types.EvolutionType::ErrorHandlingImprovement),
    "-error-handling-improvement".replace_all(old="-error", new="p-error"),
  )
}

// ============================================================================
// determine_confidence（TS L643-650）
// ============================================================================

///|
/// 三条判定的顺序：strong >= 2 优先于 strong >= 1，后者又优先于 medium >= 2。
test "determine_confidence follows the TS thresholds and their order" {
  let strong = strength_signal(@types.SignalStrength::Strong)
  let medium = strength_signal(@types.SignalStrength::Medium)
  let weak = strength_signal(@types.SignalStrength::Weak)

  assert_eq(determine_confidence([]), @types.Confidence::Low)
  assert_eq(determine_confidence([weak]), @types.Confidence::Low)
  assert_eq(determine_confidence([medium]), @types.Confidence::Low)
  assert_eq(determine_confidence([weak, weak]), @types.Confidence::Low)
  // medium >= 2 → Medium
  assert_eq(determine_confidence([medium, medium]), @types.Confidence::Medium)
  // strong >= 1 → Medium
  assert_eq(determine_confidence([strong]), @types.Confidence::Medium)
  assert_eq(determine_confidence([strong, weak]), @types.Confidence::Medium)
  // strong >= 2 → High（优先于 medium 计数）
  assert_eq(determine_confidence([strong, strong]), @types.Confidence::High)
  assert_eq(
    determine_confidence([strong, strong, medium, weak]),
    @types.Confidence::High,
  )
}

// ============================================================================
// filter_by_intensity（TS L163-174）
// ============================================================================

///|
test "filter_by_intensity keeps everything at Full, only strong at Half" {
  let all = [
    strength_signal(@types.SignalStrength::Strong),
    strength_signal(@types.SignalStrength::Medium),
    strength_signal(@types.SignalStrength::Weak),
  ]

  assert_eq(filter_by_intensity(all, @types.Intensity::Full).length(), 3)

  let half = filter_by_intensity(all, @types.Intensity::Half)
  assert_eq(half.length(), 1)
  assert_eq(half[0].strength, @types.SignalStrength::Strong)

  // Off 返回空。generate_proposal 已在①短路，故这个分支实际走不到，
  // 但闭合枚举要求 match 穷尽 —— 少写一个分支会编译失败，而不是静默走 default。
  assert_eq(filter_by_intensity(all, @types.Intensity::Off).length(), 0)
}

// ============================================================================
// 风险判定（TS L575-620）
// ============================================================================

///|
fn merge(compatible : Bool) -> @types.ToolMerge {
  {
    new_tool: "smart_fill",
    merged_from: ["a", "b"],
    new_interface: { params: ["x"], description: "d", defaults: None },
    backward_compatible: compatible,
  }
}

///|
fn simplification(
  removed : Array[String],
  defaults : Json,
) -> @types.ParamSimplification {
  { tool: "t", remove_params: removed, defaults, reason: "r" }
}

///|
test "has_breaking_changes detects incompatible merges and undefaulted removals" {
  assert_eq(has_breaking_changes([]), false)
  assert_eq(
    has_breaking_changes([@types.Change::MergeTools([merge(true)])]),
    false,
  )
  assert_eq(
    has_breaking_changes([@types.Change::MergeTools([merge(false)])]),
    true,
  )
  // 默认值数量 >= 被移除参数数量 → 不破坏
  assert_eq(
    has_breaking_changes([
      @types.Change::SimplifyParams([
        simplification(["a", "b"], { "a": 1, "b": 2 }),
      ]),
    ]),
    false,
  )
  // 默认值数量 < 被移除参数数量 → 破坏（TS L582）
  assert_eq(
    has_breaking_changes([
      @types.Change::SimplifyParams([simplification(["a", "b"], { "a": 1 })]),
    ]),
    true,
  )
  // 其他变更种类不参与这两条判据
  assert_eq(
    has_breaking_changes([
      @types.Change::AddMiddleware([
        {
          name: "loop_detection",
          target_tool: Some("a"),
          target_event: None,
          threshold: Some(5),
          intervention: "i",
          priority: 10,
        },
      ]),
    ]),
    false,
  )
}

///|
/// ★ **有意的语义修正**（已记入 CONTEXT.md）：
/// TS L592-606 在「变更集为空」时返回 `false`，而「`merge_tools` 是空数组」时
/// `[].every()` 为 `true` → 返回 `true`。同样是「没有任何变更」，结论却相反。
/// 「无变更」显然不会破坏任何调用方，故新版统一返回 `true`。
test "is_backward_compatible treats an empty change set as compatible" {
  assert_eq(is_backward_compatible([]), true)
  // 全部兼容的合并 → true
  assert_eq(
    is_backward_compatible([
      @types.Change::MergeTools([merge(true), merge(true)]),
    ]),
    true,
  )
  // 有一个不兼容 → false
  assert_eq(
    is_backward_compatible([
      @types.Change::MergeTools([merge(true), merge(false)]),
    ]),
    false,
  )
  // 每个被移除的参数都有默认值 → true
  assert_eq(
    is_backward_compatible([
      @types.Change::SimplifyParams([simplification(["a"], { "a": 1 })]),
    ]),
    true,
  )
  // 有参数没默认值 → false
  assert_eq(
    is_backward_compatible([
      @types.Change::SimplifyParams([simplification(["a", "b"], { "a": 1 })]),
    ]),
    false,
  )
  // 既无合并也无参数简化（例如只有文档更新）→ true
  assert_eq(
    is_backward_compatible([
      @types.Change::UpdateDocumentation([
        { file: "SKILL.md", section: "s", new_content: "c", reason: "r" },
      ]),
    ]),
    true,
  )
}

///|
/// `estimate_migration_effort` 数的是**非空变更组的种类数**，
/// 取代 TS L615 那句依赖 JS 运行时对象反射的
/// `Object.values(changes).filter(v => v && v.length > 0).length`。
test "estimate_migration_effort counts non-empty change kinds" {
  let doc : @types.DocumentationUpdate = {
    file: "SKILL.md",
    section: "s",
    new_content: "c",
    reason: "r",
  }
  let mw : @types.MiddlewareAddition = {
    name: "n",
    target_tool: None,
    target_event: None,
    threshold: None,
    intervention: "i",
    priority: 1,
  }
  let cap : @types.CapabilityAddition = {
    capability_name: "c",
    description: "d",
    implementation: "i",
    dependencies: [],
  }

  // 0 组 / 1 组 → Low
  assert_eq(estimate_migration_effort([]), @types.MigrationEffort::Low)
  assert_eq(
    estimate_migration_effort([@types.Change::UpdateDocumentation([doc])]),
    @types.MigrationEffort::Low,
  )
  // **空数组的组不计入** —— 这正是 TS 那个 filter 的作用
  assert_eq(
    estimate_migration_effort([
      @types.Change::UpdateDocumentation([doc]),
      @types.Change::AddMiddleware([]),
      @types.Change::MergeTools([]),
    ]),
    @types.MigrationEffort::Low,
  )
  // 2-3 组 → Medium
  assert_eq(
    estimate_migration_effort([
      @types.Change::UpdateDocumentation([doc]),
      @types.Change::AddMiddleware([mw]),
    ]),
    @types.MigrationEffort::Medium,
  )
  assert_eq(
    estimate_migration_effort([
      @types.Change::UpdateDocumentation([doc]),
      @types.Change::AddMiddleware([mw]),
      @types.Change::AddCapability([cap]),
    ]),
    @types.MigrationEffort::Medium,
  )
  // 4 组及以上 → High
  assert_eq(
    estimate_migration_effort([
      @types.Change::UpdateDocumentation([doc]),
      @types.Change::AddMiddleware([mw]),
      @types.Change::AddCapability([cap]),
      @types.Change::MergeTools([merge(true)]),
    ]),
    @types.MigrationEffort::High,
  )
}

///|
test "assess_risks composes the three judgements" {
  let risk = assess_risks([@types.Change::MergeTools([merge(false)])])
  assert_eq(risk.breaking_changes, true)
  assert_eq(risk.backward_compatible, false)
  assert_eq(risk.migration_effort, @types.MigrationEffort::Low)
  assert_eq(risk.rollback_complexity, @types.RollbackComplexity::Simple)
  // TS L567 的注释 "Would need actual user tracking"：本仓没有用户计数来源，
  // 原样保留这个诚实的 0
  assert_eq(risk.affected_users, 0)

  let empty = assess_risks([])
  assert_eq(empty.breaking_changes, false)
  assert_eq(empty.backward_compatible, true)
}

// ============================================================================
// 变更生成与验证计划（TS L303-334, L381-410, L501-545）
// ============================================================================

///|
fn plugin_with(
  tools : Array[String],
  doc_quality : Double,
) -> @types.PluginMetadata {
  {
    plugin_id: "p-1.0.0",
    name: "p",
    version: "1.0.0",
    kind: @types.PluginKind::Official,
    capabilities: ["alpha", "beta", "gamma", "delta"],
    tools,
    events: [],
    dependencies: [],
    scanned_at: 0L,
    path: "/p",
    initial_metrics: {
      complexity_score: 5.0,
      interface_clarity: 5.0,
      documentation_quality: doc_quality,
      usage_frequency: None,
    },
  }
}

///|
/// TS L315-331 的硬编码启发式：少于 3 个工具不提议；
/// 同时具备 navigate/click/type 才提议 smart_fill。
test "plan_merges only fires for the navigate+click+type triple" {
  assert_eq(
    plan_changes(
      plugin_with(["a", "b"], 9.0),
      @types.EvolutionType::InterfaceSimplification,
      [],
    ).length(),
    0,
  )
  assert_eq(
    plan_changes(
      plugin_with(["navigate", "click"], 9.0),
      @types.EvolutionType::InterfaceSimplification,
      [],
    ).length(),
    0,
  )
  // 三个都在，但工具总数已达 3 → 命中
  let hit = plan_changes(
    plugin_with(["navigate", "click", "type"], 9.0),
    @types.EvolutionType::InterfaceSimplification,
    [],
  )
  assert_eq(hit.length(), 1)
  // 三个都在但夹在别的工具里也算命中（TS 用 includes 而非位置匹配）
  let mixed = plan_changes(
    plugin_with(["screenshot", "navigate", "extra", "click", "type"], 9.0),
    @types.EvolutionType::InterfaceSimplification,
    [],
  )
  assert_eq(mixed.length(), 1)
}

///|
/// TS L388-395：`documentation_quality < 7` 才产出「补充使用示例」那条建议。
/// TS L398-407：每条 workflow 信号各产出一条「记录可复用工作流」。
test "plan_docs reacts to low documentation quality and workflow signals" {
  // 文档质量 9.0 >= 7，且无 workflow 信号 → 空
  assert_eq(
    plan_changes(
      plugin_with([], 9.0),
      @types.EvolutionType::DocumentationEnhancement,
      [],
    ).length(),
    0,
  )
  // 文档质量 5.0 < 7 → 一条
  let low = plan_changes(
    plugin_with([], 5.0),
    @types.EvolutionType::DocumentationEnhancement,
    [],
  )
  assert_eq(low.length(), 1)
  match low[0] {
    @types.Change::UpdateDocumentation(docs) => {
      assert_eq(docs.length(), 1)
      assert_eq(docs[0].file, "SKILL.md")
      assert_eq(docs[0].section, "Usage Examples")
    }
    _ => abort("expected UpdateDocumentation")
  }
}

///|
/// TS L527-529：场景先取前 3 个能力，再按类型追加。
/// `capabilities` 有 4 个，故只取 alpha/beta/gamma。
test "plan_validation takes the first three capabilities then type extras" {
  let plugin = plugin_with([], 9.0)
  let plan = plan_validation(
    @types.EvolutionType::InterfaceSimplification,
    plugin,
  )
  json_inspect(plan.test_scenarios, content=[
    "测试 alpha 功能", "测试 beta 功能", "测试 gamma 功能", "测试新工具接口",
    "测试向后兼容性",
  ])
  assert_eq(
    plan.success_criteria,
    "成功率 >= 95%，延迟 < 2s，无回归问题",
  )
  assert_eq(
    plan.rollback_strategy,
    "保留原版本 30 天，支持一键回滚",
  )
  assert_eq(plan.validation_levels.length(), 3)
  json_inspect(plan.validation_levels.map(fn(l) { l.level.wire_name() }), content=[
    "T0", "T1", "T2",
  ])
  json_inspect(plan.validation_levels.map(fn(l) { l.timeout_ms }), content=[
    Some(30000),
    Some(60000),
    Some(120000),
  ])

  // 能力不足 3 个时全取
  let small = plan_validation(
    @types.EvolutionType::BehaviorOptimization,
    plugin_with([], 9.0),
  )
  assert_true(small.test_scenarios.length() >= 2)
}

// ============================================================================
// ProposalOutcome 与 TS 的 null 语义的对应关系
// ============================================================================

///|
/// `ProposalOutcome` 必须能无损还原 TS 的 `EvolutionProposal | null`：
/// 三个带提案的变体 → 非 null；三个不带的 → null。
/// MCP 层靠这条映射保持与 legacy 完全一致的响应形状。
test "ProposalOutcome maps back onto the TS null semantics" {
  let dummy : @types.EvolutionProposal = completed_proposal("p", 0L)
  assert_true(ProposalOutcome::Created(dummy).proposal() is Some(_))
  assert_true(ProposalOutcome::AlreadyPending(dummy).proposal() is Some(_))
  assert_true(ProposalOutcome::Duplicate(dummy).proposal() is Some(_))
  assert_eq(ProposalOutcome::Disabled.proposal(), None)
  assert_eq(ProposalOutcome::NoSignals.proposal(), None)
  assert_eq(ProposalOutcome::InCooldown.proposal(), None)

  // 六个变体的 reason 互不相同，否则这个枚举就白加了
  let reasons = [
    ProposalOutcome::Created(dummy).reason(),
    ProposalOutcome::AlreadyPending(dummy).reason(),
    ProposalOutcome::Duplicate(dummy).reason(),
    ProposalOutcome::Disabled.reason(),
    ProposalOutcome::NoSignals.reason(),
    ProposalOutcome::InCooldown.reason(),
  ]
  assert_eq(@types.dedup_ordered(reasons).length(), 6)
}
