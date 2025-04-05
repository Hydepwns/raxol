/**
 * WidgetDataSync.ts
 * 
 * Handles data synchronization between widgets.
 */

/**
 * Sync configuration
 */
export interface SyncConfig {
  /**
   * Sync interval in milliseconds
   */
  interval?: number;
  
  /**
   * Whether to sync on data change
   */
  syncOnChange?: boolean;
  
  /**
   * Whether to sync on widget mount
   */
  syncOnMount?: boolean;
  
  /**
   * Whether to sync on widget unmount
   */
  syncOnUnmount?: boolean;
}

/**
 * Sync group configuration
 */
export interface SyncGroup {
  /**
   * Group ID
   */
  id: string;
  
  /**
   * Widget IDs in the group
   */
  widgetIds: string[];
  
  /**
   * Sync configuration
   */
  config: SyncConfig;
}

/**
 * Widget data sync
 */
export class WidgetDataSync {
  /**
   * Sync groups
   */
  private groups: Map<string, SyncGroup>;
  
  /**
   * Sync intervals
   */
  private intervals: Map<string, NodeJS.Timeout>;
  
  /**
   * Constructor
   */
  constructor() {
    this.groups = new Map();
    this.intervals = new Map();
  }
  
  /**
   * Create sync group
   */
  createGroup(group: SyncGroup): void {
    this.groups.set(group.id, group);
    
    // Start sync interval if configured
    if (group.config.interval) {
      this.startSyncInterval(group.id);
    }
  }
  
  /**
   * Remove sync group
   */
  removeGroup(groupId: string): void {
    // Clear sync interval
    this.clearSyncInterval(groupId);
    
    // Remove group
    this.groups.delete(groupId);
  }
  
  /**
   * Add widget to sync group
   */
  addWidgetToGroup(groupId: string, widgetId: string): void {
    const group = this.groups.get(groupId);
    
    if (group) {
      if (!group.widgetIds.includes(widgetId)) {
        group.widgetIds.push(widgetId);
      }
    }
  }
  
  /**
   * Remove widget from sync group
   */
  removeWidgetFromGroup(groupId: string, widgetId: string): void {
    const group = this.groups.get(groupId);
    
    if (group) {
      group.widgetIds = group.widgetIds.filter(id => id !== widgetId);
      
      // Remove group if empty
      if (group.widgetIds.length === 0) {
        this.removeGroup(groupId);
      }
    }
  }
  
  /**
   * Get sync group
   */
  getGroup(groupId: string): SyncGroup | undefined {
    return this.groups.get(groupId);
  }
  
  /**
   * Get widget sync groups
   */
  getWidgetGroups(widgetId: string): SyncGroup[] {
    return Array.from(this.groups.values())
      .filter(group => group.widgetIds.includes(widgetId));
  }
  
  /**
   * Start sync interval
   */
  private startSyncInterval(groupId: string): void {
    const group = this.groups.get(groupId);
    
    if (group && group.config.interval) {
      // Clear existing interval
      this.clearSyncInterval(groupId);
      
      // Start new interval
      const interval = setInterval(() => {
        this.syncGroup(groupId);
      }, group.config.interval);
      
      this.intervals.set(groupId, interval);
    }
  }
  
  /**
   * Clear sync interval
   */
  private clearSyncInterval(groupId: string): void {
    const interval = this.intervals.get(groupId);
    
    if (interval) {
      clearInterval(interval);
      this.intervals.delete(groupId);
    }
  }
  
  /**
   * Sync group
   */
  private syncGroup(groupId: string): void {
    const group = this.groups.get(groupId);
    
    if (group) {
      // Notify widgets in group
      group.widgetIds.forEach(widgetId => {
        this.notifyWidgetSync(widgetId, groupId);
      });
    }
  }
  
  /**
   * Notify widget sync
   */
  private notifyWidgetSync(widgetId: string, groupId: string): void {
    // This method would be implemented to notify widgets of sync events
    // The actual implementation would depend on the widget system
  }
  
  /**
   * Handle widget mount
   */
  handleWidgetMount(widgetId: string): void {
    const groups = this.getWidgetGroups(widgetId);
    
    groups.forEach(group => {
      if (group.config.syncOnMount) {
        this.syncGroup(group.id);
      }
    });
  }
  
  /**
   * Handle widget unmount
   */
  handleWidgetUnmount(widgetId: string): void {
    const groups = this.getWidgetGroups(widgetId);
    
    groups.forEach(group => {
      if (group.config.syncOnUnmount) {
        this.syncGroup(group.id);
      }
    });
  }
  
  /**
   * Handle data change
   */
  handleDataChange(widgetId: string): void {
    const groups = this.getWidgetGroups(widgetId);
    
    groups.forEach(group => {
      if (group.config.syncOnChange) {
        this.syncGroup(group.id);
      }
    });
  }
} 