/**
 * Chart.ts
 * 
 * A flexible, accessible data visualization component for the Raxol framework.
 * Supports multiple chart types and integrates with Raxol's performance tools.
 */

import { 
  startPerformanceMark, 
  endPerformanceMark, 
  recordMetric,
  registerComponent, 
  unregisterComponent,
  addJankContext
} from '../../core/performance';

/**
 * Supported chart types
 */
export type ChartType = 
  | 'line' 
  | 'bar' 
  | 'area' 
  | 'pie' 
  | 'donut' 
  | 'scatter' 
  | 'bubble' 
  | 'radar' 
  | 'candlestick';

/**
 * Data point structure
 */
export interface DataPoint {
  x: number | string;
  y: number;
  z?: number;       // For bubble charts (size) or 3D visualizations
  label?: string;   // Optional label for this data point
  color?: string;   // Optional color override for this specific point
  [key: string]: any; // Additional custom data
}

/**
 * Data series structure
 */
export interface DataSeries {
  name: string;
  data: DataPoint[];
  color?: string;
  visible?: boolean;
  type?: ChartType; // For mixed chart types
  yAxis?: number;   // For multiple y-axes
  stack?: string;   // For stacked charts
  [key: string]: any; // Additional custom data
}

/**
 * Axis configuration
 */
export interface AxisConfig {
  title?: string;
  min?: number;
  max?: number;
  gridLines?: boolean;
  tickInterval?: number;
  tickFormat?: (value: any) => string;
  tickCount?: number;
  visible?: boolean;
  position?: 'left' | 'right' | 'top' | 'bottom';
  [key: string]: any;
}

/**
 * Legend configuration
 */
export interface LegendConfig {
  visible?: boolean;
  position?: 'top' | 'right' | 'bottom' | 'left';
  interactive?: boolean; // Can toggle series visibility
  maxItems?: number;     // Max items before scrolling/paging
  [key: string]: any;
}

/**
 * Tooltip configuration
 */
export interface TooltipConfig {
  enabled?: boolean;
  shared?: boolean; // Show all series at a point
  format?: (point: DataPoint, series: DataSeries) => string;
  followCursor?: boolean;
  [key: string]: any;
}

/**
 * Animation configuration
 */
export interface AnimationConfig {
  enabled?: boolean;
  duration?: number;
  easing?: string;
  delayBetweenSeries?: number;
  onComplete?: () => void;
  [key: string]: any;
}

/**
 * Accessibility configuration
 */
export interface AccessibilityConfig {
  enabled?: boolean;
  description?: string;
  keyboardNavigation?: boolean;
  announceDataPoints?: boolean;
  sonification?: {
    enabled?: boolean;
    mappings?: any[]; // Sound mappings
  };
  [key: string]: any;
}

/**
 * Chart options
 */
export interface ChartOptions {
  type: ChartType;
  width?: number;
  height?: number;
  title?: string;
  subtitle?: string;
  series: DataSeries[];
  xAxis?: AxisConfig;
  yAxis?: AxisConfig | AxisConfig[]; // Support multiple y-axes
  legend?: LegendConfig;
  tooltip?: TooltipConfig;
  animation?: AnimationConfig;
  accessibility?: AccessibilityConfig;
  colors?: string[];
  backgroundColor?: string;
  margin?: {
    top?: number;
    right?: number;
    bottom?: number;
    left?: number;
  };
  events?: {
    load?: () => void;
    render?: () => void;
    seriesClick?: (series: DataSeries, index: number) => void;
    pointClick?: (point: DataPoint, series: DataSeries, indices: {seriesIndex: number, pointIndex: number}) => void;
    [key: string]: any;
  };
  // Additional specific options for different chart types
  plotOptions?: {
    [key in ChartType]?: any;
  };
  [key: string]: any;
}

/**
 * Chart component for data visualization
 */
export class Chart {
  private container: HTMLElement;
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private options: ChartOptions;
  private componentId: string;
  private resizeObserver: ResizeObserver | null = null;
  private isDestroyed: boolean = false;
  private ariaLiveRegion: HTMLElement | null = null;
  private interactionLayer: HTMLElement | null = null;
  private animationFrameId: number | null = null;
  private dataPointElements: Map<string, HTMLElement> = new Map();
  private selectedPoint: {seriesIndex: number, pointIndex: number} | null = null;
  
