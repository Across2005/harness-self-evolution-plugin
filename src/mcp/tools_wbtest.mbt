///|
/// MCP 工具层的端到端测试。
///
/// 入口一律走 `handle_line` —— 也就是 exe 里 stdin 每一行真正经过的那个函数，
/// 而不是直接调 handler。理由：协议层的四条错误阶梯（-32700/-32600/-32601/-32602）
/// 与工具层的 `isError` 分属**两个不同的失败通道**，只有走完整链路才能验证
/// 「哪种失败落到哪个通道」。直接调 handler 会把这个区分测没了。
///
/// 隔离方式：`ServerState::with_scan_config` 把扫描根指向 `@fs.tmpdir`，
/// 数据目录也指向同一个临时目录，于是整条
/// scan → propose → approve → execute → list 主链路可以在 `moon test` 里跑完，
/// 不碰真实机器上的 `~/.harness-evolution` 与 zcode 插件缓存。

// ============================================================================
// 断言辅助
// ============================================================================

fn obj(json : Json) -> Map[String, Json] {
  guard json is Object(o) else { abort("expected a JSON object") }
  o
}

///|
/// 取 `result` 键；缺失即失败（说明返回的是 error 响应）。
fn result_of(resp : Json) -> Json {
  match obj(resp).get("result") {
    Some(r) => r
    None => abort("expected a result, got: \{resp.stringify()}")
  }
}

///|
/// 取 `error.code`；缺失即失败。
fn error_code(resp : Json) -> Int {
  match obj(resp).get("error") {
    Some(Object(e)) =>
      match e.get("code") {
        Some(Number(n, ..)) => n.to_int()
        _ => abort("error.code must be a number")
      }
    _ => abort("expected an error object, got: \{resp.stringify()}")
  }
}

fn error_message(resp : Json) -> String {
  match obj(resp).get("error") {
    Some(Object(e)) =>
      match e.get("message") {
        Some(String(m)) => m
        _ => abort("error.message must be a string")
      }
    _ => abort("expected an error object")
  }
}

///|
/// 取出 `tools/call` 响应里 `content[0].text` 的**内容**并解析回 JSON。
///
/// 这一步同时验证了返回体形状（`content` 是数组、元素有 `type:"text"`）
/// 与 D14（text 是一段 `indent=2` 的 JSON 文本，而非对象）。
///
/// 声明 `raise`：`@json.parse` 是可抛错函数。这里刻意**不**包 try/catch ——
/// text 解析不了就是实现的 bug，让它直接把测试炸掉比转成一条模糊的断言失败更好定位。
fn tool_payload(resp : Json) -> Json raise {
  let result = result_of(resp)
  let content = match obj(result).get("content") {
    Some(Array(a)) => a
    _ => abort("result.content must be an array")
  }
  guard content.length() == 1 else { abort("expected exactly one content block") }
  let first = content[0]
  let text = match obj(first).get("text") {
    Some(String(t)) => t
    _ => abort("content[0].text must be a string")
  }
  @json.parse(text)
}

///|
/// 工具是否自报失败（`isError: true`）。
/// 缺键 == false，与 MCP 规范一致。
///
/// `Json` 的布尔变体是 `True` / `False` 两个**无参构造器**，
/// 而不是 `Bool(Bool)` —— 这是 core/builtin/json.mbt 的定义，踩过一次。
fn is_tool_error(resp : Json) -> Bool {
  match obj(result_of(resp)).get("isError") {
    Some(True) => true
    Some(False) => false
    _ => false
  }
}

///|
/// 建一个完全隔离的服务状态。返回 state 与临时目录（调用方负责删）。
fn isolated_state(tmp : String) -> ServerState {
  let paths = @store.DataPaths::at(tmp)
  ServerState::with_scan_config(
    paths,
    @scanner.ScanConfig::custom([tmp], paths.plugin_cache()),
  )
}

///|
/// 同上，但**强度开到 100%**。
///
/// 为什么主链路测试需要它 —— 这是本次移植挖出的一处 legacy 缺陷（记为 **F5**）：
/// · `propose_evolution` 的手动信号按 legacy 语义是 **medium/pattern**
///   （server.ts L177-186 `type: 'medium' as const`）
/// · 而默认强度是 **50%**（engine/index.ts L45 `?? '50%'`），
///   50% 的过滤只留 strong（L168 `signals.filter(s => s.type === 'strong')`）
/// → 两者相乘：在出厂默认配置下，`propose_evolution` 的 `signals` 参数
///   **永远不可能产生提案**，客户端只会收到一句笼统的
///   "insufficient signals, cooldown, or duplicate"。
///
/// 按计划约束「明确不修、保持 TS 原语义」，行为原样保留（避免顺手优化造成
/// 静默回归），但必须被**看见**：下面那条专门用例把它钉死，
/// 并写入 CONTEXT.md 的已知缺陷清单。
/// 主链路测试的目的是「7 个工具共享同一份状态」，与强度闸门无关，
/// 故用 Full 把这道门打开，让链路真的跑到提案创建。
fn full_intensity_state(tmp : String) -> ServerState {
  let paths = @store.DataPaths::at(tmp)
  let config : @types.EngineConfig = {
    intensity: @types.Intensity::Full,
    cooldown_hours: 24,
    auto_approve: false,
    thresholds: @types.SignalThresholds::default(),
  }
  ServerState::with_scan_config(
    paths,
    @scanner.ScanConfig::custom([tmp], paths.plugin_cache()),
    config=config,
  )
}

///|
/// 发一行请求并断言「一定有响应」（即它不是通知）。
async fn send(state : ServerState, line : String) -> Json {
  match handle_line(state, line) {
    Some(resp) => resp
    None => abort("expected a response for: \{line}")
  }
}

