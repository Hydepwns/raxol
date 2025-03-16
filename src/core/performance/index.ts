/**
 * Performance Tools for the Raxol Framework
 * 
 * This module provides comprehensive tools for monitoring, analyzing,
 * and optimizing application performance.
 */

// Responsiveness Tools
export * from './responsiveness/metrics';
export * from './responsiveness/collector';
export * from './responsiveness/scorer';
export * from './responsiveness/visualization';

// Alerts System
export * from './alerts/thresholds';
export * from './alerts/detector';
export * from './alerts/notifier';
export * from './alerts/dashboard';

// Animation Performance Tools
// To be added in future updates

/**
 * Convenient factory functions for common use cases
 */

import { 
  ResponsivenessCollector, 
  ResponsivenessCollectorConfig
} from './responsiveness/collector';
import { 
  ResponsivenessScorer, 
  ResponsivenessScorerConfig 
} from './responsiveness/scorer';
import { 
  ResponsivenessVisualizer, 
  ResponsivenessVisualizerConfig 
} from './responsiveness/visualization';
import { 
  ThresholdConfiguration, 
  DEFAULT_THRESHOLDS 
} from './alerts/thresholds';
import { 
  RegressionDetector, 
  RegressionDetectorConfig 
} from './alerts/detector';
import { 
  AlertNotifier, 
  AlertNotifierConfig 
} from './alerts/notifier';
import { 
  AlertsDashboard, 
  AlertsDashboardConfig 
} from './alerts/dashboard';

/**
 * Creates a complete performance monitoring system with all components
 * integrated and configured for immediate use.
 */
export function createPerformanceMonitor(options: {
  /**
   * DOM element to mount the visualization dashboard
   */
  container: HTMLElement;
  
  /**
   * Optional custom responsiveness collector configuration
   */
  collectorConfig?: Partial<ResponsivenessCollectorConfig>;
  
  /**
   * Optional custom responsiveness scorer configuration
   */
  scorerConfig?: Partial<ResponsivenessScorerConfig>;
  
  /**
   * Optional custom visualization configuration
   */
  visualizerConfig?: Partial<ResponsivenessVisualizerConfig>;
  
  /**
   * Optional custom threshold configuration
   */
  thresholds?: ThresholdConfiguration;
  
  /**
   * Optional custom regression detector configuration
   */
  detectorConfig?: Partial<RegressionDetectorConfig>;
  
  /**
   * Optional custom alert notifier configuration
   */
  notifierConfig?: Partial<AlertNotifierConfig>;
  
  /**
   * Optional custom alerts dashboard configuration
   */
  dashboardConfig?: Partial<AlertsDashboardConfig>;
  
  /**
   * Whether to automatically start monitoring
   * @default true
   */
  autoStart?: boolean;
}) {
  // Create the responsiveness collector
  const collector = new ResponsivenessCollector({
    sampleInterval: 1000,
    bufferSize: 100,
    autoStart: false,
    ...options.collectorConfig
  });
  
  // Create the responsiveness scorer
  const scorer = new ResponsivenessScorer({
    ...options.scorerConfig
  });
  
  // Create the visualization component
  const visualizer = new ResponsivenessVisualizer({
    container: document.createElement('div'),
    collector,
    scorer,
    updateInterval: 1000,
    autoStart: false,
    ...options.visualizerConfig
  });
  
  // Create the regression detector
  const detector = new RegressionDetector({
    thresholds: options.thresholds || DEFAULT_THRESHOLDS,
    detectImprovements: true,
    ...options.detectorConfig
  });
  
  // Create the alert notifier
  const notifier = new AlertNotifier({
    ...options.notifierConfig
  });
  
  // Create the dashboard
  const dashboardContainer = document.createElement('div');
  options.container.appendChild(dashboardContainer);
  
  // Split container in two - top half for responsiveness visualizer, bottom half for alerts
  options.container.style.display = 'flex';
  options.container.style.flexDirection = 'column';
  options.container.style.height = '100%';
  options.container.style.gap = '20px';
  
  const visualizerContainer = document.createElement('div');
  visualizerContainer.style.flex = '1';
  options.container.appendChild(visualizerContainer);
  
  const alertsContainer = document.createElement('div');
  alertsContainer.style.flex = '1';
  options.container.appendChild(alertsContainer);
  
  // Update visualizer container - we need to set the container directly
  // since there's no updateContainer method
  visualizer.container = visualizerContainer;
  
  const dashboard = new AlertsDashboard({
    container: alertsContainer,
    ...options.dashboardConfig
  });
  
  // Set thresholds in the dashboard
  dashboard.setThresholds(options.thresholds || DEFAULT_THRESHOLDS);
  
  // Connect the collector to the detector
  collector.addEventListener('metrics', (metrics) => {
    // Check for regressions
    const regressions = detector.checkRegressions(metrics);
    
    // If there are regressions, send them to the notifier and add to dashboard
    if (regressions.length > 0) {
      regressions.forEach(regression => {
        notifier.processRegression(regression);
      });
      
      dashboard.addAlerts(regressions);
    }
  });
  
  // Start components if autoStart is true
  const autoStart = options.autoStart !== false;
  
  if (autoStart) {
    collector.start();
    visualizer.start();
  }
  
  // Return all components for further customization
  return {
    collector,
    scorer,
    visualizer,
    detector,
    notifier,
    dashboard,
    
    /**
     * Starts all performance monitoring components
     */
    start() {
      collector.start();
      visualizer.start();
    },
    
    /**
     * Stops all performance monitoring components
     */
    stop() {
      collector.stop();
      visualizer.stop();
    },
    
    /**
     * Sets a baseline for all current metrics
     */
    setBaseline() {
      const currentMetrics = collector.getLatestMetrics();
      if (currentMetrics) {
        Object.entries(currentMetrics).forEach(([key, value]) => {
          if (typeof value === 'number') {
            detector.setBaseline(key, value);
          }
        });
      }
    },
    
    /**
     * Clears all alerts from the dashboard
     */
    clearAlerts() {
      dashboard.clearAlerts();
    }
  };
}

