/**
 * Performance Regression Detector
 * 
 * Detects performance regressions by comparing metrics against baselines and thresholds.
 */

import { 
  ThresholdConfiguration, 
  MetricThreshold, 
  DEFAULT_THRESHOLDS, 
  getMetricThreshold 
} from './thresholds';

/**
 * Alert severity levels
 */
export type AlertSeverity = 'warning' | 'critical' | 'info';

/**
 * Result of a regression check
 */
export interface RegressionResult {
  /**
   * The name of the metric
   */
  metricName: string;
  
  /**
   * The current value of the metric
   */
  currentValue: number;
  
  /**
   * The baseline value (previous measurement)
   */
  baselineValue: number;
  
  /**
   * The absolute change in the metric
   */
  absoluteChange: number;
  
  /**
   * The percentage change in the metric
   */
  percentageChange: number;
  
  /**
   * The severity of the regression
   */
  severity: AlertSeverity;
  
  /**
   * Whether the change is a regression (worse) or improvement (better)
   */
  isRegression: boolean;
  
  /**
   * The threshold configuration used for this metric
   */
  threshold: MetricThreshold;
  
  /**
   * Timestamp when the regression was detected
   */
  timestamp: number;
  
  /**
   * Component or context where the regression was detected
   */
  context?: string;
}

/**
 * Options for the regression detector
 */
export interface RegressionDetectorConfig {
  /**
   * Threshold configuration to use
   * Defaults to DEFAULT_THRESHOLDS
   */
  thresholds?: ThresholdConfiguration;
  
  /**
   * Whether to detect improvements as well as regressions
   * Default: false
   */
  detectImprovements?: boolean;
  
  /**
   * The maximum number of results to store in history
   * Default: 100
   */
  maxHistorySize?: number;
  
  /**
   * How long (in ms) to wait between the same alert being triggered again
   * This prevents alert flooding for the same issue
   * Default: 3600000 (1 hour)
   */
  alertCooldown?: number;
}

/**
 * Format used to store a baseline value
 */
interface BaselineMetric {
  /**
   * The name of the metric
   */
  name: string;
  
  /**
   * The baseline value
   */
  value: number;
  
  /**
   * When the baseline was set
   */
  timestamp: number;
  
  /**
   * Context information
   */
  context?: string;
}

/**
 * Detects performance regressions by comparing metrics against baselines and thresholds
 */
export class RegressionDetector {
  /**
   * Configuration for the detector
   */
  private config: Required<RegressionDetectorConfig>;
  
  /**
   * Current baselines for different metrics
   */
  private baselines: Map<string, BaselineMetric> = new Map();
  
  /**
   * History of detected regressions
   */
  private regressionHistory: RegressionResult[] = [];
  
  /**
   * Map to track when alerts were last triggered to implement cooldown
   */
  private lastAlertTime: Map<string, number> = new Map();
  
  /**
   * Listeners for regression events
   */
  private listeners: Array<(result: RegressionResult) => void> = [];
  
  /**
   * Creates a new RegressionDetector
   */
  constructor(config?: RegressionDetectorConfig) {
    this.config = {
      thresholds: config?.thresholds ?? DEFAULT_THRESHOLDS,
      detectImprovements: config?.detectImprovements ?? false,
      maxHistorySize: config?.maxHistorySize ?? 100,
      alertCooldown: config?.alertCooldown ?? 3600000 // 1 hour
    };
  }
  
  /**
   * Set the threshold configuration
   */
  public setThresholds(thresholds: ThresholdConfiguration): void {
    this.config.thresholds = thresholds;
  }
  
  /**
   * Set a baseline for a specific metric
   */
  public setBaseline(metricName: string, value: number, context?: string): void {
    this.baselines.set(metricName, {
      name: metricName,
      value,
      timestamp: Date.now(),
      context
    });
  }
  
  /**
   * Set multiple baselines at once
   */
  public setBaselines(metrics: Array<{ name: string; value: number; context?: string; }>): void {
    for (const metric of metrics) {
      this.setBaseline(metric.name, metric.value, metric.context);
    }
  }
  
  /**
   * Get the current baseline for a metric
   */
  public getBaseline(metricName: string): BaselineMetric | undefined {
    return this.baselines.get(metricName);
  }
  
