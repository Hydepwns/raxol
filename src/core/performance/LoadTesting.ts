/**
 * LoadTesting.ts
 * 
 * Provides infrastructure for conducting load tests on components and systems
 * to ensure performance under high stress and varying load conditions.
 */

import { recordMetric, startPerformanceMark, endPerformanceMark } from './index';

type LoadTestScenario = {
  name: string;
  description: string;
  duration: number; // milliseconds
  concurrentUsers: number;
  operations: LoadTestOperation[];
};

type LoadTestOperation = {
  name: string;
  weight: number; // Probability weight for random selection
  action: (iteration: number, context: any) => Promise<void> | void;
  postAction?: (result: any, context: any) => void;
};

type LoadTestResult = {
  scenarioName: string;
  totalOperations: number;
  operationsPerSecond: number;
  averageResponseTime: number;
  maxResponseTime: number;
  p95ResponseTime: number;
  errorRate: number;
  operationResults: Record<string, {
    count: number;
    averageTime: number;
    maxTime: number;
    minTime: number;
    errors: number;
  }>;
  duration: number;
  timestamp: number;
  testId: string;
};

type LoadTestOptions = {
  warmupDuration?: number;
  cooldownDuration?: number;
  rampUpDuration?: number;
  rampDownDuration?: number;
  contextFactory?: () => any;
  onProgress?: (progress: number, results: Partial<LoadTestResult>) => void;
};

export class LoadTester {
  private scenarios: Map<string, LoadTestScenario> = new Map();
  private results: Map<string, LoadTestResult[]> = new Map();
  private isRunning: boolean = false;
  private currentTestId: string = '';
  private abortController: AbortController | null = null;
  
  /**
   * Register a new load test scenario
   */
  public registerScenario(scenario: LoadTestScenario): void {
    if (this.scenarios.has(scenario.name)) {
      console.warn(`Scenario "${scenario.name}" already exists and will be overwritten.`);
    }
    
    this.scenarios.set(scenario.name, scenario);
  }
  
