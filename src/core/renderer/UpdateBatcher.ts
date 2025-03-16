/**
 * UpdateBatcher.ts
 * 
 * Implements UI update batching to improve rendering performance
 * by grouping UI updates together and applying them in efficient batches.
 */

interface PendingUpdate {
  id: string;
  component: string; // Component identifier
  properties: Record<string, any>;
  timestamp: number;
}

export class UpdateBatcher {
  private pendingUpdates: Map<string, PendingUpdate> = new Map();
  private isApplyingUpdates: boolean = false;
  private requestId: number | null = null;
  private batchSize: number = 50;
  private adaptiveThreshold: number = 10; // ms for processing threshold
  private lastBatchTime: number = 0;
  
  constructor(options?: {
    batchSize?: number;
    adaptiveThreshold?: number;
  }) {
    if (options?.batchSize) {
      this.batchSize = options.batchSize;
    }
    
    if (options?.adaptiveThreshold) {
      this.adaptiveThreshold = options.adaptiveThreshold;
    }
  }
  
  /**
   * Queue a UI update to be applied in the next batch
   */
  public queueUpdate(component: string, properties: Record<string, any>): string {
    const id = `${component}-${Date.now()}`;
    
    // If there's already a pending update for this component, merge the properties
    if (this.pendingUpdates.has(component)) {
      const existingUpdate = this.pendingUpdates.get(component)!;
      this.pendingUpdates.set(component, {
        ...existingUpdate,
        properties: { ...existingUpdate.properties, ...properties },
        timestamp: Date.now()
      });
      return existingUpdate.id;
    }
    
    // Otherwise, create a new update
    this.pendingUpdates.set(component, {
      id,
      component,
      properties,
      timestamp: Date.now()
    });
    
    // Schedule rendering if not already scheduled
    this.scheduleRender();
    
    return id;
  }
  
  /**
   * Schedule the next render frame
   */
  private scheduleRender(): void {
    if (this.requestId !== null || this.isApplyingUpdates) {
      return;
    }
    
    this.requestId = window.requestAnimationFrame(() => {
      this.requestId = null;
      this.applyPendingUpdates();
    });
  }
  
  /**
   * Apply all pending updates in an efficient manner
   */
  private applyPendingUpdates(): void {
    if (this.pendingUpdates.size === 0) {
      return;
    }
    
    this.isApplyingUpdates = true;
    const startTime = performance.now();
    
    try {
      // Convert map to array for processing
      const updates = Array.from(this.pendingUpdates.values());
      
      // Sort updates by timestamp (oldest first)
      updates.sort((a, b) => a.timestamp - b.timestamp);
      
      // Apply updates in batches to avoid long-running tasks
      let processedCount = 0;
      const totalUpdates = updates.length;
      
      // Calculate batch size based on previous performance
      const adaptiveBatchSize = this.calculateAdaptiveBatchSize();
      const batchSizeToUse = Math.min(adaptiveBatchSize, this.batchSize);
      
      while (processedCount < totalUpdates) {
        const batchUpdates = updates.slice(
          processedCount, 
          processedCount + batchSizeToUse
        );
        
        this.applyBatch(batchUpdates);
        processedCount += batchUpdates.length;
        
        // Check if we've spent too much time and need to yield
        if (performance.now() - startTime > 16) { // ~60fps frame budget
          // Schedule the next batch for the next frame
          if (processedCount < totalUpdates) {
            this.scheduleContinuation();
            return;
          }
        }
      }
      
      // Clear the pending updates that were processed
      this.pendingUpdates.clear();
      
      // Record how long this batch took
      this.lastBatchTime = performance.now() - startTime;
    } finally {
      this.isApplyingUpdates = false;
      
      // If there are still updates (new ones added during processing),
      // schedule another render
      if (this.pendingUpdates.size > 0) {
        this.scheduleRender();
      }
    }
  }
  
  /**
   * Apply a batch of updates
   */
  private applyBatch(updates: PendingUpdate[]): void {
    // This would be implemented based on the application's rendering system
    console.log(`Applying batch of ${updates.length} UI updates`);
    
    // Example implementation:
    updates.forEach(update => {
      // Here we would apply the update to the actual UI
      console.log(`Applied update to component: ${update.component}`, update.properties);
    });
  }
  
  /**
   * Schedule continuation of update processing in the next frame
   */
  private scheduleContinuation(): void {
    if (this.requestId !== null) {
      return;
    }
    
    this.isApplyingUpdates = false;
    this.requestId = window.requestAnimationFrame(() => {
      this.requestId = null;
      this.applyPendingUpdates();
    });
  }
  
  /**
   * Calculate adaptive batch size based on performance
   */
  private calculateAdaptiveBatchSize(): number {
    if (this.lastBatchTime === 0) {
      return this.batchSize;
    }
    
    // If the last batch took longer than our threshold, reduce batch size
    if (this.lastBatchTime > this.adaptiveThreshold) {
      return Math.max(5, Math.floor(this.batchSize * 0.8));
    }
    
    // If the last batch was fast, increase batch size
    if (this.lastBatchTime < this.adaptiveThreshold / 2) {
      return Math.min(200, Math.floor(this.batchSize * 1.2));
    }
    
    // Otherwise keep the same batch size
    return this.batchSize;
  }
  
  /**
   * Cancel the scheduled render
   */
  public cancel(): void {
    if (this.requestId !== null) {
      window.cancelAnimationFrame(this.requestId);
      this.requestId = null;
    }
  }
  
  /**
   * Clear all pending updates
   */
  public clearPendingUpdates(): void {
    this.pendingUpdates.clear();
    this.cancel();
  }
  
  /**
   * Get the number of pending updates
   */
  public get pendingUpdateCount(): number {
    return this.pendingUpdates.size;
  }
} 