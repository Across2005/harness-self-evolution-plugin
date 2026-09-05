# Harness Self-Evolution Plugin

全盘自进化升级插件 - 基于 DeepSeek Harness 的自主进化系统

## 概述

本插件实现了 DeepSeek Harness 的全盘自进化能力，整合以下核心技术：

1. **Hermes-Evolution 提案机制** - 基于信号的渐进式进化流程
2. **Matt Pocock 工程原则** - 六大原则指导代码优化方向
3. **Sub-Agent 协调执行** - 多 Agent 协作完成升级任务

## 核心能力

### 1. 插件扫描与档案建立
- 自动扫描所有 Harness 插件（官方/社区/自定义）
- 提取元数据：工具列表、能力、依赖关系
- 计算初始指标：复杂度、接口清晰度、文档质量

### 2. 性能监控与信号检测
- 实时监控工具调用、延迟、Token 消耗
- 检测进化信号：循环、纠正、偏好、工作流模式
- 信号强度分级：strong/medium/weak

### 3. 进化提案生成
- 基于信号触发进化提案
- 应用 Matt Pocock 原则确定优化方向
- 生成预期收益和风险评估

### 4. Sub-Agent 协调执行
- code-generator: 生成新工具代码
- test-writer: 编写测试用例
- doc-writer: 更新文档
- validator: 执行验证测试

## Matt Pocock 六大原则

| 原则 | 应用场景 |
|------|----------|
| 先对齐，再动手 | 能力扩展前确保需求对齐 |
| 垂直切片 > 水平切片 | 性能优化时按功能切片 |
| 紧反馈环 > 盲目试错 | 行为优化、错误处理改进 |
| Deep Module > 浅模块 | 接口简化、工具合并 |
| 定期架构扫描 | 周期性健康检查 |
| 词汇即文档 | 文档增强、命名优化 |

## 进化类型

1. **interface_simplification** - 接口简化
   - 合并频繁共用的工具
   - 简化参数，提供合理默认值

2. **behavior_optimization** - 行为优化
   - 添加循环检测中间件
   - 优化重试策略

3. **performance_tuning** - 性能调优
   - 缓存优化
   - 并行化处理

4. **documentation_enhancement** - 文档增强
   - 补充使用示例
   - 记录工作流模式

5. **capability_extension** - 能力扩展
   - 基于用户工作流添加新能力
   - 自动生成可复用模式

6. **error_handling_improvement** - 错误处理改进
   - 记录用户纠正
   - 改进错误消息

## MCP 工具

### scan_plugins
扫描所有 Harness 插件并建立档案。

```json
{
  "force_rescan": false,
  "target_paths": ["可选的自定义路径"]
}
```

### get_plugin_metrics
获取指定插件的性能指标。

```json
{
  "plugin_id": "browser-use-0.4.1",
  "time_range": "last_day"
}
```

### propose_evolution
为插件生成进化提案。

```json
{
  "plugin_id": "browser-use-0.4.1",
  "signals": ["可选的手动信号描述列表"]
}
```

### execute_evolution
执行已审批的进化提案。

```json
{
  "proposal_id": "evo-2026-09-04-browser-use-interface-simplification",
  "dry_run": false
}
```

### list_proposals
列出所有进化提案。

```json
{
  "status": "pending",
  "plugin_id": "可选的插件过滤",
  "limit": 10
}
```

### approve_proposal / reject_proposal
审批或拒绝提案。

```json
{
  "proposal_id": "evo-2026-09-04-..."
}
```

## 工作流程

```
启动 → 扫描插件 → 建立档案
         ↓
    监控性能 → 检测信号
         ↓
    生成提案 → 用户审批
         ↓
    Sub-Agent 执行 → 验证结果
         ↓
    更新档案 → 继续监控
```

## 配置

配置来自 `.zcode-plugin/plugin.json` 的 `evolution_config` 段。
查找顺序：

1. `$HARNESS_EVOLUTION_CONFIG` 指向的文件（显式覆盖，多档案场景用）
2. `<cwd>/.zcode-plugin/plugin.json`
3. 内置默认值

配置缺失绝不会导致启动失败。

```json
{
  "evolution_config": {
    "intensity": "50%",
    "auto_approve": false,
    "cooldown_hours": 24,
    "signal_thresholds": {
      "consecutive_failures": 3,
      "loop_detection": 5,
      "latency_regression": 0.2
    }
  }
}
```

> 旧文档这里写的是 `~/.harness-evolution/config.json` —— **那个文件从来没有
> 任何代码读它**。同样，`max_proposals_per_session` 被赋值后从未参与任何判定，
> 已删除。`latency_regression` 是**小数比例**（0.2 = 延迟回归 20%），
> 旧文档写的 `performance_drop: 30` 量纲就是错的。
>
> `signal_thresholds` 也兼容 1.0 的 `strong`/`medium` 嵌套写法（作为回退），
> 但推荐用上面的扁平形状 —— 它的键名与代码里的 `SignalThresholds` 字段逐字相同。

### 强度级别

- **100%**: 响应所有信号，快速进化
- **50%**: 仅响应强信号，稳健进化（默认）
- **0%**: 禁用自动进化

> ⚠️ 默认的 50% 只放行**强信号**，而 `propose_evolution` 工具的 `signals`
> 参数传入的手动信号是**中信号** —— 因此在默认配置下手动信号不会触发提案。
> 要让手动信号生效，把 `intensity` 设为 `"100%"`。
> （这是从 1.0 继承的行为，详见 `CONTEXT.md` 的 F5。）

## 安装

本插件是一个 **MoonBit native 可执行文件**，运行时不需要 Node.js。
从源码构建：

```powershell
git clone https://github.com/Across2005/harness-self-evolution-plugin.git
cd harness-self-evolution-plugin
.\build.ps1 all     # check → test → build，产物在 bin\harness-evolution.exe
```

唯一的外部依赖（`moonbitlang/async@0.20.1`）由 moon 根据 `moon.mod` 里写死的
精确版本自动拉取，无需单独的 install 步骤。

构建需要 MoonBit 工具链与 MSVC（Visual Studio 的 C++ 生成工具 + Windows SDK）；
`build.ps1` 会自动探测并注入环境，不需要手工跑 `vcvars64.bat`。

在 ZCode 中配置：

```json
{
  "mcpServers": {
    "harness-evolution": {
      "command": "path/to/harness-self-evolution/bin/harness-evolution.exe",
      "args": []
    }
  }
}
```

传输是 **stdio NDJSON**（一行一条 JSON-RPC 2.0 消息）。
所有诊断日志走 **stderr**，stdout 只承载协议字节。

## 触发条件

当以下情况发生时，本 skill 应被触发：

1. 用户请求优化或改进某个插件
2. 检测到性能问题（高延迟、低成功率）
3. 发现用户重复纠正行为
4. 识别到可复用的工作流模式
5. 用户明确请求进化提案

## 安全与审批

- 所有进化提案默认需要用户审批
- 支持试运行模式（dry_run）预览变更
- 保留原版本 30 天，支持一键回滚
- 风险评估包含破坏性变更检测

## 文件结构

```
~/.harness-evolution/
├── config.json           # 配置文件
├── plugin-cache.json     # 插件缓存
├── proposals.jsonl       # 提案记录
├── signals.jsonl         # 信号记录
└── metrics.jsonl         # 性能指标
```

## 许可证

MIT License
