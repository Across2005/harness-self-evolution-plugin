///|
/// engine 的测试。1-12 移植自 legacy-ts/tests/engine.test.ts 的 12 个用例，
/// 13 起是本次改造新增的（签名边界、决策树优先级、风险判定、Outcome 映射）。
///
/// 隔离方式对应 legacy 的 `beforeEach(fs.mkdtemp)` / `afterEach(fs.remove)`。
/// **所有路径都注入**：engine、monitor、ProposalStore、signals Jsonl 四者
/// 都指向同一个临时目录，绝不触碰真实的 `~/.harness-evolution`。

///|
/// 对应 legacy-ts/tests/engine.test.ts L14-30 的 `mockPlugin`。
///
/// 三个指标值不是随便挑的，它们分别驱动决策树的不同分支：
/// · `complexity_score: 7.5` > 7 → struggle 信号映射到 interface_simplification（TS L196）
/// · `interface_clarity: 6.0` < 7 → preference 信号映射到 interface_simplification（TS L207）
/// · `documentation_quality: 7.0` 不 < 7 → plan_docs 不产出「文档质量较低」那条建议
/// 而 `tools` 恰好含 navigate/click/type → plan_merges 会提议 smart_fill（TS L320）。
fn mock_plugin() -> @types.PluginMetadata {
  {
    plugin_id: "test-plugin-1.0.0",
    name: "test-plugin",
    version: "1.0.0",
    kind: @types.PluginKind::Community,
    capabilities: ["navigate", "click", "type"],
    tools: ["navigate", "click", "type"],
    events: [],
    dependencies: [],
    scanned_at: @util.now_ms(),
    path: "/mock/path",
    initial_metrics: {
      complexity_score: 7.5,
      interface_clarity: 6.0,
      documentation_quality: 7.0,
      usage_frequency: None,
    },
  }
}

///|
/// 造一条信号。对应 legacy 测试里那些手写的 `EvolutionSignal` 字面量。
fn signal(
  strength : @types.SignalStrength,
  category : @types.SignalCategory,
  description : String,
) -> @types.EvolutionSignal {
  {
    strength,
    category,
    description,
    evidence: @types.Evidence::Session("test"),
    ts: @util.now_ms(),
    plugin_id: "test-plugin-1.0.0",
    count: None,
    tool: None,
  }
}

///|
/// 对应 legacy 的 `strongCorrectionSignal`（L32-39）。
fn strong_correction() -> @types.EvolutionSignal {
  signal(
    @types.SignalStrength::Strong,
    @types.SignalCategory::Correction,
    "User correction: use parameter X instead of Y",
  )
}

///|
/// 对应 legacy beforeEach（L41-53）：建 engine + 共享的 ProposalStore。
fn make_engine(
  dir : String,
  intensity : @types.Intensity,
) -> (EvolutionEngine, @store.ProposalStore) {
  let proposals = @store.ProposalStore::new(
    @util.path_join(dir, "proposals.jsonl"),
  )
  let monitor = @monitor.PerformanceMonitor::new(
    @util.path_join(dir, "metrics.jsonl"),
    @util.path_join(dir, "signals.jsonl"),
  )
  let signals = @store.Jsonl::new(@util.path_join(dir, "signals.jsonl"))
  let config : @types.EngineConfig = {
    intensity,
    cooldown_hours: 24,
    auto_approve: false,
    thresholds: @types.SignalThresholds::default(),
    max_log_bytes: @types.default_max_log_bytes,
  }
  (EvolutionEngine::new(monitor, proposals, signals, config), proposals)
}

// ============================================================================
// 移植：generateProposal（legacy L59-241）
// ============================================================================

