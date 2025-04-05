/**
 * PerformanceWidget.ts
 * 
 * A widget component for displaying performance metrics in the dashboard.
 * Shows real-time performance data and alerts.
 */

import { RaxolComponent } from '../../../core/component';
import { View } from '../../../core/renderer/view';
import { WidgetConfig } from '../types';
import { PerformanceMonitor, PerformanceMetrics, PerformanceAlert } from '../PerformanceMonitor';

/**
 * Performance widget configuration
 */
export interface PerformanceWidgetConfig extends WidgetConfig {
  /**
   * Performance monitor instance
   */
  monitor: PerformanceMonitor;
  
  /**
   * Whether to show alerts
   */
  showAlerts?: boolean;
  
  /**
   * Whether to show metrics history
   */
  showHistory?: boolean;
  
  /**
   * Whether to show controls
   */
  showControls?: boolean;
  
  /**
   * Update interval in milliseconds
   */
  updateInterval?: number;
}

/**
 * Performance widget state
 */
interface PerformanceWidgetState {
  /**
   * Current metrics
   */
  metrics: PerformanceMetrics;
  
  /**
   * Current alerts
   */
  alerts: PerformanceAlert[];
  
  /**
   * Whether controls are expanded
   */
  areControlsExpanded: boolean;
  
  /**
   * Whether history is expanded
   */
  isHistoryExpanded: boolean;
  
  /**
   * Whether alerts are expanded
   */
  areAlertsExpanded: boolean;
}

/**
 * Performance widget component
 */
export class PerformanceWidget extends RaxolComponent<PerformanceWidgetConfig, PerformanceWidgetState> {
  /**
   * Update timer
   */
  private updateTimer: number | null = null;
  
  /**
   * Constructor
   */
  constructor(props: PerformanceWidgetConfig) {
    super(props);
    
    this.state = {
      metrics: props.monitor.getMetrics(),
      alerts: props.monitor.getAlerts(),
      areControlsExpanded: false,
      isHistoryExpanded: false,
      areAlertsExpanded: false
    };
  }
  
  /**
   * Component did mount
   */
  componentDidMount(): void {
    // Add metrics listener
    this.props.monitor.addMetricsListener(this.handleMetricsUpdate.bind(this));
    
    // Add alert listener
    this.props.monitor.addAlertListener(this.handleAlertUpdate.bind(this));
    
    // Start update timer
    this.startUpdateTimer();
  }
  
  /**
   * Component will unmount
   */
  componentWillUnmount(): void {
    // Remove listeners
    this.props.monitor.removeMetricsListener(this.handleMetricsUpdate.bind(this));
    this.props.monitor.removeAlertListener(this.handleAlertUpdate.bind(this));
    
    // Stop update timer
    this.stopUpdateTimer();
  }
  
  /**
   * Start update timer
   */
  private startUpdateTimer(): void {
    if (this.updateTimer !== null) {
      return;
    }
    
    const interval = this.props.updateInterval || 1000;
    
    this.updateTimer = window.setInterval(() => {
      this.setState({
        metrics: this.props.monitor.getMetrics(),
        alerts: this.props.monitor.getAlerts()
      });
    }, interval);
  }
  
  /**
   * Stop update timer
   */
  private stopUpdateTimer(): void {
    if (this.updateTimer !== null) {
      window.clearInterval(this.updateTimer);
      this.updateTimer = null;
    }
  }
  
  /**
   * Handle metrics update
   */
  private handleMetricsUpdate(metrics: PerformanceMetrics): void {
    this.setState({ metrics });
  }
  
  /**
   * Handle alert update
   */
  private handleAlertUpdate(alert: PerformanceAlert): void {
    this.setState({
      alerts: this.props.monitor.getAlerts()
    });
  }
  
  /**
   * Toggle controls
   */
  private toggleControls(): void {
    this.setState({
      areControlsExpanded: !this.state.areControlsExpanded
    });
  }
  
  /**
   * Toggle history
   */
  private toggleHistory(): void {
    this.setState({
      isHistoryExpanded: !this.state.isHistoryExpanded
    });
  }
  
  /**
   * Toggle alerts
   */
  private toggleAlerts(): void {
    this.setState({
      areAlertsExpanded: !this.state.areAlertsExpanded
    });
  }
  
  /**
   * Clear alerts
   */
  private clearAlerts(): void {
    this.props.monitor.clearAlerts();
    this.setState({
      alerts: []
    });
  }
  
