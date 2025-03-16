/**
 * Responsiveness Visualization
 * 
 * Provides visualization components for responsiveness metrics and scores.
 */

import { ResponsivenessMetrics, ResponsivenessScore } from './metrics';
import { ResponsivenessCollector } from './collector';
import { ResponsivenessScorer } from './scorer';

/**
 * Configuration options for the responsiveness visualizer
 */
export interface ResponsivenessVisualizerConfig {
  /**
   * The HTML element where the visualization will be rendered
   */
  container: HTMLElement;
  
  /**
   * Responsiveness collector instance
   */
  collector: ResponsivenessCollector;
  
  /**
   * Responsiveness scorer instance
   */
  scorer: ResponsivenessScorer;
  
  /**
   * How often to update the visualization, in milliseconds
   * Default: 1000 (1 second)
   */
  updateInterval?: number;
  
  /**
   * Maximum number of data points to show in the history chart
   * Default: 60
   */
  maxDataPoints?: number;
  
  /**
   * Whether to automatically start the visualization
   * Default: true
   */
  autoStart?: boolean;
  
  /**
   * Visual styling options
   */
  styles?: {
    /**
     * Background color of the visualizer
     */
    backgroundColor?: string;
    
    /**
     * Text color
     */
    textColor?: string;
    
    /**
     * Grid color for charts
     */
    gridColor?: string;
    
    /**
     * Colors for different score tiers
     */
    scoreColors?: {
      excellent: string;
      good: string;
      fair: string;
      poor: string;
      critical: string;
    };
    
    /**
     * Colors for different metric types
     */
    metricColors?: {
      inputLatency: string;
      timeToInteractive: string;
      frameDropRate: string;
      eventProcessingTime: string;
      gestureResponseTime: string;
    };
  };
}

/**
 * Default styles for the visualizer
 */
const DEFAULT_STYLES = {
  backgroundColor: '#111',
  textColor: '#eee',
  gridColor: '#333',
  scoreColors: {
    excellent: '#4caf50', // Green
    good: '#8bc34a',      // Light Green
    fair: '#ffc107',      // Amber
    poor: '#ff9800',      // Orange
    critical: '#f44336'   // Red
  },
  metricColors: {
    inputLatency: '#2196f3',       // Blue
    timeToInteractive: '#9c27b0',  // Purple
    frameDropRate: '#e91e63',      // Pink
    eventProcessingTime: '#00bcd4', // Cyan
    gestureResponseTime: '#009688' // Teal
  }
};

/**
 * Visualizes responsiveness metrics and scores
 */
export class ResponsivenessVisualizer {
  /**
   * Configuration for the visualizer
   */
  private config: Required<ResponsivenessVisualizerConfig>;
  
  /**
   * The container element
   */
  private container: HTMLElement;
  
  /**
   * The main visualization element
   */
  private visualizer: HTMLElement;
  
  /**
   * The current score display
   */
  private scoreDisplay: HTMLElement;
  
  /**
   * The metrics breakdown display
   */
  private metricsDisplay: HTMLElement;
  
  /**
   * The history chart canvas
   */
  private historyChart: HTMLCanvasElement;
  
  /**
   * History of responsiveness scores
   */
  private scoreHistory: Array<{ timestamp: number; score: number; }> = [];
  
  /**
   * Update timer
   */
  private updateTimer: ReturnType<typeof setInterval> | null = null;
  
  /**
   * Creates a new ResponsivenessVisualizer
   */
  constructor(config: ResponsivenessVisualizerConfig) {
    this.config = {
      container: config.container,
      collector: config.collector,
      scorer: config.scorer,
      updateInterval: config.updateInterval ?? 1000,
      maxDataPoints: config.maxDataPoints ?? 60,
      autoStart: config.autoStart ?? true,
      styles: {
        ...DEFAULT_STYLES,
        ...config.styles,
        scoreColors: {
          ...DEFAULT_STYLES.scoreColors,
          ...config.styles?.scoreColors
        },
        metricColors: {
          ...DEFAULT_STYLES.metricColors,
          ...config.styles?.metricColors
        }
      }
    };
    
    this.container = this.config.container;
    
    // Create the visualizer elements
    this.createVisualizerElements();
    
    // Register for updates from the collector
    this.config.collector.addListener(this.handleMetricsUpdate.bind(this));
    
    if (this.config.autoStart) {
      this.start();
    }
  }
  
