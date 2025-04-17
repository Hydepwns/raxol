/**
 * performance-monitoring-example.tsx
 * 
 * Comprehensive example for the performance monitoring system.
 * Demonstrates usage of the ViewPerformance class for tracking component metrics.
 */

// Import View components and performance monitoring
import { View } from '../core/renderer/view';
import { ViewPerformance } from '../core/performance/ViewPerformance';
import { ViewElement, ComponentType } from '../core/renderer/types';

// Mock React hooks for demonstration
const useState = <T,>(initialState: T): [T, (newState: T | ((prev: T) => T)) => void] => {
  let state = initialState;
  const setState = (newState: T | ((prev: T) => T)) => {
    if (typeof newState === 'function') {
      state = (newState as (prev: T) => T)(state);
    } else {
      state = newState;
    }
    // In a real implementation, this would trigger a re-render
  };
  return [state, setState];
};

const useEffect = (callback: () => void | (() => void), deps: any[]): void => {
  callback();
  // In a real implementation, this would run on mount and when deps change
  // and clean up on unmount or when deps change
};

// Example 1: Basic Performance Monitoring
const BasicPerformanceMonitoringExample = () => {
  const [metrics, setMetrics] = useState<any>(null);
  const performance = ViewPerformance.getInstance();

  useEffect(() => {
    // Start performance monitoring
    performance.startMonitoring();

    // Record some component metrics
    performance.recordComponentCreate('box', 5);
    performance.recordComponentRender('box', 10, 3);
    performance.recordComponentUpdate('box', 2);
    performance.recordComponentOperation('render', 15, 'box');
    performance.recordComponentOperation('update', 5, 'box');

    // Get metrics
    const currentMetrics = performance.getMetrics();
    setMetrics(currentMetrics);

    // Stop performance monitoring
    performance.stopMonitoring();
  }, []);

  return View.box({
    style: { padding: '1em' },
    children: [
      View.text('Basic Performance Monitoring Example', { style: { fontSize: '1.2em', fontWeight: 'bold' } }),
      View.text('Component Metrics:', { style: { marginTop: '1em' } }),
      metrics ? View.box({
        style: { 
          marginTop: '0.5em', 
          padding: '0.5em', 
          border: '1px solid #ddd' as any,
          borderRadius: '4px',
          backgroundColor: '#f8f9fa'
        },
        children: [
          View.text(`Component Create Time: ${metrics.rendering.componentCreateTime}ms`),
          View.text(`Render Time: ${metrics.rendering.renderTime}ms`),
          View.text(`Update Time: ${metrics.rendering.updateTime}ms`),
          View.text(`Layout Time: ${metrics.rendering.layoutTime}ms`),
          View.text(`Paint Time: ${metrics.rendering.paintTime}ms`)
        ]
      }) : View.text('Loading metrics...')
    ]
  });
};

// Example 2: Component Operation Metrics
const ComponentOperationMetricsExample = () => {
  const [operationMetrics, setOperationMetrics] = useState<any[]>([]);
  const performance = ViewPerformance.getInstance();

  useEffect(() => {
    // Start performance monitoring
    performance.startMonitoring();

    // Record component operation metrics
    performance.recordComponentOperation('render', 25, 'box');
    performance.recordComponentOperation('update', 15, 'text');
    performance.recordComponentOperation('render', 30, 'box');
    performance.recordComponentOperation('layout', 20, 'flex');
    performance.recordComponentOperation('paint', 10, 'button');

    // Get operation metrics
    const metrics = performance.getAllOperationMetrics();
    setOperationMetrics(metrics);

    // Stop performance monitoring
    performance.stopMonitoring();
  }, []);

  return View.box({
    style: { padding: '1em' },
    children: [
      View.text('Component Operation Metrics Example', { style: { fontSize: '1.2em', fontWeight: 'bold' } }),
      View.text('Operation Metrics:', { style: { marginTop: '1em' } }),
      View.box({
        style: { 
          marginTop: '0.5em', 
          padding: '0.5em', 
          border: '1px solid #ddd' as any,
          borderRadius: '4px',
          backgroundColor: '#f8f9fa'
        },
        children: operationMetrics.map((metric, index) => 
          View.box({
            style: { 
              padding: '0.5em', 
              borderBottom: index < operationMetrics.length - 1 ? '1px solid #eee' as any : 'none' as any
            },
            children: [
              View.text(`Operation: ${metric.operation}`),
              View.text(`Time: ${metric.operationTime}ms`),
              View.text(`Component: ${metric.componentType || 'N/A'}`),
              View.text(`Timestamp: ${new Date(metric.timestamp).toLocaleTimeString()}`)
            ]
          })
        )
      })
    ]
  });
};

