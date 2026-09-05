///|
/// 打分公式的纯函数断言 —— 无需任何文件系统。
///
/// 下面每个期望值都由 legacy-ts/src/scanner/index.ts L297-327 的**原始公式**
/// 在 node 里跑出来（脚本逐行照抄 TS 代码），不是手算的浮点。
/// 这类含 `Math.min` / `Math.max` / `Math.round(x*10)/10` 的链式浮点运算，
/// 手算极易在某一位上偏差，而偏差会直接翻转 engine 的 `> 7` / `< 7` 判定。
///
/// 交叉验证：第一组 `[None, 0, 0] → {2.0, 9.0, 5.0}` 与本机
/// `~/.harness-evolution/plugin-cache.json`（缺陷 F2 的毒化缓存）里
/// jest 残留条目的实测值 `complexity_score:2, interface_clarity:9,
/// documentation_quality:5` 完全一致 —— 那是 TS 版真实运行的产物，
/// 独立佐证了公式解读无误。

///|
/// 签名带 `raise`：`assert_eq` 对 `Double` 是可抛错函数，
/// 而工具链要求「只能在自己也声明了错误类型的函数里调用带错函数」。
fn assert_metrics(
  root_skill_len : Int?,
  tools : Int,
  caps : Int,
  complexity : Double,
  clarity : Double,
  doc : Double,
) -> Unit raise {
  let m = compute_metrics(root_skill_len, tools, caps)
  assert_eq(m.complexity_score, complexity)
  assert_eq(m.interface_clarity, clarity)
  assert_eq(m.documentation_quality, doc)
  // 扫描阶段恒为 idle，由 monitor 后续更新（对齐 TS L325）
  assert_eq(m.usage_frequency, Some(@types.UsageFrequency::Idle))
}

test "compute_metrics matches the TS formula on nine node-verified cases" {
  // 无根 SKILL.md → documentationScore 恒为 5（TS L308）
  assert_metrics(None, 0, 0, 2.0, 9.0, 5.0)
  assert_metrics(None, 3, 3, 4.4, 7.8, 5.0)
  // 有根 SKILL.md：7766 是本仓 skills/harness-evolution/SKILL.md 的 UTF-16 码元数
  assert_metrics(Some(7766), 3, 3, 4.4, 10.0, 10.0)
  // 文档分上限：min(500/500, 5) + 5 = 6
  assert_metrics(Some(500), 10, 10, 10.0, 5.5, 6.0)
  // 空文件：min(0/500,5)+5 = 5，与「文件不存在」同值
  assert_metrics(Some(0), 1, 1, 2.8, 8.6, 5.0)
  assert_metrics(Some(3310), 0, 0, 2.0, 10.0, 10.0)
  assert_metrics(Some(2500), 7, 12, 8.5, 8.3, 10.0)
  // 工具与能力双双触顶：min(20*0.5,5)=5、min(40*0.3,3)=3 → complexity=min(10,10)=10
  assert_metrics(Some(120), 20, 40, 10.0, 5.1, 5.2)
  assert_metrics(Some(2906), 2, 1, 3.3, 10.0, 10.0)
}

///|
/// 上限必须真的生效：工具数与能力数再涨也不得突破 complexity 10 / doc 10。
test "compute_metrics respects both caps" {
  let huge = compute_metrics(Some(1_000_000), 10_000, 10_000)
  assert_eq(huge.complexity_score, 10.0)
  assert_eq(huge.documentation_quality, 10.0)
  // clarity = max(10 - 10*0.5, 3) + (10-5)*0.5 = 5 + 2.5 = 7.5
  assert_eq(huge.interface_clarity, 7.5)
}

///|
/// **实测推翻了规划阶段的 R18 假设。**
/// 当时假定「MoonBit 的 `String::length()` 是 Unicode 码点数，而 JS 的
/// `.length` 是 UTF-16 码元数」，并因此设计了 `utf16_length` 辅助函数。
/// 实测 `"a😀b".length()` 返回 **4**（UTF-16 码元数）而不是码点数 3 ——
/// 两者本来就一致，`utf16_length` 属于多余抽象，已删除，
/// `scanner.mbt` 直接用 `text.length()`。
///
/// 本用例把三种候选语义逐一排除，并作为回归网钉住：
/// 若将来 core 把 `length()` 改成码点数或字节数，这里会先失败，
/// 提醒重新评估 `compute_metrics` 的输入（它直接决定 documentation_quality，
/// 进而可能翻转 engine L207 的 `clarity < 7` 判定）。
test "String::length is UTF-16 code units, identical to JS String.length" {
  assert_eq("".length(), 0)
  assert_eq("abc".length(), 3)
  // CJK 在 BMP 内：UTF-16 码元 4，UTF-8 字节 12 —— 排除「字节数」假设
  assert_eq("扫描插件".length(), 4)
  // emoji U+1F600 是代理对：UTF-16 码元 2，码点 1 —— 排除「码点数」假设
  assert_eq("😀".length(), 2)
  assert_eq("a😀b".length(), 4)
  // 混合：2 个 BMP 字符 + 1 个代理对 + 2 个 BMP 字符 = 6
  assert_eq("扫描😀ab".length(), 6)
}
