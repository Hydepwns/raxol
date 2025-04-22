---
title: Troubleshooting Guide
description: Solutions for common issues with the Raxol Terminal Emulator
---

# Troubleshooting Guide

This guide provides solutions for common issues you might encounter when working with the Raxol Terminal Emulator, particularly with the View system and performance monitoring.

## View System Issues

### Type Errors in Component Options

If you encounter type errors when using component options, check the following:

1. **Ensure proper typing for event handlers**:

   ```typescript
   // Incorrect
   onDragStart?: (item: any, index: number) => void;

   // Correct
   onDragStart?: (item: ViewElement, index: number) => void;
   ```

2. **Use proper type assertions for component types**:

   ```typescript
   // Incorrect
   type: 'flex',

   // Correct
   type: 'flex' as ComponentType,
   ```

3. **Use proper type assertions for style properties**:

   ```typescript
   // Incorrect
   display: 'flex',

   // Correct
   display: 'flex' as DisplayType,
   ```

### Component Composition Issues

If you encounter issues with component composition, check the following:

1. **Ensure proper typing for flex properties**:

   ```typescript
   // Incorrect
   style: {
     flex: {
       direction: 'row',
       justify: 'center',
       align: 'center'
     }
   }

   // Correct
   style: {
     flex: {
       direction: 'row' as FlexDirection,
       justify: 'center' as JustifyContent,
       align: 'center' as AlignItems
     }
   }
   ```

2. **Use proper type assertions for position properties**:

   ```typescript
   // Incorrect
   position: 'absolute',

   // Correct
   position: 'absolute' as PositionType,
   ```

3. **Use proper type assertions for border styles**:

   ```typescript
   // Incorrect
   border: '1px solid #ddd',

   // Correct
   border: '1px solid #ddd' as BorderStyle,
   ```

### Advanced Component Issues

#### Modal Component Issues

If you encounter issues with the Modal component, check the following:

1. **Ensure proper typing for the content property**:

   ```typescript
   // Incorrect
   content: 'Modal content',

   // Correct
   content: View.text('Modal content'),
   ```

2. **Ensure proper typing for the onClose handler**:

   ```typescript
   // Incorrect
   onClose: () => console.log('Modal closed'),

   // Correct
   onClose: () => {
     console.log('Modal closed');
     setIsModalOpen(false);
   },
   ```

#### Accordion Component Issues

If you encounter issues with the Accordion component, check the following:

1. **Ensure proper handling of single and multiple section cases**:

   ```typescript
   // Incorrect
   const activeSections = Array.isArray(activeSection)
     ? activeSection
     : [activeSection];

   // Correct
   const activeSections = Array.isArray(activeSection)
     ? activeSection
     : activeSection
     ? [activeSection]
     : [];
   ```

2. **Ensure proper typing for the onChange handler**:

   ```typescript
   // Incorrect
   onChange: (sectionId: string) => {
     setActiveSection(sectionId);
   },

   // Correct
   onChange: (sectionId: string | string[]) => {
     setActiveSection(sectionId);
   },
   ```

#### LazyLoad Component Issues

If you encounter issues with the LazyLoad component, check the following:

1. **Ensure proper typing for the onError handler**:

   ```typescript
   // Incorrect
   onError: (error) => {
     console.error('Error loading image:', error);
   },

   // Correct
   onError: (error: Error) => {
     console.error('Error loading image:', error);
   },
   ```

2. **Ensure proper handling of the dataTransfer property**:

   ```typescript
   // Incorrect
   e.dataTransfer?.setData("text/plain", index.toString());

   // Correct
   if (e.dataTransfer) {
     e.dataTransfer.setData("text/plain", index.toString());
   }
   ```

#### DragAndDrop Component Issues

If you encounter issues with the DragAndDrop component, check the following:

1. **Ensure proper typing for the onDragStart handler**:

   ```typescript
   // Incorrect
   onDragStart: (e: DragEvent) => {
     e.dataTransfer?.setData('text/plain', index.toString());
     onDragStart?.(item, index);
   },

   // Correct
   onDragStart: (e: DragEvent) => {
     if (e.dataTransfer) {
       e.dataTransfer.setData('text/plain', index.toString());
     }
     onDragStart?.(item, index);
   },
   ```