  /**
   * Start updating the visualization
   */
  public start(): void {
    if (this.updateTimer !== null) {
      return; // Already started
    }
    
    this.updateTimer = setInterval(() => {
      this.update();
    }, this.config.updateInterval);
    
    // Initial update
    this.update();
  }
  
  /**
   * Stop updating the visualization
   */
  public stop(): void {
    if (this.updateTimer !== null) {
      clearInterval(this.updateTimer);
      this.updateTimer = null;
    }
  }
  
  /**
   * Update the visualization with the latest data
   */
  public update(): void {
    const history = this.config.collector.getInteractionHistory();
    if (history.length === 0) {
      // No data yet
      this.displayNoData();
      return;
    }
    
    // Get the most recent metrics
    const latestMetrics = history[history.length - 1];
    
    // Calculate the score
    const score = this.config.scorer.calculateScore(latestMetrics);
    
    // Update the score display
    this.updateScoreDisplay(score);
    
    // Update the metrics display
    this.updateMetricsDisplay(latestMetrics, score);
    
    // Update the history chart
    this.updateHistoryChart(score);
  }
  
  /**
   * Handle a metrics update from the collector
   */
  private handleMetricsUpdate(metrics: ResponsivenessMetrics): void {
    // Calculate the score
    const score = this.config.scorer.calculateScore(metrics);
    
    // Add to history
    this.scoreHistory.push({
      timestamp: Date.now(),
      score: score.overall
    });
    
    // Trim history if needed
    if (this.scoreHistory.length > this.config.maxDataPoints) {
      this.scoreHistory = this.scoreHistory.slice(-this.config.maxDataPoints);
    }
    
    // If automatic updates are disabled, update now
    if (this.updateTimer === null) {
      this.update();
    }
  }
  
  /**
   * Create the visualizer elements
   */
  private createVisualizerElements(): void {
    // Clear existing content
    this.container.innerHTML = '';
    
    // Set container styles
    this.container.style.position = 'relative';
    this.container.style.fontFamily = 'sans-serif';
    this.container.style.color = this.config.styles.textColor;
    this.container.style.backgroundColor = this.config.styles.backgroundColor;
    this.container.style.padding = '10px';
    this.container.style.borderRadius = '4px';
    this.container.style.overflow = 'hidden';
    
    // Create main visualizer container
    this.visualizer = document.createElement('div');
    this.visualizer.style.display = 'flex';
    this.visualizer.style.flexDirection = 'column';
    this.visualizer.style.gap = '20px';
    this.container.appendChild(this.visualizer);
    
    // Create title
    const title = document.createElement('h2');
    title.textContent = 'Responsiveness Score';
    title.style.margin = '0';
    title.style.padding = '0';
    title.style.fontSize = '18px';
    title.style.fontWeight = 'bold';
    this.visualizer.appendChild(title);
    
    // Create score display
    this.scoreDisplay = document.createElement('div');
    this.scoreDisplay.style.display = 'flex';
    this.scoreDisplay.style.alignItems = 'center';
    this.scoreDisplay.style.gap = '15px';
    this.visualizer.appendChild(this.scoreDisplay);
    
    // Create metrics display
    this.metricsDisplay = document.createElement('div');
    this.metricsDisplay.style.display = 'flex';
    this.metricsDisplay.style.flexDirection = 'column';
    this.metricsDisplay.style.gap = '10px';
    this.visualizer.appendChild(this.metricsDisplay);
    
    // Create history chart
    const historyChartContainer = document.createElement('div');
    historyChartContainer.style.marginTop = '20px';
    
    const historyChartTitle = document.createElement('h3');
    historyChartTitle.textContent = 'Score History';
    historyChartTitle.style.margin = '0 0 10px 0';
    historyChartTitle.style.padding = '0';
    historyChartTitle.style.fontSize = '16px';
    historyChartTitle.style.fontWeight = 'bold';
    historyChartContainer.appendChild(historyChartTitle);
    
    this.historyChart = document.createElement('canvas');
    this.historyChart.width = 500;
    this.historyChart.height = 200;
    this.historyChart.style.width = '100%';
    this.historyChart.style.height = '200px';
    historyChartContainer.appendChild(this.historyChart);
    
    this.visualizer.appendChild(historyChartContainer);
    
    // Display initial "No data" message
    this.displayNoData();
  }
  
