///|
/// `planning.mbt` 的专项单元测试。
///
/// `risk_wbtest.mbt` 已覆盖 `InterfaceSimplification`（plan_merges）和
/// `DocumentationEnhancement`（plan_docs）的分支。本文件补齐其余 4 种
/// 进化类型的直接测试，以及空信号集/空插件元数据的边界行为。
fn make_plugin(
  tools : Array[String],
  doc_quality : Double,
) -> @types.PluginMetadata {
  {
    plugin_id: "plan-test-1.0.0",
    name: "plan-test",
    version: "1.0.0",
    kind: @types.PluginKind::Community,
    domain: @types.SkillDomain::Programming,
    capabilities: ["cap_a", "cap_b"],
    tools,
    events: [],
    dependencies: [],
    scanned_at: @util.now_ms(),
    path: "/mock",
    initial_metrics: {
      complexity_score: 5.0,
      interface_clarity: 5.0,
      documentation_quality: doc_quality,
      usage_frequency: None,
    },
  }
}

///|
fn make_signal(
  category : @types.SignalCategory,
  tool : String?,
) -> @types.EvolutionSignal {
  {
    strength: @types.SignalStrength::Medium,
    category,
    description: "test signal",
    evidence: @types.Evidence::Session("test"),
    ts: @util.now_ms(),
    plugin_id: "plan-test-1.0.0",
    count: None,
    tool,
    decay_factor: 1.0,
  }
}

// ----------------------------------------------------------------------------
// BehaviorOptimization（plan_middleware）
// ----------------------------------------------------------------------------

///|
/// 无 loop 信号 → 空变更集。
test "plan_changes BehaviorOptimization returns empty without loop signal" {
  let result = plan_changes(
    make_plugin([], 5.0),
    @types.EvolutionType::BehaviorOptimization,
    [],
  )
  assert_eq(result.length(), 0)
}

///|
/// 有 loop 信号 → 产出一条 AddMiddleware 变更，含工具名。
test "plan_changes BehaviorOptimization produces middleware with loop signal" {
  let signals = [make_signal(@types.SignalCategory::Loop, Some("screenshot"))]
  let result = plan_changes(
    make_plugin([], 5.0),
    @types.EvolutionType::BehaviorOptimization,
    signals,
  )
  assert_eq(result.length(), 1)
  match result[0] {
    @types.Change::AddMiddleware(middlewares) => {
      assert_eq(middlewares.length(), 1)
      assert_eq(middlewares[0].name, "loop_detection")
      assert_eq(middlewares[0].target_tool, Some("screenshot"))
    }
    _ => abort("expected AddMiddleware")
  }
}

///|
/// loop 信号但无 tool 字段 → target_tool 为 "unknown"。
test "plan_changes BehaviorOptimization falls back to unknown tool" {
  let signals = [make_signal(@types.SignalCategory::Loop, None)]
  let result = plan_changes(
    make_plugin([], 5.0),
    @types.EvolutionType::BehaviorOptimization,
    signals,
  )
  assert_eq(result.length(), 1)
  match result[0] {
    @types.Change::AddMiddleware(middlewares) =>
      assert_eq(middlewares[0].target_tool, Some("unknown"))
    _ => abort("expected AddMiddleware")
  }
}

// ----------------------------------------------------------------------------
// CapabilityExtension（plan_capability）
// ----------------------------------------------------------------------------

///|
/// 无 workflow 信号 → 空变更集。
test "plan_changes CapabilityExtension returns empty without workflow signal" {
  let result = plan_changes(
    make_plugin([], 5.0),
    @types.EvolutionType::CapabilityExtension,
    [],
  )
  assert_eq(result.length(), 0)
}

///|
/// 有 workflow 信号 → 产出一条 AddCapability 变更。
test "plan_changes CapabilityExtension produces capability with workflow signal" {
  let signals = [make_signal(@types.SignalCategory::Workflow, None)]
  let result = plan_changes(
    make_plugin([], 5.0),
    @types.EvolutionType::CapabilityExtension,
    signals,
  )
  assert_eq(result.length(), 1)
  match result[0] {
    @types.Change::AddCapability(caps) => {
      assert_eq(caps.length(), 1)
      assert_eq(caps[0].capability_name, "custom_workflow")
    }
    _ => abort("expected AddCapability")
  }
}

