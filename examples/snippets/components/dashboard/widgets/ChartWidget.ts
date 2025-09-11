/**
 * Chart Widget Component
 * 
 * A dashboard widget that displays charts using the Chart visualization component.
 */

import { Chart, ChartOptions, DataSeries } from '../../visualization/Chart';
import { WidgetConfig } from '../types';

export interface ChartWidgetConfig extends WidgetConfig {
  type: 'chart';
  data: {
    series: DataSeries[];
    options?: ChartOptions;
  };
  options?: {
    showToolbar?: boolean;
    allowExport?: boolean;
    autoRefresh?: boolean;
    refreshInterval?: number;
  };
}

export interface ChartWidgetEvents {
  onDataUpdate?: (widgetId: string, data: DataSeries[]) => void;
  onExport?: (widgetId: string, format: 'png' | 'jpeg' | 'json') => void;
  onRefresh?: (widgetId: string) => void;
  onChartClick?: (widgetId: string, point: any, series: DataSeries) => void;
}

export class ChartWidget {
  private container: HTMLElement;
  private config: ChartWidgetConfig;
  private events: ChartWidgetEvents;
  private chart?: Chart;
  private toolbar?: HTMLElement;
  private refreshInterval?: number;

  constructor(
    container: HTMLElement,
    config: ChartWidgetConfig,
    events: ChartWidgetEvents = {}
  ) {
    this.container = container;
    this.config = config;
    this.events = events;

    this.initialize();
  }

  private initialize(): void {
    this.createToolbar();
    this.createChart();
    this.setupAutoRefresh();
  }

  private createToolbar(): void {
    if (!this.config.options?.showToolbar) return;

    this.toolbar = document.createElement('div');
    this.toolbar.className = 'chart-widget-toolbar';
    this.toolbar.style.cssText = `
      display: flex;
      justify-content: flex-end;
      gap: 8px;
      padding: 8px;
      border-bottom: 1px solid #e0e0e0;
      background-color: #f8f9fa;
    `;

    // Refresh button
    const refreshBtn = this.createToolbarButton('🔄', 'Refresh data');
    refreshBtn.addEventListener('click', () => this.refresh());
    this.toolbar.appendChild(refreshBtn);

    // Export buttons
    if (this.config.options?.allowExport) {
      const exportPngBtn = this.createToolbarButton('📊', 'Export as PNG');
      exportPngBtn.addEventListener('click', () => this.exportChart('png'));
      this.toolbar.appendChild(exportPngBtn);

      const exportJsonBtn = this.createToolbarButton('📄', 'Export as JSON');
      exportJsonBtn.addEventListener('click', () => this.exportChart('json'));
      this.toolbar.appendChild(exportJsonBtn);
    }

    // Chart type selector
    const typeSelector = document.createElement('select');
    typeSelector.style.cssText = `
      padding: 4px 8px;
      border: 1px solid #ccc;
      border-radius: 4px;
      background-color: white;
      font-size: 12px;
    `;

    const chartTypes = [
      { value: 'line', label: 'Line Chart' },
      { value: 'bar', label: 'Bar Chart' },
      { value: 'scatter', label: 'Scatter Plot' },
      { value: 'area', label: 'Area Chart' }
    ];

    chartTypes.forEach(type => {
      const option = document.createElement('option');
      option.value = type.value;
      option.textContent = type.label;
      typeSelector.appendChild(option);
    });

    typeSelector.addEventListener('change', (e) => {
      const newType = (e.target as HTMLSelectElement).value as any;
      this.updateChartType(newType);
    });

    this.toolbar.appendChild(typeSelector);
    this.container.appendChild(this.toolbar);
  }

  private createToolbarButton(symbol: string, title: string): HTMLButtonElement {
    const button = document.createElement('button');
    button.textContent = symbol;
    button.title = title;
    button.style.cssText = `
      padding: 4px 8px;
      border: 1px solid #ccc;
      border-radius: 4px;
      background-color: white;
      cursor: pointer;
      font-size: 12px;
      transition: background-color 0.2s;
    `;

    button.addEventListener('mouseenter', () => {
      button.style.backgroundColor = '#e9ecef';
    });

    button.addEventListener('mouseleave', () => {
      button.style.backgroundColor = 'white';
    });

    return button;
  }

  private createChart(): void {
    const chartContainer = document.createElement('div');
    chartContainer.className = 'chart-widget-content';
    chartContainer.style.cssText = `
      position: relative;
      width: 100%;
      height: ${this.toolbar ? 'calc(100% - 48px)' : '100%'};
      overflow: hidden;
    `;

    this.container.appendChild(chartContainer);

    // Calculate chart dimensions
    const containerRect = chartContainer.getBoundingClientRect();
    const chartOptions: ChartOptions = {
      width: containerRect.width || 400,
      height: containerRect.height || 300,
      ...this.config.data.options
    };

    // Create chart with event handlers
    this.chart = new Chart(
      chartContainer,
      this.config.data.series,
      chartOptions,
      {
        onPointClick: (point, series) => {
          if (this.events.onChartClick) {
            this.events.onChartClick(this.config.id, point, series);
          }
        },
        onPointHover: (point, series) => {
          this.showTooltip(point, series);
        }
      }
    );
  }

