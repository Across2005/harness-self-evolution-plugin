///|
/// Sub-Agent 任务的拓扑分层。取代 legacy-ts/src/executor/index.ts L76-94 的
/// **纯串行** `for (const task of tasks)` 循环。
///
/// **为什么 TS 只能串行**：它的 `SubAgentTask.dependencies` 字段
/// （types L261 注释写 "Other task IDs"）实际存的是 **AgentType 字符串**
/// （L193 `[tasks[tasks.length-1].agent]`、L217 `['code-generator','test-writer']`），
/// 而且**全仓没有任何读取点** —— 它从未被用于排序。当提案含多类变更时
/// `decomposeTasks` 会产出最多 5 个 code-generator 任务（L142-185），
/// 此时「依赖 code-generator」到底指哪一个完全歧义。
///
/// 新版给每个任务稳定的 `id` 与真正的 task-id `deps`，
/// 于是可以做 Kahn 分层：**同层任务互不依赖，可完全并行**。
/// 以 `interface_simplification` 提案为例（cg-merge + tw + dw + integ）：
/// ```text
/// layer 0: [cg-merge, dw]   ← 并行 2 个
/// layer 1: [tw]
/// layer 2: [integ]
/// ```
/// TS 串行跑 4 步；新版 3 层。接入真实 LLM Sub-Agent 后（每任务 5-30 s），
/// 这是 wall-clock 的主要收益来源；`doc-writer` 尤其值得解放出来，
/// 它与代码生成之间本来就没有真实依赖。
///
/// 层内**按任务下标排序**后再返回，于是分层结果完全确定、可复现。

///|
/// 把任务集切成拓扑层。返回的每个内层数组是「可以并行执行的任务下标」。
///
/// 两种失败都用 `Failure` 上抛，消息里带上具体任务 id，
/// 因为这两种情况都属于**提案分解逻辑自身的 bug**（不是用户输入问题）：
/// · 依赖了不存在的任务 id
/// · 依赖成环
///
/// 调用方（`UpgradeExecutor::execute`）会把它当作执行失败处理并回滚到 pending。
pub fn topo_layers(
  tasks : ArrayView[@types.SubAgentTask],
) -> Array[Array[Int]] raise {
  let n = tasks.length()
  if n == 0 {
    return []
  }

  let index_of : Map[String, Int] = Map([])
  for i in 0..<n {
    index_of.set(tasks[i].id, i)
  }

  let indegree : Array[Int] = Array::make(n, 0)
  let dependents : Array[Array[Int]] = []
  for _ in 0..<n {
    dependents.push([])
  }
  for i in 0..<n {
    for dep in tasks[i].deps {
      match index_of.get(dep) {
        Some(j) => {
          indegree[i] += 1
          dependents[j].push(i)
        }
        None =>
          raise Failure(
            "Task \"\{tasks[i].id}\" depends on unknown task \"\{dep}\"",
          )
      }
    }
  }

  let layers : Array[Array[Int]] = []
  let mut current : Array[Int] = []
  for i in 0..<n {
    if indegree[i] == 0 {
      current.push(i)
    }
  }
  let mut placed = 0
  while !current.is_empty() {
    current.sort_by(fn(a, b) { a - b })
    layers.push(current.copy())
    placed += current.length()
    let next : Array[Int] = []
    for i in current {
      for d in dependents[i] {
        indegree[d] -= 1
        if indegree[d] == 0 {
          next.push(d)
        }
      }
    }
    current = next
  }

  if placed != n {
    // 有任务始终入度不为 0 → 依赖成环
    let stuck : Array[String] = []
    for i in 0..<n {
      if indegree[i] > 0 {
        stuck.push(tasks[i].id)
      }
    }
    raise Failure(
      "Cyclic dependency among sub-agent tasks: \{stuck.join(", ")}",
    )
  }
  layers
}

///|
/// 关键路径长度（层数）。用于日志与基准对比：
/// TS 的 wall-clock 是 Σ(全部任务)，新版是 Σ_layers(max(层内))。
pub fn critical_path_len(layers : ArrayView[Array[Int]]) -> Int {
  layers.length()
}

///|
/// 任务总数。
pub fn task_count(layers : ArrayView[Array[Int]]) -> Int {
  let mut n = 0
  for layer in layers {
    n += layer.length()
  }
  n
}
