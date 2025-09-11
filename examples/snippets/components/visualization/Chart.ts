/**
 * Chart Visualization Component
 * 
 * A flexible chart component for displaying various types of data visualizations
 * including line charts, bar charts, scatter plots, and more.
 */

// Chart data types
export interface DataPoint {
  x: number | string | Date;
  y: number;
  label?: string;
  color?: string;
  metadata?: Record<string, any>;
}

export interface DataSeries {
  name: string;
  data: DataPoint[];
  type?: 'line' | 'bar' | 'scatter' | 'area';
  color?: string;
  style?: Record<string, any>;
}

// Chart configuration
export interface ChartOptions {
  width?: number;
  height?: number;
  title?: string;
  subtitle?: string;
  xAxis?: {
    label?: string;
    type?: 'linear' | 'categorical' | 'time';
    min?: number;
    max?: number;
    format?: (value: any) => string;
  };
  yAxis?: {
    label?: string;
    type?: 'linear' | 'logarithmic';
    min?: number;
    max?: number;
    format?: (value: number) => string;
  };
  legend?: {
    show?: boolean;
    position?: 'top' | 'bottom' | 'left' | 'right';
  };
  grid?: {
    show?: boolean;
    color?: string;
    style?: 'solid' | 'dashed' | 'dotted';
  };
  animation?: {
    enabled?: boolean;
    duration?: number;
    easing?: 'linear' | 'ease' | 'ease-in' | 'ease-out' | 'ease-in-out';
  };
  interactions?: {
    zoom?: boolean;
    pan?: boolean;
    hover?: boolean;
    tooltip?: boolean;
  };
  theme?: 'light' | 'dark' | 'custom';
  colors?: string[];
}

export interface ChartEvents {
  onPointClick?: (point: DataPoint, series: DataSeries) => void;
  onPointHover?: (point: DataPoint, series: DataSeries) => void;
  onZoom?: (xRange: [number, number], yRange: [number, number]) => void;
  onPan?: (deltaX: number, deltaY: number) => void;
}

/**
 * Chart component class
 */
export class Chart {
  private container: HTMLElement;
  private options: ChartOptions;
  private series: DataSeries[];
  private events: ChartEvents;
  private canvas?: HTMLCanvasElement;
  private context?: CanvasRenderingContext2D;
  private animationFrame?: number;

  constructor(
    container: HTMLElement,
    series: DataSeries[],
    options: ChartOptions = {},
    events: ChartEvents = {}
  ) {
    this.container = container;
    this.series = series;
    this.options = this.mergeDefaultOptions(options);
    this.events = events;

    this.initialize();
  }

  private mergeDefaultOptions(options: ChartOptions): ChartOptions {
    return {
      width: 800,
      height: 400,
      title: '',
      subtitle: '',
      xAxis: {
        label: 'X Axis',
        type: 'linear',
        format: (value: any) => String(value),
        ...options.xAxis
      },
      yAxis: {
        label: 'Y Axis',
        type: 'linear',
        format: (value: number) => value.toFixed(1),
        ...options.yAxis
      },
      legend: {
        show: true,
        position: 'top',
        ...options.legend
      },
      grid: {
        show: true,
        color: '#e0e0e0',
        style: 'solid',
        ...options.grid
      },
      animation: {
        enabled: true,
        duration: 1000,
        easing: 'ease-out',
        ...options.animation
      },
      interactions: {
        zoom: false,
        pan: false,
        hover: true,
        tooltip: true,
        ...options.interactions
      },
      theme: 'light',
      colors: ['#3498db', '#e74c3c', '#2ecc71', '#f39c12', '#9b59b6', '#1abc9c'],
      ...options
    };
  }

  private initialize(): void {
    this.createCanvas();
    this.setupEventListeners();
    this.render();
  }

  private createCanvas(): void {
    this.canvas = document.createElement('canvas');
    this.canvas.width = this.options.width!;
    this.canvas.height = this.options.height!;
    this.canvas.style.border = '1px solid #ccc';
    
    this.context = this.canvas.getContext('2d')!;
    this.container.appendChild(this.canvas);
  }

  private setupEventListeners(): void {
    if (!this.canvas) return;

    // Mouse events for interactions
    this.canvas.addEventListener('click', this.handleClick.bind(this));
    this.canvas.addEventListener('mousemove', this.handleMouseMove.bind(this));
    this.canvas.addEventListener('wheel', this.handleWheel.bind(this));
  }