///|
/// 移植：engine.test.ts L60-72
/// "should generate an error_handling proposal from a strong correction signal"
async test "generates an error_handling proposal from a strong correction signal" {
  let dir = @fs.tmpdir(prefix="evo-engine-")
  defer @fs.rmdir(dir, recursive=true)
  let (engine, _) = make_engine(dir, @types.Intensity::Half)

  let outcome = engine.generate_proposal(
    mock_plugin(),
    signals=Some([strong_correction()]),
  )
  let proposal = outcome.proposal()
  assert_true(proposal is Some(_))
  match proposal {
    Some(p) => {
      assert_eq(
        p.evolution_type,
        @types.EvolutionType::ErrorHandlingImprovement,
      )
      assert_eq(p.trigger_signals.length(), 1)
      assert_eq(
        p.matt_pocock_principle,
        @types.MattPocockPrinciple::TightFeedback,
      )
      // CONTEXT.md L49：error_handling_improvement → 紧反馈环 > 盲目试错
      assert_eq(
        p.matt_pocock_principle.wire_name(),
        "紧反馈环 > 盲目试错",
      )
      assert_eq(p.status, @types.ProposalStatus::Pending)
      assert_eq(outcome, ProposalOutcome::Created(p))
    }
    None => abort("expected a proposal")
  }
}

///|
/// 移植：engine.test.ts L74-84
/// "should persist the proposal via the shared ProposalStore"
async test "persists the proposal through the shared ProposalStore" {
  let dir = @fs.tmpdir(prefix="evo-engine-")
  defer @fs.rmdir(dir, recursive=true)
  let (engine, proposals) = make_engine(dir, @types.Intensity::Half)

  let outcome = engine.generate_proposal(
    mock_plugin(),
    signals=Some([strong_correction()]),
  )
  match outcome.proposal() {
    Some(created) => {
      let loaded = proposals.find(created.proposal_id)
      assert_true(loaded is Some(_))
      match loaded {
        Some(p) => {
          assert_eq(p.plugin_id, "test-plugin-1.0.0")
          assert_eq(p.proposal_id, created.proposal_id)
        }
        None => ()
      }
    }
    None => abort("expected a proposal")
  }
}

///|
/// 移植：engine.test.ts L86-103
/// "should ignore medium-only signals at 50% intensity"
async test "ignores medium-only signals at 50% intensity" {
  let dir = @fs.tmpdir(prefix="evo-engine-")
  defer @fs.rmdir(dir, recursive=true)
  let (engine, _) = make_engine(dir, @types.Intensity::Half)

  let medium = signal(
    @types.SignalStrength::Medium,
    @types.SignalCategory::Preference,
    "User preference: verbose output",
  )
  let outcome = engine.generate_proposal(mock_plugin(), signals=Some([medium]))
  assert_eq(outcome.proposal(), None)
  // 新的 Outcome 枚举能说清「为什么没有提案」—— TS 只能给一个 null
  assert_eq(outcome, ProposalOutcome::NoSignals)
  assert_eq(outcome.reason(), "insufficient signals to trigger evolution")
}

///|
/// 移植：engine.test.ts L105-122 "should ignore weak-only signals"
async test "ignores weak-only signals" {
  let dir = @fs.tmpdir(prefix="evo-engine-")
  defer @fs.rmdir(dir, recursive=true)
  let (engine, _) = make_engine(dir, @types.Intensity::Half)

  let weak = signal(
    @types.SignalStrength::Weak,
    @types.SignalCategory::Pattern,
    "Minor performance fluctuation",
  )
  assert_eq(
    engine.generate_proposal(mock_plugin(), signals=Some([weak])).proposal(),
    None,
  )
}

///|
/// 移植：engine.test.ts L124-138
/// "should return the existing pending proposal instead of duplicating"
///
/// ★ 关键语义：第二次调用返回的是**同一份提案**，不是 null。
/// TS L80-84 就是这样，移植时最容易被「顺手统一成 null」破坏。
async test "returns the existing pending proposal instead of duplicating" {
  let dir = @fs.tmpdir(prefix="evo-engine-")
  defer @fs.rmdir(dir, recursive=true)
  let (engine, _) = make_engine(dir, @types.Intensity::Half)

  let first = engine.generate_proposal(
    mock_plugin(),
    signals=Some([strong_correction()]),
  )
  let second = engine.generate_proposal(
    mock_plugin(),
    signals=Some([strong_correction()]),
  )

  assert_true(second.proposal() is Some(_))
  match (first.proposal(), second.proposal()) {
    (Some(a), Some(b)) => {
      assert_eq(b.proposal_id, a.proposal_id)
      // 且第二次是「已存在」而不是「新建」
      assert_true(second is ProposalOutcome::AlreadyPending(_))
    }
    _ => abort("expected two proposals")
  }
}

