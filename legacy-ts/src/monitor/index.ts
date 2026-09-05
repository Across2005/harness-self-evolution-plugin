/**
 * Performance Monitor - Monitors plugin performance during conversations
 *
 * Responsibilities:
 * - Listen to plugin call events
 * - Record performance metrics (latency, success rate, token usage)
 * - Detect anomalies (loops, failures, performance drops)
 * - Accumulate evolution signals
 *
 * 信号检测使用内存中的会话事件（紧反馈环），磁盘全量扫描仅在
 * 深度检查中按节流间隔执行，避免每次工具调用都读 3 遍全量文件。
 */

import {
  PerformanceEvent,
  EvolutionSignal,
  TokenUsage,
  EventContext
} from '../types';
import { JsonlStore } from '../store';

/** 会话事件内存上限，防止长会话内存无限增长 */
const MAX_SESSION_EVENTS = 500;

/** 每插件深度检查（含磁盘对比）的最小间隔 */
const DEEP_CHECK_INTERVAL_MS = 30_000;

export class PerformanceMonitor {
  private metricsStore: JsonlStore<PerformanceEvent>;
  private signalsStore: JsonlStore<EvolutionSignal>;
  private currentSessionId: string;
  private eventBuffer: PerformanceEvent[] = [];
  private signalBuffer: EvolutionSignal[] = [];
  /** 本会话事件副本，供信号检测使用（含已刷盘事件） */
  private sessionEvents: PerformanceEvent[] = [];
  private lastDeepCheckAt: Map<string, number> = new Map();
  /** 已发射过 loop 信号的 plugin:tool 集合，片段结束后清除，防止重复刷屏 */
  private loopReported: Set<string> = new Set();
  private flushInterval: NodeJS.Timeout | null = null;

  constructor(
    metricsPath: string = '~/.harness-evolution/metrics.jsonl',
    signalsPath: string = '~/.harness-evolution/signals.jsonl'
  ) {
    this.metricsStore = new JsonlStore<PerformanceEvent>(metricsPath);
    this.signalsStore = new JsonlStore<EvolutionSignal>(signalsPath);
    this.currentSessionId = this.generateSessionId();
  }

  /**
   * Start monitoring
   */
  async start(): Promise<void> {
    // Flush buffer every 5 seconds
    this.flushInterval = setInterval(() => {
      void this.flushBuffers();
    }, 5000);

    console.log(`[Monitor] Started monitoring session ${this.currentSessionId}`);
  }

  /**
   * Stop monitoring
   */
  async stop(): Promise<void> {
    if (this.flushInterval) {
      clearInterval(this.flushInterval);
      this.flushInterval = null;
    }

    // Flush remaining events
    await this.flushBuffers();
    console.log('[Monitor] Stopped monitoring');
  }

  /**
   * Record a tool call event
   */
  async recordToolCall(
    pluginId: string,
    tool: string,
    params: Record<string, any>,
    latencyMs: number,
    success: boolean,
    tokenUsage?: TokenUsage,
    retryCount: number = 0,
    errorMessage?: string,
    context?: Partial<EventContext>
  ): Promise<void> {
    const event: PerformanceEvent = {
      session_id: this.currentSessionId,
      plugin_id: pluginId,
      timestamp: new Date().toISOString(),
      event_type: 'tool_call',
      event_data: {
        tool,
        params,
        latency_ms: latencyMs,
        success,
        token_usage: tokenUsage,
        retry_count: retryCount,
        error_message: errorMessage
      },
      context: {
        conversation_turn: context?.conversation_turn || 0,
        task_type: context?.task_type,
        user_feedback: context?.user_feedback || null,
        related_tools: context?.related_tools
      }
    };

    this.eventBuffer.push(event);
    this.pushSessionEvent(event);

    // Check for signals
    await this.checkForSignals(pluginId, event);
  }

  /**
   * Record user feedback
   */
  async recordUserFeedback(
    pluginId: string,
    feedback: 'positive' | 'negative' | 'neutral',
    context?: string
  ): Promise<void> {
    // Find last event for this plugin and update feedback
    const lastEvent = [...this.sessionEvents].reverse().find(e => e.plugin_id === pluginId);
    if (lastEvent) {
      lastEvent.context.user_feedback = feedback;
    }

    // Generate signal based on feedback
    if (feedback === 'negative') {
      this.signalBuffer.push(this.createSignal(pluginId, 'strong', 'correction',
        `User gave negative feedback: ${context || 'no details'}`,
        `session:${this.currentSessionId}`));
    }
  }

