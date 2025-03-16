# Visualization API Reference

## Chart Component API

### `Chart` Class

The primary class for creating and managing chart visualizations.

```typescript
import { Chart, ChartOptions } from 'raxol';

const chart = new Chart(container, options);
```

#### Constructor

```typescript
constructor(container: HTMLElement, options: ChartOptions)
```

- **container**: HTML element where the chart will be rendered
- **options**: Configuration options for the chart

#### Methods

| Method | Description |
|--------|-------------|
| `updateData(newSeries: DataSeries[])` | Updates the chart with new series data |
| `updateOptions(newOptions: Partial<ChartOptions>)` | Updates chart configuration options |
| `getSeriesData()` | Returns a copy of the current series data |
| `getColors()` | Returns the current color scheme |
| `getAxisOptions(axisType: 'x' \| 'y')` | Returns axis configuration |
| `toDataURL(type?: string, quality?: number)` | Exports chart as data URL |
| `download(filename?: string, type?: string)` | Downloads chart as an image file |
| `destroy()` | Cleans up resources and removes the chart |

### `ChartOptions` Interface

Configuration options for creating a chart.

```typescript
interface ChartOptions {
  type: ChartType;
  width?: number;
  height?: number;
  title?: string;
  subtitle?: string;
  series: DataSeries[];
  xAxis?: AxisConfig;
  yAxis?: AxisConfig | AxisConfig[];
  legend?: LegendConfig;
  tooltip?: TooltipConfig;
  animation?: AnimationConfig;
  accessibility?: AccessibilityConfig;
  colors?: string[];
  backgroundColor?: string;
  margin?: {
    top?: number;
    right?: number;
    bottom?: number;
    left?: number;
  };
  events?: {
    load?: () => void;
    render?: () => void;
    seriesClick?: (series: DataSeries, index: number) => void;
    pointClick?: (point: DataPoint, series: DataSeries, indices: {seriesIndex: number, pointIndex: number}) => void;
  };
  plotOptions?: {
    [key in ChartType]?: any;
  };
}
```

### `ChartType` Type

Supported chart types.

```typescript
type ChartType = 
  | 'line' 
  | 'bar' 
  | 'area' 
  | 'pie' 
  | 'donut' 
  | 'scatter' 
  | 'bubble' 
  | 'radar' 
  | 'candlestick';
```

### `DataSeries` Interface

Represents a series of data points.

```typescript
interface DataSeries {
  name: string;
  data: DataPoint[];
  color?: string;
  visible?: boolean;
  type?: ChartType;
  yAxis?: number;
  stack?: string;
  [key: string]: any;
}
```

### `DataPoint` Interface

Represents a single data point.

```typescript
interface DataPoint {
  x: number | string;
  y: number;
  z?: number;
  label?: string;
  color?: string;
  [key: string]: any;
}
```

### Other Configuration Interfaces

- **`AxisConfig`**: Configuration for chart axes
- **`LegendConfig`**: Configuration for chart legend
- **`TooltipConfig`**: Configuration for tooltips
- **`AnimationConfig`**: Configuration for animations
- **`AccessibilityConfig`**: Configuration for accessibility features

## TreeMap Component API

### `TreeMap` Class

The primary class for creating and managing treemap visualizations.

```typescript
import { TreeMap, TreeMapOptions } from 'raxol';

const treeMap = new TreeMap(container, options);
```

#### Constructor

```typescript
constructor(container: HTMLElement, options: TreeMapOptions)
```

- **container**: HTML element where the treemap will be rendered
- **options**: Configuration options for the treemap

#### Methods

| Method | Description |
|--------|-------------|
| `updateData(root: TreeMapNode)` | Updates the treemap with new data |
| `updateOptions(options: Partial<TreeMapOptions>)` | Updates treemap configuration |
| `resize()` | Recalculates layout based on container size |
| `getColors()` | Returns the current color scheme |
| `getNodeById(id: string)` | Returns a node by its ID |
| `focusNode(id: string)` | Sets focus to a specific node |
| `destroy()` | Cleans up resources and removes the treemap |

### `TreeMapOptions` Interface

Configuration options for creating a treemap.

