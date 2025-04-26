---
title: Jank Detection
description: Documentation for detecting and analyzing jank in Raxol Terminal Emulator
date: 2023-04-04
author: Raxol Team
section: performance
tags: [performance, jank, detection]
---

# Jank Detection Tools

The Raxol framework includes powerful tools for detecting, analyzing, and visualizing UI jank (frame drops and stutters). These tools help developers identify and fix performance issues that affect user experience.

## Overview

UI jank refers to stutters or frame drops in animation and interaction, which users perceive as lag or unresponsiveness. The Raxol Jank Detection system helps by:

1. Monitoring frame rates in real-time
2. Identifying periods of dropped frames (jank events)
3. Providing contextual information about what was happening during jank
4. Visualizing performance issues through an interactive dashboard

## Key Components

### JankDetector

The `JankDetector` class monitors frame timing using `requestAnimationFrame` and identifies periods where frames take longer than expected to render:

```typescript
import { JankDetector } from 'raxol/performance';

// Create a custom detector
const detector = new JankDetector({
  targetFps: 60,                 // Target frame rate
  dropThreshold: 0.5,            // Threshold for frame drops (50% longer than target)
  stutterThreshold: 2,           // Consecutive dropped frames to consider a stutter
  analysisWindow: 5000,          // Analysis window in ms
  autoStart: true,               // Start monitoring automatically
  onJankDetected: (event) => {   // Optional callback for jank events
    console.log(`Jank detected: ${event.severity}, ${event.droppedFrames} frames dropped`);
  }
});

// Or use the global instance
import { startJankDetection, stopJankDetection } from 'raxol/performance';

startJankDetection();
// ... your application code ...
stopJankDetection();
```

### JankVisualizer

The `JankVisualizer` provides a visual dashboard for analyzing jank data:

```typescript
import { createJankVisualizer } from 'raxol/performance';

// Create a visualizer in a container element
const container = document.getElementById('jank-visualizer');
const visualizer = createJankVisualizer(container, {
  updateInterval: 200,  // Update interval in ms
  maxFrames: 300,       // Maximum frames to display in timeline
  // Optional custom styling
  styles: {
    backgroundColor: '#2d2d2d',
    textColor: '#e0e0e0',
    // ... additional style options
  }
});

// Start/stop updates
visualizer.start();
visualizer.stop();

// Force a manual update
visualizer.update();

// Clean up resources
visualizer.destroy();
```

## Contextual Jank Tracking

One of the most powerful features is the ability to associate context with jank events, helping pinpoint what was happening when performance issues occurred:

```typescript
import { setJankContext, addJankContext, clearJankContext } from 'raxol/performance';

// Set context information for the current user flow
setJankContext({ 
  screen: 'ProductList',
  itemCount: 500,
  renderMode: 'virtualized'
});

// Add additional context without overwriting existing context
addJankContext('userAction', 'scrolling');
addJankContext('scrollPosition', 1250);

// Clear context when changing screens/flows
clearJankContext();
```

## Jank Reports

You can generate comprehensive jank analysis reports:

```typescript
import { getJankReport } from 'raxol/performance';

const report = getJankReport();
console.log(`Average FPS: ${report.averageFps.toFixed(1)}`);
console.log(`Frame Success Rate: ${report.frameSuccessRate.toFixed(1)}%`);
console.log(`Jank Events: ${report.jankEventCount}`);
console.log(`95th Percentile Frame Time: ${report.p95FrameTime.toFixed(2)}ms`);
```

## Best Practices

1. **Continuous Monitoring**: Integrate jank detection in development environments to catch issues early
2. **Contextual Tracking**: Always set context before operations that might cause jank
3. **Performance Budgets**: Establish frame time budgets for different operations
4. **Test on Low/Mid-Tier Devices**: What performs well on high-end devices may still cause jank on average hardware

## Common Jank Causes and Solutions

| Cause | Detection | Solution |
|-------|-----------|----------|
| Heavy DOM operations | High frame times during DOM updates | Batch DOM operations, use virtualization for large lists |
| Large component trees | Jank during component mounting | Lazy load components, implement code splitting |
| Expensive calculations | Jank with specific interaction context | Move calculations to web workers, memoize results |
| Layout thrashing | Frequent jank during resize/scroll | Batch read/write operations, use `requestAnimationFrame` |
| Garbage collection | Sporadic jank without clear cause | Reduce object allocation, reuse objects where possible |

## Example

See the JankDetectionExample.ts file for a complete demonstration:

```typescript
import { runJankDetectionExampleApp } from 'raxol/examples/performance';
runJankDetectionExampleApp();
```

## Advanced Configuration

For advanced use cases, the JankDetector and JankVisualizer classes support additional configuration options. See the API reference for complete details.

---

For more information, see the [Performance Optimization Guide](./PerformanceOptimization.md) and [Animation Performance Guide](../guides/animation_performance.md). 