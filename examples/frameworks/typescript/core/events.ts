/**
 * Event System Utilities
 * 
 * This module provides utilities for event batching, queuing, and management
 * for high-performance event handling in Raxol applications.
 */

// Types for event system
export interface RaxolEvent {
  id: string;
  type: string;
  timestamp: number;
  data: any;
  priority: 'low' | 'normal' | 'high';
  processed: boolean;
}

export interface EventBatch {
  events: RaxolEvent[];
  batchId: string;
  createdAt: number;
  priority: 'low' | 'normal' | 'high';
}

// Global event queue state
let eventIdCounter = 0;
const eventQueue: RaxolEvent[] = [];
const highPriorityQueue: RaxolEvent[] = [];
const eventBatches: EventBatch[] = [];
let isProcessing = false;

/**
 * Generate a unique event ID
 */
function generateEventId(): string {
  return `event_${++eventIdCounter}_${Date.now()}`;
}

/**
 * Queue a normal priority event
 */
export function queueEvent(type: string, data: any): string {
  const event: RaxolEvent = {
    id: generateEventId(),
    type,
    timestamp: Date.now(),
    data,
    priority: 'normal',
    processed: false
  };

  eventQueue.push(event);
  
  // Automatically process queue if not already processing
  if (!isProcessing) {
    scheduleEventProcessing();
  }

  return event.id;
}

/**
 * Queue a high priority event (processed immediately)
 */
export function queueHighPriorityEvent(type: string, data: any): string {
  const event: RaxolEvent = {
    id: generateEventId(),
    type,
    timestamp: Date.now(),
    data,
    priority: 'high',
    processed: false
  };

  highPriorityQueue.push(event);

  // Process high priority events immediately
  processHighPriorityEvents();

  return event.id;
}

/**
 * Get the current length of the event queue
 */
export function getEventQueueLength(): number {
  return eventQueue.length + highPriorityQueue.length;
}

/**
 * Process high priority events immediately
 */
function processHighPriorityEvents(): void {
  while (highPriorityQueue.length > 0) {
    const event = highPriorityQueue.shift()!;
    processEvent(event);
  }
}

/**
 * Schedule event processing using requestAnimationFrame or setTimeout
 */
function scheduleEventProcessing(): void {
  if (isProcessing) return;

  isProcessing = true;

  // Use requestAnimationFrame if available, otherwise setTimeout
  const scheduler = typeof requestAnimationFrame !== 'undefined' 
    ? requestAnimationFrame 
    : (callback: () => void) => setTimeout(callback, 16);

  scheduler(() => {
    processEventQueue();
    isProcessing = false;
  });
}

/**
 * Process the main event queue in batches
 */
function processEventQueue(): void {
  const batchSize = 10; // Process up to 10 events per frame
  const batch: RaxolEvent[] = [];

  // Process high priority events first
  processHighPriorityEvents();

  // Process normal priority events in batches
  for (let i = 0; i < batchSize && eventQueue.length > 0; i++) {
    const event = eventQueue.shift()!;
    batch.push(event);
  }

  if (batch.length > 0) {
    const eventBatch: EventBatch = {
      events: batch,
      batchId: `batch_${Date.now()}`,
      createdAt: Date.now(),
      priority: 'normal'
    };

    eventBatches.push(eventBatch);
    processBatch(eventBatch);
  }

  // Continue processing if there are more events
  if (eventQueue.length > 0) {
    scheduleEventProcessing();
  }
}

/**
 * Process a batch of events
 */
function processBatch(batch: EventBatch): void {
  batch.events.forEach(event => {
    processEvent(event);
  });

  // Remove old batches to prevent memory leaks
  while (eventBatches.length > 100) {
    eventBatches.shift();
  }
}

/**
 * Process a single event
 */
function processEvent(event: RaxolEvent): void {
  try {
    // Mark as processed
    event.processed = true;

    // Emit event to listeners (simplified implementation)
    console.log(`Processing event: ${event.type}`, event.data);

    // In a real implementation, this would dispatch to registered listeners
    if (typeof window !== 'undefined' && window.dispatchEvent) {
      const customEvent = new CustomEvent(`raxol:${event.type}`, {
        detail: event.data
      });
      window.dispatchEvent(customEvent);
    }
  } catch (error) {
    console.error(`Error processing event ${event.id}:`, error);
  }
}

/**
 * Clear all events from the queue
 */
export function clearEventQueue(): void {
  eventQueue.length = 0;
  highPriorityQueue.length = 0;
  eventBatches.length = 0;
}

/**
 * Get event queue statistics
 */
export function getEventQueueStats(): {
  normalQueue: number;
  highPriorityQueue: number;
  totalProcessed: number;
  batchCount: number;
} {
  const totalProcessed = eventBatches.reduce(
    (total, batch) => total + batch.events.filter(e => e.processed).length, 
    0
  );

  return {
    normalQueue: eventQueue.length,
    highPriorityQueue: highPriorityQueue.length,
    totalProcessed,
    batchCount: eventBatches.length
  };
}

/**
 * Register an event listener for Raxol events
 */
export function addEventListener(eventType: string, listener: (data: any) => void): () => void {
  const handler = (event: CustomEvent) => {
    listener(event.detail);
  };

  if (typeof window !== 'undefined') {
    window.addEventListener(`raxol:${eventType}`, handler as EventListener);
    
    // Return cleanup function
    return () => {
      window.removeEventListener(`raxol:${eventType}`, handler as EventListener);
    };
  }

  // Return no-op cleanup function for non-browser environments
  return () => {};
}

/**
 * Flush all pending events immediately (useful for testing)
 */
export function flushEventQueue(): void {
  processHighPriorityEvents();
  
  while (eventQueue.length > 0) {
    const event = eventQueue.shift()!;
    processEvent(event);
  }
}