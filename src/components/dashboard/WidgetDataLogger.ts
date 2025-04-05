/**
 * WidgetDataLogger.ts
 * 
 * Handles logging of data-related events and operations.
 */

/**
 * Log levels
 */
export enum LogLevel {
  DEBUG = 'debug',
  INFO = 'info',
  WARN = 'warn',
  ERROR = 'error'
}

/**
 * Log entry configuration
 */
export interface LogEntry {
  /**
   * Log level
   */
  level: LogLevel;
  
  /**
   * Log message
   */
  message: string;
  
  /**
   * Log details
   */
  details?: any;
  
  /**
   * Log timestamp
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
  
  /**
   * Operation type
   */
  operation?: string;
}

/**
 * Logger configuration
 */
export interface LoggerConfig {
  /**
   * Minimum log level
   */
  minLevel?: LogLevel;
  
  /**
   * Whether to log to console
   */
  logToConsole?: boolean;
  
  /**
   * Whether to log to file
   */
  logToFile?: boolean;
  
  /**
   * Log file path
   */
  logFilePath?: string;
  
  /**
   * Maximum log history size
   */
  maxHistorySize?: number;
  
  /**
   * Log format
   */
  format?: (entry: LogEntry) => string;
}

/**
 * Widget data logger
 */
export class WidgetDataLogger {
  /**
   * Logger configuration
   */
  private config: LoggerConfig;
  
  /**
   * Log history
   */
  private history: LogEntry[];
  
  /**
   * Constructor
   */
  constructor(config: LoggerConfig = {}) {
    this.config = {
      minLevel: LogLevel.INFO,
      logToConsole: true,
      logToFile: false,
      maxHistorySize: 1000,
      ...config
    };
    
    this.history = [];
  }
  
  /**
   * Log debug message
   */
  debug(message: string, details?: any, widgetId?: string, sourceId?: string, operation?: string): void {
    this.log(LogLevel.DEBUG, message, details, widgetId, sourceId, operation);
  }
  
  /**
   * Log info message
   */
  info(message: string, details?: any, widgetId?: string, sourceId?: string, operation?: string): void {
    this.log(LogLevel.INFO, message, details, widgetId, sourceId, operation);
  }
  
  /**
   * Log warning message
   */
  warn(message: string, details?: any, widgetId?: string, sourceId?: string, operation?: string): void {
    this.log(LogLevel.WARN, message, details, widgetId, sourceId, operation);
  }
  
  /**
   * Log error message
   */
  error(message: string, details?: any, widgetId?: string, sourceId?: string, operation?: string): void {
    this.log(LogLevel.ERROR, message, details, widgetId, sourceId, operation);
  }
  
  /**
   * Log message
   */
  private log(level: LogLevel, message: string, details?: any, widgetId?: string, sourceId?: string, operation?: string): void {
    // Check minimum log level
    if (this.shouldLog(level)) {
      // Create log entry
      const entry: LogEntry = {
        level,
        message,
        details,
        timestamp: Date.now(),
        widgetId,
        sourceId,
        operation
      };
      
      // Add to history
      this.addToHistory(entry);
      
      // Log to console
      if (this.config.logToConsole) {
        this.logToConsole(entry);
      }
      
      // Log to file
      if (this.config.logToFile && this.config.logFilePath) {
        this.logToFile(entry);
      }
    }
  }
  
  /**
   * Add entry to history
   */
  private addToHistory(entry: LogEntry): void {
    // Add entry
    this.history.push(entry);
    
    // Trim history if needed
    if (this.history.length > this.config.maxHistorySize!) {
      this.history = this.history.slice(-this.config.maxHistorySize!);
    }
  }
  
  /**
   * Log to console
   */
  private logToConsole(entry: LogEntry): void {
    const format = this.config.format || this.defaultFormat;
    const message = format(entry);
    
    switch (entry.level) {
      case LogLevel.DEBUG:
        console.debug(message);
        break;
      case LogLevel.INFO:
        console.info(message);
        break;
      case LogLevel.WARN:
        console.warn(message);
        break;
      case LogLevel.ERROR:
        console.error(message);
        break;
    }
  }
  
  /**
   * Log to file
   */
  private logToFile(entry: LogEntry): void {
    // This would be implemented to write logs to a file
    // The actual implementation would depend on the environment
  }
  
  /**
   * Check if should log
   */
  private shouldLog(level: LogLevel): boolean {
    const levels = Object.values(LogLevel);
    const minLevelIndex = levels.indexOf(this.config.minLevel!);
    const levelIndex = levels.indexOf(level);
    
    return levelIndex >= minLevelIndex;
  }
  
  /**
   * Default log format
   */
  private defaultFormat(entry: LogEntry): string {
    const timestamp = new Date(entry.timestamp!).toISOString();
    const prefix = `[${timestamp}] [${entry.level.toUpperCase()}]`;
    const context = entry.widgetId ? `[Widget: ${entry.widgetId}]` : '';
    const source = entry.sourceId ? `[Source: ${entry.sourceId}]` : '';
    const operation = entry.operation ? `[Operation: ${entry.operation}]` : '';
    const details = entry.details ? `\nDetails: ${JSON.stringify(entry.details, null, 2)}` : '';
    
    return `${prefix} ${context} ${source} ${operation} ${entry.message}${details}`;
  }
  
  /**
   * Get log history
   */
  getHistory(widgetId?: string, level?: LogLevel): LogEntry[] {
    let filtered = this.history;
    
    if (widgetId) {
      filtered = filtered.filter(entry => entry.widgetId === widgetId);
    }
    
    if (level) {
      filtered = filtered.filter(entry => entry.level === level);
    }
    
    return filtered;
  }
  
  /**
   * Clear log history
   */
  clearHistory(): void {
    this.history = [];
  }
  
  /**
   * Set logger configuration
   */
  setConfig(config: Partial<LoggerConfig>): void {
    this.config = {
      ...this.config,
      ...config
    };
  }
  
  /**
   * Get logger configuration
   */
  getConfig(): LoggerConfig {
    return { ...this.config };
  }
} 