  private handleClick(event: MouseEvent): void {
    if (!this.events.onPointClick || !this.canvas) return;

    const rect = this.canvas.getBoundingClientRect();
    const x = event.clientX - rect.left;
    const y = event.clientY - rect.top;

    // Find the closest data point (simplified implementation)
    const point = this.findNearestPoint(x, y);
    if (point) {
      this.events.onPointClick(point.dataPoint, point.series);
    }
  }

  private handleMouseMove(event: MouseEvent): void {
    if (!this.events.onPointHover || !this.canvas) return;

    const rect = this.canvas.getBoundingClientRect();
    const x = event.clientX - rect.left;
    const y = event.clientY - rect.top;

    const point = this.findNearestPoint(x, y);
    if (point) {
      this.events.onPointHover(point.dataPoint, point.series);
    }
  }

  private handleWheel(event: WheelEvent): void {
    if (!this.options.interactions?.zoom || !this.events.onZoom) return;

    event.preventDefault();
    // Simplified zoom implementation
    const zoomFactor = event.deltaY > 0 ? 0.9 : 1.1;
    // In a real implementation, you would calculate new ranges based on zoom
    this.events.onZoom([0, 100], [0, 100]);
  }

  private findNearestPoint(canvasX: number, canvasY: number): { dataPoint: DataPoint; series: DataSeries } | null {
    // Simplified point finding - in a real implementation this would be more sophisticated
    const tolerance = 10;
    
    for (const series of this.series) {
      for (const point of series.data) {
        // Convert data coordinates to canvas coordinates (simplified)
        const x = (typeof point.x === 'number' ? point.x : 0) * (this.options.width! / 100);
        const y = this.options.height! - (point.y * (this.options.height! / 100));
        
        const distance = Math.sqrt(Math.pow(canvasX - x, 2) + Math.pow(canvasY - y, 2));
        if (distance <= tolerance) {
          return { dataPoint: point, series };
        }
      }
    }
    
    return null;
  }

  private render(): void {
    if (!this.context) return;

    // Clear canvas
    this.context.clearRect(0, 0, this.options.width!, this.options.height!);

    // Draw background
    this.drawBackground();
    
    // Draw grid
    if (this.options.grid?.show) {
      this.drawGrid();
    }

    // Draw axes
    this.drawAxes();

    // Draw data series
    this.series.forEach((series, index) => {
      this.drawSeries(series, index);
    });

    // Draw legend
    if (this.options.legend?.show) {
      this.drawLegend();
    }

    // Draw title
    if (this.options.title) {
      this.drawTitle();
    }
  }

  private drawBackground(): void {
    if (!this.context) return;

    this.context.fillStyle = this.options.theme === 'dark' ? '#2c3e50' : '#ffffff';
    this.context.fillRect(0, 0, this.options.width!, this.options.height!);
  }

  private drawGrid(): void {
    if (!this.context) return;

    this.context.strokeStyle = this.options.grid!.color!;
    this.context.lineWidth = 1;
    this.context.setLineDash(this.options.grid!.style === 'dashed' ? [5, 5] : []);

    // Vertical lines
    for (let i = 0; i <= 10; i++) {
      const x = (i / 10) * this.options.width!;
      this.context.beginPath();
      this.context.moveTo(x, 0);
      this.context.lineTo(x, this.options.height!);
      this.context.stroke();
    }

    // Horizontal lines
    for (let i = 0; i <= 10; i++) {
      const y = (i / 10) * this.options.height!;
      this.context.beginPath();
      this.context.moveTo(0, y);
      this.context.lineTo(this.options.width!, y);
      this.context.stroke();
    }

    this.context.setLineDash([]);
  }

  private drawAxes(): void {
    if (!this.context) return;

    this.context.strokeStyle = this.options.theme === 'dark' ? '#ecf0f1' : '#34495e';
    this.context.lineWidth = 2;

    // X-axis
    this.context.beginPath();
    this.context.moveTo(0, this.options.height!);
    this.context.lineTo(this.options.width!, this.options.height!);
    this.context.stroke();

    // Y-axis
    this.context.beginPath();
    this.context.moveTo(0, 0);
    this.context.lineTo(0, this.options.height!);
    this.context.stroke();
  }

  private drawSeries(series: DataSeries, index: number): void {
    if (!this.context || series.data.length === 0) return;

    const color = series.color || this.options.colors![index % this.options.colors!.length];
    const type = series.type || 'line';

    switch (type) {
      case 'line':
        this.drawLineSeries(series, color);
        break;
      case 'bar':
        this.drawBarSeries(series, color);
        break;
      case 'scatter':
        this.drawScatterSeries(series, color);
        break;
      case 'area':
        this.drawAreaSeries(series, color);
        break;
    }
  }

