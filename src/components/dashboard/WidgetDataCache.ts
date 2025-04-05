/**
 * WidgetDataCache.ts
 * 
 * Handles data caching for widgets.
 */

/**
 * Cache entry configuration
 */
export interface CacheEntry<T = any> {
  /**
   * Cache key
   */
  key: string;
  
  /**
   * Cached data
   */
  data: T;
  
  /**
   * Cache timestamp
   */
  timestamp: number;
  
  /**
   * Cache expiration time in milliseconds
   */
  expiration: number;
  
  /**
   * Whether the cache entry is valid
   */
  isValid: boolean;
}

/**
 * Cache configuration
 */
export interface CacheConfig {
  /**
   * Default cache expiration time in milliseconds
   */
  defaultExpiration?: number;
  
  /**
   * Maximum cache size
   */
  maxSize?: number;
  
  /**
   * Whether to enable cache
   */
  enabled?: boolean;
}

/**
 * Widget data cache
 */
export class WidgetDataCache {
  /**
   * Cache entries
   */
  private entries: Map<string, CacheEntry>;
  
  /**
   * Cache configuration
   */
  private config: CacheConfig;
  
  /**
   * Constructor
   */
  constructor(config: CacheConfig = {}) {
    this.entries = new Map();
    this.config = {
      defaultExpiration: 5 * 60 * 1000, // 5 minutes
      maxSize: 100,
      enabled: true,
      ...config
    };
  }
  
  /**
   * Set cache entry
   */
  set<T>(key: string, data: T, expiration?: number): void {
    if (!this.config.enabled) {
      return;
    }
    
    // Check cache size
    if (this.entries.size >= this.config.maxSize!) {
      // Remove oldest entry
      const oldestKey = this.getOldestKey();
      if (oldestKey) {
        this.entries.delete(oldestKey);
      }
    }
    
    // Create cache entry
    const entry: CacheEntry<T> = {
      key,
      data,
      timestamp: Date.now(),
      expiration: expiration || this.config.defaultExpiration!,
      isValid: true
    };
    
    // Store entry
    this.entries.set(key, entry);
  }
  
  /**
   * Get cache entry
   */
  get<T>(key: string): T | null {
    if (!this.config.enabled) {
      return null;
    }
    
    const entry = this.entries.get(key) as CacheEntry<T>;
    
    if (!entry) {
      return null;
    }
    
    // Check expiration
    if (Date.now() - entry.timestamp > entry.expiration) {
      entry.isValid = false;
      this.entries.delete(key);
      return null;
    }
    
    return entry.data;
  }
  
  /**
   * Delete cache entry
   */
  delete(key: string): void {
    this.entries.delete(key);
  }
  
  /**
   * Clear cache
   */
  clear(): void {
    this.entries.clear();
  }
  
  /**
   * Get cache size
   */
  size(): number {
    return this.entries.size;
  }
  
  /**
   * Get oldest cache key
   */
  private getOldestKey(): string | null {
    let oldestKey: string | null = null;
    let oldestTimestamp = Infinity;
    
    this.entries.forEach((entry, key) => {
      if (entry.timestamp < oldestTimestamp) {
        oldestTimestamp = entry.timestamp;
        oldestKey = key;
      }
    });
    
    return oldestKey;
  }
  
  /**
   * Enable cache
   */
  enable(): void {
    this.config.enabled = true;
  }
  
  /**
   * Disable cache
   */
  disable(): void {
    this.config.enabled = false;
    this.clear();
  }
  
  /**
   * Set cache configuration
   */
  setConfig(config: Partial<CacheConfig>): void {
    this.config = {
      ...this.config,
      ...config
    };
  }
  
  /**
   * Get cache configuration
   */
  getConfig(): CacheConfig {
    return { ...this.config };
  }
  
  /**
   * Get cache statistics
   */
  getStats(): {
    size: number;
    enabled: boolean;
    maxSize: number;
    defaultExpiration: number;
  } {
    return {
      size: this.size(),
      enabled: this.config.enabled!,
      maxSize: this.config.maxSize!,
      defaultExpiration: this.config.defaultExpiration!
    };
  }
} 