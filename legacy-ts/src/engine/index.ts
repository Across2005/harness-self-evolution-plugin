/**
 * Evolution Engine - Generates evolution proposals based on performance data
 * 
 * Responsibilities:
 * - Analyze performance metrics and signals
 * - Apply Matt Pocock engineering principles
 * - Generate evolution proposals with expected benefits
 * - Deduplicate proposals using signatures
 */

import {
  EvolutionProposal,
  EvolutionSignal,
  EvolutionType,
  MattPocockPrinciple,
  ProposedChanges,
  ExpectedBenefits,
  ValidationPlan,
  RiskAssessment,
  PluginMetadata,
  ToolMerge,
  ParamSimplification,
  MiddlewareAddition,
  FlowOptimization,
  DocumentationUpdate,
  CapabilityAddition,
  ErrorHandlingImprovement
} from '../types';
import { PerformanceMonitor } from '../monitor';
import { ProposalStore, JsonlStore } from '../store';

export class EvolutionEngine {
  private signalsStore: JsonlStore<EvolutionSignal>;
  private proposals: ProposalStore;
  private monitor: PerformanceMonitor;
  private config: {
    intensity: '100%' | '50%' | '0%';
    maxProposalsPerSession: number;
    cooldownHours: number;
  };

  constructor(
    monitor: PerformanceMonitor,
    proposalsStore: ProposalStore = new ProposalStore(),
    config?: Partial<EvolutionEngine['config']>,
    signalsStore: JsonlStore<EvolutionSignal> = new JsonlStore<EvolutionSignal>('~/.harness-evolution/signals.jsonl')
  ) {
    this.monitor = monitor;
    this.proposals = proposalsStore;
    this.signalsStore = signalsStore;
    this.config = {
      intensity: config?.intensity ?? '50%',
      maxProposalsPerSession: config?.maxProposalsPerSession ?? 3,
      cooldownHours: config?.cooldownHours ?? 24
    };
  }

  /**
   * Generate evolution proposal for a plugin
   */
  async generateProposal(
    pluginId: string,
    pluginMetadata: PluginMetadata,
    signals?: EvolutionSignal[]
  ): Promise<EvolutionProposal | null> {
    // Check if evolution is enabled
    if (this.config.intensity === '0%') {
      console.error('[Engine] Evolution disabled (intensity: 0%)');
      return null;
    }

    // Get signals if not provided
    if (!signals) {
      signals = await this.getSignalsForPlugin(pluginId);
    }

    // Filter signals based on intensity
    signals = this.filterSignalsByIntensity(signals);

    // Check if we have enough signals
    if (signals.length === 0) {
      console.error('[Engine] No signals to trigger evolution');
      return null;
    }

    // Skip if a pending proposal already exists for this plugin
    const pendingProposal = await this.proposals.findPendingForPlugin(pluginId);
    if (pendingProposal) {
      console.error('[Engine] Pending proposal already exists for this plugin');
      return pendingProposal;
    }

    // Check cooldown
    const cooldownMs = this.config.cooldownHours * 60 * 60 * 1000;
    const recentProposals = await this.proposals.recentForPlugin(pluginId, cooldownMs);
    if (recentProposals.length > 0) {
      console.error('[Engine] Plugin in cooldown period');
      return null;
    }

    // Determine evolution type based on signals
    const evolutionType = await this.determineEvolutionType(signals, pluginMetadata);
    
    // Apply Matt Pocock principle
    const principle = this.selectMattPocockPrinciple(evolutionType, signals);
    
    // Generate proposed changes
    const proposedChanges = await this.generateProposedChanges(
      pluginId,
      pluginMetadata,
      evolutionType,
      signals
    );
    
    // Calculate expected benefits
    const expectedBenefits = this.calculateExpectedBenefits(evolutionType, signals);
    
    // Create validation plan
    const validationPlan = this.createValidationPlan(evolutionType, pluginMetadata);
    
    // Assess risks
    const riskAssessment = this.assessRisks(evolutionType, proposedChanges);
    
    // Generate signature for deduplication (保留完整 plugin_id 含版本)
    const signature = this.generateSignature(pluginId, evolutionType, proposedChanges);
    
    // Check for duplicate proposals
    const duplicateProposal = await this.proposals.findDuplicate(signature);

    if (duplicateProposal) {
      console.error('[Engine] Duplicate proposal detected');
      return duplicateProposal;
    }

    // Create proposal
    const proposal: EvolutionProposal = {
      proposal_id: `evo-${new Date().toISOString().split('T')[0]}-${signature}`,
      plugin_id: pluginId,
      status: 'pending',
      created_at: new Date().toISOString(),
      trigger_signals: signals,
      evolution_type: evolutionType,
      matt_pocock_principle: principle,
      proposed_changes: proposedChanges,
      expected_benefits: expectedBenefits,
      validation_plan: validationPlan,
      risk_assessment: riskAssessment,
      signature: signature,
      confidence: this.determineConfidence(signals)
    };

    // Save proposal
    await this.proposals.save(proposal);
    
    console.error(`[Engine] Generated proposal: ${proposal.proposal_id}`);
    return proposal;
  }

