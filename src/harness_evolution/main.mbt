///|
/// 可执行入口。取代 legacy-ts/src/mcp/server.ts L312-336 的 `main()`
/// 与其 SIGINT/SIGTERM 处理。
///
/// 启动序列：
/// 1. 定位数据目录（`$HARNESS_EVOLUTION_HOME` 或 `<DSH_HOME>/.harness-evolution/v2`）
/// 2. 若发现 v1 遗留目录 → stderr 提示一行（只提示、不迁移，见 store/paths.mbt）
/// 3. 读取 `.dsh-plugin/plugin.json` 的 `evolution_config`（修配置孤岛）
/// 4. 装配 `ServerState`（ProposalStore 只构造一次，三方共享）
/// 5. 在一个 task group 里同时跑「周期性 flush」「配置文件监听」与「stdio 服务循环」
/// 6. stdin EOF → 取消两个后台循环 → group 退出 → `add_defer` 做最后一次 flush → 幂等 shutdown
///
/// **不再需要手写的信号处理器**：legacy 的 `process.on('SIGINT'/'SIGTERM')`
/// （server.ts L324-332）由 `moonbitlang/async` 的结构化并发接管 ——
/// 默认的全局取消信号已覆盖 Windows 上有意义的 CTRL_C / CTRL_CLOSE / CTRL_BREAK，
/// 取消发生时 task group 会等所有子任务结束再退出，不会留下僵尸后台任务。
/// 详见 mcp/server.mbt 里关于「为什么不显式调 set_global_cancellation_signals」的说明。

///|
/// 解析**实际生效**的配置文件路径。查找顺序：
/// 1. `$HARNESS_EVOLUTION_CONFIG`（显式覆盖；指向的文件**存在**才生效）
/// 2. `<cwd>/.dsh-plugin/plugin.json`（DSH 自述清单）
/// 3. `.dsh-plugin/plugin.json`（相对路径兜底，此时文件可能尚不存在）
///
/// **v2.7.0 起（破坏性）**：不再读取旧布局 `<cwd>/.zcode-plugin/plugin.json`。
/// 已部署实例把该文件改名为 `.dsh-plugin/plugin.json` 即可（内容无需改）。
///
/// `load_config` 与 `config_watcher_loop` **共用本函数**：若监听器自行解析路径，
/// env 指向不存在的文件时它仍会盯 env 路径，而实际生效的是 cwd 的 plugin.json
/// —— 配置变了监听器也看不见。监听路径必须与生效路径同源。
///
/// 全部候选都不存在时回退到最高优先级的候选：与「用默认配置启动」的路径
/// 保持同一个名字，文件后续出现时监听器也能发现（行为与旧 watcher 一致）。
async fn effective_config_path() -> String {
  let candidates : Array[String] = []
  match @env.get_env_var("HARNESS_EVOLUTION_CONFIG") {
    Some(p) if p.length() > 0 => candidates.push(@util.expand_home(p))
    _ => ()
  }
  match @env.current_dir() {
    Some(cwd) => {
      candidates.push(@util.path_join(cwd, ".dsh-plugin/plugin.json"))
    }
    None => ()
  }
  candidates.push(".dsh-plugin/plugin.json")
  for path in candidates {
    if @fs.exists(path) {
      return path
    }
  }
  candidates[0]
}

///|
/// 读取 `evolution_config`、`scan_targets` 和 `monitoring`。配置文件路径由
/// `effective_config_path` 解析（env 指向存在文件 → cwd 的 .dsh-plugin →
/// 相对路径兜底）。
///
/// 都找不到就用默认配置 —— 配置缺失绝不能让插件启动失败。
///
/// **这一步修掉了 legacy 的一处配置孤岛**：自述清单（`.dsh-plugin/plugin.json`）L48-66
/// 写了完整的 `evolution_config`（含 `signal_thresholds`），
/// 但 legacy 的 `src/**` 里没有任何代码读它，改配置等于空操作。
/// 新版由 `EngineConfig::from_json` 真正读取，配置文件重新生效。
///
/// **2.2.0 起同一份 plugin.json 的 `scan_targets` 也被接通**（最后一块配置
/// 孤岛，见 CONTEXT.md 已知缺陷第 6 条）：解析走
/// `ScanConfig::from_plugin_json`，未配置时回退 `default_scan_roots()`。
/// 接通它会改变发现哪些插件 —— 这是「全面升级」授权下的显式行为变更。
///
/// **2.3.0 起统一配置管理**：三个配置段（`evolution_config`、`scan_targets`、
/// `monitoring`）合并为 `HarnessConfig` + `ScanConfig`。`monitoring` 段
/// 现在被解析和验证（已知缺陷 #9 的第一步），为未来的监控数据源接入做准备。
async fn load_config(
  paths : @store.DataPaths,
) -> (@types.HarnessConfig, @scanner.ScanConfig) {
  let path = effective_config_path()
  match @store.read_json(path) {
    Some(json) => {
      @util.log_info("HarnessEvolution", "Loaded config from \{path}")
      let (harness_cfg, warns) = @types.HarnessConfig::from_json_checked(json)
      // 越界取值会**回落默认值**，但必须让人看见：配置孤岛是 2.0 才接通的，
      // 退化值（`consecutive_failures: 0` 等）过去会被静默兜底，
      // 引擎会拿着被改写的阈值产出的垃圾信号去改真实插件。
      for w in warns {
        @util.log_warn(
          "HarnessEvolution",
          "Invalid config value, fell back to default: \{w}",
        )
      }
      // 同一份 plugin.json 的 scan_targets：与 evolution_config 同轮接通，
      // 告警语义见 ScanConfig::from_plugin_json（缺失静默、退化点名）。
      let (scan, scan_warns) = @scanner.ScanConfig::from_plugin_json(
        json,
        paths.plugin_cache(),
      )
      for w in scan_warns {
        @util.log_warn(
          "HarnessEvolution",
          "Invalid scan_targets value, fell back to defaults: \{w}",
        )
      }
      return (harness_cfg, scan)
    }
    None => ()
  }
  @util.log_info(
    "HarnessEvolution", "No plugin.json found; using default config and scan roots",
  )
  (@types.HarnessConfig::default(), @scanner.ScanConfig::at(paths))
}

