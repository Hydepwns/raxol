# Raxol Performance Tools

The Performance Tools module for the Raxol framework provides comprehensive tools for monitoring, analyzing, and optimizing application performance. This module helps developers identify performance bottlenecks, track responsiveness metrics, detect regressions, and visualize performance data.

## Features

- **Responsiveness Metrics Collection**: Capture key performance metrics like input latency, time to interactive, frame drop rate, and more
- **Performance Scoring**: Calculate standardized scores for various metrics to simplify interpretation
- **Performance Visualization**: Real-time visualization of performance metrics and scores
- **Performance Regression Alerting**: Detect performance regressions automatically
- **Configurable Thresholds**: Set custom thresholds for various metrics to match your application's requirements
- **Interactive Dashboard**: View performance data and alerts in an interactive dashboard

## Architecture

The Performance Tools module is organized into two main components:

### 1. Responsiveness Tools

Located in `src/core/performance/responsiveness/`:

- `metrics.ts`: Defines core responsiveness metrics
- `collector.ts`: Collects real-time performance data
- `scorer.ts`: Calculates scores based on the collected metrics
- `visualization.ts`: Visualizes the scores and metrics

### 2. Performance Alerts System

Located in `src/core/performance/alerts/`:

- `thresholds.ts`: Defines configurable threshold settings for performance metrics
- `detector.ts`: Detects performance regressions by comparing metrics against baselines and thresholds
- `notifier.ts`: Handles notifications of performance issues
- `dashboard.ts`: Visualizes performance alerts and regressions

## Getting Started

### Basic Usage

```typescript
import { createPerformanceMonitor } from 'raxol/core/performance';

// Create a container for the dashboard
const dashboardContainer = document.createElement('div');
dashboardContainer.style.width = '100%';
dashboardContainer.style.height = '600px';
document.body.appendChild(dashboardContainer);

// Initialize the performance monitor with default settings
const monitor = createPerformanceMonitor({
  container: dashboardContainer
});

// You can control the monitor programmatically
monitor.start();  // Start monitoring
monitor.stop();   // Stop monitoring
monitor.setBaseline();  // Set current values as baseline
monitor.clearAlerts();  // Clear all alerts
```

### Advanced Configuration

```typescript
import { 
  createPerformanceMonitor, 
  DEFAULT_THRESHOLDS 
} from 'raxol/core/performance';

const monitor = createPerformanceMonitor({
  container: document.getElementById('performance-container'),
  
  // Custom thresholds
  thresholds: {
    ...DEFAULT_THRESHOLDS,
    groups: DEFAULT_THRESHOLDS.groups.map(group => {
      if (group.name === 'responsiveness') {
        return {
          ...group,
          metrics: group.metrics.map(metric => {
            if (metric.name === 'inputLatency') {
              return {
                ...metric,
                warningThreshold: 75,
                criticalThreshold: 150
              };
            }
            return metric;
          })
        };
      }
      return group;
    })
  },
  
  // Custom collector settings
  collectorConfig: {
    sampleInterval: 500,
    bufferSize: 200,
    autoStart: true
  },
  
  // Custom visualization settings
  visualizerConfig: {
    updateInterval: 1000,
    maxDataPoints: 120,
    showScoreHistory: true
  },
  
  // Custom alerting settings
  detectorConfig: {
    detectImprovements: true,
    alertCooldownMs: 60000  // 1 minute cooldown between alerts for the same metric
  },
  
  // Custom dashboard settings
  dashboardConfig: {
    groupAlerts: true,
    maxAlerts: 100
  }
});
```

### Using Only Responsiveness Monitoring

If you only need responsiveness monitoring without the alerts system:

```typescript
import { createResponsivenessMonitor } from 'raxol/core/performance';

const container = document.getElementById('responsiveness-container');
const monitor = createResponsivenessMonitor(container);

// Control the monitor
monitor.start();
monitor.stop();
```

### Using Only Alerts System

If you only need the alerts system:

```typescript
import { createPerformanceAlerts } from 'raxol/core/performance';

const alerts = createPerformanceAlerts({
  // Optional custom alert handler
  onAlert: (alert) => {
    console.log(`Performance alert for ${alert.metricName}: ${alert.severity}`);
    // Integrate with your notification system
  }
});

// Control the alerts system
alerts.start();
alerts.stop();
alerts.setBaseline();
```

## Extending the Tools

### Adding Custom Metrics

You can add custom metrics by extending the collector:

```typescript
import { ResponsivenessCollector } from 'raxol/core/performance';

class CustomCollector extends ResponsivenessCollector {
  constructor(config) {
    super(config);
    
    // Add collection of custom metrics
    this.addMetricCollector('customMetric', () => {
      // Calculate and return your custom metric value
      return calculateCustomMetric();
    });
  }
}

// Use your custom collector
const collector = new CustomCollector({ autoStart: true });
```

### Creating Custom Visualization

You can create custom visualizations by using the raw metrics data:

```typescript
import { ResponsivenessCollector } from 'raxol/core/performance';

const collector = new ResponsivenessCollector({ autoStart: true });

collector.addListener('metrics', (metrics) => {
  // Use the metrics data to update your custom visualization
  updateCustomVisualization(metrics);
});
```

## Demo

Check out the working demo in `src/examples/performance-dashboard.ts` to see how to integrate and use the performance tools in a real application.

## Best Practices

1. **Set appropriate thresholds**: Default thresholds might not be optimal for your specific application. Adjust them based on your performance goals.

2. **Establish a performance baseline**: Use the `setBaseline()` method after your application reaches a stable state to establish a baseline for future regression detection.

3. **Monitor consistently**: For meaningful comparisons, ensure that performance measurements are taken under similar conditions.

4. **Filter alerts intelligently**: Configure alert filtering to focus on the most important metrics for your application.

5. **Integrate with CI/CD**: Consider integrating performance monitoring into your CI/CD pipeline to catch regressions before they reach production.

## Contributing

We welcome contributions! If you'd like to improve the performance tools, please submit a pull request or open an issue to discuss new features or report bugs. 