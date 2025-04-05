/**
 * setup.ts
 * 
 * Test setup file for performance monitoring tests.
 */

// Mock the global performance object if it doesn't exist
if (typeof global.performance === 'undefined') {
  Object.defineProperty(global, 'performance', {
    value: {
      now: () => Date.now(),
      timing: {
        navigationStart: 0,
        fetchStart: 0,
        domainLookupStart: 0,
        domainLookupEnd: 0,
        connectStart: 0,
        connectEnd: 0,
        requestStart: 0,
        responseStart: 0,
        responseEnd: 0,
        domLoading: 0,
        domInteractive: 0,
        domContentLoadedEventStart: 0,
        domContentLoadedEventEnd: 0,
        domComplete: 0,
        loadEventStart: 0,
        loadEventEnd: 0
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
    },
    writable: true
  });
}

// Mock the PerformanceObserver if it doesn't exist
if (typeof global.PerformanceObserver === 'undefined') {
  class MockPerformanceObserver {
    constructor(callback: any) {}
    observe(options: any) {}
    disconnect() {}
  }
  
  Object.defineProperty(global, 'PerformanceObserver', {
    value: MockPerformanceObserver,
    writable: true
  });
}

// Add jest mock functions to the global performance object
const originalPerformance = global.performance;
Object.defineProperty(global, 'performance', {
  value: {
    ...originalPerformance,
    now: jest.fn().mockImplementation(() => Date.now()),
    mark: jest.fn(),
    measure: jest.fn(),
    clearMarks: jest.fn(),
    clearMeasures: jest.fn(),
    getEntries: jest.fn().mockReturnValue([]),
    getEntriesByType: jest.fn().mockReturnValue([]),
    getEntriesByName: jest.fn().mockReturnValue([])
  },
  writable: true
});

// Reset mocks before each test
beforeEach(() => {
  jest.clearAllMocks();
}); 