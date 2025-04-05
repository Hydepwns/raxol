/**
 * PerformanceVisualizer.ts
 * 
 * Real-time performance visualization system for the View rendering system.
 * Provides visual feedback about performance metrics and helps identify bottlenecks.
 */

import { ViewPerformance } from '../ViewPerformance';
import { AnimationPerformance } from '../animation/AnimationPerformance';
import { PerformanceMetrics } from '../ViewPerformance';
import { AnimationPerformanceMetrics } from '../animation/AnimationPerformance';

export interface VisualizationOptions {
  updateInterval?: number; // milliseconds
  maxDataPoints?: number;
  showMemory?: boolean;
  showFPS?: boolean;
  showComponentMetrics?: boolean;
  showAnimationMetrics?: boolean;
}

export class PerformanceVisualizer {
  private static instance: PerformanceVisualizer;
  private viewPerformance: ViewPerformance;
  private animationPerformance: AnimationPerformance;
  private options: VisualizationOptions;
  private container: HTMLElement | null = null;
  private updateInterval: number | null = null;
  private dataPoints: PerformanceMetrics[] = [];
  private animationDataPoints: AnimationPerformanceMetrics[] = [];

  private constructor(options: VisualizationOptions = {}) {
    this.viewPerformance = ViewPerformance.getInstance();
    this.animationPerformance = AnimationPerformance.getInstance();
    this.options = {
      updateInterval: 1000,
      maxDataPoints: 60,
      showMemory: true,
      showFPS: true,
      showComponentMetrics: true,
      showAnimationMetrics: true,
      ...options
    };
  }

  static getInstance(options?: VisualizationOptions): PerformanceVisualizer {
    if (!PerformanceVisualizer.instance) {
      PerformanceVisualizer.instance = new PerformanceVisualizer(options);
    }
    return PerformanceVisualizer.instance;
  }

  /**
   * Show the performance visualization overlay
   */
  showOverlay(): void {
    if (this.container) return;

    // Create container
    this.container = document.createElement('div');
    this.container.style.cssText = `
      position: fixed;
      top: 10px;
      right: 10px;
      background: rgba(0, 0, 0, 0.8);
      color: #fff;
      padding: 10px;
      border-radius: 4px;
      font-family: monospace;
      font-size: 12px;
      z-index: 9999;
      max-width: 300px;
      max-height: 400px;
      overflow: auto;
    `;

    // Add to document
    document.body.appendChild(this.container);

    // Start update interval
    this.startUpdates();
  }

  /**
   * Hide the performance visualization overlay
   */
  hideOverlay(): void {
    if (this.container) {
      this.container.remove();
      this.container = null;
    }
    this.stopUpdates();
  }

  /**
   * Start periodic updates
   */
  private startUpdates(): void {
    if (this.updateInterval) return;

    this.updateInterval = window.setInterval(() => {
      this.updateVisualization();
    }, this.options.updateInterval);
  }

  /**
   * Stop periodic updates
   */
  private stopUpdates(): void {
    if (this.updateInterval) {
      clearInterval(this.updateInterval);
      this.updateInterval = null;
    }
  }

  /**
   * Update the visualization with current metrics
   */
  private updateVisualization(): void {
    if (!this.container) return;

    const metrics = this.viewPerformance.getMetrics();
    const animationMetrics = this.animationPerformance.getMetrics();

    // Update data points
    this.dataPoints.push(metrics);
    this.animationDataPoints.push(animationMetrics);

    // Trim data points if needed
    if (this.dataPoints.length > this.options.maxDataPoints!) {
      this.dataPoints = this.dataPoints.slice(-this.options.maxDataPoints!);
    }
    if (this.animationDataPoints.length > this.options.maxDataPoints!) {
      this.animationDataPoints = this.animationDataPoints.slice(-this.options.maxDataPoints!);
    }

    // Update visualization
    this.renderMetrics(metrics, animationMetrics);
  }

  /**
   * Render the current metrics
   */
  private renderMetrics(metrics: PerformanceMetrics, animationMetrics: AnimationPerformanceMetrics): void {
    if (!this.container) return;

    let html = '<div style="margin-bottom: 10px;">';

    // Memory usage
    if (this.options.showMemory && metrics.memory) {
      const usedMB = Math.round(metrics.memory.usedJSHeapSize / 1024 / 1024);
      const totalMB = Math.round(metrics.memory.totalJSHeapSize / 1024 / 1024);
      const limitMB = Math.round(metrics.memory.jsHeapSizeLimit / 1024 / 1024);
      
      html += `
        <div style="margin-bottom: 5px;">
          <strong>Memory:</strong><br>
          Used: ${usedMB}MB / ${totalMB}MB<br>
          Limit: ${limitMB}MB
        </div>
      `;
    }

    // FPS
    if (this.options.showFPS) {
      html += `
        <div style="margin-bottom: 5px;">
          <strong>FPS:</strong> ${Math.round(animationMetrics.averageFrameRate)}<br>
          Min: ${Math.round(animationMetrics.minFrameRate)}<br>
          Max: ${Math.round(animationMetrics.maxFrameRate)}<br>
          Dropped: ${animationMetrics.droppedFrames} frames
        </div>
      `;
    }

    // Component metrics
    if (this.options.showComponentMetrics) {
      const componentMetrics = this.viewPerformance.getAllComponentMetrics();
      if (componentMetrics.length > 0) {
        html += `
          <div style="margin-bottom: 5px;">
            <strong>Components:</strong><br>
            ${componentMetrics.map(m => `
              ${m.type}: ${Math.round(m.renderTime)}ms render, ${m.updateCount} updates
            `).join('<br>')}
          </div>
        `;
      }
    }

    // Animation metrics
    if (this.options.showAnimationMetrics) {
      html += `
        <div style="margin-bottom: 5px;">
          <strong>Animation:</strong><br>
          Frame Duration: ${Math.round(animationMetrics.averageFrameDuration)}ms<br>
          Drop Rate: ${animationMetrics.frameDropRate.toFixed(1)}%
        </div>
      `;
    }

    html += '</div>';
    this.container.innerHTML = html;
  }
} 