///|
/// 进化引擎。取代 legacy-ts/src/engine/index.ts L25-226 与 L501-545。
///
/// 职责：读信号 → 按强度过滤 → 去重与冷却 → 决策进化类型 → 生成变更/收益/
/// 验证计划/风险 → 落盘提案。
///
/// **相对 TS 的两处结构性改进**：
///
/// 1. `generate_proposal` 返回 `ProposalOutcome` 枚举而不是 `EvolutionProposal | null`。
///    TS 用 `null` 表达了**三种完全不同的原因**（强度为 0%、信号不足、冷却期），
///    调用方无从区分，于是 `mcp/server.ts` L194-199 只能给一句笼统的
///    "insufficient signals, cooldown, or duplicate"。枚举把这个信息还原出来，
///    而映射回 TS 的 null/非 null 语义是完全确定的（见 `ProposalOutcome::proposal`）。
///
/// 2. 决策树是一条**单一的 if-else 链**，10 个分支（7 个与 TS L184-225 逐行
///    对应的通用分支 + 3 个 v2.5 M-3 新增的写作领域分支）的优先级顺序不可重排。
///    每个通用分支上方保留 TS 的原英文注释；写作领域分支不参与 TS 对照。
///    刻意不拆成多个 `match`：拆开之后就看不出「loop 优先于 struggle」「写作
///    领域优先于通用 correction」这类跨分支的优先级关系，而这正是最容易在
///    重构中被无意调换的东西。

///|
/// `generate_proposal` 的结果。
///
/// 与 TS 的 `EvolutionProposal | null` 的对应关系（用于保持 MCP 层的响应不变）：
/// · `Created` / `AlreadyPending` / `Duplicate` → TS 返回**提案对象**
/// · `Disabled` / `NoSignals` / `InCooldown` → TS 返回 **null**
pub(all) enum ProposalOutcome {
  /// 新生成并已落盘
  Created(@types.EvolutionProposal)
  /// 该插件已有待处理提案，直接返回它（对齐 TS L80-84：**不是** null）
  AlreadyPending(@types.EvolutionProposal)
  /// 同签名的非 rejected 提案已存在，直接返回它（对齐 TS L121-126）
  Duplicate(@types.EvolutionProposal)
  /// 强度为 0%，进化被完全禁用（对齐 TS L60-63）
  Disabled
  /// 按强度过滤后没有可用信号（对齐 TS L74-77）
  NoSignals
  /// 该插件仍在冷却期内（对齐 TS L88-92）
  InCooldown
} derive(Eq, Debug)

///|
/// 取出结果里的提案（若有）。这正是 TS 那个 `EvolutionProposal | null` 返回值，
/// MCP 层用它保持与 legacy 完全一致的响应形状。
pub fn ProposalOutcome::proposal(
  self : ProposalOutcome,
) -> @types.EvolutionProposal? {
  match self {
    Created(p) => Some(p)
    AlreadyPending(p) => Some(p)
    Duplicate(p) => Some(p)
    Disabled => None
    NoSignals => None
    InCooldown => None
  }
}

///|
/// 无提案时给用户的原因说明。取代 TS `mcp/server.ts` L194-199 那句
/// 把三种原因混在一起的话。
pub fn ProposalOutcome::reason(self : ProposalOutcome) -> String {
  match self {
    Created(_) => "proposal created"
    AlreadyPending(_) => "a pending proposal already exists for this plugin"
    Duplicate(_) => "an equivalent proposal already exists"
    Disabled => "evolution is disabled (intensity: 0%)"
    NoSignals => "insufficient signals to trigger evolution"
    InCooldown => "plugin is in the cooldown period"
  }
}

///|
/// 进化引擎。
pub struct EvolutionEngine {
  monitor : @monitor.PerformanceMonitor
  proposals : @store.ProposalStore
  signals : @store.Jsonl
  config : @types.EngineConfig
}

