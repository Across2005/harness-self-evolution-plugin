/**
 * Harness Self-Evolution Plugin - Type Definitions
 * 
 * Based on:
 * - DeepSeek Harness six extension mechanisms
 * - Hermes-Evolution proposal workflow
 * - Matt Pocock engineering principles
 */

// ============================================================================
// Plugin Metadata Types
// ============================================================================

export interface PluginMetadata {
  plugin_id: string;
  name: string;
  version: string;
  type: 'official' | 'community' | 'custom';
  capabilities: string[];
  tools: string[];
  events: string[];
  dependencies: string[];
  scan_timestamp: string;
  path: string;
  initial_metrics: PluginMetrics;
}

export interface PluginMetrics {
  complexity_score: number;      // 0-10, higher = more complex
  interface_clarity: number;     // 0-10, higher = clearer
  documentation_quality: number; // 0-10, higher = better docs
  usage_frequency?: 'high' | 'medium' | 'low' | 'idle';
}

// ============================================================================
// Performance Monitoring Types
// ============================================================================

export interface PerformanceEvent {
  session_id: string;
  plugin_id: string;
  timestamp: string;
  event_type: 'tool_call' | 'event_fired' | 'capability_used' | 'error';
  event_data: ToolCallData | EventData | CapabilityData | ErrorData;
  context: EventContext;
}

export interface ToolCallData {
  tool: string;
  params: Record<string, any>;
  latency_ms: number;
  success: boolean;
  token_usage?: TokenUsage;
  retry_count: number;
  error_message?: string;
}

export interface EventData {
  event_name: string;
  payload: any;
  processing_time_ms: number;
}

export interface CapabilityData {
  capability: string;
  operation: string;
  duration_ms: number;
  success: boolean;
}

export interface ErrorData {
  error_type: 'timeout' | 'parameter_error' | 'permission_error' | 'runtime_error' | 'unknown';
  error_message: string;
  stack_trace?: string;
  recovery_attempted: boolean;
}

export interface TokenUsage {
  input: number;
  output: number;
  total: number;
}

export interface EventContext {
  task_type?: string;
  user_feedback?: 'positive' | 'negative' | 'neutral' | null;
  conversation_turn: number;
  related_tools?: string[];
}

// ============================================================================
// Signal Detection Types (from Hermes-Evolution)
// ============================================================================

export type SignalStrength = 'strong' | 'medium' | 'weak';

export interface EvolutionSignal {
  type: SignalStrength;
  category: 'correction' | 'preference' | 'workflow' | 'struggle' | 'pattern' | 'loop';
  description: string;
  evidence: string;  // File path or session log reference
  timestamp: string;
  plugin_id: string;
  count?: number;  // For accumulated signals
}

export interface SignalThresholds {
  strong: {
    user_correction: boolean;
    explicit_preference: boolean;
    consecutive_failures: number;
    performance_drop: number;  // Percentage drop threshold
  };
  medium: {
    pattern_repeat: number;
    loop_detection: number;
    preference_repeat: number;
  };
}

// ============================================================================
// Evolution Proposal Types
// ============================================================================

export interface EvolutionProposal {
  proposal_id: string;  // evo-YYYY-MM-DD-plugin-name-change-type
  plugin_id: string;
  status: 'pending' | 'approved' | 'rejected' | 'executing' | 'completed';
  created_at: string;
  trigger_signals: EvolutionSignal[];
  evolution_type: EvolutionType;
  matt_pocock_principle: MattPocockPrinciple;
  proposed_changes: ProposedChanges;
  expected_benefits: ExpectedBenefits;
  validation_plan: ValidationPlan;
  risk_assessment: RiskAssessment;
  signature: string;  // Normalized signature for deduplication
  confidence: 'high' | 'medium' | 'low';
}

export type EvolutionType = 
  | 'interface_simplification'    // Merge tools, simplify params
  | 'behavior_optimization'       // Add middleware, fix loops
  | 'performance_tuning'          // Optimize latency, token usage
  | 'documentation_enhancement'   // Improve SKILL.md
  | 'capability_extension'        // Add new capabilities
  | 'error_handling_improvement'; // Better error messages, recovery

export type MattPocockPrinciple =
  | '先对齐，再动手'        // Align before acting
  | '垂直切片 > 水平切片'   // Vertical > horizontal slicing
  | '紧反馈环 > 盲目试错'   // Tight feedback > blind trial
  | 'Deep Module > 浅模块'  // Deep > shallow modules
  | '定期架构扫描'          // Regular architecture scanning
  | '词汇即文档';           // Vocabulary as documentation

