/**
 * PerformanceRegressionDetector.ts
 * 
 * Performance regression detection system for the View rendering system.
 * Helps identify when performance has degraded compared to baseline metrics.
 */

import { ViewPerformance } from '../ViewPerformance';
import { AnimationPerformance } from '../animation/AnimationPerformance';
import { PerformanceMetrics } from '../ViewPerformance';
import { AnimationPerformanceMetrics } from '../animation/AnimationPerformance';

export interface RegressionThresholds {
  memoryIncreasePercent?: number;
  renderTimeIncreasePercent?: number;
  fpsDecreasePercent?: number;
  frameDropRateIncreasePercent?: number;
  componentUpdateTimeIncreasePercent?: number;
}

export interface RegressionReport {
  hasRegressions: boolean;
  regressions: {
    memory?: {
      current: number;
      baseline: number;
      increasePercent: number;
      threshold: number;
    };
    renderTime?: {
      current: number;
      baseline: number;
      increasePercent: number;
      threshold: number;
    };
    fps?: {
      current: number;
      baseline: number;
      decreasePercent: number;
      threshold: number;
    };
    frameDropRate?: {
      current: number;
      baseline: number;
      increasePercent: number;
      threshold: number;
    };
    componentUpdateTime?: {
      current: number;
      baseline: number;
      increasePercent: number;
      threshold: number;
    };
  };
  recommendations: string[];
}

export class PerformanceRegressionDetector {
  private static instance: PerformanceRegressionDetector;
  private viewPerformance: ViewPerformance;
  private animationPerformance: AnimationPerformance;
  private baselineMetrics: PerformanceMetrics | null = null;
  private baselineAnimationMetrics: AnimationPerformanceMetrics | null = null;
  private thresholds: RegressionThresholds;

  private constructor(thresholds: RegressionThresholds = {}) {
    this.viewPerformance = ViewPerformance.getInstance();
    this.animationPerformance = AnimationPerformance.getInstance();
    this.thresholds = {
      memoryIncreasePercent: 20,
      renderTimeIncreasePercent: 15,
      fpsDecreasePercent: 10,
      frameDropRateIncreasePercent: 5,
      componentUpdateTimeIncreasePercent: 15,
      ...thresholds
    };
  }

  static getInstance(thresholds?: RegressionThresholds): PerformanceRegressionDetector {
    if (!PerformanceRegressionDetector.instance) {
      PerformanceRegressionDetector.instance = new PerformanceRegressionDetector(thresholds);
    }
    return PerformanceRegressionDetector.instance;
  }

  /**
   * Set baseline metrics for comparison
   */
  setBaseline(): void {
    this.baselineMetrics = this.viewPerformance.getMetrics();
    this.baselineAnimationMetrics = this.animationPerformance.getMetrics();
  }

