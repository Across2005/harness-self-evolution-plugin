///|
/// 提案变更的生成。取代 legacy-ts/src/engine/index.ts L262-447 ——
/// 即 `generateProposedChanges` 与它调用的 6 个 `propose*` 私有方法。
///
/// **一次穷尽 match 取代 6 个各返回字面量数组的小方法。**
/// TS 版把它们写成 6 个 `private async` 方法（L303, 339, 351, 370, 381, 415, 433），
/// 其中 `proposeParamSimplification`（L339-346）与 `proposeFlowOptimization`
/// （L370-376）**恒返回 `[]`**，是纯占位；`proposeToolMerges`（L303-334）
/// 则在 L309 调了一次 `monitor.getStatistics(pluginId, 'last_week')`
/// 而**从未使用其结果**（L311-333 只用了 `pluginMetadata.tools`）——
/// 那是一次纯亏损的「全量落盘 + 全量读盘」（P18）。
///
/// 于是本文件是**同步纯函数**：删掉那次死调用后，整条链路不再需要 await。
/// TS 版的 `async` 只是为了容纳那次无用的 I/O。
///
/// **占位方法的处置**：`proposeParamSimplification` 与 `proposeFlowOptimization`
/// 被删除而不是保留为空壳 —— 保留一个恒返回空的函数只会让读者以为
/// 「这里有逻辑但没触发」。它们对应的位置在下面用注释标出，
/// 将来真要实现时，`Change::SimplifyParams` / `Change::OptimizeFlow`
/// 两个变体已经就位，编译器会强制所有消费点同步更新。

///|
/// 按进化类型生成变更集。取代 TS L262-298 的 switch。
///
/// **空结果不产出变更条目**：这与 TS 有一处有意的表现差异 ——
/// TS 会写 `changes.merge_tools = []`（键存在但为空），新版直接不产出该条目。
/// 两者在 `estimateMigrationEffort`（TS L615 只数非空组）与
/// `has_breaking_changes` / `is_backward_compatible`（TS 的 `?.some` / `?.every`）
/// 上行为一致，而 JSONL 里少一堆空数组更易读。
pub fn plan_changes(
  plugin : @types.PluginMetadata,
  etype : @types.EvolutionType,
  signals : ArrayView[@types.EvolutionSignal],
) -> Array[@types.Change] {
  // 每个分支写成 `if xs.is_empty() { [] } else { [Ctor(xs)] }` 而不是抽一个
  // 公共 helper：MoonBit **禁止把构造器当高阶函数传递**
  // （工具链报 "Using constructors as higher order function directly is forbidden"）。
  // 六个分支的重复因此是语言层面的必然，不是设计缺陷。
  match etype {
    @types.EvolutionType::InterfaceSimplification => {
      let merges = plan_merges(plugin)
      let simplifications = plan_param_simplification(plugin)
      let changes : Array[@types.Change] = []
      if !merges.is_empty() {
        changes.push(@types.Change::MergeTools(merges))
      }
      if !simplifications.is_empty() {
        changes.push(@types.Change::SimplifyParams(simplifications))
      }
      changes
    }
    @types.EvolutionType::BehaviorOptimization => {
      let middlewares = plan_middleware(signals)
      if middlewares.is_empty() {
        []
      } else {
        [@types.Change::AddMiddleware(middlewares)]
      }
    }
    @types.EvolutionType::PerformanceTuning => {
      let flows = plan_flow_optimization(signals)
      if flows.is_empty() {
        []
      } else {
        [@types.Change::OptimizeFlow(flows)]
      }
    }
    @types.EvolutionType::DocumentationEnhancement => {
      let docs = plan_docs(plugin, signals)
      if docs.is_empty() {
        []
      } else {
        [@types.Change::UpdateDocumentation(docs)]
      }
    }
    @types.EvolutionType::CapabilityExtension => {
      let caps = plan_capability(signals)
      if caps.is_empty() {
        []
      } else {
        [@types.Change::AddCapability(caps)]
      }
    }
    @types.EvolutionType::ErrorHandlingImprovement => {
      let handling = plan_error_handling(signals)
      if handling.is_empty() {
        []
      } else {
        [@types.Change::ImproveErrorHandling(handling)]
      }
    }
    @types.EvolutionType::SecurityHardening => {
      let middlewares = plan_security_middleware(signals)
      let handling = plan_security_error_handling(signals)
      let changes : Array[@types.Change] = []
      if !middlewares.is_empty() {
        changes.push(@types.Change::AddMiddleware(middlewares))
      }
      if !handling.is_empty() {
        changes.push(@types.Change::ImproveErrorHandling(handling))
      }
      changes
    }
    @types.EvolutionType::AccessibilityImprovement => {
      let docs = plan_accessibility_docs(plugin, signals)
      let caps = plan_accessibility_capability(signals)
      let changes : Array[@types.Change] = []
      if !docs.is_empty() {
        changes.push(@types.Change::UpdateDocumentation(docs))
      }
      if !caps.is_empty() {
        changes.push(@types.Change::AddCapability(caps))
      }
      changes
    }
  }
}

