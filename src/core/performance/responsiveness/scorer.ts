/**
 * Responsiveness Scorer
 * 
 * Calculates responsiveness scores based on collected metrics.
 */

import { 
  ResponsivenessMetrics, 
  ResponsivenessScore, 
  ResponsivenessThresholds,
  DEFAULT_RESPONSIVENESS_THRESHOLDS,
  getPerformanceTier
} from './metrics';

/**
 * Configuration options for the responsiveness scorer
 */
export interface ResponsivenessScorerConfig {
  /**
   * Thresholds for different metrics
   */
  thresholds?: Partial<ResponsivenessThresholds>;
  
  /**
   * Weights for different metrics in the overall score calculation
   */
  weights?: {
    /**
     * Weight for input latency (default: 0.4)
     */
    inputLatency?: number;
    
    /**
     * Weight for time to interactive (default: 0.2)
     */
    timeToInteractive?: number;
    
    /**
     * Weight for frame drop rate (default: 0.2)
     */
    frameDropRate?: number;
    
    /**
     * Weight for event processing time (default: 0.1)
     */
    eventProcessingTime?: number;
    
    /**
     * Weight for gesture response time (default: 0.1)
     */
    gestureResponseTime?: number;
  };
  
  /**
   * Whether to use a logarithmic scale for score calculation
   * This is useful for metrics where small differences at the low end
   * are more important than larger differences at the high end
   * Default: true
   */
  useLogarithmicScale?: boolean;
}

/**
 * Default weights for different metrics
 */
const DEFAULT_WEIGHTS = {
  inputLatency: 0.4,
  timeToInteractive: 0.2,
  frameDropRate: 0.2,
  eventProcessingTime: 0.1,
  gestureResponseTime: 0.1
};

/**
 * Calculates responsiveness scores based on metrics
 */
export class ResponsivenessScorer {
  /**
   * Thresholds for different metrics
   */
  private thresholds: ResponsivenessThresholds;
  
  /**
   * Weights for different metrics
   */
  private weights: Required<Required<ResponsivenessScorerConfig>['weights']>;
  
  /**
   * Whether to use a logarithmic scale
   */
  private useLogarithmicScale: boolean;
  
  /**
   * Creates a new ResponsivenessScorer
   */
  constructor(config?: ResponsivenessScorerConfig) {
    this.thresholds = {
      ...DEFAULT_RESPONSIVENESS_THRESHOLDS,
      ...config?.thresholds
    };
    
    this.weights = {
      ...DEFAULT_WEIGHTS,
      ...config?.weights
    };
    
    this.useLogarithmicScale = config?.useLogarithmicScale ?? true;
  }
  
  /**
   * Calculate a responsiveness score for the given metrics
   */
  public calculateScore(metrics: ResponsivenessMetrics): ResponsivenessScore {
    // Calculate individual scores
    const inputLatencyScore = this.calculateInputLatencyScore(metrics.inputLatency);
    const ttiScore = this.calculateTTIScore(metrics.timeToInteractive);
    const frameDropScore = this.calculateFrameDropScore(metrics.frameDropRate);
    const eventProcessingScore = this.calculateEventProcessingScore(metrics.eventProcessingTime);
    
    // Calculate gesture response score if applicable
    let gestureResponseScore: number | undefined;
    if (metrics.gestureResponseTime !== undefined) {
      gestureResponseScore = this.calculateGestureResponseScore(metrics.gestureResponseTime);
    }
    
    // Calculate the weighted overall score
    let totalWeight = this.weights.inputLatency + this.weights.timeToInteractive + 
                      this.weights.frameDropRate + this.weights.eventProcessingTime;
    
    let overallScore = (
      inputLatencyScore * this.weights.inputLatency +
      ttiScore * this.weights.timeToInteractive +
      frameDropScore * this.weights.frameDropRate +
      eventProcessingScore * this.weights.eventProcessingTime
    );
    
    // Add gesture response score if available
    if (gestureResponseScore !== undefined) {
      overallScore += gestureResponseScore * this.weights.gestureResponseTime;
      totalWeight += this.weights.gestureResponseTime;
    }
    
    // Normalize by total weight
    overallScore = overallScore / totalWeight;
    
    // Ensure overall score is between 0-100
    overallScore = Math.max(0, Math.min(100, overallScore));
    
    // Determine performance tier
    const tier = getPerformanceTier(overallScore);
    
    return {
      overall: Math.round(overallScore * 10) / 10, // Round to 1 decimal place
      breakdown: {
        inputLatency: Math.round(inputLatencyScore),
        tti: Math.round(ttiScore),
        frameDrops: Math.round(frameDropScore),
        eventProcessing: Math.round(eventProcessingScore),
        ...(gestureResponseScore !== undefined ? { gestureResponse: Math.round(gestureResponseScore) } : {})
      },
      tier
    };
  }
  
