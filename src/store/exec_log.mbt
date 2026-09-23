///|
/// 执行日志。收拢 legacy-ts/src/executor/index.ts L423-428 的直接
/// `fs.ensureDir` + `fs.appendFile`（那是不变量①的另一处越界）。
///
/// 与 JSONL 不同，`execution.log` 是**给人读的纯文本追加日志**，
/// 所以行格式与 legacy-ts L426 保持一致：
/// ```text
/// [<ISO-8601>] [<proposal_id>] [<event>] <message>
/// ```
/// 时间戳在**输出边界**才由 Int64 毫秒格式化为 ISO 串（内部一律 Int64，见 util/time.mbt）。

///|
/// 执行事件类别。取代 legacy-ts 里裸传的 `event : string` 参数
/// （executor L67/82/93/101/114/123/417 分别传
/// `'start'` / `'error'` / `'progress'` / `'complete'` / `'rollback'`）。
/// 闭合枚举后拼错事件名在编译期就会被拒绝。
pub(all) enum ExecEvent {
  Start
  Progress
  Error
  Complete
  Rollback
} derive(Eq, Debug)

///|
/// wire 名 = legacy-ts 实际写入日志的那几个小写字符串，逐字保留，
/// 使新旧 `execution.log` 在人类眼里仍然对得上。
///
/// 刻意**不**为它写 `ToJson` / `FromJson` impl：这个枚举从不进入 JSON，
/// 只出现在文本日志里。少两个 impl 就少两个「只为对称而存在」的无消费者定义。
pub let exec_event_wire : @util.WireEnum[ExecEvent] = @util.WireEnum::of([
  ("start", ExecEvent::Start),
  ("progress", ExecEvent::Progress),
  ("error", ExecEvent::Error),
  ("complete", ExecEvent::Complete),
  ("rollback", ExecEvent::Rollback),
])

///|
/// wire 名。
pub fn ExecEvent::wire_name(self : ExecEvent) -> String {
  exec_event_wire.name_of(self)
}

///|
/// 执行日志文件。`events_path` 为 `Some` 时启用同源双写
/// （v2.7 可视化数据面）：文本行格式一字不改，另把同一事件
/// 以一行 JSON 追加到结构化档案。
pub struct ExecutionLog {
  path : String
  events_path : String?
}

///|
/// 按文件路径构造（不启用双写，保持既有测试语义）。
pub fn ExecutionLog::new(path : String) -> ExecutionLog {
  { path: @util.expand_home(path), events_path: None, }
}

///|
/// 用 `DataPaths` 构造（生产路径，启用双写）。
pub fn ExecutionLog::at(paths : DataPaths) -> ExecutionLog {
  {
    path: @util.expand_home(paths.execution_log()),
    events_path: Some(paths.execution_events()),
  }
}

///|
/// 追加一行。父目录不存在时自动创建。
///
/// 与 legacy-ts 的差异：TS 每条日志都 `ensureDir` + `appendFile`
/// （打开-写入-关闭，2 次 syscall），一次 `execute` 约 8-12 条日志即 ~24 次 syscall。
/// 这里同样每条一次 `write_file`（保持简单的崩溃安全语义：日志绝不能丢），
/// 但省掉了 `ensureDir` —— 目录只在首次创建，之后 `exists` 检查即返回。
pub async fn ExecutionLog::append(
  self : ExecutionLog,
  proposal_id : String,
  event : ExecEvent,
  message : String,
) -> Unit {
  let dir = @util.path_dirname(self.path)
  if dir != "." && dir != "/" && !@fs.exists(dir) {
    @fs.mkdir(dir, recursive=true)
  }
  let stamp = @util.iso_utc(@util.now_ms())
  let line = "[\{stamp}] [\{proposal_id}] [\{event.wire_name()}] \{message}\n"
  @fs.write_file(self.path, line, create_mode=OpenOrCreate, append=true)
  // ★ v2.7 同源双写：文本行是事实来源（上面已写成功），这份 JSONL 是
  // 它的机器可读镜像，时间戳共用同一个 stamp 保证两文件逐事件对齐。
  match self.events_path {
    Some(ep) => {
      let dir2 = @util.path_dirname(ep)
      if dir2 != "." && dir2 != "/" && !@fs.exists(dir2) {
        @fs.mkdir(dir2, recursive=true)
      }
      let record : ExecLogRecord = {
        ts: stamp,
        proposal_id,
        event: event.wire_name(),
        message,
        malformed: false,
      }
      // 用 trait 调用形式 `ToJson::to_json(record)` 而非 `record.to_json()`：
      // 后者是从 derive(ToJson) 隐式提升的点号方法，moonc v0.10.14 起已 deprecated，
      // 未来会随隐式提升一并移除；改走 trait 形式以免依赖该提升。
      let json_line = "\{ToJson::to_json(record).stringify()}\n"
      @fs.write_file(ep, json_line, create_mode=OpenOrCreate, append=true)
    }
    None => ()
  }
}

