/**
 * Shared storage layer — the single deep module for all JSONL persistence.
 *
 * 所有模块（engine / executor / monitor / server）通过此层读写数据文件，
 * 文件 I/O、容错解析、路径展开的细节只存在这一份实现。
 */

import * as fs from 'fs-extra';
import * as path from 'path';
import { 
  EvolutionProposal, 
  EvolutionConfig, 
  ConfigValidationResult,
  DEFAULT_CONFIG
} from '../types';

/** Expand `~/` to the user home directory (works on Windows and Unix). */
export function expandPath(filePath: string): string {
  if (filePath === '~' || filePath.startsWith('~/') || filePath.startsWith('~\\')) {
    const home = process.env.HOME || process.env.USERPROFILE || process.cwd();
    return path.join(home, filePath.slice(1).replace(/^[/\\]/, ''));
  }
  return filePath;
}

/**
 * Generic JSONL store: one line = one JSON document.
 * 损坏的行跳过并告警，不让单行错误导致整个数据集不可用。
 */
export class JsonlStore<T> {
  readonly filePath: string;

  constructor(filePath: string) {
    this.filePath = expandPath(filePath);
  }

  async load(): Promise<T[]> {
    if (!(await fs.pathExists(this.filePath))) return [];

    const content = await fs.readFile(this.filePath, 'utf-8');
    const items: T[] = [];

    for (const line of content.split('\n')) {
      const trimmed = line.trim();
      if (!trimmed) continue;
      try {
        items.push(JSON.parse(trimmed));
      } catch {
        console.warn(`[Store] Skipping corrupt line in ${this.filePath}`);
      }
    }

    return items;
  }

  async append(item: T): Promise<void> {
    await fs.ensureDir(path.dirname(this.filePath));
    await fs.appendFile(this.filePath, JSON.stringify(item) + '\n', 'utf-8');
  }

  async appendMany(items: T[]): Promise<void> {
    if (items.length === 0) return;
    await fs.ensureDir(path.dirname(this.filePath));
    const lines = items.map(i => JSON.stringify(i)).join('\n') + '\n';
    await fs.appendFile(this.filePath, lines, 'utf-8');
  }

  async rewrite(items: T[]): Promise<void> {
    await fs.ensureDir(path.dirname(this.filePath));
    const body = items.map(i => JSON.stringify(i)).join('\n');
    await fs.writeFile(this.filePath, body.length > 0 ? body + '\n' : '', 'utf-8');
  }

  /** Replace every item matching the predicate via the updater. Returns how many changed. */
  async update(
    predicate: (item: T) => boolean,
    updater: (item: T) => T
  ): Promise<number> {
    const items = await this.load();
    let changed = 0;
    const next = items.map(item => {
      if (!predicate(item)) return item;
      changed++;
      return updater(item);
    });
    if (changed > 0) await this.rewrite(next);
    return changed;
  }

  /**
   * Trim the JSONL file to fit within maxBytes.
   * Keeps the newest complete lines, at least the newest one even if it exceeds maxBytes.
   */
  async trimTo(maxBytes: number): Promise<void> {
    if (!(await fs.pathExists(this.filePath))) return;

    const stat = await fs.stat(this.filePath);
    if (stat.size <= maxBytes) return;

    const content = await fs.readFile(this.filePath);
    const lines: number[] = [];

    // Find line start positions
    lines.push(0);
    for (let i = 0; i < content.length; i++) {
      if (content[i] === 0x0A) { // \n
        if (i + 1 < content.length) {
          lines.push(i + 1);
        }
      }
    }

    // Find newest lines that fit within maxBytes
    let keptStart = content.length;
    let keptBytes = 0;

    for (let i = lines.length - 1; i >= 0; i--) {
      const lineStart = lines[i];
      const lineEnd = i + 1 < lines.length ? lines[i + 1] : content.length;
      const lineBytes = lineEnd - lineStart;

      // Skip empty lines at the end
      if (lineStart === content.length) continue;
      if (content[lineStart] === 0x0A) continue;

      if (keptBytes + lineBytes > maxBytes && keptStart < content.length) {
        // This line would exceed the limit, stop
        break;
      }

      keptStart = lineStart;
      keptBytes += lineBytes;
    }

    // Ensure at least one line is kept
    if (keptStart >= content.length) {
      // Keep the last non-empty line
      for (let i = lines.length - 1; i >= 0; i--) {
        const lineStart = lines[i];
        if (lineStart < content.length && content[lineStart] !== 0x0A) {
          keptStart = lineStart;
          break;
        }
      }
    }

    const trimmed = content.slice(keptStart);
    await fs.writeFile(this.filePath, trimmed, 'utf-8');
    console.warn(`[Store] Trimmed ${this.filePath}: kept ${trimmed.length} of ${stat.size} bytes`);
  }
}

