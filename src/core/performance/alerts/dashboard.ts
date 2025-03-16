/**
 * Performance Alerts Dashboard
 * 
 * Visualizes performance alerts and regressions in a dashboard.
 */

import { RegressionResult, AlertSeverity } from './detector';
import { ThresholdConfiguration } from './thresholds';

/**
 * Configuration options for the alerts dashboard
 */
export interface AlertsDashboardConfig {
  /**
   * HTML container element for the dashboard
   */
  container: HTMLElement;
  
  /**
   * How often to update the dashboard, in milliseconds
   * Default: 5000 (5 seconds)
   */
  updateInterval?: number;
  
  /**
   * Maximum number of alerts to display
   * Default: 50
   */
  maxAlerts?: number;
  
  /**
   * Whether to group similar alerts
   * Default: true
   */
  groupAlerts?: boolean;
  
  /**
   * Visual styling options
   */
  styles?: {
    /**
     * Background color
     */
    backgroundColor?: string;
    
    /**
     * Text color
     */
    textColor?: string;
    
    /**
     * Border color
     */
    borderColor?: string;
    
    /**
     * Header background color
     */
    headerBackgroundColor?: string;
    
    /**
     * Alert colors by severity
     */
    alertColors?: {
      info: string;
      warning: string;
      critical: string;
    };
  };
  
  /**
   * Whether to auto-start the dashboard updates
   * Default: true
   */
  autoStart?: boolean;
}

/**
 * Default styles for the dashboard
 */
const DEFAULT_STYLES = {
  backgroundColor: '#111',
  textColor: '#eee',
  borderColor: '#333',
  headerBackgroundColor: '#222',
  alertColors: {
    info: '#2196f3', // Blue
    warning: '#ff9800', // Orange 
    critical: '#f44336' // Red
  }
};

/**
 * Visualizes performance alerts and regressions
 */
export class AlertsDashboard {
  /**
   * Configuration for the dashboard
   */
  private config: Required<AlertsDashboardConfig>;
  
  /**
   * Container element
   */
  private container: HTMLElement;
  
  /**
   * Dashboard elements
   */
  private elements: {
    header: HTMLElement;
    alertsContainer: HTMLElement;
    thresholdsContainer: HTMLElement;
    actionsContainer: HTMLElement;
    statusText: HTMLElement;
    clearButton: HTMLButtonElement;
    refreshButton: HTMLButtonElement;
  };
  
  /**
   * Current alerts to display
   */
  private alerts: RegressionResult[] = [];
  
  /**
   * Update timer
   */
  private updateTimer: ReturnType<typeof setInterval> | null = null;
  
  /**
   * Latest update timestamp
   */
  private lastUpdateTime: number = 0;
  
  /**
   * Creates a new AlertsDashboard
   */
  constructor(config: AlertsDashboardConfig) {
    // Initialize configuration with defaults
    this.config = {
      container: config.container,
      updateInterval: config.updateInterval ?? 5000,
      maxAlerts: config.maxAlerts ?? 50,
      groupAlerts: config.groupAlerts ?? true,
      styles: {
        ...DEFAULT_STYLES,
        ...config.styles,
        alertColors: {
          ...DEFAULT_STYLES.alertColors,
          ...config.styles?.alertColors
        }
      },
      autoStart: config.autoStart ?? true
    };
    
    this.container = this.config.container;
    
    // Create dashboard elements
    this.elements = this.createDashboardElements();
    
    // Start dashboard updates if auto-start is enabled
    if (this.config.autoStart) {
      this.start();
    }
  }
  
  /**
   * Start updating the dashboard
   */
  public start(): void {
    if (this.updateTimer !== null) {
      return; // Already started
    }
    
    this.updateTimer = setInterval(() => {
      this.updateLastUpdateTime();
    }, this.config.updateInterval);
    
    this.updateLastUpdateTime();
  }
  
  /**
   * Stop updating the dashboard
   */
  public stop(): void {
    if (this.updateTimer !== null) {
      clearInterval(this.updateTimer);
      this.updateTimer = null;
    }
  }
  
  /**
   * Add alert(s) to the dashboard
   */
  public addAlerts(alerts: RegressionResult | RegressionResult[]): void {
    const alertsArray = Array.isArray(alerts) ? alerts : [alerts];
    
    // Add the new alerts
    this.alerts = [...this.alerts, ...alertsArray];
    
    // Sort by timestamp (newest first) and limit to max alerts
    this.alerts = this.alerts
      .sort((a, b) => b.timestamp - a.timestamp)
      .slice(0, this.config.maxAlerts);
    
    // Update the dashboard
    this.renderAlerts();
  }
  