///|
/// 读回全部日志行（不含换行符）。文件不存在返回空数组。
/// 供测试与 `read_tail`（运行时快照尾窗）使用。
pub async fn ExecutionLog::read(self : ExecutionLog) -> Array[String] {
  if !@fs.exists(self.path) {
    return []
  }
  let content = @fs.read_file(self.path).text()
  let out : Array[String] = []
  for line in content.split("\n") {
    let trimmed = line.trim().to_owned()
    if trimmed.length() > 0 {
      out.push(trimmed)
    }
  }
  out
}

///|
/// 一条**已解析**的执行日志记录。为运行时可视化（`get_runtime_snapshot`
/// 与 DSH 浮窗）提供机器可读形状。
///
/// `event` 保留日志里的**原文**（不映射回 `ExecEvent` 枚举）：未知的
/// 事件名如实呈现而不是被丢弃或改写。`ExecEvent` 本身继续不进 JSON
/// （见本文件上方的既有立场）—— 这里的 ToJson 属于记录体，不属于枚举。
pub(all) struct ExecLogRecord {
  ts : String
  proposal_id : String
  event : String
  message : String
  /// 行结构不符合 `[ts] [id] [event] msg` 时为 true：整行原文进
  /// `message`，其余字段为空串。**不修复、不丢弃** —— 损坏行也是证据。
  malformed : Bool
} derive(Eq, Debug, ToJson, @json.FromJson)

///|
/// 行格式的机器可读对照：三个方括号字段 + 空格 + 消息原文。
/// 与 `append` 的写入格式逐字同源（写侧改格式，这里必须同步改）。
let re_exec_line : @string.Regex = @string.Regex::unsafe_from_string(
  "^\\[([^\\]]*)\\] \\[([^\\]]*)\\] \\[([^\\]]*)\\] (.*)$",
)

///|
/// 解析一行执行日志。格式不符时返回 `malformed=true` 的兜底记录。
pub fn parse_exec_line(line : String) -> ExecLogRecord {
  let bad : ExecLogRecord = {
    ts: "",
    proposal_id: "",
    event: "",
    message: line,
    malformed: true,
  }
  // find 的迭代器在 ^…$ 锚定下最多一个命中；组内不含 ']'，
  // 所以贪婪跨界不可能发生，group(4) 到行尾。
  for m in @string.Regex::find(re_exec_line, line) {
    let ts = match m.group(1) {
      Some(v) => v.to_owned()
      None => return bad
    }
    let pid = match m.group(2) {
      Some(v) => v.to_owned()
      None => return bad
    }
    let ev = match m.group(3) {
      Some(v) => v.to_owned()
      None => return bad
    }
    let msg = match m.group(4) {
      Some(v) => v.to_owned()
      None => ""
    }
    return { ts, proposal_id: pid, event: ev, message: msg, malformed: false, }
  }
  bad
}

///|
/// 读最近 `n` 条日志记录（旧→新）。文件不存在或 n≤0 返回空数组。
///
/// 尾窗取自 `read` 的全量行 —— 与 `get_metrics` 每次全量读盘同谱系
/// （execution.log 只在执行期写入，每次约 8-12 行，增长线性且稀疏）。
/// 真·窗口读需要偏移读 + 字节解码，收益当前撑不起其复杂度，留作日志
/// 量级证明 needed 之后的优化（届时同步评估保留策略，见 CONTEXT「窗口裁剪」段）。
pub async fn ExecutionLog::read_tail(
  self : ExecutionLog,
  n : Int,
) -> Array[ExecLogRecord] {
  if n <= 0 {
    return []
  }
  // 优先读结构化镜像（v2.7 双写产物）；镜像不存在则回落文本解析 ——
  // 旧数据（双写上线前）仍然可视。
  let from_events = match self.events_path {
    Some(ep) if @fs.exists(ep) => Some(ep)
    _ => None
  }
  let records : Array[ExecLogRecord] = match from_events {
    Some(ep) => {
      let out : Array[ExecLogRecord] = []
      for line in @fs.read_file(ep).text().split("\n") {
        let trimmed = line.trim().to_owned()
        if trimmed.length() == 0 {
          continue
        }
        let parsed : Result[ExecLogRecord, String] = Ok(
          @json.from_json(@json.parse(trimmed)),
        ) catch {
          err => Err(err.to_string())
        }
        match parsed {
          // 坏行不静默：整行原文进 message 并标 malformed（与文本侧同口径）。
          Ok(r) => out.push(r)
          Err(_) =>
            out.push({
              ts: "",
              proposal_id: "",
              event: "",
              message: trimmed,
              malformed: true,
            })
        }
      }
      out
    }
    None => {
      let lines = self.read()
      lines.map(fn(l) { parse_exec_line(l) })
    }
  }
  let total = records.length()
  let skip = if total > n { total - n } else { 0 }
  let out : Array[ExecLogRecord] = []
  for i = skip; i < total; i = i + 1 {
    out.push(records[i])
  }
  out
}