```typescript
interface TreeMapOptions {
  root: TreeMapNode;
  title?: string;
  colors?: string[];
  showLabels?: boolean;
  minLabelSize?: number;
  animationDuration?: number;
  padding?: number;
  tooltip?: {
    enabled: boolean;
    formatter?: (node: TreeMapNode) => string;
  };
  accessibility?: {
    description?: string;
    keyboardNavigation?: boolean;
  };
  events?: {
    nodeClick?: (node: TreeMapNode) => void;
    nodeHover?: (node: TreeMapNode | null) => void;
  };
}
```

### `TreeMapNode` Interface

Represents a node in the treemap hierarchy.

```typescript
interface TreeMapNode {
  id: string;
  name: string;
  value: number;
  color?: string;
  data?: any;
  children?: TreeMapNode[];
}
```

## Example Usage

### Basic Chart Example

```typescript
import { Chart, ChartOptions } from 'raxol';

const container = document.getElementById('chart-container');
const options: ChartOptions = {
  type: 'line',
  title: 'Monthly Sales',
  series: [{
    name: 'Sales',
    data: [
      { x: 'Jan', y: 42 },
      { x: 'Feb', y: 53 },
      { x: 'Mar', y: 61 },
      { x: 'Apr', y: 48 }
    ]
  }],
  accessibility: {
    description: 'Line chart showing monthly sales figures',
    keyboardNavigation: true
  }
};

const chart = new Chart(container, options);

// Update with new data later
const newData = [/* new data series */];
chart.updateData(newData);
```

### Basic TreeMap Example

```typescript
import { TreeMap, TreeMapOptions, TreeMapNode } from 'raxol';

// Create hierarchical data
const data: TreeMapNode = {
  id: 'root',
  name: 'Budget Allocation',
  value: 0,
  children: [
    {
      id: 'marketing',
      name: 'Marketing',
      value: 0,
      children: [
        { id: 'social', name: 'Social Media', value: 25 },
        { id: 'ads', name: 'Advertising', value: 35 },
        { id: 'events', name: 'Events', value: 15 }
      ]
    },
    {
      id: 'rd',
      name: 'R&D',
      value: 0,
      children: [
        { id: 'prototype', name: 'Prototyping', value: 30 },
        { id: 'testing', name: 'Testing', value: 20 }
      ]
    },
    { id: 'admin', name: 'Administration', value: 20 }
  ]
};

// Calculate parent values based on children
function calculateValues(node: TreeMapNode): number {
  if (!node.children || node.children.length === 0) {
    return node.value;
  }
  
  let sum = 0;
  for (const child of node.children) {
    sum += calculateValues(child);
  }
  
  node.value = sum;
  return sum;
}

calculateValues(data);

const container = document.getElementById('treemap-container');
const options: TreeMapOptions = {
  root: data,
  showLabels: true,
  padding: 2,
  tooltip: {
    enabled: true,
    formatter: (node) => `${node.name}: ${node.value}%`
  }
};

const treeMap = new TreeMap(container, options);
```

## Performance Integration

Both visualization components integrate with Raxol's performance tools:

```typescript
import { Chart, startPerformanceMark, endPerformanceMark } from 'raxol';

// Mark the start of chart creation
startPerformanceMark('chart-creation');

const chart = new Chart(container, options);

// Mark the end of chart creation
endPerformanceMark('chart-creation');
```

## Accessibility Best Practices

1. Always provide descriptive accessibility information:

```typescript
const options: ChartOptions = {
  // ...other options
  accessibility: {
    description: 'Bar chart showing quarterly revenue by product line from 2020 to 2022',
    keyboardNavigation: true,
    announceDataPoints: true
  }
};
```

2. Use semantic color schemes:

```typescript
const options: ChartOptions = {
  // ...other options
  colors: [
    '#4285F4', // Blue - Primary
    '#34A853', // Green - Positive
    '#FBBC05', // Yellow - Warning
    '#EA4335'  // Red - Negative
  ]
};
```

3. Ensure sufficient contrast:

```typescript
const options: ChartOptions = {
  // ...other options
  backgroundColor: '#ffffff',
  xAxis: {
    gridColor: '#e0e0e0',
    textColor: '#333333'
  }
};
``` 