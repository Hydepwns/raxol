/**
 * PerformanceRegressionDetector.test.ts
 * 
 * Tests for the PerformanceRegressionDetector class.
 */

import { PerformanceRegressionDetector } from '../PerformanceRegressionDetector';
import { ViewPerformance } from '../../ViewPerformance';
import { AnimationPerformance } from '../../animation/AnimationPerformance';
import { PerformanceMetrics } from '../../ViewPerformance';
import { AnimationPerformanceMetrics } from '../../animation/AnimationPerformance';

// Mock the ViewPerformance and AnimationPerformance classes
jest.mock('../../ViewPerformance');
jest.mock('../../animation/AnimationPerformance');

describe('PerformanceRegressionDetector', () => {
  let detector: PerformanceRegressionDetector;
  let mockViewPerformance: jest.Mocked<ViewPerformance>;
  let mockAnimationPerformance: jest.Mocked<AnimationPerformance>;

  const createMockMetrics = (overrides: Partial<PerformanceMetrics> = {}): PerformanceMetrics => ({
    memory: {
      usedJSHeapSize: 1000000,
      totalJSHeapSize: 2000000,
      jsHeapSizeLimit: 3000000
    },
    timing: {
      navigationStart: 0,
      fetchStart: 100,
      domainLookupStart: 200,
      domainLookupEnd: 300,
      connectStart: 400,
      connectEnd: 500,
      requestStart: 600,
      responseStart: 700,
      responseEnd: 800,
      domLoading: 900,
      domInteractive: 1000,
      domContentLoadedEventStart: 1100,
      domContentLoadedEventEnd: 1200,
      domComplete: 1300,
      loadEventStart: 1400,
      loadEventEnd: 1500
    },
    rendering: {
      componentCreateTime: 10,
      renderTime: 20,
      updateTime: 5,
      layoutTime: 15,
      paintTime: 8
    },
    ...overrides
  });

  const createMockAnimationMetrics = (overrides: Partial<AnimationPerformanceMetrics> = {}): AnimationPerformanceMetrics => ({
    averageFrameRate: 60,
    minFrameRate: 55,
    maxFrameRate: 65,
    frameDropRate: 0.5,
    totalFrames: 1000,
    droppedFrames: 5,
    averageFrameDuration: 16.67,
    frameHistory: [],
    duration: 10000,
    ...overrides
  });

  beforeEach(() => {
    // Reset the singleton instance
    (PerformanceRegressionDetector as any).instance = undefined;

    // Setup mocks
    mockViewPerformance = {
      getInstance: jest.fn().mockReturnThis(),
      getMetrics: jest.fn().mockReturnValue(createMockMetrics())
    } as any;

    mockAnimationPerformance = {
      getInstance: jest.fn().mockReturnThis(),
      getMetrics: jest.fn().mockReturnValue(createMockAnimationMetrics())
    } as any;

    // Create detector instance
    detector = PerformanceRegressionDetector.getInstance();
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('Singleton pattern', () => {
    it('should return the same instance when getInstance is called multiple times', () => {
      const instance1 = PerformanceRegressionDetector.getInstance();
      const instance2 = PerformanceRegressionDetector.getInstance();
      expect(instance1).toBe(instance2);
    });
  });

  describe('Baseline management', () => {
    it('should set baseline metrics when setBaseline is called', () => {
      detector.setBaseline();
      expect(mockViewPerformance.getMetrics).toHaveBeenCalled();
      expect(mockAnimationPerformance.getMetrics).toHaveBeenCalled();
    });

    it('should throw error when detecting regressions without baseline', () => {
      expect(() => detector.detectRegressions()).toThrow('Baseline metrics not set');
    });
  });

  describe('Regression detection', () => {
    beforeEach(() => {
      detector.setBaseline();
    });

    it('should detect memory usage regression', () => {
      // Simulate increased memory usage
      mockViewPerformance.getMetrics.mockReturnValueOnce(createMockMetrics({
        memory: {
          usedJSHeapSize: 1500000, // 50% increase
          totalJSHeapSize: 2000000,
          jsHeapSizeLimit: 3000000
        }
      }));

      const report = detector.detectRegressions();
      expect(report.hasRegressions).toBe(true);
      expect(report.regressions.memory).toBeDefined();
      expect(report.recommendations).toContain(expect.stringContaining('Memory usage increased'));
    });

    it('should detect render time regression', () => {
      // Simulate increased render time
      mockViewPerformance.getMetrics.mockReturnValueOnce(createMockMetrics({
        rendering: {
          componentCreateTime: 10,
          renderTime: 30, // 50% increase
          updateTime: 5,
          layoutTime: 15,
          paintTime: 8
        }
      }));

      const report = detector.detectRegressions();
      expect(report.hasRegressions).toBe(true);
      expect(report.regressions.renderTime).toBeDefined();
      expect(report.recommendations).toContain(expect.stringContaining('Render time increased'));
    });

    it('should detect FPS regression', () => {
      // Simulate decreased FPS
      mockAnimationPerformance.getMetrics.mockReturnValueOnce(createMockAnimationMetrics({
        averageFrameRate: 45 // 25% decrease
      }));

      const report = detector.detectRegressions();
      expect(report.hasRegressions).toBe(true);
      expect(report.regressions.fps).toBeDefined();
      expect(report.recommendations).toContain(expect.stringContaining('FPS decreased'));
    });

    it('should detect frame drop rate regression', () => {
      // Simulate increased frame drop rate
      mockAnimationPerformance.getMetrics.mockReturnValueOnce(createMockAnimationMetrics({
        frameDropRate: 1.0 // 100% increase
      }));

      const report = detector.detectRegressions();
      expect(report.hasRegressions).toBe(true);
      expect(report.regressions.frameDropRate).toBeDefined();
      expect(report.recommendations).toContain(expect.stringContaining('Frame drop rate increased'));
    });

    it('should detect component update time regression', () => {
      // Simulate increased component update time
      mockViewPerformance.getMetrics.mockReturnValueOnce(createMockMetrics({
        rendering: {
          componentCreateTime: 10,
          renderTime: 20,
          updateTime: 8, // 60% increase
          layoutTime: 15,
          paintTime: 8
        }
      }));

      const report = detector.detectRegressions();
      expect(report.hasRegressions).toBe(true);
      expect(report.regressions.componentUpdateTime).toBeDefined();
      expect(report.recommendations).toContain(expect.stringContaining('Component update time increased'));
    });

    it('should not detect regressions when metrics are within thresholds', () => {
      // Simulate small changes that are within thresholds
      mockViewPerformance.getMetrics.mockReturnValueOnce(createMockMetrics({
        memory: {
          usedJSHeapSize: 1100000, // 10% increase
          totalJSHeapSize: 2000000,
          jsHeapSizeLimit: 3000000
        },
        rendering: {
          componentCreateTime: 10,
          renderTime: 22, // 10% increase
          updateTime: 5,
          layoutTime: 15,
          paintTime: 8
        }
      }));

      mockAnimationPerformance.getMetrics.mockReturnValueOnce(createMockAnimationMetrics({
        averageFrameRate: 58, // Small decrease
        frameDropRate: 0.6 // Small increase
      }));

      const report = detector.detectRegressions();
      expect(report.hasRegressions).toBe(false);
      expect(Object.keys(report.regressions)).toHaveLength(0);
    });
  });

  describe('Static comparison', () => {
    it('should compare two sets of metrics', () => {
      const baseline = createMockMetrics();
      const current = createMockMetrics({
        rendering: {
          componentCreateTime: 10,
          renderTime: 30, // 50% increase
          updateTime: 5,
          layoutTime: 15,
          paintTime: 8
        }
      });

      const report = PerformanceRegressionDetector.compareMetrics(baseline, current);
      expect(report.hasRegressions).toBe(true);
      expect(report.regressions.renderTime).toBeDefined();
    });
  });

  describe('Custom thresholds', () => {
    it('should use custom thresholds when provided', () => {
      const detector = PerformanceRegressionDetector.getInstance({
        renderTimeIncreasePercent: 5 // Lower threshold
      });

      detector.setBaseline();

      // Simulate small increase that would be detected with custom threshold
      mockViewPerformance.getMetrics.mockReturnValueOnce(createMockMetrics({
        rendering: {
          componentCreateTime: 10,
          renderTime: 22, // 10% increase
          updateTime: 5,
          layoutTime: 15,
          paintTime: 8
        }
      }));

      const report = detector.detectRegressions();
      expect(report.hasRegressions).toBe(true);
      expect(report.regressions.renderTime).toBeDefined();
    });
  });
}); 