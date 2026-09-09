/**
 * DSH Sub-Agent Runner — 真正对接 DSH subagent 工具的执行器
 *
 * 设计思路：
 *   MCP Server（本插件）运行在独立进程中，无法直接调用 DSH 的 subagent 工具。
 *   因此采用「任务分解 + 宿主编排」模式：
 *     1. MCP Server 的 `execute_evolution` 工具返回结构化的任务 DAG
 *     2. 宿主 Agent（使用 DSH）读取 DAG，用 `subagent` / `subagent_fork` 并行执行
 *     3. 宿主 Agent 收集结果后，调用 `report_task_result` 回写执行记录
 *
 * 这个文件定义了：
 *   - 任务 DAG 的序列化格式
 *   - 宿主 Agent 的编排协议
 *   - 执行结果的回写接口
 *
 * ⚠️ 给接手 Agent 的提示：
 *   你拿到的 `execute_evolution` 返回值里有一个 `task_dag` 字段，
 *   它是按拓扑排序的层级列表，同层可并行、层间串行。
 *   你需要用 DSH 的 `subagent` 工具逐层执行，每层的所有任务并发启动，
 *   等该层全部完成后再进入下一层。详见 DSH_INTEGRATION.md。
 */

import {
  EvolutionProposal,
  SubAgentResult,
  AgentType,
  TaskDefinition
} from '../types';

// ============================================================================
// Task DAG 序列化格式
// ============================================================================

/**
 * 一层 DAG（可并行执行的任务组）
 */
export interface DagLayer {
  /** 层号，从 0 开始 */
  layer: number;
  /** 该层可并行执行的任务 */
  tasks: SerializedTask[];
}

/**
 * 序列化后的任务，供宿主 Agent 消费
 */
export interface SerializedTask {
  /** 任务唯一 ID */
  id: string;
  /** Agent 角色 */
  agent: AgentType;
  /** 任务描述（自然语言，直接作为 subagent 的 prompt） */
  prompt: string;
  /** 依赖的任务 ID 列表（空 = 无依赖，可立即执行） */
  deps: string[];
  /** 超时毫秒数 */
  timeout_ms: number;
  /** 输入数据（JSON 序列化后的提案变更） */
  input: unknown;
}

/**
 * execute_evolution 的增强返回值
 */
export interface EvolutionExecutionPlan {
  /** 是否需要执行（false = dry_run 或已 completed） */
  should_execute: boolean;
  /** 提案 ID */
  proposal_id: string;
  /** 任务 DAG，按拓扑排序的层级 */
  task_dag: DagLayer[];
  /** 验证计划（T0/T1/T2） */
  validation_levels: Array<{
    level: string;
    description: string;
    automated: boolean;
  }>;
  /** 总任务数 */
  total_tasks: number;
  /** 预估执行时间（毫秒） */
  estimated_duration_ms: number;
}

/**
 * 宿主 Agent 执行完一个任务后回写的结果
 */
export interface TaskResultReport {
  /** 任务 ID */
  task_id: string;
  /** Agent 角色 */
  agent: AgentType;
  /** 是否成功 */
  success: boolean;
  /** 输出（subagent 的最终文本） */
  output: string;
  /** 错误信息（失败时） */
  error?: string;
  /** 执行耗时（毫秒） */
  duration_ms: number;
}

// ============================================================================
// DSH Sub-Agent Runner
// ============================================================================

/**
 * DSH Sub-Agent Runner
 *
 * 负责将 EvolutionProposal 分解为可由 DSH subagent 执行的任务 DAG。
 *
 * ⚠️ 给接手 Agent 的提示：
 *   这个类的 `createExecutionPlan` 方法返回的是完整的执行计划。
 *   你需要：
 *   1. 调用 `execute_evolution` MCP 工具获取 `task_dag`
 *   2. 按层级遍历 DAG，对每层的任务用 `subagent` 并行启动
 *   3. 每个 subagent 的 prompt 就是 `task.prompt`
 *   4. 收集所有 subagent 的结果
 *   5. 调用 `report_task_result` 回写结果
 *   6. 全部完成后调用 `finalize_execution` 更新提案状态
 */
export class DshSubAgentRunner {
  /**
   * 将提案分解为可执行的任务 DAG
   */
  createExecutionPlan(proposal: EvolutionProposal): EvolutionExecutionPlan {
    const tasks = this.decomposeTasks(proposal);
    const dag = this.buildDag(tasks);

    return {
      should_execute: true,
      proposal_id: proposal.proposal_id,
      task_dag: dag,
      validation_levels: proposal.validation_plan.validation_levels.map(v => ({
        level: v.level,
        description: v.description,
        automated: v.automated
      })),
      total_tasks: tasks.length + 3, // tasks + 3 validation levels
      estimated_duration_ms: this.estimateDuration(tasks, proposal)
    };
  }

