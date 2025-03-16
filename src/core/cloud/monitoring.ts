/**
 * Cloud Monitoring System for Raxol
 * 
 * Provides comprehensive monitoring and analytics capabilities for cloud-integrated
 * applications, including real-user monitoring, custom event tracking, performance
 * metrics collection, and error reporting and aggregation.
 */

/**
 * Monitoring configuration options
 */
export interface MonitoringOptions {
  /**
   * Provider-specific API key
   */
  apiKey?: string;
  
  /**
   * Application environment
   */
  environment?: 'development' | 'staging' | 'production' | string;
  
  /**
   * Application version
   */
  appVersion?: string;
  
  /**
   * Whether to enable real-user monitoring
   */
  enableRUM?: boolean;
  
  /**
   * Whether to enable error tracking
   */
  enableErrorTracking?: boolean;
  
  /**
   * Whether to enable performance monitoring
   */
  enablePerformanceMonitoring?: boolean;
  
  /**
   * Whether to enable custom event tracking
   */
  enableEventTracking?: boolean;
  
  /**
   * Whether to enable console logging integration
   */
  enableConsoleIntegration?: boolean;
  
  /**
   * Sample rate for data collection (0-1)
   */
  sampleRate?: number;
  
  /**
   * Custom attributes to include with all events
   */
  globalAttributes?: Record<string, any>;
  
  /**
   * Maximum events to buffer before sending
   */
  maxEventsBuffer?: number;
  
  /**
   * Maximum time to wait before sending buffered events (ms)
   */
  maxBufferTime?: number;
  
  /**
   * List of URL patterns to ignore for monitoring
   */
  ignoredUrls?: (string | RegExp)[];
  
  /**
   * List of error messages to ignore
   */
  ignoredErrors?: (string | RegExp)[];
  
  /**
   * Maximum number of stack frames to collect
   */
  maxStackFrames?: number;
  
  /**
   * Whether to use secure connection for data transmission
   */
  useSecureConnection?: boolean;
}

/**
 * Error severity levels
 */
export enum ErrorSeverity {
  DEBUG = 'debug',
  INFO = 'info',
  WARNING = 'warning',
  ERROR = 'error',
  CRITICAL = 'critical'
}

/**
 * Performance metric types
 */
export enum PerformanceMetricType {
  NAVIGATION = 'navigation',
  RESOURCE = 'resource',
  PAINT = 'paint',
  CUSTOM = 'custom',
  LONGTASK = 'longtask',
  LAYOUT = 'layout',
  FIRST_INPUT = 'first-input',
  NETWORK = 'network',
  MEMORY = 'memory',
  RENDER = 'render'
}

/**
 * Custom event data
 */
export interface CustomEventData {
  /**
   * Event name
   */
  name: string;
  
  /**
   * Event category
   */
  category?: string;
  
  /**
   * Event attributes
   */
  attributes?: Record<string, any>;
  
  /**
   * Event timestamp
   */
  timestamp?: number;
  
  /**
   * Event value
   */
  value?: number;
}

/**
 * Error report data
 */
export interface ErrorReportData {
  /**
   * Error message
   */
  message: string;
  
  /**
   * Error name/type
   */
  name?: string;
  
  /**
   * Error stack trace
   */
  stack?: string;
  
  /**
   * Error severity level
   */
  severity?: ErrorSeverity;
  
  /**
   * Error timestamp
   */
  timestamp?: number;
  
  /**
   * Error context information
   */
  context?: Record<string, any>;
  
  /**
   * URL where the error occurred
   */
  url?: string;
  
  /**
   * User information
   */
  user?: {
    id?: string;
    username?: string;
    email?: string;
  };
  
  /**
   * Whether the error is handled
   */
  handled?: boolean;
}

/**
 * Performance data
 */
export interface PerformanceData {
  /**
   * Metric type
   */
  type: PerformanceMetricType;
  
  /**
   * Metric name
   */
  name: string;
  
  /**
   * Metric value
   */
  value: number;
  
  /**
   * Metric unit
   */
  unit?: 'ms' | 'bytes' | 'percent' | string;
  
  /**
   * Metric timestamp
   */
  timestamp?: number;
  