///|
/// 便捷构造 `tools/call` 请求行。
fn call_line(id : Int, tool : String, args : Json) -> String {
  let req : Json = {
    "jsonrpc": "2.0",
    "id": Json::number(id.to_double()),
    "method": "tools/call",
    "params": { "name": Json::string(tool), "arguments": args },
  }
  req.stringify()
}

// ============================================================================
// 协议阶梯：四种失败必须落到正确的通道
// ============================================================================

///|
/// 细节 1（最关键的一条）：通知**绝不能**回响应。
/// `notifications/initialized` 是 initialize 之后每个客户端都会发的，
/// 误回一条 result 会让多数客户端直接报协议错误并断开。
async test "a notification produces no response at all" {
  let tmp = @fs.tmpdir(prefix="evo-mcp-")
  defer @fs.rmdir(tmp, recursive=true)
  let state = isolated_state(tmp)
  assert_eq(handle_line(state, "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}"), None)
  // 任意无 id 的消息都不回应，不只是 initialized
  assert_eq(handle_line(state, "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/cancelled\"}"), None)
  assert_eq(handle_line(state, "{\"jsonrpc\":\"2.0\",\"method\":\"tools/list\"}"), None)
}

///|
/// -32700：收到的字节根本不是合法 JSON。
/// 冒烟测试实测第 9 行就是这条。
async test "unparseable input yields -32700" {
  let tmp = @fs.tmpdir(prefix="evo-mcp-")
  defer @fs.rmdir(tmp, recursive=true)
  let state = isolated_state(tmp)
  let resp = send(state, "not json at all")
  assert_eq(error_code(resp), code_parse_error)
  assert_eq(error_message(resp), "Parse error")
  // 无法确定 id → 必须是 null（JSON-RPC 2.0 的规定）
  assert_eq(obj(resp).get("id"), Some(Json::null()))
}

///|
/// 截断的 JSON 同样走 -32700，不能挂死也不能崩。
async test "truncated json yields -32700 rather than crashing" {
  let tmp = @fs.tmpdir(prefix="evo-mcp-")
  defer @fs.rmdir(tmp, recursive=true)
  let state = isolated_state(tmp)
  for line in ["{\"jsonrpc\":\"2.0\",\"id\":1", "{", "[1,2,", "\"unterminated"] {
    assert_eq(error_code(send(state, line)), code_parse_error)
  }
}

///|
/// -32600：是合法 JSON，但不是合法的 JSON-RPC 请求对象。
/// 注意 id 仍被尽力回显（`best_effort_id`），否则客户端无法关联错误与请求。
async test "a message without a string method yields -32600" {
  let tmp = @fs.tmpdir(prefix="evo-mcp-")
  defer @fs.rmdir(tmp, recursive=true)
  let state = isolated_state(tmp)
  let resp = send(state, "{\"jsonrpc\":\"2.0\",\"id\":77,\"method\":123}")
  assert_eq(error_code(resp), code_invalid_request)
  assert_eq(obj(resp).get("id"), Some(Json::number(77.0)))
  // 完全没有 method 键
  let resp2 = send(state, "{\"jsonrpc\":\"2.0\",\"id\":78}")
  assert_eq(error_code(resp2), code_invalid_request)
  assert_eq(obj(resp2).get("id"), Some(Json::number(78.0)))
}

///|
/// -32601：方法不存在。
async test "an unknown method yields -32601" {
  let tmp = @fs.tmpdir(prefix="evo-mcp-")
  defer @fs.rmdir(tmp, recursive=true)
  let state = isolated_state(tmp)
  let resp = send(state, "{\"jsonrpc\":\"2.0\",\"id\":8,\"method\":\"bogus/method\"}")
  assert_eq(error_code(resp), code_method_not_found)
  assert_eq(error_message(resp), "Method not found: bogus/method")
}

///|
/// ★ -32602（**协议级**）与 isError（**工具级**）的分界。
///
/// 「没有这个工具」是请求本身不合法 → -32602，与官方 MCP SDK 一致；
/// 「有这个工具但跑失败了」→ 200 响应 + `isError:true`。
/// 把未知工具做成 isError 会让客户端以为工具存在但出错，从而无谓重试。
async test "an unknown tool is a protocol error, not a tool error" {
  let tmp = @fs.tmpdir(prefix="evo-mcp-")
  defer @fs.rmdir(tmp, recursive=true)
  let state = isolated_state(tmp)
  let resp = send(state, call_line(7, "no_such_tool", Json::empty_object()))
  assert_eq(error_code(resp), code_invalid_params)
  assert_eq(error_message(resp), "Unknown tool: no_such_tool")
  // 协议错误响应里**不得**有 result（JSON-RPC 2.0：二者互斥）
  assert_false(obj(resp).contains("result"))
}

///|
/// `tools/call` 的 params 形状非法 → -32602（同样是协议级）。
async test "malformed tools/call params yield -32602" {
  let tmp = @fs.tmpdir(prefix="evo-mcp-")
  defer @fs.rmdir(tmp, recursive=true)
  let state = isolated_state(tmp)
  let cases : Array[String] = [
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":[]}", // 不是对象
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{}}", // 缺 name
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":42}}", // name 不是字符串
  ]
  for line in cases {
    assert_eq(error_code(send(state, line)), code_invalid_params)
  }
}

///|
/// `params.arguments` 缺失时按空对象处理 —— MCP 客户端对无参工具常常不带这个键。
async test "missing arguments defaults to an empty object" {
  let tmp = @fs.tmpdir(prefix="evo-mcp-")
  defer @fs.rmdir(tmp, recursive=true)
  let state = isolated_state(tmp)
  let resp = send(state, "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"list_proposals\"}}")
  assert_false(is_tool_error(resp))
  assert_eq(obj(tool_payload(resp)).get("count"), Some(Json::number(0.0)))
}