2. **Ensure proper typing for the border style**:

   ```typescript
   // Incorrect
   border: '1px solid #ddd',

   // Correct
   border: '1px solid #ddd' as BorderStyle,
   ```

## Performance Monitoring Issues

### Component Operation Metrics Issues

If you encounter issues with component operation metrics, check the following:

1. **Ensure proper initialization of the ViewPerformance instance**:

   ```typescript
   // Incorrect
   const performance = new ViewPerformance();

   // Correct
   const performance = ViewPerformance.getInstance();
   ```

2. **Ensure proper start and stop of monitoring**:

   ```typescript
   // Incorrect
   performance.recordComponentCreate("box", 5);

   // Correct
   performance.startMonitoring();
   performance.recordComponentCreate("box", 5);
   // ... record other metrics
   performance.stopMonitoring();
   ```

3. **Ensure proper recording of component operation metrics**:

   ```typescript
   // Incorrect
   performance.recordComponentOperation("render", 15);

   // Correct
   performance.recordComponentOperation("render", 15, "box");
   ```

### Performance API Availability Issues

If you encounter issues with the Performance API, check the following:

1. **Ensure proper fallback for unsupported browsers**:

   ```typescript
   // The ViewPerformance class already handles this internally
   // But you can check manually if needed
   if (isPerformanceAPIAvailable()) {
     // Use the real Performance API
   } else {
     // Use the fallback
   }
   ```

2. **Ensure proper handling of memory API availability**:

   ```typescript
   // Incorrect
   if (performance.memory) {
     // Access memory information
   }

   // Correct
   if (isPerformanceMemoryAPIAvailable()) {
     // Access memory information
   }
   ```

### Performance Metrics Reporting Issues

If you encounter issues with reporting performance metrics, check the following:

1. **Ensure proper aggregation of metrics**:

   ```typescript
   // Incorrect
   const metrics = performance.getMetrics();

   // Correct
   const metrics = performance.getAggregatedMetrics();
   ```

2. **Ensure proper serialization of metrics**:

   ```typescript
   // Incorrect
   const jsonMetrics = JSON.stringify(metrics);

   // Correct
   const jsonMetrics = serializeMetrics(metrics);
   ```

3. **Ensure proper clearing of metrics**:

   ```typescript
   // Incorrect
   performance.clearMetrics();

   // Correct
   performance.stopMonitoring(); // Ensure monitoring is stopped before clearing
   performance.clearMetrics();
   ```

## Visualization Issues

### Graph Visualization Issues

If you encounter issues with graph visualizations, check the following:

1. **Ensure proper type assertion for graph types**:

   ```typescript
   // Incorrect
   type: 'bar',

   // Correct
   type: 'bar' as GraphType,
   ```

2. **Ensure proper handling of graph data**:

   ```typescript
   // Incorrect
   data: [10, 20, 30],

   // Correct
   data: [
     { label: 'A', value: 10 },
     { label: 'B', value: 20 },
     { label: 'C', value: 30 },
   ],
   ```

3. **Ensure proper type assertion for color scales**:

   ```typescript
   // Incorrect
   colorScale: 'category10',

   // Correct
   colorScale: 'category10' as ColorScale,
   ```

### Tree Visualization Issues

If you encounter issues with tree visualizations, check the following:

1. **Ensure proper typing for tree node data**:

   ```typescript
   // Incorrect
   data: {
     name: 'Root',
     children: [
       { name: 'Child 1' },
       { name: 'Child 2' },
     ],
   },

   // Correct
   data: {
     name: 'Root',
     children: [
       { name: 'Child 1' as TreeNodeName },
       { name: 'Child 2' as TreeNodeName },
     ],
   } as TreeNode,
   ```

2. **Ensure proper handling of tree layout options**:

   ```typescript
   // Incorrect
   layout: {
     orientation: 'vertical',
     nodeSize: [100, 50],
   },

   // Correct
   layout: {
     orientation: 'vertical' as TreeOrientation,
     nodeSize: [100, 50],
   },
   ```

