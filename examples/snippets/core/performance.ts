/**
 * Performance Testing and Monitoring Utilities
 * 
 * This module provides utilities for load testing, performance monitoring,
 * and metrics collection for Raxol components and applications.
 */

// Types for performance testing
export interface LoadTestOperation {
  name: string;
  weight: number;
  action: (iteration: number, context: any) => any;
}

export interface LoadTestScenario {
  name: string;
  description: string;
  duration: number;
  concurrentUsers: number;
  operations: LoadTestOperation[];
}

export interface LoadTestOptions {
  warmupDuration?: number;
  rampUpDuration?: number;
  rampDownDuration?: number;
  onProgress?: (progress: number, results: LoadTestResults) => void;
}

export interface LoadTestResults {
  scenario: string;
  totalOperations: number;
  operationsPerSecond: number;
  averageResponseTime: number;
  errorRate: number;
  operationResults: Record<string, {
    count: number;
    averageTime: number;
    minTime: number;
    maxTime: number;
    errors: number;
  }>;
}

export interface PerformanceMark {
  name: string;
  startTime: number;
  metadata?: Record<string, any>;
}

export interface PerformanceMetric {
  name: string;
  value: number;
  timestamp: number;
  category: string;
  metadata?: Record<string, any>;
}

// Global state for performance testing
const loadTestScenarios = new Map<string, LoadTestScenario>();
const performanceMarks = new Map<string, PerformanceMark>();
const performanceMetrics: PerformanceMetric[] = [];

/**
 * Register a load test scenario
 */
export function registerLoadTestScenario(scenario: LoadTestScenario): void {
  loadTestScenarios.set(scenario.name, scenario);
}

/**
 * Run a load test scenario
 */
export async function runLoadTestScenario(
  scenarioName: string,
  options: LoadTestOptions = {}
): Promise<LoadTestResults> {
  const scenario = loadTestScenarios.get(scenarioName);
  if (!scenario) {
    throw new Error(`Load test scenario '${scenarioName}' not found`);
  }

  const {
    warmupDuration = 0,
    rampUpDuration = 0,
    rampDownDuration = 0,
    onProgress
  } = options;

  const results: LoadTestResults = {
    scenario: scenarioName,
    totalOperations: 0,
    operationsPerSecond: 0,
    averageResponseTime: 0,
    errorRate: 0,
    operationResults: {}
  };

  // Initialize operation results
  scenario.operations.forEach(op => {
    results.operationResults[op.name] = {
      count: 0,
      averageTime: 0,
      minTime: Infinity,
      maxTime: 0,
      errors: 0
    };
  });

  const startTime = Date.now();
  const totalDuration = warmupDuration + rampUpDuration + scenario.duration + rampDownDuration;
  let currentTime = startTime;

  // Create weight-based operation selector
  const operationPool: LoadTestOperation[] = [];
  scenario.operations.forEach(op => {
    for (let i = 0; i < op.weight; i++) {
      operationPool.push(op);
    }
  });

  const contexts: any[] = Array(scenario.concurrentUsers).fill(null).map(() => ({}));
  let iteration = 0;

  while (currentTime - startTime < totalDuration) {
    const elapsed = currentTime - startTime;
    const progress = Math.min(100, (elapsed / totalDuration) * 100);

    // Determine current phase and user count
    let activeUsers = scenario.concurrentUsers;
    if (elapsed < warmupDuration) {
      activeUsers = 1; // Warmup with single user
    } else if (elapsed < warmupDuration + rampUpDuration) {
      const rampProgress = (elapsed - warmupDuration) / rampUpDuration;
      activeUsers = Math.ceil(scenario.concurrentUsers * rampProgress);
    } else if (elapsed > warmupDuration + rampUpDuration + scenario.duration) {
      const rampDownElapsed = elapsed - warmupDuration - rampUpDuration - scenario.duration;
      const rampDownProgress = rampDownElapsed / rampDownDuration;
      activeUsers = Math.ceil(scenario.concurrentUsers * (1 - rampDownProgress));
    }

    // Execute operations for active users
    for (let user = 0; user < activeUsers; user++) {
      const operation = operationPool[Math.floor(Math.random() * operationPool.length)];
      const operationStart = Date.now();

      try {
        await operation.action(iteration, contexts[user]);
        const operationTime = Date.now() - operationStart;

        // Update operation results
        const opResult = results.operationResults[operation.name];
        opResult.count++;
        opResult.minTime = Math.min(opResult.minTime, operationTime);
        opResult.maxTime = Math.max(opResult.maxTime, operationTime);
        opResult.averageTime = ((opResult.averageTime * (opResult.count - 1)) + operationTime) / opResult.count;

        results.totalOperations++;
      } catch (error) {
        results.operationResults[operation.name].errors++;
      }
    }

    iteration++;
    currentTime = Date.now();

    // Update overall metrics
    const elapsedSeconds = (currentTime - startTime) / 1000;
    results.operationsPerSecond = results.totalOperations / elapsedSeconds;

    // Calculate average response time
    let totalTime = 0;
    let totalCount = 0;
    Object.values(results.operationResults).forEach(opResult => {
      totalTime += opResult.averageTime * opResult.count;
      totalCount += opResult.count;
    });
    results.averageResponseTime = totalCount > 0 ? totalTime / totalCount : 0;

    // Calculate error rate
    const totalErrors = Object.values(results.operationResults)
      .reduce((sum, opResult) => sum + opResult.errors, 0);
    results.errorRate = results.totalOperations > 0 ? totalErrors / results.totalOperations : 0;

    // Call progress callback
    if (onProgress) {
      onProgress(progress, { ...results });
    }

    // Small delay to prevent overwhelming the system
    await new Promise(resolve => setTimeout(resolve, 10));
  }

  return results;
}

