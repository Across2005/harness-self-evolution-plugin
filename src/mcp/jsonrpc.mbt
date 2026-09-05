///|
/// JSON-RPC 2.0 的**纯函数**核心：`Json -> Json?`，不触碰 stdio。
///
/// 取代 `@modelcontextprotocol/sdk`（legacy-ts/src/mcp/server.ts L16-17）。
/// MoonBit 生态没有 MCP SDK，协议必须手写；而手写协议最大的风险是
/// 「bug 只能靠端到端手测发现」。把协议层做成纯函数后，
/// 握手、通知、错误码、id 双形态这些细节全部可以在 `moon test` 里穷举，
/// 只有最外面那层 stdin/stdout 循环需要实机验证。
///
/// **五条必须逐条做对的协议细节**（每一条都是真实的踩坑点）：
/// 1. **通知（无 `id`）绝不能回响应**。`notifications/initialized` 若误回一条
///    result，多数 MCP 客户端会直接报协议错误并断开。
/// 2. `id` 可以是数字**或字符串**，必须原样回显，不做类型转换。
/// 3. 必须支持 `ping` → `{}`（MCP 规范要求，用于探活）。
/// 4. 解析失败回 `-32700`，未知方法回 `-32601`，参数错误回 `-32602`。
/// 5. **不做初始化门禁**（决策 D15）：MCP 客户端实现差异很大，
///    拒绝 `initialize` 之前的 `tools/list` 只会带来无收益的兼容性风险。
///    采取「宽进」策略：任何方法都直接处理。

///|
/// 协议版本常量。
pub let jsonrpc_version : String = "2.0"

///|
/// 客户端未声明 `protocolVersion` 时回给它的默认值。
/// 选 `2024-11-05` 是因为它是生态覆盖最广的版本。
///
/// **协商策略是「回显」**：客户端声明了什么就回什么（见 `initialize_result`）。
/// 这比「回自己支持的最新版本」更安全 —— 后者会让客户端以为
/// 我们实现了某个其实没实现的版本。
pub let default_protocol_version : String = "2024-11-05"

///|
/// 服务名与版本。名字逐字取自 legacy-ts/src/mcp/server.ts L85；
/// 版本随「运行时从 Node 换成 native exe」这一 breaking change 升到 2.0.0。
pub let server_name : String = "harness-self-evolution"

pub let server_version : String = "2.0.0"

// JSON-RPC 2.0 的标准错误码
///|
/// 收到非法 JSON
pub let code_parse_error : Int = -32700

///|
/// 收到的 JSON 不是合法的请求对象
pub let code_invalid_request : Int = -32600

///|
/// 方法不存在
pub let code_method_not_found : Int = -32601

///|
/// 参数无效（含缺失必填字段）
pub let code_invalid_params : Int = -32602

///|
/// 服务器内部错误
pub let code_internal_error : Int = -32603

///|
/// 一条已解析的 JSON-RPC 消息。
///
/// 字段名用 `method_name` 而不是 `method`：后者是 MoonBit 的**保留字**
/// （工具链报 reserved_keyword："reserved for possible future use"）。
pub(all) struct RpcRequest {
  /// `None` 表示**没有 id 字段**，即这是一条通知（绝不能回响应）。
  /// 注意与 `Some(Null)` 区分：后者是「id 显式为 null」的畸形请求。
  id : Json?
  method_name : String
  params : Json
} derive(Eq, Debug)

///|
/// 是否为通知（无 id）。
pub fn RpcRequest::is_notification(self : RpcRequest) -> Bool {
  self.id is None
}

///|
/// 把一条 JSON 消息解析为 `RpcRequest`；不合法则返回 `None`。
///
/// 宽松处理：`params` 缺失时按空对象处理（MCP 客户端对 `tools/list`
/// 常常不带 params）；`method` 缺失或不是字符串才算非法。
pub fn parse_message(json : Json) -> RpcRequest? {
  guard json is Object(obj) else { return None }
  let method_name = match obj.get("method") {
    Some(String(m)) => m
    _ => return None
  }
  let params = obj.get("params").unwrap_or(Json::empty_object())
  // `id` 键**存在与否**决定请求还是通知，故不能用 unwrap_or 折叠掉
  let id = match obj.contains("id") {
    true => Some(obj.get("id").unwrap_or(Json::null()))
    false => None
  }
  Some({ id, method_name, params, })
}

///|
/// 构造成功响应。`id` 原样回显（可能是数字或字符串）。
pub fn result_msg(id : Json?, result : Json) -> Json {
  {
    "jsonrpc": Json::string(jsonrpc_version),
    "id": id.unwrap_or(Json::null()),
    "result": result,
  }
}

///|
/// 构造错误响应。
pub fn error_msg(id : Json?, code : Int, message : String) -> Json {
  {
    "jsonrpc": Json::string(jsonrpc_version),
    "id": id.unwrap_or(Json::null()),
    "error": {
      "code": Json::number(code.to_double()),
      "message": Json::string(message),
    },
  }
}

///|
/// `initialize` 的响应体。
///
/// **回显客户端声明的 protocolVersion**（若声明了且是字符串），
/// 否则回 `default_protocol_version`。理由见该常量的注释。
pub fn initialize_result(params : Json) -> Json {
  let requested = match params {
    Object(obj) =>
      match obj.get("protocolVersion") {
        Some(String(v)) => v
        _ => default_protocol_version
      }
    _ => default_protocol_version
  }
  {
    "protocolVersion": Json::string(requested),
    "capabilities": { "tools": Json::empty_object() },
    "serverInfo": {
      "name": Json::string(server_name),
      "version": Json::string(server_version),
    },
  }
}