///|
/// 构造。对应 legacy-ts 的
/// `new EvolutionEngine(monitor, proposalsStore, config, signalsStore)`（L35-49），
/// 但把 4 个各自带默认值的参数收敛为 4 个必填参数 ——
/// TS 的默认值（L37-39 里 `new ProposalStore()`、`new JsonlStore('~/.harness-evolution/signals.jsonl')`）
/// 正是「默认路径散落在 4 个文件」这个毛病的来源之一，已由 `store/paths.mbt` 收拢。
pub fn EvolutionEngine::new(
  monitor : @monitor.PerformanceMonitor,
  proposals : @store.ProposalStore,
  signals : @store.Jsonl,
  config : @types.EngineConfig,
) -> EvolutionEngine {
  { monitor, proposals, signals, config }
}

///|
/// 生成进化提案。取代 TS L54-150。
///
/// 8 道闸门的顺序与 TS **逐一对应**，不得重排：
/// ① 强度为 0% → 短路（L60-63）
/// ② 取信号（未提供则从 signals.jsonl 读该插件的）（L66-68）
/// ③ 信号聚合（时间衰减）—— 2.x 新增，TS 无对应闸门
/// ④ 按强度过滤（L71）
/// ⑤ 过滤后为空 → NoSignals（L74-77）
/// ⑥ 已有 pending → **返回该 pending**（L80-84）
/// ⑦ 冷却期命中 → InCooldown（L87-92）
/// ⑧ 同签名重复 → **返回已存在的**（L120-126）
/// 全过之后才构造提案并落盘（L129-149）。
///
/// 注意 ⑥ 与 ⑧ 返回的是**已存在的提案**而不是 null —— 这是 TS 的既有语义，
/// 也是最容易在移植时被「顺手统一成 null」而破坏的一处。
/// `signals` 是 `Option` 而不是「空数组表示未提供」：TS 区分
/// `undefined`（从 signals.jsonl 读）与 `[]`（明确告知没有信号），
/// 而 legacy engine.test.ts L217-220 恰好靠传 `[]` 来验证 NoSignals 分支。
/// 用空数组当哨兵会把这两种语义合并，那条用例就测不出来了。
pub async fn EvolutionEngine::generate_proposal(
  self : EvolutionEngine,
  plugin : @types.PluginMetadata,
  signals? : Array[@types.EvolutionSignal]? = None,
) -> ProposalOutcome {
  // ① 强度为 0% → 完全禁用
  if self.config.intensity == @types.Intensity::Off {
    @util.log_info("Engine", "Evolution disabled (intensity: 0%)")
    return Disabled
  }

  // ② 取信号
  let raw_signals = match signals {
    Some(s) => s
    None => self.get_signals_for_plugin(plugin.plugin_id)
  }

  // ③ 应用信号聚合（时间衰减）
  let now = @util.now_ms()
  let aggregated = aggregate_signals(raw_signals, now)

  // ④ 按强度过滤
  let filtered = filter_by_intensity(aggregated, self.config.intensity)

  // ⑤ 过滤后为空
  if filtered.length() == 0 {
    @util.log_info("Engine", "No signals to trigger evolution")
    return NoSignals
  }

  // ⑥ 已有 pending → 返回它
  match self.proposals.find_pending_for_plugin(plugin.plugin_id) {
    Some(pending) => {
      @util.log_info(
        "Engine", "Pending proposal already exists for this plugin",
      )
      return AlreadyPending(pending)
    }
    None => ()
  }

  // ⑦ 冷却期
  let cooldown_ms = @util.hours_to_ms(self.config.cooldown_hours)
  let recent = self.proposals.recent_for_plugin(plugin.plugin_id, cooldown_ms)
  if recent.length() > 0 {
    @util.log_info("Engine", "Plugin in cooldown period")
    return InCooldown
  }

  // 决策与生成
  let etype = self.determine_evolution_type(filtered, plugin)
  // ★ v2.5 接线：写作领域命中写作类三型时，用 AcademicWritingEngine 对
  // 插件 SKILL.md 的分析结果丰富变更集（逐条可执行建议并入文档更新条目）；
  // 读不到 SKILL.md 或分析不出建议时保持 plan_changes 的既有默认变更，
  // 三型提案仍能产出。类型判定只由上面的决策树决定，不受引擎内部分析影响。
  let changes = enrich_writing_changes(
    plugin,
    etype,
    plan_changes(plugin, etype, filtered),
  )
  let signature = generate_signature(plugin.plugin_id, etype)

  // ⑧ 同签名重复 → 返回已存在的
  match self.proposals.find_duplicate(signature) {
    Some(dup) => {
      @util.log_info("Engine", "Duplicate proposal detected")
      return Duplicate(dup)
    }
    None => ()
  }

  // 检测信号模式
  let patterns = detect_signal_patterns(filtered)
  if patterns.length() > 0 {
    @util.log_info("Engine", "Detected signal patterns: \{patterns.length()}")
    for pattern in patterns {
      @util.log_info("Engine", "Pattern: \{pattern}")
    }
  }

  // 构造提案。created_at 只取一次时钟，
  // 于是 proposal_id 里的日期段与 created_at 必然自洽
  // （TS L130 与 L133 各调一次 `new Date()`，跨午夜时两者会落在不同日期）。
  let proposal : @types.EvolutionProposal = {
    proposal_id: "evo-\{@util.date_utc(now)}-\{signature}",
    plugin_id: plugin.plugin_id,
    status: @types.ProposalStatus::Pending,
    created_at: now,
    trigger_signals: filtered,
    evolution_type: etype,
    matt_pocock_principle: etype.principle(),
    proposed_changes: changes,
    expected_benefits: etype.expected_benefits(),
    validation_plan: plan_validation(etype, plugin),
    risk_assessment: assess_risks(changes),
    signature,
    confidence: determine_confidence(filtered),
    plan: None,
  }

  self.proposals.save(proposal)
  @util.log_info("Engine", "Generated proposal: \{proposal.proposal_id}")
  Created(proposal)
}

