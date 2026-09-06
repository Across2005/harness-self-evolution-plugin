///|
/// store 包的行为测试。全部用 `@fs.tmpdir` 隔离，不触碰真实 home 目录
/// —— 这是它们能并行安全的前提（对应 legacy-ts 的 `fs.mkdtemp(os.tmpdir())`）。
///
/// 其中「状态机」三例移植自 legacy-ts/tests/executor.test.ts L154-179
/// （那里把 ProposalStore 的用例放在了 executor 的测试文件里，
/// 本仓按「测试紧邻被测代码」的 MoonBit 惯例归位到 store）。

///|
/// 造一份最小可用提案。`status` / `created_at` / `signature` 可覆盖，
/// 因为绝大多数用例只关心这三个字段。
///
/// `created_at` 缺省取**实时时钟**而不是硬编码时间戳：
/// 冷却窗口的用例拿 `now_ms()` 与 `created_at` 相减，
/// 写死一个日期会让测试在系统时钟走过那个日期后静默全部失效
/// （第一版就因为写死 2025-09-04、而系统时钟已是 2026 而失败）。
fn make_proposal(
  proposal_id? : String = "evo-2026-09-04-test-plugin-a",
  plugin_id? : String = "test-plugin-1.0.0",
  status? : @types.ProposalStatus = @types.ProposalStatus::Pending,
  created_at? : Int64 = @util.now_ms(),
  signature? : String = "test-plugin-a",
) -> @types.EvolutionProposal {
  {
    proposal_id,
    plugin_id,
    status,
    created_at,
    trigger_signals: [],
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
    signature,
    confidence: @types.Confidence::Medium,
  }
}

// ============================================================================
// Jsonl
// ============================================================================

///|
async test "Jsonl::load on a missing file yields an empty array" {
  let dir = @fs.tmpdir(prefix="evo-jsonl-")
  defer @fs.rmdir(dir, recursive=true)
  let store = Jsonl::new("\{dir}/absent.jsonl")
  let rows : Array[@types.EvolutionProposal] = store.load()
  assert_eq(rows.length(), 0)
  assert_eq(store.exists(), false)
  assert_eq(store.mtime(), None)
}

///|
/// 损坏行跳过并继续 —— 对齐 legacy-ts store L38-48。
/// 这是「单行错误不得让整个数据集不可用」的保证，
/// 也是 append-only 写入被进程杀死留下半行时的自愈机制。
async test "Jsonl::load skips corrupt and blank lines, keeps the good ones" {
  let dir = @fs.tmpdir(prefix="evo-jsonl-")
  defer @fs.rmdir(dir, recursive=true)
  let path = "\{dir}/mixed.jsonl"
  let good = make_proposal(proposal_id="p-good")
  // 手工拼一个含三类脏数据的文件：
  //   第 1 行 合法 / 第 2 行 空 / 第 3 行 JSON 语法坏 / 第 4 行 词汇非法 / 第 5 行 合法
  let bad_syntax =
    #|{"proposal_id": "p-bad", }
  let bad_vocab =
    #|{"proposal_id":"p-vocab","status":"teleported"}
  let good_line = ToJson::to_json(good).stringify()
  let second = make_proposal(proposal_id="p-second")
  let second_line = ToJson::to_json(second).stringify()
  @fs.write_file(
    path,
    "\{good_line}\n\n\{bad_syntax}\n\{bad_vocab}\n\{second_line}\n",
    create_mode=CreateOrTruncate,
  )

  let store = Jsonl::new(path)
  let rows : Array[@types.EvolutionProposal] = store.load()
  // 只有两行合法
  assert_eq(rows.length(), 2)
  assert_eq(rows[0].proposal_id, "p-good")
  assert_eq(rows[1].proposal_id, "p-second")
}

