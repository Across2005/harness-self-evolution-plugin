///|
/// 插件初始指标的启发式打分 —— **纯函数，不碰文件系统**。
/// 取代 legacy-ts/src/scanner/index.ts L297-327 的 `calculateMetrics`。
///
/// TS 版把打分与 I/O 混在一起：`calculateMetrics` 在 L310-313 自己
/// `fs.pathExists` + `fs.readFile` 去读 `<pluginDir>/SKILL.md`。
/// 于是想验证那三个数学公式就必须先造一个真实目录树，
/// `tests/scanner.test.ts` 也因此无法覆盖公式本身。
/// 剥离为纯函数后，公式可以用几行断言直接钉死。
///
/// 顺带修掉 P13（同一份 SKILL.md 被读两次）：内容长度由调用方传入，
/// scanner 只在遍历时读一次。

///|
/// 复刻 JS `Math.round(x * 10) / 10`（保留 1 位小数）。
///
/// JS 的 `Math.round` 是「向 +∞ 取半」（`0.5 → 1`、`-0.5 → -0`），
/// 而 `Double::round` 的取半方向依实现而异。本函数的入参恒 >= 0
/// （complexity ∈ [2,10]、clarity >= 3、doc ∈ [5,10]），
/// 两种取半方向在非负区间上等价；但仍显式写成 `floor(x + 0.5)` 的形式，
/// 不依赖 `Double::round` 的语义。
/// `Double::to_int()` 是向零截断，对非负值即 floor。
fn round1(d : Double) -> Double {
  (d * 10.0 + 0.5).to_int().to_double() / 10.0
}

///|
/// 计算三项初始指标。
///
/// · `root_skill_len`：`<pluginDir>/SKILL.md` 的 `String::length()`；
///   `None` 表示该文件不存在（对齐 TS L308-314：不存在时 documentationScore 恒为 5）。
///   **实测定论**：MoonBit 的 `String::length()` 返回的就是 UTF-16 码元数
///   （`"a😀b".length() == 4`，而不是码点数 3），与 JS 的 `String.prototype.length`
///   完全一致。规划阶段曾假定两者不等并准备了一个 `utf16_length` 辅助函数，
///   被 `metrics_wbtest.mbt` 的用例推翻后删除 —— 该用例同时作为回归网，
///   若将来 core 改变 `length()` 语义会先在那里失败。
///   注意 TS 只看**根目录**的 SKILL.md，不看子目录里的那些 ——
///   缺陷 F3 实测发现真实插件（如 browser-use 0.4.1）的 SKILL.md 都在
///   `skills/*/SKILL.md`，根目录没有，于是它们的 documentation_quality 恒为 5。
///   这是 TS 的既有行为，此处**原样保留**（改变它会连带改变 clarity 与进化决策）。
/// · `tool_count` / `capability_count`：**未去重**的数组长度（对齐 TS L132 传入
///   `calculateMetrics` 的是去重前的数组）。
pub fn compute_metrics(
  root_skill_len : Int?,
  tool_count : Int,
  capability_count : Int,
) -> @types.PluginMetrics {
  // 复杂度 = min(工具数 * 0.5, 5) + min(能力数 * 0.3, 3) + 2，再夹到 10
  let tool_complexity = Double::min(tool_count.to_double() * 0.5, 5.0)
  let cap_complexity = Double::min(capability_count.to_double() * 0.3, 3.0)
  let complexity = Double::min(tool_complexity + cap_complexity + 2.0, 10.0)

  // 文档分 = min(长度 / 500, 5) + 5，无根 SKILL.md 时恒为 5
  let doc_score = match root_skill_len {
    Some(n) => Double::min(n.to_double() / 500.0, 5.0) + 5.0
    None => 5.0
  }

  // 清晰度 = max(10 - 复杂度 * 0.5, 3) + (文档分 - 5) * 0.5
  let clarity = Double::max(10.0 - complexity * 0.5, 3.0) +
    (doc_score - 5.0) * 0.5

  {
    complexity_score: round1(complexity),
    interface_clarity: round1(Double::min(clarity, 10.0)),
    documentation_quality: round1(Double::min(doc_score, 10.0)),
    usage_frequency: Some(@types.UsageFrequency::Idle),
  }
}

