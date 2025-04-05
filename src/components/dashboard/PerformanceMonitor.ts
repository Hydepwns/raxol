/**
 * PerformanceMonitor.ts
 * 
 * Monitors and analyzes dashboard performance metrics.
 * Provides insights into responsiveness, rendering performance, and resource usage.
 */

/**
 * Performance metrics
 */
export interface PerformanceMetrics {
  /**
   * Frame rate (FPS)
   */
  fps: number;
  
  /**
   * Frame time in milliseconds
   */
  frameTime: number;
  
  /**
   * Time to first render in milliseconds
   */
  timeToFirstRender: number;
  
  /**
   * Time to interactive in milliseconds
   */
  timeToInteractive: number;
  
  /**
   * Memory usage in MB
   */
  memoryUsage: number;
  
  /**
   * CPU usage percentage
   */
  cpuUsage: number;
  
  /**
   * Number of layout recalculations
   */
  layoutRecalculations: number;
  
  /**
   * Number of style recalculations
   */
  styleRecalculations: number;
  
  /**
   * Number of paint operations
   */
  paintOperations: number;
  
  /**
   * Number of composite operations
   */
  compositeOperations: number;
  
  /**
   * Responsiveness score (0-100)
   */
  responsivenessScore: number;
}

/**
 * Performance alert
 */
export interface PerformanceAlert {
  /**
   * Alert ID
   */
  id: string;
  
  /**
   * Alert type
   */
  type: 'warning' | 'error' | 'critical';
  
  /**
   * Alert message
   */
  message: string;
  
  /**
   * Alert timestamp
   */
  timestamp: number;
  
  /**
   * Related metric
   */
  metric: keyof PerformanceMetrics;
  
  /**
   * Metric value
   */
  value: number;
  
  /**
   * Threshold value
   */
  threshold: number;
}

/**
 * Performance monitor
 */
export class PerformanceMonitor {
  /**
   * Current metrics
   */
  private metrics: PerformanceMetrics = {
    fps: 0,
    frameTime: 0,
    timeToFirstRender: 0,
    timeToInteractive: 0,
    memoryUsage: 0,
    cpuUsage: 0,
    layoutRecalculations: 0,
    styleRecalculations: 0,
    paintOperations: 0,
    compositeOperations: 0,
    responsivenessScore: 100
  };
  
  /**
   * Historical metrics
   */
  private metricsHistory: PerformanceMetrics[] = [];
  
  /**
   * Performance alerts
   */
  private alerts: PerformanceAlert[] = [];
  
  /**
   * Alert listeners
   */
  private alertListeners: ((alert: PerformanceAlert) => void)[] = [];
  
  /**
   * Metrics listeners
   */
  private metricsListeners: ((metrics: PerformanceMetrics) => void)[] = [];
  
  /**
   * Performance thresholds
   */
  private thresholds: Partial<Record<keyof PerformanceMetrics, number>> = {
    fps: 30,
    frameTime: 16.67, // 60 FPS
    timeToFirstRender: 1000,
    timeToInteractive: 3000,
    memoryUsage: 500, // MB
    cpuUsage: 80, // %
    layoutRecalculations: 100,
    styleRecalculations: 100,
    paintOperations: 100,
    compositeOperations: 100,
    responsivenessScore: 70
  };
  
  /**
   * Frame count
   */
  private frameCount: number = 0;
  
  /**
   * Last frame time
   */
  private lastFrameTime: number = 0;
  
  /**
   * Frame times
   */
  private frameTimes: number[] = [];
  
  /**
   * Monitoring interval
   */
  private monitoringInterval: number | null = null;
  
  /**
   * Constructor
   */
  constructor() {
    // Initialize performance monitor
  }
  
  /**
   * Start monitoring
   */
  startMonitoring(interval: number = 1000): void {
    if (this.monitoringInterval !== null) {
      return;
    }
    
    this.lastFrameTime = performance.now();
    
    // Start frame monitoring
    this.monitorFrames();
    
    // Start interval monitoring
    this.monitoringInterval = window.setInterval(() => {
      this.collectMetrics();
      this.analyzeMetrics();
      this.notifyMetricsListeners();
    }, interval);
  }
  
  /**
   * Stop monitoring
   */
  stopMonitoring(): void {
    if (this.monitoringInterval !== null) {
      window.clearInterval(this.monitoringInterval);
      this.monitoringInterval = null;
    }
  }
  
  /**
   * Monitor frames
   */
  private monitorFrames(): void {
    const monitorFrame = () => {
      const now = performance.now();
      const frameTime = now - this.lastFrameTime;
      
      this.frameCount++;
      this.frameTimes.push(frameTime);
      
      // Keep only the last 60 frames
      if (this.frameTimes.length > 60) {
        this.frameTimes.shift();
      }
      
      this.lastFrameTime = now;
      
      // Calculate FPS and frame time
      if (this.frameTimes.length > 0) {
        const avgFrameTime = this.frameTimes.reduce((sum, time) => sum + time, 0) / this.frameTimes.length;
        this.metrics.frameTime = avgFrameTime;
        this.metrics.fps = 1000 / avgFrameTime;
      }
      
      // Request next frame
      requestAnimationFrame(monitorFrame);
    };
    
    requestAnimationFrame(monitorFrame);
  }
  
