///|
/// JSON-RPC 2.0 协议层的穷举测试。
///
/// 这些用例是「手写协议」这个决策（取代 `@modelcontextprotocol/sdk`）的
/// 主要安全网：协议 bug 在端到端手测里极难定位（客户端只会说「断开」），
/// 而在这里每一条都是 2 秒 pass/fail 的断言。
///
/// 覆盖 jsonrpc.mbt 文件头列出的**五条必须逐条做对的协议细节**，
/// 外加 -32600 / -32601 / -32602 / -32603 四条错误阶梯（在 server.mbt 里）。

// ============================================================================
// 细节 1：通知（无 id）绝不能回响应
// ============================================================================

///|
/// `id` 键**不存在** → 通知。这是 `notifications/initialized` 的形状。
/// 冒烟测试实测：10 条输入（含 1 条通知）产出恰好 9 行响应。
test "parse_message: absent id means notification" {
  let msg : Json = { "jsonrpc": "2.0", "method": "notifications/initialized" }
  let req = parse_message(msg).unwrap()
  assert_eq(req.method_name, "notifications/initialized")
  assert_true(req.is_notification())
  assert_eq(req.id, None)
}

///|
/// `id` 显式为 `null` **不是**通知 —— 它是「畸形请求」，
/// JSON-RPC 2.0 要求回一条 `id: null` 的错误响应。
/// 这条区分是 `Some(Null)` 与 `None` 的存在理由；若用 `unwrap_or(null)` 折叠，
/// 两者就无法分辨，通知会被误回一条响应，客户端随即报协议错误断开。
test "parse_message: explicit null id is NOT a notification" {
  let msg : Json = { "jsonrpc": "2.0", "id": null, "method": "ping" }
  let req = parse_message(msg).unwrap()
  assert_false(req.is_notification())
  assert_eq(req.id, Some(Json::null()))
}

///|
/// 有 id 的正常请求。
test "parse_message: numeric id is a request" {
  let msg : Json = { "jsonrpc": "2.0", "id": 7, "method": "ping" }
  let req = parse_message(msg).unwrap()
  assert_false(req.is_notification())
  assert_eq(req.id, Some(Json::number(7.0)))
}

// ============================================================================
// 细节 2：id 可以是数字或字符串，必须原样回显
// ============================================================================

///|
/// 冒烟测试实测：`"id":"two"` 的请求回的是 `"id":"two"`（字符串），
/// 不是 `2`、也不是被引号包起来的数字。
test "result_msg: echoes a string id verbatim" {
  let resp = result_msg(Some(Json::string("two")), Json::empty_object())
  match resp {
    Object(o) => assert_eq(o.get("id"), Some(Json::string("two")))
    _ => abort("expected an object")
  }
}

///|
test "result_msg: echoes a numeric id verbatim" {
  let resp = result_msg(Some(Json::number(42.0)), Json::empty_object())
  match resp {
    Object(o) => assert_eq(o.get("id"), Some(Json::number(42.0)))
    _ => abort("expected an object")
  }
}

///|
/// 无法确定 id 时（解析失败、畸形请求）回 `null` —— JSON-RPC 2.0 的规定。
test "result_msg: None id renders as null" {
  let resp = result_msg(None, Json::empty_object())
  match resp {
    Object(o) => assert_eq(o.get("id"), Some(Json::null()))
    _ => abort("expected an object")
  }
}

///|
/// 每条响应都必须带 `jsonrpc: "2.0"`（成功与错误两条路径都要）。
test "every response carries jsonrpc 2.0" {
  for
    resp in [
      result_msg(Some(Json::number(1.0)), Json::empty_object()),
      error_msg(Some(Json::number(1.0)), code_internal_error, "boom"),
    ] {
    match resp {
      Object(o) => assert_eq(o.get("jsonrpc"), Some(Json::string("2.0")))
      _ => abort("expected an object")
    }
  }
}

// ============================================================================
// 细节 3：ping 与 initialize
// ============================================================================

///|
/// `initialize` **回显**客户端声明的 protocolVersion，而不是回自己支持的最新版本。
/// 理由见 `default_protocol_version` 的注释：后者会让客户端以为
/// 我们实现了某个其实没实现的版本。
test "initialize_result echoes the client protocolVersion" {
  let params : Json = {
    "protocolVersion": "2025-06-18",
    "capabilities": Json::empty_object(),
    "clientInfo": { "name": "smoke", "version": "1.0" },
  }
  match initialize_result(params) {
    Object(o) =>
      assert_eq(o.get("protocolVersion"), Some(Json::string("2025-06-18")))
    _ => abort("expected an object")
  }
}

///|
/// 客户端没声明（或声明的不是字符串）→ 回默认版本。
/// 覆盖三种退化形状：缺键、非字符串、params 根本不是对象。
test "initialize_result falls back to the default protocolVersion" {
  let cases : Array[Json] = [
    Json::empty_object(),
    { "protocolVersion": Json::number(2024.0) },
    Json::null(),
  ]
  for params in cases {
    match initialize_result(params) {
      Object(o) =>
        assert_eq(
          o.get("protocolVersion"),
          Some(Json::string(default_protocol_version)),
        )
      _ => abort("expected an object")
    }
  }
}

