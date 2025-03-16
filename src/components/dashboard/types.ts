/**
 * Dashboard Layout System Types
 * 
 * This file contains all type definitions for the dashboard layout system.
 */

import { RaxolComponent } from '../../core/component';

/**
 * Position in the grid
 */
export interface Position {
  /**
   * X coordinate (column)
   */
  x: number;
  
  /**
   * Y coordinate (row)
   */
  y: number;
}

/**
 * Size in grid units
 */
export interface Size {
  /**
   * Width in grid units
   */
  width: number;
  
  /**
   * Height in grid units
   */
  height: number;
}

/**
 * Responsive breakpoints for layout
 */
export interface Breakpoints {
  /**
   * Small screen breakpoint (mobile)
   */
  small: number;
  
  /**
   * Medium screen breakpoint (tablet)
   */
  medium: number;
  
  /**
   * Large screen breakpoint (desktop)
   */
  large: number;
  
  /**
   * Extra large screen breakpoint (large desktop)
   */
  xlarge?: number;
}

/**
 * Layout configuration
 */
export interface LayoutConfig {
  /**
   * Number of columns in the grid
   */
  columns: number;
  
  /**
   * Gap between grid cells
   */
  gap?: number;
  
  /**
   * Responsive breakpoints
   */
  breakpoints?: Breakpoints;
  
  /**
   * Default row height
   */
  rowHeight?: number;
  
  /**
   * Maximum number of rows
   */
  maxRows?: number;
}

/**
 * Widget control component
 */
export interface Control {
  /**
   * Control ID
   */
  id: string;
  
  /**
   * Control type
   */
  type: 'button' | 'toggle' | 'menu' | 'custom';
  
  /**
   * Control label
   */
  label?: string;
  
  /**
   * Control icon
   */
  icon?: string;
  
  /**
   * Click handler
   */
  onClick?: () => void;
  
  /**
   * Custom component for custom control type
   */
  component?: RaxolComponent;
}

/**
 * Widget configuration
 */
export interface WidgetConfig {
  /**
   * Widget ID
   */
  id: string;
  
  /**
   * Widget title
   */
  title: string;
  
  /**
   * Widget content component
   */
  content: RaxolComponent | React.ReactNode;
  
  /**
   * Widget position in the grid
   */
  position?: Position;
  
  /**
   * Widget size in grid units
   */
  size?: Size;
  
  /**
   * Minimum widget size
   */
  minSize?: Size;
  
  /**
   * Maximum widget size
   */
  maxSize?: Size;
  
  /**
   * Whether the widget can be resized
   */
  isResizable?: boolean;
  
  /**
   * Whether the widget can be dragged
   */
  isDraggable?: boolean;
  
  /**
   * Additional widget controls
   */
  additionalControls?: Control[];
  
  /**
   * Widget background color
   */
  backgroundColor?: string;
  
  /**
   * Widget border style
   */
  border?: 'none' | 'single' | 'double' | 'rounded';
  
  /**
   * Custom widget styles
   */
  styles?: Record<string, any>;
}

/**
 * Dashboard theme settings
 */
export interface DashboardTheme {
  /**
   * Primary color
   */
  primaryColor?: string;
  
  /**
   * Secondary color
   */
  secondaryColor?: string;
  
  /**
   * Text color
   */
  textColor?: string;
  
  /**
   * Background color
   */
  backgroundColor?: string;
  
  /**
   * Widget background color
   */
  widgetBackgroundColor?: string;
  
  /**
   * Grid line color
   */
  gridLineColor?: string;
  
  /**
   * Border color
   */
  borderColor?: string;
  
  /**
   * Gap between widgets
   */
  widgetGap?: number;
  
  /**
   * Border radius for widgets
   */
  borderRadius?: number;
  
  /**
   * Shadow for widgets
   */
  widgetShadow?: string;
}

/**
 * Layout configuration with widgets
 */
export interface LayoutWithWidgets {
  /**
   * Layout configuration
   */
  layout: LayoutConfig;
  
  /**
   * Widget configurations
   */
  widgets: WidgetConfig[];
}

/**
 * Complete dashboard configuration with metadata
 */
export interface DashboardConfig {
  /**
   * Layout configuration
   */
  layout: LayoutConfig;
  
  /**
   * Widget configurations
   */
  widgets: WidgetConfig[];
  
  /**
   * Last modified timestamp
   */
  lastModified: string;
  
  /**
   * Dashboard name
   */
  name?: string;
  
  /**
   * Dashboard description
   */
  description?: string;
}

/**
 * Dashboard template
 */
export interface Template {
  /**
   * Template ID
   */
  id: string;
  
  /**
   * Template name
   */
  name: string;
  
  /**
   * Template description
   */
  description?: string;
  
  /**
   * Template thumbnail
   */
  thumbnail?: string;
  
  /**
   * Layout configuration with widgets
   */
  config: LayoutWithWidgets;
} 