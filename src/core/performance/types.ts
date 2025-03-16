/**
 * Performance monitoring and optimization types
 */

/**
 * Memory usage metrics
 */
export interface MemoryUsage {
  /**
   * Used memory (MB or %)
   */
  used: number;
  
  /**
   * Total available memory (MB)
   */
  total: number;
  
  /**
   * Memory limit if applicable (MB)
   */
  limit?: number;
}

/**
 * CPU usage metrics
 */
export interface CpuUsage {
  /**
   * CPU usage (%)
   */
  usage: number;
  
  /**
   * Number of CPU cores
   */
  cores: number;
}

/**
 * GPU usage metrics
 */
export interface GpuUsage {
  /**
   * GPU usage (%)
   */
  usage: number;
  
  /**
   * GPU memory usage
   */
  memory: {
    /**
     * Used GPU memory (MB)
     */
    used: number;
    
    /**
     * Total GPU memory (MB)
     */
    total: number;
  };
}

/**
 * Resource usage metrics
 */
export interface ResourceUsage {
  /**
   * Memory usage metrics
   */
  memory: MemoryUsage;
  
  /**
   * CPU usage metrics
   */
  cpu: CpuUsage;
  
  /**
   * GPU usage metrics if available
   */
  gpu?: GpuUsage;
}

/**
 * Component rendering metrics
 */
export interface ComponentMetrics {
  /**
   * Time to render (ms)
   */
  renderTime: number;
  
  /**
   * Number of times the component has re-rendered
   */
  updateCount: number;
  
  /**
   * Number of instances of this component
   */
  instanceCount: number;
  
  /**
   * Timestamp of last render
   */
  lastRenderTimestamp: number;
  
  /**
   * Additional component-specific metrics
   */
  [key: string]: any;
}

/**
 * Event metrics
 */
export interface EventMetrics {
  /**
   * Event type
   */
  type: string;
  
  /**
   * Event handler execution time (ms)
   */
  handlerTime: number;
  
  /**
   * Frequency of this event type (events per minute)
   */
  frequency: number;
}

/**
 * Network request metrics
 */
export interface NetworkRequestMetrics {
  /**
   * Request URL or endpoint
   */
  url: string;
  
  /**
   * Total request time (ms)
   */
  totalTime: number;
  
  /**
   * Time to first byte (ms)
   */
  ttfb?: number;
  
  /**
   * Download time (ms)
   */
  downloadTime?: number;
  
  /**
   * Response size (bytes)
   */
  responseSize: number;
  
  /**
   * HTTP status code
   */
  statusCode: number;
  
  /**
   * Whether the request was successful
   */
  success: boolean;
}

/**
 * Performance recommendation
 */
export interface PerformanceRecommendation {
  /**
   * Recommendation type
   */
  type: string;
  
  /**
   * Recommendation description
   */
  description: string;
  
  /**
   * Estimated impact (0-100)
   */
  impact: number;
  
  /**
   * Ease of implementation (0-100, higher is easier)
   */
  ease: number;
}

/**
 * Performance score
 */
export interface PerformanceScore {
  /**
   * Overall performance score (0-100)
   */
  overall: number;
  
  /**
   * Rendering performance score (0-100)
   */
  rendering: number;
  
  /**
   * Memory usage score (0-100)
   */
  memory: number;
  
  /**
   * Network performance score (0-100)
   */
  network: number;
  
  /**
   * Responsiveness score (0-100)
   */
  responsiveness: number;
}

/**
 * Performance optimization result
 */
export interface OptimizationResult {
  /**
   * Optimization applied
   */
  optimization: string;
  
  /**
   * Whether the optimization was successful
   */
  success: boolean;
  
  /**
   * Measured improvement (%)
   */
  improvement?: number;
  
  /**
   * Error message if optimization failed
   */
  error?: string;
} 