/**
 * Performance Dashboard Demo
 * 
 * This example demonstrates how to use the Raxol performance monitoring tools
 * to create a comprehensive performance dashboard for your application.
 */

import { createPerformanceMonitor } from '../core/performance';
import { DEFAULT_THRESHOLDS } from '../core/performance/alerts/thresholds';

/**
 * Initialize the performance monitoring dashboard
 */
export function initPerformanceDashboard(container: HTMLElement) {
  // Create a performance monitor with all components
  const monitor = createPerformanceMonitor({
    container,
    // You can customize thresholds here 
    thresholds: {
      ...DEFAULT_THRESHOLDS,
      // Customize a specific threshold if needed
      groups: DEFAULT_THRESHOLDS.groups.map(group => {
        if (group.name === 'responsiveness') {
          return {
            ...group,
            metrics: group.metrics.map(metric => {
              if (metric.name === 'inputLatency') {
                return {
                  ...metric,
                  warningThreshold: 75, // Custom warning threshold
                  criticalThreshold: 150 // Custom critical threshold
                };
              }
              return metric;
            })
          };
        }
        return group;
      }),
      minChangePercentage: 15, // Only alert on changes >15%
      enableAlertsByDefault: true
    },
    
    // Configure the collector
    collectorConfig: {
      autoStart: false, // We'll start it manually
      sampleInterval: 500, // More frequent sampling
      includeTracing: true // Enable tracing
    },
    
    // Configure the visualization
    visualizerConfig: {
      maxDataPoints: 120, // Show two minutes of history
      updateInterval: 1000,
      showBreakdown: true
    },
    
    // Configure the alerts dashboard
    dashboardConfig: {
      groupAlerts: true,
      maxAlerts: 100
    },
    
    // Start automatically
    autoStart: true
  });
  
  // Create controls for the dashboard
  createDashboardControls(container, monitor);
  
  // Return the monitor for further customization
  return monitor;
}

/**
 * Create controls for the performance dashboard
 */
