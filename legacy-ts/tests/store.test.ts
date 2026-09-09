import { JsonlStore, ProposalStore, expandPath } from '../src/store/index';
import { EvolutionProposal } from '../src/types/index';
import * as fs from 'fs-extra';
import * as os from 'os';
import * as path from 'path';

describe('expandPath', () => {
  it('should expand ~/ to the home directory', () => {
    const expanded = expandPath('~/foo/bar');
    expect(expanded).not.toContain('~');
    expect(expanded).toContain('foo');
    expect(expanded).toContain('bar');
  });

  it('should expand ~\\ to the home directory on Windows', () => {
    const expanded = expandPath('~\\foo\\bar');
    expect(expanded).not.toContain('~');
  });

  it('should leave absolute paths unchanged', () => {
    const abs = path.resolve('/tmp/test');
    expect(expandPath(abs)).toBe(abs);
  });

  it('should expand bare ~', () => {
    const expanded = expandPath('~');
    expect(expanded).not.toContain('~');
  });
});

describe('JsonlStore', () => {
  let tmpDir: string;
  let filePath: string;
  let store: JsonlStore<{ name: string; value: number }>;

  beforeEach(async () => {
    tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'evo-store-'));
    filePath = path.join(tmpDir, 'test.jsonl');
    store = new JsonlStore(filePath);
  });

  afterEach(async () => {
    await fs.remove(tmpDir);
  });

  describe('load', () => {
    it('should return an empty array for a non-existent file', async () => {
      const items = await store.load();
      expect(items).toEqual([]);
    });

    it('should load items from a JSONL file', async () => {
      await fs.writeFile(filePath, '{"name":"a","value":1}\n{"name":"b","value":2}\n', 'utf-8');
      const items = await store.load();
      expect(items).toHaveLength(2);
      expect(items[0]).toEqual({ name: 'a', value: 1 });
    });

    it('should skip corrupt lines gracefully', async () => {
      await fs.writeFile(filePath, '{"name":"a","value":1}\nCORRUPT\n{"name":"b","value":2}\n', 'utf-8');
      const items = await store.load();
      expect(items).toHaveLength(2);
    });

    it('should skip empty lines', async () => {
      await fs.writeFile(filePath, '{"name":"a","value":1}\n\n\n{"name":"b","value":2}\n', 'utf-8');
      const items = await store.load();
      expect(items).toHaveLength(2);
    });
  });

  describe('append', () => {
    it('should create the directory if it does not exist', async () => {
      const nestedPath = path.join(tmpDir, 'sub', 'dir', 'test.jsonl');
      const nestedStore = new JsonlStore(nestedPath);
      await nestedStore.append({ name: 'a', value: 1 });

      expect(await fs.pathExists(nestedPath)).toBe(true);
      const items = await nestedStore.load();
      expect(items).toHaveLength(1);
    });

    it('should append items to an existing file', async () => {
      await store.append({ name: 'a', value: 1 });
      await store.append({ name: 'b', value: 2 });

      const items = await store.load();
      expect(items).toHaveLength(2);
    });
  });

  describe('appendMany', () => {
    it('should append multiple items at once', async () => {
      await store.appendMany([
        { name: 'a', value: 1 },
        { name: 'b', value: 2 },
        { name: 'c', value: 3 }
      ]);

      const items = await store.load();
      expect(items).toHaveLength(3);
    });

    it('should do nothing for an empty array', async () => {
      await store.appendMany([]);
      expect(await fs.pathExists(filePath)).toBe(false);
    });
  });

  describe('rewrite', () => {
    it('should replace all content', async () => {
      await store.append({ name: 'a', value: 1 });
      await store.rewrite([{ name: 'b', value: 2 }]);

      const items = await store.load();
      expect(items).toHaveLength(1);
      expect(items[0].name).toBe('b');
    });

    it('should write an empty file for an empty array', async () => {
      await store.append({ name: 'a', value: 1 });
      await store.rewrite([]);

      const content = await fs.readFile(filePath, 'utf-8');
      expect(content).toBe('');
    });
  });

  describe('update', () => {
    it('should update matching items and return the count', async () => {
      await store.appendMany([
        { name: 'a', value: 1 },
        { name: 'b', value: 2 },
        { name: 'c', value: 3 }
      ]);

      const changed = await store.update(
        item => item.name === 'b',
        item => ({ ...item, value: 99 })
      );

      expect(changed).toBe(1);
      const items = await store.load();
      expect(items[1].value).toBe(99);
    });

    it('should return 0 when nothing matches', async () => {
      await store.append({ name: 'a', value: 1 });
      const changed = await store.update(
        item => item.name === 'z',
        item => item
      );
      expect(changed).toBe(0);
    });

    it('should not rewrite the file when nothing changed', async () => {
      await store.append({ name: 'a', value: 1 });
      const stat1 = await fs.stat(filePath);

      await store.update(item => item.name === 'z', item => item);

      const stat2 = await fs.stat(filePath);
      expect(stat2.mtimeMs).toBe(stat1.mtimeMs);
    });
  });
});