  private drawLineSeries(series: DataSeries, color: string): void {
    if (!this.context) return;

    this.context.strokeStyle = color;
    this.context.lineWidth = 2;
    this.context.beginPath();

    series.data.forEach((point, index) => {
      const x = (typeof point.x === 'number' ? point.x : index) * (this.options.width! / 100);
      const y = this.options.height! - (point.y * (this.options.height! / 100));

      if (index === 0) {
        this.context!.moveTo(x, y);
      } else {
        this.context!.lineTo(x, y);
      }
    });

    this.context.stroke();
  }

  private drawBarSeries(series: DataSeries, color: string): void {
    if (!this.context) return;

    this.context.fillStyle = color;
    const barWidth = this.options.width! / series.data.length * 0.8;

    series.data.forEach((point, index) => {
      const x = index * (this.options.width! / series.data.length) + (this.options.width! / series.data.length - barWidth) / 2;
      const height = point.y * (this.options.height! / 100);
      const y = this.options.height! - height;

      this.context!.fillRect(x, y, barWidth, height);
    });
  }

  private drawScatterSeries(series: DataSeries, color: string): void {
    if (!this.context) return;

    this.context.fillStyle = color;
    const radius = 4;

    series.data.forEach((point, index) => {
      const x = (typeof point.x === 'number' ? point.x : index) * (this.options.width! / 100);
      const y = this.options.height! - (point.y * (this.options.height! / 100));

      this.context!.beginPath();
      this.context!.arc(x, y, radius, 0, 2 * Math.PI);
      this.context!.fill();
    });
  }

  private drawAreaSeries(series: DataSeries, color: string): void {
    if (!this.context) return;

    this.context.fillStyle = color + '40'; // Add transparency
    this.context.beginPath();

    // Start from bottom left
    this.context.moveTo(0, this.options.height!);

    series.data.forEach((point, index) => {
      const x = (typeof point.x === 'number' ? point.x : index) * (this.options.width! / 100);
      const y = this.options.height! - (point.y * (this.options.height! / 100));
      this.context!.lineTo(x, y);
    });

    // Close the area
    const lastPoint = series.data[series.data.length - 1];
    const lastX = (typeof lastPoint.x === 'number' ? lastPoint.x : series.data.length - 1) * (this.options.width! / 100);
    this.context.lineTo(lastX, this.options.height!);
    this.context.closePath();
    this.context.fill();

    // Draw the line on top
    this.drawLineSeries(series, color);
  }

  private drawLegend(): void {
    if (!this.context) return;

    const legendY = 20;
    let legendX = 20;

    this.context.font = '12px Arial';
    this.context.fillStyle = this.options.theme === 'dark' ? '#ecf0f1' : '#34495e';

    this.series.forEach((series, index) => {
      const color = series.color || this.options.colors![index % this.options.colors!.length];
      
      // Draw color indicator
      this.context!.fillStyle = color;
      this.context!.fillRect(legendX, legendY - 8, 12, 12);
      
      // Draw series name
      this.context!.fillStyle = this.options.theme === 'dark' ? '#ecf0f1' : '#34495e';
      this.context!.fillText(series.name, legendX + 18, legendY + 2);
      
      legendX += this.context!.measureText(series.name).width + 50;
    });
  }

  private drawTitle(): void {
    if (!this.context || !this.options.title) return;

    this.context.font = 'bold 16px Arial';
    this.context.fillStyle = this.options.theme === 'dark' ? '#ecf0f1' : '#34495e';
    this.context.textAlign = 'center';
    this.context.fillText(this.options.title, this.options.width! / 2, 30);
    this.context.textAlign = 'left'; // Reset alignment
  }

  // Public methods
  public updateSeries(newSeries: DataSeries[]): void {
    this.series = newSeries;
    this.render();
  }

  public updateOptions(newOptions: Partial<ChartOptions>): void {
    this.options = { ...this.options, ...newOptions };
    this.render();
  }

  public exportAsImage(format: 'png' | 'jpeg' = 'png'): string {
    if (!this.canvas) throw new Error('Canvas not initialized');
    return this.canvas.toDataURL(`image/${format}`);
  }

  public destroy(): void {
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame);
    }
    if (this.canvas && this.canvas.parentNode) {
      this.canvas.parentNode.removeChild(this.canvas);
    }
  }
}