// Example 3: Component-Specific Metrics
const ComponentSpecificMetricsExample = () => {
  const [componentMetrics, setComponentMetrics] = useState<any[]>([]);
  const performance = ViewPerformance.getInstance();

  useEffect(() => {
    // Start performance monitoring
    performance.startMonitoring();

    // Record component-specific metrics
    performance.recordComponentCreate('box', 5);
    performance.recordComponentRender('box', 10, 3);
    performance.recordComponentUpdate('box', 2);
    
    performance.recordComponentCreate('text', 2);
    performance.recordComponentRender('text', 5, 0);
    performance.recordComponentUpdate('text', 1);
    
    performance.recordComponentCreate('button', 8);
    performance.recordComponentRender('button', 15, 1);
    performance.recordComponentUpdate('button', 3);

    // Get component metrics
    const metrics = performance.getAllComponentMetrics();
    setComponentMetrics(metrics);

    // Stop performance monitoring
    performance.stopMonitoring();
  }, []);

  return View.box({
    style: { padding: '1em' },
    children: [
      View.text('Component-Specific Metrics Example', { style: { fontSize: '1.2em', fontWeight: 'bold' } }),
      View.text('Component Metrics:', { style: { marginTop: '1em' } }),
      View.box({
        style: { 
          marginTop: '0.5em', 
          padding: '0.5em', 
          border: '1px solid #ddd' as any,
          borderRadius: '4px',
          backgroundColor: '#f8f9fa'
        },
        children: componentMetrics.map((metric, index) => 
          View.box({
            style: { 
              padding: '0.5em', 
              borderBottom: index < componentMetrics.length - 1 ? '1px solid #eee' as any : 'none' as any
            },
            children: [
              View.text(`Component Type: ${metric.type}`),
              View.text(`Create Time: ${metric.createTime}ms`),
              View.text(`Render Time: ${metric.renderTime}ms`),
              View.text(`Update Count: ${metric.updateCount}`),
              View.text(`Child Count: ${metric.childCount}`)
            ]
          })
        )
      })
    ]
  });
};

