/**
 * MCP Server - Model Context Protocol server for Harness Self-Evolution
 *
 * Exposes tools for:
 * - scan_plugins: Scan all harness plugins
 * - get_plugin_metrics: Get performance metrics for a plugin
 * - propose_evolution: Generate evolution proposal
 * - execute_evolution: Execute approved proposal
 * - list_proposals: List all proposals
 * - approve_proposal / reject_proposal: Set proposal status
 * - analyze_plugins: Merged scan + metrics tool
 * - evolve_plugin: Merged propose + execute tool
 * - manage_config: Configuration management
 *
 * 所有工具共享一个 ProposalStore 实例（单一事实来源），
 * 错误处理统一由 defineTool 包装器负责。
 */

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import { PluginScanner } from '../scanner';
import { PerformanceMonitor } from '../monitor';
import { EvolutionEngine } from '../engine';
import { UpgradeExecutor } from '../executor';
import { ProposalStore, ConfigStore } from '../store';
import type { PluginMetadata, EvolutionSignal } from '../types';

// Zod raw shapes for tool parameters
const ScanPluginsShape = {
  force_rescan: z.boolean().default(false).describe('强制重新扫描，即使已有缓存'),
  target_paths: z.array(z.string()).optional().describe('自定义扫描路径（可选）')
};

const GetMetricsShape = {
  plugin_id: z.string().describe('插件 ID（如 browser-use-0.4.1）'),
  time_range: z.enum(['last_hour', 'last_day', 'last_week', 'all']).default('all').describe('时间范围')
};

const ProposeEvolutionShape = {
  plugin_id: z.string().describe('插件 ID'),
  signals: z.array(z.string()).optional().describe('手动提供的信号描述列表（可选）')
};

const ExecuteEvolutionShape = {
  proposal_id: z.string().describe('提案 ID'),
  dry_run: z.boolean().default(false).describe('试运行模式（不实际修改文件）')
};

const ListProposalsShape = {
  status: z.enum(['pending', 'approved', 'rejected', 'executing', 'completed']).optional().describe('按状态过滤'),
  plugin_id: z.string().optional().describe('按插件 ID 过滤'),
  limit: z.number().default(10).describe('返回数量限制')
};

const ProposalIdShape = {
  proposal_id: z.string().describe('提案 ID')
};

// Merged tool shapes (v2.0)
const AnalyzePluginsShape = {
  mode: z.enum(['scan', 'metrics', 'both']).default('both').describe('分析模式：scan=仅扫描，metrics=仅指标，both=两者'),
  plugin_id: z.string().optional().describe('指定插件 ID（metrics 模式必填）'),
  time_range: z.enum(['last_hour', 'last_day', 'last_week', 'all']).default('all').describe('时间范围'),
  target_paths: z.array(z.string()).optional().describe('自定义扫描路径（可选）')
};

const EvolvePluginShape = {
  action: z.enum(['propose', 'execute']).describe('操作类型：propose=生成提案，execute=执行提案'),
  plugin_id: z.string().optional().describe('插件 ID（propose 必填）'),
  proposal_id: z.string().optional().describe('提案 ID（execute 必填）'),
  signals: z.array(z.string()).optional().describe('手动信号描述列表'),
  dry_run: z.boolean().default(false).describe('试运行模式')
};

const ManageConfigShape = {
  action: z.enum(['get', 'set', 'reset']).describe('操作类型：get=读取，set=设置，reset=重置'),
  key: z.string().optional().describe('配置键名（set/get 时可选）'),
  value: z.string().optional().describe('配置值（JSON 字符串，set 时必填）')
};

/** Tool result helpers */
type ToolResult = {
  content: Array<{ type: 'text'; text: string }>;
  isError?: boolean;
};

function jsonOk(value: unknown): ToolResult {
  return { content: [{ type: 'text' as const, text: JSON.stringify(value, null, 2) }] };
}

function jsonError(message: string): ToolResult {
  return {
    content: [{ type: 'text' as const, text: JSON.stringify({ success: false, error: message }, null, 2) }],
    isError: true
  };
}