  /**
   * Render metrics
   */
  private renderMetrics(): ViewElement {
    const { metrics } = this.state;
    
    return View.box({
      style: {
        padding: 10,
        border: 'single',
        marginTop: 10
      },
      children: [
        View.flex({
          direction: 'column',
          children: [
            View.flex({
              direction: 'row',
              justify: 'space-between',
              children: [
                View.text('FPS', { style: { fontWeight: 'bold' } }),
                View.text(metrics.fps.toFixed(1))
              ]
            }),
            View.flex({
              direction: 'row',
              justify: 'space-between',
              children: [
                View.text('Frame Time', { style: { fontWeight: 'bold' } }),
                View.text(`${metrics.frameTime.toFixed(2)} ms`)
              ]
            }),
            View.flex({
              direction: 'row',
              justify: 'space-between',
              children: [
                View.text('Memory Usage', { style: { fontWeight: 'bold' } }),
                View.text(`${metrics.memoryUsage} MB`)
              ]
            }),
            View.flex({
              direction: 'row',
              justify: 'space-between',
              children: [
                View.text('Layout Recalculations', { style: { fontWeight: 'bold' } }),
                View.text(metrics.layoutRecalculations.toString())
              ]
            }),
            View.flex({
              direction: 'row',
              justify: 'space-between',
              children: [
                View.text('Style Recalculations', { style: { fontWeight: 'bold' } }),
                View.text(metrics.styleRecalculations.toString())
              ]
            }),
            View.flex({
              direction: 'row',
              justify: 'space-between',
              children: [
                View.text('Paint Operations', { style: { fontWeight: 'bold' } }),
                View.text(metrics.paintOperations.toString())
              ]
            }),
            View.flex({
              direction: 'row',
              justify: 'space-between',
              children: [
                View.text('Composite Operations', { style: { fontWeight: 'bold' } }),
                View.text(metrics.compositeOperations.toString())
              ]
            }),
            View.flex({
              direction: 'row',
              justify: 'space-between',
              children: [
                View.text('Responsiveness Score', { style: { fontWeight: 'bold' } }),
                View.text(metrics.responsivenessScore.toString())
              ]
            })
          ]
        })
      ]
    });
  }
  
  /**
   * Render alerts
   */
  private renderAlerts(): ViewElement {
    const { alerts, areAlertsExpanded } = this.state;
    
    if (!this.props.showAlerts) {
      return View.box({ style: { display: 'none' } });
    }
    
    return View.box({
      style: {
        padding: 10,
        border: 'single',
        marginTop: 10,
        display: areAlertsExpanded ? 'block' : 'none'
      },
      children: [
        View.flex({
          direction: 'column',
          children: [
            View.flex({
              direction: 'row',
              justify: 'space-between',
              children: [
                View.text('Performance Alerts', { style: { fontWeight: 'bold' } }),
                View.flex({
                  direction: 'row',
                  children: [
                    View.box({
                      style: { 
                        padding: '2px 5px',
                        backgroundColor: '#f0f0f0',
                        borderRadius: 4,
                        cursor: 'pointer',
                        marginRight: 5
                      },
                      onClick: () => this.clearAlerts(),
                      children: [View.text('Clear')]
                    }),
                    View.box({
                      style: { cursor: 'pointer' },
                      onClick: () => this.toggleAlerts(),
                      children: [View.text('▼')]
                    })
                  ]
                })
              ]
            }),
            alerts.length === 0 ? View.text('No alerts') : View.box({
              style: {
                marginTop: 10,
                maxHeight: '200px',
                overflow: 'auto'
              },
              children: alerts.map(alert => View.box({
                style: {
                  padding: 5,
                  marginBottom: 5,
                  border: 'single',
                  backgroundColor: alert.type === 'critical' ? '#ffebee' : 
                                 alert.type === 'error' ? '#fff3e0' : '#e8f5e9'
                },
                children: [
                  View.flex({
                    direction: 'row',
                    justify: 'space-between',
                    children: [
                      View.text(alert.message, { style: { fontWeight: 'bold' } }),
                      View.text(new Date(alert.timestamp).toLocaleTimeString())
                    ]
                  })
                ]
              }))
            })
          ]
        })
      ]
    });
  }
  
  /**
   * Render controls
   */
  private renderControls(): ViewElement {
    const { areControlsExpanded, isHistoryExpanded } = this.state;
    
    if (!this.props.showControls) {
      return View.box({ style: { display: 'none' } });
    }
    
    return View.box({
      style: {
        padding: 10,
        border: 'single',
        marginTop: 10,
        display: areControlsExpanded ? 'block' : 'none'
      },
      children: [
        View.flex({
          direction: 'column',
          children: [
            View.flex({
              direction: 'row',
              justify: 'space-between',
              children: [
                View.text('Performance Controls', { style: { fontWeight: 'bold' } }),
                View.box({
                  style: { cursor: 'pointer' },
                  onClick: () => this.toggleControls(),
                  children: [View.text('▼')]
                })
              ]
            }),
            View.flex({
              direction: 'row',
              justify: 'space-between',
              children: [
                View.text('Show History'),
                View.box({
                  style: { 
                    width: 40, 
                    height: 20, 
                    backgroundColor: isHistoryExpanded ? '#4CAF50' : '#ccc',
                    borderRadius: 4,
                    cursor: 'pointer'
                  },
                  onClick: () => this.toggleHistory(),
                  children: [View.text(isHistoryExpanded ? 'On' : 'Off')]
                })
              ]
            })
          ]
        })
      ]
    });
  }
  
  /**
   * Render the widget
   */
  render(): ViewElement {
    return View.box({
      style: {
        padding: 15,
        backgroundColor: this.props.backgroundColor || '#ffffff',
        border: this.props.border || 'single',
        ...this.props.styles
      },
      children: [
        View.flex({
          direction: 'column',
          children: [
            View.flex({
              direction: 'row',
              justify: 'space-between',
              children: [
                View.text(this.props.title, { style: { fontWeight: 'bold', fontSize: 16 } }),
                this.props.showControls ? View.box({
                  style: { cursor: 'pointer' },
                  onClick: () => this.toggleControls(),
                  children: [View.text('⚙️')]
                }) : View.box({ style: { display: 'none' } })
              ]
            }),
            this.renderMetrics(),
            this.renderAlerts(),
            this.renderControls()
          ]
        })
      ]
    });
  }
} 