  /**
   * Clear all alerts from the dashboard
   */
  public clearAlerts(): void {
    this.alerts = [];
    this.renderAlerts();
  }
  
  /**
   * Set threshold configuration to display
   */
  public setThresholds(thresholds: ThresholdConfiguration): void {
    this.renderThresholds(thresholds);
  }
  
  /**
   * Force a refresh of the dashboard
   */
  public refresh(): void {
    this.renderAlerts();
    this.updateLastUpdateTime();
  }
  
  /**
   * Create the dashboard elements
   */
  private createDashboardElements(): {
    header: HTMLElement;
    alertsContainer: HTMLElement;
    thresholdsContainer: HTMLElement;
    actionsContainer: HTMLElement;
    statusText: HTMLElement;
    clearButton: HTMLButtonElement;
    refreshButton: HTMLButtonElement;
  } {
    // Clear container
    this.container.innerHTML = '';
    this.container.style.fontFamily = 'sans-serif';
    this.container.style.backgroundColor = this.config.styles.backgroundColor;
    this.container.style.color = this.config.styles.textColor;
    this.container.style.padding = '10px';
    this.container.style.borderRadius = '4px';
    this.container.style.border = `1px solid ${this.config.styles.borderColor}`;
    this.container.style.maxHeight = '100%';
    this.container.style.overflow = 'auto';
    
    // Create header
    const header = document.createElement('div');
    header.style.display = 'flex';
    header.style.justifyContent = 'space-between';
    header.style.alignItems = 'center';
    header.style.padding = '10px';
    header.style.marginBottom = '10px';
    header.style.backgroundColor = this.config.styles.headerBackgroundColor;
    header.style.borderRadius = '4px';
    
    const title = document.createElement('h2');
    title.textContent = 'Performance Alerts';
    title.style.margin = '0';
    title.style.fontSize = '18px';
    header.appendChild(title);
    
    // Create status text (last updated time)
    const statusText = document.createElement('div');
    statusText.style.fontSize = '12px';
    statusText.style.opacity = '0.7';
    header.appendChild(statusText);
    
    this.container.appendChild(header);
    
    // Create actions container (buttons)
    const actionsContainer = document.createElement('div');
    actionsContainer.style.display = 'flex';
    actionsContainer.style.gap = '10px';
    actionsContainer.style.marginBottom = '15px';
    
    // Create refresh button
    const refreshButton = document.createElement('button');
    refreshButton.textContent = 'Refresh';
    this.applyButtonStyles(refreshButton);
    refreshButton.addEventListener('click', () => this.refresh());
    actionsContainer.appendChild(refreshButton);
    
    // Create clear button
    const clearButton = document.createElement('button');
    clearButton.textContent = 'Clear Alerts';
    this.applyButtonStyles(clearButton);
    clearButton.addEventListener('click', () => this.clearAlerts());
    actionsContainer.appendChild(clearButton);
    
    this.container.appendChild(actionsContainer);
    
    // Create main content container with tabs
    const tabsContainer = document.createElement('div');
    tabsContainer.style.display = 'flex';
    tabsContainer.style.flexDirection = 'column';
    tabsContainer.style.gap = '10px';
    
    // Create alert container
    const alertsSection = document.createElement('div');
    alertsSection.style.marginBottom = '20px';
    
    const alertsTitle = document.createElement('h3');
    alertsTitle.textContent = 'Recent Alerts';
    alertsTitle.style.fontSize = '16px';
    alertsTitle.style.marginBottom = '10px';
    alertsSection.appendChild(alertsTitle);
    
    const alertsContainer = document.createElement('div');
    alertsContainer.style.display = 'flex';
    alertsContainer.style.flexDirection = 'column';
    alertsContainer.style.gap = '8px';
    alertsSection.appendChild(alertsContainer);
    
    tabsContainer.appendChild(alertsSection);
    
    // Create thresholds container
    const thresholdsSection = document.createElement('div');
    
    const thresholdsTitle = document.createElement('h3');
    thresholdsTitle.textContent = 'Performance Thresholds';
    thresholdsTitle.style.fontSize = '16px';
    thresholdsTitle.style.marginBottom = '10px';
    thresholdsSection.appendChild(thresholdsTitle);
    
    const thresholdsContainer = document.createElement('div');
    thresholdsContainer.style.display = 'flex';
    thresholdsContainer.style.flexDirection = 'column';
    thresholdsContainer.style.gap = '15px';
    thresholdsSection.appendChild(thresholdsContainer);
    
    tabsContainer.appendChild(thresholdsSection);
    
    this.container.appendChild(tabsContainer);
    
    return {
      header,
      alertsContainer,
      thresholdsContainer,
      actionsContainer,
      statusText,
      clearButton,
      refreshButton
    };
  }
  