///|
/// 配置文件监听器。
///
/// 通过轮询机制检测配置文件变化，当文件修改时间发生变化时记录日志。
/// 由于 MoonBit 的限制，无法在运行时修改 ServerState 的字段，
/// 因此配置热重载功能仅记录变化，不自动更新 ServerState。
///
/// **设计决策**：
/// - 使用轮询而非文件系统事件：MoonBit 的 fs 模块没有提供跨平台的文件监听 API
/// - 轮询间隔可配置，默认 5 秒
/// - 只记录配置变化，不自动重载（需要重启插件才能应用新配置）
///
/// **退出路径**：本循环是 `while true` 永不自行结束，入口在 stdin EOF 后
/// `cancel()` 本任务 —— 循环体在每轮 sleep 后检查取消状态再干活
/// （与 monitor 的 flush 循环同款写法），靠该检查 break，否则 task group
/// 会永远等它结束，进程挂死。
///
/// **首轮基线（缺陷 3a 的修复点）**：进 `while` **之前**先取一次 mtime 快照
/// 作为基线，而不是把基线初始化为 `None`。详见循环体上方的注释。
/// 读盘与比较两个原语抽在 `store/config_watch.mbt`（main 包不能放测试文件，
/// 抽出去才可测）。
async fn config_watcher_loop(config_path : String) -> Unit {
  let poll_interval_ms = 5000
  // ★ 缺陷 3a 修复：进循环**前**先取一次基线快照。
  //
  // 旧实现在这里写死 `None`，而 `(None, Some(_)) => true` 表达的是
  // 「文件在本进程运行期间被创建」。于是只要启动时配置文件就存在，
  // 首轮轮询（5 s 后）必定报一条 "Config file changed"，与用户是否改过配置无关 ——
  // 实测日志里这一行出现了 10 次，与进程生命周期数一一对应，是纯噪声。
  //
  // 预置基线后，`None` 恢复成它本来的含义「启动时确实没有文件」：
  // 只有「启动后新建」才会触发；「启动时就存在的文件被改动」仍由
  // (Some, Some) 分支正常捕获。两个方向的语义都不丢。
  //
  // 取不到快照（文件不存在 / 读不到）时基线就是 `None`，行为与旧实现一致。
  let mut last_mtime : (Int64, Int)? = @store.config_mtime(config_path)

  @util.log_info(
    "ConfigWatcher",
    "Started watching config file: \{config_path}",
  )

  while true {
    @async.sleep(poll_interval_ms)
    if @async.is_being_cancelled() {
      break
    }

    // 读取当前修改时间，并与基线比较（创建 / 删除 / 秒或纳秒变化都算变化）
    let current_mtime = @store.config_mtime(config_path)
    let changed = @store.config_changed(last_mtime, current_mtime)

    if changed {
      @util.log_info(
        "ConfigWatcher", "Config file changed, restart required to apply new configuration",
      )
      last_mtime = current_mtime
    }
  }
}

///|
async fn main {
  let paths = @store.DataPaths::default()
  paths.warn_on_legacy_v1()
  paths.ensure_root()

  let (harness_cfg, scan) = load_config(paths)
  let config = harness_cfg.engine
  let state = @mcp.ServerState::with_harness_config(paths, scan, harness_cfg)

  @util.log_info(
    "HarnessEvolution",
    "Server started (data root: \{paths.root()}, intensity: \{config.intensity.wire_name()}, scan roots: \{scan.roots.length()}, monitoring: \{harness_cfg.monitoring.enabled})",
  )

  // 确定配置文件路径：与 load_config 共用同一个解析函数，保证监听与生效路径同源
  let config_path = effective_config_path()

  @async.with_task_group() <| group => {
    let flush_task = state.run_background_tasks(group)
    // 启动配置文件监听（仅记录变化，不自动重载）。
    // allow_failure 与 flush 任务一致：watcher 自身抛错不连累整个 group。
    let watcher_task = group.spawn(allow_failure=true, async fn() {
      config_watcher_loop(config_path)
    })
    @mcp.serve_stdio(state)
    // ★ stdin EOF → 必须显式取消两个后台循环，否则 group 永远等不结束。
    // 实测教训：未取消 flush 时，客户端关闭 stdin 后进程挂死（烟雾测试超时 600 s）。
    // watcher 的 while true 同样永不自行结束，取消后由循环体内的
    // is_being_cancelled 检查退出。
    // `Task::cancel` 是纯状态突变、不抛错，故能在不带 raise 的 group 回调里调用。
    flush_task.cancel()
    watcher_task.cancel()
  }

  // task group 退出时 add_defer 已做过最后一次 flush；
  // 这里再调一次是幂等兜底，确保「stdin EOF 但没有触发取消」的路径也不丢数据。
  state.shutdown()
  @util.log_info("HarnessEvolution", "Server stopped")
}