  /**
   * Get signals for a plugin
   */
  private async getSignalsForPlugin(pluginId: string): Promise<EvolutionSignal[]> {
    const signals = await this.signalsStore.load();
    return signals.filter(s => s.plugin_id === pluginId);
  }

  /**
   * Filter signals based on intensity setting
   */
  private filterSignalsByIntensity(signals: EvolutionSignal[]): EvolutionSignal[] {
    if (this.config.intensity === '100%') {
      return signals; // Accept all signals
    }
    
    if (this.config.intensity === '50%') {
      // Only strong signals
      return signals.filter(s => s.type === 'strong');
    }
    
    return [];
  }

  /**
   * Determine evolution type based on signals and plugin metadata
   */
  private async determineEvolutionType(
    signals: EvolutionSignal[], 
    pluginMetadata: PluginMetadata
  ): Promise<EvolutionType> {
    // Check signal patterns
    const hasLoopSignal = signals.some(s => s.category === 'loop');
    const hasStruggleSignal = signals.some(s => s.category === 'struggle');
    const hasCorrectionSignal = signals.some(s => s.category === 'correction');
    const hasPreferenceSignal = signals.some(s => s.category === 'preference');
    const hasWorkflowSignal = signals.some(s => s.category === 'workflow');

    // Loop detected → behavior optimization
    if (hasLoopSignal) {
      return 'behavior_optimization';
    }

    // High complexity + struggle → interface simplification
    if (hasStruggleSignal && pluginMetadata.initial_metrics.complexity_score > 7) {
      return 'interface_simplification';
    }

    // User correction → error handling improvement
    if (hasCorrectionSignal) {
      return 'error_handling_improvement';
    }

    // User preference → documentation enhancement or interface simplification
    if (hasPreferenceSignal) {
      if (pluginMetadata.initial_metrics.interface_clarity < 7) {
        return 'interface_simplification';
      }
      return 'documentation_enhancement';
    }

    // Workflow pattern → capability extension
    if (hasWorkflowSignal) {
      return 'capability_extension';
    }

    // Performance issues → performance tuning
    const stats = await this.monitor.getStatistics(pluginMetadata.plugin_id, 'last_day');
    if (stats.avg_latency_ms > 2000 || stats.success_rate < 0.9) {
      return 'performance_tuning';
    }

    // Default: documentation enhancement
    return 'documentation_enhancement';
  }

  /**
   * Select appropriate Matt Pocock principle
   */
  private selectMattPocockPrinciple(
    evolutionType: EvolutionType, 
    _signals: EvolutionSignal[]
  ): MattPocockPrinciple {
    switch (evolutionType) {
      case 'interface_simplification':
        return 'Deep Module > 浅模块';
      
      case 'behavior_optimization':
        return '紧反馈环 > 盲目试错';
      
      case 'performance_tuning':
        return '垂直切片 > 水平切片';
      
      case 'documentation_enhancement':
        return '词汇即文档';
      
      case 'capability_extension':
        return '先对齐，再动手';
      
      case 'error_handling_improvement':
        return '紧反馈环 > 盲目试错';
      
      default:
        return '先对齐，再动手';
    }
  }

