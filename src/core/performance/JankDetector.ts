/**
 * JankDetector.ts
 * 
 * Provides tools for detecting and analyzing UI jank (frame drops and stutters)
 * to help identify and resolve visual performance issues that affect user experience.
 */

export interface JankOptions {
  /** Target frame rate to maintain (default: 60fps) */
  targetFps?: number;
  
  /** Threshold below which frames are considered dropped (default: 50% of target) */
  dropThreshold?: number;
  
  /** How many consecutive dropped frames constitute a stutter (default: 2) */
  stutterThreshold?: number;
  
  /** Time window for jank analysis in ms (default: 5000ms) */
  analysisWindow?: number;
  
  /** Whether to automatically start monitoring on creation (default: false) */
  autoStart?: boolean;
  
  /** Callback when a jank event is detected */
  onJankDetected?: (event: JankEvent) => void;
}

export interface JankEvent {
  /** When the jank occurred */
  timestamp: number;
  
  /** Duration of the jank in ms */
  duration: number;
  
  /** How many frames were dropped */
  droppedFrames: number;
  
  /** Current fps at time of jank */
  currentFps: number;
  
  /** Severity level of the jank */
  severity: 'minor' | 'moderate' | 'severe';
  
  /** Additional context about what was happening (if provided) */
  context?: Record<string, any>;
}

export interface JankReport {
  /** Total number of frames analyzed */
  totalFrames: number;
  
  /** Average FPS over the analysis period */
  averageFps: number;
  
  /** 95th percentile frame time in ms */
  p95FrameTime: number;
  
  /** Percentage of frames that were on time */
  frameSuccessRate: number;
  
  /** Total number of jank events detected */
  jankEventCount: number;
  
  /** Percentage of time spent in jank */
  jankPercentage: number;
  
  /** List of detected jank events */
  jankEvents: JankEvent[];
  
  /** Timestamp when report was generated */
  timestamp: number;
  
  /** Duration of the analysis period in ms */
  analysisPeriod: number;
}

export class JankDetector {
  private options: Required<JankOptions>;
  private isMonitoring: boolean = false;
  private frameHistory: Array<{ timestamp: number, frameDuration: number }> = [];
  private jankEvents: JankEvent[] = [];
  private animationFrameId: number | null = null;
  private lastFrameTimestamp: number | null = null;
  private currentContext: Record<string, any> = {};
  
  constructor(options: JankOptions = {}) {
    this.options = {
      targetFps: options.targetFps ?? 60,
      dropThreshold: options.dropThreshold ?? 0.5,
      stutterThreshold: options.stutterThreshold ?? 2,
      analysisWindow: options.analysisWindow ?? 5000,
      autoStart: options.autoStart ?? false,
      onJankDetected: options.onJankDetected ?? (() => {})
    };
    
    if (this.options.autoStart) {
      this.startMonitoring();
    }
  }
  
  /**
   * Start monitoring for jank
   */
  public startMonitoring(): void {
    if (this.isMonitoring) return;
    
    this.isMonitoring = true;
    this.frameHistory = [];
    this.jankEvents = [];
    this.lastFrameTimestamp = null;
    this.scheduleNextFrame();
  }
  
  /**
   * Stop monitoring for jank
   */
  public stopMonitoring(): void {
    if (!this.isMonitoring) return;
    
    this.isMonitoring = false;
    if (this.animationFrameId !== null) {
      cancelAnimationFrame(this.animationFrameId);
      this.animationFrameId = null;
    }
  }
  
  /**
   * Set context information for the current user flow
   * This helps correlate jank events with specific user actions
   */
  public setContext(context: Record<string, any>): void {
    this.currentContext = { ...context };
  }
  
  /**
   * Clear the current context
   */
  public clearContext(): void {
    this.currentContext = {};
  }
  
  /**
   * Add additional context data
   */
  public addContext(key: string, value: any): void {
    this.currentContext[key] = value;
  }
  
