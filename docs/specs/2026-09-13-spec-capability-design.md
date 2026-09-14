# /spec 能力设计文档

## 概述

为 DSH 插件增加 `/spec` 能力，作为插件的默认执行程序。当提案被批准后，自动生成执行计划再执行。

## 需求

- **名称**：`/spec` 能力
- **功能**：进化计划生成器 + 任务分解计划
- **形式**：DSH 插件的默认执行程序
- **触发**：提案被批准后自动触发

## 架构设计

### 模块位置

```
src/
├── planner/          # 新增：计划生成模块
│   ├── moon.pkg      # 包定义
│   └── planner.mbt   # 核心逻辑
├── executor/         # 现有：执行模块
├── engine/           # 现有：进化引擎
```

### 依赖关系

```
util → types → store → scanner/monitor → engine → planner → executor → mcp
```

### 数据流

```
提案批准 → Planner 生成计划 → Executor 执行计划
                ↓
        计划存储到 proposals.jsonl
        （plan 字段扩展）
```

## 数据结构

### ExecutionPlan

```moonbit
struct ExecutionPlan {
  plan_id : String
  proposal_id : String
  steps : Array[PlanStep]
  estimated_duration_ms : Int64
  created_at : Int64
}

struct PlanStep {
  step_id : String
  agent_type : AgentType
  description : String
  dependencies : Array[String]
  input : Json
  timeout_ms : Int
}
```

## 计划生成流程

1. **分析提案** — 解析 `proposed_changes`，提取变更类型
2. **评估复杂度** — 基于变更数量、依赖关系、插件规模
3. **生成步骤** — 每个变更类型映射到对应的 Agent 类型和步骤
4. **构建依赖图** — 分析步骤间的依赖关系
5. **输出计划** — 生成 `ExecutionPlan` 结构

## 清理机制

提案状态变为 `completed` 后，自动清除 `plan` 字段：
- 保留提案元数据
- 只清除计划细节
- 避免残留上下文被反复读取

## 架构守卫

- G1：新增 `planner` 包，依赖图严格分层
- G2：日志输出只在 `util/log.mbt`
- G3：持久化只在 `store/`
- G4：数据目录只在 `store/paths.mbt`
