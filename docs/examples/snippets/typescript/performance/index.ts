/**
 * Performance Examples Index
 * 
 * This module exports performance-related examples that demonstrate
 * how to use the performance optimization features of Raxol.
 */

// Export all performance examples
export { runEventBatchingExample } from './EventBatchingExample';
export { runMemoryProfilingExample } from './MemoryProfilingExample';
export { runPerformanceMetricsExample } from './PerformanceMetricsExample';
export { runLoadTestingExample } from './LoadTestingExample';
export { runMemoryDashboardExampleApp } from './MemoryDashboardExample';
export { runJankDetectionExampleApp } from './JankDetectionExample';

/**
 * Run all performance examples in sequence
 */
export function runAllPerformanceExamples(): void {
  console.log('================================');
  console.log('Starting All Performance Examples');
  console.log('================================');
  
  // Run examples with delays to prevent overlapping output
  setTimeout(() => {
    console.log('\n--- Event Batching Example ---\n');
    import('./EventBatchingExample').then(module => {
      module.runEventBatchingExample();
    });
  }, 0);
  
  setTimeout(() => {
    console.log('\n--- Memory Profiling Example ---\n');
    import('./MemoryProfilingExample').then(module => {
      module.runMemoryProfilingExample();
    });
  }, 4000);
  
  setTimeout(() => {
    console.log('\n--- Performance Metrics Example ---\n');
    import('./PerformanceMetricsExample').then(module => {
      module.runPerformanceMetricsExample();
    });
  }, 8000);
  
  setTimeout(() => {
    console.log('\n--- Load Testing Example ---\n');
    import('./LoadTestingExample').then(module => {
      module.runLoadTestingExample();
    });
  }, 12000);
  
  setTimeout(() => {
    console.log('\n--- Memory Dashboard Example ---\n');
    import('./MemoryDashboardExample').then(module => {
      module.runMemoryDashboardExampleConsole();
    });
  }, 16000);
  
  setTimeout(() => {
    console.log('\n--- Jank Detection Example ---\n');
    import('./JankDetectionExample').then(module => {
      module.runJankDetectionExampleApp();
    });
  }, 20000);
} 