///|
/// 找出第一个属于该类别的信号。取代 TS 里散落的
/// `signals.find(s => s.category === 'x')`（L352, 416, 434）。
fn find_signal(
  signals : ArrayView[@types.EvolutionSignal],
  category : @types.SignalCategory,
) -> @types.EvolutionSignal? {
  for s in signals {
    if s.category == category {
      return Some(s)
    }
  }
  None
}

///|
/// 工具合并启发式。取代 TS L303-334。
///
/// 这是 TS 原样的硬编码示例逻辑：只有当插件同时具备
/// `navigate` / `click` / `type` 三个工具时，才提议合并为 `smart_fill`。
/// 注释里 TS 自己写了 "This is a simplified heuristic - in production,
/// use more sophisticated pattern mining"（L311-312）—— 原样保留，
/// 因为「换成真正的模式挖掘」是功能增强，不是语言移植。
fn plan_merges(plugin : @types.PluginMetadata) -> Array[@types.ToolMerge] {
  let tools = plugin.tools
  if tools.length() < 3 {
    return []
  }
  if tools.contains("navigate") &&
    tools.contains("click") &&
    tools.contains("type") {
    return [
      {
        new_tool: "smart_fill",
        merged_from: ["navigate", "click", "type"],
        new_interface: {
          params: ["url", "selector", "text"],
          description: "一站式表单填充：导航 + 定位 + 输入",
          defaults: Some(Json::empty_object()),
        },
        backward_compatible: true,
      },
    ]
  }
  []
}

///|
/// 参数简化启发式。实现原 TODO(param-simplification)。
///
/// TS 的 `proposeParamSimplification` 恒返回 []，属未实现的占位。
/// 新版基于工具命名模式生成简化建议：
/// · 名称含 `config` / `settings` / `options` 的工具通常参数较多，
///   建议收敛为结构化参数对象
/// · 名称含 `advanced` / `detailed` 的工具建议提供合理默认值
///
/// 注意：`PluginMetadata.tools` 只有工具名，没有参数详情，
/// 故此处的启发式是保守的「建议」而非确定性的「必须」。
fn plan_param_simplification(
  plugin : @types.PluginMetadata,
) -> Array[@types.ParamSimplification] {
  let result : Array[@types.ParamSimplification] = []
  let complex_patterns = ["config", "settings", "options", "advanced", "detailed"]
  for tool in plugin.tools {
    let lower = tool.to_lower()
    for pattern in complex_patterns {
      if lower.contains(pattern) {
        result.push({
          tool,
          remove_params: [],
          defaults: Json::empty_object(),
          reason: "工具名含 '\{pattern}'，通常参数较多，建议提供合理默认值简化调用",
        })
        break
      }
    }
  }
  result
}

///|
/// 循环干预中间件。取代 TS L351-365。
///
/// ★ **这里删掉了一处正则反解**：TS 在 monitor L244 用模板串拼出
/// `` `Tool ${toolName} called ${loopCount} times in loop` ``，
/// 再在 engine L357 用 `/Tool (\w+) called/` 把工具名**反解**回来。
/// 同一事实被编码与解码各一次，且正则一旦与模板串漂移就会静默失效
/// （届时 `target_tool` 会变成 `'unknown'` 而没有任何报错）。
/// 新版直接读 `EvolutionSignal.tool` 这个结构化字段。
fn plan_middleware(
  signals : ArrayView[@types.EvolutionSignal],
) -> Array[@types.MiddlewareAddition] {
  match find_signal(signals, @types.SignalCategory::Loop) {
    None => []
    Some(signal) => {
      let tool = signal.tool.unwrap_or("unknown")
      [
        {
          name: "loop_detection",
          target_tool: Some(tool),
          target_event: None,
          threshold: Some(5),
          intervention: "检测到循环，建议使用批量操作或调整参数",
          priority: 10,
        },
      ]
    }
  }
}

