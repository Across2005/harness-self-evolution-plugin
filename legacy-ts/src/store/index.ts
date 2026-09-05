/**
 * Shared storage layer — the single deep module for all JSONL persistence.
 *
 * 所有模块（engine / executor / monitor / server）通过此层读写数据文件，
 * 文件 I/O、容错解析、路径展开的细节只存在这一份实现。
 */

import * as fs from 'fs-extra';
import * as path from 'path';
import { EvolutionProposal } from '../types';

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