///|
/// `capabilities.tools` 必须存在：缺了它，多数客户端会认为本服务不提供工具，
/// 于是不发 `tools/list`。
test "initialize_result advertises the tools capability" {
  match initialize_result(Json::empty_object()) {
    Object(o) => {
      let caps = o.get("capabilities")
      guard caps is Some(Object(c)) else {
        abort("capabilities must be an object")
      }
      assert_true(c.contains("tools"))
      let info = o.get("serverInfo")
      guard info is Some(Object(s)) else {
        abort("serverInfo must be an object")
      }
      assert_eq(s.get("name"), Some(Json::string(server_name)))
      assert_eq(s.get("version"), Some(Json::string(server_version)))
    }
    _ => abort("expected an object")
  }
}

// ============================================================================
// 细节 4：错误码阶梯
// ============================================================================

///|
test "the four standard error codes are the JSON-RPC 2.0 ones" {
  assert_eq(code_parse_error, -32700)
  assert_eq(code_invalid_request, -32600)
  assert_eq(code_method_not_found, -32601)
  assert_eq(code_invalid_params, -32602)
  assert_eq(code_internal_error, -32603)
}

///|
test "error_msg carries code and message" {
  let resp = error_msg(
    Some(Json::number(9.0)),
    code_method_not_found,
    "Method not found: x",
  )
  match resp {
    Object(o) => {
      assert_eq(o.get("id"), Some(Json::number(9.0)))
      // 错误响应**不得**同时带 result（JSON-RPC 2.0：二者互斥）
      assert_false(o.contains("result"))
      let err = o.get("error")
      guard err is Some(Object(e)) else { abort("error must be an object") }
      assert_eq(e.get("code"), Some(Json::number(-32601.0)))
      assert_eq(e.get("message"), Some(Json::string("Method not found: x")))
    }
    _ => abort("expected an object")
  }
}

///|
test "result_msg never carries an error key" {
  match result_msg(Some(Json::number(1.0)), Json::empty_object()) {
    Object(o) => assert_false(o.contains("error"))
    _ => abort("expected an object")
  }
}

// ============================================================================
// 畸形消息 → None（由 server.mbt 转成 -32600）
// ============================================================================

///|
/// `method` 缺失或不是字符串才算非法；`params` 缺失是合法的
/// （MCP 客户端对 `tools/list` 常常不带 params，此时按空对象处理）。
test "parse_message rejects messages without a string method" {
  let bad : Array[Json] = [
    Json::null(),
    Json::number(3.0),
    Json::string("not an object"),
    Json::array([]),
    Json::empty_object(), // 有 jsonrpc 但没有 method
    { "jsonrpc": "2.0", "method": Json::number(5.0) },
    { "jsonrpc": "2.0", "method": Json::null() },
  ]
  for msg in bad {
    assert_eq(parse_message(msg), None)
  }
}

///|
test "parse_message defaults missing params to an empty object" {
  let msg : Json = { "jsonrpc": "2.0", "id": 1, "method": "tools/list" }
  let req = parse_message(msg).unwrap()
  assert_eq(req.params, Json::empty_object())
}

///|
/// 决策 D15「不做初始化门禁」的可执行形式：
/// `parse_message` 不看任何历史状态，`tools/list` 在 `initialize` 之前一样能解析。
/// 门禁若存在，它只能是 `handle_message` 里的一个分支 —— 而那里没有。
test "parse_message is stateless: no initialize gating" {
  let before_init : Json = { "jsonrpc": "2.0", "id": 1, "method": "tools/list" }
  assert_true(parse_message(before_init) is Some(_))
}

///|
/// ★ 评审 W1/W2 的回归网：`jsonrpc` 版本字段**有意不校验**（宽容策略）。
/// 合法形状只有 `"jsonrpc":"2.0"`，但 `parse_message` 从不读它：
/// · 声明 `"1.0"`（JSON-RPC 1.0 时代的客户端）
/// · 整个缺省（部分手写客户端不发）
/// 两者都与 2.0 请求同样处理。这是刻意行为（见 jsonrpc.mbt 文件头的
/// 「宽进」策略）—— 本用例把它**钉死**，防止将来有人「顺手」加上
/// 版本检查，把一个能用的客户端组合弄挂。
test "parse_message tolerates a jsonrpc 1.0 or absent version field" {
  let cases : Array[Json] = [
    { "jsonrpc": "1.0", "id": 1, "method": "ping" },
    { "id": 1, "method": "ping" }, // 无版本字段
    { "jsonrpc": Json::number(2.0), "id": 1, "method": "ping" }, // 非字符串
  ]
  for msg in cases {
    let req = parse_message(msg).unwrap()
    assert_eq(req.method_name, "ping")
    assert_eq(req.id, Some(Json::number(1.0)))
  }
}

// ============================================================================
// -32600 的 best_effort_id：形状非法时仍尽力对上号
// ============================================================================

///|
/// 一条形状非法但**带了 id** 的消息，错误响应必须回显那个 id，
/// 否则客户端无法把错误关联到它发出的请求（会一直等到超时）。
test "best_effort_id recovers the id from a malformed message" {
  let msg : Json = { "jsonrpc": "2.0", "id": 77, "method": Json::number(1.0) }
  assert_eq(parse_message(msg), None) // 确认它确实走 -32600 路径
  assert_eq(best_effort_id(msg), Some(Json::number(77.0)))
}

///|
/// 完全取不到 id（不是对象，或没有 id 键）→ `None` → 渲染成 `null`。
test "best_effort_id yields None when the id is unrecoverable" {
  assert_eq(best_effort_id(Json::string("nope")), None)
  assert_eq(best_effort_id(Json::empty_object()), None)
}
