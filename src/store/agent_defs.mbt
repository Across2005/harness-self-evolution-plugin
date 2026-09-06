///|
/// 子 Agent 定义文件（Markdown + YAML frontmatter，ZCode 的 agent 载体格式）
/// 的读写删列 —— v2.1 子 Agent 工厂（`docs/subagent-factory.md`）的持久层。
///
/// 与 Jsonl / cache 同理，**fs 写操作只存在于本包**（CONTEXT.md 不变量① /
/// 守卫 G3）：factory 包与 mcp 层只经这里的窄接口触碰磁盘。
///
/// **文件名规则**：一律 `<name>.md`，调用方传的 `name` 不带扩展名
/// （`list()` 返回的名字同样不带）。name 合法性有**两道防线**：
/// 第一道在 factory 的校验（仅小写字母/数字/连字符），
/// 第二道在本包 —— 含 `/`、`\`、`..` 或为空的 name 直接 raise，
/// 防止路径穿越。store 是最后一道防线，不依赖上游调用方的自觉。
pub struct AgentDefStore {
  /// 定义文件所在目录（包内字段；外部经 `at()` 构造、经 `path_of()` 取路径）
  dir : String
}

///|
/// 构造。路径经 `expand_home` + 归一化，与 `DataPaths::at` / `Jsonl::new`
/// 同一惯例，故可以直接传 `~/...` 或混用 `\` 的 Windows 路径。
pub fn AgentDefStore::at(dir : String) -> AgentDefStore {
  { dir: @util.path_normalize(@util.expand_home(dir)) }
}

///|
/// 名为 `name` 的定义文件的完整路径。
/// 拼路径**之前**做最后一道 name 校验：为空或含 `/`、`\`、`..` 直接 raise
/// —— 这些字符会让 `<dir>/<name>.md` 逃出定义目录（路径穿越）。
pub fn AgentDefStore::path_of(
  self : AgentDefStore,
  name : String,
) -> String raise Failure {
  if name.length() == 0 {
    raise Failure("agent definition name must not be empty")
  }
  if name.contains("/") || name.contains("\\") || name.contains("..") {
    raise Failure(
      "invalid agent definition name \"\{name}\": must not contain '/', '\\' or '..'",
    )
  }
  @util.path_join(self.dir, "\{name}.md")
}

///|
/// 确保定义目录存在。风格同 `DataPaths::ensure_root`：
/// `@fs.mkdir` 缺省 `recursive=false`，且其递归回退仅在 ENOENT 时生效，
/// 故必须显式传 `recursive=true`（Phase 0 门禁实测）。
pub async fn AgentDefStore::ensure_dir(self : AgentDefStore) -> Unit {
  if !@fs.exists(self.dir) {
    @fs.mkdir(self.dir, recursive=true)
  }
}

///|
/// 名为 `name` 的定义是否存在。
pub async fn AgentDefStore::exists(self : AgentDefStore, name : String) -> Bool {
  @fs.exists(self.path_of(name))
}

///|
/// 写入一个定义文件，返回**是否发生了覆盖**。
///
/// · 已存在且 `overwrite=false` → raise（消息含 "already exists"，
///   经 mcp 的 `call_tool` 变成 LLM 可自我纠正的 isError 响应）；
/// · 已存在且 `overwrite=true` → 覆盖，返回 `true`；
/// · 不存在 → 创建，返回 `false`。
///
/// ★ W4（store 评审）修复：覆盖改为 **tmp + rename 原子替换**，
/// 与 `Jsonl::write_json_atomic` 同一配方。旧实现是 `CreateOrTruncate`
/// **原地截断** —— 写中途崩溃会留下一个半截的 `<name>.md`，且
/// `exists()` 检查与写入之间存在竞态窗口。rename 在同一文件系统内
/// 是原子的：读者要么看到旧版全文，要么看到新版全文，永远不会看到半截。
pub async fn AgentDefStore::write(
  self : AgentDefStore,
  name : String,
  content : String,
  overwrite? : Bool = false,
) -> Bool {
  let path = self.path_of(name)
  self.ensure_dir()
  let existed = @fs.exists(path)
  if existed {
    if !overwrite {
      raise Failure(
        "agent definition \"\{name}\" already exists at \{path}; pass overwrite=true to replace it",
      )
    }
  }
  // 统一走 tmp + rename：新文件与覆盖都是「写临时文件 → 原子改名」。
  // 不存在时 rename 同等于创建；存在时原子替换。绝不原地截断目标。
  let tmp = "\{path}.tmp"
  @fs.write_file(tmp, content, create_mode=CreateOrTruncate)
  @fs.rename(tmp, path)
  existed
}

///|
/// 读取定义全文。缺失 → raise。
///
/// 与 `Jsonl::load` 的「缺失返回空」不同：定义是**单文件**而非 append-only
/// 日志，缺失属于调用方逻辑错误（名字打错 / 文件被并发删除），
/// 必须显式暴露而不是静默返回空内容。
pub async fn AgentDefStore::read(self : AgentDefStore, name : String) -> String {
  let path = self.path_of(name)
  if !@fs.exists(path) {
    raise Failure("agent definition \"\{name}\" not found at \{path}")
  }
  @fs.read_file(path).text()
}

///|
/// 删除定义。缺失 → raise（与 write 的「已存在才允许覆盖」是同一条
/// 显式性原则：删一个不存在的名字几乎总是调用方拼错了 name）。
pub async fn AgentDefStore::remove(self : AgentDefStore, name : String) -> Unit {
  let path = self.path_of(name)
  if !@fs.exists(path) {
    raise Failure("agent definition \"\{name}\" not found at \{path}")
  }
  @fs.remove(path)
}

///|
/// 列出全部定义名（**不带** `.md` 后缀，可直接喂给 `read` / `remove`）。
///
/// · 只列 `*.md`（说明性文件被天然排除）；
/// · 目录不存在 → 空数组（首次使用前 `agents/` 尚未建立是正常状态）；
/// · 按字典序排序 —— `@fs.readdir` 的 `sort` 不承诺字典序，且实测
///   `String` 的 `<` 先比长度（结论 T16），显式 `lexical_compare`
///   才有确定性的输出顺序（决策 D10）。
pub async fn AgentDefStore::list(self : AgentDefStore) -> Array[String] {
  if !@fs.exists(self.dir) {
    return []
  }
  // readdir 失败（权限、竞态删除）时当作空目录：列表路径不让 I/O 抖动炸掉
  let names : Array[String] = @fs.readdir(self.dir, include_hidden=true) catch {
    _ => []
  }
  let out : Array[String] = []
  for n in names {
    if n.has_suffix(".md") {
      out.push(n[:n.length() - 3].to_owned())
    }
  }
  out.sort_by(fn(a, b) { a.lexical_compare(b) })
  out
}