  /**
   * Run a load test scenario
   */
  public async runScenario(
    scenarioName: string, 
    options: LoadTestOptions = {}
  ): Promise<LoadTestResult> {
    if (this.isRunning) {
      throw new Error('A load test is already running');
    }
    
    const scenario = this.scenarios.get(scenarioName);
    if (!scenario) {
      throw new Error(`Scenario "${scenarioName}" not found`);
    }
    
    this.isRunning = true;
    this.currentTestId = this.generateTestId();
    this.abortController = new AbortController();
    
    try {
      console.log(`Starting load test scenario: ${scenarioName}`);
      
      // Initialize test result
      const result: LoadTestResult = {
        scenarioName,
        totalOperations: 0,
        operationsPerSecond: 0,
        averageResponseTime: 0,
        maxResponseTime: 0,
        p95ResponseTime: 0,
        errorRate: 0,
        operationResults: {},
        duration: scenario.duration,
        timestamp: Date.now(),
        testId: this.currentTestId
      };
      
      // Initialize operation results
      scenario.operations.forEach(op => {
        result.operationResults[op.name] = {
          count: 0,
          averageTime: 0,
          maxTime: 0,
          minTime: Number.MAX_VALUE,
          errors: 0
        };
      });
      
      // Create user contexts
      const contexts = Array(scenario.concurrentUsers)
        .fill(0)
        .map(() => options.contextFactory ? options.contextFactory() : {});
      
      // Warmup period if specified
      if (options.warmupDuration && options.warmupDuration > 0) {
        await this.runWarmup(scenario, options.warmupDuration, contexts);
      }
      
      // Start the actual test
      const startTime = Date.now();
      const endTime = startTime + scenario.duration;
      
      // Setup ramp parameters
      const rampUpDuration = options.rampUpDuration || 0;
      const rampDownDuration = options.rampDownDuration || 0;
      
      const operationPromises: Promise<void>[] = [];
      let totalOperations = 0;
      const operationTimes: number[] = [];
      
      // Main test loop
      while (Date.now() < endTime && !this.abortController.signal.aborted) {
        // Calculate current load based on ramp up/down
        const elapsed = Date.now() - startTime;
        const remaining = scenario.duration - elapsed;
        
        let currentUsers = scenario.concurrentUsers;
        
        // Apply ramp up if in ramp up phase
        if (rampUpDuration > 0 && elapsed < rampUpDuration) {
          currentUsers = Math.floor((elapsed / rampUpDuration) * scenario.concurrentUsers);
          currentUsers = Math.max(1, currentUsers); // At least 1 user
        }
        
        // Apply ramp down if in ramp down phase
        if (rampDownDuration > 0 && remaining < rampDownDuration) {
          currentUsers = Math.floor((remaining / rampDownDuration) * scenario.concurrentUsers);
          currentUsers = Math.max(1, currentUsers); // At least 1 user
        }
        
        // Run operations for active users
        for (let i = 0; i < currentUsers; i++) {
          // Select an operation based on weights
          const operation = this.selectOperation(scenario.operations);
          
          // Execute the operation
          operationPromises.push(
            this.executeOperation(
              operation, 
              totalOperations, 
              contexts[i], 
              result,
              operationTimes
            )
          );
          
          totalOperations++;
        }
        
        // Report progress
        if (options.onProgress) {
          const progress = (elapsed / scenario.duration) * 100;
          options.onProgress(progress, this.calculatePartialResults(
            result, 
            operationTimes, 
            totalOperations, 
            elapsed
          ));
        }
        
        // Yield to prevent blocking
        await new Promise(resolve => setTimeout(resolve, 10));
      }
      
      // Wait for any remaining operations to complete
      await Promise.all(operationPromises);
      
      // Calculate final results
      const actualDuration = Date.now() - startTime;
      result.totalOperations = totalOperations;
      result.operationsPerSecond = totalOperations / (actualDuration / 1000);
      
      // Calculate response time statistics
      if (operationTimes.length > 0) {
        operationTimes.sort((a, b) => a - b);
        result.averageResponseTime = operationTimes.reduce((a, b) => a + b, 0) / operationTimes.length;
        result.maxResponseTime = operationTimes[operationTimes.length - 1];
        
        // Calculate p95
        const p95Index = Math.floor(operationTimes.length * 0.95);
        result.p95ResponseTime = operationTimes[p95Index];
      }
      
      // Calculate error rate
      let totalErrors = 0;
      for (const opResult of Object.values(result.operationResults)) {
        totalErrors += opResult.errors;
      }
      result.errorRate = totalErrors / totalOperations;
      
      // Store the result
      if (!this.results.has(scenarioName)) {
        this.results.set(scenarioName, []);
      }
      this.results.get(scenarioName)!.push(result);
      
      // Cooldown period if specified
      if (options.cooldownDuration && options.cooldownDuration > 0) {
        await new Promise(resolve => setTimeout(resolve, options.cooldownDuration));
      }
      
      console.log(`Load test scenario completed: ${scenarioName}`);
      
      return result;
    } finally {
      this.isRunning = false;
      this.abortController = null;
    }
  }
  
  /**
   * Stop the currently running load test
   */
  public stopTest(): void {
    if (this.isRunning && this.abortController) {
      this.abortController.abort();
      console.log('Load test aborted');
    }
  }
  
  /**
   * Get the results of previous load tests for a scenario
   */
  public getScenarioResults(scenarioName: string): LoadTestResult[] {
    return this.results.get(scenarioName) || [];
  }
  
  /**
   * Get all available scenarios
   */
  public getScenarios(): LoadTestScenario[] {
    return Array.from(this.scenarios.values());
  }
  
  /**
   * Compare results between two test runs
   */
  public compareResults(
    resultId1: string, 
    resultId2: string
  ): { 
    operationsPerSecondChange: number, 
    responseTimeChange: number,
    errorRateChange: number
  } {
    const result1 = this.findResultById(resultId1);
    const result2 = this.findResultById(resultId2);
    
    if (!result1 || !result2) {
      throw new Error('One or both test results not found');
    }
    
    return {
      operationsPerSecondChange: this.calculatePercentChange(
        result1.operationsPerSecond, 
        result2.operationsPerSecond
      ),
      responseTimeChange: this.calculatePercentChange(
        result1.averageResponseTime, 
        result2.averageResponseTime
      ),
      errorRateChange: this.calculatePercentChange(
        result1.errorRate,
        result2.errorRate
      )
    };
  }
  
  /**
   * Delete a test result
   */
  public deleteResult(testId: string): boolean {
    for (const [scenarioName, results] of this.results.entries()) {
      const index = results.findIndex(r => r.testId === testId);
      if (index !== -1) {
        results.splice(index, 1);
        if (results.length === 0) {
          this.results.delete(scenarioName);
        }
        return true;
      }
    }
    return false;
  }
  
