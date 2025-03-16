/**
 * Core events module
 * 
 * Exports the event system components and provides
 * a centralized event management system.
 */

import { EventBatcher } from './EventBatcher';

// Create singleton instance for application-wide use
export const globalEventBatcher = new EventBatcher({
  batchSize: 20,      // Process up to 20 events per batch
  throttleTime: 16    // Target 60fps (1000ms / 60 ≈ 16ms)
});

// Re-export EventBatcher for custom instances
export { EventBatcher };

// Event management API
export const queueEvent = (
  type: string, 
  payload: any, 
  priority: 'high' | 'normal' | 'low' = 'normal'
): string => {
  return globalEventBatcher.queueEvent(type, payload, priority);
};

// Utility function to queue high-priority events
export const queueHighPriorityEvent = (type: string, payload: any): string => {
  return globalEventBatcher.queueEvent(type, payload, 'high');
};

// Utility function to queue low-priority events
export const queueLowPriorityEvent = (type: string, payload: any): string => {
  return globalEventBatcher.queueEvent(type, payload, 'low');
};

// Get current queue length
export const getEventQueueLength = (): number => {
  return globalEventBatcher.queueLength;
};

// Clear all queued events
export const clearEventQueue = (): void => {
  globalEventBatcher.clearQueue();
}; 