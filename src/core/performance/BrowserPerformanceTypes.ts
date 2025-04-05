/**
 * BrowserPerformanceTypes.ts
 * 
 * Comprehensive type definitions for browser performance APIs with fallback mechanisms.
 */

/**
 * Extended Performance interface with memory API
 */
export interface ExtendedPerformance extends Performance {
  memory?: {
    usedJSHeapSize: number;
    totalJSHeapSize: number;
    jsHeapSizeLimit: number;
  };
  now(): number;
}

/**
 * Performance timing interface
 */
export interface PerformanceTiming {
  navigationStart: number;
  fetchStart: number;
  domainLookupStart: number;
  domainLookupEnd: number;
  connectStart: number;
  connectEnd: number;
  requestStart: number;
  responseStart: number;
  responseEnd: number;
  domLoading: number;
  domInteractive: number;
  domContentLoadedEventStart: number;
  domContentLoadedEventEnd: number;
  domComplete: number;
  loadEventStart: number;
  loadEventEnd: number;
}

/**
 * Performance navigation interface
 */
export interface PerformanceNavigation {
  type: number;
  redirectCount: number;
}

/**
 * Performance resource timing interface
 */
export interface PerformanceResourceTiming extends PerformanceEntry {
  initiatorType: string;
  nextHopProtocol: string;
  workerStart: number;
  redirectStart: number;
  redirectEnd: number;
  fetchStart: number;
  domainLookupStart: number;
  domainLookupEnd: number;
  connectStart: number;
  connectEnd: number;
  secureConnectionStart: number;
  requestStart: number;
  responseStart: number;
  responseEnd: number;
  transferSize: number;
  encodedBodySize: number;
  decodedBodySize: number;
}

/**
 * Performance paint timing interface
 */
export interface PerformancePaintTiming extends PerformanceEntry {
  name: 'first-paint' | 'first-contentful-paint';
}

/**
 * Performance long task timing interface
 */
export interface PerformanceLongTaskTiming extends PerformanceEntry {
  attribution: PerformanceAttribution[];
}

/**
 * Performance attribution interface
 */
export interface PerformanceAttribution {
  name: string;
  entryType: string;
  startTime: number;
  duration: number;
}

/**
 * Performance observer callback interface
 */
export interface PerformanceObserverCallback {
  (list: PerformanceObserverEntryList, observer: PerformanceObserver): void;
}

/**
 * Performance observer options interface
 */
export interface PerformanceObserverInit {
  entryTypes: string[];
  buffered?: boolean;
}

/**
 * Performance observer entry list interface
 */
export interface PerformanceObserverEntryList {
  getEntries(): PerformanceEntry[];
  getEntriesByType(entryType: string): PerformanceEntry[];
  getEntriesByName(name: string): PerformanceEntry[];
}

/**
 * Performance entry interface
 */
export interface PerformanceEntry {
  name: string;
  entryType: string;
  startTime: number;
  duration: number;
}

/**
 * Performance mark interface
 */
export interface PerformanceMark extends PerformanceEntry {
  detail: any;
}

/**
 * Performance measure interface
 */
export interface PerformanceMeasure extends PerformanceEntry {
  detail: any;
}

/**
 * Performance memory interface
 */
export interface PerformanceMemory {
  usedJSHeapSize: number;
  totalJSHeapSize: number;
  jsHeapSizeLimit: number;
}

/**
 * Performance API fallback interface
 */
export interface PerformanceFallback {
  now(): number;
  timing: Partial<PerformanceTiming>;
  navigation: Partial<PerformanceNavigation>;
  memory?: Partial<PerformanceMemory>;
  mark(name: string, options?: PerformanceMarkOptions): void;
  measure(name: string, options?: PerformanceMeasureOptions): void;
  clearMarks(name?: string): void;
  clearMeasures(name?: string): void;
  getEntries(): PerformanceEntry[];
  getEntriesByType(entryType: string): PerformanceEntry[];
  getEntriesByName(name: string): PerformanceEntry[];
}

/**
 * Performance mark options interface
 */
export interface PerformanceMarkOptions {
  detail?: any;
  startTime?: number;
}

/**
 * Performance measure options interface
 */
export interface PerformanceMeasureOptions {
  detail?: any;
  start?: string | number;
  end?: string | number;
  duration?: number;
}

/**
 * Performance API availability check
 */
export function isPerformanceAPIAvailable(): boolean {
  return typeof performance !== 'undefined' && 
         typeof performance.now === 'function' &&
         typeof performance.timing !== 'undefined';
}

/**
 * Performance memory API availability check
 */
export function isPerformanceMemoryAPIAvailable(): boolean {
  const perf = performance as ExtendedPerformance;
  return typeof perf !== 'undefined' && 
         typeof perf.memory !== 'undefined';
}

/**
 * Performance observer API availability check
 */
export function isPerformanceObserverAPIAvailable(): boolean {
  return typeof PerformanceObserver !== 'undefined';
}

/**
 * Create a performance fallback implementation
 */
export function createPerformanceFallback(): PerformanceFallback {
  const startTime = Date.now();
  
  return {
    now: () => Date.now() - startTime,
    timing: {
      navigationStart: startTime,
      fetchStart: startTime,
      domainLookupStart: startTime,
      domainLookupEnd: startTime,
      connectStart: startTime,
      connectEnd: startTime,
      requestStart: startTime,
      responseStart: startTime,
      responseEnd: startTime,
      domLoading: startTime,
      domInteractive: startTime,
      domContentLoadedEventStart: startTime,
      domContentLoadedEventEnd: startTime,
      domComplete: startTime,
      loadEventStart: startTime,
      loadEventEnd: startTime
    },
    navigation: {
      type: 0,
      redirectCount: 0
    },
    memory: {
      usedJSHeapSize: 0,
      totalJSHeapSize: 0,
      jsHeapSizeLimit: 0
    },
    mark: () => {},
    measure: () => {},
    clearMarks: () => {},
    clearMeasures: () => {},
    getEntries: () => [],
    getEntriesByType: () => [],
    getEntriesByName: () => []
  };
} 