  /**
   * Display a "No data" message
   */
  private displayNoData(): void {
    this.scoreDisplay.innerHTML = `
      <div style="font-size: 48px; font-weight: bold; color: ${this.config.styles.gridColor}">-</div>
      <div>
        <div style="font-size: 14px; color: ${this.config.styles.gridColor}">No data available</div>
        <div style="font-size: 12px; color: ${this.config.styles.gridColor}">Waiting for interactions...</div>
      </div>
    `;
    
    this.metricsDisplay.innerHTML = '';
    
    // Clear the history chart
    const ctx = this.historyChart.getContext('2d');
    if (ctx) {
      ctx.clearRect(0, 0, this.historyChart.width, this.historyChart.height);
      ctx.fillStyle = this.config.styles.backgroundColor;
      ctx.fillRect(0, 0, this.historyChart.width, this.historyChart.height);
      
      ctx.fillStyle = this.config.styles.gridColor;
      ctx.font = '14px sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('No data available', this.historyChart.width / 2, this.historyChart.height / 2);
    }
  }
  
  /**
   * Update the score display with the latest score
   */
  private updateScoreDisplay(score: ResponsivenessScore): void {
    const color = this.config.styles.scoreColors[score.tier];
    
    this.scoreDisplay.innerHTML = `
      <div style="font-size: 48px; font-weight: bold; color: ${color}">${score.overall}</div>
      <div>
        <div style="font-size: 18px; color: ${color}; text-transform: capitalize">${score.tier}</div>
        <div style="font-size: 12px; opacity: 0.7">Responsiveness Score</div>
      </div>
    `;
  }
  