///|
async test "Jsonl append and append_many round-trip in order" {
  let dir = @fs.tmpdir(prefix="evo-jsonl-")
  defer @fs.rmdir(dir, recursive=true)
  let store = Jsonl::new("\{dir}/nested/deep/log.jsonl")

  // append 会自动创建父目录（含多级）
  store.append(make_proposal(proposal_id="a"))
  let rows : Array[@types.EvolutionProposal] = store.load()
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].proposal_id, "a")

  // append_many 必须是单次 write，且保持顺序
  store.append_many([
    make_proposal(proposal_id="b"),
    make_proposal(proposal_id="c"),
    make_proposal(proposal_id="d"),
  ])
  let rows : Array[@types.EvolutionProposal] = store.load()
  assert_eq(rows.length(), 4)
  json_inspect(rows.map(fn(p) { p.proposal_id }), content=["a", "b", "c", "d"])

  // 空数组短路：不创建文件、不报错
  let empty_store = Jsonl::new("\{dir}/empty.jsonl")
  let none : Array[@types.EvolutionProposal] = []
  empty_store.append_many(none)
  assert_eq(empty_store.exists(), false)
}

///|
/// `Jsonl::new` 必须展开 `~`，否则数据会落到一个名叫 `~` 的相对目录里。
async test "Jsonl::new expands the home shorthand" {
  let store = Jsonl::new("~/.harness-evolution/v2/proposals.jsonl")
  assert_eq(
    store.path(),
    @util.expand_home("~/.harness-evolution/v2/proposals.jsonl"),
  )
  assert_true(store.path().has_suffix(".harness-evolution/v2/proposals.jsonl"))
  assert_eq(store.path().contains("~"), false)
}

// ============================================================================
// ProposalStore —— 状态机（移植自 legacy-ts/tests/executor.test.ts L154-179）
// ============================================================================

///|
/// 移植：legacy-ts/tests/executor.test.ts L155-165
/// "should allow legal transitions pending → approved → executing → completed"
async test "ProposalStore allows the legal transition chain" {
  let dir = @fs.tmpdir(prefix="evo-store-")
  defer @fs.rmdir(dir, recursive=true)
  let store = ProposalStore::new("\{dir}/proposals.jsonl")
  store.save(make_proposal(proposal_id="p1"))

  assert_eq(store.set_status("p1", @types.ProposalStatus::Approved), true)
  assert_eq(store.find("p1").unwrap().status, @types.ProposalStatus::Approved)
  assert_eq(store.set_status("p1", @types.ProposalStatus::Executing), true)
  assert_eq(store.set_status("p1", @types.ProposalStatus::Completed), true)
  assert_eq(store.find("p1").unwrap().status, @types.ProposalStatus::Completed)
}

///|
/// 移植：legacy-ts/tests/executor.test.ts L166-172
/// "should throw on illegal transitions like completed → approved"
///
/// 错误消息必须与 legacy-ts store/index.ts L147 逐字一致，
/// 因为那条 jest 断言就是按字面文本匹配的。
async test "ProposalStore rejects an illegal transition with the TS-exact message" {
  let dir = @fs.tmpdir(prefix="evo-store-")
  defer @fs.rmdir(dir, recursive=true)
  let store = ProposalStore::new("\{dir}/proposals.jsonl")
  store.save(make_proposal(proposal_id="p1"))
  ignore(store.set_status("p1", @types.ProposalStatus::Approved))
  ignore(store.set_status("p1", @types.ProposalStatus::Executing))
  ignore(store.set_status("p1", @types.ProposalStatus::Completed))

  let msg = try {
    let ok = store.set_status("p1", @types.ProposalStatus::Approved)
    ignore(ok)
    ""
  } catch {
    e => e.to_string()
  }
  assert_true(
    msg.contains("Illegal proposal status transition: completed → approved"),
  )
  // 非法迁移不得改动任何状态
  assert_eq(store.find("p1").unwrap().status, @types.ProposalStatus::Completed)
}

