///|
/// 运行时快照 —— 把**盘上**的运行时内容聚合为一份只读 JSON，
/// 供 `get_runtime_snapshot` 工具与外部可视化（DSH 浮窗）消费。
///
/// 设计立场：
/// - **只读**：不写任何文件、不触发扫描或执行，与 `read_tail` 同谱系。
/// - **如实**：metrics/signals 为空时点名「未接线」（CONTEXT 已知缺陷 9），
///   绝不把「没有数据源」呈现成「没有活动」，也不造数。
/// - **浅聚合**：各段数据都取自既有单一入口（`PluginCache` /
///   `ProposalStore` / `ExecutionLog`），本文件不新造任何存储语义。
///
/// 四段形状（稳定契约，浮窗与脚本按此解析）：
/// ```json
/// { "success": true, "generated_at": "...", "root": "...",
///   "plugin_cache": { "exists": bool, "count": int, "plugins": [ {...} ] },
///   "proposals": { "total": int, "count_by_status": {...}, "recent": [...] },
///   "execution": { "tail_lines_requested": int, "records": [ExecLogRecord] },
///   "data_gaps": [ "..." ] }
/// ```

///|
/// 快照尾窗的硬上限。Schema 只声明 minimum，上限在这里收口，
/// 防止一次快照把无界日志塞进 MCP 响应。
pub let max_snapshot_tail : Int = 5000

///|
/// `recent` 列表最多呈现的提案数（旧→新取最近）。
let recent_proposals : Int = 10

///|
/// 组装运行时快照。`tail_lines` 请求的日志尾窗行数（调用方负责
/// 先夹到 [1, max_snapshot_tail]）。
pub async fn runtime_snapshot(
  paths : DataPaths,
  proposals : ProposalStore,
  tail_lines : Int,
) -> Json {
  // —— 段 1：扫描缓存（磁盘档案，不是进程注册表 —— 快照回答的是
  // 「盘上现在有什么」，注册表随进程生死）。
  let cached = PluginCache::at(paths).load()
  let plugin_items : Array[Json] = []
  for entry in cached {
    let p = entry.profile
    plugin_items.push({
      "plugin_id": Json::string(p.plugin_id),
      "name": Json::string(p.name),
      "version": Json::string(p.version),
      "path": Json::string(p.path),
      "scanned_at": Json::string(@util.iso_utc(p.scanned_at)),
      "complexity_score": Json::number(p.initial_metrics.complexity_score),
    })
  }

  // —— 段 2：提案状态机全量计数 + 最近若干条。
  // list(limit=None) = 全量；过滤顺序语义不在这里复制，只做计数。
  let all = proposals.list({ status: None, plugin_id: None, limit: None, })
  let by_status : Map[String, Int] = Map([])
  for p in all {
    let key = p.status.wire_name()
    let prev : Int = match by_status.get(key) {
      Some(c) => c
      None => 0
    }
    by_status.set(key, prev + 1)
  }
  let status_counts : Map[String, Json] = Map([])
  for (k, v) in by_status {
    status_counts.set(k, Json::number(v.to_double()))
  }
  let recent_items : Array[Json] = []
  let n = all.length()
  let skip = if n > recent_proposals { n - recent_proposals } else { 0 }
  for i = n; i > skip; i = i - 1 {
    // 新→旧：最该先看的排最前。
    let p = all[i - 1]
    recent_items.push({
      "proposal_id": Json::string(p.proposal_id),
      "plugin_id": Json::string(p.plugin_id),
      "status": ToJson::to_json(p.status),
      "created_at": Json::string(@util.iso_utc(p.created_at)),
    })
  }

  // —— 段 3：执行日志尾窗（旧→新）。
  let records = ExecutionLog::at(paths).read_tail(tail_lines)

  // —— 段 4：数据缺口，如实点名。
  let gaps : Array[String] = []
  let metrics_jsonl = Jsonl::new(paths.metrics())
  if !metrics_jsonl.exists() {
    gaps.push(
      "metrics.jsonl 不存在：record_tool_call 无生产调用方（CONTEXT 已知缺陷 9），指标链未接线 —— 这是「未接线」而非「无活动」。",
    )
  }
  let signals_jsonl = Jsonl::new(paths.signals())
  if !signals_jsonl.exists() {
    gaps.push(
      "signals.jsonl 不存在：信号检测链同样等待宿主事件注入（缺陷 9）。",
    )
  }
  if !@fs.exists(paths.plugin_cache()) {
    gaps.push(
      "plugin-cache.json 不存在：尚未做过任何一次成功扫描。",
    )
  }

  {
    "success": true,
    "generated_at": Json::string(@util.iso_utc(@util.now_ms())),
    "root": Json::string(paths.root()),
    "plugin_cache": {
      "exists": Json::boolean(@fs.exists(paths.plugin_cache())),
      "count": Json::number(cached.length().to_double()),
      "plugins": Json::array(plugin_items),
    },
    "proposals": {
      "total": Json::number(all.length().to_double()),
      "count_by_status": Json::object(status_counts),
      "recent": Json::array(recent_items),
    },
    "execution": {
      "tail_lines_requested": Json::number(tail_lines.to_double()),
      "records": ToJson::to_json(records),
    },
    "data_gaps": ToJson::to_json(gaps),
  }
}