  /**
   * Generate proposed changes based on evolution type
   */
  private async generateProposedChanges(
    pluginId: string,
    pluginMetadata: PluginMetadata,
    evolutionType: EvolutionType,
    signals: EvolutionSignal[]
  ): Promise<ProposedChanges> {
    const changes: ProposedChanges = {};

    switch (evolutionType) {
      case 'interface_simplification':
        changes.merge_tools = await this.proposeToolMerges(pluginId, pluginMetadata, signals);
        changes.simplify_params = await this.proposeParamSimplification(pluginId, pluginMetadata);
        break;
      
      case 'behavior_optimization':
        changes.add_middleware = this.proposeMiddleware(signals);
        break;
      
      case 'performance_tuning':
        changes.optimize_flow = await this.proposeFlowOptimization(pluginId, pluginMetadata);
        break;
      
      case 'documentation_enhancement':
        changes.update_documentation = this.proposeDocumentationUpdate(pluginMetadata, signals);
        break;
      
      case 'capability_extension':
        changes.add_capability = this.proposeCapabilityExtension(signals);
        break;
      
      case 'error_handling_improvement':
        changes.improve_error_handling = this.proposeErrorHandlingImprovement(signals);
        break;
    }

    return changes;
  }

  /**
   * Propose tool merges for interface simplification.
   * Analyzes actual tool usage patterns instead of hardcoded rules.
   */
  private async proposeToolMerges(
    _pluginId: string,
    pluginMetadata: PluginMetadata,
    _signals: EvolutionSignal[]
  ): Promise<ToolMerge[]> {
    // Find tools that are frequently used together
    const tools = pluginMetadata.tools;
    
    if (tools.length < 3) {
      return [];
    }

    // Look for common tool combinations based on naming patterns
    const navigationTools = tools.filter(t => 
      t.includes('navigate') || t.includes('goto') || t.includes('open')
    );
    const interactionTools = tools.filter(t => 
      t.includes('click') || t.includes('tap') || t.includes('press')
    );
    const inputTools = tools.filter(t => 
      t.includes('type') || t.includes('input') || t.includes('fill') || t.includes('enter')
    );

    const merges: ToolMerge[] = [];

    // If navigation + interaction + input tools exist, propose a smart_fill merge
    if (navigationTools.length > 0 && interactionTools.length > 0 && inputTools.length > 0) {
      merges.push({
        new_tool: 'smart_fill',
        merged_from: [navigationTools[0], interactionTools[0], inputTools[0]],
        new_interface: {
          params: ['url', 'selector', 'text'],
          description: '一站式表单填充：导航 + 定位 + 输入',
          defaults: {}
        },
        backward_compatible: true
      });
    }

    // If there are multiple similar tools, propose consolidation
    const toolGroups = this.groupSimilarTools(tools);
    for (const group of toolGroups) {
      if (group.length >= 3) {
        merges.push({
          new_tool: `unified_${group[0]}`,
          merged_from: group,
          new_interface: {
            params: ['action', 'target', 'options'],
            description: `统一的 ${group[0]} 操作，合并 ${group.join(', ')}`,
            defaults: { action: group[0] }
          },
          backward_compatible: true
        });
      }
    }

    return merges;
  }

  /**
   * Group similar tools by name prefix
   */
  private groupSimilarTools(tools: string[]): string[][] {
    const groups: Map<string, string[]> = new Map();
    
    for (const tool of tools) {
      // Extract prefix (first word or before underscore)
      const prefix = tool.split('_')[0].split('-')[0].toLowerCase();
      if (!groups.has(prefix)) {
        groups.set(prefix, []);
      }
      groups.get(prefix)!.push(tool);
    }

    return Array.from(groups.values()).filter(g => g.length >= 2);
  }