///|
/// 移植：legacy-ts/tests/executor.test.ts L173-179
/// "should be idempotent for same-status updates"
async test "ProposalStore set_status is idempotent and appends nothing" {
  let dir = @fs.tmpdir(prefix="evo-store-")
  defer @fs.rmdir(dir, recursive=true)
  let store = ProposalStore::new("\{dir}/proposals.jsonl")
  store.save(make_proposal(proposal_id="p1"))

  assert_eq(store.set_status("p1", @types.ProposalStatus::Pending), true)
  assert_eq(store.set_status("p1", @types.ProposalStatus::Pending), true)
  // 幂等分支不追加记录：文件里仍然只有一行
  let raw = Jsonl::new("\{dir}/proposals.jsonl")
  let rows : Array[@types.EvolutionProposal] = raw.load()
  assert_eq(rows.length(), 1)
}

///|
async test "ProposalStore set_status returns false for an unknown proposal" {
  let dir = @fs.tmpdir(prefix="evo-store-")
  defer @fs.rmdir(dir, recursive=true)
  let store = ProposalStore::new("\{dir}/proposals.jsonl")
  assert_eq(store.set_status("ghost", @types.ProposalStatus::Approved), false)
  assert_eq(store.find("ghost"), None)
}

// ============================================================================
// ProposalStore —— 查询与 append-only 折叠
// ============================================================================

///|
async test "find_duplicate ignores rejected proposals" {
  let dir = @fs.tmpdir(prefix="evo-store-")
  defer @fs.rmdir(dir, recursive=true)
  let store = ProposalStore::new("\{dir}/proposals.jsonl")
  assert_eq(store.find_duplicate("sig-a"), None)

  store.save(make_proposal(proposal_id="p1", signature="sig-a"))
  assert_true(store.find_duplicate("sig-a") is Some(_))

  // 被拒绝后同签名可以重新提案（对齐 legacy-ts store L165）
  ignore(store.set_status("p1", @types.ProposalStatus::Rejected))
  assert_eq(store.find_duplicate("sig-a"), None)
}

///|
/// 冷却窗口的语义是 `now - created_at < cooldown_ms`（严格小于，
/// 对齐 legacy-ts store L171-173）。
///
/// **为何不直接钉「恰好等于」的边界**：`recent_for_plugin` 内部自己取
/// `now_ms()`，而测试造数据时又取了一次 —— 两次之间有真实时间流逝 δ≥0，
/// 于是「刚好落在边界上」这个前提在活时钟下根本不可构造
/// （第一版测试就因此失败：用 1000ms 偏移配 1001ms 窗口，δ≥1 即错过）。
/// legacy-ts 的 jest 用例（engine.test.ts L140-215）同样只用「刚刚」与
/// 「25 小时前」这种宽区间，本用例与之对齐。
async test "recent_for_plugin applies the cooldown window per plugin" {
  let dir = @fs.tmpdir(prefix="evo-store-")
  defer @fs.rmdir(dir, recursive=true)
  let store = ProposalStore::new("\{dir}/proposals.jsonl")
  let now = @util.now_ms()
  let hour : Int64 = 3_600_000L

  // 刚刚创建 → 24h 窗口内命中
  store.save(
    make_proposal(proposal_id="fresh", plugin_id="plug-a", signature="s-fresh"),
  )
  assert_eq(store.recent_for_plugin("plug-a", 24 * hour).length(), 1)
  // ★ 确定性钉住「严格小于」：窗口为 0 时，即使提案是刚刚创建的也不命中。
  //   因为 `now - created_at >= 0` 恒成立，而判定是 `< 0` → 永假。
  //   （用 1ms 窗口不行：两次取时钟可能落在同一毫秒，δ=0 会误命中）
  assert_eq(store.recent_for_plugin("plug-a", 0L).length(), 0)

  // 25 小时前 → 超出 24h 窗口（对应 legacy-ts engine.test.ts L140-177）
  store.save(
    make_proposal(
      proposal_id="old",
      plugin_id="plug-b",
      signature="s-old",
      created_at=now - 25 * hour,
    ),
  )
  assert_eq(store.recent_for_plugin("plug-b", 24 * hour).length(), 0)
  // 同一提案在 48h 窗口下命中
  assert_eq(store.recent_for_plugin("plug-b", 48 * hour).length(), 1)

  // 按插件隔离
  assert_eq(store.recent_for_plugin("plug-z", 48 * hour).length(), 0)
}

