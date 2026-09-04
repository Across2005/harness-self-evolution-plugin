# Harness Self-Evolution Plugin

> DeepSeek Harness 全盘自进化升级插件 - 让插件生态系统持续自我优化

## 概述

Harness Self-Evolution Plugin 是一个为 DeepSeek Harness 框架设计的自进化插件，它能够：

- **启动时扫描**：自动发现并分析所有 harness 插件
- **实时监控**：跟踪插件性能，检测异常模式
- **智能分析**：基于 Matt Pocock 工程原则生成进化提案
- **协同执行**：通过 Sub-Agent 协调完成升级

## 核心理念

**一切皆可进化** - 插件本身也是可进化的实体，通过数据驱动的迭代实现持续优化。

## 架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Harness Evolution Plugin                  │
├──────────────┬──────────────┬──────────────┬───────────────┤
│   Scanner    │   Monitor    │    Engine    │    Executor   │
│  (启动扫描)   │  (实时监控)  │  (进化分析)  │   (升级执行)  │
└──────────────┴──────────────┴──────────────┴───────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   MCP Server    │
                    │  (7 Tools +     │
                    │   2 Events)     │
                    └─────────────────┘
```

### 四大核心组件

#### 1. Scanner - 插件扫描器

启动时扫描所有 harness 插件，建立初始档案：

- 解析 `plugin.json` 和 `SKILL.md`
- 计算复杂度、接口清晰度、文档质量评分
- 建立插件档案到 Registry

#### 2. Monitor - 性能监控器

实时监控插件表现，检测进化信号：

- 跟踪调用延迟、成功率、Token 消耗
- 检测循环行为、性能下降、用户纠正
- 分类信号强度（强/中/弱）

#### 3. Engine - 进化引擎

基于 Matt Pocock 原则生成进化提案：

- 映射信号到进化类型
- 选择适用的工程原则
- 生成具体变更方案

#### 4. Executor - 升级执行器

协调 Sub-Agent 完成实际升级：

- 分解任务到 code-generator、test-writer、doc-writer
- 执行三级验证（T0/T1/T2）
- 支持回滚机制

## 安装

### 前置要求

- Node.js >= 18
- DeepSeek Harness 或 ZCode CLI

### 安装步骤

```bash
# 克隆仓库
# GitHub
git clone https://github.com/Across2005/harness-self-evolution-plugin.git

# 或 GitLink 国内镜像
git clone https://www.gitlink.org.cn/Across2005/harness-self-evolution-plugin.git

# 进入目录
cd harness-self-evolution-plugin

# 安装依赖
npm install

# 构建
npm run build

# 链接到 ZCode（可选）
zcode plugin link .
```

## 配置

### 在 AGENTS.md 中配置

```markdown
## Self-Evolution

- **强度**: 50% (审慎)
  - 100% (积极): 强信号或两个中信号均可触发
  - 50% (审慎): 仅强信号触发
  - 0% (关闭): 不做任何进化检查

- **冷却期**: 24 小时
- **每会话最大提案数**: 3
```

### 在 plugin.json 中配置

```json
{
  "evolution_config": {
    "intensity": "50%",
    "auto_approve": false,
    "max_proposals_per_session": 3,
    "cooldown_hours": 24,
    "signal_thresholds": {
      "strong": {
        "user_correction": true,
        "consecutive_failures": 3,
        "performance_drop": 0.2
      },
      "medium": {
        "pattern_repeat": 2,
        "loop_detection": 5,
        "preference_repeat": 2
      }
    }
  }
}
```

## 使用

### 自动模式

插件会在以下时机自动运行：

1. **启动时**：扫描所有插件，建立档案
2. **运行中**：监控插件性能，累积信号
3. **信号触发**：检测到足够信号时，生成提案

### 手动命令

```bash
# 查看插件状态
/harness-evolution status

# 查看性能指标
/harness-evolution metrics <plugin-id>

# 手动触发分析
/harness-evolution analyze <plugin-id>

# 查看提案列表
/harness-evolution proposals

