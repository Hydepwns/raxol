/**
 * PerformanceMetrics.ts
 * 
 * Provides tools for collecting, analyzing, and visualizing various
 * performance metrics to help identify and resolve performance bottlenecks.
 */

type MetricType = 'render' | 'interaction' | 'network' | 'resource' | 'custom';

interface MetricEntry {
  name: string;
  type: MetricType;
  value: number;
  timestamp: number;
  metadata?: Record<string, any>;
}

interface PerformanceMark {
  name: string;
  startTime: number;
  metadata?: Record<string, any>;
}

interface PerformanceSummary {
  name: string;
  min: number;
  max: number;
  average: number;
  median: number;
  p95: number; // 95th percentile
  count: number;
  totalTime: number;
}

export class PerformanceMetrics {
  private metrics: MetricEntry[] = [];
  private marks: Map<string, PerformanceMark> = new Map();
  private thresholds: Map<string, number> = new Map();
  private listeners: Map<string, Array<(entry: MetricEntry) => void>> = new Map();
  
  constructor() {
    // Initialize with some default thresholds
    this.setThreshold('render', 16); // 16ms (60fps)
    this.setThreshold('interaction', 100); // 100ms for interaction response
  }
  
  /**
   * Record a performance metric
   */
  public recordMetric(
    name: string,
    value: number,
    type: MetricType = 'custom',
    metadata?: Record<string, any>
  ): void {
    const entry: MetricEntry = {
      name,
      type,
      value,
      timestamp: Date.now(),
      metadata
    };
    
    this.metrics.push(entry);
    
    // Check against threshold
    const threshold = this.thresholds.get(name) || this.thresholds.get(type);
    if (threshold !== undefined && value > threshold) {
      this.reportThresholdExceeded(entry, threshold);
    }
    
    // Notify listeners
    this.notifyListeners(entry);
  }
  
  /**
   * Start timing a performance mark
   */
  public markStart(name: string, metadata?: Record<string, any>): void {
    this.marks.set(name, {
      name,
      startTime: performance.now(),
      metadata
    });
  }
  
  /**
   * End timing a performance mark and record the metric
   */
  public markEnd(name: string, type: MetricType = 'custom'): number | null {
    const mark = this.marks.get(name);
    if (!mark) {
      console.warn(`No start mark found for: ${name}`);
      return null;
    }
    
    const endTime = performance.now();
    const duration = endTime - mark.startTime;
    
    // Record the metric
    this.recordMetric(name, duration, type, mark.metadata);
    
    // Clean up the mark
    this.marks.delete(name);
    
    return duration;
  }
  
  /**
   * Set a threshold for a specific metric or metric type
   */
  public setThreshold(nameOrType: string, thresholdValue: number): void {
    this.thresholds.set(nameOrType, thresholdValue);
  }
  
  /**
   * Get metrics by name
   */
  public getMetricsByName(name: string): MetricEntry[] {
    return this.metrics.filter(metric => metric.name === name);
  }
  
  /**
   * Get metrics by type
   */
  public getMetricsByType(type: MetricType): MetricEntry[] {
    return this.metrics.filter(metric => metric.type === type);
  }
  
  /**
   * Calculate summary statistics for a metric
   */
  public getMetricSummary(nameOrType: string): PerformanceSummary | null {
    const metrics = this.metrics.filter(
      metric => metric.name === nameOrType || metric.type === nameOrType
    );
    
    if (metrics.length === 0) {
      return null;
    }
    
    const values = metrics.map(m => m.value);
    values.sort((a, b) => a - b);
    
    const min = values[0];
    const max = values[values.length - 1];
    const count = values.length;
    const totalTime = values.reduce((sum, val) => sum + val, 0);
    const average = totalTime / count;
    
    // Calculate median
    const midIndex = Math.floor(count / 2);
    const median = count % 2 === 0
      ? (values[midIndex - 1] + values[midIndex]) / 2
      : values[midIndex];
    
    // Calculate 95th percentile
    const p95Index = Math.min(Math.floor(count * 0.95), count - 1);
    const p95 = values[p95Index];
    
    return {
      name: nameOrType,
      min,
      max,
      average,
      median,
      p95,
      count,
      totalTime
    };
  }
  
