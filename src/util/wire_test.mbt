///|
/// `WireEnum` 的机制测试。
///
/// 这里用一个测试本地的三色枚举验证「表 → 编解码 → schema」这条链路本身；
/// 17 个真实业务枚举的逐变体往返断言放在 `types/wire_test.mbt`，
/// 那样一来「表是否覆盖了枚举的全部变体」这个最易出错的问题就由 types 包负责把关。
///
/// 注意：本仓一律用 `derive(Debug)` 而非 `derive(Show)` ——
/// 后者已被工具链标记为 deprecated（"Use derive(Debug) or manually implement Show"）。

enum Color {
  Red
  Green
  Blue
} derive(Eq, Debug)

let color_wire : @util.WireEnum[Color] = @util.WireEnum::of(
  [("red", Red), ("green", Green), ("blue", Blue)],
)

///|
/// `JsonPath` 没有公开构造器（只能由 `add_key` / `add_index` 扩展），
/// 所以 `decode` 无法被直接调用。用一个 FromJson 包装把它接到
/// `@json.from_json` 上 —— 这也正是 types 包里 17 张表的真实用法。
struct ColorBox {
  value : Color
}

impl @json.FromJson for ColorBox with fn from_json(json, path) {
  { value: @util.WireEnum::decode(color_wire, json, path), }
}

///|
/// `@json.from_json` 带标签可选参数 `path?`，故不能被部分应用（工具链报
/// "Function with labelled arguments can only be applied directly"）。
/// 必须靠类型标注让它直接应用。这个 helper 把「期望解码失败」收敛成一处。
fn decode_fails(json : Json) -> Bool {
  try {
    let box : ColorBox = @json.from_json(json)
    ignore(box)
    false
  } catch {
    _ => true
  }
}

test "WireEnum names preserves table order for MCP inputSchema enum arrays" {
  json_inspect(color_wire.names(), content=["red", "green", "blue"])
}

test "WireEnum name_of and encode produce the wire string, not a tagged array" {
  // 这条断言就是 D3 的反面教材：derive(ToJson) 会给出 ["Green"]，
  // 而 WireEnum 必须给出 "green"。
  assert_eq(color_wire.name_of(Green), "green")
  inspect(color_wire.encode(Green).stringify(), content="\"green\"")
  inspect(color_wire.encode(Red).stringify(), content="\"red\"")
  inspect(color_wire.encode(Blue).stringify(), content="\"blue\"")
}

test "WireEnum decode round-trips every variant" {
  for c in [Red, Green, Blue] {
    let box : ColorBox = @json.from_json(color_wire.encode(c))
    assert_eq(box.value, c)
  }
}

test "WireEnum decode rejects an unknown value" {
  assert_true(decode_fails(Json::string("purple")))
}

test "WireEnum decode rejects a non-string value" {
  assert_true(decode_fails(Json::boolean(true)))
  assert_true(decode_fails(Json::null()))
}

///|
/// 错误消息必须列出全部合法值 —— 这条消息会经 MCP 的 isError 响应回到 LLM 面前，
/// 列出合法值才能让模型自我纠正，而不是盲目重试。
test "WireEnum decode error message lists the legal values" {
  let msg = try {
    let box : ColorBox = @json.from_json(Json::string("purple"))
    ignore(box)
    ""
  } catch {
    e => e.to_string()
  }
  assert_true(msg.contains("purple"))
  assert_true(msg.contains("red"))
  assert_true(msg.contains("green"))
  assert_true(msg.contains("blue"))
}
