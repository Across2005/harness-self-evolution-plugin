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
// PerformanceTuning（恒返回空，TODO(flow-optimization)）
// ----------------------------------------------------------------------------

///|
/// 锁定 TODO 语义：PerformanceTuning 恒返回空变更集。
test "plan_changes PerformanceTuning always returns empty" {
  let signals = [
    make_signal(@types.SignalCategory::Loop, None),
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
