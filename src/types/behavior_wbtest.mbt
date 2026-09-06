///|
/// 领域行为的断言：状态机、分类器、映射表、配置解析。
/// 这些是 CONTEXT.md 里那几张表的**可执行形式**，改表必须改这里。
///
/// 本文件遵守两条工具链约束（都会以 deprecated 警告形式出现，
/// 而 `build.ps1 -Task check` 用了 `--deny-warn`，故等同硬错误）：
/// · 用 `ToJson::to_json(x)` 而非 `x.to_json()`（后者是隐式提升，已废弃）
/// · `#|` 多行串必须先 `let` 绑定，不能直接作实参

///|
/// CONTEXT.md L19-25 的提案状态机，5×5 = 25 种组合全部枚举。
/// 取代 legacy-ts/src/store/index.ts L104-110 的 Record 字面量。
test "ProposalStatus state machine: full 5x5 matrix" {
  let all = [
    ProposalStatus::Pending,
    ProposalStatus::Approved,
    ProposalStatus::Rejected,
    ProposalStatus::Executing,
    ProposalStatus::Completed,
  ]
  for from in all {
    for to in all {
      let expected = match (from, to) {
        (ProposalStatus::Pending, ProposalStatus::Approved) => true
        (ProposalStatus::Pending, ProposalStatus::Rejected) => true
        (ProposalStatus::Approved, ProposalStatus::Executing) => true
        // 失败自动回滚：executing → pending
        (ProposalStatus::Executing, ProposalStatus::Completed) => true
        (ProposalStatus::Executing, ProposalStatus::Pending) => true
        // 其余一律非法，包括自迁移（自迁移由 set_status 的幂等分支单独处理）
        _ => false
      }
      assert_eq(from.can_transition_to(to), expected)
    }
  }
}

///|
/// 终态不可再迁移 —— 这是 legacy-ts/tests/executor.test.ts L166-171
/// 「completed → approved 必须抛错」那条用例的类型层依据。
test "terminal statuses accept no transitions" {
  for
    to in [
      ProposalStatus::Pending,
      ProposalStatus::Approved,
      ProposalStatus::Rejected,
      ProposalStatus::Executing,
      ProposalStatus::Completed,
    ] {
    assert_eq(ProposalStatus::Completed.can_transition_to(to), false)
    assert_eq(ProposalStatus::Rejected.can_transition_to(to), false)
  }
}

///|
/// 取代 legacy-ts/src/monitor/index.ts L344-350。
/// **判定顺序与大小写敏感性都是行为契约**，不能「顺手优化」。
test "ErrorKind::classify keeps the TS branch order and case sensitivity" {
  assert_eq(
    ErrorKind::classify("request timeout after 30s"),
    ErrorKind::Timeout,
  )
  assert_eq(
    ErrorKind::classify("invalid parameter: url"),
    ErrorKind::ParameterError,
  )
  // "param" 单独也要命中（TS L346 的 || 分支）
  assert_eq(ErrorKind::classify("bad param"), ErrorKind::ParameterError)
  assert_eq(
    ErrorKind::classify("permission denied"),
    ErrorKind::PermissionError,
  )
  // "access" 也归为权限错误（TS L347）
  assert_eq(ErrorKind::classify("access denied"), ErrorKind::PermissionError)
  assert_eq(ErrorKind::classify("file not found"), ErrorKind::NotFound)
  assert_eq(ErrorKind::classify("target does not exist"), ErrorKind::NotFound)
  assert_eq(ErrorKind::classify("something exploded"), ErrorKind::RuntimeError)
  assert_eq(ErrorKind::classify(""), ErrorKind::RuntimeError)

  // 顺序敏感：同时含 timeout 与 permission 时必须归为 Timeout（TS 的 if 链顺序）
  assert_eq(ErrorKind::classify("permission check timeout"), ErrorKind::Timeout)
  // 大小写敏感：TS 用的是 String.prototype.includes，不做归一化。
  // 若这里「顺手」加 to_lower()，"Timeout" 会从 RuntimeError 变成 Timeout。
  assert_eq(ErrorKind::classify("Timeout"), ErrorKind::RuntimeError)
  assert_eq(ErrorKind::classify("NOT FOUND"), ErrorKind::RuntimeError)
}