  /**
   * Render the alerts
   */
  private renderAlerts(): void {
    const container = this.elements.alertsContainer;
    container.innerHTML = '';
    
    if (this.alerts.length === 0) {
      const emptyMessage = document.createElement('div');
      emptyMessage.textContent = 'No alerts to display';
      emptyMessage.style.padding = '20px';
      emptyMessage.style.textAlign = 'center';
      emptyMessage.style.opacity = '0.5';
      container.appendChild(emptyMessage);
      return;
    }
    
    // Create a map to group similar alerts if grouping is enabled
    const alertGroups: Map<string, {
      alert: RegressionResult;
      count: number;
      latestTimestamp: number;
    }> = new Map();
    
    // Group alerts if enabled
    if (this.config.groupAlerts) {
      for (const alert of this.alerts) {
        const groupKey = `${alert.metricName}:${alert.severity}:${alert.context || 'global'}`;
        
        if (alertGroups.has(groupKey)) {
          // Add to existing group
          const group = alertGroups.get(groupKey);
          if (group) {
            group.count++;
            group.latestTimestamp = Math.max(group.latestTimestamp, alert.timestamp);
          }
        } else {
          // Create new group
          alertGroups.set(groupKey, {
            alert,
            count: 1,
            latestTimestamp: alert.timestamp
          });
        }
      }
      
      // Render each group
      const sortedGroups = Array.from(alertGroups.values())
        .sort((a, b) => b.latestTimestamp - a.latestTimestamp);
      
      for (const group of sortedGroups) {
        container.appendChild(
          this.createAlertElement(group.alert, group.count)
        );
      }
    } else {
      // Render each alert individually
      for (const alert of this.alerts) {
        container.appendChild(
          this.createAlertElement(alert)
        );
      }
    }
  }
  