// ============================================================================
// 握手与探活
// ============================================================================

async test "initialize and ping over the wire" {
  let tmp = @fs.tmpdir(prefix="evo-mcp-")
  defer @fs.rmdir(tmp, recursive=true)
  let state = isolated_state(tmp)

  let init = send(
    state,
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{},\"clientInfo\":{\"name\":\"wbtest\",\"version\":\"1.0\"}}}",
  )
  let init_result = result_of(init)
  assert_eq(
    obj(init_result).get("protocolVersion"),
    Some(Json::string("2024-11-05")),
  )
  assert_eq(obj(init).get("id"), Some(Json::number(1.0)))

  // 字符串 id 必须原样回显（冒烟测试实测 id="two"）
  let ping = send(state, "{\"jsonrpc\":\"2.0\",\"id\":\"two\",\"method\":\"ping\"}")
  assert_eq(obj(ping).get("id"), Some(Json::string("two")))
  assert_eq(result_of(ping), Json::empty_object())
}

///|
/// 决策 D15：不做初始化门禁。`tools/list` 在 `initialize` 之前一样能拿到全部 7 个工具。
async test "tools/list works before any initialize handshake" {
  let tmp = @fs.tmpdir(prefix="evo-mcp-")
  defer @fs.rmdir(tmp, recursive=true)
  let state = isolated_state(tmp)
  let resp = send(state, "{\"jsonrpc\":\"2.0\",\"id\":\"two\",\"method\":\"tools/list\",\"params\":{}}")
  let list = match obj(result_of(resp)).get("tools") {
    Some(Array(a)) => a
    _ => abort("tools must be an array")
  }
  assert_eq(list.length(), 7)
}

// ============================================================================
// 工具级错误 → isError（不变量④：handler 不写 try/catch）
// ============================================================================

///|
/// 缺必填参数 → `FromJson` raise → `call_tool` 兜住 → isError。
/// 这正是「全仓唯一的工具错误处理点」要覆盖的第一类失败。
async test "a missing required argument becomes isError, not a protocol error" {
  let tmp = @fs.tmpdir(prefix="evo-mcp-")
  defer @fs.rmdir(tmp, recursive=true)
  let state = isolated_state(tmp)
  for pair in [("get_plugin_metrics", Json::empty_object()), ("approve_proposal", Json::empty_object())] {
    let (tool, args) = pair
    let resp = send(state, call_line(1, tool, args))
    assert_true(obj(resp).contains("result"))
    assert_eq(is_tool_error(resp), true)
  }
}

///|
/// 枚举取值非法（schema 声明了合法值、客户端传了别的）→ isError。
/// 与 schema_wbtest 的「schema 声明的每个值都可解码」互为表里。
async test "an out-of-vocabulary enum value becomes isError" {
  let tmp = @fs.tmpdir(prefix="evo-mcp-")
  defer @fs.rmdir(tmp, recursive=true)
  let state = isolated_state(tmp)
  let resp = send(state, call_line(1, "list_proposals", { "status": "teleported" }))
  assert_eq(is_tool_error(resp), true)
  // 错误消息必须列出合法值 —— 这是 wire 表驱动的第三处消费
  // （JSONL 序列化 / MCP schema enum / 错误消息），见 util/wire.mbt 的头注释。
  let text = match obj(result_of(resp)).get("content") {
    Some(Array(a)) =>
      match obj(a[0]).get("text") {
        Some(String(t)) => t
        _ => abort("text must be a string")
      }
    _ => abort("content must be an array")
  }
  assert_true(text.contains("pending"))
  assert_true(text.contains("completed"))
}

///|
/// 业务错误：插件不在注册表。消息与 legacy server.ts L173 **逐字一致**，
/// 这样 legacy 的既有客户端提示语不会变。
async test "propose_evolution on an unscanned plugin reports the legacy message" {
  let tmp = @fs.tmpdir(prefix="evo-mcp-")
  defer @fs.rmdir(tmp, recursive=true)
  let state = isolated_state(tmp)
  let resp = send(state, call_line(6, "propose_evolution", { "plugin_id": "ghost" }))
  assert_eq(is_tool_error(resp), true)
  let payload = obj(tool_payload(resp))
  assert_eq(payload.get("success"), Some(Json::boolean(false)))
  assert_eq(
    payload.get("error"),
    Some(Json::string("Plugin not found: ghost. Run scan_plugins first.")),
  )
}

async test "approve_proposal on an unknown id reports not found" {
  let tmp = @fs.tmpdir(prefix="evo-mcp-")
  defer @fs.rmdir(tmp, recursive=true)
  let state = isolated_state(tmp)
  let resp = send(state, call_line(1, "approve_proposal", { "proposal_id": "evo-nope" }))
  assert_eq(is_tool_error(resp), true)
  assert_eq(
    obj(tool_payload(resp)).get("error"),
    Some(Json::string("Proposal not found: evo-nope")),
  )
}