export interface ProposedChanges {
  merge_tools?: ToolMerge[];
  simplify_params?: ParamSimplification[];
  add_middleware?: MiddlewareAddition[];
  optimize_flow?: FlowOptimization[];
  update_documentation?: DocumentationUpdate[];
  add_capability?: CapabilityAddition[];
  improve_error_handling?: ErrorHandlingImprovement[];
}

export interface ToolMerge {
  new_tool: string;
  merged_from: string[];
  new_interface: {
    params: string[];
    description: string;
    defaults?: Record<string, any>;
  };
  backward_compatible: boolean;
}

export interface ParamSimplification {
  tool: string;
  remove_params: string[];
  defaults: Record<string, any>;
  reason: string;
}

export interface MiddlewareAddition {
  name: string;
  target_tool?: string;
  target_event?: string;
  threshold?: number;
  intervention: string;
  priority: number;
}

export interface FlowOptimization {
  tool: string;
  optimization_type: 'caching' | 'parallelization' | 'lazy_loading' | 'batching';
  implementation: string;
  expected_improvement: string;
}

export interface DocumentationUpdate {
  file: string;  // SKILL.md, README.md, etc.
  section: string;
  new_content: string;
  reason: string;
}

export interface CapabilityAddition {
  capability_name: string;
  description: string;
  implementation: string;
  dependencies: string[];
}

export interface ErrorHandlingImprovement {
  error_type: string;
  current_behavior: string;
  improved_behavior: string;
  user_message: string;
  recovery_strategy: string;
}

export interface ExpectedBenefits {
  latency_improvement?: string;  // e.g., "30%"
  token_reduction?: string;      // e.g., "25%"
  user_satisfaction?: string;    // e.g., "+15%"
  success_rate?: string;         // e.g., "+10%"
  error_reduction?: string;      // e.g., "-50%"
}

export interface ValidationPlan {
  test_scenarios: string[];
  success_criteria: string;
  rollback_strategy: string;
  validation_levels: ValidationLevel[];
}

export interface ValidationLevel {
  level: 'T0' | 'T1' | 'T2';  // Syntax, Functionality, Regression
  description: string;
  automated: boolean;
  timeout_ms?: number;
}

export interface RiskAssessment {
  breaking_changes: boolean;
  backward_compatible: boolean;
  migration_effort: 'low' | 'medium' | 'high';
  affected_users: number;
  rollback_complexity: 'simple' | 'moderate' | 'complex';
}

// ============================================================================
// Sub-Agent Orchestration Types
// ============================================================================

export interface SubAgentTask {
  agent: AgentType;
  task: string;
  input: any;
  dependencies?: string[];  // Other task IDs
  timeout_ms?: number;
}

export type AgentType = 
  | 'code-generator'    // Generate new tool code
  | 'test-writer'       // Write test cases
  | 'doc-writer'        // Update documentation
  | 'integration'       // Handle dependencies
  | 'validator';        // Run validation tests

export interface SubAgentResult {
  task_id: string;
  agent: AgentType;
  success: boolean;
  output: any;
  error?: string;
  duration_ms: number;
}

// ============================================================================
// Registry Types
// ============================================================================

export interface PluginRegistry {
  plugins: Map<string, PluginMetadata>;
  metrics: PerformanceEvent[];
  proposals: Map<string, EvolutionProposal>;
  last_scan: string;
  config: EvolutionConfig;
}

export interface EvolutionConfig {
  intensity: '100%' | '50%' | '0%';
  auto_approve: boolean;
  max_proposals_per_session: number;
  cooldown_hours: number;
  signal_thresholds: SignalThresholds;
}

// ============================================================================
// MCP Tool Types
// ============================================================================

export interface ScanPluginsParams {
  force_rescan?: boolean;
  target_paths?: string[];
}

export interface GetMetricsParams {
  plugin_id: string;
  time_range?: 'last_hour' | 'last_day' | 'last_week' | 'all';
  metrics?: string[];
}

export interface ProposeEvolutionParams {
  plugin_id: string;
  signals?: string[];
  evolution_type?: EvolutionType;
}

export interface ExecuteEvolutionParams {
  proposal_id: string;
  dry_run?: boolean;
}

export interface ListProposalsParams {
  status?: EvolutionProposal['status'];
  plugin_id?: string;
  limit?: number;
}

export interface ApprovalParams {
  proposal_id: string;
  action: 'approve' | 'reject' | 'revise';
  revision_instructions?: string;
}