  /**
   * 将任务列表分解为具体的子任务
   */
  private decomposeTasks(proposal: EvolutionProposal): TaskDefinition[] {
    const tasks: TaskDefinition[] = [];
    const changes = proposal.proposed_changes;
    let taskIndex = 0;

    const nextId = (prefix: string) => `${prefix}-${taskIndex++}`;

    // 代码生成任务
    if (changes.merge_tools && changes.merge_tools.length > 0) {
      tasks.push({
        id: nextId('cg'),
        agent: 'code-generator',
        task: '实现工具合并：创建新工具并保留向后兼容性',
        input: changes.merge_tools,
        deps: [],
        timeout_ms: 120000
      });
    }

    if (changes.add_middleware && changes.add_middleware.length > 0) {
      tasks.push({
        id: nextId('cg'),
        agent: 'code-generator',
        task: '实现中间件：添加行为优化逻辑',
        input: changes.add_middleware,
        deps: [],
        timeout_ms: 60000
      });
    }

    if (changes.optimize_flow && changes.optimize_flow.length > 0) {
      tasks.push({
        id: nextId('cg'),
        agent: 'code-generator',
        task: '实现性能优化：优化工具调用流程',
        input: changes.optimize_flow,
        deps: [],
        timeout_ms: 90000
      });
    }

    if (changes.add_capability && changes.add_capability.length > 0) {
      tasks.push({
        id: nextId('cg'),
        agent: 'code-generator',
        task: '实现新能力：扩展插件功能',
        input: changes.add_capability,
        deps: [],
        timeout_ms: 120000
      });
    }

    if (changes.improve_error_handling && changes.improve_error_handling.length > 0) {
      tasks.push({
        id: nextId('cg'),
        agent: 'code-generator',
        task: '改进错误处理：增强用户体验',
        input: changes.improve_error_handling,
        deps: [],
        timeout_ms: 60000
      });
    }

    if (changes.simplify_params && changes.simplify_params.length > 0) {
      tasks.push({
        id: nextId('cg'),
        agent: 'code-generator',
        task: '简化参数：移除未使用参数并设置默认值',
        input: changes.simplify_params,
        deps: [],
        timeout_ms: 60000
      });
    }

    // 收集代码生成任务 ID
    const cgTaskIds = tasks.filter(t => t.agent === 'code-generator').map(t => t.id);

    // 测试编写任务（依赖代码生成）
    if (cgTaskIds.length > 0) {
      tasks.push({
        id: nextId('tw'),
        agent: 'test-writer',
        task: '编写测试用例：验证新功能的正确性和向后兼容性',
        input: proposal.validation_plan.test_scenarios,
        deps: cgTaskIds,
        timeout_ms: 90000
      });
    }

    // 文档任务（独立）
    if (changes.update_documentation && changes.update_documentation.length > 0) {
      tasks.push({
        id: nextId('dw'),
        agent: 'doc-writer',
        task: '更新文档：记录变更和使用说明',
        input: changes.update_documentation,
        deps: [],
        timeout_ms: 60000
      });
    }

    // 集成任务（依赖代码生成 + 测试）
    const integrationDeps = [
      ...cgTaskIds,
      ...tasks.filter(t => t.agent === 'test-writer').map(t => t.id)
    ];

    if (integrationDeps.length > 0) {
      tasks.push({
        id: nextId('integ'),
        agent: 'integration',
        task: '集成变更：处理依赖关系和兼容性检查',
        input: { plugin_id: proposal.plugin_id, changes },
        deps: integrationDeps,
        timeout_ms: 90000
      });
    }

    return tasks;
  }

