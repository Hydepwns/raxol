/**
 * MemoryDashboard.ts
 * 
 * Provides visualization and dashboard functionality for memory usage monitoring.
 * This component can be used to track memory consumption in real-time and
 * identify potential memory leaks or optimization opportunities.
 */

import { MemoryProfiler } from './MemoryProfiler';

interface DashboardOptions {
  container: HTMLElement;
  updateInterval?: number;
  maxDataPoints?: number;
  showComponentBreakdown?: boolean;
  showHistoricalTrend?: boolean;
  warningThreshold?: number;
  criticalThreshold?: number;
}

interface MemoryDataPoint {
  timestamp: number;
  total: number;
  used: number;
  components: Map<string, number>;
}

export class MemoryDashboard {
  private container: HTMLElement;
  private profiler: MemoryProfiler;
  private options: Required<DashboardOptions>;
  private updateIntervalId: number | null = null;
  private dataPoints: MemoryDataPoint[] = [];
  private elements: {
    title: HTMLElement;
    summary: HTMLElement;
    chart: HTMLElement;
    componentList: HTMLElement;
    controls: HTMLElement;
  };
  
  constructor(profiler: MemoryProfiler, options: DashboardOptions) {
    this.profiler = profiler;
    this.container = options.container;
    
    // Set default options
    this.options = {
      container: options.container,
      updateInterval: options.updateInterval ?? 1000,
      maxDataPoints: options.maxDataPoints ?? 60,
      showComponentBreakdown: options.showComponentBreakdown ?? true,
      showHistoricalTrend: options.showHistoricalTrend ?? true,
      warningThreshold: options.warningThreshold ?? 75 * 1024 * 1024, // 75MB
      criticalThreshold: options.criticalThreshold ?? 150 * 1024 * 1024 // 150MB
    };
    
    // Initialize the dashboard UI
    this.elements = this.createDashboardElements();
    
    // Listen to profiler events
    this.profiler.addListener(this.handleMemorySnapshot.bind(this));
  }
  
  /**
   * Start updating the dashboard
   */
  public start(): void {
    if (this.updateIntervalId !== null) {
      return;
    }
    
    // Take initial snapshot
    this.updateDashboard();
    
    // Set up interval for regular updates
    this.updateIntervalId = window.setInterval(() => {
      this.updateDashboard();
    }, this.options.updateInterval) as unknown as number;
  }
  
  /**
   * Stop updating the dashboard
   */
  public stop(): void {
    if (this.updateIntervalId !== null) {
      window.clearInterval(this.updateIntervalId);
      this.updateIntervalId = null;
    }
  }
  
  /**
   * Manually update the dashboard
   */
  public updateDashboard(): void {
    const snapshot = this.profiler.takeSnapshot();
    this.handleMemorySnapshot(snapshot);
  }
  
  /**
   * Clear all data points
   */
  public clearData(): void {
    this.dataPoints = [];
    this.updateDisplay();
  }
  
  /**
   * Handle a new memory snapshot
   */
  private handleMemorySnapshot(snapshot: any): void {
    // Extract relevant data
    const dataPoint: MemoryDataPoint = {
      timestamp: snapshot.timestamp,
      total: snapshot.totalJSHeapSize || 0,
      used: snapshot.usedJSHeapSize || 0,
      components: snapshot.componentMemoryUsage
    };
    
    // Add to data points
    this.dataPoints.push(dataPoint);
    
    // Trim data points if exceeding max
    if (this.dataPoints.length > this.options.maxDataPoints) {
      this.dataPoints.shift();
    }
    
    // Update the display
    this.updateDisplay();
  }
  
  /**
   * Update the dashboard display
   */
  private updateDisplay(): void {
    // Skip if no data points
    if (this.dataPoints.length === 0) {
      return;
    }
    
    const latestData = this.dataPoints[this.dataPoints.length - 1];
    
    // Update summary information
    this.updateSummary(latestData);
    
    // Update chart if enabled
    if (this.options.showHistoricalTrend) {
      this.updateChart();
    }
    
    // Update component breakdown if enabled
    if (this.options.showComponentBreakdown) {
      this.updateComponentList(latestData);
    }
  }
  