///|
/// 文本质量评估指标
pub struct TextQualityMetrics {
  /// AI 写作痕迹检测分数（0-10，越高越像人写）
  humanization_score : Double
  /// 学术规范符合度（0-10）
  academic_compliance : Double
  /// 文本多样性（0-10，词汇丰富度、句式变化）
  text_diversity : Double
  /// 引用规范性（0-10）
  citation_quality : Double
} derive(Eq, Debug)

///|
/// 计算文本质量指标
///
/// · `skill_content`：SKILL.md 的完整文本内容
/// · `domain`：Skill 领域分类（保留用于未来扩展，当前未使用）
///
/// 返回四项文本质量指标，用于评估文本/学术类 Skill 的质量。
pub fn compute_text_metrics(
  skill_content : String,
  _domain : @types.SkillDomain,
) -> TextQualityMetrics {
  // AI 痕迹检测
  let ai_score = detect_ai_fingerprints(skill_content)
  let humanization = ai_score.total
  
  // 学术规范检测（简化版：检查是否有引用、是否有结构化内容）
  let academic = check_academic_compliance(skill_content)
  
  // 文本多样性（词汇丰富度）
  let diversity = compute_text_diversity(skill_content)
  
  // 引用规范性
  let citation = check_citation_quality(skill_content)
  
  { humanization_score: humanization,
    academic_compliance: academic,
    text_diversity: diversity,
    citation_quality: citation }
}

///|
/// 检查学术规范符合度
fn check_academic_compliance(text : String) -> Double {
  let mut score = 5.0  // 基础分
  
  // 检查是否有结构化内容（标题、列表等）
  if text.contains("## ") || text.contains("- ") {
    score += 1.0
  }
  
  // 检查是否有引用格式
  if text.contains("(") && text.contains(")") && text.contains(",") {
    score += 1.0
  }
  
  // 检查是否有学术术语
  let academic_terms = ["hypothesis", "methodology", "analysis", "conclusion", "abstract"]
  for term in academic_terms {
    if text.to_lower().contains(term) {
      score += 0.5
    }
  }
  
  Double::min(score, 10.0)
}

///|
/// 计算文本多样性（词汇丰富度）
fn compute_text_diversity(text : String) -> Double {
  let words = text.split(" ")
  let word_count = words.length()
  
  if word_count < 10 {
    return 5.0
  }
  
  // 计算唯一词比例（手动去重）
  let seen : Map[String, Unit] = Map([])
  let mut unique_count = 0
  for word in words {
    let word_str = word.to_owned()
    if !seen.contains(word_str) {
      seen.set(word_str, ())
      unique_count += 1
    }
  }
  
  let diversity_ratio = unique_count.to_double() / word_count.to_double()
  
  // 转换为 0-10 分（diversity_ratio 在 0.3-0.8 之间是正常的）
  let score = (diversity_ratio - 0.3) / 0.5 * 10.0
  Double::min(Double::max(score, 0.0), 10.0)
}

///|
/// 检查引用规范性
fn check_citation_quality(text : String) -> Double {
  let mut score = 5.0  // 基础分
  
  // 检查是否有 DOI 或 URL
  if text.contains("doi:") || text.contains("https://") {
    score += 2.0
  }
  
  // 检查是否有年份格式（简化版：检查括号+数字）
  if text.contains("(") && text.contains(")") {
    // 进一步检查括号内是否有数字
    let has_year = text.contains("(2024)") || text.contains("(2023)") || text.contains("(2025)")
    if has_year {
      score += 1.0
    }
  }
  
  // 检查是否有作者格式
  if text.contains("et al.") || text.contains("and") {
    score += 1.0
  }
  
  Double::min(score, 10.0)
}
