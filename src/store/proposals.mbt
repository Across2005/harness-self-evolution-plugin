///|
/// 进化提案的唯一事实来源。取代 legacy-ts/src/store/index.ts L90-175。
///
/// CONTEXT.md「架构不变量②」：提案状态只能经本模块流转，
/// engine / executor / mcp 共享同一个实例。
///
/// **相对 TS 版的两处结构性改进**：
///
/// 1. **进程内索引**。TS 的 `ProposalStore` 有 5 个查询方法
///    （`list` L118、`find` L126、`findPendingForPlugin` L157、`findDuplicate` L163、
///    `recentForPlugin` L169），**每一个都独立调用一次 `store.load()`**，
///    即每次都全量读文件 + 逐行 `JSON.parse`。而 `setStatus`（L140-155）
///    先 `find` 再 `update`，等于「2 次全量读 + 1 次全量写」。
///    新版把记录常驻内存并建三个索引：
///    `by_id`（O(1) 查提案）、`by_plugin`（O(k) 查某插件）、
///    `by_signature`（O(1) 去重）。查询全部走内存，`set_status` 只追加一行。
///
/// 2. **append-only + 按 proposal_id 折叠**，取代 TS 的 `rewrite`。
///    状态变更不再重写整个文件，而是追加一条该提案的完整新版本；
///    `reload` 时按 `proposal_id` 折叠，后出现的覆盖先出现的。
///    好处：崩溃永远不会留下半截文件（TS 的 `rewrite` 先截断再写，
///    中途失败即全量丢失），且写入成本与文件规模无关。
///
/// **缓存一致性**：`loaded_mtime` 记录上次加载时的文件修改时间。
/// `refresh` 只做一次 stat：时间未变 → 内存索引就是最新的，直接返回；
/// 时间变了（说明有别的进程写过）→ 全量重载。
/// 自己写入后立即刷新 `loaded_mtime`，于是单进程场景下 `refresh` 恒为 O(1) stat。
///
/// **并发安全性**：MoonBit 的 async 是单线程协作式调度，只在 await 处让出。
/// 索引更新与 `items` 写入之间没有 await 点，故进程内不需要互斥锁。
/// 跨进程靠 append-only 的单行原子写 + 下次 `refresh` 收敛：
/// `set_status` 在临界区开头强制 `refresh`，把陈旧窗口压到 0，
/// 因此两个会话同时审批同一提案时，后写者会看到前写者的状态，
/// 若构成非法迁移则报错，而不是静默覆盖 ——
/// 这正是 TS 版缺失的保证（其 `update` 是无锁的「读-改-全量写」，会互相丢更新）。

///|
/// 查询过滤条件。对应 legacy-ts 的 `ProposalFilter`（store L92-96）。
/// `pub(all)`：mcp 包需要直接构造它（而不只是读）。
pub(all) struct ProposalFilter {
  status : @types.ProposalStatus?
  plugin_id : String?
  limit : Int?
}

///|
/// 不过滤、不限数量。
pub fn ProposalFilter::all() -> ProposalFilter {
  { status: None, plugin_id: None, limit: None }
}

///|
/// 提案存储。
pub struct ProposalStore {
  jsonl : Jsonl
  /// 事实来源：按首次出现顺序排列的提案数组。索引里存的是它的下标。
  items : Array[@types.EvolutionProposal]
  /// proposal_id → items 下标
  by_id : Map[String, Int]
  /// plugin_id → items 下标列表（append-only 保证按 created_at 升序）
  by_plugin : Map[String, Array[Int]]
  /// signature → items 下标（指向**最近**一条同签名提案）
  by_signature : Map[String, Int]
  /// 上次加载时的文件 mtime；`None` 表示「还没加载过」或「文件不存在」
  mut loaded_mtime : (Int64, Int)?
}

///|
/// 按文件路径构造。
pub fn ProposalStore::new(path : String) -> ProposalStore {
  {
    jsonl: Jsonl::new(path),
    items: [],
    by_id: Map([]),
    by_plugin: Map([]),
    by_signature: Map([]),
    loaded_mtime: None,
  }
}

///|
/// 用 `DataPaths` 构造（生产路径）。
pub fn ProposalStore::at(paths : DataPaths) -> ProposalStore {
  ProposalStore::new(paths.proposals())
}

