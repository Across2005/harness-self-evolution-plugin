///|
/// 字符串枚举的统一 wire 编解码表 —— 本仓「词汇即文档」的物理载体。
///
/// **为什么不用 `derive(ToJson)`**：`core/json` 对 enum 生成的是 tagged-array。
/// 实证见 `core/json/from_to_json_test.mbt` 的 `Expr` 测试：
/// `Expr::Add(Val("x"), Val("y"))` → `["Add",["Val","x"],["Val","y"]]`。
/// 于是 `EvolutionType::InterfaceSimplification` 会被序列化成
/// `["InterfaceSimplification"]` 而不是 `"interface_simplification"` ——
/// 这会摧毁 CONTEXT.md L29-49 规定的 snake_case 词汇表，
/// 也会让 MCP 工具返回给 LLM 的 JSON 变得难以理解。
///
/// **一张表同时驱动三件事**（Deep Module：窄接口、厚实现）：
/// 1. JSONL 序列化（`encode` / `decode`）
/// 2. MCP `inputSchema` 的 `enum` 数组（`names`）
/// 3. 解码失败时错误消息里的合法值列表（`decode` 的 raise 分支）
///
/// 于是「词汇表」在代码里只有一份，CONTEXT.md 与 wire 格式不可能漂移。

///|
/// 字符串枚举 ↔ wire 名的双向表。`T` 需可相等比较以支持反查。
pub struct WireEnum[T] {
  table : Array[(String, T)]
}

///|
/// 从 `(wire 名, 值)` 数组构造。表必须覆盖该枚举的**全部**变体，
/// 否则 `name_of` 会在运行时 abort —— 这属于编程错误而非输入错误，
/// 由 `types/wire_test.mbt` 的表驱动往返测试在 CI 阶段拦住。
pub fn[T] WireEnum::of(table : Array[(String, T)]) -> WireEnum[T] {
  { table, }
}

///|
/// 值 → wire 名。表不全时 abort。
pub fn[T : Eq] WireEnum::name_of(self : WireEnum[T], value : T) -> String {
  for pair in self.table {
    let (name, v) = pair
    if v == value {
      return name
    }
  }
  abort("WireEnum::name_of: value is absent from the wire table (table is incomplete)")
}

///|
/// 值 → `Json`（一个 JSON 字符串）。
pub fn[T : Eq] WireEnum::encode(self : WireEnum[T], value : T) -> Json {
  Json::string(self.name_of(value))
}

///|
/// `Json` → 值。非字符串或未知字符串都 raise `JsonDecodeError`，
/// 错误消息里列出全部合法值，便于 LLM 自我纠正。
///
/// 注意此处**不需要** `T : Eq`：反向查找比较的是 wire 名（String），
/// 而不是 `T` 本身。只有 `name_of` / `encode` 的正向查找才需要 Eq。
pub fn[T] WireEnum::decode(
  self : WireEnum[T],
  json : Json,
  path : @json.JsonPath,
) -> T raise @json.JsonDecodeError {
  guard json is String(raw) else {
    raise @json.JsonDecodeError((path, "expected a JSON string"))
  }
  for pair in self.table {
    let (name, v) = pair
    if name == raw {
      return v
    }
  }
  raise @json.JsonDecodeError(
    (
      path,
      "unknown value \"\{raw}\"; expected one of: \{self.names().join(", ")}",
    ),
  )
}

///|
/// 按 wire 名查找，找不到返回 `None`（不 raise）。
///
/// 与 `decode` 的分工：`decode` 用于 **FromJson 路径**（错误必须带 JsonPath 上抛，
/// 让调用方知道是哪个字段坏了）；`find_by_name` 用于 **容错配置解析**
/// （如读 plugin.json 时遇到未知取值应回退到默认值，而不是让整个插件启动失败）。
pub fn[T] WireEnum::find_by_name(self : WireEnum[T], name : String) -> T? {
  for pair in self.table {
    let (n, v) = pair
    if n == name {
      return Some(v)
    }
  }
  None
}

///|
/// 全部 wire 名，顺序与构造表一致。
/// 供 MCP `inputSchema` 的 `enum` 数组复用，避免 schema 与类型两处各写一份词汇表。
pub fn[T] WireEnum::names(self : WireEnum[T]) -> Array[String] {
  self.table.map(fn(pair) { pair.0 })
}
