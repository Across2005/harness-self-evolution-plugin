///|
/// 7 个工具的 JSON Schema 不变量测试。
///
/// 核心目的不是「断言每个键都写对了」（那是把实现抄一遍，改一处要改两处），
/// 而是钉住**三条会静默漂移的约束**：
/// 1. `enum` 数组必须与 `types/wire_tables.mbt` 的 `names()` **是同一份数据**。
///    TS 版把取值域写在 zod 的 `z.enum([...])` 里，同一批字符串又在
///    `types/index.ts` 的联合类型里写了一遍 —— 两处漂移不会有任何报错，
///    表现为「schema 说合法，解码却拒绝」。
/// 2. Schema 里声明的 `default` 必须与 handler 实际用的 `unwrap_or` 值一致。
///    手写 Schema 的 `default` 只是**声明给 LLM 看**，真正的补齐在 handler 里，
///    两者不一致会让 LLM 依 schema 推理出错误行为。
/// 3. 7 个工具的名字与顺序必须与 legacy-ts/package.json 的 `mcp.tools` 一致 ——
///    这是对外契约，客户端可能按名字硬编码。

///|
/// 从 Schema 里取出某个属性的 `enum` 数组。
fn enum_of(schema : Json, prop : String) -> Array[String] {
  guard schema is Object(s) else { abort("schema must be an object") }
  let props = s.get("properties")
  guard props is Some(Object(p)) else { abort("properties must be an object") }
  let one = p.get(prop)
  guard one is Some(Object(f)) else { abort("property \{prop} must exist") }
  let values = f.get("enum")
  guard values is Some(Array(a)) else {
    abort("property \{prop} must have enum")
  }
  let out : Array[String] = []
  for v in a {
    guard v is String(s2) else { abort("enum entries must be strings") }
    out.push(s2)
  }
  out
}

///|
/// 从 Schema 里取出某个属性的 `default`。
fn default_of(schema : Json, prop : String) -> Json {
  guard schema is Object(s) else { abort("schema must be an object") }
  let props = s.get("properties")
  guard props is Some(Object(p)) else { abort("properties must be an object") }
  let one = p.get(prop)
  guard one is Some(Object(f)) else { abort("property \{prop} must exist") }
  f.get("default").unwrap_or(Json::null())
}

///|
fn required_of(schema : Json) -> Array[String] {
  guard schema is Object(s) else { abort("schema must be an object") }
  let req = s.get("required")
  guard req is Some(Array(a)) else { abort("required must be an array") }
  let out : Array[String] = []
  for v in a {
    guard v is String(s2) else { abort("required entries must be strings") }
    out.push(s2)
  }
  out
}

// ============================================================================
// 约束 1：enum 与 wire 表同源
// ============================================================================

///|
/// `list_proposals.status` 的取值域 == `proposal_status_wire.names()`。
/// 这条断言的意义在于**它不写字面量**：往 wire 表加一个状态，
/// schema 自动跟着变，测试自动跟着过；而两处各写一遍的话，
/// 加了表却忘了 schema，客户端就会看到「合法值」被服务器拒绝。
test "list_proposals.status enum is the proposal_status wire table" {
  assert_eq(
    enum_of(list_proposals_schema(), "status"),
    @types.proposal_status_wire.names(),
  )
}

///|
/// `get_plugin_metrics.time_range` 同理。
test "get_plugin_metrics.time_range enum is the time_range wire table" {
  assert_eq(
    enum_of(get_metrics_schema(), "time_range"),
    @types.time_range_wire.names(),
  )
}

///|
/// ★ 交叉验证：wire 表的合法值必须**真的能被 FromJson 解码**。
/// 这是「schema 说合法但解码拒绝」这类矛盾的直接否证 ——
/// 遍历 schema 声明的每一个取值，逐个喂给 `from_json`，一个都不许失败。
/// TS 版无法写这条测试（zod 与 union type 之间没有可编程的桥梁）。
test "every enum value the schema advertises is decodable" {
  let status_values = enum_of(list_proposals_schema(), "status")
  for name in status_values {
    let j = Json::string(name)
    let decoded : @types.ProposalStatus = @json.from_json(j)
    // 解码后再编码必须拿回同一个字符串（往返闭合）
    assert_eq(ToJson::to_json(decoded), j)
  }
  let range_values = enum_of(get_metrics_schema(), "time_range")
  for name in range_values {
    let j = Json::string(name)
    let decoded : @types.TimeRange = @json.from_json(j)
    assert_eq(ToJson::to_json(decoded), j)
  }
}

///|
/// 反向：wire 表里的名字**一个都不许多余**。
/// 若 schema 少声明一个合法值，LLM 就不会用它 —— 功能静默丢失。
test "the schema advertises exactly the wire vocabulary, no more no less" {
  assert_eq(
    enum_of(list_proposals_schema(), "status").length(),
    @types.proposal_status_wire.names().length(),
  )
  assert_eq(
    enum_of(get_metrics_schema(), "time_range").length(),
    @types.time_range_wire.names().length(),
  )
}

