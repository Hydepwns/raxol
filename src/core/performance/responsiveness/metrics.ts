/**
 * Responsiveness Metrics
 * 
 * Defines the core metrics used for measuring application responsiveness.
 */

/**
 * Represents a set of responsiveness metrics
 */
export interface ResponsivenessMetrics {
  /**
   * Time from input event to first visual response (ms)
   */
  inputLatency: number;
  
  /**
   * Time until the component becomes fully interactive (ms)
   */
  timeToInteractive: number;
  
  /**
   * Percentage of dropped frames during interaction (0-100)
   */
  frameDropRate: number;
  
  /**
   * Average time to process an event (ms)
   */
  eventProcessingTime: number;
  
  /**
   * Time to complete a gesture (ms) - e.g., drag, swipe
   */
  gestureResponseTime?: number;
  
  /**
   * Additional context information about the interaction
   */
  context?: {
    /**
     * Type of interaction (e.g., click, drag, keypress)
     */
    interactionType: string;
    
    /**
     * Component that was interacted with
     */
    componentId: string;
    
    /**
     * Timestamp when the interaction started
     */
    timestamp: number;
    
    /**
     * Additional metadata about the interaction
     */
    metadata?: Record<string, any>;
  };
}

/**
 * Result of responsiveness score calculation
 */
export interface ResponsivenessScore {
  /**
   * Overall responsiveness score (0-100)
   * Higher is better.
   */
  overall: number;
  
  /**
   * Breakdown of individual metric scores
   */
  breakdown: {
    /**
     * Input latency score (0-100)
     */
    inputLatency: number;
    
    /**
     * Time to interactive score (0-100)
     */
    tti: number;
    
    /**
     * Frame drop rate score (0-100)
     */
    frameDrops: number;
    
    /**
     * Event processing score (0-100)
     */
    eventProcessing: number;
    
    /**
     * Gesture response score (0-100), if applicable
     */
    gestureResponse?: number;
  };
  
  /**
   * Performance tiers based on the score
   * - Excellent: 90-100
   * - Good: 75-89
   * - Fair: 50-74
   * - Poor: 25-49
   * - Critical: 0-24
   */
  tier: 'excellent' | 'good' | 'fair' | 'poor' | 'critical';
}

/**
 * Thresholds for responsiveness metrics
 */
export interface ResponsivenessThresholds {
  /**
   * Threshold for input latency in ms
   * Default: 100ms (based on RAIL model)
   */
  inputLatency: number;
  
  /**
   * Threshold for time to interactive in ms
   * Default: 300ms
   */
  timeToInteractive: number;
  
  /**
   * Threshold for frame drop rate as percentage
   * Default: 5% (3 frames in 60)
   */
  frameDropRate: number;
  
  /**
   * Threshold for event processing time in ms
   * Default: 50ms
   */
  eventProcessingTime: number;
  
  /**
   * Threshold for gesture response time in ms
   * Default: 200ms
   */
  gestureResponseTime: number;
}

/**
 * Default thresholds for responsiveness metrics
 */
export const DEFAULT_RESPONSIVENESS_THRESHOLDS: ResponsivenessThresholds = {
  inputLatency: 100, // 100ms
  timeToInteractive: 300, // 300ms
  frameDropRate: 5, // 5%
  eventProcessingTime: 50, // 50ms
  gestureResponseTime: 200 // 200ms
};

/**
 * Helper function to determine performance tier based on overall score
 */
export function getPerformanceTier(score: number): 'excellent' | 'good' | 'fair' | 'poor' | 'critical' {
  if (score >= 90) return 'excellent';
  if (score >= 75) return 'good';
  if (score >= 50) return 'fair';
  if (score >= 25) return 'poor';
  return 'critical';
} 