///|
/// 取代 engine/index.ts L568 的嵌套三元。
test "MigrationEffort maps to rollback complexity" {
  assert_eq(
    MigrationEffort::Low.rollback_complexity(),
    RollbackComplexity::Simple,
  )
  assert_eq(
    MigrationEffort::Medium.rollback_complexity(),
    RollbackComplexity::Moderate,
  )
  assert_eq(
    MigrationEffort::High.rollback_complexity(),
    RollbackComplexity::Complex,
  )
}

///|
/// 取代 engine/index.ts L452-496 的收益表。数值区间是用户可见文案，逐字保留。
test "EvolutionType expected_benefits matches the TS table" {
  let b = EvolutionType::InterfaceSimplification.expected_benefits()
  assert_eq(b.latency_improvement, Some("30-40%"))
  assert_eq(b.token_reduction, Some("25-35%"))
  assert_eq(b.user_satisfaction, Some("+15-25%"))
  assert_eq(b.success_rate, None)
  assert_eq(b.error_reduction, None)

  let b = EvolutionType::BehaviorOptimization.expected_benefits()
  assert_eq(b.token_reduction, Some("40-60%"))
  assert_eq(b.error_reduction, Some("-50%"))
  assert_eq(b.latency_improvement, None)

  let b = EvolutionType::ErrorHandlingImprovement.expected_benefits()
  assert_eq(b.error_reduction, Some("-40-60%"))
  assert_eq(b.user_satisfaction, Some("+10-15%"))
}

///|
/// `None` 字段必须在 JSON 里**被省略**而不是写成 null ——
/// 与 TS 里「不写这个键」的行为一致（实证见 core/json 的 "optional field" 用例）。
test "ExpectedBenefits omits absent keys instead of writing null" {
  let benefits = EvolutionType::DocumentationEnhancement.expected_benefits()
  inspect(
    ToJson::to_json(benefits).stringify(),
    content="{\"user_satisfaction\":\"+10-20%\"}",
  )
}

///|
/// 取代 engine/index.ts L531-542 的 switch。
test "EvolutionType extra_scenarios" {
  json_inspect(EvolutionType::InterfaceSimplification.extra_scenarios(), content=[
    "测试新工具接口", "测试向后兼容性",
  ])
  json_inspect(EvolutionType::BehaviorOptimization.extra_scenarios(), content=[
    "测试循环检测", "测试干预提示",
  ])
  json_inspect(EvolutionType::PerformanceTuning.extra_scenarios(), content=[
    "性能基准测试", "负载测试",
  ])
  json_inspect(EvolutionType::DocumentationEnhancement.extra_scenarios(), content=[])
}

///|
/// 取代 monitor/index.ts L355-366 的 calculateCutoff。
test "TimeRange spans and cutoffs" {
  assert_eq(TimeRange::LastHour.span_ms(), 3_600_000L)
  assert_eq(TimeRange::LastDay.span_ms(), 86_400_000L)
  assert_eq(TimeRange::LastWeek.span_ms(), 604_800_000L)
  assert_eq(TimeRange::All.span_ms(), 0L)

  let now = 1_757_000_000_000L
  assert_eq(TimeRange::LastHour.cutoff_ms(now), now - 3_600_000L)
  assert_eq(TimeRange::All.cutoff_ms(now), 0L)
  // 时钟异常或 span 大于纪元至今时夹到 0，绝不返回负值
  assert_eq(TimeRange::LastWeek.cutoff_ms(1_000L), 0L)
}

///|
/// 取代 engine/index.ts L615 的 `Object.values(...).filter(...).length` ——
/// 那行依赖 JS 运行时对象反射，MoonBit 无对应能力，是本次移植的硬阻塞之一。
test "changes_kinds counts only non-empty change groups, in order" {
  let merge : ToolMerge = {
    new_tool: "smart_fill",
    merged_from: ["navigate", "click", "type"],
    new_interface: {
      params: ["url", "selector", "text"],
      description: "一站式表单填充：导航 + 定位 + 输入",
      defaults: None,
    },
    backward_compatible: true,
  }
  let doc : DocumentationUpdate = {
    file: "SKILL.md",
    section: "Usage Examples",
    new_content: "添加具体使用示例",
    reason: "文档质量评分较低",
  }
  let changes : Array[Change] = [
    Change::MergeTools([merge]),
    Change::SimplifyParams([]), // 空变更不计入
    Change::UpdateDocumentation([doc]),
  ]
  json_inspect(changes_kinds(changes).map(fn(k) { k.wire_name() }), content=[
    "merge_tools", "update_documentation",
  ])
  assert_eq(changes_kinds(changes).length(), 2)
  assert_eq(changes_kinds([]).length(), 0)
  assert_eq(Change::MergeTools([merge]).kind(), ChangeKind::MergeTools)
  assert_eq(Change::MergeTools([]).is_empty(), true)
  assert_eq(Change::MergeTools([merge]).is_empty(), false)
}

