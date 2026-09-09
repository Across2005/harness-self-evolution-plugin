# DSH Sub-Agent 集成指南

> **⚠️ 给接手 Agent 的提示**
>
> 本文档说明如何将本插件的进化执行器与 DSH (DeepSeek Harness) 的 `subagent` 工具对接。
> 如果你是一个运行在 DSH 中的 Agent，并且需要执行进化提案，请仔细阅读本文档。

## 架构概览

```
┌─────────────────────────────────────────────────────────────┐
│                    DSH 宿主 Agent                            │
│                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │ subagent()   │    │ subagent()   │    │ subagent()   │  │
│  │ code-gen     │    │ test-writer  │    │ doc-writer   │  │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘  │
│         │                   │                   │           │
│         ▼                   ▼                   ▼           │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              ResultCollector                          │  │
│  └──────────────────────────────────────────────────────┘  │
│                           │                                 │
│                           ▼                                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         MCP Server (本插件)                           │  │
│  │  execute_evolution → 返回 task_dag                   │  │
│  │  report_task_result → 接收执行结果                   │  │
│  │  finalize_execution → 更新提案状态                   │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## 执行流程

### 第一步：获取执行计划

调用 `execute_evolution` MCP 工具，获取结构化的任务 DAG：

```json
{
  "proposal_id": "evo-2026-09-09-browser-use-0.4.2-performance-tuning",
  "dry_run": false
}
```

返回值中的 `task_dag` 是按拓扑排序的层级列表：

```json
{
  "success": true,
  "proposal_id": "evo-2026-09-09-browser-use-0.4.2-performance-tuning",
  "task_dag": [
    {
      "layer": 0,
      "tasks": [
        {
          "id": "cg-0",
          "agent": "code-generator",
          "prompt": "## 任务：实现工具合并...",
          "deps": [],
          "timeout_ms": 120000,
          "input": { ... }
        },
        {
          "id": "dw-0",
          "agent": "doc-writer",
          "prompt": "## 任务：更新文档...",
          "deps": [],
          "timeout_ms": 60000,
          "input": { ... }
        }
      ]
    },
    {
      "layer": 1,
      "tasks": [
        {
          "id": "tw-0",
          "agent": "test-writer",
          "prompt": "## 任务：编写测试用例...",
          "deps": ["cg-0"],
          "timeout_ms": 90000,
          "input": { ... }
        }
      ]
    },
    {
      "layer": 2,
      "tasks": [
        {
          "id": "integ-0",
          "agent": "integration",
          "prompt": "## 任务：集成变更...",
          "deps": ["cg-0", "tw-0"],
          "timeout_ms": 90000,
          "input": { ... }
        }
      ]
    }
  ],
  "validation_levels": [
    { "level": "T0", "description": "语法验证", "automated": true },
    { "level": "T1", "description": "功能验证", "automated": true },
    { "level": "T2", "description": "回归验证", "automated": true }
  ],
  "total_tasks": 6,
  "estimated_duration_ms": 180000
}
```

### 第二步：按层级执行任务

**关键规则**：
- 同一层的任务可以**并行**执行（用多个 `subagent` 同时启动）
- 必须等一层的**所有任务完成**后才能进入下一层
- 依赖关系由 `deps` 字段指定，必须满足

```javascript
// ⚠️ 给接手 Agent 的示例代码
// 这是你需要在 DSH 中执行的编排逻辑

async function executeDag(taskDag) {
  const results = {};

  for (const layer of taskDag) {
    console.log(`执行第 ${layer.layer} 层，${layer.tasks.length} 个任务`);

    // 同一层的任务并行执行
    const layerPromises = layer.tasks.map(async (task) => {
      // 使用 DSH 的 subagent 工具
      const result = await subagent({
        prompt: task.prompt,
        description: `${task.agent}: ${task.task}`,
        run_in_background: false  // 等待完成
      });

      return {
        task_id: task.id,
        agent: task.agent,
        success: true,
        output: result,
        duration_ms: 0 // 实际计时
      };
    });

    // 等待该层所有任务完成
    const layerResults = await Promise.all(layerPromises);

    // 收集结果
    for (const result of layerResults) {
      results[result.task_id] = result;
    }
  }

  return results;
}
```

### 第三步：回写执行结果

每个任务执行完后，调用 `report_task_result` 回写结果：

```json
{
  "proposal_id": "evo-2026-09-09-browser-use-0.4.2-performance-tuning",
  "task_id": "cg-0",
  "agent": "code-generator",
  "success": true,
  "output": "已创建 unified_fill 工具，合并了 navigate + click + type",
  "duration_ms": 45000
}
```

### 第四步：完成执行

所有任务和验证完成后，调用 `finalize_execution`：

```json
{
  "proposal_id": "evo-2026-09-09-browser-use-0.4.2-performance-tuning",
  "success": true
}
```

## Agent 角色说明

| Agent | 职责 | prompt 中的关键词 |
|-------|------|-------------------|
| `code-generator` | 生成新代码、合并工具、添加中间件 | 实现、创建、合并、添加 |
| `test-writer` | 编写测试用例 | 测试、验证、断言、覆盖 |
| `doc-writer` | 更新文档 | 文档、说明、示例、README |
| `integration` | 处理依赖和兼容性 | 集成、依赖、兼容、检查 |
| `validator` | 运行三级验证 | 验证、语法、功能、回归 |

## 完整示例：Agent 编排脚本

```javascript
// ⚠️ 给接手 Agent 的完整编排模板
// 复制这段代码到你的工作流中

