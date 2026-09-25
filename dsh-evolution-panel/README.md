# dsh-evolution-panel

harness-self-evolution 的**只读运行时浮窗**（DSH Web client 插件）：会话标题栏「进化面板」按钮 → 面板，展示提案状态机计数、执行时间线（DAG 层粒度、5s 内追加）、指标与缺口的如实状态。

数据链路：单元 A（MoonBit MCP 插件）把运行时写进 DSH tree 的 `.harness-evolution/v2/`（`HARNESS_EVOLUTION_HOME` 显式覆盖时以其为准）；本插件 Host 侧轮询该数据根并经 Typert Gateway 推给浏览器侧。**不经 MCP 通信、不修改任何数据、不触发执行。**

设计契约（数据语义、通道决议、质量门）全文见 [DESIGN.md](./DESIGN.md)。

## 构建

依赖直接来自 npm registry（无需 DSH 源码 checkout）：

```sh
npm install          # devDeps + @deepseek-ai/* 0.1.5-rc.2 peer
npm run typecheck
npm test             # build-last + node --test（数据读层夹具，不触真实数据根）
npm run build        # 清理 lib → tsc + tsdown → lib/（host + client 双入口）
```

## 安装

```sh
dsh plugin --profile web add ./dsh-evolution-panel
# 重启 DSH Host 并刷新页面一次（new-client）
```

MIT。与 [dsh-watcher](../dsh-watcher/README.md) 同宿主共存：watcher 的眼睛看会话工作图，本面板看进化流水线盘上状态。
