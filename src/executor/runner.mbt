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
/// 保留 TS 的 100 ms 模拟耗时：它让 `duration_ms` 有一个非零值，
/// 也让日志里的时序看起来合理。⚠️ 但这**不是**与真实执行同量级 ——
/// 参照实现（defending-code-reference-harness）里每个任务是 CLI 子进程 +
/// 沙箱 + 流式回传，耗时是秒到分钟级（见 docs/subagent-factory.md §1.2）。
/// 100 ms 只是「模拟的代价」，不是「真实任务的预算」。
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

///|
/// 真实进程执行器（环境变量驱动，M7）。
///
/// **安全闸门**：当前生产装配仍使用这个兼容入口，但真实子进程没有被
/// transactional adapter 包住。子进程可以绕过 `sandbox_atomic_write`，
/// 因此 `PreCheckResult.modified_paths` 不会记录新文件、删除或任意写入。
/// 在可信 mutation manifest / 临时 worktree 适配器落地前，设置
/// `HARNESS_EVOLUTION_AGENT_CMD` 会明确失败，而不是把不可回滚的执行伪装成
/// 「已回滚」。未设置时仍走模拟实现，旧测试与默认行为不变。
///
/// `HARNESS_EVOLUTION_WORKDIR` 仍被 real_validation 使用；它不代表任务 runner
/// 已获得写入边界或回滚能力。
///
/// MoonBit async **不用 `await` 关键字**：async 函数直接调用（见 server.mbt）。
pub async fn process_task(task : @types.SubAgentTask) -> Json {
  match @env.get_env_var("HARNESS_EVOLUTION_AGENT_CMD") {
    Some(cmd) if cmd.trim() != "" =>
      raise Failure(
        "real sub-agent execution is disabled: HARNESS_EVOLUTION_AGENT_CMD requires a transactional sandbox adapter",
      )
    _ => simulated_task(task)
  }
}

///|
/// 失败细节截断：stderr 优先、回退 stdout，上限 400 字符。
fn clip_fail(err_text : String, out_text : String) -> String {
  let detail = if err_text.trim() != "" { err_text } else { out_text }
  if detail.length() > 400 {
    detail[:400].to_owned()
  } else {
    detail
  }
}

///|
/// Choose a T2 result without evaluating the fallback on the success path.
/// Kept as a small test seam because the production fallback is a process
/// launch, not a value that can be inspected after eager evaluation.
async fn choose_t2_result(
  primary : Result[(Int, String, String), String],
  fallback : async () -> Result[(Int, String, String), String],
) -> (Result[(Int, String, String), String], Bool) {
  match primary {
    Ok(t) if t.0 == 0 => (Ok(t), false)
    _ => (fallback(), true)
  }
}

///|
/// 真实三级验证（环境变量驱动，M7）。
///
/// **开关**：`HARNESS_EVOLUTION_REAL_VALIDATION=true` 才走真命令；
/// 否则回退 `simulated_validation`（既有语义）。
///
/// | 级 | 命令（cwd = `HARNESS_EVOLUTION_WORKDIR` 或继承） |
/// |----|--------------------------------------------------|
/// | T0 | `moon check --deny-warn` |
/// | T1 | `moon test` |
/// | T2 | `pwsh -File build.ps1 -Task all`（失败再试 `powershell`） |
///
/// 非 0 退出 → `(false, "Tn failed …")`；0 → `(true, "Tn passed …")`。
/// **绝不**在开关打开时返回模拟通过（宁可失败不可假绿）。
pub async fn real_validation(
  level : @types.ValidationLevelTag,
  _proposal : @types.EvolutionProposal,
) -> (Bool, String) {
  let use_real = match @env.get_env_var("HARNESS_EVOLUTION_REAL_VALIDATION") {
    Some(val) => val == "true"
    None => false
  }
  if !use_real {
    return simulated_validation(level, _proposal)
  }

  let cwd = match @env.get_env_var("HARNESS_EVOLUTION_WORKDIR") {
    Some(w) if w.trim() != "" => Some(w)
    _ => None
  }
  let tag = level.wire_name()
  let (program, args) = match level {
    @types.ValidationLevelTag::T0 => ("moon", ["check", "--deny-warn"])
    @types.ValidationLevelTag::T1 => ("moon", ["test"])
    @types.ValidationLevelTag::T2 =>
      ("pwsh", ["-File", "build.ps1", "-Task", "all"])
  }
  let initial_used = "\{program} \{args.join(" ")}"
  // spawn 失败（假 cwd / 找不到程序）会 raise —— 收口成验证失败，不逃逸。
  let collect0 : Result[(Int, String, String), String] = Ok(
    {
      let t = match cwd {
        Some(w) =>
          @process.collect_output(
            program,
            args,
            cwd=w,
            no_console_window=true,
          )
        None =>
          @process.collect_output(
            program,
            args,
            no_console_window=true,
          )
      }
      (t.0, t.1.text(), t.2.text())
    },
  ) catch {
    e => Err(e.to_string())
  }
  let (ran, used) = match level {
    @types.ValidationLevelTag::T2 => {
      // Windows 常无 pwsh；命令缺失与任意非 0 都必须再试 powershell。
      // The fallback is a thunk so a successful pwsh never launches powershell.
      let fallback_args = ["-NoProfile", "-File", "build.ps1", "-Task", "all"]
      let (result, used_fallback) = choose_t2_result(
        collect0,
        async fn() {
          let collect_fb : Result[(Int, String, String), String] = Ok(
            {
              let t = match cwd {
                Some(w) =>
                  @process.collect_output(
                    "powershell",
                    fallback_args,
                    cwd=w,
                    no_console_window=true,
                  )
                None =>
                  @process.collect_output(
                    "powershell",
                    fallback_args,
                    no_console_window=true,
                  )
              }
              (t.0, t.1.text(), t.2.text())
            },
          ) catch {
            e => Err(e.to_string())
          }
          collect_fb
        },
      )
      if used_fallback {
        (result, "powershell \{fallback_args.join(" ")}")
      } else {
        (result, initial_used)
      }
    }
    _ => (collect0, initial_used)
  }
  let ran = match ran {
    Ok(t) => t
    Err(msg) => return (false, "\{tag} failed via \{used}: \{msg}")
  }
  let (exit_code, out_text, err_text) = ran
  if exit_code == 0 {
    (true, "\{tag} passed: \{used}")
  } else {
    (
      false,
      "\{tag} failed (exit \{exit_code}) via \{used}: \{clip_fail(err_text, out_text)}",
    )
  }
}
