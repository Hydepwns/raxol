/**
 * WidgetDataBinding.ts
 * 
 * Manages data bindings between data sources and widgets.
 */

import { DataSourceConfig } from './WidgetDataSourceManager';

/**
 * Data binding configuration
 */
export interface DataBindingConfig {
  /**
   * Binding ID
   */
  id: string;
  
  /**
   * Source data source ID
   */
  sourceId: string;
  
  /**
   * Target widget ID
   */
  targetId: string;
  
  /**
   * Data transformation function
   */
  transform?: (data: any) => any;
  
  /**
   * Update interval in milliseconds
   */
  updateInterval?: number;
  
  /**
   * Whether to update on source change
   */
  updateOnChange?: boolean;
}

/**
 * Data binding state
 */
interface DataBindingState {
  /**
   * Current value
   */
  value: any;
  
  /**
   * Last update timestamp
   */
  lastUpdate: number;
  
  /**
   * Error state
   */
  error: Error | null;
}

/**
 * Widget data binding manager
 */
export class WidgetDataBinding {
  /**
   * Data bindings
   */
  private bindings: Map<string, DataBindingConfig>;
  
  /**
   * Binding states
   */
  private states: Map<string, DataBindingState>;
  
  /**
   * Binding listeners
   */
  private listeners: Map<string, Set<(value: any) => void>>;
  
  /**
   * Update intervals
   */
  private intervals: Map<string, NodeJS.Timeout>;
  
  /**
   * Constructor
   */
  constructor() {
    this.bindings = new Map();
    this.states = new Map();
    this.listeners = new Map();
    this.intervals = new Map();
  }
  
  /**
   * Create a data binding
   */
  createBinding(config: DataBindingConfig): void {
    this.bindings.set(config.id, config);
    this.states.set(config.id, {
      value: null,
      lastUpdate: 0,
      error: null
    });
    this.listeners.set(config.id, new Set());
    
    // Set up update interval if specified
    if (config.updateInterval) {
      this.startUpdateInterval(config);
    }
  }
  
  /**
   * Remove a data binding
   */
  removeBinding(id: string): void {
    // Clear update interval
    const interval = this.intervals.get(id);
    if (interval) {
      clearInterval(interval);
      this.intervals.delete(id);
    }
    
    // Remove binding
    this.bindings.delete(id);
    this.states.delete(id);
    this.listeners.delete(id);
  }
  
  /**
   * Add a binding listener
   */
  addListener(id: string, listener: (value: any) => void): void {
    const listeners = this.listeners.get(id);
    
    if (listeners) {
      listeners.add(listener);
    }
  }
  
  /**
   * Remove a binding listener
   */
  removeListener(id: string, listener: (value: any) => void): void {
    const listeners = this.listeners.get(id);
    
    if (listeners) {
      listeners.delete(listener);
    }
  }
  
  /**
   * Get binding state
   */
  getState(id: string): DataBindingState | null {
    return this.states.get(id) || null;
  }
  
  /**
   * Update binding value
   */
  updateValue(id: string, value: any): void {
    const binding = this.bindings.get(id);
    
    if (binding) {
      // Transform value if needed
      const transformedValue = binding.transform ? binding.transform(value) : value;
      
      // Update state
      this.states.set(id, {
        value: transformedValue,
        lastUpdate: Date.now(),
        error: null
      });
      
      // Notify listeners
      const listeners = this.listeners.get(id);
      
      if (listeners) {
        listeners.forEach(listener => listener(transformedValue));
      }
    }
  }
  
  /**
   * Start update interval
   */
  private startUpdateInterval(config: DataBindingConfig): void {
    const { id, updateInterval = 5000 } = config;
    
    // Clear existing interval
    const existingInterval = this.intervals.get(id);
    if (existingInterval) {
      clearInterval(existingInterval);
    }
    
    // Set up new interval
    const newInterval = setInterval(() => {
      // Trigger update
      this.updateValue(id, null);
    }, updateInterval);
    
    // Store interval
    this.intervals.set(id, newInterval);
  }
} 