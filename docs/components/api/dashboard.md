---
title: Dashboard Layout API
description: Documentation for the Dashboard Layout system in Raxol Terminal Emulator
date: 2023-04-04
author: Raxol Team
section: api
tags: [api, dashboard, layout, documentation]
---

# Dashboard Layout API Reference

## Dashboard Container API

### `DashboardContainer` Class

The primary class for creating and managing dashboard layouts with widgets.

```typescript
import { DashboardContainer, DashboardContainerConfig } from "raxol";

const dashboard = new DashboardContainer(container, config);
```

#### Constructor

```typescript
constructor(container: HTMLElement, config: DashboardContainerConfig)
```

- **container**: HTML element where the dashboard will be rendered
- **config**: Configuration options for the dashboard

#### Methods

| Method                                                          | Description                                   |
| --------------------------------------------------------------- | --------------------------------------------- |
| `addWidget(widget: WidgetConfig)`                               | Adds a new widget to the dashboard            |
| `removeWidget(widgetId: string)`                                | Removes a widget from the dashboard           |
| `updateWidget(widgetId: string, config: Partial<WidgetConfig>)` | Updates a widget's configuration              |
| `getLayout()`                                                   | Returns the current dashboard layout          |
| `saveLayout(name?: string)`                                     | Saves the current layout to storage           |
| `loadLayout(name: string)`                                      | Loads a saved layout from storage             |
| `resetLayout()`                                                 | Resets to the default layout                  |
| `toggleEditMode()`                                              | Toggles dashboard edit mode                   |
| `destroy()`                                                     | Cleans up resources and removes the dashboard |

### `DashboardContainerConfig` Interface

Configuration options for creating a dashboard.

```typescript
interface DashboardContainerConfig {
  title: string;
  description?: string;
  widgets: Array<{
    type: WidgetType;
    config: Partial<WidgetConfig>;
    position: {
      row: number;
      column: number;
      rowSpan?: number;
      columnSpan?: number;
    };
  }>;
  layout: {
    rows: number;
    columns: number;
  };
  widgetFactoryConfig?: WidgetFactoryConfig;
  theme?: ThemeConfig;
  onRefresh?: () => void;
  onSave?: () => void;
  onReset?: () => void;
}
```

### `WidgetType` Type

Supported widget types.

```typescript
type WidgetType =
  | "chart"
  | "treemap"
  | "info"
  | "text"
  | "performance"
  | "custom";
```

### `WidgetConfig` Interface

Represents the configuration for a dashboard widget.

```typescript
interface WidgetConfig {
  id: string;
  title: string;
  content: any;
  position: { x: number; y: number };
  size: { width: number; height: number };
  isResizable: boolean;
  isDraggable: boolean;
  minSize?: { width: number; height: number };
  maxSize?: { width: number; height: number };
  theme?: Partial<ThemeConfig>;
  events?: {
    onResize?: (size: { width: number; height: number }) => void;
    onMove?: (position: { x: number; y: number }) => void;
    onClose?: () => void;
  };
}
```

## Layout Management API

### `LayoutConfig` Interface

Configuration for the dashboard grid layout.

```typescript
interface LayoutConfig {
  columns: number;
  gap: number;
  breakpoints?: {
    small: number;
    medium: number;
    large: number;
  };
}
```

### `DashboardConfig` Interface

Complete dashboard configuration with metadata.

```typescript
interface DashboardConfig {
  layout: LayoutConfig;
  widgets: WidgetConfig[];
  lastModified: string;
  name?: string;
  description?: string;
  thumbnail?: string;
}
```

### `ConfigurationManager` Class

Manages saving and loading dashboard configurations.

```typescript
import { ConfigurationManager } from "raxol";

const configManager = new ConfigurationManager();
```

#### Methods

| Method                                              | Description                                  |
| --------------------------------------------------- | -------------------------------------------- |
| `saveLayout(name: string, config: DashboardConfig)` | Saves a dashboard configuration to storage   |
| `loadLayout(name: string)`                          | Loads a dashboard configuration from storage |
| `getLayoutNames()`                                  | Returns names of all saved layouts           |
| `deleteLayout(name: string)`                        | Deletes a saved layout                       |

