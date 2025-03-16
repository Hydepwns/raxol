/**
 * Visualization Examples Index
 * 
 * This file exports all visualization examples for the Raxol framework.
 */

import { runChartExamples } from './ChartExample';
import { runTreeMapExamples } from './TreeMapExample';

/**
 * Runs all visualization examples with appropriate delays to prevent overlap
 */
export function runAllVisualizationExamples(): void {
  console.log("Starting visualization examples...");
  
  // Run chart examples immediately
  setTimeout(() => {
    console.log("Running Chart examples...");
    runChartExamples();
  }, 0);
  
  // Run tree map examples after a delay
  setTimeout(() => {
    console.log("Running TreeMap examples...");
    runTreeMapExamples();
  }, 5000);
  
  // Add other visualization examples here with appropriate delays
  
  console.log("All visualization examples scheduled.");
} 