  /**
   * Additional attributes
   */
  attributes?: Record<string, any>;
}

/**
 * Session data
 */
export interface SessionData {
  /**
   * Session ID
   */
  id: string;
  
  /**
   * Session start timestamp
   */
  startTime: number;
  
  /**
   * User agent information
   */
  userAgent?: string;
  
  /**
   * Device information
   */
  device?: {
    type?: 'desktop' | 'mobile' | 'tablet' | string;
    model?: string;
    os?: string;
    osVersion?: string;
    browser?: string;
    browserVersion?: string;
  };
  
  /**
   * Geographic information
   */
  geo?: {
    country?: string;
    region?: string;
    city?: string;
  };
  
  /**
   * Connection information
   */
  connection?: {
    type?: 'wifi' | 'cellular' | 'ethernet' | string;
    effectiveType?: '2g' | '3g' | '4g' | string;
    downlink?: number;
    rtt?: number;
  };
  
  /**
   * User information
   */
  user?: {
    id?: string;
    username?: string;
    email?: string;
  };
}

/**
 * Monitoring client interface
 */
export interface MonitoringClient {
  /**
   * Initialize the monitoring client
   */
  initialize(options: MonitoringOptions): Promise<boolean>;
  
  /**
   * Track a custom event
   */
  trackEvent(event: CustomEventData): Promise<void>;
  
  /**
   * Report an error
   */
  reportError(error: Error | ErrorReportData): Promise<void>;
  
  /**
   * Record a performance metric
   */
  recordPerformance(data: PerformanceData): Promise<void>;
  
  /**
   * Start a new session
   */
  startSession(data?: Partial<SessionData>): Promise<SessionData>;
  
  /**
   * End the current session
   */
  endSession(): Promise<void>;
  
  /**
   * Add context attributes to all future events
   */
  addContext(attributes: Record<string, any>): void;
  
  /**
   * Set user information
   */
  setUser(user: { id?: string; username?: string; email?: string }): void;
  
  /**
   * Flush all buffered events
   */
  flush(): Promise<void>;
}

/**
 * Cloud monitoring system
 */
export class MonitoringSystem {
  private client: MonitoringClient;
  private enabled: boolean = false;
  private options: MonitoringOptions;
  private sessionActive: boolean = false;
  private currentSession?: SessionData;
  private errorHandlerInstalled: boolean = false;
  private performanceObserverInstalled: boolean = false;
  
  /**
   * Create a new monitoring system
   */
  constructor(client: MonitoringClient, options: MonitoringOptions = {}) {
    this.client = client;
    this.options = {
      environment: 'production',
      enableRUM: true,
      enableErrorTracking: true,
      enablePerformanceMonitoring: true,
      enableEventTracking: true,
      enableConsoleIntegration: false,
      sampleRate: 1.0,
      maxEventsBuffer: 30,
      maxBufferTime: 10000,
      maxStackFrames: 50,
      useSecureConnection: true,
      ...options
    };
  }
  
  /**
   * Initialize the monitoring system
   */
  async initialize(): Promise<boolean> {
    try {
      // Initialize the client
      this.enabled = await this.client.initialize(this.options);
      
      if (this.enabled) {
        // Start session if RUM is enabled
        if (this.options.enableRUM) {
          await this.startSession();
        }
        
        // Set up global error handler if error tracking is enabled
        if (this.options.enableErrorTracking) {
          this.installErrorHandler();
        }
        
        // Set up performance monitoring if enabled
        if (this.options.enablePerformanceMonitoring) {
          this.installPerformanceObserver();
        }
        
        // Set up console integration if enabled
        if (this.options.enableConsoleIntegration) {
          this.installConsoleIntegration();
        }
      }
      
      return this.enabled;
    } catch (error) {
      console.error('Failed to initialize monitoring system:', error);
      return false;
    }
  }
  
  /**
   * Track a custom event
   */
  async trackEvent(
    name: string,
    attributes: Record<string, any> = {},
    category?: string
  ): Promise<void> {
    if (!this.enabled || !this.options.enableEventTracking) {
      return;
    }
    
    // Apply sampling if configured
    if (this.shouldSample()) {
      try {
        await this.client.trackEvent({
          name,
          attributes,
          category,
          timestamp: Date.now()
        });
      } catch (error) {
        console.error('Failed to track event:', error);
      }
    }
  }
  
