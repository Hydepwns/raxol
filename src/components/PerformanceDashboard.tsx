/**
 * PerformanceDashboard.tsx
 * 
 * A dashboard component for monitoring and visualizing performance metrics.
 */

import { View, ViewElement, DisplayType } from '../core/renderer/view';
import { ViewPerformance, PerformanceMetrics as ViewPerformanceMetrics } from '../core/performance/ViewPerformance';

type PerformanceMetrics = {
  memory: {
    usedJSHeapSize: number;
    totalJSHeapSize: number;
    jsHeapSizeLimit: number;
  };
  timing: {
    navigationStart: number;
    fetchStart: number;
    domainLookupStart: number;
    domainLookupEnd: number;
    connectStart: number;
    connectEnd: number;
    requestStart: number;
    responseStart: number;
    responseEnd: number;
    domLoading: number;
    domInteractive: number;
    domContentLoadedEventStart: number;
    domContentLoadedEventEnd: number;
    domComplete: number;
    loadEventStart: number;
    loadEventEnd: number;
  };
  rendering: {
    componentCreateTime: number;
    renderTime: number;
    updateTime: number;
    layoutTime: number;
    paintTime: number;
  };
};

interface ComponentMetrics {
  type: string;
  createTime: number;
  renderTime: number;
  updateCount: number;
  childCount: number;
  memoryUsage: number;
}