  /**
   * Get all metrics within a time range
   */
  public getMetricsInTimeRange(startTime: number, endTime: number): MetricEntry[] {
    return this.metrics.filter(metric => 
      metric.timestamp >= startTime && metric.timestamp <= endTime
    );
  }
  
  /**
   * Add a listener for a specific metric type
   */
  public addListener(type: MetricType | string, callback: (entry: MetricEntry) => void): void {
    if (!this.listeners.has(type)) {
      this.listeners.set(type, []);
    }
    
    this.listeners.get(type)!.push(callback);
  }
  
  /**
   * Remove a listener
   */
  public removeListener(type: MetricType | string, callback: (entry: MetricEntry) => void): void {
    if (!this.listeners.has(type)) {
      return;
    }
    
    this.listeners.set(
      type,
      this.listeners.get(type)!.filter(listener => listener !== callback)
    );
  }
  
  /**
   * Clear all metrics
   */
  public clearMetrics(): void {
    this.metrics = [];
  }
  
  /**
   * Get all recorded metrics
   */
  public getAllMetrics(): MetricEntry[] {
    return [...this.metrics];
  }
  
  /**
   * Detect performance regressions by comparing metrics
   */
  public detectRegressions(
    baselineMetrics: MetricEntry[],
    currentMetrics: MetricEntry[],
    thresholdPercentage: number = 20
  ): Record<string, { baseline: number, current: number, change: number }> {
    const baselineByName: Record<string, number[]> = {};
    const currentByName: Record<string, number[]> = {};
    const regressions: Record<string, { baseline: number, current: number, change: number }> = {};
    
    // Group baseline metrics by name
    baselineMetrics.forEach(metric => {
      if (!baselineByName[metric.name]) {
        baselineByName[metric.name] = [];
      }
      baselineByName[metric.name].push(metric.value);
    });
    
    // Group current metrics by name
    currentMetrics.forEach(metric => {
      if (!currentByName[metric.name]) {
        currentByName[metric.name] = [];
      }
      currentByName[metric.name].push(metric.value);
    });
    
    // Calculate averages and compare
    Object.keys(baselineByName).forEach(name => {
      if (!currentByName[name]) {
        return;
      }
      
      const baselineAvg = baselineByName[name].reduce((sum, val) => sum + val, 0) / baselineByName[name].length;
      const currentAvg = currentByName[name].reduce((sum, val) => sum + val, 0) / currentByName[name].length;
      
      // Calculate percentage change
      const percentChange = ((currentAvg - baselineAvg) / baselineAvg) * 100;
      
      // If the change exceeds the threshold and it's worse (higher is worse for performance metrics)
      if (percentChange > thresholdPercentage) {
        regressions[name] = {
          baseline: baselineAvg,
          current: currentAvg,
          change: percentChange
        };
      }
    });
    
    return regressions;
  }
  
  /**
   * Notify listeners when a metric is recorded
   */
  private notifyListeners(entry: MetricEntry): void {
    // Notify type-specific listeners
    this.notifyTypeListeners(entry.type, entry);
    
    // Notify name-specific listeners
    this.notifyTypeListeners(entry.name, entry);
    
    // Notify general listeners
    this.notifyTypeListeners('*', entry);
  }
  
  /**
   * Notify listeners of a specific type
   */
  private notifyTypeListeners(type: string, entry: MetricEntry): void {
    const typeListeners = this.listeners.get(type);
    if (!typeListeners) {
      return;
    }
    
    typeListeners.forEach(listener => {
      try {
        listener(entry);
      } catch (error) {
        console.error(`Error in performance metric listener for ${type}:`, error);
      }
    });
  }
  
  /**
   * Report when a threshold is exceeded
   */
  private reportThresholdExceeded(entry: MetricEntry, threshold: number): void {
    console.warn(`Performance threshold exceeded for ${entry.name} (${entry.type}):`, {
      value: entry.value,
      threshold,
      timestamp: entry.timestamp,
      metadata: entry.metadata
    });
  }
} 