  /**
   * Propose parameter simplification based on tool analysis
   */
  private async proposeParamSimplification(
    _pluginId: string,
    pluginMetadata: PluginMetadata
  ): Promise<ParamSimplification[]> {
    // Analyze which tools have many parameters
    // In production, this would analyze actual usage patterns
    const simplifications: ParamSimplification[] = [];

    // For now, suggest simplifying tools with common optional parameters
    for (const tool of pluginMetadata.tools.slice(0, 5)) {
      simplifications.push({
        tool,
        remove_params: ['verbose', 'debug', 'dry_run'],
        defaults: { verbose: false, debug: false, dry_run: false },
        reason: '这些参数很少使用，可以设置默认值简化接口'
      });
    }

    return simplifications;
  }

  /**
   * Propose middleware for behavior optimization
   */
  private proposeMiddleware(signals: EvolutionSignal[]): MiddlewareAddition[] {
    const middleware: MiddlewareAddition[] = [];

    // Loop detection middleware
    const loopSignal = signals.find(s => s.category === 'loop');
    if (loopSignal) {
      const toolMatch = loopSignal.description.match(/Tool (\w+) called/);
      middleware.push({
        name: 'loop_detection',
        target_tool: toolMatch?.[1] || 'unknown',
        threshold: 5,
        intervention: '检测到循环，建议使用批量操作或调整参数',
        priority: 10
      });
    }

    // Failure recovery middleware
    const struggleSignal = signals.find(s => s.category === 'struggle');
    if (struggleSignal) {
      middleware.push({
        name: 'failure_recovery',
        threshold: 3,
        intervention: '连续失败检测，建议切换策略或请求帮助',
        priority: 8
      });
    }

    return middleware;
  }

  /**
   * Propose flow optimization based on performance analysis
   */
  private async proposeFlowOptimization(
    pluginId: string,
    pluginMetadata: PluginMetadata
  ): Promise<FlowOptimization[]> {
    const optimizations: FlowOptimization[] = [];
    const stats = await this.monitor.getStatistics(pluginId, 'last_week');

    // If latency is high, suggest caching
    if (stats.avg_latency_ms > 1000) {
      optimizations.push({
        tool: pluginMetadata.tools[0] || 'unknown',
        optimization_type: 'caching',
        implementation: '添加结果缓存，避免重复计算',
        expected_improvement: '延迟降低 30-50%'
      });
    }

    // If many calls, suggest batching
    if (stats.total_calls > 100) {
      optimizations.push({
        tool: pluginMetadata.tools[0] || 'unknown',
        optimization_type: 'batching',
        implementation: '批量处理多个请求，减少上下文切换',
        expected_improvement: '吞吐量提升 20-40%'
      });
    }

    // If multiple tools used together, suggest parallelization
    if (pluginMetadata.tools.length > 3) {
      optimizations.push({
        tool: 'multiple',
        optimization_type: 'parallelization',
        implementation: '并行执行独立的工具调用',
        expected_improvement: '总延迟降低 40-60%'
      });
    }

    return optimizations;
  }

  /**
   * Propose documentation update
   */
  private proposeDocumentationUpdate(
    pluginMetadata: PluginMetadata,
    signals: EvolutionSignal[]
  ): DocumentationUpdate[] {
    const updates: DocumentationUpdate[] = [];
    
    // If documentation quality is low, propose improvements
    if (pluginMetadata.initial_metrics.documentation_quality < 7) {
      updates.push({
        file: 'SKILL.md',
        section: 'Usage Examples',
        new_content: '添加具体使用示例和常见场景说明',
        reason: '文档质量评分较低，需要增强实用性'
      });
    }

    // Add signal-based documentation
    for (const signal of signals) {
      if (signal.category === 'workflow') {
        updates.push({
          file: 'SKILL.md',
          section: 'Workflow',
          new_content: `记录可复用工作流：${signal.description}`,
          reason: '用户形成了可复用的工作流模式'
        });
      }

      if (signal.category === 'correction') {
        updates.push({
          file: 'SKILL.md',
          section: 'Common Mistakes',
          new_content: `常见错误：${signal.description}`,
          reason: '用户多次纠正同一问题'
        });
      }
    }

    return updates;
  }

