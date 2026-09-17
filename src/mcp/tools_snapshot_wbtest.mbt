///|
/// `get_runtime_snapshot` 的工具层用例：注册形状、四段返回、
/// 尾窗上限收口。复用 tools_wbtest.mbt 的 send / call_line /
/// tool_payload / is_tool_error / obj / seed_proposal 助手。

///|
async test "get_runtime_snapshot returns four sections" {
  let tmp = @fs.tmpdir(prefix="evo-mcp-snap-")
  defer @fs.rmdir(tmp, recursive=true)
  let state = isolated_state(tmp)
  state.proposals.save(
    seed_proposal("evo-snap-pending", @types.ProposalStatus::Pending),
  )

  let resp = send(
    state,
    call_line(1, "get_runtime_snapshot", Json::empty_object()),
  )
  assert_false(is_tool_error(resp))
  let body = obj(tool_payload(resp))
  assert_eq(body.get("success"), Some(Json::boolean(true)))
  for key in ["plugin_cache", "proposals", "execution", "data_gaps", "root"] {
    assert_true(body.contains(key))
  }
  // 空数据根下提案计数如实为 1（刚 seed 的那条）。
  let proposals = obj(
    match body.get("proposals") {
      Some(p) => p
      None => abort("proposals section missing")
    },
  )
  assert_eq(proposals.get("total"), Some(Json::number(1.0)))
}

///|
/// 尾窗请求超上限时**收口到 5000** 并在响应里如实回显实际生效值，
/// 而不是静默按请求值工作或直接把无界日志塞进响应。
async test "get_runtime_snapshot clamps tail_lines to the hard cap" {
  let tmp = @fs.tmpdir(prefix="evo-mcp-snap-cap-")
  defer @fs.rmdir(tmp, recursive=true)
  let state = isolated_state(tmp)
  let resp = send(
    state,
    call_line(1, "get_runtime_snapshot", {
      "tail_lines": Json::number(999999.0),
    }),
  )
  assert_false(is_tool_error(resp))
  let body = obj(tool_payload(resp))
  let execution = obj(
    match body.get("execution") {
      Some(e) => e
      None => abort("execution section missing")
    },
  )
  assert_eq(
    execution.get("tail_lines_requested"),
    Some(Json::number(@store.max_snapshot_tail.to_double())),
  )
}