///|
/// 读某插件的全部信号。取代 TS L155-158。
async fn EvolutionEngine::get_signals_for_plugin(
  self : EvolutionEngine,
  plugin_id : String,
) -> Array[@types.EvolutionSignal] {
  let all : Array[@types.EvolutionSignal] = self.signals.load()
  let out : Array[@types.EvolutionSignal] = []
  for s in all {
    if s.plugin_id == plugin_id {
      out.push(s)
    }
  }
  out
}

///|
/// 按强度过滤信号。取代 TS L163-174。
///
/// · `Full`（100%）→ 收下全部信号（含 weak）
/// · `Half`（50%）→ **只收 strong**
/// · `Off`（0%）→ 空（实际走不到：`generate_proposal` 已在①短路）
///
/// `Off` 分支必须存在，否则 `match` 不穷尽 —— 这正是闭合枚举相对
/// TS 字符串联合的好处：少写一个分支会编译失败，而不是静默走 default。
pub fn filter_by_intensity(
  signals : ArrayView[@types.EvolutionSignal],
  intensity : @types.Intensity,
) -> Array[@types.EvolutionSignal] {
  match intensity {
    @types.Intensity::Full => signals.to_owned()
    @types.Intensity::Half => {
      let out : Array[@types.EvolutionSignal] = []
      for s in signals {
        if s.strength == @types.SignalStrength::Strong {
          out.push(s)
        }
      }
      out
    }
    @types.Intensity::Off => []
  }
}

