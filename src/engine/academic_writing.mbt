///|
/// 学术写作进化引擎
///
/// 基于 AI 写作痕迹检测和学术规范检查，生成针对性的进化提案。
/// 支持三种进化类型：
/// - AcademicWritingEnhancement：学术写作规范化
/// - AntiAIDetection：反 AI 写作检测
/// - CitationNormalization：引用规范化
///
/// **设计理念**：
/// - 基于研究的 AI 痕迹检测（Kobak et al. 2024）
/// - 提供具体的改写建议，而非笼统的"优化"
/// - 生成"反 AI slop"改写对照表

///|
/// 学术写作进化引擎
pub struct AcademicWritingEngine {
  /// 改写建议库
  rewrite_suggestions : RewriteSuggestionLibrary
}

///|
/// 改写建议库
pub struct RewriteSuggestionLibrary {
  /// AI 词汇替换表
  ai_vocabulary_replacements : Map[String, String]
  /// 句式转换模板
  syntax_templates : Array[SyntaxTemplate]
}

///|
/// 句式转换模板
pub struct SyntaxTemplate {
  /// 原始模式
  pattern : String
  /// 建议替换
  suggestion : String
  /// 适用场景
  context : String
} derive(Eq, Debug)

///|
/// 进化提案结果
pub struct AcademicProposal {
  /// 进化类型
  evolution_type : @types.EvolutionType
  /// 具体变更建议
  changes : Array[String]
  /// 预期收益
  expected_benefits : Map[String, Double]
  /// 优先级（1-5，5 最高）
  priority : Int
} derive(Eq, Debug)

///|
/// 创建学术写作进化引擎
pub fn AcademicWritingEngine::new() -> AcademicWritingEngine {
  {
    rewrite_suggestions: create_default_rewrite_suggestions(),
  }
}

///|
/// 创建默认改写建议库
fn create_default_rewrite_suggestions() -> RewriteSuggestionLibrary {
  let replacements = Map([])
  
  // AI 词汇替换表（基于 Kobak et al. 2024 研究）
  replacements.set("delve", "examine")
  replacements.set("crucial", "important")
  replacements.set("pivotal", "key")
  replacements.set("comprehensive", "complete")
  replacements.set("multifaceted", "complex")
  replacements.set("intricate", "detailed")
  replacements.set("vibrant", "active")
  replacements.set("profound", "deep")
  replacements.set("essential", "necessary")
  replacements.set("fundamentally", "basically")
  replacements.set("leverage", "use")
  replacements.set("utilize", "use")
  replacements.set("facilitate", "help")
  replacements.set("underscore", "emphasize")
  
  // 句式转换模板
  let templates = [
    {
      pattern: "It is widely recognized that",
      suggestion: "Many researchers have noted that",
      context: "学术写作"
    },
    {
      pattern: "Many philosophers have argued",
      suggestion: "As X argues in Y (year, p. N)",
      context: "哲学写作"
    },
    {
      pattern: "This paper aims to",
      suggestion: "I argue that / I find that",
      context: "学术写作"
    },
    {
      pattern: "In this paper, I will argue that",
      suggestion: "直接进入论证，无需宣告",
      context: "哲学写作"
    },
  ]
  
  { ai_vocabulary_replacements: replacements, syntax_templates: templates }
}

