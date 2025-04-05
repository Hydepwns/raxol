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
   const activeSections = Array.isArray(activeSection) ? activeSection : [activeSection];
   
   // Correct
   const activeSections = Array.isArray(activeSection) 
     ? activeSection 
     : activeSection ? [activeSection] : [];
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
   e.dataTransfer?.setData('text/plain', index.toString());
   
   // Correct
   if (e.dataTransfer) {
     e.dataTransfer.setData('text/plain', index.toString());
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
   performance.recordComponentCreate('box', 5);
   
   // Correct
   performance.startMonitoring();
   performance.recordComponentCreate('box', 5);
   // ... record other metrics
   performance.stopMonitoring();
   ```

3. **Ensure proper recording of component operation metrics**:
   ```typescript
   // Incorrect
   performance.recordComponentOperation('render', 15);
   
   // Correct
   performance.recordComponentOperation('render', 15, 'box');
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
   // The ViewPerformance class already handles this internally
   // But you can check manually if needed
   if (isPerformanceMemoryAPIAvailable()) {
     // Use the memory API
   } else {
     // Skip memory metrics
   }
   ```

### Performance Metrics Calculation Issues

If you encounter issues with performance metrics calculation, check the following:

1. **Ensure proper calculation of rendering metrics**:
   ```typescript
   // The ViewPerformance class already handles this internally
   // But you can check the implementation if needed
   const componentMetrics = performance.getAllComponentMetrics();
   const totalCreateTime = componentMetrics.reduce((sum, m) => sum + m.createTime, 0);
   const totalRenderTime = componentMetrics.reduce((sum, m) => sum + m.renderTime, 0);
   const totalUpdateTime = componentMetrics.reduce((sum, m) => sum + (m.updateCount * 5), 0);
   ```

2. **Ensure proper handling of timing metrics**:
   ```typescript
   // The ViewPerformance class already handles this internally
   // But you can check the implementation if needed
   const timing = performanceAPI.timing;
   const now = performanceAPI.now();
   
   // Provide default values for potentially undefined timing properties
   return {
     navigationStart: timing.navigationStart || now,
     // ... other timing properties
   };
   ```

### Performance Dashboard Issues

If you encounter issues with the performance dashboard, check the following:

1. **Ensure proper display of component metrics**:
   ```typescript
   // Example of displaying component metrics
   const componentMetrics = performance.getAllComponentMetrics();
   
   return View.box({
     children: componentMetrics.map(metric => 
       View.box({
         children: [
           View.text(`Component Type: ${metric.type}`),
           View.text(`Create Time: ${metric.createTime}ms`),
           View.text(`Render Time: ${metric.renderTime}ms`),
           View.text(`Update Count: ${metric.updateCount}`),
           View.text(`Child Count: ${metric.childCount}`)
         ]
       })
     )
   });
   ```

2. **Ensure proper display of operation metrics**:
   ```typescript
   // Example of displaying operation metrics
   const operationMetrics = performance.getAllOperationMetrics();
   
   return View.box({
     children: operationMetrics.map(metric => 
       View.box({
         children: [
           View.text(`Operation: ${metric.operation}`),
           View.text(`Time: ${metric.operationTime}ms`),
           View.text(`Component: ${metric.componentType || 'N/A'}`),
           View.text(`Timestamp: ${new Date(metric.timestamp).toLocaleTimeString()}`)
         ]
       })
     )
   });
   ```

## Common Error Messages and Solutions

### Type Errors

1. **"Type 'string' is not assignable to type 'ComponentType'"**:
   - Solution: Use proper type assertion for component types: `type: 'div' as ComponentType`

2. **"Type 'string' is not assignable to type 'DisplayType'"**:
   - Solution: Use proper type assertion for display types: `display: 'flex' as DisplayType`

3. **"Type 'string' is not assignable to type 'PositionType'"**:
   - Solution: Use proper type assertion for position types: `position: 'absolute' as PositionType`

4. **"Type 'string' is not assignable to type 'BorderStyle'"**:
   - Solution: Use proper type assertion for border styles: `border: '1px solid #ddd' as BorderStyle`

### Performance Monitoring Errors

1. **"Cannot read property 'now' of undefined"**:
   - Solution: Ensure the Performance API is available or use the fallback: `const performanceAPI = isPerformanceAPIAvailable() ? (performance as ExtendedPerformance) : createPerformanceFallback();`

2. **"Cannot read property 'memory' of undefined"**:
   - Solution: Check if the memory API is available before accessing it: `if (isPerformanceMemoryAPIAvailable()) { /* use memory API */ }`

3. **"Component metrics not found"**:
   - Solution: Ensure you've started monitoring before recording metrics: `performance.startMonitoring();`

4. **"Operation metrics not found"**:
   - Solution: Ensure you've recorded operation metrics before trying to retrieve them: `performance.recordComponentOperation('render', 15, 'box');`

## Best Practices

1. **Always use proper type assertions for component types and style properties**:
   ```typescript
   type: 'div' as ComponentType,
   display: 'flex' as DisplayType,
   position: 'absolute' as PositionType,
   border: '1px solid #ddd' as BorderStyle,
   ```

2. **Always start and stop performance monitoring**:
   ```typescript
   performance.startMonitoring();
   // ... record metrics
   performance.stopMonitoring();
   ```

3. **Always include component type when recording operation metrics**:
   ```typescript
   performance.recordComponentOperation('render', 15, 'box');
   ```

4. **Always check for API availability before using browser-specific APIs**:
   ```typescript
   if (isPerformanceAPIAvailable()) {
     // Use the real Performance API
   } else {
     // Use the fallback
   }
   ```

5. **Always provide default values for potentially undefined properties**:
   ```typescript
   const value = property || defaultValue;
   ```

6. **Always use proper error handling for event handlers**:
   ```typescript
   onError: (error: Error) => {
     console.error('Error:', error);
     // Handle error appropriately
   },
   ```

7. **Always use proper type assertions for array operations**:
   ```typescript
   const activeSections = Array.isArray(activeSection) 
     ? activeSection 
     : activeSection ? [activeSection] : [];
   ```

8. **Always use proper type assertions for conditional rendering**:
   ```typescript
   display: isActive ? 'block' as DisplayType : 'none' as DisplayType,
   ```

9. **Always use proper type assertions for flex properties**:
   ```typescript
   justifyContent: 'space-between' as JustifyContent,
   alignItems: 'center' as AlignItems,
   ```

10. **Always use proper type assertions for overflow and textAlign properties**:
    ```typescript
    overflow: 'hidden' as const,
    textAlign: 'left' as const,
    ```

## Performance Issues

### Slow Component Rendering

If you're experiencing slow component rendering, try the following:

1. **Use virtualization for large lists**:
   ```typescript
   // Instead of rendering all items
   const items = View.list({ items: allItems });
   
   // Use virtualization
   const items = View.virtualList({
     items: allItems,
     itemHeight: 50,
     containerHeight: 400,
     overscan: 5
   });
   ```

2. **Optimize component updates**:
   ```typescript
   // Instead of updating components individually
   items.forEach(item => updateItem(item));
   
   // Batch updates
   View.batchUpdates([
     () => updateItem(items[0]),
     () => updateItem(items[1]),
     // ...
   ]);
   ```

3. **Use debouncing for frequent updates**:
   ```typescript
   // Instead of updating on every change
   input.onChange = () => updateValue(input.value);
   
   // Debounce updates
   View.debounceRender(() => updateValue(input.value), 300);
   ```

### High Memory Usage

If you're experiencing high memory usage, try the following:

1. **Monitor memory usage**:
   ```typescript
   // Start monitoring
   viewPerformance.startMonitoring();
   
   // Periodically check memory usage
   setInterval(() => {
     const metrics = viewPerformance.getMetrics();
     if (metrics.memory) {
       console.log(`Memory usage: ${metrics.memory.usedJSHeapSize / 1024 / 1024}MB`);
     }
   }, 60000); // Check every minute
   ```

2. **Use lazy loading for images and heavy components**:
   ```typescript
   // Instead of loading all images at once
   const images = items.map(item => View.image({ src: item.imageUrl }));
   
   // Use lazy loading
   const images = items.map(item => View.lazyLoad({
     src: item.imageUrl,
     placeholder: View.text('Loading...'),
     threshold: 0.5
   }));
   ```

3. **Clean up resources when components are unmounted**:
   ```typescript
   // Add cleanup logic to component lifecycle
   const component = View.box({
     lifecycle: {
       onUnmount: () => {
         // Clean up resources
         clearInterval(interval);
         removeEventListener('resize', handleResize);
       }
     }
   });
   ```

## Testing Issues

### Component Testing

If you're having issues testing components, try the following:

1. **Mock the performance API**:
   ```typescript
   // Mock performance API
   const mockPerformance = {
     now: jest.fn().mockReturnValue(0),
     timing: {
       navigationStart: 0,
       // ...
     }
   };
   
   // Mock global performance object
   global.performance = mockPerformance as any;
   ```

2. **Test component metrics**:
   ```typescript
   // Start monitoring
   viewPerformance.startMonitoring();
   
   // Create component
   const component = View.box();
   
   // Record metrics
   viewPerformance.recordComponentCreate('box', 10);
   viewPerformance.recordComponentRender('box', 20, 0);
   
   // Get metrics
   const metrics = viewPerformance.getComponentMetrics('box');
   
   // Assert metrics
   expect(metrics).toBeDefined();
   expect(metrics?.createTime).toBe(10);
   expect(metrics?.renderTime).toBe(20);
   ```

3. **Test operation metrics**:
   ```typescript
   // Start monitoring
   viewPerformance.startMonitoring();
   
   // Record operation metrics
   viewPerformance.recordComponentOperation('render', 25, 'box');
   
   // Get operation metrics
   const operationMetrics = viewPerformance.getAllOperationMetrics();
   
   // Assert operation metrics
   expect(operationMetrics).toHaveLength(1);
   expect(operationMetrics[0].operation).toBe('render');
   expect(operationMetrics[0].operationTime).toBe(25);
   expect(operationMetrics[0].componentType).toBe('box');
   ```

## Conclusion

If you're still experiencing issues after trying the solutions in this guide, please contact the Raxol support team or check the [GitHub repository](https://github.com/raxol/raxol) for more information. 