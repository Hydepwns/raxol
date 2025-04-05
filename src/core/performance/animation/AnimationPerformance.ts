/**
 * AnimationPerformance.ts
 * 
 * Performance monitoring system for animations.
 * Tracks frame rates, jank, and animation timing.
 */

import { ViewPerformance } from '../ViewPerformance';

/**
 * Animation frame metrics
 */
export interface AnimationFrameMetrics {
  /**
   * Frame timestamp
   */
  timestamp: number;
  
  /**
   * Frame duration (ms)
   */
  duration: number;
  
  /**
   * Whether the frame was dropped
   */
  dropped: boolean;
  
  /**
   * Frame budget (ms)
   */
  budget: number;
  
  /**
   * Frame budget utilization (%)
   */
  utilization: number;
}

/**
 * Animation performance metrics
 */
export interface AnimationPerformanceMetrics {
  /**
   * Average frame rate (fps)
   */
  averageFrameRate: number;
  
  /**
   * Minimum frame rate (fps)
   */
  minFrameRate: number;
  
  /**
   * Maximum frame rate (fps)
   */
  maxFrameRate: number;
  
  /**
   * Frame drop rate (%)
   */
  frameDropRate: number;
  
  /**
   * Total frames
   */
  totalFrames: number;
  
  /**
   * Dropped frames
   */
  droppedFrames: number;
  
  /**
   * Average frame duration (ms)
   */
  averageFrameDuration: number;
  
  /**
   * Frame metrics history
   */
  frameHistory: AnimationFrameMetrics[];
  
  /**
   * Animation duration (ms)
   */
  duration: number;
}

/**
 * Animation performance options
 */
export interface AnimationPerformanceOptions {
  /**
   * Target frame rate (fps)
   */
  targetFrameRate?: number;
  
  /**
   * Frame budget (ms)
   */
  frameBudget?: number;
  
  /**
   * Maximum history size
   */
  maxHistorySize?: number;
  
  /**
   * Whether to record detailed frame history
   */
  recordFrameHistory?: boolean;
}

export class AnimationPerformance {
  private static instance: AnimationPerformance;
  private viewPerformance: ViewPerformance;
  private frameMetrics: AnimationFrameMetrics[] = [];
  private startTime: number = 0;
  private lastFrameTime: number = 0;
  private isMonitoring: boolean = false;
  private targetFrameRate: number = 60;
  private frameBudget: number = 16.67; // 1000ms / 60fps
  private maxHistorySize: number = 100;
  private recordFrameHistory: boolean = true;
  private animationId: number | null = null;

  private constructor() {
    this.viewPerformance = ViewPerformance.getInstance();
  }

  static getInstance(): AnimationPerformance {
    if (!AnimationPerformance.instance) {
      AnimationPerformance.instance = new AnimationPerformance();
    }
    return AnimationPerformance.instance;
  }

  /**
   * Configure animation performance monitoring
   */
  configure(options: AnimationPerformanceOptions = {}): void {
    this.targetFrameRate = options.targetFrameRate || 60;
    this.frameBudget = options.frameBudget || (1000 / this.targetFrameRate);
    this.maxHistorySize = options.maxHistorySize || 100;
    this.recordFrameHistory = options.recordFrameHistory !== false;
  }

  /**
   * Start animation performance monitoring
   */
  startMonitoring(): void {
    if (this.isMonitoring) return;
    
    this.isMonitoring = true;
    this.startTime = performance.now();
    this.lastFrameTime = this.startTime;
    this.frameMetrics = [];
    
    // Start the animation frame loop
    this.animationId = requestAnimationFrame(this.onAnimationFrame.bind(this));
  }

  /**
   * Stop animation performance monitoring
   */
  stopMonitoring(): void {
    this.isMonitoring = false;
    if (this.animationId !== null) {
      cancelAnimationFrame(this.animationId);
      this.animationId = null;
    }
  }

  /**
   * Animation frame callback
   */
  private onAnimationFrame(timestamp: number): void {
    if (!this.isMonitoring) return;
    
    // Calculate frame duration
    const frameDuration = timestamp - this.lastFrameTime;
    
    // Check if frame was dropped
    const dropped = frameDuration > this.frameBudget * 1.5;
    
    // Calculate frame budget utilization
    const utilization = Math.min(100, (frameDuration / this.frameBudget) * 100);
    
    // Create frame metrics
    const frameMetric: AnimationFrameMetrics = {
      timestamp,
      duration: frameDuration,
      dropped,
      budget: this.frameBudget,
      utilization
    };
    
    // Record frame metrics
    if (this.recordFrameHistory) {
      this.frameMetrics.push(frameMetric);
      
      // Trim history if needed
      if (this.frameMetrics.length > this.maxHistorySize) {
        this.frameMetrics = this.frameMetrics.slice(-this.maxHistorySize);
      }
    }
    
    // Update last frame time
    this.lastFrameTime = timestamp;
    
    // Continue animation frame loop
    this.animationId = requestAnimationFrame(this.onAnimationFrame.bind(this));
  }

  /**
   * Get animation performance metrics
   */
  getMetrics(): AnimationPerformanceMetrics {
    if (this.frameMetrics.length === 0) {
      return {
        averageFrameRate: 0,
        minFrameRate: 0,
        maxFrameRate: 0,
        frameDropRate: 0,
        totalFrames: 0,
        droppedFrames: 0,
        averageFrameDuration: 0,
        frameHistory: [],
        duration: 0
      };
    }
    
    // Calculate frame rates
    const frameRates = this.frameMetrics.map(m => 1000 / m.duration);
    const averageFrameRate = frameRates.reduce((sum, rate) => sum + rate, 0) / frameRates.length;
    const minFrameRate = Math.min(...frameRates);
    const maxFrameRate = Math.max(...frameRates);
    
    // Calculate dropped frames
    const droppedFrames = this.frameMetrics.filter(m => m.dropped).length;
    const frameDropRate = (droppedFrames / this.frameMetrics.length) * 100;
    
    // Calculate average frame duration
    const averageFrameDuration = this.frameMetrics.reduce((sum, m) => sum + m.duration, 0) / this.frameMetrics.length;
    
    // Calculate total duration
    const duration = this.frameMetrics[this.frameMetrics.length - 1].timestamp - this.startTime;
    
    return {
      averageFrameRate,
      minFrameRate,
      maxFrameRate,
      frameDropRate,
      totalFrames: this.frameMetrics.length,
      droppedFrames,
      averageFrameDuration,
      frameHistory: this.recordFrameHistory ? [...this.frameMetrics] : [],
      duration
    };
  }

  /**
   * Reset animation performance metrics
   */
  reset(): void {
    this.frameMetrics = [];
    this.startTime = performance.now();
    this.lastFrameTime = this.startTime;
  }
} 