// ============================================================================
// 约束 2：声明的 default 与 handler 实际用的默认值一致
// ============================================================================

///|
test "scan_plugins declares default_force_rescan" {
  assert_eq(
    default_of(scan_plugins_schema(), "force_rescan"),
    Json::boolean(default_force_rescan),
  )
}

///|
test "get_plugin_metrics declares default_time_range" {
  assert_eq(
    default_of(get_metrics_schema(), "time_range"),
    Json::string(default_time_range.wire_name()),
  )
}

///|
test "execute_evolution declares default_dry_run" {
  assert_eq(
    default_of(execute_evolution_schema(), "dry_run"),
    Json::boolean(default_dry_run),
  )
}

///|
test "list_proposals declares default_limit" {
  assert_eq(
    default_of(list_proposals_schema(), "limit"),
    Json::number(default_limit.to_double()),
  )
}

///|
/// 这四个默认值必须与 legacy-ts/src/mcp/server.ts L27-51 的 zod `.default(x)`
/// 逐一对应。把 TS 的字面量写在这里（而不是引用常量）是**刻意的**：
/// 常量改名不会让这条测试失效，于是它真的在守「移植有没有走样」。
test "the four defaults match the legacy zod defaults verbatim" {
  assert_false(default_force_rescan) // TS L28 .default(false)
  assert_eq(default_time_range, @types.TimeRange::All) // TS L34 .default('all')
  assert_false(default_dry_run) // TS L44 .default(false)
  assert_eq(default_limit, 10) // TS L50 .default(10)
}

// ============================================================================
// 约束 3：必填字段与对外契约
// ============================================================================

///|
/// 必填项集合。缺必填字段时 `FromJson` 会 raise，
/// 由 `call_tool` 统一转成 isError（不变量④）—— 见 tools_wbtest。
test "required fields match the legacy zod shapes" {
  assert_eq(required_of(scan_plugins_schema()), []) // 两个参数都可选
  assert_eq(required_of(get_metrics_schema()), ["plugin_id"])
  assert_eq(required_of(propose_evolution_schema()), ["plugin_id"])
  assert_eq(required_of(execute_evolution_schema()), ["proposal_id"])
  assert_eq(required_of(list_proposals_schema()), []) // 三个参数都可选
  assert_eq(required_of(proposal_id_schema()), ["proposal_id"])
}

///|
/// 7 个工具的名字与**顺序**。顺序即 `tools/list` 的返回顺序，
/// 与 legacy-ts/package.json L58-66 的 `mcp.tools` 逐项、同序一致。
test "the seven tool names appear in the legacy order" {
  let names : Array[String] = []
  for t in tools() {
    names.push(t.name)
  }
  assert_eq(names, [
    "scan_plugins", "get_plugin_metrics", "propose_evolution", "execute_evolution",
    "list_proposals", "approve_proposal", "reject_proposal",
  ])
}

///|
/// 每个工具都必须有非空描述与合法 Schema —— LLM 完全靠这两样决定怎么调用，
/// 空描述会让工具在实际使用中形同不存在。
test "every tool has a non-empty description and an object schema" {
  for t in tools() {
    assert_true(t.description.length() > 0)
    guard t.schema is Object(s) else {
      abort("\{t.name}: schema must be an object")
    }
    assert_eq(s.get("type"), Some(Json::string("object")))
    assert_true(s.contains("properties"))
    assert_true(s.contains("required"))
  }
}

///|
/// `find_tool` 对全部 7 个名字都能命中，对不存在的名字返回 None。
/// 后者是 -32602 的触发条件，见 tools_wbtest。
///
/// 这里用 `is None` 而不是 `assert_eq(.., None)`：`Tool` 持一个**函数字段**
/// （`handler`），函数没有相等性，因而 `Tool` 无法 `derive(Eq)` ——
/// 这也是它刻意不 derive 的原因：比较两个工具没有意义，只能比名字。
test "find_tool resolves every declared name and nothing else" {
  for t in tools() {
    match find_tool(t.name) {
      Some(found) => assert_eq(found.name, t.name)
      None => abort("\{t.name} must be findable")
    }
  }
  assert_true(find_tool("no_such_tool") is None)
  assert_true(find_tool("") is None)
  // 大小写敏感：MCP 工具名是精确匹配，不做归一化
  assert_true(find_tool("SCAN_PLUGINS") is None)
}

///|
/// `tools/list` 的响应体形状：`{tools:[{name,description,inputSchema}]}`，
/// 不含 `nextCursor`（7 个工具远小于任何客户端的页大小，不分页）。
test "tools_list_result has the MCP tool-list shape" {
  let resp = tools_list_result()
  guard resp is Object(o) else { abort("expected an object") }
  assert_false(o.contains("nextCursor"))
  let list = o.get("tools")
  guard list is Some(Array(a)) else { abort("tools must be an array") }
  assert_eq(a.length(), 7)
  for entry in a {
    guard entry is Object(t) else { abort("each tool must be an object") }
    assert_true(t.contains("name"))
    assert_true(t.contains("description"))
    assert_true(t.contains("inputSchema"))
  }
}
