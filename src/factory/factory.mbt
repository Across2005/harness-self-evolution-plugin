///|
/// 子 Agent 工厂（v2.1，`docs/subagent-factory.md`）。
///
/// 职责：把结构化的 `AgentDefinition` 变成磁盘上的定义文件
/// （Markdown + YAML frontmatter，ZCode 的 agent 载体格式），
/// 以及列出现有定义、按名删除。**创建 ≠ 派发** —— 本包只管理定义文件，
/// 定义由宿主在其后的会话中发现加载；真实派发是 M7 的进程型扩展缝
/// （见设计文档 §4），刻意不放在这里：管理平面与数据平面分开，
/// 与 defending harness 及本仓「executor 用函数缝注入执行」的分层一致。
///
/// 分层位置与 engine / executor 同层：依赖 store（唯一的 fs 写出口）、
/// types（AgentScope wire 表）、util（日志与路径），被 mcp 依赖（G1）。

///|
/// 一个子 Agent 定义 —— 定义文件的结构化视图。
///
/// `tools` 为**空数组**与「未指定」同义：render 不渲染该行，
/// parse 解不出该行时也归空数组 —— frontmatter 里缺席的键与空列表
/// 在语义上不区分，调用方无需处理第三种状态。
pub(all) struct AgentDefinition {
  /// 定义名 = 文件名（不含 .md）。kebab-case（见 validate 的规则）
  name : String
  /// 一句话职责描述。单行 —— frontmatter 的值不允许换行
  description : String
  /// 系统提示词，即 .md 的正文
  system_prompt : String
  /// 允许的工具名列表；空 = 未指定（不渲染该行）
  tools : Array[String]
  /// 标识色；None = 未指定（不渲染该行）
  color : String?
} derive(Eq, Debug)

// ----------------------------------------------------------------------------
// 校验（全部 raise Failure，消息说明规则本身，LLM 读得懂就能自我纠正）
// ----------------------------------------------------------------------------

///|
/// name 的字符白名单：小写字母 / 数字 / 连字符。
/// 用逐字符 `contains_char` 而非正则 —— 本仓对 MoonBit Regex 的锚点语义
/// 有过实测踩坑记录（`$` 是整串锚点，见 util/path.mbt），ASCII 白名单
/// 逐字符判断零歧义且可单测。
let agent_name_chars : String = "abcdefghijklmnopqrstuvwxyz0123456789-"

///|
/// color 的字符白名单：仅小写字母 a-z。
let agent_color_chars : String = "abcdefghijklmnopqrstuvwxyz"

///|
/// 校验 name：长度 1..64；仅小写字母/数字/`-`；不以 `-` 开头或结尾；
/// 无连续 `--`（kebab-case）。
fn validate_name(name : String) -> Unit raise Failure {
  if name.length() == 0 || name.length() > 64 {
    raise Failure(
      "invalid sub-agent name: length must be between 1 and 64 characters, got \{name.length()}",
    )
  }
  for ch in name.iter() {
    if !agent_name_chars.contains_char(ch) {
      raise Failure(
        "invalid sub-agent name \"\{name}\": only lowercase letters, digits and '-' are allowed",
      )
    }
  }
  if name.has_prefix("-") || name.has_suffix("-") {
    raise Failure(
      "invalid sub-agent name \"\{name}\": must not start or end with '-'",
    )
  }
  if name.contains("--") {
    raise Failure(
      "invalid sub-agent name \"\{name}\": must not contain consecutive '--'",
    )
  }
}

///|
/// 校验 description：长度 1..1024；不含换行（frontmatter 的值是单行的）；
/// 首尾不得有空白（★ 评审 B2：parse 对 frontmatter 值无条件 `trim()`，
/// 若放行首尾空白，`render → parse` 往返不恒等，list 会回显与磁盘
/// 不同的内容，list→create(overwrite=true) 还会静默改写用户输入）。
fn validate_description(description : String) -> Unit raise Failure {
  if description.length() == 0 || description.length() > 1024 {
    raise Failure(
      "invalid sub-agent description: length must be between 1 and 1024 characters, got \{description.length()}",
    )
  }
  if description.contains("\n") || description.contains("\r") {
    raise Failure(
      "invalid sub-agent description: must be a single line without newline characters",
    )
  }
  if description != description.trim().to_owned() {
    raise Failure(
      "invalid sub-agent description: must not have leading or trailing whitespace (render→parse would not round-trip)",
    )
  }
}

