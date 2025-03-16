/**
 * EventBatcher.ts
 * 
 * Implements an event batching system to improve performance by
 * grouping related events together and processing them in batches.
 */

type EventPriority = 'high' | 'normal' | 'low';

interface QueuedEvent {
  type: string;
  payload: any;
  priority: EventPriority;
  timestamp: number;
  id: string;
}

export class EventBatcher {
  private eventQueue: QueuedEvent[] = [];
  private isProcessing: boolean = false;
  private batchSize: number = 10;
  private throttleTime: number = 16; // ~60fps in milliseconds
  private lastProcessTime: number = 0;
  private processingTimeoutId: number | null = null;
  
  constructor(options?: {
    batchSize?: number;
    throttleTime?: number;
  }) {
    if (options?.batchSize) {
      this.batchSize = options.batchSize;
    }
    
    if (options?.throttleTime) {
      this.throttleTime = options.throttleTime;
    }
  }
  
  /**
   * Queue an event for processing
   */
  public queueEvent(type: string, payload: any, priority: EventPriority = 'normal'): string {
    const id = this.generateEventId();
    
    this.eventQueue.push({
      type,
      payload,
      priority,
      timestamp: Date.now(),
      id,
    });
    
    this.scheduleProcessing();
    
    return id;
  }
  
  /**
   * Schedule the processing of queued events
   */
  private scheduleProcessing(): void {
    if (this.isProcessing || this.processingTimeoutId) {
      return;
    }
    
    const currentTime = Date.now();
    const timeSinceLastProcess = currentTime - this.lastProcessTime;
    
    if (timeSinceLastProcess >= this.throttleTime) {
      // Process immediately
      this.processEventQueue();
    } else {
      // Schedule processing
      const delay = this.throttleTime - timeSinceLastProcess;
      this.processingTimeoutId = window.setTimeout(() => {
        this.processingTimeoutId = null;
        this.processEventQueue();
      }, delay) as unknown as number;
    }
  }
  
  /**
   * Process events in the queue based on priority and batch size
   */
  private processEventQueue(): void {
    if (this.eventQueue.length === 0) {
      return;
    }
    
    this.isProcessing = true;
    this.lastProcessTime = Date.now();
    
    try {
      // Sort queue by priority (high -> normal -> low)
      this.eventQueue.sort((a, b) => {
        const priorityOrder = { high: 0, normal: 1, low: 2 };
        return priorityOrder[a.priority] - priorityOrder[b.priority];
      });
      
      // Take a batch of events to process
      const eventsToProcess = this.eventQueue.splice(0, this.batchSize);
      
      // Process the batch
      this.processBatch(eventsToProcess);
      
      // Coalesce similar events in the remaining queue
      this.coalesceEvents();
      
      // If there are more events to process, schedule the next batch
      if (this.eventQueue.length > 0) {
        this.scheduleProcessing();
      }
    } finally {
      this.isProcessing = false;
    }
  }
  
  /**
   * Process a batch of events
   */
  private processBatch(events: QueuedEvent[]): void {
    // Dispatch events to their respective handlers
    // This would be implemented based on the application's event system
    console.log(`Processing batch of ${events.length} events`);
    
    // Example implementation:
    events.forEach(event => {
      // Here we would call the actual event handlers
      // For now, just log the event
      console.log(`Processed event: ${event.type} with priority ${event.priority}`);
    });
  }
  
  /**
   * Coalesce similar events to reduce processing overhead
   */
  private coalesceEvents(): void {
    // Group events by type
    const eventsByType: Record<string, QueuedEvent[]> = {};
    
    this.eventQueue.forEach(event => {
      if (!eventsByType[event.type]) {
        eventsByType[event.type] = [];
      }
      eventsByType[event.type].push(event);
    });
    
    // Apply coalescing rules for specific event types
    for (const type in eventsByType) {
      const events = eventsByType[type];
      
      // Only attempt coalescing if there are multiple events of the same type
      if (events.length > 1) {
        this.coalesceEventsByType(type, events);
      }
    }
  }
  
  /**
   * Coalesce events of a specific type
   */
  private coalesceEventsByType(type: string, events: QueuedEvent[]): void {
    // This would be customized based on event types
    // For example, multiple resize events could be coalesced into one
    
    // Example for "resize" events - keep only the latest one
    if (type === 'resize') {
      // Find the latest resize event (highest timestamp)
      const latestEvent = events.reduce((latest, current) => {
        return current.timestamp > latest.timestamp ? current : latest;
      });
      
      // Remove all resize events from the queue
      this.eventQueue = this.eventQueue.filter(e => e.type !== 'resize');
      
      // Add back only the latest one
      this.eventQueue.push(latestEvent);
    }
    
    // Example for "scroll" events - throttle them
    if (type === 'scroll') {
      // Sort by timestamp
      events.sort((a, b) => a.timestamp - b.timestamp);
      
      // Keep only the first and the last event if there are more than 2
      if (events.length > 2) {
        const firstEvent = events[0];
        const lastEvent = events[events.length - 1];
        
        // Remove all scroll events from the queue
        this.eventQueue = this.eventQueue.filter(e => e.type !== 'scroll');
        
        // Add back only the first and last
        this.eventQueue.push(firstEvent, lastEvent);
      }
    }
  }
  
  /**
   * Generate a unique ID for the event
   */
  private generateEventId(): string {
    return `event_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }
  
  /**
   * Cancel scheduled processing
   */
  public cancel(): void {
    if (this.processingTimeoutId) {
      window.clearTimeout(this.processingTimeoutId);
      this.processingTimeoutId = null;
    }
  }
  
  /**
   * Get the current number of events in the queue
   */
  public get queueLength(): number {
    return this.eventQueue.length;
  }
  
  /**
   * Clear all events from the queue
   */
  public clearQueue(): void {
    this.eventQueue = [];
    this.cancel();
  }
} 