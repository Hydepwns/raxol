/**
 * Load Testing Example
 * 
 * This example demonstrates how to use the Load Testing infrastructure
 * to evaluate component performance under stress.
 */

import {
  registerLoadTestScenario,
  runLoadTestScenario,
  getLoadTestResults,
  compareLoadTestResults,
  recordMetric
} from '../../core/performance';

/**
 * Mock component used for load testing
 */
class MockTableComponent {
  private rows: any[] = [];
  private columns: string[] = [];
  private renderTime: number = 0;
  
  constructor(columns: string[] = ['id', 'name', 'value']) {
    this.columns = columns;
  }
  
  /**
   * Add rows to the table
   */
  public addRows(count: number): void {
    const startTime = performance.now();
    
    for (let i = 0; i < count; i++) {
      const row: Record<string, any> = {};
      this.columns.forEach(col => {
        row[col] = `${col}_value_${Math.random().toString(36).substring(2, 9)}`;
      });
      this.rows.push(row);
    }
    
    // Simulate render calculation based on row count
    const renderWork = Math.min(50, 0.05 * this.rows.length);
    const endTime = startTime + renderWork;
    
    // Busy wait to simulate work
    while (performance.now() < endTime) {
      // Intentionally empty - simulating render work
    }
    
    this.renderTime = performance.now() - startTime;
    recordMetric('table_render', this.renderTime, 'render', { rowCount: this.rows.length });
  }
  
  /**
   * Sort the table data
   */
  public sortBy(column: string): void {
    const startTime = performance.now();
    
    if (this.columns.includes(column)) {
      this.rows.sort((a, b) => {
        if (a[column] < b[column]) return -1;
        if (a[column] > b[column]) return 1;
        return 0;
      });
    }
    
    // Simulate work based on row count (sorting is O(n log n))
    const sortTime = this.rows.length * Math.log(this.rows.length) * 0.01;
    const endTime = startTime + sortTime;
    
    // Busy wait to simulate work
    while (performance.now() < endTime) {
      // Intentionally empty - simulating sort work
    }
    
    this.renderTime = performance.now() - startTime;
    recordMetric('table_sort', this.renderTime, 'render', { 
      rowCount: this.rows.length,
      column 
    });
  }
  
  /**
   * Filter the table data
   */
  public filter(column: string, value: string): void {
    const startTime = performance.now();
    
    // Simulate filter operation (this doesn't actually filter the data in this mock)
    
    // Simulate work based on row count (filtering is O(n))
    const filterTime = this.rows.length * 0.02;
    const endTime = startTime + filterTime;
    
    // Busy wait to simulate work
    while (performance.now() < endTime) {
      // Intentionally empty - simulating filter work
    }
    
    this.renderTime = performance.now() - startTime;
    recordMetric('table_filter', this.renderTime, 'render', { 
      rowCount: this.rows.length,
      column,
      value
    });
  }
  
  /**
   * Get the current row count
   */
  public getRowCount(): number {
    return this.rows.length;
  }
}

/**
 * Define test scenarios
 */
