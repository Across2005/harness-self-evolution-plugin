///|
/// 7 个 MCP 工具的 JSON Schema 与参数解码。
/// 取代 legacy-ts/src/mcp/server.ts L27-55 的 6 个 Zod raw shape。
///
/// MoonBit 没有 zod，Schema 手写。这看起来是退步，实则消除了一处重复：
/// TS 版把「取值域」写在 zod 里（`z.enum([...])`），
/// 而同一批字符串又在 `types/index.ts` 的联合类型里写了一遍，
/// 两处漂移不会有任何报错。新版的 `enum` 数组直接取自
/// `types/wire_tables.mbt` 的 `names()` —— **与 JSONL 序列化用的是同一张表**，
/// 于是「schema 说合法但解码拒绝」这类矛盾在结构上不可能出现。
///
/// **默认值处理**：zod 的 `.default(x)` 会在解析阶段补齐，
/// 手写 Schema 只是**声明** `default` 供 LLM 阅读，真正的补齐发生在
/// 各 handler 里的 `unwrap_or`。为避免漏补，默认值只在一处定义
/// （见 `defaults` 段落），Schema 与 handler 都从那里取。

// ----------------------------------------------------------------------------
// 默认值：唯一定义处
// ----------------------------------------------------------------------------

///|
/// `scan_plugins.force_rescan` 的默认值（TS L28 `.default(false)`）。
pub let default_force_rescan : Bool = false

///|
/// `get_plugin_metrics.time_range` 的默认值（TS L34 `.default('all')`）。
pub let default_time_range : @types.TimeRange = @types.TimeRange::All

///|
/// `execute_evolution.dry_run` 的默认值（TS L44 `.default(false)`）。
pub let default_dry_run : Bool = false

///|
/// `list_proposals.limit` 的默认值（TS L50 `.default(10)`）。
pub let default_limit : Int = 10

// ----------------------------------------------------------------------------
// Schema 构造
// ----------------------------------------------------------------------------

///|
fn object_schema(properties : Json, required : Array[String]) -> Json {
  {
    "type": "object",
    "properties": properties,
    "required": ToJson::to_json(required),
    // 声明给 LLM 看，帮助它不要臆造参数；解析侧**不强制**
    // （derive(FromJson) 只读它认识的键，多出来的自然被忽略），
    // 以免某些客户端附加的元数据字段被误判为非法请求。
    "additionalProperties": false,
  }
}

///|
fn str_prop(description : String) -> Json {
  { "type": "string", "description": Json::string(description) }
}

///|
fn bool_prop(description : String, default : Bool) -> Json {
  {
    "type": "boolean",
    "description": Json::string(description),
    "default": Json::boolean(default),
  }
}

///|
fn number_prop(description : String, default : Int) -> Json {
  {
    "type": "number",
    "description": Json::string(description),
    "default": Json::number(default.to_double()),
  }
}

///|
fn string_array_prop(description : String) -> Json {
  {
    "type": "array",
    "items": { "type": "string" },
    "description": Json::string(description),
  }
}

///|
/// 枚举属性。取值域直接来自 wire 表 —— 与 JSONL 序列化共用同一份词汇。
fn enum_prop(description : String, values : Array[String]) -> Json {
  {
    "type": "string",
    "description": Json::string(description),
    "enum": ToJson::to_json(values),
  }
}

// ----------------------------------------------------------------------------
// 7 个工具的 Schema（描述文案逐字取自 legacy-ts/src/mcp/server.ts L126-289）
// ----------------------------------------------------------------------------

///|
/// `scan_plugins`（TS L27-30）。两个参数都非必填。
pub fn scan_plugins_schema() -> Json {
  object_schema(
    {
      "force_rescan": bool_prop(
        "强制重新扫描，即使已有缓存", default_force_rescan,
      ),
      "target_paths": string_array_prop("自定义扫描路径（可选）"),
    },
    [],
  )
}

///|
/// `get_plugin_metrics`（TS L32-35）。`plugin_id` 必填。
pub fn get_metrics_schema() -> Json {
  object_schema(
    {
      "plugin_id": str_prop("插件 ID（如 browser-use-0.4.1）"),
      "time_range": {
        "type": "string",
        "description": "时间范围",
        "enum": ToJson::to_json(@types.time_range_wire.names()),
        "default": Json::string(default_time_range.wire_name()),
      },
    },
    ["plugin_id"],
  )
}

///|
/// `propose_evolution`（TS L37-40）。`plugin_id` 必填。
pub fn propose_evolution_schema() -> Json {
  object_schema(
    {
      "plugin_id": str_prop("插件 ID"),
      "signals": string_array_prop(
        "手动提供的信号描述列表（可选）",
      ),
    },
    ["plugin_id"],
  )
}

///|
/// `execute_evolution`（TS L42-45）。`proposal_id` 必填。
pub fn execute_evolution_schema() -> Json {
  object_schema(
    {
      "proposal_id": str_prop("提案 ID"),
      "dry_run": bool_prop(
        "试运行模式（不实际修改文件）", default_dry_run,
      ),
    },
    ["proposal_id"],
  )
}

///|
/// `list_proposals`（TS L47-51）。三个参数都非必填。
pub fn list_proposals_schema() -> Json {
  object_schema(
    {
      "status": enum_prop(
        "按状态过滤",
        @types.proposal_status_wire.names(),
      ),
      "plugin_id": str_prop("按插件 ID 过滤"),
      "limit": number_prop("返回数量限制", default_limit),
    },
    [],
  )
}

///|
/// `approve_proposal` / `reject_proposal`（TS L53-55）。
pub fn proposal_id_schema() -> Json {
  object_schema({ "proposal_id": str_prop("提案 ID") }, ["proposal_id"])
}

// ----------------------------------------------------------------------------
// 参数结构体
// ----------------------------------------------------------------------------
//
// 全部字段都是 Option：derive(FromJson) 对缺失的键会还原成 None
// （实证见 core/json 的 "optional field round trip" 用例），
// 于是「客户端没传」与「客户端传了 null」都落到同一条默认值路径上。
// 必填字段（如 plugin_id）不用 Option —— 缺失时 FromJson 直接 raise，
// 由 dispatch 统一转成 isError 响应（CONTEXT.md 不变量④）。

///|
/// `scan_plugins` 的参数。
pub(all) struct ScanPluginsArgs {
  force_rescan : Bool?
  target_paths : Array[String]?
} derive(Debug, @json.FromJson)

///|
/// `get_plugin_metrics` 的参数。
pub(all) struct GetMetricsArgs {
  plugin_id : String
  time_range : @types.TimeRange?
} derive(Debug, @json.FromJson)

///|
/// `propose_evolution` 的参数。
pub(all) struct ProposeEvolutionArgs {
  plugin_id : String
  signals : Array[String]?
} derive(Debug, @json.FromJson)

///|
/// `execute_evolution` 的参数。
pub(all) struct ExecuteEvolutionArgs {
  proposal_id : String
  dry_run : Bool?
} derive(Debug, @json.FromJson)

///|
/// `list_proposals` 的参数。
pub(all) struct ListProposalsArgs {
  status : @types.ProposalStatus?
  plugin_id : String?
  limit : Int?
} derive(Debug, @json.FromJson)

///|
/// `approve_proposal` / `reject_proposal` 的参数。
pub(all) struct ProposalIdArgs {
  proposal_id : String
} derive(Debug, @json.FromJson)