///|
/// ★ `execute_evolution` 的失败走的是**第三条通道**，与前两条都不同：
///
/// | 失败类型 | 通道 | 例子 |
/// |---|---|---|
/// | 请求不合法 | JSON-RPC error（-326xx） | 未知工具、方法不存在 |
/// | handler 抛错 | `isError: true` | 插件不存在、非法状态迁移 |
/// | **executor 返回失败** | `success: false` + `error` 字段（仍是正常响应） | 提案不存在、状态不对 |
///
/// 第三条是 legacy executor/index.ts L44-51 的原语义：`execute()` 对这两种情况
/// 都是 **return** `{success:false, results:[], error}` 而不是 throw，
/// 于是 server.ts L216-234 走 `jsonOk` → 不是 isError。
/// 忠实移植，不统一成 isError —— 改了会让靠 `isError` 判断的客户端误以为
/// 「执行器本身坏了」而不是「提案状态不对」。
async test "execute_evolution on an unknown id reports failure in the payload, not isError" {
  let tmp = @fs.tmpdir(prefix="evo-mcp-")
  defer @fs.rmdir(tmp, recursive=true)
  let state = isolated_state(tmp)
  let resp = send(state, call_line(1, "execute_evolution", { "proposal_id": "does-not-exist" }))
  // ★ 不是 isError
  assert_false(is_tool_error(resp))
  let body = obj(tool_payload(resp))
  assert_eq(body.get("success"), Some(Json::boolean(false)))
  assert_eq(
    body.get("error"),
    Some(Json::string("Proposal not found: does-not-exist")),
  )
  // results 是空数组（legacy L46），而不是缺键
  assert_eq(body.get("results"), Some(Json::array([])))
}

///|
/// 同上，但触发的是**状态闸门**：提案存在但状态不是 approved。
/// 消息与 legacy executor/index.ts L56-60 逐字一致。
async test "execute_evolution on a non-approved proposal reports the legacy status message" {
  let tmp = @fs.tmpdir(prefix="evo-mcp-")
  defer @fs.rmdir(tmp, recursive=true)
  let paths = @store.DataPaths::at(tmp)
  let state = ServerState::with_scan_config(
    paths,
    @scanner.ScanConfig::custom([tmp], paths.plugin_cache()),
  )
  state.proposals.save(
    seed_proposal("evo-pending", @types.ProposalStatus::Pending),
  )
  let resp = send(
    state,
    call_line(1, "execute_evolution", { "proposal_id": "evo-pending" }),
  )
  assert_false(is_tool_error(resp))
  let body = obj(tool_payload(resp))
  assert_eq(body.get("success"), Some(Json::boolean(false)))
  assert_eq(
    body.get("error"),
    Some(Json::string("Proposal status is pending, expected 'approved'")),
  )
}

// ============================================================================
// 返回体形状（D14：信封紧凑、内层 text 用 indent=2）
// ============================================================================

///|
/// `json_ok` 的 text 必须是 **2 空格缩进**的 JSON 文本，
/// 与 legacy server.ts L64 的 `JSON.stringify(value, null, 2)` 逐字节对齐。
/// 外层信封则是紧凑的（由 `stringify()` 无参调用产生）。
///
/// 注意 `json_ok` 返回的**就是** result 体本身（`{content:[...]}`），
/// 不是完整的 JSON-RPC 信封 —— 包上 `{jsonrpc,id,result}` 是 `result_msg` 的事。
/// 所以这里用 `obj(resp)` 而不是 `result_of(resp)`。
test "json_ok renders the inner text with two-space indent" {
  let resp = json_ok({ "a": Json::number(1.0) })
  let text = match obj(resp).get("content") {
    Some(Array(a)) =>
      match obj(a[0]).get("text") {
        Some(String(t)) => t
        _ => abort("text must be a string")
      }
    _ => abort("content must be an array")
  }
  assert_eq(text, "{\n  \"a\": 1\n}")
  // 信封不带 isError（成功路径）
  assert_false(obj(resp).contains("isError"))
}

test "json_error carries isError and a success:false body" {
  let resp = json_error("boom")
  let o = obj(resp)
  assert_eq(o.get("isError"), Some(Json::boolean(true)))
  let body = match o.get("content") {
    Some(Array(a)) =>
      match obj(a[0]).get("text") {
        Some(String(t)) => @json.parse(t)
        _ => abort("text must be a string")
      }
    _ => abort("content must be an array")
  }
  assert_eq(obj(body).get("success"), Some(Json::boolean(false)))
  assert_eq(obj(body).get("error"), Some(Json::string("boom")))
}

///|
/// ★ 通道纪律的最后一道断言：响应字符串里**不得含裸换行**。
/// 传输是 NDJSON（一行一条消息），裸换行会让客户端把一条响应读成两条，
/// 第二条必然是非法 JSON → 客户端断开。
/// `indent=2` 的 text 里确实有换行，但它们必须是**转义后的** `\n`（两字符），
/// 这条断言正是在钉这个区别。
async test "no response contains a raw newline (NDJSON discipline)" {
  let tmp = @fs.tmpdir(prefix="evo-mcp-")
  defer @fs.rmdir(tmp, recursive=true)
  let state = isolated_state(tmp)
  let lines : Array[String] = [
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{}}",
    "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"ping\"}",
    "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/list\"}",
    call_line(4, "list_proposals", Json::empty_object()),
    call_line(5, "get_plugin_metrics", { "plugin_id": "ghost" }),
    call_line(6, "propose_evolution", { "plugin_id": "ghost" }), // isError 路径
    "not json at all", // -32700 路径
    "{\"jsonrpc\":\"2.0\",\"id\":9,\"method\":\"nope\"}", // -32601 路径
  ]
  for line in lines {
    let resp = send(state, line)
    let wire = resp.stringify()
    assert_false(wire.contains("\n"))
    assert_false(wire.contains("\r"))
    // 且必须能被重新解析回来（自证合法）
    ignore(@json.parse(wire))
  }
}

// ============================================================================
// 主链路：scan → metrics → propose → approve → execute → list
// ============================================================================

///|
/// 在 tmpdir 里放一个 plugin（`package.json` + `SKILL.md`），
/// 对应 legacy tests/scanner.test.ts 的 `makePluginDir`。
async fn seed_plugin(root : String) -> Unit {
  let dir = @util.path_join(root, "demo-plugin")
  @fs.mkdir(dir, recursive=true)
  let pkg = "{\"name\":\"demo-plugin\",\"version\":\"1.2.3\"}"
  @fs.write_file(
    @util.path_join(dir, "package.json"),
    pkg,
    create_mode=CreateOrTruncate,
  )
  let skill = "# Demo\nThis tool can navigate and supports clicks."
  @fs.write_file(
    @util.path_join(dir, "SKILL.md"),
    skill,
    create_mode=CreateOrTruncate,
  )
}

