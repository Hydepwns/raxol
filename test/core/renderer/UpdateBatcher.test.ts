import { UpdateBatcher } from '../../../src/core/renderer/UpdateBatcher';
import { ViewPerformance } from '../../../src/core/performance/ViewPerformance';

describe('UpdateBatcher', () => {
  let batcher: UpdateBatcher;
  let performance: ViewPerformance;

  beforeEach(() => {
    performance = ViewPerformance.getInstance();
    performance.startMonitoring();
    batcher = new UpdateBatcher(50, 10);
  });

  afterEach(() => {
    performance.stopMonitoring();
    jest.clearAllMocks();
  });

  describe('Basic Functionality', () => {
    it('should queue updates correctly', () => {
      const update = { id: 'test', type: 'box', props: { x: 0, y: 0 } };
      batcher.queueUpdate(update);
      expect(batcher.getPendingUpdateCount()).toBe(1);
    });

    it('should merge updates for the same component', () => {
      const update1 = { id: 'test', type: 'box', props: { x: 0, y: 0 } };
      const update2 = { id: 'test', type: 'box', props: { x: 1, y: 1 } };
      batcher.queueUpdate(update1);
      batcher.queueUpdate(update2);
      expect(batcher.getPendingUpdateCount()).toBe(1);
    });

    it('should apply updates when scheduled', async () => {
      const update = { id: 'test', type: 'box', props: { x: 0, y: 0 } };
      batcher.queueUpdate(update);
      await new Promise(resolve => setTimeout(resolve, 0));
      expect(batcher.getPendingUpdateCount()).toBe(0);
    });

    it('should clear pending updates', () => {
      const update = { id: 'test', type: 'box', props: { x: 0, y: 0 } };
      batcher.queueUpdate(update);
      batcher.clearPendingUpdates();
      expect(batcher.getPendingUpdateCount()).toBe(0);
    });
  });

  describe('Performance Integration', () => {
    it('should record component update metrics', async () => {
      const update = { id: 'test', type: 'box', props: { x: 0, y: 0 } };
      batcher.queueUpdate(update);
      await new Promise(resolve => setTimeout(resolve, 0));
      const metrics = performance.getComponentMetrics('box');
      expect(metrics).toBeDefined();
      expect(metrics?.updateCount).toBeGreaterThan(0);
    });

    it('should record batch rendering metrics', async () => {
      const updates = Array(5).fill(null).map((_, i) => ({
        id: `test${i}`,
        type: 'box',
        props: { x: i, y: i }
      }));
      updates.forEach(update => batcher.queueUpdate(update));
      await new Promise(resolve => setTimeout(resolve, 0));
      const metrics = performance.getMetrics();
      expect(metrics.rendering.batchCount).toBeGreaterThan(0);
      expect(metrics.rendering.totalUpdates).toBeGreaterThan(0);
    });

    it('should adapt batch size based on performance', async () => {
      const updates = Array(100).fill(null).map((_, i) => ({
        id: `test${i}`,
        type: 'box',
        props: { x: i, y: i }
      }));
      updates.forEach(update => batcher.queueUpdate(update));
      await new Promise(resolve => setTimeout(resolve, 0));
      const metrics = performance.getMetrics();
      expect(metrics.rendering.adaptiveBatchSize).toBeDefined();
    });
  });
}); 