///|
/// 底层 JSONL 的文件路径。测试用它直接检查落盘内容。
pub fn ProposalStore::path(self : ProposalStore) -> String {
  self.jsonl.path()
}

///|
/// 全量重载并重建索引。按 `proposal_id` 折叠，后出现的记录覆盖先出现的。
async fn ProposalStore::reload(self : ProposalStore) -> Unit {
  let rows : Array[@types.EvolutionProposal] = self.jsonl.load()
  self.items.clear()
  self.by_id.clear()
  self.by_plugin.clear()
  self.by_signature.clear()
  for row in rows {
    // 折叠逻辑与 absorb 共用 `fold_row`：同 id 原位覆盖、签名索引指向最近一条
    self.fold_row(row)
  }
  self.loaded_mtime = self.jsonl.mtime()
}

///|
/// 若文件被外部改过则重载；否则什么都不做（一次 stat）。
///
/// 所有读路径与所有写路径的开头都调用它，这是内存索引与磁盘保持一致的唯一机制。
pub async fn ProposalStore::refresh(self : ProposalStore) -> Unit {
  let current = self.jsonl.mtime()
  if current == self.loaded_mtime {
    return
  }
  self.reload()
}

///|
/// 列出提案。三级过滤顺序 **status → plugin_id → limit**，limit 最后
/// （与 legacy-ts store L118-124 严格一致；调换顺序会改变结果）。
pub async fn ProposalStore::list(
  self : ProposalStore,
  filter : ProposalFilter,
) -> Array[@types.EvolutionProposal] {
  self.refresh()
  let out : Array[@types.EvolutionProposal] = []
  let limit = filter.limit.unwrap_or(self.items.length())
  for p in self.items {
    if out.length() >= limit {
      break
    }
    match filter.status {
      Some(wanted) if p.status != wanted => continue
      _ => ()
    }
    match filter.plugin_id {
      Some(wanted) if p.plugin_id != wanted => continue
      _ => ()
    }
    out.push(p)
  }
  out
}

///|
/// 按 id 查提案。O(1)。对应 legacy-ts store L126-129（那里是 O(N) 全量读 + 线性查找）。
pub async fn ProposalStore::find(
  self : ProposalStore,
  proposal_id : String,
) -> @types.EvolutionProposal? {
  self.refresh()
  match self.by_id.get(proposal_id) {
    Some(i) => Some(self.items[i])
    None => None
  }
}

///|
/// 写入一份新提案（追加一行 + 更新内存索引）。
pub async fn ProposalStore::save(
  self : ProposalStore,
  proposal : @types.EvolutionProposal,
) -> Unit {
  self.refresh()
  self.jsonl.append(proposal)
  self.absorb(proposal)
  // 自己刚写过，刷新水位以免下次 refresh 白白重载一遍
  self.loaded_mtime = self.jsonl.mtime()
}

///|
/// 把一条记录折叠进内存索引（append-only 折叠的内存侧）。
/// reload 与 absorb 共用这一份逻辑，避免「两处手写同一折叠」悄悄走样：
/// 同 proposal_id 的记录**原位覆盖**（保持首次出现的顺序），
/// 签名索引始终指向最近一条，供去重使用。
fn ProposalStore::fold_row(
  self : ProposalStore,
  row : @types.EvolutionProposal,
) -> Unit {
  let index = match self.by_id.get(row.proposal_id) {
    Some(i) => i
    None => {
      let i = self.items.length()
      self.items.push(row)
      self.by_id.set(row.proposal_id, i)
      let bucket = match self.by_plugin.get(row.plugin_id) {
        Some(b) => b
        None => {
          let fresh : Array[Int] = []
          self.by_plugin.set(row.plugin_id, fresh)
          fresh
        }
      }
      bucket.push(i)
      i
    }
  }
  self.items[index] = row
  self.by_signature.set(row.signature, index)
}

///|
/// 把一条记录并入内存索引（append-only 折叠的内存侧）。
/// 与 reload 共用 `fold_row` 的折叠实现，本函数只是语义化的调用名。
fn ProposalStore::absorb(
  self : ProposalStore,
  row : @types.EvolutionProposal,
) -> Unit {
  self.fold_row(row)
}