///|
/// 校验 system_prompt：长度 1..65536（.md 正文，允许任意换行与中文）；
/// 首行与末行不得是空行（★ 评审 B2：parse 会剥掉正文首尾的空行，
/// 若放行首尾空行，`render → parse` 往返不恒等 —— 首行空行会在渲染后
/// 被吞掉，末行空行与 render 的收尾换行叠加后边界含糊）。
fn validate_system_prompt(prompt : String) -> Unit raise Failure {
  if prompt.length() == 0 || prompt.length() > 65536 {
    raise Failure(
      "invalid sub-agent system_prompt: length must be between 1 and 65536 characters, got \{prompt.length()}",
    )
  }
  let lines : Array[String] = []
  for raw in prompt.split("\n") {
    lines.push(raw.to_owned())
  }
  if lines.length() > 0 && lines[0].trim().length() == 0 {
    raise Failure(
      "invalid sub-agent system_prompt: first line must not be blank (render→parse would not round-trip)",
    )
  }
  if lines.length() > 0 && lines[lines.length() - 1].trim().length() == 0 {
    raise Failure(
      "invalid sub-agent system_prompt: last line must not be blank (render→parse would not round-trip)",
    )
  }
}

///|
/// 校验 color（可选）：长度 1..20，仅小写字母 a-z。
fn validate_color(color : String) -> Unit raise Failure {
  if color.length() == 0 || color.length() > 20 {
    raise Failure(
      "invalid sub-agent color: length must be between 1 and 20 characters, got \{color.length()}",
    )
  }
  for ch in color.iter() {
    if !agent_color_chars.contains_char(ch) {
      raise Failure(
        "invalid sub-agent color \"\{color}\": only lowercase letters a-z are allowed",
      )
    }
  }
}

///|
/// 校验 tools 的每一项：长度 1..64；不含空白、`,`、`[`、`]` ——
/// 后三者会破坏 frontmatter 的 `tools: [a, b]` 形状。
/// 工具名是否真实存在由宿主裁决，这里只做形状校验（设计文档 §3.2）。
fn validate_tools(tools : Array[String]) -> Unit raise Failure {
  for tool in tools {
    if tool.length() == 0 || tool.length() > 64 {
      raise Failure(
        "invalid sub-agent tool name: each entry must be between 1 and 64 characters, got \{tool.length()}",
      )
    }
    if tool.contains_any(chars=" \t\n\r,[]") {
      raise Failure(
        "invalid sub-agent tool name \"\{tool}\": must not contain whitespace, ',', '[' or ']'",
      )
    }
  }
}

///|
/// 全量校验。`create` 的第一件事就是它 —— `AgentDefinition` 是 `pub(all)`
/// 的纯数据，构造不设防，校验集中在工厂入口。
pub fn AgentDefinition::validate(self : AgentDefinition) -> Unit raise Failure {
  validate_name(self.name)
  validate_description(self.description)
  validate_system_prompt(self.system_prompt)
  match self.color {
    Some(c) => validate_color(c)
    None => ()
  }
  validate_tools(self.tools)
}

// ----------------------------------------------------------------------------
// 渲染 / 解析（YAML 子集）
// ----------------------------------------------------------------------------

///|
/// 渲染为 Markdown + YAML frontmatter 文本（ZCode 的 agent 载体格式，
/// 与官方 document-skills 插件的 `agents/judge.md` 同一形状）：
///
/// ```
/// ---
/// name: <name>
/// description: <description>
/// color: <color>      // 仅当指定
/// tools: [a, b]       // 仅当 tools 非空（空数组 = 未指定）
/// ---
///
/// <system_prompt>
/// ```
///
/// 末尾恰好一个换行；tools 用逗号 + 空格分隔。
/// `render → parse` 必须是恒等往返（factory_wbtest 有专门用例钉住），
/// 因此这里的每个格式细节都是契约的一部分。
pub fn render(def : AgentDefinition) -> String {
  let buf = StringBuilder::new(size_hint=def.system_prompt.length() + 128)
  buf.write_string("---\n")
  buf.write_string("name: ")
  buf.write_string(def.name)
  buf.write_char('\n')
  buf.write_string("description: ")
  buf.write_string(def.description)
  buf.write_char('\n')
  match def.color {
    Some(c) => {
      buf.write_string("color: ")
      buf.write_string(c)
      buf.write_char('\n')
    }
    None => ()
  }
  if def.tools.length() > 0 {
    buf.write_string("tools: [")
    buf.write_string(def.tools.join(", "))
    buf.write_string("]\n")
  }
  buf.write_string("---\n\n")
  buf.write_string(def.system_prompt)
  buf.write_char('\n')
  buf.to_string()
}