// ============================================================================
// ProposalStore — 进化提案的唯一事实来源
// ============================================================================

export type ProposalStatus = EvolutionProposal['status'];

export interface ProposalFilter {
  status?: ProposalStatus;
  plugin_id?: string;
  limit?: number;
}

/**
 * engine 写入提案、executor 流转状态、server 查询与审批都走这里，
 * 保证所有组件看到同一份提案数据，状态变更不会互相覆盖。
 */
export class ProposalStore {
  /** CONTEXT.md 状态机的合法迁移表；空数组表示终态 */
  private static legalTransitions: Record<ProposalStatus, ProposalStatus[]> = {
    pending: ['approved', 'rejected'],
    approved: ['executing'],
    executing: ['completed', 'pending'],
    completed: [],
    rejected: []
  };

  private store: JsonlStore<EvolutionProposal>;

  constructor(filePath: string = '~/.harness-evolution/proposals.jsonl') {
    this.store = new JsonlStore<EvolutionProposal>(filePath);
  }

  async list(filter: ProposalFilter = {}): Promise<EvolutionProposal[]> {
    let proposals = await this.store.load();
    if (filter.status) proposals = proposals.filter(p => p.status === filter.status);
    if (filter.plugin_id) proposals = proposals.filter(p => p.plugin_id === filter.plugin_id);
    if (filter.limit !== undefined) proposals = proposals.slice(0, filter.limit);
    return proposals;
  }

  async find(proposalId: string): Promise<EvolutionProposal | null> {
    const proposals = await this.store.load();
    return proposals.find(p => p.proposal_id === proposalId) ?? null;
  }

  async save(proposal: EvolutionProposal): Promise<void> {
    await this.store.append(proposal);
  }

  /**
   * Update proposal status, enforcing the CONTEXT.md state machine.
   * Returns false if the proposal does not exist;
   * throws on an illegal transition (e.g. completed → approved).
   */
  async setStatus(proposalId: string, status: ProposalStatus): Promise<boolean> {
    const current = await this.find(proposalId);
    if (!current) return false;
    if (current.status === status) return true; // idempotent

    const allowed = ProposalStore.legalTransitions[current.status] ?? [];
    if (!allowed.includes(status)) {
      throw new Error(`Illegal proposal status transition: ${current.status} → ${status}`);
    }

    await this.store.update(
      p => p.proposal_id === proposalId,
      p => ({ ...p, status })
    );
    return true;
  }

  async findPendingForPlugin(pluginId: string): Promise<EvolutionProposal | null> {
    const pending = await this.list({ plugin_id: pluginId, status: 'pending' });
    return pending[0] ?? null;
  }

  /** Non-rejected proposal with the same signature (deduplication). */
  async findDuplicate(signature: string): Promise<EvolutionProposal | null> {
    const proposals = await this.store.load();
    return proposals.find(p => p.signature === signature && p.status !== 'rejected') ?? null;
  }

  /** Proposals for a plugin created within the cooldown window. */
  async recentForPlugin(pluginId: string, cooldownMs: number): Promise<EvolutionProposal[]> {
    const proposals = await this.store.load();
    return proposals.filter(
      p => p.plugin_id === pluginId && Date.now() - new Date(p.created_at).getTime() < cooldownMs
    );
  }
}

// ============================================================================
// ConfigStore — 配置管理
// ============================================================================

/**
 * 管理进化配置的读写和验证。
 * 配置缺失或字段非法时回落默认值，绝不让启动失败。
 */
export class ConfigStore {
  private configPath: string;

  constructor(configPath: string = '~/.harness-evolution/config.json') {
    this.configPath = expandPath(configPath);
  }

  /**
   * Load configuration with validation.
   * Missing fields fall back to defaults, invalid values generate warnings.
   */
  async load(): Promise<ConfigValidationResult> {
    if (!(await fs.pathExists(this.pathExists))) {
      return { config: { ...DEFAULT_CONFIG }, warnings: [] };
    }

    try {
      const content = await fs.readFile(this.configPath, 'utf-8');
      const json = JSON.parse(content);
      return this.from_json_checked(json);
    } catch (err) {
      console.warn(`[ConfigStore] Failed to load config: ${err}`);
      return { config: { ...DEFAULT_CONFIG }, warnings: [`Failed to load config: ${err}`] };
    }
  }

  /**
   * Save configuration to file.
   */
  async save(config: EvolutionConfig): Promise<void> {
    await fs.ensureDir(path.dirname(this.configPath));
    await fs.writeFile(this.configPath, JSON.stringify(config, null, 2), 'utf-8');
  }