3. **Ensure proper typing for tree link styles**:

   ```typescript
   // Incorrect
   linkStyle: {
     stroke: '#ccc',
     strokeWidth: 1,
   },

   // Correct
   linkStyle: {
     stroke: '#ccc',
     strokeWidth: 1,
   } as LinkStyle,
   ```

## Animation Issues

### Basic Animation Issues

If you encounter issues with basic animations, check the following:

1. **Ensure proper typing for animation types**:

   ```typescript
   // Incorrect
   type: 'fade',

   // Correct
   type: 'fade' as AnimationType,
   ```

2. **Ensure proper handling of animation duration and easing**:

   ```typescript
   // Incorrect
   duration: 500,
   easing: 'linear',

   // Correct
   duration: 500,
   easing: 'linear' as EasingFunction,
   ```

3. **Ensure proper coordination with component lifecycle**:
   ```typescript
   // Ensure animations are triggered at the right time
   // (e.g., after component mount or state change)
   ```

### Complex Animation Issues

If you encounter issues with complex animations, check the following:

1. **Ensure proper handling of animation sequences and delays**:

   ```typescript
   // Incorrect
   sequence: [
     { type: 'fade', duration: 500 },
     { type: 'slide', duration: 500 },
   ],

   // Correct
   sequence: [
     { type: 'fade' as AnimationType, duration: 500 },
     { type: 'slide' as AnimationType, duration: 500, delay: 500 },
   ],
   ```

2. **Ensure proper handling of animation chaining and callbacks**:

   ```typescript
   // Use onAnimationEnd callbacks to chain animations
   onAnimationEnd: () => {
     // Start next animation
   },
   ```

3. **Ensure proper performance optimization for animations**:
   ```typescript
   // Use requestAnimationFrame for smooth animations
   // Avoid triggering too many re-renders during animations
   ```

## Testing and Debugging Issues

### Test Setup Issues

If you encounter issues with test setup, check the following:

1. **Ensure proper mocking of browser APIs (if needed)**:

   ```typescript
   // Use libraries like jest-canvas-mock for canvas testing
   // Mock Performance API if needed
   ```

2. **Ensure proper setup of testing environment (e.g., JSDOM)**:

   ```typescript
   // Configure Jest or other test runner with JSDOM
   ```

3. **Ensure proper isolation of components in tests**:
   ```typescript
   // Use testing libraries like @testing-library/react for component testing
   ```

### Debugging Performance Issues

If you encounter issues with debugging performance, check the following:

1. **Use browser developer tools for performance profiling**:

   ```
   // Use Chrome DevTools Performance tab or Firefox Profiler
   ```

2. **Use the ViewPerformance class for detailed metrics**:

   ```typescript
   // Get aggregated metrics
   const metrics = ViewPerformance.getInstance().getAggregatedMetrics();
   console.log("Performance Metrics:", metrics);
   ```

3. **Use logging and breakpoints for debugging specific operations**:
   ```typescript
   // Add console.log statements or breakpoints in performance-critical code
   ```

## State Management Issues

### State Update Issues

If you encounter issues with state updates, check the following:

1. **Ensure proper use of immutable updates**:

   ```typescript
   // Incorrect (mutating state)
   state.items.push(newItem);

   // Correct (creating new state)
   setState({ ...state, items: [...state.items, newItem] });
   ```

2. **Ensure proper handling of asynchronous state updates**:

   ```typescript
   // Use async/await or Promises for asynchronous operations
   // Update state only after asynchronous operation completes
   ```

3. **Ensure proper scoping and closure behavior**:
   ```typescript
   // Be mindful of closures when updating state in callbacks
   // Use functional updates if needed: setState(prevState => ...)
   ```

### State Synchronization Issues

If you encounter issues with state synchronization, check the following:

1. **Ensure proper lifting of state up to common ancestors**:

   ```typescript
   // If multiple components need the same state, lift it up
   ```

2. **Use context or state management libraries for global state**:

   ```typescript
   // Use React Context, Redux, Zustand, etc. for managing shared state
   ```

3. **Ensure proper handling of props drilling vs. context**:
   ```typescript
   // Avoid excessive props drilling by using context where appropriate
   ```

---

_This guide provides solutions for common issues. If you encounter an issue not listed here, please refer to the main documentation or seek help from the community._