///|
async test "find_pending_for_plugin only sees pending proposals of that plugin" {
  let dir = @fs.tmpdir(prefix="evo-store-")
  defer @fs.rmdir(dir, recursive=true)
  let store = ProposalStore::new("\{dir}/proposals.jsonl")
  store.save(
    make_proposal(proposal_id="p1", plugin_id="plug-a", signature="sig-1"),
  )
  store.save(
    make_proposal(proposal_id="p2", plugin_id="plug-b", signature="sig-2"),
  )
  ignore(store.set_status("p2", @types.ProposalStatus::Approved))

  assert_eq(store.find_pending_for_plugin("plug-a").unwrap().proposal_id, "p1")
  assert_eq(store.find_pending_for_plugin("plug-b"), None)
  assert_eq(store.find_pending_for_plugin("plug-z"), None)
}

///|
async test "list applies status, plugin_id and limit in that order" {
  let dir = @fs.tmpdir(prefix="evo-store-")
  defer @fs.rmdir(dir, recursive=true)
  let store = ProposalStore::new("\{dir}/proposals.jsonl")
  for i in 0..<5 {
    store.save(
      make_proposal(
        proposal_id="p\{i}",
        plugin_id=if i < 3 { "plug-a" } else { "plug-b" },
        signature="sig-\{i}",
      ),
    )
  }
  assert_eq(store.list(ProposalFilter::all()).length(), 5)
  assert_eq(
    store
    .list({ status: None, plugin_id: Some("plug-a"), limit: None })
    .length(),
    3,
  )
  assert_eq(
    store.list({ status: None, plugin_id: None, limit: Some(2) }).length(),
    2,
  )
  // limit 在 plugin_id 之后生效：先过滤再截断
  assert_eq(
    store
    .list({ status: None, plugin_id: Some("plug-b"), limit: Some(5) })
    .length(),
    2,
  )
  // 保持写入顺序
  json_inspect(store.list(ProposalFilter::all()).map(fn(p) { p.proposal_id }), content=[
    "p0", "p1", "p2", "p3", "p4",
  ])
}

///|
/// append-only 折叠：同一 proposal_id 的多行，后写的覆盖先写的，
/// 但**位置保持首次出现的顺序**（于是 `list` 的顺序不会因状态变更而抖动）。
async test "reload folds repeated proposal_ids with last-wins semantics" {
  let dir = @fs.tmpdir(prefix="evo-store-")
  defer @fs.rmdir(dir, recursive=true)
  let path = "\{dir}/proposals.jsonl"
  let store = ProposalStore::new(path)
  store.save(make_proposal(proposal_id="p1", signature="s1"))
  store.save(make_proposal(proposal_id="p2", signature="s2"))
  ignore(store.set_status("p1", @types.ProposalStatus::Approved))

  // 文件里现在有 3 行（p1 的两次写入 + p2 的一次）
  let raw = Jsonl::new(path)
  let rows : Array[@types.EvolutionProposal] = raw.load()
  assert_eq(rows.length(), 3)

  // 但折叠后只有 2 条提案，且 p1 保持在前、状态是最新的
  let reopened = ProposalStore::new(path)
  reopened.refresh()
  assert_eq(reopened.count(), 2)
  json_inspect(
    reopened.list(ProposalFilter::all()).map(fn(p) { p.proposal_id }),
    content=["p1", "p2"],
  )
  assert_eq(
    reopened.find("p1").unwrap().status,
    @types.ProposalStatus::Approved,
  )
}