describe('ProposalStore', () => {
  let tmpDir: string;
  let proposals: ProposalStore;

  function makeProposal(overrides: Partial<EvolutionProposal> = {}): EvolutionProposal {
    return {
      proposal_id: 'evo-test-1',
      plugin_id: 'test-plugin-1.0.0',
      status: 'pending',
      created_at: new Date().toISOString(),
      trigger_signals: [],
      evolution_type: 'documentation_enhancement',
      matt_pocock_principle: '词汇即文档',
      proposed_changes: {},
      expected_benefits: {},
      validation_plan: {
        test_scenarios: [],
        success_criteria: '',
        rollback_strategy: '',
        validation_levels: []
      },
      risk_assessment: {
        breaking_changes: false,
        backward_compatible: true,
        migration_effort: 'low',
        affected_users: 0,
        rollback_complexity: 'simple'
      },
      signature: 'test-sig',
      confidence: 'medium',
      ...overrides
    };
  }

  beforeEach(async () => {
    tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'evo-prop-'));
    proposals = new ProposalStore(path.join(tmpDir, 'proposals.jsonl'));
  });

  afterEach(async () => {
    await fs.remove(tmpDir);
  });

  describe('save and find', () => {
    it('should save and retrieve a proposal', async () => {
      await proposals.save(makeProposal());
      const found = await proposals.find('evo-test-1');
      expect(found).not.toBeNull();
      expect(found?.proposal_id).toBe('evo-test-1');
    });

    it('should return null for a non-existent proposal', async () => {
      const found = await proposals.find('does-not-exist');
      expect(found).toBeNull();
    });
  });

  describe('list', () => {
    it('should list all proposals', async () => {
      await proposals.save(makeProposal({ proposal_id: 'evo-1' }));
      await proposals.save(makeProposal({ proposal_id: 'evo-2' }));

      const all = await proposals.list();
      expect(all).toHaveLength(2);
    });

    it('should filter by status', async () => {
      await proposals.save(makeProposal({ proposal_id: 'evo-1', status: 'pending' }));
      await proposals.save(makeProposal({ proposal_id: 'evo-2', status: 'completed' }));

      const pending = await proposals.list({ status: 'pending' });
      expect(pending).toHaveLength(1);
      expect(pending[0].proposal_id).toBe('evo-1');
    });

    it('should filter by plugin_id', async () => {
      await proposals.save(makeProposal({ proposal_id: 'evo-1', plugin_id: 'plugin-a' }));
      await proposals.save(makeProposal({ proposal_id: 'evo-2', plugin_id: 'plugin-b' }));

      const filtered = await proposals.list({ plugin_id: 'plugin-a' });
      expect(filtered).toHaveLength(1);
    });

    it('should respect the limit parameter', async () => {
      await proposals.save(makeProposal({ proposal_id: 'evo-1' }));
      await proposals.save(makeProposal({ proposal_id: 'evo-2' }));
      await proposals.save(makeProposal({ proposal_id: 'evo-3' }));

      const limited = await proposals.list({ limit: 2 });
      expect(limited).toHaveLength(2);
    });
  });

  describe('setStatus', () => {
    it('should allow legal transitions', async () => {
      await proposals.save(makeProposal({ status: 'pending' }));

      expect(await proposals.setStatus('evo-test-1', 'approved')).toBe(true);
      expect(await proposals.setStatus('evo-test-1', 'executing')).toBe(true);
      expect(await proposals.setStatus('evo-test-1', 'completed')).toBe(true);

      const stored = await proposals.find('evo-test-1');
      expect(stored?.status).toBe('completed');
    });

    it('should throw on illegal transitions', async () => {
      await proposals.save(makeProposal({ status: 'completed' }));
      await expect(proposals.setStatus('evo-test-1', 'approved'))
        .rejects.toThrow('Illegal proposal status transition');
    });

    it('should be idempotent for same-status updates', async () => {
      await proposals.save(makeProposal({ status: 'pending' }));
      expect(await proposals.setStatus('evo-test-1', 'pending')).toBe(true);
    });

    it('should return false for non-existent proposals', async () => {
      expect(await proposals.setStatus('does-not-exist', 'approved')).toBe(false);
    });

    it('should allow pending → rejected', async () => {
      await proposals.save(makeProposal({ status: 'pending' }));
      expect(await proposals.setStatus('evo-test-1', 'rejected')).toBe(true);
      expect((await proposals.find('evo-test-1'))?.status).toBe('rejected');
    });

    it('should allow executing → pending (rollback)', async () => {
      await proposals.save(makeProposal({ status: 'pending' }));
      await proposals.setStatus('evo-test-1', 'approved');
      await proposals.setStatus('evo-test-1', 'executing');
      expect(await proposals.setStatus('evo-test-1', 'pending')).toBe(true);
    });
  });

  describe('findPendingForPlugin', () => {
    it('should find the first pending proposal for a plugin', async () => {
      await proposals.save(makeProposal({ proposal_id: 'evo-1', plugin_id: 'p-1', status: 'pending' }));
      await proposals.save(makeProposal({ proposal_id: 'evo-2', plugin_id: 'p-1', status: 'completed' }));

      const found = await proposals.findPendingForPlugin('p-1');
      expect(found?.proposal_id).toBe('evo-1');
    });

    it('should return null when no pending proposal exists', async () => {
      await proposals.save(makeProposal({ status: 'completed' }));
      const found = await proposals.findPendingForPlugin('test-plugin-1.0.0');
      expect(found).toBeNull();
    });
  });

  describe('findDuplicate', () => {
    it('should find a non-rejected proposal with the same signature', async () => {
      await proposals.save(makeProposal({ signature: 'dup-sig', status: 'pending' }));
      const found = await proposals.findDuplicate('dup-sig');
      expect(found).not.toBeNull();
    });

    it('should not find a rejected proposal', async () => {
      await proposals.save(makeProposal({ signature: 'dup-sig', status: 'rejected' }));
      const found = await proposals.findDuplicate('dup-sig');
      expect(found).toBeNull();
    });
  });

  describe('recentForPlugin', () => {
    it('should find proposals within the cooldown window', async () => {
      await proposals.save(makeProposal({ plugin_id: 'p-1' }));
      const recent = await proposals.recentForPlugin('p-1', 3600000);
      expect(recent).toHaveLength(1);
    });

    it('should not find proposals outside the cooldown window', async () => {
      const oldDate = new Date(Date.now() - 48 * 60 * 60 * 1000).toISOString();
      await proposals.save(makeProposal({ plugin_id: 'p-1', created_at: oldDate }));
      const recent = await proposals.recentForPlugin('p-1', 3600000);
      expect(recent).toHaveLength(0);
    });
  });
});
