/**
 * Memory Profiling Example
 * 
 * This example demonstrates how to use the memory profiling system
 * to monitor and analyze memory usage in components.
 */

import {
  registerComponent,
  unregisterComponent,
  updateComponentSize,
  takeMemorySnapshot,
  getComponentMemoryStats,
  getMemoryTrend,
  compareMemorySnapshots
} from '../../core/performance';

// Example component class to demonstrate memory tracking
class ExampleComponent {
  private id: string;
  private data: any[] = [];
  
  constructor(id: string, initialDataSize: number = 0) {
    this.id = id;
    // Register the component with the memory profiler
    registerComponent(id, this.estimateSize());
    
    // Initialize with some data
    if (initialDataSize > 0) {
      this.addData(initialDataSize);
    }
  }
  
  // Add data to simulate memory growth
  public addData(itemCount: number): void {
    for (let i = 0; i < itemCount; i++) {
      this.data.push({
        id: `item_${i}`,
        value: `This is item ${i} with some data to consume memory`,
        timestamp: Date.now(),
        metadata: {
          type: 'example',
          tags: ['sample', 'memory', 'profiling']
        }
      });
    }
    
    // Update the component size estimation
    updateComponentSize(this.id, this.estimateSize());
  }
  
  // Clear data to simulate memory release
  public clearData(): void {
    this.data = [];
    updateComponentSize(this.id, this.estimateSize());
  }
  
  // Estimate the memory size of this component
  private estimateSize(): number {
    // This is a simplified estimation
    // In a real app, you would need more sophisticated size calculation
    const approximateSizePerItem = 200; // bytes
    return this.data.length * approximateSizePerItem;
  }
  
  // Simulate component destruction
  public destroy(): void {
    unregisterComponent(this.id);
    this.data = [];
  }
}

/**
 * Run a memory profiling demonstration
 */
export function runMemoryProfilingExample(): void {
  console.log('Starting Memory Profiling Example...');
  
  // Take an initial snapshot
  takeMemorySnapshot();
  const initialSnapshotId = 0;
  
  // Create a few components
  const components: ExampleComponent[] = [
    new ExampleComponent('table-component', 100),
    new ExampleComponent('chart-component', 50),
    new ExampleComponent('list-component', 200)
  ];
  
  // Take a snapshot after initial creation
  takeMemorySnapshot();
  
  // Simulate user interactions that increase memory usage
  setTimeout(() => {
    console.log('Simulating memory growth...');
    components[0].addData(500);  // Add 500 items to the table
    components[1].addData(200);  // Add 200 items to the chart
    
    // Take snapshot after growth
    takeMemorySnapshot();
    const growthSnapshotId = 2;
    
    // Log memory stats for a component
    const tableStats = getComponentMemoryStats('table-component');
    console.log('Table component memory stats:', tableStats);
    
    // Simulate memory cleanup
    setTimeout(() => {
      console.log('Simulating memory cleanup...');
      components[0].clearData();
      components[2].clearData();
      
      // Take snapshot after cleanup
      takeMemorySnapshot();
      const cleanupSnapshotId = 3;
      
      // Compare snapshots to analyze memory changes
      const growthComparison = compareMemorySnapshots(initialSnapshotId, growthSnapshotId);
      console.log('Memory growth comparison:', growthComparison);
      
      const cleanupComparison = compareMemorySnapshots(growthSnapshotId, cleanupSnapshotId);
      console.log('Memory cleanup comparison:', cleanupComparison);
      
      // Get overall memory trend
      const memoryTrend = getMemoryTrend();
      console.log('Memory usage trend:', memoryTrend);
      
      // Clean up components
      setTimeout(() => {
        components.forEach(component => component.destroy());
        console.log('Memory profiling example complete');
      }, 1000);
    }, 1000);
  }, 1000);
} 