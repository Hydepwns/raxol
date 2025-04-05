/**
 * WidgetDataSourceManager.ts
 * 
 * Manages data sources and data fetching for dashboard widgets.
 */

/**
 * Data source configuration
 */
export interface DataSourceConfig {
  /**
   * Data source ID
   */
  id: string;
  
  /**
   * Data source type
   */
  type: 'http' | 'websocket' | 'polling' | 'static';
  
  /**
   * Data source URL or endpoint
   */
  url?: string;
  
  /**
   * Polling interval in milliseconds
   */
  interval?: number;
  
  /**
   * Static data
   */
  data?: any;
  
  /**
   * Request headers
   */
  headers?: Record<string, string>;
  
  /**
   * Request method
   */
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE';
  
  /**
   * Request body
   */
  body?: any;
  
  /**
   * Data transformation function
   */
  transform?: (data: any) => any;
}

/**
 * Data source state
 */
interface DataSourceState {
  /**
   * Current data
   */
  data: any;
  
  /**
   * Last update timestamp
   */
  lastUpdate: number;
  
  /**
   * Error state
   */
  error: Error | null;
  
  /**
   * Loading state
   */
  isLoading: boolean;
}

/**
 * Data source manager
 */
export class WidgetDataSourceManager {
  /**
   * Data sources
   */
  private dataSources: Map<string, DataSourceConfig>;
  
  /**
   * Data source states
   */
  private states: Map<string, DataSourceState>;
  
  /**
   * Data source listeners
   */
  private listeners: Map<string, Set<(data: any) => void>>;
  
  /**
   * Polling intervals
   */
  private intervals: Map<string, NodeJS.Timeout>;
  
  /**
   * WebSocket connections
   */
  private websockets: Map<string, WebSocket>;
  
  /**
   * Constructor
   */
  constructor() {
    this.dataSources = new Map();
    this.states = new Map();
    this.listeners = new Map();
    this.intervals = new Map();
    this.websockets = new Map();
  }
  
  /**
   * Register a data source
   */
  registerDataSource(config: DataSourceConfig): void {
    this.dataSources.set(config.id, config);
    this.states.set(config.id, {
      data: null,
      lastUpdate: 0,
      error: null,
      isLoading: false
    });
    this.listeners.set(config.id, new Set());
    
    // Initialize data source
    this.initializeDataSource(config);
  }
  
  /**
   * Unregister a data source
   */
  unregisterDataSource(id: string): void {
    // Clean up data source
    this.cleanupDataSource(id);
    
    // Remove data source
    this.dataSources.delete(id);
    this.states.delete(id);
    this.listeners.delete(id);
  }
  
  /**
   * Add a data source listener
   */
  addListener(id: string, listener: (data: any) => void): void {
    const listeners = this.listeners.get(id);
    
    if (listeners) {
      listeners.add(listener);
    }
  }
  
  /**
   * Remove a data source listener
   */
  removeListener(id: string, listener: (data: any) => void): void {
    const listeners = this.listeners.get(id);
    
    if (listeners) {
      listeners.delete(listener);
    }
  }
  
  /**
   * Get data source state
   */
  getState(id: string): DataSourceState | null {
    return this.states.get(id) || null;
  }
  
  /**
   * Initialize a data source
   */
  private initializeDataSource(config: DataSourceConfig): void {
    const { id, type } = config;
    
    switch (type) {
      case 'http':
        this.fetchHttpData(config);
        break;
      
      case 'websocket':
        this.initializeWebSocket(config);
        break;
      
      case 'polling':
        if (config.interval) {
          this.startPolling(config);
        }
        break;
      
      case 'static':
        if (config.data) {
          this.updateData(id, config.data);
        }
        break;
    }
  }
  
  /**
   * Clean up a data source
   */
  private cleanupDataSource(id: string): void {
    // Clear interval
    const interval = this.intervals.get(id);
    if (interval) {
      clearInterval(interval);
      this.intervals.delete(id);
    }
    
    // Close WebSocket
    const websocket = this.websockets.get(id);
    if (websocket) {
      websocket.close();
      this.websockets.delete(id);
    }
  }
  
  /**
   * Fetch HTTP data
   */
  private async fetchHttpData(config: DataSourceConfig): Promise<void> {
    const { id, url, method = 'GET', headers = {}, body, transform } = config;
    
    if (!url) {
      return;
    }
    
    try {
      // Update loading state
      this.updateState(id, { isLoading: true });
      
      // Make request
      const response = await fetch(url, {
        method,
        headers,
        body: body ? JSON.stringify(body) : undefined
      });
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      
      // Parse response
      const data = await response.json();
      
      // Transform data if needed
      const transformedData = transform ? transform(data) : data;
      
      // Update data
      this.updateData(id, transformedData);
    } catch (error) {
      this.updateState(id, { error: error as Error });
    } finally {
      this.updateState(id, { isLoading: false });
    }
  }
  
  /**
   * Initialize WebSocket
   */
  private initializeWebSocket(config: DataSourceConfig): void {
    const { id, url } = config;
    
    if (!url) {
      return;
    }
    
    try {
      // Create WebSocket
      const websocket = new WebSocket(url);
      
      // Store WebSocket
      this.websockets.set(id, websocket);
      
      // Set up event handlers
      websocket.onmessage = (event) => {
        try {
          // Parse message
          const data = JSON.parse(event.data);
          
          // Transform data if needed
          const transformedData = config.transform ? config.transform(data) : data;
          
          // Update data
          this.updateData(id, transformedData);
        } catch (error) {
          this.updateState(id, { error: error as Error });
        }
      };
      
      websocket.onerror = (event) => {
        this.updateState(id, { error: new Error('WebSocket error occurred') });
      };
      
      websocket.onclose = () => {
        this.websockets.delete(id);
      };
    } catch (error) {
      this.updateState(id, { error: error as Error });
    }
  }
  
  /**
   * Start polling
   */
  private startPolling(config: DataSourceConfig): void {
    const { id, interval = 5000 } = config;
    
    // Clear existing interval
    const existingInterval = this.intervals.get(id);
    if (existingInterval) {
      clearInterval(existingInterval);
    }
    
    // Set up new interval
    const newInterval = setInterval(() => {
      this.fetchHttpData(config);
    }, interval);
    
    // Store interval
    this.intervals.set(id, newInterval);
  }
  
  /**
   * Update data source state
   */
  private updateState(id: string, state: Partial<DataSourceState>): void {
    const currentState = this.states.get(id);
    
    if (currentState) {
      this.states.set(id, {
        ...currentState,
        ...state
      });
    }
  }
  
  /**
   * Update data source data
   */
  private updateData(id: string, data: any): void {
    // Update state
    this.updateState(id, {
      data,
      lastUpdate: Date.now(),
      error: null
    });
    
    // Notify listeners
    const listeners = this.listeners.get(id);
    
    if (listeners) {
      listeners.forEach(listener => listener(data));
    }
  }
} 