// Example 4: Performance Monitoring Dashboard
const PerformanceMonitoringDashboardExample = () => {
  const [metrics, setMetrics] = useState<any>(null);
  const [operationMetrics, setOperationMetrics] = useState<any[]>([]);
  const [componentMetrics, setComponentMetrics] = useState<any[]>([]);
  const performance = ViewPerformance.getInstance();

  useEffect(() => {
    // Start performance monitoring
    performance.startMonitoring();

    // Record metrics
    performance.recordComponentCreate('box', 5);
    performance.recordComponentRender('box', 10, 3);
    performance.recordComponentUpdate('box', 2);
    performance.recordComponentOperation('render', 15, 'box');
    performance.recordComponentOperation('update', 5, 'box');
    
    performance.recordComponentCreate('text', 2);
    performance.recordComponentRender('text', 5, 0);
    performance.recordComponentUpdate('text', 1);
    performance.recordComponentOperation('render', 8, 'text');
    
    performance.recordComponentCreate('button', 8);
    performance.recordComponentRender('button', 15, 1);
    performance.recordComponentUpdate('button', 3);
    performance.recordComponentOperation('render', 20, 'button');

    // Get metrics
    const currentMetrics = performance.getMetrics();
    const currentOperationMetrics = performance.getAllOperationMetrics();
    const currentComponentMetrics = performance.getAllComponentMetrics();
    
    setMetrics(currentMetrics);
    setOperationMetrics(currentOperationMetrics);
    setComponentMetrics(currentComponentMetrics);

    // Stop performance monitoring
    performance.stopMonitoring();
  }, []);

  return View.box({
    style: { padding: '1em' },
    children: [
      View.text('Performance Monitoring Dashboard Example', { style: { fontSize: '1.2em', fontWeight: 'bold' } }),
      
      // Overall Metrics
      View.box({
        style: { 
          marginTop: '1em', 
          padding: '1em', 
          border: '1px solid #ddd' as any,
          borderRadius: '4px',
          backgroundColor: '#f8f9fa'
        },
        children: [
          View.text('Overall Metrics', { style: { fontWeight: 'bold' } }),
          metrics ? View.box({
            style: { marginTop: '0.5em' },
            children: [
              View.text(`Component Create Time: ${metrics.rendering.componentCreateTime}ms`),
              View.text(`Render Time: ${metrics.rendering.renderTime}ms`),
              View.text(`Update Time: ${metrics.rendering.updateTime}ms`),
              View.text(`Layout Time: ${metrics.rendering.layoutTime}ms`),
              View.text(`Paint Time: ${metrics.rendering.paintTime}ms`)
            ]
          }) : View.text('Loading metrics...')
        ]
      }),
      
      // Component Metrics
      View.box({
        style: { 
          marginTop: '1em', 
          padding: '1em', 
          border: '1px solid #ddd' as any,
          borderRadius: '4px',
          backgroundColor: '#f8f9fa'
        },
        children: [
          View.text('Component Metrics', { style: { fontWeight: 'bold' } }),
          View.box({
            style: { marginTop: '0.5em' },
            children: componentMetrics.map((metric, index) => 
              View.box({
                style: { 
                  padding: '0.5em', 
                  borderBottom: index < componentMetrics.length - 1 ? '1px solid #eee' as any : 'none' as any
                },
                children: [
                  View.text(`Component Type: ${metric.type}`),
                  View.text(`Create Time: ${metric.createTime}ms`),
                  View.text(`Render Time: ${metric.renderTime}ms`),
                  View.text(`Update Count: ${metric.updateCount}`),
                  View.text(`Child Count: ${metric.childCount}`)
                ]
              })
            )
          })
        ]
      }),
      
      // Operation Metrics
      View.box({
        style: { 
          marginTop: '1em', 
          padding: '1em', 
          border: '1px solid #ddd' as any,
          borderRadius: '4px',
          backgroundColor: '#f8f9fa'
        },
        children: [
          View.text('Operation Metrics', { style: { fontWeight: 'bold' } }),
          View.box({
            style: { marginTop: '0.5em' },
            children: operationMetrics.map((metric, index) => 
              View.box({
                style: { 
                  padding: '0.5em', 
                  borderBottom: index < operationMetrics.length - 1 ? '1px solid #eee' as any : 'none' as any
                },
                children: [
                  View.text(`Operation: ${metric.operation}`),
                  View.text(`Time: ${metric.operationTime}ms`),
                  View.text(`Component: ${metric.componentType || 'N/A'}`),
                  View.text(`Timestamp: ${new Date(metric.timestamp).toLocaleTimeString()}`)
                ]
              })
            )
          })
        ]
      })
    ]
  });
};

// Export examples
export const PerformanceMonitoringExamples = {
  BasicPerformanceMonitoringExample,
  ComponentOperationMetricsExample,
  ComponentSpecificMetricsExample,
  PerformanceMonitoringDashboardExample
}; 