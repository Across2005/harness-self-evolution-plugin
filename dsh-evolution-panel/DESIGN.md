# dsh-evolution-panel · 设计契约

> 只读浮窗：把 harness-self-evolution（单元 A）的运行时装进 DSH Web 会话标题栏旁的一个面板。
> 它不注入消息、不触发执行、不修饰数据。**首要美德是如实。**

## Design Mandate

- 产品意图：把「扫插件 → 信号 → 提案 → 审批 → DAG 执行 → 三级验证」这条流水线的**当前盘上状态**变成一眼可读的工作图。
- 主要受众：监督自进化跑动的 DSH 用户 / 插件作者本人。
- 核心待办之完成判据：开面板 3 秒内回答「现在有什么提案、上次执行跑到哪层、哪些数据其实没接线」。
- 成功标准：全局数据如实标注为全局；空与未接线语义分离；损坏行原样呈现；无跨轮伪造。

## 数据通道决议（S3 spike 记录）

| 候选 | 判定 |
|------|------|
| A 会话投影附着（watcher 先例） | 语义错位：投影是 per-session 事件折叠，进化数据是全局文件态。仅作退路。 |
| **B Typert Gateway（采纳）** | Host 侧 `TypertRemoteService` + `@Remote` 注册 `evolution/snapshot` 与 `evolution/watch`（logical stream）；client 经 `ctx.remote.evolution.*` 消费。编译链已在 0.1.6-alpha.1 的 d.ts 上验证。**运行时可见性（网关是否放行插件贡献的服务）待 S5 实机验证**，失败则回退 A。 |
| C 事件转发白名单 | 白名单固定（`API_REMOTE_FORWARDED_EVENTS`），无自定义事件位。不可行。 |

- 版本基线：peer 钉 `@deepseek-ai/* 0.1.6-alpha.1`（对齐投放的 runtime），cordis 4.0.2。宿主升级属新决策。
- 轮询：Host 侧 5s mtime/size 签名变化才重读；数据根不可读时保留上一视图，不闪空。

## 三视区语义

1. **管道总览**：提案按 wire 状态计数条（pending/approved/executing/completed/rejected，仅显非零）+ 扫描档案数 + 损坏行计数。proposals.jsonl 折叠语义与单元 A 一致（同 id 后行覆盖）。
2. **执行时间线**：`execution.jsonl` 优先（缺失回落 `execution.log` 并标注「旧文本日志」+ 缺口说明）；事件文案固定为 开始/进度/失败/已回滚/完成，未知事件原样显示 wire 名；尾部半行丢弃待下轮（标注「尾部半行待下轮」，不算异常）；malformed 行前缀「异常行」原文展示，不修复。
3. **指标与缺口**：metrics/signals 行数为 0 时显示「未接线」（缺陷 9 语境），**绝不显示为 0 活动**；`dataGaps` 全文罗列。

## 状态语言

- 头部只有一处连接态文案：`连接中 / 等待数据 / 更新于 HH:MM:SS / 未获取到数据`。
- 失败与回滚是证据不是任务：红仅强调「失败/已回滚」文字，状态永远有文字承载，不单靠颜色。
- 无聚合成功徽章；无「需要处理」式召唤。

## 视觉与可及性

- 字号下限 13/13/12（正文/代码/元数据）；数字 tabular-nums；色彩仅引用宿主 `--dsw-*` 语义 token 加回退值。
- Portal 挂 body，z-index 固定于 shell 之上；Esc 关闭并把焦点还给触发按钮；`aria-expanded`/`role=dialog` 完整。
- 当前无动效预算（v1 静态显隐）；后续动效须尊重 `prefers-reduced-motion`。

## Quality Gates（验收逐条自查）

1. 空数据根首开：三视区各自显示空态/未接线文案，无伪造数字。
2. 塞一行损坏 JSONL：时间线出现「异常行」原文，其余记录不受影响。
3. 删除 execution.jsonl 只留 .log：来源标注切换 + 缺口说明出现。
4. 执行进行中打开面板：每 DAG 层的 progress 在 ≤5s 内追加，proposal 状态计数随之变化。
5. Host 拒绝服务放行：面板显示「未获取到数据」并解释，不白屏、不谎报在线。
6. `npm run typecheck && npm test && npm run build` 全绿才可声明可安装。

## Non-goals

不触发 approve/execute；不画图表装饰；不做历史全量归档视图（tail 窗内）；不展示提案正文 diff（那是宿主对话的事）。