  /**
   * 构建 DAG（拓扑排序分层）
   *
   * ⚠️ 给接手 Agent 的提示：
   *   返回的 DagLayer[] 是按拓扑排序的层级。
   *   同一层的 tasks 可以用 `subagent` 并行启动。
   *   必须等一层的所有任务完成后才能进入下一层。
   */
  private buildDag(tasks: TaskDefinition[]): DagLayer[] {
    if (tasks.length === 0) return [];

    // 构建依赖图
    const taskMap = new Map<string, TaskDefinition>();
    const inDegree = new Map<string, number>();
    const dependents = new Map<string, string[]>(); // task_id → 依赖它的任务

    for (const task of tasks) {
      taskMap.set(task.id, task);
      inDegree.set(task.id, 0);
      dependents.set(task.id, []);
    }

    for (const task of tasks) {
      for (const dep of task.deps) {
        if (!taskMap.has(dep)) {
          throw new Error(`Task ${task.id} depends on unknown task ${dep}`);
        }
        inDegree.set(task.id, (inDegree.get(task.id) || 0) + 1);
        dependents.get(dep)!.push(task.id);
      }
    }

    // Kahn 拓扑排序
    const layers: DagLayer[] = [];
    let currentLayer: string[] = [];

    // 第一层：无依赖的任务
    for (const [id, degree] of inDegree) {
      if (degree === 0) currentLayer.push(id);
    }

    let layerIndex = 0;
    while (currentLayer.length > 0) {
      const serializedTasks: SerializedTask[] = currentLayer.map(id => {
        const task = taskMap.get(id)!;
        return {
          id: task.id,
          agent: task.agent,
          prompt: this.buildPrompt(task),
          deps: task.deps,
          timeout_ms: task.timeout_ms,
          input: task.input
        };
      });

      layers.push({ layer: layerIndex++, tasks: serializedTasks });

      const nextLayer: string[] = [];
      for (const id of currentLayer) {
        for (const dependent of dependents.get(id) || []) {
          const newDegree = (inDegree.get(dependent) || 1) - 1;
          inDegree.set(dependent, newDegree);
          if (newDegree === 0) nextLayer.push(dependent);
        }
      }
      currentLayer = nextLayer;
    }

    return layers;
  }

  /**
   * 为任务构建 prompt（供 subagent 使用）
   *
   * ⚠️ 给接手 Agent 的提示：
   *   这个 prompt 是给 DSH `subagent` 工具的 prompt 参数。
   *   它包含了任务描述、输入数据和预期输出格式。
   *   subagent 的返回文本就是任务的 output。
   */
  private buildPrompt(task: TaskDefinition): string {
    const inputJson = JSON.stringify(task.input, null, 2);

    return `## 任务：${task.task}

### 角色
你是一个 ${task.agent} 类型的 Sub-Agent，负责执行进化提案中的一项具体任务。

### 输入数据
\`\`\`json
${inputJson}
\`\`\`

### 要求
1. 仔细分析输入数据
2. 执行任务并生成具体结果
3. 输出必须是结构化的 JSON，包含：
   - \`success\`: boolean
   - \`changes\`: 具体的变更内容
   - \`summary\`: 执行摘要（一句话）

### 注意事项
- 保持向后兼容性
- 遵循现有代码风格
- 生成可直接使用的输出
`;
  }

  /**
   * 预估执行时间
   */
  private estimateDuration(tasks: TaskDefinition[], proposal: EvolutionProposal): number {
    const taskTime = tasks.reduce((sum, t) => sum + t.timeout_ms, 0);
    const validationTime = proposal.validation_plan.validation_levels.reduce(
      (sum, v) => sum + (v.timeout_ms || 60000), 0
    );
    // 并行执行时，取每层最大值的和
    return Math.ceil((taskTime + validationTime) * 0.6); // 60% 效率因子
  }
}

// ============================================================================
// 结果收集器
// ============================================================================

/**
 * Sub-Agent 执行结果收集器
 *
 * ⚠️ 给接手 Agent 的提示：
 *   宿主 Agent 每执行完一个 subagent，就调用 `collect` 收集结果。
 *   全部完成后调用 `getSummary` 获取执行摘要。
 */
export class ResultCollector {
  private results: SubAgentResult[] = [];

  /**
   * 收集一个任务的执行结果
   */
  collect(report: TaskResultReport): void {
    this.results.push({
      task_id: report.task_id,
      agent: report.agent,
      success: report.success,
      output: report.output,
      error: report.error,
      duration_ms: report.duration_ms
    });
  }

  /**
   * 获取所有结果
   */
  getResults(): SubAgentResult[] {
    return [...this.results];
  }

  /**
   * 获取执行摘要
   */
  getSummary(): {
    total: number;
    succeeded: number;
    failed: number;
    total_duration_ms: number;
    all_succeeded: boolean;
  } {
    const succeeded = this.results.filter(r => r.success).length;
    const totalDuration = this.results.reduce((sum, r) => sum + r.duration_ms, 0);

    return {
      total: this.results.length,
      succeeded,
      failed: this.results.length - succeeded,
      total_duration_ms: totalDuration,
      all_succeeded: succeeded === this.results.length
    };
  }

  /**
   * 重置收集器
   */
  reset(): void {
    this.results = [];
  }
}
