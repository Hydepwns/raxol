/**
 * Dashboard Component Types
 * 
 * Type definitions for dashboard layout, widgets, and configuration.
 */

// Base widget interface
export interface WidgetConfig {
  id: string;
  type: string;
  title: string;
  position: {
    x: number;
    y: number;
    width: number;
    height: number;
  };
  data?: any;
  options?: Record<string, any>;
  style?: Record<string, any>;
  metadata?: Record<string, any>;
}

// Layout configuration
export interface LayoutConfig {
  columns: number;
  rows: number;
  gap?: number;
  padding?: number;
  responsive?: boolean;
  breakpoints?: {
    mobile?: number;
    tablet?: number;
    desktop?: number;
  };
}

// Dashboard configuration
export interface DashboardConfig {
  id: string;
  title: string;
  layout: LayoutConfig;
  widgets: WidgetConfig[];
  theme?: 'light' | 'dark' | 'custom';
  autoRefresh?: {
    enabled: boolean;
    interval: number; // in milliseconds
  };
  permissions?: {
    canEdit: boolean;
    canDelete: boolean;
    canShare: boolean;
  };
}

// Widget data source
export interface DataSource {
  id: string;
  type: 'static' | 'api' | 'websocket' | 'polling';
  url?: string;
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE';
  headers?: Record<string, string>;
  params?: Record<string, any>;
  refreshInterval?: number;
  transformData?: (data: any) => any;
}

// Widget state
export interface WidgetState {
  loading: boolean;
  error?: string;
  data?: any;
  lastUpdated?: Date;
  isMinimized: boolean;
  isMaximized: boolean;
}

// Dashboard events
export interface DashboardEvents {
  onWidgetAdd?: (widget: WidgetConfig) => void;
  onWidgetRemove?: (widgetId: string) => void;
  onWidgetMove?: (widgetId: string, newPosition: WidgetConfig['position']) => void;
  onWidgetResize?: (widgetId: string, newSize: { width: number; height: number }) => void;
  onWidgetClick?: (widgetId: string, widget: WidgetConfig) => void;
  onWidgetDataUpdate?: (widgetId: string, data: any) => void;
  onLayoutChange?: (newLayout: LayoutConfig) => void;
  onDashboardSave?: (dashboard: DashboardConfig) => void;
}

// Grid system types
export interface GridPosition {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface GridCell {
  occupied: boolean;
  widgetId?: string;
}

export interface GridSystem {
  columns: number;
  rows: number;
  cells: GridCell[][];
  gap: number;
  cellWidth: number;
  cellHeight: number;
}

// Responsive breakpoints
export interface ResponsiveBreakpoint {
  name: string;
  minWidth: number;
  maxWidth?: number;
  columns: number;
  gap?: number;
}

// Widget resize handle positions
export type ResizeHandle = 'n' | 'ne' | 'e' | 'se' | 's' | 'sw' | 'w' | 'nw';

// Widget drag and drop
export interface DragState {
  isDragging: boolean;
  draggedWidget?: WidgetConfig;
  dragOffset?: { x: number; y: number };
  dropTarget?: { x: number; y: number };
}

export interface DropZone {
  x: number;
  y: number;
  width: number;
  height: number;
  valid: boolean;
  occupied: boolean;
}

// Theme configuration
export interface DashboardTheme {
  name: string;
  colors: {
    primary: string;
    secondary: string;
    background: string;
    surface: string;
    text: string;
    border: string;
    success: string;
    warning: string;
    error: string;
  };
  fonts: {
    primary: string;
    secondary: string;
    mono: string;
  };
  spacing: {
    xs: number;
    sm: number;
    md: number;
    lg: number;
    xl: number;
  };
  shadows: {
    light: string;
    medium: string;
    heavy: string;
  };
  borderRadius: {
    sm: number;
    md: number;
    lg: number;
  };
}

// Export default themes
export const lightTheme: DashboardTheme = {
  name: 'light',
  colors: {
    primary: '#3498db',
    secondary: '#95a5a6',
    background: '#ffffff',
    surface: '#f8f9fa',
    text: '#2c3e50',
    border: '#dee2e6',
    success: '#27ae60',
    warning: '#f39c12',
    error: '#e74c3c'
  },
  fonts: {
    primary: 'system-ui, -apple-system, sans-serif',
    secondary: 'Georgia, serif',
    mono: 'Monaco, Consolas, monospace'
  },
  spacing: {
    xs: 4,
    sm: 8,
    md: 16,
    lg: 24,
    xl: 32
  },
  shadows: {
    light: '0 1px 3px rgba(0,0,0,0.1)',
    medium: '0 4px 6px rgba(0,0,0,0.1)',
    heavy: '0 8px 25px rgba(0,0,0,0.15)'
  },
  borderRadius: {
    sm: 4,
    md: 8,
    lg: 12
  }
};

export const darkTheme: DashboardTheme = {
  name: 'dark',
  colors: {
    primary: '#3498db',
    secondary: '#95a5a6',
    background: '#2c3e50',
    surface: '#34495e',
    text: '#ecf0f1',
    border: '#4a6741',
    success: '#27ae60',
    warning: '#f39c12',
    error: '#e74c3c'
  },
  fonts: {
    primary: 'system-ui, -apple-system, sans-serif',
    secondary: 'Georgia, serif',
    mono: 'Monaco, Consolas, monospace'
  },
  spacing: {
    xs: 4,
    sm: 8,
    md: 16,
    lg: 24,
    xl: 32
  },
  shadows: {
    light: '0 1px 3px rgba(0,0,0,0.3)',
    medium: '0 4px 6px rgba(0,0,0,0.3)',
    heavy: '0 8px 25px rgba(0,0,0,0.4)'
  },
  borderRadius: {
    sm: 4,
    md: 8,
    lg: 12
  }
};