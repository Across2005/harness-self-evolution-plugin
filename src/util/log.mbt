///|
/// 全仓**唯一**的日志出口，物理上只写 `@stdio.stderr`。
///
/// **为什么这至关重要**：MCP 的 stdout 是 JSON-RPC 协议通道，混入任何非协议字节
/// 都会让客户端解析失败。legacy-ts 的 `src/**` 里有 **14 处 `console.log`**
/// （engine L61/75/82/90/124/148、executor L42/232/303/410、monitor L59/73、
/// scanner L63/150）、1 处 `console.warn`（store L44）、8 处 `console.error`，
/// 其中 `console.log` 默认写 **stdout**。TS 版之所以没炸，是因为
/// `@modelcontextprotocol/sdk` 的 `StdioServerTransport` 接管并 patch 了 `console.*`。
/// 本仓自研 stdio server **没有这层魔法**，必须自己在模块层面封死：
/// 本文件是全仓唯一引用 `@stdio.stderr` 的地方，任何模块想打日志只能走这三个函数。
///
/// 另有一条实测教训强化了这一设计：native 后端下**未捕获异常的错误信息会被打到
/// stdout**（Phase 0 门禁实测），所以 `mcp/server.mbt` 的服务循环必须兜住一切错误，
/// 绝不能让异常逃出到运行时默认处理器。
///
/// 输出格式刻意保持 legacy-ts 的 `[Tag] message`，不带级别前缀 ——
/// 这样双跑对拍时 stderr 也能逐行比对。
///
/// `@io.Writer::write` 是 `async fn`，故这三个函数也是 async。
/// 全仓 23 处日志调用点都位于 async 函数内，不构成约束。

///|
/// 常规进度信息。对应 legacy-ts 的 `console.log`。
pub async fn log_info(tag : String, msg : StringView) -> Unit {
  @stdio.stderr.write("[\{tag}] \{msg}\n")
}

///|
/// 可容忍的异常（如 JSONL 里的损坏行被跳过）。对应 legacy-ts 的 `console.warn`。
pub async fn log_warn(tag : String, msg : StringView) -> Unit {
  @stdio.stderr.write("[\{tag}] \{msg}\n")
}

///|
/// 失败。对应 legacy-ts 的 `console.error`。
pub async fn log_error(tag : String, msg : StringView) -> Unit {
  @stdio.stderr.write("[\{tag}] \{msg}\n")
}
