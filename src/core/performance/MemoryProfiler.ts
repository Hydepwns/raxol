/**
 * MemoryProfiler.ts
 * 
 * Provides tools for monitoring and analyzing memory usage in the application.
 * Helps identify memory leaks and optimize memory usage.
 */

interface MemorySnapshot {
  timestamp: number;
  jsHeapSizeLimit?: number;
  totalJSHeapSize?: number;
  usedJSHeapSize?: number;
  componentMemoryUsage: Map<string, number>;
  detailedBreakdown?: any;
}

interface ComponentMemoryStats {
  componentId: string;
  currentSize: number;
  peakSize: number;
  averageSize: number;
  snapshots: Array<{ timestamp: number, size: number }>;
}

export class MemoryProfiler {
  private snapshots: MemorySnapshot[] = [];
  private componentRegistry: Map<string, { size: number, instances: number }> = new Map();
  private memoryWarningThreshold: number = 100 * 1024 * 1024; // 100MB default
  private snapshotInterval: number | null = null;
  private listeners: Array<(snapshot: MemorySnapshot) => void> = [];
  
  constructor(options?: {
    warningThreshold?: number;
    autoSnapshot?: boolean;
    snapshotIntervalMs?: number;
  }) {
    if (options?.warningThreshold) {
      this.memoryWarningThreshold = options.warningThreshold;
    }
    
    if (options?.autoSnapshot && options?.snapshotIntervalMs) {
      this.startAutoSnapshots(options.snapshotIntervalMs);
    }
  }
  
  /**
   * Register a component to be tracked for memory usage
   */
  public registerComponent(componentId: string, estimatedSize: number): void {
    if (!this.componentRegistry.has(componentId)) {
      this.componentRegistry.set(componentId, { size: estimatedSize, instances: 1 });
    } else {
      const component = this.componentRegistry.get(componentId)!;
      component.instances++;
      this.componentRegistry.set(componentId, component);
    }
  }
  
  /**
   * Unregister a component when it's destroyed
   */
  public unregisterComponent(componentId: string): void {
    if (this.componentRegistry.has(componentId)) {
      const component = this.componentRegistry.get(componentId)!;
      component.instances--;
      
      if (component.instances <= 0) {
        this.componentRegistry.delete(componentId);
      } else {
        this.componentRegistry.set(componentId, component);
      }
    }
  }
  
  /**
   * Update the estimated memory size of a component
   */
  public updateComponentSize(componentId: string, newSize: number): void {
    if (this.componentRegistry.has(componentId)) {
      const component = this.componentRegistry.get(componentId)!;
      component.size = newSize;
      this.componentRegistry.set(componentId, component);
    }
  }
  
  /**
   * Take a snapshot of current memory usage
   */
  public takeSnapshot(): MemorySnapshot {
    // Get browser memory info if available
    const memoryInfo = this.getBrowserMemoryInfo();
    
    // Build component memory map
    const componentMemoryUsage = new Map<string, number>();
    this.componentRegistry.forEach((details, componentId) => {
      componentMemoryUsage.set(componentId, details.size * details.instances);
    });
    
    const snapshot: MemorySnapshot = {
      timestamp: Date.now(),
      componentMemoryUsage,
      ...memoryInfo
    };
    
    this.snapshots.push(snapshot);
    
    // Check if memory usage is above warning threshold
    if (memoryInfo.usedJSHeapSize && memoryInfo.usedJSHeapSize > this.memoryWarningThreshold) {
      this.emitMemoryWarning(snapshot);
    }
    
    // Notify listeners
    this.notifyListeners(snapshot);
    
    return snapshot;
  }
  
  /**
   * Start taking automatic snapshots at a specified interval
   */
  public startAutoSnapshots(intervalMs: number): void {
    if (this.snapshotInterval !== null) {
      this.stopAutoSnapshots();
    }
    
    this.snapshotInterval = window.setInterval(() => {
      this.takeSnapshot();
    }, intervalMs) as unknown as number;
  }
  
  /**
   * Stop taking automatic snapshots
   */
  public stopAutoSnapshots(): void {
    if (this.snapshotInterval !== null) {
      window.clearInterval(this.snapshotInterval);
      this.snapshotInterval = null;
    }
  }
  
