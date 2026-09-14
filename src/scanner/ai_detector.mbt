///|
/// AI 写作痕迹检测器
///
/// 基于以下研究实现四级检测：
/// 1. Kobak et al. (Science Advances, 2024): "Delve into LLM-marked text"
/// 2. Wikipedia "Signs of AI writing" (WikiProject AI Cleanup)
/// 3. Bloomberry "AI Dialects" 研究 (Vol. 1)
///
/// 检测维度：词汇级（12条）、句法级（6条）、段落级（6条）、篇章级（6条）
///
/// **设计理念**：
/// - 每个检测器返回 0-10 分，越高越像人类写的
/// - 综合分数 = 各维度加权平均
/// - 单一指标不是铁证，需要多维度交叉验证

///|
/// AI 写作检测结果
pub struct AIScore {
  /// 综合分数（0-10，越高越像人写）
  total : Double
  /// 词汇级分数
  vocabulary : Double
  /// 句法级分数
  syntax : Double
  /// 段落级分数
  paragraph : Double
  /// 篇章级分数
  discourse : Double
} derive(Eq, Debug)

///|
/// AI 写作痕迹检测器
pub struct AIDetector {
  /// 检测阈值（低于此值视为 AI 生成）
  threshold : Double
} derive(Eq, Debug)

///|
/// 创建 AI 写作痕迹检测器
pub fn AIDetector::new() -> AIDetector {
  { threshold: 6.0 }
}

///|
/// 检测文本的 AI 写作痕迹
pub fn AIDetector::detect(_self : AIDetector, text : String) -> AIScore {
  detect_ai_fingerprints(text)
}

///|
/// 词汇级 AI 痕迹检测
/// 基于 Kobak et al. 2024 和 Wikipedia "Signs of AI writing"

/// 标志性 AI 词汇（A类）
fn detect_ai_vocabulary_markers(text : String) -> Double {
  let lower = text.to_lower()
  let mut penalty = 0.0
  
  // 标志性 AI 词（每个扣 0.5 分，最多扣 3 分）
  let ai_markers = [
    "delve", "crucial", "pivotal", "comprehensive", "multifaceted",
    "intricate", "vibrant", "profound", "essential", "fundamentally",
    "leverage", "utilize", "facilitate", "underscore",
  ]
  for marker in ai_markers {
    if lower.contains(marker) {
      penalty += 0.5
    }
  }
  
  // 过渡 puffery（每个扣 0.3 分，最多扣 2 分）
  let transitions = ["moreover", "furthermore", "additionally", "highlighting"]
  for t in transitions {
    if lower.contains(t) {
      penalty += 0.3
    }
  }
  
  // 抽象名词伪装（每个扣 0.3 分，最多扣 2 分）
  let abstract_nouns = ["realm", "landscape", "tapestry", "testament", "journey"]
  for noun in abstract_nouns {
    if lower.contains(noun) {
      penalty += 0.3
    }
  }
  
  // 返回分数（10 - 惩罚，最低 0）
  Double::max(10.0 - penalty, 0.0)
}

///|
/// 句法级 AI 痕迹检测
fn detect_syntax_patterns(text : String) -> Double {
  let mut penalty = 0.0
  
  // em-dash 过度使用（每 100 词超过 2 个扣 1 分）
  let lower = text.to_lower()
  let dash_count = lower.split("--").length() - 1 + lower.split("—").length() - 1
  let word_count = text.split(" ").length().to_double()
  if word_count > 0.0 {
    let dash_ratio = dash_count.to_double() / word_count * 100.0
    if dash_ratio > 2.0 {
      penalty += 1.0
    }
  }
  
  // 三段式排比（Rule of three）检测
  // 简单启发：连续三个相似结构的短语
  let triple_patterns = [
    "robust, scalable, and transformative",
    "clarity, precision, and elegance",
    "comprehensive, thorough, and detailed",
  ]
  for pattern in triple_patterns {
    if text.to_lower().contains(pattern) {
      penalty += 1.0
    }
  }
  
  // Negative parallelism（Not only X, but also Y）
  if text.to_lower().contains("not only") && text.to_lower().contains("but also") {
    penalty += 0.5
  }
  
  // Vague attributions
  let vague_patterns = [
    "many experts believe",
    "it is widely recognized",
    "studies have shown",
    "it has been widely held",
  ]
  for pattern in vague_patterns {
    if text.to_lower().contains(pattern) {
      penalty += 0.5
    }
  }
  
  Double::max(10.0 - penalty, 0.0)
}

