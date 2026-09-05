///|
/// MCP stdio 传输层。取代 legacy-ts/src/mcp/server.ts L292-336
/// （`start()` / `stop()` / `main()` / SIGINT-SIGTERM 处理）。
///
/// 传输格式是 **NDJSON**：一行一个 JSON-RPC 消息，消息体内不得含裸换行
/// （`Json::stringify` 默认不产生裸换行，故天然满足）。
///
/// **通道纪律（本文件最重要的约束）**：
/// stdout **只**承载 JSON-RPC 响应字节。全部日志走 stderr（`util/log.mbt`
/// 是全仓唯一引用 `@stdio.stderr` 的地方）。这不是风格问题 ——
/// 混入任何非协议字节都会让客户端解析失败，而 legacy-ts 之所以没炸，
/// 是因为 `@modelcontextprotocol/sdk` 的 `StdioServerTransport` 接管并 patch 了
/// `console.*`（src/** 里有 14 处 `console.log` 默认写 stdout）。
/// 自研 server 没有这层魔法，必须自己封死。
///
/// **每条响应后立即 flush**：客户端在阻塞等待，
/// `BufferedWriter` 的缓冲会导致它永久挂起。缓冲只对「批量写」有意义，
/// 对「请求-响应」是纯粹的延迟。
///
/// **顺序处理请求，不为每条请求 spawn 任务**：单客户端 MCP 场景下，
/// 串行天然规避了对共享 `ProposalStore` 与插件注册表的竞态。
/// 代价是 `execute_evolution` 执行期间其他调用会排队 ——
/// 这是有意的取舍，已记入 README。

///|
/// 服务循环：读 stdin 的每一行，回一行响应，直到 EOF。
///
/// stdin EOF 是**主要退出路径**（决策 D16）：MCP 客户端断开即 EOF，
/// 覆盖全部正常场景。信号处理是补充 —— `moonbitlang/async` 的默认全局取消信号
/// 已包含 Windows 上有意义的 SIGINT（CTRL_C_EVENT）、SIGHUP（CTRL_CLOSE_EVENT）
/// 与 SIGBREAK；SIGTERM 在 Windows 无对应，会被库静默忽略。
/// 因此这里**不**显式调 `set_global_cancellation_signals`：
/// 默认列表比我们能写出的更完整，显式传一个子集反而是缩减覆盖面。
pub async fn serve_stdio(state : ServerState) -> Unit {
  let out = @io.BufferedWriter::new(@stdio.stdout, size=16 * 1024)
  while @stdio.stdin.read_until("\n") is Some(line) {
    let trimmed = line.trim().to_owned()
    if trimmed.length() == 0 {
      continue // 容忍空行（心跳/分隔）
    }
    match handle_line(state, trimmed) {
      Some(response) => {
        out.write(response.stringify())
        out.write("\n")
        out.flush()
      }
      None => () // 通知：不回应
    }
  }
  out.flush()
}

///|
/// 处理一行输入，产出响应（或 `None` 表示通知、不回应）。
///
/// ★ **本函数是「绝不让异常逃到 stdout」的最后一道闸门。**
/// Phase 0 门禁实测：native 后端下未捕获异常的信息会被打到 **stdout**，
/// 那会直接污染 MCP 协议通道、让客户端断开。
/// 于是这里把「解析 → 校验 → 派发」整条链路包进 try/catch，
/// 任何逃逸的错误都变成一条合法的 JSON-RPC 错误响应。
/// `call_tool` 里那层 catch 处理的是**工具级**错误（转 isError），
/// 这一层处理的是**协议级**意外，两者职责不同、缺一不可。
///
/// 写成 async：它要调 `@util.log_error`（写 stderr 是 async）与
/// `handle_message`（工具执行是 async）。
async fn handle_line(state : ServerState, line : String) -> Json? {
  // 第一步：JSON 解析 → 失败则 -32700
  let parsed : Result[Json, String] = Ok(@json.parse(line)) catch {
    e => Err(e.to_string())
  }
  match parsed {
    Err(reason) => {
      @util.log_error("Server", "Parse error: \{reason}")
      Some(error_msg(None, code_parse_error, "Parse error"))
    }
    Ok(message) => handle_parsed(state, message)
  }
}

///|
/// 第二步与第三步：消息形状校验 → 派发。
///
/// 拆成两个函数而不是在 `handle_line` 里一路写下去，是为了避开
/// 「在 match 分支的表达式位置用 `return`」这类控制流纠缠 ——
/// 每一层都只靠 match 的返回值向外传，读起来与错误阶梯一一对应。
async fn handle_parsed(state : ServerState, message : Json) -> Json? {
  match parse_message(message) {
    None => {
      @util.log_error("Server", "Invalid Request: not a JSON-RPC 2.0 message")
      Some(
        error_msg(
          best_effort_id(message),
          code_invalid_request,
          "Invalid Request: expected a JSON-RPC 2.0 object with a string \"method\"",
        ),
      )
    }
    Some(request) => {
      let outcome : Result[Json?, String] = Ok(handle_message(state, request)) catch {
        e => Err(e.to_string())
      }
      match outcome {
        Ok(response) => response
        Err(reason) => {
          @util.log_error(
            "Server",
            "Internal error while handling \{request.method_name}: \{reason}",
          )
          Some(error_msg(request.id, code_internal_error, "Internal error"))
        }
      }
    }
  }
}

///|
/// 从一条形状不合法的消息里尽力取出 `id`，好让错误响应能对上号。
/// 取不到就用 `null`（JSON-RPC 2.0 对「无法确定 id」的规定）。
fn best_effort_id(message : Json) -> Json? {
  match message {
    Object(obj) => obj.get("id")
    _ => None
  }
}