///|
/// 决定进化类型。取代 TS L179-226。
///
/// **这是一条单一的 if-else 链，10 个分支的优先级顺序不可重排。**
/// 其中 7 个分支与 TS 逐行对应（loop → struggle+complexity → correction →
/// preference → workflow → performance → 默认 documentation）；剩下 3 个是
/// v2.5 M-3 新增的写作领域分支（仅对 domain 属于 Academic / TextGeneration
/// 的插件生效，不含 Mixed），插在 struggle+complexity 与通用 correction 之间。
/// 每个分支上方保留 TS 的原英文注释（新增分支除外），便于逐行 diff。
/// 分支间的跨依赖：「loop 优先于 struggle」「写作领域优先于通用
/// correction/preference/workflow」「correction 优先于 preference」
/// ——拆开写就看不出来了，而这正是重构中最容易被无意调换的地方。
async fn EvolutionEngine::determine_evolution_type(
  self : EvolutionEngine,
  signals : ArrayView[@types.EvolutionSignal],
  plugin : @types.PluginMetadata,
) -> @types.EvolutionType {
  let has_loop = has_category(signals, @types.SignalCategory::Loop)
  let has_struggle = has_category(signals, @types.SignalCategory::Struggle)
  let has_correction = has_category(signals, @types.SignalCategory::Correction)
  let has_preference = has_category(signals, @types.SignalCategory::Preference)
  let has_workflow = has_category(signals, @types.SignalCategory::Workflow)

  // Loop detected → behavior optimization
  if has_loop {
    return @types.EvolutionType::BehaviorOptimization
  }
  // High complexity + struggle → interface simplification
  if has_struggle && plugin.initial_metrics.complexity_score > 7.0 {
    return @types.EvolutionType::InterfaceSimplification
  }
  // ★ v2.5 M-3 修复：纯写作类插件（Academic / TextGeneration）优先路由
  // 到专属进化类型，避免被通用 correction/preference/workflow 分支提前抢占，
  // 导致 `plan_changes` 中对应的学术写作分支不可达。
  // loop 与 struggle+complexity 属于“行为异常”信号，无论领域都优先处理。
  //
  // ★ 不包含 Mixed：Mixed = “同时具备编程与文本能力”（types/plugin.mbt），
  //   其 correction/preference/workflow 信号可能是编程向的（如参数命名纠正），
  //   不能无条件归为写作领域。待未来能基于信号内容二次判别时再开启。
  let domain = plugin.domain
  let is_writing_domain =
    domain == @types.SkillDomain::Academic ||
      domain == @types.SkillDomain::TextGeneration
  if is_writing_domain {
    // 用户纠正写作风格 → 反 AI 痕迹
    if has_correction {
      return @types.EvolutionType::AntiAIDetection
    }
    // 用户偏好“引用风格” → 引用规范化
    if has_preference {
      return @types.EvolutionType::CitationNormalization
    }
    // 可复用的写作工作流 → 学术写作规范化
    if has_workflow {
      return @types.EvolutionType::AcademicWritingEnhancement
    }
  }
  // User correction → error handling improvement
  if has_correction {
    return @types.EvolutionType::ErrorHandlingImprovement
  }
  // User preference → documentation enhancement or interface simplification
  if has_preference {
    if plugin.initial_metrics.interface_clarity < 7.0 {
      return @types.EvolutionType::InterfaceSimplification
    }
    return @types.EvolutionType::DocumentationEnhancement
  }
  // Workflow pattern → capability extension
  if has_workflow {
    return @types.EvolutionType::CapabilityExtension
  }
  // Performance issues → performance tuning
  // 这是唯一需要读指标的分支，故本函数必须是 async
  let stats = self.monitor.get_statistics(
    plugin.plugin_id,
    time_range=@types.TimeRange::LastDay,
  )
  if stats.avg_latency_ms > 2000.0 || stats.success_rate < 0.9 {
    return @types.EvolutionType::PerformanceTuning
  }
  // Default: documentation enhancement
  @types.EvolutionType::DocumentationEnhancement
}