// ----------------------------------------------------------------------------
// ErrorHandlingImprovement（plan_error_handling）
// ----------------------------------------------------------------------------

///|
/// 无 correction 信号 → 空变更集。
test "plan_changes ErrorHandlingImprovement returns empty without correction signal" {
  let result = plan_changes(
    make_plugin([], 5.0),
    @types.EvolutionType::ErrorHandlingImprovement,
    [],
  )
  assert_eq(result.length(), 0)
}

///|
/// 有 correction 信号 → 产出一条 ImproveErrorHandling 变更。
test "plan_changes ErrorHandlingImprovement produces improvement with correction signal" {
  let signals = [make_signal(@types.SignalCategory::Correction, None)]
  let result = plan_changes(
    make_plugin([], 5.0),
    @types.EvolutionType::ErrorHandlingImprovement,
    signals,
  )
  assert_eq(result.length(), 1)
  match result[0] {
    @types.Change::ImproveErrorHandling(handling) => {
      assert_eq(handling.length(), 1)
      assert_eq(handling[0].error_type, "user_correction")
    }
    _ => abort("expected ImproveErrorHandling")
  }
}

// ----------------------------------------------------------------------------
// PerformanceTuning（C3 已实现：基于 Loop 信号生成 OptimizeFlow 变更）
// ----------------------------------------------------------------------------

///|
/// 性能调优：有 Loop 信号时生成 OptimizeFlow 变更。
test "plan_changes PerformanceTuning with Loop signal returns OptimizeFlow" {
  let signals = [
    make_signal(@types.SignalCategory::Loop, Some("navigate")),
  ]
  let result = plan_changes(
    make_plugin(["navigate", "click", "type"], 5.0),
    @types.EvolutionType::PerformanceTuning,
    signals,
  )
  assert_eq(result.length(), 1)
  match result[0] {
    @types.Change::OptimizeFlow(xs) => assert_eq(xs.length(), 1)
    _ => fail("expected OptimizeFlow change")
  }
}

///|
/// 性能调优：无 Loop 信号时返回空变更集。
test "plan_changes PerformanceTuning without Loop signal returns empty" {
  let signals = [
    make_signal(@types.SignalCategory::Correction, None),
    make_signal(@types.SignalCategory::Workflow, None),
  ]
  let result = plan_changes(
    make_plugin(["navigate", "click", "type"], 5.0),
    @types.EvolutionType::PerformanceTuning,
    signals,
  )
  assert_eq(result.length(), 0)
}

// ----------------------------------------------------------------------------
// 空信号集 / 空插件元数据的边界
// ----------------------------------------------------------------------------

///|
/// 空信号集 + 空插件 → 所有类型都返回空。
test "plan_changes with empty signals and empty plugin returns empty for all types" {
  let empty_plugin = make_plugin([], 9.0)
  let empty_signals : Array[@types.EvolutionSignal] = []
  let types = [
    @types.EvolutionType::InterfaceSimplification,
    @types.EvolutionType::BehaviorOptimization,
    @types.EvolutionType::PerformanceTuning,
    @types.EvolutionType::DocumentationEnhancement,
    @types.EvolutionType::CapabilityExtension,
    @types.EvolutionType::ErrorHandlingImprovement,
    @types.EvolutionType::SecurityHardening,
    @types.EvolutionType::AccessibilityImprovement,
  ]
  for etype in types {
    let result = plan_changes(empty_plugin, etype, empty_signals)
    assert_eq(result.length(), 0)
  }
}

// ----------------------------------------------------------------------------
// plan_validation 的额外覆盖
// ----------------------------------------------------------------------------

///|
/// 零能力的插件：验证计划只含类型追加的场景（无能力场景）。
test "plan_validation with zero capabilities still produces type extras" {
  let plugin : @types.PluginMetadata = {
    plugin_id: "empty-1.0.0",
    name: "empty",
    version: "1.0.0",
    kind: @types.PluginKind::Community,
    domain: @types.SkillDomain::Programming,
    capabilities: [],
    tools: [],
    events: [],
    dependencies: [],
    scanned_at: @util.now_ms(),
    path: "/mock",
    initial_metrics: {
      complexity_score: 5.0,
      interface_clarity: 5.0,
      documentation_quality: 5.0,
      usage_frequency: None,
    },
  }
  let plan = plan_validation(@types.EvolutionType::BehaviorOptimization, plugin)
  // 零能力 → 无 "测试 X 功能" 场景，只有 extra_scenarios
  let has_capability_scenario = plan.test_scenarios.any(fn(s) {
    s.has_prefix("测试 ") && s.has_suffix(" 功能")
  })
  assert_false(has_capability_scenario)
  // 三级验证始终存在
  assert_eq(plan.validation_levels.length(), 3)
}