/**
 * Get results from previous load test runs
 */
export function getLoadTestResults(scenarioName?: string): LoadTestResults[] {
  // In a real implementation, this would return stored results
  // For this example, we'll return an empty array
  return [];
}

/**
 * Compare load test results
 */
export function compareLoadTestResults(
  baseline: LoadTestResults,
  current: LoadTestResults
): {
  performanceChange: number;
  operationChanges: Record<string, number>;
  recommendation: string;
} {
  const performanceChange = (current.operationsPerSecond - baseline.operationsPerSecond) / baseline.operationsPerSecond;
  
  const operationChanges: Record<string, number> = {};
  Object.keys(baseline.operationResults).forEach(opName => {
    const baselineOp = baseline.operationResults[opName];
    const currentOp = current.operationResults[opName];
    if (baselineOp && currentOp) {
      operationChanges[opName] = (currentOp.averageTime - baselineOp.averageTime) / baselineOp.averageTime;
    }
  });

  let recommendation = 'Performance is stable';
  if (performanceChange < -0.1) {
    recommendation = 'Performance has degraded significantly';
  } else if (performanceChange > 0.1) {
    recommendation = 'Performance has improved significantly';
  }

  return {
    performanceChange,
    operationChanges,
    recommendation
  };
}

/**
 * Record a performance metric
 */
export function recordMetric(
  name: string,
  value: number,
  category: string = 'general',
  metadata?: Record<string, any>
): void {
  performanceMetrics.push({
    name,
    value,
    timestamp: Date.now(),
    category,
    metadata
  });
}

/**
 * Start a performance mark
 */
export function startPerformanceMark(name: string, metadata?: Record<string, any>): void {
  performanceMarks.set(name, {
    name,
    startTime: Date.now(),
    metadata
  });
}

/**
 * End a performance mark and record the duration
 */
export function endPerformanceMark(name: string, category: string = 'timing'): number {
  const mark = performanceMarks.get(name);
  if (!mark) {
    throw new Error(`Performance mark '${name}' not found`);
  }

  const duration = Date.now() - mark.startTime;
  recordMetric(name, duration, category, mark.metadata);
  performanceMarks.delete(name);

  return duration;
}

/**
 * Get a summary of performance metrics
 */
export function getMetricSummary(
  category?: string,
  timeWindow?: number
): {
  count: number;
  average: number;
  min: number;
  max: number;
  recent: PerformanceMetric[];
} {
  let filteredMetrics = performanceMetrics;

  if (category) {
    filteredMetrics = filteredMetrics.filter(m => m.category === category);
  }

  if (timeWindow) {
    const cutoff = Date.now() - timeWindow;
    filteredMetrics = filteredMetrics.filter(m => m.timestamp >= cutoff);
  }

  if (filteredMetrics.length === 0) {
    return {
      count: 0,
      average: 0,
      min: 0,
      max: 0,
      recent: []
    };
  }

  const values = filteredMetrics.map(m => m.value);
  return {
    count: filteredMetrics.length,
    average: values.reduce((sum, v) => sum + v, 0) / values.length,
    min: Math.min(...values),
    max: Math.max(...values),
    recent: filteredMetrics.slice(-10) // Last 10 metrics
  };
}

/**
 * Detect performance regressions
 */
export function detectPerformanceRegressions(
  metricName: string,
  threshold: number = 0.2
): {
  hasRegression: boolean;
  changePercent: number;
  recommendation: string;
} {
  const recentMetrics = performanceMetrics
    .filter(m => m.name === metricName)
    .slice(-20); // Last 20 measurements

  if (recentMetrics.length < 10) {
    return {
      hasRegression: false,
      changePercent: 0,
      recommendation: 'Insufficient data for regression analysis'
    };
  }

  const baseline = recentMetrics.slice(0, 10);
  const recent = recentMetrics.slice(-10);

  const baselineAvg = baseline.reduce((sum, m) => sum + m.value, 0) / baseline.length;
  const recentAvg = recent.reduce((sum, m) => sum + m.value, 0) / recent.length;

  const changePercent = (recentAvg - baselineAvg) / baselineAvg;
  const hasRegression = Math.abs(changePercent) > threshold;

  let recommendation = 'Performance is stable';
  if (hasRegression) {
    if (changePercent > 0) {
      recommendation = `Performance degradation detected: ${(changePercent * 100).toFixed(1)}% slower`;
    } else {
      recommendation = `Performance improvement detected: ${(Math.abs(changePercent) * 100).toFixed(1)}% faster`;
    }
  }

  return {
    hasRegression,
    changePercent,
    recommendation
  };
}

/**
 * Global performance metrics instance
 */
export const globalPerformanceMetrics = {
  getAll: () => [...performanceMetrics],
  clear: () => performanceMetrics.length = 0,
  getByCategory: (category: string) => performanceMetrics.filter(m => m.category === category),
  getRecent: (count: number = 10) => performanceMetrics.slice(-count)
};