  /**
   * Propose capability extension
   */
  private proposeCapabilityExtension(signals: EvolutionSignal[]): CapabilityAddition[] {
    const capabilities: CapabilityAddition[] = [];
    const workflowSignal = signals.find(s => s.category === 'workflow');
    
    if (workflowSignal) {
      capabilities.push({
        capability_name: 'custom_workflow',
        description: workflowSignal.description,
        implementation: '基于用户工作流模式自动生成',
        dependencies: []
      });
    }

    return capabilities;
  }

  /**
   * Propose error handling improvement
   */
  private proposeErrorHandlingImprovement(signals: EvolutionSignal[]): ErrorHandlingImprovement[] {
    const improvements: ErrorHandlingImprovement[] = [];
    const correctionSignal = signals.find(s => s.category === 'correction');
    
    if (correctionSignal) {
      improvements.push({
        error_type: 'user_correction',
        current_behavior: '未捕获用户纠正',
        improved_behavior: '记录用户纠正并调整行为',
        user_message: '已记录您的偏好，下次将按此执行',
        recovery_strategy: '应用用户纠正并更新规则'
      });
    }

    // Add error-specific improvements
    const struggleSignal = signals.find(s => s.category === 'struggle');
    if (struggleSignal) {
      improvements.push({
        error_type: 'consecutive_failure',
        current_behavior: '连续失败后继续尝试',
        improved_behavior: '检测到连续失败后切换策略',
        user_message: '检测到多次失败，正在尝试替代方案',
        recovery_strategy: '自动切换到备用实现'
      });
    }

    return improvements;
  }

  /**
   * Calculate expected benefits
   */
  private calculateExpectedBenefits(
    evolutionType: EvolutionType, 
    _signals: EvolutionSignal[]
  ): ExpectedBenefits {
    switch (evolutionType) {
      case 'interface_simplification':
        return {
          latency_improvement: '30-40%',
          token_reduction: '25-35%',
          user_satisfaction: '+15-25%'
        };
      
      case 'behavior_optimization':
        return {
          token_reduction: '40-60%',
          error_reduction: '-50%'
        };
      
      case 'performance_tuning':
        return {
          latency_improvement: '20-30%',
          success_rate: '+5-10%'
        };
      
      case 'documentation_enhancement':
        return {
          user_satisfaction: '+10-20%'
        };
      
      case 'capability_extension':
        return {
          user_satisfaction: '+20-30%',
          success_rate: '+10-15%'
        };
      
      case 'error_handling_improvement':
        return {
          error_reduction: '-40-60%',
          user_satisfaction: '+10-15%'
        };
      
      default:
        return {};
    }
  }

  /**
   * Create validation plan
   */
  private createValidationPlan(
    evolutionType: EvolutionType, 
    pluginMetadata: PluginMetadata
  ): ValidationPlan {
    return {
      test_scenarios: this.generateTestScenarios(evolutionType, pluginMetadata),
      success_criteria: '成功率 >= 95%，延迟 < 2s，无回归问题',
      rollback_strategy: '保留原版本 30 天，支持一键回滚',
      validation_levels: [
        { level: 'T0', description: '语法验证：代码可编译/解析', automated: true, timeout_ms: 30000 },
        { level: 'T1', description: '功能验证：新功能正常工作', automated: true, timeout_ms: 60000 },
        { level: 'T2', description: '回归验证：不影响现有功能', automated: true, timeout_ms: 120000 }
      ]
    };
  }

