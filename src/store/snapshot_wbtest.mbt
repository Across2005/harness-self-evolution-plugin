///|
/// 运行时快照（snapshot.mbt）与执行日志尾窗（exec_log.mbt read_tail /
/// parse_exec_line）的白盒用例。全部落盘在 @fs.tmpdir，不触碰真实数据根。
fn jobj(json : Json) -> Map[String, Json] {
  match json {
    Object(m) => m
    _ => abort("expected a JSON object")
  }
}

///|
async test "snapshot parses legacy exec-log lines" {
  let dir = @fs.tmpdir(prefix="evo-snap-log-")
  defer @fs.rmdir(dir, recursive=true)
  let log = ExecutionLog::new("\{dir}/execution.log")
  log.append(
    "evo-x-1.0.0",
    ExecEvent::Start,
    "Starting execution of evo-x-1.0.0",
  )
  log.append("evo-x-1.0.0", ExecEvent::Progress, "Layer completed (2 task(s))")
  log.append("evo-x-1.0.0", ExecEvent::Complete, "Execution completed")

  let recs = log.read_tail(10)
  assert_eq(recs.length(), 3)
  assert_eq(recs[0].proposal_id, "evo-x-1.0.0")
  assert_eq(recs[0].event, "start")
  assert_eq(recs[0].message, "Starting execution of evo-x-1.0.0")
  assert_eq(recs[1].event, "progress")
  assert_eq(recs[2].event, "complete")
  assert_false(recs[0].malformed)
  // ISO 时间戳如实带出（含 T 分隔符），不做任何再格式化。
  assert_true(recs[0].ts.contains("T"))
}

///|
/// 损坏行与崩溃残行**原样保留**并标记 malformed —— 不修复、不丢弃，
/// 损坏本身就是要给浮窗看的证据。
async test "snapshot tolerates malformed and half lines" {
  let dir = @fs.tmpdir(prefix="evo-snap-bad-")
  defer @fs.rmdir(dir, recursive=true)
  let path = "\{dir}/execution.log"
  let content = "garbage without brackets\n[2026-09-17T00:00:00.000Z] [p-1] [start] ok message\n[2026-09-17T00:00:01.000Z] [p-1] [progress] half-written tail"
  @fs.write_file(path, content, create_mode=CreateOrTruncate)
  let recs = ExecutionLog::new(path).read_tail(10)
  assert_eq(recs.length(), 3)
  assert_true(recs[0].malformed)
  assert_eq(recs[0].message, "garbage without brackets")
  assert_eq(recs[0].ts, "")
  assert_false(recs[1].malformed)
  assert_eq(recs[1].event, "start")
  // 末行缺换行符也照常解析（残行判定在 append 侧，不在读侧造假）。
  assert_false(recs[2].malformed)
  assert_eq(recs[2].message, "half-written tail")
  // 尾窗截断只保末尾 n 条，且保持旧→新顺序。
  let tail2 = ExecutionLog::new(path).read_tail(2)
  assert_eq(tail2.length(), 2)
  assert_eq(tail2[0].message, "ok message")
}

///|
/// metrics / signals / plugin-cache 三个文件都不存在时，快照必须
/// **点名「尚未产生」并写清覆盖范围**（缺陷 9：自测量只覆盖本插件自身），
/// 而不是留白让读者误判「没有活动」。
async test "snapshot reports empty metrics as not-wired" {
  let dir = @fs.tmpdir(prefix="evo-snap-gaps-")
  defer @fs.rmdir(dir, recursive=true)
  let paths = DataPaths::at(dir)
  let snap = runtime_snapshot(paths, ProposalStore::at(paths), 5)
  let body = jobj(snap)
  let rendered = snap.stringify()
  assert_true(rendered.contains("metrics.jsonl"))
  assert_true(rendered.contains("signals.jsonl"))
  assert_true(rendered.contains("plugin-cache.json"))
  // 四段结构齐全。
  for key in ["plugin_cache", "proposals", "execution", "data_gaps", "root"] {
    assert_true(body.contains(key))
  }
}

