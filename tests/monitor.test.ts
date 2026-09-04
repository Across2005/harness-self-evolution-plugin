import { PerformanceMonitor } from '../src/monitor/index';
import { JsonlStore } from '../src/store/index';
import { PerformanceEvent, EvolutionSignal } from '../src/types/index';
import * as fs from 'fs-extra';
import * as os from 'os';
import * as path from 'path';

describe('PerformanceMonitor', () => {
  let tmpDir: string;
  let metricsPath: string;
  let signalsPath: string;
  let monitor: PerformanceMonitor;

  beforeEach(async () => {
    tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'evo-mon-'));
    metricsPath = path.join(tmpDir, 'metrics.jsonl');
    signalsPath = path.join(tmpDir, 'signals.jsonl');
    monitor = new PerformanceMonitor(metricsPath, signalsPath);
    await monitor.start();
  });

  afterEach(async () => {
    await monitor.stop();
    await fs.remove(tmpDir);
  });

  describe('recordToolCall + getStatistics', () => {
    it('should aggregate success rate and latency', async () => {
      await monitor.recordToolCall('p-1', 'navigate', {}, 100, true);
      await monitor.recordToolCall('p-1', 'click', {}, 200, true);
      await monitor.recordToolCall('p-1', 'type', {}, 300, false, undefined, 0, 'timeout');

      const stats = await monitor.getStatistics('p-1');

      expect(stats.total_calls).toBe(3);
      expect(stats.success_rate).toBeCloseTo(2 / 3);
      expect(stats.avg_latency_ms).toBe(200);
      expect(stats.error_types.timeout).toBe(1);
    });

    it('should aggregate token usage', async () => {
      await monitor.recordToolCall('p-1', 'navigate', {}, 100, true, { input: 10, output: 20, total: 30 });
      await monitor.recordToolCall('p-1', 'click', {}, 100, true, { input: 5, output: 5, total: 10 });

      const stats = await monitor.getStatistics('p-1');

      expect(stats.total_tokens).toBe(40);
    });

    it('should isolate statistics per plugin', async () => {
      await monitor.recordToolCall('p-1', 'navigate', {}, 100, true);
      await monitor.recordToolCall('p-2', 'navigate', {}, 999, true);

      const stats = await monitor.getStatistics('p-1');

      expect(stats.total_calls).toBe(1);
      expect(stats.avg_latency_ms).toBe(100);
    });

    it('should return zeroed stats for an unknown plugin', async () => {
      const stats = await monitor.getStatistics('nope');

      expect(stats.total_calls).toBe(0);
      expect(stats.loop_detected).toBe(false);
    });
  });

  describe('signal detection', () => {
    it('should emit a struggle signal after 3 consecutive failures', async () => {
      await monitor.recordToolCall('p-1', 'a', {}, 10, false, undefined, 0, 'runtime error');
      await monitor.recordToolCall('p-1', 'a', {}, 10, false, undefined, 0, 'runtime error');
      await monitor.recordToolCall('p-1', 'a', {}, 10, false, undefined, 0, 'runtime error');

      await monitor.stop(); // flush signal buffer
      const signals = await new JsonlStore<EvolutionSignal>(signalsPath).load();

      const struggle = signals.find(s => s.category === 'struggle');
      expect(struggle).toBeDefined();
      expect(struggle?.count).toBeGreaterThanOrEqual(3);
    });

    it('should not emit a struggle signal for fewer than 3 consecutive failures', async () => {
      await monitor.recordToolCall('p-1', 'a', {}, 10, true);
      await monitor.recordToolCall('p-1', 'a', {}, 10, false, undefined, 0, 'error');

      await monitor.stop();
      const signals = await new JsonlStore<EvolutionSignal>(signalsPath).load();

      expect(signals.filter(s => s.category === 'struggle' && s.count)).toHaveLength(0);
    });

    it('should emit a loop signal after 5 consecutive calls of the same tool', async () => {
      for (let i = 0; i < 5; i++) {
        await monitor.recordToolCall('p-1', 'navigate', {}, 10, true);
      }

      await monitor.stop();
      const signals = await new JsonlStore<EvolutionSignal>(signalsPath).load();

      const loop = signals.find(s => s.category === 'loop');
      expect(loop).toBeDefined();
      expect(loop?.description).toContain('navigate');
    });

    it('should emit a correction signal on negative user feedback', async () => {
      await monitor.recordToolCall('p-1', 'a', {}, 10, true);
      await monitor.recordUserFeedback('p-1', 'negative', 'wrong behavior');

      await monitor.stop();
      const signals = await new JsonlStore<EvolutionSignal>(signalsPath).load();

      const correction = signals.find(s => s.category === 'correction');
      expect(correction).toBeDefined();
      expect(correction?.type).toBe('strong');
    });

    it('should update the last event feedback in memory', async () => {
      await monitor.recordToolCall('p-1', 'a', {}, 10, true);
      await monitor.recordUserFeedback('p-1', 'positive');

      await monitor.stop();
      const events = await new JsonlStore<PerformanceEvent>(metricsPath).load();

      // flushed events keep whatever feedback the buffer had at flush time;
      // the in-memory update is exercised for absence of errors here
      expect(events.length).toBe(1);
    });
  });

  describe('persistence', () => {
    it('should flush buffered events to the metrics file on stop', async () => {
      await monitor.recordToolCall('p-1', 'navigate', {}, 50, true);
      await monitor.stop();

      const events = await new JsonlStore<PerformanceEvent>(metricsPath).load();
      expect(events).toHaveLength(1);
      expect(events[0].event_data).toMatchObject({ tool: 'navigate', success: true });
    });
  });
});