async function runEvolution(proposalId) {
  // 1. 获取执行计划
  const plan = await callMcpTool('execute_evolution', {
    proposal_id: proposalId,
    dry_run: false
  });

  if (!plan.success) {
    console.error('执行计划获取失败:', plan.error);
    return;
  }

  console.log(`提案 ${proposalId} 分解为 ${plan.total_tasks} 个任务`);

  // 2. 按层级执行
  for (const layer of plan.task_dag) {
    console.log(`\n--- 第 ${layer.layer} 层 (${layer.tasks.length} 个任务) ---`);

    // 并行启动该层所有任务
    const promises = layer.tasks.map(async (task) => {
      console.log(`  启动 ${task.agent}: ${task.task}`);

      const startTime = Date.now();
      try {
        // ⚠️ 这里调用 DSH 的 subagent 工具
        const result = await subagent({
          prompt: task.prompt,
          description: `${task.agent}-${task.id}`,
          run_in_background: false
        });

        const duration = Date.now() - startTime;

        // 回写结果
        await callMcpTool('report_task_result', {
          proposal_id: proposalId,
          task_id: task.id,
          agent: task.agent,
          success: true,
          output: typeof result === 'string' ? result : JSON.stringify(result),
          duration_ms: duration
        });

        console.log(`  ✓ ${task.agent} 完成 (${duration}ms)`);
        return { task_id: task.id, success: true };
      } catch (error) {
        const duration = Date.now() - startTime;

        await callMcpTool('report_task_result', {
          proposal_id: proposalId,
          task_id: task.id,
          agent: task.agent,
          success: false,
          error: String(error),
          duration_ms: duration
        });

        console.error(`  ✗ ${task.agent} 失败: ${error}`);
        return { task_id: task.id, success: false, error: String(error) };
      }
    });

    // 等待该层所有任务完成
    const results = await Promise.all(promises);

    // 检查是否有失败
    const failures = results.filter(r => !r.success);
    if (failures.length > 0) {
      console.error(`第 ${layer.layer} 层有 ${failures.length} 个任务失败`);

      // 回滚并报告
      await callMcpTool('finalize_execution', {
        proposal_id: proposalId,
        success: false,
        error: `Layer ${layer.layer} failed: ${failures.map(f => f.task_id).join(', ')}`
      });
      return;
    }
  }

  // 3. 运行验证
  console.log('\n--- 验证阶段 ---');
  for (const level of plan.validation_levels) {
    console.log(`  运行 ${level.level}: ${level.description}`);
    // 验证逻辑...
  }

  // 4. 完成
  await callMcpTool('finalize_execution', {
    proposal_id: proposalId,
    success: true
  });

  console.log(`\n✓ 提案 ${proposalId} 执行完成`);
}

// 辅助函数：调用 MCP 工具
async function callMcpTool(name, params) {
  // 实现取决于你的 MCP 客户端
  // 这里只是示例
  return await mcpClient.callTool(name, params);
}
```

## 错误处理

### 任务失败

如果某个任务失败：
1. 该层的其他任务可以继续完成
2. 不再执行后续层
3. 调用 `finalize_execution` 报告失败
4. 提案状态回滚到 `pending`

### 超时处理

每个任务都有 `timeout_ms` 限制：
- `code-generator`: 120 秒
- `test-writer`: 90 秒
- `doc-writer`: 60 秒
- `integration`: 90 秒

如果超时：
1. 使用 `interrupt_agent` 取消该 subagent
2. 记录超时错误
3. 继续执行其他任务

### 回滚机制

执行失败时：
1. 提案状态回滚到 `pending`
2. 已修改的文件从备份恢复（如果启用了备份）
3. 执行日志记录失败原因

## DSH 工具映射

| 本插件操作 | DSH 工具 | 说明 |
|-----------|---------|------|
| 启动子任务 | `subagent(prompt, opts)` | 启动一个独立的 subagent |
| 带上下文的子任务 | `subagent_fork(prompt, opts)` | 继承当前对话上下文 |
| 检查任务状态 | `list_agents()` | 列出所有运行中的 agent |
| 取消任务 | `interrupt_agent(agent_id)` | 取消指定的 agent |
| 发送消息 | `send_message(subagent_id, msg)` | 向已有 agent 发送消息 |

## 注意事项

1. **并发限制**：DSH 有并发 subagent 数量限制，通常不超过 5 个
2. **上下文窗口**：每个 subagent 有独立的上下文窗口，不要传递过多历史
3. **结果格式**：subagent 返回的是文本，需要解析 JSON 提取结构化数据
4. **错误传播**：subagent 的异常不会自动传播到宿主，需要显式检查
5. **资源清理**：长时间运行的 subagent 需要及时清理，避免资源泄漏

## 快速开始

如果你是一个 DSH Agent，想要执行一个进化提案：

```javascript
// 最简版本
const plan = await callMcpTool('execute_evolution', { proposal_id: 'evo-xxx' });

for (const layer of plan.task_dag) {
  await Promise.all(layer.tasks.map(task =>
    subagent({ prompt: task.prompt, description: task.agent })
  ));
}

await callMcpTool('finalize_execution', { proposal_id: 'evo-xxx', success: true });
```

就这么简单。详细的错误处理和结果收集请参考上面的完整示例。
