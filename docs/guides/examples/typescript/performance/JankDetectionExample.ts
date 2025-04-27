/**
 * JankDetectionExample.ts
 * 
 * Demonstrates how to use the JankDetector and JankVisualizer
 * to monitor and analyze UI performance issues.
 */

import { 
  JankDetector, 
  JankVisualizer, 
  setJankContext, 
  addJankContext,
  clearJankContext,
  getJankReport
} from '../../core/performance';

// Function to create artificial jank for demonstration purposes
function createJank(duration: number): void {
  const start = performance.now();
  while (performance.now() - start < duration) {
    // Busy wait to simulate heavy computation
    Math.random() * Math.random() * Math.random();
  }
}

// Function to run different jank scenarios
async function runJankScenarios(): Promise<void> {
  console.log('Running jank detection example...');

  // Scenario 1: Light jank
  setJankContext({ scenario: 'Light Jank', action: 'Simulated' });
  console.log('Scenario 1: Light jank - 50ms (approximately 3 dropped frames at 60fps)');
  createJank(50);
  await new Promise(resolve => setTimeout(resolve, 1000));

  // Scenario 2: Moderate jank
  setJankContext({ scenario: 'Moderate Jank', action: 'Simulated' });
  console.log('Scenario 2: Moderate jank - 100ms (approximately 6 dropped frames at 60fps)');
  createJank(100);
  await new Promise(resolve => setTimeout(resolve, 1000));

  // Scenario 3: Severe jank
  setJankContext({ scenario: 'Severe Jank', action: 'Simulated' });
  console.log('Scenario 3: Severe jank - 200ms (approximately 12 dropped frames at 60fps)');
  createJank(200);
  await new Promise(resolve => setTimeout(resolve, 1000));

  // Scenario 4: Simulated heavy rendering
  console.log('Scenario 4: Simulated heavy rendering with multiple jank incidents');
  for (let i = 0; i < 5; i++) {
    addJankContext('renderIteration', i);
    addJankContext('renderComponent', `HeavyComponent-${i}`);
    
    const jankDuration = 30 + Math.random() * 120;
    createJank(jankDuration);
    await new Promise(resolve => setTimeout(resolve, 300));
  }
  
  clearJankContext();
  
  // Log the jank report
  const report = getJankReport();
  console.log('Jank Detection Report:');
  console.log(`- Average FPS: ${report.averageFps.toFixed(1)}`);
  console.log(`- Frame Success Rate: ${report.frameSuccessRate.toFixed(1)}%`);
  console.log(`- Jank Events: ${report.jankEventCount}`);
  console.log(`- 95th Percentile Frame Time: ${report.p95FrameTime.toFixed(2)}ms`);
}

// Main example app
export function runJankDetectionExampleApp(): void {
  // Create container for the visualizer
  const container = document.createElement('div');
  container.id = 'jank-visualizer-container';
  container.style.width = '800px';
  container.style.height = '500px';
  container.style.margin = '20px auto';
  container.style.border = '1px solid #ccc';
  container.style.borderRadius = '4px';
  container.style.overflow = 'hidden';
  
  // Add a title
  const title = document.createElement('h2');
  title.textContent = 'Raxol Jank Detection Example';
  title.style.textAlign = 'center';
  title.style.fontFamily = 'sans-serif';
  
  // Add a description
  const description = document.createElement('p');
  description.textContent = 'This example demonstrates the jank detection tools. The visualizer shows frame timings and jank events in real-time. Various jank scenarios will be simulated to demonstrate the detection capabilities.';
  description.style.margin = '0 auto 20px auto';
  description.style.maxWidth = '800px';
  description.style.textAlign = 'center';
  description.style.fontFamily = 'sans-serif';
  
  // Create control buttons
  const controlPanel = document.createElement('div');
  controlPanel.style.display = 'flex';
  controlPanel.style.justifyContent = 'center';
  controlPanel.style.margin = '10px auto';
  controlPanel.style.gap = '10px';
  
  const createJankButton = document.createElement('button');
  createJankButton.textContent = 'Create Jank (100ms)';
  createJankButton.onclick = () => createJank(100);
  
  const runScenariosButton = document.createElement('button');
  runScenariosButton.textContent = 'Run Jank Scenarios';
  runScenariosButton.onclick = () => runJankScenarios();
  
  controlPanel.appendChild(createJankButton);
  controlPanel.appendChild(runScenariosButton);
  
  // Add everything to the document
  document.body.appendChild(title);
  document.body.appendChild(description);
  document.body.appendChild(controlPanel);
  document.body.appendChild(container);
  
  // Create a custom jank detector with callback
  const jankDetector = new JankDetector({
    targetFps: 60,
    dropThreshold: 0.5,
    stutterThreshold: 2,
    analysisWindow: 5000,
    autoStart: true,
    onJankDetected: (event) => {
      console.log(`Jank detected: ${event.droppedFrames} frames dropped (${event.duration.toFixed(2)}ms) - ${event.severity}`);
      if (event.context && Object.keys(event.context).length > 0) {
        console.log('Context:', event.context);
      }
    }
  });
  
  // Create the visualizer
  const jankVisualizer = new JankVisualizer({
    container,
    jankDetector,
    updateInterval: 200,
    styles: {
      backgroundColor: '#2d2d2d',
      textColor: '#e0e0e0',
      gridColor: '#555555',
      frameBarColor: '#4CAF50',
      jankBarColors: {
        minor: '#FFC107',
        moderate: '#FF9800',
        severe: '#F44336'
      }
    }
  });
  
  // Start updates
  jankVisualizer.start();
  
  // Run the scenarios after a short delay
  setTimeout(() => {
    runJankScenarios();
  }, 1000);
} 