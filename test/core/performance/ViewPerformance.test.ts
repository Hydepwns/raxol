import { ViewPerformance, PerformanceMetrics, ComponentMetrics } from '../../../src/core/performance/ViewPerformance';

describe('ViewPerformance', () => {
  let performance: ViewPerformance;

  beforeEach(() => {
    performance = ViewPerformance.getInstance();
    performance.startMonitoring();
  });

  afterEach(() => {
    performance.stopMonitoring();
  });

  describe('Component Metrics', () => {
    it('should record component creation metrics', () => {
      performance.recordComponentCreate('box', 100);
      const metrics = performance.getComponentMetrics('box');
      
      expect(metrics).toBeDefined();
      expect(metrics?.createTime).toBe(100);
    });

    it('should record component render metrics', () => {
      performance.recordComponentCreate('text', 50);
      performance.recordComponentRender('text', 50, 2);
      const metrics = performance.getComponentMetrics('text');
      
      expect(metrics).toBeDefined();
      expect(metrics?.renderTime).toBe(50);
      expect(metrics?.childCount).toBe(2);
    });

    it('should record component update metrics', () => {
      performance.recordComponentCreate('button', 75);
      performance.recordComponentUpdate('button', 25);
      const metrics = performance.getComponentMetrics('button');
      
      expect(metrics).toBeDefined();
      expect(metrics?.updateCount).toBe(1);
    });

    it('should accumulate metrics for the same component type', () => {
      performance.recordComponentCreate('box', 100);
      performance.recordComponentCreate('box', 150);
      const metrics = performance.getComponentMetrics('box');
      
      expect(metrics).toBeDefined();
      expect(metrics?.createTime).toBe(150); // Last value overwrites
    });
  });

  describe('Performance Metrics', () => {
    it('should track overall performance metrics', () => {
      performance.recordComponentCreate('box', 100);
      performance.recordComponentRender('text', 50, 1);
      performance.recordComponentUpdate('button', 75);

      const metrics = performance.getMetrics();
      
      expect(metrics.rendering.componentCreateTime).toBeGreaterThan(0);
      expect(metrics.rendering.renderTime).toBeGreaterThan(0);
      expect(metrics.rendering.updateTime).toBeGreaterThan(0);
    });

    it('should track memory metrics when available', () => {
      const metrics = performance.getMetrics();
      
      if (metrics.memory) {
        expect(metrics.memory.usedJSHeapSize).toBeGreaterThan(0);
        expect(metrics.memory.totalJSHeapSize).toBeGreaterThan(0);
        expect(metrics.memory.jsHeapSizeLimit).toBeGreaterThan(0);
      }
    });

    it('should track timing metrics', () => {
      const metrics = performance.getMetrics();
      
      expect(metrics.timing.navigationStart).toBeGreaterThan(0);
      expect(metrics.timing.domComplete).toBeGreaterThan(0);
      expect(metrics.timing.loadEventEnd).toBeGreaterThan(0);
    });
  });

  describe('Monitoring State', () => {
    it('should not record metrics when monitoring is stopped', () => {
      performance.stopMonitoring();
      performance.recordComponentCreate('box', 100);
      
      const metrics = performance.getComponentMetrics('box');
      expect(metrics).toBeUndefined();
    });

    it('should clear metrics when monitoring is restarted', () => {
      performance.recordComponentCreate('box', 100);
      performance.stopMonitoring();
      performance.startMonitoring();
      
      const metrics = performance.getComponentMetrics('box');
      expect(metrics).toBeUndefined();
    });

    it('should track all component metrics', () => {
      performance.recordComponentCreate('box', 100);
      performance.recordComponentCreate('text', 50);
      performance.recordComponentCreate('button', 75);

      const allMetrics = performance.getAllComponentMetrics();
      
      expect(allMetrics.length).toBe(3);
      expect(allMetrics.some(m => m.type === 'box')).toBe(true);
      expect(allMetrics.some(m => m.type === 'text')).toBe(true);
      expect(allMetrics.some(m => m.type === 'button')).toBe(true);
    });
  });
}); 