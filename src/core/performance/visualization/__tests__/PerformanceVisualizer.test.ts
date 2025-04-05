/**
 * PerformanceVisualizer.test.ts
 * 
 * Tests for the PerformanceVisualizer class.
 */

import { PerformanceVisualizer } from '../PerformanceVisualizer';
import { ViewPerformance } from '../../ViewPerformance';
import { AnimationPerformance } from '../../animation/AnimationPerformance';

// Mock the ViewPerformance and AnimationPerformance classes
jest.mock('../../ViewPerformance');
jest.mock('../../animation/AnimationPerformance');

describe('PerformanceVisualizer', () => {
  let visualizer: PerformanceVisualizer;
  let mockViewPerformance: jest.Mocked<ViewPerformance>;
  let mockAnimationPerformance: jest.Mocked<AnimationPerformance>;

  beforeEach(() => {
    // Reset the singleton instance
    (PerformanceVisualizer as any).instance = undefined;

    // Setup mocks
    mockViewPerformance = {
      getInstance: jest.fn().mockReturnThis(),
      getMetrics: jest.fn().mockReturnValue({
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
        }
      }),
      getAllComponentMetrics: jest.fn().mockReturnValue([
        {
          type: 'test-component',
          createTime: 10,
          renderTime: 20,
          updateCount: 5,
          childCount: 3,
          memoryUsage: 1000
        }
      ])
    } as any;

    mockAnimationPerformance = {
      getInstance: jest.fn().mockReturnThis(),
      getMetrics: jest.fn().mockReturnValue({
        averageFrameRate: 60,
        minFrameRate: 55,
        maxFrameRate: 65,
        frameDropRate: 0.5,
        totalFrames: 1000,
        droppedFrames: 5,
        averageFrameDuration: 16.67,
        frameHistory: [],
        duration: 10000
      })
    } as any;

    // Create visualizer instance
    visualizer = PerformanceVisualizer.getInstance();
  });

  afterEach(() => {
    // Clean up
    visualizer.hideOverlay();
    jest.clearAllMocks();
  });

  describe('Singleton pattern', () => {
    it('should return the same instance when getInstance is called multiple times', () => {
      const instance1 = PerformanceVisualizer.getInstance();
      const instance2 = PerformanceVisualizer.getInstance();
      expect(instance1).toBe(instance2);
    });
  });

  describe('Overlay management', () => {
    it('should create and show the overlay when showOverlay is called', () => {
      // Mock document.body.appendChild
      const appendChildMock = jest.fn();
      document.body.appendChild = appendChildMock;

      visualizer.showOverlay();

      expect(appendChildMock).toHaveBeenCalled();
      expect(appendChildMock.mock.calls[0][0]).toBeInstanceOf(HTMLElement);
    });

    it('should remove the overlay when hideOverlay is called', () => {
      // Mock document.body.appendChild and removeChild
      const appendChildMock = jest.fn();
      const removeChildMock = jest.fn();
      document.body.appendChild = appendChildMock;
      document.body.removeChild = removeChildMock;

      visualizer.showOverlay();
      visualizer.hideOverlay();

      expect(removeChildMock).toHaveBeenCalled();
    });
  });

  describe('Metrics visualization', () => {
    beforeEach(() => {
      // Mock document.body.appendChild
      document.body.appendChild = jest.fn();
    });

    it('should update metrics periodically when overlay is shown', () => {
      jest.useFakeTimers();
      visualizer.showOverlay();

      // Fast-forward time
      jest.advanceTimersByTime(1000);

      expect(mockViewPerformance.getMetrics).toHaveBeenCalled();
      expect(mockAnimationPerformance.getMetrics).toHaveBeenCalled();

      jest.useRealTimers();
    });

    it('should stop updating metrics when overlay is hidden', () => {
      jest.useFakeTimers();
      visualizer.showOverlay();
      visualizer.hideOverlay();

      // Fast-forward time
      jest.advanceTimersByTime(1000);

      expect(mockViewPerformance.getMetrics).not.toHaveBeenCalled();
      expect(mockAnimationPerformance.getMetrics).not.toHaveBeenCalled();

      jest.useRealTimers();
    });
  });

  describe('Options handling', () => {
    it('should use default options when none are provided', () => {
      const visualizer = PerformanceVisualizer.getInstance();
      expect(visualizer).toBeDefined();
    });

    it('should use custom options when provided', () => {
      const customOptions = {
        updateInterval: 2000,
        maxDataPoints: 30,
        showMemory: false,
        showFPS: false,
        showComponentMetrics: false,
        showAnimationMetrics: false
      };

      const visualizer = PerformanceVisualizer.getInstance(customOptions);
      expect(visualizer).toBeDefined();
    });
  });
}); 