# 执行提案
/harness-evolution execute <proposal-id>
```

## 进化类型

| 类型 | 触发条件 | Matt Pocock 原则 | 变更内容 |
|------|---------|------------------|---------|
| `interface_simplification` | 循环 + 高复杂度 | Deep Module > 浅模块 | 合并工具、简化参数 |
| `behavior_optimization` | 循环检测 | 紧反馈环 > 盲目试错 | 添加中间件、优化流程 |
| `error_handling_improvement` | 用户纠正 | 先对齐，再动手 | 改进错误处理、增加提示 |
| `documentation_enhancement` | 用户偏好 + 高清晰度 | 词汇即文档 | 更新文档、添加示例 |
| `capability_extension` | 工作流模式 | 垂直切片 > 水平切片 | 扩展能力、添加工具 |
| `performance_tuning` | 性能问题 | 定期架构扫描 | 优化性能、减少延迟 |

## 信号检测

### 强信号（立即触发）

- 用户明确纠正插件行为
- 用户明确表达"以后都这样/不要这样"
- 连续失败 >= 3 次后成功
- 性能指标持续下降（> 20%）

### 中信号（累积触发）

- 同类任务出现清晰模式（>= 2 次）
- 某个参数组合反复出错
- 用户偏好重复出现（>= 2 次）
- 循环行为被检测到（>= 5 次）

### 弱信号（仅记录）

- 轻微性能波动
- 一次性上下文需求
- 用户明确说"这次只是临时的"

## 三级验证

| 级别 | 验证内容 | 失败处理 |
|------|---------|---------|
| T0 | 语法验证 | 回退 + 重新生成 |
| T1 | 功能验证 | 回退 + 重新生成 |
| T2 | 回归验证 | 评估影响 + 决策 |

## Sub-Agent 协同

```
提案审批 → Executor 启动 → Sub-Agent 协同 → 验证测试 → 部署上线
    │              │              │              │           │
    │              │              │              │           └─ 更新 Registry
    │              │              │              └─ 三级验证
    │              │              └─ 代码生成 + 测试 + 文档
    │              └─ 分解任务 + 分配 Agent
    └─ 用户确认
```

### Sub-Agent 类型

- **code-generator**：生成新工具代码
- **test-writer**：编写和执行测试用例
- **doc-writer**：更新 SKILL.md 和文档
- **integration**：处理依赖和集成
- **validator**：运行验证测试

## 数据存储

所有数据以 JSONL 格式存储：

```
~/.harness-evolution/
├── registry.jsonl      # 插件档案
├── metrics.jsonl       # 性能指标
├── signals.jsonl       # 进化信号
├── proposals.jsonl     # 进化提案
└── backups/            # 升级备份
    └── <plugin-id>/
        └── <timestamp>/
```

## API

### MCP Tools

| Tool | 描述 |
|------|------|
| `scan_plugins` | 扫描所有插件 |
| `get_plugin_metrics` | 获取插件性能指标 |
| `propose_evolution` | 生成进化提案 |
| `execute_evolution` | 执行进化升级 |
| `list_proposals` | 列出所有提案 |
| `approve_proposal` | 批准提案 |
| `reject_proposal` | 拒绝提案 |

### MCP Events

| Event | 描述 |
|-------|------|
| `on_plugin_call` | 插件调用事件 |
| `on_user_feedback` | 用户反馈事件 |

## 示例

### 查看插件状态

```
/harness-evolution status
```

输出：
```
插件生态系统状态：
- 总插件数: 15
- 活跃插件: 12
- 待处理提案: 2
- 已完成升级: 5
```

### 执行进化提案

```
/harness-evolution execute evo-2026-09-04-browser-use-simplify-interface
```

输出：
```
执行提案: evo-2026-09-04-browser-use-simplify-interface

步骤 1/7: 代码生成...
✓ 实现工具合并: smart_fill

步骤 2/7: 测试编写...
✓ 编写测试用例: 表单填充, 网页抓取

...

✓ 执行完成！

变更摘要：
- 新增工具: smart_fill
- 延迟: 3.0s → 1.8s (-40%)
- Token: 350 → 245 (-30%)
```

## 开发

### 构建

```bash
npm run build
```

### 测试

```bash
npm test
```

### 代码检查

```bash
npm run lint
```

## 风险缓解

- **只读扫描**：Scanner 不修改任何插件代码
- **审批强制**：所有进化必须用户确认
- **回滚保留**：原版本保留 30 天
- **沙箱测试**：升级在隔离环境验证
- **权限最小**：仅访问必要目录和事件

## 参考资料

以下为本项目设计时的输入材料。它们属于作者本地笔记，未随本仓库一同分发，
因此这里只列出名称而不给链接：

- DeepSeek Harness 六大扩展机制全解析
- Langchain 团队 Harness 工程实践
- DeepSeek Harness AI Agent 开发框架五层系统架构设计全解析
- Hermes-Evolution（渐进式进化提案机制）
- Matt Pocock Engineering Skills（六大工程原则来源）
- defending-code-reference-harness（T0/T1/T2 三级验证来源）

## 许可证

MIT

## 贡献

欢迎提交 Issue 和 Pull Request！