  /**
   * Get the current jank report
   */
  public getJankReport(): JankReport {
    const now = performance.now();
    const frameTimes = this.frameHistory.map(frame => frame.frameDuration);
    
    // Sort frame times for percentile calculation
    const sortedFrameTimes = [...frameTimes].sort((a, b) => a - b);
    
    // Calculate average FPS from frame times
    const avgFrameTime = frameTimes.length > 0 
      ? frameTimes.reduce((sum, time) => sum + time, 0) / frameTimes.length 
      : 0;
    const averageFps = avgFrameTime > 0 ? 1000 / avgFrameTime : this.options.targetFps;
    
    // Calculate 95th percentile frame time
    const p95Index = Math.floor(sortedFrameTimes.length * 0.95);
    const p95FrameTime = sortedFrameTimes.length > 0 ? sortedFrameTimes[p95Index] || 0 : 0;
    
    // Calculate frame success rate (percentage of frames that were fast enough)
    const targetFrameTime = 1000 / this.options.targetFps;
    const successfulFrames = frameTimes.filter(time => time <= targetFrameTime * (1 + this.options.dropThreshold));
    const frameSuccessRate = frameTimes.length > 0 
      ? (successfulFrames.length / frameTimes.length) * 100 
      : 100;
    
    // Calculate percentage of time spent in jank
    const totalAnalysisTime = this.frameHistory.length > 0 
      ? now - this.frameHistory[0].timestamp 
      : 0;
    const totalJankTime = this.jankEvents.reduce((sum, event) => sum + event.duration, 0);
    const jankPercentage = totalAnalysisTime > 0 
      ? (totalJankTime / totalAnalysisTime) * 100 
      : 0;
    
    return {
      totalFrames: this.frameHistory.length,
      averageFps,
      p95FrameTime,
      frameSuccessRate,
      jankEventCount: this.jankEvents.length,
      jankPercentage,
      jankEvents: [...this.jankEvents],
      timestamp: now,
      analysisPeriod: totalAnalysisTime
    };
  }
  
  /**
   * Clear all recorded jank data
   */
  public clearJankData(): void {
    this.frameHistory = [];
    this.jankEvents = [];
  }
  
  /**
   * Force a significant jank event for testing
   */
  public simulateJank(duration: number = 500): void {
    const start = performance.now();
    while (performance.now() - start < duration) {
      // Busy wait to block the main thread
      const dummy = Math.random() * 1000;
    }
  }
  
  /**
   * Schedule the next animation frame
   */
  private scheduleNextFrame(): void {
    if (!this.isMonitoring) return;
    
    this.animationFrameId = requestAnimationFrame(this.onAnimationFrame.bind(this));
  }
  
  /**
   * Process an animation frame
   */
  private onAnimationFrame(timestamp: number): void {
    if (this.lastFrameTimestamp !== null) {
      const frameDuration = timestamp - this.lastFrameTimestamp;
      
      // Record frame time
      this.frameHistory.push({
        timestamp,
        frameDuration
      });
      
      // Check for dropped frames
      this.detectJank(timestamp, frameDuration);
      
      // Prune old frame history
      this.pruneHistory(timestamp);
    }
    
    this.lastFrameTimestamp = timestamp;
    this.scheduleNextFrame();
  }
  
  /**
   * Detect jank based on frame duration
   */
  private detectJank(timestamp: number, frameDuration: number): void {
    const targetFrameDuration = 1000 / this.options.targetFps;
    const dropThreshold = targetFrameDuration * (1 + this.options.dropThreshold);
    
    if (frameDuration > dropThreshold) {
      // Calculate how many frames were effectively dropped
      const droppedFrames = Math.floor(frameDuration / targetFrameDuration) - 1;
      
      if (droppedFrames >= this.options.stutterThreshold) {
        // Calculate FPS during the jank
        const currentFps = 1000 / frameDuration;
        
        // Determine severity
        let severity: 'minor' | 'moderate' | 'severe' = 'minor';
        if (droppedFrames >= 5) {
          severity = 'severe';
        } else if (droppedFrames >= 3) {
          severity = 'moderate';
        }
        
        // Create jank event
        const jankEvent: JankEvent = {
          timestamp,
          duration: frameDuration,
          droppedFrames,
          currentFps,
          severity,
          context: { ...this.currentContext }
        };
        
        this.jankEvents.push(jankEvent);
        
        // Notify listener if set
        if (this.options.onJankDetected) {
          this.options.onJankDetected(jankEvent);
        }
      }
    }
  }
  
  /**
   * Remove frame history older than the analysis window
   */
  private pruneHistory(currentTimestamp: number): void {
    const cutoffTime = currentTimestamp - this.options.analysisWindow;
    
    // Prune frame history
    this.frameHistory = this.frameHistory.filter(frame => frame.timestamp >= cutoffTime);
    
    // Prune jank events
    this.jankEvents = this.jankEvents.filter(event => event.timestamp >= cutoffTime);
  }
} 