export class HarnessEvolutionServer {
  private server: McpServer;
  private scanner: PluginScanner;
  private monitor: PerformanceMonitor;
  private engine: EvolutionEngine;
  private executor: UpgradeExecutor;
  private proposals: ProposalStore;
  private configStore: ConfigStore;
  private pluginRegistry: Map<string, PluginMetadata> = new Map();

  constructor() {
    this.server = new McpServer({
      name: 'harness-self-evolution',
      version: '2.0.0'
    });

    // Single source of truth shared by engine, executor and the tools below
    this.proposals = new ProposalStore();
    this.configStore = new ConfigStore();
    this.scanner = new PluginScanner();
    this.monitor = new PerformanceMonitor();
    this.engine = new EvolutionEngine(this.monitor, this.proposals);
    this.executor = new UpgradeExecutor(this.proposals);

    this.setupTools();
    this.setupShutdown();
  }

  /**
   * Register a tool with centralized error handling.
   */
  private defineTool(
    name: string,
    description: string,
    shape: Record<string, z.ZodTypeAny>,
    handler: (params: Record<string, unknown>) => Promise<ToolResult>
  ): void {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    this.server.registerTool(
      name,
      { description, inputSchema: shape as any },
      async (params: any) => {
        try {
          return await handler(params as Record<string, unknown>);
        } catch (error) {
          const message = error instanceof Error ? error.message : String(error);
          console.error(`[Server] Tool ${name} failed:`, message);
          return jsonError(message);
        }
      }
    );
  }

