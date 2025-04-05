/**
 * AnimationPerformance.test.ts
 * 
 * Tests for the AnimationPerformance class.
 */

import { AnimationPerformance } from '../AnimationPerformance';

// Mock requestAnimationFrame and cancelAnimationFrame
const mockRequestAnimationFrame = jest.fn().mockImplementation(callback => {
  setTimeout(() => callback(performance.now()), 0);
  return 1;
});
const mockCancelAnimationFrame = jest.fn();

Object.defineProperty(global, 'requestAnimationFrame', {
  value: mockRequestAnimationFrame,
  writable: true
});

Object.defineProperty(global, 'cancelAnimationFrame', {
  value: mockCancelAnimationFrame,
  writable: true
});

// Mock performance.now
const mockPerformanceNow = jest.fn();
let currentTime = 0;
mockPerformanceNow.mockImplementation(() => {
  currentTime += 16.67; // Simulate 60fps
  return currentTime;
});

Object.defineProperty(global, 'performance', {
  value: {
    ...global.performance,
    now: mockPerformanceNow
  },
  writable: true
});

describe('AnimationPerformance', () => {
  let animationPerformance: AnimationPerformance;
  
  beforeEach(() => {
    // Reset the singleton instance
    (AnimationPerformance as any).instance = undefined;
    animationPerformance = AnimationPerformance.getInstance();
    jest.clearAllMocks();
    currentTime = 0;
  });
  
  describe('Singleton pattern', () => {
    it('should return the same instance when getInstance is called multiple times', () => {
      const instance1 = AnimationPerformance.getInstance();
      const instance2 = AnimationPerformance.getInstance();
      expect(instance1).toBe(instance2);
    });
  });
  
  describe('Configuration', () => {
    it('should configure with default options', () => {
      animationPerformance.configure();
      animationPerformance.startMonitoring();
      animationPerformance.stopMonitoring();
      
      // Wait for the animation frame to be called
      return new Promise(resolve => {
        setTimeout(() => {
          expect(mockRequestAnimationFrame).toHaveBeenCalled();
          resolve(undefined);
        }, 10);
      });
    });
    
    it('should configure with custom options', () => {
      animationPerformance.configure({
        targetFrameRate: 30,
        frameBudget: 33.33,
        maxHistorySize: 50,
        recordFrameHistory: false
      });
      
      animationPerformance.startMonitoring();
      animationPerformance.stopMonitoring();
      
      // Wait for the animation frame to be called
      return new Promise(resolve => {
        setTimeout(() => {
          expect(mockRequestAnimationFrame).toHaveBeenCalled();
          resolve(undefined);
        }, 10);
      });
    });
  });
  
  describe('Monitoring control', () => {
    it('should start monitoring when startMonitoring is called', () => {
      animationPerformance.startMonitoring();
      
      // Wait for the animation frame to be called
      return new Promise(resolve => {
        setTimeout(() => {
          expect(mockRequestAnimationFrame).toHaveBeenCalled();
          resolve(undefined);
        }, 10);
      });
    });
    
    it('should stop monitoring when stopMonitoring is called', () => {
      animationPerformance.startMonitoring();
      animationPerformance.stopMonitoring();
      
      expect(mockCancelAnimationFrame).toHaveBeenCalled();
    });
    
    it('should not start monitoring twice', () => {
      animationPerformance.startMonitoring();
      animationPerformance.startMonitoring();
      
      // Wait for the animation frame to be called
      return new Promise(resolve => {
        setTimeout(() => {
          expect(mockRequestAnimationFrame).toHaveBeenCalledTimes(1);
          resolve(undefined);
        }, 10);
      });
    });
  });
  
  describe('Metrics collection', () => {
    it('should collect metrics during monitoring', () => {
      animationPerformance.startMonitoring();
      
      // Wait for a few animation frames to be processed
      return new Promise(resolve => {
        setTimeout(() => {
          animationPerformance.stopMonitoring();
          
          const metrics = animationPerformance.getMetrics();
          expect(metrics.totalFrames).toBeGreaterThan(0);
          expect(metrics.averageFrameRate).toBeGreaterThan(0);
          expect(metrics.duration).toBeGreaterThan(0);
          
          resolve(undefined);
        }, 50);
      });
    });
    
    it('should reset metrics when reset is called', () => {
      animationPerformance.startMonitoring();
      
      // Wait for a few animation frames to be processed
      return new Promise(resolve => {
        setTimeout(() => {
          animationPerformance.stopMonitoring();
          
          const metricsBeforeReset = animationPerformance.getMetrics();
          expect(metricsBeforeReset.totalFrames).toBeGreaterThan(0);
          
          animationPerformance.reset();
          
          const metricsAfterReset = animationPerformance.getMetrics();
          expect(metricsAfterReset.totalFrames).toBe(0);
          
          resolve(undefined);
        }, 50);
      });
    });
  });
  
  describe('Frame drop detection', () => {
    it('should detect dropped frames', () => {
      // Simulate frame drops by making some frames take longer
      let frameCount = 0;
      const originalNow = mockPerformanceNow;
      
      mockPerformanceNow.mockImplementation(() => {
        frameCount++;
        if (frameCount % 3 === 0) {
          // Every third frame is dropped
          currentTime += 50; // Much longer than the frame budget
        } else {
          currentTime += 16.67; // Normal frame time
        }
        return currentTime;
      });
      
      animationPerformance.startMonitoring();
      
      // Wait for several animation frames to be processed
      return new Promise(resolve => {
        setTimeout(() => {
          animationPerformance.stopMonitoring();
          
          const metrics = animationPerformance.getMetrics();
          expect(metrics.droppedFrames).toBeGreaterThan(0);
          expect(metrics.frameDropRate).toBeGreaterThan(0);
          
          // Restore the original mock
          mockPerformanceNow.mockImplementation(originalNow);
          
          resolve(undefined);
        }, 100);
      });
    });
  });
}); 