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
 *
 * 所有工具共享一个 ProposalStore 实例（单一事实来源），
 * 错误处理统一由 defineTool 包装器负责。
 */

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import { PluginScanner } from '../scanner/index.js';
import { PerformanceMonitor } from '../monitor/index.js';
import { EvolutionEngine } from '../engine/index.js';
import { UpgradeExecutor } from '../executor/index.js';
import { ProposalStore } from '../store/index.js';
import type { PluginMetadata, EvolutionSignal } from '../types/index.js';

// Zod raw shapes for tool parameters（registerTool 需要 ZodRawShape，而非 ZodObject）
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

/** Tool result helpers — 统一所有工具的返回格式 */
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
  private pluginRegistry: Map<string, PluginMetadata> = new Map();

  constructor() {
    this.server = new McpServer({
      name: 'harness-self-evolution',
      version: '1.0.0'
    });

    // Single source of truth shared by engine, executor and the tools below
    this.proposals = new ProposalStore();
    this.scanner = new PluginScanner();
    this.monitor = new PerformanceMonitor();
    this.engine = new EvolutionEngine(this.monitor, this.proposals);
    this.executor = new UpgradeExecutor(this.proposals);

    this.setupTools();
  }

  /**
   * Register a tool with centralized error handling.
   * 处理器只需返回业务结果 JSON；抛出的异常在这里变成标准错误响应。
   */
  private defineTool(
    name: string,
    description: string,
    shape: Record<string, z.ZodTypeAny>,
    handler: (params: any) => Promise<ToolResult>
  ): void {
    this.server.registerTool(
      name,
      { description, inputSchema: shape },
      async (params) => {
        try {
          return await handler(params);
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
        const plugins = await this.scanner.scanAll(params.force_rescan);
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
        const stats = await this.monitor.getStatistics(params.plugin_id, params.time_range);
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
        const plugin = this.pluginRegistry.get(params.plugin_id);
        if (!plugin) {
          return jsonError(`Plugin not found: ${params.plugin_id}. Run scan_plugins first.`);
        }

        // Manually supplied signal descriptions become medium pattern signals
        const manualSignals: EvolutionSignal[] | undefined = params.signals?.map(
          (description: string) => ({
            type: 'medium' as const,
            category: 'pattern' as const,
            description,
            evidence: 'user:manual',
            timestamp: new Date().toISOString(),
            plugin_id: params.plugin_id
          })
        );

        const proposal = await this.engine.generateProposal(
          params.plugin_id,
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
        const result = await this.executor.execute(params.proposal_id, params.dry_run);
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
          status: params.status,
          plugin_id: params.plugin_id,
          limit: params.limit
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
        const updated = await this.proposals.setStatus(params.proposal_id, 'approved');
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
        const updated = await this.proposals.setStatus(params.proposal_id, 'rejected');
        if (!updated) {
          return jsonError(`Proposal not found: ${params.proposal_id}`);
        }
        return jsonOk({ success: true, message: `Proposal ${params.proposal_id} rejected` });
      }
    );
  }

  /**
   * Start the server with stdio transport
   */
  async start(): Promise<void> {
    await this.monitor.start();
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('[HarnessEvolution] Server started'); // Use stderr for logging
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

  // Handle shutdown
  process.on('SIGINT', async () => {
    await server.stop();
    process.exit(0);
  });

  process.on('SIGTERM', async () => {
    await server.stop();
    process.exit(0);
  });
}

// Run main if this is the entry point
main().catch(console.error);