///|
/// `Change` 的自描述 wire 形式。用对象而非 derive 的 tagged-array，
/// 因为 proposals.jsonl 是面向人类审批决策的低频文档，可读性优先。
test "Change serializes as a self-describing object and round-trips" {
  let c : Change = Change::AddCapability([
    {
      capability_name: "custom_workflow",
      description: "用户重复的三步操作",
      implementation: "基于用户工作流模式自动生成",
      dependencies: [],
    },
  ])
  let text = ToJson::to_json(c).stringify()
  let expected =
    #|{"kind":"add_capability","items":[{"capability_name":"custom_workflow","description":"用户重复的三步操作","implementation":"基于用户工作流模式自动生成","dependencies":[]}]}
  inspect(text, content=expected)
  let back : Change = @json.from_json(@json.parse(text))
  assert_eq(back, c)
}

///|
/// 未知 kind 必须被拒绝，且错误消息来自 wire 表（而非本文件里另抄一份列表）。
test "Change rejects an unknown kind" {
  let raw =
    #|{"kind":"teleport","items":[]}
  let msg = try {
    let decoded : Change = @json.from_json(@json.parse(raw))
    ignore(decoded)
    ""
  } catch {
    e => e.to_string()
  }
  assert_true(msg.contains("teleport"))
  assert_true(msg.contains("merge_tools"))
}

///|
/// 取代 TS 里 `"session:x"` / `"metrics:x"` / `"user:manual"` 的字符串前缀约定。
test "Evidence serializes as a self-describing object and round-trips" {
  let cases : Array[Evidence] = [
    Evidence::Session("sess_abc"),
    Evidence::Metrics("browser-use-0.4.1"),
    Evidence::UserManual,
    Evidence::FilePath("/var/log/session.jsonl"),
  ]
  for c in cases {
    let text = ToJson::to_json(c).stringify()
    let back : Evidence = @json.from_json(@json.parse(text))
    assert_eq(back, c)
  }
  let session = Evidence::Session("sess_abc")
  inspect(
    ToJson::to_json(session).stringify(),
    content="{\"kind\":\"session\",\"id\":\"sess_abc\"}",
  )
  inspect(
    ToJson::to_json(Evidence::UserManual).stringify(),
    content="{\"kind\":\"user_manual\"}",
  )
}

///|
/// 取代 scanner/index.ts L140-142 的 `[...new Set(xs)]`。
/// 关键性质是**顺序确定性**：MoonBit 的 Set 是哈希表、迭代序不定，
/// 直接用它会让 capabilities 数组顺序在不同运行间抖动。
test "dedup_ordered keeps first-occurrence order" {
  json_inspect(dedup_ordered(["b", "a", "b", "c", "a"]), content=["b", "a", "c"])
  json_inspect(dedup_ordered([]), content=[])
  json_inspect(dedup_ordered(["x", "x", "x"]), content=["x"])
}

///|
/// 取代 legacy-ts 的默认阈值（monitor L227 / L238 / L267 的三个硬编码常量）。
test "SignalThresholds defaults mirror the TS hardcoded constants" {
  let t = SignalThresholds::default()
  assert_eq(t.consecutive_failures, 3)
  assert_eq(t.loop_detection, 5)
  assert_eq(t.latency_regression, 0.2)
}