  /**
   * Get metrics for a specific plugin
   */
  async getMetrics(
    pluginId: string,
    timeRange: 'last_hour' | 'last_day' | 'last_week' | 'all' = 'all'
  ): Promise<PerformanceEvent[]> {
    // 刷盘后再读，保证统计包含本会话尚未落盘的事件
    await this.flushBuffers();
    const events = await this.metricsStore.load();
    const cutoff = this.calculateCutoff(new Date(), timeRange);

    return events.filter(e => {
      const eventTime = new Date(e.timestamp);
      return e.plugin_id === pluginId && eventTime >= cutoff;
    });
  }

  /**
   * Get aggregated statistics for a plugin
   */
  async getStatistics(pluginId: string, timeRange: 'last_hour' | 'last_day' | 'last_week' | 'all' = 'all'): Promise<{
    total_calls: number;
    success_rate: number;
    avg_latency_ms: number;
    total_tokens: number;
    avg_retry_count: number;
    error_types: Record<string, number>;
    loop_detected: boolean;
  }> {
    const events = await this.getMetrics(pluginId, timeRange);
    const toolCalls = events.filter(e => e.event_type === 'tool_call');

    if (toolCalls.length === 0) {
      return {
        total_calls: 0,
        success_rate: 0,
        avg_latency_ms: 0,
        total_tokens: 0,
        avg_retry_count: 0,
        error_types: {},
        loop_detected: false
      };
    }

    const successCount = toolCalls.filter(e => (e.event_data as any).success).length;
    const totalLatency = toolCalls.reduce((sum, e) => sum + (e.event_data as any).latency_ms, 0);
    const totalTokens = toolCalls.reduce((sum, e) => {
      const tokenUsage = (e.event_data as any).token_usage;
      return sum + (tokenUsage ? tokenUsage.total || (tokenUsage.input + tokenUsage.output) : 0);
    }, 0);
    const totalRetries = toolCalls.reduce((sum, e) => sum + (e.event_data as any).retry_count, 0);

    // Count error types
    const errorTypes: Record<string, number> = {};
    for (const event of toolCalls) {
      const error = (event.event_data as any).error_message;
      if (error) {
        const errorType = this.classifyError(error);
        errorTypes[errorType] = (errorTypes[errorType] || 0) + 1;
      }
    }

    return {
      total_calls: toolCalls.length,
      success_rate: successCount / toolCalls.length,
      avg_latency_ms: totalLatency / toolCalls.length,
      total_tokens: totalTokens,
      avg_retry_count: totalRetries / toolCalls.length,
      error_types: errorTypes,
      loop_detected: this.detectLoops(toolCalls)
    };
  }

  /**
   * Check for evolution signals.
   * 失败/循环检测走内存会话事件（O(最近事件)），延迟对比等
   * 磁盘深度检查按 DEEP_CHECK_INTERVAL_MS 节流。
   */
  private async checkForSignals(pluginId: string, event: PerformanceEvent): Promise<void> {
    const recentToolCalls = this.sessionEvents.filter(
      e => e.plugin_id === pluginId && e.event_type === 'tool_call'
    );

    // Check for consecutive failures (in-memory)
    const consecutiveFailures = this.countTrailing(recentToolCalls, e => !(e.event_data as any).success);
    if (consecutiveFailures >= 3) {
      this.signalBuffer.push(this.createSignal(
        pluginId, 'strong', 'struggle',
        `${consecutiveFailures} consecutive failures detected`,
        `session:${this.currentSessionId}`, consecutiveFailures));
    }

    // Check for loops (in-memory); emit once per loop episode
    const toolName = (event.event_data as any).tool;
    const loopKey = `${pluginId}:${toolName}`;
    const loopCount = this.countTrailing(recentToolCalls, e => (e.event_data as any).tool === toolName);
    if (loopCount < 5) {
      this.loopReported.delete(loopKey);
    } else if (!this.loopReported.has(loopKey)) {
      this.loopReported.add(loopKey);
      this.signalBuffer.push(this.createSignal(
        pluginId, 'medium', 'loop',
        `Tool ${toolName} called ${loopCount} times in loop`,
        `session:${this.currentSessionId}`, loopCount));
    }

    // Deep check: latency regression vs weekly baseline (disk, throttled)
    await this.maybeDeepCheck(pluginId);
  }