  private setupTools(): void {
    // Tool: scan_plugins
    this.defineTool(
      'scan_plugins',
      '扫描所有 harness 插件并建立档案。返回发现的插件列表及其元数据。',
      ScanPluginsShape,
      async (params) => {
        const plugins = await this.scanner.scanAll(params.force_rescan as boolean);
        this.pluginRegistry = plugins;

        return jsonOk({
          success: true,
          plugin_count: plugins.size,
          plugins: Array.from(plugins.values(), (p: PluginMetadata) => ({
            plugin_id: p.plugin_id,
            name: p.name,
            version: p.version,
            type: p.type,
            capabilities: p.capabilities,
            tools_count: p.tools.length
          }))
        });
      }
    );

    // Tool: get_plugin_metrics
    this.defineTool(
      'get_plugin_metrics',
      '获取指定插件的性能指标，包括调用次数、成功率、延迟、Token 消耗等。',
      GetMetricsShape,
      async (params) => {
        const stats = await this.monitor.getStatistics(
          params.plugin_id as string, 
          params.time_range as 'last_hour' | 'last_day' | 'last_week' | 'all'
        );
        return jsonOk({
          success: true,
          plugin_id: params.plugin_id,
          time_range: params.time_range,
          statistics: stats
        });
      }
    );

    // Tool: propose_evolution
    this.defineTool(
      'propose_evolution',
      '为指定插件生成进化提案。基于性能数据和信号，应用 Matt Pocock 工程原则生成优化建议。',
      ProposeEvolutionShape,
      async (params) => {
        const plugin = this.pluginRegistry.get(params.plugin_id as string);
        if (!plugin) {
          return jsonError(`Plugin not found: ${params.plugin_id}. Run scan_plugins first.`);
        }

        // Manually supplied signal descriptions become strong signals (F5 fix)
        const manualSignals: EvolutionSignal[] | undefined = (params.signals as string[] | undefined)?.map(
          (description: string) => ({
            type: 'strong' as const,
            category: 'pattern' as const,
            description,
            evidence: 'user:manual',
            timestamp: new Date().toISOString(),
            plugin_id: params.plugin_id as string
          })
        );

        const proposal = await this.engine.generateProposal(
          params.plugin_id as string,
          plugin,
          manualSignals
        );

        if (!proposal) {
          return jsonOk({
            success: true,
            message: 'No evolution proposal generated (insufficient signals, cooldown, or duplicate)'
          });
        }

        return jsonOk({
          success: true,
          proposal: {
            proposal_id: proposal.proposal_id,
            evolution_type: proposal.evolution_type,
            matt_pocock_principle: proposal.matt_pocock_principle,
            confidence: proposal.confidence,
            expected_benefits: proposal.expected_benefits,
            status: proposal.status
          }
        });
      }
    );

    // Tool: execute_evolution
    this.defineTool(
      'execute_evolution',
      '执行已审批的进化提案。协调 Sub-Agent 完成代码生成、测试、文档更新和验证。',
      ExecuteEvolutionShape,
      async (params) => {
        const result = await this.executor.execute(
          params.proposal_id as string, 
          params.dry_run as boolean
        );
        return jsonOk({
          success: result.success,
          proposal_id: params.proposal_id,
          results: result.results.map(r => ({
            agent: r.agent,
            success: r.success,
            duration_ms: r.duration_ms,
            error: r.error
          })),
          error: result.error
        });
      }
    );

    // Tool: list_proposals
    this.defineTool(
      'list_proposals',
      '列出所有进化提案，可按状态和插件过滤。',
      ListProposalsShape,
      async (params) => {
        const proposals = await this.proposals.list({
          status: params.status as 'pending' | 'approved' | 'rejected' | 'executing' | 'completed' | undefined,
          plugin_id: params.plugin_id as string | undefined,
          limit: params.limit as number
        });

        return jsonOk({
          success: true,
          count: proposals.length,
          proposals: proposals.map(p => ({
            proposal_id: p.proposal_id,
            plugin_id: p.plugin_id,
            evolution_type: p.evolution_type,
            status: p.status,
            created_at: p.created_at,
            confidence: p.confidence
          }))
        });
      }
    );

    // Tool: approve_proposal
    this.defineTool(
      'approve_proposal',
      '批准一个进化提案，使其可以被执行。',
      ProposalIdShape,
      async (params) => {
        const updated = await this.proposals.setStatus(
          params.proposal_id as string, 
          'approved'
        );
        if (!updated) {
          return jsonError(`Proposal not found: ${params.proposal_id}`);
        }
        return jsonOk({ success: true, message: `Proposal ${params.proposal_id} approved` });
      }
    );

    // Tool: reject_proposal
    this.defineTool(
      'reject_proposal',
      '拒绝一个进化提案。',
      ProposalIdShape,
      async (params) => {
        const updated = await this.proposals.setStatus(
          params.proposal_id as string, 
          'rejected'
        );
        if (!updated) {
          return jsonError(`Proposal not found: ${params.proposal_id}`);
        }
        return jsonOk({ success: true, message: `Proposal ${params.proposal_id} rejected` });
      }
    );

    // Tool: analyze_plugins (merged scan + metrics)
    this.defineTool(
      'analyze_plugins',
      '合并工具：扫描插件并/或获取性能指标。mode=scan 仅扫描，metrics 仅获取指标，both 两者都做。',
      AnalyzePluginsShape,
      async (params) => {
        const mode = params.mode as string;
        const result: Record<string, unknown> = { success: true };

        // Scan if needed
        if (mode === 'scan' || mode === 'both') {
          const plugins = await this.scanner.scanAll(false);
          this.pluginRegistry = plugins;
          result.scan = {
            plugin_count: plugins.size,
            plugins: Array.from(plugins.values(), (p: PluginMetadata) => ({
              plugin_id: p.plugin_id,
              name: p.name,
              version: p.version,
              tools_count: p.tools.length
            }))
          };
        }

        // Get metrics if needed
        if (mode === 'metrics' || mode === 'both') {
          const pluginId = params.plugin_id as string | undefined;
          if (!pluginId) {
            return jsonError('plugin_id is required for metrics mode');
          }
          const stats = await this.monitor.getStatistics(
            pluginId,
            params.time_range as 'last_hour' | 'last_day' | 'last_week' | 'all'
          );
          result.metrics = {
            plugin_id: pluginId,
            statistics: stats
          };
        }

        return jsonOk(result);
      }
    );

    // Tool: evolve_plugin (merged propose + execute)
    this.defineTool(
      'evolve_plugin',
      '合并工具：生成或执行进化提案。action=propose 生成提案，execute 执行提案。',
      EvolvePluginShape,
      async (params) => {
        const action = params.action as string;

        if (action === 'propose') {
          const pluginId = params.plugin_id as string | undefined;
          if (!pluginId) {
            return jsonError('plugin_id is required for propose action');
          }

          const plugin = this.pluginRegistry.get(pluginId);
          if (!plugin) {
            return jsonError(`Plugin not found: ${pluginId}. Run scan_plugins first.`);
          }

          const manualSignals = (params.signals as string[] | undefined)?.map(
            (desc: string) => ({
              type: 'strong' as const,
              category: 'pattern' as const,
              description: desc,
              evidence: 'user:manual',
              timestamp: new Date().toISOString(),
              plugin_id: pluginId
            })
          );

          const proposal = await this.engine.generateProposal(pluginId, plugin, manualSignals);

          if (!proposal) {
            return jsonOk({
              success: true,
              action: 'propose',
              message: 'No proposal generated (insufficient signals, cooldown, or duplicate)'
            });
          }

          return jsonOk({
            success: true,
            action: 'propose',
            proposal: {
              proposal_id: proposal.proposal_id,
              evolution_type: proposal.evolution_type,
              confidence: proposal.confidence,
              status: proposal.status
            }
          });
        }

        if (action === 'execute') {
          const proposalId = params.proposal_id as string | undefined;
          if (!proposalId) {
            return jsonError('proposal_id is required for execute action');
          }

          const result = await this.executor.execute(
            proposalId,
            params.dry_run as boolean
          );

          return jsonOk({
            success: result.success,
            action: 'execute',
            proposal_id: proposalId,
            results: result.results.map(r => ({
              agent: r.agent,
              success: r.success,
              duration_ms: r.duration_ms
            })),
            error: result.error
          });
        }

        return jsonError(`Unknown action: ${action}`);
      }
    );

    // Tool: manage_config
    this.defineTool(
      'manage_config',
      '管理进化配置。action=get 读取配置，set 设置配置项，reset 重置为默认值。',
      ManageConfigShape,
      async (params) => {
        const action = params.action as string;

        if (action === 'get') {
          const { config, warnings } = await this.configStore.load();
          return jsonOk({
            success: true,
            action: 'get',
            config,
            warnings
          });
        }

        if (action === 'set') {
          const key = params.key as string | undefined;
          const value = params.value as string | undefined;

          if (!key || !value) {
            return jsonError('key and value are required for set action');
          }

          const { config, warnings } = await this.configStore.load();
          const parsedValue = JSON.parse(value);

          // Update the config field
          const configRecord = config as unknown as Record<string, unknown>;
          if (key in configRecord) {
            configRecord[key] = parsedValue;
          } else {
            return jsonError(`Unknown config key: ${key}`);
          }

          await this.configStore.save(config);

          return jsonOk({
            success: true,
            action: 'set',
            key,
            value: parsedValue,
            warnings
          });
        }

        if (action === 'reset') {
          await this.configStore.reset();
          return jsonOk({
            success: true,
            action: 'reset',
            message: 'Configuration reset to defaults'
          });
        }

        return jsonError(`Unknown action: ${action}`);
      }
    );

    // Tool: get_execution_plan (DSH 集成)
    // ⚠️ 给接手 Agent 的提示：
    //   这个工具返回任务 DAG，你需要用 DSH 的 subagent 工具按层级执行。
    //   详见 DSH_INTEGRATION.md。
    this.defineTool(
      'get_execution_plan',
      '获取进化提案的执行计划（任务 DAG）。返回按拓扑排序的层级，同层可并行、层间串行。供 DSH Agent 编排 subagent 使用。',
      ProposalIdShape,
      async (params) => {
        const proposal = await this.proposals.find(params.proposal_id as string);
        if (!proposal) {
          return jsonError(`Proposal not found: ${params.proposal_id}`);
        }
        if (proposal.status !== 'approved') {
          return jsonError(`Proposal status is ${proposal.status}, expected 'approved'`);
        }

        const { DshSubAgentRunner } = await import('../executor/dsh-runner');
        const runner = new DshSubAgentRunner();
        const plan = runner.createExecutionPlan(proposal);

        return jsonOk({
          success: true,
          ...plan,
          // 提示：用 DSH 的 subagent 工具按层级执行
          _hint: '按 task_dag 的层级顺序执行：同层 tasks 用 subagent 并行启动，等该层全部完成后再进入下一层。详见 DSH_INTEGRATION.md。'
        });
      }
    );

    // Tool: report_task_result (DSH 集成)
    // ⚠️ 给接手 Agent 的提示：
    //   每执行完一个 subagent，调用这个工具回写结果。
    const ReportTaskResultShape = {
      proposal_id: z.string().describe('提案 ID'),
      task_id: z.string().describe('任务 ID'),
      agent: z.enum(['code-generator', 'test-writer', 'doc-writer', 'integration', 'validator']).describe('Agent 角色'),
      success: z.boolean().describe('是否成功'),
      output: z.string().describe('执行输出（subagent 的最终文本）'),
      error: z.string().optional().describe('错误信息（失败时）'),
      duration_ms: z.number().describe('执行耗时（毫秒）')
    };

    this.defineTool(
      'report_task_result',
      '回写 Sub-Agent 任务执行结果。宿主 Agent 每执行完一个 subagent 后调用此工具。',
      ReportTaskResultShape,
      async (params) => {
        const proposal = await this.proposals.find(params.proposal_id as string);
        if (!proposal) {
          return jsonError(`Proposal not found: ${params.proposal_id}`);
        }

        // 记录到执行日志
        const logEntry = {
          task_id: params.task_id as string,
          agent: params.agent as string,
          success: params.success as boolean,
          output: params.output as string,
          error: params.error as string | undefined,
          duration_ms: params.duration_ms as number,
          timestamp: new Date().toISOString()
        };

        console.error(`[Executor] Task result: ${params.task_id} (${params.agent}) = ${params.success ? 'OK' : 'FAIL'}`);

        return jsonOk({
          success: true,
          message: `Task result recorded for ${params.task_id}`,
          result: logEntry
        });
      }
    );

    // Tool: finalize_execution (DSH 集成)
    // ⚠️ 给接手 Agent 的提示：
    //   所有任务和验证完成后，调用这个工具更新提案状态。
    const FinalizeExecutionShape = {
      proposal_id: z.string().describe('提案 ID'),
      success: z.boolean().describe('是否全部成功'),
      error: z.string().optional().describe('失败原因（失败时）')
    };

    this.defineTool(
      'finalize_execution',
      '完成进化提案的执行。所有任务和验证完成后调用此工具更新提案状态。',
      FinalizeExecutionShape,
      async (params) => {
        const proposal = await this.proposals.find(params.proposal_id as string);
        if (!proposal) {
          return jsonError(`Proposal not found: ${params.proposal_id}`);
        }

        if (params.success as boolean) {
          // 成功：更新为 completed
          await this.proposals.setStatus(params.proposal_id as string, 'completed');
          console.error(`[Executor] Proposal ${params.proposal_id} completed successfully`);
          return jsonOk({
            success: true,
            message: `Proposal ${params.proposal_id} execution completed`,
            new_status: 'completed'
          });
        } else {
          // 失败：回滚到 pending
          await this.proposals.setStatus(params.proposal_id as string, 'pending');
          console.error(`[Executor] Proposal ${params.proposal_id} execution failed, rolled back to pending`);
          return jsonOk({
            success: true,
            message: `Proposal ${params.proposal_id} execution failed, rolled back to pending`,
            new_status: 'pending',
            error: params.error
          });
        }
      }
    );
  }

  /**
   * Set up graceful shutdown handlers
   */
  private setupShutdown(): void {
    const shutdown = async () => {
      console.error('[HarnessEvolution] Shutting down...');
      await this.stop();
      process.exit(0);
    };

    process.on('SIGINT', shutdown);
    process.on('SIGTERM', shutdown);
    if (process.platform === 'win32') {
      process.on('SIGBREAK', shutdown);
    }
  }

  /**
   * Start the server with stdio transport
   */
  async start(): Promise<void> {
    await this.monitor.start();
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('[HarnessEvolution] Server started');
  }

  /**
   * Stop the server
   */
  async stop(): Promise<void> {
    await this.monitor.stop();
    await this.server.close();
    console.error('[HarnessEvolution] Server stopped');
  }
}

// Main entry point
async function main() {
  const server = new HarnessEvolutionServer();

  try {
    await server.start();
  } catch (error) {
    console.error('[HarnessEvolution] Failed to start:', error);
    process.exit(1);
  }
}

// Run main if this is the entry point
if (require.main === module) {
  main().catch(console.error);
}
