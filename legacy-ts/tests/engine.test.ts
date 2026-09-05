import { EvolutionEngine } from '../src/engine/index';
import { ProposalStore, JsonlStore } from '../src/store/index';
import { PerformanceMonitor } from '../src/monitor/index';
import { EvolutionSignal, PluginMetadata } from '../src/types/index';
import * as fs from 'fs-extra';
import * as os from 'os';
import * as path from 'path';

describe('EvolutionEngine', () => {
  let tmpDir: string;
  let proposals: ProposalStore;
  let engine: EvolutionEngine;

  const mockPlugin: PluginMetadata = {
    plugin_id: 'test-plugin-1.0.0',
    name: 'test-plugin',
    version: '1.0.0',
    type: 'community',
    capabilities: ['navigate', 'click', 'type'],
    tools: ['navigate', 'click', 'type'],
    events: [],
    dependencies: [],
    scan_timestamp: new Date().toISOString(),
    path: '/mock/path',
    initial_metrics: {
      complexity_score: 7.5,
      interface_clarity: 6.0,
      documentation_quality: 7.0
    }
  };

  const strongCorrectionSignal: EvolutionSignal = {
    type: 'strong',
    category: 'correction',
    description: 'User correction: use parameter X instead of Y',
    evidence: 'session:test',
    timestamp: new Date().toISOString(),
    plugin_id: 'test-plugin-1.0.0'
  };

  beforeEach(async () => {
    tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'evo-engine-'));
    proposals = new ProposalStore(path.join(tmpDir, 'proposals.jsonl'));
    engine = new EvolutionEngine(
      new PerformanceMonitor(
        path.join(tmpDir, 'metrics.jsonl'),
        path.join(tmpDir, 'signals.jsonl')
      ),
      proposals,
      { intensity: '50%', cooldownHours: 24 },
      new JsonlStore<EvolutionSignal>(path.join(tmpDir, 'signals.jsonl'))
    );
  });

  afterEach(async () => {
    await fs.remove(tmpDir);
  });

  describe('generateProposal', () => {
    it('should generate an error_handling proposal from a strong correction signal', async () => {
      const proposal = await engine.generateProposal(
        mockPlugin.plugin_id,
        mockPlugin,
        [strongCorrectionSignal]
      );

      expect(proposal).not.toBeNull();
      expect(proposal?.evolution_type).toBe('error_handling_improvement');
      expect(proposal?.trigger_signals).toHaveLength(1);
      expect(proposal?.matt_pocock_principle).toBe('紧反馈环 > 盲目试错');
      expect(proposal?.status).toBe('pending');
    });

    it('should persist the proposal via the shared ProposalStore', async () => {
      const proposal = await engine.generateProposal(
        mockPlugin.plugin_id,
        mockPlugin,
        [strongCorrectionSignal]
      );

      const loaded = await proposals.find(proposal!.proposal_id);
      expect(loaded).not.toBeNull();
      expect(loaded?.plugin_id).toBe(mockPlugin.plugin_id);
    });

    it('should ignore medium-only signals at 50% intensity', async () => {
      const mediumSignal: EvolutionSignal = {
        type: 'medium',
        category: 'preference',
        description: 'User preference: verbose output',
        evidence: 'session:test',
        timestamp: new Date().toISOString(),
        plugin_id: 'test-plugin-1.0.0'
      };

      const proposal = await engine.generateProposal(
        mockPlugin.plugin_id,
        mockPlugin,
        [mediumSignal]
      );

      expect(proposal).toBeNull();
    });

    it('should ignore weak-only signals', async () => {
      const weakSignal: EvolutionSignal = {
        type: 'weak',
        category: 'pattern',
        description: 'Minor performance fluctuation',
        evidence: 'session:test',
        timestamp: new Date().toISOString(),
        plugin_id: 'test-plugin-1.0.0'
      };

      const proposal = await engine.generateProposal(
        mockPlugin.plugin_id,
        mockPlugin,
        [weakSignal]
      );

      expect(proposal).toBeNull();
    });

    it('should return the existing pending proposal instead of duplicating', async () => {
      const first = await engine.generateProposal(
        mockPlugin.plugin_id,
        mockPlugin,
        [strongCorrectionSignal]
      );
      const second = await engine.generateProposal(
        mockPlugin.plugin_id,
        mockPlugin,
        [strongCorrectionSignal]
      );

      expect(second).not.toBeNull();
      expect(second?.proposal_id).toBe(first?.proposal_id);
    });

    it('should stay silent during cooldown after a recent proposal', async () => {
      // Simulate a recent proposal already on disk (pending check bypassed by
      // using a completed status so the cooldown branch is what fires)
      await proposals.save({
        proposal_id: 'evo-2026-09-04-prior',
        plugin_id: mockPlugin.plugin_id,
        status: 'completed',
        created_at: new Date().toISOString(),
        trigger_signals: [strongCorrectionSignal],
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
        signature: 'prior-signature',
        confidence: 'medium'
      });

      const proposal = await engine.generateProposal(
        mockPlugin.plugin_id,
        mockPlugin,
        [strongCorrectionSignal]
      );

      expect(proposal).toBeNull();
    });

    it('should allow a new proposal once the cooldown has elapsed', async () => {
      const oldDate = new Date(Date.now() - 25 * 60 * 60 * 1000).toISOString();
      await proposals.save({
        proposal_id: 'evo-2026-09-03-prior',
        plugin_id: mockPlugin.plugin_id,
        status: 'completed',
        created_at: oldDate,
        trigger_signals: [strongCorrectionSignal],
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
        signature: 'prior-signature',
        confidence: 'medium'
      });

      const proposal = await engine.generateProposal(
        mockPlugin.plugin_id,
        mockPlugin,
        [strongCorrectionSignal]
      );

      expect(proposal).not.toBeNull();
    });

    it('should produce no proposal when there are no signals', async () => {
      const proposal = await engine.generateProposal(mockPlugin.plugin_id, mockPlugin, []);
      expect(proposal).toBeNull();
    });

    it('should disable generation entirely at 0% intensity', async () => {
      const disabledEngine = new EvolutionEngine(
        new PerformanceMonitor(
          path.join(tmpDir, 'm.jsonl'),
          path.join(tmpDir, 's.jsonl')
        ),
        proposals,
        { intensity: '0%' },
        new JsonlStore<EvolutionSignal>(path.join(tmpDir, 's.jsonl'))
      );

      const proposal = await disabledEngine.generateProposal(
        mockPlugin.plugin_id,
        mockPlugin,
        [strongCorrectionSignal]
      );

      expect(proposal).toBeNull();
    });
  });

  describe('signal-to-evolution-type mapping', () => {
    it('should map a struggle signal with high complexity to interface_simplification', async () => {
      const struggleSignal: EvolutionSignal = {
        type: 'strong',
        category: 'struggle',
        description: '3 consecutive failures detected',
        evidence: 'session:test',
        timestamp: new Date().toISOString(),
        plugin_id: mockPlugin.plugin_id
      };

      const proposal = await engine.generateProposal(
        mockPlugin.plugin_id,
        mockPlugin,
        [struggleSignal]
      );

      expect(proposal?.evolution_type).toBe('interface_simplification');
      expect(proposal?.matt_pocock_principle).toBe('Deep Module > 浅模块');
    });

    it('should map a loop signal to behavior_optimization with middleware proposal', async () => {
      const loopSignal: EvolutionSignal = {
        type: 'medium',
        category: 'loop',
        description: 'Tool navigate called 5 times in loop',
        evidence: 'session:test',
        timestamp: new Date().toISOString(),
        plugin_id: mockPlugin.plugin_id
      };

      // 100% intensity so the medium signal alone is enough
      const fullEngine = new EvolutionEngine(
        new PerformanceMonitor(
          path.join(tmpDir, 'm2.jsonl'),
          path.join(tmpDir, 's2.jsonl')
        ),
        proposals,
        { intensity: '100%' },
        new JsonlStore<EvolutionSignal>(path.join(tmpDir, 's2.jsonl'))
      );

      const proposal = await fullEngine.generateProposal(
        mockPlugin.plugin_id,
        mockPlugin,
        [loopSignal]
      );

      expect(proposal?.evolution_type).toBe('behavior_optimization');
      expect(proposal?.proposed_changes.add_middleware?.length).toBeGreaterThan(0);
    });

    it('should assign high confidence when two strong signals are present', async () => {
      const struggleSignal: EvolutionSignal = {
        type: 'strong',
        category: 'struggle',
        description: '3 consecutive failures',
        evidence: 'session:test',
        timestamp: new Date().toISOString(),
        plugin_id: mockPlugin.plugin_id
      };

      const proposal = await engine.generateProposal(
        mockPlugin.plugin_id,
        mockPlugin,
        [strongCorrectionSignal, struggleSignal]
      );

      expect(proposal?.confidence).toBe('high');
    });
  });
});