  /**
   * Clear all test results
   */
  public clearAllResults(): void {
    this.results.clear();
  }
  
  /**
   * Generate a unique test ID
   */
  private generateTestId(): string {
    return `test_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
  }
  
  /**
   * Select an operation based on weights
   */
  private selectOperation(operations: LoadTestOperation[]): LoadTestOperation {
    // Calculate total weight
    const totalWeight = operations.reduce((sum, op) => sum + op.weight, 0);
    
    // Generate a random value between 0 and total weight
    let random = Math.random() * totalWeight;
    
    // Find the selected operation
    for (const operation of operations) {
      random -= operation.weight;
      if (random <= 0) {
        return operation;
      }
    }
    
    // Fallback to the first operation (should never happen unless weights are 0)
    return operations[0];
  }
  
  /**
   * Execute an operation and record metrics
   */
  private async executeOperation(
    operation: LoadTestOperation,
    iteration: number,
    context: any,
    result: LoadTestResult,
    operationTimes: number[]
  ): Promise<void> {
    const opResult = result.operationResults[operation.name];
    
    try {
      // Start timing the operation
      const startTimestamp = performance.now();
      
      // Execute the operation
      startPerformanceMark(`load_test_${operation.name}`, { iteration, context });
      const actionResult = await Promise.resolve(operation.action(iteration, context));
      const duration = endPerformanceMark(`load_test_${operation.name}`, 'custom');
      
      // Record the operation result
      if (duration !== null) {
        opResult.count++;
        
        // Update time statistics
        const prevTotal = opResult.averageTime * (opResult.count - 1);
        opResult.averageTime = (prevTotal + duration) / opResult.count;
        opResult.maxTime = Math.max(opResult.maxTime, duration);
        opResult.minTime = Math.min(opResult.minTime, duration);
        
        operationTimes.push(duration);
      }
      
      // Run post-action if defined
      if (operation.postAction) {
        operation.postAction(actionResult, context);
      }
    } catch (error) {
      opResult.errors++;
      console.error(`Error in operation ${operation.name}:`, error);
    }
  }
  
  /**
   * Run a warmup period
   */
  private async runWarmup(
    scenario: LoadTestScenario,
    duration: number,
    contexts: any[]
  ): Promise<void> {
    console.log(`Starting warmup period (${duration}ms)`);
    
    const startTime = Date.now();
    const endTime = startTime + duration;
    
    while (Date.now() < endTime && this.abortController && !this.abortController.signal.aborted) {
      // Run a sample of operations
      const promises = [];
      for (let i = 0; i < Math.min(contexts.length, 5); i++) {
        const operation = this.selectOperation(scenario.operations);
        promises.push(operation.action(-1, contexts[i]));
      }
      
      await Promise.all(promises.map(p => Promise.resolve(p).catch(e => console.error('Warmup error:', e))));
      
      // Brief pause to prevent tight loop
      await new Promise(resolve => setTimeout(resolve, 50));
    }
    
    console.log('Warmup period completed');
  }
  
  /**
   * Calculate percentage change between two values
   */
  private calculatePercentChange(oldValue: number, newValue: number): number {
    if (oldValue === 0) {
      return newValue === 0 ? 0 : 100; // Avoid division by zero
    }
    return ((newValue - oldValue) / oldValue) * 100;
  }
  
  /**
   * Find a test result by ID
   */
  private findResultById(testId: string): LoadTestResult | undefined {
    for (const results of this.results.values()) {
      const found = results.find(r => r.testId === testId);
      if (found) {
        return found;
      }
    }
    return undefined;
  }
  
  /**
   * Calculate partial results during test execution
   */
  private calculatePartialResults(
    result: LoadTestResult, 
    operationTimes: number[], 
    totalOperations: number, 
    elapsed: number
  ): Partial<LoadTestResult> {
    const partial: Partial<LoadTestResult> = {
      totalOperations,
      operationsPerSecond: totalOperations / (elapsed / 1000)
    };
    
    // Calculate partial response time statistics
    if (operationTimes.length > 0) {
      partial.averageResponseTime = operationTimes.reduce((a, b) => a + b, 0) / operationTimes.length;
      partial.maxResponseTime = Math.max(...operationTimes);
    }
    
    return partial;
  }
} 