  /**
   * Create a new chart
   */
  constructor(container: HTMLElement, options: ChartOptions) {
    startPerformanceMark('chart-init');
    
    this.container = container;
    this.options = this.mergeDefaults(options);
    this.componentId = `chart-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
    
    // Set up canvas
    this.canvas = document.createElement('canvas');
    this.canvas.width = this.options.width || this.container.clientWidth;
    this.canvas.height = this.options.height || this.container.clientHeight;
    this.canvas.style.display = 'block';
    
    // Get context
    const context = this.canvas.getContext('2d');
    if (!context) {
      throw new Error('Could not get 2D context for chart canvas');
    }
    this.ctx = context;
    
    // Append canvas to container
    this.container.appendChild(this.canvas);
    
    // Set up accessibility features
    this.setupAccessibility();
    
    // Set up interaction layer
    this.setupInteractionLayer();
    
    // Register with performance monitoring
    const memoryEstimate = this.estimateMemoryUsage();
    registerComponent(this.componentId, memoryEstimate);
    
    // Set up resize handling
    this.setupResizeHandling();
    
    // Initial render
    this.render();
    
    endPerformanceMark('chart-init', 'render');
  }
  
  /**
   * Set up accessibility features
   */
  private setupAccessibility(): void {
    if (this.options.accessibility?.enabled !== false) {
      // Create ARIA live region for announcements
      this.ariaLiveRegion = document.createElement('div');
      this.ariaLiveRegion.setAttribute('aria-live', 'polite');
      this.ariaLiveRegion.setAttribute('aria-atomic', 'true');
      this.ariaLiveRegion.classList.add('chart-announcer');
      this.ariaLiveRegion.style.position = 'absolute';
      this.ariaLiveRegion.style.width = '1px';
      this.ariaLiveRegion.style.height = '1px';
      this.ariaLiveRegion.style.overflow = 'hidden';
      this.ariaLiveRegion.style.clip = 'rect(0, 0, 0, 0)';
      this.container.appendChild(this.ariaLiveRegion);
      
      // Set ARIA attributes on container
      this.container.setAttribute('role', 'img');
      this.container.setAttribute('aria-roledescription', 'chart');
      
      if (this.options.title) {
        this.container.setAttribute('aria-label', this.options.title);
      }
      
      if (this.options.accessibility?.description) {
        this.container.setAttribute('aria-description', this.options.accessibility.description);
      }
    }
  }
  
  /**
   * Set up the interaction layer for handling user input
   */
  private setupInteractionLayer(): void {
    this.interactionLayer = document.createElement('div');
    this.interactionLayer.style.position = 'absolute';
    this.interactionLayer.style.top = '0';
    this.interactionLayer.style.left = '0';
    this.interactionLayer.style.width = '100%';
    this.interactionLayer.style.height = '100%';
    this.interactionLayer.style.zIndex = '1';
    this.interactionLayer.style.cursor = 'default';
    this.interactionLayer.tabIndex = 0; // Make focusable for keyboard navigation
    
    // Make container position relative if it's not already
    const containerStyle = window.getComputedStyle(this.container);
    if (containerStyle.position === 'static') {
      this.container.style.position = 'relative';
    }
    
    // Add event listeners
    this.interactionLayer.addEventListener('mousemove', this.handleMouseMove.bind(this));
    this.interactionLayer.addEventListener('click', this.handleClick.bind(this));
    this.interactionLayer.addEventListener('keydown', this.handleKeyDown.bind(this));
    this.interactionLayer.addEventListener('focus', this.handleFocus.bind(this));
    
    this.container.appendChild(this.interactionLayer);
  }
  
  /**
   * Handle mouse movement
   */
  private handleMouseMove(event: MouseEvent): void {
    // Implementation would find the nearest data point and display tooltip
    // For now, just track performance
    addJankContext('action', 'chart-hover');
  }
  
  /**
   * Handle click events
   */
  private handleClick(event: MouseEvent): void {
    // Implementation would find the clicked point/series and trigger callbacks
    // For now, just track performance
    addJankContext('action', 'chart-click');
  }
  
  /**
   * Handle keyboard navigation
   */
  private handleKeyDown(event: KeyboardEvent): void {
    if (!this.options.accessibility?.keyboardNavigation) return;
    
    // Basic keyboard navigation - would be more sophisticated in full implementation
    switch (event.key) {
      case 'ArrowRight':
        this.navigatePoints(1, 0);
        event.preventDefault();
        break;
      case 'ArrowLeft':
        this.navigatePoints(-1, 0);
        event.preventDefault();
        break;
      case 'ArrowUp':
        this.navigatePoints(0, 1);
        event.preventDefault();
        break;
      case 'ArrowDown':
        this.navigatePoints(0, -1);
        event.preventDefault();
        break;
      case 'Enter':
      case ' ':
        this.activateSelectedPoint();
        event.preventDefault();
        break;
    }
  }
  
  /**
   * Navigate between data points with keyboard
   */
  private navigatePoints(xDelta: number, yDelta: number): void {
    // Implementation would move selection between points
    // For now just a stub
    this.announce('Navigating data points');
  }
  
  /**
   * Activate the currently selected point (Enter/Space key)
   */
  private activateSelectedPoint(): void {
    // Implementation would trigger point activation
    // For now just a stub
    this.announce('Point activated');
  }
  
  /**
   * Handle focus events
   */
  private handleFocus(): void {
    if (this.options.accessibility?.enabled !== false) {
      const description = this.generateAccessibleDescription();
      this.announce(description);
    }
  }
  
  /**
   * Generate accessible description of the chart
   */
  private generateAccessibleDescription(): string {
    // Basic description - would be more sophisticated in full implementation
    let description = this.options.title || 'Chart';
    
    if (this.options.subtitle) {
      description += `, ${this.options.subtitle}`;
    }
    
    description += `. ${this.options.type} chart with ${this.options.series.length} data series.`;
    
    // Add series information
    this.options.series.forEach(series => {
      description += ` ${series.name}: ${series.data.length} data points.`;
    });
    
    return description;
  }
  
  /**
   * Announce message to screen readers through the ARIA live region
   */
  private announce(message: string): void {
    if (this.ariaLiveRegion) {
      this.ariaLiveRegion.textContent = message;
    }
  }
  
  /**
   * Set up resize observation
   */
  private setupResizeHandling(): void {
    // Use ResizeObserver to handle container resizing
    this.resizeObserver = new ResizeObserver(entries => {
      for (const entry of entries) {
        if (entry.target === this.container) {
          this.handleResize();
        }
      }
    });
    
    this.resizeObserver.observe(this.container);
  }
  
  /**
   * Handle container resize
   */
  private handleResize(): void {
    if (this.isDestroyed) return;
    
    startPerformanceMark('chart-resize');
    
    // Update canvas dimensions
    this.canvas.width = this.container.clientWidth;
    this.canvas.height = this.container.clientHeight;
    
    // Re-render the chart
    this.render();
    
    endPerformanceMark('chart-resize', 'render');
  }
  
  /**
   * Merge user options with defaults
   */
  private mergeDefaults(options: ChartOptions): ChartOptions {
    // Basic defaults - would be more comprehensive in full implementation
    return {
      ...options,
      width: options.width || this.container.clientWidth,
      height: options.height || this.container.clientHeight,
      legend: {
        visible: true,
        position: 'bottom',
        interactive: true,
        ...options.legend
      },
      tooltip: {
        enabled: true,
        shared: false,
        followCursor: true,
        ...options.tooltip
      },
      animation: {
        enabled: true,
        duration: 1000,
        easing: 'easeOutQuad',
        ...options.animation
      },
      accessibility: {
        enabled: true,
        keyboardNavigation: true,
        announceDataPoints: true,
        ...options.accessibility
      },
      margin: {
        top: 10,
        right: 10,
        bottom: 30,
        left: 40,
        ...options.margin
      }
    };
  }
  
  /**
   * Estimate memory usage for performance monitoring
   */
  private estimateMemoryUsage(): number {
    // Rough estimate of memory usage based on data size and options
    const seriesCount = this.options.series.length;
    const totalPoints = this.options.series.reduce((sum, series) => sum + series.data.length, 0);
    
    // Base memory for the component
    let estimatedBytes = 1024;
    
    // Add memory for data points (rough estimate)
    estimatedBytes += totalPoints * 64;
    
    // Add memory for series
    estimatedBytes += seriesCount * 256;
    
    // Add canvas memory (4 bytes per pixel for RGBA)
    estimatedBytes += this.canvas.width * this.canvas.height * 4;
    
    return estimatedBytes;
  }
  
  /**
   * Render the chart
   */
  private render(): void {
    if (this.isDestroyed) return;
    
    startPerformanceMark('chart-render');
    addJankContext('action', 'chart-render');
    addJankContext('chartType', this.options.type);
    addJankContext('dataPoints', this.getTotalDataPoints());
    
    // Clear canvas
    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    
    // Set background if specified
    if (this.options.backgroundColor) {
      this.ctx.fillStyle = this.options.backgroundColor;
      this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    }
    
    // Calculate drawing area based on margins
    const drawingArea = this.calculateDrawingArea();
    
    // Draw chart components
    this.drawTitle();
    this.drawAxes(drawingArea);
    this.drawSeries(drawingArea);
    this.drawLegend(drawingArea);
    
    // Track rendering performance
    const renderTime = endPerformanceMark('chart-render', 'render');
    recordMetric(`chart-render-${this.options.type}`, renderTime || 0, 'render', {
      seriesCount: this.options.series.length,
      dataPoints: this.getTotalDataPoints()
    });
    
    // Call render callback if provided
    if (this.options.events?.render) {
      this.options.events.render();
    }
  }
  
  /**
   * Calculate the drawing area based on margins
   */
  private calculateDrawingArea(): {x: number, y: number, width: number, height: number} {
    const margin = this.options.margin || {};
    
    return {
      x: margin.left || 0,
      y: margin.top || 0,
      width: this.canvas.width - (margin.left || 0) - (margin.right || 0),
      height: this.canvas.height - (margin.top || 0) - (margin.bottom || 0)
    };
  }
  
  /**
   * Draw chart title and subtitle
   */
  private drawTitle(): void {
    // Title rendering would go here
    // This is just a stub implementation
    if (this.options.title) {
      this.ctx.textAlign = 'center';
      this.ctx.textBaseline = 'top';
      this.ctx.font = 'bold 16px Arial';
      this.ctx.fillStyle = '#333';
      this.ctx.fillText(this.options.title, this.canvas.width / 2, 10);
      
      if (this.options.subtitle) {
        this.ctx.font = '12px Arial';
        this.ctx.fillText(this.options.subtitle, this.canvas.width / 2, 30);
      }
    }
  }
  
  /**
   * Draw chart axes
   */
  private drawAxes(area: {x: number, y: number, width: number, height: number}): void {
    // Axes rendering would go here
    // This is just a stub implementation
    this.ctx.strokeStyle = '#999';
    this.ctx.lineWidth = 1;
    
    // X-axis
    this.ctx.beginPath();
    this.ctx.moveTo(area.x, area.y + area.height);
    this.ctx.lineTo(area.x + area.width, area.y + area.height);
    this.ctx.stroke();
    
    // Y-axis
    this.ctx.beginPath();
    this.ctx.moveTo(area.x, area.y);
    this.ctx.lineTo(area.x, area.y + area.height);
    this.ctx.stroke();
  }
  
  /**
   * Draw data series
   */
  private drawSeries(area: {x: number, y: number, width: number, height: number}): void {
    // Series rendering would go here based on chart type
    // This is just a stub that would be replaced with actual rendering logic
    
    // Delegate to type-specific rendering methods
    switch (this.options.type) {
      case 'line':
        this.drawLineChart(area);
        break;
      case 'bar':
        this.drawBarChart(area);
        break;
      case 'pie':
        this.drawPieChart(area);
        break;
      // Additional chart types would be implemented
      default:
        // Fallback to basic rendering
        this.drawLineChart(area);
    }
  }
  
  /**
   * Draw line chart
   */
  private drawLineChart(area: {x: number, y: number, width: number, height: number}): void {
    // Stub implementation for line chart
    this.options.series.forEach((series, seriesIndex) => {
      if (series.visible !== false && series.data.length > 0) {
        const color = series.color || this.getSeriesColor(seriesIndex);
        
        this.ctx.strokeStyle = color;
        this.ctx.lineWidth = 2;
        this.ctx.beginPath();
        
        // Draw lines connecting points
        series.data.forEach((point, pointIndex) => {
          const x = area.x + (pointIndex / (series.data.length - 1)) * area.width;
          
          // Normalize y value between 0 and 1
          let normalizedY = 1;
          if (point.y !== undefined) {
            const yAxis = Array.isArray(this.options.yAxis) 
              ? this.options.yAxis[series.yAxis || 0] 
              : this.options.yAxis;
              
            const min = yAxis?.min ?? Math.min(...series.data.map(p => p.y));
            const max = yAxis?.max ?? Math.max(...series.data.map(p => p.y));
            
            normalizedY = max > min ? 1 - ((point.y - min) / (max - min)) : 0.5;
          }
          
          const y = area.y + normalizedY * area.height;
          
          if (pointIndex === 0) {
            this.ctx.moveTo(x, y);
          } else {
            this.ctx.lineTo(x, y);
          }
        });
        
        this.ctx.stroke();
      }
    });
  }
  
  /**
   * Draw bar chart
   */
  private drawBarChart(area: {x: number, y: number, width: number, height: number}): void {
    // Stub implementation for bar chart
    const seriesCount = this.options.series.length;
    const visibleSeries = this.options.series.filter(s => s.visible !== false);
    
    visibleSeries.forEach((series, seriesIndex) => {
      const color = series.color || this.getSeriesColor(seriesIndex);
      
      series.data.forEach((point, pointIndex) => {
        const barWidth = (area.width / series.data.length) / visibleSeries.length * 0.8;
        const barSpacing = (area.width / series.data.length) * 0.2 / visibleSeries.length;
        
        const x = area.x + 
                 (pointIndex / series.data.length) * area.width + 
                 seriesIndex * (barWidth + barSpacing);
        
        // Normalize y value between 0 and 1
        let normalizedY = 0;
        if (point.y !== undefined) {
          const yAxis = Array.isArray(this.options.yAxis) 
            ? this.options.yAxis[series.yAxis || 0] 
            : this.options.yAxis;
            
          const min = yAxis?.min ?? 0;
          const max = yAxis?.max ?? Math.max(...series.data.map(p => p.y));
          
          normalizedY = max > min ? (point.y - min) / (max - min) : 0;
        }
        
        const barHeight = normalizedY * area.height;
        const y = area.y + area.height - barHeight;
        
        this.ctx.fillStyle = point.color || color;
        this.ctx.fillRect(x, y, barWidth, barHeight);
      });
    });
  }
  
  /**
   * Draw pie chart
   */
  private drawPieChart(area: {x: number, y: number, width: number, height: number}): void {
    // Stub implementation for pie chart
    const centerX = area.x + area.width / 2;
    const centerY = area.y + area.height / 2;
    const radius = Math.min(area.width, area.height) / 2;
    
    // For simplicity, we'll just use the first series for a pie chart
    const series = this.options.series[0];
    
    if (series && series.visible !== false) {
      let total = series.data.reduce((sum, point) => sum + point.y, 0);
      
      if (total <= 0) {
        // Nothing to draw
        return;
      }
      
      let startAngle = 0;
      
      series.data.forEach((point, pointIndex) => {
        const sliceAngle = (point.y / total) * Math.PI * 2;
        const endAngle = startAngle + sliceAngle;
        
        this.ctx.beginPath();
        this.ctx.moveTo(centerX, centerY);
        this.ctx.arc(centerX, centerY, radius, startAngle, endAngle);
        this.ctx.closePath();
        
        this.ctx.fillStyle = point.color || this.getSeriesColor(pointIndex);
        this.ctx.fill();
        
        startAngle = endAngle;
      });
    }
  }
  
  /**
   * Draw chart legend
   */
  private drawLegend(area: {x: number, y: number, width: number, height: number}): void {
    const legend = this.options.legend;
    if (!legend || legend.visible === false) return;
    
    // Legend rendering would go here
    // This is just a stub implementation
    const legendY = area.y + area.height + 10;
    const itemWidth = area.width / this.options.series.length;
    
    this.options.series.forEach((series, i) => {
      const x = area.x + (i * itemWidth);
      
      // Color swatch
      this.ctx.fillStyle = series.color || this.getSeriesColor(i);
      this.ctx.fillRect(x, legendY, 10, 10);
      
      // Series name
      this.ctx.fillStyle = '#333';
      this.ctx.font = '12px Arial';
      this.ctx.textAlign = 'left';
      this.ctx.textBaseline = 'top';
      this.ctx.fillText(series.name, x + 15, legendY);
    });
  }
  
  /**
   * Get color for a series based on index
   */
  private getSeriesColor(index: number): string {
    const defaultColors = [
      '#4285F4', // Google Blue
      '#EA4335', // Google Red
      '#FBBC05', // Google Yellow
      '#34A853', // Google Green
      '#FF6D01', // Orange
      '#46BDC6', // Teal
      '#9C27B0', // Purple
      '#FFCA28', // Amber
      '#607D8B', // Blue Grey
      '#009688'  // Material Teal
    ];
    
    // Use provided colors or defaults
    const colors = this.options.colors || defaultColors;
    return colors[index % colors.length];
  }
  
  /**
   * Get total number of data points across all series
   */
  private getTotalDataPoints(): number {
    return this.options.series.reduce((sum, series) => sum + series.data.length, 0);
  }
  
  /**
   * Update chart data and re-render
   */
  public updateData(newSeries: DataSeries[]): void {
    startPerformanceMark('chart-update-data');
    
    this.options.series = newSeries;
    
    // Update memory estimate
    const newMemoryEstimate = this.estimateMemoryUsage();
    registerComponent(this.componentId, newMemoryEstimate);
    
    // Re-render the chart
    this.render();
    
    endPerformanceMark('chart-update-data', 'render');
  }
  
  /**
   * Update chart options and re-render
   */
  public updateOptions(newOptions: Partial<ChartOptions>): void {
    startPerformanceMark('chart-update-options');
    
    this.options = this.mergeDefaults({
      ...this.options,
      ...newOptions,
      series: newOptions.series || this.options.series
    });
    
    // Re-render the chart
    this.render();
    
    endPerformanceMark('chart-update-options', 'render');
  }
  
  /**
   * Export chart as image
   */
  public toDataURL(type: string = 'image/png', quality?: number): string {
    return this.canvas.toDataURL(type, quality);
  }
  
  /**
   * Download chart as image
   */
  public download(filename: string = 'chart.png', type: string = 'image/png'): void {
    const link = document.createElement('a');
    link.download = filename;
    link.href = this.toDataURL(type);
    link.click();
  }
  
  /**
   * Clean up resources
   */
  public destroy(): void {
    if (this.isDestroyed) return;
    
    this.isDestroyed = true;
    
    // Stop any animations
    if (this.animationFrameId !== null) {
      cancelAnimationFrame(this.animationFrameId);
      this.animationFrameId = null;
    }
    
    // Remove resize observer
    if (this.resizeObserver) {
      this.resizeObserver.disconnect();
      this.resizeObserver = null;
    }
    
    // Remove elements
    if (this.ariaLiveRegion && this.ariaLiveRegion.parentNode) {
      this.ariaLiveRegion.parentNode.removeChild(this.ariaLiveRegion);
      this.ariaLiveRegion = null;
    }
    
    if (this.interactionLayer && this.interactionLayer.parentNode) {
      this.interactionLayer.parentNode.removeChild(this.interactionLayer);
      this.interactionLayer = null;
    }
    
    if (this.canvas && this.canvas.parentNode) {
      this.canvas.parentNode.removeChild(this.canvas);
    }
    
    // Unregister from performance monitoring
    unregisterComponent(this.componentId);
    
    // Clear data structures
    this.dataPointElements.clear();
  }
  
  /**
   * Get series data for external operations
   * @returns The series data array
   */
  public getSeriesData(): DataSeries[] {
    return [...this.options.series];
  }
  
  /**
   * Get colors used in the chart
   * @returns Array of color strings
   */
  public getColors(): string[] {
    return this.options.colors || [];
  }
  
  /**
   * Get axis options for specified axis type
   * @param axisType 'x' or 'y' axis
   * @returns The axis configuration
   */
  public getAxisOptions(axisType: 'x' | 'y'): AxisConfig | undefined {
    return axisType === 'x' ? this.options.xAxis : this.options.yAxis;
  }
} 