///|
/// 文档更新建议。取代 TS L381-410。
///
/// 两个来源，顺序与 TS 一致（先按文档质量评分，再按 workflow 信号逐条）：
/// 1. `documentation_quality < 7` → 建议补充使用示例
/// 2. 每条 `workflow` 信号 → 建议把该工作流写进文档
fn plan_docs(
  plugin : @types.PluginMetadata,
  signals : ArrayView[@types.EvolutionSignal],
) -> Array[@types.DocumentationUpdate] {
  let updates : Array[@types.DocumentationUpdate] = []
  if plugin.initial_metrics.documentation_quality < 7.0 {
    updates.push({
      file: "SKILL.md",
      section: "Usage Examples",
      new_content: "添加具体使用示例和常见场景说明",
      reason: "文档质量评分较低，需要增强实用性",
    })
  }
  for signal in signals {
    if signal.category == @types.SignalCategory::Workflow {
      updates.push({
        file: "SKILL.md",
        section: "Workflow",
        new_content: "记录可复用工作流：\{signal.description}",
        reason: "用户形成了可复用的工作流模式",
      })
    }
  }
  updates
}

///|
/// 能力扩展建议。取代 TS L415-428。
fn plan_capability(
  signals : ArrayView[@types.EvolutionSignal],
) -> Array[@types.CapabilityAddition] {
  match find_signal(signals, @types.SignalCategory::Workflow) {
    None => []
    Some(signal) =>
      [
        {
          capability_name: "custom_workflow",
          description: signal.description,
          implementation: "基于用户工作流模式自动生成",
          dependencies: [],
        },
      ]
  }
}

///|
/// 错误处理改进建议。取代 TS L433-447。
/// 四个字段的文案逐字保留 —— 其中 `user_message` 是直接给用户看的。
fn plan_error_handling(
  signals : ArrayView[@types.EvolutionSignal],
) -> Array[@types.ErrorHandlingImprovement] {
  match find_signal(signals, @types.SignalCategory::Correction) {
    None => []
    Some(_) =>
      [
        {
          error_type: "user_correction",
          current_behavior: "未捕获用户纠正",
          improved_behavior: "记录用户纠正并调整行为",
          user_message: "已记录您的偏好，下次将按此执行",
          recovery_strategy: "应用用户纠正并更新规则",
        },
      ]
  }
}

///|
/// 生成验证计划。取代 TS L501-545（`createValidationPlan` + `generateTestScenarios`）。
///
/// `success_criteria` 与 `rollback_strategy` 两句文案逐字保留，
/// 它们会出现在提案文档里给用户看。
pub fn plan_validation(
  etype : @types.EvolutionType,
  plugin : @types.PluginMetadata,
) -> @types.ValidationPlan {
  let scenarios : Array[String] = []
  // TS L527-529：取前 3 个能力，各生成一条场景
  let caps = plugin.capabilities
  let limit = if caps.length() < 3 { caps.length() } else { 3 }
  for i in 0..<limit {
    scenarios.push("测试 \{caps[i]} 功能")
  }
  // TS L531-542 的按类型追加，已收敛为 EvolutionType 上的方法（见 types/proposal.mbt）
  for extra in etype.extra_scenarios() {
    scenarios.push(extra)
  }
  {
    test_scenarios: scenarios,
    success_criteria: "成功率 >= 95%，延迟 < 2s，无回归问题",
    rollback_strategy: "保留原版本 30 天，支持一键回滚",
    validation_levels: [
      {
        level: @types.ValidationLevelTag::T0,
        description: "语法验证：代码可编译/解析",
        automated: true,
        timeout_ms: Some(30000),
      },
      {
        level: @types.ValidationLevelTag::T1,
        description: "功能验证：新功能正常工作",
        automated: true,
        timeout_ms: Some(60000),
      },
      {
        level: @types.ValidationLevelTag::T2,
        description: "回归验证：不影响现有功能",
        automated: true,
        timeout_ms: Some(120000),
      },
    ],
  }
}