  /**
   * Create an alert element
   */
  private createAlertElement(alert: RegressionResult, count?: number): HTMLElement {
    const alertElement = document.createElement('div');
    alertElement.style.padding = '12px';
    alertElement.style.borderRadius = '4px';
    alertElement.style.border = `1px solid ${this.config.styles.alertColors[alert.severity]}`;
    alertElement.style.backgroundColor = `${this.config.styles.alertColors[alert.severity]}22`; // 22 = 13% opacity
    
    // Alert header
    const alertHeader = document.createElement('div');
    alertHeader.style.display = 'flex';
    alertHeader.style.justifyContent = 'space-between';
    alertHeader.style.alignItems = 'center';
    alertHeader.style.marginBottom = '8px';
    
    // Left side: metric name and severity
    const alertTitle = document.createElement('div');
    alertTitle.style.fontWeight = 'bold';
    alertTitle.style.fontSize = '14px';
    
    const severityBadge = document.createElement('span');
    severityBadge.textContent = alert.severity.toUpperCase();
    severityBadge.style.backgroundColor = this.config.styles.alertColors[alert.severity];
    severityBadge.style.color = '#fff';
    severityBadge.style.padding = '2px 6px';
    severityBadge.style.borderRadius = '3px';
    severityBadge.style.fontSize = '10px';
    severityBadge.style.marginRight = '8px';
    alertTitle.appendChild(severityBadge);
    
    const metricName = document.createElement('span');
    metricName.textContent = alert.metricName;
    alertTitle.appendChild(metricName);
    
    // Add count if grouped
    if (count && count > 1) {
      const countBadge = document.createElement('span');
      countBadge.textContent = `×${count}`;
      countBadge.style.backgroundColor = this.config.styles.headerBackgroundColor;
      countBadge.style.color = this.config.styles.textColor;
      countBadge.style.padding = '2px 6px';
      countBadge.style.borderRadius = '3px';
      countBadge.style.fontSize = '10px';
      countBadge.style.marginLeft = '8px';
      alertTitle.appendChild(countBadge);
    }
    
    alertHeader.appendChild(alertTitle);
    
    // Right side: timestamp
    const timestamp = document.createElement('div');
    timestamp.textContent = new Date(alert.timestamp).toLocaleTimeString();
    timestamp.style.fontSize = '12px';
    timestamp.style.opacity = '0.7';
    alertHeader.appendChild(timestamp);
    
    alertElement.appendChild(alertHeader);
    
    // Alert details
    const alertDetails = document.createElement('div');
    alertDetails.style.display = 'flex';
    alertDetails.style.flexDirection = 'column';
    alertDetails.style.gap = '4px';
    alertDetails.style.fontSize = '13px';
    
    // Value information
    const valueRow = document.createElement('div');
    valueRow.style.display = 'flex';
    valueRow.style.justifyContent = 'space-between';
    
    const valueLabel = document.createElement('span');
    valueLabel.textContent = 'Current Value:';
    valueLabel.style.opacity = '0.7';
    valueRow.appendChild(valueLabel);
    
    const valueText = document.createElement('span');
    // Use optional chaining and nullish coalescing to safely handle undefined unit
    const unit = alert.threshold?.unit ?? '';
    valueText.textContent = `${alert.currentValue.toFixed(2)} ${unit}`;
    valueText.style.fontWeight = 'bold';
    valueRow.appendChild(valueText);
    
    alertDetails.appendChild(valueRow);
    
    // Change information
    const changeRow = document.createElement('div');
    changeRow.style.display = 'flex';
    changeRow.style.justifyContent = 'space-between';
    
    const changeLabel = document.createElement('span');
    changeLabel.textContent = 'Change:';
    changeLabel.style.opacity = '0.7';
    changeRow.appendChild(changeLabel);
    
    const changeText = document.createElement('span');
    const changeDirection = alert.isRegression ? '↑' : '↓';
    const changeColor = alert.isRegression ? 
      this.config.styles.alertColors.critical : 
      this.config.styles.alertColors.info;
    
    changeText.innerHTML = `${changeDirection} ${Math.abs(alert.percentageChange).toFixed(1)}% from ${alert.baselineValue.toFixed(2)}`;
    changeText.style.color = changeColor;
    changeRow.appendChild(changeText);
    
    alertDetails.appendChild(changeRow);
    
    // Context information if available
    if (alert.context) {
      const contextRow = document.createElement('div');
      contextRow.style.display = 'flex';
      contextRow.style.justifyContent = 'space-between';
      
      const contextLabel = document.createElement('span');
      contextLabel.textContent = 'Context:';
      contextLabel.style.opacity = '0.7';
      contextRow.appendChild(contextLabel);
      
      const contextText = document.createElement('span');
      contextText.textContent = alert.context;
      contextRow.appendChild(contextText);
      
      alertDetails.appendChild(contextRow);
    }
    
    // Threshold information
    const thresholdRow = document.createElement('div');
    thresholdRow.style.display = 'flex';
    thresholdRow.style.justifyContent = 'space-between';
    
    const thresholdLabel = document.createElement('span');
    thresholdLabel.textContent = 'Thresholds:';
    thresholdLabel.style.opacity = '0.7';
    thresholdRow.appendChild(thresholdLabel);
    
    const thresholdText = document.createElement('span');
    // Use optional chaining to safely access properties that might be undefined
    if (alert.threshold) {
      thresholdText.textContent = `Warning: ${alert.threshold.warningThreshold}, Critical: ${alert.threshold.criticalThreshold}`;
    } else {
      thresholdText.textContent = 'No thresholds defined';
    }
    thresholdRow.appendChild(thresholdText);
    
    alertDetails.appendChild(thresholdRow);
    
    alertElement.appendChild(alertDetails);
    
    return alertElement;
  }
  