  /**
   * Report an error
   */
  async reportError(
    error: Error | string,
    severity: ErrorSeverity = ErrorSeverity.ERROR,
    context: Record<string, any> = {}
  ): Promise<void> {
    if (!this.enabled || !this.options.enableErrorTracking) {
      return;
    }
    
    try {
      // Convert string to Error if needed
      const errorObj = typeof error === 'string' ? new Error(error) : error;
      
      // Check if the error should be ignored
      if (this.shouldIgnoreError(errorObj)) {
        return;
      }
      
      const errorData: ErrorReportData = {
        message: errorObj.message,
        name: errorObj.name,
        stack: this.processStackTrace(errorObj.stack),
        severity,
        timestamp: Date.now(),
        context,
        url: typeof window !== 'undefined' ? window.location.href : undefined,
        handled: true
      };
      
      await this.client.reportError(errorData);
    } catch (reportError) {
      console.error('Failed to report error:', reportError);
    }
  }
  
  /**
   * Record a performance metric
   */
  async recordPerformance(
    name: string,
    value: number,
    type: PerformanceMetricType = PerformanceMetricType.CUSTOM,
    attributes: Record<string, any> = {}
  ): Promise<void> {
    if (!this.enabled || !this.options.enablePerformanceMonitoring) {
      return;
    }
    
    // Apply sampling if configured
    if (this.shouldSample()) {
      try {
        await this.client.recordPerformance({
          name,
          value,
          type,
          attributes,
          timestamp: Date.now()
        });
      } catch (error) {
        console.error('Failed to record performance metric:', error);
      }
    }
  }
  
  /**
   * Start a new session
   */
  async startSession(): Promise<SessionData | undefined> {
    if (!this.enabled || !this.options.enableRUM || this.sessionActive) {
      return this.currentSession;
    }
    
    try {
      const sessionData: Partial<SessionData> = {
        userAgent: typeof navigator !== 'undefined' ? navigator.userAgent : undefined
      };
      
      // Add device information if available
      if (typeof navigator !== 'undefined') {
        sessionData.device = this.getDeviceInfo();
      }
      
      // Add connection information if available
      if (typeof navigator !== 'undefined' && 'connection' in navigator) {
        sessionData.connection = this.getConnectionInfo();
      }
      
      this.currentSession = await this.client.startSession(sessionData);
      this.sessionActive = true;
      
      // Set up session end handler
      if (typeof window !== 'undefined') {
        window.addEventListener('beforeunload', this.handleBeforeUnload);
      }
      
      return this.currentSession;
    } catch (error) {
      console.error('Failed to start session:', error);
      return undefined;
    }
  }
  
  /**
   * End the current session
   */
  async endSession(): Promise<void> {
    if (!this.enabled || !this.options.enableRUM || !this.sessionActive) {
      return;
    }
    
    try {
      await this.client.endSession();
      this.sessionActive = false;
      this.currentSession = undefined;
      
      // Remove session end handler
      if (typeof window !== 'undefined') {
        window.removeEventListener('beforeunload', this.handleBeforeUnload);
      }
    } catch (error) {
      console.error('Failed to end session:', error);
    }
  }
  
  /**
   * Set user information
   */
  setUser(user: { id?: string; username?: string; email?: string }): void {
    if (!this.enabled) {
      return;
    }
    
    try {
      this.client.setUser(user);
    } catch (error) {
      console.error('Failed to set user:', error);
    }
  }
  
  /**
   * Add context attributes
   */
  addContext(attributes: Record<string, any>): void {
    if (!this.enabled) {
      return;
    }
    
    try {
      this.client.addContext(attributes);
    } catch (error) {
      console.error('Failed to add context:', error);
    }
  }
  
  /**
   * Flush all buffered events
   */
  async flush(): Promise<void> {
    if (!this.enabled) {
      return;
    }
    
    try {
      await this.client.flush();
    } catch (error) {
      console.error('Failed to flush events:', error);
    }
  }
  