## Widget Components API

### Chart Widget

Widget that renders chart visualizations. Compatible with the Chart API.

```typescript
import { ChartWidget } from "raxol";

const chartWidget = ChartWidget.create({
  id: "sales-chart",
  title: "Sales Performance",
  chartType: "line",
  data: salesData,
  position: { x: 0, y: 0 },
  size: { width: 2, height: 1 },
});
```

### TreeMap Widget

Widget that renders TreeMap visualizations. Compatible with the TreeMap API.

```typescript
import { TreeMapWidget } from "raxol";

const treeMapWidget = TreeMapWidget.create({
  id: "product-categories",
  title: "Product Categories",
  data: categoryData,
  position: { x: 2, y: 0 },
  size: { width: 1, height: 1 },
});
```

### Info Widget

Widget that displays static information.

```typescript
import { InfoWidget } from "raxol";

const infoWidget = InfoWidget.create({
  id: "system-info",
  title: "System Information",
  content: {
    items: [
      { label: "CPU", value: "45%" },
      { label: "Memory", value: "1.2GB / 4GB" },
      { label: "Disk", value: "25GB / 100GB" },
    ],
  },
  position: { x: 0, y: 1 },
  size: { width: 1, height: 1 },
});
```

### Text Input Widget

Widget that provides text input functionality.

```typescript
import { TextInputWidget } from "raxol";

const textInputWidget = TextInputWidget.create({
  id: "command-input",
  title: "Command Input",
  placeholder: "Enter command...",
  onSubmit: (value) => {
    console.log("Command submitted:", value);
  },
  position: { x: 1, y: 1 },
  size: { width: 2, height: 1 },
});
```

## Theme System API

### `ThemeConfig` Interface

Configuration for the dashboard and widget theming system.

```typescript
interface ThemeConfig {
  colors: {
    primary: string;
    secondary: string;
    background: string;
    surface: string;
    text: string;
    textSecondary: string;
    border: string;
    accent: string;
    error: string;
    warning: string;
    success: string;
    info: string;
  };
  typography: {
    fontFamily: string;
    fontSize: string;
    fontWeightNormal: number;
    fontWeightBold: number;
    headingFontFamily?: string;
  };
  spacing: {
    small: number;
    medium: number;
    large: number;
  };
  border: {
    radius: string;
    width: string;
  };
  shadows: {
    small: string;
    medium: string;
    large: string;
  };
}
```

### `ThemeManager` Class

Manages themes for the dashboard system.

```typescript
import { ThemeManager, ThemeConfig } from "raxol";

const themeManager = new ThemeManager();
```

#### Methods

| Method                                             | Description                        |
| -------------------------------------------------- | ---------------------------------- |
| `getTheme(name: string)`                           | Returns a theme by name            |
| `getCurrentTheme()`                                | Returns the currently active theme |
| `setTheme(name: string)`                           | Sets the active theme              |
| `registerTheme(name: string, config: ThemeConfig)` | Registers a custom theme           |
| `getDarkTheme()`                                   | Returns the built-in dark theme    |
| `getLightTheme()`                                  | Returns the built-in light theme   |

### Built-in Themes

The theme system provides two built-in themes:

1. **Light Theme** - Default light color scheme
2. **Dark Theme** - Default dark color scheme

### Example Theme Usage

```typescript
import { DashboardContainer, ThemeManager } from "raxol";

// Get theme manager instance
const themeManager = new ThemeManager();

// Register a custom theme
themeManager.registerTheme("corporate", {
  colors: {
    primary: "#003366",
    secondary: "#6699cc",
    background: "#f5f5f5",
    surface: "#ffffff",
    text: "#333333",
    textSecondary: "#666666",
    border: "#dddddd",
    accent: "#ff9900",
    error: "#cc0000",
    warning: "#ff9900",
    success: "#009900",
    info: "#0099cc",
  },
  typography: {
    fontFamily: "Arial, sans-serif",
    fontSize: "14px",
    fontWeightNormal: 400,
    fontWeightBold: 700,
    headingFontFamily: "Georgia, serif",
  },
  spacing: {
    small: 4,
    medium: 8,
    large: 16,
  },
  border: {
    radius: "4px",
    width: "1px",
  },
  shadows: {
    small: "0 1px 2px rgba(0,0,0,0.1)",
    medium: "0 2px 4px rgba(0,0,0,0.1)",
    large: "0 4px 8px rgba(0,0,0,0.1)",
  },
});

// Apply theme to dashboard
const dashboard = new DashboardContainer(container, {
  // other config...
  theme: themeManager.getTheme("corporate"),
});

// Set theme for all dashboards
themeManager.setTheme("dark");

// Apply theme to a specific widget only
dashboard.updateWidget("widget-id", {
  theme: {
    colors: {
      background: "#f0f8ff",
      border: "#4682b4",
    },
  },
});
```

