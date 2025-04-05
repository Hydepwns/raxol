/**
 * Core renderer module for Raxol.
 * Handles rendering of UI elements and managing the render loop.
 */

import { UpdateBatcher } from './UpdateBatcher';
import { View } from './view';

// Create singleton instance for application-wide use
export const globalUpdateBatcher = new UpdateBatcher({
  batchSize: 50,           // Process up to 50 UI updates per batch
  adaptiveThreshold: 10    // 10ms threshold for adaptive batching
});

// Re-export UpdateBatcher for custom instances
export { UpdateBatcher };

// Rendering API
export const queueUIUpdate = (
  componentId: string, 
  properties: Record<string, any>
): string => {
  return globalUpdateBatcher.queueUpdate(componentId, properties);
};

// Get pending update count
export const getPendingUpdateCount = (): number => {
  return globalUpdateBatcher.pendingUpdateCount;
};

// Clear all pending updates
export const clearPendingUpdates = (): void => {
  globalUpdateBatcher.clearPendingUpdates();
};

export {
  View
}; 