  /**
   * Handle page visibility change
   */
  private handleVisibilityChange = (): void => {
    if (typeof document === 'undefined') {
      return;
    }
    
    if (document.visibilityState === 'hidden') {
      // Flush events when page becomes hidden
      this.flush().catch(console.error);
    }
  };
  
  /**
   * Handle before unload event
   */
  private handleBeforeUnload = (): void => {
    // Flush events before page unloads
    this.flush().catch(console.error);
    
    // End session before page unloads
    this.endSession().catch(console.error);
  };
  
  /**
   * Install global error handler
   */
  private installErrorHandler(): void {
    if (typeof window === 'undefined' || this.errorHandlerInstalled) {
      return;
    }
    
    const originalOnError = window.onerror;
    window.onerror = (message, source, lineno, colno, error) => {
      // Report the error
      if (error) {
        this.reportError(error, ErrorSeverity.ERROR, {
          source,
          line: lineno,
          column: colno
        }).catch(console.error);
      } else {
        this.reportError(
          String(message),
          ErrorSeverity.ERROR,
          {
            source,
            line: lineno,
            column: colno
          }
        ).catch(console.error);
      }
      
      // Call the original handler if it exists
      if (typeof originalOnError === 'function') {
        return originalOnError(message, source, lineno, colno, error);
      }
      
      return false;
    };
    
    const originalOnUnhandledRejection = window.onunhandledrejection;
    window.onunhandledrejection = (event) => {
      // Report the unhandled promise rejection
      const error = event.reason instanceof Error
        ? event.reason
        : new Error(String(event.reason));
      
      this.reportError(error, ErrorSeverity.ERROR, {
        unhandledRejection: true
      }).catch(console.error);
      
      // Call the original handler if it exists
      if (typeof originalOnUnhandledRejection === 'function') {
        return originalOnUnhandledRejection(event);
      }
    };
    
    this.errorHandlerInstalled = true;
  }
  