  /**
   * Update the summary section
   */
  private updateSummary(data: MemoryDataPoint): void {
    const { used, total } = data;
    const usedMB = this.formatMemorySize(used);
    const totalMB = this.formatMemorySize(total);
    const percentUsed = total > 0 ? ((used / total) * 100).toFixed(1) : 'N/A';
    
    // Determine status class based on thresholds
    let statusClass = 'status-normal';
    if (used > this.options.criticalThreshold) {
      statusClass = 'status-critical';
    } else if (used > this.options.warningThreshold) {
      statusClass = 'status-warning';
    }
    
    this.elements.summary.innerHTML = `
      <div class="memory-usage ${statusClass}">
        <div class="memory-value">Current usage: ${usedMB}</div>
        <div class="memory-total">Total available: ${totalMB}</div>
        <div class="memory-percentage">Usage: ${percentUsed}%</div>
        <div class="memory-bar">
          <div class="memory-bar-fill" style="width: ${percentUsed}%;"></div>
        </div>
      </div>
      <div class="snapshot-info">
        <div>Last update: ${this.formatTimestamp(data.timestamp)}</div>
        <div>Data points: ${this.dataPoints.length}/${this.options.maxDataPoints}</div>
      </div>
    `;
  }
  
  /**
   * Update the memory usage chart
   */
  private updateChart(): void {
    // This is a simple representation - in a real app, you'd use a proper charting library
    let chartHtml = '<div class="chart-container">';
    
    // Get max value for scaling
    const maxUsage = Math.max(...this.dataPoints.map(d => d.used));
    const chartHeight = 150; // pixels
    
    chartHtml += '<div class="chart-y-axis">';
    chartHtml += `<div class="chart-y-label">0</div>`;
    chartHtml += `<div class="chart-y-label">${this.formatMemorySize(maxUsage)}</div>`;
    chartHtml += '</div>';
    
    chartHtml += '<div class="chart-grid">';
    
    // Draw threshold lines
    const warningRatio = Math.min(1, this.options.warningThreshold / maxUsage);
    const criticalRatio = Math.min(1, this.options.criticalThreshold / maxUsage);
    
    chartHtml += `<div class="chart-threshold warning" style="bottom: ${warningRatio * chartHeight}px;"></div>`;
    chartHtml += `<div class="chart-threshold critical" style="bottom: ${criticalRatio * chartHeight}px;"></div>`;
    
    // Draw data points
    this.dataPoints.forEach((point, index) => {
      const ratio = point.used / maxUsage;
      const height = ratio * chartHeight;
      const barClass = point.used > this.options.criticalThreshold 
        ? 'critical' 
        : point.used > this.options.warningThreshold 
          ? 'warning' 
          : 'normal';
      
      chartHtml += `<div class="chart-bar ${barClass}" style="height: ${height}px; left: ${index * 100 / this.options.maxDataPoints}%;"></div>`;
    });
    
    chartHtml += '</div>'; // End chart-grid
    chartHtml += '</div>'; // End chart-container
    
    this.elements.chart.innerHTML = chartHtml;
  }
  
  /**
   * Update the component breakdown list
   */
  private updateComponentList(data: MemoryDataPoint): void {
    if (!data.components || data.components.size === 0) {
      this.elements.componentList.innerHTML = '<div class="no-data">No component data available</div>';
      return;
    }
    
    // Sort components by memory usage (descending)
    const sortedComponents = Array.from(data.components.entries())
      .sort((a, b) => b[1] - a[1]);
    
    let listHtml = `<table class="component-table">
      <thead>
        <tr>
          <th>Component</th>
          <th>Memory Usage</th>
          <th>% of Total</th>
        </tr>
      </thead>
      <tbody>
    `;
    
    sortedComponents.forEach(([componentId, memoryUsage]) => {
      const percentage = data.used > 0 ? ((memoryUsage / data.used) * 100).toFixed(1) : '0.0';
      const rowClass = memoryUsage > 5 * 1024 * 1024 ? 'high-usage' : '';
      
      listHtml += `
        <tr class="${rowClass}">
          <td>${componentId}</td>
          <td>${this.formatMemorySize(memoryUsage)}</td>
          <td>${percentage}%</td>
        </tr>
      `;
    });
    
    listHtml += '</tbody></table>';
    this.elements.componentList.innerHTML = listHtml;
  }
  