  /**
   * Throttled deep check comparing recent latency against the weekly baseline.
   */
  private async maybeDeepCheck(pluginId: string): Promise<void> {
    const now = Date.now();
    const lastCheck = this.lastDeepCheckAt.get(pluginId) ?? 0;
    if (now - lastCheck < DEEP_CHECK_INTERVAL_MS) return;
    this.lastDeepCheckAt.set(pluginId, now);

    try {
      const dayStats = await this.getStatistics(pluginId, 'last_day');
      const weekStats = await this.getStatistics(pluginId, 'last_week');

      if (weekStats.avg_latency_ms > 0) {
        const latencyIncrease = (dayStats.avg_latency_ms - weekStats.avg_latency_ms) / weekStats.avg_latency_ms;
        if (latencyIncrease > 0.2) {
          this.signalBuffer.push(this.createSignal(
            pluginId, 'strong', 'struggle',
            `Latency increased by ${(latencyIncrease * 100).toFixed(1)}%`,
            `metrics:${pluginId}`));
        }
      }
    } catch (error) {
      console.error('[Monitor] Deep check failed:', error);
    }
  }

  /**
   * Count how many consecutive events at the tail satisfy the predicate.
   */
  private countTrailing(events: PerformanceEvent[], predicate: (e: PerformanceEvent) => boolean): number {
    let count = 0;
    for (let i = events.length - 1; i >= 0; i--) {
      if (predicate(events[i])) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  /**
   * Create a signal with common fields filled in
   */
  private createSignal(
    pluginId: string,
    type: EvolutionSignal['type'],
    category: EvolutionSignal['category'],
    description: string,
    evidence: string,
    count?: number
  ): EvolutionSignal {
    return {
      type,
      category,
      description,
      evidence,
      timestamp: new Date().toISOString(),
      plugin_id: pluginId,
      ...(count !== undefined ? { count } : {})
    };
  }

  /**
   * Detect loops in tool calls
   */
  private detectLoops(events: PerformanceEvent[]): boolean {
    if (events.length < 5) return false;

    // Check for repeated patterns
    const recentCalls = events.slice(-10).map(e =>
      e.event_type === 'tool_call' ? (e.event_data as any).tool : null
    );

    // Simple pattern: same tool called 5+ times within the recent window
    const toolCounts: Record<string, number> = {};
    for (const tool of recentCalls) {
      if (tool) {
        toolCounts[tool] = (toolCounts[tool] || 0) + 1;
        if (toolCounts[tool] >= 5) {
          return true;
        }
      }
    }

    return false;
  }

  /**
   * Classify error type from error message
   */
  private classifyError(errorMessage: string): string {
    if (errorMessage.includes('timeout')) return 'timeout';
    if (errorMessage.includes('parameter') || errorMessage.includes('param')) return 'parameter_error';
    if (errorMessage.includes('permission') || errorMessage.includes('access')) return 'permission_error';
    if (errorMessage.includes('not found') || errorMessage.includes('does not exist')) return 'not_found';
    return 'runtime_error';
  }

  /**
   * Calculate cutoff time for time range
   */
  private calculateCutoff(now: Date, timeRange: string): Date {
    switch (timeRange) {
      case 'last_hour':
        return new Date(now.getTime() - 60 * 60 * 1000);
      case 'last_day':
        return new Date(now.getTime() - 24 * 60 * 60 * 1000);
      case 'last_week':
        return new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      default:
        return new Date(0); // All time
    }
  }

  /**
   * Append an event to the in-memory session history, capping its size
   */
  private pushSessionEvent(event: PerformanceEvent): void {
    this.sessionEvents.push(event);
    if (this.sessionEvents.length > MAX_SESSION_EVENTS) {
      this.sessionEvents.splice(0, this.sessionEvents.length - MAX_SESSION_EVENTS);
    }
  }

  /**
   * Flush buffers to files
   */
  private async flushBuffers(): Promise<void> {
    if (this.eventBuffer.length > 0) {
      await this.metricsStore.appendMany(this.eventBuffer);
      this.eventBuffer = [];
    }

    if (this.signalBuffer.length > 0) {
      await this.signalsStore.appendMany(this.signalBuffer);
      this.signalBuffer = [];
    }
  }

  /**
   * Generate session ID
   */
  private generateSessionId(): string {
    return `sess_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 11)}`;
  }
}