  /**
   * Install performance observer
   */
  private installPerformanceObserver(): void {
    if (typeof window === 'undefined' || 
        typeof PerformanceObserver === 'undefined' || 
        this.performanceObserverInstalled) {
      return;
    }
    
    try {
      // Observe navigation timing
      const navigationObserver = new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          this.recordPerformance(
            'navigation',
            entry.duration,
            PerformanceMetricType.NAVIGATION,
            {
              startTime: entry.startTime,
              domComplete: (entry as PerformanceNavigationTiming).domComplete,
              loadEventEnd: (entry as PerformanceNavigationTiming).loadEventEnd,
              domInteractive: (entry as PerformanceNavigationTiming).domInteractive,
              domContentLoadedEventEnd: (entry as PerformanceNavigationTiming).domContentLoadedEventEnd
            }
          ).catch(console.error);
        }
      });
      navigationObserver.observe({ type: 'navigation', buffered: true });
      
      // Observe resource timing
      const resourceObserver = new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          // Skip monitoring service requests to avoid circular reporting
          const url = (entry as PerformanceResourceTiming).name;
          if (this.shouldIgnoreUrl(url)) {
            continue;
          }
          
          this.recordPerformance(
            url,
            entry.duration,
            PerformanceMetricType.RESOURCE,
            {
              startTime: entry.startTime,
              initiatorType: (entry as PerformanceResourceTiming).initiatorType,
              size: (entry as PerformanceResourceTiming).transferSize,
              serverTiming: (entry as PerformanceResourceTiming).serverTiming
            }
          ).catch(console.error);
        }
      });
      resourceObserver.observe({ type: 'resource', buffered: true });
      
      // Observe paint timing
      const paintObserver = new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          this.recordPerformance(
            entry.name,
            entry.startTime,
            PerformanceMetricType.PAINT
          ).catch(console.error);
        }
      });
      paintObserver.observe({ type: 'paint', buffered: true });
      
      // Observe first input delay
      const fidObserver = new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          this.recordPerformance(
            'first-input-delay',
            entry.processingStart! - entry.startTime,
            PerformanceMetricType.FIRST_INPUT
          ).catch(console.error);
        }
      });
      fidObserver.observe({ type: 'first-input', buffered: true });
      
      // Observe long tasks
      try {
        const longTaskObserver = new PerformanceObserver((list) => {
          for (const entry of list.getEntries()) {
            this.recordPerformance(
              'long-task',
              entry.duration,
              PerformanceMetricType.LONGTASK,
              {
                startTime: entry.startTime,
                attribution: (entry as any).attribution
              }
            ).catch(console.error);
          }
        });
        longTaskObserver.observe({ type: 'longtask', buffered: true });
      } catch (e) {
        // Long task observation may not be supported in all browsers
      }
      
      // Observe layout shifts
      try {
        const layoutShiftObserver = new PerformanceObserver((list) => {
          for (const entry of list.getEntries()) {
            // Skip entries with a value of 0
            if ((entry as any).value > 0) {
              this.recordPerformance(
                'layout-shift',
                (entry as any).value,
                PerformanceMetricType.LAYOUT,
                {
                  startTime: entry.startTime,
                  hadRecentInput: (entry as any).hadRecentInput
                }
              ).catch(console.error);
            }
          }
        });
        layoutShiftObserver.observe({ type: 'layout-shift', buffered: true });
      } catch (e) {
        // Layout shift observation may not be supported in all browsers
      }
      
      this.performanceObserverInstalled = true;
    } catch (error) {
      console.error('Failed to install performance observer:', error);
    }
  }
  
  /**
   * Install console integration
   */
  private installConsoleIntegration(): void {
    if (typeof console === 'undefined' || typeof window === 'undefined') {
      return;
    }
    
    const originalConsoleError = console.error;
    console.error = (...args: any[]) => {
      // Report console.error as an error
      const message = args.map(arg => String(arg)).join(' ');
      this.reportError(message, ErrorSeverity.ERROR, {
        source: 'console.error'
      }).catch(console.error);
      
      // Call the original method
      originalConsoleError.apply(console, args);
    };
    
    const originalConsoleWarn = console.warn;
    console.warn = (...args: any[]) => {
      // Report console.warn as a warning
      const message = args.map(arg => String(arg)).join(' ');
      this.reportError(message, ErrorSeverity.WARNING, {
        source: 'console.warn'
      }).catch(console.error);
      
      // Call the original method
      originalConsoleWarn.apply(console, args);
    };
  }
  
  /**
   * Get device information
   */
  private getDeviceInfo(): SessionData['device'] {
    if (typeof navigator === 'undefined') {
      return {};
    }
    
    const userAgent = navigator.userAgent;
    const platform = navigator.platform;
    
    // This is a simple implementation
    // A real implementation would use a more sophisticated user agent parser
    const isDesktop = !/Mobi|Android|iPad|iPhone|iPod/i.test(userAgent);
    
    let deviceType = isDesktop ? 'desktop' : 'mobile';
    if (/iPad/i.test(userAgent) || (/Macintosh/i.test(userAgent) && 'ontouchend' in document)) {
      deviceType = 'tablet';
    }
    
    // Basic OS detection
    let os = 'unknown';
    let osVersion = '';
    
    if (/Windows/i.test(userAgent)) {
      os = 'Windows';
      const match = userAgent.match(/Windows NT (\d+\.\d+)/);
      if (match) {
        osVersion = match[1];
      }
    } else if (/Macintosh|Mac OS X/i.test(userAgent)) {
      os = 'macOS';
      const match = userAgent.match(/Mac OS X (\d+[._]\d+[._]\d+)/);
      if (match) {
        osVersion = match[1].replace(/_/g, '.');
      }
    } else if (/Android/i.test(userAgent)) {
      os = 'Android';
      const match = userAgent.match(/Android (\d+\.\d+)/);
      if (match) {
        osVersion = match[1];
      }
    } else if (/iPhone|iPad|iPod/i.test(userAgent)) {
      os = 'iOS';
      const match = userAgent.match(/OS (\d+[._]\d+)/);
      if (match) {
        osVersion = match[1].replace(/_/g, '.');
      }
    } else if (/Linux/i.test(platform)) {
      os = 'Linux';
    }
    
    // Basic browser detection
    let browser = 'unknown';
    let browserVersion = '';
    
    if (/Chrome/i.test(userAgent) && !/Chromium|Edge|Edg|OPR|SamsungBrowser/i.test(userAgent)) {
      browser = 'Chrome';
      const match = userAgent.match(/Chrome\/(\d+\.\d+)/);
      if (match) {
        browserVersion = match[1];
      }
    } else if (/Firefox/i.test(userAgent)) {
      browser = 'Firefox';
      const match = userAgent.match(/Firefox\/(\d+\.\d+)/);
      if (match) {
        browserVersion = match[1];
      }
    } else if (/Safari/i.test(userAgent) && !/Chrome|Chromium|Edge|Edg|OPR|SamsungBrowser/i.test(userAgent)) {
      browser = 'Safari';
      const match = userAgent.match(/Version\/(\d+\.\d+)/);
      if (match) {
        browserVersion = match[1];
      }
    } else if (/Edge|Edg/i.test(userAgent)) {
      browser = 'Edge';
      const match = userAgent.match(/Edge\/(\d+\.\d+)/) || userAgent.match(/Edg\/(\d+\.\d+)/);
      if (match) {
        browserVersion = match[1];
      }
    } else if (/OPR/i.test(userAgent)) {
      browser = 'Opera';
      const match = userAgent.match(/OPR\/(\d+\.\d+)/);
      if (match) {
        browserVersion = match[1];
      }
    }
    
    return {
      type: deviceType,
      os,
      osVersion,
      browser,
      browserVersion
    };
  }
  
  /**
   * Get connection information
   */
  private getConnectionInfo(): SessionData['connection'] {
    if (typeof navigator === 'undefined' || !('connection' in navigator)) {
      return {};
    }
    
    // @ts-ignore: navigator.connection is not standardized yet
    const connection = navigator.connection;
    
    if (!connection) {
      return {};
    }
    
    return {
      type: connection.type,
      effectiveType: connection.effectiveType,
      downlink: connection.downlink,
      rtt: connection.rtt
    };
  }
  
  /**
   * Process stack trace
   */
  private processStackTrace(stack?: string): string | undefined {
    if (!stack) {
      return undefined;
    }
    
    // Limit the number of stack frames
    const maxFrames = this.options.maxStackFrames || 50;
    const lines = stack.split('\n');
    
    if (lines.length > maxFrames + 1) {
      return lines.slice(0, maxFrames + 1).join('\n');
    }
    
    return stack;
  }
  
  /**
   * Check if an error should be ignored
   */
  private shouldIgnoreError(error: Error): boolean {
    if (!this.options.ignoredErrors || this.options.ignoredErrors.length === 0) {
      return false;
    }
    
    const message = error.message;
    
    for (const pattern of this.options.ignoredErrors) {
      if (typeof pattern === 'string') {
        if (message.includes(pattern)) {
          return true;
        }
      } else if (pattern instanceof RegExp) {
        if (pattern.test(message)) {
          return true;
        }
      }
    }
    
    return false;
  }
  
  /**
   * Check if a URL should be ignored
   */
  private shouldIgnoreUrl(url: string): boolean {
    if (!this.options.ignoredUrls || this.options.ignoredUrls.length === 0) {
      return false;
    }
    
    for (const pattern of this.options.ignoredUrls) {
      if (typeof pattern === 'string') {
        if (url.includes(pattern)) {
          return true;
        }
      } else if (pattern instanceof RegExp) {
        if (pattern.test(url)) {
          return true;
        }
      }
    }
    
    return false;
  }
  
  /**
   * Check if an event should be sampled
   */
  private shouldSample(): boolean {
    if (this.options.sampleRate === undefined || this.options.sampleRate >= 1) {
      return true;
    }
    
    if (this.options.sampleRate <= 0) {
      return false;
    }
    
    return Math.random() < this.options.sampleRate;
  }
}