function createDashboardControls(container: HTMLElement, monitor: ReturnType<typeof createPerformanceMonitor>) {
  // Create container for controls
  const controlsContainer = document.createElement('div');
  controlsContainer.style.display = 'flex';
  controlsContainer.style.justifyContent = 'space-between';
  controlsContainer.style.marginBottom = '20px';
  controlsContainer.style.padding = '10px';
  controlsContainer.style.backgroundColor = '#f5f5f5';
  controlsContainer.style.borderRadius = '4px';
  container.insertBefore(controlsContainer, container.firstChild);
  
  // Left side - basic controls
  const basicControls = document.createElement('div');
  basicControls.style.display = 'flex';
  basicControls.style.gap = '10px';
  controlsContainer.appendChild(basicControls);
  
  // Start/Stop button
  const startStopButton = document.createElement('button');
  startStopButton.textContent = 'Stop Monitoring';
  startStopButton.style.padding = '8px 16px';
  startStopButton.style.borderRadius = '4px';
  startStopButton.style.border = 'none';
  startStopButton.style.backgroundColor = '#dc3545';
  startStopButton.style.color = 'white';
  startStopButton.style.cursor = 'pointer';
  basicControls.appendChild(startStopButton);
  
  let isRunning = true;
  startStopButton.addEventListener('click', () => {
    if (isRunning) {
      monitor.stop();
      startStopButton.textContent = 'Start Monitoring';
      startStopButton.style.backgroundColor = '#28a745';
    } else {
      monitor.start();
      startStopButton.textContent = 'Stop Monitoring';
      startStopButton.style.backgroundColor = '#dc3545';
    }
    isRunning = !isRunning;
  });
  
  // Clear alerts button
  const clearAlertsButton = document.createElement('button');
  clearAlertsButton.textContent = 'Clear Alerts';
  clearAlertsButton.style.padding = '8px 16px';
  clearAlertsButton.style.borderRadius = '4px';
  clearAlertsButton.style.border = 'none';
  clearAlertsButton.style.backgroundColor = '#6c757d';
  clearAlertsButton.style.color = 'white';
  clearAlertsButton.style.cursor = 'pointer';
  basicControls.appendChild(clearAlertsButton);
  
  clearAlertsButton.addEventListener('click', () => {
    monitor.dashboard.clearAlerts();
  });
  
  // Set baseline button
  const setBaselineButton = document.createElement('button');
  setBaselineButton.textContent = 'Set Baseline';
  setBaselineButton.style.padding = '8px 16px';
  setBaselineButton.style.borderRadius = '4px';
  setBaselineButton.style.border = 'none';
  setBaselineButton.style.backgroundColor = '#17a2b8';
  setBaselineButton.style.color = 'white';
  setBaselineButton.style.cursor = 'pointer';
  basicControls.appendChild(setBaselineButton);
  
  setBaselineButton.addEventListener('click', () => {
    monitor.setBaseline();
    
    // Show confirmation
    const existingToast = document.getElementById('baseline-toast');
    if (existingToast) {
      document.body.removeChild(existingToast);
    }
    
    const toast = document.createElement('div');
    toast.id = 'baseline-toast';
    toast.style.position = 'fixed';
    toast.style.bottom = '20px';
    toast.style.right = '20px';
    toast.style.backgroundColor = '#28a745';
    toast.style.color = 'white';
    toast.style.padding = '10px 20px';
    toast.style.borderRadius = '4px';
    toast.style.boxShadow = '0 4px 8px rgba(0,0,0,0.1)';
    toast.style.zIndex = '1000';
    toast.style.transition = 'all 0.3s ease';
    toast.textContent = 'New baseline set!';
    
    document.body.appendChild(toast);
    
    setTimeout(() => {
      toast.style.opacity = '0';
      setTimeout(() => {
        if (document.body.contains(toast)) {
          document.body.removeChild(toast);
        }
      }, 300);
    }, 3000);
  });
  
  // Right side - test controls
  const testControls = document.createElement('div');
  testControls.style.display = 'flex';
  testControls.style.gap = '10px';
  controlsContainer.appendChild(testControls);
  
  // Simulate load button
  const simulateLoadButton = document.createElement('button');
  simulateLoadButton.textContent = 'Simulate Load';
  simulateLoadButton.style.padding = '8px 16px';
  simulateLoadButton.style.borderRadius = '4px';
  simulateLoadButton.style.border = 'none';
  simulateLoadButton.style.backgroundColor = '#fd7e14';
  simulateLoadButton.style.color = 'white';
  simulateLoadButton.style.cursor = 'pointer';
  testControls.appendChild(simulateLoadButton);
  
  let loadInterval: ReturnType<typeof setInterval> | null = null;
  
  simulateLoadButton.addEventListener('click', () => {
    if (loadInterval) {
      clearInterval(loadInterval);
      loadInterval = null;
      simulateLoadButton.textContent = 'Simulate Load';
      simulateLoadButton.style.backgroundColor = '#fd7e14';
    } else {
      // Create artificial load by doing heavy calculations
      let counter = 0;
      loadInterval = setInterval(() => {
        // Simulate expensive operations
        for (let i = 0; i < 1000000; i++) {
          counter += Math.sqrt(i) * Math.sin(i);
        }
        
        // Force layout thrashing
        for (let i = 0; i < 10; i++) {
          document.body.offsetHeight;
          document.body.style.margin = (i % 2) + 'px';
        }
      }, 500);
      
      simulateLoadButton.textContent = 'Stop Load';
      simulateLoadButton.style.backgroundColor = '#dc3545';
    }
  });
  
  // Simulate bad input latency
  const simulateInputLagButton = document.createElement('button');
  simulateInputLagButton.textContent = 'Simulate Input Lag';
  simulateInputLagButton.style.padding = '8px 16px';
  simulateInputLagButton.style.borderRadius = '4px';
  simulateInputLagButton.style.border = 'none';
  simulateInputLagButton.style.backgroundColor = '#6f42c1';
  simulateInputLagButton.style.color = 'white';
  simulateInputLagButton.style.cursor = 'pointer';
  testControls.appendChild(simulateInputLagButton);
  
  let originalAddEventListener = EventTarget.prototype.addEventListener;
  let laggyEventListener: boolean = false;
  
  simulateInputLagButton.addEventListener('click', () => {
    if (laggyEventListener) {
      // Restore original event listener
      EventTarget.prototype.addEventListener = originalAddEventListener;
      laggyEventListener = false;
      simulateInputLagButton.textContent = 'Simulate Input Lag';
      simulateInputLagButton.style.backgroundColor = '#6f42c1';
    } else {
      // Override addEventListener to introduce artificial lag
      EventTarget.prototype.addEventListener = function (type, listener, options) {
        if (type === 'click' || type === 'input' || type === 'keydown' || type === 'mousemove') {
          const wrappedListener = function (this: any, ...args: any[]) {
            setTimeout(() => {
              (listener as any).apply(this, args);
            }, 200); // 200ms artificial lag
          };
          return originalAddEventListener.call(this, type, wrappedListener, options);
        } else {
          return originalAddEventListener.call(this, type, listener, options);
        }
      };
      
      laggyEventListener = true;
      simulateInputLagButton.textContent = 'Fix Input Lag';
      simulateInputLagButton.style.backgroundColor = '#dc3545';
    }
  });
}

/**
 * Example usage:
 * 
 * ```
 * // Create a container for the dashboard
 * const dashboardContainer = document.createElement('div');
 * dashboardContainer.style.width = '100%';
 * dashboardContainer.style.height = '600px';
 * document.body.appendChild(dashboardContainer);
 * 
 * // Initialize the dashboard
 * const monitor = initPerformanceDashboard(dashboardContainer);
 * 
 * // You can then use the monitor object to programmatically control the dashboard
 * // For example:
 * // monitor.setBaseline();
 * // monitor.stop();
 * // monitor.start();
 * ```
 */ 