///|
/// 修掉配置孤岛：legacy-ts 的 plugin.json L48-66 写了 evolution_config
/// 但 src/** 无任何代码读取它。这里用真实的 plugin.json 片段验证解析。
test "EngineConfig::from_json reads the real plugin.json shape" {
  // ★ 2.0 的真实形状：signal_thresholds 是**扁平**的三个数，
  // 字段名与 SignalThresholds 的字段逐一对应。
  // 刻意用**非默认值**（7 / 9 / 0.75）：若解析其实没生效、只是回落到
  // SignalThresholds::default()（3 / 5 / 0.2），下面的断言就会全部失败。
  // 这是本用例最要紧的一点 —— 1.0 版的同名测试内联的是嵌套旧形状，
  // from_json 根本读不懂，断言之所以通过纯粹因为默认值恰好也是 3/5/0.2，
  // 属于「碰巧变绿的假测试」。
  let raw =
    #|{
    #|  "evolution_config": {
    #|    "intensity": "100%",
    #|    "auto_approve": true,
    #|    "cooldown_hours": 6,
    #|    "signal_thresholds": {
    #|      "consecutive_failures": 7,
    #|      "loop_detection": 9,
    #|      "latency_regression": 0.75
    #|    }
    #|  }
    #|}
  let cfg = EngineConfig::from_json(@json.parse(raw))
  assert_eq(cfg.intensity, Intensity::Full)
  assert_eq(cfg.cooldown_hours, 6)
  // auto_approve 没有消费方，写 true 会被显式告警并回落 false（见下面
  // "auto_approve: true is reported..." 用例），这里断言回落后的值。
  assert_eq(cfg.auto_approve, false)
  assert_eq(cfg.thresholds.consecutive_failures, 7)
  assert_eq(cfg.thresholds.loop_detection, 9)
  assert_eq(cfg.thresholds.latency_regression, 0.75)

  // 也允许直接传 evolution_config 的内容本身（外层包装是可选的），
  // 且缺失的键各自回落到默认值
  let inner_raw =
    #|{"intensity":"50%","cooldown_hours":1}
  let inner_only = EngineConfig::from_json(@json.parse(inner_raw))
  assert_eq(inner_only.intensity, Intensity::Half)
  assert_eq(inner_only.cooldown_hours, 1)
  assert_eq(inner_only.thresholds, SignalThresholds::default())
}

///|
/// 1.0 版的嵌套 signal_thresholds（strong/medium 两层）**仍然能读**，
/// 作为回退路径保留，好让旧的配置文件继续生效。
///
/// 刻意用**非默认值**（4 / 6 / 0.33）：旧版的同名测试用的是 3 / 5 / 0.2，
/// 恰好等于 `SignalThresholds::default()`，于是「根本没读到」与「读到了」
/// 两种情况都能变绿 —— 那是个碰巧通过的假测试。换成非默认值后，
/// 回退路径一旦失效就会立即变红。
///
/// 注意 1.0 的键名与结构体字段并不同名：`performance_drop` → `latency_regression`。
/// 这份手写映射无据可依，也正是 2.0 把规范形状换成扁平的理由。
test "EngineConfig::from_json still reads the legacy 1.0 nested thresholds shape" {
  let legacy =
    #|{
    #|  "evolution_config": {
    #|    "intensity": "50%",
    #|    "auto_approve": false,
    #|    "max_proposals_per_session": 3,
    #|    "cooldown_hours": 24,
    #|    "signal_thresholds": {
    #|      "strong": { "consecutive_failures": 4, "performance_drop": 0.33 },
    #|      "medium": { "pattern_repeat": 2, "loop_detection": 6 }
    #|    }
    #|  }
    #|}
  let cfg = EngineConfig::from_json(@json.parse(legacy))
  assert_eq(cfg.intensity, Intensity::Half)
  assert_eq(cfg.cooldown_hours, 24)
  assert_eq(cfg.auto_approve, false)
  // 嵌套路径真的被读到了，而不是回落到默认的 3 / 5 / 0.2
  assert_eq(cfg.thresholds.consecutive_failures, 4)
  assert_eq(cfg.thresholds.loop_detection, 6)
  assert_eq(cfg.thresholds.latency_regression, 0.33)
  // `max_proposals_per_session` 被忽略（已删除的死配置），不报错
}

///|
/// 扁平与嵌套**同时存在**时，扁平优先。
/// 这钉住了 `threshold_field` 的尝试顺序：若有人把两者调反，
/// 2.0 的规范配置就会被 1.0 的遗留值默默覆盖。
test "EngineConfig::from_json prefers the flat shape over the nested one" {
  let both =
    #|{
    #|  "signal_thresholds": {
    #|    "consecutive_failures": 8,
    #|    "loop_detection": 11,
    #|    "latency_regression": 0.9,
    #|    "strong": { "consecutive_failures": 2, "performance_drop": 0.1 },
    #|    "medium": { "loop_detection": 3 }
    #|  }
    #|}
  let cfg = EngineConfig::from_json(@json.parse(both))
  assert_eq(cfg.thresholds.consecutive_failures, 8)
  assert_eq(cfg.thresholds.loop_detection, 11)
  assert_eq(cfg.thresholds.latency_regression, 0.9)
}