///|
/// 移植：engine.test.ts L140-177
/// "should stay silent during cooldown after a recent proposal"
///
/// legacy 用 `status: 'completed'` 绕过 pending 检查，好让 cooldown 分支成为唯一触发点。
/// 这里同样先存一份 completed 提案。
async test "stays silent during the cooldown period" {
  let dir = @fs.tmpdir(prefix="evo-engine-")
  defer @fs.rmdir(dir, recursive=true)
  let (engine, proposals) = make_engine(dir, @types.Intensity::Half)

  proposals.save(completed_proposal("evo-prior", @util.now_ms()))
  let outcome = engine.generate_proposal(
    mock_plugin(),
    signals=Some([strong_correction()]),
  )
  assert_eq(outcome.proposal(), None)
  assert_eq(outcome, ProposalOutcome::InCooldown)
}

///|
/// 移植：engine.test.ts L179-215
/// "should allow a new proposal once the cooldown has elapsed"
async test "allows a new proposal once the cooldown has elapsed" {
  let dir = @fs.tmpdir(prefix="evo-engine-")
  defer @fs.rmdir(dir, recursive=true)
  let (engine, proposals) = make_engine(dir, @types.Intensity::Half)

  // 25 小时前，超出 24 小时冷却期
  let old = @util.now_ms() - @util.hours_to_ms(25)
  proposals.save(completed_proposal("evo-prior", old))

  let outcome = engine.generate_proposal(
    mock_plugin(),
    signals=Some([strong_correction()]),
  )
  assert_true(outcome.proposal() is Some(_))
  assert_true(outcome is ProposalOutcome::Created(_))
}

///|
/// 移植：engine.test.ts L217-220
/// "should produce no proposal when there are no signals"
async test "produces no proposal when there are no signals" {
  let dir = @fs.tmpdir(prefix="evo-engine-")
  defer @fs.rmdir(dir, recursive=true)
  let (engine, _) = make_engine(dir, @types.Intensity::Half)

  let outcome = engine.generate_proposal(mock_plugin(), signals=Some([]))
  assert_eq(outcome.proposal(), None)
  assert_eq(outcome, ProposalOutcome::NoSignals)
}

///|
/// 移植：engine.test.ts L222-240
/// "should disable generation entirely at 0% intensity"
async test "disables generation entirely at 0% intensity" {
  let dir = @fs.tmpdir(prefix="evo-engine-")
  defer @fs.rmdir(dir, recursive=true)
  let (engine, _) = make_engine(dir, @types.Intensity::Off)

  let outcome = engine.generate_proposal(
    mock_plugin(),
    signals=Some([strong_correction()]),
  )
  assert_eq(outcome.proposal(), None)
  assert_eq(outcome, ProposalOutcome::Disabled)
  assert_eq(outcome.reason(), "evolution is disabled (intensity: 0%)")
}

// ============================================================================
// 移植：signal-to-evolution-type mapping（legacy L243-313）
// ============================================================================

