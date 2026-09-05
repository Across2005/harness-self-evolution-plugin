///|
/// 风险评估、签名与置信度。取代 legacy-ts/src/engine/index.ts L550-650。
///
/// 全部是**同步纯函数**：TS 版把它们声明为 `private async` 方法
/// （L550, 575, 592, 611, 625, 643），但函数体里一个 await 都没有 ——
/// 那是 P21（无谓的 Promise 分配与 await 点）。

///|
/// 从变更集里挑出全部工具合并条目。
fn collect_merges(
  changes : ArrayView[@types.Change],
) -> Array[@types.ToolMerge] {
  let out : Array[@types.ToolMerge] = []
  for c in changes {
    match c {
      @types.Change::MergeTools(xs) =>
        for x in xs {
          out.push(x)
        }
      _ => ()
    }
  }
  out
}

///|
/// 从变更集里挑出全部参数简化条目。
fn collect_params(
  changes : ArrayView[@types.Change],
) -> Array[@types.ParamSimplification] {
  let out : Array[@types.ParamSimplification] = []
  for c in changes {
    match c {
      @types.Change::SimplifyParams(xs) =>
        for x in xs {
          out.push(x)
        }
      _ => ()
    }
  }
  out
}

///|
/// JSON 对象的键数；不是对象则为 0。
/// 取代 TS L582 的 `Object.keys(p.defaults).length`。
fn json_object_size(json : Json) -> Int {
  match json {
    Object(obj) => obj.length()
    _ => 0
  }
}

///|
/// 是否存在破坏性变更。取代 TS L575-587。
///
/// 两条判据逐一对应：
/// · 有任一工具合并**不**向后兼容（L577）
/// · 有任一参数简化，其默认值数量**少于**被移除的参数数量（L582）
///   —— 即存在「被移除却没有默认值兜底」的参数
pub fn has_breaking_changes(changes : ArrayView[@types.Change]) -> Bool {
  for m in collect_merges(changes) {
    if !m.backward_compatible {
      return true
    }
  }
  for p in collect_params(changes) {
    if json_object_size(p.defaults) < p.remove_params.length() {
      return true
    }
  }
  false
}

///|
/// 是否向后兼容。取代 TS L592-606。
///
/// ★ **这里做了一处有意的语义修正**（已记入 CONTEXT.md）：
/// TS 的实现是
/// ```ts
/// if (changes.merge_tools?.every(m => m.backward_compatible)) return true
/// if (changes.simplify_params?.every(p => p.remove_params.every(...))) return true
/// return false
/// ```
/// 当 `ProposedChanges` 为**空对象**时，两个 `?.every()` 都求值为 `undefined`
/// → 整体返回 `false`；而当 `merge_tools` 是**空数组**时，`[].every()` 为 `true`
/// → 返回 `true`。同样是「没有任何变更」，结论却相反 —— 这是 TS 的自相矛盾。
/// 「无变更」显然不会破坏任何调用方，故新版统一返回 `true`。
pub fn is_backward_compatible(changes : ArrayView[@types.Change]) -> Bool {
  let merges = collect_merges(changes)
  let params = collect_params(changes)

  if merges.length() > 0 {
    let mut all_ok = true
    for m in merges {
      if !m.backward_compatible {
        all_ok = false
      }
    }
    if all_ok {
      return true
    }
  }
  if params.length() > 0 {
    let mut all_defaulted = true
    for p in params {
      for removed in p.remove_params {
        if !json_has_key(p.defaults, removed) {
          all_defaulted = false
        }
      }
    }
    if all_defaulted {
      return true
    }
  }
  // 既无工具合并也无参数简化（含变更集为空）→ 不会破坏调用方
  if merges.length() == 0 && params.length() == 0 {
    return true
  }
  false
}

///|
/// JSON 对象是否含某个键。取代 TS L600 的 `param in p.defaults`。
fn json_has_key(json : Json, key : String) -> Bool {
  match json {
    Object(obj) => obj.contains(key)
    _ => false
  }
}