  /**
   * Set custom thresholds for the scorer
   */
  public setThresholds(thresholds: Partial<ResponsivenessThresholds>): void {
    this.thresholds = {
      ...this.thresholds,
      ...thresholds
    };
  }
  
  /**
   * Set custom weights for the scorer
   */
  public setWeights(weights: Partial<Required<ResponsivenessScorerConfig>['weights']>): void {
    this.weights = {
      ...this.weights,
      ...weights
    };
  }
  
  /**
   * Calculate a score for input latency (0-100)
   * Lower latency is better
   */
  private calculateInputLatencyScore(inputLatency: number): number {
    const threshold = this.thresholds.inputLatency;
    return this.calculateMetricScore(inputLatency, threshold, true);
  }
  
  /**
   * Calculate a score for time to interactive (0-100)
   * Lower TTI is better
   */
  private calculateTTIScore(timeToInteractive: number): number {
    const threshold = this.thresholds.timeToInteractive;
    return this.calculateMetricScore(timeToInteractive, threshold, true);
  }
  
  /**
   * Calculate a score for frame drop rate (0-100)
   * Lower drop rate is better
   */
  private calculateFrameDropScore(frameDropRate: number): number {
    const threshold = this.thresholds.frameDropRate;
    return this.calculateMetricScore(frameDropRate, threshold, true);
  }
  
  /**
   * Calculate a score for event processing time (0-100)
   * Lower time is better
   */
  private calculateEventProcessingScore(eventProcessingTime: number): number {
    const threshold = this.thresholds.eventProcessingTime;
    return this.calculateMetricScore(eventProcessingTime, threshold, true);
  }
  
  /**
   * Calculate a score for gesture response time (0-100)
   * Lower time is better
   */
  private calculateGestureResponseScore(gestureResponseTime: number): number {
    const threshold = this.thresholds.gestureResponseTime;
    return this.calculateMetricScore(gestureResponseTime, threshold, true);
  }
  
  /**
   * Calculate a metric score using a logarithmic or linear scale
   * @param value The metric value
   * @param threshold The threshold for the metric
   * @param lowerIsBetter Whether a lower value is better (true) or a higher value is better (false)
   * @returns A score between 0 and 100
   */
  private calculateMetricScore(value: number, threshold: number, lowerIsBetter: boolean): number {
    // For metrics where lower is better:
    // - At 0, score should be 100
    // - At threshold, score should be 50
    // - At 2*threshold, score should be near 0
    //
    // For metrics where higher is better:
    // - At 2*threshold, score should be 100
    // - At threshold, score should be 50
    // - At 0, score should be 0
    
    if (lowerIsBetter) {
      // When lower is better (e.g., latency)
      if (value <= 0) {
        return 100; // Perfect score for 0 or negative (shouldn't happen)
      }
      
      if (this.useLogarithmicScale) {
        // Logarithmic scale for better sensitivity at lower values
        // Score = 100 - 50 * log(value / threshold) / log(2)
        const ratio = value / threshold;
        if (ratio <= 0) {
          return 100; // Avoid Math.log(0) or negative
        }
        
        const score = 100 - 50 * Math.log(ratio) / Math.log(2);
        return Math.max(0, Math.min(100, score));
      } else {
        // Linear scale
        // Score = 100 * (1 - value / (2 * threshold))
        const score = 100 * (1 - value / (2 * threshold));
        return Math.max(0, Math.min(100, score));
      }
    } else {
      // When higher is better (e.g., throughput)
      if (value >= 2 * threshold) {
        return 100; // Perfect score for 2x threshold or higher
      }
      
      if (this.useLogarithmicScale) {
        // Logarithmic scale
        // Score = 50 * (1 + log(value / threshold) / log(2))
        const ratio = value / threshold;
        if (ratio <= 0) {
          return 0; // Avoid Math.log(0) or negative
        }
        
        const score = 50 * (1 + Math.log(ratio) / Math.log(2));
        return Math.max(0, Math.min(100, score));
      } else {
        // Linear scale
        // Score = 50 * value / threshold
        const score = 50 * value / threshold;
        return Math.max(0, Math.min(100, score));
      }
    }
  }
} 