/**
 * Memory Dashboard Example
 * 
 * This example demonstrates how to use the Memory Dashboard component
 * to visualize and monitor memory usage in applications.
 */

import {
  registerComponent,
  unregisterComponent,
  updateComponentSize,
  createMemoryDashboard
} from '../../core/performance';

interface SimulatedComponent {
  id: string;
  data: Array<Array<number>>;
  allocation: number;
}

/**
 * Run the memory dashboard example in a browser environment
 */
export function runMemoryDashboardExample(): void {
  console.log('Starting Memory Dashboard Example...');
  console.log('Note: This example requires a browser environment to display the dashboard.');
  
  // Check if we're in a browser environment
  if (typeof window === 'undefined' || typeof document === 'undefined') {
    console.error('Memory Dashboard Example requires a browser environment.');
    return;
  }
  
  // Create container for the dashboard
  const container = document.createElement('div');
  container.style.width = '100%';
  container.style.maxWidth = '800px';
  container.style.margin = '0 auto';
  
  // Add container to document
  document.body.appendChild(container);
  
  // Create title
  const title = document.createElement('h1');
  title.textContent = 'Memory Dashboard Example';
  title.style.textAlign = 'center';
  container.appendChild(title);
  
  // Create description
  const description = document.createElement('p');
  description.textContent = 'This dashboard shows real-time memory usage monitoring. The example will simulate multiple components allocating and releasing memory.';
  description.style.marginBottom = '20px';
  container.appendChild(description);
  
  // Create dashboard container
  const dashboardContainer = document.createElement('div');
  dashboardContainer.id = 'memory-dashboard-container';
  container.appendChild(dashboardContainer);
  
  // Create controls
  const controls = document.createElement('div');
  controls.style.marginTop = '20px';
  controls.style.display = 'flex';
  controls.style.justifyContent = 'center';
  controls.style.gap = '10px';
  container.appendChild(controls);
  
  // Add buttons
  const allocateButton = document.createElement('button');
  allocateButton.textContent = 'Allocate Memory';
  allocateButton.style.padding = '8px 16px';
  controls.appendChild(allocateButton);
  
  const releaseButton = document.createElement('button');
  releaseButton.textContent = 'Release Memory';
  releaseButton.style.padding = '8px 16px';
  controls.appendChild(releaseButton);
  
  // Create the memory dashboard
  const dashboard = createMemoryDashboard(dashboardContainer, {
    updateInterval: 1000, // Update every second
    maxDataPoints: 60,    // Show 1 minute of data
    warningThreshold: 20 * 1024 * 1024, // 20MB warning
    criticalThreshold: 50 * 1024 * 1024 // 50MB critical
  });
  
  // Simulated components and their data
  const components: SimulatedComponent[] = [
    { id: 'UserInterface', data: [], allocation: 500000 },   // ~500KB per allocation
    { id: 'DataStore', data: [], allocation: 1000000 },      // ~1MB per allocation
    { id: 'ImageProcessor', data: [], allocation: 2000000 }, // ~2MB per allocation
    { id: 'LogManager', data: [], allocation: 250000 }       // ~250KB per allocation
  ];
  
  // Register components with initial sizes
  components.forEach(component => {
    registerComponent(component.id, 10000); // Start with 10KB
  });
  
  // Function to allocate memory to components
  allocateButton.addEventListener('click', () => {
    components.forEach(component => {
      // Create a large array to simulate memory allocation
      const newData = new Array(Math.floor(component.allocation / 8)).fill(0);
      component.data.push(newData);
      
      // Update the component size estimation
      updateComponentSize(component.id, component.data.length * component.allocation);
    });
  });
  
  // Function to release memory from components
  releaseButton.addEventListener('click', () => {
    components.forEach(component => {
      // Remove half of the data arrays
      const halfLength = Math.floor(component.data.length / 2);
      if (halfLength > 0) {
        component.data.splice(0, halfLength);
        
        // Update the component size estimation
        updateComponentSize(component.id, component.data.length * component.allocation);
      }
    });
  });
  
  // Automatically allocate some memory to start with
  for (let i = 0; i < 3; i++) {
    setTimeout(() => {
      allocateButton.click();
    }, i * 2000);
  }
  
  console.log('Memory Dashboard Example initialized.');
  console.log('Use the "Allocate Memory" and "Release Memory" buttons to simulate memory usage changes.');
}

/**
 * Alternative implementation for non-browser environments
 */
export function runMemoryDashboardExampleConsole(): void {
  console.log('Memory Dashboard Example (Console Version)');
  console.log('Note: The full dashboard requires a browser environment.');
  
  // Create simulated components
  const components = [
    { id: 'UserInterface', allocation: 500000 },
    { id: 'DataStore', allocation: 1000000 },
    { id: 'ImageProcessor', allocation: 2000000 },
    { id: 'LogManager', allocation: 250000 }
  ];
  
  // Register components
  components.forEach(component => {
    registerComponent(component.id, component.allocation);
    console.log(`Registered component: ${component.id} with initial size ${formatBytes(component.allocation)}`);
  });
  
  // Take 5 snapshots with increasing memory usage
  for (let i = 1; i <= 5; i++) {
    // Increase memory usage for each component
    components.forEach(component => {
      const newSize = component.allocation * (i + 1);
      updateComponentSize(component.id, newSize);
    });
    
    console.log(`\nSnapshot ${i}:`);
    components.forEach(component => {
      const currentSize = component.allocation * (i + 1);
      console.log(`- ${component.id}: ${formatBytes(currentSize)}`);
    });
  }
  
  // Then decrease for the last 2 snapshots
  for (let i = 1; i <= 2; i++) {
    // Decrease memory usage for each component
    components.forEach(component => {
      const newSize = component.allocation * (6 - i);
      updateComponentSize(component.id, newSize);
    });
    
    console.log(`\nSnapshot ${i + 5}:`);
    components.forEach(component => {
      const currentSize = component.allocation * (6 - i);
      console.log(`- ${component.id}: ${formatBytes(currentSize)}`);
    });
  }
  
  console.log('\nMemory Dashboard Example (Console Version) complete.');
  console.log('For the full visual dashboard, please run this example in a browser environment.');
}

/**
 * Format bytes to a human-readable string
 */
function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 Bytes';
  
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

/**
 * Main function to run the appropriate example based on environment
 */
export function runMemoryDashboardExampleApp(): void {
  if (typeof window !== 'undefined' && typeof document !== 'undefined') {
    runMemoryDashboardExample();
  } else {
    runMemoryDashboardExampleConsole();
  }
} 