///|
/// 跨进程一致性：另一个进程追加的记录必须能被 `reload` 看见。
/// 这里直接调白盒可见的 `reload`，避开「mtime 时钟粒度」带来的时序不确定性。
async test "reload picks up rows appended by another writer" {
  let dir = @fs.tmpdir(prefix="evo-store-")
  defer @fs.rmdir(dir, recursive=true)
  let path = "\{dir}/proposals.jsonl"
  let mine = ProposalStore::new(path)
  mine.save(make_proposal(proposal_id="p1"))
  assert_eq(mine.count(), 1)

  // 模拟另一个进程
  let other = ProposalStore::new(path)
  other.refresh()
  other.save(make_proposal(proposal_id="p2", signature="s2"))

  mine.reload()
  assert_eq(mine.count(), 2)
  assert_true(mine.find("p2") is Some(_))
}

// ============================================================================
// PluginCache —— 缺陷 F2 的回归测试
// ============================================================================

///|
fn make_profile(plugin_id : String, path : String) -> @types.PluginMetadata {
  {
    plugin_id,
    name: plugin_id,
    version: "0.1.0",
    kind: @types.PluginKind::Official,
    capabilities: [],
    tools: [],
    events: [],
    dependencies: [],
    scanned_at: 1_757_000_000_000L,
    path,
    initial_metrics: {
      complexity_score: 2.0,
      interface_clarity: 9.0,
      documentation_quality: 5.0,
      usage_frequency: Some(@types.UsageFrequency::Idle),
    },
  }
}

///|
async test "PluginCache round-trips and validates against the real directory" {
  let dir = @fs.tmpdir(prefix="evo-cache-")
  defer @fs.rmdir(dir, recursive=true)

  // 造一个真实的插件目录
  let plugin_dir = "\{dir}/plugins/cached-plugin"
  @fs.mkdir(plugin_dir, recursive=true)
  @fs.write_file(
    "\{plugin_dir}/SKILL.md",
    "# Cached",
    create_mode=CreateOrTruncate,
  )
  let fp = fingerprint_of(plugin_dir).unwrap()

  let cache = PluginCache::new("\{dir}/plugin-cache.json")
  // 空缓存 → 空数组，不报错
  assert_eq(cache.load().length(), 0)

  cache.save([
    {
      profile: make_profile("cached-plugin-0.1.0", plugin_dir),
      fingerprint: fp,
    },
  ])
  let loaded = cache.load()
  assert_eq(loaded.length(), 1)
  assert_eq(loaded[0].profile.plugin_id, "cached-plugin-0.1.0")
  assert_eq(PluginCache::validate(loaded[0]), true)

  // 目录内容变化 → 指纹不符 → 缓存失效（必须重扫）
  @fs.write_file("\{plugin_dir}/EXTRA.md", "x", create_mode=CreateOrTruncate)
  assert_eq(PluginCache::validate(loaded[0]), false)
}

///|
/// ★ W3/W5（store 评审）的回归网：**同一目录结构内的就地改写**必须让指纹变化。
/// 旧实现的 `child_mtime_sec` 只有秒精度 —— 同一秒内覆写 `SKILL.md` 的内容
/// 不会改目录 mtime，若子项 mtime 也落在同一秒，指纹就察觉不到 → 缓存陈旧。
/// 新实现记录子项 mtime 的**纳秒**计数（`child_mtime_ns`），覆写前后指纹必须不同。
async test "PluginCache fingerprint detects in-place content rewrites" {
  let dir = @fs.tmpdir(prefix="evo-cache-")
  defer @fs.rmdir(dir, recursive=true)
  let plugin_dir = "\{dir}/plugins/cached-plugin"
  @fs.mkdir(plugin_dir, recursive=true)
  @fs.write_file(
    "\{plugin_dir}/SKILL.md",
    "# Cached v1",
    create_mode=CreateOrTruncate,
  )
  let fp_before = fingerprint_of(plugin_dir).unwrap()

  // 同一目录结构（不增删文件），只覆写 SKILL.md 的内容
  @fs.write_file(
    "\{plugin_dir}/SKILL.md",
    "# Cached v2 rewritten in place",
    create_mode=CreateOrTruncate,
  )
  let fp_after = fingerprint_of(plugin_dir).unwrap()

  // 目录自身 mtime 与 entry_count 可能不变，但子项纳秒级 mtime 必须变
  assert_eq(fp_before.entry_count, fp_after.entry_count)
  assert_true(fp_before != fp_after, msg="in-place rewrite must change the fingerprint")
  assert_true(
    fp_after.child_mtime_ns >= fp_before.child_mtime_ns,
    msg="rewrite must not move the child mtime backwards",
  )
}

