/**
 * Event Batching Example
 * 
 * This example demonstrates how to use the event batching and UI update
 * batching systems to improve performance in high-frequency UI interactions.
 */

import { queueEvent, queueHighPriorityEvent, getEventQueueLength } from '../../core/events';
import { queueUIUpdate, getPendingUpdateCount } from '../../core/renderer';

/**
 * Example: Handle a scroll event with batching
 */
export function handleScrollWithBatching(scrollPosition: number): void {
  // Queue a scroll event (low priority by default)
  queueEvent('scroll', { position: scrollPosition });
  
  // Log stats
  console.log(`Event queue length: ${getEventQueueLength()}`);
}

/**
 * Example: Handle user input with high priority
 */
export function handleUserInput(inputValue: string): void {
  // User input should be processed with high priority
  queueHighPriorityEvent('input', { value: inputValue });
}

/**
 * Example: Update multiple UI components efficiently
 */
export function updateUIComponents(
  data: { [componentId: string]: Record<string, any> }
): void {
  // Queue updates for each component
  Object.entries(data).forEach(([componentId, properties]) => {
    queueUIUpdate(componentId, properties);
  });
  
  // Log stats
  console.log(`Pending UI updates: ${getPendingUpdateCount()}`);
}

/**
 * Example: Simulate a high-frequency event (like window resize)
 */
export function simulateHighFrequencyEvent(): void {
  let count = 0;
  
  // Simulate events firing rapidly (e.g., during window resize)
  const interval = setInterval(() => {
    count++;
    
    // Queue the resize event
    queueEvent('resize', { width: 800 + count, height: 600 });
    
    // Update UI components based on the new size
    updateUIComponents({
      'header': { width: 800 + count },
      'main-content': { width: 800 + count, height: 600 - 80 },
      'footer': { width: 800 + count }
    });
    
    // Stop after 20 events
    if (count >= 20) {
      clearInterval(interval);
      console.log('High-frequency event simulation complete');
    }
  }, 50); // Events fire every 50ms (much faster than we'd want to update the UI)
}

/**
 * Run the complete example
 */
export function runEventBatchingExample(): void {
  console.log('Starting Event Batching Example...');
  
  // Simulate scrolling
  for (let i = 0; i < 10; i++) {
    setTimeout(() => {
      handleScrollWithBatching(i * 100);
    }, i * 100);
  }
  
  // Simulate user input
  setTimeout(() => {
    handleUserInput('Hello, world!');
  }, 500);
  
  // Simulate high-frequency events
  setTimeout(() => {
    simulateHighFrequencyEvent();
  }, 1000);
  
  // Log final stats after everything is processed
  setTimeout(() => {
    console.log(`Final event queue length: ${getEventQueueLength()}`);
    console.log(`Final pending UI updates: ${getPendingUpdateCount()}`);
    console.log('Event batching example complete');
  }, 3000);
} 