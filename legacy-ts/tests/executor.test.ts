import { UpgradeExecutor } from '../src/executor/index';
import { ProposalStore } from '../src/store/index';
import { EvolutionProposal } from '../src/types/index';
import * as fs from 'fs-extra';
import * as os from 'os';
import * as path from 'path';

describe('UpgradeExecutor', () => {
  let tmpDir: string;
  let proposals: ProposalStore;
  let executor: UpgradeExecutor;

  function makeProposal(overrides: Partial<EvolutionProposal> = {}): EvolutionProposal {
    return {
      proposal_id: 'evo-test-1',
      plugin_id: 'test-plugin-1.0.0',
      status: 'approved',
      created_at: new Date().toISOString(),
      trigger_signals: [],
      evolution_type: 'interface_simplification',
      matt_pocock_principle: 'Deep Module > 浅模块',
      proposed_changes: {
        merge_tools: [
          {
            new_tool: 'smart_fill',
            merged_from: ['navigate', 'click', 'type'],
            new_interface: {
              params: ['url', 'selector', 'text'],
              description: 'One-stop form filling'
            },
            backward_compatible: true
          }
        ]
      },
      expected_benefits: {
        latency_improvement: '30-40%'
      },
      validation_plan: {
        test_scenarios: ['form filling'],
        success_criteria: 'success_rate >= 95%',
        rollback_strategy: 'keep previous version 30 days',
        validation_levels: [
          { level: 'T0', description: 'Syntax', automated: true },
          { level: 'T1', description: 'Functionality', automated: true },
          { level: 'T2', description: 'Regression', automated: true }
        ]
      },
      risk_assessment: {
        breaking_changes: false,
        backward_compatible: true,
        migration_effort: 'low',
        affected_users: 0,
        rollback_complexity: 'simple'
      },
      signature: 'test-plugin-interface-simplification',
      confidence: 'medium',
      ...overrides
    };
  }

  beforeEach(async () => {
    tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'evo-exec-'));
    proposals = new ProposalStore(path.join(tmpDir, 'proposals.jsonl'));
    executor = new UpgradeExecutor(
      proposals,
      path.join(tmpDir, 'execution.log')
    );
  });

  afterEach(async () => {
    await fs.remove(tmpDir);
  });

  describe('execute', () => {
    it('should fail when the proposal does not exist', async () => {
      const result = await executor.execute('does-not-exist');

      expect(result.success).toBe(false);
      expect(result.error).toContain('not found');
    });

    it('should fail when the proposal is already completed', async () => {
      await proposals.save(makeProposal({ status: 'completed' }));

      const result = await executor.execute('evo-test-1');

      expect(result.success).toBe(false);
      expect(result.error).toContain('completed');
    });

    it('should fail when the proposal is rejected', async () => {
      await proposals.save(makeProposal({ status: 'rejected' }));

      const result = await executor.execute('evo-test-1');

      expect(result.success).toBe(false);
      expect(result.error).toContain('rejected');
    });

    it('should complete a dry run over an approved proposal', async () => {
      await proposals.save(makeProposal());

      const result = await executor.execute('evo-test-1', true);

      expect(result.success).toBe(true);
      expect(result.error).toBeUndefined();
      // code-generator + test-writer + integration + validation results
      expect(result.results.length).toBeGreaterThan(0);
      expect(result.results.some(r => r.agent === 'code-generator')).toBe(true);
    });

    it('should mark the proposal completed after a successful run', async () => {
      await proposals.save(makeProposal());

      await executor.execute('evo-test-1', true);

      const stored = await proposals.find('evo-test-1');
      expect(stored?.status).toBe('completed');
    });

    it('should reset the proposal to pending when dry run is not requested and a task fails', async () => {
      // Non-dry-run path uses simulated sub-agents that always succeed,
      // so exercise the failure branch via a proposal whose validation
      // levels contain an unknown level name (T9) making validation fail.
      await proposals.save(makeProposal({
        proposal_id: 'evo-test-fail',
        validation_plan: {
          test_scenarios: [],
          success_criteria: '',
          rollback_strategy: '',
          validation_levels: [
            { level: 'T9' as any, description: 'unknown', automated: true }
          ]
        }
      }));

      const result = await executor.execute('evo-test-fail', false);

      expect(result.success).toBe(false);
      const stored = await proposals.find('evo-test-fail');
      expect(stored?.status).toBe('pending');
    });

    it('should reject executing a pending proposal (state machine)', async () => {
      await proposals.save(makeProposal({ status: 'pending' }));

      const result = await executor.execute('evo-test-1');

      expect(result.success).toBe(false);
      expect(result.error).toContain("expected 'approved'");
    });
  });

  describe('ProposalStore state machine', () => {
    it('should allow legal transitions pending → approved → executing → completed', async () => {
      await proposals.save(makeProposal({ status: 'pending' }));

      expect(await proposals.setStatus('evo-test-1', 'approved')).toBe(true);
      expect(await proposals.setStatus('evo-test-1', 'executing')).toBe(true);
      expect(await proposals.setStatus('evo-test-1', 'completed')).toBe(true);

      const stored = await proposals.find('evo-test-1');
      expect(stored?.status).toBe('completed');
    });

    it('should throw on illegal transitions like completed → approved', async () => {
      await proposals.save(makeProposal({ status: 'completed' }));

      await expect(proposals.setStatus('evo-test-1', 'approved'))
        .rejects.toThrow('Illegal proposal status transition: completed → approved');
    });

    it('should be idempotent for same-status updates', async () => {
      await proposals.save(makeProposal({ status: 'pending' }));

      expect(await proposals.setStatus('evo-test-1', 'pending')).toBe(true);
      expect((await proposals.find('evo-test-1'))?.status).toBe('pending');
    });
  });
});