///|
/// ★ 全链路端到端。这是整个 mcp 包最重要的一条测试：
/// 它证明 7 个工具不只是各自能跑，而是**共享同一份状态**
/// （CONTEXT.md 不变量②：ProposalStore 单一事实来源）。
///
/// 具体钉住的四件事：
/// 1. `scan_plugins` 填的注册表，`propose_evolution` 立刻看得见
/// 2. `propose_evolution` 建的提案，`list_proposals` 立刻看得见
/// 3. `approve_proposal` 改的状态，`execute_evolution` 的闸门认
/// 4. `execute_evolution` 跑完的状态，`list_proposals` 反映出来
///
/// 若三方各持一个 ProposalStore，第 2/3/4 步会全部失败。
async test "the full scan-propose-approve-execute-list chain over one shared state" {
  let tmp = @fs.tmpdir(prefix="evo-mcp-")
  defer @fs.rmdir(tmp, recursive=true)
  seed_plugin(tmp)
  let state = full_intensity_state(tmp)

  // --- 1. scan_plugins -------------------------------------------------
  let scan = send(state, call_line(1, "scan_plugins", { "force_rescan": true }))
  assert_false(is_tool_error(scan))
  let scan_body = obj(tool_payload(scan))
  assert_eq(scan_body.get("success"), Some(Json::boolean(true)))
  assert_eq(scan_body.get("plugin_count"), Some(Json::number(1.0)))
  let plugins = match scan_body.get("plugins") {
    Some(Array(a)) => a
    _ => abort("plugins must be an array")
  }
  let first = obj(plugins[0])
  assert_eq(first.get("name"), Some(Json::string("demo-plugin")))
  assert_eq(first.get("version"), Some(Json::string("1.2.3")))
  // 对外契约仍是 `type`（不是内部的 `kind`），见 handle_scan_plugins 的注释
  assert_true(first.contains("type"))
  assert_eq(first.get("tools_count"), Some(Json::number(0.0)))
  let plugin_id = match first.get("plugin_id") {
    Some(String(s)) => s
    _ => abort("plugin_id must be a string")
  }
  assert_eq(plugin_id, "demo-plugin-1.2.3")

  // --- 2. get_plugin_metrics：未知插件也返回零统计（对齐 legacy 语义）---
  // legacy server.ts L150-163 **不校验插件是否存在**，直接问 monitor 要统计；
  // 空统计表现为 total_calls=0 / success_rate=0。忠实移植，不改。
  let metrics = send(
    state,
    call_line(2, "get_plugin_metrics", { "plugin_id": plugin_id }),
  )
  assert_false(is_tool_error(metrics))
  let metrics_body = obj(tool_payload(metrics))
  assert_eq(metrics_body.get("plugin_id"), Some(Json::string(plugin_id)))
  assert_eq(
    metrics_body.get("time_range"),
    Some(Json::string(default_time_range.wire_name())),
  )
  let stats = obj((metrics_body.get("statistics")).unwrap_or(Json::empty_object()))
  assert_eq(stats.get("total_calls"), Some(Json::number(0.0)))
  assert_eq(stats.get("loop_detected"), Some(Json::boolean(false)))
  assert_true(stats.contains("error_types"))

  // --- 3. propose_evolution：手动信号 → 生成提案 -----------------------
  let propose = send(
    state,
    call_line(
      3,
      "propose_evolution",
      { "plugin_id": Json::string(plugin_id), "signals": Json::array([Json::string("users keep retrying the same call")]) },
    ),
  )
  assert_false(is_tool_error(propose))
  let propose_body = obj(tool_payload(propose))
  assert_eq(propose_body.get("success"), Some(Json::boolean(true)))
  let proposal = match propose_body.get("proposal") {
    Some(p) => obj(p)
    // 引擎的 7 道闸门可能判定信号不足；此时 legacy 语义是 success:true + message。
    // 那条分支由下面那条专门用例覆盖，这里必须是「生成了」。
    None => abort("expected a proposal, got: \{propose.stringify()}")
  }
  assert_eq(
    proposal.get("status"),
    Some(Json::string(@types.ProposalStatus::Pending.wire_name())),
  )
  // 中文字面量原样出现在 wire 上（CONTEXT.md「词汇即文档」）
  let principle = match proposal.get("matt_pocock_principle") {
    Some(String(s)) => s
    _ => abort("principle must be a string")
  }
  assert_true(principle.length() > 0)
  let proposal_id = match proposal.get("proposal_id") {
    Some(String(s)) => s
    _ => abort("proposal_id must be a string")
  }

  // --- 4. list_proposals 立刻看得见（共享索引）--------------------------
  let listed = send(state, call_line(4, "list_proposals", Json::empty_object()))
  let list_body = obj(tool_payload(listed))
  assert_eq(list_body.get("count"), Some(Json::number(1.0)))
  let items = match list_body.get("proposals") {
    Some(Array(a)) => a
    _ => abort("proposals must be an array")
  }
  let item = obj(items[0])
  assert_eq(item.get("proposal_id"), Some(Json::string(proposal_id)))
  assert_eq(item.get("plugin_id"), Some(Json::string(plugin_id)))
  // created_at 对外仍是 ISO-8601 字符串（内部是 Int64 毫秒）
  let created = match item.get("created_at") {
    Some(String(s)) => s
    _ => abort("created_at must be an ISO string")
  }
  assert_eq(created.length(), 24)
  assert_true(created.has_suffix("Z"))

  // --- 5. 状态过滤（走 wire 表解码）-------------------------------------
  let pending_only = send(
    state,
    call_line(5, "list_proposals", { "status": Json::string(@types.ProposalStatus::Pending.wire_name()) }),
  )
  assert_eq(obj(tool_payload(pending_only)).get("count"), Some(Json::number(1.0)))
  let completed_only = send(
    state,
    call_line(6, "list_proposals", { "status": Json::string(@types.ProposalStatus::Completed.wire_name()) }),
  )
  assert_eq(obj(tool_payload(completed_only)).get("count"), Some(Json::number(0.0)))

  // --- 6. 未审批就执行 → 被状态机闸门挡住 -------------------------------
  // 注意这走的是**载荷通道**（success:false）而不是 isError，
  // 因为 legacy 的 executor.execute 对状态不对是 return 而不是 throw。
  let premature = send(
    state,
    call_line(7, "execute_evolution", { "proposal_id": Json::string(proposal_id), "dry_run": true }),
  )
  assert_false(is_tool_error(premature))
  let premature_body = obj(tool_payload(premature))
  assert_eq(premature_body.get("success"), Some(Json::boolean(false)))
  assert_eq(
    premature_body.get("error"),
    Some(Json::string("Proposal status is pending, expected 'approved'")),
  )
  // 且状态没被改动（闸门在 setStatus 之前）
  let still_pending = send(
    state,
    call_line(
      71,
      "list_proposals",
      { "status": Json::string(@types.ProposalStatus::Pending.wire_name()) },
    ),
  )
  assert_eq(
    obj(tool_payload(still_pending)).get("count"),
    Some(Json::number(1.0)),
  )

  // --- 7. approve_proposal ----------------------------------------------
  let approved = send(
    state,
    call_line(8, "approve_proposal", { "proposal_id": Json::string(proposal_id) }),
  )
  assert_false(is_tool_error(approved))
  assert_eq(
    obj(tool_payload(approved)).get("message"),
    Some(Json::string("Proposal \{proposal_id} approved")),
  )

  // --- 8. 重复审批：幂等（set_status 同状态返回 true）-------------------
  let again = send(
    state,
    call_line(9, "approve_proposal", { "proposal_id": Json::string(proposal_id) }),
  )
  assert_false(is_tool_error(again))

  // --- 9. execute_evolution（dry_run → 无 sleep，确定性）----------------
  let executed = send(
    state,
    call_line(10, "execute_evolution", { "proposal_id": Json::string(proposal_id), "dry_run": true }),
  )
  assert_false(is_tool_error(executed))
  let exec_body = obj(tool_payload(executed))
  assert_eq(exec_body.get("proposal_id"), Some(Json::string(proposal_id)))
  let results = match exec_body.get("results") {
    Some(Array(a)) => a
    _ => abort("results must be an array")
  }
  assert_true(results.length() > 0)
  for r in results {
    let one = obj(r)
    assert_true(one.contains("agent"))
    assert_true(one.contains("success"))
    assert_true(one.contains("duration_ms"))
    // 成功的结果**不得**带 error 键（复刻 TS 的 `error: undefined` 被
    // JSON.stringify 省略的行为，而不是写 null）
    if one.get("success") == Some(Json::boolean(true)) {
      assert_false(one.contains("error"))
    }
  }

  // --- 10. 执行后的状态经 list 反映出来 --------------------------------
  let after = send(
    state,
    call_line(
      11,
      "list_proposals",
      { "status": Json::string(@types.ProposalStatus::Completed.wire_name()) },
    ),
  )
  assert_eq(obj(tool_payload(after)).get("count"), Some(Json::number(1.0)))

  // --- 11. 终态不可再迁移 → isError，消息与 store/index.ts L147 逐字一致 --
  let illegal = send(
    state,
    call_line(12, "approve_proposal", { "proposal_id": Json::string(proposal_id) }),
  )
  assert_eq(is_tool_error(illegal), true)

  // --- 12. reject_proposal 走的是同一条状态机 ---------------------------
  // completed 是终态，rejected 也不可达
  let rejected = send(
    state,
    call_line(13, "reject_proposal", { "proposal_id": Json::string(proposal_id) }),
  )
  assert_eq(is_tool_error(rejected), true)
}

