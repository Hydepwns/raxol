# Visualization Components

The Raxol framework includes powerful visualization components for data representation and analysis. These components are designed with accessibility, performance, and flexibility in mind.

## Chart Component

The `Chart` component (`src/components/visualization/Chart.ts`) provides diverse chart types for various data visualization needs.

### Supported Chart Types

- Line charts
- Bar charts
- Pie charts
- Area charts
- Scatter plots
- Bubble charts
- Radar charts
- Candlestick charts

### Key Features

- **Performance Optimized**: Efficiently renders large datasets with minimal jank
- **Accessibility**: Full keyboard navigation, ARIA attributes, and screen reader support
- **Customizable**: Extensive styling options, animations, and layout controls
- **Interactive**: Event handling for user interactions (click, hover, etc.)
- **Responsive**: Adapts to container size and orientation changes

### Usage Example

```typescript
const options: ChartOptions = {
  type: 'line',
  title: 'Monthly Temperature',
  series: [
    {
      name: 'Tokyo',
      data: [
        { x: 'Jan', y: 7 },
        { x: 'Feb', y: 8 },
        { x: 'Mar', y: 12 },
        // ...more data points
      ]
    }
  ],
  accessibility: {
    description: 'Line chart showing monthly temperatures for Tokyo'
  }
};

const chart = new Chart(container, options);
```

## TreeMap Component

The `TreeMap` component (`src/components/visualization/TreeMap.ts`) visualizes hierarchical data structures as nested rectangles.

### Key Features

- **Hierarchical Data**: Effectively represents parent-child relationships
- **Proportional Sizing**: Rectangle size corresponds to data value
- **Interactive**: Click and hover interactions with data nodes
- **Accessible**: Keyboard navigation and screen reader announcements
- **Customizable**: Colors, labels, padding, and animations

### Usage Example

```typescript
const options: TreeMapOptions = {
  root: {
    id: 'root',
    name: 'File System',
    value: 0,
    children: [
      {
        id: 'docs',
        name: 'Documents',
        value: 0,
        children: [
          { id: 'photos', name: 'Photos', value: 1200 },
          { id: 'work', name: 'Work Files', value: 600 }
        ]
      },
      { id: 'music', name: 'Music', value: 800 }
    ]
  },
  showLabels: true,
  padding: 2
};

const treeMap = new TreeMap(container, options);
```

## Integration with Performance Tools

Both visualization components integrate with Raxol's performance monitoring tools:

- Performance marks for tracking rendering time
- Memory usage monitoring
- Jank detection for identifying UI stutters
- FPS monitoring during animations

## Accessibility Considerations

Accessibility is a core feature of the visualization components:

1. **Keyboard Navigation**:
   - Tab navigation between chart elements
   - Arrow key navigation within data points
   - Enter/Space to activate elements

2. **Screen Reader Support**:
   - Descriptive ARIA labels
   - Announcements of data point values
   - Structural information about chart layout

3. **Visual Accessibility**:
   - High contrast mode support
   - Color blind friendly palettes
   - Text alternatives for visual information

## Demo Application

A comprehensive demo application showcases these components:

- Interactive chart examples with various configurations
- TreeMap examples with different data structures
- UI controls for modifying visualization properties
- Performance monitoring integration

The demo can be run using:

```javascript
import { runDemo } from './examples';
runDemo();
```

## Future Expansion

Planned enhancements for visualization components:

- Data explorer component with advanced filtering
- Dashboard layout system
- Additional specialized chart types
- Data-driven animation system
- Integration with AI for automatic insights
