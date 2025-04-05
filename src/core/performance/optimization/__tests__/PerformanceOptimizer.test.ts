/**
 * PerformanceOptimizer.test.ts
 * 
 * Tests for the PerformanceOptimizer class.
 */

import { PerformanceOptimizer } from '../PerformanceOptimizer';
import { ViewPerformance } from '../../ViewPerformance';
import { AnimationPerformance } from '../../animation/AnimationPerformance';
import { PerformanceMetrics } from '../../ViewPerformance';
import { AnimationPerformanceMetrics } from '../../animation/AnimationPerformance';
import { ComponentMetrics } from '../../ViewPerformance';

// Mock the ViewPerformance and AnimationPerformance classes
jest.mock('../../ViewPerformance');
jest.mock('../../animation/AnimationPerformance');

describe('PerformanceOptimizer', () => {
  let optimizer: PerformanceOptimizer;
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

  const createMockComponentMetrics = (overrides: Partial<ComponentMetrics> = {}): ComponentMetrics => ({
    type: 'test-component',
    createTime: 10,
    renderTime: 20,
    updateCount: 5,
    childCount: 3,
    memoryUsage: 1000,
    ...overrides
  });

  beforeEach(() => {
    // Reset the singleton instance
    (PerformanceOptimizer as any).instance = undefined;

    // Setup mocks
    mockViewPerformance = {
      getInstance: jest.fn().mockReturnThis(),
      getMetrics: jest.fn().mockReturnValue(createMockMetrics()),
      getAllComponentMetrics: jest.fn().mockReturnValue([createMockComponentMetrics()]),
      getComponentMetrics: jest.fn().mockReturnValue(createMockComponentMetrics())
    } as any;

    mockAnimationPerformance = {
      getInstance: jest.fn().mockReturnThis(),
      getMetrics: jest.fn().mockReturnValue(createMockAnimationMetrics())
    } as any;

    // Create optimizer instance
    optimizer = PerformanceOptimizer.getInstance();
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('Singleton pattern', () => {
    it('should return the same instance when getInstance is called multiple times', () => {
      const instance1 = PerformanceOptimizer.getInstance();
      const instance2 = PerformanceOptimizer.getInstance();
      expect(instance1).toBe(instance2);
    });
  });

  describe('Optimization recommendations', () => {
    it('should generate memory optimization recommendations when memory usage is high', () => {
      mockViewPerformance.getMetrics.mockReturnValueOnce(createMockMetrics({
        memory: {
          usedJSHeapSize: 1800000, // 90% of total
          totalJSHeapSize: 2000000,
          jsHeapSizeLimit: 3000000
        }
      }));

      const recommendations = optimizer.generateOptimizationRecommendations();
      expect(recommendations).toContainEqual(expect.objectContaining({
        category: 'memory',
        severity: 'high',
        title: 'Critical Memory Usage'
      }));
    });

    it('should generate rendering optimization recommendations when render time is high', () => {
      mockViewPerformance.getMetrics.mockReturnValueOnce(createMockMetrics({
        rendering: {
          componentCreateTime: 10,
          renderTime: 25, // Above 16ms threshold
          updateTime: 5,
          layoutTime: 15,
          paintTime: 8
        }
      }));

      const recommendations = optimizer.generateOptimizationRecommendations();
      expect(recommendations).toContainEqual(expect.objectContaining({
        category: 'rendering',
        severity: 'medium',
        title: 'Optimize Render Performance'
      }));
    });

    it('should generate animation optimization recommendations when FPS is low', () => {
      mockAnimationPerformance.getMetrics.mockReturnValueOnce(createMockAnimationMetrics({
        averageFrameRate: 45 // Below 55 FPS threshold
      }));

      const recommendations = optimizer.generateOptimizationRecommendations();
      expect(recommendations).toContainEqual(expect.objectContaining({
        category: 'animation',
        severity: 'medium',
        title: 'Optimize Animation Performance'
      }));
    });

    it('should generate component optimization recommendations when component metrics indicate issues', () => {
      mockViewPerformance.getAllComponentMetrics.mockReturnValueOnce([
        createMockComponentMetrics({
          renderTime: 25, // Above 16ms threshold
          updateCount: 15, // Above 10 updates threshold
          childCount: 150 // Above 100 children threshold
        })
      ]);

      const recommendations = optimizer.generateOptimizationRecommendations();
      expect(recommendations).toContainEqual(expect.objectContaining({
        category: 'component',
        severity: 'medium',
        title: 'Optimize Component Render Time'
      }));
      expect(recommendations).toContainEqual(expect.objectContaining({
        category: 'component',
        severity: 'medium',
        title: 'Reduce Component Update Frequency'
      }));
      expect(recommendations).toContainEqual(expect.objectContaining({
        category: 'component',
        severity: 'medium',
        title: 'Optimize Large Component Tree'
      }));
    });
  });

  describe('Component performance analysis', () => {
    it('should analyze component performance and return recommendations', () => {
      const componentType = 'test-component';
      mockViewPerformance.getComponentMetrics.mockReturnValueOnce(createMockComponentMetrics({
        renderTime: 25,
        updateCount: 15,
        childCount: 150
      }));

      const analysis = optimizer.analyzeComponentPerformance(componentType);
      expect(analysis.componentType).toBe(componentType);
      expect(analysis.recommendations).toHaveLength(3);
      expect(analysis.bottlenecks).toHaveLength(3);
    });

    it('should throw error when component metrics not found', () => {
      mockViewPerformance.getComponentMetrics.mockReturnValueOnce(undefined);
      expect(() => optimizer.analyzeComponentPerformance('non-existent')).toThrow();
    });
  });
}); 