/**
 * DashboardContainer.ts
 * 
 * Main container component for the Raxol dashboard layout system.
 * This component manages the overall dashboard layout, handles
 * responsive behavior, coordinates widget interactions, and manages
 * dashboard state.
 */

import { RaxolComponent } from '../../core/component';
import { View } from '../../core/view';
import { GridSystem } from './GridSystem';
import { WidgetContainer } from './WidgetContainer';
import { ConfigurationManager } from './ConfigurationManager';
import { LayoutConfig, WidgetConfig, Position, Size, DashboardTheme } from './types';

/**
 * Dashboard component props
 */
export interface DashboardProps {
  /**
   * Configuration for widgets to display in the dashboard
   */
  widgets: WidgetConfig[];
  
  /**
   * Optional layout configuration
   */
  layout?: LayoutConfig;
  
  /**
   * Callback for when the layout changes
   */
  onLayoutChange?: (layout: LayoutConfig) => void;
  
  /**
   * Callback for when a widget is added
   */
  onWidgetAdd?: (widget: WidgetConfig) => void;
  
  /**
   * Callback for when a widget is removed
   */
  onWidgetRemove?: (widgetId: string) => void;
  
  /**
   * Callback for when a widget is resized
   */
  onWidgetResize?: (widgetId: string, size: Size) => void;
  
  /**
   * Dashboard theme settings
   */
  theme?: DashboardTheme;
}

/**
 * Dashboard component state
 */
interface DashboardState {
  /**
   * Current layout configuration
   */
  layout: LayoutConfig;
  
  /**
   * Current widgets configuration
   */
  widgets: WidgetConfig[];
  
  /**
   * Whether the dashboard is in edit mode
   */
  isEditMode: boolean;
  
  /**
   * ID of the widget being dragged, if any
   */
  draggingWidgetId: string | null;
  
  /**
   * ID of the widget being resized, if any
   */
  resizingWidgetId: string | null;
}

/**
 * Dashboard container component implementation
 */
export class DashboardContainer extends RaxolComponent<DashboardProps, DashboardState> {
  private configManager: ConfigurationManager;
  
  /**
   * Constructor
   */
  constructor(props: DashboardProps) {
    super(props);
    
    // Initialize state
    this.state = {
      layout: props.layout || this.getDefaultLayout(),
      widgets: [...props.widgets],
      isEditMode: false,
      draggingWidgetId: null,
      resizingWidgetId: null
    };
    
    // Initialize configuration manager
    this.configManager = new ConfigurationManager();
    
    // Bind methods
    this.handleWidgetDragStart = this.handleWidgetDragStart.bind(this);
    this.handleWidgetDragEnd = this.handleWidgetDragEnd.bind(this);
    this.handleWidgetDragMove = this.handleWidgetDragMove.bind(this);
    this.handleWidgetResize = this.handleWidgetResize.bind(this);
    this.handleWidgetRemove = this.handleWidgetRemove.bind(this);
    this.toggleEditMode = this.toggleEditMode.bind(this);
    this.saveLayout = this.saveLayout.bind(this);
    this.loadLayout = this.loadLayout.bind(this);
  }
  
  /**
   * Get default layout configuration
   */
  private getDefaultLayout(): LayoutConfig {
    return {
      columns: 3,
      gap: 10,
      breakpoints: {
        small: 480,
        medium: 768,
        large: 1200
      }
    };
  }
  
  /**
   * Handle widget drag start event
   */
  private handleWidgetDragStart(widgetId: string): void {
    this.setState({ draggingWidgetId: widgetId });
  }
  
  /**
   * Handle widget drag end event
   */
  private handleWidgetDragEnd(): void {
    this.setState({ draggingWidgetId: null });
    
    // Notify layout change
    if (this.props.onLayoutChange) {
      this.props.onLayoutChange(this.state.layout);
    }
  }
  
  /**
   * Handle widget drag move event
   */
  private handleWidgetDragMove(widgetId: string, position: Position): void {
    // Update widget position
    const updatedWidgets = this.state.widgets.map(widget => {
      if (widget.id === widgetId) {
        return { ...widget, position };
      }
      return widget;
    });
    
    this.setState({ widgets: updatedWidgets });
  }
  
  /**
   * Handle widget resize event
   */
  private handleWidgetResize(widgetId: string, size: Size): void {
    // Update widget size
    const updatedWidgets = this.state.widgets.map(widget => {
      if (widget.id === widgetId) {
        return { ...widget, size };
      }
      return widget;
    });
    
    this.setState({ widgets: updatedWidgets });
    
    // Notify widget resize
    if (this.props.onWidgetResize) {
      this.props.onWidgetResize(widgetId, size);
    }
  }
  
  /**
   * Handle widget remove event
   */
  private handleWidgetRemove(widgetId: string): void {
    // Remove widget
    const updatedWidgets = this.state.widgets.filter(widget => widget.id !== widgetId);
    this.setState({ widgets: updatedWidgets });
    
    // Notify widget remove
    if (this.props.onWidgetRemove) {
      this.props.onWidgetRemove(widgetId);
    }
  }
  
  /**
   * Toggle dashboard edit mode
   */
  private toggleEditMode(): void {
    this.setState({ isEditMode: !this.state.isEditMode });
  }
  
  /**
   * Save current layout
   */
  private async saveLayout(name: string): Promise<void> {
    const layoutConfig = {
      layout: this.state.layout,
      widgets: this.state.widgets
    };
    
    await this.configManager.saveLayout(name, layoutConfig);
  }
  
  /**
   * Load a saved layout
   */
  private async loadLayout(name: string): Promise<void> {
    try {
      const layoutConfig = await this.configManager.loadLayout(name);
      
      this.setState({
        layout: layoutConfig.layout,
        widgets: layoutConfig.widgets
      });
      
      // Notify layout change
      if (this.props.onLayoutChange) {
        this.props.onLayoutChange(layoutConfig.layout);
      }
    } catch (error) {
      console.error(`Failed to load layout '${name}':`, error);
    }
  }
  
  /**
   * Render the dashboard
   */
  render() {
    const { layout, widgets, isEditMode } = this.state;
    
    // Create grid system
    const grid = new GridSystem({
      columns: layout.columns,
      gap: layout.gap,
      breakpoints: layout.breakpoints
    });
    
    // Create toolbar for edit mode
    const toolbar = isEditMode ? View.box({
      border: 'single',
      children: [
        View.text('Dashboard Edit Mode'),
        View.button({
          label: 'Save Layout',
          onClick: () => this.saveLayout('default')
        }),
        View.button({
          label: 'Exit Edit Mode',
          onClick: this.toggleEditMode
        })
      ]
    }) : null;
    
    // Create widgets
    const widgetComponents = widgets.map(widget => {
      return new WidgetContainer({
        ...widget,
        isEditable: isEditMode,
        onDragStart: () => this.handleWidgetDragStart(widget.id),
        onDragEnd: this.handleWidgetDragEnd,
        onDragMove: (position) => this.handleWidgetDragMove(widget.id, position),
        onResize: (size) => this.handleWidgetResize(widget.id, size),
        onRemove: () => this.handleWidgetRemove(widget.id)
      });
    });
    
    // Combine all components
    return View.box({
      children: [
        toolbar,
        grid.withChildren(widgetComponents),
        View.button({
          label: isEditMode ? 'Exit Edit Mode' : 'Edit Dashboard',
          onClick: this.toggleEditMode
        })
      ]
    });
  }
} 