  /**
   * Update the metrics display with the latest metrics and score
   */
  private updateMetricsDisplay(metrics: ResponsivenessMetrics, score: ResponsivenessScore): void {
    this.metricsDisplay.innerHTML = '';
    
    const createMetricBar = (
      label: string, 
      value: number, 
      scoreValue: number, 
      color: string, 
      unit: string,
      description: string
    ) => {
      const metricContainer = document.createElement('div');
      metricContainer.style.display = 'flex';
      metricContainer.style.flexDirection = 'column';
      metricContainer.style.gap = '4px';
      
      const labelRow = document.createElement('div');
      labelRow.style.display = 'flex';
      labelRow.style.justifyContent = 'space-between';
      labelRow.style.alignItems = 'center';
      
      const labelElem = document.createElement('div');
      labelElem.textContent = label;
      labelElem.style.fontSize = '14px';
      labelElem.style.fontWeight = 'bold';
      
      const valueElem = document.createElement('div');
      valueElem.textContent = `${value.toFixed(1)} ${unit}`;
      valueElem.style.fontSize = '14px';
      
      labelRow.appendChild(labelElem);
      labelRow.appendChild(valueElem);
      
      const barContainer = document.createElement('div');
      barContainer.style.height = '8px';
      barContainer.style.backgroundColor = this.config.styles.gridColor;
      barContainer.style.borderRadius = '4px';
      barContainer.style.overflow = 'hidden';
      
      const bar = document.createElement('div');
      bar.style.height = '100%';
      bar.style.width = `${scoreValue}%`;
      bar.style.backgroundColor = color;
      bar.style.borderRadius = '4px';
      
      barContainer.appendChild(bar);
      
      const descriptionElem = document.createElement('div');
      descriptionElem.textContent = description;
      descriptionElem.style.fontSize = '12px';
      descriptionElem.style.opacity = '0.7';
      descriptionElem.style.marginTop = '2px';
      
      metricContainer.appendChild(labelRow);
      metricContainer.appendChild(barContainer);
      metricContainer.appendChild(descriptionElem);
      
      return metricContainer;
    };
    
    // Input Latency
    this.metricsDisplay.appendChild(
      createMetricBar(
        'Input Latency',
        metrics.inputLatency,
        score.breakdown.inputLatency,
        this.config.styles.metricColors.inputLatency,
        'ms',
        'Time from input event to first visual response'
      )
    );
    
    // Time to Interactive
    this.metricsDisplay.appendChild(
      createMetricBar(
        'Time to Interactive',
        metrics.timeToInteractive,
        score.breakdown.tti,
        this.config.styles.metricColors.timeToInteractive,
        'ms',
        'Time until the component becomes fully interactive'
      )
    );
    
    // Frame Drop Rate
    this.metricsDisplay.appendChild(
      createMetricBar(
        'Frame Drop Rate',
        metrics.frameDropRate,
        score.breakdown.frameDrops,
        this.config.styles.metricColors.frameDropRate,
        '%',
        'Percentage of dropped frames during interaction'
      )
    );
    
    // Event Processing Time
    this.metricsDisplay.appendChild(
      createMetricBar(
        'Event Processing',
        metrics.eventProcessingTime,
        score.breakdown.eventProcessing,
        this.config.styles.metricColors.eventProcessingTime,
        'ms',
        'Average time to process an event'
      )
    );
    
    // Gesture Response Time (if available)
    if (metrics.gestureResponseTime !== undefined && score.breakdown.gestureResponse !== undefined) {
      this.metricsDisplay.appendChild(
        createMetricBar(
          'Gesture Response',
          metrics.gestureResponseTime,
          score.breakdown.gestureResponse,
          this.config.styles.metricColors.gestureResponseTime,
          'ms',
          'Time to complete a gesture (e.g., drag, swipe)'
        )
      );
    }
    
    // Add context information if available
    if (metrics.context) {
      const contextContainer = document.createElement('div');
      contextContainer.style.marginTop = '10px';
      contextContainer.style.fontSize = '12px';
      contextContainer.style.opacity = '0.7';
      
      contextContainer.innerHTML = `
        <div><strong>Interaction:</strong> ${metrics.context.interactionType}</div>
        <div><strong>Component:</strong> ${metrics.context.componentId}</div>
        <div><strong>Timestamp:</strong> ${new Date(metrics.context.timestamp).toLocaleTimeString()}</div>
      `;
      
      this.metricsDisplay.appendChild(contextContainer);
    }
  }
  
  /**
   * Update the history chart with the latest score
   */
  private updateHistoryChart(score: ResponsivenessScore): void {
    const ctx = this.historyChart.getContext('2d');
    if (!ctx) return;
    
    // Clear the canvas
    ctx.clearRect(0, 0, this.historyChart.width, this.historyChart.height);
    
    // Draw background
    ctx.fillStyle = this.config.styles.backgroundColor;
    ctx.fillRect(0, 0, this.historyChart.width, this.historyChart.height);
    
    // If we don't have enough data, show a message
    if (this.scoreHistory.length < 2) {
      ctx.fillStyle = this.config.styles.gridColor;
      ctx.font = '14px sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('Collecting data...', this.historyChart.width / 2, this.historyChart.height / 2);
      return;
    }
    
    // Draw grid
    this.drawGrid(ctx);
    
    // Draw score history
    this.drawScoreHistory(ctx);
    
    // Draw latest score marker
    this.drawLatestScoreMarker(ctx, score);
  }
  