// ============================================================================
// 以下为 C1/C2/C3 新增的辅助函数
// ============================================================================

///|
/// 流程优化建议。基于 Loop 信号生成 OptimizeFlow 变更。
/// Loop 信号表明某个工具被反复调用，可以通过缓存或批处理优化。
fn plan_flow_optimization(
  signals : ArrayView[@types.EvolutionSignal],
) -> Array[@types.FlowOptimization] {
  match find_signal(signals, @types.SignalCategory::Loop) {
    None => []
    Some(signal) => {
      let tool = signal.tool.unwrap_or("unknown")
      [
        {
          tool,
          optimization: @types.OptimizationKind::Batching,
          implementation: "检测到循环调用，建议使用批量操作替代重复单次调用",
          expected_improvement: "减少 \{signal.count.unwrap_or(0)} 次独立调用为单次批量操作",
        },
      ]
    }
  }
}

///|
/// 安全加固中间件建议。基于 Correction 和 Struggle 信号生成安全相关中间件。
fn plan_security_middleware(
  signals : ArrayView[@types.EvolutionSignal],
) -> Array[@types.MiddlewareAddition] {
  let result : Array[@types.MiddlewareAddition] = []
  // 输入验证中间件：当有 Correction 信号时建议添加
  if find_signal(signals, @types.SignalCategory::Correction) is Some(_) {
    result.push({
      name: "input_validation",
      target_tool: None,
      target_event: None,
      threshold: None,
      intervention: "添加输入验证和参数校验，防止无效或恶意输入",
      priority: 8,
    })
  }
  // 速率限制中间件：当有 Struggle 信号时建议添加
  if find_signal(signals, @types.SignalCategory::Struggle) is Some(_) {
    result.push({
      name: "rate_limiting",
      target_tool: None,
      target_event: None,
      threshold: Some(10),
      intervention: "添加速率限制，防止过度调用导致资源耗尽",
      priority: 9,
    })
  }
  result
}

///|
/// 安全加固错误处理建议。
fn plan_security_error_handling(
  signals : ArrayView[@types.EvolutionSignal],
) -> Array[@types.ErrorHandlingImprovement] {
  match find_signal(signals, @types.SignalCategory::Correction) {
    None => []
    Some(_) =>
      [
        {
          error_type: "security_input_validation",
          current_behavior: "未对用户输入进行安全校验",
          improved_behavior: "对所有用户输入进行转义和校验，防止注入攻击",
          user_message: "输入包含不安全字符，已自动过滤",
          recovery_strategy: "应用输入验证规则并记录安全事件",
        },
      ]
  }
}

///|
/// 可访问性文档建议。
fn plan_accessibility_docs(
  plugin : @types.PluginMetadata,
  signals : ArrayView[@types.EvolutionSignal],
) -> Array[@types.DocumentationUpdate] {
  let updates : Array[@types.DocumentationUpdate] = []
  // 为所有插件添加可访问性文档建议
  if plugin.initial_metrics.documentation_quality < 8.0 {
    updates.push({
      file: "SKILL.md",
      section: "Accessibility",
      new_content: "添加可访问性指南，包括键盘导航、屏幕阅读器支持和高对比度模式说明",
      reason: "提升插件的可访问性，确保更多用户能够使用",
    })
  }
  // 如果有 workflow 信号，添加工作流可访问性文档
  for signal in signals {
    if signal.category == @types.SignalCategory::Workflow {
      updates.push({
        file: "SKILL.md",
        section: "Accessible Workflows",
        new_content: "记录可访问的工作流模式：\{signal.description}",
        reason: "确保用户工作流对所有用户都可访问",
      })
    }
  }
  updates
}

///|
/// 可访问性能力扩展建议。
fn plan_accessibility_capability(
  signals : ArrayView[@types.EvolutionSignal],
) -> Array[@types.CapabilityAddition] {
  match find_signal(signals, @types.SignalCategory::Workflow) {
    None => []
    Some(signal) =>
      [
        {
          capability_name: "accessible_interaction",
          description: "可访问的交互模式：\{signal.description}",
          implementation: "添加键盘快捷键、ARIA 标签和屏幕阅读器支持",
          dependencies: [],
        },
      ]
  }
}