///|
/// 估算迁移成本。取代 TS L611-620。
///
/// TS 写的是 `Object.values(changes).filter(v => v && v.length > 0).length` ——
/// 依赖 **JS 运行时对象反射**遍历 7 个可选字段。MoonBit 没有 `Object.values`，
/// 这行代码**无法移植**，是本次改写的硬阻塞之一。
/// 换成 `Array[Change]` 变体列表后，它退化为 `changes_kinds(changes).length()`，
/// 而且新增变更种类时编译器会强制更新所有 `match` 消费点。
pub fn estimate_migration_effort(
  changes : ArrayView[@types.Change],
) -> @types.MigrationEffort {
  let kind_count = @types.changes_kinds(changes).length()
  if kind_count <= 1 {
    @types.MigrationEffort::Low
  } else if kind_count <= 3 {
    @types.MigrationEffort::Medium
  } else {
    @types.MigrationEffort::High
  }
}

///|
/// 汇总风险评估。取代 TS L550-570。
///
/// `affected_users` 恒为 0：TS L567 的注释写着
/// "Would need actual user tracking" —— 本仓没有任何用户计数来源，
/// 原样保留这个诚实的 0，而不是编一个数。
pub fn assess_risks(
  changes : ArrayView[@types.Change],
) -> @types.RiskAssessment {
  let effort = estimate_migration_effort(changes)
  {
    breaking_changes: has_breaking_changes(changes),
    backward_compatible: is_backward_compatible(changes),
    migration_effort: effort,
    affected_users: 0,
    rollback_complexity: effort.rollback_complexity(),
  }
}

///|
/// 生成去重签名。取代 TS L625-638。
///
/// 形式是 `<插件名>-<进化类型>`，其中：
/// · 插件名 = `plugin_id` 按 `-` 切分后**去掉最后一段**（那是 version）再拼回。
///   于是 `browser-use-0.4.1` → `browser-use`，`my-cool-plugin-1.0.0` → `my-cool-plugin`。
///   注意 `plugin_id` 本身不含 `-` 时（如 `foo`），TS 的 `slice(0,-1)` 得到空数组，
///   签名会变成 `-<type>`；此处逐字保留该行为，因为它决定了去重的分桶。
/// · 进化类型的 wire 名把 `_` 换成 `-`（TS L634 的 `replace(/_/g,'-')`）。
///
/// 签名是 CONTEXT.md L17 定义的「归一化串」，用于 `findDuplicate` 去重，
/// 因此它的构造规则一旦改动，历史 `proposals.jsonl` 里的签名就全部失配。
pub fn generate_signature(
  plugin_id : String,
  etype : @types.EvolutionType,
) -> String {
  let parts : Array[String] = []
  for seg in plugin_id.split("-") {
    parts.push(seg.to_owned())
  }
  let kept : Array[String] = []
  let n = parts.length()
  // slice(0, -1)：去掉最后一段。n == 1 时范围为空 → kept 为空。
  // `..<` 与 `-` 的优先级有歧义，必须加括号（工具链会报 ambiguous_precedence）。
  for i in 0..<(n - 1) {
    kept.push(parts[i])
  }
  let normalized_type = etype.wire_name().replace_all(old="_", new="-")
  "\{kept.join("-")}-\{normalized_type}"
}

///|
/// 判定置信度。取代 TS L643-650。
/// 三条判定的**顺序不可调换**：strong >= 2 优先于 strong >= 1。
pub fn determine_confidence(
  signals : ArrayView[@types.EvolutionSignal],
) -> @types.Confidence {
  let mut strong = 0
  let mut medium = 0
  for s in signals {
    match s.strength {
      @types.SignalStrength::Strong => strong += 1
      @types.SignalStrength::Medium => medium += 1
      @types.SignalStrength::Weak => ()
    }
  }
  if strong >= 2 {
    @types.Confidence::High
  } else if strong >= 1 || medium >= 2 {
    @types.Confidence::Medium
  } else {
    @types.Confidence::Low
  }
}
