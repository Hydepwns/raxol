/**
 * ViewPerformance.test.ts
 * 
 * Tests for the ViewPerformance class.
 */

import { ViewPerformance } from '../ViewPerformance';
import { 
  ExtendedPerformance, 
  PerformanceTiming, 
  PerformanceMemory,
  isPerformanceAPIAvailable,
  isPerformanceMemoryAPIAvailable,
  createPerformanceFallback
} from '../BrowserPerformanceTypes';

// Mock browser performance API
jest.mock('../BrowserPerformanceTypes', () => {
  return {
    isPerformanceAPIAvailable: jest.fn().mockReturnValue(true),
    isPerformanceMemoryAPIAvailable: jest.fn().mockReturnValue(true),
    createPerformanceFallback: jest.fn().mockReturnValue({
      now: jest.fn().mockReturnValue(100),
      timing: {
        navigationStart: 0,
        fetchStart: 10,
        domainLookupStart: 20,
        domainLookupEnd: 30,
        connectStart: 40,
        connectEnd: 50,
        requestStart: 60,
        responseStart: 70,
        responseEnd: 80,
        domLoading: 90,
        domInteractive: 100,
        domContentLoadedEventStart: 110,
        domContentLoadedEventEnd: 120,
        domComplete: 130,
        loadEventStart: 140,
        loadEventEnd: 150
      },
      memory: {
        usedJSHeapSize: 1000000,
        totalJSHeapSize: 2000000,
        jsHeapSizeLimit: 5000000
      }
    })
  };
});

describe('ViewPerformance', () => {
  let viewPerformance: ViewPerformance;

  beforeEach(() => {
    // Reset the singleton instance
    (ViewPerformance as any).instance = undefined;
    viewPerformance = ViewPerformance.getInstance();
  });

  it('should be a singleton', () => {
    const instance1 = ViewPerformance.getInstance();
    const instance2 = ViewPerformance.getInstance();
    expect(instance1).toBe(instance2);
  });

  it('should start and stop monitoring', () => {
    viewPerformance.startMonitoring();
    expect(viewPerformance['isMonitoring']).toBe(true);
    
    viewPerformance.stopMonitoring();
    expect(viewPerformance['isMonitoring']).toBe(false);
  });

  it('should record component create metrics', () => {
    viewPerformance.startMonitoring();
    viewPerformance.recordComponentCreate('box', 10);
    
    const metrics = viewPerformance.getComponentMetrics('box');
    expect(metrics).toBeDefined();
    expect(metrics?.createTime).toBe(10);
  });

  it('should record component render metrics', () => {
    viewPerformance.startMonitoring();
    viewPerformance.recordComponentCreate('box', 10);
    viewPerformance.recordComponentRender('box', 20, 5);
    
    const metrics = viewPerformance.getComponentMetrics('box');
    expect(metrics).toBeDefined();
    expect(metrics?.renderTime).toBe(20);
    expect(metrics?.childCount).toBe(5);
  });

  it('should record component update metrics', () => {
    viewPerformance.startMonitoring();
    viewPerformance.recordComponentCreate('box', 10);
    viewPerformance.recordComponentUpdate('box', 15);
    
    const metrics = viewPerformance.getComponentMetrics('box');
    expect(metrics).toBeDefined();
    expect(metrics?.updateCount).toBe(1);
  });

  it('should record component operation metrics', () => {
    viewPerformance.startMonitoring();
    viewPerformance.recordComponentOperation('render', 25, 'box');
    
    const operationMetrics = viewPerformance.getAllOperationMetrics();
    expect(operationMetrics).toHaveLength(1);
    expect(operationMetrics[0].operation).toBe('render');
    expect(operationMetrics[0].operationTime).toBe(25);
    expect(operationMetrics[0].componentType).toBe('box');
  });

  it('should get operation metrics by component type', () => {
    viewPerformance.startMonitoring();
    viewPerformance.recordComponentOperation('render', 25, 'box');
    viewPerformance.recordComponentOperation('update', 15, 'text');
    viewPerformance.recordComponentOperation('render', 30, 'box');
    
    const boxOperationMetrics = viewPerformance.getOperationMetricsByComponentType('box');
    expect(boxOperationMetrics).toHaveLength(2);
    expect(boxOperationMetrics[0].operation).toBe('render');
    expect(boxOperationMetrics[1].operation).toBe('render');
  });

  it('should get operation metrics by operation', () => {
    viewPerformance.startMonitoring();
    viewPerformance.recordComponentOperation('render', 25, 'box');
    viewPerformance.recordComponentOperation('update', 15, 'text');
    viewPerformance.recordComponentOperation('render', 30, 'box');
    
    const renderOperationMetrics = viewPerformance.getOperationMetricsByOperation('render');
    expect(renderOperationMetrics).toHaveLength(2);
    expect(renderOperationMetrics[0].componentType).toBe('box');
    expect(renderOperationMetrics[1].componentType).toBe('box');
  });

  it('should get metrics', () => {
    viewPerformance.startMonitoring();
    viewPerformance.recordComponentCreate('box', 10);
    viewPerformance.recordComponentRender('box', 20, 5);
    
    const metrics = viewPerformance.getMetrics();
    expect(metrics).toBeDefined();
    expect(metrics.memory).toBeDefined();
    expect(metrics.timing).toBeDefined();
    expect(metrics.rendering).toBeDefined();
    expect(metrics.rendering.componentCreateTime).toBe(10);
    expect(metrics.rendering.renderTime).toBe(20);
  });

  it('should get component metrics', () => {
    viewPerformance.startMonitoring();
    viewPerformance.recordComponentCreate('box', 10);
    viewPerformance.recordComponentRender('box', 20, 5);
    
    const metrics = viewPerformance.getComponentMetrics('box');
    expect(metrics).toBeDefined();
    expect(metrics?.type).toBe('box');
    expect(metrics?.createTime).toBe(10);
    expect(metrics?.renderTime).toBe(20);
    expect(metrics?.childCount).toBe(5);
  });

  it('should get all component metrics', () => {
    viewPerformance.startMonitoring();
    viewPerformance.recordComponentCreate('box', 10);
    viewPerformance.recordComponentCreate('text', 5);
    
    const metrics = viewPerformance.getAllComponentMetrics();
    expect(metrics).toHaveLength(2);
    expect(metrics[0].type).toBe('box');
    expect(metrics[1].type).toBe('text');
  });

  it('should handle performance API fallback', () => {
    // Mock the performance API as unavailable
    (isPerformanceAPIAvailable as jest.Mock).mockReturnValueOnce(false);
    
    // Reset the singleton instance
    (ViewPerformance as any).instance = undefined;
    const fallbackInstance = ViewPerformance.getInstance();
    
    // Start monitoring and record metrics
    fallbackInstance.startMonitoring();
    fallbackInstance.recordComponentCreate('box', 10);
    
    const metrics = fallbackInstance.getMetrics();
    expect(metrics).toBeDefined();
    expect(metrics.timing).toBeDefined();
  });
}); 