/**
 * Default monitoring client implementation that logs to console
 */
export class ConsoleMonitoringClient implements MonitoringClient {
  private options: MonitoringOptions = {};
  private context: Record<string, any> = {};
  private user?: { id?: string; username?: string; email?: string };
  private buffer: Array<{
    type: 'event' | 'error' | 'performance';
    data: any;
  }> = [];
  private flushTimeout?: number;
  
  async initialize(options: MonitoringOptions): Promise<boolean> {
    this.options = options;
    
    console.log('[Monitoring] Initialized with options:', options);
    
    // Set up flush timer if buffering is enabled
    if (options.maxBufferTime && options.maxBufferTime > 0) {
      this.setupFlushTimer();
    }
    
    return true;
  }
  
  async trackEvent(event: CustomEventData): Promise<void> {
    this.addToBuffer('event', event);
    
    if (this.shouldFlushImmediately()) {
      await this.flush();
    }
  }
  
  async reportError(error: Error | ErrorReportData): Promise<void> {
    const errorData = error instanceof Error
      ? {
          message: error.message,
          name: error.name,
          stack: error.stack,
          severity: ErrorSeverity.ERROR,
          timestamp: Date.now()
        }
      : error;
    
    this.addToBuffer('error', errorData);
    
    if (this.shouldFlushImmediately()) {
      await this.flush();
    }
  }
  