///|
/// `propose_evolution` 在**信号不足**时的返回形状：
/// `success: true` + message（**不是** isError）。
/// 这是 legacy server.ts L194-199 的语义 —— 「没生成提案」是正常业务结果，
/// 不是失败。做成 isError 会让 LLM 以为出了故障而反复重试。
///
/// 用 `Intensity::Off` 关掉引擎是最干净的构造方式：
/// 它命中的是 7 道闸门的第一道，与信号内容无关，因而完全确定。
async test "propose_evolution with the engine disabled reports success plus a reason" {
  let tmp = @fs.tmpdir(prefix="evo-mcp-")
  defer @fs.rmdir(tmp, recursive=true)
  seed_plugin(tmp)
  let paths = @store.DataPaths::at(tmp)
  let config : @types.EngineConfig = {
    intensity: @types.Intensity::Off,
    cooldown_hours: 24,
    auto_approve: false,
    thresholds: @types.SignalThresholds::default(),
  }
  let state = ServerState::with_scan_config(
    paths,
    @scanner.ScanConfig::custom([tmp], paths.plugin_cache()),
    config=config,
  )
  ignore(send(state, call_line(1, "scan_plugins", { "force_rescan": true })))

  let resp = send(
    state,
    call_line(2, "propose_evolution", { "plugin_id": "demo-plugin-1.2.3" }),
  )
  // ★ 不是 isError
  assert_false(is_tool_error(resp))
  let body = obj(tool_payload(resp))
  assert_eq(body.get("success"), Some(Json::boolean(true)))
  assert_eq(
    body.get("message"),
    Some(
      Json::string(
        "No evolution proposal generated (insufficient signals, cooldown, or duplicate)",
      ),
    ),
  )
  // `reason` 是新版**追加**的字段：ProposalOutcome 枚举相对 TS 的 `null` 的价值
  // 就在于能把「为什么没生成」说清楚。追加不改既有字段，对旧客户端完全兼容。
  let reason = match body.get("reason") {
    Some(String(s)) => s
    _ => abort("reason must be a string")
  }
  assert_true(reason.length() > 0)
  assert_false(body.contains("proposal"))
}