///|
/// 变更提案状态，强制执行 CONTEXT.md L19-25 的状态机。
///
/// 三种结果，与 legacy-ts store L140-155 逐条对应：
/// · 提案不存在 → `false`
/// · 目标状态与当前相同 → `true`（**幂等**，不追加任何记录）
/// · 非法迁移 → `raise Failure`，消息与 TS L147 逐字一致：
///   `"Illegal proposal status transition: completed → approved"`
///
/// 用内置的 `Failure`（携带一个 String）而非自定义 suberror：
/// TS 抛的就是 `new Error(msg)`，语义完全对应；
/// 而 MCP 层对任何错误都统一转成 `isError` + 消息文本，
/// 并不需要按错误类型分支，自定义错误类型只会增加一层没有消费者的抽象。
pub async fn ProposalStore::set_status(
  self : ProposalStore,
  proposal_id : String,
  status : @types.ProposalStatus,
) -> Bool {
  self.refresh()
  let index = match self.by_id.get(proposal_id) {
    Some(i) => i
    None => return false
  }
  let current = self.items[index]
  if current.status == status {
    return true // 幂等
  }
  if !current.status.can_transition_to(status) {
    raise Failure(
      "Illegal proposal status transition: \{current.status.wire_name()} → \{status.wire_name()}",
    )
  }
  // 只改 status，其余字段原样保留（对齐 TS L152 的 `{ ...p, status }`）：
  // struct 函数式更新 `..current` 逐字段浅拷贝，等价于 TS 的展开语法，
  // 且不会因 EvolutionProposal 增删字段而漏改这里。
  let updated : @types.EvolutionProposal = { ..current, status, }
  self.jsonl.append(updated)
  self.absorb(updated)
  self.loaded_mtime = self.jsonl.mtime()
  true
}

///|
/// 该插件是否有待处理提案。对应 legacy-ts store L157-160。
pub async fn ProposalStore::find_pending_for_plugin(
  self : ProposalStore,
  plugin_id : String,
) -> @types.EvolutionProposal? {
  self.refresh()
  for i in self.plugin_indices(plugin_id) {
    let p = self.items[i]
    if p.status == @types.ProposalStatus::Pending {
      return Some(p)
    }
  }
  None
}

///|
/// 同签名的**非 rejected** 提案，用于去重。对应 legacy-ts store L163-166。
/// O(1)（TS 是 O(N) 全量读 + filter）。
pub async fn ProposalStore::find_duplicate(
  self : ProposalStore,
  signature : String,
) -> @types.EvolutionProposal? {
  self.refresh()
  match self.by_signature.get(signature) {
    Some(i) => {
      let p = self.items[i]
      if p.status == @types.ProposalStatus::Rejected {
        None
      } else {
        Some(p)
      }
    }
    None => None
  }
}

///|
/// 冷却窗口内创建的该插件提案。对应 legacy-ts store L169-174。
///
/// TS 写的是 `Date.now() - new Date(p.created_at).getTime() < cooldownMs`，
/// 每条都要解析一次 ISO 字符串；新版 `created_at` 本就是 Int64 毫秒，
/// 直接相减 —— 无解析、无 raise、无时区歧义。
/// 边界是**严格小于**：恰好等于 `cooldown_ms` 不算命中。
pub async fn ProposalStore::recent_for_plugin(
  self : ProposalStore,
  plugin_id : String,
  cooldown_ms : Int64,
) -> Array[@types.EvolutionProposal] {
  self.refresh()
  let now = @util.now_ms()
  let out : Array[@types.EvolutionProposal] = []
  for i in self.plugin_indices(plugin_id) {
    let p = self.items[i]
    if now - p.created_at < cooldown_ms {
      out.push(p)
    }
  }
  out
}

///|
/// 某插件的下标列表；没有则空数组。
fn ProposalStore::plugin_indices(
  self : ProposalStore,
  plugin_id : String,
) -> Array[Int] {
  self.by_plugin.get(plugin_id).unwrap_or([])
}

///|
/// 内存中的提案总数（折叠后）。暂无生产调用方，保留作诊断与测试断言之用。
pub async fn ProposalStore::count(self : ProposalStore) -> Int {
  self.refresh()
  self.items.length()
}