///|
/// 提案按 wire 状态计数；recent 新→旧排列。
async test "snapshot counts proposals by status" {
  let dir = @fs.tmpdir(prefix="evo-snap-prop-")
  defer @fs.rmdir(dir, recursive=true)
  let paths = DataPaths::at(dir)
  let store = ProposalStore::at(paths)
  store.save(make_proposal(status=@types.ProposalStatus::Pending))
  store.save(
    make_proposal(
      proposal_id="evo-2026-09-04-test-plugin-b",
      status=@types.ProposalStatus::Completed,
    ),
  )
  store.save(
    make_proposal(
      proposal_id="evo-2026-09-04-test-plugin-c",
      status=@types.ProposalStatus::Rejected,
    ),
  )

  let snap = runtime_snapshot(paths, store, 5)
  let proposals = jobj(
    match jobj(snap).get("proposals") {
      Some(p) => p
      None => abort("proposals section missing")
    },
  )
  assert_eq(proposals.get("total"), Some(Json::number(3.0)))
  let counts = match proposals.get("count_by_status") {
    Some(c) => c
    None => abort("count_by_status missing")
  }
  let rendered = counts.stringify()
  assert_true(rendered.contains("\"pending\":1"))
  assert_true(rendered.contains("\"completed\":1"))
  assert_true(rendered.contains("\"rejected\":1"))
  // recent 新→旧：最后保存的 c 排第一。
  let recent = match proposals.get("recent") {
    Some(Array(items)) => items
    _ => abort("recent must be an array")
  }
  assert_eq(recent.length(), 3)
  assert_true(recent[0].stringify().contains("test-plugin-c"))
}

///|
/// 同源双写：每个事件同时落 `execution.log`（文本，行格式一字不改）
/// 与 `execution.jsonl`（镜像）。两文件条数相等、逐事件字段对齐，
/// 时间戳共用同一个 stamp —— 镜像不是第二事实来源，是同一事实的第二形状。
async test "execution.jsonl mirrors execution.log" {
  let dir = @fs.tmpdir(prefix="evo-snap-mirror-")
  defer @fs.rmdir(dir, recursive=true)
  let paths = DataPaths::at(dir)
  let log = ExecutionLog::at(paths)
  log.append(
    "evo-m-1.0.0",
    ExecEvent::Start,
    "Starting execution of evo-m-1.0.0",
  )
  log.append("evo-m-1.0.0", ExecEvent::Progress, "Layer completed (1 task(s))")
  log.append("evo-m-1.0.0", ExecEvent::Complete, "Execution completed")

  let text_lines = ExecutionLog::new("\{dir}/execution.log").read()
  assert_eq(text_lines.length(), 3)
  let mirrored = ExecutionLog::at(paths).read_tail(10)
  assert_eq(mirrored.length(), 3)
  // 镜像字段与文本行逐事件对齐（时间戳同源）。
  assert_true(text_lines[0].has_prefix("[\{mirrored[0].ts}]"))
  assert_eq(mirrored[0].proposal_id, "evo-m-1.0.0")
  assert_eq(mirrored[0].event, "start")
  assert_eq(mirrored[1].event, "progress")
  assert_eq(mirrored[2].event, "complete")
  assert_false(mirrored[2].malformed)
  // 镜像里的坏行按文本侧同口径标记，不静默吞掉。
  @fs.write_file(
    paths.execution_events(),
    "not-json\n",
    create_mode=OpenOrCreate,
    append=true,
  )
  let with_bad = ExecutionLog::at(paths).read_tail(10)
  assert_eq(with_bad.length(), 4)
  assert_true(with_bad[3].malformed)
  assert_eq(with_bad[3].message, "not-json")
}

///|
/// 镜像文件不存在（双写上线前的旧数据根）时，read_tail 回落到
/// 文本解析 —— 旧执行记录仍然可视，而不是直接空掉。
async test "snapshot falls back to text log when mirror is absent" {
  let dir = @fs.tmpdir(prefix="evo-snap-fallback-")
  defer @fs.rmdir(dir, recursive=true)
  let paths = DataPaths::at(dir)
  // 只造文本日志（模拟旧版本留下的数据根）。
  let legacy = ExecutionLog::new(paths.execution_log())
  legacy.append("evo-old-1.0.0", ExecEvent::Start, "legacy run")
  legacy.append("evo-old-1.0.0", ExecEvent::Complete, "legacy done")

  assert_false(@fs.exists(paths.execution_events()))
  let recs = ExecutionLog::at(paths).read_tail(10)
  assert_eq(recs.length(), 2)
  assert_eq(recs[0].event, "start")
  assert_eq(recs[1].proposal_id, "evo-old-1.0.0")
}