///|
/// 剥掉值两侧**成对**的一层引号（双或单）。真实世界的 agent 文件普遍给
/// frontmatter 值加引号（实测 `~/.zcode/agents/coder.md` 写的是
/// `name: "coder"`），不剥的话 `list_sub_agents` 会把 `"coder"` 连引号
/// 一起当名字返回，与 create 侧校验通过的裸名对不上。只在两侧引号
/// **互相配对**时剥，值内部含引号（如 `say "hi"`）不受影响。
fn unquote(value : String) -> String {
  let n = value.length()
  if n < 2 {
    return value
  }
  // 引号是 ASCII，首尾各取一个码元足以判型；中间内容按码元原样保留
  let head = value[0:1].to_owned()
  let tail = value[n - 1:n].to_owned()
  if (head == "\"" && tail == "\"") || (head == "'" && tail == "'") {
    return value[1:n - 1].to_owned()
  }
  value
}

///|
/// 解析 frontmatter 的 tools 值：剥掉 `[` `]`，按 `,` 切并逐项去空白、去引号。
/// render 写的是 `[a, b]`（逗号 + 空格），手写文件常见 `[a,b]` 与
/// `["a", "b"]`，三者都接受；空值 / `[]` → 空数组（与「未指定」同义）。
fn split_tools_value(value : String) -> Array[String] {
  let stripped = value.replace_all(old="[", new="").replace_all(old="]", new="")
  let out : Array[String] = []
  if stripped.trim().length() == 0 {
    return out
  }
  for seg in stripped.split(",") {
    let item = unquote(seg.trim().to_owned())
    if item.length() > 0 {
      out.push(item)
    }
  }
  out
}

///|
/// 解析定义文件内容，只认一个 **YAML 子集**：
///
/// · 首行是 `---`（围栏），到下一个 `---` 之间是 `key: value` 行；
/// · `key` 识别 `name` / `description` / `color` / `tools`，未知键忽略；
///   值取**首个** `:` 之后的全部内容（description 里可能含 `:`），
///   并剥掉一层成对的包裹引号（`name: "coder"` 与 `name: coder` 等价）；
/// · 围栏之后的正文是 system_prompt，去掉开头与结尾的空行 ——
///   收尾空行是 render 末尾那个换行留下的，剥掉它才能让
///   `parse(render(def)) == def` 恒成立；
/// · 容忍 CRLF（文件可能被 Windows 编辑器改过）。
///
/// 无围栏、或缺 name / description → `None`：这是「不是本工厂产出的
/// Markdown」，调用方按跳过 + 告警处理，而不是当成错误。
pub fn parse(content : String) -> AgentDefinition? {
  let lines : Array[String] = []
  for raw in content.split("\n") {
    lines.push(raw.trim_end(chars="\r").to_owned())
  }
  guard lines.length() >= 2 else { return None }
  guard lines[0].trim().to_owned() == "---" else { return None }
  // 找闭合围栏：下一个 trim 后恰好是 --- 的行
  let mut close = -1
  for i in 1..<lines.length() {
    if lines[i].trim().to_owned() == "---" {
      close = i
      break
    }
  }
  if close < 0 {
    return None
  }
  let mut name = ""
  let mut description = ""
  let mut color : String? = None
  let tools : Array[String] = []
  for i in 1..<close {
    let line = lines[i].trim().to_owned()
    // 空行与 `#` 注释行跳过（YAML 子集）
    if line.length() == 0 || line.has_prefix("#") {
      continue
    }
    let parts : Array[String] = []
    for seg in line.split(":") {
      parts.push(seg.to_owned())
    }
    if parts.length() < 2 {
      // 没有 ':' 的行不是 key: value，忽略
      continue
    }
    let key = parts[0].trim().to_owned()
    // value = 首个 ':' 之后的内容重新拼回（description 里可能含 ':'），
    // 再剥掉一层成对的包裹引号（真实文件普遍是 `name: "coder"` 的写法）
    let mut raw_value = parts[1]
    for j in 2..<parts.length() {
      raw_value = "\{raw_value}:\{parts[j]}"
    }
    let value = unquote(raw_value.trim().to_owned())
    match key {
      "name" => name = value
      "description" => description = value
      "color" => color = Some(value)
      "tools" =>
        for item in split_tools_value(value) {
          tools.push(item)
        }
      _ => () // 未知键忽略
    }
  }
  guard name.length() > 0 && description.length() > 0 else { return None }
  // 正文：围栏之后，去开头与结尾的空行
  let body : Array[String] = []
  for i in (close + 1)..<lines.length() {
    body.push(lines[i])
  }
  let mut start = 0
  while start < body.length() && body[start].trim().length() == 0 {
    start += 1
  }
  let mut end = body.length()
  while end > start && body[end - 1].trim().length() == 0 {
    end -= 1
  }
  let mut prompt = ""
  for k in start..<end {
    if k > start {
      prompt = "\{prompt}\n\{body[k]}"
    } else {
      prompt = body[k]
    }
  }
  Some({ name, description, system_prompt: prompt, tools, color })
}

// ----------------------------------------------------------------------------
// 工厂
// ----------------------------------------------------------------------------