  /**
   * Render threshold configuration
   */
  private renderThresholds(thresholds: ThresholdConfiguration): void {
    const container = this.elements.thresholdsContainer;
    container.innerHTML = '';
    
    if (!thresholds || !thresholds.groups || thresholds.groups.length === 0) {
      const emptyMessage = document.createElement('div');
      emptyMessage.textContent = 'No threshold configuration to display';
      emptyMessage.style.padding = '20px';
      emptyMessage.style.textAlign = 'center';
      emptyMessage.style.opacity = '0.5';
      container.appendChild(emptyMessage);
      return;
    }
    
    // Render each threshold group
    for (const group of thresholds.groups) {
      // Skip disabled groups
      if (group.enabled === false) continue;
      
      const groupElement = document.createElement('div');
      groupElement.style.marginBottom = '15px';
      
      // Group header
      const groupHeader = document.createElement('div');
      groupHeader.style.display = 'flex';
      groupHeader.style.justifyContent = 'space-between';
      groupHeader.style.alignItems = 'center';
      groupHeader.style.marginBottom = '8px';
      groupHeader.style.padding = '8px';
      groupHeader.style.backgroundColor = this.config.styles.headerBackgroundColor;
      groupHeader.style.borderRadius = '4px';
      
      const groupName = document.createElement('div');
      groupName.textContent = group.name;
      groupName.style.fontWeight = 'bold';
      groupName.style.textTransform = 'capitalize';
      groupHeader.appendChild(groupName);
      
      // Add description if available
      if (group.description) {
        const groupDescription = document.createElement('div');
        groupDescription.textContent = group.description;
        groupDescription.style.fontSize = '12px';
        groupDescription.style.opacity = '0.7';
        groupHeader.appendChild(groupDescription);
      }
      
      groupElement.appendChild(groupHeader);
      
      // Create a table for the metrics
      const table = document.createElement('table');
      table.style.width = '100%';
      table.style.borderCollapse = 'collapse';
      
      // Create table header
      const thead = document.createElement('thead');
      const headerRow = document.createElement('tr');
      
      const createHeader = (text: string) => {
        const th = document.createElement('th');
        th.textContent = text;
        th.style.textAlign = 'left';
        th.style.padding = '8px';
        th.style.borderBottom = `1px solid ${this.config.styles.borderColor}`;
        th.style.fontSize = '12px';
        return th;
      };
      
      headerRow.appendChild(createHeader('Metric'));
      headerRow.appendChild(createHeader('Warning'));
      headerRow.appendChild(createHeader('Critical'));
      headerRow.appendChild(createHeader('Unit'));
      
      thead.appendChild(headerRow);
      table.appendChild(thead);
      
      // Create table body
      const tbody = document.createElement('tbody');
      
      for (const metric of group.metrics) {
        const row = document.createElement('tr');
        
        const createCell = (text: string) => {
          const td = document.createElement('td');
          td.textContent = text;
          td.style.padding = '8px';
          td.style.borderBottom = `1px solid ${this.config.styles.borderColor}30`; // 30 = 19% opacity
          return td;
        };
        
        // Metric name cell
        const nameCell = createCell(metric.name);
        const description = metric.description ?? '';
        nameCell.setAttribute('title', description);
        row.appendChild(nameCell);
        
        // Warning threshold cell
        const warningCell = createCell(metric.warningThreshold.toString());
        warningCell.style.color = this.config.styles.alertColors.warning;
        row.appendChild(warningCell);
        
        // Critical threshold cell
        const criticalCell = createCell(metric.criticalThreshold.toString());
        criticalCell.style.color = this.config.styles.alertColors.critical;
        row.appendChild(criticalCell);
        
        // Unit cell
        const unitCell = createCell(metric.unit ?? '');
        unitCell.style.opacity = '0.7';
        row.appendChild(unitCell);
        
        tbody.appendChild(row);
      }
      
      table.appendChild(tbody);
      groupElement.appendChild(table);
      
      container.appendChild(groupElement);
    }
  }
  
  /**
   * Update the last update time display
   */
  private updateLastUpdateTime(): void {
    this.lastUpdateTime = Date.now();
    
    const options = { 
      hour: '2-digit', 
      minute: '2-digit', 
      second: '2-digit'
    } as Intl.DateTimeFormatOptions;
    
    this.elements.statusText.textContent = 
      `Last updated: ${new Date(this.lastUpdateTime).toLocaleTimeString(undefined, options)}`;
  }
  
  /**
   * Apply common button styles
   */
  private applyButtonStyles(button: HTMLButtonElement): void {
    button.style.padding = '8px 12px';
    button.style.border = 'none';
    button.style.borderRadius = '4px';
    button.style.backgroundColor = this.config.styles.headerBackgroundColor;
    button.style.color = this.config.styles.textColor;
    button.style.cursor = 'pointer';
    button.style.fontSize = '14px';
    
    // Add hover effect
    button.onmouseover = () => {
      button.style.backgroundColor = lightenColor(this.config.styles.headerBackgroundColor, 10);
    };
    
    button.onmouseout = () => {
      button.style.backgroundColor = this.config.styles.headerBackgroundColor;
    };
  }
}

/**
 * Helper function to lighten a color
 */
function lightenColor(color: string, percent: number): string {
  // Convert hex to RGB
  let r = parseInt(color.substring(1, 3), 16);
  let g = parseInt(color.substring(3, 5), 16);
  let b = parseInt(color.substring(5, 7), 16);
  
  // Lighten
  r = Math.min(255, Math.floor(r * (1 + percent / 100)));
  g = Math.min(255, Math.floor(g * (1 + percent / 100)));
  b = Math.min(255, Math.floor(b * (1 + percent / 100)));
  
  // Convert back to hex
  return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`;
} 