  /**
   * Check if a metric has regressed compared to its baseline
   */
  public checkRegression(
    metricName: string, 
    currentValue: number, 
    context?: string
  ): RegressionResult | null {
    // Get the baseline for this metric
    const baseline = this.baselines.get(metricName);
    if (!baseline) {
      // No baseline yet, set it and return null
      this.setBaseline(metricName, currentValue, context);
      return null;
    }
    
    // Get the threshold configuration for this metric
    const thresholdConfig = getMetricThreshold(this.config.thresholds, metricName);
    if (!thresholdConfig) {
      // No threshold configuration for this metric
      return null;
    }
    
    // Calculate the change
    const absoluteChange = currentValue - baseline.value;
    const percentageChange = (absoluteChange / baseline.value) * 100;
    
    // Determine if this is a regression or improvement
    const higherIsBad = thresholdConfig.higherIsBad ?? true;
    const isRegression = higherIsBad ? currentValue > baseline.value : currentValue < baseline.value;
    
    // If we're not detecting improvements and this is an improvement, return null
    if (!this.config.detectImprovements && !isRegression) {
      return null;
    }
    
    // Check if the change exceeds the minimum percentage threshold
    const minChangePercentage = thresholdConfig.minChangePercentage ?? 
                              this.config.thresholds.defaultMinChangePercentage ?? 
                              10;
    
    if (Math.abs(percentageChange) < minChangePercentage) {
      // Change is too small to be significant
      return null;
    }
    
    // Determine the severity of the change
    let severity: AlertSeverity;
    
    if (isRegression) {
      // For regressions, check against warning and critical thresholds
      if (higherIsBad) {
        if (currentValue >= thresholdConfig.criticalThreshold) {
          severity = 'critical';
        } else if (currentValue >= thresholdConfig.warningThreshold) {
          severity = 'warning';
        } else {
          severity = 'info';
        }
      } else {
        // For metrics where lower is worse
        if (currentValue <= thresholdConfig.criticalThreshold) {
          severity = 'critical';
        } else if (currentValue <= thresholdConfig.warningThreshold) {
          severity = 'warning';
        } else {
          severity = 'info';
        }
      }
    } else {
      // For improvements, always use info severity
      severity = 'info';
    }
    
    // Create the regression result
    const result: RegressionResult = {
      metricName,
      currentValue,
      baselineValue: baseline.value,
      absoluteChange,
      percentageChange,
      severity,
      isRegression,
      threshold: thresholdConfig,
      timestamp: Date.now(),
      context
    };
    
    // Check if we're in the cooldown period for this alert
    const alertKey = `${metricName}:${severity}:${context || 'global'}`;
    const lastAlertTime = this.lastAlertTime.get(alertKey);
    
    if (lastAlertTime && Date.now() - lastAlertTime < this.config.alertCooldown) {
      // We're in the cooldown period, don't trigger another alert
      return null;
    }
    
    // Add to history and notify listeners
    this.addToHistory(result);
    this.notifyListeners(result);
    
    // Update the last alert time
    this.lastAlertTime.set(alertKey, Date.now());
    
    return result;
  }
  
  /**
   * Check multiple metrics for regressions
   */
  public checkRegressions(
    metrics: Array<{ name: string; value: number; context?: string; }>
  ): RegressionResult[] {
    const results: RegressionResult[] = [];
    
    for (const metric of metrics) {
      const result = this.checkRegression(metric.name, metric.value, metric.context);
      if (result) {
        results.push(result);
      }
    }
    
    return results;
  }
  
  /**
   * Reset all baselines to their current values
   * Useful after a known change that impacts performance
   */
  public resetBaselines(): void {
    // Create a new map to avoid concurrent modification
    const newBaselines = new Map<string, BaselineMetric>();
    
    for (const [name, baseline] of this.baselines.entries()) {
      newBaselines.set(name, {
        name,
        value: baseline.value,
        timestamp: Date.now(),
        context: baseline.context
      });
    }
    
    this.baselines = newBaselines;
  }
  
  /**
   * Get the regression history
   */
  public getRegressionHistory(): RegressionResult[] {
    return [...this.regressionHistory];
  }
  
  /**
   * Clear the regression history
   */
  public clearRegressionHistory(): void {
    this.regressionHistory = [];
  }
  
  /**
   * Add a listener for regression events
   */
  public addListener(callback: (result: RegressionResult) => void): void {
    this.listeners.push(callback);
  }
  
  /**
   * Remove a listener
   */
  public removeListener(callback: (result: RegressionResult) => void): void {
    this.listeners = this.listeners.filter(listener => listener !== callback);
  }
  
  /**
   * Add a regression result to the history
   */
  private addToHistory(result: RegressionResult): void {
    this.regressionHistory.push(result);
    
    // Trim the history if needed
    if (this.regressionHistory.length > this.config.maxHistorySize) {
      this.regressionHistory = this.regressionHistory.slice(-this.config.maxHistorySize);
    }
  }
  
  /**
   * Notify listeners of a regression
   */
  private notifyListeners(result: RegressionResult): void {
    for (const listener of this.listeners) {
      try {
        listener(result);
      } catch (error) {
        console.error('Error in regression detector listener:', error);
      }
    }
  }
} 