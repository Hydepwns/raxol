// Import example runners
import { runAllPerformanceExamples } from './performance';
import { runAllVisualizationExamples } from './visualization';
import { runVisualizationDemoApp } from './VisualizationDemoApp';
import { PerformanceMonitoringExamples } from './performance-monitoring-example';

/**
 * Run all examples with appropriate delays to prevent conflicts
 */
export function runAllExamples(): void {
  console.log("Starting all examples...");
  
  // Run performance examples first
  setTimeout(() => runAllPerformanceExamples(), 0);
  
  // Run visualization examples after a delay
  setTimeout(() => runAllVisualizationExamples(), 5000);
  
  // Run performance monitoring examples after a delay
  setTimeout(() => {
    console.log("Running performance monitoring examples...");
    PerformanceMonitoringExamples.BasicPerformanceMonitoringExample();
    PerformanceMonitoringExamples.ComponentOperationMetricsExample();
    PerformanceMonitoringExamples.ComponentSpecificMetricsExample();
    PerformanceMonitoringExamples.PerformanceMonitoringDashboardExample();
  }, 10000);
  
  console.log("All examples scheduled");
}

/**
 * Run the visualization demo app (standalone)
 */
export function runDemo(): void {
  runVisualizationDemoApp();
}

/**
 * Run performance monitoring examples (standalone)
 */
export function runPerformanceMonitoringExamples(): void {
  console.log("Running performance monitoring examples...");
  PerformanceMonitoringExamples.BasicPerformanceMonitoringExample();
  PerformanceMonitoringExamples.ComponentOperationMetricsExample();
  PerformanceMonitoringExamples.ComponentSpecificMetricsExample();
  PerformanceMonitoringExamples.PerformanceMonitoringDashboardExample();
} 