///|
/// ★ 修掉的配置孤岛：legacy 的 `scan_plugins` schema 声明了 `target_paths`
/// （server.ts L29），但 handler 从未使用它（L131 只传 `force_rescan`）——
/// 客户端传了等于没传。新版让它真正生效。
async test "target_paths actually redirects the scan (legacy declared but ignored it)" {
  let tmp = @fs.tmpdir(prefix="evo-mcp-")
  defer @fs.rmdir(tmp, recursive=true)

  // 两个互不相干的扫描根：一个有插件，一个是空的
  let populated = @util.path_join(tmp, "populated")
  let empty_root = @util.path_join(tmp, "empty-root")
  @fs.mkdir(empty_root, recursive=true)
  seed_plugin(populated)

  let paths = @store.DataPaths::at(tmp)
  // 默认扫描根指向**空目录**：若不传 target_paths，就一个插件都找不到
  let state = ServerState::with_scan_config(
    paths,
    @scanner.ScanConfig::custom([empty_root], paths.plugin_cache()),
  )
  let baseline = send(state, call_line(1, "scan_plugins", { "force_rescan": true }))
  assert_eq(obj(tool_payload(baseline)).get("plugin_count"), Some(Json::number(0.0)))

  // 传 target_paths → 必须改扫那个有插件的目录
  let redirected = send(
    state,
    call_line(2, "scan_plugins", { "force_rescan": true, "target_paths": Json::array([Json::string(populated)]) }),
  )
  assert_eq(obj(tool_payload(redirected)).get("plugin_count"), Some(Json::number(1.0)))

  // 且注册表被**替换**而非累加（adopt 先 clear）
  let after = send(state, call_line(3, "scan_plugins", { "force_rescan": true }))
  assert_eq(obj(tool_payload(after)).get("plugin_count"), Some(Json::number(0.0)))
}

///|
/// ★ **F5 的钉死用例**：在出厂默认强度（50%）下，
/// `propose_evolution` 的 `signals` 参数是**惰性的** ——
/// 手动信号按 legacy 语义是 medium，而 50% 的过滤只留 strong。
///
/// 这条测试**不是在庆祝一个想要的行为**，而是在把一个已知的 legacy 缺陷
/// 钉在当前状态：将来有人「修好」它（例如把手动信号改成 strong，
/// 或让 50% 也放行 medium），这条用例会立即变红，迫使他意识到
/// 自己正在改一个对外可见的语义 —— 而这正是「不默默优化」约束的执行手段。
///
/// 对照用例：同一组手动信号在 `Full` 强度下**确实**能产生提案
/// （见上面的主链路测试），证明参数本身没死，只是被强度闸门挡住。
async test "F5: manual signals are inert under the default 50% intensity" {
  let tmp = @fs.tmpdir(prefix="evo-mcp-")
  defer @fs.rmdir(tmp, recursive=true)
  seed_plugin(tmp)

  // 默认配置 == legacy engine/index.ts L45 的 `intensity: '50%'`
  let state = isolated_state(tmp)
  ignore(send(state, call_line(1, "scan_plugins", { "force_rescan": true })))

  let args : Json = {
    "plugin_id": "demo-plugin-1.2.3",
    "signals": Json::array(
      [Json::string("users keep retrying the same call over and over")],
    ),
  }
  let resp = send(state, call_line(2, "propose_evolution", args))
  // 不是 isError（legacy 语义：「没生成」是正常业务结果）
  assert_false(is_tool_error(resp))
  let body = obj(tool_payload(resp))
  assert_eq(body.get("success"), Some(Json::boolean(true)))
  assert_false(body.contains("proposal"))
  // reason 字段把真因说清楚了（新版追加），而不只是笼统的那一句
  assert_eq(
    body.get("reason"),
    Some(Json::string("insufficient signals to trigger evolution")),
  )

  // 对照：同一份参数，只把强度改成 Full，就能产生提案。
  // 这里重新走一次 scan_plugins 而不是直接把注册表搬过去 ——
  // 对照组的价值在于「只变强度这一个变量」，其余步骤完全相同。
  let full = full_intensity_state(tmp)
  ignore(send(full, call_line(3, "scan_plugins", { "force_rescan": true })))
  let resp2 = send(full, call_line(4, "propose_evolution", args))
  let body2 = obj(tool_payload(resp2))
  assert_true(body2.contains("proposal"))
}

///|
/// 空目录 / 不存在的路径：`scan_plugins` 必须成功返回 0，而不是 isError。
/// 对应 legacy tests/scanner.test.ts L72-77「不可抛」的断言。
async test "scanning an empty or missing root succeeds with zero plugins" {
  let tmp = @fs.tmpdir(prefix="evo-mcp-")
  defer @fs.rmdir(tmp, recursive=true)
  let paths = @store.DataPaths::at(tmp)
  let state = ServerState::with_scan_config(
    paths,
    @scanner.ScanConfig::custom(
      [@util.path_join(tmp, "does-not-exist")],
      paths.plugin_cache(),
    ),
  )
  let resp = send(state, call_line(1, "scan_plugins", Json::empty_object()))
  assert_false(is_tool_error(resp))
  assert_eq(obj(tool_payload(resp)).get("plugin_count"), Some(Json::number(0.0)))
}

