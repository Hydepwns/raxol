/**
 * ConfigurationManager.ts
 * 
 * Manages saving and loading of dashboard layouts and configurations.
 * Provides persistence for dashboard state between sessions.
 */

import { LayoutConfig, WidgetConfig, DashboardConfig } from './types';

/**
 * Configuration storage options
 */
interface StorageOptions {
  /**
   * Storage namespace
   */
  namespace?: string;
  
  /**
   * Storage key prefix
   */
  keyPrefix?: string;
  
  /**
   * Storage type (local, session, custom)
   */
  storageType?: 'local' | 'session' | 'custom';
  
  /**
   * Custom storage provider if using custom storage type
   */
  customStorage?: Storage;
}

/**
 * ConfigurationManager class for handling dashboard configuration persistence
 */
export class ConfigurationManager {
  private storageNamespace: string;
  private keyPrefix: string;
  private storage: Storage;
  
  /**
   * Constructor
   */
  constructor(options: StorageOptions = {}) {
    this.storageNamespace = options.namespace || 'raxol-dashboard';
    this.keyPrefix = options.keyPrefix || 'dashboard-';
    
    // Determine storage to use
    if (options.storageType === 'custom' && options.customStorage) {
      this.storage = options.customStorage;
    } else if (options.storageType === 'session' && typeof sessionStorage !== 'undefined') {
      this.storage = sessionStorage;
    } else if (typeof localStorage !== 'undefined') {
      this.storage = localStorage;
    } else {
      // Fallback to memory storage if browser storage is unavailable
      this.storage = this.createMemoryStorage();
    }
  }
  
  /**
   * Save layout configuration
   */
  async saveLayout(name: string, layout: LayoutConfig, widgets: WidgetConfig[]): Promise<void> {
    const config: DashboardConfig = {
      layout,
      widgets,
      lastModified: new Date().toISOString()
    };
    
    const key = this.getStorageKey(name);
    try {
      this.storage.setItem(key, JSON.stringify(config));
      return Promise.resolve();
    } catch (error) {
      console.error(`Failed to save layout '${name}':`, error);
      return Promise.reject(error);
    }
  }
  
  /**
   * Load layout configuration
   */
  async loadLayout(name: string): Promise<DashboardConfig> {
    const key = this.getStorageKey(name);
    const data = this.storage.getItem(key);
    
    if (!data) {
      return Promise.reject(new Error(`Layout '${name}' not found`));
    }
    
    try {
      const config: DashboardConfig = JSON.parse(data);
      return Promise.resolve(config);
    } catch (error) {
      console.error(`Failed to parse layout '${name}':`, error);
      return Promise.reject(error);
    }
  }
  
  /**
   * Delete a saved layout configuration
   */
  async deleteLayout(name: string): Promise<void> {
    const key = this.getStorageKey(name);
    try {
      this.storage.removeItem(key);
      return Promise.resolve();
    } catch (error) {
      console.error(`Failed to delete layout '${name}':`, error);
      return Promise.reject(error);
    }
  }
  
  /**
   * List all saved layouts
   */
  async listLayouts(): Promise<string[]> {
    const layouts: string[] = [];
    const prefix = `${this.storageNamespace}:${this.keyPrefix}`;
    
    try {
      // Iterate through storage
      for (let i = 0; i < this.storage.length; i++) {
        const key = this.storage.key(i);
        if (key && key.startsWith(prefix)) {
          // Extract layout name from key
          const name = key.substring(prefix.length);
          layouts.push(name);
        }
      }
      
      return Promise.resolve(layouts);
    } catch (error) {
      console.error('Failed to list layouts:', error);
      return Promise.reject(error);
    }
  }
  
  /**
   * Get formatted storage key
   */
  private getStorageKey(name: string): string {
    return `${this.storageNamespace}:${this.keyPrefix}${name}`;
  }
  
  /**
   * Create memory-based storage for environments without localStorage
   */
  private createMemoryStorage(): Storage {
    const items = new Map<string, string>();
    
    return {
      getItem(key: string): string | null {
        return items.has(key) ? items.get(key) || null : null;
      },
      setItem(key: string, value: string): void {
        items.set(key, value);
      },
      removeItem(key: string): void {
        items.delete(key);
      },
      clear(): void {
        items.clear();
      },
      key(index: number): string | null {
        return Array.from(items.keys())[index] || null;
      },
      get length(): number {
        return items.size;
      }
    };
  }
}
