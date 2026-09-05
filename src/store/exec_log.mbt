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
/// 执行日志文件。
pub struct ExecutionLog {
  path : String
}

///|
/// 按文件路径构造。
pub fn ExecutionLog::new(path : String) -> ExecutionLog {
  { path: @util.expand_home(path) }
}

///|
/// 用 `DataPaths` 构造（生产路径）。
pub fn ExecutionLog::at(paths : DataPaths) -> ExecutionLog {
  ExecutionLog::new(paths.execution_log())
}

///|
/// 文件路径。测试用它直接读回落盘内容做断言。
pub fn ExecutionLog::path(self : ExecutionLog) -> String {
  self.path
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
}

///|
/// 读回全部日志行（不含换行符）。文件不存在返回空数组。
/// 供测试与将来的 `status` 子命令使用。
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
