///|
/// Sub-Agent 执行与三级验证的**可注入实现**。
/// 取代 legacy-ts/src/executor/index.ts L228-404。
///
/// **为什么用函数值而不是 trait 或布尔开关**：
/// TS 版把 `dry_run` 写成散落在三处的 `if`（L234-243、L336-344，
/// 以及 `runValidation` 的透传），于是「模拟执行」与「试运行」两条路径
/// 与主流程缠在一起，想加第三种（例如接真实 LLM）就得再插一批 `if`。
/// 新版把「怎么跑一个任务」与「怎么验一级」抽成两个**函数字段**，
/// `dry_run` 从三处分支收敛为「构造时选哪一对实现」，
/// 而测试可以直接注入一个必定失败的实现。
///
/// **这条注入缝救回了一个测试。**
/// legacy-ts/tests/executor.test.ts L121-142 要覆盖「任务失败 → 回滚 → 回 pending」，
/// 但非 dry-run 路径的模拟 Sub-Agent 恒成功，于是它只能靠
/// `{ level: 'T9' as any }` 这个**类型系统外的伪造值**去触发
/// executor L386-393 的 "Unknown validation level" 分支。
/// 而 `ValidationLevelTag` 闭合后 `'T9'` 根本不可构造。
/// 有了注入缝，测试改为传入 `failing_validation` —— 覆盖的是
/// 「验证失败」这一**真实语义**，而不是「等级名拼错」这一实现巧合。
///
/// **将来接真实 Sub-Agent 的扩展点**（不改动 `execute` 主体一行）：
/// · 进程型：`@process.collect_output` 调本地 CLI Agent，不引入新的 C stub
/// · LLM 型：`@http.post` + `@async.retry(ExponentialDelay(...))` + `Semaphore` 限流；
///   届时才需要在 moon.pkg 里加 `moonbitlang/async/http`
///   （它会拉入 tls/socket 的 native stub，故按需再加）

///|
/// 模拟执行一个 Sub-Agent 任务。对应 TS L274-290 的 `simulateSubAgent`。
///
/// 保留 TS 的 100 ms 模拟耗时：它让 `duration_ms` 有一个非零的、
/// 与真实执行同量级的值，也让日志里的时序看起来合理。
pub async fn simulated_task(task : @types.SubAgentTask) -> Json {
  @async.sleep(100)
  {
    "simulated": true,
    "task": Json::string(task.task),
    "input": task.input,
    "message": "Sub-agent execution simulated",
  }
}

///|
/// 试运行：立即返回，不做任何工作。对应 TS L234-243。
///
/// `async` 标注是**必需但无用**的：它必须与可注入的函数类型
/// `async (SubAgentTask) -> Json` 一致（因为 `simulated_task` 真的会 await），
/// 但自身函数体里没有任何 await 点 —— 这正是「立即返回」的意思。
/// 故局部关掉 unused_async 而不是插入一个假的 `sleep(0)`。
#warnings("-unused_async")
pub async fn dry_run_task(task : @types.SubAgentTask) -> Json {
  { "dry_run": true, "task": Json::string(task.task) }
}

///|
/// 模拟三级验证。把 TS L346-384 那 **75 行三段近似重复**的
/// `if (level === 'T0') {...} if (level === 'T1') {...} if (level === 'T2') {...}`
/// 压成一次穷尽 match —— 各级的耗时与文案差异一目了然。
///
/// 返回 `(是否通过, 输出消息)`。
pub async fn simulated_validation(
  level : @types.ValidationLevelTag,
  _proposal : @types.EvolutionProposal,
) -> (Bool, String) {
  let (delay_ms, message) = match level {
    @types.ValidationLevelTag::T0 => (50, "Syntax validation passed")
    @types.ValidationLevelTag::T1 => (100, "Functionality validation passed")
    @types.ValidationLevelTag::T2 => (150, "Regression validation passed")
  }
  @async.sleep(delay_ms)
  (true, message)
}

///|
/// 试运行的验证：立即通过。对应 TS L336-344。
/// `async` 同 `dry_run_task`：为匹配可注入的函数类型而声明，自身无 await 点。
#warnings("-unused_async")
pub async fn dry_run_validation(
  level : @types.ValidationLevelTag,
  _proposal : @types.EvolutionProposal,
) -> (Bool, String) {
  (true, "dry run: \{level.wire_name()} skipped")
}

///|
/// **必定失败**的验证。仅用于测试覆盖「验证失败 → 回滚 → 回 pending」这条路径。
///
/// 它取代了 legacy 测试里那个 `{ level: 'T9' as any }` 的伪造值 ——
/// 闭合枚举下 `T9` 不可构造，而这条路径又必须被测到。
#warnings("-unused_async")
pub async fn failing_validation(
  level : @types.ValidationLevelTag,
  _proposal : @types.EvolutionProposal,
) -> (Bool, String) {
  (false, "injected failure at \{level.wire_name()}")
}

///|
/// **必定失败**的任务执行器。用于覆盖「任务失败 → 回滚」这条路径
/// （TS 的模拟 Sub-Agent 恒成功，这条分支在 legacy 测试里根本测不到）。
#warnings("-unused_async")
pub async fn failing_task(task : @types.SubAgentTask) -> Json {
  ignore(task)
  raise Failure("injected sub-agent failure")
}

///|
/// 会**超时**的任务执行器。用于验证 `timeout_ms` 真的被强制执行 ——
/// TS 版声明了 `timeout_ms`（L147, 156, 165, 174, 183, 194, 204, 218）
/// 却从未执行过它，属纯装饰字段。
pub async fn hanging_task(task : @types.SubAgentTask) -> Json {
  ignore(task)
  // 睡得比任何合理的 timeout_ms 都久；with_timeout_opt 会真正取消它
  @async.sleep(60_000)
  { "never": "reached" }
}
