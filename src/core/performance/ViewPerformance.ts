/**
 * ViewPerformance.ts
 * 
 * Performance monitoring system for the View rendering system.
 * Tracks rendering performance, memory usage, and component lifecycle.
 */

import { 
  ExtendedPerformance, 
  PerformanceTiming, 
  PerformanceMemory,
  isPerformanceAPIAvailable,
  isPerformanceMemoryAPIAvailable,
  createPerformanceFallback
} from './BrowserPerformanceTypes';

export interface PerformanceMetrics {
  memory?: PerformanceMemory;
  timing: PerformanceTiming;
  rendering: {
    componentCreateTime: number;
    renderTime: number;
    updateTime: number;
    layoutTime: number;
    paintTime: number;
  };
}

export interface ComponentMetrics {
  type: string;
  createTime: number;
  renderTime: number;
  updateCount: number;
  childCount: number;
  memoryUsage: number;
}

export interface ComponentOperationMetrics {
  operation: string;
  operationTime: number;
  timestamp: number;
  componentType?: string;
}

export class ViewPerformance {
  private static instance: ViewPerformance;
  private metrics: Map<string, ComponentMetrics> = new Map();
  private operationMetrics: ComponentOperationMetrics[] = [];
  private startTime: number = 0;
  private isMonitoring: boolean = false;
  private performanceAPI: ExtendedPerformance | ReturnType<typeof createPerformanceFallback>;

  private constructor() {
    // Use the real Performance API if available, otherwise use the fallback
    this.performanceAPI = isPerformanceAPIAvailable() 
      ? (performance as ExtendedPerformance) 
      : createPerformanceFallback();
  }

  static getInstance(): ViewPerformance {
    if (!ViewPerformance.instance) {
      ViewPerformance.instance = new ViewPerformance();
    }
    return ViewPerformance.instance;
  }

  /**
   * Start performance monitoring
   */
  startMonitoring(): void {
    if (this.isMonitoring) return;
    this.isMonitoring = true;
    this.startTime = this.performanceAPI.now();
    this.metrics.clear();
    this.operationMetrics = [];
  }

  /**
   * Stop performance monitoring
   */
  stopMonitoring(): void {
    this.isMonitoring = false;
  }

  /**
   * Record component creation metrics
   */
  recordComponentCreate(type: string, createTime: number): void {
    if (!this.isMonitoring) return;

    const metrics: ComponentMetrics = {
      type,
      createTime,
      renderTime: 0,
      updateCount: 0,
      childCount: 0,
      memoryUsage: 0
    };

    this.metrics.set(type, metrics);
  }

  /**
   * Record component render metrics
   */
  recordComponentRender(type: string, renderTime: number, childCount: number): void {
    if (!this.isMonitoring) return;

    const metrics = this.metrics.get(type);
    if (metrics) {
      metrics.renderTime = renderTime;
      metrics.childCount = childCount;
      this.metrics.set(type, metrics);
    }
  }

  /**
   * Record component update metrics
   */
  recordComponentUpdate(type: string, updateTime: number): void {
    if (!this.isMonitoring) return;

    const metrics = this.metrics.get(type);
    if (metrics) {
      metrics.updateCount++;
      this.metrics.set(type, metrics);
    }
  }

  /**
   * Record component operation metrics
   * @param operation - The name of the operation
   * @param operationTime - The time taken for the operation in milliseconds
   * @param componentType - Optional component type associated with the operation
   */
  recordComponentOperation(operation: string, operationTime: number, componentType?: string): void {
    if (!this.isMonitoring) return;
    
    const operationMetric: ComponentOperationMetrics = {
      operation,
      operationTime,
      timestamp: this.performanceAPI.now(),
      componentType
    };
    
    this.operationMetrics.push(operationMetric);
    
    // Log operation metrics for debugging
    console.debug(`Component operation '${operation}'${componentType ? ` for ${componentType}` : ''} took ${operationTime.toFixed(2)}ms`);
  }

  /**
   * Get performance metrics
   */
  getMetrics(): PerformanceMetrics {
    const memory = this.getMemoryMetrics();
    const timing = this.getTimingMetrics();
    const rendering = this.getRenderingMetrics();

    return {
      memory,
      timing,
      rendering
    };
  }

  /**
   * Get component-specific metrics
   */
  getComponentMetrics(type: string): ComponentMetrics | undefined {
    return this.metrics.get(type);
  }

  /**
   * Get all component metrics
   */
  getAllComponentMetrics(): ComponentMetrics[] {
    return Array.from(this.metrics.values());
  }

  /**
   * Get all component operation metrics
   */
  getAllOperationMetrics(): ComponentOperationMetrics[] {
    return [...this.operationMetrics];
  }

  /**
   * Get operation metrics for a specific component type
   */
  getOperationMetricsByComponentType(componentType: string): ComponentOperationMetrics[] {
    return this.operationMetrics.filter(metric => metric.componentType === componentType);
  }

  /**
   * Get operation metrics for a specific operation
   */
  getOperationMetricsByOperation(operation: string): ComponentOperationMetrics[] {
    return this.operationMetrics.filter(metric => metric.operation === operation);
  }

  /**
   * Get memory usage metrics
   */
  private getMemoryMetrics(): PerformanceMemory | undefined {
    if (isPerformanceMemoryAPIAvailable()) {
      const perf = this.performanceAPI as ExtendedPerformance;
      return {
        usedJSHeapSize: perf.memory!.usedJSHeapSize,
        totalJSHeapSize: perf.memory!.totalJSHeapSize,
        jsHeapSizeLimit: perf.memory!.jsHeapSizeLimit
      };
    }
    return undefined;
  }

  /**
   * Get timing metrics
   */
  private getTimingMetrics(): PerformanceTiming {
    const timing = this.performanceAPI.timing;
    const now = this.performanceAPI.now();
    
    // Provide default values for potentially undefined timing properties
    return {
      navigationStart: timing.navigationStart || now,
      fetchStart: timing.fetchStart || now,
      domainLookupStart: timing.domainLookupStart || now,
      domainLookupEnd: timing.domainLookupEnd || now,
      connectStart: timing.connectStart || now,
      connectEnd: timing.connectEnd || now,
      requestStart: timing.requestStart || now,
      responseStart: timing.responseStart || now,
      responseEnd: timing.responseEnd || now,
      domLoading: timing.domLoading || now,
      domInteractive: timing.domInteractive || now,
      domContentLoadedEventStart: timing.domContentLoadedEventStart || now,
      domContentLoadedEventEnd: timing.domContentLoadedEventEnd || now,
      domComplete: timing.domComplete || now,
      loadEventStart: timing.loadEventStart || now,
      loadEventEnd: timing.loadEventEnd || now
    };
  }

  /**
   * Get rendering metrics
   */
  private getRenderingMetrics(): PerformanceMetrics['rendering'] {
    const componentMetrics = this.getAllComponentMetrics();
    const totalCreateTime = componentMetrics.reduce((sum, m) => sum + m.createTime, 0);
    const totalRenderTime = componentMetrics.reduce((sum, m) => sum + m.renderTime, 0);
    const totalUpdateTime = componentMetrics.reduce((sum, m) => sum + (m.updateCount * 5), 0); // Estimate update time
    
    return {
      componentCreateTime: totalCreateTime,
      renderTime: totalRenderTime,
      updateTime: totalUpdateTime,
      layoutTime: totalRenderTime * 0.3, // Estimate layout time as 30% of render time
      paintTime: totalRenderTime * 0.2 // Estimate paint time as 20% of render time
    };
  }
} 