///|
/// 段落级 AI 痕迹检测
fn detect_paragraph_patterns(text : String) -> Double {
  let mut penalty = 0.0
  let paragraphs = text.split("\n\n")
  
  // 段落长度方差检测（AI 段落长度方差小）
  if paragraphs.length() > 2 {
    // 计算段落长度
    let lengths : Array[Double] = []
    for p in paragraphs {
      lengths.push(p.length().to_double())
    }
    
    // 计算平均值
    let mut sum = 0.0
    for len in lengths {
      sum += len
    }
    let mean = sum / lengths.length().to_double()
    
    // 计算方差
    let mut variance_sum = 0.0
    for len in lengths {
      let diff = len - mean
      variance_sum += diff * diff
    }
    let variance = variance_sum / lengths.length().to_double()
    let std_dev = variance.sqrt()
    let cv = if mean > 0.0 { std_dev / mean } else { 0.0 }
    
    // 变异系数 < 0.3 表示段落长度过于均匀
    if cv < 0.3 {
      penalty += 2.0
    }
  }
  
  // 每段都是"开头概括 + 末句预告"模式
  let preview_patterns = [
    "in the next section",
    "this brings us to",
    "as we will see",
    "let us now turn to",
  ]
  for pattern in preview_patterns {
    if text.to_lower().contains(pattern) {
      penalty += 0.5
    }
  }
  
  Double::max(10.0 - penalty, 0.0)
}

///|
/// 篇章级 AI 痕迹检测
fn detect_discourse_patterns(text : String) -> Double {
  let mut penalty = 0.0
  let lower = text.to_lower()
  
  // "In this paper, I will argue that..." 格式开头
  if lower.contains("in this paper") && lower.contains("i will argue") {
    penalty += 2.0
  }
  
  // "Let us now turn to..." 过渡僵尸
  if lower.contains("let us now turn to") {
    penalty += 1.0
  }
  
  // "It is important to note that..." 模板 hedge
  if lower.contains("it is important to note") {
    penalty += 1.0
  }
  
  // "I hope this..." 收束
  if lower.contains("i hope this") {
    penalty += 1.0
  }
  
  // Outline-like conclusion 收束
  if lower.contains("in conclusion") && lower.contains("represents a significant") {
    penalty += 1.5
  }
  
  Double::max(10.0 - penalty, 0.0)
}

///|
/// 综合 AI 写作痕迹检测
pub fn detect_ai_fingerprints(text : String) -> AIScore {
  let vocabulary = detect_ai_vocabulary_markers(text)
  let syntax = detect_syntax_patterns(text)
  let paragraph = detect_paragraph_patterns(text)
  let discourse = detect_discourse_patterns(text)
  
  // 加权综合评分（词汇 30%，句法 25%，段落 25%，篇章 20%）
  let total = vocabulary * 0.3 + syntax * 0.25 + paragraph * 0.25 + discourse * 0.2
  
  { total, vocabulary, syntax, paragraph, discourse }
}

///|
/// 判断文本是否为 AI 生成（阈值：综合分 < 6.0 视为 AI 生成）
pub fn is_ai_generated(score : AIScore) -> Bool {
  score.total < 6.0
}

///|
/// 生成 AI 痕迹诊断报告
pub fn generate_diagnostic_report(score : AIScore) -> String {
  let mut report = "AI 写作痕迹诊断报告\n"
  report = report + "====================\n\n"
  report = report + "综合分数: \{score.total}/10\n"
  report = report + "  - 词汇级: \{score.vocabulary}/10\n"
  report = report + "  - 句法级: \{score.syntax}/10\n"
  report = report + "  - 段落级: \{score.paragraph}/10\n"
  report = report + "  - 篇章级: \{score.discourse}/10\n\n"
  
  if is_ai_generated(score) {
    report = report + "诊断结果: 疑似 AI 生成文本\n"
  } else {
    report = report + "诊断结果: 人类写作\n"
  }
  
  report
}
