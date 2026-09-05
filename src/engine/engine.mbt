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
/// 2. 决策树是一条**单一的 if-else 链**，7 个分支的优先级顺序与 TS L184-225
///    逐行对应，每个分支上方保留 TS 的原英文注释。刻意不拆成多个 `match`：
///    拆开之后就看不出「loop 优先于 struggle」这类跨分支的优先级关系，
///    而这正是最容易在重构中被无意调换的东西。

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
/// 用 `DataPaths` 构造（生产路径）。
pub fn EvolutionEngine::at(
  paths : @store.DataPaths,
  monitor : @monitor.PerformanceMonitor,
  config~ : @types.EngineConfig = @types.EngineConfig::default(),
) -> EvolutionEngine {
  EvolutionEngine::new(
    monitor,
    @store.ProposalStore::at(paths),
    @store.Jsonl::new(paths.signals()),
    config,
  )
}

///|
/// 生成进化提案。取代 TS L54-150。
///
/// 7 道闸门的顺序与 TS **逐一对应**，不得重排：
/// ① 强度为 0% → 短路（L60-63）
/// ② 取信号（未提供则从 signals.jsonl 读该插件的）（L66-68）
/// ③ 按强度过滤（L71）
/// ④ 过滤后为空 → NoSignals（L74-77）
/// ⑤ 已有 pending → **返回该 pending**（L80-84）
/// ⑥ 冷却期命中 → InCooldown（L87-92）
/// ⑦ 同签名重复 → **返回已存在的**（L120-126）
/// 全过之后才构造提案并落盘（L129-149）。
///
/// 注意 ⑤ 与 ⑦ 返回的是**已存在的提案**而不是 null —— 这是 TS 的既有语义，
/// 也是最容易在移植时被「顺手统一成 null」而破坏的一处。
/// `signals` 是 `Option` 而不是「空数组表示未提供」：TS 区分
/// `undefined`（从 signals.jsonl 读）与 `[]`（明确告知没有信号），
/// 而 legacy engine.test.ts L217-220 恰好靠传 `[]` 来验证 NoSignals 分支。
/// 用空数组当哨兵会把这两种语义合并，那条用例就测不出来了。
pub async fn EvolutionEngine::generate_proposal(
  self : EvolutionEngine,
  plugin : @types.PluginMetadata,
  signals~ : Array[@types.EvolutionSignal]? = None,
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

  // ③ 按强度过滤
  let filtered = filter_by_intensity(raw_signals, self.config.intensity)

  // ④ 过滤后为空
  if filtered.length() == 0 {
    @util.log_info("Engine", "No signals to trigger evolution")
    return NoSignals
  }

  // ⑤ 已有 pending → 返回它
  match self.proposals.find_pending_for_plugin(plugin.plugin_id) {
    Some(pending) => {
      @util.log_info(
        "Engine",
        "Pending proposal already exists for this plugin",
      )
      return AlreadyPending(pending)
    }
    None => ()
  }

  // ⑥ 冷却期
  let cooldown_ms = @util.hours_to_ms(self.config.cooldown_hours)
  let recent = self.proposals.recent_for_plugin(plugin.plugin_id, cooldown_ms)
  if recent.length() > 0 {
    @util.log_info("Engine", "Plugin in cooldown period")
    return InCooldown
  }

  // 决策与生成
  let etype = self.determine_evolution_type(filtered, plugin)
  let changes = plan_changes(plugin, etype, filtered)
  let signature = generate_signature(plugin.plugin_id, etype)

  // ⑦ 同签名重复 → 返回已存在的
  match self.proposals.find_duplicate(signature) {
    Some(dup) => {
      @util.log_info("Engine", "Duplicate proposal detected")
      return Duplicate(dup)
    }
    None => ()
  }

  // 构造提案。created_at 只取一次时钟，
  // 于是 proposal_id 里的日期段与 created_at 必然自洽
  // （TS L130 与 L133 各调一次 `new Date()`，跨午夜时两者会落在不同日期）。
  let now = @util.now_ms()
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
/// **这是一条单一的 if-else 链，7 个分支的优先级顺序不可重排。**
/// 每个分支上方保留 TS 的原英文注释，便于逐行 diff。
/// 唯一分支间的依赖是「loop 优先于 struggle」「correction 优先于 preference」
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