  /**
   * Format a memory size in bytes to a human-readable format
   */
  private formatMemorySize(bytes: number): string {
    if (bytes === 0) return '0 B';
    
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return `${parseFloat((bytes / Math.pow(k, i)).toFixed(2))} ${sizes[i]}`;
  }
  
  /**
   * Format a timestamp to a readable time
   */
  private formatTimestamp(timestamp: number): string {
    const date = new Date(timestamp);
    return date.toLocaleTimeString();
  }
  
  /**
   * Create the dashboard UI elements
   */
  private createDashboardElements(): {
    title: HTMLElement;
    summary: HTMLElement;
    chart: HTMLElement;
    componentList: HTMLElement;
    controls: HTMLElement;
  } {
    // Ensure container has position relative or absolute
    const containerStyle = window.getComputedStyle(this.container);
    if (containerStyle.position !== 'relative' && containerStyle.position !== 'absolute') {
      this.container.style.position = 'relative';
    }
    
    // Add dashboard CSS
    this.addDashboardStyles();
    
    // Create elements
    const dashboardDiv = document.createElement('div');
    dashboardDiv.className = 'memory-dashboard';
    this.container.appendChild(dashboardDiv);
    
    const titleDiv = document.createElement('div');
    titleDiv.className = 'dashboard-title';
    titleDiv.textContent = 'Memory Usage Dashboard';
    dashboardDiv.appendChild(titleDiv);
    
    const summaryDiv = document.createElement('div');
    summaryDiv.className = 'memory-summary';
    dashboardDiv.appendChild(summaryDiv);
    
    const chartDiv = document.createElement('div');
    chartDiv.className = 'memory-chart';
    
    // Only add chart if historical trend is enabled
    if (this.options.showHistoricalTrend) {
      dashboardDiv.appendChild(chartDiv);
    }
    
    const componentListDiv = document.createElement('div');
    componentListDiv.className = 'component-list';
    
    // Only add component list if breakdown is enabled
    if (this.options.showComponentBreakdown) {
      const componentTitle = document.createElement('h3');
      componentTitle.textContent = 'Component Memory Usage';
      dashboardDiv.appendChild(componentTitle);
      dashboardDiv.appendChild(componentListDiv);
    }
    
    const controlsDiv = document.createElement('div');
    controlsDiv.className = 'dashboard-controls';
    
    // Add buttons
    const refreshBtn = document.createElement('button');
    refreshBtn.textContent = 'Refresh';
    refreshBtn.onclick = () => this.updateDashboard();
    
    const clearBtn = document.createElement('button');
    clearBtn.textContent = 'Clear Data';
    clearBtn.onclick = () => this.clearData();
    
    const snapshotBtn = document.createElement('button');
    snapshotBtn.textContent = 'Take Snapshot';
    snapshotBtn.onclick = () => this.profiler.takeSnapshot();
    
    controlsDiv.appendChild(refreshBtn);
    controlsDiv.appendChild(clearBtn);
    controlsDiv.appendChild(snapshotBtn);
    
    dashboardDiv.appendChild(controlsDiv);
    
    return {
      title: titleDiv,
      summary: summaryDiv,
      chart: chartDiv,
      componentList: componentListDiv,
      controls: controlsDiv
    };
  }
  
