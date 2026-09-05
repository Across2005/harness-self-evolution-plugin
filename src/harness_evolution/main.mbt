///|
/// 可执行入口。取代 legacy-ts/src/mcp/server.ts L312-336 的 `main()`
/// 与其 SIGINT/SIGTERM 处理。
///
/// 启动序列：
/// 1. 定位数据目录（`$HARNESS_EVOLUTION_HOME` 或 `~/.harness-evolution/v2`）
/// 2. 若发现 v1 遗留目录 → stderr 提示一行（只提示、不迁移，见 store/paths.mbt）
/// 3. 读取 `.zcode-plugin/plugin.json` 的 `evolution_config`（修配置孤岛）
/// 4. 装配 `ServerState`（ProposalStore 只构造一次，三方共享）
/// 5. 在一个 task group 里同时跑「周期性 flush」与「stdio 服务循环」
/// 6. stdin EOF → group 退出 → `add_defer` 做最后一次 flush → 幂等 shutdown
///
/// **不再需要手写的信号处理器**：legacy 的 `process.on('SIGINT'/'SIGTERM')`
/// （server.ts L324-332）由 `moonbitlang/async` 的结构化并发接管 ——
/// 默认的全局取消信号已覆盖 Windows 上有意义的 CTRL_C / CTRL_CLOSE / CTRL_BREAK，
/// 取消发生时 task group 会等所有子任务结束再退出，不会留下僵尸后台任务。
/// 详见 mcp/server.mbt 里关于「为什么不显式调 set_global_cancellation_signals」的说明。

///|
/// 读取 `evolution_config`。查找顺序：
/// 1. `$HARNESS_EVOLUTION_CONFIG`（显式覆盖，测试与多档案场景用）
/// 2. `<cwd>/.zcode-plugin/plugin.json`
/// 3. `.zcode-plugin/plugin.json`（相对路径兜底）
///
/// 都找不到就用默认配置 —— 配置缺失绝不能让插件启动失败。
///
/// **这一步修掉了 legacy 的一处配置孤岛**：`.zcode-plugin/plugin.json` L48-66
/// 写了完整的 `evolution_config`（含 `signal_thresholds`），
/// 但 legacy 的 `src/**` 里没有任何代码读它，改配置等于空操作。
async fn load_config() -> @types.EngineConfig {
  let candidates : Array[String] = []
  match @env.get_env_var("HARNESS_EVOLUTION_CONFIG") {
    Some(p) if p.length() > 0 => candidates.push(@util.expand_home(p))
    _ => ()
  }
  match @env.current_dir() {
    Some(cwd) =>
      candidates.push(@util.path_join(cwd, ".zcode-plugin/plugin.json"))
    None => ()
  }
  candidates.push(".zcode-plugin/plugin.json")

  for path in candidates {
    match @store.read_json(path) {
      Some(json) => {
        @util.log_info(
          "HarnessEvolution",
          "Loaded evolution_config from \{path}",
        )
        let (cfg, warns) = @types.EngineConfig::from_json_checked(json)
        // 越界取值会**回落默认值**，但必须让人看见：配置孤岛是 2.0 才接通的，
        // 退化值（`consecutive_failures: 0` 等）过去会被静默兜底，
        // 引擎会拿着被改写的阈值产出的垃圾信号去改真实插件。
        for w in warns {
          @util.log_warn(
            "HarnessEvolution",
            "Invalid evolution_config value, fell back to default: \{w}",
          )
        }
        return cfg
      }
      None => ()
    }
  }
  @util.log_info(
    "HarnessEvolution", "No plugin.json found; using the default evolution config",
  )
  @types.EngineConfig::default()
}

///|
async fn main {
  let paths = @store.DataPaths::default()
  paths.warn_on_legacy_v1()
  paths.ensure_root()

  let config = load_config()
  let state = @mcp.ServerState::at(paths, config~)

  @util.log_info(
    "HarnessEvolution",
    "Server started (data root: \{paths.root()}, intensity: \{config.intensity.wire_name()})",
  )

  @async.with_task_group() <| group => {
    let flush_task = state.run_background_tasks(group)
    @mcp.serve_stdio(state)
    // ★ stdin EOF → 必须显式取消后台 flush 循环，否则 group 永远等不结束。
    // 实测教训：未加这一行时，客户端关闭 stdin 后进程挂死（烟雾测试超时 600 s）。
    // `Task::cancel` 是纯状态突变、不抛错，故能在不带 raise 的 group 回调里调用。
    flush_task.cancel()
  }

  // task group 退出时 add_defer 已做过最后一次 flush；
  // 这里再调一次是幂等兜底，确保「stdin EOF 但没有触发取消」的路径也不丢数据。
  state.shutdown()
  @util.log_info("HarnessEvolution", "Server stopped")
}
