/**
 * Performance Alert Notifier
 * 
 * Manages and delivers notifications about performance issues.
 */

import { RegressionResult, AlertSeverity } from './detector';

/**
 * Configuration for a notification channel
 */
export interface NotificationChannel {
  /**
   * Name of the channel
   */
  name: string;
  
  /**
   * Handler function that delivers the notification
   */
  handler: (alert: AlertNotification) => Promise<void> | void;
  
  /**
   * Minimum severity level to notify on this channel
   * Default: warning
   */
  minSeverity?: AlertSeverity;
  
  /**
   * Whether the channel is enabled
   * Default: true
   */
  enabled?: boolean;
}

/**
 * An alert notification to be sent
 */
export interface AlertNotification {
  /**
   * Title of the notification
   */
  title: string;
  
  /**
   * Detailed message
   */
  message: string;
  
  /**
   * Severity level
   */
  severity: AlertSeverity;
  
  /**
   * The metric that triggered the alert
   */
  metricName: string;
  
  /**
   * The metric's current value
   */
  value: number;
  
  /**
   * Timestamp when the alert was generated
   */
  timestamp: number;
  
  /**
   * Component or context where the issue was detected
   */
  context?: string;
  
  /**
   * Additional data about the alert
   */
  data?: Record<string, any>;
}

/**
 * Configuration for the alert notifier
 */
export interface AlertNotifierConfig {
  /**
   * Notification channels to use
   */
  channels?: NotificationChannel[];
  
  /**
   * Format for notification titles
   * May include placeholders: {severity}, {metricName}, {context}
   */
  titleFormat?: string;
  
  /**
   * Format for notification messages
   * May include placeholders: {severity}, {metricName}, {value}, {unit}, 
   * {baseline}, {change}, {percentChange}, {context}, {description}
   */
  messageFormat?: string;
  
  /**
   * Whether to group similar alerts
   * Default: true
   */
  groupSimilarAlerts?: boolean;
  
  /**
   * Time window (in ms) for grouping similar alerts
   * Default: 300000 (5 minutes)
   */
  groupingWindow?: number;
}

/**
 * Default console notification channel
 */
export const consoleNotificationChannel: NotificationChannel = {
  name: 'console',
  handler: (alert: AlertNotification) => {
    const consoleMethod = alert.severity === 'critical' ? 'error' : 
                        alert.severity === 'warning' ? 'warn' : 'info';
    
    console[consoleMethod](
      `[${alert.severity.toUpperCase()}] ${alert.title}`,
      '\n',
      alert.message,
      '\n',
      alert.data || {}
    );
  },
  minSeverity: 'warning',
  enabled: true
};

/**
 * Manages and delivers notifications about performance issues
 */
export class AlertNotifier {
  /**
   * Configuration for the notifier
   */
  private config: Required<AlertNotifierConfig>;
  
  /**
   * Notification channels
   */
  private channels: NotificationChannel[] = [];
  
  /**
   * Recent alerts for grouping
   */
  private recentAlerts: Map<string, AlertNotification> = new Map();
  
  /**
   * Creates a new AlertNotifier
   */
  constructor(config?: AlertNotifierConfig) {
    this.config = {
      channels: config?.channels ?? [consoleNotificationChannel],
      titleFormat: config?.titleFormat ?? 'Performance {severity}: {metricName}',
      messageFormat: config?.messageFormat ?? 
        '{description}. Current value: {value}{unit}, changed by {percentChange}% from baseline.',
      groupSimilarAlerts: config?.groupSimilarAlerts ?? true,
      groupingWindow: config?.groupingWindow ?? 300000 // 5 minutes
    };
    
    this.channels = [...this.config.channels];
    
    // Clean up old alerts periodically
    setInterval(() => this.cleanupRecentAlerts(), this.config.groupingWindow);
  }
  
  /**
   * Add a notification channel
   */
  public addChannel(channel: NotificationChannel): void {
    this.channels.push(channel);
  }
  
  /**
   * Remove a notification channel by name
   */
  public removeChannel(channelName: string): void {
    this.channels = this.channels.filter(channel => channel.name !== channelName);
  }
  
  /**
   * Enable or disable a channel
   */
  public setChannelEnabled(channelName: string, enabled: boolean): void {
    const channel = this.channels.find(ch => ch.name === channelName);
    if (channel) {
      channel.enabled = enabled;
    }
  }
  