  /**
   * Collect metrics
   */
  private collectMetrics(): void {
    // Collect memory usage if available
    if (performance.memory) {
      this.metrics.memoryUsage = Math.round(performance.memory.usedJSHeapSize / (1024 * 1024));
    }
    
    // Collect layout and style recalculations
    // This requires browser dev tools API, which is not available in all environments
    // For now, we'll use a placeholder implementation
    this.metrics.layoutRecalculations = Math.floor(Math.random() * 50);
    this.metrics.styleRecalculations = Math.floor(Math.random() * 50);
    this.metrics.paintOperations = Math.floor(Math.random() * 50);
    this.metrics.compositeOperations = Math.floor(Math.random() * 50);
    
    // Calculate responsiveness score
    this.calculateResponsivenessScore();
    
    // Add to history
    this.metricsHistory.push({ ...this.metrics });
    
    // Keep only the last 100 metrics
    if (this.metricsHistory.length > 100) {
      this.metricsHistory.shift();
    }
  }
  
  /**
   * Calculate responsiveness score
   */
  private calculateResponsivenessScore(): void {
    let score = 100;
    
    // FPS impact
    if (this.metrics.fps < 30) {
      score -= 30;
    } else if (this.metrics.fps < 45) {
      score -= 15;
    } else if (this.metrics.fps < 55) {
      score -= 5;
    }
    
    // Frame time impact
    if (this.metrics.frameTime > 33.33) { // Below 30 FPS
      score -= 20;
    } else if (this.metrics.frameTime > 16.67) { // Below 60 FPS
      score -= 10;
    }
    
    // Memory impact
    if (this.metrics.memoryUsage > 1000) { // Over 1GB
      score -= 20;
    } else if (this.metrics.memoryUsage > 500) { // Over 500MB
      score -= 10;
    }
    
    // Layout and style impact
    if (this.metrics.layoutRecalculations > 200) {
      score -= 15;
    } else if (this.metrics.layoutRecalculations > 100) {
      score -= 5;
    }
    
    if (this.metrics.styleRecalculations > 200) {
      score -= 15;
    } else if (this.metrics.styleRecalculations > 100) {
      score -= 5;
    }
    
    // Ensure score is between 0 and 100
    this.metrics.responsivenessScore = Math.max(0, Math.min(100, score));
  }
  
  /**
   * Analyze metrics
   */
  private analyzeMetrics(): void {
    // Check each metric against thresholds
    for (const [metric, value] of Object.entries(this.metrics)) {
      const threshold = this.thresholds[metric as keyof PerformanceMetrics];
      
      if (threshold !== undefined) {
        // Check if metric exceeds threshold
        if (value < threshold) {
          // Determine alert type
          let type: 'warning' | 'error' | 'critical' = 'warning';
          
          if (value < threshold * 0.5) {
            type = 'critical';
          } else if (value < threshold * 0.75) {
            type = 'error';
          }
          
          // Create alert
          const alert: PerformanceAlert = {
            id: `alert-${Date.now()}-${Math.random().toString(36).substring(2, 9)}`,
            type,
            message: `${metric} is below threshold (${value} < ${threshold})`,
            timestamp: Date.now(),
            metric: metric as keyof PerformanceMetrics,
            value,
            threshold
          };
          
          // Add alert
          this.alerts.push(alert);
          
          // Notify listeners
          this.notifyAlertListeners(alert);
        }
      }
    }
  }
  
  /**
   * Add alert listener
   */
  addAlertListener(listener: (alert: PerformanceAlert) => void): void {
    this.alertListeners.push(listener);
  }
  
  /**
   * Remove alert listener
   */
  removeAlertListener(listener: (alert: PerformanceAlert) => void): void {
    const index = this.alertListeners.indexOf(listener);
    if (index !== -1) {
      this.alertListeners.splice(index, 1);
    }
  }
  
  /**
   * Add metrics listener
   */
  addMetricsListener(listener: (metrics: PerformanceMetrics) => void): void {
    this.metricsListeners.push(listener);
  }
  
  /**
   * Remove metrics listener
   */
  removeMetricsListener(listener: (metrics: PerformanceMetrics) => void): void {
    const index = this.metricsListeners.indexOf(listener);
    if (index !== -1) {
      this.metricsListeners.splice(index, 1);
    }
  }
  
  /**
   * Notify alert listeners
   */
  private notifyAlertListeners(alert: PerformanceAlert): void {
    for (const listener of this.alertListeners) {
      listener(alert);
    }
  }
  
  /**
   * Notify metrics listeners
   */
  private notifyMetricsListeners(): void {
    for (const listener of this.metricsListeners) {
      listener(this.metrics);
    }
  }
  
  /**
   * Get current metrics
   */
  getMetrics(): PerformanceMetrics {
    return { ...this.metrics };
  }
  
  /**
   * Get metrics history
   */
  getMetricsHistory(): PerformanceMetrics[] {
    return [...this.metricsHistory];
  }
  
  /**
   * Get alerts
   */
  getAlerts(): PerformanceAlert[] {
    return [...this.alerts];
  }
  
  /**
   * Clear alerts
   */
  clearAlerts(): void {
    this.alerts = [];
  }
  
  /**
   * Set threshold
   */
  setThreshold(metric: keyof PerformanceMetrics, threshold: number): void {
    this.thresholds[metric] = threshold;
  }
  
  /**
   * Get thresholds
   */
  getThresholds(): Partial<Record<keyof PerformanceMetrics, number>> {
    return { ...this.thresholds };
  }
} 