/**
 * Creates a simple monitor focused only on responsiveness metrics
 */
export function createResponsivenessMonitor(container: HTMLElement, autoStart = true) {
  const collector = new ResponsivenessCollector({ autoStart });
  const scorer = new ResponsivenessScorer();
  
  return new ResponsivenessVisualizer({
    container,
    collector,
    scorer,
    autoStart
  });
}

/**
 * Creates a simple alert system for performance regressions
 */
export function createPerformanceAlerts(options?: {
  thresholds?: ThresholdConfiguration;
  onAlert?: (alert: any) => void;
}) {
  const detector = new RegressionDetector({
    thresholds: options?.thresholds || DEFAULT_THRESHOLDS
  });
  
  const notifier = new AlertNotifier();
  
  if (options?.onAlert) {
    notifier.addChannel({
      name: 'custom',
      handler: options.onAlert,
      enabled: true,
      minSeverity: 'warning'
    });
  }
  
  const collector = new ResponsivenessCollector({ autoStart: true });
  
  collector.addEventListener('metrics', (metrics) => {
    const regressions = detector.checkRegressions(metrics);
    regressions.forEach(regression => {
      notifier.processRegression(regression);
    });
  });
  
  return {
    detector,
    notifier,
    collector,
    
    /**
     * Starts monitoring and alerting
     */
    start() {
      collector.start();
    },
    
    /**
     * Stops monitoring and alerting
     */
    stop() {
      collector.stop();
    },
    
    /**
     * Sets a baseline for all current metrics
     */
    setBaseline() {
      const currentMetrics = collector.getLatestMetrics();
      if (currentMetrics) {
        Object.entries(currentMetrics).forEach(([key, value]) => {
          if (typeof value === 'number') {
            detector.setBaseline(key, value);
          }
        });
      }
    }
  };
} 