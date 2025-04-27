/**
 * Performance Metrics Example
 * 
 * This example demonstrates how to use the Performance Metrics system
 * to monitor application performance and detect bottlenecks.
 */

import {
  recordMetric,
  startPerformanceMark,
  endPerformanceMark,
  getMetricSummary,
  detectPerformanceRegressions,
  globalPerformanceMetrics
} from '../../core/performance';

/**
 * Simulate a render operation with variable performance
 */
function simulateRenderOperation(componentId: string, complexity: number): void {
  startPerformanceMark(`render_${componentId}`, { complexity });
  
  // Simulate render work
  const startTime = Date.now();
  
  // The more complex, the longer it takes
  const simulatedWorkTime = complexity * 2;
  
  // Busy wait to simulate CPU work
  while (Date.now() - startTime < simulatedWorkTime) {
    // Intentionally empty - simulating work
  }
  
  endPerformanceMark(`render_${componentId}`, 'render');
}

/**
 * Simulate user interaction with variable response time
 */
function simulateUserInteraction(interactionType: string, delay: number): void {
  startPerformanceMark(`interaction_${interactionType}`);
  
  // Simulate interaction processing
  const startTime = Date.now();
  
  // Busy wait to simulate processing time
  while (Date.now() - startTime < delay) {
    // Intentionally empty - simulating work
  }
  
  endPerformanceMark(`interaction_${interactionType}`, 'interaction');
}

/**
 * Collect performance metrics for multiple components
 */
function collectComponentMetrics(): void {
  // Simulate different components with different complexities
  const components = [
    { id: 'header', complexity: 5 },
    { id: 'sidebar', complexity: 10 },
    { id: 'main-content', complexity: 25 },
    { id: 'data-table', complexity: 40 },
    { id: 'footer', complexity: 5 }
  ];
  
  // Record render metrics for each component
  components.forEach(component => {
    simulateRenderOperation(component.id, component.complexity);
  });
}

/**
 * Collect user interaction metrics
 */
function collectInteractionMetrics(): void {
  // Simulate different user interactions
  const interactions = [
    { type: 'click', delay: 10 },
    { type: 'hover', delay: 5 },
    { type: 'keypress', delay: 8 },
    { type: 'drag', delay: 120 }, // Intentionally slow
    { type: 'scroll', delay: 25 }
  ];
  
  // Record interaction metrics
  interactions.forEach(interaction => {
    simulateUserInteraction(interaction.type, interaction.delay);
  });
}

/**
 * Directly record some custom metrics
 */
function recordCustomMetrics(): void {
  // Record some network metrics
  recordMetric('api_request', 120, 'network', { endpoint: '/users' });
  recordMetric('api_request', 85, 'network', { endpoint: '/products' });
  recordMetric('api_request', 210, 'network', { endpoint: '/orders' });
  
  // Record some resource metrics
  recordMetric('image_load', 350, 'resource', { size: '250kb', type: 'image/jpeg' });
  recordMetric('script_load', 180, 'resource', { size: '120kb', type: 'application/javascript' });
}

/**
 * Analyze performance metrics
 */
function analyzeMetrics(): void {
  // Get summary for render metrics
  const renderSummary = getMetricSummary('render');
  console.log('Render Performance Summary:', renderSummary);
  
  // Get summary for interaction metrics
  const interactionSummary = getMetricSummary('interaction');
  console.log('Interaction Performance Summary:', interactionSummary);
  
  // Get summary for network metrics
  const networkSummary = getMetricSummary('network');
  console.log('Network Performance Summary:', networkSummary);
}

/**
 * Simulate performance regression detection
 */
function detectRegressions(): void {
  // Create baseline metrics (simulated previous release)
  const baselineMetrics = [
    { name: 'render_main-content', type: 'render', value: 40, timestamp: Date.now() - 86400000 },
    { name: 'render_data-table', type: 'render', value: 65, timestamp: Date.now() - 86400000 },
    { name: 'interaction_drag', type: 'interaction', value: 80, timestamp: Date.now() - 86400000 },
  ];
  
  // Get current metrics for comparison
  const currentMetrics = [
    ...globalPerformanceMetrics.getMetricsByName('render_main-content'),
    ...globalPerformanceMetrics.getMetricsByName('render_data-table'),
    ...globalPerformanceMetrics.getMetricsByName('interaction_drag')
  ];
  
  // Detect regressions with 15% threshold
  const regressions = detectPerformanceRegressions(baselineMetrics, currentMetrics, 15);
  
  console.log('Performance Regressions Detected:', regressions);
}

/**
 * Run the complete performance metrics example
 */
export function runPerformanceMetricsExample(): void {
  console.log('Starting Performance Metrics Example...');
  
  // First batch of metrics
  collectComponentMetrics();
  collectInteractionMetrics();
  recordCustomMetrics();
  
  // Analyze initial metrics
  analyzeMetrics();
  
  // Simulate some changes to the application
  setTimeout(() => {
    console.log('Simulating application changes...');
    
    // Second batch with some performance differences
    collectComponentMetrics();
    collectInteractionMetrics();
    
    // Analyze updated metrics and detect regressions
    analyzeMetrics();
    detectRegressions();
    
    console.log('Performance metrics example complete');
  }, 1000);
} 