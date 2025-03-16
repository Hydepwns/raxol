/**
 * JankVisualizer.ts
 * 
 * Provides visualization tools for jank data collected by the JankDetector,
 * helping developers identify and analyze UI performance issues.
 */

import { JankDetector, JankEvent, JankReport } from './JankDetector';

export interface JankVisualizerOptions {
  /** Container element where the visualizer will be rendered */
  container: HTMLElement;
  
  /** JankDetector instance to visualize data from */
  jankDetector: JankDetector;
  
  /** How often to update the visualization in ms (default: 500) */
  updateInterval?: number;
  
  /** Maximum number of frames to display in the timeline (default: 300) */
  maxFrames?: number;
  
  /** Style settings for the visualizer */
  styles?: {
    backgroundColor?: string;
    textColor?: string;
    gridColor?: string;
    frameBarColor?: string;
    jankBarColors?: {
      minor: string;
      moderate: string;
      severe: string;
    };
  };
}

export class JankVisualizer {
  private options: Required<JankVisualizerOptions> & {
    styles: Required<Required<JankVisualizerOptions>['styles']> & {
      jankBarColors: Required<Required<JankVisualizerOptions>['styles']>['jankBarColors']
    }
  };
  private container: HTMLElement;
  private jankDetector: JankDetector;
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private updateIntervalId: number | null = null;
  private isDestroyed: boolean = false;
  
  constructor(options: JankVisualizerOptions) {
    // Apply default options
    this.options = {
      container: options.container,
      jankDetector: options.jankDetector,
      updateInterval: options.updateInterval ?? 500,
      maxFrames: options.maxFrames ?? 300,
      styles: {
        backgroundColor: options.styles?.backgroundColor ?? '#262626',
        textColor: options.styles?.textColor ?? '#e0e0e0',
        gridColor: options.styles?.gridColor ?? '#404040',
        frameBarColor: options.styles?.frameBarColor ?? '#4CAF50',
        jankBarColors: {
          minor: options.styles?.jankBarColors?.minor ?? '#FFC107',
          moderate: options.styles?.jankBarColors?.moderate ?? '#FF9800',
          severe: options.styles?.jankBarColors?.severe ?? '#F44336'
        }
      }
    };
    
    this.container = this.options.container;
    this.jankDetector = this.options.jankDetector;
    
    // Create canvas
    this.canvas = document.createElement('canvas');
    this.canvas.width = this.container.clientWidth;
    this.canvas.height = this.container.clientHeight;
    this.canvas.style.width = '100%';
    this.canvas.style.height = '100%';
    
    // Get rendering context
    const ctx = this.canvas.getContext('2d');
    if (!ctx) {
      throw new Error('Could not get 2D rendering context');
    }
    this.ctx = ctx;
    
    // Append canvas to container
    this.container.appendChild(this.canvas);
    
    // Handle resize
    window.addEventListener('resize', this.handleResize.bind(this));
    
    // Initial render
    this.render();
  }
  
  /**
   * Start automatic updates
   */
  public start(): void {
    if (this.updateIntervalId !== null) return;
    
    this.updateIntervalId = window.setInterval(() => {
      this.render();
    }, this.options.updateInterval);
  }
  
  /**
   * Stop automatic updates
   */
  public stop(): void {
    if (this.updateIntervalId === null) return;
    
    window.clearInterval(this.updateIntervalId);
    this.updateIntervalId = null;
  }
  
  /**
   * Force a manual update
   */
  public update(): void {
    this.render();
  }
  
  /**
   * Destroy the visualizer and clean up resources
   */
  public destroy(): void {
    if (this.isDestroyed) return;
    
    this.stop();
    window.removeEventListener('resize', this.handleResize.bind(this));
    
    if (this.canvas.parentNode) {
      this.canvas.parentNode.removeChild(this.canvas);
    }
    
    this.isDestroyed = true;
  }
  
  /**
   * Handle window resize
   */
  private handleResize(): void {
    this.canvas.width = this.container.clientWidth;
    this.canvas.height = this.container.clientHeight;
    this.render();
  }
  
  /**
   * Render the visualization
   */
  private render(): void {
    const report = this.jankDetector.getJankReport();
    const { width, height } = this.canvas;
    
    // Clear canvas
    this.ctx.fillStyle = this.options.styles.backgroundColor;
    this.ctx.fillRect(0, 0, width, height);
    
    this.renderMetrics(report, width, height);
    this.renderFrameTimeline(report, width, height);
    this.renderJankEvents(report, width, height);
  }
  
  /**
   * Render general metrics
   */
  private renderMetrics(report: JankReport, width: number, height: number): void {
    const { ctx, options } = this;
    const padding = 15;
    
    ctx.fillStyle = options.styles.textColor;
    ctx.font = '14px monospace';
    ctx.textBaseline = 'top';
    
    // Draw FPS metrics
    ctx.fillText(`FPS: ${report.averageFps.toFixed(1)}`, padding, padding);
    ctx.fillText(`Frame success: ${report.frameSuccessRate.toFixed(1)}%`, padding, padding + 20);
    ctx.fillText(`P95 frame time: ${report.p95FrameTime.toFixed(2)}ms`, padding, padding + 40);
    ctx.fillText(`Jank events: ${report.jankEventCount}`, padding, padding + 60);
    ctx.fillText(`Jank %: ${report.jankPercentage.toFixed(1)}%`, padding, padding + 80);
    
    // Draw target FPS line
    const targetFrameTime = 1000 / (options.jankDetector as any).options.targetFps;
    ctx.fillText(`Target: ${(options.jankDetector as any).options.targetFps} FPS (${targetFrameTime.toFixed(2)}ms)`, width - 200, padding);
  }
  
