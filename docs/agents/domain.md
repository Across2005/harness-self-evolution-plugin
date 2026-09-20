# Domain Docs

工程类 skill 在探索本仓库代码时，应如何消费本仓库的领域文档。

## 探索之前先读这些

- 仓库根的 **`CONTEXT.md`**；或
- 若存在仓库根的 **`CONTEXT-MAP.md`**：它指向每个 context 各自的 `CONTEXT.md`，读与当前主题相关的那些。
- **`docs/adr/`**：读与即将改动的区域相关的 ADR。多 context 仓库还要看 `src/<context>/docs/adr/` 里的 context 级决策。

这些文件不存在就**静默继续**：不要指出缺失、不要建议提前创建。`/domain-modeling`
（经 `/grill-with-docs` 与 `/improve-codebase-architecture` 到达）会在术语或决策真正被
确定时惰性创建它们。

## 文件结构

本仓库是 **single-context**（根目录无 `CONTEXT-MAP.md`）：

```
/
├── CONTEXT.md          ← 词汇表、架构不变量、缺陷清单、配置来源
├── docs/adr/           ← 尚未创建；由 /domain-modeling 惰性创建
└── src/                ← 按包分层：util → types → store → scanner/monitor/planner → engine/executor/factory → mcp → harness_evolution
```

## 使用词汇表的词汇

输出里命名领域概念时（issue 标题、重构提案、假设、用例名），使用 `CONTEXT.md` 中定义的术语，
不要漂移到词汇表刻意回避的同义词。

本仓库已登记的术语（示例，权威定义见 `CONTEXT.md`）：**插件档案 / plugin_id**、
**AgentScope（定义作用域）**、**提案状态机**、**进化类型**、**信号强度**、
**DSH home 路由**、**清单形态**、**架构不变量 ①–⑨**。

需要用的概念还不在词汇表里，本身就是一个信号：要么你在发明项目不使用的语言（重新考虑），
要么存在真实缺口（记下来交给 `/domain-modeling`）。

## 标出 ADR 冲突

若你的输出与既有 ADR 相矛盾，显式提出来，而不是悄悄覆盖：

> _与 ADR-0007（…）冲突，但值得重开，因为……_
