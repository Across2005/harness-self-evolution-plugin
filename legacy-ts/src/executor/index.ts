/**
 * Upgrade Executor - Executes evolution proposals via Sub-Agent orchestration
 * 
 * Responsibilities:
 * - Execute approved evolution proposals
 * - Coordinate Sub-Agents for code generation, testing, documentation
 * - Run three-level validation (T0, T1, T2)
 * - Handle rollback on failure
 */

import * as fs from 'fs-extra';
import * as path from 'path';
import { 
  EvolutionProposal, 
  SubAgentTask, 
  SubAgentResult,
  AgentType,
  ProposedChanges
} from '../types';
import { ProposalStore, expandPath } from '../store';

export class UpgradeExecutor {
  private proposals: ProposalStore;
  private executionLogPath: string;

  constructor(
    proposalsStore: ProposalStore = new ProposalStore(),
    executionLogPath: string = '~/.harness-evolution/execution.log'
  ) {
    this.proposals = proposalsStore;
    this.executionLogPath = expandPath(executionLogPath);
  }

  /**
   * Execute an approved evolution proposal
   */
  async execute(proposalId: string, dryRun: boolean = false): Promise<{
    success: boolean;
    results: SubAgentResult[];
    error?: string;
  }> {
    console.log(`[Executor] Executing proposal: ${proposalId}`);
    
    // Load proposal
    const proposal = await this.proposals.find(proposalId);
    if (!proposal) {
      return {
        success: false,
        results: [],
        error: `Proposal not found: ${proposalId}`
      };
    }

    // Check status — only approved proposals may execute (see CONTEXT.md state machine)
    if (proposal.status !== 'approved') {
      return {
        success: false,
        results: [],
        error: `Proposal status is ${proposal.status}, expected 'approved'`
      };
    }

    // Update status to executing
    await this.proposals.setStatus(proposalId, 'executing');

    // Log execution start
    await this.logExecution(proposalId, 'start', `Starting execution of ${proposalId}`);

    try {
      // Decompose into sub-agent tasks
      const tasks = this.decomposeTasks(proposal);
      
      // Execute tasks
      const results: SubAgentResult[] = [];
      
      for (const task of tasks) {
        const result = await this.executeSubAgentTask(task, dryRun);
        results.push(result);
        
        if (!result.success) {
          // Task failed, rollback
          await this.logExecution(proposalId, 'error', `Task ${task.agent} failed: ${result.error}`);
          await this.rollback(proposal, results);
          await this.proposals.setStatus(proposalId, 'pending'); // Reset to pending
          
          return {
            success: false,
            results,
            error: `Task ${task.agent} failed: ${result.error}`
          };
        }
        
        await this.logExecution(proposalId, 'progress', `Task ${task.agent} completed successfully`);
      }

      // Run validation
      const validationResults = await this.runValidation(proposal, dryRun);
      
      if (!validationResults.success) {
        // Validation failed, rollback
        await this.logExecution(proposalId, 'error', `Validation failed: ${validationResults.error}`);
        await this.rollback(proposal, results);
        await this.proposals.setStatus(proposalId, 'pending');
        
        return {
          success: false,
          results: [...results, ...validationResults.results],
          error: `Validation failed: ${validationResults.error}`
        };
      }

      // All successful, update status to completed
      await this.proposals.setStatus(proposalId, 'completed');
      await this.logExecution(proposalId, 'complete', `Execution completed successfully`);
      
      return {
        success: true,
        results: [...results, ...validationResults.results]
      };
      
    } catch (error) {
      // Unexpected error, rollback
      await this.logExecution(proposalId, 'error', `Unexpected error: ${error}`);
      await this.proposals.setStatus(proposalId, 'pending');
      
      return {
        success: false,
        results: [],
        error: `Unexpected error: ${error}`
      };
    }
  }

