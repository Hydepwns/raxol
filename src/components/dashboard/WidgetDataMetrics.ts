/**
 * WidgetDataMetrics.ts
 * 
 * Handles tracking and analysis of data-related performance metrics.
 */

/**
 * Metric types
 */
export enum MetricType {
  DATA_SOURCE = 'data_source',
  TRANSFORMATION = 'transformation',
  VALIDATION = 'validation',
  CACHE = 'cache',
  BINDING = 'binding',
  SYNC = 'sync',
  ERROR = 'error',
  PERFORMANCE = 'performance'
}

/**
 * Metric configuration
 */
export interface MetricConfig {
  /**
   * Metric type
   */
  type: MetricType;
  
  /**
   * Metric name
   */
  name: string;
  
  /**
   * Metric value
   */
  value: number;
  
  /**
   * Metric timestamp
   */
  timestamp?: number;
  
  /**
   * Widget ID
   */
  widgetId?: string;
  
  /**
   * Source ID
   */
  sourceId?: string;
  
  /**
   * Metric details
   */
  details?: any;
}

/**
 * Metrics configuration
 */
export interface MetricsConfig {
  /**
   * Whether to track metrics
   */
  enabled?: boolean;
  
  /**
   * Maximum history size
   */
  maxHistorySize?: number;
  
  /**
   * Metric aggregation interval in milliseconds
   */
  aggregationInterval?: number;
  
  /**
   * Metric thresholds
   */
  thresholds?: {
    [key: string]: number;
  };
}

/**
 * Widget data metrics
 */
export class WidgetDataMetrics {
  /**
   * Metrics configuration
   */
  private config: MetricsConfig;
  
  /**
   * Metric history
   */
  private history: MetricConfig[];
  
  /**
   * Aggregated metrics
   */
  private aggregated: Map<string, number[]>;
  
  /**
   * Constructor
   */
  constructor(config: MetricsConfig = {}) {
    this.config = {
      enabled: true,
      maxHistorySize: 1000,
      aggregationInterval: 60000, // 1 minute
      ...config
    };
    
    this.history = [];
    this.aggregated = new Map();
    
    // Start aggregation interval
    if (this.config.enabled && this.config.aggregationInterval) {
      setInterval(() => this.aggregateMetrics(), this.config.aggregationInterval);
    }
  }
  
  /**
   * Track metric
   */
  trackMetric(metric: MetricConfig): void {
    if (!this.config.enabled) {
      return;
    }
    
    // Add timestamp if not provided
    if (!metric.timestamp) {
      metric.timestamp = Date.now();
    }
    
    // Add to history
    this.history.push(metric);
    
    // Trim history if needed
    if (this.history.length > this.config.maxHistorySize!) {
      this.history = this.history.slice(-this.config.maxHistorySize!);
    }
    
    // Add to aggregated metrics
    const key = this.getMetricKey(metric);
    if (!this.aggregated.has(key)) {
      this.aggregated.set(key, []);
    }
    this.aggregated.get(key)!.push(metric.value);
    
    // Check thresholds
    this.checkThresholds(metric);
  }
  
  /**
   * Get metric history
   */
  getHistory(type?: MetricType, widgetId?: string): MetricConfig[] {
    let filtered = this.history;
    
    if (type) {
      filtered = filtered.filter(metric => metric.type === type);
    }
    
    if (widgetId) {
      filtered = filtered.filter(metric => metric.widgetId === widgetId);
    }
    
    return filtered;
  }
  
  /**
   * Get aggregated metrics
   */
  getAggregated(type?: MetricType, widgetId?: string): Map<string, number[]> {
    if (!type && !widgetId) {
      return this.aggregated;
    }
    
    const filtered = new Map<string, number[]>();
    
    this.aggregated.forEach((values, key) => {
      const [metricType, metricWidgetId] = key.split(':');
      
      if ((!type || metricType === type) && (!widgetId || metricWidgetId === widgetId)) {
        filtered.set(key, values);
      }
    });
    
    return filtered;
  }
  
  /**
   * Get metric statistics
   */
  getStatistics(type?: MetricType, widgetId?: string): {
    [key: string]: {
      min: number;
      max: number;
      avg: number;
      count: number;
    };
  } {
    const aggregated = this.getAggregated(type, widgetId);
    const statistics: {
      [key: string]: {
        min: number;
        max: number;
        avg: number;
        count: number;
      };
    } = {};
    
    aggregated.forEach((values, key) => {
      if (values.length > 0) {
        const min = Math.min(...values);
        const max = Math.max(...values);
        const sum = values.reduce((a, b) => a + b, 0);
        const avg = sum / values.length;
        
        statistics[key] = {
          min,
          max,
          avg,
          count: values.length
        };
      }
    });
    
    return statistics;
  }
  
  /**
   * Clear metrics
   */
  clearMetrics(): void {
    this.history = [];
    this.aggregated.clear();
  }
  
  /**
   * Set metrics configuration
   */
  setConfig(config: Partial<MetricsConfig>): void {
    this.config = {
      ...this.config,
      ...config
    };
  }
  
  /**
   * Get metrics configuration
   */
  getConfig(): MetricsConfig {
    return { ...this.config };
  }
  
  /**
   * Get metric key
   */
  private getMetricKey(metric: MetricConfig): string {
    return `${metric.type}:${metric.widgetId || 'global'}:${metric.name}`;
  }
  
  /**
   * Aggregate metrics
   */
  private aggregateMetrics(): void {
    // This method would be implemented to aggregate metrics over time
    // The actual implementation would depend on the requirements
  }
  
  /**
   * Check thresholds
   */
  private checkThresholds(metric: MetricConfig): void {
    const key = this.getMetricKey(metric);
    const threshold = this.config.thresholds?.[key];
    
    if (threshold !== undefined && metric.value > threshold) {
      // This would trigger a notification or alert
      console.warn(`Metric threshold exceeded: ${key}`, {
        value: metric.value,
        threshold,
        metric
      });
    }
  }
} 