const PerformanceDashboard = () => {
  let metrics: PerformanceMetrics | null = null;
  let componentMetrics: ComponentMetrics[] = [];
  let refreshInterval = 1000;
  let isAutoRefresh = true;
  let autoRefreshInterval: ReturnType<typeof setInterval> | null = null;

  // Format bytes to human readable format
  const formatBytes = (bytes: number): string => {
    const units = ['B', 'KB', 'MB', 'GB'];
    let size = bytes;
    let unitIndex = 0;
    
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    
    return `${size.toFixed(2)} ${units[unitIndex]}`;
  };

  // Format milliseconds to human readable format
  const formatTime = (ms: number): string => {
    if (ms < 1) return `${(ms * 1000).toFixed(2)}μs`;
    if (ms < 1000) return `${ms.toFixed(2)}ms`;
    return `${(ms / 1000).toFixed(2)}s`;
  };

  // Update metrics
  const updateMetrics = () => {
    const performance = ViewPerformance.getInstance();
    const viewMetrics = performance.getMetrics();
    
    if (viewMetrics.memory && viewMetrics.timing && viewMetrics.rendering) {
      metrics = {
        memory: {
          usedJSHeapSize: viewMetrics.memory.usedJSHeapSize || 0,
          totalJSHeapSize: viewMetrics.memory.totalJSHeapSize || 0,
          jsHeapSizeLimit: viewMetrics.memory.jsHeapSizeLimit || 0
        },
        timing: viewMetrics.timing,
        rendering: viewMetrics.rendering
      };
    }
    
    componentMetrics = performance.getAllComponentMetrics();
  };

  // Set up auto-refresh
  const setupAutoRefresh = () => {
    if (autoRefreshInterval) {
      clearInterval(autoRefreshInterval);
    }
    
    if (isAutoRefresh) {
      autoRefreshInterval = setInterval(updateMetrics, refreshInterval);
    }
  };

  // Initial metrics update
  updateMetrics();
  setupAutoRefresh();

  if (!metrics) {
    return View.text('Loading performance metrics...');
  }

  // Create memory usage chart
  const renderMemoryChart = (): ViewElement => {
    const { usedJSHeapSize, totalJSHeapSize, jsHeapSizeLimit } = metrics!.memory;
    const usedPercentage = (usedJSHeapSize / jsHeapSizeLimit) * 100;
    const totalPercentage = (totalJSHeapSize / jsHeapSizeLimit) * 100;
    
    return View.box({
      style: {
        padding: 20,
        border: '1px solid #ccc',
        borderRadius: 4
      },
      children: [
        View.text('Memory Usage', { style: { fontSize: 18, marginBottom: 10 } }),
        View.box({
          style: {
            height: 20,
            backgroundColor: '#eee',
            borderRadius: 2,
            overflow: 'hidden'
          },
          children: [
            View.box({
              style: {
                width: `${usedPercentage}%`,
                height: '100%',
                backgroundColor: usedPercentage > 80 ? '#ff4444' : '#44ff44'
              }
            })
          ]
        }),
        View.text(`Used: ${formatBytes(usedJSHeapSize)} (${usedPercentage.toFixed(1)}%)`),
        View.text(`Total: ${formatBytes(totalJSHeapSize)} (${totalPercentage.toFixed(1)}%)`),
        View.text(`Limit: ${formatBytes(jsHeapSizeLimit)}`)
      ]
    });
  };

  // Create timing chart
  const renderTimingChart = (): ViewElement => {
    const { timing } = metrics!;
    const timings = [
      { label: 'Navigation Start', value: timing.navigationStart },
      { label: 'Fetch Start', value: timing.fetchStart },
      { label: 'Domain Lookup', value: timing.domainLookupEnd - timing.domainLookupStart },
      { label: 'Connect', value: timing.connectEnd - timing.connectStart },
      { label: 'Request', value: timing.responseStart - timing.requestStart },
      { label: 'Response', value: timing.responseEnd - timing.responseStart },
      { label: 'DOM Loading', value: timing.domInteractive - timing.domLoading },
      { label: 'DOM Complete', value: timing.domComplete - timing.domInteractive },
      { label: 'Load Event', value: timing.loadEventEnd - timing.loadEventStart }
    ];
    
    return View.box({
      style: {
        padding: 20,
        border: '1px solid #ccc',
        borderRadius: 4
      },
      children: [
        View.text('Timing Metrics', { style: { fontSize: 18, marginBottom: 10 } }),
        ...timings.map(({ label, value }) => 
          View.box({
            style: {
              marginBottom: 5
            },
            children: [
              View.text(`${label}: ${formatTime(value)}`)
            ]
          })
        )
      ]
    });
  };

  // Create rendering performance chart
  const renderRenderingChart = (): ViewElement => {
    const { rendering } = metrics!;
    const renderings = [
      { label: 'Component Create', value: rendering.componentCreateTime },
      { label: 'Render', value: rendering.renderTime },
      { label: 'Update', value: rendering.updateTime },
      { label: 'Layout', value: rendering.layoutTime },
      { label: 'Paint', value: rendering.paintTime }
    ];
    
    return View.box({
      style: {
        padding: 20,
        border: '1px solid #ccc',
        borderRadius: 4
      },
      children: [
        View.text('Rendering Performance', { style: { fontSize: 18, marginBottom: 10 } }),
        ...renderings.map(({ label, value }) => 
          View.box({
            style: {
              marginBottom: 5
            },
            children: [
              View.text(`${label}: ${formatTime(value)}`)
            ]
          })
        )
      ]
    });
  };

  // Create component metrics table
  const renderComponentTable = (): ViewElement => {
    return View.box({
      style: {
        padding: 20,
        border: '1px solid #ccc',
        borderRadius: 4
      },
      children: [
        View.text('Component Metrics', { style: { fontSize: 18, marginBottom: 10 } }),
        View.box({
          style: {
            display: 'grid' as DisplayType,
            width: '100%',
            borderCollapse: 'collapse'
          },
          children: [
            // Header
            View.box({
              style: {
                display: 'grid' as DisplayType,
                backgroundColor: '#f5f5f5'
              },
              children: [
                View.text('Type', { style: { padding: 8, borderBottom: '1px solid #ddd' } }),
                View.text('Create Time', { style: { padding: 8, borderBottom: '1px solid #ddd' } }),
                View.text('Render Time', { style: { padding: 8, borderBottom: '1px solid #ddd' } }),
                View.text('Updates', { style: { padding: 8, borderBottom: '1px solid #ddd' } }),
                View.text('Children', { style: { padding: 8, borderBottom: '1px solid #ddd' } }),
                View.text('Memory', { style: { padding: 8, borderBottom: '1px solid #ddd' } })
              ]
            }),
            // Rows
            ...componentMetrics.map(metric => 
              View.box({
                style: {
                  display: 'grid' as DisplayType
                },
                children: [
                  View.text(metric.type, { style: { padding: 8, borderBottom: '1px solid #ddd' } }),
                  View.text(formatTime(metric.createTime), { style: { padding: 8, borderBottom: '1px solid #ddd' } }),
                  View.text(formatTime(metric.renderTime), { style: { padding: 8, borderBottom: '1px solid #ddd' } }),
                  View.text(metric.updateCount.toString(), { style: { padding: 8, borderBottom: '1px solid #ddd' } }),
                  View.text(metric.childCount.toString(), { style: { padding: 8, borderBottom: '1px solid #ddd' } }),
                  View.text(formatBytes(metric.memoryUsage), { style: { padding: 8, borderBottom: '1px solid #ddd' } })
                ]
              })
            )
          ]
        })
      ]
    });
  };

  // Create controls
  const renderControls = (): ViewElement => {
    return View.box({
      style: {
        padding: 20,
        marginBottom: 20,
        border: '1px solid #ccc',
        borderRadius: 4
      },
      children: [
        View.text('Performance Dashboard Controls', { style: { fontSize: 18, marginBottom: 10 } }),
        View.box({
          style: {
            display: 'flex',
            gap: 10,
            marginBottom: 10
          },
          children: [
            View.button({
              children: [View.text('Refresh Now')],
              events: {
                click: updateMetrics
              }
            }),
            View.button({
              children: [View.text(isAutoRefresh ? 'Stop Auto-Refresh' : 'Start Auto-Refresh')],
              events: {
                click: () => {
                  isAutoRefresh = !isAutoRefresh;
                  setupAutoRefresh();
                }
              }
            })
          ]
        }),
        View.box({
          style: {
            display: 'flex',
            alignItems: 'center',
            gap: 10
          },
          children: [
            View.text('Refresh Interval:'),
            View.select({
              value: refreshInterval.toString(),
              options: [
                { value: '500', label: '500ms' },
                { value: '1000', label: '1s' },
                { value: '2000', label: '2s' },
                { value: '5000', label: '5s' }
              ],
              events: {
                change: (value) => {
                  refreshInterval = parseInt(value);
                  setupAutoRefresh();
                }
              }
            })
          ]
        })
      ]
    });
  };

  // Main layout
  return View.box({
    style: {
      padding: 20,
      maxWidth: 1200,
      margin: '0 auto'
    },
    children: [
      View.text('Performance Dashboard', { style: { fontSize: 24, marginBottom: 20 } }),
      renderControls(),
      View.box({
        style: {
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))',
          gap: 20,
          marginBottom: 20
        },
        children: [
          renderMemoryChart(),
          renderTimingChart(),
          renderRenderingChart()
        ]
      }),
      renderComponentTable()
    ]
  });
};

export default PerformanceDashboard; 