///|
/// **缺陷 F2 的回归测试**。
/// legacy-ts 的 `scanAll`（L36-42）命中缓存的条件仅是 `cached.size > 0`，
/// 实测本机 `~/.harness-evolution/plugin-cache.json` 的唯一条目指向一个
/// 早已被 jest `afterEach` 删除的临时目录，于是每次启动都返回这条幽灵记录、永不重扫。
/// 本用例把「目录已消失的缓存条目必须被判为无效」钉死。
async test "PluginCache rejects entries whose directory no longer exists (F2)" {
  let dir = @fs.tmpdir(prefix="evo-cache-")
  defer @fs.rmdir(dir, recursive=true)
  let ghost_dir = "\{dir}/already-deleted/cached-plugin"

  let entry : CachedProfile = {
    profile: make_profile("cached-plugin-0.1.0", ghost_dir),
    // 指纹是编造的：目录根本不存在，任何指纹都不该通过校验
    fingerprint: {
      mtime_sec: 1_757_000_000L,
      mtime_nsec: 0,
      entry_count: 3,
      child_mtime_ns: 1_757_000_000_000_000_000L,
    },
  }
  assert_eq(fingerprint_of(ghost_dir), None)
  assert_eq(PluginCache::validate(entry), false)
}

///|
/// 缓存文件损坏或版本不符时必须返回空数组，而不是让整个插件启动失败 ——
/// 缓存是派生数据，丢弃只会触发一次重扫。
async test "PluginCache tolerates corrupt and outdated cache files" {
  let dir = @fs.tmpdir(prefix="evo-cache-")
  defer @fs.rmdir(dir, recursive=true)

  let corrupt = "\{dir}/corrupt.json"
  @fs.write_file(corrupt, "{ not json at all", create_mode=CreateOrTruncate)
  assert_eq(PluginCache::new(corrupt).load().length(), 0)

  // v1 格式：顶层是 { "<plugin_id>": {...} } 的对象，没有 version/plugins 字段
  let v1 = "\{dir}/v1.json"
  let v1_body =
    #|{"cached-plugin-0.1.0":{"plugin_id":"cached-plugin-0.1.0"}}
  @fs.write_file(v1, v1_body, create_mode=CreateOrTruncate)
  assert_eq(PluginCache::new(v1).load().length(), 0)

  // 版本不符
  let old = "\{dir}/old.json"
  let old_body =
    #|{"version":1,"plugins":[]}
  @fs.write_file(old, old_body, create_mode=CreateOrTruncate)
  assert_eq(PluginCache::new(old).load().length(), 0)
}

// ============================================================================
// ExecutionLog
// ============================================================================

///|
async test "ExecutionLog appends lines in the legacy-ts format" {
  let dir = @fs.tmpdir(prefix="evo-log-")
  defer @fs.rmdir(dir, recursive=true)
  let log = ExecutionLog::new("\{dir}/nested/execution.log")
  assert_eq(log.read().length(), 0)

  log.append("evo-1", ExecEvent::Start, "Starting execution of evo-1")
  log.append("evo-1", ExecEvent::Progress, "Task code-generator completed")
  log.append("evo-1", ExecEvent::Rollback, "Changes rolled back")

  let lines = log.read()
  assert_eq(lines.length(), 3)
  // 行格式：[<ISO-8601>] [<proposal_id>] [<event>] <message>
  // 时间戳与 proposal_id 是 24 字符 ISO 串加方括号，事件名取自 wire 表
  assert_true(
    lines[0].contains("] [evo-1] [start] Starting execution of evo-1"),
  )
  assert_true(
    lines[1].contains("] [evo-1] [progress] Task code-generator completed"),
  )
  assert_true(lines[2].contains("] [evo-1] [rollback] Changes rolled back"))
  // ISO-8601 前缀恒为 24 字符，故行首必形如 "[YYYY-MM-DDTHH:MM:SS.mmmZ] "（共 26 字符）。
  // 用**切片**而不是 `s[i]` 索引：MoonBit 对 String 做下标访问返回的是字节值
  // （实测 `"["[0]` 得到 91，即 `[` 的 ASCII 码）而不是 Char。
  let head = lines[0][:26].to_owned()
  assert_eq(head[:1].to_owned(), "[")
  assert_eq(head[25:26].to_owned(), "]")
  // 时间戳本体去掉方括号后必须是 24 字符的 ISO 串，且以 Z 结尾
  let stamp = head[1:25].to_owned()
  assert_eq(stamp.length(), 24)
  assert_true(stamp.has_suffix("Z"))
  assert_eq(stamp[10:11].to_owned(), "T")
}