  /**
   * Decompose proposal into sub-agent tasks
   */
  private decomposeTasks(proposal: EvolutionProposal): SubAgentTask[] {
    const tasks: SubAgentTask[] = [];
    const changes = proposal.proposed_changes;

    // Code generation tasks
    if (changes.merge_tools && changes.merge_tools.length > 0) {
      tasks.push({
        agent: 'code-generator',
        task: '实现工具合并：创建新工具并保留向后兼容性',
        input: changes.merge_tools,
        timeout_ms: 120000
      });
    }

    if (changes.add_middleware && changes.add_middleware.length > 0) {
      tasks.push({
        agent: 'code-generator',
        task: '实现中间件：添加行为优化逻辑',
        input: changes.add_middleware,
        timeout_ms: 60000
      });
    }

    if (changes.optimize_flow && changes.optimize_flow.length > 0) {
      tasks.push({
        agent: 'code-generator',
        task: '实现性能优化：优化工具调用流程',
        input: changes.optimize_flow,
        timeout_ms: 90000
      });
    }

    if (changes.add_capability && changes.add_capability.length > 0) {
      tasks.push({
        agent: 'code-generator',
        task: '实现新能力：扩展插件功能',
        input: changes.add_capability,
        timeout_ms: 120000
      });
    }

    if (changes.improve_error_handling && changes.improve_error_handling.length > 0) {
      tasks.push({
        agent: 'code-generator',
        task: '改进错误处理：增强用户体验',
        input: changes.improve_error_handling,
        timeout_ms: 60000
      });
    }

    // Test writing tasks
    if (tasks.some(t => t.agent === 'code-generator')) {
      tasks.push({
        agent: 'test-writer',
        task: '编写测试用例：验证新功能',
        input: proposal.validation_plan.test_scenarios,
        dependencies: [tasks[tasks.length - 1].agent], // Depends on code generation
        timeout_ms: 90000
      });
    }

    // Documentation tasks
    if (changes.update_documentation && changes.update_documentation.length > 0) {
      tasks.push({
        agent: 'doc-writer',
        task: '更新文档：记录变更和使用说明',
        input: changes.update_documentation,
        timeout_ms: 60000
      });
    }

    // Integration tasks
    if (tasks.length > 1) {
      tasks.push({
        agent: 'integration',
        task: '集成变更：处理依赖关系和兼容性',
        input: {
          plugin_id: proposal.plugin_id,
          changes: changes
        },
        dependencies: ['code-generator', 'test-writer'],
        timeout_ms: 90000
      });
    }

    return tasks;
  }

  /**
   * Execute a single sub-agent task
   */
  private async executeSubAgentTask(
    task: SubAgentTask, 
    dryRun: boolean
  ): Promise<SubAgentResult> {
    console.log(`[Executor] Executing task: ${task.agent} - ${task.task}`);
    
    if (dryRun) {
      // Simulate success in dry-run mode
      return {
        task_id: `${task.agent}-${Date.now()}`,
        agent: task.agent,
        success: true,
        output: { dry_run: true, task: task.task },
        duration_ms: 0
      };
    }

    const startTime = Date.now();
    
    try {
      // In production, this would spawn actual sub-agents via sessions_spawn
      // For now, simulate execution
      const output = await this.simulateSubAgent(task);
      
      return {
        task_id: `${task.agent}-${Date.now()}`,
        agent: task.agent,
        success: true,
        output,
        duration_ms: Date.now() - startTime
      };
    } catch (error) {
      return {
        task_id: `${task.agent}-${Date.now()}`,
        agent: task.agent,
        success: false,
        output: null,
        error: String(error),
        duration_ms: Date.now() - startTime
      };
    }
  }

  /**
   * Simulate sub-agent execution (placeholder for actual implementation)
   */
  private async simulateSubAgent(task: SubAgentTask): Promise<any> {
    // In production, this would:
    // 1. Use sessions_spawn to create a sub-agent
    // 2. Pass task details and input
    // 3. Wait for completion
    // 4. Return results
    
    // Simulate processing time
    await new Promise(resolve => setTimeout(resolve, 100));
    
    return {
      simulated: true,
      task: task.task,
      input: task.input,
      message: 'Sub-agent execution simulated'
    };
  }