///|
/// 生成学术写作进化提案
pub fn AcademicWritingEngine::generate_proposal(
  self : AcademicWritingEngine,
  skill_content : String,
  domain : @types.SkillDomain,
) -> AcademicProposal? {
  let score = @scanner.detect_ai_fingerprints(skill_content)
  
  // AI 痕迹较重（总分 < 6.0），生成反 AI 进化提案
  if score.total < 6.0 {
    let changes = self.generate_rewrite_suggestions(skill_content, score)
    return Some({
      evolution_type: @types.EvolutionType::AntiAIDetection,
      changes,
      expected_benefits: Map([("humanization_improvement", 10.0 - score.total)]),
      priority: 5,
    })
  }
  
  // 学术规范不足（学术分 < 6.0）
  if domain == @types.SkillDomain::Academic {
    let text_metrics = @scanner.compute_text_metrics(skill_content, domain)
    if text_metrics.academic_compliance < 6.0 {
      let changes = self.generate_academic_suggestions(skill_content)
      return Some({
        evolution_type: @types.EvolutionType::AcademicWritingEnhancement,
        changes,
        expected_benefits: Map([("academic_compliance", 10.0 - text_metrics.academic_compliance)]),
        priority: 4,
      })
    }
  }
  
  // 引用规范不足
  if domain == @types.SkillDomain::Academic {
    let text_metrics = @scanner.compute_text_metrics(skill_content, domain)
    if text_metrics.citation_quality < 6.0 {
      let changes = self.generate_citation_suggestions(skill_content)
      return Some({
        evolution_type: @types.EvolutionType::CitationNormalization,
        changes,
        expected_benefits: Map([("citation_quality", 10.0 - text_metrics.citation_quality)]),
        priority: 3,
      })
    }
  }
  
  None
}

///|
/// 生成改写建议
fn AcademicWritingEngine::generate_rewrite_suggestions(
  self : AcademicWritingEngine,
  text : String,
  score : @scanner.AIScore,
) -> Array[String] {
  let suggestions = []
  
  // 词汇级改写建议
  if score.vocabulary < 6.0 {
    for entry in self.rewrite_suggestions.ai_vocabulary_replacements {
      let original = entry.0
      let replacement = entry.1
      if text.to_lower().contains(original) {
        suggestions.push("将 '\{original}' 替换为 '\{replacement}'")
      }
    }
  }
  
  // 句法级改写建议
  if score.syntax < 6.0 {
    for template in self.rewrite_suggestions.syntax_templates {
      if text.to_lower().contains(template.pattern.to_lower()) {
        suggestions.push("将 '\\{template.pattern}' 改为 '\\{template.suggestion}' (\\{template.context})")
      }
    }
  }
  
  // 段落级改写建议
  if score.paragraph < 6.0 {
    suggestions.push("增加段落长度方差，避免每段长度过于均匀")
    suggestions.push("减少段末预告句式（如 'In the next section...'）")
  }
  
  // 篇章级改写建议
  if score.discourse < 6.0 {
    suggestions.push("避免使用 'In this paper, I will argue that...' 开头")
    suggestions.push("减少模板化过渡句（如 'Let us now turn to...'）")
    suggestions.push("避免使用 'It is important to note that...' 模板 hedge")
  }
  
  suggestions
}

///|
/// 生成学术规范建议
fn AcademicWritingEngine::generate_academic_suggestions(
  _self : AcademicWritingEngine,
  text : String,
) -> Array[String] {
  let suggestions = []
  
  // 检查结构化内容
  if !text.contains("## ") && !text.contains("- ") {
    suggestions.push("添加标题和列表结构，提高可读性")
  }
  
  // 检查学术术语
  let academic_terms = ["hypothesis", "methodology", "analysis", "conclusion", "abstract"]
  let mut has_academic_terms = false
  for term in academic_terms {
    if text.to_lower().contains(term) {
      has_academic_terms = true
    }
  }
  if !has_academic_terms {
    suggestions.push("添加学术术语（如 hypothesis, methodology, analysis, conclusion）")
  }
  
  suggestions
}

///|
/// 生成引用规范建议
fn AcademicWritingEngine::generate_citation_suggestions(
  _self : AcademicWritingEngine,
  text : String,
) -> Array[String] {
  let suggestions = []
  
  // 检查 DOI 或 URL
  if !text.contains("doi:") && !text.contains("https://") {
    suggestions.push("添加 DOI 或 URL 引用")
  }
  
  // 检查年份格式
  if !text.contains("(") || !text.contains(")") {
    suggestions.push("添加年份格式引用（如 (2024)）")
  }
  
  // 检查作者格式
  if !text.contains("et al.") {
    suggestions.push("添加作者引用（如 Author et al.）")
  }
  
  suggestions
}