  /**
   * Generate test scenarios
   */
  private generateTestScenarios(
    evolutionType: EvolutionType, 
    pluginMetadata: PluginMetadata
  ): string[] {
    const scenarios: string[] = [];
    
    // Add scenarios based on plugin capabilities
    for (const capability of pluginMetadata.capabilities.slice(0, 3)) {
      scenarios.push(`测试 ${capability} 功能`);
    }
    
    // Add evolution-type specific scenarios
    switch (evolutionType) {
      case 'interface_simplification':
        scenarios.push('测试新工具接口', '测试向后兼容性');
        break;
      case 'behavior_optimization':
        scenarios.push('测试循环检测', '测试干预提示');
        break;
      case 'performance_tuning':
        scenarios.push('性能基准测试', '负载测试');
        break;
      case 'error_handling_improvement':
        scenarios.push('测试错误恢复', '测试用户提示');
        break;
    }

    return scenarios;
  }

  /**
   * Assess risks
   */
  private assessRisks(
    evolutionType: EvolutionType, 
    proposedChanges: ProposedChanges
  ): RiskAssessment {
    // Check for breaking changes
    const hasBreakingChanges = this.checkBreakingChanges(proposedChanges);
    
    // Check backward compatibility
    const backwardCompatible = this.checkBackwardCompatibility(proposedChanges);
    
    // Estimate migration effort
    const migrationEffort = this.estimateMigrationEffort(evolutionType, proposedChanges);
    
    return {
      breaking_changes: hasBreakingChanges,
      backward_compatible: backwardCompatible,
      migration_effort: migrationEffort,
      affected_users: 0, // Would need actual user tracking
      rollback_complexity: migrationEffort === 'low' ? 'simple' : migrationEffort === 'medium' ? 'moderate' : 'complex'
    };
  }

  /**
   * Check for breaking changes
   */
  private checkBreakingChanges(changes: ProposedChanges): boolean {
    // Tool merges without backward compatibility
    if (changes.merge_tools?.some(m => !m.backward_compatible)) {
      return true;
    }
    
    // Parameter removal without defaults
    if (changes.simplify_params?.some(p => Object.keys(p.defaults).length < p.remove_params.length)) {
      return true;
    }
    
    return false;
  }

  /**
   * Check backward compatibility
   */
  private checkBackwardCompatibility(changes: ProposedChanges): boolean {
    // Empty change set is compatible
    const hasChanges = Object.values(changes).some(v => v && v.length > 0);
    if (!hasChanges) return true;

    // All tool merges are backward compatible
    if (changes.merge_tools?.every(m => m.backward_compatible)) {
      return true;
    }
    
    // All param simplifications have defaults
    if (changes.simplify_params?.every(p => 
      p.remove_params.every(param => param in p.defaults)
    )) {
      return true;
    }
    
    return false;
  }

  /**
   * Estimate migration effort
   */
  private estimateMigrationEffort(
    _evolutionType: EvolutionType, 
    changes: ProposedChanges
  ): 'low' | 'medium' | 'high' {
    const changeCount = Object.values(changes).filter(v => v && v.length > 0).length;
    
    if (changeCount <= 1) return 'low';
    if (changeCount <= 3) return 'medium';
    return 'high';
  }

  /**
   * Generate signature for deduplication.
   * 保留完整 plugin_id（含版本号），避免多版本同名插件签名撞车。
   */
  private generateSignature(
    pluginId: string, 
    evolutionType: EvolutionType, 
    _changes: ProposedChanges
  ): string {
    // Normalize evolution type
    const normalizedType = evolutionType.replace(/_/g, '-');
    
    // Use full plugin_id (including version)
    return `${pluginId}-${normalizedType}`;
  }

  /**
   * Determine confidence level
   */
  private determineConfidence(signals: EvolutionSignal[]): 'high' | 'medium' | 'low' {
    const strongCount = signals.filter(s => s.type === 'strong').length;
    const mediumCount = signals.filter(s => s.type === 'medium').length;
    
    if (strongCount >= 2) return 'high';
    if (strongCount >= 1 || mediumCount >= 2) return 'medium';
    return 'low';
  }
}