///|
/// 配置是人写的、可能残缺的输入：任何缺失或非法字段都必须回退默认值，
/// 绝不能让整个插件启动失败。
test "EngineConfig::from_json falls back to defaults on bad input" {
  assert_eq(EngineConfig::from_json(Json::null()), EngineConfig::default())
  let empty =
    #|{}
  assert_eq(
    EngineConfig::from_json(@json.parse(empty)),
    EngineConfig::default(),
  )
  // 未知 intensity 回退 Half，而不是 raise
  let bad_intensity =
    #|{"intensity":"200%"}
  assert_eq(
    EngineConfig::from_json(@json.parse(bad_intensity)).intensity,
    Intensity::Half,
  )
  // 类型不符（字符串而非数字）回退默认
  let bad_cooldown =
    #|{"cooldown_hours":"24"}
  assert_eq(
    EngineConfig::from_json(@json.parse(bad_cooldown)).cooldown_hours,
    24,
  )
  // signal_thresholds 部分缺失时逐字段回退
  let partial =
    #|{"signal_thresholds":{"strong":{"consecutive_failures":7}}}
  let cfg = EngineConfig::from_json(@json.parse(partial))
  assert_eq(cfg.thresholds.consecutive_failures, 7)
  assert_eq(cfg.thresholds.loop_detection, 5)
  assert_eq(cfg.thresholds.latency_regression, 0.2)
}

///|
/// 取代 monitor 里 9 处 `(e.event_data as any).xxx` 的窄接口投影。
test "EventPayload projections replace the TS as-any casts" {
  let call : EventPayload = EventPayload::ToolCall({
    tool: "navigate",
    params: Json::empty_object(),
    latency_ms: 120,
    success: true,
    token_usage: None,
    retry_count: 0,
    error_message: None,
  })
  assert_eq(call.tool_name(), Some("navigate"))
  assert_eq(call.succeeded(), Some(true))
  assert_eq(call.duration_ms(), Some(120))

  let fired : EventPayload = EventPayload::EventFired({
    event_name: "on_error",
    payload: Json::null(),
    processing_time_ms: 7,
  })
  assert_eq(fired.tool_name(), None)
  assert_eq(fired.succeeded(), None)
  assert_eq(fired.duration_ms(), Some(7))

  let failed : EventPayload = EventPayload::Failed({
    error_kind: ErrorKind::Timeout,
    message: "timeout",
    stack_trace: None,
    recovery_attempted: false,
  })
  assert_eq(failed.tool_name(), None)
  assert_eq(failed.succeeded(), None)
  assert_eq(failed.duration_ms(), None)
}