///|
/// 信号集里是否存在某类别。取代 TS 的 `signals.some(s => s.category === 'x')`。
fn has_category(
  signals : ArrayView[@types.EvolutionSignal],
  category : @types.SignalCategory,
) -> Bool {
  for s in signals {
    if s.category == category {
      return true
    }
  }
  false
}

///|
/// 写作类三型（AntiAIDetection / CitationNormalization /
/// AcademicWritingEnhancement）的变更丰富：读插件 SKILL.md 交给
/// AcademicWritingEngine 分析，把逐条可执行建议作为附加的文档更新条目
/// 并入变更集。
///
/// · 只在写作领域（Academic / TextGeneration）且决策树已命中写作三型时触发；
///   类型判定只属于 `determine_evolution_type`，这里不重复判型
///   （AcademicWritingEngine 自带的「指纹分 < 6.0 → AntiAIDetection」判据
///   与主引擎的信号类别路由矛盾，故只取其建议、不取其类型）。
/// · SKILL.md 缺失/不可读，或分析不出可用建议 → 原样返回默认变更，
///   保证三型提案仍能产出。
/// · 建议条目并入已存在的 UpdateDocumentation 组（写作三型的默认变更
///   通常已有一组），没有才新起一组 —— 不增加变更组数，
///   迁移成本估算不被建议条目抬高。
async fn enrich_writing_changes(
  plugin : @types.PluginMetadata,
  etype : @types.EvolutionType,
  default_changes : Array[@types.Change],
) -> Array[@types.Change] {
  let is_writing_domain =
    plugin.domain == @types.SkillDomain::Academic ||
      plugin.domain == @types.SkillDomain::TextGeneration
  if !is_writing_domain {
    return default_changes
  }
  let suggestions : Array[String] = match etype {
    @types.EvolutionType::AntiAIDetection |
    @types.EvolutionType::CitationNormalization |
    @types.EvolutionType::AcademicWritingEnhancement => {
      let content = @scanner.read_text_or_none(
        @util.path_join(plugin.path, "SKILL.md"),
      )
      match content {
        Some(text) => AcademicWritingEngine::new().suggest_for(text, etype)
        None => []
      }
    }
    _ => []
  }
  if suggestions.is_empty() {
    return default_changes
  }
  // section 沿用 planning.mbt 各类型的既有词汇，不另起新词
  let section = match etype {
    @types.EvolutionType::AntiAIDetection => "Anti-AI Detection Guidelines"
    @types.EvolutionType::AcademicWritingEnhancement =>
      "Academic Writing Guidelines"
    _ => "Citation Format Guidelines"
  }
  let items : Array[@types.DocumentationUpdate] = []
  for s in suggestions {
    items.push({
      file: "SKILL.md",
      section,
      new_content: s,
      reason: "学术写作引擎：基于 SKILL.md 分析的可执行建议",
    })
  }
  @util.log_info("Engine", "Writing suggestions merged: \{items.length()}")
  let mut merged = false
  for c in default_changes {
    match c {
      @types.Change::UpdateDocumentation(docs) =>
        if !merged {
          for item in items {
            docs.push(item)
          }
          merged = true
        }
      _ => ()
    }
  }
  if !merged {
    default_changes.push(@types.Change::UpdateDocumentation(items))
  }
  default_changes
}

///|
/// 计算信号的时间衰减因子。
/// 信号越老，衰减因子越小。默认衰减半衰期为 24 小时。
/// 衰减公式：decay_factor = 0.5 ^ (age_hours / half_life_hours)
fn calculate_decay_factor(
  signal_ts : Int64,
  current_ts : Int64,
  half_life_hours : Double,
) -> Double {
  let age_ms = current_ts - signal_ts
  let age_hours = @util.ms_to_hours(age_ms)
  let exponent = age_hours / half_life_hours
  // 精确衰减：0.5^x = exp(-x * ln(2))
  // 历史注释：曾用 1/(1+x·ln2) 近似，但 x=24 时误差 ~955 倍（0.057 vs 0.00006），
  // 导致老信号权重被严重高估。改用 @math.exp 保证数学正确性。
  let decay_factor = @math.exp(-exponent * 0.693147)
  // 限制衰减因子在 [0.01, 1.0] 范围内
  if decay_factor < 0.01 {
    0.01
  } else if decay_factor > 1.0 {
    1.0
  } else {
    decay_factor
  }
}