///|
/// 移植：engine.test.ts L244-262
/// "should map a struggle signal with high complexity to interface_simplification"
async test "maps struggle + high complexity to interface_simplification" {
  let dir = @fs.tmpdir(prefix="evo-engine-")
  defer @fs.rmdir(dir, recursive=true)
  let (engine, _) = make_engine(dir, @types.Intensity::Half)

  let struggle = signal(
    @types.SignalStrength::Strong,
    @types.SignalCategory::Struggle,
    "3 consecutive failures detected",
  )
  match
    engine.generate_proposal(mock_plugin(), signals=Some([struggle])).proposal() {
    Some(p) => {
      assert_eq(p.evolution_type, @types.EvolutionType::InterfaceSimplification)
      assert_eq(p.matt_pocock_principle, @types.MattPocockPrinciple::DeepModule)
      assert_eq(p.matt_pocock_principle.wire_name(), "Deep Module > 浅模块")
      // mock_plugin 的 tools 含 navigate/click/type → 应提议 smart_fill
      assert_eq(p.proposed_changes.length(), 1)
      match p.proposed_changes[0] {
        @types.Change::MergeTools(merges) => {
          assert_eq(merges.length(), 1)
          assert_eq(merges[0].new_tool, "smart_fill")
          json_inspect(merges[0].merged_from, content=[
            "navigate", "click", "type",
          ])
        }
        _ => abort("expected MergeTools")
      }
    }
    None => abort("expected a proposal")
  }
}

///|
/// 移植：engine.test.ts L264-293
/// "should map a loop signal to behavior_optimization with middleware proposal"
///
/// legacy 用 100% 强度，好让单条 medium 信号就够了。
async test "maps a loop signal to behavior_optimization with middleware" {
  let dir = @fs.tmpdir(prefix="evo-engine-")
  defer @fs.rmdir(dir, recursive=true)
  let (engine, _) = make_engine(dir, @types.Intensity::Full)

  let mut loop_signal = signal(
    @types.SignalStrength::Medium,
    @types.SignalCategory::Loop,
    "Tool navigate called 5 times in loop",
  )
  // ★ monitor 现在会把工具名放进结构化字段，engine 不必再用正则从描述里反解
  loop_signal = {
    strength: loop_signal.strength,
    category: loop_signal.category,
    description: loop_signal.description,
    evidence: loop_signal.evidence,
    ts: loop_signal.ts,
    plugin_id: loop_signal.plugin_id,
    count: Some(5),
    tool: Some("navigate"),
  }

  match
    engine
    .generate_proposal(mock_plugin(), signals=Some([loop_signal]))
    .proposal() {
    Some(p) => {
      assert_eq(p.evolution_type, @types.EvolutionType::BehaviorOptimization)
      assert_eq(p.proposed_changes.length(), 1)
      match p.proposed_changes[0] {
        @types.Change::AddMiddleware(mws) => {
          assert_true(mws.length() > 0)
          assert_eq(mws[0].name, "loop_detection")
          assert_eq(mws[0].target_tool, Some("navigate"))
          assert_eq(mws[0].threshold, Some(5))
          assert_eq(mws[0].priority, 10)
        }
        _ => abort("expected AddMiddleware")
      }
    }
    None => abort("expected a proposal")
  }
}

///|
/// ★ 结构化 `tool` 字段缺失时必须回退到 `"unknown"` ——
/// 这正是 TS L357 正则反解失败时的行为（`?.[1] || 'unknown'`）。
async test "middleware falls back to unknown when the signal carries no tool" {
  let dir = @fs.tmpdir(prefix="evo-engine-")
  defer @fs.rmdir(dir, recursive=true)
  let (engine, _) = make_engine(dir, @types.Intensity::Full)

  let loop_signal = signal(
    @types.SignalStrength::Medium,
    @types.SignalCategory::Loop,
    "a loop happened",
  )
  match
    engine
    .generate_proposal(mock_plugin(), signals=Some([loop_signal]))
    .proposal() {
    Some(p) =>
      match p.proposed_changes[0] {
        @types.Change::AddMiddleware(mws) =>
          assert_eq(mws[0].target_tool, Some("unknown"))
        _ => abort("expected AddMiddleware")
      }
    None => abort("expected a proposal")
  }
}

///|
/// 移植：engine.test.ts L295-312
/// "should assign high confidence when two strong signals are present"
async test "assigns high confidence when two strong signals are present" {
  let dir = @fs.tmpdir(prefix="evo-engine-")
  defer @fs.rmdir(dir, recursive=true)
  let (engine, _) = make_engine(dir, @types.Intensity::Half)

  let struggle = signal(
    @types.SignalStrength::Strong,
    @types.SignalCategory::Struggle,
    "3 consecutive failures",
  )
  match
    engine
    .generate_proposal(
      mock_plugin(),
      signals=Some([strong_correction(), struggle]),
    )
    .proposal() {
    Some(p) => assert_eq(p.confidence, @types.Confidence::High)
    None => abort("expected a proposal")
  }
}