///|
/// `list_proposals` 的 `limit` 参数真的生效，且**过滤顺序是 status → plugin_id → limit**
/// （limit 最后，对齐 legacy store/index.ts L118-124）。
///
/// 顺序错了的表现很隐蔽：先 limit 再过滤，会让「limit=1 + status=pending」
/// 在最新一条恰好不是 pending 时返回空，而正确答案是 1 条。
async test "list_proposals applies limit after the other filters" {
  let tmp = @fs.tmpdir(prefix="evo-mcp-")
  defer @fs.rmdir(tmp, recursive=true)
  let paths = @store.DataPaths::at(tmp)
  let state = ServerState::with_scan_config(
    paths,
    @scanner.ScanConfig::custom([tmp], paths.plugin_cache()),
  )

  // 直接往共享的 ProposalStore 里塞两条 pending 提案
  for i = 0; i < 2; i = i + 1 {
    state.proposals.save(
      seed_proposal("evo-limit-\{i}", @types.ProposalStatus::Pending),
    )
  }
  state.proposals.save(
    seed_proposal("evo-limit-done", @types.ProposalStatus::Rejected),
  )

  let all = send(state, call_line(1, "list_proposals", { "limit": 10 }))
  assert_eq(obj(tool_payload(all)).get("count"), Some(Json::number(3.0)))

  let limited = send(state, call_line(2, "list_proposals", { "limit": 1 }))
  assert_eq(obj(tool_payload(limited)).get("count"), Some(Json::number(1.0)))

  // status 过滤 + limit：两条 pending 里取 1 条（若先 limit 后过滤会得 0 条）
  let both = send(
    state,
    call_line(
      3,
      "list_proposals",
      { "status": Json::string(@types.ProposalStatus::Pending.wire_name()), "limit": 1 },
    ),
  )
  assert_eq(obj(tool_payload(both)).get("count"), Some(Json::number(1.0)))

  // 缺省 limit == 10（default_limit）
  let defaulted = send(state, call_line(4, "list_proposals", Json::empty_object()))
  assert_eq(obj(tool_payload(defaulted)).get("count"), Some(Json::number(3.0)))
}

///|
/// 造一条最小可用的提案，供 store 层面的断言使用。
/// 字段形状与 executor_wbtest 的 `make_proposal` 一致。
fn seed_proposal(
  proposal_id : String,
  status : @types.ProposalStatus,
) -> @types.EvolutionProposal {
  let etype = @types.EvolutionType::InterfaceSimplification
  {
    proposal_id,
    plugin_id: "demo-plugin-1.2.3",
    status,
    created_at: @util.now_ms(),
    trigger_signals: [],
    evolution_type: etype,
    matt_pocock_principle: etype.principle(),
    proposed_changes: [
      @types.Change::MergeTools(
        [
          {
            new_tool: "smart_fill",
            merged_from: ["navigate", "click"],
            new_interface: {
              params: ["url", "selector"],
              description: "One-stop form filling",
              defaults: None,
            },
            backward_compatible: true,
          },
        ],
      ),
    ],
    expected_benefits: etype.expected_benefits(),
    validation_plan: {
      test_scenarios: ["form filling"],
      success_criteria: "success_rate >= 95%",
      rollback_strategy: "keep previous version 30 days",
      validation_levels: [
        {
          level: @types.ValidationLevelTag::T0,
          description: "type check",
          automated: true,
          timeout_ms: Some(1000),
        },
      ],
    },
    risk_assessment: {
      breaking_changes: false,
      backward_compatible: true,
      migration_effort: @types.MigrationEffort::Low,
      affected_users: 0,
      rollback_complexity: @types.RollbackComplexity::Simple,
    },
    signature: "demo-plugin-interface-simplification",
    confidence: @types.Confidence::Medium,
  }
}

///|
/// 非法状态迁移经**工具通道**暴露出来的消息，必须与
/// legacy store/index.ts L147 逐字一致 —— legacy tests/executor.test.ts
/// L166-171 就是按这个字符串断言的。
async test "an illegal transition surfaces the legacy store message" {
  let tmp = @fs.tmpdir(prefix="evo-mcp-")
  defer @fs.rmdir(tmp, recursive=true)
  let paths = @store.DataPaths::at(tmp)
  let state = ServerState::with_scan_config(
    paths,
    @scanner.ScanConfig::custom([tmp], paths.plugin_cache()),
  )
  // completed 是终态
  state.proposals.save(
    seed_proposal("evo-done", @types.ProposalStatus::Completed),
  )
  let resp = send(
    state,
    call_line(1, "approve_proposal", { "proposal_id": "evo-done" }),
  )
  assert_eq(is_tool_error(resp), true)
  assert_eq(
    obj(tool_payload(resp)).get("error"),
    Some(
      Json::string(
        "Illegal proposal status transition: completed → approved",
      ),
    ),
  )
}

///|
/// 工具错误必须**同时**写 stderr（可观测性）并回 isError（协议）。
/// 这里只能验证后者不依赖前者 —— 即 `call_tool` 的 catch 分支里
/// 日志失败也不会改变响应形状。做法：连续触发多次错误，每次都拿到完整响应。
async test "repeated tool failures each still produce a well-formed response" {
  let tmp = @fs.tmpdir(prefix="evo-mcp-")
  defer @fs.rmdir(tmp, recursive=true)
  let state = isolated_state(tmp)
  for i = 0; i < 5; i = i + 1 {
    let resp = send(state, call_line(i, "propose_evolution", { "plugin_id": "ghost" }))
    assert_eq(is_tool_error(resp), true)
    assert_eq(obj(resp).get("id"), Some(Json::number(i.to_double())))
    // 每次都能重新解析（响应始终合法）
    ignore(@json.parse(resp.stringify()))
  }
}