function defineTestScenarios(): void {
  // Scenario 1: Table component with basic operations
  registerLoadTestScenario({
    name: 'table-component-basic',
    description: 'Tests basic table component operations with moderate data',
    duration: 10000, // 10 seconds
    concurrentUsers: 5,
    operations: [
      {
        name: 'add_rows',
        weight: 5,
        action: (iteration, context) => {
          if (!context.table) {
            context.table = new MockTableComponent();
          }
          context.table.addRows(10);
          return context.table.getRowCount();
        }
      },
      {
        name: 'sort_table',
        weight: 3,
        action: (iteration, context) => {
          if (!context.table || context.table.getRowCount() === 0) {
            context.table = new MockTableComponent();
            context.table.addRows(50);
          }
          
          const columns = ['id', 'name', 'value'];
          const randomColumn = columns[Math.floor(Math.random() * columns.length)];
          context.table.sortBy(randomColumn);
        }
      },
      {
        name: 'filter_table',
        weight: 2,
        action: (iteration, context) => {
          if (!context.table || context.table.getRowCount() === 0) {
            context.table = new MockTableComponent();
            context.table.addRows(50);
          }
          
          const columns = ['id', 'name', 'value'];
          const randomColumn = columns[Math.floor(Math.random() * columns.length)];
          const searchValue = `value_${Math.floor(Math.random() * 100)}`;
          context.table.filter(randomColumn, searchValue);
        }
      }
    ]
  });
  
  // Scenario 2: Table component with heavy load
  registerLoadTestScenario({
    name: 'table-component-heavy',
    description: 'Tests table component operations with large datasets',
    duration: 15000, // 15 seconds
    concurrentUsers: 10,
    operations: [
      {
        name: 'add_large_dataset',
        weight: 2,
        action: (iteration, context) => {
          if (!context.table) {
            context.table = new MockTableComponent(['id', 'name', 'value', 'description', 'category', 'price', 'stock']);
          }
          
          // Add a large number of rows
          context.table.addRows(100);
          return context.table.getRowCount();
        }
      },
      {
        name: 'complex_sort',
        weight: 4,
        action: (iteration, context) => {
          if (!context.table || context.table.getRowCount() < 200) {
            context.table = new MockTableComponent(['id', 'name', 'value', 'description', 'category', 'price', 'stock']);
            context.table.addRows(200);
          }
          
          const columns = ['id', 'name', 'value', 'description', 'category', 'price', 'stock'];
          const randomColumn = columns[Math.floor(Math.random() * columns.length)];
          context.table.sortBy(randomColumn);
        }
      },
      {
        name: 'complex_filter',
        weight: 4,
        action: (iteration, context) => {
          if (!context.table || context.table.getRowCount() < 200) {
            context.table = new MockTableComponent(['id', 'name', 'value', 'description', 'category', 'price', 'stock']);
            context.table.addRows(200);
          }
          
          const columns = ['id', 'name', 'value', 'description', 'category', 'price', 'stock'];
          const randomColumn = columns[Math.floor(Math.random() * columns.length)];
          const searchValue = `value_${Math.floor(Math.random() * 100)}`;
          context.table.filter(randomColumn, searchValue);
        }
      }
    ]
  });
}

/**
 * Run the load tests
 */
async function runLoadTests(): Promise<void> {
  console.log('Running load test scenario 1: Basic table operations');
  
  // Run the first scenario with warmup
  const basicResults = await runLoadTestScenario('table-component-basic', {
    warmupDuration: 1000,
    rampUpDuration: 2000,
    onProgress: (progress, results) => {
      if (progress % 20 === 0) { // Log every 20%
        console.log(`Progress: ${progress.toFixed(1)}%, Operations: ${results.totalOperations}, Ops/sec: ${results.operationsPerSecond.toFixed(2)}`);
      }
    }
  });
  
  console.log('Basic scenario results:', {
    totalOperations: basicResults.totalOperations,
    operationsPerSecond: basicResults.operationsPerSecond.toFixed(2),
    averageResponseTime: basicResults.averageResponseTime.toFixed(2),
    errorRate: basicResults.errorRate
  });
  
  // Run the second scenario with warmup and ramp up/down
  console.log('\nRunning load test scenario 2: Heavy table operations');
  const heavyResults = await runLoadTestScenario('table-component-heavy', {
    warmupDuration: 2000,
    rampUpDuration: 3000,
    rampDownDuration: 3000,
    onProgress: (progress, results) => {
      if (progress % 20 === 0) { // Log every 20%
        console.log(`Progress: ${progress.toFixed(1)}%, Operations: ${results.totalOperations}, Ops/sec: ${results.operationsPerSecond.toFixed(2)}`);
      }
    }
  });
  
  console.log('Heavy scenario results:', {
    totalOperations: heavyResults.totalOperations,
    operationsPerSecond: heavyResults.operationsPerSecond.toFixed(2),
    averageResponseTime: heavyResults.averageResponseTime.toFixed(2),
    errorRate: heavyResults.errorRate
  });
  
  // Compare the two scenarios
  console.log('\nOperation breakdown - Basic scenario:');
  Object.entries(basicResults.operationResults).forEach(([opName, stats]) => {
    console.log(`- ${opName}: ${stats.count} operations, avg time: ${stats.averageTime.toFixed(2)}ms`);
  });
  
  console.log('\nOperation breakdown - Heavy scenario:');
  Object.entries(heavyResults.operationResults).forEach(([opName, stats]) => {
    console.log(`- ${opName}: ${stats.count} operations, avg time: ${stats.averageTime.toFixed(2)}ms`);
  });
}

/**
 * Run the load testing example
 */
export async function runLoadTestingExample(): Promise<void> {
  console.log('Starting Load Testing Example...');
  
  // Define test scenarios
  defineTestScenarios();
  
  // Run the load tests
  await runLoadTests();
  
  console.log('\nLoad testing example complete');
} 