// ============================================================================
// 新增：决策树的其余分支与优先级
// ============================================================================

///|
/// 决策树的**优先级**是 engine 最不能错的地方（TS L184-225 是一条严格有序的 if 链）。
/// 现有 12 个 legacy 用例只覆盖了单信号场景，
/// 本用例专门钉「多信号同时出现时谁赢」。
async test "decision tree honours its priority order" {
  let dir = @fs.tmpdir(prefix="evo-engine-")
  defer @fs.rmdir(dir, recursive=true)

  // loop 优先于 correction（TS L191 在 L201 之前）
  let (engine, _) = make_engine(dir, @types.Intensity::Full)
  let both = [
    signal(@types.SignalStrength::Medium, @types.SignalCategory::Loop, "loop"),
    strong_correction(),
  ]
  match engine.generate_proposal(mock_plugin(), signals=Some(both)).proposal() {
    Some(p) =>
      assert_eq(p.evolution_type, @types.EvolutionType::BehaviorOptimization)
    None => abort("expected a proposal")
  }

  // correction 优先于 preference（TS L201 在 L206 之前）
  let dir2 = @fs.tmpdir(prefix="evo-engine-")
  defer @fs.rmdir(dir2, recursive=true)
  let (engine2, _) = make_engine(dir2, @types.Intensity::Full)
  let both2 = [
    signal(
      @types.SignalStrength::Medium,
      @types.SignalCategory::Preference,
      "pref",
    ),
    strong_correction(),
  ]
  match
    engine2.generate_proposal(mock_plugin(), signals=Some(both2)).proposal() {
    Some(p) =>
      assert_eq(
        p.evolution_type,
        @types.EvolutionType::ErrorHandlingImprovement,
      )
    None => abort("expected a proposal")
  }
}

///|
/// preference 分支的双向判定（TS L206-211）：
/// `interface_clarity < 7` → interface_simplification，否则 documentation_enhancement。
async test "preference branch splits on interface_clarity" {
  // mock_plugin 的 clarity = 6.0 < 7 → interface_simplification
  let dir = @fs.tmpdir(prefix="evo-engine-")
  defer @fs.rmdir(dir, recursive=true)
  let (engine, _) = make_engine(dir, @types.Intensity::Full)
  let pref = signal(
    @types.SignalStrength::Medium,
    @types.SignalCategory::Preference,
    "prefers terse output",
  )
  match
    engine.generate_proposal(mock_plugin(), signals=Some([pref])).proposal() {
    Some(p) =>
      assert_eq(p.evolution_type, @types.EvolutionType::InterfaceSimplification)
    None => abort("expected a proposal")
  }

  // clarity = 8.5 >= 7 → documentation_enhancement
  let dir2 = @fs.tmpdir(prefix="evo-engine-")
  defer @fs.rmdir(dir2, recursive=true)
  let (engine2, _) = make_engine(dir2, @types.Intensity::Full)
  let clear_plugin = mock_plugin()
  let clearer : @types.PluginMetadata = {
    plugin_id: clear_plugin.plugin_id,
    name: clear_plugin.name,
    version: clear_plugin.version,
    kind: clear_plugin.kind,
    capabilities: clear_plugin.capabilities,
    tools: clear_plugin.tools,
    events: clear_plugin.events,
    dependencies: clear_plugin.dependencies,
    scanned_at: clear_plugin.scanned_at,
    path: clear_plugin.path,
    initial_metrics: {
      complexity_score: clear_plugin.initial_metrics.complexity_score,
      interface_clarity: 8.5,
      documentation_quality: 8.5,
      usage_frequency: None,
    },
  }
  match engine2.generate_proposal(clearer, signals=Some([pref])).proposal() {
    Some(p) => {
      assert_eq(
        p.evolution_type,
        @types.EvolutionType::DocumentationEnhancement,
      )
      assert_eq(p.matt_pocock_principle.wire_name(), "词汇即文档")
    }
    None => abort("expected a proposal")
  }
}