// ----------------------------------------------------------------------------
// C1/C2/C4 新增功能的测试覆盖
// ----------------------------------------------------------------------------

///|
/// SecurityHardening：有 Correction 信号时生成安全中间件和错误处理改进。
test "plan_changes SecurityHardening with Correction signal generates changes" {
  let signals = [
    make_signal(@types.SignalCategory::Correction, None),
  ]
  let result = plan_changes(
    make_plugin(["navigate"], 5.0),
    @types.EvolutionType::SecurityHardening,
    signals,
  )
  // 应生成 AddMiddleware 和 ImproveErrorHandling 两种变更
  assert_true(result.length() >= 2)
  let has_middleware = result.any(fn(c) { c.kind() == @types.ChangeKind::AddMiddleware })
  let has_error_handling = result.any(fn(c) { c.kind() == @types.ChangeKind::ImproveErrorHandling })
  assert_true(has_middleware)
  assert_true(has_error_handling)
}

///|
/// SecurityHardening：无信号时返回空变更集。
test "plan_changes SecurityHardening without signals returns empty" {
  let signals : Array[@types.EvolutionSignal] = []
  let result = plan_changes(
    make_plugin(["navigate"], 5.0),
    @types.EvolutionType::SecurityHardening,
    signals,
  )
  assert_eq(result.length(), 0)
}

///|
/// AccessibilityImprovement：有 Workflow 信号时生成文档和能力扩展。
test "plan_changes AccessibilityImprovement with Workflow signal generates changes" {
  let signals = [
    make_signal(@types.SignalCategory::Workflow, None),
  ]
  let result = plan_changes(
    make_plugin(["navigate"], 5.0),
    @types.EvolutionType::AccessibilityImprovement,
    signals,
  )
  // 应生成 UpdateDocumentation 和 AddCapability 两种变更
  assert_true(result.length() >= 2)
  let has_docs = result.any(fn(c) { c.kind() == @types.ChangeKind::UpdateDocumentation })
  let has_capability = result.any(fn(c) { c.kind() == @types.ChangeKind::AddCapability })
  assert_true(has_docs)
  assert_true(has_capability)
}

///|
/// AccessibilityImprovement：无信号但文档质量低时仍生成文档建议。
test "plan_changes AccessibilityImprovement with low doc quality generates docs" {
  let signals : Array[@types.EvolutionSignal] = []
  let result = plan_changes(
    make_plugin(["navigate"], 5.0),
    @types.EvolutionType::AccessibilityImprovement,
    signals,
  )
  // 文档质量5.0 < 8.0，应生成文档建议
  assert_true(result.length() >= 1)
  let has_docs = result.any(fn(c) { c.kind() == @types.ChangeKind::UpdateDocumentation })
  assert_true(has_docs)
}

///|
/// plan_param_simplification：工具名含 config/settings 时生成简化建议。
test "plan_param_simplification generates suggestions for complex tool names" {
  let plugin = make_plugin(["get_config", "update_settings", "navigate"], 5.0)
  let result = plan_changes(
    plugin,
    @types.EvolutionType::InterfaceSimplification,
    [],
  )
  // 应包含 SimplifyParams 变更
  let has_simplify = result.any(fn(c) { c.kind() == @types.ChangeKind::SimplifyParams })
  assert_true(has_simplify)
}

///|
/// plan_param_simplification：工具名不含复杂模式时不生成建议。
test "plan_param_simplification generates no suggestions for simple tool names" {
  let plugin = make_plugin(["navigate", "click", "type"], 5.0)
  let result = plan_changes(
    plugin,
    @types.EvolutionType::InterfaceSimplification,
    [],
  )
  // 不应包含 SimplifyParams 变更（但可能包含 MergeTools）
  let has_simplify = result.any(fn(c) { c.kind() == @types.ChangeKind::SimplifyParams })
  assert_false(has_simplify)
}