  /**
   * Draw the chart grid
   */
  private drawGrid(ctx: CanvasRenderingContext2D): void {
    const width = this.historyChart.width;
    const height = this.historyChart.height;
    
    ctx.strokeStyle = this.config.styles.gridColor;
    ctx.lineWidth = 1;
    ctx.beginPath();
    
    // Draw horizontal grid lines
    for (let i = 0; i <= 100; i += 20) {
      const y = height - (i / 100) * height;
      ctx.moveTo(0, y);
      ctx.lineTo(width, y);
      
      // Add labels
      ctx.fillStyle = this.config.styles.textColor;
      ctx.font = '10px sans-serif';
      ctx.textAlign = 'left';
      ctx.textBaseline = 'middle';
      ctx.fillText(`${i}`, 5, y);
    }
    
    // Draw vertical grid lines
    const timeStep = width / 6; // 6 divisions
    for (let i = 0; i <= width; i += timeStep) {
      ctx.moveTo(i, 0);
      ctx.lineTo(i, height);
    }
    
    ctx.stroke();
  }
  
  /**
   * Draw the score history line
   */
  private drawScoreHistory(ctx: CanvasRenderingContext2D): void {
    if (this.scoreHistory.length < 2) return;
    
    const width = this.historyChart.width;
    const height = this.historyChart.height;
    const historyLength = this.scoreHistory.length;
    
    // Calculate the x step
    const xStep = width / (this.config.maxDataPoints - 1);
    
    ctx.strokeStyle = this.config.styles.textColor;
    ctx.lineWidth = 2;
    ctx.beginPath();
    
    // Start at the first point
    const firstPoint = this.scoreHistory[0];
    const firstX = 0;
    const firstY = height - (firstPoint.score / 100) * height;
    ctx.moveTo(firstX, firstY);
    
    // Draw the line through all points
    for (let i = 1; i < historyLength; i++) {
      const point = this.scoreHistory[i];
      const x = i * xStep;
      const y = height - (point.score / 100) * height;
      ctx.lineTo(x, y);
    }
    
    ctx.stroke();
    
    // Add gradient fill below the line
    const gradient = ctx.createLinearGradient(0, 0, 0, height);
    gradient.addColorStop(0, `${this.config.styles.textColor}33`); // 20% opacity
    gradient.addColorStop(1, `${this.config.styles.textColor}00`); // 0% opacity
    
    ctx.fillStyle = gradient;
    ctx.beginPath();
    ctx.moveTo(0, height);
    ctx.lineTo(0, firstY);
    
    for (let i = 1; i < historyLength; i++) {
      const point = this.scoreHistory[i];
      const x = i * xStep;
      const y = height - (point.score / 100) * height;
      ctx.lineTo(x, y);
    }
    
    ctx.lineTo((historyLength - 1) * xStep, height);
    ctx.closePath();
    ctx.fill();
  }
  
  /**
   * Draw a marker for the latest score
   */
  private drawLatestScoreMarker(ctx: CanvasRenderingContext2D, score: ResponsivenessScore): void {
    if (this.scoreHistory.length === 0) return;
    
    const width = this.historyChart.width;
    const height = this.historyChart.height;
    
    // Latest point is at the end of the chart
    const x = (this.scoreHistory.length - 1) * (width / (this.config.maxDataPoints - 1));
    const y = height - (score.overall / 100) * height;
    
    // Draw the marker
    ctx.fillStyle = this.config.styles.scoreColors[score.tier];
    ctx.beginPath();
    ctx.arc(x, y, 5, 0, Math.PI * 2);
    ctx.fill();
    
    // Draw score label
    ctx.fillStyle = this.config.styles.textColor;
    ctx.font = 'bold 12px sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'bottom';
    ctx.fillText(`${score.overall}`, x, y - 10);
  }
} 