### Elixir Theme Example

```elixir
alias Raxol.Components.Dashboard.ThemeManager

# Register a custom theme
ThemeManager.register_theme(:high_contrast, %{
  colors: %{
    primary: "#ffffff",
    secondary: "#dddddd",
    background: "#000000",
    text: "#ffffff",
    # other color values...
  },
  # other theme properties...
})

# Apply theme to dashboard
{:ok, dashboard} = Dashboard.init([
  # widgets...
], %{
  # other config...
  theme: :high_contrast
})

# Get theme by name
theme = ThemeManager.get_theme(:dark)
```

## Dashboard Templates API

### `DashboardTemplates` Class

Provides predefined dashboard templates.

```typescript
import { DashboardTemplates } from "raxol";

const templates = new DashboardTemplates().getDefaultTemplates();
```

#### Methods

| Method                             | Description                       |
| ---------------------------------- | --------------------------------- |
| `getDefaultTemplates()`            | Returns the default templates     |
| `getTemplate(id: string)`          | Returns a specific template by ID |
| `saveTemplate(template: Template)` | Saves a custom template           |
| `deleteTemplate(id: string)`       | Deletes a custom template         |

### `Template` Interface

Represents a dashboard template.

```typescript
interface Template {
  id: string;
  name: string;
  description: string;
  config: DashboardConfig;
  thumbnail?: string;
}
```

## Example Usage

### Basic Dashboard Example

```typescript
import { DashboardContainer, ChartWidget, TreeMapWidget } from "raxol";

const container = document.getElementById("dashboard-container");
const config = {
  title: "Performance Dashboard",
  description: "System performance metrics",
  layout: {
    rows: 2,
    columns: 3,
  },
  widgets: [
    {
      type: "chart",
      config: {
        id: "cpu-usage",
        title: "CPU Usage",
        chartType: "line",
        data: cpuData,
      },
      position: {
        row: 0,
        column: 0,
        rowSpan: 1,
        columnSpan: 2,
      },
    },
    {
      type: "treemap",
      config: {
        id: "memory-usage",
        title: "Memory Usage",
        data: memoryData,
      },
      position: {
        row: 0,
        column: 2,
        rowSpan: 1,
        columnSpan: 1,
      },
    },
  ],
};

const dashboard = new DashboardContainer(container, config);

// Save the current layout
dashboard.saveLayout("performance-dashboard");

// Load a saved layout
dashboard.loadLayout("performance-dashboard");
```

### Elixir API Example

```elixir
alias Raxol.Components.Dashboard.Dashboard
alias Raxol.Components.Dashboard.Widgets.ChartWidget
alias Raxol.Components.Dashboard.Widgets.TreeMapWidget

# Initialize a dashboard with widgets
{:ok, dashboard} = Dashboard.init([
  %{
    id: "cpu-chart",
    type: :chart,
    title: "CPU Usage",
    grid_spec: %{x: 0, y: 0, w: 2, h: 1}
  },
  %{
    id: "memory-treemap",
    type: :treemap,
    title: "Memory Usage",
    grid_spec: %{x: 2, y: 0, w: 1, h: 1}
  }
], %{
  parent_bounds: %{width: 80, height: 30},
  cols: 3,
  rows: 2,
  gap: 1
})

# Save layout to file
Dashboard.save_layout(dashboard)

# Load layout from file
{:ok, loaded_dashboard} = Dashboard.load_layout()
```
