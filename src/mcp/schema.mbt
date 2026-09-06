///|
/// 10 个 MCP 工具的 JSON Schema 与参数解码。
/// 取代 legacy-ts/src/mcp/server.ts L27-55 的 6 个 Zod raw shape。
///
/// 前 7 个工具与 legacy-ts/package.json 的 `mcp.tools` 逐项同序，
/// 后 3 个（create/list/delete_sub_agent）是 v2.1 子 Agent 工厂新增，
/// 无 legacy 对应物（见 docs/subagent-factory.md）。
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

///|
/// `create_sub_agent.scope` / `delete_sub_agent.scope` 的默认值（v2.1）。
/// 默认写**插件数据目录**而非用户目录：跨出数据根的动作必须显式选择。
pub let default_sub_agent_scope : @types.AgentScope = @types.AgentScope::Plugin

///|
/// `create_sub_agent.overwrite` 的默认值（v2.1）：同名已存在时报错而非覆盖，
/// 破坏性动作必须显式声明（与 ProposalStore 状态机的显式性原则一致）。
pub let default_sub_agent_overwrite : Bool = false

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
/// 带下界的整数属性。★ 评审 W3：`list_proposals.limit` 的合法域是 `>= 1` ——
/// 0 或负数会让 store 的 `list` 因 `out.length() >= limit` 恒真而**静默返回空**
/// （proposals.mbt L131），把「参数写错」伪装成「没有提案」。schema 里声明
/// `minimum` 是给 LLM 看的声明式约束；解析侧按「宽容」惯例不强制
/// （与 `object_schema` 的 `additionalProperties` 同一条注释）。
///
/// 只有这一个使用方，故不再保留无下界的 `number_prop`（避免 unused 警告）。
fn bounded_number_prop(description : String, default : Int, minimum : Int) -> Json {
  {
    "type": "number",
    "description": Json::string(description),
    "default": Json::number(default.to_double()),
    "minimum": Json::number(minimum.to_double()),
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
/// `limit` 带 `minimum: 1`（评审 W3，见 `bounded_number_prop`）。
pub fn list_proposals_schema() -> Json {
  object_schema(
    {
      "status": enum_prop(
        "按状态过滤",
        @types.proposal_status_wire.names(),
      ),
      "plugin_id": str_prop("按插件 ID 过滤"),
      "limit": bounded_number_prop("返回数量限制", default_limit, 1),
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
// v2.1 新增：子 Agent 工厂（无 legacy 对应物，描述文案取自 docs/subagent-factory.md）
// ----------------------------------------------------------------------------

///|
/// scope 属性的公共形状：enum 直接取 wire 表（不变量⑦）。
fn agent_scope_prop(description : String) -> Json {
  {
    "type": "string",
    "description": Json::string(description),
    "enum": ToJson::to_json(@types.agent_scope_wire.names()),
  }
}

///|
/// `create_sub_agent`（v2.1）。name / description / system_prompt 必填。
pub fn create_sub_agent_schema() -> Json {
  object_schema(
    {
      "name": str_prop(
        "子 Agent 名称，即文件名（不含 .md）：kebab-case，小写字母/数字/连字符，1-64 字符，不以 - 开头或结尾，无连续 --",
      ),
      "description": str_prop(
        "一句话职责描述（1-1024 字符，单行，写入 frontmatter）",
      ),
      "system_prompt": str_prop(
        "系统提示词，作为 .md 正文（1-65536 字符）",
      ),
      "tools": string_array_prop(
        "允许的工具名列表（可选；每项 1-64 字符且不含空白/逗号/方括号；空数组视为未指定）",
      ),
      "color": str_prop(
        "标识色（可选，仅小写字母 a-z，1-20 字符）",
      ),
      "scope": {
        "type": "string",
        "description": "写入位置：plugin 写入插件数据目录（默认）；user 会写入宿主的 ~/.zcode/agents/（跨出插件数据根，宿主会在后续会话加载该定义）",
        "enum": ToJson::to_json(@types.agent_scope_wire.names()),
        "default": Json::string(default_sub_agent_scope.wire_name()),
      },
      "overwrite": bool_prop(
        "同名定义已存在时是否覆盖（默认 false：报错而不是覆盖）",
        default_sub_agent_overwrite,
      ),
    },
    ["name", "description", "system_prompt"],
  )
}

///|
/// `list_sub_agents`（v2.1）。scope 非必填：缺省列出两个作用域。
pub fn list_sub_agents_schema() -> Json {
  object_schema(
    {
      "scope": agent_scope_prop(
        "过滤范围：plugin 只列插件数据目录，user 只列宿主用户目录；缺省两个作用域都列",
      ),
    },
    [],
  )
}

///|
/// `delete_sub_agent`（v2.1）。name 必填；scope 缺省 plugin。
pub fn delete_sub_agent_schema() -> Json {
  object_schema(
    {
      "name": str_prop("要删除的子 Agent 名称（不含 .md 后缀）"),
      "scope": agent_scope_prop(
        "在哪个作用域里删除：plugin（默认，插件数据目录）或 user（宿主的 ~/.zcode/agents/）",
      ),
    },
    ["name"],
  )
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

///|
/// `create_sub_agent` 的参数（v2.1）。
/// `tools` 传出的空数组在 handler 里按「未指定」处理（与 factory 的语义一致）。
pub(all) struct CreateSubAgentArgs {
  name : String
  description : String
  system_prompt : String
  tools : Array[String]?
  color : String?
  scope : @types.AgentScope?
  overwrite : Bool?
} derive(Debug, @json.FromJson)

///|
/// `list_sub_agents` 的参数（v2.1）。scope 缺省为 None = 两个作用域都列。
pub(all) struct ListSubAgentsArgs {
  scope : @types.AgentScope?
} derive(Debug, @json.FromJson)

///|
/// `delete_sub_agent` 的参数（v2.1）。scope 缺省为 plugin。
pub(all) struct DeleteSubAgentArgs {
  name : String
  scope : @types.AgentScope?
} derive(Debug, @json.FromJson)