///|
/// 完整提案的 JSON 往返 —— 这是 proposals.jsonl 的持久化契约。
/// 字段顺序必须与 legacy-ts/src/types/index.ts L125-139 的 interface 一致。
test "EvolutionProposal round-trips through JSONL-shaped JSON" {
  let p : EvolutionProposal = {
    proposal_id: "evo-2026-09-04-browser-use-interface-simplification",
    plugin_id: "browser-use-0.4.1",
    status: ProposalStatus::Pending,
    created_at: 1_757_000_000_700L,
    trigger_signals: [
      {
        strength: SignalStrength::Medium,
        category: SignalCategory::Loop,
        description: "Tool navigate called 5 times in loop",
        evidence: Evidence::Session("sess_abc"),
        ts: 1_757_000_000_700L,
        plugin_id: "browser-use-0.4.1",
        count: Some(5),
        tool: Some("navigate"),
      },
    ],
    evolution_type: EvolutionType::BehaviorOptimization,
    matt_pocock_principle: MattPocockPrinciple::TightFeedback,
    proposed_changes: [
      Change::AddMiddleware([
        {
          name: "loop_detection",
          target_tool: Some("navigate"),
          target_event: None,
          threshold: Some(5),
          intervention: "检测到循环，建议使用批量操作或调整参数",
          priority: 10,
        },
      ]),
    ],
    expected_benefits: EvolutionType::BehaviorOptimization.expected_benefits(),
    validation_plan: {
      test_scenarios: ["测试循环检测"],
      success_criteria: "成功率 >= 95%，延迟 < 2s，无回归问题",
      rollback_strategy: "保留原版本 30 天，支持一键回滚",
      validation_levels: [
        {
          level: ValidationLevelTag::T0,
          description: "语法验证：代码可编译/解析",
          automated: true,
          timeout_ms: Some(30000),
        },
      ],
    },
    risk_assessment: {
      breaking_changes: false,
      backward_compatible: true,
      migration_effort: MigrationEffort::Low,
      affected_users: 0,
      rollback_complexity: RollbackComplexity::Simple,
    },
    signature: "browser-use-behavior-optimization",
    confidence: Confidence::Medium,
  }

  let text = ToJson::to_json(p).stringify()
  let back : EvolutionProposal = @json.from_json(@json.parse(text))
  assert_eq(back, p)

  // 关键字段在 JSON 里必须是 CONTEXT.md 的词汇，而不是 PascalCase 变体名
  assert_true(text.contains("\"status\":\"pending\""))
  assert_true(text.contains("\"evolution_type\":\"behavior_optimization\""))
  assert_true(
    text.contains("\"matt_pocock_principle\":\"紧反馈环 > 盲目试错\""),
  )
  assert_true(text.contains("\"confidence\":\"medium\""))
  assert_true(text.contains("\"level\":\"T0\""))
  // ★ Int64 在 MoonBit 的 JSON 里是**带引号的十进制字符串**，不是裸数字。
  // 这是 core/json 的刻意设计：`Json::Number` 用 Double 承载，而
  // `FromJson for Int64` 直接要求 `String`（源码报错文本为
  // "Int64::from_json: expected number in string representation"），
  // 以避免超过 2^53 的整数丢精度。
  // 上面的 `assert_eq(back, p)` 往返成功已证明 ToJson/FromJson 两侧同构。
  //
  // 为何用 Int64 而不是 Int：MoonBit 的 `Int` 是 32 位
  // （@int.max_value + 1 回绕到 -2147483648），而 Unix 毫秒约 1.7e12 远超此范围。
  assert_true(text.contains("\"created_at\":\"1757000000700\""))
}

// ============================================================================
// 加固 H2：配置取值域校验（越界 → 回落默认值 + 点名字段告警）
// ============================================================================

///|
/// 从告警文本里取出被点名的字段名。
///
/// 约定每条告警的形状是 `"<字段名>: <说明>"`（说明里不含半角冒号），
/// 于是断言只依赖字段名、不依赖中文措辞，也不依赖 4 条告警的先后顺序。
fn warned_fields(warns : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for w in warns {
    for part in w.split(":") {
      out.push(part.trim().to_owned())
      break // 只取冒号前的字段名
    }
  }
  out
}

///|
/// H2：越界的取值必须回落默认值，并**点名字段**告警。
///
/// `EngineConfig::from_json` 每个字段都有兜底 —— 配置写错不该让引擎起不来，
/// 这是有意的。但「写成退化值」和「没写」后果完全不同：
/// `consecutive_failures: 0` 会让每次**成功**调用都发一条 strong 信号
/// （成功把计数清成 0，而判定是 `>=`，见 `monitor.mbt` L321），
/// `loop_detection: 1` 让每次调用都算「循环」，
/// `latency_regression: 0` 让任何抖动都算「退化」（L476 是 `>`），
/// `cooldown_hours: -1` 让冷却终点落在过去、冷却形同不存在（engine L167）。
/// 这些值过去被静默兜底，引擎会拿着垃圾信号去改真实插件。
test "EngineConfig::from_json_checked reports out-of-domain values by name" {
  let raw =
    #|{
    #|  "evolution_config": {
    #|    "cooldown_hours": -1,
    #|    "signal_thresholds": {
    #|      "consecutive_failures": 0,
    #|      "loop_detection": 1,
    #|      "latency_regression": 0
    #|    }
    #|  }
    #|}
  let (cfg, warns) = EngineConfig::from_json_checked(@json.parse(raw))
  // 四个越界字段全部回落默认值，而不是拿退化值去驱动检测逻辑
  assert_eq(cfg, EngineConfig::default())
  assert_eq(warns.length(), 4)
  let fields = warned_fields(warns)
  assert_true(fields.contains("cooldown_hours"))
  assert_true(fields.contains("signal_thresholds.consecutive_failures"))
  assert_true(fields.contains("signal_thresholds.loop_detection"))
  assert_true(fields.contains("signal_thresholds.latency_regression"))
}