///|
/// 子 Agent 工厂：plugin / user 两个作用域各挂一个 `AgentDefStore`。
///
/// 为什么是两个显式字段而不是一个目录参数：scope 的语义就是「写到哪」，
/// 在类型层面固定为两个 store，`scope_store` 的穷尽 match 保证新增
/// AgentScope 变体时编译器立刻指出所有需要跟进的分支。
pub struct AgentFactory {
  plugin_scope : @store.AgentDefStore
  user_scope : @store.AgentDefStore
}

///|
/// 用显式目录构造 —— 测试与多档案场景的 DI 缝：
/// 两个作用域分别指向独立的临时目录，工厂的全部行为都可以在
/// 完全隔离的环境里验证。
pub fn AgentFactory::with_dirs(
  plugin_dir : String,
  user_dir : String,
) -> AgentFactory {
  {
    plugin_scope: @store.AgentDefStore::at(plugin_dir),
    user_scope: @store.AgentDefStore::at(user_dir),
  }
}

///|
/// 生产构造：plugin 作用域 = 数据根下的 `agents/`，
/// user 作用域 = 宿主的 `~/.zcode/agents/`（路径单点定义在 store/paths.mbt）。
pub fn AgentFactory::at(paths : @store.DataPaths) -> AgentFactory {
  AgentFactory::with_dirs(paths.agent_defs(), @store.user_agents_dir())
}

///|
/// scope → store 的穷尽映射。AgentScope 新增变体时这里先编译失败，
/// 提醒实现者决定新作用域落在哪个目录。
fn AgentFactory::scope_store(
  self : AgentFactory,
  scope : @types.AgentScope,
) -> @store.AgentDefStore {
  match scope {
    @types.AgentScope::Plugin => self.plugin_scope
    @types.AgentScope::User => self.user_scope
  }
}

///|
/// 创建一个子 Agent 定义文件。
///
/// 先全量校验（非法定义在触碰磁盘之前就被拒绝），再写入对应作用域。
/// 返回 `(path, overwritten)`：path 是写入的绝对路径（诊断与回显用），
/// overwritten 表示是否覆盖了同名文件。
/// 已存在且 `overwrite=false` → raise（经 mcp 的 `call_tool` 变 isError）。
pub async fn AgentFactory::create(
  self : AgentFactory,
  def : AgentDefinition,
  scope : @types.AgentScope,
  overwrite? : Bool = false,
) -> (String, Bool) {
  def.validate()
  let store = self.scope_store(scope)
  let path = store.path_of(def.name)
  let overwritten = store.write(def.name, render(def), overwrite~)
  (path, overwritten)
}

///|
/// 列出子 Agent 定义。
///
/// · `scope = None` 列两个作用域，顺序固定为先 plugin 后 user（决策 D10）；
///   每个作用域内部由 `AgentDefStore::list` 按字典序排列；
/// · 每项是 `(scope, 解析后的定义, 路径)` 三元组；
/// · **解析失败的文件跳过并告警，不让整个列表失败** —— 手改坏的
///   一个 .md 不能把其余定义全部遮住（与 Jsonl::load 跳过损坏行同理）。
pub async fn AgentFactory::list(
  self : AgentFactory,
  scope : @types.AgentScope?,
) -> Array[(@types.AgentScope, AgentDefinition, String)] {
  let out : Array[(@types.AgentScope, AgentDefinition, String)] = []
  let scopes : Array[@types.AgentScope] = match scope {
    Some(s) => [s]
    None => [@types.AgentScope::Plugin, @types.AgentScope::User]
  }
  for s in scopes {
    let store = self.scope_store(s)
    for name in store.list() {
      // list 与 read 之间文件可能被并发删除：读取失败按「坏文件」跳过
      let loaded : Result[String, String] = Ok(store.read(name)) catch {
        e => Err(e.to_string())
      }
      match loaded {
        Ok(content) =>
          match parse(content) {
            Some(def) => out.push((s, def, store.path_of(name)))
            None =>
              @util.log_warn(
                "Factory",
                "Skipping agent definition \"\{name}\": no YAML frontmatter fence or missing name/description",
              )
          }
        Err(reason) =>
          @util.log_warn(
            "Factory",
            "Skipping agent definition \"\{name}\": \{reason}",
          )
      }
    }
  }
  out
}

///|
/// 删除一个子 Agent 定义，返回被删的路径。
/// 名字不存在 → raise（消息含 "not found"，让 LLM 能区分拼错与删除成功）。
pub async fn AgentFactory::delete(
  self : AgentFactory,
  name : String,
  scope : @types.AgentScope,
) -> String {
  let store = self.scope_store(scope)
  let path = store.path_of(name)
  store.remove(name)
  path
}