  /**
   * Validate and normalize configuration from JSON.
   * Returns the validated config and any warnings generated.
   */
  from_json_checked(json: unknown): ConfigValidationResult {
    const warnings: string[] = [];
    const config = { ...DEFAULT_CONFIG };

    if (typeof json !== 'object' || json === null) {
      return { config, warnings: ['Config is not an object, using defaults'] };
    }

    const obj = json as Record<string, unknown>;

    // intensity
    if (typeof obj.intensity === 'string' && ['100%', '50%', '0%'].includes(obj.intensity)) {
      config.intensity = obj.intensity as EvolutionConfig['intensity'];
    } else if (obj.intensity !== undefined) {
      warnings.push(`intensity: invalid value "${obj.intensity}", using default "50%"`);
    }

    // auto_approve — always forced to false
    if (obj.auto_approve === true) {
      warnings.push('auto_approve: true is not allowed, forced to false (human approval required)');
    }
    config.auto_approve = false;

    // max_proposals_per_session
    if (typeof obj.max_proposals_per_session === 'number' && Number.isFinite(obj.max_proposals_per_session)) {
      const val = Math.floor(obj.max_proposals_per_session);
      if (val >= 1 && val <= 100) {
        config.max_proposals_per_session = val;
      } else {
        warnings.push(`max_proposals_per_session: ${val} out of range [1,100], using default`);
      }
    }

    // cooldown_hours
    if (typeof obj.cooldown_hours === 'number' && Number.isFinite(obj.cooldown_hours)) {
      const val = Math.floor(obj.cooldown_hours);
      if (val >= 1 && val <= 87600) {
        config.cooldown_hours = val;
      } else {
        warnings.push(`cooldown_hours: ${val} out of range [1,87600], using default`);
      }
    }

    // max_log_bytes
    if (typeof obj.max_log_bytes === 'number' && Number.isFinite(obj.max_log_bytes)) {
      const val = Math.floor(obj.max_log_bytes);
      if (val >= 1048576 && val <= 2147483648) {
        config.max_log_bytes = val;
      } else {
        warnings.push(`max_log_bytes: ${val} out of range [1MiB, 2GiB], using default 32MiB`);
      }
    }

    // signal_thresholds — accept both flat and nested formats
    if (obj.signal_thresholds && typeof obj.signal_thresholds === 'object') {
      const st = obj.signal_thresholds as Record<string, unknown>;

      // Flat format (preferred)
      if (typeof st.consecutive_failures === 'number' && Number.isFinite(st.consecutive_failures)) {
        const val = Math.floor(st.consecutive_failures);
        if (val >= 1) {
          config.signal_thresholds.consecutive_failures = val;
        } else {
          warnings.push(`signal_thresholds.consecutive_failures: ${val} < 1, using default`);
        }
      }

      if (typeof st.loop_detection === 'number' && Number.isFinite(st.loop_detection)) {
        const val = Math.floor(st.loop_detection);
        if (val >= 2) {
          config.signal_thresholds.loop_detection = val;
        } else {
          warnings.push(`signal_thresholds.loop_detection: ${val} < 2, using default`);
        }
      }

      if (typeof st.latency_regression === 'number' && Number.isFinite(st.latency_regression)) {
        const val = st.latency_regression;
        if (val > 0 && val <= 100) {
          config.signal_thresholds.latency_regression = val;
        } else {
          warnings.push(`signal_thresholds.latency_regression: ${val} out of range (0,100], using default`);
        }
      }

      // Nested format (legacy fallback)
      if (st.strong && typeof st.strong === 'object') {
        const strong = st.strong as Record<string, unknown>;
        if (typeof strong.consecutive_failures === 'number' && Number.isFinite(strong.consecutive_failures)) {
          const val = Math.floor(strong.consecutive_failures);
          if (val >= 1) {
            config.signal_thresholds.consecutive_failures = val;
          }
        }
      }

      if (st.medium && typeof st.medium === 'object') {
        const medium = st.medium as Record<string, unknown>;
        if (typeof medium.loop_detection === 'number' && Number.isFinite(medium.loop_detection)) {
          const val = Math.floor(medium.loop_detection);
          if (val >= 2) {
            config.signal_thresholds.loop_detection = val;
          }
        }
      }
    }

    return { config, warnings };
  }

  /**
   * Reset configuration to defaults.
   */
  async reset(): Promise<void> {
    await this.save({ ...DEFAULT_CONFIG });
  }

  private get pathExists(): string {
    return this.configPath;
  }
}