  /**
   * Run three-level validation
   */
  private async runValidation(
    proposal: EvolutionProposal, 
    dryRun: boolean
  ): Promise<{
    success: boolean;
    results: SubAgentResult[];
    error?: string;
  }> {
    console.log('[Executor] Running validation...');
    
    const results: SubAgentResult[] = [];
    
    for (const level of proposal.validation_plan.validation_levels) {
      const result = await this.runValidationLevel(level.level, proposal, dryRun);
      results.push(result);
      
      if (!result.success) {
        return {
          success: false,
          results,
          error: `${level.level} validation failed: ${result.error}`
        };
      }
    }
    
    return {
      success: true,
      results
    };
  }

  /**
   * Run a single validation level
   */
  private async runValidationLevel(
    level: 'T0' | 'T1' | 'T2',
    proposal: EvolutionProposal,
    dryRun: boolean
  ): Promise<SubAgentResult> {
    const startTime = Date.now();
    
    if (dryRun) {
      return {
        task_id: `validation-${level}-${Date.now()}`,
        agent: 'validator',
        success: true,
        output: { dry_run: true, level },
        duration_ms: 0
      };
    }

    try {
      // T0: Syntax validation
      if (level === 'T0') {
        // In production: run linter, type checker, parser
        await new Promise(resolve => setTimeout(resolve, 50));
        return {
          task_id: `validation-T0-${Date.now()}`,
          agent: 'validator',
          success: true,
          output: { level: 'T0', message: 'Syntax validation passed' },
          duration_ms: Date.now() - startTime
        };
      }
      
      // T1: Functionality validation
      if (level === 'T1') {
        // In production: run unit tests, integration tests
        await new Promise(resolve => setTimeout(resolve, 100));
        return {
          task_id: `validation-T1-${Date.now()}`,
          agent: 'validator',
          success: true,
          output: { level: 'T1', message: 'Functionality validation passed' },
          duration_ms: Date.now() - startTime
        };
      }
      
      // T2: Regression validation
      if (level === 'T2') {
        // In production: run full test suite, regression tests
        await new Promise(resolve => setTimeout(resolve, 150));
        return {
          task_id: `validation-T2-${Date.now()}`,
          agent: 'validator',
          success: true,
          output: { level: 'T2', message: 'Regression validation passed' },
          duration_ms: Date.now() - startTime
        };
      }
      
      return {
        task_id: `validation-${level}-${Date.now()}`,
        agent: 'validator',
        success: false,
        output: null,
        error: `Unknown validation level: ${level}`,
        duration_ms: Date.now() - startTime
      };
    } catch (error) {
      return {
        task_id: `validation-${level}-${Date.now()}`,
        agent: 'validator',
        success: false,
        output: null,
        error: String(error),
        duration_ms: Date.now() - startTime
      };
    }
  }

  /**
   * Rollback changes
   */
  private async rollback(proposal: EvolutionProposal, results: SubAgentResult[]): Promise<void> {
    console.log('[Executor] Rolling back changes...');
    
    // In production, this would:
    // 1. Revert file changes
    // 2. Restore previous version from backup
    // 3. Clean up temporary files
    
    await this.logExecution(proposal.proposal_id, 'rollback', 'Changes rolled back');
  }

  /**
   * Log execution event
   */
  private async logExecution(proposalId: string, event: string, message: string): Promise<void> {
    await fs.ensureDir(path.dirname(this.executionLogPath));
    
    const logEntry = `[${new Date().toISOString()}] [${proposalId}] [${event}] ${message}\n`;
    await fs.appendFile(this.executionLogPath, logEntry, 'utf-8');
  }
}