  /**
   * Render frame timeline
   */
  private renderFrameTimeline(report: JankReport, width: number, height: number): void {
    const { ctx, options } = this;
    
    // Calculate dimensions
    const timelineHeight = height * 0.3;
    const timelineTop = height * 0.25;
    const timelineBottom = timelineTop + timelineHeight;
    const padding = 40;
    const timelineWidth = width - (padding * 2);
    
    // Draw timeline background
    ctx.fillStyle = options.styles.backgroundColor;
    ctx.fillRect(padding, timelineTop, timelineWidth, timelineHeight);
    
    // Draw grid
    ctx.strokeStyle = options.styles.gridColor;
    ctx.lineWidth = 1;
    
    // Horizontal grid lines
    const gridLines = 5;
    for (let i = 0; i <= gridLines; i++) {
      const y = timelineTop + (timelineHeight * (i / gridLines));
      
      ctx.beginPath();
      ctx.moveTo(padding, y);
      ctx.lineTo(width - padding, y);
      ctx.stroke();
      
      // Draw labels for ms
      const msValue = ((gridLines - i) / gridLines) * 100; // Max 100ms
      ctx.fillStyle = options.styles.textColor;
      ctx.font = '10px monospace';
      ctx.textBaseline = 'middle';
      ctx.textAlign = 'right';
      ctx.fillText(`${msValue.toFixed(0)}ms`, padding - 5, y);
    }
    
    // Get frame data
    const frameHistory = (this.jankDetector as any).frameHistory || [];
    if (!frameHistory || frameHistory.length === 0) return;
    
    // Draw frame bars
    const barCount = Math.min(frameHistory.length, options.maxFrames);
    const barWidth = timelineWidth / barCount;
    
    // Calculate target frame time
    const targetFrameTime = 1000 / (options.jankDetector as any).options.targetFps;
    const targetY = timelineTop + timelineHeight - (timelineHeight * Math.min(targetFrameTime / 100, 1));
    
    // Draw target frame time line
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.5)';
    ctx.lineWidth = 1;
    ctx.setLineDash([5, 3]);
    ctx.beginPath();
    ctx.moveTo(padding, targetY);
    ctx.lineTo(width - padding, targetY);
    ctx.stroke();
    ctx.setLineDash([]);
    
    // Draw frame bars
    for (let i = 0; i < barCount; i++) {
      const frame = frameHistory[frameHistory.length - barCount + i];
      const x = padding + (i * barWidth);
      
      // Map frame time to height (cap at 100ms for scaling)
      const frameTime = Math.min(frame.frameDuration, 100);
      const barHeight = (frameTime / 100) * timelineHeight;
      const y = timelineBottom - barHeight;
      
      // Color based on whether it's a jank frame
      const isJank = frame.frameDuration > targetFrameTime * (1 + (options.jankDetector as any).options.dropThreshold);
      
      if (isJank) {
        // Determine severity
        const droppedFrames = Math.floor(frame.frameDuration / targetFrameTime) - 1;
        let color = options.styles.jankBarColors.minor;
        
        if (droppedFrames >= 5) {
          color = options.styles.jankBarColors.severe;
        } else if (droppedFrames >= 3) {
          color = options.styles.jankBarColors.moderate;
        }
        
        ctx.fillStyle = color;
      } else {
        ctx.fillStyle = options.styles.frameBarColor;
      }
      
      ctx.fillRect(x, y, barWidth - 1, barHeight);
    }
  }
  
  /**
   * Render jank events
   */
  private renderJankEvents(report: JankReport, width: number, height: number): void {
    const { ctx, options } = this;
    const padding = 15;
    const eventsTop = height * 0.65;
    const eventRowHeight = 20;
    
    // Title
    ctx.fillStyle = options.styles.textColor;
    ctx.font = 'bold 14px monospace';
    ctx.textBaseline = 'top';
    ctx.fillText('Recent Jank Events:', padding, eventsTop);
    
    // Display up to 10 most recent jank events
    const recentEvents = [...report.jankEvents]
      .sort((a, b) => b.timestamp - a.timestamp)
      .slice(0, 10);
    
    ctx.font = '12px monospace';
    
    for (let i = 0; i < recentEvents.length; i++) {
      const event = recentEvents[i];
      const y = eventsTop + 25 + (i * eventRowHeight);
      
      // Set color based on severity
      switch (event.severity) {
        case 'severe':
          ctx.fillStyle = options.styles.jankBarColors.severe;
          break;
        case 'moderate':
          ctx.fillStyle = options.styles.jankBarColors.moderate;
          break;
        default:
          ctx.fillStyle = options.styles.jankBarColors.minor;
          break;
      }
      
      // Jank info
      const timeSince = ((report.timestamp - event.timestamp) / 1000).toFixed(1);
      const eventText = `${timeSince}s ago: ${event.duration.toFixed(1)}ms (${event.droppedFrames} dropped) - ${event.severity}`;
      ctx.fillText(eventText, padding, y);
      
      // Context info if available
      if (event.context && Object.keys(event.context).length > 0) {
        const contextStr = Object.entries(event.context)
          .map(([key, value]) => `${key}: ${value}`)
          .join(', ');
        
        ctx.fillStyle = 'rgba(255, 255, 255, 0.7)';
        ctx.fillText(`Context: ${contextStr}`, padding + 20, y + eventRowHeight - 5);
      }
    }
  }
} 