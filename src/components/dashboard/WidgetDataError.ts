/**
 * WidgetDataError.ts
 * 
 * Handles data-related errors for widgets.
 */

/**
 * Error severity levels
 */
export enum ErrorSeverity {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high',
  CRITICAL = 'critical'
}

/**
 * Error types
 */
export enum ErrorType {
  VALIDATION = 'validation',
  TRANSFORMATION = 'transformation',
  DATA_SOURCE = 'data_source',
  BINDING = 'binding',
  CACHE = 'cache',
  SYNC = 'sync',
  UNKNOWN = 'unknown'
}

/**
 * Error configuration
 */
export interface ErrorConfig {
  /**
   * Error type
   */
  type: ErrorType;
  
  /**
   * Error severity
   */
  severity: ErrorSeverity;
  
  /**
   * Error message
   */
  message: string;
  
  /**
   * Error details
   */
  details?: any;
  
  /**
   * Error timestamp
   */
  timestamp?: number;
  
  /**
   * Widget ID
   */
  widgetId?: string;
  
  /**
   * Source ID
   */
  sourceId?: string;
}

/**
 * Error handler configuration
 */
export interface ErrorHandlerConfig {
  /**
   * Whether to log errors
   */
  logErrors?: boolean;
  
  /**
   * Whether to notify on errors
   */
  notifyOnError?: boolean;
  
  /**
   * Error notification callback
   */
  onError?: (error: ErrorConfig) => void;
  
  /**
   * Error severity threshold for notification
   */
  notifySeverityThreshold?: ErrorSeverity;
}

/**
 * Widget data error handler
 */
export class WidgetDataError {
  /**
   * Error handlers
   */
  private handlers: Map<string, ErrorHandlerConfig>;
  
  /**
   * Error history
   */
  private errorHistory: ErrorConfig[];
  
  /**
   * Constructor
   */
  constructor() {
    this.handlers = new Map();
    this.errorHistory = [];
  }
  
  /**
   * Register error handler
   */
  registerHandler(widgetId: string, config: ErrorHandlerConfig): void {
    this.handlers.set(widgetId, {
      logErrors: true,
      notifyOnError: true,
      notifySeverityThreshold: ErrorSeverity.MEDIUM,
      ...config
    });
  }
  
  /**
   * Unregister error handler
   */
  unregisterHandler(widgetId: string): void {
    this.handlers.delete(widgetId);
  }
  
  /**
   * Handle error
   */
  handleError(error: ErrorConfig): void {
    // Add timestamp if not provided
    if (!error.timestamp) {
      error.timestamp = Date.now();
    }
    
    // Add to error history
    this.errorHistory.push(error);
    
    // Get handler for widget
    const handler = error.widgetId ? this.handlers.get(error.widgetId) : undefined;
    
    if (handler) {
      // Log error if configured
      if (handler.logErrors) {
        this.logError(error);
      }
      
      // Notify error if configured
      if (handler.notifyOnError && this.shouldNotify(error, handler.notifySeverityThreshold)) {
        this.notifyError(error, handler.onError);
      }
    }
  }
  
  /**
   * Get error history
   */
  getErrorHistory(widgetId?: string): ErrorConfig[] {
    if (widgetId) {
      return this.errorHistory.filter(error => error.widgetId === widgetId);
    }
    return this.errorHistory;
  }
  
  /**
   * Clear error history
   */
  clearErrorHistory(widgetId?: string): void {
    if (widgetId) {
      this.errorHistory = this.errorHistory.filter(error => error.widgetId !== widgetId);
    } else {
      this.errorHistory = [];
    }
  }
  
  /**
   * Log error
   */
  private logError(error: ErrorConfig): void {
    console.error(`[${error.type}] ${error.message}`, {
      severity: error.severity,
      widgetId: error.widgetId,
      sourceId: error.sourceId,
      details: error.details,
      timestamp: error.timestamp
    });
  }
  
  /**
   * Notify error
   */
  private notifyError(error: ErrorConfig, callback?: (error: ErrorConfig) => void): void {
    if (callback) {
      callback(error);
    }
  }
  
  /**
   * Check if error should be notified
   */
  private shouldNotify(error: ErrorConfig, threshold?: ErrorSeverity): boolean {
    if (!threshold) {
      return true;
    }
    
    const severities = Object.values(ErrorSeverity);
    const errorSeverityIndex = severities.indexOf(error.severity);
    const thresholdSeverityIndex = severities.indexOf(threshold);
    
    return errorSeverityIndex >= thresholdSeverityIndex;
  }
} 