///|
/// workflow 分支（TS L214-216）→ capability_extension + custom_workflow。
async test "workflow signal maps to capability_extension" {
  let dir = @fs.tmpdir(prefix="evo-engine-")
  defer @fs.rmdir(dir, recursive=true)
  let (engine, _) = make_engine(dir, @types.Intensity::Full)

  let wf = signal(
    @types.SignalStrength::Medium,
    @types.SignalCategory::Workflow,
    "navigate then screenshot then export",
  )
  match engine.generate_proposal(mock_plugin(), signals=Some([wf])).proposal() {
    Some(p) => {
      assert_eq(p.evolution_type, @types.EvolutionType::CapabilityExtension)
      assert_eq(p.matt_pocock_principle, @types.MattPocockPrinciple::AlignFirst)
      match p.proposed_changes[0] {
        @types.Change::AddCapability(caps) => {
          assert_eq(caps[0].capability_name, "custom_workflow")
          assert_eq(caps[0].description, "navigate then screenshot then export")
        }
        _ => abort("expected AddCapability")
      }
    }
    None => abort("expected a proposal")
  }
}

///|
/// ★ **实测揭示的一处 TS 实质缺陷（原样保留，不修）。**
///
/// 决策树最后的性能兜底是 `avg_latency_ms > 2000 || success_rate < 0.9`（TS L220），
/// 而 `getStatistics` 在**没有任何工具调用**时返回 `success_rate: 0`（TS L177）。
/// 于是 `0 < 0.9` 恒真 → **任何没有指标的插件都会落到 performance_tuning**，
/// TS L225 那句 "Default: documentation enhancement" 实际上近乎死代码：
/// 只有当插件已有指标、且成功率 >= 0.9、且平均延迟 <= 2000 时才走得到。
///
/// 本次移植**原样保留**这个行为（改了会静默改变大量提案的类型，
/// 超出语言移植的范围），但把两个分支都写成用例钉死，
/// 并在 CONTEXT.md 记录这处已知缺陷。
async test "performance fallback swallows the documentation default when metrics are absent" {
  let dir = @fs.tmpdir(prefix="evo-engine-")
  defer @fs.rmdir(dir, recursive=true)
  let (engine, _) = make_engine(dir, @types.Intensity::Full)

  // pattern 类别在决策树里没有专属分支 → 落到性能兜底；
  // 而本插件没有任何指标 → success_rate = 0 < 0.9 → performance_tuning
  let pat = signal(
    @types.SignalStrength::Medium,
    @types.SignalCategory::Pattern,
    "some recurring pattern",
  )
  match
    engine.generate_proposal(mock_plugin(), signals=Some([pat])).proposal() {
    Some(p) => {
      assert_eq(p.evolution_type, @types.EvolutionType::PerformanceTuning)
      assert_eq(
        p.matt_pocock_principle,
        @types.MattPocockPrinciple::VerticalSlice,
      )
      // TS L370-376 的 proposeFlowOptimization 恒返回 [] → 变更集为空
      assert_eq(p.proposed_changes.length(), 0)
    }
    None => abort("expected a proposal")
  }
}