  async recordPerformance(data: PerformanceData): Promise<void> {
    this.addToBuffer('performance', data);
    
    if (this.shouldFlushImmediately()) {
      await this.flush();
    }
  }
  
  async startSession(data?: Partial<SessionData>): Promise<SessionData> {
    const sessionId = `session-${Date.now()}-${Math.random().toString(36).substring(2, 11)}`;
    
    const session: SessionData = {
      id: sessionId,
      startTime: Date.now(),
      ...data
    };
    
    console.log('[Monitoring] Session started:', session);
    
    return session;
  }
  
  async endSession(): Promise<void> {
    console.log('[Monitoring] Session ended');
    
    // Flush any remaining events
    await this.flush();
  }
  
  addContext(attributes: Record<string, any>): void {
    this.context = { ...this.context, ...attributes };
  }
  
  setUser(user: { id?: string; username?: string; email?: string }): void {
    this.user = user;
  }
  
  async flush(): Promise<void> {
    if (this.buffer.length === 0) {
      return;
    }
    
    console.log('[Monitoring] Flushing', this.buffer.length, 'events');
    
    // Group events by type
    const events = this.buffer.filter(item => item.type === 'event').map(item => item.data);
    const errors = this.buffer.filter(item => item.type === 'error').map(item => item.data);
    const performance = this.buffer.filter(item => item.type === 'performance').map(item => item.data);
    
    if (events.length > 0) {
      console.log('[Monitoring] Events:', events);
    }
    
    if (errors.length > 0) {
      console.log('[Monitoring] Errors:', errors);
    }
    
    if (performance.length > 0) {
      console.log('[Monitoring] Performance:', performance);
    }
    
    // Clear the buffer
    this.buffer = [];
    
    // Reset the flush timeout
    if (this.flushTimeout) {
      window.clearTimeout(this.flushTimeout);
      this.setupFlushTimer();
    }
  }
  
  /**
   * Add an item to the buffer
   */
  private addToBuffer(type: 'event' | 'error' | 'performance', data: any): void {
    // Add context and user information
    const enrichedData = {
      ...data,
      context: { ...this.context, ...(data.context || {}) },
      user: this.user
    };
    
    this.buffer.push({ type, data: enrichedData });
  }
  
  /**
   * Check if the buffer should be flushed immediately
   */
  private shouldFlushImmediately(): boolean {
    const maxBuffer = this.options.maxEventsBuffer;
    return maxBuffer !== undefined && this.buffer.length >= maxBuffer;
  }
  
  /**
   * Set up the flush timer
   */
  private setupFlushTimer(): void {
    if (typeof window === 'undefined') {
      return;
    }
    
    const maxBufferTime = this.options.maxBufferTime || 10000;
    
    this.flushTimeout = window.setTimeout(() => {
      this.flush().catch(console.error);
    }, maxBufferTime);
  }
}

/**
 * Create a monitoring system with the specified client and options
 */
export function createMonitoringSystem(
  client: MonitoringClient = new ConsoleMonitoringClient(),
  options: MonitoringOptions = {}
): MonitoringSystem {
  return new MonitoringSystem(client, options);
} 