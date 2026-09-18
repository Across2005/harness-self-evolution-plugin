///|
/// 旧行兼容：缺 `decay_factor` 的信号必须解码成功，并取「无衰减」缺省 1.0。
///
/// 实测 2026-09-18：本机 `proposals.jsonl` 里最老那条提案的 4 行是旧 schema 写的
/// （`trigger_signals[0]` 没有 `decay_factor`），派生解码器把**整行**判为 corrupt 丢掉 →
/// `get_runtime_snapshot` 报 2 条提案、面板报 3 条：同一份文件两个数字。
/// 这条用例把「容忍缺失」钉死，避免有人把字段加回去又把旧数据变成不可读。
test "EvolutionSignal decodes rows written before decay_factor existed" {
  let legacy =
    #|{"strength":"medium","category":"pattern","description":"d","evidence":{"kind":"user_manual"},"ts":"1788841466366","plugin_id":"p-1"}
  let signal : EvolutionSignal = @json.from_json(@json.parse(legacy))
  assert_eq(signal.decay_factor, 1.0)
  assert_eq(signal.plugin_id, "p-1")
  assert_eq(signal.ts.to_string(), "1788841466366")
  assert_eq(signal.count, None)
  assert_eq(signal.tool, None)
}

///|
/// 容错**只放宽缺失**：新行里显式写的 `decay_factor` 必须原样保留，不得被缺省覆盖。
test "EvolutionSignal keeps an explicit decay_factor" {
  let fresh =
    #|{"strength":"strong","category":"struggle","description":"d","evidence":{"kind":"session","id":"s-1"},"ts":"1788841466366","plugin_id":"p-1","decay_factor":0.42}
  let signal : EvolutionSignal = @json.from_json(@json.parse(fresh))
  assert_eq(signal.decay_factor, 0.42)
  assert_eq(signal.strength, Strong)
  assert_eq(signal.evidence, Session("s-1"))
}
