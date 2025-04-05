/**
 * WidgetStateManager.ts
 * 
 * Manages widget state and data binding for the dashboard.
 * Provides a centralized state management system for widgets.
 */

import { WidgetConfig } from './types';

/**
 * Widget state change listener
 */
type StateChangeListener = (widgetId: string, state: any) => void;

/**
 * Widget data binding configuration
 */
export interface DataBindingConfig {
  /**
   * Data source ID
   */
  sourceId: string;
  
  /**
   * Data property to bind to
   */
  property: string;
  
  /**
   * Transformation function for the data
   */
  transform?: (data: any) => any;
}

/**
 * Widget state manager
 */
export class WidgetStateManager {
  /**
   * Widget states
   */
  private widgetStates: Map<string, any> = new Map();
  
  /**
   * Data bindings
   */
  private dataBindings: Map<string, DataBindingConfig[]> = new Map();
  
  /**
   * State change listeners
   */
  private stateChangeListeners: StateChangeListener[] = [];
  
  /**
   * Data sources
   */
  private dataSources: Map<string, any> = new Map();
  
  /**
   * Constructor
   */
  constructor() {
    // Initialize empty state manager
  }
  
  /**
   * Register a widget state
   */
  registerWidgetState(widgetId: string, initialState: any): void {
    this.widgetStates.set(widgetId, initialState);
  }
  
  /**
   * Get widget state
   */
  getWidgetState(widgetId: string): any {
    return this.widgetStates.get(widgetId) || {};
  }
  
  /**
   * Update widget state
   */
  updateWidgetState(widgetId: string, newState: any): void {
    const currentState = this.widgetStates.get(widgetId) || {};
    const updatedState = { ...currentState, ...newState };
    
    this.widgetStates.set(widgetId, updatedState);
    
    // Notify listeners
    this.notifyStateChange(widgetId, updatedState);
  }
  
  /**
   * Register a data binding
   */
  registerDataBinding(widgetId: string, binding: DataBindingConfig): void {
    const bindings = this.dataBindings.get(widgetId) || [];
    bindings.push(binding);
    this.dataBindings.set(widgetId, bindings);
    
    // Apply initial binding if data source exists
    if (this.dataSources.has(binding.sourceId)) {
      this.applyDataBinding(widgetId, binding);
    }
  }
  
  /**
   * Register a data source
   */
  registerDataSource(sourceId: string, data: any): void {
    this.dataSources.set(sourceId, data);
    
    // Apply bindings for this data source
    this.applyDataSourceBindings(sourceId);
  }
  
  /**
   * Update a data source
   */
  updateDataSource(sourceId: string, data: any): void {
    this.dataSources.set(sourceId, data);
    
    // Apply bindings for this data source
    this.applyDataSourceBindings(sourceId);
  }
  
  /**
   * Apply data source bindings
   */
  private applyDataSourceBindings(sourceId: string): void {
    const data = this.dataSources.get(sourceId);
    
    if (!data) return;
    
    // Find all widgets bound to this data source
    for (const [widgetId, bindings] of this.dataBindings.entries()) {
      for (const binding of bindings) {
        if (binding.sourceId === sourceId) {
          this.applyDataBinding(widgetId, binding, data);
        }
      }
    }
  }
  
  /**
   * Apply a data binding
   */
  private applyDataBinding(widgetId: string, binding: DataBindingConfig, data?: any): void {
    const sourceData = data || this.dataSources.get(binding.sourceId);
    
    if (!sourceData) return;
    
    // Extract the property from the data
    const propertyPath = binding.property.split('.');
    let value = sourceData;
    
    for (const prop of propertyPath) {
      if (value === undefined || value === null) break;
      value = value[prop];
    }
    
    // Apply transformation if provided
    if (binding.transform && typeof binding.transform === 'function') {
      value = binding.transform(value);
    }
    
    // Update widget state with the bound value
    this.updateWidgetState(widgetId, {
      [binding.property]: value
    });
  }
  
  /**
   * Add state change listener
   */
  addStateChangeListener(listener: StateChangeListener): void {
    this.stateChangeListeners.push(listener);
  }
  
  /**
   * Remove state change listener
   */
  removeStateChangeListener(listener: StateChangeListener): void {
    const index = this.stateChangeListeners.indexOf(listener);
    if (index !== -1) {
      this.stateChangeListeners.splice(index, 1);
    }
  }
  
  /**
   * Notify state change listeners
   */
  private notifyStateChange(widgetId: string, state: any): void {
    for (const listener of this.stateChangeListeners) {
      listener(widgetId, state);
    }
  }
  
  /**
   * Initialize widget states from widget configs
   */
  initializeFromWidgets(widgets: WidgetConfig[]): void {
    for (const widget of widgets) {
      if (widget.id && !this.widgetStates.has(widget.id)) {
        this.registerWidgetState(widget.id, {});
      }
    }
  }
} 