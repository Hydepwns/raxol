/**
 * Performance Threshold Configuration
 * 
 * Defines configurable thresholds for performance metrics.
 */

/**
 * Threshold configuration for a specific metric
 */
export interface MetricThreshold {
  /**
   * The name of the metric
   */
  name: string;
  
  /**
   * The warning threshold value
   * When the metric exceeds this value, a warning alert will be triggered
   */
  warningThreshold: number;
  
  /**
   * The critical threshold value
   * When the metric exceeds this value, a critical alert will be triggered
   */
  criticalThreshold: number;
  
  /**
   * The minimum change percentage required to trigger an alert
   * This helps prevent noisy alerts for minor fluctuations
   * Default: 10 (10%)
   */
  minChangePercentage?: number;
  
  /**
   * Whether a higher value is worse (true) or better (false)
   * Default: true
   */
  higherIsBad?: boolean;
  
  /**
   * Description of the metric for display purposes
   */
  description?: string;
  
  /**
   * Unit for display purposes (e.g., "ms", "%", "MB")
   */
  unit?: string;
}

/**
 * Configuration for a group of related metrics
 */
export interface ThresholdGroup {
  /**
   * The name of the group
   */
  name: string;
  
  /**
   * Description of the group
   */
  description?: string;
  
  /**
   * Metrics in this group
   */
  metrics: MetricThreshold[];
  
  /**
   * Whether this group is enabled
   * Default: true
   */
  enabled?: boolean;
}

/**
 * Complete threshold configuration
 */
export interface ThresholdConfiguration {
  /**
   * Groups of metric thresholds
   */
  groups: ThresholdGroup[];
  
  /**
   * Global minimum change percentage
   * This is used if not specified at the metric level
   * Default: 10 (10%)
   */
  defaultMinChangePercentage?: number;
  
  /**
   * Whether to enable all alerts by default
   * Default: true
   */
  enabledByDefault?: boolean;
}

/**
 * Default performance thresholds for common metrics
 */
export const DEFAULT_THRESHOLDS: ThresholdConfiguration = {
  defaultMinChangePercentage: 10,
  enabledByDefault: true,
  groups: [
    {
      name: 'responsiveness',
      description: 'User interaction responsiveness metrics',
      metrics: [
        {
          name: 'inputLatency',
          warningThreshold: 100,
          criticalThreshold: 200,
          description: 'Time from input event to first visual response',
          unit: 'ms',
          higherIsBad: true
        },
        {
          name: 'timeToInteractive',
          warningThreshold: 300,
          criticalThreshold: 500,
          description: 'Time until component becomes fully interactive',
          unit: 'ms',
          higherIsBad: true
        },
        {
          name: 'frameDropRate',
          warningThreshold: 5,
          criticalThreshold: 10,
          description: 'Percentage of dropped frames during interaction',
          unit: '%',
          higherIsBad: true
        }
      ]
    },
    {
      name: 'rendering',
      description: 'Visual rendering performance metrics',
      metrics: [
        {
          name: 'fps',
          warningThreshold: 45,
          criticalThreshold: 30,
          description: 'Frames per second',
          unit: 'fps',
          higherIsBad: false
        },
        {
          name: 'renderTime',
          warningThreshold: 16,
          criticalThreshold: 33,
          description: 'Time to render a frame',
          unit: 'ms',
          higherIsBad: true
        },
        {
          name: 'jankFrequency',
          warningThreshold: 5,
          criticalThreshold: 10,
          description: 'Frequency of janky frames',
          unit: '%',
          higherIsBad: true
        }
      ]
    },
    {
      name: 'memory',
      description: 'Memory usage metrics',
      metrics: [
        {
          name: 'heapSize',
          warningThreshold: 100,
          criticalThreshold: 250,
          description: 'Total JavaScript heap size',
          unit: 'MB',
          higherIsBad: true
        },
        {
          name: 'memoryGrowthRate',
          warningThreshold: 5,
          criticalThreshold: 10,
          description: 'Memory growth rate over time',
          unit: 'MB/min',
          higherIsBad: true
        }
      ]
    }
  ]
};

/**
 * Get a specific metric threshold by name
 */
export function getMetricThreshold(config: ThresholdConfiguration, metricName: string): MetricThreshold | null {
  for (const group of config.groups) {
    if (group.enabled === false) continue;
    
    for (const metric of group.metrics) {
      if (metric.name === metricName) {
        return metric;
      }
    }
  }
  
  return null;
}

/**
 * Get all enabled metrics from the configuration
 */
export function getEnabledMetrics(config: ThresholdConfiguration): MetricThreshold[] {
  const enabledMetrics: MetricThreshold[] = [];
  
  for (const group of config.groups) {
    if (group.enabled === false) continue;
    
    for (const metric of group.metrics) {
      enabledMetrics.push(metric);
    }
  }
  
  return enabledMetrics;
} 