// ============================================================================
// DataPaths
// ============================================================================

///|
test "DataPaths lays out all five files under one root" {
  let paths = DataPaths::at("/tmp/he")
  assert_eq(paths.root(), "/tmp/he")
  assert_eq(paths.proposals(), "/tmp/he/proposals.jsonl")
  assert_eq(paths.metrics(), "/tmp/he/metrics.jsonl")
  assert_eq(paths.signals(), "/tmp/he/signals.jsonl")
  assert_eq(paths.plugin_cache(), "/tmp/he/plugin-cache.json")
  assert_eq(paths.execution_log(), "/tmp/he/execution.log")
}

///|
/// 默认根目录必须是 `v2` 子目录 —— 决策 D13：
/// 与 v1 的数据结构不兼容，故并存而不覆盖。
test "DataPaths::default targets the v2 subdirectory" {
  let paths = DataPaths::default()
  assert_true(paths.root().has_suffix(".harness-evolution/v2"))
}

///|
async test "DataPaths::ensure_root creates the directory tree" {
  let dir = @fs.tmpdir(prefix="evo-paths-")
  defer @fs.rmdir(dir, recursive=true)
  let paths = DataPaths::at("\{dir}/a/b/c")
  assert_eq(@fs.exists(paths.root()), false)
  paths.ensure_root()
  assert_eq(@fs.exists(paths.root()), true)
  // 幂等
  paths.ensure_root()
  assert_eq(@fs.exists(paths.root()), true)
}

// ============================================================================
// AgentDefStore（v2.1 子 Agent 工厂的持久层）
// ============================================================================

///|
async test "AgentDefStore writes, reads, lists and removes definitions" {
  let dir = @fs.tmpdir(prefix="evo-agent-defs-")
  defer @fs.rmdir(dir, recursive=true)
  let store = AgentDefStore::at("\{dir}/agents")
  assert_eq(@fs.exists(store.path_of("alpha")), false)
  assert_eq(store.exists("alpha"), false)
  // 目录尚不存在也能直接写（ensure_dir 惰性建目录）
  assert_eq(store.write("alpha", "alpha-content", overwrite=false), false)
  assert_eq(store.exists("alpha"), true)
  assert_eq(store.read("alpha"), "alpha-content")
  // 只列 *.md；其余扩展名被排除；字典序（决策 D10）
  let _ = store.write("beta", "beta-content", overwrite=false)
  @fs.write_file(
    "\{dir}/agents/notes.txt",
    "not an agent definition",
    create_mode=CreateOrTruncate,
  )
  assert_eq(store.list(), ["alpha", "beta"])
  // 覆盖：overwrite=true 时整体替换并报告发生了覆盖
  assert_eq(store.write("alpha", "alpha-v2", overwrite=true), true)
  assert_eq(store.read("alpha"), "alpha-v2")
  // 删除后 exists / read 同步失效
  store.remove("beta")
  assert_eq(store.exists("beta"), false)
}