///|
/// 非整数阈值过去被 `.to_int()` **静默截断**（`2.5` → 2，无任何提示），
/// 检测灵敏度已变而写配置的人不知情 —— 与 H2 的越界取值同属「静默改行为」。
/// 钉成「回落默认值 + 点名告警」，让失效可见。
test "EngineConfig::from_json_checked reports non-integer thresholds and falls back" {
  let raw =
    #|{
    #|  "signal_thresholds": {
    #|    "consecutive_failures": 2.5,
    #|    "loop_detection": 4.5
    #|  }
    #|}
  let (cfg, warns) = EngineConfig::from_json_checked(@json.parse(raw))
  // 非整数不截断采纳，而是回落各自的默认值（3 与 5）
  let td = EngineConfig::default().thresholds
  assert_eq(cfg.thresholds.consecutive_failures, td.consecutive_failures)
  assert_eq(cfg.thresholds.loop_detection, td.loop_detection)
  assert_eq(warns.length(), 2)
  let fields = warned_fields(warns)
  assert_true(fields.contains("signal_thresholds.consecutive_failures"))
  assert_true(fields.contains("signal_thresholds.loop_detection"))
  // 告警消息里带上写错的那个值，人能一眼看出配置文件哪里错了
  assert_true(warns[0].contains("2.5 is not an integer"))
}

///|
/// H2：合法域**边界上**的值必须原样生效，且一条告警都不产生。
///
/// 刻意取边界值（0 / 1 / 2 / 0.01 / 上界 87600）而不是中间值：
/// 若校验写成了「clamp 到边界」，中间值也能过，只有端点能区分
/// 「接受」与「改写」。
test "EngineConfig::from_json_checked keeps in-domain values untouched" {
  let raw =
    #|{
    #|  "cooldown_hours": 0,
    #|  "signal_thresholds": {
    #|    "consecutive_failures": 1,
    #|    "loop_detection": 2,
    #|    "latency_regression": 0.01
    #|  }
    #|}
  let (cfg, warns) = EngineConfig::from_json_checked(@json.parse(raw))
  assert_eq(warns.length(), 0)
  assert_eq(cfg.cooldown_hours, 0)
  assert_eq(cfg.thresholds.consecutive_failures, 1)
  assert_eq(cfg.thresholds.loop_detection, 2)
  assert_eq(cfg.thresholds.latency_regression, 0.01)

  let upper_raw =
    #|{"cooldown_hours":87600}
  let (upper, upper_warns) = EngineConfig::from_json_checked(
    @json.parse(upper_raw),
  )
  assert_eq(upper_warns.length(), 0)
  assert_eq(upper.cooldown_hours, 87600)

  // 上界之外（多 1）就要回落 + 告警
  let over_raw =
    #|{"cooldown_hours":87601,"signal_thresholds":{"latency_regression":100.1}}
  let (over, over_warns) = EngineConfig::from_json_checked(
    @json.parse(over_raw),
  )
  assert_eq(over_warns.length(), 2)
  assert_eq(over.cooldown_hours, 24)
  assert_eq(over.thresholds.latency_regression, 0.2)

  // 100% 是合法上界（延迟翻倍算退化）
  let hundred_raw =
    #|{"signal_thresholds":{"latency_regression":100}}
  let (hundred, hundred_warns) = EngineConfig::from_json_checked(
    @json.parse(hundred_raw),
  )
  assert_eq(hundred_warns.length(), 0)
  assert_eq(hundred.thresholds.latency_regression, 100.0)
}

///|
/// H2：`from_json` 的同步签名与既有语义不变 —— 它等于 `from_json_checked`
/// 丢掉告警。校验不能让本来能解析出来的东西变得解析不出来。
test "EngineConfig::from_json agrees with from_json_checked" {
  let a =
    #|{"intensity":"100%","cooldown_hours":-5}
  let b =
    #|{}
  let c =
    #|{"signal_thresholds":{"consecutive_failures":0,"loop_detection":5,"latency_regression":0.5}}
  let d =
    #|{"cooldown_hours":"24"}
  let e =
    #|{"intensity":"999%","cooldown_hours":3}
  for raw in [a, b, c, d, e] {
    let json = @json.parse(raw)
    let (checked, _) = EngineConfig::from_json_checked(json)
    assert_eq(EngineConfig::from_json(json), checked)
  }
}