///|
/// 性能兜底的另一侧：指标健康时才能走到 `documentation_enhancement`。
/// 这条用例证明了上面那个默认分支**确实可达**，只是条件苛刻。
async test "documentation_enhancement is reachable only when metrics look healthy" {
  let dir = @fs.tmpdir(prefix="evo-engine-")
  defer @fs.rmdir(dir, recursive=true)
  let (engine, _) = make_engine(dir, @types.Intensity::Full)
  let metrics = @store.Jsonl::new(@util.path_join(dir, "metrics.jsonl"))

  // 3 条成功且快速的调用 → success_rate = 1.0 >= 0.9、avg_latency = 100 <= 2000
  let now = @util.now_ms()
  for _ in 0..<3 {
    metrics.append(slow_event("test-plugin-1.0.0", "fast_tool", 100, now))
  }

  let pat = signal(
    @types.SignalStrength::Medium,
    @types.SignalCategory::Pattern,
    "some recurring pattern",
  )
  match
    engine.generate_proposal(mock_plugin(), signals=Some([pat])).proposal() {
    Some(p) => {
      assert_eq(
        p.evolution_type,
        @types.EvolutionType::DocumentationEnhancement,
      )
      assert_eq(p.matt_pocock_principle.wire_name(), "词汇即文档")
    }
    None => abort("expected a proposal")
  }
}

///|
/// 性能兜底的触发条件（TS L219-222）：`avg_latency_ms > 2000 || success_rate < 0.9`。
/// 用**直接落盘**的历史事件构造，不依赖真实等待。
async test "performance fallback triggers on slow tools" {
  let dir = @fs.tmpdir(prefix="evo-engine-")
  defer @fs.rmdir(dir, recursive=true)
  let (engine, _) = make_engine(dir, @types.Intensity::Full)
  let metrics = @store.Jsonl::new(@util.path_join(dir, "metrics.jsonl"))

  // 三条慢调用（每条 3000ms > 2000）
  for _ in 0..<3 {
    metrics.append(
      slow_event("test-plugin-1.0.0", "slow_tool", 3000, @util.now_ms()),
    )
  }

  let pat = signal(
    @types.SignalStrength::Medium,
    @types.SignalCategory::Pattern,
    "some recurring pattern",
  )
  match
    engine.generate_proposal(mock_plugin(), signals=Some([pat])).proposal() {
    Some(p) => {
      assert_eq(p.evolution_type, @types.EvolutionType::PerformanceTuning)
      assert_eq(
        p.matt_pocock_principle,
        @types.MattPocockPrinciple::VerticalSlice,
      )
      // TS L370-376 的 proposeFlowOptimization 恒返回 [] → 变更集为空
      assert_eq(p.proposed_changes.length(), 0)
    }
    None => abort("expected a proposal")
  }
}

///|
/// 一条指定延迟的工具调用事件。
fn slow_event(
  plugin_id : String,
  tool : String,
  latency_ms : Int,
  ts : Int64,
) -> @types.PerformanceEvent {
  {
    session_id: "sess-test",
    plugin_id,
    ts,
    payload: @types.EventPayload::ToolCall({
      tool,
      params: Json::empty_object(),
      latency_ms,
      success: true,
      token_usage: None,
      retry_count: 0,
      error_message: None,
    }),
    context: {
      task_type: None,
      user_feedback: None,
      conversation_turn: 0,
      related_tools: None,
    },
  }
}

///|
/// 一份已完成的提案，用于冷却期测试。
/// 对应 legacy engine.test.ts L143-168 / L181-206 那两个手写的完整字面量。
fn completed_proposal(
  proposal_id : String,
  created_at : Int64,
) -> @types.EvolutionProposal {
  {
    proposal_id,
    plugin_id: "test-plugin-1.0.0",
    status: @types.ProposalStatus::Completed,
    created_at,
    trigger_signals: [strong_correction()],
    evolution_type: @types.EvolutionType::DocumentationEnhancement,
    matt_pocock_principle: @types.MattPocockPrinciple::VocabularyAsDocs,
    proposed_changes: [],
    expected_benefits: @types.EvolutionType::DocumentationEnhancement.expected_benefits(),
    validation_plan: {
      test_scenarios: [],
      success_criteria: "",
      rollback_strategy: "",
      validation_levels: [],
    },
    risk_assessment: {
      breaking_changes: false,
      backward_compatible: true,
      migration_effort: @types.MigrationEffort::Low,
      affected_users: 0,
      rollback_complexity: @types.RollbackComplexity::Simple,
    },
    signature: "prior-signature",
    confidence: @types.Confidence::Medium,
  }
}