  /**
   * Get memory statistics for a specific component
   */
  public getComponentStats(componentId: string): ComponentMemoryStats | null {
    if (!this.snapshots.length) {
      return null;
    }
    
    const snapshots = this.snapshots.filter(snapshot => 
      snapshot.componentMemoryUsage.has(componentId)
    ).map(snapshot => ({
      timestamp: snapshot.timestamp,
      size: snapshot.componentMemoryUsage.get(componentId) || 0
    }));
    
    if (!snapshots.length) {
      return null;
    }
    
    const sizes = snapshots.map(s => s.size);
    const currentSize = sizes[sizes.length - 1];
    const peakSize = Math.max(...sizes);
    const averageSize = sizes.reduce((sum, size) => sum + size, 0) / sizes.length;
    
    return {
      componentId,
      currentSize,
      peakSize,
      averageSize,
      snapshots
    };
  }
  
  /**
   * Get memory usage trend over time
   */
  public getMemoryTrend(): Array<{ timestamp: number, usage: number }> {
    return this.snapshots.map(snapshot => ({
      timestamp: snapshot.timestamp,
      usage: snapshot.usedJSHeapSize || 0
    }));
  }
  
  /**
   * Compare two snapshots to identify potential memory leaks
   */
  public compareSnapshots(snapshotId1: number, snapshotId2: number): any {
    if (!this.snapshots[snapshotId1] || !this.snapshots[snapshotId2]) {
      throw new Error('Invalid snapshot IDs');
    }
    
    const snapshot1 = this.snapshots[snapshotId1];
    const snapshot2 = this.snapshots[snapshotId2];
    
    const comparison = {
      timeDifference: snapshot2.timestamp - snapshot1.timestamp,
      overallDifference: {
        jsHeapSize: (snapshot2.usedJSHeapSize || 0) - (snapshot1.usedJSHeapSize || 0)
      },
      componentDifferences: new Map<string, number>()
    };
    
    // Compare component memory usage
    const allComponentIds = new Set([
      ...snapshot1.componentMemoryUsage.keys(),
      ...snapshot2.componentMemoryUsage.keys()
    ]);
    
    allComponentIds.forEach(componentId => {
      const size1 = snapshot1.componentMemoryUsage.get(componentId) || 0;
      const size2 = snapshot2.componentMemoryUsage.get(componentId) || 0;
      const difference = size2 - size1;
      
      if (difference !== 0) {
        comparison.componentDifferences.set(componentId, difference);
      }
    });
    
    return comparison;
  }
  
  /**
   * Add a listener for memory snapshots
   */
  public addListener(callback: (snapshot: MemorySnapshot) => void): void {
    this.listeners.push(callback);
  }
  
  /**
   * Remove a listener
   */
  public removeListener(callback: (snapshot: MemorySnapshot) => void): void {
    this.listeners = this.listeners.filter(listener => listener !== callback);
  }
  
  /**
   * Notify all listeners of a new snapshot
   */
  private notifyListeners(snapshot: MemorySnapshot): void {
    this.listeners.forEach(listener => {
      try {
        listener(snapshot);
      } catch (error) {
        console.error('Error in memory profiler listener:', error);
      }
    });
  }
  
  /**
   * Get browser memory information if available
   */
  private getBrowserMemoryInfo(): {
    jsHeapSizeLimit?: number;
    totalJSHeapSize?: number;
    usedJSHeapSize?: number;
  } {
    // Check if performance.memory is available (Chrome/Chromium-based browsers)
    if (window.performance && (window.performance as any).memory) {
      const memory = (window.performance as any).memory;
      return {
        jsHeapSizeLimit: memory.jsHeapSizeLimit,
        totalJSHeapSize: memory.totalJSHeapSize,
        usedJSHeapSize: memory.usedJSHeapSize
      };
    }
    
    // Fallback for browsers that don't support memory API
    return {};
  }
  
  /**
   * Emit a warning when memory usage exceeds the threshold
   */
  private emitMemoryWarning(snapshot: MemorySnapshot): void {
    console.warn('Memory usage warning:', {
      usedJSHeapSize: snapshot.usedJSHeapSize,
      threshold: this.memoryWarningThreshold,
      timestamp: snapshot.timestamp
    });
    
    // Find top memory consumers
    const topConsumers = Array.from(snapshot.componentMemoryUsage.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5);
    
    console.warn('Top memory consumers:', topConsumers);
  }
  
  /**
   * Clear all snapshots
   */
  public clearSnapshots(): void {
    this.snapshots = [];
  }
  
  /**
   * Get all snapshots
   */
  public getAllSnapshots(): MemorySnapshot[] {
    return [...this.snapshots];
  }
} 