/**
 * ChartWidget.ts
 * 
 * A widget component that wraps the Chart visualization for use in the dashboard.
 * Provides controls for chart configuration and data updates.
 */

import { RaxolComponent } from '../../../core/component';
import { View } from '../../../core/renderer/view';
import { Chart, ChartOptions } from '../../visualization/Chart';
import { WidgetConfig } from '../types';

/**
 * Chart widget configuration
 */
export interface ChartWidgetConfig extends WidgetConfig {
  /**
   * Chart options
   */
  chartOptions: ChartOptions;
  
  /**
   * Whether to show chart controls
   */
  showControls?: boolean;
  
  /**
   * Whether to enable real-time updates
   */
  enableRealTime?: boolean;
  
  /**
   * Update interval in milliseconds (for real-time updates)
   */
  updateInterval?: number;
}

/**
 * Chart widget state
 */
interface ChartWidgetState {
  /**
   * Current chart options
   */
  chartOptions: ChartOptions;
  
  /**
   * Whether controls are expanded
   */
  areControlsExpanded: boolean;
  
  /**
   * Whether real-time updates are enabled
   */
  isRealTimeEnabled: boolean;
}

/**
 * Chart widget component
 */
export class ChartWidget extends RaxolComponent<ChartWidgetConfig, ChartWidgetState> {
  private chart: Chart | null = null;
  private updateTimer: number | null = null;
  
  /**
   * Constructor
   */
  constructor(props: ChartWidgetConfig) {
    super(props);
    
    // Initialize state
    this.state = {
      chartOptions: props.chartOptions,
      areControlsExpanded: false,
      isRealTimeEnabled: props.enableRealTime || false
    };
    
    // Bind methods
    this.toggleControls = this.toggleControls.bind(this);
    this.toggleRealTime = this.toggleRealTime.bind(this);
    this.updateChartType = this.updateChartType.bind(this);
    this.updateChartData = this.updateChartData.bind(this);
  }
  
  /**
   * Initialize the chart
   */
  private initializeChart(): void {
    // Create container for the chart
    const container = document.createElement('div');
    container.style.width = '100%';
    container.style.height = '100%';
    
    // Create chart instance
    this.chart = new Chart(container, this.state.chartOptions);
    
    // Add container to the widget content
    this.setContent(container);
  }
  
  /**
   * Toggle chart controls visibility
   */
  private toggleControls(): void {
    this.setState({ areControlsExpanded: !this.state.areControlsExpanded });
  }
  
  /**
   * Toggle real-time updates
   */
  private toggleRealTime(): void {
    const isEnabled = !this.state.isRealTimeEnabled;
    
    if (isEnabled) {
      // Start update timer
      this.updateTimer = window.setInterval(() => {
        this.updateChartData();
      }, this.props.updateInterval || 5000);
    } else {
      // Clear update timer
      if (this.updateTimer) {
        window.clearInterval(this.updateTimer);
        this.updateTimer = null;
      }
    }
    
    this.setState({ isRealTimeEnabled: isEnabled });
  }
  
  /**
   * Update chart type
   */
  private updateChartType(type: string): void {
    const newOptions = { ...this.state.chartOptions, type };
    this.setState({ chartOptions: newOptions });
    
    if (this.chart) {
      this.chart.updateOptions(newOptions);
    }
  }
  
  /**
   * Update chart data
   */
  private updateChartData(): void {
    // This is a placeholder - in a real implementation,
    // this would fetch new data from a data source
    const newData = this.generateSampleData();
    
    if (this.chart) {
      this.chart.updateData(newData);
    }
  }
  
  /**
   * Generate sample data for demonstration
   */
  private generateSampleData(): any[] {
    // This is just example data - in a real implementation,
    // this would come from a data source
    return [{
      name: 'Sample Data',
      data: Array.from({ length: 10 }, (_, i) => ({
        x: `Point ${i + 1}`,
        y: Math.random() * 100
      }))
    }];
  }
  
  /**
   * Render chart controls
   */
  private renderControls(): View {
    const { areControlsExpanded, isRealTimeEnabled } = this.state;
    
    if (!areControlsExpanded) {
      return View.box({
        border: 'none',
        children: [
          View.button({
            label: 'Show Controls',
            onClick: this.toggleControls
          })
        ]
      });
    }
    
    return View.box({
      border: 'single',
      children: [
        // Chart type selector
        View.select({
          label: 'Chart Type',
          options: [
            { value: 'line', label: 'Line' },
            { value: 'bar', label: 'Bar' },
            { value: 'area', label: 'Area' },
            { value: 'pie', label: 'Pie' }
          ],
          onChange: (value) => this.updateChartType(value)
        }),
        
        // Real-time toggle
        View.button({
          label: isRealTimeEnabled ? 'Disable Real-time' : 'Enable Real-time',
          onClick: this.toggleRealTime
        }),
        
        // Hide controls button
        View.button({
          label: 'Hide Controls',
          onClick: this.toggleControls
        })
      ]
    });
  }
  
  /**
   * Render the widget
   */
  render(): View {
    // Initialize chart if not already done
    if (!this.chart) {
      this.initializeChart();
    }
    
    return View.box({
      border: 'single',
      children: [
        // Widget header
        View.box({
          border: 'none',
          children: [
            View.text(this.props.title),
            View.button({
              label: this.state.areControlsExpanded ? '▲' : '▼',
              onClick: this.toggleControls
            })
          ]
        }),
        
        // Chart controls
        this.renderControls(),
        
        // Chart content (handled by initializeChart)
        View.box({
          border: 'none',
          style: {
            flex: 1,
            minHeight: '200px'
          }
        })
      ]
    });
  }
  
  /**
   * Clean up resources
   */
  destroy(): void {
    if (this.updateTimer) {
      window.clearInterval(this.updateTimer);
      this.updateTimer = null;
    }
    
    if (this.chart) {
      this.chart.destroy();
      this.chart = null;
    }
  }
} 