///|
/// 聚合信号：**逐条**计算时间衰减系数后原样透传 —— 不合并相同类别、
/// 不去重，`strength` 也保持原值（衰减只写入 `decay_factor` 字段，
/// 不影响按强度过滤与置信度判定的既有行为）。
/// `decay_factor` 当前在仓内没有消费方，供外部/后续按衰减强度加权时使用；
/// 该字段是 signals.jsonl 的一部分，不可删除。
pub fn aggregate_signals(
  signals : ArrayView[@types.EvolutionSignal],
  current_ts : Int64,
) -> Array[@types.EvolutionSignal] {
  let aggregated : Array[@types.EvolutionSignal] = []
  let half_life_hours = 24.0
  for s in signals {
    let decay_factor = calculate_decay_factor(s.ts, current_ts, half_life_hours)
    let decayed_signal : @types.EvolutionSignal = {
      strength: s.strength,
      category: s.category,
      description: s.description,
      evidence: s.evidence,
      ts: s.ts,
      plugin_id: s.plugin_id,
      count: s.count,
      tool: s.tool,
      decay_factor,
    }
    aggregated.push(decayed_signal)
  }
  aggregated
}

///|
/// 识别信号模式：检测信号中的重复模式和趋势。
/// 返回识别到的模式列表。
pub fn detect_signal_patterns(
  signals : ArrayView[@types.EvolutionSignal],
) -> Array[String] {
  let patterns : Array[String] = []
  
  // 统计各类别信号的数量
  let mut struggle_count = 0
  let mut loop_count = 0
  let mut correction_count = 0
  let mut preference_count = 0
  let mut workflow_count = 0
  let mut pattern_count = 0
  
  for s in signals {
    match s.category {
      @types.SignalCategory::Struggle => struggle_count += 1
      @types.SignalCategory::Loop => loop_count += 1
      @types.SignalCategory::Correction => correction_count += 1
      @types.SignalCategory::Preference => preference_count += 1
      @types.SignalCategory::Workflow => workflow_count += 1
      @types.SignalCategory::Pattern => pattern_count += 1
    }
  }
  
  // 检测高频类别
  if struggle_count >= 3 {
    patterns.push("High frequency struggle signals detected (\{struggle_count} occurrences)")
  }
  if loop_count >= 3 {
    patterns.push("High frequency loop signals detected (\{loop_count} occurrences)")
  }
  if correction_count >= 3 {
    patterns.push("High frequency correction signals detected (\{correction_count} occurrences)")
  }
  if preference_count >= 3 {
    patterns.push("High frequency preference signals detected (\{preference_count} occurrences)")
  }
  if workflow_count >= 3 {
    patterns.push("High frequency workflow signals detected (\{workflow_count} occurrences)")
  }
  if pattern_count >= 3 {
    patterns.push("High frequency pattern signals detected (\{pattern_count} occurrences)")
  }
  
  // 检测时间集中模式（使用 Map 优化，从 O(n²) 降到 O(n)）
  let window_size_ms = 3600000L // 1 小时
  let time_windows : Map[Int64, Int] = Map([])
  for s in signals {
    let window_start = s.ts / window_size_ms * window_size_ms
    let count = time_windows.get(window_start).unwrap_or(0)
    time_windows.set(window_start, count + 1)
  }
  
  // 检测时间窗口内的信号集中
  for entry in time_windows {
    let (window_start, count) = entry
    if count >= 5 {
      patterns.push("Signal burst detected at \{@util.date_utc(window_start)} (\{count} signals in 1 hour)")
    }
  }
  
  patterns
}
