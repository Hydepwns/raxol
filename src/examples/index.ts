// Import example runners
import { runAllPerformanceExamples } from './performance';
import { runAllVisualizationExamples } from './visualization';
import { runVisualizationDemoApp } from './VisualizationDemoApp';

/**
 * Run all examples with appropriate delays to prevent conflicts
 */
export function runAllExamples(): void {
  console.log("Starting all examples...");
  
  // Run performance examples first
  setTimeout(() => runAllPerformanceExamples(), 0);
  
  // Run visualization examples after a delay
  setTimeout(() => runAllVisualizationExamples(), 5000);
  
  // Add other example categories with appropriate delays
  
  console.log("All examples scheduled");
}

/**
 * Run the visualization demo app (standalone)
 */
export function runDemo(): void {
  runVisualizationDemoApp();
} 