  /**
   * Add dashboard styles to the document
   */
  private addDashboardStyles(): void {
    // Check if styles are already added
    if (document.getElementById('memory-dashboard-styles')) {
      return;
    }
    
    const styleEl = document.createElement('style');
    styleEl.id = 'memory-dashboard-styles';
    styleEl.textContent = `
      .memory-dashboard {
        font-family: sans-serif;
        background-color: #f5f5f5;
        border: 1px solid #ddd;
        border-radius: 4px;
        padding: 16px;
        margin: 16px 0;
        max-width: 800px;
      }
      
      .dashboard-title {
        font-size: 18px;
        font-weight: bold;
        margin-bottom: 16px;
        color: #333;
      }
      
      .memory-summary {
        margin-bottom: 24px;
      }
      
      .memory-usage {
        padding: 12px;
        border-radius: 4px;
        margin-bottom: 8px;
      }
      
      .status-normal {
        background-color: #e8f5e9;
        border-left: 4px solid #4caf50;
      }
      
      .status-warning {
        background-color: #fff8e1;
        border-left: 4px solid #ff9800;
      }
      
      .status-critical {
        background-color: #ffebee;
        border-left: 4px solid #f44336;
      }
      
      .memory-value {
        font-size: 16px;
        font-weight: bold;
        margin-bottom: 8px;
      }
      
      .memory-bar {
        height: 8px;
        background-color: #e0e0e0;
        border-radius: 4px;
        overflow: hidden;
        margin-top: 8px;
      }
      
      .memory-bar-fill {
        height: 100%;
        background-color: #2196f3;
        transition: width 0.3s ease;
      }
      
      .status-warning .memory-bar-fill {
        background-color: #ff9800;
      }
      
      .status-critical .memory-bar-fill {
        background-color: #f44336;
      }
      
      .snapshot-info {
        font-size: 12px;
        color: #757575;
        margin-top: 8px;
      }
      
      .chart-container {
        display: flex;
        height: 180px;
        margin-bottom: 24px;
        position: relative;
      }
      
      .chart-y-axis {
        width: 60px;
        height: 150px;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
        font-size: 12px;
        color: #757575;
      }
      
      .chart-grid {
        flex: 1;
        height: 150px;
        border-left: 1px solid #ddd;
        border-bottom: 1px solid #ddd;
        position: relative;
        background-color: rgba(0, 0, 0, 0.02);
      }
      
      .chart-bar {
        position: absolute;
        bottom: 0;
        width: 8px;
        margin-left: -4px;
        background-color: #2196f3;
        border-top-left-radius: 2px;
        border-top-right-radius: 2px;
      }
      
      .chart-bar.warning {
        background-color: #ff9800;
      }
      
      .chart-bar.critical {
        background-color: #f44336;
      }
      
      .chart-threshold {
        position: absolute;
        left: 0;
        right: 0;
        height: 1px;
        background-color: rgba(0, 0, 0, 0.2);
      }
      
      .chart-threshold.warning {
        background-color: #ff9800;
      }
      
      .chart-threshold.critical {
        background-color: #f44336;
      }
      
      .component-table {
        width: 100%;
        border-collapse: collapse;
        margin-bottom: 24px;
      }
      
      .component-table th {
        text-align: left;
        padding: 8px;
        border-bottom: 2px solid #ddd;
        font-weight: bold;
        color: #333;
      }
      
      .component-table td {
        padding: 8px;
        border-bottom: 1px solid #eee;
      }
      
      .component-table tr.high-usage {
        background-color: #ffebee;
      }
      
      .dashboard-controls {
        display: flex;
        gap: 8px;
      }
      
      .dashboard-controls button {
        padding: 8px 16px;
        background-color: #2196f3;
        border: none;
        border-radius: 4px;
        color: white;
        cursor: pointer;
        font-size: 14px;
      }
      
      .dashboard-controls button:hover {
        background-color: #1976d2;
      }
      
      .no-data {
        padding: 16px;
        text-align: center;
        color: #757575;
        font-style: italic;
      }
    `;
    
    document.head.appendChild(styleEl);
  }
} 