///|
/// 「已存在且未显式 overwrite」必须报错而非静默覆盖 ——
/// 与 ProposalStore 状态机的显式性原则一致：破坏性动作必须显式声明。
async test "AgentDefStore refuses to overwrite without overwrite=true" {
  let dir = @fs.tmpdir(prefix="evo-agent-defs-")
  defer @fs.rmdir(dir, recursive=true)
  let store = AgentDefStore::at(dir)
  assert_eq(store.write("dup", "first", overwrite=false), false)
  let msg = try {
    let _ = store.write("dup", "second", overwrite=false)
    ""
  } catch {
    e => e.to_string()
  }
  assert_true(msg.contains("already exists"))
  // 报错后旧内容原样保留（报错不能有副作用）
  assert_eq(store.read("dup"), "first")
}

///|
/// 路径穿越防御：store 层是最后一道防线，`/`、`\`、`..` 与空名全部拦下，
/// 且 read / remove 与 write 同样设防。
async test "AgentDefStore rejects path traversal and empty names" {
  let dir = @fs.tmpdir(prefix="evo-agent-defs-")
  defer @fs.rmdir(dir, recursive=true)
  let store = AgentDefStore::at(dir)
  let bad_names : Array[String] = ["../evil", "a/b", "a\b", "..", "a..b", ""]
  for bad in bad_names {
    let msg = try {
      let _ = store.write(bad, "x", overwrite=false)
      ""
    } catch {
      e => e.to_string()
    }
    assert_true(msg.length() > 0)
    let msg_read = try {
      let _ = store.read(bad)
      ""
    } catch {
      e => e.to_string()
    }
    assert_true(msg_read.length() > 0)
  }
  // 报错不能留下半成品：目录里没有任何 .md
  assert_eq(store.list(), [])
}

///|
/// read / remove 对缺失的定义必须显式报错（与 Jsonl::load 的「缺失返回空」
/// 刻意不同：定义是单文件，缺失几乎总是调用方拼错了名字）。
async test "AgentDefStore read and remove raise on missing definitions" {
  let dir = @fs.tmpdir(prefix="evo-agent-defs-")
  defer @fs.rmdir(dir, recursive=true)
  let store = AgentDefStore::at(dir)
  let msg_read = try {
    let _ = store.read("absent")
    ""
  } catch {
    e => e.to_string()
  }
  assert_true(msg_read.contains("not found"))
  let msg_remove = try {
    store.remove("absent")
    ""
  } catch {
    e => e.to_string()
  }
  assert_true(msg_remove.contains("not found"))
}

///|
/// 目录不存在时 list 返回空（首次使用前 agents/ 尚未建立是正常状态），
/// 且不做任何写入（list 是纯读操作）。
async test "AgentDefStore lists nothing when the directory does not exist" {
  let dir = @fs.tmpdir(prefix="evo-agent-defs-")
  defer @fs.rmdir(dir, recursive=true)
  let store = AgentDefStore::at("\{dir}/absent")
  assert_eq(store.list(), [])
  assert_eq(@fs.exists("\{dir}/absent"), false)
}

///|
/// ★ 第五轮 W11：目录位置被**文件**占据时 `@fs.exists` 仍为真、
/// `@fs.readdir` 必然失败。旧实现用 `catch { _ => [] }` 把它和「目录里
/// 真的没有定义」混为一谈；现在返回空数组的同时必须留一行 warn。
/// 日志本身不在断言范围内（`@stdio.stderr` 无法在用例里回收），
/// 本用例钉的是新的错误分支本身：不抛错、返回空。
async test "AgentDefStore lists nothing when the directory cannot be read" {
  let dir = @fs.tmpdir(prefix="evo-agent-defs-")
  defer @fs.rmdir(dir, recursive=true)
  let store = AgentDefStore::at("\{dir}/agents")
  let _ = store.write("alpha", "alpha-content", overwrite=false)
  // 把「目录」指向一个真实存在的**文件**：readdir 在这里一定失败
  let blocked = AgentDefStore::at(store.path_of("alpha"))
  assert_true(@fs.exists(store.path_of("alpha")))
  assert_eq(blocked.list(), [])
}