  /**
   * Process a regression result and send alerts if needed
   */
  public async processRegression(regression: RegressionResult): Promise<void> {
    // Don't send alerts for info level if it's not an improvement worth mentioning
    if (regression.severity === 'info' && !regression.isRegression) {
      // Only mention significant improvements (> 20%)
      if (Math.abs(regression.percentageChange) < 20) {
        return;
      }
    }
    
    // Create the alert notification
    const alert = this.createAlertFromRegression(regression);
    
    // Check if we should group this with a similar recent alert
    if (this.config.groupSimilarAlerts) {
      const groupKey = `${regression.metricName}:${regression.severity}:${regression.context || 'global'}`;
      const existingAlert = this.recentAlerts.get(groupKey);
      
      if (existingAlert) {
        // Update the existing alert with new information
        existingAlert.data = {
          ...(existingAlert.data || {}),
          count: ((existingAlert.data?.count || 1) + 1),
          latestValue: regression.currentValue,
          latestTimestamp: regression.timestamp
        };
        
        // For grouped alerts, we don't send a new notification
        return;
      }
      
      // Store this as a recent alert for future grouping
      this.recentAlerts.set(groupKey, {
        ...alert,
        data: {
          ...(alert.data || {}),
          count: 1
        }
      });
    }
    
    // Send the alert to all enabled channels with appropriate severity level
    for (const channel of this.channels) {
      // Skip disabled channels
      if (channel.enabled === false) {
        continue;
      }
      
      // Skip if below minimum severity
      const minSeverity = channel.minSeverity || 'warning';
      if (!this.isAtLeastAsSevere(alert.severity, minSeverity)) {
        continue;
      }
      
      try {
        await channel.handler(alert);
      } catch (error) {
        console.error(`Error sending alert to channel ${channel.name}:`, error);
      }
    }
  }
  
  /**
   * Create an alert notification from a regression result
   */
  private createAlertFromRegression(regression: RegressionResult): AlertNotification {
    // Format the title
    const title = this.formatTemplate(this.config.titleFormat, {
      severity: regression.severity,
      metricName: regression.metricName,
      context: regression.context || 'global'
    });
    
    // Format the message
    const message = this.formatTemplate(this.config.messageFormat, {
      severity: regression.severity,
      metricName: regression.metricName,
      value: regression.currentValue.toFixed(2),
      unit: regression.threshold.unit || '',
      baseline: regression.baselineValue.toFixed(2),
      change: regression.absoluteChange.toFixed(2),
      percentChange: regression.percentageChange.toFixed(1),
      context: regression.context || 'global',
      description: regression.threshold.description || regression.metricName
    });
    
    // Create the alert
    return {
      title,
      message,
      severity: regression.severity,
      metricName: regression.metricName,
      value: regression.currentValue,
      timestamp: regression.timestamp,
      context: regression.context,
      data: {
        baselineValue: regression.baselineValue,
        absoluteChange: regression.absoluteChange,
        percentageChange: regression.percentageChange,
        isRegression: regression.isRegression,
        threshold: {
          warning: regression.threshold.warningThreshold,
          critical: regression.threshold.criticalThreshold
        }
      }
    };
  }
  
  /**
   * Format a template string with values
   */
  private formatTemplate(template: string, values: Record<string, string | number | undefined>): string {
    return template.replace(/{(\w+)}/g, (match, key) => {
      const value = values[key];
      return value !== undefined ? value.toString() : match;
    });
  }
  
  /**
   * Check if a severity level is at least as severe as another
   */
  private isAtLeastAsSevere(severity: AlertSeverity, minSeverity: AlertSeverity): boolean {
    const severityOrder: Record<AlertSeverity, number> = {
      info: 0,
      warning: 1,
      critical: 2
    };
    
    return severityOrder[severity] >= severityOrder[minSeverity];
  }
  
  /**
   * Clean up old alerts from the recent alerts map
   */
  private cleanupRecentAlerts(): void {
    const cutoffTime = Date.now() - this.config.groupingWindow;
    
    for (const [key, alert] of this.recentAlerts.entries()) {
      if (alert.timestamp < cutoffTime) {
        this.recentAlerts.delete(key);
      }
    }
  }
} 