  private showTooltip(point: any, series: DataSeries): void {
    // Remove existing tooltip
    const existingTooltip = this.container.querySelector('.chart-tooltip');
    if (existingTooltip) {
      existingTooltip.remove();
    }

    // Create new tooltip
    const tooltip = document.createElement('div');
    tooltip.className = 'chart-tooltip';
    tooltip.style.cssText = `
      position: absolute;
      background-color: rgba(0, 0, 0, 0.8);
      color: white;
      padding: 8px 12px;
      border-radius: 4px;
      font-size: 12px;
      pointer-events: none;
      z-index: 1000;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      white-space: nowrap;
    `;

    tooltip.innerHTML = `
      <div><strong>${series.name}</strong></div>
      <div>X: ${point.x}</div>
      <div>Y: ${point.y}</div>
      ${point.label ? `<div>${point.label}</div>` : ''}
    `;

    this.container.appendChild(tooltip);

    // Auto-remove tooltip after 3 seconds
    setTimeout(() => {
      if (tooltip.parentNode) {
        tooltip.remove();
      }
    }, 3000);
  }

  private updateChartType(newType: 'line' | 'bar' | 'scatter' | 'area'): void {
    if (!this.chart) return;

    // Update all series to use new type
    const updatedSeries = this.config.data.series.map(series => ({
      ...series,
      type: newType
    }));

    this.config.data.series = updatedSeries;
    this.chart.updateSeries(updatedSeries);

    // Trigger data update event
    if (this.events.onDataUpdate) {
      this.events.onDataUpdate(this.config.id, updatedSeries);
    }
  }

  private refresh(): void {
    if (this.events.onRefresh) {
      this.events.onRefresh(this.config.id);
    }

    // Animate refresh button
    const refreshBtn = this.toolbar?.querySelector('button');
    if (refreshBtn) {
      refreshBtn.style.transform = 'rotate(360deg)';
      refreshBtn.style.transition = 'transform 0.5s ease';
      
      setTimeout(() => {
        refreshBtn.style.transform = 'rotate(0deg)';
        refreshBtn.style.transition = '';
      }, 500);
    }
  }

  private exportChart(format: 'png' | 'jpeg' | 'json'): void {
    if (!this.chart) return;

    try {
      let exportData: string;

      if (format === 'json') {
        exportData = JSON.stringify({
          config: this.config,
          data: this.config.data,
          timestamp: new Date().toISOString()
        }, null, 2);

        // Create and download JSON file
        const blob = new Blob([exportData], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `chart-${this.config.id}-${Date.now()}.json`;
        link.click();
        URL.revokeObjectURL(url);
      } else {
        exportData = this.chart.exportAsImage(format);

        // Create and download image file
        const link = document.createElement('a');
        link.href = exportData;
        link.download = `chart-${this.config.id}-${Date.now()}.${format}`;
        link.click();
      }

      if (this.events.onExport) {
        this.events.onExport(this.config.id, format);
      }
    } catch (error) {
      console.error('Failed to export chart:', error);
    }
  }

  private setupAutoRefresh(): void {
    if (!this.config.options?.autoRefresh) return;

    const interval = this.config.options.refreshInterval || 30000; // Default 30 seconds

    this.refreshInterval = setInterval(() => {
      this.refresh();
    }, interval) as any;
  }

  // Public methods
  public updateData(newSeries: DataSeries[]): void {
    this.config.data.series = newSeries;
    
    if (this.chart) {
      this.chart.updateSeries(newSeries);
    }

    if (this.events.onDataUpdate) {
      this.events.onDataUpdate(this.config.id, newSeries);
    }
  }

  public updateOptions(newOptions: Partial<ChartOptions>): void {
    this.config.data.options = { ...this.config.data.options, ...newOptions };
    
    if (this.chart) {
      this.chart.updateOptions(newOptions);
    }
  }

  public resize(width: number, height: number): void {
    if (this.chart) {
      this.chart.updateOptions({ width, height });
    }
  }

  public getConfig(): ChartWidgetConfig {
    return { ...this.config };
  }

  public getData(): DataSeries[] {
    return [...this.config.data.series];
  }

  public destroy(): void {
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval);
    }

    if (this.chart) {
      this.chart.destroy();
    }

    // Remove tooltips
    const tooltip = this.container.querySelector('.chart-tooltip');
    if (tooltip) {
      tooltip.remove();
    }

    this.container.innerHTML = '';
  }

  // Static factory method
  public static create(
    container: HTMLElement,
    config: Partial<ChartWidgetConfig>,
    events?: ChartWidgetEvents
  ): ChartWidget {
    const defaultConfig: ChartWidgetConfig = {
      id: `chart-widget-${Date.now()}`,
      type: 'chart',
      title: 'Chart Widget',
      position: { x: 0, y: 0, width: 2, height: 2 },
      data: {
        series: [],
        options: {
          width: 400,
          height: 300,
          title: 'Sample Chart'
        }
      },
      options: {
        showToolbar: true,
        allowExport: true,
        autoRefresh: false,
        refreshInterval: 30000
      }
    };

    const mergedConfig = { ...defaultConfig, ...config } as ChartWidgetConfig;
    return new ChartWidget(container, mergedConfig, events);
  }
}