  /**
   * Detect performance regressions compared to baseline
   */
  detectRegressions(): RegressionReport {
    if (!this.baselineMetrics || !this.baselineAnimationMetrics) {
      throw new Error('Baseline metrics not set. Call setBaseline() first.');
    }

    const currentMetrics = this.viewPerformance.getMetrics();
    const currentAnimationMetrics = this.animationPerformance.getMetrics();
    const regressions: RegressionReport['regressions'] = {};
    const recommendations: string[] = [];

    // Check memory usage
    if (this.baselineMetrics.memory && currentMetrics.memory) {
      const baselineUsed = this.baselineMetrics.memory.usedJSHeapSize;
      const currentUsed = currentMetrics.memory.usedJSHeapSize;
      const increasePercent = ((currentUsed - baselineUsed) / baselineUsed) * 100;

      if (increasePercent > (this.thresholds.memoryIncreasePercent || 0)) {
        regressions.memory = {
          current: currentUsed,
          baseline: baselineUsed,
          increasePercent,
          threshold: this.thresholds.memoryIncreasePercent || 0
        };
        recommendations.push(
          `Memory usage increased by ${increasePercent.toFixed(1)}%. ` +
          `Consider implementing memory optimizations or investigating memory leaks.`
        );
      }
    }

    // Check render time
    const baselineRenderTime = this.baselineMetrics.rendering.renderTime;
    const currentRenderTime = currentMetrics.rendering.renderTime;
    const renderTimeIncreasePercent = ((currentRenderTime - baselineRenderTime) / baselineRenderTime) * 100;

    if (renderTimeIncreasePercent > (this.thresholds.renderTimeIncreasePercent || 0)) {
      regressions.renderTime = {
        current: currentRenderTime,
        baseline: baselineRenderTime,
        increasePercent: renderTimeIncreasePercent,
        threshold: this.thresholds.renderTimeIncreasePercent || 0
      };
      recommendations.push(
        `Render time increased by ${renderTimeIncreasePercent.toFixed(1)}%. ` +
        `Consider optimizing render cycles or reducing component complexity.`
      );
    }

    // Check FPS
    const baselineFPS = this.baselineAnimationMetrics.averageFrameRate;
    const currentFPS = currentAnimationMetrics.averageFrameRate;
    const fpsDecreasePercent = ((baselineFPS - currentFPS) / baselineFPS) * 100;

    if (fpsDecreasePercent > (this.thresholds.fpsDecreasePercent || 0)) {
      regressions.fps = {
        current: currentFPS,
        baseline: baselineFPS,
        decreasePercent: fpsDecreasePercent,
        threshold: this.thresholds.fpsDecreasePercent || 0
      };
      recommendations.push(
        `FPS decreased by ${fpsDecreasePercent.toFixed(1)}%. ` +
        `Consider optimizing animations or reducing visual complexity.`
      );
    }

    // Check frame drop rate
    const baselineDropRate = this.baselineAnimationMetrics.frameDropRate;
    const currentDropRate = currentAnimationMetrics.frameDropRate;
    const dropRateIncreasePercent = ((currentDropRate - baselineDropRate) / baselineDropRate) * 100;

    if (dropRateIncreasePercent > (this.thresholds.frameDropRateIncreasePercent || 0)) {
      regressions.frameDropRate = {
        current: currentDropRate,
        baseline: baselineDropRate,
        increasePercent: dropRateIncreasePercent,
        threshold: this.thresholds.frameDropRateIncreasePercent || 0
      };
      recommendations.push(
        `Frame drop rate increased by ${dropRateIncreasePercent.toFixed(1)}%. ` +
        `Consider optimizing frame processing or reducing animation complexity.`
      );
    }

    // Check component update time
    const baselineUpdateTime = this.baselineMetrics.rendering.updateTime;
    const currentUpdateTime = currentMetrics.rendering.updateTime;
    const updateTimeIncreasePercent = ((currentUpdateTime - baselineUpdateTime) / baselineUpdateTime) * 100;

    if (updateTimeIncreasePercent > (this.thresholds.componentUpdateTimeIncreasePercent || 0)) {
      regressions.componentUpdateTime = {
        current: currentUpdateTime,
        baseline: baselineUpdateTime,
        increasePercent: updateTimeIncreasePercent,
        threshold: this.thresholds.componentUpdateTimeIncreasePercent || 0
      };
      recommendations.push(
        `Component update time increased by ${updateTimeIncreasePercent.toFixed(1)}%. ` +
        `Consider optimizing component updates or reducing update frequency.`
      );
    }

    return {
      hasRegressions: Object.keys(regressions).length > 0,
      regressions,
      recommendations
    };
  }

  /**
   * Compare two sets of metrics
   */
  static compareMetrics(baseline: PerformanceMetrics, current: PerformanceMetrics): RegressionReport {
    const detector = PerformanceRegressionDetector.getInstance();
    detector.baselineMetrics = baseline;
    return detector.detectRegressions();
  }
} 