///|
/// H2：非数值 / 缺失字段仍然静默回落默认值，**不**产生告警。
///
/// 类型不符与「根本没写」在配置文件里太常见了，为它们告警会淹没真正
/// 要紧的越界告警。这条用例守住「只有取值域越界才告警」的边界。
test "EngineConfig::from_json_checked stays silent on missing or mistyped keys" {
  let raw =
    #|{"cooldown_hours":"24","intensity":7,"signal_thresholds":"none","auto_approve":"yes"}
  let (cfg, warns) = EngineConfig::from_json_checked(@json.parse(raw))
  assert_eq(warns.length(), 0)
  assert_eq(cfg, EngineConfig::default())
}

///|
/// R：`max_log_bytes`（观测日志保留上限）的取值域校验。
///
/// 与 H2 的四个数值字段同理：低于下界（1 MiB）意味着裁剪几乎每轮 flush
/// 都会触发（读全文件 + 原子重写的「裁剪风暴」），属退化取值 ——
/// 回落默认值并点名告警。上界是 Int 饱和值，正常配置不会触及。
test "EngineConfig::from_json_checked validates max_log_bytes" {
  // 低于下界 → 默认 + 点名告警
  let low_raw =
    #|{"max_log_bytes": 100}
  let (low, low_warns) = EngineConfig::from_json_checked(@json.parse(low_raw))
  assert_eq(low.max_log_bytes, default_max_log_bytes)
  assert_eq(low_warns.length(), 1)
  assert_true(warned_fields(low_warns).contains("max_log_bytes"))

  // 0 与负数同样越界（0 会让「不做保留」静默生效，把无界增长带回来）
  let zero_raw =
    #|{"max_log_bytes": 0}
  let (zero, zero_warns) = EngineConfig::from_json_checked(
    @json.parse(zero_raw),
  )
  assert_eq(zero.max_log_bytes, default_max_log_bytes)
  assert_eq(zero_warns.length(), 1)

  // 下边界值原样生效（区分「接受」与「clamp」）
  let edge_raw =
    #|{"max_log_bytes": 1048576}
  let (edge, edge_warns) = EngineConfig::from_json_checked(
    @json.parse(edge_raw),
  )
  assert_eq(edge_warns.length(), 0)
  assert_eq(edge.max_log_bytes, 1_048_576)

  // 缺省 → 默认值，无告警
  let absent_raw =
    #|{}
  let (absent, absent_warns) = EngineConfig::from_json_checked(
    @json.parse(absent_raw),
  )
  assert_eq(absent.max_log_bytes, default_max_log_bytes)
  assert_eq(absent_warns.length(), 0)
}

///|
/// P2：`auto_approve` 在 1.0 就只是声明、从未被读过（`legacy-ts/src/types/index.ts:295`），
/// 2.0 忠实移植了这个孤岛。缺陷不在「没接通」，而在**静默**：配置里写
/// `auto_approve: true` 的人以为绕过了审批，而审批照旧必经，且没有任何提示。
/// 这里钉成「显式告警 + 回落 false」，与 H2 对越界取值的处理同一套原则。
/// 注意这**不是**接通自动审批：人工审批是「自动改代码失控」的唯一闸门，
/// 要接通它属于对外语义变更，需要单独决策（见 CONTEXT.md 已知缺陷清单）。
test "auto_approve: true is reported and falls back to false" {
  let raw =
    #|{
    #|  "intensity": "100%",
    #|  "auto_approve": true,
    #|  "cooldown_hours": 6
    #|}
  let (cfg, warns) = EngineConfig::from_json_checked(@json.parse(raw))
  assert_eq(cfg.auto_approve, false)
  let mut mentions = false
  for w in warns {
    if w.contains("auto_approve") {
      mentions = true
    }
  }
  assert_true(mentions)
  // 其余字段不受影响：告警只针对这一项，不做整体回落
  assert_eq(cfg.intensity, Intensity::Full)
  assert_eq(cfg.cooldown_hours, 6)
}

///|
/// 显式写 false（plugin.json 的出厂值）不该产生任何噪声。
test "auto_approve: false is accepted silently" {
  let raw =
    #|{"auto_approve":false}
  let (cfg, warns) = EngineConfig::from_json_checked(@json.parse(raw))
  assert_eq(cfg.auto_approve, false)
  assert_eq(warns.length(), 0)
}

///|
/// 缺省不写这一项时也不该告警 —— 否则每次启动都会为「用户没写的字段」刷屏。
test "absent auto_approve produces no warning" {
  let raw =
    #|{"intensity":"50%"}
  let (cfg, warns) = EngineConfig::from_json_checked(@json.parse(raw))
  assert_eq(cfg.auto_approve, false)
  assert_eq(warns.length(), 0)
}
